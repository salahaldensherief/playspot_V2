// Rollback-only, synthetic test against the guarded local exact-schema restore.
const assert = require('node:assert/strict');
const { randomUUID } = require('node:crypto');
const { readFileSync } = require('node:fs');
const { join } = require('node:path');
const { Client } = require('../runtime/node_modules/pg');

assert.equal(process.env.PLAYSPOT_EXACT_SCHEMA_TEST, '1');
const target = new URL(process.env.PLAYSPOT_ISOLATED_DB_URL || '');
assert.ok(['localhost', '127.0.0.1'].includes(target.hostname));
const migration = readFileSync(join(__dirname,
  '../../migrations/20261025170000_guard_pre_session_manual_transfer_total.sql'), 'utf8');

async function asOwner(db, owner, sql, args) {
  await db.query('SET LOCAL ROLE authenticated');
  await db.query("SELECT set_config('request.jwt.claim.sub',$1,true)", [owner]);
  const result = await db.query(sql, args);
  await db.query('RESET ROLE');
  return result;
}

async function state(db, booking) {
  return (await db.query(`SELECT b.status::text, b.payment_status, b.deposit_amount,
    (SELECT count(*)::int FROM public.payments WHERE booking_id=b.id) AS payment_rows,
    (SELECT coalesce(sum(amount),0) FROM public.payments WHERE booking_id=b.id AND status='completed') AS paid,
    (SELECT count(*)::int FROM public.shift_payments WHERE booking_id=b.id) AS shift_rows,
    (SELECT coalesce(sum(amount),0) FROM public.shift_payments WHERE booking_id=b.id) AS shift_total
    FROM public.bookings b WHERE b.id=$1`, [booking])).rows[0];
}

(async () => {
  const db = new Client({ connectionString: target.toString() });
  await db.connect();
  try {
    assert.equal((await db.query(`SELECT token FROM private.playspot_isolated_test_guard
      WHERE token='PLAYSPOT_DISPOSABLE_EXACT_SCHEMA_20261025'`)).rowCount, 1);
    await db.query('BEGIN');
    const [owner, customer, lounge, room, shift, booking] = Array.from({length: 6}, randomUUID);
    for (const id of [owner, customer]) await db.query('INSERT INTO auth.users(id) VALUES($1)', [id]);
    await db.query(`INSERT INTO public.app_permissions(key,name_ar,name_en,category,
      default_super_admin,default_owner,default_cashier)
      VALUES('billing_checkout','Synthetic billing','Synthetic billing','billing',true,true,false)
      ON CONFLICT(key) DO NOTHING`);
    await db.query(`INSERT INTO public.profiles(id,role,is_active,is_banned)
      VALUES($1,'owner',true,false),($2,'user',true,false)`, [owner, customer]);
    await db.query(`INSERT INTO public.lounges(id,owner_id,name,status,is_active,instapay_account,
      allow_cash_payment,require_deposit_for_future,future_deposit_percentage)
      VALUES($1,$2,'Synthetic transfer guard','active',true,'TEST-ONLY',true,true,20)`, [lounge, owner]);
    await db.query('UPDATE public.profiles SET lounge_id=$1 WHERE id=$2', [lounge, owner]);
    await db.query(`INSERT INTO public.rooms(id,lounge_id,name,status,hourly_rate_single)
      VALUES($1,$2,'Fixture PC','available',100)`, [room, lounge]);
    await db.query(`INSERT INTO public.shifts(id,lounge_id,status,cashier_id,staff_user_id,opened_at)
      VALUES($1,$2,'open',$3,$3,now())`, [shift, lounge, owner]);
    await db.query(`INSERT INTO public.bookings(id,user_id,lounge_id,room_id,date,start_time,end_time,
      status,room_price,total_price,payment_status,payment_method,receipt_url,sender_wallet_phone,
      deposit_required,deposit_amount,deposit_paid)
      VALUES($1,$2,$3,$4,current_date+2,'10:00','11:00','pending',100,100,'unpaid',
      'manual_transfer','https://example.invalid/synthetic-proof','01000000000',true,20,false)`,
      [booking, customer, lounge, room]);

    await db.query('SAVEPOINT before_baseline');
    const before = (await asOwner(db, owner,
      'SELECT public.approve_manual_booking($1,$2) AS result', [booking, owner])).rows[0].result;
    const baseline = await state(db, booking);
    assert.equal(Number(before.delta_collected), 100);
    assert.equal(baseline.payment_status, 'paid');
    assert.equal(Number(baseline.paid), 100);
    assert.equal(Number(baseline.shift_total), 100);
    await db.query('ROLLBACK TO SAVEPOINT before_baseline');

    await db.query(migration);
    await db.query('SAVEPOINT before_approval');
    let approvalError;
    try {
      await asOwner(db, owner, 'SELECT public.approve_manual_booking($1,$2)', [booking, owner]);
    } catch (error) { approvalError = error; }
    assert.equal(approvalError?.message,
      'PRE_SESSION_MANUAL_TRANSFER_REQUIRES_VERIFIED_DEPOSIT_CONTRACT');
    await db.query('ROLLBACK TO SAVEPOINT before_approval');
    const after = await state(db, booking);
    assert.equal(after.payment_status, 'unpaid');
    assert.equal(after.payment_rows, 0);
    assert.equal(after.shift_rows, 0);
    assert.equal(Number(after.paid), 0);
    assert.equal(Number(after.shift_total), 0);

    await db.query('SAVEPOINT before_direct');
    let directError;
    try {
      await asOwner(db, owner,
        "SELECT public.complete_booking_payment($1,'manual_transfer',NULL)", [booking]);
    } catch (error) { directError = error; }
    assert.equal(directError?.message,
      'PRE_SESSION_MANUAL_TRANSFER_REQUIRES_VERIFIED_DEPOSIT_CONTRACT');
    await db.query('ROLLBACK TO SAVEPOINT before_direct');
    assert.equal((await state(db, booking)).shift_rows, 0);

    await db.query("UPDATE public.bookings SET status='completed' WHERE id=$1", [booking]);
    await db.query('SAVEPOINT before_mixed_method_probe');
    await db.query(`INSERT INTO public.payments(booking_id,user_id,lounge_id,amount,
      commission_rate,commission,net_to_lounge,payment_method,status)
      VALUES($1,$2,$3,20,0.15,3,17,'manual_transfer','completed')`,
      [booking, customer, lounge]);
    await db.query(`INSERT INTO public.shift_payments(shift_id,lounge_id,booking_id,
      payment_method,category,amount)
      VALUES($1,$2,$3,'manual_transfer','gaming_time',20)`, [shift, lounge, booking]);
    await db.query("UPDATE public.bookings SET payment_status='partial',deposit_paid=true WHERE id=$1", [booking]);
    await db.query('SAVEPOINT before_mixed_cash');
    let mixedError;
    try {
      await asOwner(db, owner,
        'SELECT public.collect_booking_cash_partial($1,$2,$3,$4)',
        [booking, shift, 8000, randomUUID()]);
    } catch (error) { mixedError = error; }
    assert.equal(mixedError?.message, 'PAYMENT_REQUIRES_RECONCILIATION');
    await db.query('ROLLBACK TO SAVEPOINT before_mixed_cash');
    assert.equal(Number((await state(db, booking)).shift_total), 20);
    await db.query('ROLLBACK TO SAVEPOINT before_mixed_method_probe');

    const final = (await asOwner(db, owner,
      "SELECT public.complete_booking_payment($1,'manual_transfer',NULL) AS result", [booking])).rows[0].result;
    assert.equal(Number(final.delta_collected), 100);
    const settled = await state(db, booking);
    assert.equal(settled.payment_status, 'paid');
    assert.equal(Number(settled.paid), 100);
    assert.equal(Number(settled.shift_total), 100);
    process.stdout.write(JSON.stringify({scenario:'pre-session transfer guard',
      baseline:{status:baseline.payment_status,paid:Number(baseline.paid),shift:Number(baseline.shift_total)},
      guarded:{error:approvalError.message,paid:Number(after.paid),shift:Number(after.shift_total)},
      mixed_method_blocker:mixedError.message,
      completed:{status:settled.payment_status,paid:Number(settled.paid),shift:Number(settled.shift_total)}})+'\n');
    await db.query('ROLLBACK');
  } catch (error) {
    try { await db.query('ROLLBACK'); } catch (_) {}
    throw error;
  } finally {
    await db.end();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
