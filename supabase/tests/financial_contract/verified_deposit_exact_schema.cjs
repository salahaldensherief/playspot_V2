// Synthetic, rollback-only authorized transfer-deposit collection proof.
const assert = require('node:assert/strict');
const { randomUUID } = require('node:crypto');
const { Client } = require('../runtime/node_modules/pg');

assert.equal(process.env.PLAYSPOT_EXACT_SCHEMA_TEST, '1');
const target = new URL(process.env.PLAYSPOT_ISOLATED_DB_URL || '');
assert.ok(['localhost','127.0.0.1'].includes(target.hostname));

async function asActor(db, actor, sql, args) {
  await db.query('SET LOCAL ROLE authenticated');
  await db.query("SELECT set_config('request.jwt.claim.sub',$1,true)",[actor]);
  const result = await db.query(sql,args);
  await db.query('RESET ROLE');
  await db.query("SELECT set_config('request.jwt.claim.sub','',true)");
  return result;
}

async function rejectsAs(db, actor, sql, args, code) {
  await db.query('SAVEPOINT expected_failure');
  await db.query('SET LOCAL ROLE authenticated');
  await db.query("SELECT set_config('request.jwt.claim.sub',$1,true)",[actor]);
  await assert.rejects(db.query(sql,args),{code});
  await db.query('ROLLBACK TO SAVEPOINT expected_failure');
  await db.query('RELEASE SAVEPOINT expected_failure');
}

(async () => {
  const db = new Client({connectionString:target.toString()});
  await db.connect();
  try {
    assert.equal((await db.query(`SELECT 1 FROM private.playspot_isolated_test_guard
      WHERE token='PLAYSPOT_DISPOSABLE_EXACT_SCHEMA_20261025'`)).rowCount,1);
    await db.query('BEGIN');
    const [owner,customer,outsider,lounge,room,shift,booking,operation] =
      Array.from({length:8},randomUUID);
    for(const id of [owner,customer,outsider]) {
      await db.query('INSERT INTO auth.users(id) VALUES($1)',[id]);
    }
    await db.query(`INSERT INTO public.app_permissions(key,name_ar,name_en,category,
      default_super_admin,default_owner,default_cashier)
      VALUES('billing_checkout','Synthetic billing','Synthetic billing','billing',true,true,false)
      ON CONFLICT(key) DO NOTHING`);
    await db.query(`INSERT INTO public.profiles(id,role,is_active,is_banned)
      VALUES($1,'owner',true,false),($2,'user',true,false),($3,'user',true,false)`,
      [owner,customer,outsider]);
    await db.query(`INSERT INTO public.lounges(id,owner_id,name,status,is_active,
      instapay_account,allow_cash_payment,require_deposit_for_future,
      future_deposit_percentage)
      VALUES($1,$2,'Synthetic verified deposit','active',true,'TEST-ONLY',true,true,20)`,
      [lounge,owner]);
    await db.query('UPDATE public.profiles SET lounge_id=$1 WHERE id=$2',[lounge,owner]);
    await db.query(`INSERT INTO public.rooms(id,lounge_id,name,status,hourly_rate_single)
      VALUES($1,$2,'Fixture PC','available',100)`,[room,lounge]);
    await db.query(`INSERT INTO public.shifts(id,lounge_id,status,cashier_id,staff_user_id,
      opened_at) VALUES($1,$2,'open',$3,$3,now())`,[shift,lounge,owner]);
    await db.query(`INSERT INTO public.bookings(id,user_id,lounge_id,room_id,date,
      start_time,end_time,status,room_price,total_price,payment_status,
      payment_method,sender_wallet_phone,receipt_url,deposit_required,
      deposit_amount,deposit_paid,confirmation_status)
      VALUES($1,$2,$3,$4,current_date+2,'10:00','11:00','upcoming',
      100,100,'unpaid','manual_transfer','01000000000','synthetic-receipt',
      true,20,false,'confirmed')`,[booking,customer,lounge,room]);

    const verify = `SELECT public.verify_booking_deposit_transfer($1,$2,$3,$4,$5)
      AS result`;
    const args = [booking,shift,operation,'TEST-BANK-REFERENCE','lounge'];
    const legacyApproval = `SELECT public.approve_manual_booking($1,$2)`;
    await rejectsAs(db,owner,legacyApproval,[booking,owner],'55000');
    await rejectsAs(db,outsider,verify,args,'42501');
    const first = (await asActor(db,owner,verify,args)).rows[0].result;
    assert.equal(first.replayed,false);
    assert.equal(Number(first.collected_minor),2000);
    assert.equal(Number(first.commission_minor),300);
    await rejectsAs(db,owner,legacyApproval,[booking,owner],'55000');
    const replay = (await asActor(db,owner,verify,args)).rows[0].result;
    assert.equal(replay.replayed,true);
    assert.equal(replay.movement_id,first.movement_id);
    await rejectsAs(db,owner,verify,
      [booking,shift,operation,'DIFFERENT-REFERENCE','lounge'],'22023');
    await rejectsAs(db,owner,verify,
      [booking,shift,randomUUID(),'TEST-BANK-REFERENCE','lounge'],'55000');

    const state = (await db.query(`SELECT b.payment_status,b.deposit_paid,
      (SELECT count(*)::int FROM public.payments p WHERE p.booking_id=b.id) AS payment_rows,
      (SELECT sum(amount) FROM public.payments p WHERE p.booking_id=b.id) AS payment_amount,
      (SELECT count(*)::int FROM public.shift_payments s WHERE s.booking_id=b.id) AS shift_rows,
      (SELECT sum(amount) FROM public.shift_payments s WHERE s.booking_id=b.id) AS shift_amount,
      (SELECT count(*)::int FROM private.booking_money_movements m
        WHERE m.booking_id=b.id) AS movement_rows,
      (SELECT sum(amount_minor) FROM private.booking_money_movements m
        WHERE m.booking_id=b.id) AS movement_minor
      FROM public.bookings b WHERE b.id=$1`,[booking])).rows[0];
    assert.equal(state.payment_status,'partial');
    assert.equal(state.deposit_paid,true);
    assert.equal(state.payment_rows,1);
    assert.equal(Number(state.payment_amount),20);
    assert.equal(state.shift_rows,1);
    assert.equal(Number(state.shift_amount),20);
    assert.equal(state.movement_rows,1);
    assert.equal(Number(state.movement_minor),2000);

    await db.query(`UPDATE public.shifts SET status='closed',closed_at=now()
      WHERE id=$1`,[shift]);
    assert.equal((await asActor(db,owner,verify,args)).rows[0].result.replayed,true);
    await db.query(`UPDATE public.profiles SET is_active=false WHERE id=$1`,[owner]);
    await rejectsAs(db,owner,verify,args,'42501');

    process.stdout.write(JSON.stringify({scenario:'verified transfer deposit',
      expected_total:100,verified_deposit:20,payment_rows:state.payment_rows,
      shift_rows:state.shift_rows,movement_rows:state.movement_rows,
      payment_status:state.payment_status,replayed_after_shift_close:true})+'\n');
    await db.query('ROLLBACK');
  } catch(error) {
    try {await db.query('ROLLBACK');} catch (_) {}
    throw error;
  } finally {
    await db.end();
  }
})().catch(error=>{console.error(error);process.exitCode=1});
