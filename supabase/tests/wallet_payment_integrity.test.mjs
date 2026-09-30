import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import assert from 'node:assert/strict';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
const root=resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const runtime=process.env.PLAYSPOT_TEST_RUNTIME ?? resolve(root,'supabase/tests/runtime');
const {PGlite}=createRequire(resolve(runtime,'package.json'))('@electric-sql/pglite');
const db=new PGlite();
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
 (SELECT payment_status FROM public.bookings WHERE id='${booking}') as payment_status`)).rows[0];}
async function denied(name,id,sql,code){const before=await snapshot();await actor(id);
 await assert.rejects(()=>db.query(sql),e=>e.code===code);
 assert.deepEqual(await snapshot(),before);passed++;console.log('PASS '+name);}
async function check(name,fn){await fn();passed++;console.log('PASS '+name);}
try {
 await db.exec(read('supabase/tests/fixtures/wallet_integrity_fixture.sql'));
 const old=read('supabase/migrations/20260930220000_p2_advanced_operations_and_wallets.sql');
 await db.exec(old.slice(old.indexOf('CREATE TABLE IF NOT EXISTS public.user_wallets'),old.indexOf('-- ============================================================================',old.indexOf('GRANT EXECUTE ON FUNCTION public.refund_to_wallet'))));
 await db.exec(read('supabase/migrations/20261001090000_wallet_payment_integrity_and_unsafe_credit_containment.sql'));
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
 await denied('same key different owner',foreign,`SELECT public.pay_with_wallet('${other}',100,'payment-1')`,'22023');
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
 console.log(JSON.stringify({passed,engine:(await db.query('SELECT version()')).rows[0],limitations:['Synthetic minimal schema; production triggers are not mirrored','Single connection; concurrent sessions not tested','No live database contacted']}));
} finally {await db.close();}
