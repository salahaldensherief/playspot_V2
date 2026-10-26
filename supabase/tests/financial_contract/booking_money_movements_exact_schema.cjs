// Synthetic, rollback-only structural proof against the preserved exact schema.
const assert = require('node:assert/strict');
const { randomUUID } = require('node:crypto');
const { Client } = require('../runtime/node_modules/pg');

assert.equal(process.env.PLAYSPOT_EXACT_SCHEMA_TEST, '1');
const target = new URL(process.env.PLAYSPOT_ISOLATED_DB_URL || '');
assert.ok(['localhost', '127.0.0.1'].includes(target.hostname));

async function rejectsWith(db, query, args, code) {
  await db.query('SAVEPOINT expected_failure');
  await assert.rejects(db.query(query, args), { code });
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
    const [owner, customer, lounge, room, shift, booking, payment, transferShift,
      cashShift, transferMovement, cashMovement, payout, retryPayout] =
      Array.from({ length: 13 }, randomUUID);
    for (const user of [owner, customer]) {
      await db.query('INSERT INTO auth.users(id) VALUES($1)', [user]);
    }
    await db.query(`INSERT INTO public.profiles(id,role,is_active,is_banned)
      VALUES($1,'owner',true,false),($2,'user',true,false)`, [owner, customer]);
    await db.query(`INSERT INTO public.lounges(id,owner_id,name,status,is_active,
      allow_cash_payment,instapay_account)
      VALUES($1,$2,'Synthetic movement proof','active',true,true,'TEST-ONLY')`, [lounge, owner]);
    await db.query('UPDATE public.profiles SET lounge_id=$1 WHERE id=$2', [lounge, owner]);
    await db.query(`INSERT INTO public.rooms(id,lounge_id,name,status,hourly_rate_single)
      VALUES($1,$2,'Fixture PC','available',100)`, [room, lounge]);
    await db.query(`INSERT INTO public.shifts(id,lounge_id,status,cashier_id,staff_user_id,opened_at)
      VALUES($1,$2,'open',$3,$3,now())`, [shift, lounge, owner]);
    await db.query(`INSERT INTO public.bookings(id,user_id,lounge_id,room_id,date,start_time,
      end_time,status,room_price,total_price,payment_status,payment_method,
      sender_wallet_phone,confirmation_status) VALUES($1,$2,$3,$4,current_date+2,'10:00','11:00',
      'upcoming',100,150,'paid','manual_transfer','01000000000','confirmed')`,
      [booking, customer, lounge, room]);
    await db.query(`INSERT INTO public.payments(id,booking_id,user_id,lounge_id,amount,
      commission_rate,commission,net_to_lounge,payment_method,status)
      VALUES($1,$2,$3,$4,150,0.15,22.50,127.50,'manual_transfer','completed')`,
      [payment, booking, customer, lounge]);
    await db.query(`INSERT INTO public.shift_payments(id,shift_id,lounge_id,booking_id,
      payment_method,category,amount) VALUES
      ($1,$3,$4,$5,'manual_transfer','gaming_time',20),
      ($2,$3,$4,$5,'cash','gaming_time',130)`,
      [transferShift, cashShift, shift, lounge, booking]);

    const collectionSql = `INSERT INTO private.booking_money_movements
      (id,operation_id,booking_id,payment_id,lounge_id,shift_id,shift_payment_id,
       movement_type,collection_purpose,payment_method,amount_minor,commission_minor,
       funds_holder,evidence_reference,verified_by)
      VALUES($1,$2,$3,$4,$5,$6,$7,'collection',$8,$9,$10,$11,$12,$13,$14)`;
    const transfer = [transferMovement,randomUUID(),booking,payment,lounge,shift,
      transferShift,'deposit','manual_transfer',2000,300,'platform','TEST-ONLY',owner];
    const cash = [cashMovement,randomUUID(),booking,payment,lounge,shift,
      cashShift,'settlement','cash',13000,1950,'lounge',null,owner];
    await db.query(collectionSql, transfer);
    assert.equal((await db.query(`SELECT coverage_state FROM private.booking_money_coverage
      WHERE payment_id=$1`, [payment])).rows[0].coverage_state,
    'requires_reconciliation');
    await db.query(collectionSql, cash);
    const totals = (await db.query(`SELECT sum(amount_minor)::int AS gross,
      sum(commission_minor)::int AS commission,
      sum(amount_minor) FILTER (WHERE payment_method='manual_transfer')::int AS electronic,
      sum(amount_minor) FILTER (WHERE payment_method='cash')::int AS cash,
      sum(CASE WHEN funds_holder='platform' THEN net_to_lounge_minor
        ELSE -commission_minor END)::int AS payout_net
      FROM private.booking_money_movements WHERE booking_id=$1`, [booking])).rows[0];
    assert.deepEqual(totals, { gross: 15000, commission: 2250,
      electronic: 2000, cash: 13000, payout_net: -250 });
    const coverage = (await db.query(`SELECT * FROM private.booking_money_coverage
      WHERE payment_id=$1`, [payment])).rows[0];
    assert.equal(coverage.coverage_state, 'covered');
    assert.equal(Number(coverage.aggregate_gross_minor), 15000);
    assert.equal(Number(coverage.movement_gross_minor), 15000);

    await rejectsWith(db, collectionSql, cash, '23505'); // operation/row replay
    await rejectsWith(db, `UPDATE private.booking_money_movements
      SET amount_minor=1 WHERE id=$1`, [cashMovement], '55000');
    await rejectsWith(db, `DELETE FROM private.booking_money_movements WHERE id=$1`,
      [cashMovement], '55000');
    await rejectsWith(db, collectionSql, [randomUUID(),randomUUID(),booking,payment,lounge,
      shift,cashShift,'partial','cash',13000,1950,'lounge',null,owner],
    '23505'); // same shift evidence cannot be counted twice

    const refundSql = `INSERT INTO private.booking_money_movements
      (operation_id,booking_id,payment_id,lounge_id,shift_id,movement_type,
       collection_purpose,payment_method,amount_minor,commission_minor,
       funds_holder,evidence_reference,reversal_of,verified_by)
      VALUES($1,$2,$3,$4,$5,'refund','refund','manual_transfer',$6,$7,
       'platform','TEST-RETURN',$8,$9)`;
    await db.query(refundSql, [randomUUID(),booking,payment,lounge,shift,-1000,-150,
      transferMovement,owner]);
    await rejectsWith(db, refundSql, [randomUUID(),booking,payment,lounge,shift,
      -1100,-165,transferMovement,owner], '22023');
    await rejectsWith(db, refundSql, [randomUUID(),booking,payment,lounge,shift,
      -1000,-151,transferMovement,owner], '22023');

    await db.query(`INSERT INTO public.payouts(id,lounge_id,period_start,period_end,
      total_amount,status,created_by) VALUES($1,$2,current_date,current_date,17,'pending',$3)`,
      [payout,lounge,owner]);
    await db.query(`INSERT INTO private.booking_movement_payout_entries
      (payout_id,movement_id,contribution_minor) VALUES($1,$2,1700)`,
      [payout,transferMovement]);
    await rejectsWith(db, `INSERT INTO private.booking_movement_payout_entries
      (payout_id,movement_id,contribution_minor) VALUES($1,$2,1700)`,
      [payout,transferMovement], '55000');
    await rejectsWith(db, `INSERT INTO private.booking_movement_payout_entries
      (payout_id,movement_id,contribution_minor) VALUES($1,$2,13000)`,
      [payout,cashMovement], '23514');
    await db.query(`UPDATE public.payouts SET status='cancelled' WHERE id=$1`, [payout]);
    await db.query(`INSERT INTO public.payouts(id,lounge_id,period_start,period_end,
      total_amount,status,created_by) VALUES($1,$2,current_date,current_date,17,'pending',$3)`,
      [retryPayout,lounge,owner]);
    await db.query(`INSERT INTO private.booking_movement_payout_entries
      (payout_id,movement_id,contribution_minor) VALUES($1,$2,1700)`,
      [retryPayout,transferMovement]);

    await db.query('SAVEPOINT unauthorized_read');
    await db.query('SET LOCAL ROLE authenticated');
    await assert.rejects(db.query('SELECT count(*) FROM private.booking_money_movements'),
      { code: '42501' });
    await db.query('ROLLBACK TO SAVEPOINT unauthorized_read');
    await db.query('RELEASE SAVEPOINT unauthorized_read');
    process.stdout.write(JSON.stringify({ scenario: 'method-specific movement foundation',
      gross_minor: totals.gross, electronic_minor: totals.electronic,
      cash_minor: totals.cash, commission_minor: totals.commission,
      payout_net_minor: totals.payout_net, excess_refund_rejected: true }) + '\n');
    await db.query('ROLLBACK');
  } catch (error) {
    try { await db.query('ROLLBACK'); } catch (_) {}
    throw error;
  } finally {
    await db.end();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
