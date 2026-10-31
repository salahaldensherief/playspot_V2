import {fixedSessionFixture} from './runtime/fixed_session_fixture.mjs';
import {installLatestFunctions} from './runtime/latest_contracts.mjs';
import {readFile} from 'node:fs/promises';
import {randomUUID} from 'node:crypto';
import assert from 'node:assert/strict';
const f=await fixedSessionFixture();const {db,admin,lounge,actor,device,shift}=f;
let passed=0;
try {
 await admin(`ALTER TABLE lounges ADD COLUMN IF NOT EXISTS is_open boolean DEFAULT true;
  ALTER TABLE rooms ADD pricing_model text DEFAULT 'single_multi_hour';
  CREATE TABLE booking_holds(id uuid PRIMARY KEY,lounge_id uuid,room_id uuid,start_at timestamp,end_at timestamp,expires_at timestamptz,released_at timestamptz,user_id uuid);
 `);
 for(const path of ['../repairs/offline_cashier_bootstrap.sql','../migrations/20261004151006_cashier_writer_generation_handover.sql','../migrations/20261009000002_cashier_writer_renewal_without_mode_change.sql']) await db.exec(await readFile(new URL(path,import.meta.url),'utf8'));
 await installLatestFunctions(db,['public.refresh_cashier_writer','public.get_lounge_online_availability']);
 async function reset(){await f.reset();await admin(`UPDATE private.cashier_writer_authorities SET released_at=NULL;
   INSERT INTO public.fixture_permissions VALUES('${actor}','${lounge}','bookings.view');`);await f.login();await db.query('SELECT bootstrap_offline_cashier($1,$2,true)',[lounge,device]);}
 async function check(name,body){await reset();await body();passed++;console.log('PASS '+name);}
 const online=async()=>(await db.query('SELECT get_lounge_online_availability($1) ok',[lounge])).rows[0].ok;
 const refresh=()=>db.query('SELECT refresh_cashier_writer($1,$2,true)',[lounge,device]);
 await check('online selection without live heartbeat never proves connectivity',async()=>{
   assert.equal(await online(),true);await admin("UPDATE private.cashier_writer_authorities SET heartbeat_expires_at=clock_timestamp()-interval '1 second'");
   assert.equal(await online(),false);await f.login();await refresh();assert.equal(await online(),true);
 });
 await check('offline mode stays unavailable even with a heartbeat',async()=>{
   await db.query('SELECT bootstrap_offline_cashier($1,$2,false)',[lounge,device]);
   await admin("UPDATE private.cashier_writer_authorities SET heartbeat_expires_at=clock_timestamp()+interval '1 hour'");assert.equal(await online(),false);
 });
 await check('expired permit cannot implicitly retire queued work or admit another writer',async()=>{
   await admin("UPDATE private.cashier_writer_authorities SET permit_expires_at=clock_timestamp()-interval '1 second'");assert.equal(await online(),false);await f.login();
   await assert.rejects(db.query('SELECT bootstrap_offline_cashier($1,$2,true)',[lounge,randomUUID()]),e=>e.code==='55000');
 });
 await check('closed shift does not implicitly release a generation',async()=>{
   await admin(`UPDATE public.shifts SET status='closed',closed_at=clock_timestamp() WHERE id='${shift}'`);await f.login();
   await assert.rejects(db.query('SELECT refresh_cashier_writer($1,$2,true)',[lounge,randomUUID()]),e=>e.code==='55000');
   await admin('');assert.equal((await db.query('SELECT released_at FROM private.cashier_writer_authorities')).rows[0].released_at,null);
 });
 await check('revoked permissions and banned identity immediately remove availability',async()=>{
   await admin("DELETE FROM public.fixture_permissions WHERE permission='sessions_control'");assert.equal(await online(),false);
   await admin(`INSERT INTO public.fixture_permissions VALUES('${actor}','${lounge}','sessions_control');UPDATE public.profiles SET is_banned=true WHERE id='${actor}'`);
   assert.equal(await online(),false);await f.login();await assert.rejects(refresh(),e=>e.code==='42501');
 });
 await check('stale heartbeat cannot switch an offline writer back online',async()=>{
   await db.query('SELECT bootstrap_offline_cashier($1,$2,false)',[lounge,device]);
   await assert.rejects(refresh(),e=>e.code==='55000'&&e.message==='CASHIER_MODE_CHANGE_REQUIRES_BOOTSTRAP');
 });
 console.log(JSON.stringify({passed}));
}finally{await db.close();}
