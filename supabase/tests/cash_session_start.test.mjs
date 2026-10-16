import {fixedSessionFixture} from './runtime/fixed_session_fixture.mjs';
import {readFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
const f=await fixedSessionFixture();
const {db,admin,login,reset,seedBooking,actor,room}=f;
const read=p=>readFile(new URL(p,import.meta.url),'utf8');
let passed=0;
async function fixture(method='cash',payment='unpaid',status='upcoming') {
  await reset();
  await admin('UPDATE public.lounges SET require_prepaid_first_time=false');
  const id=await seedBooking(undefined,status);
  await admin(`UPDATE public.bookings SET payment_method='${method}',payment_status='${payment}',
    sender_wallet_phone='01000000000',actual_start_time=NULL`);
  await login();
  // This disposable fixture starts in offline-writer mode. Exercise the real
  // online authority path rather than disabling its booking guard.
  await db.query('SELECT public.refresh_cashier_writer($1,$2,true)',[f.lounge,f.device]);
  return id;
}
async function start(id){return (await db.query('SELECT public.start_booking_session($1) value',[id])).rows[0].value;}
async function check(name,body){await body();passed++;console.log('PASS '+name);}
try {
  await admin(`ALTER TABLE public.shifts ADD opened_at timestamptz DEFAULT now();
    ALTER TABLE public.rooms ADD name_ar text,ADD name_en text;`);
  await db.exec(await read('./fixtures/cash_start_baseline.sql'));
  await db.exec('REVOKE ALL ON FUNCTION public.start_booking_session(uuid) FROM PUBLIC,anon; GRANT EXECUTE ON FUNCTION public.start_booking_session(uuid) TO authenticated');
  await check('baseline reproduces refusal to start an unpaid cash booking',async()=>{
    const id=await fixture();const before=await f.snapshot();
    await assert.rejects(start(id),e=>e.code==='55000'&&e.message.includes('PAYMENT_REQUIRED'));
    assert.deepEqual(await f.snapshot(),before);
  });
  await admin('');await db.exec(await read('../migrations/20261016211005_cash_session_start_before_collection.sql'));
  for (const payment of ['unpaid','partial','paid']) await check('cash '+payment+' starts without recording collection',async()=>{
    const id=await fixture('cash',payment);const before=await f.snapshot();
    const response=await start(id);const after=await f.snapshot();
    assert.equal(response.success,true);assert.equal(response.status,'in_progress');
    assert.equal(after.bookings[0].payment_status,payment);
    assert.equal(after.bookings[0].total_price,before.bookings[0].total_price);
    assert.deepEqual(after.payments,before.payments);assert.deepEqual(after.cash,before.cash);
    assert.equal(after.rooms.find(r=>r.id===room).status,'occupied');
  });
  for (const method of ['manual_transfer','wallet','card','unknown']) await check(method+' unpaid remains blocked',async()=>{
    const id=await fixture(method);const before=await f.snapshot();
    await assert.rejects(start(id),e=>e.code==='55000'&&e.message.includes('PAYMENT_REQUIRED'));
    assert.deepEqual(await f.snapshot(),before);
  });
  await check('unknown null method cannot exploit SQL null logic',async()=>{
    const id=await fixture();await admin('UPDATE public.bookings SET payment_method=NULL');await login();
    await assert.rejects(start(id),e=>e.code==='55000');
  });
  await check('refunded cash booking cannot start',async()=>{
    const id=await fixture('cash','refunded');await assert.rejects(start(id),e=>e.code==='55000');
  });
  await check('verified prepaid transfer can start',async()=>{assert.equal((await start(await fixture('manual_transfer','paid'))).success,true);});
  await check('unpaid open-time behavior is retained',async()=>{
    const id=await fixture('manual_transfer');await admin('UPDATE public.bookings SET is_open_time=true');await login();
    assert.equal((await start(id)).success,true);
  });
  await check('missing session-control permission still denies',async()=>{
    const id=await fixture();await admin("DELETE FROM public.fixture_permissions WHERE permission='sessions_control'");await login();
    await assert.rejects(start(id),e=>e.code==='42501');
  });
  await check('missing shift still denies without modifying attendance',async()=>{
    const id=await fixture();await admin("UPDATE public.shifts SET status='closed',closed_at=now()");await login();
    const before=await f.snapshot();await assert.rejects(start(id),e=>e.message==='NO_OPEN_SHIFT');
    assert.deepEqual(await f.snapshot(),before);
  });
  await check('cancelled booking remains terminal',async()=>{
    const id=await fixture('cash','unpaid','cancelled');await assert.rejects(start(id),e=>e.code==='55000');
  });
  await check('repeat start does not duplicate or reset attendance',async()=>{
    const id=await fixture();await start(id);const before=await f.snapshot();
    assert.equal((await start(id)).idempotent,true);assert.deepEqual(await f.snapshot(),before);
  });
  await check('missing authentication still denies',async()=>{
    const id=await fixture();await db.exec("SELECT set_config('test.actor','',false)");
    await assert.rejects(start(id),e=>e.code==='28000');
  });
  await check('migration retains restricted client execute privileges',async()=>{
    await admin('');
    assert.equal((await db.query("SELECT has_function_privilege('anon','public.start_booking_session(uuid)','EXECUTE') allowed")).rows[0].allowed,false);
    assert.equal((await db.query("SELECT has_function_privilege('authenticated','public.start_booking_session(uuid)','EXECUTE') allowed")).rows[0].allowed,true);
  });
  await check('manual immediate start leaves cash uncollected',async()=>{
    await reset();
    await admin(`ALTER TABLE public.bookings ALTER COLUMN id SET DEFAULT gen_random_uuid();
      UPDATE public.lounges SET require_prepaid_first_time=false;
      INSERT INTO public.fixture_permissions VALUES('${actor}','${f.lounge}','bookings_create');`);
    await login();await db.query('SELECT public.refresh_cashier_writer($1,$2,true)',[f.lounge,f.device]);
    const r=(await db.query(`SELECT public.create_manual_booking_admin($1,$2,
      (now() AT TIME ZONE 'Africa/Cairo')::date,(now() AT TIME ZONE 'Africa/Cairo')::time,
      60,'Synthetic walk-in',NULL,'single','[]',true) value`,[f.lounge,room])).rows[0].value;
    const after=await f.snapshot();assert.equal(r.success,true);assert.equal(r.started,true);
    assert.equal(after.bookings[0].status,'in_progress');assert.equal(after.bookings[0].payment_status,'unpaid');
    assert.equal(after.payments,null);assert.equal(after.cash,null);
  });
  console.log(JSON.stringify({passed,hostedConnections:0}));
} finally {await db.close();}
