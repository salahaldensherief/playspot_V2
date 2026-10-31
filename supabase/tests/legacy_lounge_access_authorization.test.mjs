import {createFixtureDatabase} from './runtime/database.mjs';
import {readFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
const db=await createFixtureDatabase();let passed=0;
const actor='10000000-0000-0000-0000-000000000001';
const lounge='20000000-0000-0000-0000-000000000001';
const foreign='20000000-0000-0000-0000-000000000002';
const read=p=>readFile(new URL(p,import.meta.url),'utf8');
async function access(id=lounge){return (await db.query('SELECT public._playspot_has_lounge_access($1) allowed',[id])).rows[0].allowed;}
async function reset(){await db.exec(`RESET ROLE;SET test.actor='${actor}'; DELETE FROM public.platform_super_admins;DELETE FROM public.lounge_staff;
 INSERT INTO auth.users VALUES('${actor}') ON CONFLICT DO NOTHING;
 UPDATE public.profiles SET role='cashier',is_active=true,is_banned=false,lounge_id='${lounge}';
 UPDATE public.lounges SET owner_id=NULL;SET ROLE authenticated;`);}
async function check(name,body){await reset();await body();passed++;console.log('PASS '+name);}
try{
 await db.exec(`CREATE ROLE anon;CREATE ROLE authenticated;CREATE SCHEMA auth;CREATE SCHEMA private;
 CREATE TABLE auth.users(id uuid PRIMARY KEY);CREATE TABLE public.profiles(id uuid PRIMARY KEY,role text,is_active boolean,is_banned boolean,lounge_id uuid);
 CREATE TABLE public.platform_super_admins(user_id uuid PRIMARY KEY);CREATE TABLE public.lounges(id uuid PRIMARY KEY,owner_id uuid);
 CREATE TABLE public.lounge_staff(lounge_id uuid,user_id uuid);
 CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql AS $$SELECT NULLIF(current_setting('test.actor',true),'')::uuid$$;
 INSERT INTO auth.users VALUES('${actor}');INSERT INTO public.profiles VALUES('${actor}','cashier',true,false,'${lounge}');
 INSERT INTO public.lounges VALUES('${lounge}',NULL),('${foreign}',NULL);
 ALTER TABLE public.lounges ENABLE ROW LEVEL SECURITY;
 CREATE POLICY staff_scope ON public.lounges FOR SELECT TO authenticated USING (true);
 GRANT USAGE ON SCHEMA public,auth TO authenticated;GRANT SELECT ON public.lounges TO authenticated;`);
 await db.exec(await read('../repairs/active_super_admin_boundary.sql'));
 await db.exec(await read('./fixtures/hosted_playspot_is_super_admin.sql'));
 await db.exec(await read('./fixtures/hosted_playspot_has_lounge_access.sql'));
 if(!process.env.PLAYSPOT_LEGACY_ACCESS_BASELINE)await db.exec(await read('../migrations/20261010120058_eligible_legacy_lounge_access.sql'));
 await db.exec('DROP POLICY staff_scope ON public.lounges;CREATE POLICY staff_scope ON public.lounges FOR SELECT TO authenticated USING(public._playspot_has_lounge_access(id))');
 await check('banned owner cannot retain direct RLS access',async()=>{
  await db.exec(`RESET ROLE;UPDATE public.lounges SET owner_id='${actor}' WHERE id='${lounge}';UPDATE public.profiles SET is_banned=true;SET ROLE authenticated`);
  assert.equal(await access(),false);assert.equal((await db.query('SELECT * FROM public.lounges')).rows.length,0);
 });
 await check('inactive owner cannot access',async()=>{await db.exec(`RESET ROLE;UPDATE public.lounges SET owner_id='${actor}';UPDATE public.profiles SET is_active=false;SET ROLE authenticated`);assert.equal(await access(),false);});
 await check('banned staff membership cannot access',async()=>{await db.exec(`RESET ROLE;INSERT INTO public.lounge_staff VALUES('${lounge}','${actor}');UPDATE public.profiles SET is_banned=true;SET ROLE authenticated`);assert.equal(await access(),false);});
 await check('banned super-admin helper returns false',async()=>{await db.exec("RESET ROLE;UPDATE public.profiles SET role='super_admin',is_banned=true;SET ROLE authenticated");assert.equal((await db.query('SELECT public._playspot_is_super_admin() allowed')).rows[0].allowed,false);});
 await check('missing Auth actor cannot use retained profile',async()=>{await db.exec(`RESET ROLE;DELETE FROM auth.users;SET ROLE authenticated`);assert.equal(await access(),false);});
 await check('NULL eligibility fails closed',async()=>{await db.exec('RESET ROLE;UPDATE public.profiles SET is_active=NULL,is_banned=NULL;SET ROLE authenticated');assert.equal(await access(),false);});
 await check('eligible scoped cashier retains own lounge only',async()=>{assert.equal(await access(),true);assert.equal(await access(foreign),false);assert.equal((await db.query('SELECT * FROM public.lounges')).rows.length,1);});
 await check('eligible owner retains access',async()=>{await db.exec(`RESET ROLE;UPDATE public.profiles SET role='user',lounge_id=NULL;UPDATE public.lounges SET owner_id='${actor}' WHERE id='${lounge}';SET ROLE authenticated`);assert.equal(await access(),true);assert.equal(await access(foreign),false);});
 await check('eligible staff retains membership scope',async()=>{await db.exec(`RESET ROLE;UPDATE public.profiles SET role='user',lounge_id=NULL;INSERT INTO public.lounge_staff VALUES('${lounge}','${actor}');SET ROLE authenticated`);assert.equal(await access(),true);assert.equal(await access(foreign),false);});
 await check('canonical active platform member retains authority',async()=>{await db.exec(`RESET ROLE;INSERT INTO public.platform_super_admins VALUES('${actor}');SET ROLE authenticated`);assert.equal(await access(foreign),true);});
 await check('no JWT actor cannot access',async()=>{await db.exec("SET test.actor=''");assert.equal(await access(),false);});
 console.log(JSON.stringify({passed}));
}finally{await db.close();}
