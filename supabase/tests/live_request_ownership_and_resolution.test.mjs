import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {createFixtureDatabase} from './runtime/database.mjs';

const db = await createFixtureDatabase();
const customer = '00000000-0000-0000-0000-000000000001';
const otherCustomer = '00000000-0000-0000-0000-000000000002';
const staff = '00000000-0000-0000-0000-000000000003';
const lounge = '00000000-0000-0000-0000-000000000011';
const otherLounge = '00000000-0000-0000-0000-000000000012';
const room = '00000000-0000-0000-0000-000000000021';
const otherRoom = '00000000-0000-0000-0000-000000000022';
const booking = '00000000-0000-0000-0000-000000000031';
const otherBooking = '00000000-0000-0000-0000-000000000032';
const orderOne = '00000000-0000-0000-0000-000000000041';
const orderTwo = '00000000-0000-0000-0000-000000000042';
const callOne = '00000000-0000-0000-0000-000000000051';
const callTwo = '00000000-0000-0000-0000-000000000052';
const migration = await readFile(
  new URL('../migrations/20261019000001_live_request_ownership_and_resolution.sql', import.meta.url),
  'utf8',
);

async function actor(id) {
  await db.exec(`RESET ROLE; SELECT set_config('test.actor','${id}',false); SET ROLE authenticated;`);
}

async function owner() {
  await db.exec('RESET ROLE');
}

try {
  await db.exec(`
    CREATE ROLE anon;
    CREATE ROLE authenticated;
    CREATE ROLE service_role;
    CREATE ROLE supabase_auth_admin;
    CREATE SCHEMA auth;
    CREATE TYPE public.booking_status AS ENUM ('upcoming','in_progress','completed');
    CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS
      $$ SELECT NULLIF(current_setting('test.actor', true),'')::uuid $$;
    CREATE TABLE public.bookings (
      id uuid PRIMARY KEY, user_id uuid, status public.booking_status,
      lounge_id uuid, room_id uuid
    );
    CREATE TABLE public.service_calls (
      id uuid PRIMARY KEY, booking_id uuid REFERENCES public.bookings(id),
      user_id uuid, lounge_id uuid, room_id uuid, call_type text,
      status text DEFAULT 'pending', is_attended boolean DEFAULT false,
      is_read boolean DEFAULT false, updated_at timestamptz
    );
    CREATE TABLE public.canteen_orders (
      id uuid PRIMARY KEY, booking_id uuid, lounge_id uuid,
      status text DEFAULT 'pending', is_attended boolean DEFAULT false,
      is_read boolean DEFAULT false, updated_at timestamptz
    );
    CREATE TABLE public.client_requests (
      id uuid PRIMARY KEY, booking_id uuid, lounge_id uuid,
      status text DEFAULT 'pending', is_attended boolean DEFAULT false,
      is_read boolean DEFAULT false
    );
    CREATE FUNCTION public.is_super_admin() RETURNS boolean LANGUAGE sql
      AS $$ SELECT false $$;
    CREATE FUNCTION public.has_lounge_permission(uuid,text) RETURNS boolean
      LANGUAGE sql STABLE AS
      $$ SELECT auth.uid() = '${staff}'::uuid $$;
    ALTER TABLE public.service_calls ENABLE ROW LEVEL SECURITY;
    CREATE POLICY "Users can create service calls for their bookings"
      ON public.service_calls FOR INSERT TO authenticated
      WITH CHECK (auth.uid() = user_id);
    CREATE POLICY own_bookings ON public.bookings FOR SELECT TO authenticated
      USING (user_id = auth.uid());
    GRANT USAGE ON SCHEMA public,auth TO authenticated;
    GRANT EXECUTE ON FUNCTION auth.uid() TO authenticated;
    GRANT SELECT ON public.bookings TO authenticated;
    GRANT INSERT ON public.service_calls TO authenticated;
    GRANT UPDATE ON public.canteen_orders TO authenticated;
    INSERT INTO public.bookings VALUES
      ('${booking}','${customer}','in_progress','${lounge}','${room}'),
      ('${otherBooking}','${otherCustomer}','in_progress','${otherLounge}','${otherRoom}');
    INSERT INTO public.canteen_orders(id,booking_id,lounge_id) VALUES
      ('${orderOne}','${booking}','${lounge}'),
      ('${orderTwo}','${booking}','${lounge}');
    INSERT INTO public.service_calls(id,booking_id,user_id,lounge_id,room_id,call_type)
      VALUES ('${callOne}','${booking}','${customer}','${lounge}','${room}','canteen_order'),
      ('${callTwo}','${booking}','${customer}','${lounge}','${room}','canteen_order');
  `);

  await actor(customer);
  await db.query(
    'INSERT INTO public.service_calls(id,booking_id,user_id,lounge_id,room_id,call_type) VALUES($1,$2,$3,$4,$5,$6)',
    ['00000000-0000-0000-0000-000000000061', otherBooking, customer, otherLounge, otherRoom, 'call_staff'],
  );
  await owner();
  await db.exec(migration);
  await db.exec(migration);
  assert.equal(
    (await db.query("SELECT has_table_privilege('authenticated','public.canteen_orders','UPDATE') AS allowed")).rows[0].allowed,
    false,
    'customers and staff must use an authorized order RPC',
  );
  assert.equal(
    (await db.query("SELECT has_function_privilege('anon','public.resolve_live_request(text,uuid)','EXECUTE') AS allowed")).rows[0].allowed,
    false,
    'anonymous clients cannot execute the resolution RPC',
  );

  await actor(customer);
  for (const [name, id, bookingId, loungeId, roomId, status] of [
    ['another customer booking', '00000000-0000-0000-0000-000000000062', otherBooking, otherLounge, otherRoom, 'pending'],
    ['different lounge', '00000000-0000-0000-0000-000000000063', booking, otherLounge, room, 'pending'],
    ['different room', '00000000-0000-0000-0000-000000000064', booking, lounge, otherRoom, 'pending'],
    ['pre-completed call', '00000000-0000-0000-0000-000000000065', booking, lounge, room, 'completed'],
  ]) {
    await assert.rejects(
      db.query(
        'INSERT INTO public.service_calls(id,booking_id,user_id,lounge_id,room_id,call_type,status) VALUES($1,$2,$3,$4,$5,$6,$7)',
        [id, bookingId, customer, loungeId, roomId, 'call_staff', status],
      ),
      error => error.code === '42501',
      name,
    );
  }
  await db.query(
    'INSERT INTO public.service_calls(id,booking_id,user_id,lounge_id,room_id,call_type) VALUES($1,$2,$3,$4,$5,$6)',
    ['00000000-0000-0000-0000-000000000066', booking, customer, lounge, room, 'call_staff'],
  );

  await actor(customer);
  await assert.rejects(
    db.query('SELECT public.resolve_live_request($1,$2)', ['canteen', orderOne]),
    error => error.code === '42501',
    'customer cannot complete a canteen order',
  );
  await actor(staff);
  const result = await db.query('SELECT public.resolve_live_request($1,$2) AS value', ['canteen', orderOne]);
  assert.equal(result.rows[0].value.success, true);
  await owner();
  const orders = (await db.query('SELECT id,status FROM public.canteen_orders ORDER BY id')).rows;
  const calls = (await db.query('SELECT id,status FROM public.service_calls WHERE id IN ($1,$2) ORDER BY id', [callOne, callTwo])).rows;
  assert.deepEqual(orders.map(row => row.status), ['completed', 'pending']);
  assert.deepEqual(calls.map(row => row.status), ['pending', 'pending']);
  console.log('PASS live request ownership and independent resolution');
} finally {
  await db.close();
}
