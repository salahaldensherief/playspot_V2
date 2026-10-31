import {readFile} from 'node:fs/promises';
import {stripTypeScriptTypes} from 'node:module';
import vm from 'node:vm';
import test from 'node:test';
import assert from 'node:assert/strict';
const source=stripTypeScriptTypes((await readFile(new URL('./index.ts',import.meta.url),'utf8')).replace(/^import .*createClient.*;\r?\n/m,''));
async function request({authenticated=true,dbError=false,confirmed=true,banFailures=0,completionError=false,completionMissing=false}={}){
 let handler,bans=0,writes=0;const calls=[];
 const admin={rpc:async(name,params)=>{calls.push({name,params});return {data:confirmed?{success:true,deactivated:true}:null,error:dbError?{message:'synthetic DB failure'}:null};},
  auth:{getUser:async()=>({data:{user:authenticated?{id:'fixture-actor'}:null},error:null}),admin:{updateUserById:async(id)=>{calls.push({ban:id});bans++;return {error:bans<=banFailures?{message:'synthetic Auth outage'}:null};}}},
  from:table=>{
   assert.equal(table,'account_deletion_requests');
   return {update:()=>{
    writes++;
    return {eq:(field,id)=>{
     calls.push({field,id});
     return {select:()=>({maybeSingle:async()=>({data:completionMissing?null:{user_id:id},error:completionError?{message:'synthetic write error'}:null})})};
    }};
   }};
  }};
 vm.runInNewContext(source,{createClient:()=>admin,Deno:{env:{get:key=>key==='SUPABASE_SECRET_KEYS'?'{"default":"synthetic"}':'synthetic'},serve:value=>handler=value},Request,Response,console:{error(){}}});
 const response=await handler(new Request('https://fixture.invalid/delete-account',{method:'POST',headers:{Authorization:'Bearer synthetic'},body:JSON.stringify({user_id:'forged-victim'})}));
 return {status:response.status,body:await response.json(),calls,bans,writes};
}
test('caller ID is resolved from Auth and request body cannot choose a victim',async()=>{const r=await request();assert.equal(r.status,200);assert.deepEqual(JSON.parse(JSON.stringify(r.calls[0])),{name:'anonymize_account_for_deletion',params:{p_user_id:'fixture-actor'}});});
test('unauthenticated actor never reaches deletion',async()=>{const r=await request({authenticated:false});assert.equal(r.status,401);assert.equal(r.calls.length,0);});
test('DB transaction failure never bans an account or reports completion',async()=>{const r=await request({dbError:true});assert.equal(r.status,500);assert.equal(r.bans,0);assert.equal(r.writes,0);});
test('unconfirmed DB response cannot advance to Auth',async()=>{const r=await request({confirmed:false});assert.equal(r.status,500);assert.equal(r.bans,0);});
test('transient Auth failure is retried before completion',async()=>{const r=await request({banFailures:1});assert.equal(r.status,200);assert.equal(r.bans,2);assert.equal(r.writes,1);});
test('permanent Auth outage is explicit and retains pending reconciliation',async()=>{const r=await request({banFailures:2});assert.equal(r.status,503);assert.equal(r.body.deactivated,true);assert.equal(r.writes,0);assert.notEqual(r.body.success,true);});
for(const options of [{completionError:true},{completionMissing:true}])test('failed completion acknowledgment does not report success '+JSON.stringify(options),async()=>{const r=await request(options);assert.equal(r.status,503);assert.equal(r.body.auth_disabled,true);assert.notEqual(r.body.success,true);});
