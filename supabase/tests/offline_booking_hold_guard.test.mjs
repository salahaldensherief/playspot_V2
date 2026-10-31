import {fixedSessionFixture} from './runtime/fixed_session_fixture.mjs';
import {readFile} from 'node:fs/promises';
import {randomUUID} from 'node:crypto';
import assert from 'node:assert/strict';
const f=await fixedSessionFixture();const {db,admin,lounge,room}=f;let passed=0;
const insert=async()=>db.query("INSERT INTO public.booking_holds(id,lounge_id,room_id,start_at,end_at,expires_at) VALUES($1,$2,$3,now()::timestamp,now()::timestamp+interval '1 hour',now()+interval '10 minutes') RETURNING id",[randomUUID(),lounge,room]);
const check=async(name,body)=>{await f.reset();await admin("DELETE FROM public.booking_holds;UPDATE public.lounges SET is_open=true;UPDATE private.cashier_writer_authorities SET online_requested=true,heartbeat_expires_at=now()+interval '90 seconds'");await body();passed++;console.log('PASS '+name);};
try {
 await admin('CREATE TABLE public.booking_holds(id uuid PRIMARY KEY,lounge_id uuid,room_id uuid,start_at timestamp,end_at timestamp,expires_at timestamptz,released_at timestamptz)');
 await db.exec(await readFile(new URL('../migrations/20261004154405_offline_booking_hold_guard.sql',import.meta.url),'utf8'));
 await check('healthy writer admits a new hold',async()=>assert.equal((await insert()).rows.length,1));
 await check('offline writer refuses a hold before it blocks local capacity',async()=>{await admin('UPDATE private.cashier_writer_authorities SET online_requested=false');await assert.rejects(insert(),e=>e.code==='55000'&&e.message==='LOUNGE_OFFLINE');assert.equal((await db.query('SELECT count(*)::int AS count FROM public.booking_holds')).rows[0].count,0);});
 await check('expired heartbeat refuses hold renewal',async()=>{await insert();await admin("UPDATE private.cashier_writer_authorities SET heartbeat_expires_at=now()-interval '1 second'");await assert.rejects(db.query("UPDATE public.booking_holds SET expires_at=now()+interval '30 minutes'"),e=>e.message==='LOUNGE_OFFLINE');});
 await check('existing hold can still be released while lounge is offline',async()=>{await insert();await admin('UPDATE private.cashier_writer_authorities SET online_requested=false');assert.equal((await db.query('UPDATE public.booking_holds SET released_at=now() RETURNING id')).rows.length,1);});
 await check('foreign room scope is rejected',async()=>{await admin(`UPDATE public.rooms SET lounge_id='${f.otherLounge}'`);await assert.rejects(insert(),e=>e.code==='42501');});
 await check('legacy venue without writer retains its existing hold policy',async()=>{await admin('DELETE FROM private.cashier_writer_authorities');assert.equal((await insert()).rows.length,1);});
 await check('guard function cannot be called by API or system roles',async()=>{await admin('');for(const role of ['anon','authenticated','service_role','supabase_auth_admin'])assert.equal((await db.query("SELECT has_function_privilege($1,'private.guard_cashier_online_hold()','execute') AS allowed",[role])).rows[0].allowed,false);});
 if(db.connect)await check('busy offline writer refuses immediately instead of a room/lounge deadlock',async()=>{
   const writer=await db.connect();try{await writer.query('BEGIN');await writer.query('SELECT private.lock_cashier_lounge($1)',[lounge]);await assert.rejects(insert(),e=>e.code==='55P03'&&e.message==='CASHIER_WRITER_BUSY_RETRY');}finally{await writer.query('ROLLBACK');await writer.end();}
 });
 console.log(JSON.stringify({passed}));
}finally{await db.close();}
