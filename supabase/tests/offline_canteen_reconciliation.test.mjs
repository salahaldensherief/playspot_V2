import {createFixtureDatabase} from './runtime/database.mjs';
import {lockedRace} from './runtime/locked_race.mjs';
import {readFile,writeFile} from 'node:fs/promises';
import {randomUUID} from 'node:crypto';
import assert from 'node:assert/strict';

const db=await createFixtureDatabase();
const actor=randomUUID(),customer=randomUUID(),lounge=randomUUID(),otherLounge=randomUUID(),device=randomUUID(),
 shift=randomUUID(),otherShift=randomUUID(),booking=randomUUID(),room=randomUUID(),product=randomUUID(),secondProduct=randomUUID();
let permit,passed=0;
const read=path=>readFile(new URL(path,import.meta.url),'utf8');
const admin=sql=>db.exec(`RESET ROLE;${sql}`);
const login=()=>db.exec(`RESET ROLE;SET test.actor='${actor}';SET ROLE authenticated;`);
const line=(id=product,quantity=2,price=1500)=>({product_id:id,quantity,unit_price_minor:price});
function operation(lines=[line()],total=13000) {return {id:randomUUID(),actor_id:actor,lounge_id:lounge,device_id:device,
 permit_id:permit,booking_id:booking,shift_id:shift,sequence:1,occurred_at:new Date().toISOString(),kind:'addItems',
 payload:{items:lines.map(({product_id,quantity})=>({product_id,quantity})),note:'offline order'},quoted_items:lines,quoted_total_minor:total};}
const request=op=>({sql:'SELECT public.apply_offline_cashier_operation($1::jsonb) AS receipt',args:[JSON.stringify(op)]});
async function send(op) {await login();const r=request(op);return (await db.query(r.sql,r.args)).rows[0].receipt;}
async function snapshot() {await admin('');return (await db.query(`SELECT jsonb_build_object(
 'orders',(SELECT jsonb_agg(to_jsonb(p) ORDER BY id) FROM public.canteen_orders p),
 'lines',(SELECT jsonb_agg(to_jsonb(p) ORDER BY id) FROM public.canteen_order_items p),
 'booking_items',(SELECT jsonb_agg(to_jsonb(p) ORDER BY id) FROM public.booking_items p),
 'bookings',(SELECT jsonb_agg(to_jsonb(p) ORDER BY id) FROM public.bookings p),
 'stock',(SELECT jsonb_agg(to_jsonb(p) ORDER BY id) FROM public.extras p),
 'payments',(SELECT jsonb_agg(to_jsonb(p) ORDER BY id) FROM public.payments p),
 'cash',(SELECT jsonb_agg(to_jsonb(p) ORDER BY id) FROM public.shift_payments p),
 'sequence',(SELECT last_applied_sequence FROM private.cashier_writer_authorities)) AS value`)).rows[0].value;}
async function reset() {await admin(`ALTER TABLE public.bookings DISABLE TRIGGER guard_cashier_online_booking;
 DELETE FROM private.cashier_operation_receipts;DELETE FROM private.cash_collection_receipts;
 DELETE FROM public.booking_items;DELETE FROM public.canteen_order_items;DELETE FROM public.canteen_orders;
 DELETE FROM public.shift_payments;DELETE FROM public.payments;
 UPDATE public.rooms SET hourly_rate_single=100 WHERE id='${room}';
 UPDATE public.bookings SET status='in_progress',is_open_time=false,shift_id='${shift}',total_price=100,
 addons_price=0,addons_total=0,payment_status='unpaid',discount_amount=0,discount_percentage=0;
 UPDATE public.extras SET lounge_id='${lounge}',price=15,is_active=true,is_available=true,track_stock=true,stock_quantity=4;
 UPDATE public.profiles SET is_active=true,is_banned=false;
 UPDATE public.shifts SET status='open',closed_at=NULL;
 UPDATE public.lounges SET is_active=true,status='active';
 DELETE FROM public.fixture_permissions WHERE permission='billing_checkout';
 INSERT INTO public.fixture_permissions SELECT '${actor}','${lounge}','sessions_control'
 WHERE NOT EXISTS(SELECT 1 FROM public.fixture_permissions WHERE permission='sessions_control');
 UPDATE private.cashier_writer_authorities SET last_applied_sequence=0;
 ALTER TABLE public.bookings ENABLE TRIGGER guard_cashier_online_booking;`);}
async function check(name,body) {await reset();await body();passed++;console.log('PASS '+name);}
async function conflict(op,code) {const before=await snapshot();const r=await send(op);assert.equal(r.status,'conflict');
 assert.equal(r.code,code);assert.deepEqual(await snapshot(),before);return r;}
try {
 await db.exec(await read('./fixtures/partial_cash_fixture.sql'));
 await db.exec(await read('./fixtures/offline_order_fixture.sql'));
 await db.exec(await read('./fixtures/hosted_booking_price_trigger.sql'));
 await admin(`INSERT INTO auth.users VALUES('${actor}'),('${customer}');
 INSERT INTO public.profiles VALUES('${actor}','cashier',true,false);
 INSERT INTO public.lounges(id,is_active,status) VALUES('${lounge}',true,'active'),('${otherLounge}',true,'active');
 INSERT INTO public.fixture_permissions VALUES('${actor}','${lounge}','sessions_control');
 INSERT INTO public.shifts VALUES('${shift}','${lounge}','${actor}','${actor}','open',NULL),
 ('${otherShift}','${lounge}','${customer}','${customer}','open',NULL);
 INSERT INTO public.rooms(id,lounge_id,hourly_rate_single) VALUES('${room}','${lounge}',100);
 INSERT INTO public.bookings(id,user_id,lounge_id,status,room_id,shift_id,total_price)
 VALUES('${booking}','${customer}','${lounge}','in_progress','${room}','${shift}',100);
 INSERT INTO public.extras(id,lounge_id,name,price,stock_quantity) VALUES
 ('${product}','${lounge}','Water',15,4),('${secondProduct}','${lounge}','Snack',15,4);`);
 for(const file of ['active_super_admin_boundary.sql','partial_cash_collection.sql','cashier_writer_permits.sql','cashier_writer_availability.sql',
  'offline_canteen_reconciliation.sql','offline_cash_reconciliation.sql']) await db.exec(await read('../repairs/'+file));
 await login();permit=(await db.query('SELECT public.refresh_cashier_writer($1,$2,false) AS authority',[lounge,device])).rows[0].authority.permit_id;
 await check('session permission can add canonically priced items without billing permission or implicit cash',async()=>{
  const op=operation(),r=await send(op);assert.equal(r.status,'applied');assert.equal(r.order_receipt.total_minor,13000);
  if(process.env.PLAYSPOT_ORDER_CONTRACT_EXPORT) await writeFile(process.env.PLAYSPOT_ORDER_CONTRACT_EXPORT,
   JSON.stringify({operation:op,response:r},null,2)+'\n','utf8');
  assert.equal(r.order_receipt.due_minor,13000);assert.equal(r.order_receipt.order_id,op.id);
  const s=await snapshot();assert.equal(s.orders.length,1);assert.equal(s.lines.length,1);assert.equal(s.booking_items.length,1);
  assert.equal(s.stock.find(x=>x.id===product).stock_quantity,2);assert.equal(s.cash,null);assert.equal(s.payments,null);
  assert.equal(s.bookings[0].addons_total,30);assert.equal(s.sequence,1);
 });
 await check('lost response retry keeps one order and stock deduction',async()=>{
  const op=operation();await send(op);const before=await snapshot();assert.equal((await send(op)).status,'replayed');assert.deepEqual(await snapshot(),before);
 });
 await check('changed quote under same operation id cannot replay',async()=>{
  const op=operation();await send(op);const before=await snapshot();await assert.rejects(send({...op,quoted_total_minor:13001}),e=>e.code==='22023');
  assert.deepEqual(await snapshot(),before);
 });
 await check('product price drift retains conflict and rolls back stock',async()=>{
  await admin(`UPDATE public.extras SET price=16 WHERE id='${product}'`);await conflict(operation(),'OFFLINE_PRODUCT_PRICE_CHANGED');
 });
 await check('forged client total cannot reduce balance',async()=>await conflict(operation([line()],10000),'OFFLINE_BOOKING_PRICE_CHANGED'));
 await check('trigger repricing the room rolls back header, lines and inventory',async()=>{
  await admin(`UPDATE public.rooms SET hourly_rate_single=120 WHERE id='${room}'`);await conflict(operation(),'OFFLINE_BOOKING_PRICE_CHANGED');
 });
 for(const field of ['is_active','is_available']) await check('disabled product '+field,async()=>{
  await admin(`UPDATE public.extras SET ${field}=false WHERE id='${product}'`);await conflict(operation(),'OFFLINE_PRODUCT_UNAVAILABLE');
 });
 await check('foreign venue product cannot consume stock',async()=>{
  await admin(`UPDATE public.extras SET lounge_id='${otherLounge}' WHERE id='${product}'`);await conflict(operation(),'OFFLINE_PRODUCT_UNAVAILABLE');
 });
 await check('missing product fails without financial changes',async()=>await conflict(operation([line(randomUUID())]),'OFFLINE_PRODUCT_UNAVAILABLE'));
 await check('tracked shortage is atomic',async()=>{
  await admin(`UPDATE public.extras SET stock_quantity=1 WHERE id='${product}'`);await conflict(operation(),'OFFLINE_INSUFFICIENT_STOCK');
 });
 await check('duplicate product lines share aggregate stock limit',async()=>await conflict(operation([line(product,3),line(product,2)],17500),'OFFLINE_INSUFFICIENT_STOCK'));
 await check('duplicate lines with sufficient aggregate stock keep both canonical lines',async()=>{
  assert.equal((await send(operation([line(product,1),line(product,2)],14500))).status,'applied');
  const s=await snapshot();assert.equal(s.lines.length,2);assert.equal(s.stock.find(x=>x.id===product).stock_quantity,1);
 });
 await check('untracked zero inventory is preserved',async()=>{
  await admin(`UPDATE public.extras SET track_stock=false,stock_quantity=0 WHERE id='${product}'`);
  assert.equal((await send(operation())).status,'applied');assert.equal((await snapshot()).stock.find(x=>x.id===product).stock_quantity,0);
 });
 for(const quantity of [0,-1,1.5,101,'2',null]) await check('invalid quantity '+quantity,async()=>{
  await conflict(operation([line(product,quantity)]),'INVALID_OFFLINE_ORDER');
 });
 await check('missing quote never silently reprices',async()=>{const op=operation();delete op.quoted_items;await conflict(op,'INVALID_OFFLINE_ORDER');});
 await check('quote must describe actual requested items',async()=>{
  const op=operation();op.quoted_items=[line(secondProduct)];await conflict(op,'INVALID_OFFLINE_ORDER');
 });
 await check('quote total must be integer JSON number',async()=>await conflict(operation([line()],'13000'),'INVALID_OFFLINE_ORDER'));
 await check('closed session rejects new orders',async()=>{
  await admin(`UPDATE public.bookings SET status='completed'`);await conflict(operation(),'OFFLINE_ORDER_REQUIRES_FIXED_ACTIVE_SESSION');
 });
 await check('open-time unsettled price is explicitly unsupported',async()=>{
  await admin(`UPDATE public.bookings SET is_open_time=true`);await conflict(operation(),'OFFLINE_ORDER_REQUIRES_FIXED_ACTIVE_SESSION');
 });
 await check('own open shift must match session shift',async()=>await conflict({...operation(),shift_id:otherShift},'OWN_OPEN_SHIFT_REQUIRED'));
 await check('closed shift retains order for review',async()=>{
  await admin(`UPDATE public.shifts SET status='closed',closed_at=now() WHERE id='${shift}'`);await conflict(operation(),'OWN_OPEN_SHIFT_REQUIRED');
 });
 await check('revoked session permission blocks request without receipt or data writes',async()=>{
  await admin(`DELETE FROM public.fixture_permissions WHERE permission='sessions_control';
   INSERT INTO public.fixture_permissions VALUES('${actor}','${lounge}','billing_checkout')`);
  const before=await snapshot();await assert.rejects(send(operation()),e=>e.code==='42501');assert.deepEqual(await snapshot(),before);
 });
 await check('partial cash remains intact and order increases remaining balance',async()=>{
  await admin(`INSERT INTO public.fixture_permissions VALUES('${actor}','${lounge}','billing_checkout')`);await login();
  await db.query('SELECT public.collect_booking_cash_partial($1,$2,5000,$3)',[booking,shift,randomUUID()]);
  const r=await send(operation());assert.equal(r.order_receipt.paid_minor,5000);assert.equal(r.order_receipt.due_minor,8000);
  assert.equal(r.order_receipt.payment_status,'partial');const s=await snapshot();assert.equal(s.payments[0].amount,50);assert.equal(s.cash.length,1);
 });
 await check('fully paid session becomes partial when an unpaid order is added',async()=>{
  await admin(`INSERT INTO public.fixture_permissions VALUES('${actor}','${lounge}','billing_checkout')`);await login();
  await db.query('SELECT public.collect_booking_cash_partial($1,$2,10000,$3)',[booking,shift,randomUUID()]);
  const r=await send(operation());assert.equal(r.order_receipt.payment_status,'partial');assert.equal(r.order_receipt.due_minor,3000);
 });
 await check('cash ledger mismatch blocks adding debt to corrupted payment state',async()=>{
  await admin(`INSERT INTO public.payments(booking_id,lounge_id,amount,payment_method,status) VALUES('${booking}','${lounge}',50,'cash','completed')`);
  await conflict(operation(),'PAYMENT_REQUIRES_RECONCILIATION');
 });
 await check('failure in second line rolls back first stock and header',async()=>{
  await admin(`CREATE FUNCTION public.fail_second_line() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN
   IF NEW.extra_id='${secondProduct}' THEN RAISE EXCEPTION 'INJECTED_LINE_FAILURE' USING ERRCODE='55000';END IF;RETURN NEW;END;$$;
   CREATE TRIGGER fail_line BEFORE INSERT ON public.canteen_order_items FOR EACH ROW EXECUTE FUNCTION public.fail_second_line();`);
  try {await conflict(operation([line(product,1),line(secondProduct,1)]),'INJECTED_LINE_FAILURE');}
  finally {await admin('DROP TRIGGER fail_line ON public.canteen_order_items;DROP FUNCTION public.fail_second_line();');}
 });
 if(db.connect) {
  await check('simultaneous retry demonstrably waits and deducts inventory once',async()=>{
   const op=operation();await admin('');const [a,b]=await lockedRace(db,request(op),request(op),actor);
   assert.equal(a.rows[0].receipt.status,'applied');assert.equal(b.error,undefined);assert.equal(b.value.rows[0].receipt.status,'replayed');
   const s=await snapshot();assert.equal(s.orders.length,1);assert.equal(s.stock.find(x=>x.id===product).stock_quantity,2);
  });
  await check('competing stock sale commits before waiting order, then order retains shortage conflict',async()=>{
   const before=await snapshot();const [,b]=await lockedRace(db,
    {sql:'UPDATE public.extras SET stock_quantity=1 WHERE id=$1',args:[product]},request(operation()),actor,true);
   assert.equal(b.error,undefined);assert.equal(b.value.rows[0].receipt.code,'OFFLINE_INSUFFICIENT_STOCK');
   const after=await snapshot();assert.equal(after.orders,null);assert.equal(after.bookings[0].total_price,before.bookings[0].total_price);
  });
 }
 console.log(JSON.stringify({passed,limitations:['Source-only item fixture; fixed lifecycle has a separate integrated suite',
  'Minimal fixture reproduces actual hosted price trigger, not every production RLS/audit/notification trigger',
  'No combo/open-time/discount repricing or conflict resolution UI enablement']}));
} finally {await db.close();}
