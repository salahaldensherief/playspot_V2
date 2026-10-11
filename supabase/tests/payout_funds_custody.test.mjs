import {installLatestFunctions} from './runtime/latest_contracts.mjs';
import {createFixtureDatabase} from './runtime/database.mjs';
import {lockedRace} from './runtime/locked_race.mjs';
import {readFile} from 'node:fs/promises';
import assert from 'node:assert/strict';

const db=await createFixtureDatabase();
const id=n=>`00000000-0000-0000-0000-${String(n).padStart(12,'0')}`;
const admin=id(1),lounge=id(2),cash=id(3),electronic=id(4),venueTransfer=id(5);
let passed=0;
async function check(name,body) {
  await db.exec('BEGIN');
  try {await body();passed++;console.log('PASS '+name);} finally {await db.exec('ROLLBACK');}
}
async function denied(action,code='55000') {
  await db.exec('SAVEPOINT denied');
  await assert.rejects(action(),error=>error.code===code);
  await db.exec('ROLLBACK TO SAVEPOINT denied; RELEASE SAVEPOINT denied');
}
const create=async(start='2026-10-01',end='2026-10-31')=>(await db.query(
  'SELECT create_payout($1,$2,$3) r',[lounge,start,end])).rows[0].r;
const record=(payment,holder,reference='bank-statement-fixture')=>db.query(
  'SELECT record_payment_funds_custody($1,$2,$3) r',[payment,holder,reference]);
async function payment(paymentId,method,amount=100,day='2026-10-12') {
  await db.query(`INSERT INTO payments(id,lounge_id,amount,commission,net_to_lounge,payment_method,paid_at)
    VALUES($1,$2,$3,$3::numeric*0.15,$3::numeric*0.85,$4,$5::date+interval '12 hours')`,[paymentId,lounge,amount,method,day]);
}
try {
  await db.exec(`CREATE ROLE anon;CREATE ROLE authenticated;CREATE SCHEMA auth;CREATE SCHEMA private;
    CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql AS $$SELECT nullif(current_setting('test.actor',true),'')::uuid$$;
    CREATE TABLE auth.users(id uuid PRIMARY KEY,banned_until timestamptz);
    CREATE TABLE profiles(id uuid PRIMARY KEY,role text,is_active boolean DEFAULT true,is_banned boolean DEFAULT false);
    CREATE TABLE platform_super_admins(user_id uuid PRIMARY KEY);
    CREATE FUNCTION public.is_super_admin() RETURNS boolean LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$
      SELECT EXISTS(SELECT 1 FROM public.profiles p JOIN auth.users u ON u.id=p.id WHERE p.id=auth.uid()
        AND p.is_active AND NOT p.is_banned AND (u.banned_until IS NULL OR u.banned_until<=now()) AND (p.role IN ('super_admin','superadmin')
          OR EXISTS(SELECT 1 FROM public.platform_super_admins s WHERE s.user_id=p.id)))$$;
    CREATE TABLE lounges(id uuid PRIMARY KEY,name text,name_ar text,name_en text,owner_id uuid);
    CREATE TABLE bookings(id uuid PRIMARY KEY,status text DEFAULT 'completed',payment_status text DEFAULT 'paid');
    CREATE TABLE payouts(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),lounge_id uuid,period_start date,period_end date,
      total_amount numeric,status text,created_by uuid,approved_by uuid,approved_at timestamptz,
      processing_started_by uuid,processing_started_at timestamptz,paid_at timestamptz,paid_by uuid,
      transfer_method text,transfer_reference text,receipt_url text,notes text,cancelled_by uuid,
      cancelled_at timestamptz,cancelled_reason text,failure_reason text);
    CREATE TABLE payments(id uuid PRIMARY KEY,booking_id uuid,user_id uuid,commission_rate numeric DEFAULT 0.15,lounge_id uuid,amount numeric NOT NULL,
      commission numeric NOT NULL,net_to_lounge numeric NOT NULL,payment_method text NOT NULL,
      status text DEFAULT 'completed',paid_at timestamptz,payout_id uuid REFERENCES payouts(id));
    CREATE TABLE private.cash_collection_receipts(booking_id uuid);
    CREATE TABLE private.cash_collection_context(transaction_id bigint,booking_id uuid);
    CREATE TABLE notifications(user_id uuid,lounge_id uuid,title text,title_ar text,title_en text,
      body text,body_ar text,body_en text,type text,is_read boolean,metadata jsonb);
    INSERT INTO auth.users VALUES('${admin}',NULL);
    INSERT INTO profiles(id,role) VALUES('${admin}','super_admin');
    INSERT INTO lounges(id,name,owner_id) VALUES('${lounge}','Fixture','${admin}');
    SELECT set_config('test.actor','${admin}',false);
    GRANT USAGE ON SCHEMA public,auth,private TO authenticated;
    GRANT EXECUTE ON FUNCTION auth.uid() TO authenticated;`);
  await db.exec(await readFile(new URL('../migrations/20261011065428_payout_cash_commission_settlement.sql',import.meta.url),'utf8'));
  await installLatestFunctions(db,["public.get_pending_payouts_overview", "public.create_payout"]);
  await db.exec(`CREATE TRIGGER cash_guard BEFORE INSERT OR UPDATE ON payments
    FOR EACH ROW EXECUTE FUNCTION private.guard_partial_cash_payment();`);
  await check('cash alone never creates an 85% payout',async()=>{
    await payment(cash,'cash');assert.equal((await create()).success,false);
    assert.equal((await db.query('SELECT * FROM get_pending_payouts_overview()')).rows.length,0);
    assert.equal((await db.query('SELECT * FROM payouts')).rows.length,0);
  });
  await check('same electronic method pays different contributions according to custody',async()=>{
    await payment(electronic,'instapay');await payment(venueTransfer,'instapay');
    await record(electronic,'platform');await record(venueTransfer,'lounge');
    const payout=await create();assert.equal(payout.amount,70);assert.equal(payout.payment_count,2);
    const overview=(await db.query('SELECT * FROM get_pending_payouts_overview()')).rows;
    assert.equal(overview.length,0);
    const details=(await db.query('SELECT get_payout_details($1) r',[payout.payout_id])).rows[0].r;
    assert.equal(details.reconciliation.calculated_net,70);assert.equal(details.reconciliation.difference,0);
    await db.query('SELECT approve_payout($1)',[payout.payout_id]);
    await db.query('SELECT start_payout_processing($1)',[payout.payout_id]);
    await denied(()=>db.query('SELECT mark_payout_paid($1)',[payout.payout_id]));
    await db.query("SELECT complete_payout($1,'bank_transfer','verified-transfer')",[payout.payout_id]);
    assert.equal((await db.query('SELECT status FROM payouts')).rows[0].status,'paid');
  });
  await check('cash commission offsets platform money and prior-period debt is carried once',async()=>{
    await payment(cash,'cash',100,'2026-09-01');await payment(electronic,'manual_transfer');
    await record(electronic,'platform');assert.equal((await create()).amount,70);
    await payment(id(7),'manual_transfer',100,'2026-11-01');await record(id(7),'platform');
    assert.equal((await create('2026-11-01','2026-11-30')).amount,85);
  });
  await check('zero or negative balance is retained until later platform receipts offset it',async()=>{
    await payment(cash,'cash',600);await payment(electronic,'card');await record(electronic,'platform');
    assert.equal((await create()).success,false);
    assert.equal((await db.query('SELECT count(*) n FROM payments WHERE payout_id IS NULL')).rows[0].n,'2');
  });
  await check('unclassified historical transfers block payout even outside the start date',async()=>{
    await payment(electronic,'manual_transfer',100,'2026-09-01');await payment(cash,'cash');
    await denied(()=>create());
    assert.equal((await db.query('SELECT get_payment_funds_review() r')).rows[0].r.length,1);
    await record(electronic,'lounge');assert.equal((await create()).success,false);
  });
  await check('custody evidence is immutable and exact retries are idempotent',async()=>{
    await payment(electronic,'manual_transfer');await record(electronic,'platform');
    assert.equal((await record(electronic,'platform')).rows[0].r.replayed,true);
    await denied(()=>record(electronic,'lounge'));
    await denied(()=>record(electronic,'platform','different-proof'));
    await payment(cash,'cash');await denied(()=>record(cash,'platform'),'22023');
  });
  await check('changed method requires reconciliation instead of stale custody reuse',async()=>{
    await payment(electronic,'instapay');await record(electronic,'platform');
    await db.exec("UPDATE payments SET payment_method='card'");await denied(()=>create());
  });
  await check('new financial revision needs fresh review and preserves old custody evidence',async()=>{
    await payment(electronic,'instapay');await record(electronic,'platform');
    await db.exec('UPDATE payments SET amount=200,commission=30,net_to_lounge=170');
    await denied(()=>create());
    assert.equal((await db.query('SELECT get_payment_funds_review() r')).rows[0].r.length,1);
    await record(electronic,'lounge','new-account-statement');
    assert.equal((await db.query('SELECT count(*) n FROM private.payment_funds_custody')).rows[0].n,'2');
    assert.equal((await create()).success,false);
  });
  await check('legacy payouts without a snapshot cannot be approved or paid directly',async()=>{
    await db.query("INSERT INTO payouts(id,lounge_id,total_amount,status) VALUES($1,$2,85,'pending')",[id(8),lounge]);
    await denied(()=>db.query('SELECT approve_payout($1)',[id(8)]));
    await denied(()=>db.query("UPDATE payouts SET status='paid',transfer_method='cash',transfer_reference='x'"));
  });
  await check('refund or financial drift blocks settlement before transferring money',async()=>{
    await payment(electronic,'card');await record(electronic,'platform');const p=await create();
    await db.exec("UPDATE payments SET status='refunded'");
    await denied(()=>db.query('SELECT approve_payout($1)',[p.payout_id]));
    await db.exec("UPDATE payments SET status='completed',amount=110,commission=16.5,net_to_lounge=93.5");
    await denied(()=>db.query('SELECT approve_payout($1)',[p.payout_id]));
  });
  await check('partial cash remains collectable and only finalized sessions enter settlement',async()=>{
    await payment(cash,'cash');await payment(electronic,'card');await record(electronic,'platform');
    await db.exec(`INSERT INTO bookings VALUES('${id(9)}','completed','partial');
      UPDATE payments SET booking_id='${id(9)}' WHERE id='${cash}';
      INSERT INTO private.cash_collection_receipts VALUES('${id(9)}');`);
    const p=await create();assert.equal(p.amount,85);
    assert.equal((await db.query('SELECT payout_id FROM payments WHERE id=$1',[cash])).rows[0].payout_id,null);
    await denied(()=>db.query('UPDATE payments SET amount=90 WHERE id=$1',[cash]));
    await db.exec("UPDATE bookings SET payment_status='paid'");
    await db.query('SELECT cancel_payout($1,$2)',[p.payout_id,'cancel fixture']);
    const q=await create();assert.equal(q.amount,70);
    await db.query('SELECT cancel_payout($1,$2)',[q.payout_id,'cancel fixture']);
    assert.equal((await db.query('SELECT count(*) n FROM payments WHERE payout_id IS NULL')).rows[0].n,'2');
  });
  await check('review cancellation releases linked payments and missing review cannot fake success',async()=>{
    await payment(electronic,'card');await record(electronic,'platform');const p=await create();
    await db.exec("UPDATE payouts SET status='needs_review'");
    await db.query("SELECT resolve_payout_review($1,'cancel','fixture reason')",[p.payout_id]);
    assert.equal((await db.query('SELECT payout_id FROM payments')).rows[0].payout_id,null);
    await denied(()=>db.query("SELECT resolve_payout_review($1,'cancel','fixture reason')",[id(99)]),'P0001');
  });
  await check('canonical membership is accepted but inactive, banned and owner actors are denied',async()=>{
    await db.exec(`UPDATE profiles SET role='owner';INSERT INTO platform_super_admins VALUES('${admin}')`);
    await payment(electronic,'card');await record(electronic,'platform');
    await db.exec('UPDATE profiles SET is_banned=true');await denied(()=>create(),'42501');
    await db.exec('UPDATE profiles SET is_banned=false,is_active=false');await denied(()=>create(),'42501');
    await db.exec("UPDATE profiles SET is_active=true;UPDATE auth.users SET banned_until=now()+interval '1 day'");await denied(()=>create(),'42501');
    await db.exec('UPDATE auth.users SET banned_until=NULL;DELETE FROM platform_super_admins');await denied(()=>create(),'42501');
  });
  await check('untrusted roles cannot write private evidence or call private helpers',async()=>{
    await db.exec('SET ROLE authenticated');
    await denied(()=>db.exec('SELECT * FROM private.payment_funds_custody'),'42501');
    await denied(()=>db.exec('SELECT private.assert_payout_admin()'),'42501');
    await db.exec('RESET ROLE;SET ROLE anon');
    await denied(()=>db.exec('SELECT get_payment_funds_review()'),'42501');await db.exec('RESET ROLE');
  });
  await check('Cairo calendar boundary is stable regardless of session timezone',async()=>{
    await payment(electronic,'card');
    await db.exec("UPDATE payments SET paid_at='2026-09-30 22:30:00+00'");
    await record(electronic,'platform');await db.exec("SET LOCAL timezone='America/Los_Angeles'");
    assert.equal((await create('2026-10-01','2026-10-01')).amount,85);
  });
  await check('invalid financial evidence rolls back all payout links',async()=>{
    await payment(electronic,'card');await record(electronic,'platform');
    await db.exec('UPDATE payments SET net_to_lounge=999');await denied(()=>create());
    assert.equal((await db.query('SELECT * FROM payouts')).rows.length,0);
  });
  if(db.connect) {
    await payment(electronic,'card');await record(electronic,'platform');
    const q={sql:'SELECT create_payout($1,$2,$3) r',args:[lounge,'2026-10-01','2026-10-31']};
    const [first,second]=await lockedRace(db,q,q,admin);
    assert.equal(first.rows[0].r.amount,85);assert.equal(second.error?.code,'55000');
    assert.equal((await db.query('SELECT * FROM payouts')).rows.length,1);
    passed++;console.log('PASS concurrent payout creation waits then rejects duplicate allocation');
  }
  console.log(JSON.stringify({passed,environment:'isolated synthetic PostgreSQL; no production writes'}));
} finally {await db.close();}
