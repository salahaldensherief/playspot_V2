import {createFixtureDatabase} from './runtime/database.mjs';
import {readFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
import {randomUUID} from 'node:crypto';
import {lockedRace} from './runtime/locked_race.mjs';

const db=await createFixtureDatabase();
const actor=randomUUID(), customer=randomUUID(), outsider=randomUUID();
const lounge=randomUUID(), foreignLounge=randomUUID(), booking=randomUUID(), shift=randomUUID();
let passed=0;
const collect=(amount,id=randomUUID(),b=booking,s=shift)=>({sql:
  'SELECT public.collect_booking_cash_partial($1,$2,$3,$4) AS receipt',args:[b,s,amount,id]});
async function asActor(id=actor) {await db.exec(`RESET ROLE; SET test.actor='${id}'; SET ROLE authenticated;`);}
async function admin(sql) {await db.exec(`RESET ROLE;${sql}`);}
async function state() {await db.exec('RESET ROLE');return (await db.query(`SELECT jsonb_build_object(
 'bookings',(SELECT jsonb_agg(to_jsonb(b) ORDER BY id) FROM public.bookings b),
 'payments',(SELECT jsonb_agg(to_jsonb(p) ORDER BY id) FROM public.payments p),
 'shift_payments',(SELECT jsonb_agg(to_jsonb(p) ORDER BY id) FROM public.shift_payments p),
 'receipts',(SELECT jsonb_agg(to_jsonb(r) ORDER BY operation_id) FROM private.cash_collection_receipts r),
 'context',(SELECT count(*) FROM private.cash_collection_context)) AS value`)).rows[0].value;}
async function reject(name,request,code,id=actor) {
 const before=await state();await asActor(id);
 await assert.rejects(db.query(request.sql,request.args),error=>error.code===code);
 assert.deepEqual(await state(),before);passed++;console.log('PASS '+name);
}
async function check(name,body) {await body();passed++;console.log('PASS '+name);}
try {
 await db.exec(`CREATE ROLE anon;CREATE ROLE authenticated;CREATE SCHEMA auth;CREATE SCHEMA private;
 CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql AS $$SELECT NULLIF(current_setting('test.actor',true),'')::uuid$$;
 CREATE TABLE auth.users(id uuid PRIMARY KEY);
 CREATE TABLE public.profiles(id uuid PRIMARY KEY,role text,is_active boolean,is_banned boolean);
 CREATE TABLE public.platform_super_admins(user_id uuid PRIMARY KEY);
 CREATE TABLE public.lounges(id uuid PRIMARY KEY,is_active boolean,status text);
 CREATE TABLE public.fixture_permissions(actor uuid,lounge uuid,permission text);
 CREATE FUNCTION public.has_lounge_permission(uuid,text) RETURNS boolean LANGUAGE sql SECURITY DEFINER SET search_path='' AS
 $$SELECT EXISTS(SELECT 1 FROM public.fixture_permissions WHERE actor=auth.uid() AND lounge=$1 AND permission=$2)$$;
 CREATE FUNCTION private.platform_commission_rate() RETURNS numeric LANGUAGE sql IMMUTABLE AS $$SELECT 0.15::numeric$$;
 CREATE TABLE public.shifts(id uuid PRIMARY KEY,lounge_id uuid,cashier_id uuid,staff_user_id uuid,status text,closed_at timestamptz);
 CREATE TABLE public.bookings(id uuid PRIMARY KEY,user_id uuid,lounge_id uuid,status text,is_open_time boolean DEFAULT false,
 total_price numeric,payment_status text DEFAULT 'unpaid',payment_method text,updated_at timestamptz);
 CREATE TABLE public.payments(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),booking_id uuid UNIQUE REFERENCES public.bookings(id),
 user_id uuid,lounge_id uuid,amount numeric CHECK(amount>=0),commission_rate numeric CHECK(commission_rate BETWEEN 0 AND 1),
 commission numeric,net_to_lounge numeric,payment_method text,status text,payout_id uuid,paid_at timestamptz);
 CREATE TABLE public.shift_payments(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),shift_id uuid REFERENCES public.shifts(id),
 lounge_id uuid,booking_id uuid,payment_method text,category text CHECK(category IN ('gaming_time','snacks','extra_controllers','other')),
 amount numeric CHECK(amount>=0),paid_at timestamptz);
 CREATE FUNCTION public.enforce_payment_financials() RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $$
 BEGIN NEW.commission_rate:=private.platform_commission_rate();NEW.commission:=round(NEW.amount*NEW.commission_rate,2);
 NEW.net_to_lounge:=NEW.amount-NEW.commission;RETURN NEW;END;$$;
 CREATE TRIGGER finance BEFORE INSERT OR UPDATE ON public.payments FOR EACH ROW EXECUTE FUNCTION public.enforce_payment_financials();
 CREATE FUNCTION public.prevent_closed_shift_transaction() RETURNS trigger LANGUAGE plpgsql AS $$
 BEGIN IF NOT EXISTS(SELECT 1 FROM public.shifts WHERE id=NEW.shift_id AND status='open') THEN
 RAISE EXCEPTION 'CLOSED_SHIFT' USING ERRCODE='55000';END IF;RETURN NEW;END;$$;
 CREATE TRIGGER closed_shift BEFORE INSERT ON public.shift_payments FOR EACH ROW EXECUTE FUNCTION public.prevent_closed_shift_transaction();
 INSERT INTO auth.users VALUES('${actor}'),('${customer}'),('${outsider}');
 INSERT INTO public.profiles VALUES('${actor}','cashier',true,false),('${outsider}','cashier',true,false);
 INSERT INTO public.lounges VALUES('${lounge}',true,'active'),('${foreignLounge}',true,'active');
 INSERT INTO public.fixture_permissions VALUES('${actor}','${lounge}','billing_checkout');
 INSERT INTO public.shifts VALUES('${shift}','${lounge}','${actor}','${actor}','open',NULL);
 INSERT INTO public.bookings(id,user_id,lounge_id,status,total_price) VALUES('${booking}','${customer}','${lounge}','completed',100);
 GRANT USAGE ON SCHEMA public,auth TO authenticated,anon;
 `);
 await db.exec(await readFile(new URL('../repairs/active_super_admin_boundary.sql',import.meta.url),'utf8'));
 await db.exec(await readFile(new URL('../repairs/partial_cash_collection.sql',import.meta.url),'utf8'));
 await reject('anonymous collection',collect(1000),'28000','');
 await reject('unassigned cashier',collect(1000),'42501',outsider);
 for(const amount of [null,0,-1,'NaN','Infinity','-Infinity',1.5,'9007199254740992'])
  await reject('invalid minor units '+amount,collect(amount),'22023');
 await reject('overpayment',collect(10001),'22023');
 await admin(`UPDATE public.profiles SET is_banned=true WHERE id='${actor}'`);
 await reject('banned cashier',collect(1000),'42501');
 await admin(`UPDATE public.profiles SET is_banned=false,is_active=false WHERE id='${actor}'`);
 await reject('inactive cashier',collect(1000),'42501');
 await admin(`UPDATE public.profiles SET is_active=true WHERE id='${actor}';UPDATE public.lounges SET status='pending' WHERE id='${lounge}'`);
 await reject('unapproved venue',collect(1000),'42501');
 await admin(`UPDATE public.lounges SET status='active';UPDATE public.shifts SET cashier_id='${outsider}'`);
 await reject('another cashier shift',collect(1000),'55000');
 await admin(`UPDATE public.shifts SET cashier_id='${actor}',staff_user_id='${outsider}'`);
 await reject('conflicting staff identity',collect(1000),'55000');
 await admin(`UPDATE public.shifts SET staff_user_id='${actor}',lounge_id='${foreignLounge}'`);
 await reject('another venue shift',collect(1000),'55000');
 await admin(`UPDATE public.shifts SET lounge_id='${lounge}',status='closed',closed_at=now()`);
 await reject('closed shift',collect(1000),'55000');
 await admin(`UPDATE public.shifts SET status='open',closed_at=NULL;UPDATE public.bookings SET status='cancelled'`);
 await reject('cancelled booking',collect(1000),'55000');
 await admin(`UPDATE public.bookings SET status='in_progress',is_open_time=true`);
 await reject('unsettled open time',collect(1000),'55000');
 await admin(`UPDATE public.bookings SET status='completed',is_open_time=false`);
 for(const total of ['NULL',"'NaN'::numeric","'Infinity'::numeric",'-1','100.001']) {
  await admin(`UPDATE public.bookings SET total_price=${total}`);
  await reject('invalid server total '+total,collect(1000),'22023');
 }
 await admin(`UPDATE public.bookings SET total_price=100,payment_status='paid'`);
 await reject('paid flag without a ledger is not fabricated into zero paid',collect(1000),'55000');
 await admin(`UPDATE public.bookings SET payment_status='unpaid';DELETE FROM auth.users WHERE id='${actor}'`);
 await reject('deleted Auth identity',collect(1000),'42501');
 await admin(`INSERT INTO auth.users VALUES('${actor}');
 CREATE FUNCTION public.fixture_failure() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN RAISE EXCEPTION 'failure' USING ERRCODE='P0001';END;$$;
 CREATE TRIGGER failure BEFORE INSERT ON public.shift_payments FOR EACH ROW EXECUTE FUNCTION public.fixture_failure();`);
 await reject('late ledger failure rolls back aggregate and receipt',collect(4000),'P0001');
 await admin('DROP TRIGGER failure ON public.shift_payments');
 const first=collect(4000);
 await check('partial cash preserves completed session and exposes canonical due',async()=>{
  await asActor();const r=(await db.query(first.sql,first.args)).rows[0].receipt;
  assert.equal(r.paid_minor,4000);assert.equal(r.due_minor,6000);assert.equal(r.payment_status,'partial');
  const s=await state();assert.equal(s.bookings[0].status,'completed');assert.equal(s.payments[0].amount,40);
  assert.equal(s.payments[0].commission,6);assert.equal(s.shift_payments.length,1);assert.equal(s.context,0);
 });
 await check('lost-response retry after shift closes never collects twice',async()=>{
  await admin(`UPDATE public.shifts SET status='closed',closed_at=now()`);const before=await state();await asActor();
  const r=(await db.query(first.sql,first.args)).rows[0].receipt;assert.equal(r.replayed,true);assert.deepEqual(await state(),before);
 });
 await reject('same operation changed amount',collect(4001,first.args[3]),'22023');
 await reject('other actor cannot claim a receipt',first,'22023',outsider);
 await reject('new operation after shift closes',collect(1000),'55000');
 await admin(`UPDATE public.shifts SET status='open',closed_at=NULL;UPDATE public.profiles SET is_banned=true WHERE id='${actor}'`);
 await reject('banned account cannot replay receipt',first,'42501');
 await admin(`UPDATE public.profiles SET is_banned=false WHERE id='${actor}'`);
 await check('second collection increments aggregate and only the new cash ledger amount',async()=>{
  await asActor();const request=collect(6000);const r=(await db.query(request.sql,request.args)).rows[0].receipt;
  assert.equal(r.paid_minor,10000);assert.equal(r.due_minor,0);assert.equal(r.payment_status,'paid');
  const s=await state();assert.equal(s.payments.length,1);assert.equal(s.payments[0].amount,100);
  assert.equal(s.shift_payments.reduce((sum,p)=>sum+Number(p.amount),0),100);
 });
 await reject('paid booking rejects another cash operation',collect(1),'22023');
 await check('legacy aggregate overwrite cannot bypass the canonical cash ledger',async()=>{
  await db.exec('RESET ROLE');await assert.rejects(db.query(`UPDATE public.payments SET amount=200 WHERE booking_id='${booking}'`),e=>e.code==='55000');
 });
 await asActor();await check('private receipts are inaccessible to clients',async()=>{
  await assert.rejects(db.query('SELECT * FROM private.cash_collection_receipts'),e=>e.code==='42501');
 });
 await check('private financial implementation is inaccessible',async()=>{
  await assert.rejects(db.query(`SELECT private.apply_partial_cash_collection('${booking}','${shift}',1)`),e=>e.code==='42501');
 });
 await db.exec('RESET ROLE;SET ROLE anon;');await check('anonymous execute grant absent',async()=>{
  const r=collect(1);await assert.rejects(db.query(r.sql,r.args),e=>e.code==='42501');
 });
 if(db.connect) {
  async function newBooking() {
   const id=randomUUID();await admin(`INSERT INTO public.bookings(id,user_id,lounge_id,status,total_price)
     VALUES('${id}','${customer}','${lounge}','completed',100)`);return id;
  }
  await check('simultaneous same operation collects exactly once',async()=>{
   const id=await newBooking(),req=collect(4000,randomUUID(),id);
   const [first,second]=await lockedRace(db,req,req,actor);
   assert.equal(first.rows[0].receipt.replayed,false);assert.equal(second.error,undefined);
   assert.equal(second.value.rows[0].receipt.replayed,true);
   const count=(await db.query('SELECT count(*) AS n,sum(amount) AS amount FROM public.shift_payments WHERE booking_id=$1',[id])).rows[0];
   assert.equal(Number(count.n),1);assert.equal(Number(count.amount),40);
  });
  await check('competing different operations cannot overcollect the remaining balance',async()=>{
   const id=await newBooking();const [first,second]=await lockedRace(db,collect(6000,randomUUID(),id),collect(6000,randomUUID(),id),actor);
   assert.equal(first.rows[0].receipt.paid_minor,6000);assert.equal(second.error?.code,'22023');
   assert.equal(Number((await db.query('SELECT amount FROM public.payments WHERE booking_id=$1',[id])).rows[0].amount),60);
   assert.equal(Number((await db.query('SELECT count(*) AS n FROM private.cash_collection_receipts WHERE booking_id=$1',[id])).rows[0].n),1);
  });
  await check('shift closing first makes blocked collection recheck closed status',async()=>{
   const id=await newBooking();const [,second]=await lockedRace(db,
    {sql:'UPDATE public.shifts SET status=$1,closed_at=now() WHERE id=$2',args:['closed',shift]},
    collect(1000,randomUUID(),id),actor,true);
   assert.equal(second.error?.code,'55000');
   assert.equal(Number((await db.query('SELECT count(*) AS n FROM public.payments WHERE booking_id=$1',[id])).rows[0].n),0);
   await admin(`UPDATE public.shifts SET status='open',closed_at=NULL`);
  });
  await check('same operation id for two bookings cannot be reused concurrently',async()=>{
   const a=await newBooking(),b=await newBooking(),operation=randomUUID();
   const [,second]=await lockedRace(db,collect(1000,operation,a),collect(1000,operation,b),actor);
   assert.equal(second.error?.code,'22023');
   assert.equal(Number((await db.query('SELECT count(*) AS n FROM public.payments WHERE booking_id=$1',[b])).rows[0].n),0);
  });
 }
 console.log(JSON.stringify({passed,limitations:['Synthetic schema and Auth claims','Hosted audit trigger not reproduced','Not yet the offline apply endpoint','No deployed SQL or client integration']}));
} finally {await db.close();}
