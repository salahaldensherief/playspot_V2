import {createFixtureDatabase} from './runtime/database.mjs';
import {readFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
const db=await createFixtureDatabase();
const id=n=>`00000000-0000-0000-0000-${String(n).padStart(12,'0')}`;
const owner=id(1),other=id(2),lounge=id(10),combo=id(20),rule=id(21);
let passed=0;
const read=path=>readFile(new URL(path,import.meta.url),'utf8');
async function check(name,body){await db.exec('BEGIN');try{await body();passed++;console.log('PASS '+name);}finally{await db.exec('ROLLBACK');}}
async function denied(action,code='42501'){await db.exec('SAVEPOINT denied');await assert.rejects(action(),e=>e.code===code);await db.exec('ROLLBACK TO SAVEPOINT denied;RELEASE SAVEPOINT denied');}
const archive=kind=>db.query('SELECT archive_canteen_catalogue_item($1,$2) r',[kind,kind==='combo'?combo:rule]);
try{
 await db.exec(await read('./runtime/checkout_canteen_schema.sql'));
 await db.exec(`CREATE TABLE auth.users(id uuid PRIMARY KEY);
 CREATE TABLE platform_super_admins(user_id uuid PRIMARY KEY);
 CREATE TABLE lounge_staff(user_id uuid,lounge_id uuid,role text);
 CREATE TABLE app_permissions(key text PRIMARY KEY,default_super_admin boolean,default_owner boolean,default_cashier boolean);
 CREATE TABLE lounge_role_permissions(lounge_id uuid,role text,permission_key text,is_enabled boolean);
 CREATE TABLE staff_permissions(user_id uuid,lounge_id uuid,permission_key text,is_enabled boolean);
 INSERT INTO app_permissions VALUES('menu_manage_items',true,true,false);
 INSERT INTO auth.users VALUES('${owner}'),('${other}');
 INSERT INTO profiles(id,role) VALUES('${owner}','owner'),('${other}','owner');
 INSERT INTO lounges(id,name,owner_id) VALUES('${lounge}','Synthetic','${owner}');
 INSERT INTO canteen_combos(id,lounge_id,name_ar,price,is_active) VALUES('${combo}','${lounge}','Synthetic offer',100,false);
 INSERT INTO upsell_rules(id,lounge_id,trigger_type,suggest_combo_id) VALUES('${rule}','${lounge}','session_minutes_elapsed','${combo}');
 CREATE TABLE fixture_sales(id integer PRIMARY KEY,combo_id uuid REFERENCES public.canteen_combos(id),rule_id uuid REFERENCES public.upsell_rules(id),total numeric);
 INSERT INTO fixture_sales VALUES(1,'${combo}','${rule}',100);
 GRANT SELECT,INSERT,UPDATE,DELETE ON public.canteen_combos,public.upsell_rules TO authenticated;
 SET request.jwt.claim.sub='${owner}';`);
 const permissions=await read('../migrations/20260927000002_server_authoritative_permission_precedence.sql');
 await db.exec(permissions.slice(0,permissions.indexOf('CREATE OR REPLACE FUNCTION public.get_my_permissions'))+'\nCOMMIT;');
 const boundaries=await read('../migrations/20261007000005_permission_delegation_boundaries.sql');
 await db.exec(boundaries.slice(0,boundaries.indexOf('CREATE OR REPLACE FUNCTION public.get_lounge_role_permission_catalog'))+'\nCOMMIT;');
 await db.exec(await read('../migrations/20261010131519_eligible_canonical_lounge_authorization.sql'));
 const actor=await read('../migrations/20261010134409_eligible_booking_hold_and_checkout_actor.sql');
 await db.exec(actor.slice(0,actor.indexOf('-- Gate before capacity'))+'\nCOMMIT;');
 await db.exec(await read('../migrations/20261011133002_canteen_catalogue_deletion_tombstones.sql'));
 await check('inactive catalogue items remain editable until explicitly archived',async()=>{
  assert.equal((await db.query('SELECT count(*)::int n FROM canteen_combos WHERE deleted_at IS NULL')).rows[0].n,1);
  await db.exec('UPDATE canteen_combos SET is_active=true');assert.equal((await db.query('SELECT is_active FROM canteen_combos')).rows[0].is_active,true);
 });
 await check('combo archive survives reload, disables suggestions and preserves sales',async()=>{
  assert.equal((await archive('combo')).rows[0].r.success,true);
  assert.equal((await db.query('SELECT count(*)::int n FROM canteen_combos WHERE deleted_at IS NULL')).rows[0].n,0);
  assert.equal((await db.query('SELECT is_active FROM upsell_rules')).rows[0].is_active,false);
  assert.equal((await db.query('SELECT total FROM fixture_sales')).rows[0].total,'100');
  const first=(await db.query('SELECT deleted_at FROM canteen_combos')).rows[0].deleted_at;
  await archive('combo');assert.deepEqual((await db.query('SELECT deleted_at FROM canteen_combos')).rows[0].deleted_at,first);
  await denied(()=>db.query('UPDATE canteen_combos SET deleted_at=NULL,is_active=true'),'55000');
 });
 await check('upsell archive is permanent and idempotent without deleting reports',async()=>{
  await archive('upsell_rule');await archive('upsell_rule');
  assert.equal((await db.query('SELECT count(*)::int n FROM upsell_rules WHERE deleted_at IS NULL')).rows[0].n,0);
  await denied(()=>db.query('UPDATE upsell_rules SET is_active=true'),'55000');
  assert.equal((await db.query('SELECT count(*)::int n FROM fixture_sales')).rows[0].n,1);
 });
 await check('foreign lounge, explicit denial, inactive and banned actors cannot archive',async()=>{
  await db.exec(`SET request.jwt.claim.sub='${other}'`);await denied(()=>archive('combo'));
  await db.exec(`SET request.jwt.claim.sub='${owner}';INSERT INTO staff_permissions VALUES('${owner}','${lounge}','menu_manage_items',false)`);await denied(()=>archive('combo'));
  await db.exec(`DELETE FROM staff_permissions;UPDATE profiles SET is_active=false WHERE id='${owner}'`);await denied(()=>archive('combo'));
  await db.exec(`UPDATE profiles SET is_active=true,is_banned=true WHERE id='${owner}'`);await denied(()=>archive('combo'));
 });
 await check('invalid identifiers and anonymous actors fail without catalogue mutations',async()=>{
  await denied(()=>archive('unknown'),'22023');await denied(()=>db.query("SELECT archive_canteen_catalogue_item('combo',NULL)"),'22023');
  await db.exec("SET request.jwt.claim.sub=''");await denied(()=>archive('combo'),'28000');
 });
 await check('clients cannot physically delete catalogue rows or execute private guard',async()=>{
  for(const role of ['anon','authenticated','service_role']) for(const table of ['canteen_combos','upsell_rules'])
   assert.equal((await db.query('SELECT has_table_privilege($1,$2,$3) ok',[role,'public.'+table,'DELETE'])).rows[0].ok,false);
  assert.equal((await db.query("SELECT has_function_privilege('authenticated','private.guard_catalogue_tombstone()','EXECUTE') ok")).rows[0].ok,false);
 });
 console.log(JSON.stringify({passed,environment:'isolated PostgreSQL with canonical lounge permissions'}));
}finally{await db.close();}
