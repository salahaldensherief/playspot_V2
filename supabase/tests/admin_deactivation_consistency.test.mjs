import {createFixtureDatabase} from './runtime/database.mjs';
import {readFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
const db=await createFixtureDatabase();let passed=0;
const admin='10000000-0000-0000-0000-000000000001',target='10000000-0000-0000-0000-000000000002',other='10000000-0000-0000-0000-000000000003';
const read=p=>readFile(new URL(p,import.meta.url),'utf8');
async function call(id=target){return (await db.query('SELECT public.deactivate_lounge_admin($1) AS result',[id])).rows[0].result;}
async function check(name,body){await body();passed++;console.log('PASS '+name);}
try{
 await db.exec(`CREATE ROLE anon;CREATE ROLE authenticated;CREATE SCHEMA auth;
 CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql AS $$SELECT nullif(current_setting('test.actor',true),'')::uuid$$;
 CREATE TABLE auth.users(id uuid PRIMARY KEY);
 CREATE TABLE public.profiles(id uuid PRIMARY KEY,role text,is_active boolean,is_banned boolean,lounge_id uuid,fcm_token text,updated_at timestamptz);
 CREATE TABLE public.platform_super_admins(user_id uuid);
 CREATE TABLE public.lounges(id integer PRIMARY KEY,owner_id uuid,updated_at timestamptz);
 CREATE TABLE public.lounge_staff(user_id uuid);
 INSERT INTO auth.users VALUES('${admin}'),('${target}'),('${other}');
 INSERT INTO public.profiles VALUES('${admin}','super_admin',true,false,null,null,now()),('${target}','owner',true,false,null,'synthetic',now()),('${other}','owner',true,false,null,null,now());
 INSERT INTO public.lounges VALUES(1,'${target}',now()),(2,'${other}',now());INSERT INTO public.lounge_staff VALUES('${target}'),('${other}');
 GRANT USAGE ON SCHEMA auth,public TO authenticated;`);
 await db.exec(await read('../repairs/active_super_admin_boundary.sql'));await db.exec(await read('./fixtures/legacy_admin_deactivation_contract.sql'));
 await db.exec(`SET test.actor='${other}';SET ROLE authenticated`);
 await check('ordinary owner cannot deactivate another lounge administrator',async()=>await assert.rejects(call(),e=>e.code==='42501'));
 for(const field of ['is_active','is_banned'])await check('disabled super admin denied: '+field,async()=>{
  await db.exec(`RESET ROLE;SET test.actor='${admin}';UPDATE public.profiles SET ${field}=${field==='is_active'?'false':'true'} WHERE id='${admin}';SET ROLE authenticated`);
  await assert.rejects(call(),e=>e.code==='42501');await db.exec(`RESET ROLE;UPDATE public.profiles SET ${field}=${field==='is_active'?'true':'false'} WHERE id='${admin}';SET ROLE authenticated`);
 });
 await check('self and platform administrator targets are protected',async()=>{
  await assert.rejects(call(admin),e=>e.code==='42501');await db.exec(`RESET ROLE;INSERT INTO public.platform_super_admins VALUES('${target}');SET ROLE authenticated`);
  await assert.rejects(call(),e=>e.code==='42501');await db.exec('RESET ROLE;DELETE FROM public.platform_super_admins;SET ROLE authenticated');
 });
 await check('late profile failure rolls back ownership and staff removal',async()=>{
  await db.exec(`RESET ROLE;CREATE FUNCTION public.synthetic_failure() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN RAISE EXCEPTION 'fixture failure' USING ERRCODE='23514';END$$;
  CREATE TRIGGER fail_update BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.synthetic_failure();SET ROLE authenticated`);
  await assert.rejects(call(),e=>e.code==='23514');await db.exec('RESET ROLE');
  assert.equal((await db.query('SELECT owner_id FROM public.lounges WHERE id=1')).rows[0].owner_id,target);
  assert.equal((await db.query(`SELECT count(*)::int AS n FROM public.lounge_staff WHERE user_id='${target}'`)).rows[0].n,1);
  await db.exec('DROP TRIGGER fail_update ON public.profiles;SET ROLE authenticated');
 });
 await check('deactivation is scoped and disables the target account',async()=>{
  assert.equal((await call()).unassigned_lounges,1);await db.exec('RESET ROLE');
  const profile=(await db.query(`SELECT * FROM public.profiles WHERE id='${target}'`)).rows[0];assert.equal(profile.is_active,false);assert.equal(profile.role,'inactive');assert.equal(profile.fcm_token,null);
  assert.equal((await db.query('SELECT owner_id FROM public.lounges WHERE id=2')).rows[0].owner_id,other);
  assert.equal((await db.query(`SELECT count(*)::int AS n FROM public.lounge_staff WHERE user_id='${other}'`)).rows[0].n,1);await db.exec('SET ROLE authenticated');
 });
 await check('retry after an Auth outage is idempotent',async()=>{const r=await call();assert.equal(r.success,true);assert.equal(r.unassigned_lounges,0);});
 console.log(JSON.stringify({passed}));
}finally{await db.close();}
