// Synthetic return attestation only: no bank, wallet or physical cash movement.
import {readFile,writeFile} from 'node:fs/promises';
import {randomUUID} from 'node:crypto';
import assert from 'node:assert/strict';
const [directory,report]=process.argv.slice(2);
const load=async name=>JSON.parse(await readFile(directory+'/'+name,'utf8'));
const status=await load('status.json'),accounts=await load('accounts.json'),s=await load('journey-state.json');
const base=status.API_URL;assert.ok(['http://127.0.0.1:56621','http://127.0.0.1:56821'].includes(base));const tokens={};
async function request(path,token,body){const r=await fetch(base+path,{method:'POST',redirect:'error',headers:{apikey:status.ANON_KEY,Authorization:'Bearer '+token,'Content-Type':'application/json'},body:JSON.stringify(body),signal:AbortSignal.timeout(15000)});const b=await r.json();if(!r.ok)throw Object.assign(new Error(b.message),{code:b.code,http:r.status});return b;}
for(const a of accounts)tokens[a.persona]=(await request('/auth/v1/token?grant_type=password',status.ANON_KEY,{email:a.email,password:a.password})).access_token;
const rpc=(actor,name,args)=>request('/rest/v1/rpc/'+name,tokens[actor],args);
let state;try{state=await load('refund-state.json');}catch(e){if(e.code!=='ENOENT')throw e;state={initiateId:randomUUID(),executeId:randomUUID(),customerId:randomUUID()};}
const save=()=>writeFile(directory+'/refund-state.json',JSON.stringify(state,null,2),{mode:0o600});await save();
const args={p_booking_id:s.booking.primary_booking_id,p_collection_movement_id:s.receipt.movement_id,p_refund_amount_minor:2000,p_reason:'LOCAL SYNTHETIC partial service refund; no external money',p_operation_id:state.initiateId,p_policy_override:true};
await assert.rejects(rpc('customer','initiate_booking_refund',{...args,p_operation_id:state.customerId}),e=>e.code==='42501');
state.request=await rpc('owner','initiate_booking_refund',args);await save();assert.equal(state.request.status,'approved_pending_return');
const execute={p_refund_request_id:state.request.refund_request_id,p_return_payment_method:'cash',p_evidence_reference:'LOCAL-SYNTHETIC-RETURN-NOT-A-REAL-BANK-OR-CASH-TRANSACTION',p_operation_id:state.executeId,p_shift_id:s.shift.id};
state.receipt=await rpc('cashier','execute_booking_refund',execute);await save();assert.equal(state.receipt.refunded_amount_minor,2000);
const replay=await rpc('cashier','execute_booking_refund',execute);assert.equal(replay.replayed,true);assert.equal(replay.refund_movement_id,state.receipt.refund_movement_id);
assert.equal(state.receipt.commission_reversed_minor,300);assert.equal(state.receipt.net_collected_minor,8000);
await writeFile(report,JSON.stringify({environment:base,evidence:'Real local authenticated refund RPC and synthetic return attestation; no external return executed; not UI acceptance',customerDenied:true,request:state.request,receipt:state.receipt,replay:true,accounting:'Requires independent signed-ledger and shift-expense check'},null,2));console.log('Authenticated synthetic partial refund, customer denial and replay passed; external money never moved.');
