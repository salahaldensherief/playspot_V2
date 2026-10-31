// Synthetic, rollback-only check of the guarded customer payment quote.
const assert = require('node:assert/strict');
const { randomUUID } = require('node:crypto');
const { Client } = require('../runtime/node_modules/pg');
assert.equal(process.env.PLAYSPOT_EXACT_SCHEMA_TEST, '1');
const target = new URL(process.env.PLAYSPOT_ISOLATED_DB_URL || '');
assert.ok(['localhost','127.0.0.1'].includes(target.hostname));
(async () => {
  const db = new Client({connectionString: target.toString()});
  await db.connect();
  try {
    assert.equal((await db.query("SELECT 1 FROM private.playspot_isolated_test_guard WHERE token='PLAYSPOT_DISPOSABLE_EXACT_SCHEMA_20261025'")).rowCount,1);
    await db.query('BEGIN');
    const [owner,customer,outsider,lounge,room,shift,booking]=Array.from({length:7},randomUUID);
    for(const id of [owner,customer,outsider]) await db.query('INSERT INTO auth.users(id) VALUES($1)',[id]);
    await db.query("INSERT INTO public.profiles(id,role,is_active,is_banned) VALUES($1,'owner',true,false),($2,'user',true,false),($3,'user',true,false)",[owner,customer,outsider]);
    await db.query("INSERT INTO public.lounges(id,owner_id,name,status,is_active,instapay_account,allow_cash_payment,require_deposit_for_future,future_deposit_percentage) VALUES($1,$2,'Synthetic deposit quote','active',true,'TEST-ONLY',true,true,20)",[lounge,owner]);
    await db.query('UPDATE public.profiles SET lounge_id=$1 WHERE id=$2',[lounge,owner]);
    await db.query("INSERT INTO public.rooms(id,lounge_id,name,status,hourly_rate_single) VALUES($1,$2,'Fixture PC','available',100)",[room,lounge]);
    await db.query("INSERT INTO public.shifts(id,lounge_id,status,cashier_id,staff_user_id,opened_at) VALUES($1,$2,'open',$3,$3,now())",[shift,lounge,owner]);
    await db.query("INSERT INTO public.bookings(id,user_id,lounge_id,room_id,date,start_time,end_time,status,room_price,total_price,payment_status,payment_method,sender_wallet_phone,deposit_required,deposit_amount,deposit_paid,confirmation_status) VALUES($1,$2,$3,$4,current_date+2,'10:00','11:00','upcoming',100,100,'unpaid','manual_transfer','01000000000',true,20,false,'confirmed')",[booking,customer,lounge,room]);
    await db.query('SAVEPOINT outsider_quote');
    await db.query('SET LOCAL ROLE authenticated');
    await db.query("SELECT set_config('request.jwt.claim.sub',$1,true)",[outsider]);
    await assert.rejects(db.query('SELECT public.get_booking_payment_destination($1)',[booking]),{code:'42501'});
    await db.query('ROLLBACK TO SAVEPOINT outsider_quote');
    await db.query('SET LOCAL ROLE authenticated');
    await db.query("SELECT set_config('request.jwt.claim.sub',$1,true)",[customer]);
    const before=(await db.query('SELECT public.get_booking_payment_destination($1) AS result',[booking])).rows[0].result;
    await db.query('RESET ROLE');
    assert.equal(before.can_pay,true);
    assert.equal(Number(before.amount_due),20);
    await db.query("INSERT INTO public.payments(booking_id,user_id,lounge_id,amount,commission_rate,commission,net_to_lounge,payment_method,status) VALUES($1,$2,$3,20,0.15,3,17,'manual_transfer','completed')",[booking,customer,lounge]);
    await db.query("INSERT INTO public.shift_payments(shift_id,lounge_id,booking_id,payment_method,category,amount) VALUES($1,$2,$3,'manual_transfer','gaming_time',20)",[shift,lounge,booking]);
    await db.query("UPDATE public.bookings SET deposit_paid=true,payment_status='partial' WHERE id=$1",[booking]);
    await db.query('SET LOCAL ROLE authenticated');
    await db.query("SELECT set_config('request.jwt.claim.sub',$1,true)",[customer]);
    const after=(await db.query('SELECT public.get_booking_payment_destination($1) AS result',[booking])).rows[0].result;
    await db.query('RESET ROLE');
    assert.equal(after.can_pay,false);
    assert.equal(after.reason,'DEPOSIT_ALREADY_COLLECTED_USE_CANONICAL_SETTLEMENT');
    assert.equal(Object.hasOwn(after,'amount_due'),false);
    assert.equal(after.deposit_paid,true);
    process.stdout.write(JSON.stringify({scenario:'paid deposit withholds unsafe second transfer quote',expected_total:100,configured_deposit:20,before_quote:Number(before.amount_due),recorded_collection:20,after_reason:after.reason,after_can_pay:after.can_pay})+'\n');
    await db.query('ROLLBACK');
  } catch(e) {try {await db.query('ROLLBACK');} catch(_) {} throw e;}
  finally {await db.end();}
})().catch(e=>{console.error(e);process.exitCode=1});
