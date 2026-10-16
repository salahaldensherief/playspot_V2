import { createFixtureDatabase } from './runtime/database.mjs';
import { readFile } from 'node:fs/promises';
import assert from 'node:assert/strict';

const db = await createFixtureDatabase();
const bookingId = '00000000-0000-0000-0000-000000000041';
const terminal = ['completed', 'cancelled', 'expired', 'rejected'];
let passed = 0;

async function check(label, test) {
  await db.exec('BEGIN');
  try {
    await test();
    passed++;
    console.log('PASS ' + label);
  } finally {
    await db.exec('ROLLBACK');
  }
}

try {
  await db.exec(await readFile(
    new URL('./runtime/checkout_canteen_schema.sql', import.meta.url),
    'utf8',
  ));
  await db.exec(await readFile(
    new URL('../migrations/20261016171500_terminal_booking_extension_cleanup.sql', import.meta.url),
    'utf8',
  ));

  await db.exec(`INSERT INTO public.bookings(
    id, date, start_time, end_time, room_price, total_price,
    status, extension_status, requested_extension_minutes
  ) VALUES (
    '${bookingId}', '2026-10-16', '18:00', '19:00', 100, 100,
    'in_progress', 'none', 0
  );`);

  async function state() {
    const result = await db.query(
      'SELECT status::text,extension_status,requested_extension_minutes FROM public.bookings WHERE id=$1',
      [bookingId],
    );
    return result.rows[0];
  }

  await check('active pending request remains reviewable', async () => {
    await db.query(
      "UPDATE public.bookings SET extension_status='pending',requested_extension_minutes=30 WHERE id=$1",
      [bookingId],
    );
    const row = await state();
    assert.equal(row.status, 'in_progress');
    assert.equal(row.extension_status, 'pending');
    assert.equal(row.requested_extension_minutes, 30);
  });

  for (const endStatus of terminal) {
    await check('terminal ' + endStatus + ' clears unreviewed request', async () => {
      await db.query(
        "UPDATE public.bookings SET extension_status='pending',requested_extension_minutes=45 WHERE id=$1",
        [bookingId],
      );
      await db.query('UPDATE public.bookings SET status=$1 WHERE id=$2', [endStatus, bookingId]);
      const row = await state();
      assert.equal(row.status, endStatus);
      assert.equal(row.extension_status, 'none');
      assert.equal(row.requested_extension_minutes, null);
    });
  }

  for (const reviewed of ['approved', 'rejected']) {
    await check('terminal transition preserves ' + reviewed + ' extension audit', async () => {
      await db.query(
        'UPDATE public.bookings SET extension_status=$1,requested_extension_minutes=30 WHERE id=$2',
        [reviewed, bookingId],
      );
      await db.query("UPDATE public.bookings SET status='completed' WHERE id=$1", [bookingId]);
      const row = await state();
      assert.equal(row.extension_status, reviewed);
      assert.equal(row.requested_extension_minutes, 30);
    });
  }

  await check('stale request on completed booking cannot become pending', async () => {
    await db.query("UPDATE public.bookings SET status='completed' WHERE id=$1", [bookingId]);
    await db.query(
      "UPDATE public.bookings SET extension_status='pending',requested_extension_minutes=60 WHERE id=$1",
      [bookingId],
    );
    const row = await state();
    assert.equal(row.extension_status, 'none');
    assert.equal(row.requested_extension_minutes, null);
  });

  await check('terminal insert cannot contain actionable pending extension', async () => {
    const otherId = '00000000-0000-0000-0000-000000000042';
    await db.query(
      `INSERT INTO public.bookings(id,date,start_time,end_time,room_price,total_price,status,
        extension_status,requested_extension_minutes)
        VALUES($1,'2026-10-16','19:00','20:00',100,100,'completed','pending',20)`,
      [otherId],
    );
    const row = (await db.query(
      'SELECT extension_status,requested_extension_minutes FROM public.bookings WHERE id=$1',
      [otherId],
    )).rows[0];
    assert.equal(row.extension_status, 'none');
    assert.equal(row.requested_extension_minutes, null);
  });

  console.log(JSON.stringify({ passed, environment: 'isolated synthetic PostgreSQL; no hosted writes' }));
} finally {
  await db.close();
}
