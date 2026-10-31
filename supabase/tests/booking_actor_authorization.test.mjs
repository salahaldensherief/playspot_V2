import {fixedSessionFixture} from './runtime/fixed_session_fixture.mjs';
import {readFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
const f=await fixedSessionFixture();
const {db,admin,lounge,room,customer}=f;
const read=path=>readFile(new URL(path,import.meta.url),'utf8');
let passed=0;
async function hold(){
 return db.query(`SELECT public.acquire_booking_hold(ARRAY[$1]::uuid[],
 ((now() AT TIME ZONE 'Africa/Cairo')::date+1)+'10:00'::time,
 ((now() AT TIME ZONE 'Africa/Cairo')::date+1)+'11:00'::time) result`,[room]);
}
async function quote(){return db.query("SELECT public.quote_my_booking_checkout('30000000-0000-0000-0000-000000000001','[]')");}
async function checkout(){return db.query("SELECT public.create_my_booking_checkout('30000000-0000-0000-0000-000000000001','[]','[]',NULL,'invalid')");}
async function check(name,body){
 await f.reset();
 await admin(`INSERT INTO auth.users VALUES('${customer}') ON CONFLICT DO NOTHING;
 UPDATE public.lounges SET is_open=true,allow_future_bookings=true,allow_request_without_shift=true;
 DELETE FROM public.shifts; DELETE FROM public.booking_holds;
 SET test.actor='${customer}'; SET ROLE authenticated;`);
 await body();passed++;console.log('PASS '+name);
}
try{
 await admin(`ALTER TABLE public.lounges ADD opening_time time,ADD closing_time time,
 ADD allow_future_bookings boolean DEFAULT true,ADD allow_request_without_shift boolean DEFAULT true,
 ADD future_booking_max_days_advance integer DEFAULT 14;
 ALTER TABLE public.bookings ADD confirmation_status text DEFAULT 'confirmed';
 ALTER TABLE public.rooms ADD pricing_model text DEFAULT 'single_multi_hour';`);
 await db.exec(await read('../migrations/20260927000010_real_booking_holds.sql'));
 await db.exec(await read('../migrations/20261009000001_booking_hold_occupied_room_capacity.sql'));
 await db.exec(await read('./fixtures/hosted_checkout_actor_contract.sql'));
 await db.exec(`CREATE FUNCTION private.build_my_booking_checkout_quote(uuid,uuid,jsonb,jsonb,text)
 RETURNS jsonb LANGUAGE plpgsql AS $$BEGIN RAISE EXCEPTION 'ELIGIBLE_QUOTE_REACHED'; END$$;`);
 if(!process.env.PLAYSPOT_BOOKING_ACTOR_BASELINE)
  await db.exec(await read('../migrations/20261010134409_eligible_booking_hold_and_checkout_actor.sql'));
 for(const [name,change] of [
  ['banned',`UPDATE public.profiles SET is_banned=true WHERE id='${customer}'`],
  ['inactive',`UPDATE public.profiles SET is_active=false WHERE id='${customer}'`],
  ['unknown eligibility',`UPDATE public.profiles SET is_active=NULL,is_banned=NULL WHERE id='${customer}'`],
  ['deleted Auth identity',`DELETE FROM auth.users WHERE id='${customer}'`],
 ]){
  await check(name+' actor cannot acquire, quote or checkout',async()=>{
   await admin(change+`;SET test.actor='${customer}';SET ROLE authenticated;`);
   for(const call of [hold,quote,checkout])await assert.rejects(call(),error=>error.code==='42501');
   await admin('');
   assert.equal((await db.query('SELECT count(*)::int n FROM public.booking_holds')).rows[0].n,0);
   assert.equal((await db.query('SELECT count(*)::int n FROM public.bookings')).rows[0].n,0);
  });
 }
 await check('eligible actor can acquire a future request hold',async()=>{
  assert.equal((await hold()).rows[0].result.success,true);
 });
 await check('eligible quote reaches the existing pricing boundary',async()=>{
  await assert.rejects(quote(),/ELIGIBLE_QUOTE_REACHED/);
 });
 await check('eligible checkout retains payment-method validation',async()=>{
  await assert.rejects(checkout(),error=>error.code==='22023'&&error.message==='Invalid payment method');
 });
 await check('absent JWT actor retains authentication failure',async()=>{
  await db.exec("SET test.actor=''");
  for(const call of [hold,quote,checkout])await assert.rejects(call(),error=>error.code==='28000');
 });
 await check('reapplication preserves RPC grants and cannot duplicate the guard',async()=>{
  await admin('');
  const before=(await db.query("SELECT proname,proacl::text acl FROM pg_proc WHERE pronamespace='public'::regnamespace AND proname IN ('acquire_booking_hold','quote_my_booking_checkout','create_my_booking_checkout') ORDER BY proname")).rows;
  await db.exec(await read('../migrations/20261010134409_eligible_booking_hold_and_checkout_actor.sql'));
  const after=(await db.query("SELECT proname,proacl::text acl FROM pg_proc WHERE pronamespace='public'::regnamespace AND proname IN ('acquire_booking_hold','quote_my_booking_checkout','create_my_booking_checkout') ORDER BY proname")).rows;
  assert.deepEqual(after,before);
  assert.equal((await db.query("SELECT has_function_privilege('authenticated','private.require_active_booking_actor()','EXECUTE') allowed")).rows[0].allowed,false);
  const definitions=(await db.query("SELECT pg_get_functiondef(oid) definition FROM pg_proc WHERE pronamespace='public'::regnamespace AND proname IN ('acquire_booking_hold','quote_my_booking_checkout','create_my_booking_checkout')")).rows;
  for(const {definition} of definitions)assert.equal(definition.split('PERFORM private.require_active_booking_actor();').length-1,1);
 });
 console.log(JSON.stringify({passed,limitations:'Synthetic PostgreSQL authorization tests; quote spy is not full checkout or real Auth E2E'}));
}finally{await db.close();}
