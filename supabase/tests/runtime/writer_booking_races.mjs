import assert from 'node:assert/strict';
import {lockedRace} from './locked_race.mjs';

export async function writerBookingRaces(db, {actor, other, lounge, room, device}) {
  if (!db.connect) return 0;
  let passed = 0;
  const refresh = (id, online) => `SELECT public.refresh_cashier_writer('${id}','${device}',${online})`;
  const insert = (id, resource) => `INSERT INTO public.bookings(user_id,lounge_id,room_id)
    VALUES('${other}','${id}','${resource}')`;
  const pass = name => {passed++; console.log('PASS ' + name);};

  await db.exec(`RESET ROLE;SET test.actor='${actor}';SET ROLE authenticated;`);
  await db.query(refresh(lounge, true));
  const [, denied] = await lockedRace(db,
    {sql: refresh(lounge, false), args: []}, {sql: insert(lounge, room), args: []}, actor);
  assert.equal(denied.error?.code, '55000');
  pass('committed offline transition precedes competing customer insertion');

  await db.query(refresh(lounge, true));
  const [, closed] = await lockedRace(db,
    {sql: insert(lounge, room), args: []}, {sql: refresh(lounge, false), args: []}, actor);
  assert.equal(closed.error, undefined);
  assert.equal((await db.query(`SELECT public.get_lounge_online_availability('${lounge}') AS online`)).rows[0].online, false);
  pass('accepted customer insertion precedes competing offline transition');

  for (const firstBooking of [false, true]) {
    const id = firstBooking ? '10000000-0000-0000-0000-000000000004' : '10000000-0000-0000-0000-000000000003';
    const resource = firstBooking ? '50000000-0000-0000-0000-000000000004' : '50000000-0000-0000-0000-000000000003';
    await db.exec(`RESET ROLE;INSERT INTO public.lounges VALUES('${id}','active',true,true);
      INSERT INTO public.rooms VALUES('${resource}','${id}');
      INSERT INTO public.fixture_permissions VALUES('${actor}','${id}','sessions_control');SET ROLE authenticated;`);
    const claim = {sql: refresh(id, false), args: []};
    const booking = {sql: insert(id, resource), args: []};
    const [, result] = await lockedRace(db, firstBooking ? booking : claim, firstBooking ? claim : booking, actor);
    assert.equal(result.error?.code, firstBooking ? undefined : '55000');
    pass(firstBooking ? 'first writer claim waits for accepted legacy-venue booking' : 'first writer claim fences a booking before writer row exists');
  }

  await db.query(refresh(lounge, true));
  const [, expired] = await lockedRace(db, {
    sql: `RESET ROLE;UPDATE private.cashier_writer_authorities
      SET heartbeat_expires_at=clock_timestamp()+interval '1 second' WHERE lounge_id='${lounge}'`, args: [],
    beforeCommit: peer => peer.query('SELECT pg_sleep(1.1)'),
  }, {sql: insert(lounge, room), args: []}, actor, true);
  assert.equal(expired.error?.code, '55000');
  pass('booking waiting on writer row rechecks expired heartbeat');

  await db.exec(`RESET ROLE;UPDATE private.cashier_writer_authorities
    SET heartbeat_expires_at=clock_timestamp()+interval '100 milliseconds' WHERE lounge_id='${lounge}';
    CREATE FUNCTION public.fixture_delayed_availability(uuid) RETURNS boolean LANGUAGE plpgsql AS
    $$BEGIN PERFORM pg_sleep(0.2);RETURN public.get_lounge_online_availability($1);END;$$;
    SET ROLE authenticated;`);
  assert.equal((await db.query(`SELECT public.fixture_delayed_availability('${lounge}') AS online`)).rows[0].online, false);
  pass('long-running statement evaluates availability against current wall clock');
  await db.query(refresh(lounge, true));
  const before = (await db.query('SELECT count(*)::int AS total FROM public.bookings')).rows[0].total;
  for (const isolation of ['REPEATABLE READ', 'SERIALIZABLE']) {
    for (const [name, sql] of [['writer refresh', refresh(lounge, false)], ['booking insertion', insert(lounge, room)]]) {
      await db.exec('BEGIN ISOLATION LEVEL ' + isolation);
      try {
        await assert.rejects(db.query(sql), error => error.code === '25001' && error.message === 'CASHIER_REQUIRES_READ_COMMITTED');
      } finally {await db.exec('ROLLBACK');}
      pass(name + ' rejects unverified snapshot isolation: ' + isolation);
    }
  }
  assert.equal((await db.query('SELECT count(*)::int AS total FROM public.bookings')).rows[0].total, before);
  return passed;
}
