import {readFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
import {createFixtureDatabase} from './runtime/database.mjs';

const db = await createFixtureDatabase();
const booking = (n) => `00000000-0000-0000-0000-${String(n).padStart(12, '0')}`;
let passed = 0;
async function check(label, run) {
  await db.exec('BEGIN');
  try {
    await run();
    passed++;
    console.log('PASS', label);
  } finally {
    await db.exec('ROLLBACK');
  }
}
try {
  await db.exec(`
    CREATE SCHEMA private;
    CREATE TYPE public.booking_status AS ENUM
      ('upcoming','completed','cancelled','pending','in_progress','rejected','expired');
    CREATE TABLE public.bookings(
      id uuid PRIMARY KEY,
      status public.booking_status NOT NULL,
      extension_status text DEFAULT 'none',
      requested_extension_minutes integer
    );
  `);
  const migration = await readFile(
    new URL('../migrations/20261016183000_expire_pending_booking_extensions_on_terminal.sql', import.meta.url),
    'utf8',
  );
  await db.exec(migration);

  await check('completion expires a pending request but keeps its original minutes', async () => {
    await db.query(
      'INSERT INTO bookings VALUES ($1,$2,$3,$4)',
      [booking(1), 'in_progress', 'pending', 30],
    );
    await db.query('UPDATE bookings SET status=$1 WHERE id=$2', ['completed', booking(1)]);
    const {rows} = await db.query(
      'SELECT status::text, extension_status, requested_extension_minutes FROM bookings WHERE id=$1',
      [booking(1)],
    );
    assert.deepEqual(rows[0], {
      status: 'completed',
      extension_status: 'expired',
      requested_extension_minutes: 30,
    });
  });

  await check('cancellation and no-show expiration clean unresolved requests', async () => {
    for (const status of ['cancelled','rejected','expired']) {
      await db.query(
        'INSERT INTO bookings VALUES ($1,$2,$3,$4)',
        [booking(2), 'in_progress', 'pending', 15],
      );
      await db.query('UPDATE bookings SET status=$1 WHERE id=$2', [status, booking(2)]);
      assert.equal((await db.query(
        'SELECT extension_status FROM bookings WHERE id=$1',[booking(2)],
      )).rows[0].extension_status, 'expired');
      await db.query('DELETE FROM bookings WHERE id=$1',[booking(2)]);
    }
  });

  await check('already approved and rejected extensions keep their audit status', async () => {
    for (const extension of ['approved','rejected','none']) {
      await db.query(
        'INSERT INTO bookings VALUES ($1,$2,$3,$4)',
        [booking(3), 'in_progress', extension, 45],
      );
      await db.query('UPDATE bookings SET status=$1 WHERE id=$2', ['completed', booking(3)]);
      assert.equal((await db.query(
        'SELECT extension_status FROM bookings WHERE id=$1',[booking(3)],
      )).rows[0].extension_status, extension);
      await db.query('DELETE FROM bookings WHERE id=$1',[booking(3)]);
    }
  });

  await check('live pending extension stays actionable', async () => {
    await db.query('INSERT INTO bookings VALUES ($1,$2,$3,$4)',[
      booking(4), 'in_progress', 'none', null,
    ]);
    await db.query('UPDATE bookings SET extension_status=$1, requested_extension_minutes=$2 WHERE id=$3',[
      'pending', 60, booking(4),
    ]);
    assert.equal((await db.query(
      'SELECT extension_status FROM bookings WHERE id=$1',[booking(4)],
    )).rows[0].extension_status, 'pending');
  });

  await check('terminal booking cannot be assigned a pending extension', async () => {
    await db.query('INSERT INTO bookings VALUES ($1,$2,$3,$4)',[
      booking(5), 'completed', 'none', null,
    ]);
    await db.query('UPDATE bookings SET extension_status=$1, requested_extension_minutes=$2 WHERE id=$3',[
      'pending', 60, booking(5),
    ]);
    assert.equal((await db.query(
      'SELECT extension_status FROM bookings WHERE id=$1',[booking(5)],
    )).rows[0].extension_status, 'expired');
  });

  await check('trigger helper is not directly executable by clients', async () => {
    const {rows} = await db.query(
      `SELECT has_function_privilege('anon',
        'private.expire_pending_booking_extension_on_terminal()', 'EXECUTE') a,
        has_function_privilege('authenticated',
        'private.expire_pending_booking_extension_on_terminal()', 'EXECUTE') b`,
    );
    assert.equal(rows[0].a, false);
    assert.equal(rows[0].b, false);
  });

  console.log(JSON.stringify({
    passed,
    environment:'isolated synthetic Postgres; no hosted booking updates',
  }));
} finally {
  await db.close();
}
