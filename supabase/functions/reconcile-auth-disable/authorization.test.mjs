import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {stripTypeScriptTypes} from 'node:module';
import vm from 'node:vm';
const source=stripTypeScriptTypes((await readFile(new URL('./index.ts',import.meta.url),'utf8')).replace(/^import .*;\r?\n/gm,''));
async function request({token='synthetic-service-key',method='POST',failure=false}={}){
 let handler,calls=0;
 const context=vm.createContext({Request,Response,console:{error(){}},createClient:()=>({}),
  reconcileAuthDisabling:async()=>{calls++;if(failure)throw Error('failed');return{processed:0,completed:0,deferred:0,recovery:{failed:0}};},
  Deno:{env:{get:name=>name==='SUPABASE_URL'?'http://127.0.0.1:54321':'synthetic-service-key'},serve:fn=>handler=fn}});
 vm.runInContext(source,context);
 const result=await handler(new Request('http://127.0.0.1/reconcile',{method,headers:token?{authorization:'Bearer '+token}:{}}));
 return{status:result.status,calls};
}
for(const token of [null,'synthetic-customer-jwt','synthetic-admin-jwt','synthetic-anon-key'])test('non-scheduler credential never reaches jobs '+token,async()=>{const r=await request({token});assert.equal(r.status,401);assert.equal(r.calls,0);});
test('GET cannot execute worker',async()=>{const r=await request({method:'GET'});assert.equal(r.status,405);assert.equal(r.calls,0);});
test('scheduler can execute bounded worker',async()=>{const r=await request();assert.equal(r.status,200);assert.equal(r.calls,1);});
test('scheduler failure is explicit',async()=>{assert.equal((await request({failure:true})).status,503);});
