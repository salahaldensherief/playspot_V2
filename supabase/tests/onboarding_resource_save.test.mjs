import {createFixtureDatabase} from './runtime/database.mjs';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {pathToFileURL} from 'node:url';
import path from 'node:path';
const runtime=process.env.PLAYSPOT_TEST_RUNTIME??path.resolve('supabase/tests/runtime');
const db = await createFixtureDatabase();
const owner='00000000-0000-0000-0000-000000000001',other='00000000-0000-0000-0000-000000000002';
const lounge='10000000-0000-0000-0000-000000000001',foreign='10000000-0000-0000-0000-000000000002';
const room='20000000-0000-0000-0000-000000000001',extra='30000000-0000-0000-0000-000000000001';
await db.exec(`CREATE ROLE anon;CREATE ROLE authenticated;CREATE SCHEMA auth;
 CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql AS $$SELECT NULLIF(current_setting('test.actor',true),'')::uuid$$;
 GRANT USAGE ON SCHEMA public,auth TO authenticated,anon;
 CREATE DOMAIN public.geography AS text;
 CREATE FUNCTION public.st_makepoint(double precision,double precision) RETURNS text LANGUAGE sql AS $$SELECT $1::text||','||$2::text$$;
 CREATE FUNCTION public.st_setsrid(text,integer) RETURNS text LANGUAGE sql AS $$SELECT $1$$;
 CREATE TABLE public.profiles(id uuid primary key,is_setup_completed boolean,updated_at timestamptz);
 CREATE TABLE public.brands(id uuid primary key,owner_id uuid);
 CREATE TABLE public.bookings(id uuid primary key,lounge_id uuid,status text,room_id uuid);
 CREATE TABLE public.lounges(id uuid primary key,owner_id uuid,status text,name text,name_ar text,name_en text,brand_id uuid,branch_name text,
 city text,city_id uuid,location text,opening_time time,closing_time time,image_url text,images text[],description_ar text,description_en text,
 address text,contact_phone text,location_point public.geography,vodafone_cash_number text,instapay_account text);
 CREATE TABLE public.rooms(id uuid primary key,lounge_id uuid,name text,photo_url text,images text[],features text[],is_available boolean,
 controllers_count integer,screen_size text,status text,name_ar text,name_en text,features_ar text[],features_en text[],description_ar text,
 description_en text,extra_controller_price numeric,device_type text,room_type text,hourly_rate_single numeric,hourly_rate_multi numeric,
 max_capacity integer,description text,is_active boolean,space_type_id uuid);
 CREATE TABLE public.extras(id uuid primary key,lounge_id uuid,name text,price numeric,category text,icon text,is_available boolean,name_ar text,
 name_en text,is_active boolean,stock_quantity integer,track_stock boolean,min_stock_alert integer,icon_key text,image_url text);
 INSERT INTO public.profiles VALUES('${owner}',false,now()),('${other}',false,now());
 INSERT INTO public.lounges(id,owner_id,status,name) VALUES('${lounge}','${owner}','pending','Old'),('${foreign}','${other}','pending','Foreign');
`);
await db.exec(await readFile(new URL('../review/migrations/20261001140000_idempotent_onboarding_resource_save.sql',import.meta.url),'utf8'));
await db.exec(await readFile(new URL('../review/migrations/20261001170000_onboarding_omitted_resources.sql',import.meta.url),'utf8'));
let passed=0;async function actor(id){await db.exec(`RESET ROLE;SET test.actor='${id??''}';SET ROLE authenticated;`);}
const rooms=[{id:room,name:'Room',hourly_rate_single:60,hourly_rate_multi:90,max_capacity:4,status:'available'}];
const extras=[{id:extra,name:'Snack',price:15,category:'food'}];
const data={name:'Updated',contact_phone:'01000000000',address:'Address',instapay_account:'synthetic@instapay'};
const q=(value)=>`'${JSON.stringify(value).replaceAll("'","''")}'::jsonb`;
const save=(r=rooms,e=extras,d=data)=>`SELECT public.batch_complete_onboarding('${lounge}',${q(d)},${q(r)},${q(e)})`;
async function deny(name,sql,code){await assert.rejects(db.query(sql),e=>e.code===code);passed++;console.log('PASS '+name);}
async function check(name,fn){await fn();passed++;console.log('PASS '+name);}
await actor(null);await deny('anonymous resource save',save(),'42501');
await actor(other);await deny('cross-owner resource save',save(),'42501');
await actor(owner);await deny('resources need stable IDs',save([{...rooms[0],id:null}]),'22023');
await deny('duplicate room intent rejected',save([rooms[0],rooms[0]]),'22023');
await deny('negative resource price rejected',save([{...rooms[0],hourly_rate_single:-1}]),'22023');
await deny('nonfinite resource price rejected',save([{...rooms[0],hourly_rate_multi:'NaN'}]),'22023');
await check('whole draft and resources saved',async()=>{await db.query(save());});
await check('exact retry does not duplicate resources',async()=>{
 await db.query(save());await db.exec('RESET ROLE');
 assert.equal(Number((await db.query('SELECT count(*) AS count FROM public.rooms')).rows[0].count),1);
 assert.equal(Number((await db.query('SELECT count(*) AS count FROM public.extras')).rows[0].count),1);
 assert.equal((await db.query(`SELECT is_setup_completed FROM public.profiles WHERE id='${owner}'`)).rows[0].is_setup_completed,false);
 await db.exec('SET ROLE authenticated');
});
await db.exec(`RESET ROLE;INSERT INTO public.rooms(id,lounge_id) VALUES('20000000-0000-0000-0000-000000000002','${foreign}'); SET ROLE authenticated;`);
await deny('foreign resource cannot be reassigned',save([{...rooms[0],id:'20000000-0000-0000-0000-000000000002'}]),'42501');
await db.exec(`RESET ROLE;UPDATE public.rooms SET status='maintenance',is_available=false WHERE id='${room}';SET ROLE authenticated;`);
await check('editing room pricing preserves maintenance state',async()=>{
 await db.query(save([{...rooms[0],hourly_rate_single:75}]));await db.exec('RESET ROLE');
 const row=(await db.query(`SELECT * FROM public.rooms WHERE id='${room}'`)).rows[0];assert.equal(row.status,'maintenance');assert.equal(row.is_available,false);
 await db.exec('SET ROLE authenticated');
});
await db.exec(`RESET ROLE;
 INSERT INTO public.rooms(id,lounge_id,is_active,is_available) VALUES('20000000-0000-0000-0000-000000000003','${lounge}',true,true);
 INSERT INTO public.extras(id,lounge_id,is_active,is_available) VALUES('30000000-0000-0000-0000-000000000003','${lounge}',true,true);
 INSERT INTO public.bookings VALUES('40000000-0000-0000-0000-000000000001','${lounge}','upcoming','20000000-0000-0000-0000-000000000003');SET ROLE authenticated;`);
await deny('omitted resource with future booking cannot disappear',save(),'55000');
await db.exec(`RESET ROLE;UPDATE public.bookings SET status='cancelled';SET ROLE authenticated;`);
await check('removed draft resources are retained but disabled',async()=>{
 await db.query(save([{...rooms[0],hourly_rate_single:75}]));await db.exec('RESET ROLE');
 const omittedRoom=(await db.query(`SELECT is_active,is_available FROM public.rooms WHERE id='20000000-0000-0000-0000-000000000003'`)).rows[0];
 const omittedExtra=(await db.query(`SELECT is_active,is_available FROM public.extras WHERE id='30000000-0000-0000-0000-000000000003'`)).rows[0];
 assert.deepEqual(omittedRoom,{is_active:false,is_available:false});assert.deepEqual(omittedExtra,{is_active:false,is_available:false});
 assert.equal(Number((await db.query(`SELECT count(*) AS n FROM public.rooms WHERE lounge_id='${foreign}'`)).rows[0].n),1);
 await db.exec('SET ROLE authenticated');
});
await db.exec(`RESET ROLE;CREATE FUNCTION public.fail_extra_test() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN RAISE EXCEPTION 'fixture failure';END$$;
 CREATE TRIGGER fail_extra_test BEFORE INSERT OR UPDATE ON public.extras FOR EACH ROW EXECUTE FUNCTION public.fail_extra_test();SET ROLE authenticated;`);
await deny('later extra failure rolls back lounge and room changes',save([{...rooms[0],hourly_rate_single:99}],extras,{...data,name:'Must rollback'}),'P0001');
await db.exec('RESET ROLE');
assert.equal((await db.query(`SELECT name FROM public.lounges WHERE id='${lounge}'`)).rows[0].name,'Updated');
assert.equal(Number((await db.query(`SELECT hourly_rate_single FROM public.rooms WHERE id='${room}'`)).rows[0].hourly_rate_single),75);
console.log(JSON.stringify({passed,limitations:['Synthetic schema; live triggers/RLS not mirrored','PostGIS stubbed','Single connection, no concurrency proof','No live mutations']}));await db.close();
