// Synthetic local full reversal and blind shift close; never an external refund.
import {readFile,writeFile} from 'node:fs/promises';
import {randomUUID} from 'node:crypto';
import {createRequire} from 'node:module';
import assert from 'node:assert/strict';
const require=createRequire(new URL('../../supabase/tests/runtime/package.json',import.meta.url));
const {Client}=require('pg');
const [directory,report]=process.argv.slice(2);
const load=async name=>JSON.parse(await readFile(directory+'/'+name,'utf8'));
const status=await load('status.json'),accounts=await load('accounts.json'),journey=await load('journey-state.json');
const base=status.API_URL;assert.ok(['http://127.0.0.1:56621','http://127.0.0.1:56821'].includes(base));
const url=new URL(status.DB_URL);assert.equal(url.hostname,'127.0.0.1');assert.equal(url.port,String(new URL(status.API_URL).port === '56821' ? 56822 : 56622));
let state;try{state=await load('full-refund-state.json');}catch(e){if(e.code!=='ENOENT')throw e;state={initiate:randomUUID(),execute:randomUUID()};}
const save=()=>writeFile(directory+'/full-refund-state.json',JSON.stringify(state,null,2),{mode:0o600});await save();
async function request(path,token,body,method='POST'){
 const r=await fetch(base+path,{method,redirect:'error',headers:{apikey:status.ANON_KEY,Authorization:'Bearer '+token,'Content-Type':'application/json'},body:body===undefined?undefined:JSON.stringify(body),signal:AbortSignal.timeout(15000)});
 const result=await r.json();if(!r.ok)throw Object.assign(new Error(result.message),{code:result.code,http:r.status});return result;
}
const tokens={};for(const a of accounts)tokens[a.persona]=(await request('/auth/v1/token?grant_type=password',status.ANON_KEY,{email:a.email,password:a.password})).access_token;
const rpc=(actor,name,body)=>request('/rest/v1/rpc/'+name,tokens[actor],body);
const booking=journey.booking.primary_booking_id;
await assert.rejects(request('/rest/v1/audit_events',tokens.cashier,{entity_type:'payment',entity_id:booking,event_code:'payment_refunded'}),e=>e.code==='42501');
state.request=await rpc('owner','initiate_booking_refund',{p_booking_id:booking,p_collection_movement_id:journey.receipt.movement_id,p_refund_amount_minor:8000,p_reason:'LOCAL SYNTHETIC remaining return; no external money',p_operation_id:state.initiate,p_policy_override:true});await save();
const args={p_refund_request_id:state.request.refund_request_id,p_return_payment_method:'cash',p_evidence_reference:'LOCAL-SYNTHETIC-FULL-RETURN-NO-EXTERNAL-MONEY',p_operation_id:state.execute,p_shift_id:journey.shift.id};
state.receipt=await rpc('cashier','execute_booking_refund',args);await save();
assert.equal(state.receipt.total_refunded_minor,10000);assert.equal(state.receipt.net_collected_minor,0);assert.equal(state.receipt.payment_status,'refunded');
const replay=await rpc('cashier','execute_booking_refund',args);assert.equal(replay.replayed,true);assert.equal(replay.refund_movement_id,state.receipt.refund_movement_id);
if(!state.closed){
 const cashier=accounts.find(a=>a.persona==='cashier').id;
 const close={p_shift_id:journey.shift.id,p_cashier_id:cashier,p_counted_cash:0,p_notes:'LOCAL synthetic collection minus full return = zero drawer'};
 if(!state.closePermissionGranted){
   await assert.rejects(rpc('cashier','blind_close_shift',close),e=>e.code==='42501');
   state.closePermissionDenied=true;
   const granted=await rpc('owner','set_staff_permission',{p_lounge_id:journey.shift.lounge_id,p_target_user_id:cashier,p_permission_key:'shifts_blind_close',p_is_enabled:true});
   assert.equal(granted.success,true);state.closePermissionGranted=true;await save();
 }
 state.closed=await rpc('cashier','blind_close_shift',close);await save();
}
const c=new Client({connectionString:status.DB_URL});await c.connect();
try {
 await c.query('BEGIN READ ONLY');
 const row=(await c.query(`SELECT
   (SELECT sum(amount_minor) FROM private.booking_money_movements WHERE booking_id=$1) AS signed_minor,
   (SELECT sum(commission_minor) FROM private.booking_money_movements WHERE booking_id=$1) AS commission_minor,
   (SELECT amount*100 FROM public.payments WHERE booking_id=$1) AS payment_minor,
   (SELECT sum(amount)*100 FROM public.shift_payments WHERE booking_id=$1) AS drawer_in_minor,
   (SELECT sum(e.amount)*100 FROM public.shift_expenses e JOIN private.booking_refund_requests r ON r.shift_expense_id=e.id WHERE r.booking_id=$1) AS drawer_out_minor,
   (SELECT count(*) FROM private.booking_money_movements WHERE booking_id=$1 AND amount_minor<0) AS reversals,
   (SELECT count(*) FROM public.audit_events WHERE booking_id=$1) AS audit_events,
   (SELECT status FROM public.shifts WHERE id=$2) AS shift_status`,[booking,journey.shift.id])).rows[0];
 const actual=Object.fromEntries(Object.entries(row).map(([k,v])=>[k,k==='shift_status'?v:Number(v)]));
 assert.deepEqual(actual,{signed_minor:0,commission_minor:0,payment_minor:0,drawer_in_minor:10000,drawer_out_minor:10000,reversals:2,audit_events:4,shift_status:'closed'});
 await c.query('COMMIT');
 await writeFile(report,JSON.stringify({environment:base,evidence:'Real local Auth/PostgREST refund and blind-close RPCs plus independent read-only ledger reconciliation',booking,receipt:state.receipt,closed:state.closed,actual,replay:true,directAuditForgeryDenied:true,limitation:'Synthetic return attestations; no external money, hosted compatibility or complete UI acceptance'},null,2));
 console.log('Local full reversal, replay, audit forgery denial, blind shift close and zero-net reconciliation passed.');
} finally {await c.end();}
