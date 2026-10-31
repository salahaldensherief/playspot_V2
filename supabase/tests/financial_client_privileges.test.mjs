import {createFixtureDatabase} from './runtime/database.mjs';
import {readFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
import {randomUUID} from 'node:crypto';

const db=await createFixtureDatabase();
const actor=randomUUID(),customer=randomUUID(),other=randomUUID();
const lounge=randomUUID(),foreign=randomUUID(),booking=randomUUID(),shift=randomUUID();
const read=p=>readFile(new URL(p,import.meta.url),'utf8');
let passed=0;
async function actorAs(id,role='authenticated') {await db.exec(`RESET ROLE;SET test.actor='${id}';SET ROLE ${role};`);}
async function check(name,body) {await body();passed++;console.log('PASS '+name);}
async function admin(sql) {await db.exec(`RESET ROLE;${sql}`);}
async function visible(table,count) {assert.equal(Number((await db.query(`SELECT count(*) AS n FROM public.${table}`)).rows[0].n),count);}
try {
 await db.exec(await read('./fixtures/partial_cash_fixture.sql'));
 await db.exec(`INSERT INTO auth.users VALUES('${actor}'),('${customer}'),('${other}');
 INSERT INTO public.profiles VALUES('${actor}','cashier',true,false),('${customer}','user',true,false),('${other}','cashier',true,false);
 INSERT INTO public.lounges VALUES('${lounge}',true,'active'),('${foreign}',true,'active');
 INSERT INTO public.fixture_permissions VALUES('${actor}','${lounge}','billing_checkout');
 INSERT INTO public.shifts VALUES('${shift}','${lounge}','${actor}','${actor}','open',NULL);
 INSERT INTO public.bookings(id,user_id,lounge_id,status,total_price) VALUES('${booking}','${customer}','${lounge}','completed',100);
 INSERT INTO public.payments(booking_id,user_id,lounge_id,amount,payment_method,status) VALUES('${booking}','${customer}','${lounge}',40,'cash','completed');
 INSERT INTO public.shift_payments(shift_id,lounge_id,booking_id,payment_method,category,amount)
 VALUES('${shift}','${lounge}','${booking}','cash','gaming_time',40);
 GRANT ALL ON public.payments,public.shift_payments TO anon,authenticated;
 GRANT USAGE ON SCHEMA public,auth TO anon,authenticated;
 ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
 ALTER TABLE public.shift_payments ENABLE ROW LEVEL SECURITY;
 CREATE POLICY "Super admin full access on payments" ON public.payments FOR ALL USING(true);
 CREATE POLICY "Users can view own payments" ON public.payments FOR SELECT USING(true);
 CREATE POLICY "Staff view shift payments" ON public.shift_payments FOR SELECT USING(true);
 CREATE POLICY legacy_permissive_reader ON public.payments FOR SELECT USING(true);
 CREATE POLICY legacy_permissive_reader ON public.shift_payments FOR SELECT USING(true);`);
 await db.exec(await read('../repairs/active_super_admin_boundary.sql'));
 await db.exec(await read('../repairs/partial_cash_collection.sql'));
 await db.exec(await read('../repairs/financial_client_privileges.sql'));
 for(const role of ['anon','authenticated']) {
  await actorAs(actor,role);
  for(const table of ['payments','shift_payments']) {
   for(const sql of [`TRUNCATE public.${table}`,`DELETE FROM public.${table}`,`UPDATE public.${table} SET amount=0`,`INSERT INTO public.${table}(amount) VALUES(0)`])
    await check(`${role} denied direct ${sql.split(' ')[0]} on ${table}`,async()=>assert.rejects(db.query(sql),e=>e.code==='42501'));
   for(const privilege of ['TRIGGER','REFERENCES']) await check(`${role} lacks ${privilege} on ${table}`,async()=>{
    assert.equal((await db.query('SELECT has_table_privilege(current_user,$1,$2) AS allowed',[`public.${table}`,privilege])).rows[0].allowed,false);
   });
  }
 }
 await actorAs('', 'anon');await check('anonymous financial reads revoked',async()=>assert.rejects(db.query('SELECT * FROM public.payments'),e=>e.code==='42501'));
 await actorAs(customer);await check('active customer sees their own payment only',async()=>{await visible('payments',1);await visible('shift_payments',0);});
 await actorAs(other);await check('restrictive guard contains leftover permissive read policies',async()=>{await visible('payments',0);await visible('shift_payments',0);});
 await actorAs(actor);await check('cashier with exact billing grant sees venue financials',async()=>{await visible('payments',1);await visible('shift_payments',1);});
 await admin(`UPDATE public.profiles SET is_banned=true WHERE id='${actor}'`);await actorAs(actor);
 await check('banned assigned cashier reads nothing',async()=>{await visible('payments',0);await visible('shift_payments',0);});
 await admin(`UPDATE public.profiles SET is_banned=false,is_active=false WHERE id='${actor}'`);await actorAs(actor);
 await check('inactive assigned cashier reads nothing',async()=>{await visible('payments',0);await visible('shift_payments',0);});
 await admin(`UPDATE public.profiles SET is_active=true,role='super_admin' WHERE id='${actor}'`);await actorAs(actor);
 await check('active canonical super admin sees records',async()=>{await visible('payments',1);await visible('shift_payments',1);});
 await admin(`UPDATE public.profiles SET is_banned=true WHERE id='${actor}'`);await actorAs(actor);
 await check('banned super admin has no ALL-policy bypass',async()=>{await visible('payments',0);await visible('shift_payments',0);});
 await admin(`UPDATE public.profiles SET is_banned=false,role='cashier' WHERE id='${actor}'`);await actorAs(actor);
 await check('authorized RPC still records partial cash after direct writes revoked',async()=>{
  const r=(await db.query('SELECT public.collect_booking_cash_partial($1,$2,1000,$3) AS receipt',[booking,shift,randomUUID()])).rows[0].receipt;
  assert.equal(r.paid_minor,5000);assert.equal(r.due_minor,5000);await visible('shift_payments',2);
 });
 await admin(`DELETE FROM auth.users WHERE id='${actor}'`);await actorAs(actor);
 await check('deleted Auth identity cannot read surviving financial data',async()=>{await visible('payments',0);await visible('shift_payments',0);});
 console.log(JSON.stringify({passed,limitations:['Synthetic Auth/RLS schema','Known hosted policy names; additional deployment policies must be reviewed','No production writes or deployed privilege changes']}));
} finally {await db.close();}
