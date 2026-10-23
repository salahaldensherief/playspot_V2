import {createFixtureDatabase} from './runtime/database.mjs';
import {readFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
const db=await createFixtureDatabase();
const id=n=>`00000000-0000-0000-0000-${String(n).padStart(12,'0')}`;
const lounge=id(1),room=id(2),customer=id(3),staff=id(4),booking=id(5),shift=id(6);
let passed=0;
async function check(name,body) {
  await db.exec('BEGIN');
  try {await body(); passed++; console.log('PASS '+name);} finally {await db.exec('ROLLBACK');}
}
async function extend(minutes=30) {
  return (await db.query('SELECT extend_booking_session($1,$2,0) r',[booking,minutes])).rows[0].r;
}
async function stored() {return (await db.query('SELECT * FROM bookings WHERE id=$1',[booking])).rows[0];}
async function denied(action,code) {
  await db.exec('SAVEPOINT denied');
  await assert.rejects(action(),e=>e.code===code);
  await db.exec('ROLLBACK TO SAVEPOINT denied; RELEASE SAVEPOINT denied');
}
try {
  await db.exec(await readFile(new URL('./runtime/checkout_canteen_schema.sql',import.meta.url),'utf8'));
  const pricing=await readFile(new URL('../migrations/20261007000015_pricing_engine_contract_v2.sql',import.meta.url),'utf8');
  const start=pricing.indexOf('CREATE OR REPLACE FUNCTION private.price_room_interval(');
  const tail=pricing.slice(start),tag=tail.match(/AS (\$[a-z_]*\$)/i)[1];
  await db.exec(tail.slice(0,tail.indexOf(tag+';',tail.indexOf(tag)+tag.length)+tag.length+1));
  await db.exec(`ALTER TABLE bookings ADD pricing_snapshot jsonb DEFAULT '{}',ADD pricing_rule_ids uuid[] DEFAULT '{}';
    CREATE FUNCTION public.has_lounge_permission(uuid,text) RETURNS boolean LANGUAGE sql AS $$SELECT auth.uid()='${staff}'::uuid$$;
    CREATE FUNCTION private.assert_lounge_operator(uuid,boolean) RETURNS void LANGUAGE plpgsql AS $$BEGIN
      IF NOT public.has_lounge_permission($1,'sessions_control') THEN RAISE EXCEPTION 'NOT_AUTHORIZED' USING ERRCODE='42501'; END IF; END$$;
    CREATE TABLE shift_audit_logs(id uuid,entity_type text,entity_id uuid,action text,created_at timestamptz,old_data jsonb,new_data jsonb);
    CREATE TABLE payments(booking_id uuid UNIQUE,user_id uuid,lounge_id uuid,amount numeric,commission numeric,
      net_to_lounge numeric,payment_method text,status text,paid_at timestamptz,discount_amount numeric,
      discount_percentage numeric,discount_reason text,discount_approved_by uuid);
    CREATE TABLE notifications(user_id uuid,lounge_id uuid,title_ar text,title_en text,body_ar text,body_en text,type text,is_read boolean,metadata jsonb);
    INSERT INTO lounges(id,name) VALUES('${lounge}','Fixture');
    INSERT INTO rooms(id,lounge_id,name,hourly_rate_single,hourly_rate_multi,extra_controller_price)
      VALUES('${room}','${lounge}','Room',80,120,10);
    INSERT INTO shifts(id,lounge_id,status) VALUES('${shift}','${lounge}','open');`);
  await db.exec(await readFile(new URL('../migrations/20261007114816_client_request_contract_completion.sql',import.meta.url),'utf8'));
  await db.exec(await readFile(new URL('../migrations/20261007115950_approved_extension_payment_integrity.sql',import.meta.url),'utf8'));
  await db.exec(`CREATE TRIGGER clamp BEFORE INSERT OR UPDATE ON bookings FOR EACH ROW EXECUTE FUNCTION fn_validate_and_clamp_booking_price();
    INSERT INTO bookings(id,user_id,lounge_id,room_id,date,start_time,end_time,duration_minutes,status,
      room_price,total_price,discount_amount,extra_controllers,shift_id)
    VALUES('${booking}','${customer}','${lounge}','${room}','2026-10-12','18:00','20:00',120,'in_progress',0,0,20,2,'${shift}');
    SET request.jwt.claim.sub='${staff}';`);
  await db.exec(await readFile(new URL('../../docs/audits/playspot-launch-v2/evidence/approve_booking_extension.sql',import.meta.url),'utf8'));
  await db.exec(`UPDATE bookings SET payment_status='paid',extension_status='pending',requested_extension_minutes=30;
    INSERT INTO payments(booking_id,user_id,lounge_id,amount,status,payment_method) VALUES('${booking}','${customer}','${lounge}',180,'completed','cash');`);
  const before=(await db.query('SELECT amount FROM payments WHERE booking_id=$1',[booking])).rows[0].amount;
  const r=(await db.query('SELECT approve_booking_extension($1) r',[booking])).rows[0].r;
  const after=(await db.query('SELECT amount FROM payments WHERE booking_id=$1',[booking])).rows[0].amount;
  const ledger=(await db.query('SELECT sum(amount) amount FROM shift_payments WHERE booking_id=$1',[booking])).rows[0].amount;
  assert.equal(Number(before),180); assert.equal(Number(after),230); assert.equal(Number(ledger),50);
  console.log(JSON.stringify({finding:'PS-004',result:'DEFECT REPRODUCED in isolated minimal fixture',beforePaid:Number(before),afterPaid:Number(after),newShiftCollection:Number(ledger),explicitCollectionCalls:0,extensionCost:r.extension_cost}));
} finally {await db.close();}
