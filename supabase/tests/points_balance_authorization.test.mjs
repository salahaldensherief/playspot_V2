import {createFixtureDatabase} from './runtime/database.mjs';
import {readFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
const db=await createFixtureDatabase();let passed=0;
const actor='10000000-0000-0000-0000-000000000001',other='10000000-0000-0000-0000-000000000002';
const read=path=>readFile(new URL(path,import.meta.url),'utf8');
async function reset(){await db.exec(`RESET ROLE;SET test.actor='${actor}';
 DELETE FROM public.platform_super_admins;UPDATE public.profiles SET role='user',is_active=true,is_banned=false;
 INSERT INTO auth.users VALUES('${actor}') ON CONFLICT DO NOTHING;SET ROLE authenticated;`);}
async function balance(target=actor){return (await db.query('SELECT public.get_user_points_balance($1) AS balance',[target])).rows[0].balance;}
async function check(name,body){await reset();await body();passed++;console.log('PASS '+name);}
try{
 await db.exec(`CREATE ROLE anon;CREATE ROLE authenticated;CREATE SCHEMA auth;CREATE SCHEMA private;
 CREATE TABLE auth.users(id uuid PRIMARY KEY);CREATE TABLE public.profiles(id uuid PRIMARY KEY,role text,is_active boolean,is_banned boolean);
 CREATE TABLE public.platform_super_admins(user_id uuid PRIMARY KEY);
 CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql AS $$SELECT NULLIF(current_setting('test.actor',true),'')::uuid$$;
 CREATE TABLE public.points_transactions(user_id uuid,points integer);
 INSERT INTO auth.users VALUES('${actor}'),('${other}');INSERT INTO public.profiles VALUES('${actor}','user',true,false),('${other}','user',true,false);
 INSERT INTO public.points_transactions VALUES('${actor}',10),('${actor}',20),('${actor}',-5),('${other}',45);
 GRANT USAGE ON SCHEMA public,auth TO authenticated;`);
 await db.exec(await read('../repairs/active_super_admin_boundary.sql'));
 await db.exec(await read('./fixtures/hosted_points_balance_contract.sql'));
 await db.exec('GRANT EXECUTE ON FUNCTION public.get_user_points_balance(uuid) TO authenticated');
 if(!process.env.PLAYSPOT_POINTS_BASELINE)await db.exec(await read('../migrations/20261009000003_points_balance_active_account_authority.sql'));
 await check('banned super-admin cannot read another account balance',async()=>{
  await db.exec(`RESET ROLE;UPDATE public.profiles SET role='super_admin',is_banned=true WHERE id='${actor}';SET ROLE authenticated;`);
  await assert.rejects(balance(other),e=>e.code==='42501');
 });
 await check('own balance preserves the original sum',async()=>assert.equal(await balance(),25));
 await check('null target selects the authenticated actor',async()=>assert.equal(await balance(null),25));
 await check('ordinary actor cannot read another user or lounge staff balance',async()=>await assert.rejects(balance(other),e=>e.code==='42501'));
 await check('inactive own account cannot read points',async()=>{
  await db.exec(`RESET ROLE;UPDATE public.profiles SET is_active=false WHERE id='${actor}';SET ROLE authenticated;`);
  await assert.rejects(balance(),e=>e.code==='42501');
 });
 await check('orphaned Auth identity cannot use a stale role label',async()=>{
  await db.exec(`RESET ROLE;DELETE FROM auth.users WHERE id='${actor}';UPDATE public.profiles SET role='super_admin' WHERE id='${actor}';SET ROLE authenticated;`);
  await assert.rejects(balance(other),e=>e.code==='42501');
 });
 await check('canonical active platform membership authorizes another balance',async()=>{
  await db.exec(`RESET ROLE;INSERT INTO public.platform_super_admins VALUES('${actor}');SET ROLE authenticated;`);
  assert.equal(await balance(other),45);
 });
 await check('canonical superadmin alias has the same authority',async()=>{
  await db.exec(`RESET ROLE;UPDATE public.profiles SET role='superadmin' WHERE id='${actor}';SET ROLE authenticated;`);
  assert.equal(await balance(other),45);
 });
 await check('unauthenticated callers cannot read points',async()=>{
  await db.exec("RESET ROLE;SET test.actor='';SET ROLE authenticated");
  await assert.rejects(balance(other),e=>e.code==='28000');
 });
 await check('anonymous and system API roles have no execute grant',async()=>{
  await db.exec('RESET ROLE');for(const role of ['anon','service_role','supabase_auth_admin'])
   assert.equal((await db.query("SELECT has_function_privilege($1,'public.get_user_points_balance(uuid)','execute') AS allowed",[role])).rows[0].allowed,false);
 });
 console.log(JSON.stringify({passed}));
}finally{await db.close();}
