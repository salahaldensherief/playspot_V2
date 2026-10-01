import {fixedSessionFixture} from './runtime/fixed_session_fixture.mjs';
import {lockedRace} from './runtime/locked_race.mjs';
import {randomUUID} from 'node:crypto';
import {writeFile} from 'node:fs/promises';
import assert from 'node:assert/strict';

const f=await fixedSessionFixture();let passed=0;
const {db,actor,customer,lounge,otherLounge,room,shift,otherShift,booking,product,start,admin,login,reset,operation,request,send,snapshot,seedBooking}=f;
const at=minutes=>new Date(start+minutes*60000).toISOString();
async function check(name,body) {await reset();await body();passed++;console.log('PASS '+name);}
async function conflict(op,code) {const before=await snapshot();const r=await send(op);assert.equal(r.status,'conflict');
 assert.equal(r.code,code);assert.deepEqual(await snapshot(),before);return r;}
async function reserve() {assert.equal((await send(operation())).status,'applied');}
async function begin() {await reserve();assert.equal((await send(operation('start',2,{occurred_at:at(1)}))).status,'applied');}
try {
 await check('walk-in can reserve without account even when first registered customer must prepay',async()=>{
  const op=operation(),r=await send(op);assert.equal(r.status,'applied');assert.equal(r.session_receipt.status,'upcoming');
  assert.equal(r.session_receipt.total_minor,10000);assert.equal(r.session_receipt.paid_minor,0);
  const s=await snapshot();assert.equal(s.bookings[0].user_id,null);assert.equal(s.bookings[0].is_first_booking,false);
  assert.equal(s.payments,null);assert.equal(s.cash,null);assert.equal(s.contexts,0);
  if(process.env.PLAYSPOT_FIXED_CONTRACT_EXPORT) await writeFile(process.env.PLAYSPOT_FIXED_CONTRACT_EXPORT,
   JSON.stringify({reserve:{operation:op,response:r}},null,2)+'\n','utf8');
 });
 await check('registered first customer still cannot bypass prepaid policy',async()=>{
  await login();await db.query('SELECT public.refresh_cashier_writer($1,$2,true)',[lounge,f.device]);
  await admin('');await assert.rejects(db.query(`INSERT INTO public.bookings(id,user_id,lounge_id,room_id,date,start_time,end_time,status,total_price,payment_method)
   VALUES($1,$2,$3,$4,'2024-01-01','10:00','11:00','cancelled',100,'cash')`,[randomUUID(),customer,lounge,room]),
   e=>e.code==='P0001'&&e.message.includes('First booking'));
 });
 await check('offline reservation cannot invent an implicit cash payment',async()=>{
  await reserve();const s=await snapshot();assert.equal(s.bookings[0].payment_status,'unpaid');assert.equal(s.payments,null);
 });
 await check('unprivileged customer cannot disguise a first booking as an account-free walk-in',async()=>{
  await login();await db.query('SELECT public.refresh_cashier_writer($1,$2,true)',[lounge,f.device]);
  await admin(`SET test.actor='${customer}'`);
  await assert.rejects(db.query(`INSERT INTO public.bookings(id,user_id,lounge_id,room_id,date,start_time,end_time,status,total_price,payment_method)
   VALUES($1,NULL,$2,$3,'2024-01-01','10:00','11:00','cancelled',100,'cash')`,[randomUUID(),lounge,room]),
   e=>e.code==='42501'&&e.message==='WALK_IN_BOOKING_PERMISSION_DENIED');
  assert.equal((await snapshot()).bookings,null);
 });
 await check('same reservation replay neither creates another booking nor advances twice',async()=>{
  const op=operation();await send(op);const before=await snapshot();assert.equal((await send(op)).status,'replayed');assert.deepEqual(await snapshot(),before);
 });
 await check('overlapping reservation rolls back and blocks later sequences',async()=>{
  await reserve();await conflict(operation('reserve',2,{booking_id:randomUUID()}),'OFFLINE_ROOM_CONFLICT');
  assert.equal((await send(operation('start',3,{occurred_at:at(1)}))).code,'OFFLINE_SEQUENCE_GAP');
 });
 await check('adjacent room bookings do not falsely overlap',async()=>{
  await reserve();const op=operation('reserve',2,{booking_id:randomUUID(),payload:{...operation().payload,start_ms:start+3600000,end_ms:start+7200000}});
  assert.equal((await send(op)).status,'applied');assert.equal((await snapshot()).bookings.length,2);
 });
 await check('room tariff drift refuses the saved local quote',async()=>{
  await admin(`UPDATE public.rooms SET hourly_rate_single=120`);await conflict(operation(),'OFFLINE_BOOKING_PRICE_CHANGED');
 });
 for(const patch of [{customer_name:null},{customer_name:1},{customer_name:''},{customer_name:'x'.repeat(121)},
  {customer_phone:1},{customer_phone:'1'.repeat(33)}]) await check('invalid walk-in identity '+JSON.stringify(patch),async()=>{
  const op=operation();Object.assign(op.payload,patch);await conflict(op,'INVALID_OFFLINE_BOOKING');
 });
 await check('mismatched reservation snapshot rolls back insertion and private proof contexts',async()=>{
  const op=operation();op.quoted_session.room_id=randomUUID();await conflict(op,'OFFLINE_SESSION_SNAPSHOT_CHANGED');
 });
 for(const patch of [{status:'maintenance'},{is_active:false},{is_available:false}]) await check('room eligibility '+JSON.stringify(patch),async()=>{
  const [key,value]=Object.entries(patch)[0];await admin(`UPDATE public.rooms SET ${key}=${typeof value==='string'?"'"+value+"'":value}`);
  await conflict(operation(),'OFFLINE_ROOM_UNAVAILABLE');
 });
 await check('other venue room cannot be reserved',async()=>{
  await admin(`UPDATE public.rooms SET lounge_id='${otherLounge}'`);await conflict(operation(),'OFFLINE_ROOM_UNAVAILABLE');
 });
 await check('cash-disabled lounge remains protected for walk-ins',async()=>{
  await admin(`UPDATE public.lounges SET allow_cash_payment=false WHERE id='${lounge}'`);await conflict(operation(),'OFFLINE_CASH_BOOKING_DISABLED');
 });
 await check('caller timezone must match venue timezone',async()=>{
  const op=operation();op.payload.timezone='Asia/Dubai';await conflict(op,'INVALID_LOUNGE_TIMEZONE');
 });
 for(const patch of [{start_ms:start+1},{end_ms:start+3600001},{end_ms:start},{end_ms:start+86460000},{start_ms:'1'}])
  await check('invalid interval '+JSON.stringify(patch),async()=>{
   const op=operation();Object.assign(op.payload,patch);await conflict(op,'INVALID_OFFLINE_BOOKING_INTERVAL');
  });
 await check('61 actual minutes use canonical cent rounding rather than open-time quantum',async()=>{
  const op=operation();op.payload.end_ms=start+61*60000;op.quoted_session.end_ms=op.payload.end_ms;op.quoted_total_minor=10167;
  const r=await send(op);assert.equal(r.status,'applied');assert.equal(r.session_receipt.total_minor,10167);
 });
 await check('overnight booking preserves the full UTC planned interval',async()=>{
  const from=Date.UTC(2026,8,30,20,30);await f.issuePermit(from-3600000);const op=operation('reserve',1,{occurred_at:new Date(from).toISOString(),
   payload:{...operation().payload,start_ms:from,end_ms:from+3600000}});const r=await send(op);
  assert.equal(r.status,'applied');assert.equal(r.session_receipt.start_ms,from);assert.equal(r.session_receipt.end_ms,from+3600000);
 });
 await check('DST-crossing interval is retained for review instead of billing the wrong duration',async()=>{
  const from=Date.UTC(2026,3,23,21,30);await f.issuePermit(from-3600000);const op=operation('reserve',1,{occurred_at:new Date(from).toISOString(),
   payload:{...operation().payload,start_ms:from,end_ms:from+3600000}});
  await conflict(op,'OFFLINE_DST_INTERVAL_REQUIRES_REVIEW');
 });
 await check('existing tournament room allocation cannot be consumed by offline reservation',async()=>{
  await admin(`INSERT INTO public.tournament_matches(room_id,status,scheduled_at,scheduled_end_at)
   VALUES('${room}','scheduled',to_timestamp(${start}/1000.0),to_timestamp(${start+3600000}/1000.0))`);
  await conflict(operation(),'OFFLINE_TOURNAMENT_ROOM_CONFLICT');
 });
 await check('starting recorded session uses original event time and does not collect',async()=>{
  await reserve();const op=operation('start',2,{occurred_at:at(1)}),r=await send(op);assert.equal(r.status,'applied');
  assert.equal(r.session_receipt.status,'in_progress');assert.equal(Date.parse(r.session_receipt.started_at),start+60000);
  const s=await snapshot();assert.equal(s.rooms[0].status,'occupied');assert.equal(s.payments,null);assert.equal(s.contexts,0);
 });
 await check('session-control permission starts without booking-management permission',async()=>{
  await reserve();await admin(`DELETE FROM public.fixture_permissions WHERE permission='bookings.manage'`);
  assert.equal((await send(operation('start',2,{occurred_at:at(1)}))).status,'applied');
 });
 await check('canonical super admin reconciles reserve/start/cash/close without staff grants',async()=>{
  await admin(`UPDATE public.profiles SET role='super_admin' WHERE id='${actor}';DELETE FROM public.fixture_permissions`);
  await begin();assert.equal((await send(operation('collectCash',3,{occurred_at:at(2),payload:{amount_minor:5000}}))).status,'applied');
  const op=operation('close',4,{occurred_at:at(10)});op.quoted_session.paid_minor=5000;
  assert.equal((await send(op)).status,'applied');
 });
 await check('missing session snapshot never acknowledges a transition',async()=>{
  await reserve();const op=operation('start',2,{occurred_at:at(1)});delete op.quoted_session;
  await conflict(op,'OFFLINE_SESSION_SNAPSHOT_REQUIRED');
 });
 await check('rescheduled server booking refuses the old offline start snapshot',async()=>{
  await reserve();await login();await db.query('SELECT public.refresh_cashier_writer($1,$2,true)',[lounge,f.device]);
  await admin(`UPDATE public.bookings SET start_time=start_time+interval '1 minute',end_time=end_time+interval '1 minute'`);
  await login();await db.query('SELECT public.refresh_cashier_writer($1,$2,false)',[lounge,f.device]);
  await conflict(operation('start',2,{occurred_at:at(1)}),'OFFLINE_SESSION_SNAPSHOT_CHANGED');
 });
 await check('incorrect saved start event cannot mutate the session',async()=>{
  await reserve();const op=operation('start',2,{occurred_at:at(1)});op.quoted_session.started_ms+=1;
  await conflict(op,'OFFLINE_SESSION_SNAPSHOT_CHANGED');
 });
 for(const minute of [-1,60]) await check('start outside booked window '+minute,async()=>{
  await reserve();await conflict(operation('start',2,{occurred_at:at(minute)}),'OFFLINE_SESSION_OUTSIDE_BOOKED_WINDOW');
 });
 await check('an overdue physical session still prevents a second session starting',async()=>{
  await seedBooking(randomUUID(),'in_progress',start-7200000,start-3600000);await reserve();
  await conflict(operation('start',2,{occurred_at:at(1)}),'OFFLINE_ROOM_STILL_OCCUPIED');
 });
 await check('shift belonging to another cashier cannot receive reservation',async()=>await conflict(operation('reserve',1,{shift_id:otherShift}),'OWN_OPEN_SHIFT_REQUIRED'));
 await check('closed shift cannot start recorded session',async()=>{
  await reserve();await admin(`UPDATE public.shifts SET status='closed',closed_at=now() WHERE id='${shift}'`);
  await conflict(operation('start',2,{occurred_at:at(1)}),'OWN_OPEN_SHIFT_REQUIRED');
 });
 await check('early close preserves planned duration, price and unpaid debt while releasing capacity',async()=>{
  await begin();const op=operation('close',3,{occurred_at:at(10)}),r=await send(op);assert.equal(r.status,'applied');
  assert.equal(r.session_receipt.status,'completed');assert.equal(r.session_receipt.capacity_end_ms,start+600000);
  assert.equal(r.session_receipt.end_ms,start+3600000);assert.equal(r.session_receipt.total_minor,10000);
  assert.equal(r.session_receipt.due_minor,10000);const s=await snapshot();assert.equal(s.rooms[0].status,'available');
  assert.equal(s.bookings[0].duration_minutes,60);assert.equal(s.payments,null);
  const next=operation('reserve',4,{booking_id:randomUUID(),occurred_at:at(10),
   payload:{...operation().payload,start_ms:start+600000,end_ms:start+4200000}});
  assert.equal((await send(next)).status,'applied');
 });
 await check('completed actual occupancy remains protected against overlapping historical reservations',async()=>{
  await begin();await send(operation('close',3,{occurred_at:at(10)}));
  const op=operation('reserve',4,{booking_id:randomUUID(),occurred_at:at(9),
   payload:{...operation().payload,start_ms:start+540000,end_ms:start+4140000}});await conflict(op,'OFFLINE_ROOM_CONFLICT');
 });
 await check('legacy completed rows retain their planned capacity until explicitly reconciled',async()=>{
  await seedBooking();await conflict(operation(),'OFFLINE_ROOM_CONFLICT');
 });
 await check('close before recorded start is rejected without releasing room',async()=>{
  await begin();await conflict(operation('close',3,{occurred_at:at(0)}),'OFFLINE_SESSION_NOT_READY_TO_CLOSE');
 });
 await check('stale paid-balance snapshot cannot close after a separate cash collection',async()=>{
  await begin();assert.equal((await send(operation('collectCash',3,{occurred_at:at(2),payload:{amount_minor:5000}}))).status,'applied');
  await conflict(operation('close',4,{occurred_at:at(10)}),'OFFLINE_SESSION_SNAPSHOT_CHANGED');
 });
 await check('microsecond close event produces an exact integer millisecond capacity receipt',async()=>{
  await begin();const occurred=new Date(start+600123).toISOString().replace('.123Z','.123456Z');
  const r=await send(operation('close',3,{occurred_at:occurred}));assert.equal(r.status,'applied');
  assert.equal(r.session_receipt.capacity_end_ms,start+600123);
  assert.equal(Date.parse(r.session_receipt.closed_at),start+600123);
 });
 await check('maintenance stays maintenance after close',async()=>{
  await begin();await admin(`UPDATE public.rooms SET status='maintenance',is_available=false`);
  assert.equal((await send(operation('close',3,{occurred_at:at(10)}))).status,'applied');assert.equal((await snapshot()).rooms[0].status,'maintenance');
 });
 await check('changed tariff during close rolls back status and capacity release',async()=>{
  await begin();await admin(`UPDATE public.rooms SET hourly_rate_single=120`);
  await conflict(operation('close',3,{occurred_at:at(10)}),'OFFLINE_BOOKING_PRICE_CHANGED');
 });
 await check('cash collection cannot silently reprice a booking through the hosted trigger',async()=>{
  await begin();await admin(`UPDATE public.rooms SET hourly_rate_single=120`);
  await conflict(operation('collectCash',3,{occurred_at:at(2),payload:{amount_minor:5000}}),'BOOKING_PRICE_CHANGED_DURING_COLLECTION');
 });
 await check('untrusted direct capacity edits cannot free a room',async()=>{
  await begin();await admin('GRANT UPDATE,SELECT ON public.bookings TO authenticated');const before=await snapshot();await login();
  await assert.rejects(db.query('UPDATE public.bookings SET status=$1,cashier_closed_at=$2 WHERE id=$3',['completed',at(10),booking]),e=>e.code==='42501');
  assert.deepEqual(await snapshot(),before);
 });
 await check('full recorded flow reconciles order, partial cash and early close without duplicate money',async()=>{
  const exports={};const res=operation();exports.reserve={operation:res,response:await send(res)};
  const started=operation('start',2,{occurred_at:at(1)});exports.start={operation:started,response:await send(started)};
  const order=operation('addItems',3,{occurred_at:at(2),payload:{items:[{product_id:product,quantity:2}]},
   quoted_items:[{product_id:product,quantity:2,unit_price_minor:1500}],quoted_total_minor:13000});
  exports.order={operation:order,response:await send(order)};assert.equal(exports.order.response.status,'applied');
  const cash=operation('collectCash',4,{occurred_at:at(3),payload:{amount_minor:5000}});
  exports.cash={operation:cash,response:await send(cash)};assert.equal(exports.cash.response.status,'applied');
  const closed=operation('close',5,{occurred_at:at(10),quoted_total_minor:13000});closed.quoted_session.paid_minor=5000;
  exports.close={operation:closed,response:await send(closed)};
  assert.equal(exports.close.response.status,'applied');assert.equal(exports.close.response.session_receipt.paid_minor,5000);
  assert.equal(exports.close.response.session_receipt.due_minor,8000);const s=await snapshot();assert.equal(s.cash.length,1);assert.equal(s.payments[0].amount,50);
  await admin(`UPDATE public.shifts SET status='closed',closed_at=now() WHERE id='${shift}'`);const before=await snapshot();
  assert.equal((await send(closed)).status,'replayed');assert.deepEqual(await snapshot(),before);
  if(process.env.PLAYSPOT_FIXED_CONTRACT_EXPORT) await writeFile(process.env.PLAYSPOT_FIXED_CONTRACT_EXPORT,JSON.stringify(exports,null,2)+'\n','utf8');
 });
 if(db.connect) await check('simultaneous reservation retries actually wait and commit exactly one booking',async()=>{
  const op=operation();await admin('');const [a,b]=await lockedRace(db,request(op),request(op),actor);
  assert.equal(a.rows[0].receipt.status,'applied');assert.equal(b.error,undefined);assert.equal(b.value.rows[0].receipt.status,'replayed');
  assert.equal((await snapshot()).bookings.length,1);
 });
 console.log(JSON.stringify({passed,limitations:['Source only; no hosted writes or UI enablement',
  'Synthetic Auth/permissions and incomplete hosted audit/moderation/loyalty triggers',
  'DST-crossing/ambiguous intervals retained for review; advanced pricing and open time excluded',
  'New capacity index requires deployment planning and discovery adapter changes']}));
} finally {await db.close();}
