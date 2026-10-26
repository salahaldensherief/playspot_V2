// Rollback-only proof of a verified electronic deposit followed by cash settlement.
const assert = require('node:assert/strict');
const { randomUUID } = require('node:crypto');
const { Client } = require('../runtime/node_modules/pg');

assert.equal(process.env.PLAYSPOT_EXACT_SCHEMA_TEST, '1');
const target = new URL(process.env.PLAYSPOT_ISOLATED_DB_URL || '');
assert.ok(['localhost', '127.0.0.1'].includes(target.hostname));

async function actor(db, id, sql, args) {
  await db.query('SET LOCAL ROLE authenticated');
  await db.query("SELECT set_config('request.jwt.claim.sub',$1,true)", [id]);
  const result = await db.query(sql, args);
  await db.query('RESET ROLE');
  await db.query("SELECT set_config('request.jwt.claim.sub','',true)");
  return result;
}

async function rejectsAs(db, id, sql, args, code) {
  await db.query('SAVEPOINT expected_failure');
  await db.query('SET LOCAL ROLE authenticated');
  await db.query("SELECT set_config('request.jwt.claim.sub',$1,true)", [id]);
  await assert.rejects(db.query(sql, args), { code });
  await db.query('ROLLBACK TO SAVEPOINT expected_failure');
  await db.query('RELEASE SAVEPOINT expected_failure');
}

(async () => {
  const db = new Client({ connectionString: target.toString() });
  await db.connect();
  try {
    assert.equal((await db.query(`SELECT 1 FROM private.playspot_isolated_test_guard
      WHERE token='PLAYSPOT_DISPOSABLE_EXACT_SCHEMA_20261025'`)).rowCount, 1);
    await db.query('BEGIN');
    for (const discountPercent of [0, 10]) {
    const expectedTotal = discountPercent ? 135 : 150;
    const expectedCash = expectedTotal - 20;
    const [owner, customer, outsider, lounge, room, shift, booking,
      depositOp, cashOp] = Array.from({ length: 9 }, randomUUID);
    for (const id of [owner, customer, outsider]) {
      await db.query('INSERT INTO auth.users(id) VALUES($1)', [id]);
    }
    await db.query(`INSERT INTO public.app_permissions(key,name_ar,name_en,category,
      default_super_admin,default_owner,default_cashier)
      VALUES('billing_checkout','Synthetic billing','Synthetic billing','billing',true,true,false)
      ON CONFLICT(key) DO NOTHING`);
    await db.query(`INSERT INTO public.profiles(id,role,is_active,is_banned)
      VALUES($1,'owner',true,false),($2,'user',true,false),
      ($3,'user',true,false)`, [owner, customer, outsider]);
    await db.query(`INSERT INTO public.lounges(id,owner_id,name,status,is_active,
      instapay_account,allow_cash_payment,require_deposit_for_future,
      future_deposit_percentage)
      VALUES($1,$2,'Synthetic mixed checkout','active',true,'TEST-ONLY',true,true,20)`, [lounge, owner]);
    await db.query('UPDATE public.profiles SET lounge_id=$1 WHERE id=$2', [lounge, owner]);
    await db.query(`INSERT INTO public.rooms(id,lounge_id,name,status,hourly_rate_single)
      VALUES($1,$2,'Fixture PC','available',100)`, [room, lounge]);
    await db.query(`INSERT INTO public.shifts(id,lounge_id,status,cashier_id,staff_user_id,
      opened_at) VALUES($1,$2,'open',$3,$3,now())`, [shift, lounge, owner]);
    await db.query(`INSERT INTO public.bookings(id,user_id,lounge_id,room_id,date,
      start_time,end_time,status,room_price,total_price,payment_status,
      payment_method,sender_wallet_phone,receipt_url,deposit_required,
      deposit_amount,deposit_paid,confirmation_status)
      VALUES($1,$2,$3,$4,current_date+2,'10:00','11:00','upcoming',
      100,100,'unpaid','manual_transfer','01000000000','synthetic-receipt',
      true,20,false,'confirmed')`, [booking, customer, lounge, room]);
    const deposit = (await actor(db, owner,
      'SELECT public.verify_booking_deposit_transfer($1,$2,$3,$4,$5) AS result',
      [booking, shift, depositOp, 'SYNTHETIC-BANK-REFERENCE', 'platform'])).rows[0].result;
    assert.equal(Number(deposit.collected_minor), 2000);
    await db.query(`UPDATE public.bookings SET status='completed',
      addons_price=50,addons_total=50 WHERE id=$1`, [booking]);
    const beforeCash = (await db.query(`SELECT total_price,room_price,payment_status,
      private.cash_collection_paid_amount(id,lounge_id,payment_status) AS paid
      FROM public.bookings WHERE id=$1`, [booking])).rows[0];
    assert.equal(Number(beforeCash.total_price), 150);
    assert.equal(Number(beforeCash.paid), 20);
    const cashSql = `SELECT public.checkout_booking_cash_atomic(
      $1,$2,$3,$4,$5,$6,$7) AS result`;
    const discountReason = discountPercent ? 'Synthetic approved discount' : null;
    const cashArgs = [booking, shift, null, cashOp, 0, discountPercent, discountReason];
    await rejectsAs(db, outsider, cashSql, cashArgs, '42501');
    await rejectsAs(db, owner, cashSql,
      [booking, shift, 13100, randomUUID(), 0, discountPercent,
        discountReason], '22023');
    const cash = (await actor(db, owner, cashSql, cashArgs)).rows[0].result;
    assert.equal(Number(cash.collected_minor), expectedCash * 100);
    assert.equal(Number(cash.due_minor), 0);
    assert.equal(cash.replayed, false);
    const replay = (await actor(db, owner, cashSql, cashArgs)).rows[0].result;
    assert.equal(replay.replayed, true);
    assert.equal(replay.movement_id, cash.movement_id);
    const result = (await db.query(`SELECT b.payment_status,b.payment_method,
      b.total_price,
      p.amount,p.commission,p.payment_method AS aggregate_method,
      (SELECT count(*)::int FROM private.booking_money_movements
        WHERE booking_id=b.id) AS movement_count,
      (SELECT sum(amount_minor) FROM private.booking_money_movements
        WHERE booking_id=b.id) AS movement_minor,
      (SELECT sum(commission_minor) FROM private.booking_money_movements
        WHERE booking_id=b.id) AS commission_minor,
      (SELECT sum(amount) FROM public.shift_payments
        WHERE booking_id=b.id) AS shift_amount,
      (SELECT count(*)::int FROM public.shift_payments
        WHERE booking_id=b.id) AS shift_count
      FROM public.bookings b JOIN public.payments p ON p.booking_id=b.id
      WHERE b.id=$1`, [booking])).rows[0];
    assert.equal(result.payment_status, 'paid');
    assert.equal(result.payment_method, 'mixed');
    assert.equal(result.aggregate_method, 'mixed');
    assert.equal(Number(result.total_price), expectedTotal);
    assert.equal(Number(result.amount), expectedTotal);
    assert.equal(Number(result.commission), expectedTotal * 0.15);
    assert.equal(result.movement_count, 2);
    assert.equal(Number(result.movement_minor), expectedTotal * 100);
    assert.equal(Number(result.commission_minor), expectedTotal * 15);
    assert.equal(Number(result.shift_amount), expectedTotal);
    assert.equal(result.shift_count, 2);
    const methods = (await db.query(`SELECT payment_method,amount_minor,funds_holder
      FROM private.booking_money_movements WHERE booking_id=$1 ORDER BY amount_minor`,
      [booking])).rows;
    assert.deepEqual(methods.map(m => [m.payment_method, Number(m.amount_minor), m.funds_holder]),
      [['manual_transfer', 2000, 'platform'],
        ['cash', expectedCash * 100, 'lounge']]);
    await rejectsAs(db, owner, cashSql,
      [booking, shift, 100, randomUUID(), 0, 0, null], '22023');
    await db.query(`UPDATE public.shifts SET status='closed',closed_at=now()
      WHERE id=$1`, [shift]);
    assert.equal((await actor(db, owner, cashSql, cashArgs)).rows[0].result.replayed, true);
    process.stdout.write(JSON.stringify({ scenario: 'mixed deposit and cash',
      discount_percentage: discountPercent,
      deposit_minor: 2000, cash_minor: expectedCash * 100, due_minor: 0,
      movement_count: result.movement_count, commission_minor: Number(result.commission_minor),
      replay: true }) + '\n');
    }
    await db.query('ROLLBACK');
  } catch (error) {
    try { await db.query('ROLLBACK'); } catch (_) {}
    throw error;
  } finally {
    await db.end();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
