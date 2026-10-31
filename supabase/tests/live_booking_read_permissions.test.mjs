import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {createFixtureDatabase} from './runtime/database.mjs';

const db = await createFixtureDatabase();
const customer = '00000000-0000-0000-0000-000000000001';
const staff = '00000000-0000-0000-0000-000000000002';
const memberWithoutPermission = '00000000-0000-0000-0000-000000000003';
const owner = '00000000-0000-0000-0000-000000000004';
const lounge = '00000000-0000-0000-0000-000000000011';
const room = '00000000-0000-0000-0000-000000000021';
const booking = '00000000-0000-0000-0000-000000000031';
const order = '00000000-0000-0000-0000-000000000041';
const previousMigration = await readFile(
  new URL('../migrations/20261019212750_live_session_visit_number.sql', import.meta.url),
  'utf8',
);
const migration = await readFile(
  new URL('../migrations/20261020123340_live_booking_read_permissions.sql', import.meta.url),
  'utf8',
);

async function actor(id) {
  await db.exec(`RESET ROLE; SELECT set_config('test.actor','${id}',false); SET ROLE authenticated;`);
}

try {
  await db.exec(`
    DO $roles$ BEGIN
      IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN CREATE ROLE anon; END IF;
      IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN CREATE ROLE authenticated; END IF;
      IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN CREATE ROLE service_role; END IF;
      IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_auth_admin') THEN CREATE ROLE supabase_auth_admin; END IF;
    END; $roles$;
    CREATE SCHEMA auth;
    CREATE SCHEMA private;
    CREATE TYPE public.booking_status AS ENUM ('upcoming','in_progress','completed');
    CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS
      $$ SELECT NULLIF(current_setting('test.actor', true),'')::uuid $$;
    GRANT USAGE ON SCHEMA auth TO authenticated;
    GRANT EXECUTE ON FUNCTION auth.uid() TO authenticated;
    CREATE FUNCTION public.is_super_admin() RETURNS boolean LANGUAGE sql AS $$ SELECT false $$;
    CREATE FUNCTION public.has_lounge_permission(uuid,text) RETURNS boolean
      LANGUAGE sql STABLE AS $$ SELECT auth.uid() = '${staff}'::uuid AND $1 = '${lounge}'::uuid AND $2 = 'bookings.view' $$;
    CREATE FUNCTION public.is_lounge_member_or_admin(uuid) RETURNS boolean
      LANGUAGE sql AS $$ SELECT auth.uid() = '${memberWithoutPermission}'::uuid $$;
    CREATE FUNCTION public._playspot_has_lounge_access(uuid) RETURNS boolean
      LANGUAGE sql AS $$ SELECT auth.uid() = '${memberWithoutPermission}'::uuid $$;
    CREATE FUNCTION private.can_operate_playspot_lounge(uuid) RETURNS boolean
      LANGUAGE sql AS $$ SELECT auth.uid() = '${memberWithoutPermission}'::uuid $$;
    CREATE TABLE public.lounges (id uuid PRIMARY KEY, owner_id uuid);
    CREATE TABLE public.bookings (
      id uuid PRIMARY KEY, lounge_id uuid, user_id uuid, room_id uuid,
      user_name text, user_phone text, status public.booking_status,
      created_at timestamptz, start_time time, end_time time,
      duration_minutes integer, total_price numeric, addons_price numeric
    );
    CREATE TABLE public.profiles (id uuid PRIMARY KEY, full_name text, phone text);
    CREATE TABLE public.rooms (id uuid PRIMARY KEY, name_ar text, name_en text, name text);
    CREATE TABLE public.canteen_orders (
      id uuid PRIMARY KEY, booking_id uuid, lounge_id uuid, user_id uuid,
      items jsonb, total_price numeric, status text, created_at timestamptz
    );
    INSERT INTO public.lounges VALUES ('${lounge}','${owner}');
    INSERT INTO public.profiles VALUES ('${customer}','Customer','0100');
    INSERT INTO public.rooms VALUES ('${room}','Room','Room','Room');
    INSERT INTO public.bookings (id,lounge_id,user_id,room_id,status,created_at)
      VALUES ('${booking}','${lounge}','${customer}','${room}','in_progress','2026-10-20');
    INSERT INTO public.canteen_orders (id,booking_id,lounge_id,user_id,status)
      VALUES ('${order}','${booking}','${lounge}','${customer}','pending');
    ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;
    ALTER TABLE public.canteen_orders ENABLE ROW LEVEL SECURITY;
    GRANT SELECT ON public.bookings, public.canteen_orders TO authenticated;
    GRANT INSERT, UPDATE, DELETE ON public.bookings TO authenticated;
    GRANT SELECT ON public.lounges, public.profiles, public.rooms TO authenticated;
    CREATE POLICY bookings_select_customer_or_branch ON public.bookings
      FOR SELECT TO authenticated USING (user_id=auth.uid() OR public._playspot_has_lounge_access(lounge_id));
    CREATE POLICY bookings_select_policy ON public.bookings
      FOR SELECT TO authenticated USING (user_id=auth.uid() OR public.is_lounge_member_or_admin(lounge_id));
    CREATE POLICY "Users can view own canteen orders" ON public.canteen_orders
      FOR SELECT TO authenticated USING (user_id=auth.uid() OR public.is_lounge_member_or_admin(lounge_id));
  `);
  await db.exec(previousMigration);

  await actor(memberWithoutPermission);
  assert.equal((await db.query('SELECT count(*)::int AS total FROM public.bookings')).rows[0].total, 1);
  assert.equal((await db.query('SELECT count(*)::int AS total FROM public.canteen_orders')).rows[0].total, 1);
  assert.equal((await db.query('SELECT jsonb_array_length(public.get_live_bookings_with_items($1)) AS total', [lounge])).rows[0].total, 1);

  await db.exec('RESET ROLE');
  await db.exec(migration);
  await db.exec(migration);
  assert.equal(
    (await db.query("SELECT has_table_privilege('authenticated','public.bookings','INSERT,UPDATE,DELETE') AS allowed")).rows[0].allowed,
    false,
  );

  await actor(memberWithoutPermission);
  assert.equal((await db.query('SELECT count(*)::int AS total FROM public.bookings')).rows[0].total, 0);
  assert.equal((await db.query('SELECT count(*)::int AS total FROM public.canteen_orders')).rows[0].total, 0);
  await assert.rejects(
    db.query('SELECT public.get_live_bookings_with_items($1)', [lounge]),
    error => error.code === '42501',
  );

  await actor(customer);
  assert.equal((await db.query('SELECT count(*)::int AS total FROM public.bookings')).rows[0].total, 1);
  assert.equal((await db.query('SELECT count(*)::int AS total FROM public.canteen_orders')).rows[0].total, 1);
  await assert.rejects(
    db.query('SELECT public.get_live_bookings_with_items($1)', [lounge]),
    error => error.code === '42501',
  );

  for (const permitted of [staff, owner]) {
    await actor(permitted);
    assert.equal((await db.query('SELECT count(*)::int AS total FROM public.bookings')).rows[0].total, 1);
    assert.equal((await db.query('SELECT count(*)::int AS total FROM public.canteen_orders')).rows[0].total, 1);
    assert.equal((await db.query('SELECT jsonb_array_length(public.get_live_bookings_with_items($1)) AS total', [lounge])).rows[0].total, 1);
  }
  console.log('PASS live booking reads require customer ownership or an operational permission');
} finally {
  await db.close();
}
