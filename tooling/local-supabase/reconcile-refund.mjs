// Independent local ledger reads after the authenticated refund journey.
import {readFile, writeFile} from 'node:fs/promises';
import {createRequire} from 'node:module';
import assert from 'node:assert/strict';
const require=createRequire(new URL('../../supabase/tests/runtime/package.json',import.meta.url));
const {Client}=require('pg');
const [directory,report]=process.argv.slice(2);
const load=async name=>JSON.parse(await readFile(directory+'/'+name,'utf8'));
const status=await load('status.json'),state=await load('refund-state.json');
assert.equal(status.API_URL,'http://127.0.0.1:56621');
const url=new URL(status.DB_URL);
assert.equal(url.hostname,'127.0.0.1');assert.equal(url.port,'56622');
const client=new Client({connectionString:status.DB_URL});
await client.connect();
try {
 await client.query('BEGIN READ ONLY');
 const booking=state.receipt.booking_id;
 const row=(await client.query(`SELECT
   (SELECT amount*100 FROM public.payments WHERE booking_id=$1) AS payment_minor,
   (SELECT sum(amount_minor) FROM private.booking_money_movements WHERE booking_id=$1) AS movement_minor,
   (SELECT sum(commission_minor) FROM private.booking_money_movements WHERE booking_id=$1) AS commission_minor,
   (SELECT sum(net_to_lounge_minor) FROM private.booking_money_movements WHERE booking_id=$1) AS net_minor,
   (SELECT count(*) FROM private.booking_money_movements WHERE booking_id=$1 AND amount_minor<0) AS refunds,
   (SELECT sum(amount)*100 FROM public.shift_payments WHERE booking_id=$1) AS drawer_in_minor,
   (SELECT sum(e.amount)*100 FROM public.shift_expenses e JOIN private.booking_refund_requests r ON r.shift_expense_id=e.id WHERE r.booking_id=$1) AS drawer_out_minor,
   (SELECT count(*) FROM private.booking_refund_requests WHERE booking_id=$1 AND status='completed') AS completed_requests,
   (SELECT count(*) FROM public.audit_events WHERE booking_id=$1 AND payload->>'stage' IN ('initiated','completed')) AS audit_events,
   (SELECT count(*) FROM public.audit_events WHERE booking_id=$1 AND lounge_id IS NULL) AS missing_audit_scope,
   (SELECT count(*) FROM private.cash_collection_receipts WHERE booking_id=$1) AS collection_receipts`,[booking])).rows[0];
 const actual=Object.fromEntries(Object.entries(row).map(([key,value])=>[key,Number(value)]));
 assert.deepEqual(actual,{payment_minor:8000,movement_minor:8000,commission_minor:1200,net_minor:6800,
   refunds:1,drawer_in_minor:10000,drawer_out_minor:2000,completed_requests:1,audit_events:2,
   missing_audit_scope:0,collection_receipts:1});
 assert.equal(actual.drawer_in_minor-actual.drawer_out_minor,actual.movement_minor);
 assert.equal(actual.commission_minor+actual.net_minor,actual.movement_minor);
 await client.query('COMMIT');
 await writeFile(report,JSON.stringify({environment:status.API_URL,booking,actual,
   result:'Independent read-only payment/movement/commission/drawer/receipt/audit reconciliation passed',
   limitation:'Synthetic local return attestation; no external money, hosted compatibility or browser UI acceptance'},null,2));
 console.log('Independent refund ledger, commission, drawer, receipt and audit reconciliation passed.');
} finally {await client.end();}
