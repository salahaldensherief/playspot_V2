// Authorization/replay checks on an already settled synthetic booking.
import {readFile,writeFile} from 'node:fs/promises';
import {randomUUID} from 'node:crypto';
import assert from 'node:assert/strict';
const [directory,report]=process.argv.slice(2);
const load=async name=>JSON.parse(await readFile(directory+'/'+name,'utf8'));
const status=await load('status.json'),accounts=await load('accounts.json'),f=await load('business-fixture.json'),s=await load('journey-state.json');
const base=status.API_URL;assert.ok(['http://127.0.0.1:56621','http://127.0.0.1:56821'].includes(base));const tokens={};
async function request(path,token,body){const r=await fetch(base+path,{method:'POST',redirect:'error',headers:{apikey:status.ANON_KEY,Authorization:'Bearer '+token,'Content-Type':'application/json'},body:JSON.stringify(body),signal:AbortSignal.timeout(15000)});const b=await r.json();if(!r.ok)throw Object.assign(new Error(b.message),{code:b.code,http:r.status});return b;}
for(const a of accounts){tokens[a.persona]=(await request('/auth/v1/token?grant_type=password',status.ANON_KEY,{email:a.email,password:a.password})).access_token;}
const rpc=(actor,name,args)=>request('/rest/v1/rpc/'+name,tokens[actor],args);
const args={p_booking_id:s.booking.primary_booking_id,p_shift_id:s.shift.id,p_amount_minor:null,p_operation_id:s.operationId};
const results=[];
const permission=enabled=>rpc('owner','set_staff_permission',{p_lounge_id:f.lounge,p_target_user_id:f.cashier,p_permission_key:'billing_checkout',p_is_enabled:enabled});
try{
 await permission(false);
 await assert.rejects(rpc('cashier','checkout_booking_cash_atomic',args),e=>e.code==='42501');results.push('revoked cashier cannot replay receipt with an existing JWT');
}finally{await permission(true);}
const receipts=await Promise.all(Array.from({length:4},()=>rpc('cashier','checkout_booking_cash_atomic',args)));
for(const r of receipts){assert.equal(r.replayed,true);assert.equal(r.movement_id,s.receipt.movement_id);}results.push('four concurrent identical requests return the same canonical receipt');
await assert.rejects(rpc('cashier','checkout_booking_cash_atomic',{...args,p_amount_minor:1}),e=>e.code==='22023');results.push('same operation with changed amount rejected');
await assert.rejects(rpc('cashier','checkout_booking_cash_atomic',{...args,p_operation_id:randomUUID(),p_amount_minor:1}),e=>e.code==='22023'||e.code==='55000');results.push('new overpayment after full settlement rejected');
await writeFile(report,JSON.stringify({environment:base,results,evidence:'Real authenticated local RPCs; no UI concurrency claim'},null,2));console.log(results.length+' authenticated retry/authorization groups passed; cashier permission restored.');
