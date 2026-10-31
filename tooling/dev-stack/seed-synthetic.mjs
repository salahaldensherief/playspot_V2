import {readFile,writeFile} from 'node:fs/promises';
import {createRequire} from 'node:module';
import {randomUUID,randomBytes} from 'node:crypto';
import {resolve} from 'node:path';
import assert from 'node:assert/strict';
const require=createRequire(new URL('../../supabase/tests/runtime/package.json',import.meta.url));
const {Client}=require('pg');
const [directory,report]=process.argv.slice(2);
const load=async n=>JSON.parse(await readFile(resolve(directory,n),'utf8'));
const status=await load('status.json'),base='http://127.0.0.1:56821';assert.equal(status.API_URL,base);
const url=new URL(status.DB_URL);assert.equal(url.hostname,'127.0.0.1');assert.equal(url.port,'56822');
const c=new Client({connectionString:status.DB_URL});await c.connect();
let accounts;try{accounts=await load('accounts.json');}catch(e){if(e.code!=='ENOENT')throw e;accounts=[];}
const save=()=>writeFile(resolve(directory,'accounts.json'),JSON.stringify(accounts,null,2),{mode:0o600});
async function request(path,key,body){
 const r=await fetch(base+path,{method:'POST',redirect:'error',headers:{apikey:status.ANON_KEY,Authorization:'Bearer '+key,'Content-Type':'application/json'},body:JSON.stringify(body),signal:AbortSignal.timeout(20000)});
 const b=await r.json();if(!r.ok)throw Object.assign(new Error(b.message??b.msg??'Local Auth failure'),{code:b.code,http:r.status});return b;
}
try {
 const marker=(await c.query("SELECT count(*)::int AS n FROM private.local_development_environment WHERE environment='synthetic-only-v1'")).rows[0];
 assert.equal(marker.n,1,'Synthetic reference data is forbidden outside the marked local environment');
 const catalogue=JSON.parse(await readFile(new URL('synthetic-permissions.json',import.meta.url),'utf8'));
 for(const key of catalogue.keys){
  await c.query(`INSERT INTO public.app_permissions(key,name_ar,name_en,category,default_super_admin,default_owner,default_cashier)
   VALUES($1,$1,$1,'local_synthetic',false,false,false) ON CONFLICT(key) DO NOTHING`,[key]);
 }
 for(const persona of ['owner','cashier','customer']){
  if(accounts.some(a=>a.persona===persona))continue;
  const email=`playspot.dev.${persona}.20261031@example.invalid`,password=randomBytes(24).toString('base64url');
  const user=await request('/auth/v1/admin/users',status.SERVICE_ROLE_KEY,{email,password,email_confirm:true,user_metadata:{full_name:'LOCAL SYNTHETIC '+persona,role:'super_admin'}});
  const id=user.id??user.user?.id;assert.ok(id);
  accounts.push({persona,email,password,id});await save();
  const profile=(await c.query('SELECT role FROM public.profiles WHERE id=$1',[id])).rows[0];
  assert.equal(profile?.role,'user','Signup metadata must never select an elevated role');
 }
 let fixture;try{fixture=await load('business-fixture.json');}catch(e){if(e.code!=='ENOENT')throw e;}
 if(!fixture){
  const owner=accounts.find(a=>a.persona==='owner').id,cashier=accounts.find(a=>a.persona==='cashier').id;
  fixture={lounge:randomUUID(),room:randomUUID(),owner,cashier,customer:accounts.find(a=>a.persona==='customer').id,rooms:[]};
  await c.query('BEGIN');
  try {
   await c.query(`INSERT INTO public.lounges(id,owner_id,name,name_ar,name_en,status,is_active,is_open,allow_cash_payment,require_prepaid_first_time,allow_open_time_sessions,opening_time,closing_time,timezone,instapay_account)
    VALUES($1,$2,'LOCAL SYNTHETIC DEV','صالة اختبار محلية','Local synthetic lounge','active',true,true,true,false,true,'00:00','23:59','Africa/Cairo','local-synthetic@invalid')`,[fixture.lounge,owner]);
   await c.query("UPDATE public.profiles SET role='owner',lounge_id=$1,is_setup_completed=true WHERE id=$2",[fixture.lounge,owner]);
   await c.query("UPDATE public.profiles SET role='cashier',lounge_id=$1,is_setup_completed=true WHERE id=$2",[fixture.lounge,cashier]);
   await c.query("UPDATE public.profiles SET is_setup_completed=true WHERE id=$1",[fixture.customer]);
   await c.query("INSERT INTO public.lounge_staff(lounge_id,user_id,role) VALUES($1,$2,'lounge_owner'),($1,$3,'cashier') ON CONFLICT DO NOTHING",[fixture.lounge,owner,cashier]);
   for(let i=0;i<40;i++){
    const id=i===0?fixture.room:randomUUID(),pc=i%2===1,maintenance=i===39;
    await c.query(`INSERT INTO public.rooms(id,lounge_id,name,name_ar,name_en,device_type,resource_type,room_type,hourly_rate_single,hourly_rate_multi,is_available,is_active,status)
     VALUES($1,$2,$3,$4,$3,$5,$6,'standard',100,150,$7,true,$8)`,[id,fixture.lounge,`${pc?'PC':'PS5'} ${i+1}`,`${pc?'كمبيوتر':'بلايستيشن'} ${i+1} — اختبار محلي`,pc?'PC':'PS5',pc?'pc':'console',!maintenance,maintenance?'maintenance':'available']);
    fixture.rooms.push(id);
   }
   await c.query('COMMIT');
  }catch(error){await c.query('ROLLBACK');throw error;}
  await writeFile(resolve(directory,'business-fixture.json'),JSON.stringify(fixture,null,2),{mode:0o600});
 }
 // Explicit fixture owner template; no guessed global/default Production policy.
 for(const key of catalogue.keys){
  await c.query(`INSERT INTO public.lounge_role_permissions(lounge_id,role,permission_key,is_enabled)
   SELECT $1,'owner',$2,true WHERE private.permission_key_allowed_for_role('owner',$2)
   ON CONFLICT(lounge_id,role,permission_key) DO NOTHING`,[fixture.lounge,key]);
 }
 const auth=[];
 for(const account of accounts){const login=await request('/auth/v1/token?grant_type=password',status.ANON_KEY,{email:account.email,password:account.password});assert.equal(login.user.id,account.id);auth.push(account.persona);}
 await writeFile(report,JSON.stringify({environment:base,authentication:auth,signupMetadataEscalationDenied:true,rooms:fixture.rooms.length,fixture:{lounge:fixture.lounge,room:fixture.room},credentials:'Private accounts.json outside Git; not included in report',result:'Fresh real GoTrue synthetic accounts, automatic safe profiles and mixed station data ready'},null,2));
 console.log('Fresh synthetic Auth sign-ins, metadata-role rejection and 40 mixed stations passed.');
}finally{await c.end();}
