import {createFixtureDatabase} from './runtime/database.mjs';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import assert from 'node:assert/strict';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
const root=resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const runtime=process.env.PLAYSPOT_TEST_RUNTIME ?? resolve(root,'supabase/tests/runtime');
const db = await createFixtureDatabase();
const read=p=>readFileSync(resolve(root,p),'utf8');
const cust='00000000-0000-0000-0000-000000000001';
const staff='00000000-0000-0000-0000-000000000002';
const foreign='00000000-0000-0000-0000-000000000003';
const lounge='10000000-0000-0000-0000-000000000001';
const booking='20000000-0000-0000-0000-000000000001';
const other='20000000-0000-0000-0000-000000000002';
const shift='30000000-0000-0000-0000-000000000001';
let passed=0;
async function actor(id){await db.exec(`RESET ROLE; SELECT set_config('request.jwt.claim.sub','${id}',false); SET ROLE authenticated;`);}
async function admin(sql){await db.exec('RESET ROLE');return db.exec(sql);}
async function snapshot(){await db.exec('RESET ROLE');return (await db.query(`SELECT
 (SELECT balance FROM public.user_wallets WHERE user_id='${cust}') as balance,
 (SELECT count(*) FROM public.wallet_transactions) as transactions,
 (SELECT count(*) FROM public.payments) as payments,
 (SELECT count(*) FROM public.shift_payments) as shift_payments,
 (SELECT payment_status FROM public.bookings WHERE id='${booking}') as payment_status,
 (SELECT jsonb_agg(to_jsonb(b) ORDER BY id) FROM public.bookings b) as bookings`)).rows[0];}
async function denied(name,id,sql,code){const before=await snapshot();await actor(id);
 await assert.rejects(()=>db.query(sql),e=>e.code===code);
 assert.deepEqual(await snapshot(),before);passed++;console.log('PASS '+name);}
async function check(name,fn){await fn();passed++;console.log('PASS '+name);}
try {
 await db.exec(read('supabase/tests/fixtures/wallet_integrity_fixture.sql'));
 const old=read('supabase/review/migrations/20260930220000_p2_advanced_operations_and_wallets.sql');
 await db.exec(old.slice(old.indexOf('CREATE TABLE IF NOT EXISTS public.user_wallets'),old.indexOf('-- ============================================================================',old.indexOf('GRANT EXECUTE ON FUNCTION public.refund_to_wallet'))));
 await db.exec(read('supabase/review/migrations/20261001090000_wallet_payment_integrity_and_unsafe_credit_containment.sql'));
 await admin(`INSERT INTO auth.users VALUES('${cust}'),('${staff}'),('${foreign}');
 INSERT INTO public.user_wallets(user_id,balance) VALUES('${cust}',250);
 INSERT INTO public.fixture_permissions VALUES('${staff}','${lounge}','billing_checkout');
 INSERT INTO public.shifts VALUES('${shift}','${lounge}','open',NULL,now());
 INSERT INTO public.bookings(id,user_id,lounge_id,status,payment_status,total_price)
 VALUES('${booking}','${cust}','${lounge}','completed','unpaid',100),
 ('${other}','${foreign}','${lounge}','completed','unpaid',100);`);
 await denied('anonymous wallet read','',`SELECT public.get_or_create_user_wallet('${cust}')`,'28000');
 await denied('cross-user wallet read',foreign,`SELECT public.get_or_create_user_wallet('${cust}')`,'42501');
 await denied('unverified credit revoked',cust,`SELECT public.topup_user_wallet(250,'vodafone_cash',NULL,'fake')`,'42501');
 await denied('unsafe refund revoked',staff,`SELECT public.refund_to_wallet('${booking}',500,'fake')`,'55000');
 await denied('private recorder inaccessible',cust,`SELECT private.record_verified_booking_payment('${booking}','app_wallet',100)`,'42501');
 await denied('anonymous payment','',`SELECT public.pay_with_wallet('${booking}',100,'a')`,'28000');
 await denied('cross-user booking',foreign,`SELECT public.pay_with_wallet('${booking}',100,'a')`,'42501');
 await denied('underpayment',cust,`SELECT public.pay_with_wallet('${booking}',1,'a')`,'22023');
 await denied('overpayment',cust,`SELECT public.pay_with_wallet('${booking}',101,'a')`,'22023');
 for(const value of ['NULL','0','-1',"'NaN'::numeric","'Infinity'::numeric",'100.001'])
   await denied('invalid amount '+value,cust,`SELECT public.pay_with_wallet('${booking}',${value},'a')`,'22023');
 await denied('missing key',cust,`SELECT public.pay_with_wallet('${booking}',100,NULL)`,'22023');
 await denied('empty key',cust,`SELECT public.pay_with_wallet('${booking}',100,' ')`,'22023');
 await denied('cash wallet bypass',staff,`SELECT public.complete_booking_payment('${booking}','app_wallet',100)`,'22023');
 await admin(`UPDATE public.shifts SET status='closed',closed_at=now();`);
 await denied('closed shift',cust,`SELECT public.pay_with_wallet('${booking}',100,'a')`,'55000');
 await admin(`UPDATE public.shifts SET status='open',closed_at=NULL; UPDATE public.user_wallets SET is_frozen=true;`);
 await denied('frozen wallet',cust,`SELECT public.pay_with_wallet('${booking}',100,'a')`,'55000');
 await admin(`UPDATE public.user_wallets SET is_frozen=false,balance=50;`);
 await denied('insufficient funds',cust,`SELECT public.pay_with_wallet('${booking}',100,'a')`,'55000');
 await admin(`UPDATE public.user_wallets SET balance=250; UPDATE public.bookings SET is_open_time=true,status='in_progress' WHERE id='${booking}';`);
 await denied('open session unsettled total',cust,`SELECT public.pay_with_wallet('${booking}',100,'a')`,'55000');
 await admin(`UPDATE public.bookings SET is_open_time=false,status='cancelled' WHERE id='${booking}';`);
 await denied('cancelled booking',cust,`SELECT public.pay_with_wallet('${booking}',100,'a')`,'55000');
 await admin(`UPDATE public.bookings SET status='completed' WHERE id='${booking}';
 CREATE FUNCTION public.fixture_fail_shift_payment() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'fixture failure' USING ERRCODE='P0001'; END; $$;
 CREATE TRIGGER fixture_fail BEFORE INSERT ON public.shift_payments FOR EACH ROW EXECUTE FUNCTION public.fixture_fail_shift_payment();`);
 await denied('atomic rollback after payment insert',cust,`SELECT public.pay_with_wallet('${booking}',100,'a')`,'P0001');
 await admin('DROP TRIGGER fixture_fail ON public.shift_payments;');
 await check('ledger-backed payment keeps completed status',async()=>{
   await actor(cust);const result=(await db.query(`SELECT public.pay_with_wallet('${booking}',100,'payment-1') AS value`)).rows[0].value;
   assert.equal(result.status,'completed');assert.equal(result.amount_deducted,100);assert.equal(result.remaining_balance,150);
   assert.equal(result.amount_due,0);const state=await snapshot();assert.equal(state.payment_status,'paid');assert.equal(Number(state.transactions),1);assert.equal(Number(state.payments),1);assert.equal(Number(state.shift_payments),1);
 });
 await check('same request does not debit or collect twice',async()=>{
   const before=await snapshot();await actor(cust);const result=(await db.query(`SELECT public.pay_with_wallet('${booking}',100,'payment-1') AS value`)).rows[0].value;
   assert.equal(result.idempotent,true);assert.deepEqual(await snapshot(),before);
 });
 await denied('same key altered amount',cust,`SELECT public.pay_with_wallet('${booking}',99,'payment-1')`,'22023');
 await denied('other owner raw key cannot reuse earlier receipt',foreign,`SELECT public.pay_with_wallet('${other}',100,'payment-1')`,'55000');
 await denied('new payment operation for paid booking',cust,`SELECT public.pay_with_wallet('${booking}',100,'payment-2')`,'55000');
 await denied('customer cannot collect cash',cust,`SELECT public.collect_wallet_cash_topup('${cust}','${lounge}',100,'cash-1')`,'42501');
 await denied('cashier cannot collect for another lounge',staff,`SELECT public.collect_wallet_cash_topup('${cust}','10000000-0000-0000-0000-000000000002',100,'cash-1')`,'42501');
 await check('authorized cash collection credits target once',async()=>{
   await actor(staff);const result=(await db.query(`SELECT public.collect_wallet_cash_topup('${cust}','${lounge}',50,'cash-1') AS value`)).rows[0].value;
   assert.equal(result.amount_collected,50);assert.equal(result.balance,200);
   const before=await snapshot();await actor(staff);
   const replay=(await db.query(`SELECT public.collect_wallet_cash_topup('${cust}','${lounge}',50,'cash-1') AS value`)).rows[0].value;
   assert.equal(replay.idempotent,true);assert.deepEqual(await snapshot(),before);
 });
 await denied('cash key changed amount',staff,`SELECT public.collect_wallet_cash_topup('${cust}','${lounge}',60,'cash-1')`,'22023');
 await denied('refund requires billing permission',cust,`SELECT public.refund_to_wallet('${booking}',100,'cancel')`,'42501');
 await denied('refund cannot exceed payment',staff,`SELECT public.refund_to_wallet('${booking}',101,'cancel')`,'22023');
 await denied('partial refund needs separate reviewed contract',staff,`SELECT public.refund_to_wallet('${booking}',50,'cancel')`,'22023');
 await denied('negative refund',staff,`SELECT public.refund_to_wallet('${booking}',-1,'cancel')`,'22023');
 await check('full wallet reversal restores funds once and keeps session completed',async()=>{
   await actor(staff);const result=(await db.query(`SELECT public.refund_to_wallet('${booking}',100,'cancel') AS value`)).rows[0].value;
   assert.equal(result.status,'completed');assert.equal(result.balance_after,300);
   const before=await snapshot();await actor(staff);const replay=(await db.query(`SELECT public.refund_to_wallet('${booking}',100,'cancel') AS value`)).rows[0].value;
   assert.equal(replay.idempotent,true);assert.deepEqual(await snapshot(),before);
 });
 await denied('refund replay changed reason',staff,`SELECT public.refund_to_wallet('${booking}',100,'other')`,'22023');
 await denied('customer cannot record cash collection',foreign,`SELECT public.complete_booking_payment('${other}','cash',100)`,'42501');
 await denied('cash amount must match server total',staff,`SELECT public.complete_booking_payment('${other}','cash',1)`,'22023');
 await check('cash collection records authoritative total once',async()=>{
   await actor(staff);const result=(await db.query(`SELECT public.complete_booking_payment('${other}','cash',100) AS value`)).rows[0].value;
   assert.equal(result.amount_paid,100);assert.equal(result.status,'completed');
   const before=await snapshot();await actor(staff);const replay=(await db.query(`SELECT public.complete_booking_payment('${other}','cash',100) AS value`)).rows[0].value;
   assert.equal(replay.idempotent,true);assert.deepEqual(await snapshot(),before);
 });
 await denied('cash replay different method',staff,`SELECT public.complete_booking_payment('${other}','card',100)`,'22023');
 await denied('cash replay different amount',staff,`SELECT public.complete_booking_payment('${other}','cash',99)`,'22023');
 await admin(`CREATE OR REPLACE FUNCTION public.has_lounge_permission(p_lounge uuid,p_permission text) RETURNS boolean LANGUAGE sql AS 'SELECT NULL::boolean';`);
 await denied('NULL capability fails closed',staff,`SELECT public.collect_wallet_cash_topup('${cust}','${lounge}',50,'null-cap')`,'42501');
 await check('private function has no client execute grant',async()=>{
   await db.exec('RESET ROLE');const grants=(await db.query(`SELECT has_function_privilege('authenticated','private.record_verified_booking_payment(uuid,text,numeric)','execute') AS allowed`)).rows[0];assert.equal(grants.allowed,false);
 });
 await admin(`CREATE OR REPLACE FUNCTION public.has_lounge_permission(p_lounge uuid,p_permission text)
 RETURNS boolean LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$
 SELECT EXISTS(SELECT 1 FROM public.fixture_permissions WHERE actor=auth.uid() AND lounge=p_lounge AND permission=p_permission) $$;
 ALTER TABLE public.bookings ADD COLUMN open_time_pricing_snapshot jsonb,
 ADD COLUMN open_time_started_at timestamptz, ADD COLUMN actual_start_time timestamptz,
 ADD COLUMN created_at timestamptz DEFAULT now(), ADD COLUMN open_time_closed_at timestamptz,
 ADD COLUMN open_time_billing_minutes integer CHECK(open_time_billing_minutes BETWEEN 1 AND 1440),
 ADD COLUMN duration_minutes integer, ADD COLUMN room_price numeric, ADD COLUMN play_mode text,
 ADD COLUMN addons_total numeric;
 CREATE TABLE public.rooms(id uuid PRIMARY KEY,lounge_id uuid,status text,is_available boolean,
 updated_at timestamptz,open_time_minimum_minutes integer,open_time_rounding_minutes integer,
 open_time_max_minutes integer,hourly_rate_single numeric,hourly_rate_multi numeric,hourly_rate numeric);
 CREATE TABLE public.lounges(id uuid PRIMARY KEY,open_time_minimum_minutes integer,
 open_time_rounding_minutes integer,open_time_max_minutes integer);
 INSERT INTO public.fixture_permissions VALUES('${staff}','${lounge}','sessions_control');
 INSERT INTO public.lounges(id) VALUES('${lounge}');
 INSERT INTO public.rooms(id,lounge_id,status,is_available) VALUES('40000000-0000-0000-0000-000000000001','${lounge}','occupied',false);
 INSERT INTO public.bookings(id,user_id,lounge_id,room_id,status,payment_status,total_price,is_open_time,
 open_time_started_at,open_time_pricing_snapshot)
 VALUES('20000000-0000-0000-0000-000000000003','${cust}','${lounge}','40000000-0000-0000-0000-000000000001',
 'in_progress','unpaid',0,true,now()-interval '61 minutes',
 '{"effective_hourly_rate":60,"minimum_minutes":30,"rounding_minutes":15,"max_minutes":30}');`);
 await db.exec(read('supabase/review/migrations/20261001100000_session_close_shift_and_ledger_integrity.sql'));
 const session='20000000-0000-0000-0000-000000000003';
 await denied('anonymous session close','',`SELECT public.complete_booking_session('${session}',NULL)`,'28000');
 await denied('session close capability required',cust,`SELECT public.complete_booking_session('${session}',NULL)`,'42501');
 await denied('session actor cannot be spoofed',staff,`SELECT public.complete_booking_session('${session}','${cust}')`,'42501');
 await admin(`UPDATE public.shifts SET closed_at=now(),status='closed';`);
 await denied('session close requires open same-lounge shift',staff,`SELECT public.complete_booking_session('${session}',NULL)`,'55000');
 await admin(`UPDATE public.shifts SET closed_at=NULL,status='open';`);
 await check('overrun billed without free max cap and no implicit payment',async()=>{
   const before=await snapshot();await actor(staff);
   const result=(await db.query(`SELECT public.complete_booking_session('${session}',NULL) AS value`)).rows[0].value;
   assert.equal(result.billing_minutes,75);assert.equal(result.final_total,75);
   assert.equal(result.amount_paid,0);assert.equal(result.amount_due,75);
   const after=await snapshot();assert.equal(after.transactions,before.transactions);
   assert.equal(after.payments,before.payments);assert.equal(after.shift_payments,before.shift_payments);
 });
 await check('completed session price is stable after snapshot changes',async()=>{
   await admin(`UPDATE public.bookings SET open_time_pricing_snapshot='{ "effective_hourly_rate":900}' WHERE id='${session}'; UPDATE public.shifts SET status='closed',closed_at=now();`);
   await actor(staff);const result=(await db.query(`SELECT public.complete_booking_session('${session}',NULL) AS value`)).rows[0].value;
   assert.equal(result.final_total,75);assert.equal(result.billing_minutes,75);assert.equal(result.idempotent,true);
 });
 await check('paid flag is not proof of collection',async()=>{
   await admin(`UPDATE public.bookings SET payment_status='paid' WHERE id='${session}';`);
   await actor(staff);const result=(await db.query(`SELECT public.complete_booking_session('${session}',NULL) AS value`)).rows[0].value;
   assert.equal(result.amount_paid,0);assert.equal(result.amount_due,75);
 });
 await check('receipt follows actual ledger instead of final total',async()=>{
   await admin(`INSERT INTO public.payments(booking_id,user_id,lounge_id,amount,status) VALUES('${session}','${cust}','${lounge}',50,'completed');`);
   await actor(staff);const result=(await db.query(`SELECT public.complete_booking_session('${session}',NULL) AS value`)).rows[0].value;
   assert.equal(result.amount_paid,50);assert.equal(result.amount_due,25);
 });
 await admin(`UPDATE public.shifts SET status='open',closed_at=NULL;
 UPDATE public.bookings SET status='in_progress',payment_status='unpaid',open_time_started_at=now()-interval '30 minutes 6 seconds',
 open_time_pricing_snapshot='{"effective_hourly_rate":60,"minimum_minutes":30,"rounding_minutes":15}' WHERE id='${session}';
 UPDATE public.rooms SET status='occupied',is_available=false;`);
 await check('fractional minute rounds up before billing quantum',async()=>{
   await actor(staff);const result=(await db.query(`SELECT public.complete_booking_session('${session}',NULL) AS value`)).rows[0].value;
   assert.equal(result.billing_minutes,45);assert.equal(result.final_total,45);
 });
 await admin(`UPDATE public.bookings SET status='in_progress',open_time_pricing_snapshot='{"effective_hourly_rate":60,"minimum_minutes":30,"rounding_minutes":0}' WHERE id='${session}';`);
 await denied('invalid rounding fails atomically',staff,`SELECT public.complete_booking_session('${session}',NULL)`,'22023');
 await admin(`UPDATE public.bookings SET open_time_pricing_snapshot='{"effective_hourly_rate":60,"minimum_minutes":30,"rounding_minutes":15}' WHERE id='${session}';
 UPDATE public.rooms SET status='maintenance',is_available=false;`);
 await check('close preserves maintenance state',async()=>{
   await actor(staff);await db.query(`SELECT public.complete_booking_session('${session}',NULL)`);
   await db.exec('RESET ROLE');const room=(await db.query('SELECT status,is_available FROM public.rooms')).rows[0];
   assert.equal(room.status,'maintenance');assert.equal(room.is_available,false);
 });
 await admin(`UPDATE public.bookings SET status='in_progress',open_time_started_at=now()-interval '25 hours',
 open_time_pricing_snapshot='{"effective_hourly_rate":60,"minimum_minutes":30,"rounding_minutes":15,"max_minutes":30}' WHERE id='${session}';`);
 await check('long overrun can close beyond old 1440-minute constraint',async()=>{
   await actor(staff);const result=(await db.query(`SELECT public.complete_booking_session('${session}',NULL) AS value`)).rows[0].value;
   assert.ok(result.billing_minutes>1440);assert.ok(result.final_total>1440);
 });
 await admin(`UPDATE public.bookings SET status='in_progress' WHERE id='${session}'; UPDATE public.rooms SET status='occupied',is_available=false;
 INSERT INTO public.bookings(id,user_id,lounge_id,room_id,status,payment_status,total_price)
 VALUES('20000000-0000-0000-0000-000000000004','${cust}','${lounge}','40000000-0000-0000-0000-000000000001','in_progress','unpaid',100);`);
 await check('closing one session cannot free a room with another active session',async()=>{
   await actor(staff);await db.query(`SELECT public.complete_booking_session('${session}',NULL)`);
   await db.exec('RESET ROLE');const room=(await db.query('SELECT status,is_available FROM public.rooms')).rows[0];
   assert.equal(room.status,'occupied');assert.equal(room.is_available,false);
 });
 await check('private completion receipt is not callable by clients',async()=>{
   await db.exec('RESET ROLE');const value=(await db.query(`SELECT has_function_privilege('authenticated','private.booking_completion_receipt(uuid,boolean)','execute') AS allowed`)).rows[0];assert.equal(value.allowed,false);
 });
 console.log(JSON.stringify({passed,engine:(await db.query('SELECT version()')).rows[0],limitations:['Synthetic minimal schema; production triggers are not mirrored','Single connection; concurrent sessions not tested','No live database contacted']}));
} finally {await db.close();}
