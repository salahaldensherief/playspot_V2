import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {createFixtureDatabase} from './runtime/database.mjs';

if (!process.env.PLAYSPOT_NATIVE_PG_PORT) throw new Error('Concurrency requires native PostgreSQL');
const db = await createFixtureDatabase();
const user = '00000000-0000-0000-0000-000000000001';
const staff = '00000000-0000-0000-0000-000000000002';
const lounge = '10000000-0000-0000-0000-000000000001';
const booking = '20000000-0000-0000-0000-000000000001';
const other = '20000000-0000-0000-0000-000000000002';
const shift = '30000000-0000-0000-0000-000000000001';
const read = file => readFile(new URL(file, import.meta.url), 'utf8');
const peers = [];
let passed = 0;
try {
  await db.exec(await read('./fixtures/wallet_integrity_fixture.sql'));
  const old = await read('../migrations/20260930220000_p2_advanced_operations_and_wallets.sql');
  await db.exec(old.slice(old.indexOf('CREATE TABLE IF NOT EXISTS public.user_wallets'),
    old.indexOf('-- ============================================================================', old.indexOf('GRANT EXECUTE ON FUNCTION public.refund_to_wallet'))));
  await db.exec(await read('../migrations/20261001090000_wallet_payment_integrity_and_unsafe_credit_containment.sql'));
  await db.exec(`INSERT INTO auth.users VALUES('${user}'),('${staff}');
    INSERT INTO public.user_wallets(user_id,balance) VALUES('${user}',150);
    INSERT INTO public.fixture_permissions VALUES('${staff}','${lounge}','billing_checkout');
    INSERT INTO public.shifts VALUES('${shift}','${lounge}','open',NULL,now());
    INSERT INTO public.bookings(id,user_id,lounge_id,status,payment_status,total_price)
    VALUES('${booking}','${user}','${lounge}','completed','unpaid',100),
    ('${other}','${user}','${lounge}','completed','unpaid',100);`);
  const a = await db.connect(); const b = await db.connect(); peers.push(a, b);
  async function actor(client, id) {
    await client.query(`RESET ROLE; SELECT set_config('request.jwt.claim.sub','${id??''}',false); ${id===null?'':'SET ROLE authenticated;'} SET statement_timeout='10s';`);
  }
  // Hold a real transaction until pg_stat_activity confirms the peer waits on its lock.
  async function race(first, second, id, secondId=id) {
    await actor(a, id); await actor(b, secondId);
    await a.query('BEGIN');
    try {
      const firstResult = await a.query(first);
      const pid = (await b.query('SELECT pg_backend_pid() AS pid')).rows[0].pid;
      const pending = b.query(second).then(value=>({value}), error=>({error}));
      const deadline = Date.now()+5000;
      let blocked = false;
      while (Date.now()<deadline) {
        const row = (await db.query('SELECT wait_event_type FROM pg_stat_activity WHERE pid=$1',[pid])).rows[0];
        if (row?.wait_event_type === 'Lock') { blocked=true; break; }
        await new Promise(resolve=>setTimeout(resolve,10));
      }
      assert.equal(blocked,true,'The second operation must actually wait for the first transaction');
      await a.query('COMMIT');
      return [firstResult, await pending];
    } catch (error) { await a.query('ROLLBACK'); throw error; }
  }
  const payment = (id,key) => `SELECT public.pay_with_wallet('${id}',100,'${key}') AS result`;
  const result = await race(payment(booking,'same'),payment(booking,'same'),user);
  assert.equal(result[1].error,undefined);
  assert.equal(result[1].value.rows[0].result.idempotent,true);
  assert.equal(Number((await db.query('SELECT balance FROM public.user_wallets')).rows[0].balance),50);
  assert.equal(Number((await db.query('SELECT count(*) AS n FROM public.payments')).rows[0].n),1);
  console.log('PASS simultaneous same payment debits and collects exactly once'); passed++;

  await db.exec(`TRUNCATE public.wallet_transactions,public.payments,public.shift_payments;
    UPDATE public.user_wallets SET balance=150;
    UPDATE public.bookings SET payment_status='unpaid',payment_method=NULL;`);
  const competing = await race(payment(booking,'first'),payment(other,'second'),user);
  assert.equal(competing[1].error?.code,'55000');
  assert.equal(Number((await db.query('SELECT balance FROM public.user_wallets')).rows[0].balance),50);
  assert.equal(Number((await db.query('SELECT count(*) AS n FROM public.payments')).rows[0].n),1);
  console.log('PASS different bookings cannot concurrently overspend one wallet'); passed++;

  const cash = `SELECT public.collect_wallet_cash_topup('${user}','${lounge}',30,'cash-race') AS result`;
  const collected = await race(cash,cash,staff);
  assert.equal(collected[1].error,undefined);
  assert.equal(collected[1].value.rows[0].result.idempotent,true);
  assert.equal(Number((await db.query('SELECT balance FROM public.user_wallets')).rows[0].balance),80);
  console.log('PASS simultaneous cash topup records one receipt and one credit'); passed++;

  const refund = `SELECT public.refund_to_wallet('${booking}',100,'synthetic reversal') AS result`;
  const refunded = await race(refund,refund,staff);
  assert.equal(refunded[1].error,undefined);
  assert.equal(refunded[1].value.rows[0].result.idempotent,true);
  assert.equal(Number((await db.query('SELECT balance FROM public.user_wallets')).rows[0].balance),180);
  console.log('PASS simultaneous refund restores funds once'); passed++;

  const closed = await race(`UPDATE public.shifts SET status='closed',closed_at=now() WHERE id='${shift}'`,
    `SELECT public.collect_wallet_cash_topup('${user}','${lounge}',30,'after-close')`,null,staff);
  assert.equal(closed[1].error?.code,'55000');
  assert.equal(Number((await db.query('SELECT balance FROM public.user_wallets')).rows[0].balance),180);
  console.log('PASS cash collection blocked by closing shift rechecks its state'); passed++;
  console.log(JSON.stringify({passed,engine:'native PostgreSQL 17',limitations:['Synthetic schema; production triggers not mirrored','No live database contacted']}));
} finally {
  for (const peer of peers) await peer.end();
  await db.close();
}
