import {fixedSessionFixture} from './runtime/fixed_session_fixture.mjs';
import {readFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
const f=await fixedSessionFixture();
const {db,admin,login,reset,seedBooking,actor,room}=f;
const read=p=>readFile(new URL(p,import.meta.url),'utf8');
let passed=0;
async function fixture(method='cash',payment='unpaid',status='upcoming') {
  await reset();
  await admin('UPDATE public.lounges SET require_prepaid_first_time=false');
  const id=await seedBooking(undefined,status);
  await admin(`UPDATE public.bookings SET payment_method='${method}',payment_status='${payment}',
    sender_wallet_phone='01000000000',actual_start_time=NULL`);
  await login();
  // This disposable fixture starts in offline-writer mode. Exercise the real
  // online authority path rather than disabling its booking guard.
  await db.query('SELECT public.refresh_cashier_writer($1,$2,true)',[f.lounge,f.device]);
  return id;
}
async function start(id){return (await db.query('SELECT public.start_booking_session($1) value',[id])).rows[0].value;}
async function check(name,body){await body();passed++;console.log('PASS '+name);}
try {
  await admin(`ALTER TABLE public.shifts ADD opened_at timestamptz DEFAULT now();
    ALTER TABLE public.rooms ADD name_ar text,ADD name_en text;`);
  await db.exec(await read('../../docs/audits/playspot-launch-v2/evidence/start_booking_session.sql'));
  const booking=await fixture();
  await assert.rejects(start(booking),e=>e.code==='55000'&&e.message.includes('PAYMENT_REQUIRED'));
  console.log(JSON.stringify({finding:'PS-002',result:'DEPLOYMENT MISMATCH REPRODUCED in isolated fixture',cash:'unpaid',expectedClientAction:'start without collection',observed:'PAYMENT_REQUIRED_BEFORE_SESSION_START'}));
} finally {await db.close();}
