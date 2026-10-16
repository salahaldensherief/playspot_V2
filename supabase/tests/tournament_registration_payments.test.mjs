import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {createFixtureDatabase} from './runtime/database.mjs';

const db=await createFixtureDatabase();
const id=n=>`00000000-0000-0000-0000-${String(n).padStart(12,'0')}`;
let passed=0;
async function check(name,body){
  await db.exec('BEGIN');
  try{await body();passed++;console.log('PASS '+name);}
  finally{await db.exec('ROLLBACK');}
}
async function reject(action,code){
  await db.exec('SAVEPOINT expected_error');
  try{await assert.rejects(action,e=>e.code===code);}
  finally{await db.exec('ROLLBACK TO SAVEPOINT expected_error; RELEASE SAVEPOINT expected_error');}
}
async function actor(n){await db.query("SELECT set_config('test.actor',$1,true)",[id(n)]);}
async function register(n){await actor(n);return (await db.query('SELECT public.register_for_tournament($1) participant',[id(10)])).rows[0].participant;}
async function cash(pid,amount=100){return (await db.query('SELECT (public.record_cash_tournament_payment($1,$2,NULL)).*',[pid,amount])).rows[0];}
try{
  await db.exec(await readFile(new URL('./fixtures/tournament_registration_fixture.sql',import.meta.url),'utf8'));
  await db.exec(await readFile(new URL('./fixtures/deployed_cancel_tournament.sql',import.meta.url),'utf8'));
  await db.exec(await readFile(new URL('../migrations/20261015221806_tournament_registration_payment_lifecycle.sql',import.meta.url),'utf8'));
  for(let n=1;n<=8;n++)await db.query('INSERT INTO public.profiles VALUES($1,true,false)',[id(n)]);
  await db.query(`INSERT INTO public.tournaments(id,lounge_id,status,entry_fee,max_participants,
    registration_opens_at,registration_closes_at,check_in_closes_at,payment_deadline_minutes)
    VALUES($1,$2,'registration_open',100,2,now()-interval '1 hour',now()+interval '1 hour',now()+interval '3 hours',60)`,[id(10),id(11)]);
  await check('paid registration reserves a seat without claiming a payment',async()=>{
    const p=await register(1);assert.equal(p.registration_status,'pending_payment');assert.equal(p.payment_status,'unpaid');assert.ok(p.payment_deadline);
    assert.equal((await db.query('SELECT count(*)::int n FROM public.payments')).rows[0].n,0);
  });
  await check('free registration confirms without creating a financial payment',async()=>{
    await db.exec('UPDATE public.tournaments SET entry_fee=0');
    const p=await register(1);assert.equal(p.registration_status,'confirmed');assert.equal(p.payment_status,'paid');assert.equal(p.payment_deadline,null);
    assert.equal((await db.query('SELECT count(*)::int n FROM public.payments')).rows[0].n,0);
  });
  await check('duplicate registration cannot reserve a second seat',async()=>{
    await register(1);await reject(()=>register(1),'23505');
    assert.equal((await db.query('SELECT count(*)::int n FROM public.tournament_participants')).rows[0].n,1);
  });
  await check('capacity overflow creates ordered waitlist entries without deadlines',async()=>{
    await register(1);await register(2);
    const third=await register(3),fourth=await register(4);
    assert.equal(third.registration_status,'waitlist');assert.equal(third.waitlist_position,1);assert.equal(third.payment_deadline,null);assert.equal(fourth.waitlist_position,2);
  });
  await check('cash payment confirms the held seat once and records its actor',async()=>{
    const p=await register(1);await actor(2);
    await db.query('SELECT public.record_cash_tournament_payment($1,100,NULL)',[p.id]);
    const row=(await db.query('SELECT * FROM public.tournament_participants WHERE id=$1',[p.id])).rows[0];
    assert.equal(row.payment_status,'paid');assert.equal(row.cash_received_by,id(2));
    await reject(()=>db.query('SELECT public.record_cash_tournament_payment($1,100,NULL)',[p.id]),'55000');
  });
  await check('cash collection rejects expired reservation deadlines before the expiry job',async()=>{
    const p=await register(1);await db.query("UPDATE public.tournament_participants SET payment_deadline=now()-interval '1 minute' WHERE id=$1",[p.id]);
    await reject(()=>cash(p.id),'55000');
  });
  await check('cash collection rejects wrong, negative, fractional and nonfinite amounts',async()=>{
    const p=await register(1);
    for(const amount of [99,-1,'100.001','NaN','Infinity',null])await reject(()=>cash(p.id,amount),'22023');
  });
  await check('a waitlisted participant cannot pay for a seat they do not hold',async()=>{
    await register(1);await register(2);const p=await register(3);await reject(()=>cash(p.id),'55000');
  });
  await check('cash collection requires actual tournament management authority',async()=>{
    const p=await register(1);await db.exec("SET test.manager='false'");await reject(()=>cash(p.id),'42501');
  });
  await check('inactive accounts cannot register',async()=>{
    await db.query('UPDATE public.profiles SET is_active=false WHERE id=$1',[id(1)]);await reject(()=>register(1),'42501');
  });
  await check('paid cancellation queues refunds without claiming they were paid',async()=>{
    const first=await register(1);await db.query('SELECT public.record_cash_tournament_payment($1,100,NULL)',[first.id]);
    const second=await register(2);await db.query('SELECT public.record_cash_tournament_payment($1,100,NULL)',[second.id]);
    await db.query('SELECT public.cancel_tournament($1,$2)',[id(10),'QA cancellation']);
    assert.equal((await db.query('SELECT count(*)::int n FROM public.tournament_refunds')).rows[0].n,2);
    assert.ok((await db.query('SELECT payment_status FROM public.tournament_participants')).rows.every(p=>p.payment_status==='refund_pending'));
    await reject(()=>db.query('SELECT public.cancel_tournament($1,$2)',[id(10),'repeat']),'P0001');
    assert.equal((await db.query('SELECT count(*)::int n FROM public.tournament_refunds')).rows[0].n,2);
  });
  await check('unpaid cancellation creates no refund',async()=>{
    await register(1);await db.query('SELECT public.cancel_tournament($1,$2)',[id(10),'QA cancellation']);
    assert.equal((await db.query('SELECT count(*)::int n FROM public.tournament_refunds')).rows[0].n,0);
    assert.equal((await db.query('SELECT payment_status FROM public.tournament_participants')).rows[0].payment_status,'cancelled');
  });
  await check('promotion respects FIFO and confirms free seats without a payment',async()=>{
    await db.exec('UPDATE public.tournaments SET entry_fee=0');
    await register(1);await register(2);const waiting=await register(3);
    await db.query("UPDATE public.tournament_participants SET registration_status='withdrawn' WHERE user_id=$1",[id(1)]);
    await db.query('SELECT private.promote_tournament_waitlist_internal($1)',[id(10)]);
    const promoted=(await db.query('SELECT * FROM public.tournament_participants WHERE id=$1',[waiting.id])).rows[0];
    assert.equal(promoted.registration_status,'confirmed');assert.equal(promoted.payment_status,'paid');assert.equal(promoted.payment_deadline,null);
  });
  console.log(JSON.stringify({passed,synthetic:true,hostedConnections:0,limitations:['Synthetic authorization helpers; actual Auth/RLS coverage runs separately']}));
}finally{await db.close();}
