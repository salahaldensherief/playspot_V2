// Real local Auth/PostgREST journey; not browser or installed-device acceptance.
import {readFile,writeFile} from 'node:fs/promises';
import {randomUUID} from 'node:crypto';
import assert from 'node:assert/strict';
const [directory,report]=process.argv.slice(2);
const load=async name=>JSON.parse(await readFile(directory+'/'+name,'utf8'));
const status=await load('status.json'), accounts=await load('accounts.json'), fixture=await load('business-fixture.json');
const base='http://127.0.0.1:56821';
assert.equal(status.API_URL,base);
let state;
try{state=await load('journey-state.json');}catch(e){if(e.code!=='ENOENT')throw e;state={operationId:randomUUID(),deniedId:randomUUID()};}
const save=()=>writeFile(directory+'/journey-state.json',JSON.stringify(state,null,2),{mode:0o600});
await save();
let stage='login';
async function call(path,token,body){
 const r=await fetch(base+path,{method:'POST',redirect:'error',headers:{apikey:status.ANON_KEY,Authorization:'Bearer '+token,'Content-Type':'application/json'},body:JSON.stringify(body),signal:AbortSignal.timeout(20000)});
 const result=await r.json();
 if(!r.ok)throw Object.assign(new Error(result.message??'Local API failure'),{http:r.status,code:result.code});
 return result;
}
const tokens={};
const rpc=(persona,name,body)=>call('/rest/v1/rpc/'+name,tokens[persona],body);
try{
 for(const a of accounts){const login=await call('/auth/v1/token?grant_type=password',status.ANON_KEY,{email:a.email,password:a.password});assert.equal(login.user.id,a.id);tokens[a.persona]=login.access_token;}
 stage='owner grants';
 for(const permission of ['billing_checkout','sessions_control','bookings_view','rooms_view']){
  const grant=await rpc('owner','set_staff_permission',{p_lounge_id:fixture.lounge,p_target_user_id:fixture.cashier,p_permission_key:permission,p_is_enabled:true});assert.equal(grant.success,true);
 }
 stage='cashier shift';
 if(!state.shift){state.shift=await rpc('cashier','open_lounge_shift',{p_lounge_id:fixture.lounge,p_starting_cash:0,p_notes:'LOCAL SYNTHETIC ACCEPTANCE'});await save();}
 assert.equal(state.shift.staff_user_id,fixture.cashier);
 const rooms=[{room_id:fixture.room,play_mode:'single',extra_controllers:0}];
 if(!state.booking){
  stage='customer hold';
  if(state.hold && new Date(state.hold.start_at).getSeconds()!==0){
   await rpc('customer','release_booking_hold',{p_hold_token:state.hold.hold_token});
   state.previousInvalidHold=state.hold;delete state.hold;await save();
  }
  if(!state.hold){
   const start=new Date(Math.ceil((Date.now()+120000)/60000)*60000),end=new Date(start.getTime()+3600000);
   const local=d=>new Intl.DateTimeFormat('sv-SE',{timeZone:'Africa/Cairo',year:'numeric',month:'2-digit',day:'2-digit',hour:'2-digit',minute:'2-digit',second:'2-digit',hour12:false}).format(d).replace(' ','T');
   state.hold=await rpc('customer','acquire_booking_hold',{p_room_ids:[fixture.room],p_start_at:local(start),p_end_at:local(end),p_hold_minutes:10});await save();
  }
  const params={p_hold_token:state.hold.hold_token,p_room_requests:rooms,p_extra_items:[],p_voucher_code:null};
  stage='customer quote';state.quote=await rpc('customer','quote_my_booking_checkout',params);await save();
  stage='customer create';state.booking=await rpc('customer','create_my_booking_checkout',{...params,p_payment_method:'cash',p_sender_wallet_phone:null,p_receipt_url:null});await save();
 }
 const booking=state.booking.primary_booking_id;assert.ok(booking);
 if(!state.started){stage='cashier start';state.started=await rpc('cashier','start_booking_session',{p_booking_id:booking});await save();}
 if(!state.completed){stage='cashier complete';state.completed=await rpc('cashier','complete_booking_session',{p_booking_id:booking,p_action_by:fixture.cashier});await save();}
 const checkout={p_booking_id:booking,p_shift_id:state.shift.id,p_amount_minor:null,p_operation_id:state.operationId};
 stage='unauthorized customer';
 await assert.rejects(rpc('customer','checkout_booking_cash_atomic',{...checkout,p_operation_id:state.deniedId}),e=>e.http===403||e.code==='42501');
 stage='cashier collection';state.receipt=await rpc('cashier','checkout_booking_cash_atomic',checkout);await save();
 assert.equal(state.receipt.booking_id,booking);assert.equal(state.receipt.operation_id,state.operationId);
 stage='lost response replay';const replay=await rpc('cashier','checkout_booking_cash_atomic',checkout);assert.equal(replay.replayed,true);
 assert.equal(replay.movement_id,state.receipt.movement_id);
 await writeFile(report,JSON.stringify({environment:base,evidence:'Real local GoTrue + PostgREST JWT requests shaped from both client data sources; not browser UI E2E',authentication:['owner','cashier','customer'],booking,quote:state.quote,completed:state.completed,receipt:state.receipt,unauthorizedCustomerDenied:true,lostResponseReplay:true,accounting:'Pending independent ledger reconciliation'},null,2));
 console.log('Local authenticated booking/session/collection/replay journey passed; ledger reconciliation still required.');
}catch(e){await writeFile(directory+'/journey-failure.json',JSON.stringify({stage,http:e.http,code:e.code,message:e.message},null,2),{mode:0o600});console.error('Local journey stopped at '+stage+': '+e.message);process.exitCode=1;}
