import {fixedSessionFixture} from './runtime/fixed_session_fixture.mjs';
import {readFile} from 'node:fs/promises';
import {randomUUID} from 'node:crypto';
import assert from 'node:assert/strict';
const f=await fixedSessionFixture();const {db,admin,lounge,actor,customer,device}=f;
let passed=0;
async function renew(venue=lounge,id=device){
 await f.login();return (await db.query('SELECT public.refresh_cashier_writer($1,$2,true) AS result',[venue,id])).rows[0].result;
}
async function check(name,body){
 await f.reset();await admin(`UPDATE private.cashier_writer_authorities SET released_at=NULL;
  INSERT INTO public.fixture_permissions VALUES('${actor}','${lounge}','bookings.view');`);await f.login();
 await db.query('SELECT public.bootstrap_offline_cashier($1,$2,true)',[lounge,device]);
 await body();passed++;console.log('PASS '+name);
}
try{
 await admin(`ALTER TABLE public.rooms ADD pricing_model text DEFAULT 'single_multi_hour';
  CREATE TABLE public.booking_holds(id uuid PRIMARY KEY,lounge_id uuid,room_id uuid,start_at timestamp,end_at timestamp,expires_at timestamptz,released_at timestamptz,user_id uuid);`);
 for(const path of ['../repairs/offline_cashier_bootstrap.sql','../migrations/20261004151006_cashier_writer_generation_handover.sql',
  '../migrations/20261009000002_cashier_writer_renewal_without_mode_change.sql'])
  await db.exec(await readFile(new URL(path,import.meta.url),'utf8'));
 await check('online renewal preserves the existing permit',async()=>{
  const before=(await db.query('SELECT public.refresh_cashier_writer($1,$2,true) AS result',[lounge,device])).rows[0].result;
  assert.equal((await renew()).permit_id,before.permit_id);
 });
 await check('stale online tab cannot reopen an offline writer',async()=>{
  await db.query('SELECT public.bootstrap_offline_cashier($1,$2,false)',[lounge,device]);
  await assert.rejects(renew(),e=>e.code==='55000'&&e.message==='CASHIER_MODE_CHANGE_REQUIRES_BOOTSTRAP');
  await admin('');assert.equal((await db.query('SELECT online_requested FROM private.cashier_writer_authorities')).rows[0].online_requested,false);
 });
 await check('explicit online bootstrap still reopens an offline writer',async()=>{
  await db.query('SELECT public.bootstrap_offline_cashier($1,$2,false)',[lounge,device]);
  const snapshot=(await db.query('SELECT public.bootstrap_offline_cashier($1,$2,true) AS result',[lounge,device])).rows[0].result;
  assert.equal(snapshot.authority.online_requested,true);
  assert.equal((await renew()).online_requested,true);
 });
 await check('network recovery renews an expired heartbeat without mode change',async()=>{
  await admin("UPDATE private.cashier_writer_authorities SET heartbeat_expires_at=clock_timestamp()-interval '1 second'");
  assert.equal((await renew()).online_requested,true);
  await admin('');assert.equal((await db.query('SELECT public.get_lounge_online_availability($1) AS available',[lounge])).rows[0].available,true);
 });
 await check('different device cannot renew or take over',async()=>{
  await assert.rejects(renew(lounge,randomUUID()),e=>e.code==='55000');
 });
 await check('different venue cannot be renewed',async()=>{
  await assert.rejects(renew(f.otherLounge),e=>e.code==='42501');
 });
 await check('banned actor cannot renew',async()=>{
  await admin(`UPDATE public.profiles SET is_banned=true WHERE id='${actor}'`);
  await assert.rejects(renew(),e=>e.code==='42501');
 });
 await check('inactive actor cannot renew',async()=>{
  await admin(`UPDATE public.profiles SET is_active=false WHERE id='${actor}'`);
  await assert.rejects(renew(),e=>e.code==='42501');
 });
 await check('missing permission cannot renew',async()=>{
  await admin(`DELETE FROM public.fixture_permissions WHERE permission='sessions_control'`);
  await assert.rejects(renew(),e=>e.code==='42501');
 });
 await check('another authenticated actor cannot renew',async()=>{
  await admin(`SET test.actor='${customer}';SET ROLE authenticated`);
  await assert.rejects(db.query('SELECT public.refresh_cashier_writer($1,$2,true)',[lounge,device]),e=>e.code==='42501');
 });
 await check('released generation cannot be reclaimed by a heartbeat',async()=>{
  await admin('UPDATE private.cashier_writer_authorities SET released_at=clock_timestamp()');
  await assert.rejects(renew(),e=>e.code==='55000');
 });
 await check('RPC grants are limited to authenticated callers',async()=>{
  await admin('');for(const role of ['anon','authenticated','service_role','supabase_auth_admin'])
   assert.equal((await db.query("SELECT has_function_privilege($1,'public.refresh_cashier_writer(uuid,uuid,boolean)','execute') AS allowed",[role])).rows[0].allowed,role==='authenticated');
 });
 await check('migration reapplication installs exactly one guard',async()=>{
  await admin('');await db.exec(await readFile(new URL('../migrations/20261009000002_cashier_writer_renewal_without_mode_change.sql',import.meta.url),'utf8'));
  const definition=(await db.query("SELECT pg_get_functiondef('public.refresh_cashier_writer(uuid,uuid,boolean)'::regprocedure) AS value")).rows[0].value;
  assert.equal(definition.split('CASHIER_MODE_CHANGE_REQUIRES_BOOTSTRAP').length,2);
 });
 await check('reviewed rollback and reapplication preserve the RPC contract',async()=>{
  await admin('');await db.exec(await readFile(new URL('../review/rollbacks/20261009000002_cashier_writer_renewal_without_mode_change.sql',import.meta.url),'utf8'));
  await f.login();await db.query('SELECT public.bootstrap_offline_cashier($1,$2,false)',[lounge,device]);
  assert.equal((await renew()).online_requested,true);
  await admin('');await db.exec(await readFile(new URL('../migrations/20261009000002_cashier_writer_renewal_without_mode_change.sql',import.meta.url),'utf8'));
  await f.login();await db.query('SELECT public.bootstrap_offline_cashier($1,$2,false)',[lounge,device]);
  await assert.rejects(renew(),e=>e.message==='CASHIER_MODE_CHANGE_REQUIRES_BOOTSTRAP');
 });
 console.log(JSON.stringify({passed}));
}finally{await db.close();}

