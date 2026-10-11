import {installLatestFunctions} from './runtime/latest_contracts.mjs';
import {createFixtureDatabase} from './runtime/database.mjs';
import {readFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
const db=await createFixtureDatabase();
const id=n=>`00000000-0000-0000-0000-${String(n).padStart(12,'0')}`;
const owner=id(1),manager=id(2),platform=id(3),lounges=[id(10),id(11),id(12)];
let passed=0;
const read=path=>readFile(new URL(path,import.meta.url),'utf8');
async function check(name,body){await db.exec('BEGIN');try{await body();passed++;console.log('PASS '+name);}finally{await db.exec('ROLLBACK');}}
const bookings=async(lounge=null,status=null,limit=50,offset=0)=>(await db.query(
  'SELECT get_all_bookings_admin($1,$2,$3,$4) r',[lounge,status,limit,offset])).rows[0].r;
async function denied(action,code='42501'){await db.exec('SAVEPOINT denied');await assert.rejects(action(),e=>e.code===code);await db.exec('ROLLBACK TO SAVEPOINT denied;RELEASE SAVEPOINT denied');}
try{
  await db.exec(await read('./runtime/checkout_canteen_schema.sql'));
  await db.exec(`CREATE TABLE auth.users(id uuid PRIMARY KEY);
    CREATE TABLE platform_super_admins(user_id uuid PRIMARY KEY);
    CREATE TABLE lounge_staff(user_id uuid,lounge_id uuid,role text);
    CREATE TABLE app_permissions(key text PRIMARY KEY,default_super_admin boolean,default_owner boolean,default_cashier boolean);
    CREATE TABLE lounge_role_permissions(lounge_id uuid,role text,permission_key text,is_enabled boolean);
    CREATE TABLE staff_permissions(user_id uuid,lounge_id uuid,permission_key text,is_enabled boolean);
    INSERT INTO app_permissions VALUES('bookings.view',true,true,true);
    INSERT INTO auth.users VALUES('${owner}'),('${manager}'),('${platform}');
    INSERT INTO profiles(id,role,lounge_id) VALUES('${owner}','owner','${lounges[0]}'),
      ('${manager}','manager','${lounges[0]}'),('${platform}','manager','${lounges[0]}');
    INSERT INTO platform_super_admins VALUES('${platform}');
    CREATE OR REPLACE FUNCTION public.is_super_admin() RETURNS boolean LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$
      SELECT EXISTS(SELECT 1 FROM public.profiles p JOIN auth.users u ON u.id=p.id WHERE p.id=auth.uid()
        AND p.is_active IS TRUE AND p.is_banned IS FALSE AND (p.role IN ('super_admin','superadmin')
          OR EXISTS(SELECT 1 FROM public.platform_super_admins s WHERE s.user_id=p.id)))$$;
    INSERT INTO lounge_staff VALUES('${manager}','${lounges[2]}','manager');
    SET request.jwt.claim.sub='${owner}';`);
  for(let i=0;i<3;i++)await db.query(`INSERT INTO lounges(id,name,owner_id) VALUES($1,$2,$3);
    `,[lounges[i],`Branch ${i}`,i<2?owner:id(90)]);
  for(let i=0;i<3;i++)await db.query(`INSERT INTO bookings(id,lounge_id,date,start_time,end_time,room_price,total_price,status)
    VALUES($1,$2,'2026-10-12','12:00','13:00',100,100,'upcoming')`,[id(20+i),lounges[i]]);
  const permissions=await read('../migrations/20260927000002_server_authoritative_permission_precedence.sql');
  await db.exec(permissions.slice(0,permissions.indexOf('CREATE OR REPLACE FUNCTION public.get_my_permissions'))+'\nCOMMIT;');
  const boundaries=await read('../migrations/20261007000005_permission_delegation_boundaries.sql');
  await db.exec(boundaries.slice(0,boundaries.indexOf('CREATE OR REPLACE FUNCTION public.get_lounge_role_permission_catalog'))+'\nCOMMIT;');
  await db.exec(await read('../migrations/20261010131519_eligible_canonical_lounge_authorization.sql'));
  const actor=await read('../migrations/20261010134409_eligible_booking_hold_and_checkout_actor.sql');
  await db.exec(actor.slice(0,actor.indexOf('-- Gate before capacity'))+'\nCOMMIT;');
  await db.exec(await read('../migrations/20261011072030_branch_booking_read_scope.sql'));
  await db.exec('DROP FUNCTION get_all_bookings_admin(uuid,text,integer,integer)');
  await installLatestFunctions(db,["public.get_all_bookings_admin", "public.validate_voucher_by_code", "public.apply_booking_discount"]);
  await check('owner can read another owned branch despite a different profile lounge',async()=>{
    const rows=await bookings(lounges[1]);assert.equal(rows.length,1);assert.equal(rows[0].lounge_id,lounges[1]);
    assert.deepEqual((await bookings()).map(r=>r.lounge_id).sort(),lounges.slice(0,2).sort());
  });
  await check('other owner branch is denied and global requests never expose it',async()=>{
    await denied(()=>bookings(lounges[2]));assert.equal((await bookings()).some(r=>r.lounge_id===lounges[2]),false);
  });
  await check('staff membership authorizes its branch and explicit view denial is honored',async()=>{
    await db.exec(`SET request.jwt.claim.sub='${manager}'`);assert.equal((await bookings(lounges[2])).length,1);
    await db.query("INSERT INTO staff_permissions VALUES($1,$2,'bookings.view',false)",[manager,lounges[2]]);
    await denied(()=>bookings(lounges[2]));assert.equal((await bookings()).some(r=>r.lounge_id===lounges[2]),false);
  });
  await check('canonical platform membership grants all branches without a super-admin role string',async()=>{
    await db.exec(`SET request.jwt.claim.sub='${platform}'`);assert.equal((await bookings()).length,3);
  });
  await check('inactive, banned, missing Auth and anonymous actors cannot use retained credentials',async()=>{
    await db.exec(`UPDATE profiles SET is_active=false WHERE id='${owner}'`);await denied(()=>bookings());
    await db.exec(`UPDATE profiles SET is_active=true,is_banned=true WHERE id='${owner}'`);await denied(()=>bookings());
    await db.exec(`UPDATE profiles SET is_banned=false WHERE id='${owner}';DELETE FROM auth.users WHERE id='${owner}'`);await denied(()=>bookings());
    await db.exec("SET request.jwt.claim.sub=''");await denied(()=>bookings(),'28000');
  });
  await check('status filter and pagination retain exact branch scope',async()=>{
    assert.equal((await bookings(null,'completed')).length,0);
    const first=await bookings(null,null,1,0),second=await bookings(null,null,1,1);
    assert.equal(first.length,1);assert.equal(second.length,1);assert.notEqual(first[0].id,second[0].id);
    await denied(()=>bookings(null,null,0),'22023');await denied(()=>bookings(null,null,50,-1),'22023');
  });
  await check('discounts require checkout authority and reject unverified voucher and invalid money',async()=>{
    await db.exec("INSERT INTO app_permissions VALUES('billing_checkout',true,true,true)");
    const discount=(amount=10,percentage=0,voucher=null)=>db.query(
      'SELECT apply_booking_discount($1,$2,$3,$4,$5) r',[id(20),amount,percentage,'Reviewed adjustment',voucher]);
    assert.equal((await discount()).rows[0].r.discount_amount,10);
    for(const value of ['NaN','Infinity','-Infinity',-1,0.001]) await denied(()=>discount(value),'22023');
    await denied(()=>discount(10,0,'INVENTED_CODE'),'22023');
    await denied(()=>discount(10,10),'22023');
    await db.exec(`INSERT INTO staff_permissions VALUES('${owner}','${lounges[0]}','billing_checkout',false)`);
    await denied(()=>discount());
    await db.exec(`DELETE FROM staff_permissions;UPDATE profiles SET is_active=false WHERE id='${owner}'`);
    await denied(()=>discount());
  });
  await check('customer voucher lookup requires an explicit authorized target instead of a role shortcut',async()=>{
    await db.query("INSERT INTO app_permissions VALUES('billing_checkout',true,true,false)");
    await db.query('INSERT INTO auth.users VALUES($1),($2)',[id(90),id(91)]);
    await db.query("INSERT INTO profiles(id,role,lounge_id) VALUES($1,'customer',$2),($3,'customer',NULL)",[id(90),lounges[0],id(91)]);
    await db.query('UPDATE bookings SET user_id=$1 WHERE lounge_id=$2',[id(90),lounges[0]]);
    await db.query('UPDATE bookings SET user_id=$1 WHERE lounge_id=$2',[id(91),lounges[2]]);
    await db.query("INSERT INTO user_vouchers(id,user_id,code,reward_type,reward_value,status,expires_at) VALUES($1,$2,'OWNED_CODE','discount',10,'active',now()+interval '1 day'),($3,$4,'FOREIGN_CODE','discount',20,'active',now()+interval '1 day')",[id(100),id(90),id(101),id(91)]);
    const validate=async(code,target=null)=>(await db.query('SELECT validate_voucher_by_code($1,$2) r',[code,target])).rows[0].r;
    assert.equal((await validate('OWNED_CODE')).valid,false);
    assert.equal((await validate('OWNED_CODE',id(90))).valid,true);
    await denied(()=>validate('FOREIGN_CODE',id(91)));
    await db.query("INSERT INTO staff_permissions VALUES($1,$2,'billing_checkout',false)",[owner,lounges[0]]);
    await denied(()=>validate('OWNED_CODE',id(90)));
    await db.exec(`SET request.jwt.claim.sub='${id(90)}'`);
    assert.equal((await validate('OWNED_CODE')).valid,true);
    await denied(()=>validate('FOREIGN_CODE',id(91)));
    await db.query('UPDATE profiles SET is_banned=true WHERE id=$1',[id(90)]);await denied(()=>validate('OWNED_CODE'));
  });
  console.log(JSON.stringify({passed,environment:'isolated RPC with actual canonical permission functions'}));
}finally{await db.close();}
