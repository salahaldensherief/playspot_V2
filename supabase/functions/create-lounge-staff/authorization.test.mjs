import {readFile} from 'node:fs/promises';
import {stripTypeScriptTypes} from 'node:module';
import vm from 'node:vm';
import test from 'node:test';
import assert from 'node:assert/strict';

const source=stripTypeScriptTypes((await readFile(new URL('./index.ts',import.meta.url),'utf8')).replace(/^import .*createClient.*;\r?\n/m,''));
async function request({role='owner',active=true,banned=false,superAdmin=false,permission=true,canonicalError=null,staffRole='cashier'}={}){
 let handler,creates=0;const rpcCalls=[];
 const service={auth:{getUser:async()=>({data:{user:{id:'fixture-actor'}},error:null}),admin:{createUser:async()=>{
  creates++;return {data:{user:null},error:{message:'STOP_AFTER_AUTHORIZATION'}};
 }}},from:()=>({select:()=>({eq:()=>({maybeSingle:async()=>({data:{id:'fixture-actor',role,is_active:active,is_banned:banned},error:null})})})})};
 const caller={rpc:async(name,params)=>{rpcCalls.push({name,params});return name==='is_super_admin'
  ? {data:superAdmin,error:canonicalError} : {data:permission,error:null};}};
 vm.runInNewContext(source,{createClient:(_url,_key,options)=>options?.global?caller:service,
  Deno:{env:{get:()=> 'synthetic-only'},serve:value=>handler=value},Request,Response,console:{error(){}}});
 const response=await handler(new Request('https://fixture.invalid/create-lounge-staff',{
  method:'POST',headers:{Authorization:'Bearer synthetic-user-token','Content-Type':'application/json'},
  body:JSON.stringify({email:'staff@example.invalid',password:'synthetic-only',full_name:'Fixture',lounge_id:'fixture-lounge',role:staffRole}),
 }));
 return {status:response.status,body:await response.json(),creates,rpcCalls};
}
test('stale profile super_admin label cannot bypass canonical authority',async()=>{
 const r=await request({role:'super_admin',superAdmin:false});assert.equal(r.status,403);assert.equal(r.creates,0);
});
test('banned owner cannot create staff',async()=>{
 const r=await request({banned:true});assert.equal(r.status,403);assert.equal(r.creates,0);
});
test('inactive owner cannot create staff',async()=>{
 const r=await request({active:false});assert.equal(r.status,403);assert.equal(r.creates,0);
});
test('canonical authority error fails before Auth account creation',async()=>{
 const r=await request({canonicalError:{message:'unavailable'}});assert.equal(r.status,403);assert.equal(r.creates,0);
});
test('owner cannot manage another lounge without scoped permission',async()=>{
 const r=await request({permission:false});assert.equal(r.status,403);assert.equal(r.creates,0);
 assert.deepEqual(JSON.parse(JSON.stringify(r.rpcCalls.at(-1))),{name:'has_lounge_permission',params:{p_lounge_id:'fixture-lounge',p_permission_key:'staff_manage'}});
});
test('cashier role cannot create staff even with a permission response',async()=>{
 const r=await request({role:'cashier'});assert.equal(r.status,403);assert.equal(r.creates,0);
});
test('manager cannot create a peer manager',async()=>{
 const r=await request({role:'manager',staffRole:'manager'});assert.equal(r.status,403);assert.equal(r.creates,0);
});
test('authorized owner reaches creation only after canonical and scoped checks',async()=>{
 const r=await request();assert.equal(r.creates,1);assert.equal(r.body.error,'STOP_AFTER_AUTHORIZATION');
 assert.deepEqual(r.rpcCalls.map(c=>c.name),['is_super_admin','has_lounge_permission']);
});
test('canonical active super admin reaches creation without scoped role bypass',async()=>{
 const r=await request({role:'super_admin',superAdmin:true});assert.equal(r.creates,1);assert.equal(r.body.error,'STOP_AFTER_AUTHORIZATION');
 assert.deepEqual(r.rpcCalls.map(c=>c.name),['is_super_admin']);
});
test('canonical platform authority with manager profile may create manager',async()=>{
 const r=await request({role:'manager',superAdmin:true,staffRole:'manager'});
 assert.equal(r.creates,1);assert.equal(r.body.error,'STOP_AFTER_AUTHORIZATION');
});
