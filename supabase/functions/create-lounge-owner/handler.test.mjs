import test from 'node:test';
import assert from 'node:assert/strict';
import { createOwnerHandler } from './handler.js';

const body={email:'OWNER@example.invalid',password:'fixture-only-password',owner_name:'Owner',lounge_name:'Venue',address:'Address',phone:'01234567890',owner_phone:'01987654321'};
const request=(payload=body,token='Bearer fixture')=>new Request('https://fixture.invalid',{method:'POST',headers:{Authorization:token,'Content-Type':'application/json'},body:JSON.stringify(payload)});
function fixture(overrides={}) {
  const calls=[];
  const handler=createOwnerHandler({
    authenticate:async()=>({id:'admin'}),authorize:async()=>true,
    createAccount:async(p)=>{calls.push(['create',p]);return {id:'owner'};},
    finalize:async(p)=>{calls.push(['finalize',p]);return {success:true,owner_id:'owner',lounge_id:'venue',status:'pending'};},
    reportUnconfirmed:id=>calls.push(['unconfirmed',id]),...overrides,
  });
  return {handler,calls};
}
test('active authenticated super admin creates pending venue through Auth Admin',async()=>{
  const {handler,calls}=fixture();const response=await handler(request());
  assert.equal(response.status,201);assert.equal((await response.json()).status,'pending');
  assert.equal(calls[0][1].email,'owner@example.invalid');
  assert.equal(calls[1][1].p_actor_id,'admin');assert.equal(calls[1][1].p_address,'Address');
  assert.equal('password' in calls[1][1],false);
  assert.equal(calls[1][1].p_phone,'01234567890');
  assert.equal(calls[1][1].p_owner_phone,'01987654321');
});
for (const [name,overrides,status] of [
  ['expired session',{authenticate:async()=>null},401],
  ['non administrator',{authorize:async()=>false},403],
]) test(name+' never creates an account',async()=>{
  const {handler,calls}=fixture(overrides);assert.equal((await handler(request())).status,status);assert.deepEqual(calls,[]);
});
test('missing bearer token is rejected',async()=>{const {handler,calls}=fixture();assert.equal((await handler(request(body,''))).status,401);assert.deepEqual(calls,[]);});
test('short password rejected before account creation',async()=>{const {handler,calls}=fixture();assert.equal((await handler(request({...body,password:'short'}))).status,400);assert.deepEqual(calls,[]);});
test('existing email is rejected without modifying its account',async()=>{
  const {handler,calls}=fixture({createAccount:async()=>({duplicate:true})});
  const response=await handler(request());assert.equal(response.status,409);assert.equal((await response.json()).error,'owner_email_exists');assert.deepEqual(calls,[]);
});
test('lost finalization response retries the same owner without creating a second account',async()=>{
  let attempts=0;const {handler,calls}=fixture({finalize:async()=>++attempts===1?null:{success:true,owner_id:'owner',lounge_id:'venue'}});
  assert.equal((await handler(request())).status,201);assert.equal(attempts,2);assert.equal(calls.filter(c=>c[0]==='create').length,1);
});
test('uncertain commit never reports success or deletes an account',async()=>{
  const {handler,calls}=fixture({finalize:async()=>null});const response=await handler(request());
  assert.equal(response.status,503);assert.equal((await response.json()).error,'owner_provisioning_unconfirmed');assert.deepEqual(calls.at(-1),['unconfirmed','owner']);
});
test('network exceptions during finalization remain an unconfirmed operation',async()=>{
  const {handler,calls}=fixture({finalize:async()=>{throw new Error('fixture network failure');}});
  const response=await handler(request());assert.equal(response.status,503);
  assert.equal((await response.json()).error,'owner_provisioning_unconfirmed');
  assert.deepEqual(calls.at(-1),['unconfirmed','owner']);
});
test('preflight and unsupported methods do not create accounts',async()=>{
  const {handler,calls}=fixture();assert.equal((await handler(new Request('https://fixture.invalid',{method:'OPTIONS'}))).status,200);
  assert.equal((await handler(new Request('https://fixture.invalid'))).status,405);assert.deepEqual(calls,[]);
});

test('omitted owner phone never copies the venue contact into the owner profile',async()=>{
 const {handler,calls}=fixture(); const {owner_phone,...legacy}=body;
 assert.equal((await handler(request(legacy))).status,201);
 assert.equal(calls[1][1].p_owner_phone,null);
 assert.equal(calls[1][1].p_phone,'01234567890');
});
