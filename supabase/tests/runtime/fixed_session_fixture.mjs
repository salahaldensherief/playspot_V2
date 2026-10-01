import {createFixtureDatabase} from './database.mjs';
import {readFile} from 'node:fs/promises';
import {randomUUID} from 'node:crypto';

export async function fixedSessionFixture() {
 const db=await createFixtureDatabase();
 const actor=randomUUID(),customer=randomUUID(),lounge=randomUUID(),otherLounge=randomUUID(),device=randomUUID(),
  room=randomUUID(),shift=randomUUID(),otherShift=randomUUID(),booking=randomUUID(),product=randomUUID();
 const start=Math.floor(Date.now()/60000)*60000-120*60000;
 const read=path=>readFile(new URL(path,import.meta.url),'utf8');
 const admin=sql=>db.exec(`RESET ROLE;${sql}`);
 const login=()=>db.exec(`RESET ROLE;SET test.actor='${actor}';SET ROLE authenticated;`);
 try {
  for(const file of ['partial_cash_fixture.sql','offline_order_fixture.sql','offline_fixed_session_fixture.sql',
   'hosted_booking_price_trigger.sql','hosted_fixed_session_contract.sql']) await db.exec(await read('../fixtures/'+file));
  for(const file of ['active_super_admin_boundary.sql','offline_walk_in_customer_policy.sql','partial_cash_collection.sql',
   'cashier_writer_permits.sql','cashier_writer_availability.sql','offline_fixed_session_capacity.sql','offline_fixed_session_reservation.sql',
   'offline_fixed_session_transitions.sql','offline_canteen_reconciliation.sql','offline_cash_reconciliation.sql'])
   await db.exec(await read('../../repairs/'+file));
  await admin(`INSERT INTO auth.users VALUES('${actor}'),('${customer}');
   INSERT INTO public.profiles(id,role,is_active,is_banned) VALUES('${actor}','cashier',true,false),('${customer}','user',true,false);
   INSERT INTO public.lounges(id,is_active,status) VALUES('${lounge}',true,'active'),('${otherLounge}',true,'active');
   INSERT INTO public.shifts VALUES('${shift}','${lounge}','${actor}','${actor}','open',NULL),
    ('${otherShift}','${lounge}','${customer}','${customer}','open',NULL);
   INSERT INTO public.rooms(id,lounge_id,hourly_rate_single,hourly_rate_multi) VALUES('${room}','${lounge}',100,150);
   INSERT INTO public.extras(id,lounge_id,name,price,stock_quantity) VALUES('${product}','${lounge}','Water',15,10);
   INSERT INTO public.fixture_permissions VALUES('${actor}','${lounge}','sessions_control'),
    ('${actor}','${lounge}','bookings.manage'),('${actor}','${lounge}','billing_checkout');`);
  await login();let permit=(await db.query('SELECT public.refresh_cashier_writer($1,$2,false) AS authority',[lounge,device])).rows[0].authority.permit_id;
  async function issuePermit(from=start-3600000,permissions={'bookings.manage':true,sessions_control:true,billing_checkout:true}) {
   permit=randomUUID();await admin(`INSERT INTO private.cashier_writer_permits VALUES('${permit}','${lounge}','${actor}','${device}',
    to_timestamp(${from}/1000.0),to_timestamp(${from+86400000}/1000.0),'${JSON.stringify(permissions)}'::jsonb);
    UPDATE private.cashier_writer_authorities SET permit_id='${permit}',issued_at=to_timestamp(${from}/1000.0),
     permit_expires_at=to_timestamp(${from+86400000}/1000.0) WHERE lounge_id='${lounge}';`);
   return permit;
  }
  async function reset() {await admin(`SET test.actor='${actor}';DELETE FROM private.cashier_operation_receipts;DELETE FROM private.cash_collection_receipts;
   DELETE FROM public.booking_items;DELETE FROM public.canteen_order_items;DELETE FROM public.canteen_orders;
   DELETE FROM public.shift_payments;DELETE FROM public.payments;DELETE FROM public.bookings;DELETE FROM public.tournament_matches;
   UPDATE public.rooms SET lounge_id='${lounge}',hourly_rate_single=100,status='available',is_active=true,is_available=true;
   UPDATE public.extras SET stock_quantity=10,price=15;
   UPDATE public.shifts SET status='open',closed_at=NULL;
   UPDATE public.profiles SET is_active=true,is_banned=false,completed_bookings_count=0,
    role=CASE WHEN id='${actor}' THEN 'cashier' ELSE 'user' END;
   UPDATE public.lounges SET status='active',is_active=true,timezone='Africa/Cairo',allow_cash_payment=true;
   DELETE FROM public.fixture_permissions;
   INSERT INTO public.fixture_permissions VALUES('${actor}','${lounge}','sessions_control'),
    ('${actor}','${lounge}','bookings.manage'),('${actor}','${lounge}','billing_checkout');
   UPDATE private.cashier_writer_authorities SET last_applied_sequence=0,online_requested=false,heartbeat_expires_at=now();`);
   await issuePermit();}
  function operation(kind='reserve',sequence=1,options={}) {
   const op={id:randomUUID(),actor_id:actor,lounge_id:lounge,device_id:device,permit_id:permit,
    booking_id:booking,shift_id:shift,sequence,occurred_at:new Date(start).toISOString(),kind,
    payload:kind==='reserve'?{room_id:room,start_ms:start,end_ms:start+3600000,timezone:'Africa/Cairo',play_mode:'single',customer_name:'Walk-in'}:{},
    quoted_total_minor:10000,...options};
   if(kind==='collectCash') delete op.quoted_total_minor;
   if(['reserve','start','close'].includes(kind)) op.quoted_session={room_id:room,timezone:'Africa/Cairo',
    start_ms:kind==='reserve'?op.payload.start_ms:start,end_ms:kind==='reserve'?op.payload.end_ms:start+3600000,
    started_ms:kind==='reserve'?null:start+60000,paid_minor:0};
   return op;
  }
  const request=op=>({sql:'SELECT public.apply_offline_cashier_operation($1::jsonb) AS receipt',args:[JSON.stringify(op)]});
  async function send(op) {await login();const r=request(op);return (await db.query(r.sql,r.args)).rows[0].receipt;}
  async function snapshot() {await admin('');return (await db.query(`SELECT jsonb_build_object(
   'bookings',(SELECT jsonb_agg(to_jsonb(b) ORDER BY id) FROM public.bookings b),
   'rooms',(SELECT jsonb_agg(to_jsonb(r) ORDER BY id) FROM public.rooms r),
   'payments',(SELECT jsonb_agg(to_jsonb(p) ORDER BY id) FROM public.payments p),
   'cash',(SELECT jsonb_agg(to_jsonb(p) ORDER BY id) FROM public.shift_payments p),
   'sequence',(SELECT last_applied_sequence FROM private.cashier_writer_authorities),
   'contexts',(SELECT count(*) FROM private.cashier_sync_context)+(SELECT count(*) FROM private.cashier_booking_command_context)) AS value`)).rows[0].value;}
  async function seedBooking(id=randomUUID(),status='completed',from=start,to=start+3600000) {
   await admin(`ALTER TABLE public.bookings DISABLE TRIGGER guard_cashier_online_booking;
    INSERT INTO public.bookings(id,user_id,lounge_id,room_id,date,start_time,end_time,status,shift_id,total_price,actual_start_time)
    VALUES('${id}',NULL,'${lounge}','${room}',(to_timestamp(${from}/1000.0) AT TIME ZONE 'Africa/Cairo')::date,
    (to_timestamp(${from}/1000.0) AT TIME ZONE 'Africa/Cairo')::time,(to_timestamp(${to}/1000.0) AT TIME ZONE 'Africa/Cairo')::time,
    '${status}','${shift}',100,to_timestamp(${from}/1000.0));
    ALTER TABLE public.bookings ENABLE TRIGGER guard_cashier_online_booking;`);return id;
  }
  await reset();return {db,actor,customer,lounge,otherLounge,device,room,shift,otherShift,booking,product,start,get permit(){return permit;},
   admin,login,reset,issuePermit,operation,request,send,snapshot,seedBooking};
 } catch(error) {await db.close();throw error;}
}
