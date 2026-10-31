import {fixedSessionFixture} from './runtime/fixed_session_fixture.mjs';
import {readFile} from 'node:fs/promises';
import {randomUUID} from 'node:crypto';
import assert from 'node:assert/strict';
const f=await fixedSessionFixture();const {db,admin,lounge}=f;let passed=0;
const status=async()=>{await admin('SET ROLE anon');return (await db.query('SELECT public.get_lounge_operating_status($1) AS status',[lounge])).rows[0].status;};
const check=async(name,body)=>{await f.reset();await admin(`UPDATE public.lounges SET is_open=true,contact_phone='01000000000';UPDATE private.cashier_writer_authorities SET online_requested=true,heartbeat_expires_at=now()+interval '90 seconds';`);await body();passed++;console.log('PASS '+name);};
try {
 await admin('ALTER TABLE public.lounges ADD contact_phone text');
 await db.exec(await readFile(new URL('../migrations/20261004153152_lounge_public_operating_status.sql',import.meta.url),'utf8'));
 await check('connected lounge reports open',async()=>{assert.deepEqual(await status(),{status:'open',can_book_online:true,contact_phone:null});});
 await check('expired heartbeat during open shift reports technical issue and venue phone',async()=>{await admin("UPDATE private.cashier_writer_authorities SET heartbeat_expires_at=now()-interval '1 second'");assert.deepEqual(await status(),{status:'technical_issue',can_book_online:false,contact_phone:'01000000000'});});
 await check('local operation during open shift reports technical issue',async()=>{await admin('UPDATE private.cashier_writer_authorities SET online_requested=false');assert.equal((await status()).status,'technical_issue');});
 await check('no open shift never reports technical issue',async()=>{await admin("UPDATE public.shifts SET status='closed',closed_at=now();UPDATE private.cashier_writer_authorities SET online_requested=false");assert.deepEqual(await status(),{status:'closed',can_book_online:false,contact_phone:null});});
 await check('manual closure takes precedence over disconnection',async()=>{await admin('UPDATE public.lounges SET is_open=false;UPDATE private.cashier_writer_authorities SET online_requested=false');assert.equal((await status()).status,'closed');});
 await check('inactive venue does not leak phone',async()=>{await admin('UPDATE public.lounges SET is_active=false');assert.deepEqual(await status(),{status:'unavailable',can_book_online:false,contact_phone:null});});
 await check('banned writer is not presented as a network outage',async()=>{await admin('UPDATE public.profiles SET is_banned=true;UPDATE private.cashier_writer_authorities SET online_requested=false');assert.equal((await status()).status,'closed');});
 await check('empty contact phone is never invented',async()=>{await admin("UPDATE public.lounges SET contact_phone=' ';UPDATE private.cashier_writer_authorities SET online_requested=false");assert.equal((await status()).contact_phone,null);});
 await check('unknown lounge leaks no data',async()=>{await admin('SET ROLE anon');const r=(await db.query('SELECT public.get_lounge_operating_status($1) AS status',[randomUUID()])).rows[0].status;assert.equal(r.status,'unavailable');assert.equal(r.contact_phone,null);});
 await check('public response exposes only three intended fields and grants',async()=>{assert.deepEqual(Object.keys(await status()).sort(),['can_book_online','contact_phone','status']);await admin('');for(const role of ['anon','authenticated','service_role','supabase_auth_admin'])assert.equal((await db.query("SELECT has_function_privilege($1,'public.get_lounge_operating_status(uuid)','execute') AS allowed",[role])).rows[0].allowed,['anon','authenticated'].includes(role));});
 console.log(JSON.stringify({passed}));
}finally{await db.close();}
