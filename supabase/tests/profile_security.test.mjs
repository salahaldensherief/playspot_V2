import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {pathToFileURL} from 'node:url';
import path from 'node:path';
const runtime=process.env.PLAYSPOT_TEST_RUNTIME??path.resolve('supabase/tests/runtime');
const {PGlite}=await import(pathToFileURL(path.join(runtime,'node_modules/@electric-sql/pglite/dist/index.js')));
const db=new PGlite();const owner='00000000-0000-0000-0000-000000000001';const other='00000000-0000-0000-0000-000000000002';
await db.exec(`CREATE ROLE anon;CREATE ROLE authenticated;CREATE SCHEMA auth;
 CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql AS $$SELECT NULLIF(current_setting('test.actor',true),'')::uuid$$;
 GRANT USAGE ON SCHEMA public,auth TO authenticated,anon;
 CREATE TABLE public.profiles(id uuid primary key,full_name text,email text,phone text,avatar_url text,city_id uuid,
 latitude numeric,longitude numeric,fcm_token text,notification_preferences jsonb,updated_at timestamptz,
 role text DEFAULT 'cashier',lounge_id uuid,is_banned boolean default false,is_active boolean default true,
 is_setup_completed boolean default false,points integer default 0,referral_code text);
 ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
 GRANT ALL ON public.profiles TO anon,authenticated;
 CREATE POLICY "Allow insert profile" ON public.profiles FOR INSERT TO authenticated WITH CHECK(id=auth.uid());
 CREATE POLICY "profiles_update_policy" ON public.profiles FOR UPDATE TO authenticated USING(id=auth.uid()) WITH CHECK(id=auth.uid());
 CREATE POLICY profiles_select ON public.profiles FOR SELECT TO authenticated USING(id=auth.uid());
 INSERT INTO public.profiles(id,full_name,role,is_active) VALUES('${other}','Other','owner',false);
`);
await db.exec(await readFile(new URL('../migrations/20261001130000_profile_security_write_boundaries.sql',import.meta.url),'utf8'));
let passed=0;async function deny(name,sql,code='42501'){await assert.rejects(db.query(sql),e=>e.code===code);passed++;console.log('PASS '+name);}
await db.exec(`SET test.actor='${owner}';SET ROLE authenticated;`);
await deny('cannot create own super admin role',`INSERT INTO public.profiles(id,role) VALUES('${owner}','super_admin')`);
await deny('cannot assign lounge while creating profile',`INSERT INTO public.profiles(id,lounge_id) VALUES('${owner}','10000000-0000-0000-0000-000000000001')`);
await db.exec(`INSERT INTO public.profiles(id,full_name) VALUES('${owner}','Owner');`);passed++;console.log('PASS basic signup defaults to customer');
for(const [field,value] of [['role',"'super_admin'"],['is_active','true'],['is_setup_completed','true'],['is_banned','false'],['points','9999'],['lounge_id',"'10000000-0000-0000-0000-000000000001'"],['referral_code',"'FORGED'"]]){
 await deny('cannot directly mutate '+field,`UPDATE public.profiles SET ${field}=${value} WHERE id='${owner}'`);
}
await db.exec(`UPDATE public.profiles SET full_name='Updated',fcm_token='synthetic-token' WHERE id='${owner}'`);passed++;console.log('PASS basic profile and notification token remain writable');
assert.equal((await db.query(`UPDATE public.profiles SET full_name='Forged' WHERE id='${other}' RETURNING id`)).rows.length,0);passed++;console.log('PASS cannot edit coworker basic profile');
await deny('TRUNCATE bypass not granted','TRUNCATE public.profiles');
await deny('profile deletion not granted',`DELETE FROM public.profiles WHERE id='${owner}'`);
const first=(await db.query('SELECT public.ensure_my_referral_code() AS code')).rows[0].code;
assert.equal((await db.query('SELECT public.ensure_my_referral_code() AS code')).rows[0].code,first);passed++;console.log('PASS server referral generation replays same code');
await db.exec('RESET ROLE;SET ROLE anon');await deny('anonymous cannot write profiles',`INSERT INTO public.profiles(id) VALUES(gen_random_uuid())`);
await deny('anonymous referral execution revoked','SELECT public.ensure_my_referral_code()');
await db.exec('RESET ROLE');assert.equal((await db.query(`SELECT is_active FROM public.profiles WHERE id='${other}'`)).rows[0].is_active,false);
console.log(JSON.stringify({passed,limitations:['Synthetic profile schema and SELECT policy','No real Supabase signup trigger or concurrent clients','No live mutations']}));await db.close();
