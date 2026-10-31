import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {createFixtureDatabase} from './runtime/database.mjs';

const db = await createFixtureDatabase();
const id = n => `00000000-0000-0000-0000-${String(n).padStart(12,'0')}`;
let passed = 0;
async function check(name, body) {
  await db.exec('BEGIN');
  try { await body(); passed++; console.log('PASS '+name); }
  finally { await db.exec('ROLLBACK'); }
}
async function collected(status='paid',total=362.62) {
  return Number((await db.query('SELECT private.booking_collected_amount($1,$2,$3,$4) amount',[id(4),id(2),status,total])).rows[0].amount);
}
try {
  await db.exec(await readFile(new URL('./fixtures/partial_cash_fixture.sql',import.meta.url),'utf8'));
  await db.exec(`CREATE TABLE private.cash_collection_receipts(booking_id uuid);
    INSERT INTO auth.users VALUES('${id(1)}');
    INSERT INTO public.profiles VALUES('${id(1)}','cashier',true,false);
    INSERT INTO public.lounges VALUES('${id(2)}',true,'active');
    INSERT INTO public.shifts VALUES('${id(3)}','${id(2)}','${id(1)}','${id(1)}','open',NULL);
    INSERT INTO public.bookings(id,user_id,lounge_id,status,total_price,payment_status,payment_method)
      VALUES('${id(4)}','${id(1)}','${id(2)}','completed',362.62,'paid','cash');
    INSERT INTO public.payments(booking_id,lounge_id,amount,payment_method,status)
      VALUES('${id(4)}','${id(2)}',362.62,'cash','completed');
    INSERT INTO public.shift_payments(shift_id,lounge_id,booking_id,payment_method,category,amount)
      VALUES('${id(3)}','${id(2)}','${id(4)}','cash','gaming_time',232.62);`);
  await db.exec(await readFile(new URL('../migrations/20261015192841_booking_legacy_cash_ledger_agreement.sql',import.meta.url),'utf8'));
  await check('legacy cash with the EGP130 gap requires reconciliation', async () => {
    await assert.rejects(collected(), e => e.code==='55000' && e.message==='PAYMENT_REQUIRES_RECONCILIATION');
  });
  await check('matching legacy cash is accepted without fabricating a receipt', async () => {
    await db.exec('UPDATE public.shift_payments SET amount=362.62');
    assert.equal(await collected(),362.62);
    assert.equal((await db.query('SELECT count(*)::int n FROM private.cash_collection_receipts')).rows[0].n,0);
  });
  await check('a receipt cannot hide an inconsistent cash ledger', async () => {
    await db.exec(`INSERT INTO private.cash_collection_receipts VALUES('${id(4)}')`);
    await assert.rejects(collected(),e=>e.code==='55000');
  });
  await check('cash ledger rows from another lounge do not count', async () => {
    await db.exec(`INSERT INTO public.lounges VALUES('${id(5)}',true,'active');
      UPDATE public.shift_payments SET lounge_id='${id(5)}',amount=362.62`);
    await assert.rejects(collected(),e=>e.code==='55000');
  });
  await check('noncash completed payments retain their existing contract', async () => {
    await db.exec("UPDATE public.payments SET payment_method='card'");
    assert.equal(await collected(),362.62);
  });
  await check('an unpaid booking without any collection returns zero', async () => {
    await db.exec('DELETE FROM public.shift_payments; DELETE FROM public.payments');
    assert.equal(await collected('unpaid'),0);
  });
  await check('a paid summary without a payment is not evidence of collection', async () => {
    await db.exec('DELETE FROM public.shift_payments; DELETE FROM public.payments');
    await assert.rejects(collected(),e=>e.code==='55000');
  });
  await check('ordinary clients cannot invoke the private collection helper', async () => {
    const result=await db.query("SELECT has_function_privilege('authenticated','private.booking_collected_amount(uuid,uuid,text,numeric)','EXECUTE') allowed");
    assert.equal(result.rows[0].allowed,false);
  });
  console.log(JSON.stringify({passed,synthetic:true,hostedConnections:0}));
} finally { await db.close(); }
