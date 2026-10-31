import {readFile} from 'node:fs/promises';
import {stripTypeScriptTypes} from 'node:module';
import vm from 'node:vm';
import test from 'node:test';
import assert from 'node:assert/strict';
const source=stripTypeScriptTypes((await readFile(new URL('./index.ts',import.meta.url),'utf8')).replace(/^import .*createClient.*;\r?\n/m,''));
const target='10000000-0000-0000-0000-000000000002';
async function fixture({authority=true,authorityError=false,dbError=false,banFailures=0}={}){
 let handler,deactivated=false,bans=0;const calls=[];
 const caller={rpc:async(name,params)=>{
  calls.push({name,params});
  if(name==='is_super_admin')return {data:authority,error:authorityError?{message:'synthetic outage'}:null};
  if(dbError)return {data:null,error:{message:'synthetic DB failure'}};
  deactivated=true;return {data:{success:true,target_user_id:target},error:null};
 }};
 const service={auth:{getUser:async()=>({data:{user:{id:'fixture-actor'}},error:null}),admin:{updateUserById:async(id)=>{
  assert.equal(id,target);assert.equal(deactivated,true);bans++;return {error:bans<=banFailures?{message:'synthetic Auth outage'}:null};
 }}}};
 vm.runInNewContext(source,{createClient:(_url,_key,options)=>options?.global?caller:service,Deno:{env:{get:()=> 'synthetic'},serve:value=>handler=value},Request,Response,console:{error(){}}});
 async function run(){const r=await handler(new Request('https://fixture.invalid/deactivate',{method:'POST',headers:{Authorization:'Bearer synthetic','Content-Type':'application/json'},body:JSON.stringify({target_user_id:target})}));return {status:r.status,body:await r.json(),bans,deactivated,calls};}
 return {run};
}
test('ordinary caller cannot deactivate a target',async()=>{const r=await(await fixture({authority:false})).run();assert.equal(r.status,403);assert.equal(r.deactivated,false);assert.equal(r.bans,0);});
test('canonical authorization outage fails closed',async()=>{const r=await(await fixture({authorityError:true})).run();assert.equal(r.status,403);assert.equal(r.bans,0);});
test('DB failure cannot disable Auth while ownership remains unchanged',async()=>{const r=await(await fixture({dbError:true})).run();assert.equal(r.status,400);assert.equal(r.bans,0);});
test('transient Auth failure retries after database deactivation',async()=>{const r=await(await fixture({banFailures:1})).run();assert.equal(r.status,200);assert.equal(r.bans,2);assert.equal(r.body.auth_disabled,true);});
test('permanent Auth failure reports partial result and explicit retry reconciles it',async()=>{const f=await fixture({banFailures:2});const first=await f.run();assert.equal(first.status,503);assert.equal(first.body.deactivated,true);assert.notEqual(first.body.auth_disabled,true);const retry=await f.run();assert.equal(retry.status,200);assert.equal(retry.body.auth_disabled,true);assert.equal(retry.bans,3);});
