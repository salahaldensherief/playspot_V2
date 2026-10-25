// Synthetic recorded-payment cancellation probe; no external funds are moved.
// Rollback-only against the isolated exact-schema restore. Never run on production.
const assert = require('node:assert/strict');
const { randomUUID } = require('node:crypto');
const { Client } = require('../runtime/node_modules/pg');
assert.equal(process.env.PLAYSPOT_EXACT_SCHEMA_TEST, '1');
const url = new URL(process.env.PLAYSPOT_ISOLATED_DB_URL || '');
assert.ok(['localhost', '127.0.0.1'].includes(url.hostname));
(async () => {
  const db = new Client({ connectionString: url.toString() });
  await db.connect();
  try {
    assert.equal((await db.query("SELECT 1 FROM private.playspot_isolated_test_guard WHERE token='PLAYSPOT_DISPOSABLE_EXACT_SCHEMA_20261025'")).rowCount, 1);
    await db.query('BEGIN');
    const [owner, customer, lounge, room, shift, booking] = Array.from({length: 6}, randomUUID);
    for (const id of [owner, customer]) await db.query('INSERT INTO auth.users(id) VALUES($1)', [id]);
    await db.query(`INSERT INTO public.app_permissions(key,name_ar,name_en,category,
      default_super_admin,default_owner,default_cashier)
      VALUES('billing_checkout','Synthetic billing','Synthetic billing','billing',true,true,false)
      ON CONFLICT(key) DO NOTHING`);
    await db.query("INSERT INTO public.profiles(id,role,is_active,is_banned) VALUES($1,'owner',true,false),($2,'user',true,false)", [owner, customer]);
    await db.query("INSERT INTO public.lounges(id,owner_id,name,status,is_active,instapay_account,allow_cash_payment) VALUES($1,$2,'Synthetic cancellation','active',true,'TEST-ONLY',true)", [lounge, owner]);
    await db.query('UPDATE public.profiles SET lounge_id=$1 WHERE id=$2', [lounge, owner]);
    await db.query("INSERT INTO public.rooms(id,lounge_id,name,status,hourly_rate_single) VALUES($1,$2,'Fixture PC','available',100)", [room, lounge]);
    await db.query("INSERT INTO public.shifts(id,lounge_id,status,cashier_id,staff_user_id,opened_at) VALUES($1,$2,'open',$3,$3,now())", [shift, lounge, owner]);
    await db.query("INSERT INTO public.bookings(id,user_id,lounge_id,room_id,date,start_time,end_time,status,room_price,total_price,payment_status,payment_method,receipt_url,sender_wallet_phone) VALUES($1,$2,$3,$4,current_date+2,'10:00','11:00','pending',100,100,'unpaid','manual_transfer','https://example.invalid/synthetic-proof','01000000000')", [booking, customer, lounge, room]);
    await db.query('SET LOCAL ROLE authenticated');
    await db.query("SELECT set_config('request.jwt.claim.sub',$1,true)", [owner]);
    await db.query('SELECT public.approve_manual_booking($1,$2)', [booking, owner]);
    await db.query('RESET ROLE');
    const before = (await db.query(`SELECT b.status::text,b.payment_status,b.total_price,
      (SELECT count(*)::int FROM public.payments WHERE booking_id=b.id) AS payment_rows,
      (SELECT coalesce(sum(amount),0) FROM public.payments WHERE booking_id=b.id AND status='completed') AS collected,
      (SELECT count(*)::int FROM public.shift_payments WHERE booking_id=b.id) AS shift_rows,
      (SELECT coalesce(sum(amount),0) FROM public.shift_payments WHERE booking_id=b.id) AS shift_total
      FROM public.bookings b WHERE b.id=$1`, [booking])).rows[0];
    await db.query('SET LOCAL ROLE authenticated');
    await db.query("SELECT set_config('request.jwt.claim.sub',$1,true)", [customer]);
    const cancelled = (await db.query('SELECT public.cancel_my_booking($1,$2) AS result', [booking, 'Synthetic test cancellation'])).rows[0].result;
    await db.query('RESET ROLE');
    const state = (await db.query(`SELECT b.status::text,b.payment_status,b.total_price,p.status AS payment_row_status,p.amount,
      (SELECT count(*)::int FROM public.payments WHERE booking_id=b.id) AS payment_rows,
      (SELECT count(*)::int FROM public.shift_payments WHERE booking_id=b.id) AS shift_rows,
      (SELECT coalesce(sum(amount),0) FROM public.shift_payments WHERE booking_id=b.id) AS shift_total,
      (SELECT count(*)::int FROM private.booking_cancellation_events WHERE booking_id=b.id) AS cancellation_events,
      (SELECT count(*)::int FROM public.shift_audit_logs WHERE entity_id=b.id) AS booking_audit_rows
      FROM public.bookings b LEFT JOIN public.payments p ON p.booking_id=b.id WHERE b.id=$1`, [booking])).rows[0];
    const audit = (await db.query(`SELECT action,old_data->>'status' AS old_status,
      new_data->>'status' AS new_status FROM public.shift_audit_logs
      WHERE entity_id=$1 ORDER BY created_at DESC LIMIT 3`, [booking])).rows;
    assert.equal(cancelled.status, 'cancelled');
    assert.equal(state.status, 'cancelled');
    assert.equal(state.payment_status, 'paid');
    assert.equal(state.payment_row_status, 'completed');
    assert.equal(Number(state.amount), 100);
    assert.equal(state.payment_rows,before.payment_rows);
    assert.equal(state.shift_rows,before.shift_rows);
    assert.equal(Number(state.shift_total), 100);
    assert.ok(state.cancellation_events>=1);
    assert.ok(state.booking_audit_rows>=1);
    process.stdout.write(JSON.stringify({scenario:'paid booking cancellation leaves collection intact pending policy',
      before:{status:before.status,payment_status:before.payment_status,expected:Number(before.total_price),collected:Number(before.collected),payment_rows:before.payment_rows,shift_rows:before.shift_rows,shift_total:Number(before.shift_total)},
      after:{status:state.status,payment_status:state.payment_status,payment_row_status:state.payment_row_status,payment_amount:Number(state.amount),payment_rows:state.payment_rows,shift_rows:state.shift_rows,shift_total:Number(state.shift_total),outstanding:Number(state.total_price)-Number(state.amount),cancellation_events:state.cancellation_events,booking_audit_rows:state.booking_audit_rows},audit})+'\n');
    await db.query('ROLLBACK');
  } catch (e) { try { await db.query('ROLLBACK'); } catch (_) {} throw e; }
  finally { await db.end(); }
})().catch(e => { console.error(e); process.exitCode=1; });
