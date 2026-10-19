import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {createFixtureDatabase} from './runtime/database.mjs';

const db = await createFixtureDatabase();
const staff = '00000000-0000-0000-0000-000000000001';
const customer = '00000000-0000-0000-0000-000000000002';
const anotherCustomer = '00000000-0000-0000-0000-000000000003';
const lounge = '00000000-0000-0000-0000-000000000011';
const otherLounge = '00000000-0000-0000-0000-000000000012';
const room = '00000000-0000-0000-0000-000000000021';
const returning = '00000000-0000-0000-0000-000000000033';
const firstVisit = '00000000-0000-0000-0000-000000000034';
const returningGuest = '00000000-0000-0000-0000-000000000036';
const migration = await readFile(
  new URL('../migrations/20261019000002_live_session_visit_number.sql', import.meta.url),
  'utf8',
);

try {
  await db.exec(`
    CREATE ROLE anon;
    CREATE ROLE authenticated;
    CREATE ROLE service_role;
    CREATE ROLE supabase_auth_admin;
    CREATE SCHEMA auth;
    CREATE SCHEMA private;
    CREATE TYPE public.booking_status AS ENUM ('upcoming','in_progress','completed');
    CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS
      $$ SELECT NULLIF(current_setting('test.actor', true),'')::uuid $$;
    CREATE FUNCTION public.is_super_admin() RETURNS boolean LANGUAGE sql
      AS $$ SELECT false $$;
    CREATE FUNCTION public.is_lounge_member_or_admin(uuid) RETURNS boolean
      LANGUAGE sql AS $$ SELECT false $$;
    CREATE FUNCTION private.can_operate_playspot_lounge(uuid) RETURNS boolean
      LANGUAGE sql STABLE AS
      $$ SELECT auth.uid() = '${staff}'::uuid AND $1 = '${lounge}'::uuid $$;
    CREATE TABLE public.bookings (
      id uuid PRIMARY KEY, lounge_id uuid, user_id uuid, room_id uuid,
      user_name text, user_phone text, status public.booking_status,
      created_at timestamptz, start_time time, end_time time,
      duration_minutes integer, total_price numeric, addons_price numeric
    );
    CREATE TABLE public.profiles (id uuid PRIMARY KEY, full_name text, phone text);
    CREATE TABLE public.rooms (id uuid PRIMARY KEY, name_ar text, name_en text, name text);
    CREATE TABLE public.canteen_orders (
      id uuid PRIMARY KEY, booking_id uuid, items jsonb, total_price numeric,
      status text, created_at timestamptz
    );
    INSERT INTO public.profiles VALUES
      ('${customer}','Returning','0100'),('${anotherCustomer}','First','0200');
    INSERT INTO public.rooms VALUES ('${room}','Room','Room','Room');
    INSERT INTO public.bookings(id,lounge_id,user_id,room_id,status,created_at) VALUES
      ('00000000-0000-0000-0000-000000000031','${lounge}','${customer}','${room}','completed','2026-10-01'),
      ('00000000-0000-0000-0000-000000000032','${lounge}','${customer}','${room}','completed','2026-10-02'),
      ('${returning}','${lounge}','${customer}','${room}','in_progress','2026-10-03'),
      ('${firstVisit}','${lounge}','${anotherCustomer}','${room}','in_progress','2026-10-03'),
      ('00000000-0000-0000-0000-000000000037','${otherLounge}','${customer}','${room}','completed','2026-09-01');
    INSERT INTO public.bookings(id,lounge_id,room_id,user_phone,status,created_at) VALUES
      ('00000000-0000-0000-0000-000000000035','${lounge}','${room}','0300','completed','2026-10-01'),
      ('${returningGuest}','${lounge}','${room}','0300','in_progress','2026-10-03');
  `);
  await db.exec(migration);
  await db.exec(migration);
  assert.equal(
    (await db.query("SELECT has_function_privilege('anon','public.get_live_bookings_with_items(uuid)','EXECUTE') AS allowed")).rows[0].allowed,
    false,
  );
  await db.exec(`SELECT set_config('test.actor','${customer}',false); SET ROLE authenticated;`);
  await assert.rejects(
    db.query('SELECT public.get_live_bookings_with_items($1)', [lounge]),
    error => error.code === '42501',
  );
  await db.exec(`RESET ROLE; SELECT set_config('test.actor','${staff}',false); SET ROLE authenticated;`);
  const rows = (await db.query('SELECT public.get_live_bookings_with_items($1) AS data', [lounge])).rows[0].data;
  const byId = new Map(rows.map(row => [row.id, row]));
  assert.equal(rows.length, 3);
  assert.equal(byId.get(returning).visit_number, 3);
  assert.equal(byId.get(returning).out_visit_number, 3);
  assert.equal(byId.get(firstVisit).visit_number, 1);
  assert.equal(byId.get(returningGuest).visit_number, 2);
  console.log('PASS active session visits use the full lounge history');
} finally {
  await db.close();
}
