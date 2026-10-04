import {fixedSessionFixture} from './runtime/fixed_session_fixture.mjs';
import {readFile, writeFile} from 'node:fs/promises';
import {randomUUID} from 'node:crypto';
import assert from 'node:assert/strict';

const f = await fixedSessionFixture();
const {db, actor, lounge, otherLounge, room, shift, product, admin, login} = f;
let passed = 0;
const read = file => readFile(new URL(file, import.meta.url), 'utf8');
const load = async (venue = lounge, online = false) => {
  await login();
  return (await db.query('SELECT public.bootstrap_offline_cashier($1,$2,$3) AS snapshot',
    [venue, f.device, online])).rows[0].snapshot;
};
const check = async (name, body) => {
  await f.reset();
  await admin(`DELETE FROM public.booking_holds; UPDATE public.rooms SET pricing_model='single_multi_hour';
    INSERT INTO public.fixture_permissions VALUES('${actor}','${lounge}','bookings.view'),
      ('${actor}','${lounge}','menu_view');
    UPDATE public.shifts SET cashier_id='${actor}',staff_user_id='${actor}' WHERE id='${shift}';
    UPDATE public.shifts SET cashier_id='${f.customer}',staff_user_id='${f.customer}' WHERE id='${f.otherShift}';`);
  await body(); passed++; console.log('PASS ' + name);
};
try {
  if (!process.env.PLAYSPOT_ROOM_GUARD_SQL) {
    await db.exec(await read('../migrations/20261004035454_room_active_session_invariants.sql'));
  }
  // Mirror only additional hosted columns/tables used by this read contract.
  await admin(`ALTER TABLE public.rooms ADD pricing_model text DEFAULT 'single_multi_hour';
    CREATE TABLE public.booking_holds(id uuid PRIMARY KEY, lounge_id uuid, room_id uuid,
      start_at timestamp, end_at timestamp, expires_at timestamptz, released_at timestamptz);`);
  await admin('ALTER TABLE public.booking_holds ADD user_id uuid;');
  // The hosted hold guard was inspected and matches this canonical migration.
  // Load its actual function/trigger, rather than a simplified mock, to verify
  // that reconciliation keeps hold conflicts instead of bypassing them.
  const holdMigration=await read('../migrations/20260927000010_real_booking_holds.sql');
  const holdStart=holdMigration.indexOf('CREATE OR REPLACE FUNCTION private.guard_booking_against_active_holds()');
  const holdEnd=holdMigration.indexOf('CREATE OR REPLACE FUNCTION public.verify_and_hold_slot(',holdStart);
  assert(holdStart>=0 && holdEnd>holdStart);
  await db.exec(holdMigration.slice(holdStart,holdEnd));
  await db.exec(await read('../repairs/offline_cashier_bootstrap.sql'));

  await check('bootstrap returns one complete scoped snapshot without inventing bookings or payments', async () => {
    const before = await f.snapshot(), r = await load();
    assert.equal(r.complete, true); assert.equal(r.protocol_version, 2);
    assert.equal(r.authority.actor_id, actor); assert.equal(r.authority.lounge_id, lounge);
    assert.equal(r.shift.id, shift); assert.equal(r.shift.actor_id, actor);
    assert.equal(r.rooms[room].single_hour_minor, 10000);
    assert.equal(r.rooms[room].multi_hour_minor, 15000);
    assert.equal(r.products[product].unit_price_minor, 1500);
    assert.equal(r.products[product].stock_quantity, 10);
    assert.deepEqual(r.bookings, {}); assert.deepEqual(r.rooms[room].blocked_intervals, []);
    assert.equal(r.shift.cash_total_visible, false);
    assert.deepEqual(await f.snapshot(), before);
    if (process.env.PLAYSPOT_BOOTSTRAP_CONTRACT_EXPORT) {
      await writeFile(process.env.PLAYSPOT_BOOTSTRAP_CONTRACT_EXPORT, JSON.stringify(r, null, 2)+'\n');
    }
  });
  await check('foreign venue and foreign open shift are never used as bootstrap scope', async () => {
    await assert.rejects(load(otherLounge), e => e.code==='42501');
    await admin(`UPDATE public.shifts SET status='closed' WHERE id='${shift}'`);
    await assert.rejects(load(), e => e.message==='OFFLINE_BOOTSTRAP_REQUIRES_ONE_OWN_SHIFT');
  });
  await check('multiple own shifts fail instead of guessing a shift', async () => {
    await admin(`UPDATE public.shifts SET cashier_id='${actor}',staff_user_id='${actor}'`);
    await assert.rejects(load(), e => e.message==='OFFLINE_BOOTSTRAP_REQUIRES_ONE_OWN_SHIFT');
  });
  await check('banned and inactive actors cannot bootstrap even with stored writer authority', async () => {
    for (const patch of ['is_banned=true', 'is_active=false']) {
      await admin(`UPDATE public.profiles SET is_active=true,is_banned=false WHERE id='${actor}';
        UPDATE public.profiles SET ${patch} WHERE id='${actor}'`);
      await assert.rejects(load(), e => e.code==='42501' && e.message==='ACCOUNT_NOT_ELIGIBLE');
    }
  });
  await check('unauthenticated actors and anon execute are rejected', async () => {
    await admin(`SET test.actor=''; SET ROLE authenticated;`);
    await assert.rejects(db.query('SELECT public.bootstrap_offline_cashier($1,$2,false)',
      [lounge,f.device]), e=>e.code==='28000');
    await admin(`SET ROLE anon;`);
    await assert.rejects(db.query('SELECT public.bootstrap_offline_cashier($1,$2,false)',
      [lounge,f.device]), e=>e.code==='42501');
  });
  await check('lost scoped permission does not reuse a previously issued grant', async () => {
    await admin(`DELETE FROM public.fixture_permissions WHERE permission='sessions_control'`);
    await assert.rejects(load(), e=>e.code==='42501');
  });
  await check('bootstrap grants exactly the authenticated API role and keeps the private helper private', async () => {
    await admin('');
    for (const [role, expected] of [['anon',false],['authenticated',true],
      ['service_role',false],['supabase_auth_admin',false]]) {
      const r=(await db.query(`SELECT has_function_privilege($1,
        'public.bootstrap_offline_cashier(uuid,uuid,boolean)','execute') AS api,
        has_function_privilege($1,'private.offline_minor_amount(numeric)','execute') AS helper`,[role])).rows[0];
      assert.equal(r.api,expected,role); assert.equal(r.helper,false,role);
    }
  });
  await check('session control alone does not grant access to customer booking data', async () => {
    await admin(`DELETE FROM public.fixture_permissions WHERE permission='bookings.view'`);
    await assert.rejects(load(), e=>e.code==='42501' && e.message==='OFFLINE_BOOTSTRAP_READ_PERMISSION_DENIED');
  });
  await check('menu data and stock are absent when menu viewing is revoked', async () => {
    await admin(`DELETE FROM public.fixture_permissions WHERE permission='menu_view'`);
    const r=await load();
    assert.deepEqual(r.products,{});
    assert.equal(Object.keys(r.rooms).length,1);
    assert.equal(r.complete,true);
  });
  await check('online bootstrap requests the matching online heartbeat', async () => {
    const r=await load(lounge,true);
    assert.equal(r.authority.online_requested,true);
    const delta=Date.parse(r.authority.heartbeat_expires_at)-r.authority.server_time_ms;
    assert(delta>0 && delta<=90000);
  });
  await check('foreign device does not silently take over the venue writer', async () => {
    await login();
    await assert.rejects(db.query('SELECT public.bootstrap_offline_cashier($1,$2,false)',
      [lounge,randomUUID()]), e=>e.code==='55000');
  });
  await check('blind cash total remains hidden unless the actual grant allows it', async () => {
    await admin(`INSERT INTO public.shift_payments(shift_id,lounge_id,payment_method,category,amount)
      VALUES('${shift}','${lounge}','cash','gaming_time',20);`);
    let r=await load(); assert.equal(r.shift.collected_cash_minor,0);
    assert.equal(r.shift.cash_total_visible,false);
    await admin(`INSERT INTO public.fixture_permissions VALUES('${actor}','${lounge}','shifts_view_blind_cash')`);
    r=await load(); assert.equal(r.shift.collected_cash_minor,2000);
    assert.equal(r.shift.cash_total_visible,true);
  });
  await check('tournament reservations and live booking holds are included in capacity coverage', async () => {
    const start=Math.floor(Date.now()/60000)*60000+3600000, end=start+3600000;
    await admin(`INSERT INTO public.tournament_matches(room_id,status,scheduled_at,scheduled_end_at)
      VALUES('${room}','scheduled',to_timestamp(${start}/1000.0),to_timestamp(${end}/1000.0));
      INSERT INTO public.booking_holds(id,lounge_id,room_id,start_at,end_at,expires_at,released_at) VALUES('${randomUUID()}','${lounge}','${room}',
        to_timestamp(${end}/1000.0) AT TIME ZONE 'Africa/Cairo',
        to_timestamp(${end+3600000}/1000.0) AT TIME ZONE 'Africa/Cairo',now()+interval '10 minutes',NULL);`);
    const r=await load(), intervals=r.rooms[room].blocked_intervals;
    assert.equal(intervals.length,2);
    assert(intervals.some(i=>i.start_ms===start && i.end_ms===end));
    assert(intervals.some(i=>i.start_ms===end && i.end_ms===end+3600000));
  });
  await check('expired and released holds do not block local availability', async () => {
    await admin(`INSERT INTO public.booking_holds(id,lounge_id,room_id,start_at,end_at,expires_at,released_at) VALUES('${randomUUID()}','${lounge}','${room}',
      now() AT TIME ZONE 'Africa/Cairo', (now()+interval '1 hour') AT TIME ZONE 'Africa/Cairo',
      now()-interval '1 minute',NULL),('${randomUUID()}','${lounge}','${room}',
      now() AT TIME ZONE 'Africa/Cairo',(now()+interval '1 hour') AT TIME ZONE 'Africa/Cairo',
      now()+interval '1 hour',now());`);
    assert.deepEqual((await load()).rooms[room].blocked_intervals,[]);
  });
  await check('retained unpaid bookings include exact debt and shift while foreign shifts stay unsupported', async () => {
    const id=await f.seedBooking();
    await admin(`UPDATE public.bookings SET shift_id='${shift}' WHERE id='${id}'`);
    let r=await load(); assert.equal(r.bookings[id].total_minor,10000);
    assert.equal(r.bookings[id].paid_minor,0); assert.equal(r.bookings[id].payment_status,'unpaid');
    assert.equal(r.bookings[id].offline_supported,true);
    await admin(`UPDATE public.bookings SET shift_id='${f.otherShift}' WHERE id='${id}'`);
    // This historical row is outside capacity coverage and no longer belongs to
    // the current shift, so it must not leak into this cashier's debt workspace.
    r=await load(); assert.equal(r.bookings[id],undefined);
  });
  await check('unsupported pricing retains room visibility without offering an offline quote', async () => {
    await admin(`UPDATE public.rooms SET pricing_model='per_person_hour'`);
    assert.equal((await load()).rooms[room].offline_supported,false);
  });
  await check('fractional-cent prices fail rather than being silently rounded', async () => {
    await admin(`UPDATE public.extras SET price=15.001`);
    await assert.rejects(load(),e=>e.code==='22023' && e.message==='INVALID_OFFLINE_FINANCIAL_SNAPSHOT');
  });
  await check('invalid timezone fails before returning a false complete snapshot', async () => {
    await admin(`UPDATE public.lounges SET timezone='Invalid/Zone'`);
    await assert.rejects(load(),e=>e.message==='INVALID_LOUNGE_TIMEZONE');
  });
  await check('the actual hosted hold guard rejects an offline reservation without losing saved sequence', async () => {
    const op=f.operation(), from=op.payload.start_ms, until=op.payload.end_ms;
    await admin(`INSERT INTO public.booking_holds(id,lounge_id,room_id,start_at,end_at,expires_at,user_id)
      VALUES('${randomUUID()}','${lounge}','${room}',
        to_timestamp(${from}/1000.0) AT TIME ZONE 'Africa/Cairo',
        to_timestamp(${until}/1000.0) AT TIME ZONE 'Africa/Cairo',now()+interval '10 minutes','${f.customer}');`);
    const before=await f.snapshot(), receipt=await f.send(op);
    assert.equal(receipt.status,'conflict');
    assert.deepEqual(await f.snapshot(),before);
    assert.equal((await f.send(op)).status,'conflict');
  });
  await check('a released hold does not produce a false offline reservation conflict', async () => {
    const op=f.operation(), from=op.payload.start_ms, until=op.payload.end_ms;
    await admin(`INSERT INTO public.booking_holds(id,lounge_id,room_id,start_at,end_at,expires_at,released_at,user_id)
      VALUES('${randomUUID()}','${lounge}','${room}',
        to_timestamp(${from}/1000.0) AT TIME ZONE 'Africa/Cairo',
        to_timestamp(${until}/1000.0) AT TIME ZONE 'Africa/Cairo',now()+interval '10 minutes',now(),'${f.customer}');`);
    assert.equal((await f.send(op)).status,'applied');
  });
  await check('failed first bootstrap rolls back the writer claim and permit issuance', async () => {
    await admin(`DELETE FROM private.cashier_writer_authorities; UPDATE public.shifts SET status='closed'`);
    const before=(await db.query('SELECT count(*)::int AS n FROM private.cashier_writer_permits')).rows[0].n;
    await assert.rejects(load(),e=>e.message==='OFFLINE_BOOTSTRAP_REQUIRES_ONE_OWN_SHIFT');
    await admin('');
    assert.equal((await db.query('SELECT count(*)::int AS n FROM private.cashier_writer_authorities')).rows[0].n,0);
    assert.equal((await db.query('SELECT count(*)::int AS n FROM private.cashier_writer_permits')).rows[0].n,before);
  });
  console.log(`All ${passed} offline bootstrap checks passed.`);
} finally { await db.close(); }
