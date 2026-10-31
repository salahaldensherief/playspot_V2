import {readFile} from 'node:fs/promises';
import {stripTypeScriptTypes} from 'node:module';
import vm from 'node:vm';
import test from 'node:test';
import assert from 'node:assert/strict';

const source=stripTypeScriptTypes((await readFile(new URL('./index.ts',import.meta.url),'utf8')).replace(/^import .*createClient.*;\r?\n/m,''));
async function request({finalizeError=false,throwAfterCommit=false,mismatch=false,recovery=false,authResponseLost=false,existingAccount=false,foreignAccount=false}={}) {
  let handler, creates=0, deletes=0; const calls=[];
  const service={auth:{getUser:async()=>({data:{user:{id:'actor'}},error:null}),admin:{
    createUser:async options=>{creates++;calls.push(options);
      if(authResponseLost)throw new Error('Auth committed, response lost');
      if(existingAccount)return {data:{user:null},error:{message:'User already registered'}};
      return {data:{user:{id:'new-staff'}},error:null};},
    deleteUser:async()=>{deletes++;},
  }},from:()=>({select:()=>({eq:()=>({maybeSingle:async()=>({data:{id:'actor',role:'owner',is_active:true,is_banned:false},error:null})})})}),
  rpc:async(name,params)=>{
    calls.push({name,params});
    if(name==='recover_lounge_staff_provisioning')return {data:foreignAccount?null:'new-staff',error:null};
    if(throwAfterCommit)throw new Error('Response lost after commit');
    return {data:finalizeError?null:{success:true,user_id:mismatch?'different':'new-staff',role:'cashier'},error:finalizeError?{message:'failure'}:null};
  }};
  const caller={rpc:async name=>({data:name==='is_super_admin'?false:true,error:null})};
  vm.runInNewContext(source,{createClient:(_url,_key,options)=>options?.global?caller:service,
    Deno:{env:{get:()=> 'synthetic-only'},serve:value=>handler=value},Request,Response,console:{error(){}}});
  const response=await handler(new Request('https://fixture.invalid/create-lounge-staff',{
    method:'POST',headers:{Authorization:'Bearer synthetic-user-token','Content-Type':'application/json'},
    body:JSON.stringify({email:'staff@example.invalid',password:'synthetic-only',full_name:'Fixture',lounge_id:'lounge',role:'cashier',
      ...(recovery?{recovery_user_id:'new-staff'}:{})}),
  }));
  return {status:response.status,body:await response.json(),creates,deletes,calls};
}
test('Auth account carries server-controlled provisioning provenance',async()=>{
  const r=await request();assert.equal(r.status,201);assert.equal(r.creates,1);
  assert.deepEqual(JSON.parse(JSON.stringify(r.calls[0].app_metadata)),{staff_provisioning:{actor_id:'actor',lounge_id:'lounge',role:'cashier'}});
  assert.equal(r.calls[1].name,'finalize_lounge_staff_provisioning');
});
for(const options of [{finalizeError:true},{throwAfterCommit:true},{mismatch:true}]) {
  test('unconfirmed finalization retains Auth account for recovery '+JSON.stringify(options),async()=>{
    const r=await request(options);assert.equal(r.status,503);assert.equal(r.deletes,0);
    assert.equal(r.body.provisioning_confirmed,false);assert.equal(r.body.recovery_user_id,'new-staff');
  });
}
test('explicit recovery uses atomic finalizer without creating another account',async()=>{
  const r=await request({recovery:true});assert.equal(r.status,201);assert.equal(r.creates,0);assert.equal(r.deletes,0);
  assert.equal(r.calls[0].params.p_actor_id,'actor');assert.equal(r.calls[0].params.p_user_id,'new-staff');
});
for(const options of [{authResponseLost:true},{existingAccount:true}]) {
  test('lost Auth acknowledgement recovers before atomic finalization '+JSON.stringify(options),async()=>{
    const r=await request(options);assert.equal(r.status,201);assert.equal(r.deletes,0);
    assert.equal(r.calls[1].name,'recover_lounge_staff_provisioning');
    assert.equal(r.calls[2].name,'finalize_lounge_staff_provisioning');
  });
}
test('unrelated existing account is never adopted',async()=>{
  const r=await request({existingAccount:true,foreignAccount:true});assert.equal(r.status,503);
  assert.equal(r.calls.length,2);assert.equal(r.deletes,0);
});
