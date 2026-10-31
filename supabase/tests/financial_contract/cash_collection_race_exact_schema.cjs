// Disposable exact-schema fixture only. Never point at a production database.
const { Client } = require('../runtime/node_modules/pg');
const assert = require('node:assert/strict');
const { randomUUID } = require('node:crypto');

if (process.env.PLAYSPOT_EXACT_SCHEMA_TEST !== '1') throw new Error('Isolated schema test opt-in required');
const target = new URL(process.env.PLAYSPOT_ISOLATED_DB_URL || '');
if (!['127.0.0.1','localhost'].includes(target.hostname)) throw new Error('Only a localhost database is allowed');
const db = () => new Client({connectionString:target.toString()});
const actor = '00000000-0000-0000-0000-000000000001';
const customer = '00000000-0000-0000-0000-000000000002';
const lounge = '00000000-0000-0000-0000-000000000010';
const room = '00000000-0000-0000-0000-000000000020';
const shift = '00000000-0000-0000-0000-000000000030';
const booking = randomUUID();
const op = randomUUID();
const competingBooking = randomUUID();
const dateOffset = 1000 + Math.floor(Math.random()*10000);

async function cashier(c) {
  await c.query('BEGIN');
  await c.query('SET LOCAL ROLE authenticated');
  await c.query("SELECT set_config('request.jwt.claim.sub',$1,true)", [actor]);
}

async function main() {
  const setup = db(), a = db(), b = db();
  await Promise.all([setup.connect(), a.connect(), b.connect()]);
  try {
    assert.equal((await setup.query('SELECT inet_server_port() AS port')).rows[0].port, 5432);
    assert.equal((await setup.query("SELECT token FROM private.playspot_isolated_test_guard WHERE token='PLAYSPOT_DISPOSABLE_EXACT_SCHEMA_20261025'")).rowCount,1);
    await setup.query('INSERT INTO public.bookings(id,user_id,lounge_id,room_id,date,start_time,end_time,status,room_price,total_price,payment_status) VALUES($1,$2,$3,$4,current_date+$5::int,\'10:00\',\'11:00\',\'completed\',100,100,\'unpaid\') ON CONFLICT(id) DO NOTHING', [booking,customer,lounge,room,dateOffset]);
    await Promise.all([cashier(a), cashier(b)]);
    const sql = 'SELECT public.collect_booking_cash_partial($1,$2,$3,$4) AS result';
    const collect = async (c) => {
      const result = await c.query(sql, [booking,shift,4000,op]);
      await c.query('COMMIT');
      return result;
    };
    const [ra, rb] = await Promise.all([collect(a),collect(b)]);
    const results = [ra.rows[0].result, rb.rows[0].result];
    assert.deepEqual(results.map(r => r.replayed).sort(), [false,true]);
    const state = (await setup.query(`SELECT b.payment_status,b.total_price,p.amount AS payment_amount,
      (SELECT sum(amount) FROM public.shift_payments WHERE booking_id=b.id) AS shift_amount,
      (SELECT count(*)::int FROM private.cash_collection_receipts WHERE booking_id=b.id) AS receipts
      FROM public.bookings b JOIN public.payments p ON p.booking_id=b.id WHERE b.id=$1`,[booking])).rows[0];
    assert.equal(Number(state.payment_amount),40);
    assert.equal(Number(state.shift_amount),40);
    assert.equal(state.receipts,1);
    assert.equal(state.payment_status,'partial');
    process.stdout.write(JSON.stringify({scenario:'same-operation concurrent requests', results, state})+'\n');

    await setup.query('INSERT INTO public.bookings(id,user_id,lounge_id,room_id,date,start_time,end_time,status,room_price,total_price,payment_status) VALUES($1,$2,$3,$4,current_date+$5::int,\'10:00\',\'11:00\',\'completed\',100,100,\'unpaid\') ON CONFLICT(id) DO NOTHING', [competingBooking,customer,lounge,room,dateOffset+1]);
    await Promise.all([cashier(a),cashier(b)]);
    const compete = async (c,operation) => {
      try {
        const r=await c.query(sql,[competingBooking,shift,6000,operation]);
        await c.query('COMMIT');
        return {ok:true,result:r.rows[0].result};
      } catch (e) {
        await c.query('ROLLBACK');
        return {ok:false,code:e.code,message:e.message,detail:e.detail,where:e.where};
      }
    };
    const contested=await Promise.all([
      compete(a,randomUUID()),
      compete(b,randomUUID()),
    ]);
    assert.equal(contested.filter(r=>r.ok).length,1);
    process.stdout.write(JSON.stringify({scenario:'different-operation concurrent attempt',contested})+'\n');
    assert.equal(contested.find(r=>!r.ok).message,'CASH_EXCEEDS_OUTSTANDING_BALANCE');
    const contestedState=(await setup.query(`SELECT p.amount AS payment_amount,
      (SELECT sum(amount) FROM public.shift_payments WHERE booking_id=$1) AS shift_amount,
      (SELECT count(*)::int FROM private.cash_collection_receipts WHERE booking_id=$1) AS receipts
      FROM public.payments p WHERE p.booking_id=$1`,[competingBooking])).rows[0];
    assert.equal(Number(contestedState.payment_amount),60);
    assert.equal(Number(contestedState.shift_amount),60);
    assert.equal(contestedState.receipts,1);
    process.stdout.write(JSON.stringify({scenario:'different-operation concurrent overpayment',contested,state:contestedState})+'\n');
  } finally {
    await Promise.allSettled([setup.end(),a.end(),b.end()]);
  }
}
main().catch(e => { process.stderr.write(`${e.code || 'ERROR'} ${e.message}\n`); process.exitCode=1; });
