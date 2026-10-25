// Exact-schema isolated probe. Uses only localhost:55442 and synthetic actors.
const { Client } = require('../runtime/node_modules/pg');
const { randomUUID } = require('node:crypto');
const assert = require('node:assert/strict');
if (process.env.PLAYSPOT_EXACT_SCHEMA_TEST !== '1') throw new Error('Isolated schema test opt-in required');
const target = new URL(process.env.PLAYSPOT_ISOLATED_DB_URL || '');
if (!['127.0.0.1','localhost'].includes(target.hostname)) throw new Error('Only a localhost database is allowed');
const cfg = {connectionString:target.toString()};
const ids={admin:'00000000-0000-0000-0000-000000000001',customer:'00000000-0000-0000-0000-000000000002',manager:'00000000-0000-0000-0000-000000000003',lounge:'00000000-0000-0000-0000-000000000010',room:'00000000-0000-0000-0000-000000000020',shift:'00000000-0000-0000-0000-000000000030'};
const fn='SELECT public.checkout_booking_cash_atomic($1,$2,$3,$4,$5,$6,$7) AS result';
async function client(){const c=new Client(cfg);await c.connect();return c;}
async function booking(c,day){const id=randomUUID();await c.query("INSERT INTO public.bookings(id,user_id,lounge_id,room_id,date,start_time,end_time,status,room_price,total_price,payment_status) VALUES($1,$2,$3,$4,current_date-$5::int,'10:00','11:00','completed',100,100,'unpaid')",[id,ids.customer,ids.lounge,ids.room,day]);await c.query("UPDATE public.bookings SET status='completed' WHERE id=$1",[id]);return id;}
async function call(c,actor,args){await c.query('BEGIN');try{await c.query('SET LOCAL ROLE authenticated');await c.query("SELECT set_config('request.jwt.claim.sub',$1,true)",[actor]);const r=await c.query(fn,args);await c.query('COMMIT');return {ok:true,result:r.rows[0].result};}catch(e){await c.query('ROLLBACK');return {ok:false,code:e.code,message:e.message};}}
async function collect(c,actor,args){await c.query('BEGIN');try{await c.query('SET LOCAL ROLE authenticated');await c.query("SELECT set_config('request.jwt.claim.sub',$1,true)",[actor]);const r=await c.query('SELECT public.collect_booking_cash_partial($1,$2,$3,$4) AS result',args);await c.query('COMMIT');return {ok:true,result:r.rows[0].result};}catch(e){await c.query('ROLLBACK');return {ok:false,code:e.code,message:e.message};}}
async function state(c,id){return (await c.query(`SELECT b.total_price,b.discount_amount,b.payment_status,p.amount,p.discount_amount AS payment_discount,
  p.commission_rate,p.commission,p.net_to_lounge,p.discount_reason,p.discount_approved_by,
  (SELECT COALESCE(sum(sp.amount),0) FROM public.shift_payments sp WHERE sp.booking_id=b.id) AS shift_amount,
  (SELECT count(*)::int FROM public.shift_payments sp WHERE sp.booking_id=b.id AND sp.payment_method='cash' AND sp.category='gaming_time') AS cash_shift_rows,
  (SELECT count(*)::int FROM private.cash_collection_receipts r WHERE r.booking_id=b.id) AS receipts
  FROM public.bookings b LEFT JOIN public.payments p ON p.booking_id=b.id WHERE b.id=$1`,[id])).rows[0];}
async function main(){const setup=await client(),cashier=await client();try{
  assert.equal((await setup.query('SELECT inet_server_port() AS port')).rows[0].port,5432);
  assert.equal((await setup.query("SELECT token FROM private.playspot_isolated_test_guard WHERE token='PLAYSPOT_DISPOSABLE_EXACT_SCHEMA_20261025'")).rowCount,1);
  ids.manager=randomUUID();ids.lounge=randomUUID();ids.room=randomUUID();
  await setup.query('INSERT INTO auth.users(id) VALUES($1)',[ids.manager]);
  await setup.query("INSERT INTO public.lounges(id,name,status,is_active,instapay_account,allow_cash_payment,require_prepaid_first_time) VALUES($1,'Isolated atomic fixture','active',true,'TEST-ONLY',true,false)",[ids.lounge]);
  await setup.query("INSERT INTO public.rooms(id,lounge_id,name,status,hourly_rate_single) VALUES($1,$2,'Fixture PC','available',100)",[ids.room,ids.lounge]);
  await setup.query("INSERT INTO public.profiles(id,lounge_id,role,is_active,is_banned) VALUES($1,$2,'manager',true,false)",[ids.manager,ids.lounge]);
  await setup.query("INSERT INTO public.staff_permissions(user_id,lounge_id,permission_key,is_enabled) VALUES($1,$2,'billing_checkout',true)",[ids.manager,ids.lounge]);
  ids.shift=randomUUID();
  await setup.query("INSERT INTO public.shifts(id,lounge_id,status,cashier_id,staff_user_id,opened_at) VALUES($1,$2,'open',$3,$3,now())",[ids.shift,ids.lounge,ids.manager]);
  const day=12000+Math.floor(Math.random()*10000),id=await booking(setup,day),op=randomUUID();
  const args=[id,ids.shift,9000,op,10,0,'fixture discount'];
  const first=await call(cashier,ids.manager,args);assert.equal(first.ok,true,JSON.stringify(first));
  const replay=await call(cashier,ids.manager,args);assert.equal(replay.ok,true,JSON.stringify(replay));
  assert.equal(first.result.replayed,false);assert.equal(replay.result.replayed,true);
  assert.equal(first.result.shift_payment_id,replay.result.shift_payment_id);
  assert.equal(first.result.total_minor,replay.result.total_minor);
  const changed=await call(cashier,ids.manager,[id,ids.shift,9000,op,9,0,'fixture discount']);
  assert.equal(changed.message,'ATOMIC_CHECKOUT_REPLAY_CONFLICT');
  const paid=await state(setup,id);
  assert.equal(Number(paid.total_price),90);assert.equal(Number(paid.discount_amount),10);
  assert.equal(Number(paid.amount),90);assert.equal(Number(paid.payment_discount),10);
  assert.equal(Number(paid.shift_amount),90);assert.equal(paid.receipts,1);assert.equal(paid.payment_status,'paid');
  assert.equal(Number(paid.commission)+Number(paid.net_to_lounge),Number(paid.amount));
  assert.equal(paid.cash_shift_rows,1);assert.equal(paid.discount_reason,'fixture discount');
  assert.equal(paid.discount_approved_by,ids.manager);
  process.stdout.write(JSON.stringify({scenario:'discount collection replay reconciliation',first:first.result,replay:replay.result,changed,paid})+'\n');

  const partialId=await booking(setup,day+3);
  const initial=await collect(cashier,ids.manager,[partialId,ids.shift,4000,randomUUID()]);
  assert.equal(initial.ok,true,JSON.stringify(initial));
  const settled=await call(cashier,ids.manager,[partialId,ids.shift,5000,randomUUID(),10,0,'settle partial']);
  assert.equal(settled.ok,true,JSON.stringify(settled));
  const partialState=await state(setup,partialId);
  assert.equal(Number(partialState.total_price),90);assert.equal(Number(partialState.amount),90);
  assert.equal(Number(partialState.payment_discount),10);assert.equal(Number(partialState.shift_amount),90);
  assert.equal(partialState.receipts,2);assert.equal(partialState.payment_status,'paid');
  assert.equal(Number(partialState.commission)+Number(partialState.net_to_lounge),Number(partialState.amount));
  assert.equal(partialState.cash_shift_rows,2);
  process.stdout.write(JSON.stringify({scenario:'atomic discount settles previous partial receipt',initial:initial.result,settled:settled.result,state:partialState})+'\n');

  const percentageId=await booking(setup,day+4);
  const percentage=await call(cashier,ids.manager,[percentageId,ids.shift,9000,randomUUID(),0,10,'ten percent']);
  assert.equal(percentage.ok,true,JSON.stringify(percentage));
  const percentageState=await state(setup,percentageId);
  assert.equal(Number(percentageState.total_price),90);
  assert.equal(Number(percentageState.discount_amount),10);
  assert.equal(Number(percentageState.payment_discount),10);
  assert.equal(Number(percentageState.shift_amount),90);
  process.stdout.write(JSON.stringify({scenario:'percentage discount accounting',state:percentageState})+'\n');

  const sameOpId=await booking(setup,day+5),sameOp=randomUUID(),secondCashier=await client();
  try {
    const raceArgs=[sameOpId,ids.shift,9000,sameOp,10,0,'parallel checkout'];
    const race=await Promise.all([call(cashier,ids.manager,raceArgs),call(secondCashier,ids.manager,raceArgs)]);
    assert.equal(race.every(r=>r.ok),true,JSON.stringify(race));
    assert.deepEqual(race.map(r=>r.result.replayed).sort(),[false,true]);
    const raceState=await state(setup,sameOpId);
    assert.equal(Number(raceState.amount),90);assert.equal(Number(raceState.shift_amount),90);assert.equal(raceState.receipts,1);
    process.stdout.write(JSON.stringify({scenario:'simultaneous atomic checkout replay',race,state:raceState})+'\n');
  } finally {await secondCashier.end();}

  const competingId=await booking(setup,day+6),competingCashier=await client();
  try {
    const base=[competingId,ids.shift,9000,null,10,0,'competing discount'];
    const competing=await Promise.all([
      call(cashier,ids.manager,[...base.slice(0,3),randomUUID(),...base.slice(4)]),
      call(competingCashier,ids.manager,[...base.slice(0,3),randomUUID(),...base.slice(4)]),
    ]);
    assert.equal(competing.filter(r=>r.ok).length,1,JSON.stringify(competing));
    assert.equal(competing.find(r=>!r.ok).message,'DISCOUNT_ALREADY_APPLIED');
    const competingState=await state(setup,competingId);
    assert.equal(Number(competingState.amount),90);assert.equal(Number(competingState.shift_amount),90);
    assert.equal(competingState.receipts,1);assert.equal(competingState.cash_shift_rows,1);
    process.stdout.write(JSON.stringify({scenario:'different-operation concurrent discount checkout',competing,state:competingState})+'\n');
  } finally {await competingCashier.end();}

  const rejectedId=await booking(setup,day+1);
  const excess=await call(cashier,ids.manager,[rejectedId,ids.shift,9500,randomUUID(),10,0,'too much']);
  assert.equal(excess.message,'CASH_EXCEEDS_OUTSTANDING_BALANCE');
  const rejected=await state(setup,rejectedId);
  assert.equal(Number(rejected.total_price),100);assert.equal(Number(rejected.discount_amount),0);
  assert.equal(rejected.amount,null);assert.equal(Number(rejected.shift_amount),0);assert.equal(rejected.receipts,0);
  process.stdout.write(JSON.stringify({scenario:'overpayment rolls discount back',excess,rejected})+'\n');

  const unauthorizedId=await booking(setup,day+2);
  const customer=await call(cashier,ids.customer,[unauthorizedId,ids.shift,9000,randomUUID(),10,0,'unauthorized']);
  const manager=await call(cashier,ids.admin,[unauthorizedId,ids.shift,9000,randomUUID(),10,0,'wrong shift']);
  assert.equal(customer.ok,false);assert.equal(manager.message,'OWN_OPEN_SHIFT_REQUIRED');
  const unauthorized=await state(setup,unauthorizedId);
  assert.equal(unauthorized.receipts,0);assert.equal(Number(unauthorized.discount_amount),0);
  const grants=(await setup.query(`SELECT has_function_privilege('anon','public.checkout_booking_cash_atomic(uuid,uuid,numeric,uuid,numeric,numeric,text)','EXECUTE') AS anon,
    has_function_privilege('authenticated','public.checkout_booking_cash_atomic(uuid,uuid,numeric,uuid,numeric,numeric,text)','EXECUTE') AS authenticated,
    has_table_privilege('authenticated','private.cash_collection_receipts','SELECT') AS receipt_select`)).rows[0];
  assert.deepEqual(grants,{anon:false,authenticated:true,receipt_select:false});
  await cashier.query('BEGIN');
  await cashier.query('SET LOCAL ROLE authenticated');
  await assert.rejects(cashier.query('SELECT * FROM private.cash_collection_receipts LIMIT 1'),e=>e.code==='42501');
  await cashier.query('ROLLBACK');
  process.stdout.write(JSON.stringify({scenario:'authorization and grants',customer,manager,unauthorized,grants})+'\n');

  const futureId=randomUUID();
  await setup.query("INSERT INTO public.bookings(id,user_id,lounge_id,room_id,date,start_time,end_time,status,room_price,total_price,payment_status) VALUES($1,$2,$3,$4,current_date+365,'10:00','11:00','pending',100,100,'unpaid')",[futureId,ids.customer,ids.lounge,ids.room]);
  const future=await call(cashier,ids.manager,[futureId,ids.shift,9000,randomUUID(),10,0,'future booking']);
  assert.equal(future.ok,true,JSON.stringify(future));
  const futureState=await state(setup,futureId);
  assert.equal(futureState.payment_status,'paid');
  assert.equal(Number(futureState.amount),90);
  assert.equal(Number(futureState.shift_amount),90);
  assert.equal(futureState.receipts,1);
  await setup.query("UPDATE public.staff_permissions SET is_enabled=false WHERE user_id=$1 AND lounge_id=$2 AND permission_key='billing_checkout'",[ids.manager,ids.lounge]);
  const revoked=await call(cashier,ids.manager,args);
  assert.equal(revoked.message,'CASH_COLLECTION_PERMISSION_DENIED');
  process.stdout.write(JSON.stringify({scenario:'future reservation collection and revoked replay denied',future,revoked})+'\n');
}finally{await Promise.allSettled([setup.end(),cashier.end()]);}}
main().catch(e=>{process.stderr.write(`${e.code||'ERROR'} ${e.message}\n`);process.exitCode=1;});
