import {fixedSessionFixture} from './runtime/fixed_session_fixture.mjs';
import {readFile} from 'node:fs/promises';
import {randomUUID} from 'node:crypto';
import assert from 'node:assert/strict';

const f=await fixedSessionFixture();
const {db,admin,lounge,room,actor,customer,device,shift}=f;
let passed=0;
const read=path=>readFile(new URL(path,import.meta.url),'utf8');
async function hold(start='10:00',end='11:00',user=customer){
 await admin(`SET test.actor='${user}';SET ROLE authenticated;`);
 return (await db.query(`SELECT public.acquire_booking_hold(ARRAY[$1]::uuid[],
  ((now() AT TIME ZONE 'Africa/Cairo')::date+1)+$2::time,
  ((now() AT TIME ZONE 'Africa/Cairo')::date+1)+$3::time) AS result`,[room,start,end])).rows[0].result;
}
async function check(name,body){
 await f.reset();await admin(`DELETE FROM public.booking_holds;
  UPDATE public.lounges SET is_open=true,allow_future_bookings=true,allow_request_without_shift=true;
  INSERT INTO public.fixture_permissions VALUES('${actor}','${lounge}','bookings.view');
  SET test.actor='${actor}';`);
 await db.query('SELECT public.bootstrap_offline_cashier($1,$2,true)',[lounge,device]);
 await body();passed++;console.log('PASS '+name);
}
async function booking(start,end,status='upcoming'){
 await admin(`INSERT INTO public.bookings(id,user_id,lounge_id,room_id,date,start_time,end_time,status,shift_id,total_price)
  VALUES('${randomUUID()}','${customer}','${lounge}','${room}',
  (now() AT TIME ZONE 'Africa/Cairo')::date+1,'${start}','${end}','${status}','${shift}',100);`);
}
try{
 await admin(`ALTER TABLE public.lounges ADD opening_time time,ADD closing_time time,
  ADD allow_future_bookings boolean DEFAULT true,ADD allow_request_without_shift boolean DEFAULT true,
  ADD future_booking_max_days_advance integer DEFAULT 14;
  ALTER TABLE public.bookings ADD confirmation_status text DEFAULT 'confirmed';`);
 await admin("ALTER TABLE public.rooms ADD pricing_model text DEFAULT 'single_multi_hour'");
 await db.exec(await read('../migrations/20260927000010_real_booking_holds.sql'));
 for(const path of ['../repairs/offline_cashier_bootstrap.sql',
  '../migrations/20261004151006_cashier_writer_generation_handover.sql',
  '../migrations/20261009000002_cashier_writer_renewal_without_mode_change.sql'])await db.exec(await read(path));
 await db.exec(await read('./fixtures/hosted_booking_hold_contract.sql'));
 await db.exec(await read('../migrations/20261004154405_offline_booking_hold_guard.sql'));
 if(!process.env.PLAYSPOT_HOLD_BASELINE)await db.exec(await read('../migrations/20261009000001_booking_hold_occupied_room_capacity.sql'));
 await check('occupied room accepts a nonoverlapping future hold',async()=>{
  await booking('08:00','09:00','in_progress');
  await admin("UPDATE public.rooms SET status='occupied',is_available=false");
  assert.equal((await hold()).success,true);
 });
 await check('occupied room rejects overlapping confirmed booking',async()=>{
  await booking('10:00','11:00','in_progress');
  await admin("UPDATE public.rooms SET status='occupied',is_available=false");
  assert.equal((await hold()).error_code,'SLOT_OVERLAP_CONFLICT');
 });
 await check('maintenance rejects even an inconsistent available flag',async()=>{
  await admin("UPDATE public.rooms SET status='maintenance',is_available=true");
  await assert.rejects(hold(),e=>e.code==='23514');
 });
 await check('administratively disabled available room rejects',async()=>{
  await admin("UPDATE public.rooms SET status='available',is_available=false");
  await assert.rejects(hold(),e=>e.code==='23514');
 });
 await check('inactive occupied room rejects',async()=>{
  await admin("UPDATE public.rooms SET status='occupied',is_available=false,is_active=false");
  await assert.rejects(hold(),e=>e.code==='23514');
 });
 await check('other customer active hold rejects overlap',async()=>{
  assert.equal((await hold()).success,true);
  assert.equal((await hold('10:30','11:30',actor)).error_code,'SLOT_HELD_BY_ANOTHER_USER');
 });
 await check('adjacent booking periods do not overlap',async()=>{
  await booking('09:00','10:00');assert.equal((await hold()).success,true);
 });
 await check('offline writer barrier is preserved for future occupied room',async()=>{
  await admin(`SET test.actor='${actor}';`);
  await db.query('SELECT public.bootstrap_offline_cashier($1,$2,false)',[lounge,device]);
  await admin("UPDATE public.rooms SET status='occupied',is_available=false");
  await assert.rejects(hold(),e=>e.code==='55000'&&e.message==='LOUNGE_OFFLINE');
 });
 if(process.env.PLAYSPOT_NATIVE_PG_PORT)await check('concurrent customers cannot hold the same future interval',async()=>{
  const peer=await db.connect();let competing;
  try{
   const pid=(await peer.query('SELECT pg_backend_pid() AS pid')).rows[0].pid;
   await db.query('BEGIN');assert.equal((await hold()).success,true);
   await db.query('RESET ROLE');
   await peer.query(`BEGIN;SET test.actor='${actor}';SET ROLE authenticated;`);
   competing=peer.query(`SELECT public.acquire_booking_hold(ARRAY[$1]::uuid[],
    ((now() AT TIME ZONE 'Africa/Cairo')::date+1)+time '10:00',
    ((now() AT TIME ZONE 'Africa/Cairo')::date+1)+time '11:00') AS result`,[room]);
   let waiting=false;
   for(let i=0;i<50;i++){
    await db.query('SELECT pg_stat_clear_snapshot()');
    waiting=(await db.query('SELECT wait_event_type FROM pg_stat_activity WHERE pid=$1',[pid])).rows[0]?.wait_event_type==='Lock';
    if(waiting)break;await new Promise(resolve=>setTimeout(resolve,20));
   }
   assert.equal(waiting,true,'second request must serialize behind room mutex');
   await db.query('COMMIT');
   assert.equal((await competing).rows[0].result.error_code,'SLOT_HELD_BY_ANOTHER_USER');
   await peer.query('COMMIT');
  }finally{
   await db.query('ROLLBACK');await peer.query('ROLLBACK');await peer.end();
  }
 });
 console.log(JSON.stringify({passed}));
}finally{await db.close();}
