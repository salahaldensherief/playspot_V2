import {readFile} from 'node:fs/promises';
import {stripTypeScriptTypes} from 'node:module';
import vm from 'node:vm';
import test from 'node:test';
import assert from 'node:assert/strict';

const source=stripTypeScriptTypes((await readFile(new URL('./index.ts',import.meta.url),'utf8'))
  .replace(/^import .*;\r?\n/gm,''));
function fixture(overrides={}) {
  const calls={constructors:0,tokens:0,sends:[],updates:[]};let handler;
  const credential={getAccessToken:async()=>{calls.tokens++;return overrides.token?.()??{token:'fixture-token'};}};
  class GoogleAuth {
    constructor(){calls.constructors++;}
    async getClient(){return credential;}
  }
  const supabase={
    rpc:async()=>({data:'fixture-server-secret',error:null}),
    from:table=>({
      select:()=>({eq:()=>({maybeSingle:async()=>({data:table==='profiles'
        ? {fcm_token:'device-token',...overrides.profile}
        : overrides.settings??{},error:null})})}),
      update:values=>({eq:async()=>{calls.updates.push(values);return {error:null};}}),
    }),
  };
  vm.runInNewContext(source,{
    GoogleAuth,createClient:()=>supabase,
    Deno:{env:{get:key=>key==='FIREBASE_PRIVATE_KEY'?'fixture-private-key':'fixture'},serve:value=>{handler=value;}},
    fetch:async(url,options)=>{calls.sends.push({url,options});return Response.json({name:'sent'});},
    Request,Response,TextEncoder,console:{error:()=>{},log:()=>{}},
  });
  const request=(key='fixture-server-secret')=>new Request('https://fixture.invalid',{
    method:'POST',headers:{apikey:key},body:JSON.stringify({record:{id:'notice',user_id:'user',
      type:'booking_confirmed',title_ar:'حجز',title_en:'Booking',body_en:'Confirmed',language:'en'}}),
  });
  return {calls,send:key=>handler(request(key))};
}
test('sequential requests reuse one credential client and ask it for a current token each time',async()=>{
  let token='first';const f=fixture({token:()=>({token})});
  assert.equal((await f.send()).status,200);token='after-library-refresh';
  assert.equal((await f.send()).status,200);
  assert.equal(f.calls.constructors,1);assert.equal(f.calls.tokens,2);
  assert.equal(f.calls.sends[0].options.headers.Authorization,'Bearer first');
  assert.equal(f.calls.sends[1].options.headers.Authorization,'Bearer after-library-refresh');
});
test('concurrent notification requests retain the shared GoogleAuth instance',async()=>{
  const f=fixture();const responses=await Promise.all(Array.from({length:12},()=>f.send()));
  assert.ok(responses.every(r=>r.status===200));assert.equal(f.calls.constructors,1);
  assert.equal(f.calls.sends.length,12);
});
test('an OAuth failure does not poison the shared client for later requests',async()=>{
  let unavailable=true;const f=fixture({token:()=>{if(unavailable)throw Error('fixture outage');return {token:'recovered'};}});
  assert.equal((await f.send()).status,500);assert.equal(f.calls.sends.length,0);
  unavailable=false;assert.equal((await f.send()).status,200);assert.equal(f.calls.constructors,1);
});
test('unauthorized callers never request OAuth tokens or send a push',async()=>{
  const f=fixture();assert.equal((await f.send('public-anon-key')).status,401);
  assert.equal(f.calls.tokens,0);assert.equal(f.calls.sends.length,0);
});
for(const options of [{settings:{push_enabled:false}},{settings:{booking_updates:false}},
  {profile:{notification_preferences:{push_notifications_enabled:false}}},{profile:{fcm_token:null}}]) {
  test(`recipient opt-out or missing device is respected: ${JSON.stringify(options)}`,async()=>{
    const f=fixture(options);assert.equal((await f.send()).status,200);
    assert.equal(f.calls.tokens,0);assert.equal(f.calls.sends.length,0);
  });
}
test('notification still contains localized content and targets only the recipient device',async()=>{
  const f=fixture();await f.send();const message=JSON.parse(f.calls.sends[0].options.body).message;
  assert.equal(message.token,'device-token');assert.equal(message.notification.title,'Booking');
  assert.equal(message.data.notification_id,'notice');assert.equal('topic' in message,false);
});
