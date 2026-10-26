// Synthetic, rollback-only policy configuration and booking snapshot proof.
const assert = require('node:assert/strict');
const { randomUUID } = require('node:crypto');
const { Client } = require('../runtime/node_modules/pg');

assert.equal(process.env.PLAYSPOT_EXACT_SCHEMA_TEST, '1');
const target = new URL(process.env.PLAYSPOT_ISOLATED_DB_URL || '');
assert.ok(['localhost', '127.0.0.1'].includes(target.hostname));

async function asActor(db, actor, query, args) {
  await db.query('SET LOCAL ROLE authenticated');
  await db.query("SELECT set_config('request.jwt.claim.sub',$1,true)", [actor]);
  const result = await db.query(query, args);
  await db.query('RESET ROLE');
  await db.query("SELECT set_config('request.jwt.claim.sub','',true)");
  return result;
}

async function rejectedAsActor(db, actor, query, args, code) {
  await db.query('SAVEPOINT rejected_call');
  await db.query('SET LOCAL ROLE authenticated');
  await db.query("SELECT set_config('request.jwt.claim.sub',$1,true)", [actor]);
  await assert.rejects(db.query(query, args), { code });
  await db.query('ROLLBACK TO SAVEPOINT rejected_call');
  await db.query('RELEASE SAVEPOINT rejected_call');
}

(async () => {
  const db = new Client({ connectionString: target.toString() });
  await db.connect();
  try {
    assert.equal((await db.query(`SELECT 1 FROM private.playspot_isolated_test_guard
      WHERE token='PLAYSPOT_DISPOSABLE_EXACT_SCHEMA_20261025'`)).rowCount, 1);
    await db.query('BEGIN');
    const [ownerA,ownerB,customer,loungeA,loungeB,roomA,roomB,shiftA,shiftB,
      bookingOld,bookingNew,bookingB,bookingBExpired,operationA,operationB] =
      Array.from({length:15},randomUUID);
    for (const user of [ownerA,ownerB,customer]) {
      await db.query('INSERT INTO auth.users(id) VALUES($1)', [user]);
    }
    await db.query(`INSERT INTO public.profiles(id,role,is_active,is_banned)
      VALUES($1,'owner',true,false),($2,'owner',true,false),($3,'user',true,false)`,
      [ownerA,ownerB,customer]);
    await db.query(`INSERT INTO public.lounges(id,owner_id,name,status,is_active,
      instapay_account,allow_cash_payment) VALUES
      ($1,$3,'Synthetic refund A','active',true,'TEST-A',true),
      ($2,$4,'Synthetic refund B','active',true,'TEST-B',true)`,
      [loungeA,loungeB,ownerA,ownerB]);
    await db.query(`UPDATE public.profiles SET lounge_id=$1 WHERE id=$2`, [loungeA,ownerA]);
    await db.query(`UPDATE public.profiles SET lounge_id=$1 WHERE id=$2`, [loungeB,ownerB]);
    for (const [room,lounge] of [[roomA,loungeA],[roomB,loungeB]]) {
      await db.query(`INSERT INTO public.rooms(id,lounge_id,name,status,hourly_rate_single)
        VALUES($1,$2,'Fixture PC','available',100)`, [room,lounge]);
    }
    for (const [shift,lounge,owner] of
      [[shiftA,loungeA,ownerA],[shiftB,loungeB,ownerB]]) {
      await db.query(`INSERT INTO public.shifts(id,lounge_id,status,cashier_id,
        staff_user_id,opened_at) VALUES($1,$2,'open',$3,$3,now())`,
        [shift,lounge,owner]);
    }

    const configure = `SELECT public.configure_branch_booking_refund_policy($1,$2,$3,$4)
      AS result`;
    const first = (await asActor(db,ownerA,configure,[loungeA,120,50,operationA]))
      .rows[0].result;
    assert.equal(first.replayed,false);
    assert.equal(Number(first.refund_percentage),50);
    const replay = (await asActor(db,ownerA,configure,[loungeA,120,50,operationA]))
      .rows[0].result;
    assert.equal(replay.replayed,true);
    assert.equal(replay.policy_version_id,first.policy_version_id);
    await rejectedAsActor(db,ownerA,configure,[loungeA,120,75,operationA],'22023');
    await rejectedAsActor(db,ownerB,configure,[loungeA,120,50,randomUUID()],'42501');
    await rejectedAsActor(db,customer,configure,[loungeA,120,50,randomUUID()],'42501');
    await db.query(`UPDATE public.profiles SET is_active=false WHERE id=$1`,[ownerA]);
    await rejectedAsActor(db,ownerA,configure,[loungeA,60,75,randomUUID()],'42501');
    await db.query(`UPDATE public.profiles SET is_active=true WHERE id=$1`,[ownerA]);
    await rejectedAsActor(db,customer,`SELECT count(*) FROM
      private.booking_refund_policy_versions`,[],'42501');
    const branchB = (await asActor(db,ownerB,configure,[loungeB,30,25,operationB]))
      .rows[0].result;

    const bookingSql = `INSERT INTO public.bookings(id,user_id,lounge_id,room_id,date,
      start_time,end_time,status,room_price,total_price,payment_status,
      payment_method,sender_wallet_phone,confirmation_status)
      VALUES($1,$2,$3,$4,current_date+$5::integer,'10:00','11:00','upcoming',
      100,100,'unpaid','manual_transfer','01000000000','confirmed')`;
    await db.query(bookingSql,[bookingOld,customer,loungeA,roomA,2]);
    await db.query(bookingSql,[bookingB,customer,loungeB,roomB,2]);
    const changed = (await asActor(db,ownerA,configure,
      [loungeA,60,75,randomUUID()])).rows[0].result;
    await db.query(bookingSql,[bookingNew,customer,loungeA,roomA,3]);
    const snapshots = (await db.query(`SELECT id,refund_policy_version_id FROM public.bookings
      WHERE id=ANY($1::uuid[])`, [[bookingOld,bookingNew,bookingB]])).rows;
    const byId = Object.fromEntries(snapshots.map(row =>
      [row.id,row.refund_policy_version_id]));
    assert.equal(byId[bookingOld],first.policy_version_id);
    assert.equal(byId[bookingNew],changed.policy_version_id);
    assert.equal(byId[bookingB],branchB.policy_version_id);

    await asActor(db,ownerB,configure,[loungeB,43200,25,randomUUID()]);
    await db.query(bookingSql,[bookingBExpired,customer,loungeB,roomB,4]);
    await asActor(db,customer,`SELECT public.cancel_my_booking($1,$2)`,
      [bookingOld,'Synthetic policy test']);
    await asActor(db,customer,`SELECT public.cancel_my_booking($1,$2)`,
      [bookingBExpired,'Synthetic policy test']);
    const eligible = (await db.query(`SELECT private.booking_refund_policy_decision($1)
      AS result`,[bookingOld])).rows[0].result;
    const expired = (await db.query(`SELECT private.booking_refund_policy_decision($1)
      AS result`,[bookingBExpired])).rows[0].result;
    assert.equal(eligible.decision,'eligible');
    assert.equal(Number(eligible.eligible_percentage),50);
    assert.equal(expired.decision,'cutoff_passed');
    assert.equal(Number(expired.eligible_percentage),0);

    await db.query('SAVEPOINT immutable_snapshot');
    await assert.rejects(db.query(`UPDATE public.bookings SET refund_policy_version_id=$1
      WHERE id=$2`,[changed.policy_version_id,bookingOld]),{code:'55000'});
    await db.query('ROLLBACK TO SAVEPOINT immutable_snapshot');
    await db.query('RELEASE SAVEPOINT immutable_snapshot');

    await db.query('SET LOCAL ROLE anon');
    const visible = (await db.query(`SELECT public.get_branch_booking_refund_policy($1)
      AS result`,[loungeA])).rows[0].result;
    assert.equal(visible.configured,true);
    assert.equal(Number(visible.refund_percentage),75);
    assert.equal(visible.cutoff_minutes_before_start,60);
    await db.query('RESET ROLE');

    const versions = (await db.query(`SELECT count(*)::int AS count FROM
      private.booking_refund_policy_versions WHERE lounge_id=$1`,[loungeA])).rows[0].count;
    assert.equal(versions,2);
    process.stdout.write(JSON.stringify({scenario:'branch refund policy snapshots',
      original_percentage:50,new_percentage:75,other_branch_percentage:25,
      old_booking_kept_original:true,repeat_idempotent:true,
      old_booking_eligible:eligible.decision,late_booking_eligible:expired.decision})+'\n');
    await db.query('ROLLBACK');
  } catch (error) {
    try { await db.query('ROLLBACK'); } catch (_) {}
    throw error;
  } finally {
    await db.end();
  }
})().catch(error => { console.error(error); process.exitCode=1; });
