import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {stripTypeScriptTypes} from 'node:module';
import vm from 'node:vm';
const source=stripTypeScriptTypes((await readFile(new URL('./worker.ts',import.meta.url),'utf8')).replace('export async function','async function'));
const context=vm.createContext({});vm.runInContext(source,context);
const run=context.reconcileAuthDisabling;
async function fixture({tasks=[{user_id:'synthetic-user',lease_id:'lease-1'}],claimError=false,authError=null,throwAuth=false,ackError=false,monitorError=false}={}){
 const calls=[];
 const client={rpc:async(name,params)=>{calls.push({name,params});if(name==='claim_auth_disable_tasks')return{data:tasks,error:claimError?'failed':null};if(name==='finish_auth_disable_task')return{data:!ackError,error:ackError?'failed':null};return{data:monitorError?null:{pending:0,failed:0},error:monitorError?'failed':null};},auth:{admin:{updateUserById:async(id,attrs)=>{calls.push({id,attrs});if(throwAuth)throw Error('provider secrets must not persist');return{error:authError};}}}};
 return{calls,run:()=>run(client)};
}
test('success bans only claimed identity and acknowledges exact lease',async()=>{const f=await fixture();const r=await f.run();assert.equal(r.completed,1);const ack=f.calls.find(c=>c.name==='finish_auth_disable_task').params;assert.equal(ack.p_user_id,'synthetic-user');assert.equal(ack.p_lease_id,'lease-1');assert.equal(ack.p_success,true);});
test('empty batch performs no Auth request',async()=>{const f=await fixture({tasks:[]});assert.equal((await f.run()).processed,0);assert.equal(f.calls.some(c=>c.id),false);});
test('claim failure performs no Auth request',async()=>{const f=await fixture({claimError:true});await assert.rejects(f.run(),/CLAIM_FAILED/);assert.equal(f.calls.some(c=>c.id),false);});
test('Auth outage schedules retry without raw provider data',async()=>{const f=await fixture({throwAuth:true});assert.equal((await f.run()).deferred,1);const p=f.calls.find(c=>c.name==='finish_auth_disable_task').params;assert.equal(p.p_success,false);assert.equal(p.p_error_code,'AUTH_UNAVAILABLE');assert.equal(JSON.stringify(f.calls).includes('provider secrets'),false);});
test('deleted Auth identity is already disabled',async()=>{const f=await fixture({authError:{status:404}});assert.equal((await f.run()).completed,1);});
test('Auth rejection uses bounded SQL retry policy',async()=>{const f=await fixture({authError:{status:403}});await f.run();assert.equal(f.calls.find(c=>c.name==='finish_auth_disable_task').params.p_error_code,'AUTH_REJECTED');});
test('lost acknowledgement never reports completion',async()=>{const f=await fixture({ackError:true});const r=await f.run();assert.equal(r.completed,0);assert.equal(r.deferred,1);});
test('monitor failure is explicit',async()=>{const f=await fixture({monitorError:true});await assert.rejects(f.run(),/MONITOR_FAILED/);});
