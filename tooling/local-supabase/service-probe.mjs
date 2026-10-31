import {readFile,writeFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
const [directory,report]=process.argv.slice(2);
const status=JSON.parse(await readFile(directory+'/status.json','utf8'));
const accounts=JSON.parse(await readFile(directory+'/accounts.json','utf8'));
const base=status.API_URL;assert.ok(['http://127.0.0.1:56621','http://127.0.0.1:56821'].includes(base));
const results=[];
for(const a of accounts){
 const r=await fetch(base+'/auth/v1/token?grant_type=password',{method:'POST',redirect:'error',headers:{apikey:status.ANON_KEY,'Content-Type':'application/json'},body:JSON.stringify({email:a.email,password:a.password})});assert.equal(r.status,200);
 const login=await r.json();const headers={apikey:status.ANON_KEY,Authorization:'Bearer '+login.access_token};
 const profile=await fetch(base+'/rest/v1/profiles?select=id,role&id=eq.'+a.id,{headers,redirect:'error'});assert.equal(profile.status,200);
 const rows=await profile.json();assert.equal(rows.length,1);assert.equal(rows[0].role,a.persona==='customer'?'user':a.persona);
 results.push({persona:a.persona,realAuth:true,profileRead:true,role:rows[0].role});
 if(a.persona!=='customer')continue;
 const storage=await fetch(base+'/storage/v1/bucket',{headers,redirect:'error'});assert.equal(storage.status,200);
 const buckets=await storage.json();
 const realtime=await new Promise((resolve,reject)=>{
  const ws=new WebSocket(base.replace('http:','ws:')+'/realtime/v1/websocket?apikey='+encodeURIComponent(status.ANON_KEY)+'&vsn=1.0.0');
  const timeout=setTimeout(()=>{ws.close();reject(new Error('Local Realtime join timed out'));},15000);
  ws.onopen=()=>ws.send(JSON.stringify({topic:'realtime:local-acceptance',event:'phx_join',payload:{config:{broadcast:{self:false},presence:{key:''},postgres_changes:[]},access_token:login.access_token},ref:'1'}));
  ws.onmessage=e=>{const m=JSON.parse(e.data);if(m.event==='phx_reply'&&m.ref==='1'){clearTimeout(timeout);ws.close();if(m.payload.status==='ok')resolve(true);else reject(new Error('Realtime join rejected'));}};
  ws.onerror=()=>{clearTimeout(timeout);reject(new Error('Local Realtime transport failure'));};
 });
 results.push({storageApi:true,visibleBuckets:buckets.length,receiptUpload:'NOT TESTED; managed bucket/policy baseline not imported',realtimeAuthenticatedChannelJoin:realtime,postgresChangeDelivery:'NOT TESTED'});
}
await writeFile(report,JSON.stringify({environment:base,results},null,2));console.log('Three real Auth/profile role reads, Storage API and authenticated Realtime channel join passed.');
