import {fixedSessionFixture} from './runtime/fixed_session_fixture.mjs';
import {readFile} from 'node:fs/promises';
import {randomUUID} from 'node:crypto';
import assert from 'node:assert/strict';
const f=await fixedSessionFixture();
const {db,admin,lounge,room,actor,customer,shift}=f;
const read=path=>readFile(new URL(path,import.meta.url),'utf8');
let passed=0;
async function check(name,body){await f.reset();await admin(`DELETE FROM public.booking_holds;UPDATE public.lounges SET allow_future_bookings=true,allow_request_without_shift=true,future_booking_max_days_advance=14;INSERT INTO private.cashier_permit_generations
 SELECT permit_id,writer_generation FROM private.cashier_writer_authorities WHERE lounge_id='${lounge}' ON CONFLICT DO NOTHING`);await body();passed++;console.log('PASS '+name);}
async function horizon(){await admin('');return Number((await db.query(`SELECT extract(epoch FROM greatest(w.permit_expires_at,max(p.expires_at)))*1000 AS ms
  FROM private.cashier_writer_authorities w JOIN private.cashier_writer_permits p ON p.lounge_id=w.lounge_id
  JOIN private.cashier_permit_generations g ON g.permit_id=p.permit_id AND g.writer_generation=w.writer_generation
  WHERE w.lounge_id=$1 GROUP BY w.permit_expires_at`,[lounge])).rows[0].ms);}
async function hold(from,to=from+3600000,user=customer){await admin(`SET test.actor='${user}';SET ROLE authenticated`);
  return (await db.query(`SELECT acquire_booking_hold(ARRAY[$1]::uuid[],
    to_timestamp($2::double precision/1000) AT TIME ZONE 'Africa/Cairo',
    to_timestamp($3::double precision/1000) AT TIME ZONE 'Africa/Cairo') r`,[room,from,to])).rows[0].r;}
try{
  await admin(`ALTER TABLE public.lounges ADD opening_time time,ADD closing_time time,ADD contact_phone text,
    ADD allow_future_bookings boolean DEFAULT true,ADD allow_request_without_shift boolean DEFAULT true,
    ADD future_booking_max_days_advance integer DEFAULT 14;
    ALTER TABLE public.bookings ADD confirmation_status text DEFAULT 'confirmed';
    ALTER TABLE public.rooms ADD pricing_model text DEFAULT 'single_multi_hour';`);
  await db.exec(await read('../migrations/20260927000010_real_booking_holds.sql'));
  await db.exec(await read('../migrations/20261004151006_cashier_writer_generation_handover.sql'));
  await db.exec(await read('./fixtures/hosted_booking_hold_contract.sql'));
  await db.exec(await read('../migrations/20261004154405_offline_booking_hold_guard.sql'));
  await db.exec(await read('../migrations/20261009000001_booking_hold_occupied_room_capacity.sql'));
  await db.exec(await read('../migrations/20261011072728_future_booking_offline_coverage_boundary.sql'));
  await check('offline heartbeat does not block a future hold beyond every replayable permit',async()=>{
    const start=Math.ceil((await horizon())/60000)*60000+3600000;
    assert.equal((await hold(start)).success,true);
  });
  await check('near-term interval still cannot compete with the offline device',async()=>{
    const start=Math.ceil(Date.now()/60000)*60000+3600000;
    await assert.rejects(hold(start),e=>e.code==='55000'&&e.message==='LOUNGE_OFFLINE');
  });
  await check('final booking uses the same coverage boundary as its hold',async()=>{
    const start=Math.ceil((await horizon())/60000)*60000+3600000;
    assert.equal((await hold(start,start+3600000,actor)).success,true);
    await admin(`SET test.actor='${actor}';UPDATE public.lounges SET require_prepaid_first_time=false`);
    await db.query(`INSERT INTO bookings(id,user_id,lounge_id,room_id,date,start_time,end_time,status,total_price,shift_id)
      VALUES($1,$6,$2,$3,(to_timestamp($4::double precision/1000) AT TIME ZONE 'Africa/Cairo')::date,
      (to_timestamp($4::double precision/1000) AT TIME ZONE 'Africa/Cairo')::time,
      (to_timestamp(($4::double precision+3600000)/1000) AT TIME ZONE 'Africa/Cairo')::time,'upcoming',100,$5)`,
      [randomUUID(),lounge,room,start,shift,actor]);
    assert.equal((await db.query('SELECT * FROM bookings')).rows.length,1);
  });
  await check('offline journal cannot reserve beyond its issued coverage or alter money on rejection',async()=>{
    const op=f.operation();const start=Math.ceil((await horizon())/60000)*60000+3600000;
    op.payload.start_ms=start;op.payload.end_ms=start+3600000;
    op.quoted_session.start_ms=start;op.quoted_session.end_ms=start+3600000;
    const before=await f.snapshot();const r=await f.send(op);
    assert.equal(r.status,'conflict');assert.equal(r.code,'OFFLINE_BOOKING_OUTSIDE_PERMIT_COVERAGE');
    assert.deepEqual(await f.snapshot(),before);
  });
  await check('valid offline operations remain replayable within their original permit',async()=>{
    const op=f.operation();assert.equal((await f.send(op)).status,'applied');
    assert.equal((await f.send(op)).status,'replayed');
  });
  await check('a longer historical permit in the current generation still protects its future interval',async()=>{
    const oldHorizon=await horizon(),permit=randomUUID();
    await admin('');await db.query(`INSERT INTO private.cashier_writer_permits(permit_id,lounge_id,actor_id,device_id,issued_at,expires_at,permissions)
      SELECT $1,lounge_id,actor_id,device_id,to_timestamp($2::double precision/1000)-interval '22 hours',
        to_timestamp($2::double precision/1000)+interval '2 hours','{"bookings.manage":true,"sessions_control":true,"billing_checkout":true}'::jsonb FROM private.cashier_writer_authorities WHERE lounge_id=$3`,[permit,oldHorizon,lounge]);
    await db.query(`INSERT INTO private.cashier_permit_generations SELECT $1,writer_generation
      FROM private.cashier_writer_authorities WHERE lounge_id=$2 ON CONFLICT DO NOTHING`,[permit,lounge]);
    await assert.rejects(hold(Math.ceil(oldHorizon/60000)*60000+3600000),e=>e.code==='55000');
    assert.equal((await hold(Math.ceil(oldHorizon/60000)*60000+3*3600000)).success,true);
  });
  await check('an exact adjacent boundary is allowed and time-zone settings cannot shift it',async()=>{
    await admin(`SET timezone='America/Los_Angeles'`);
    const result=(await db.query(`SELECT private.online_booking_outside_offline_coverage($1,
      (greatest(w.permit_expires_at,(SELECT max(p.expires_at) FROM private.cashier_writer_permits p
        JOIN private.cashier_permit_generations g ON g.permit_id=p.permit_id
        WHERE p.lounge_id=w.lounge_id AND g.writer_generation=w.writer_generation)) AT TIME ZONE 'Africa/Cairo')) allowed
      FROM private.cashier_writer_authorities w WHERE w.lounge_id=$1`,[lounge])).rows[0].allowed;
    assert.equal(result,true);
  });
  await check('public status exposes an earliest future date without writer identities',async()=>{
    await admin('SET ROLE anon');
    const status=(await db.query('SELECT get_lounge_operating_status($1) r',[lounge])).rows[0].r;
    assert.equal(status.can_book_online,false);assert.match(status.future_booking_date_from,/^\d{4}-\d{2}-\d{2}$/);
    assert.deepEqual(Object.keys(status).sort(),['can_book_online','contact_phone','future_booking_date_from','status']);
    await admin('UPDATE public.lounges SET allow_future_bookings=false;SET ROLE anon');
    assert.equal((await db.query('SELECT get_lounge_operating_status($1) r',[lounge])).rows[0].r.future_booking_date_from,null);
  });
  await check('inactive lounges never advertise future eligibility',async()=>{
    await admin('UPDATE public.lounges SET is_active=false;SET ROLE anon');
    const status=(await db.query('SELECT get_lounge_operating_status($1) r',[lounge])).rows[0].r;
    assert.equal(status.status,'unavailable');assert.equal(status.future_booking_date_from??null,null);
  });
  console.log(JSON.stringify({passed,environment:'isolated shared online/offline guard and replay contracts'}));
}finally{await db.close();}
