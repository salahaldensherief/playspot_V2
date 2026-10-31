import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {createFixtureDatabase} from './runtime/database.mjs';

const db=await createFixtureDatabase();
let passed=0;
async function check(name,body) {
  await db.exec('BEGIN');
  try {await body();passed++;console.log('PASS '+name);}
  finally {await db.exec('ROLLBACK');}
}
try {
  await db.exec(`
    CREATE ROLE anon; CREATE ROLE authenticated; CREATE ROLE service_role;
    CREATE SCHEMA private;
    CREATE TYPE public.booking_status AS ENUM (
      'pending','upcoming','in_progress','completed','cancelled'
    );
    CREATE TABLE public.bookings (
      id integer PRIMARY KEY,
      status public.booking_status NOT NULL,
      extension_status text,
      requested_extension_minutes integer
    );
    INSERT INTO public.bookings VALUES
      (1,'in_progress','pending',30),
      (2,'in_progress','pending',45),
      (3,'in_progress','approved',20),
      (4,'in_progress','rejected',10),
      (5,'completed','pending',15),
      (6,'in_progress','pending',60);
  `);
  await db.exec(await readFile(
    new URL('../migrations/20261016163000_close_terminal_pending_extensions.sql',import.meta.url),
    'utf8',
  ));
  await check('prior terminal pending request is repaired without losing original minutes', async () => {
    const r=(await db.query('SELECT extension_status,requested_extension_minutes FROM bookings WHERE id=5')).rows[0];
    assert.equal(r.extension_status,'expired');
    assert.equal(r.requested_extension_minutes,15);
  });
  await check('completion expires pending extension but preserves approved history', async () => {
    await db.exec("UPDATE bookings SET status='completed' WHERE id IN (1,3)");
    const r=(await db.query('SELECT id,extension_status FROM bookings WHERE id IN (1,3) ORDER BY id')).rows;
    assert.deepEqual(r.map(x=>x.extension_status),['expired','approved']);
  });
  await check('cancellation expires pending request but not rejected history', async () => {
    await db.exec("UPDATE bookings SET status='cancelled' WHERE id IN (2,4)");
    const r=(await db.query('SELECT id,extension_status FROM bookings WHERE id IN (2,4) ORDER BY id')).rows;
    assert.deepEqual(r.map(x=>x.extension_status),['expired','rejected']);
  });
  await check('pending active request remains reviewable', async () => {
    await db.exec("UPDATE bookings SET requested_extension_minutes=50 WHERE id=6");
    const r=(await db.query('SELECT extension_status,requested_extension_minutes FROM bookings WHERE id=6')).rows[0];
    assert.equal(r.extension_status,'pending');assert.equal(r.requested_extension_minutes,50);
  });
  await check('setting pending after terminal status becomes expired immediately', async () => {
    await db.exec("UPDATE bookings SET extension_status='pending' WHERE id=5");
    const r=(await db.query('SELECT extension_status FROM bookings WHERE id=5')).rows[0];
    assert.equal(r.extension_status,'expired');
  });
  await check('clients cannot invoke internal trigger function', async () => {
    const r=(await db.query("SELECT has_function_privilege('authenticated','private.expire_terminal_booking_extension()','EXECUTE') allowed")).rows[0];
    assert.equal(r.allowed,false);
  });
  console.log(JSON.stringify({passed,synthetic:true,productionWrites:0}));
} finally {await db.close();}
