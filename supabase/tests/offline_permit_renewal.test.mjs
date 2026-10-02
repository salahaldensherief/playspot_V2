import {fixedSessionFixture} from './runtime/fixed_session_fixture.mjs';
import {lockedRace} from './runtime/locked_race.mjs';
import {randomUUID} from 'node:crypto';
import {writeFile} from 'node:fs/promises';
import assert from 'node:assert/strict';

const f=await fixedSessionFixture();let passed=0;
const {db,actor,customer,lounge,device,booking,start,admin,login,reset,operation,send,snapshot}=f;
const at=ms=>new Date(ms).toISOString();
async function check(name,body){await reset();await body();passed++;console.log('PASS '+name);}
async function refresh(online=false){await login();return (await db.query('SELECT public.refresh_cashier_writer($1,$2,$3) AS grant',[lounge,device,online])).rows[0].grant;}
async function grant(id){await admin('');return (await db.query('SELECT to_jsonb(p) AS value FROM private.cashier_writer_permits p WHERE permit_id=$1',[id])).rows[0]?.value;}
async function denied(op,code,message){const before=await snapshot();await login();await assert.rejects(
 db.query('SELECT public.apply_offline_cashier_operation($1::jsonb)',[JSON.stringify(op)]),e=>e.code===code&&(!message||e.message===message));
 assert.deepEqual(await snapshot(),before);}
function reserveAt(permit,time,sequence=1){return operation('reserve',sequence,{permit_id:permit,occurred_at:at(time),
 payload:{...operation().payload,start_ms:time,end_ms:time+3600000}});}
function transition(kind,sequence,permit,reserved,offset){const op=operation(kind,sequence,{permit_id:permit,
 occurred_at:at(reserved.payload.start_ms+offset)});op.quoted_session={...reserved.quoted_session,started_ms:reserved.payload.start_ms+60000};return op;}
const expiredIssued=Math.floor(Date.now()/60000)*60000-48*3600000;
try {
 await check('heartbeat refresh never extends a live immutable permit',async()=>{
  const old=await grant(f.permit),r=await refresh(true);assert.equal(r.protocol_version,2);assert.equal(r.permit_id,old.permit_id);
  assert.equal(r.issued_ms,Date.parse(old.issued_at));assert.equal(r.expires_ms,Date.parse(old.expires_at));
  assert.deepEqual(await grant(old.permit_id),old);assert.equal(r.online_requested,true);
 });
 await check('expired permit rotates identity without modifying its original window or sequence',async()=>{
  const oldId=await f.issuePermit(expiredIssued),old=await grant(oldId),r=await refresh();
  assert.notEqual(r.permit_id,oldId);assert.equal(r.expires_ms-r.issued_ms,86400000);
  assert.equal(r.last_applied_sequence,0);assert.deepEqual(await grant(oldId),old);
  assert.equal(Date.parse((await grant(r.permit_id)).issued_at),r.issued_ms);
 });
 await check('expired permit cannot advertise online even with a fresh heartbeat',async()=>{
  await f.issuePermit(expiredIssued);await admin('UPDATE private.cashier_writer_authorities SET online_requested=true,heartbeat_expires_at=now()+interval \'90 seconds\'');
  await login();assert.equal((await db.query('SELECT public.get_lounge_online_availability($1) AS online',[lounge])).rows[0].online,false);
  await refresh(true);await login();assert.equal((await db.query('SELECT public.get_lounge_online_availability($1) AS online',[lounge])).rows[0].online,true);
 });
 await check('legitimate old reservation/start/close reconcile after renewal under their original permit',async()=>{
  const oldId=await f.issuePermit(expiredIssued),reserved=reserveAt(oldId,expiredIssued+3600000);const renewed=await refresh();
  assert.equal((await send(reserved)).status,'applied');
  assert.equal((await send(transition('start',2,oldId,reserved,60000))).status,'applied');
  assert.equal((await send(transition('close',3,oldId,reserved,600000))).status,'applied');
  await admin('');const rows=(await db.query('SELECT permit_id FROM private.cashier_operation_receipts ORDER BY sequence')).rows;
  assert.equal(rows.length,3);assert.ok(rows.every(r=>r.permit_id===oldId));assert.notEqual(renewed.permit_id,oldId);
 });
 await check('old event outside its original expiry remains denied after renewal',async()=>{
  const oldId=await f.issuePermit(expiredIssued);await refresh();
  await denied(reserveAt(oldId,start),'22023','OFFLINE_OPERATION_OUTSIDE_PERMIT');
 });
 await check('new permit cannot backdate an event before its issuance',async()=>{
  await f.issuePermit(expiredIssued);const renewed=await refresh();
  await denied(reserveAt(renewed.permit_id,start),'22023','OFFLINE_OPERATION_OUTSIDE_PERMIT');
 });
 await check('permission changes issue a new immutable snapshot and leave old grants intact',async()=>{
  const old=await grant(f.permit);await admin("DELETE FROM public.fixture_permissions WHERE permission='bookings.manage'");
  const revised=await refresh();assert.notEqual(revised.permit_id,old.permit_id);assert.equal(revised.permissions['bookings.manage'],false);
  assert.deepEqual(await grant(old.permit_id),old);
  await denied(reserveAt(old.permit_id,start),'42501','OFFLINE_SESSION_PERMISSION_DENIED');
 });
 await check('newly granted billing permission cannot authorize cash recorded under an older unissued billing grant',async()=>{
  const oldId=await f.issuePermit(start-3600000,{'bookings.manage':true,sessions_control:true,billing_checkout:false});
  const reserved=reserveAt(oldId,start);await refresh();await send(reserved);await send(transition('start',2,oldId,reserved,60000));
  await denied(operation('collectCash',3,{permit_id:oldId,occurred_at:at(start+120000),payload:{amount_minor:5000}}),
   '42501','OFFLINE_PERMISSION_NOT_ISSUED');
 });
 await check('conflicting old sequence cannot be bypassed using a renewed permit',async()=>{
  const oldId=await f.issuePermit(expiredIssued),old=reserveAt(oldId,expiredIssued+3600000);old.quoted_total_minor=1;
  assert.equal((await send(old)).status,'conflict');const revised=await refresh();
  const event=Math.ceil(revised.issued_ms/60000)*60000;
  const next=reserveAt(revised.permit_id,event);next.occurred_at=at(revised.server_time_ms);
  const before=await snapshot();const result=await send(next);assert.equal(result.code,'OFFLINE_SEQUENCE_BLOCKED');assert.deepEqual(await snapshot(),before);
 });
 await check('lost old response retries after renewal without creating another booking',async()=>{
  const oldId=await f.issuePermit(expiredIssued),op=reserveAt(oldId,expiredIssued+3600000);await send(op);await refresh();
  const before=await snapshot();assert.equal((await send(op)).status,'replayed');assert.deepEqual(await snapshot(),before);
 });
 await check('next sequence under new permit follows old events without resetting the writer counter',async()=>{
  const oldId=await f.issuePermit(expiredIssued);await send(reserveAt(oldId,expiredIssued+3600000));const renewed=await refresh();
  assert.equal(renewed.last_applied_sequence,1);const now=Math.ceil(renewed.server_time_ms/60000)*60000;
  const next=reserveAt(renewed.permit_id,now,2);next.booking_id=randomUUID();next.occurred_at=at(renewed.server_time_ms);
  assert.equal((await send(next)).status,'applied');assert.equal((await snapshot()).sequence,2);
 });
 await check('banned actor cannot replay a historical receipt after renewal',async()=>{
  const oldId=await f.issuePermit(expiredIssued),op=reserveAt(oldId,expiredIssued+3600000);await send(op);await refresh();
  await admin(`UPDATE public.profiles SET is_banned=true WHERE id='${actor}'`);await denied(op,'42501');
 });
 await check('a historical permit of a different identity cannot use the current writer',async()=>{
  const id=randomUUID();await admin(`INSERT INTO private.cashier_writer_permits VALUES('${id}','${lounge}','${customer}','${device}',
   to_timestamp(${start-3600000}/1000.0),to_timestamp(${start+82800000}/1000.0),'{"bookings.manage":true,"sessions_control":true,"billing_checkout":true}')`);
  await denied(reserveAt(id,start),'42501','OFFLINE_WRITER_MISMATCH');
 });
 await check('a different device cannot claim an expired assignment',async()=>{
  await f.issuePermit(expiredIssued);await login();await assert.rejects(
   db.query('SELECT public.refresh_cashier_writer($1,$2,false)',[lounge,randomUUID()]),e=>e.code==='55000');
 });
 for(const sql of ['SELECT * FROM private.cashier_writer_permits','UPDATE private.cashier_writer_permits SET expires_at=now()',
  'DELETE FROM private.cashier_writer_permits',"INSERT INTO private.cashier_writer_permits DEFAULT VALUES"])
  await check('client cannot access immutable grant records: '+sql.split(' ')[0],async()=>{
   await login();await assert.rejects(db.query(sql),e=>e.code==='42501');
  });
 for(const sql of ['UPDATE private.cashier_writer_permits SET expires_at=expires_at+interval \'1 second\'',
  'DELETE FROM private.cashier_writer_permits']) await check('even privileged accidental mutation is rejected: '+sql.split(' ')[0],async()=>{
   const before=await grant(f.permit);await admin('');await assert.rejects(db.query(sql),e=>e.code==='55000'&&e.message==='CASHIER_PERMITS_ARE_IMMUTABLE');
   assert.deepEqual(await grant(f.permit),before);
  });
 await check('legacy or corrupted writer grant is not silently replaced',async()=>{
  await admin('UPDATE private.cashier_writer_authorities SET permit_id=gen_random_uuid()');await login();
  await assert.rejects(db.query('SELECT public.refresh_cashier_writer($1,$2,false)',[lounge,device]),
   e=>e.code==='55000'&&e.message==='CASHIER_PERMIT_RECORD_MISSING_OR_CHANGED');
 });
 if(db.connect) await check('simultaneous renewal waits and issues exactly one current generation',async()=>{
  const oldId=await f.issuePermit(expiredIssued);await admin('');
  const query={sql:'SELECT public.refresh_cashier_writer($1,$2,false) AS grant',args:[lounge,device]};
  const [a,b]=await lockedRace(db,query,query,actor);assert.equal(b.error,undefined);
  assert.equal(a.rows[0].grant.permit_id,b.value.rows[0].grant.permit_id);assert.notEqual(a.rows[0].grant.permit_id,oldId);
 });
 if(db.connect) for(const reserveFirst of [true,false]) await check(
  reserveFirst ? 'writer refresh waits for atomic offline reservation' : 'offline reservation waits for writer refresh',async()=>{
   const op=operation(),reserve=f.request(op),heartbeat={
    sql:'SELECT public.refresh_cashier_writer($1,$2,false) AS grant',args:[lounge,device]};
   const [a,b]=await lockedRace(db,reserveFirst?reserve:heartbeat,reserveFirst?heartbeat:reserve,actor);
   assert.equal(b.error,undefined);
   const receipt=reserveFirst?a.rows[0].receipt:b.value.rows[0].receipt;
   assert.equal(receipt.status,'applied');
   const persisted=await snapshot();assert.equal(persisted.sequence,1);
   assert.equal(persisted.bookings.some(value=>value.id===op.booking_id),true);
  });
 await check('native authority wire fixture includes original and renewed generations with a queued old event',async()=>{
  const oldId=await f.issuePermit(expiredIssued),old=await grant(oldId),pending=reserveAt(oldId,expiredIssued+3600000),current=await refresh();
  if(process.env.PLAYSPOT_PERMIT_CONTRACT_EXPORT) await writeFile(process.env.PLAYSPOT_PERMIT_CONTRACT_EXPORT,
   JSON.stringify({current,previous:{...current,permit_id:oldId,issued_ms:Date.parse(old.issued_at),expires_ms:Date.parse(old.expires_at),
    server_time_ms:Date.parse(old.issued_at)+3600000,heartbeat_expires_at:at(Date.parse(old.issued_at)+3600000)},pending},null,2)+'\n','utf8');
 });
 console.log(JSON.stringify({passed,limitations:['Native synthetic Auth/schema; no hosted writes','Immutable timing is not hardware or event-time attestation',
  'Cross-device reassignment and closed-shift reconciliation remain explicit review work','Canonical resource bootstrap/UI still incomplete']}));
} finally {await db.close();}
