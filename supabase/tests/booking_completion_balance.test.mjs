import {createFixtureDatabase} from './runtime/database.mjs';
import {readFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
const db=await createFixtureDatabase();
const id=n=>`00000000-0000-0000-0000-${String(n).padStart(12,'0')}`;
const lounge=id(1),room=id(2),staff=id(3),booking=id(4),shift=id(5);
let passed=0;
const complete=async()=>(await db.query('SELECT complete_booking_session($1) r',[booking])).rows[0].r;
async function check(name,body){await db.exec('BEGIN');try{await body();passed++;console.log('PASS '+name);}finally{await db.exec('ROLLBACK');}}
async function denied(action,code='55000'){await db.exec('SAVEPOINT denied');await assert.rejects(action(),e=>e.code===code);await db.exec('ROLLBACK TO SAVEPOINT denied;RELEASE SAVEPOINT denied');}
async function prepay(amount=60,method='cash'){
  await db.query(`INSERT INTO payments(booking_id,lounge_id,user_id,amount,commission_rate,commission,net_to_lounge,payment_method,status)
    VALUES($1,$2,$3,$4,0.15,$4::numeric*0.15,$4::numeric*0.85,$5,'completed')`,[booking,lounge,id(6),amount,method]);
  await db.query('UPDATE bookings SET payment_status=$1,payment_method=$2 WHERE id=$3',[amount===60?'paid':'partial',method,booking]);
  if(method==='cash')await db.query(`INSERT INTO shift_payments(shift_id,lounge_id,booking_id,payment_method,category,amount)
    VALUES($1,$2,$3,'cash','gaming_time',$4)`,[shift,lounge,booking,amount]);
}
try{
  await db.exec(await readFile(new URL('./runtime/checkout_canteen_schema.sql',import.meta.url),'utf8'));
  await db.exec(`CREATE TABLE auth.users(id uuid PRIMARY KEY);
    CREATE TABLE payments(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),booking_id uuid UNIQUE,user_id uuid,lounge_id uuid,
      amount numeric,commission_rate numeric,commission numeric,net_to_lounge numeric,payment_method text,status text,
      paid_at timestamptz DEFAULT now(),payout_id uuid);
    CREATE FUNCTION private.platform_commission_rate() RETURNS numeric LANGUAGE sql AS $$SELECT 0.15$$;
    CREATE FUNCTION public.has_lounge_permission(uuid,text) RETURNS boolean LANGUAGE sql AS $$
      SELECT auth.uid()='${staff}'::uuid AND $1='${lounge}'::uuid$$;
    INSERT INTO auth.users VALUES('${staff}');
    INSERT INTO profiles(id,role,is_active,is_banned) VALUES('${staff}','cashier',true,false);
    INSERT INTO lounges(id,name,status,is_active) VALUES('${lounge}','Fixture','active',true);
    INSERT INTO rooms(id,lounge_id,name,status) VALUES('${room}','${lounge}','Room','occupied');
    INSERT INTO shifts(id,lounge_id,status,cashier_id,staff_user_id) VALUES('${shift}','${lounge}','open','${staff}','${staff}');
    INSERT INTO bookings(id,user_id,lounge_id,room_id,date,start_time,end_time,status,room_price,total_price,
      is_open_time,open_time_started_at,open_time_pricing_snapshot)
    VALUES('${booking}','${id(6)}','${lounge}','${room}',current_date,'10:00','11:00','in_progress',60,60,
      true,now()-interval '120 minutes','{"effective_hourly_rate":60,"minimum_minutes":30,"rounding_minutes":15,"max_minutes":720}');
    SET request.jwt.claim.sub='${staff}';`);
  const actor=await readFile(new URL('../migrations/20261010134409_eligible_booking_hold_and_checkout_actor.sql',import.meta.url),'utf8');
  await db.exec(actor.slice(0,actor.indexOf('-- Gate before capacity'))+'\nCOMMIT;');
  await db.exec(await readFile(new URL('../repairs/partial_cash_collection.sql',import.meta.url),'utf8'));
  await db.exec(await readFile(new URL('../migrations/20261011071308_booking_completion_collected_balance.sql',import.meta.url),'utf8'));
  await db.exec(`CREATE TABLE loyalty_observations(payment_status text);
    CREATE FUNCTION observe_loyalty() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN
      IF NEW.status='completed' AND OLD.status IS DISTINCT FROM NEW.status THEN
        INSERT INTO public.loyalty_observations VALUES(NEW.payment_status);
      END IF;RETURN NEW;END$$;
    CREATE TRIGGER completion_observation AFTER UPDATE ON bookings FOR EACH ROW EXECUTE FUNCTION observe_loyalty();`);
  await db.exec(await readFile(new URL('../migrations/20261011075336_booking_collection_remaining_balance.sql',import.meta.url),'utf8'));
  await check('prepaid open-time growth leaves a real balance and never inserts phantom cash',async()=>{
    await prepay();const r=await complete();assert.equal(r.final_total,120);assert.equal(r.amount_paid,60);
    assert.equal(r.amount_due,60);assert.equal(r.payment_status,'partial');
    assert.equal((await db.query('SELECT count(*) n,sum(amount) total FROM shift_payments')).rows[0].n,'1');
    assert.equal(Number((await db.query('SELECT amount FROM payments')).rows[0].amount),60);
    assert.equal((await db.query('SELECT payment_status FROM bookings')).rows[0].payment_status,'partial');
    assert.equal((await db.query('SELECT payment_status FROM loyalty_observations')).rows[0].payment_status,'partial');
    const retry=await complete();assert.equal(retry.idempotent,true);assert.equal(retry.amount_due,60);
  });
  await check('explicit canonical collection settles only the remainder then close retry reports collected funds',async()=>{
    await prepay();await complete();
    const collected=(await db.query('SELECT collect_booking_cash_partial($1,$2,6000,$3) r',[booking,shift,id(7)])).rows[0].r;
    assert.equal(collected.due_minor,0);assert.equal(collected.paid_minor,12000);
    const retry=await complete();assert.equal(retry.amount_paid,120);assert.equal(retry.amount_due,0);
    assert.equal(retry.payment_status,'paid');
    assert.equal(Number((await db.query('SELECT sum(amount) total FROM shift_payments')).rows[0].total),120);
  });
  await check('electronic prepayment remains electronic and its increased balance is not recorded as cash',async()=>{
    await prepay(60,'instapay');const r=await complete();assert.equal(r.amount_due,60);
    assert.equal((await db.query('SELECT * FROM shift_payments')).rows.length,0);
    assert.equal((await db.query('SELECT payment_method FROM payments')).rows[0].payment_method,'instapay');
  });
  await check('unpaid session closes with full balance and no payment rows',async()=>{
    const r=await complete();assert.equal(r.amount_paid,0);assert.equal(r.amount_due,120);assert.equal(r.payment_status,'unpaid');
    assert.equal((await db.query('SELECT * FROM payments')).rows.length,0);
    assert.equal((await db.query('SELECT * FROM shift_payments')).rows.length,0);
  });
  await check('partial prepayment is reported from the ledger instead of zero',async()=>{
    await prepay(30);const r=await complete();assert.equal(r.amount_paid,30);assert.equal(r.amount_due,90);
  });
  await check('unproven legacy paid flags require reconciliation without releasing the room',async()=>{
    await db.exec("UPDATE bookings SET payment_status='paid'");await denied(()=>complete());
    assert.equal((await db.query('SELECT status FROM bookings')).rows[0].status,'in_progress');
    assert.equal((await db.query('SELECT status FROM rooms')).rows[0].status,'occupied');
  });
  await check('payment in a different lounge or refunded ledger is not accepted as collected',async()=>{
    await prepay();await db.query('UPDATE payments SET lounge_id=$1',[id(90)]);await denied(()=>complete());
    await db.query("UPDATE payments SET lounge_id=$1,status='refunded'",[lounge]);await denied(()=>complete());
  });
  await check('canonical cash receipt mismatch fails closed without updating totals',async()=>{
    await prepay();await db.query(`INSERT INTO private.cash_collection_receipts(operation_id,actor_id,booking_id,shift_id,amount_minor)
      VALUES($1,$2,$3,$4,6000)`,[id(8),staff,booking,shift]);
    await db.exec('UPDATE shift_payments SET amount=10');await denied(()=>complete());
    assert.equal(Number((await db.query('SELECT total_price FROM bookings')).rows[0].total_price),60);
  });
  await check('standard sessions keep their price and actual paid balance',async()=>{
    await prepay();await db.exec('UPDATE bookings SET is_open_time=false');const r=await complete();
    assert.equal(r.final_total,60);assert.equal(r.amount_paid,60);assert.equal(r.payment_status,'paid');
  });
  await check('inactive, banned and wrong-lounge callers cannot close sessions',async()=>{
    await db.exec('UPDATE profiles SET is_active=false');await denied(()=>complete(),'42501');
    await db.exec('UPDATE profiles SET is_active=true,is_banned=true');await denied(()=>complete(),'42501');
    await db.exec(`UPDATE profiles SET is_banned=false;SET request.jwt.claim.sub='${id(90)}'`);await denied(()=>complete(),'42501');
  });
  await check('Dashboard cash confirmation collects only the remainder and retries without duplicating',async()=>{
    await prepay();await complete();
    const r=(await db.query("SELECT complete_booking_payment($1,'cash') r",[booking])).rows[0].r;
    assert.equal(r.amount_collected,60);assert.equal(r.amount_paid,120);
    assert.equal(Number((await db.query('SELECT sum(amount) total FROM shift_payments')).rows[0].total),120);
    const retry=(await db.query("SELECT complete_booking_payment($1,'cash') r",[booking])).rows[0].r;
    assert.equal(retry.idempotent,true);
    assert.equal((await db.query('SELECT count(*) n FROM shift_payments')).rows[0].n,'2');
    await denied(()=>db.query("SELECT complete_booking_payment($1,'instapay')",[booking]),'22023');
  });
  await check('electronic and mixed installments retain history and require separate receipts',async()=>{
    await prepay(60,'instapay');await complete();
    await denied(()=>db.query("SELECT complete_booking_payment($1,'instapay')",[booking]));
    await denied(()=>db.query("SELECT complete_booking_payment($1,'cash')",[booking]));
    assert.equal(Number((await db.query('SELECT amount FROM payments')).rows[0].amount),60);
    assert.equal((await db.query('SELECT * FROM shift_payments')).rows.length,0);
  });
  await check('wallet method cannot fabricate payment without debiting verified wallet',async()=>{
    await complete();await denied(()=>db.query("SELECT complete_booking_payment($1,'app_wallet')",[booking]),'22023');
    assert.equal((await db.query('SELECT * FROM payments')).rows.length,0);
  });
  console.log(JSON.stringify({passed,environment:'isolated actual RPC and cash-collector bodies; no production writes'}));
}finally{await db.close();}
