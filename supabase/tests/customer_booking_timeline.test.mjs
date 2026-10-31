import {createFixtureDatabase} from './runtime/database.mjs';
import {readFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
const db = await createFixtureDatabase();
const owner='00000000-0000-0000-0000-000000000001';
const other='00000000-0000-0000-0000-000000000002';
const booking='00000000-0000-0000-0000-000000000003';
try {
  await db.exec(`CREATE ROLE anon; CREATE ROLE authenticated; CREATE SCHEMA auth;
    CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql AS $$SELECT NULLIF(current_setting('test.actor',true),'')::uuid$$;
    GRANT USAGE ON SCHEMA public,auth TO authenticated,anon;
    CREATE TABLE bookings(id uuid PRIMARY KEY,user_id uuid,status text,created_at timestamptz,
      approved_at timestamptz,checked_in_at timestamptz,cancelled_at timestamptz,cashier_closed_at timestamptz);
    CREATE TABLE shift_audit_logs(id uuid PRIMARY KEY,entity_type text,entity_id uuid,action text,
      created_at timestamptz,old_data jsonb,new_data jsonb);
    INSERT INTO bookings VALUES('${booking}','${owner}','in_progress','2026-10-01',
      '2026-10-02','2026-10-03',NULL,NULL);
    INSERT INTO shift_audit_logs VALUES(gen_random_uuid(),'booking','${booking}','update','2026-10-03',
      '{"status":"upcoming"}','{"status":"in_progress","receipt_url":"private","actor_id":"private"}');
    INSERT INTO shift_audit_logs VALUES(gen_random_uuid(),'booking','${booking}','update','2026-10-04',
      '{"status":"in_progress","extension_status":"none"}',
      '{"status":"in_progress","extension_status":"pending","sender_wallet_phone":"private"}');`);
  const migration = await readFile(new URL('../migrations/20261007114816_client_request_contract_completion.sql',import.meta.url),'utf8');
  await db.exec(migration.slice(migration.indexOf('CREATE OR REPLACE FUNCTION public.get_booking_timeline'),
    migration.indexOf('CREATE OR REPLACE FUNCTION private.booking_extension_quote')));
  await db.exec(`SET test.actor='${owner}'; SET ROLE authenticated;`);
  const rows=(await db.query(`SELECT * FROM get_booking_timeline_for_customer('${booking}')`)).rows;
  assert.deepEqual(rows.map(x=>x.event_code),[
    'booking_created','booking_approved','booking_checked_in','booking_extension_requested']);
  assert.ok(rows.every(x=>x.title_ar && x.title_en && Object.keys(x.payload).length===0));
  console.log('PASS ordered, deduplicated lifecycle and extension events with safe payload');
  for (const actor of [other,'']) {
    await db.exec(`SET test.actor='${actor}'`);
    await assert.rejects(db.query(`SELECT * FROM get_booking_timeline_for_customer('${booking}')`),e=>e.code==='42501');
    console.log('PASS inaccessible booking rejected for '+(actor||'missing session'));
  }
  await db.exec('RESET ROLE; SET ROLE anon;');
  await assert.rejects(db.query(`SELECT * FROM get_booking_timeline_for_customer('${booking}')`),e=>e.code==='42501');
  console.log('PASS anonymous execution denied');
} finally { await db.close(); }
