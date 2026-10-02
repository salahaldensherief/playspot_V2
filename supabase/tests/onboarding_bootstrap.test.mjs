import {createFixtureDatabase} from './runtime/database.mjs';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {pathToFileURL} from 'node:url';
import path from 'node:path';
const runtime=process.env.PLAYSPOT_TEST_RUNTIME??path.resolve('supabase/tests/runtime');
const db = await createFixtureDatabase();
const owner='00000000-0000-0000-0000-000000000001';
const stranger='00000000-0000-0000-0000-000000000002';
const lounge='10000000-0000-0000-0000-000000000001';
await db.exec(`CREATE ROLE anon;CREATE ROLE authenticated;CREATE SCHEMA auth;
 CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql AS $$ SELECT NULLIF(current_setting('test.actor',true),'')::uuid $$;
 CREATE DOMAIN public.geography AS text;
 CREATE FUNCTION public.st_makepoint(double precision,double precision) RETURNS text LANGUAGE sql AS $$ SELECT $1::text||','||$2::text $$;
 CREATE FUNCTION public.st_setsrid(text,integer) RETURNS text LANGUAGE sql AS $$ SELECT $1 $$;
 CREATE TABLE public.profiles(id uuid primary key,role text,lounge_id uuid,is_setup_completed boolean,is_active boolean,updated_at timestamptz);
 CREATE TABLE public.platform_super_admins(user_id uuid);
 CREATE TABLE public.lounges(id uuid primary key default gen_random_uuid(),owner_id uuid,name text not null,city text,location text,
 location_point public.geography,opening_time time,closing_time time,image_url text,images text[],description_ar text,description_en text,
 is_open boolean,is_active boolean,status text,vodafone_cash_number text,instapay_account text);
 ALTER TABLE public.lounges ADD CONSTRAINT lounges_at_least_one_payment_method CHECK(NULLIF(btrim(vodafone_cash_number),'') IS NOT NULL OR NULLIF(btrim(instapay_account),'') IS NOT NULL) NOT VALID;
 INSERT INTO public.profiles VALUES('${owner}','owner',NULL,false,true,now()),('${stranger}','cashier',NULL,false,true,now());
 GRANT USAGE ON SCHEMA public,auth TO authenticated,anon;
`);
await db.exec(await readFile(new URL('../review/migrations/20261001120000_onboarding_draft_bootstrap.sql',import.meta.url),'utf8'));
let passed=0;
async function actor(id){await db.exec(`RESET ROLE;SET test.actor='${id??''}';SET ROLE authenticated;`);}
async function deny(name,sql,code){await assert.rejects(db.query(sql),e=>e.code===code);passed++;console.log('PASS '+name);}
async function ok(name,fn){await fn();passed++;console.log('PASS '+name);}
const create=`SELECT public.onboard_lounge('Synthetic venue','Cairo',NULL,NULL,'Synthetic location','10:00','02:00') AS result`;
await actor(null);await deny('anonymous cannot bootstrap lounge',create,'P0001');
await actor(stranger);await deny('cashier cannot create owner lounge',create,'P0001');
await actor(owner);await deny('blank draft name',`SELECT public.onboard_lounge(' ','Cairo',NULL,NULL,'Address','10:00','02:00')`,'22023');
await deny('partial coordinates',`SELECT public.onboard_lounge('Venue','Cairo',30,NULL,'Address','10:00','02:00')`,'22023');
await deny('out-of-range coordinates',`SELECT public.onboard_lounge('Venue','Cairo',91,30,'Address','10:00','02:00')`,'22023');
let first;
await ok('pending draft can be created before payment setup',async()=>{first=(await db.query(create)).rows[0].result;assert.equal(first.status,'pending');});
await ok('retry uses same owned pending lounge',async()=>{const retry=(await db.query(create)).rows[0].result;assert.equal(retry.lounge_id,first.lounge_id);});
await db.exec('RESET ROLE');
await ok('draft creation does not suspend owner account or open lounge',async()=>{
 const profile=(await db.query(`SELECT * FROM public.profiles WHERE id='${owner}'`)).rows[0];assert.equal(profile.is_active,true);assert.equal(profile.is_setup_completed,false);
 const row=(await db.query(`SELECT * FROM public.lounges WHERE id='${first.lounge_id}'`)).rows[0];assert.equal(row.is_open,false);assert.equal(row.is_active,false);
 assert.equal(Number((await db.query('SELECT count(*) AS count FROM public.lounges')).rows[0].count),1);
});
await deny('active lounge still requires configured transfer destination',`UPDATE public.lounges SET status='active' WHERE id='${first.lounge_id}'`,'23514');
await db.exec(`UPDATE public.lounges SET owner_id='${stranger}' WHERE id='${first.lounge_id}'`);
await actor(owner);await deny('profile lounge link does not authorize modifying another owner venue',create,'42501');
await db.exec('RESET ROLE');
assert.equal((await db.query(`SELECT owner_id FROM public.lounges WHERE id='${first.lounge_id}'`)).rows[0].owner_id,stranger);
console.log(JSON.stringify({passed,limitations:['Synthetic schema','Geography functions stubbed: PostGIS behavior NOT verified','Single connection: concurrency NOT proven','No live mutations']}));
await db.close();
