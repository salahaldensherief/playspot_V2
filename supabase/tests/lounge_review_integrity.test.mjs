import {createFixtureDatabase} from './runtime/database.mjs';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';
import path from 'node:path';

const runtime = process.env.PLAYSPOT_TEST_RUNTIME ?? path.resolve('supabase/tests/runtime');
const db = await createFixtureDatabase();
const owner = '00000000-0000-0000-0000-000000000001';
const stranger = '00000000-0000-0000-0000-000000000002';
const admin = '00000000-0000-0000-0000-000000000003';
const lounge = '10000000-0000-0000-0000-000000000001';
const other = '10000000-0000-0000-0000-000000000002';
let passed = 0;
await db.exec(`
 CREATE ROLE anon; CREATE ROLE authenticated; CREATE SCHEMA auth; CREATE SCHEMA storage;
 CREATE TABLE auth.users(id uuid primary key);
 INSERT INTO auth.users VALUES('${owner}'),('${stranger}'),('${admin}');
 CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql AS $$ SELECT NULLIF(current_setting('test.actor',true),'')::uuid $$;
 CREATE FUNCTION public.is_super_admin() RETURNS boolean LANGUAGE sql AS $$ SELECT auth.uid()='${admin}'::uuid $$;
 CREATE TABLE public.lounges(id uuid primary key, owner_id uuid,name text,city text,address text,contact_phone text,
  opening_time time,closing_time time,location_point text,status text,is_active boolean,is_open boolean);
 CREATE TABLE public.rooms(id uuid primary key,lounge_id uuid,is_active boolean);
 CREATE TABLE public.extras(id uuid primary key,lounge_id uuid);
 CREATE TABLE storage.objects(bucket_id text,name text);
 CREATE TABLE public.profiles(id uuid primary key,lounge_id uuid,is_active boolean,is_setup_completed boolean,updated_at timestamptz);
 CREATE TABLE public.notifications(user_id uuid,title text,title_ar text,title_en text,body text,body_ar text,body_en text,type text,metadata jsonb);
 INSERT INTO public.profiles VALUES('${owner}','${lounge}',false,false,now());
 ALTER TABLE public.profiles ADD COLUMN full_name text, ADD COLUMN email text;
 UPDATE public.profiles SET full_name='Synthetic Owner',email='owner@example.invalid';
 INSERT INTO public.lounges VALUES('${lounge}','${owner}','Synthetic lounge','Cairo','Synthetic address','01000000000',
  '10:00','02:00','synthetic point','pending',false,false),
  ('${other}','${owner}','Other lounge','Cairo','Other address','01000000001','10:00','02:00','synthetic point','pending',false,false);
 INSERT INTO public.rooms VALUES('20000000-0000-0000-0000-000000000001','${lounge}',true);
 INSERT INTO storage.objects VALUES('kyc-documents','${owner}/id.png');
 GRANT USAGE ON SCHEMA public,auth TO authenticated,anon;
`);
await db.exec(await readFile(new URL('../migrations/20261001110000_versioned_lounge_review.sql', import.meta.url), 'utf8'));
await db.exec(`ALTER TABLE public.lounges ADD COLUMN vodafone_cash_number text, ADD COLUMN instapay_account text; UPDATE public.lounges SET instapay_account='synthetic@instapay';`);
await db.exec(await readFile(new URL('../migrations/20261001150000_finalize_review_submission.sql', import.meta.url), 'utf8'));
async function actor(id) { await db.exec(`RESET ROLE; SET test.actor='${id ?? ''}'; SET ROLE authenticated;`); }
async function deny(name, sql, code) {
 await assert.rejects(db.query(sql), error => error.code === code);
 passed++; console.log(`PASS ${name}`);
}
async function ok(name, action) { await action(); passed++; console.log(`PASS ${name}`); }
const submit = `SELECT public.submit_lounge_review('${lounge}','${owner}/id.png') AS result`;
await actor(null);
await deny('anonymous submission', submit, '28000');
await actor(stranger);
await deny('cross-owner submission', submit, '42501');
await deny('ordinary user cannot list sensitive reviews', 'SELECT public.get_lounge_review_requests()', '42501');
await actor(owner);
await deny('missing uploaded object', `SELECT public.submit_lounge_review('${lounge}','${owner}/missing.png')`, '22023');
await deny('foreign document path', `SELECT public.submit_lounge_review('${lounge}','${stranger}/id.png')`, '22023');
let request;
await db.exec(`RESET ROLE; UPDATE public.lounges SET instapay_account=NULL WHERE id='${lounge}'; SET ROLE authenticated;`);
await deny('review requires payment destination', submit, '22023');
await db.exec(`RESET ROLE; UPDATE public.lounges SET instapay_account='synthetic@instapay' WHERE id='${lounge}'; SET ROLE authenticated;`);
await ok('complete lounge submitted as immutable revision', async () => {
 request = (await db.query(submit)).rows[0].result;
 assert.equal(request.revision,1); assert.equal(request.status,'pending');
});
await ok('only final accepted submission completes setup without activating venue',async()=>{
 await db.exec('RESET ROLE');
 const row=(await db.query(`SELECT p.is_setup_completed,p.is_active,l.status,l.is_open FROM public.profiles p JOIN public.lounges l ON l.id=p.lounge_id WHERE p.id='${owner}'`)).rows[0];
 assert.equal(row.is_setup_completed,true);assert.equal(row.is_active,false);
 assert.equal(row.status,'pending');assert.equal(row.is_open,false);
 await db.exec('SET ROLE authenticated');
});
await ok('same submission replay does not create a second request', async () => {
 const result = (await db.query(submit)).rows[0].result;
 assert.equal(result.request_id,request.request_id); assert.equal(result.idempotent,true);
});
await deny('owner cannot approve', `SELECT public.review_lounge_request('${request.request_id}',1,true)`, '42501');
await actor(admin);
await deny('wrong review revision', `SELECT public.review_lounge_request('${request.request_id}',2,true)`, '55000');
await deny('NULL approval cannot become rejection', `SELECT public.review_lounge_request('${request.request_id}',1,NULL)`, '22023');
await deny('rejection requires useful reason', `SELECT public.review_lounge_request('${request.request_id}',1,false,' ')`, '22023');
await ok('admin receives full frozen data and stored document paths', async () => {
 const list=(await db.query('SELECT public.get_lounge_review_requests() AS result')).rows[0].result;
 assert.equal(list.length,1); assert.equal(list[0].snapshot.lounge.address,'Synthetic address');
 assert.equal(list[0].snapshot.rooms.length,1); assert.equal(list[0].id_document_path,`${owner}/id.png`);
});
await db.exec('RESET ROLE');
await deny('pending lounge fields cannot change underneath reviewer', `UPDATE public.lounges SET address='Changed' WHERE id='${lounge}'`, '55000');
await deny('pending room list cannot acquire a new row', `INSERT INTO public.rooms VALUES('20000000-0000-0000-0000-000000000002','${lounge}',true)`, '55000');
await db.exec(`UPDATE private.lounge_review_requests SET snapshot=jsonb_set(snapshot,'{lounge,address}','"Old snapshot"') WHERE id='${request.request_id}'; SET ROLE authenticated;`);
await deny('approval cannot silently approve data changed after submission', `SELECT public.review_lounge_request('${request.request_id}',1,true)`, '55000');
await db.exec(`RESET ROLE; UPDATE private.lounge_review_requests SET snapshot=jsonb_set(snapshot,'{lounge,address}','"Synthetic address"') WHERE id='${request.request_id}'; SET ROLE authenticated;`);
await ok('approval is scoped to exact lounge', async () => {
 await db.query(`SELECT public.review_lounge_request('${request.request_id}',1,true)`);
 await db.exec('RESET ROLE');
 const rows=(await db.query('SELECT id,status,is_open FROM public.lounges ORDER BY id')).rows;
 assert.equal(rows[0].status,'active'); assert.equal(rows[0].is_open,false);
 assert.equal(rows[1].status,'pending'); assert.equal(rows[1].is_open,false);
 assert.equal((await db.query(`SELECT is_active FROM public.profiles WHERE id='${owner}'`)).rows[0].is_active,true);
 await db.exec('SET ROLE authenticated');
});
await ok('decision replay is stable',async()=>{
 const result=(await db.query(`SELECT public.review_lounge_request('${request.request_id}',1,true) AS result`)).rows[0].result;
 assert.equal(result.idempotent,true);
});
await deny('conflicting second decision', `SELECT public.review_lounge_request('${request.request_id}',1,false,'Changed mind')`, '55000');
await actor(owner);
await deny('clients cannot write private decision table', `UPDATE private.lounge_review_requests SET status='approved'`, '42501');
await db.exec('RESET ROLE');
await ok('replayed decision emits only one durable notification',async()=>{
 assert.equal(Number((await db.query('SELECT count(*) AS count FROM public.notifications')).rows[0].count),1);
});
console.log(JSON.stringify({passed,engine:(await db.query('SELECT version()')).rows[0],limitations:['Synthetic schema; live triggers and PostGIS not mirrored','Single connection, concurrency not proven','No live mutations']}));
await db.close();
