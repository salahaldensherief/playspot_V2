import {createFixtureDatabase} from './runtime/database.mjs';
import {lockedRace} from './runtime/locked_race.mjs';
import {readFile,writeFile} from 'node:fs/promises';
import {randomUUID} from 'node:crypto';
import assert from 'node:assert/strict';

const db=await createFixtureDatabase();
const actor=randomUUID(),customer=randomUUID(),lounge=randomUUID(),device=randomUUID(),shift=randomUUID(),booking=randomUUID();
let permit,passed=0;
const read=path=>readFile(new URL(path,import.meta.url),'utf8');
async function admin(sql) {await db.exec(`RESET ROLE;${sql}`);}
async function login() {await db.exec(`RESET ROLE;SET test.actor='${actor}';SET ROLE authenticated;`);}
function operation(sequence=1,amount=4000) {return {id:randomUUID(),actor_id:actor,lounge_id:lounge,device_id:device,
 permit_id:permit,booking_id:booking,shift_id:shift,sequence,occurred_at:new Date().toISOString(),kind:'collectCash',payload:{amount_minor:amount}};}
const request=op=>({sql:'SELECT public.apply_offline_cashier_operation($1::jsonb) AS receipt',args:[JSON.stringify(op)]});
async function send(op) {await login();const r=request(op);return (await db.query(r.sql,r.args)).rows[0].receipt;}
async function financial() {await db.exec('RESET ROLE');return (await db.query(`SELECT jsonb_build_object(
 'payments',(SELECT jsonb_agg(to_jsonb(p) ORDER BY id) FROM public.payments p),
 'cash',(SELECT jsonb_agg(to_jsonb(p) ORDER BY id) FROM public.shift_payments p),
 'financial_receipts',(SELECT count(*) FROM private.cash_collection_receipts),
 'last_sequence',(SELECT last_applied_sequence FROM private.cashier_writer_authorities)) AS value`)).rows[0].value;}
async function rejected(name,op,code) {const before=await financial();await login();const r=request(op);
 await assert.rejects(db.query(r.sql,r.args),e=>e.code===code);assert.deepEqual(await financial(),before);passed++;console.log('PASS '+name);}
async function check(name,body) {await body();passed++;console.log('PASS '+name);}
try {
 await db.exec(await read('./fixtures/partial_cash_fixture.sql'));
 await db.exec(`ALTER TABLE public.lounges ADD is_open boolean DEFAULT true;
 CREATE TABLE public.rooms(id uuid PRIMARY KEY,lounge_id uuid);
 ALTER TABLE public.bookings ADD room_id uuid,ADD date date,ADD start_time time,ADD end_time time;
 CREATE FUNCTION private.user_permission_value(uuid,uuid,text) RETURNS boolean LANGUAGE sql AS
 $$SELECT EXISTS(SELECT 1 FROM public.fixture_permissions WHERE actor=$1 AND lounge=$2 AND permission=$3)$$;
 INSERT INTO auth.users VALUES('${actor}'),('${customer}');
 INSERT INTO public.profiles VALUES('${actor}','cashier',true,false);
 INSERT INTO public.lounges(id,is_active,status) VALUES('${lounge}',true,'active');
 INSERT INTO public.fixture_permissions VALUES('${actor}','${lounge}','billing_checkout'),('${actor}','${lounge}','sessions_control');
 INSERT INTO public.shifts VALUES('${shift}','${lounge}','${actor}','${actor}','open',NULL);
 INSERT INTO public.bookings(id,user_id,lounge_id,status,total_price) VALUES('${booking}','${customer}','${lounge}','completed',100);
 GRANT USAGE ON SCHEMA public,auth TO authenticated,anon;`);
 for(const file of ['active_super_admin_boundary.sql','partial_cash_collection.sql','cashier_writer_permits.sql','cashier_writer_availability.sql','offline_cash_reconciliation.sql'])
  await db.exec(await read('../repairs/'+file));
 await login();permit=(await db.query('SELECT public.refresh_cashier_writer($1,$2,false) AS authority',[lounge,device])).rows[0].authority.permit_id;
 await check('issued writer can stay offline while submitting recorded cash',async()=>{
  assert.equal((await db.query('SELECT public.get_lounge_online_availability($1) AS available',[lounge])).rows[0].available,false);
 });
 const first=operation();
 await rejected('spoofed actor denied',{...first,actor_id:customer},'42501');
 await rejected('other device denied',{...first,device_id:randomUUID()},'42501');
 await rejected('other permit denied',{...first,permit_id:randomUUID()},'42501');
 for(const sequence of [0,-1,1.5,'1',null]) await rejected('invalid sequence '+sequence,{...first,sequence},'22023');
 await rejected('missing shift denied',{...first,shift_id:null},'22023');
 await rejected('naive time has no timezone',{...first,occurred_at:'2026-10-01T12:00:00'},'22023');
 await rejected('before permit issuance',{...first,occurred_at:'2020-01-01T00:00:00Z'},'22023');
 await rejected('future clock cannot invent events',{...first,occurred_at:new Date(Date.now()+3600000).toISOString()},'22023');
 await rejected('unknown operation preserves the queue rather than pretending success',{...first,kind:'extend'},'0A000');
 await check('sequence gap never writes money',async()=>{
  const before=await financial(),r=await send({...first,sequence:2});assert.equal(r.status,'conflict');
  assert.equal(r.code,'OFFLINE_SEQUENCE_GAP');assert.deepEqual(await financial(),before);
 });
 await check('first financial operation atomically advances sequence and exposes canonical receipt',async()=>{
  const r=await send(first);assert.equal(r.status,'applied');assert.equal(r.operation_id,first.id);
  if(process.env.PLAYSPOT_CASH_CONTRACT_EXPORT) await writeFile(process.env.PLAYSPOT_CASH_CONTRACT_EXPORT,
   JSON.stringify({operation:first,response:r},null,2)+'\n','utf8');
  assert.equal(r.financial_receipt.paid_minor,4000);assert.equal(r.financial_receipt.due_minor,6000);
  assert.equal((await financial()).last_sequence,1);
 });
 await check('server response lost then retried does not repeat money or sequence',async()=>{
  const before=await financial(),r=await send(first);assert.equal(r.status,'replayed');assert.deepEqual(await financial(),before);
 });
 await rejected('same id altered payload fails closed',{...first,payload:{amount_minor:4001}},'22023');
 await admin(`UPDATE public.profiles SET is_banned=true WHERE id='${actor}'`);
 await rejected('banned actor cannot replay a synchronized receipt',first,'42501');
 await admin(`UPDATE public.profiles SET is_banned=false WHERE id='${actor}'`);
 const second=operation(2,6000);
 if(db.connect) {
  await check('simultaneous envelope requests share one writer and one financial receipt',async()=>{
   await admin('');const [a,b]=await lockedRace(db,request(second),request(second),actor);
   assert.equal(a.rows[0].receipt.status,'applied');assert.equal(b.error,undefined);assert.equal(b.value.rows[0].receipt.status,'replayed');
   const s=await financial();assert.equal(s.last_sequence,2);assert.equal(s.financial_receipts,2);
   assert.equal(s.cash.reduce((sum,p)=>sum+Number(p.amount),0),100);
  });
 } else await check('second envelope completes cash balance',async()=>assert.equal((await send(second)).status,'applied'));
 const conflict=operation(3,1);
 await check('business conflict persists but rolls back every financial side effect',async()=>{
  const before=await financial(),r=await send(conflict);assert.equal(r.status,'conflict');
  assert.equal(r.code,'CASH_EXCEEDS_OUTSTANDING_BALANCE');assert.deepEqual(await financial(),before);
 });
 await check('same conflict returns its original receipt for explicit review',async()=>{
  assert.equal((await send(conflict)).code,'CASH_EXCEEDS_OUTSTANDING_BALANCE');
 });
 await check('replacement operation cannot silently bypass a conflicted sequence',async()=>{
  const before=await financial();assert.equal((await send(operation(3,1))).code,'OFFLINE_SEQUENCE_BLOCKED');
  assert.deepEqual(await financial(),before);
 });
 await check('dependent later operation stays blocked',async()=>assert.equal((await send(operation(4,1))).code,'OFFLINE_SEQUENCE_GAP'));
 await login();await check('operation receipts cannot be edited by client',async()=>{
  await assert.rejects(db.query('DELETE FROM private.cashier_operation_receipts'),e=>e.code==='42501');
 });
 console.log(JSON.stringify({passed,limitations:['This fixture covers cash; item orders have a separate native fixture','Minimal cash fixture does not load separate fixed-session handlers','No UI enablement or production writes','Minimal schema; audit/Auth session revocation not mirrored','Conflicts require a separate reviewed resolution flow']}));
} finally {await db.close();}
