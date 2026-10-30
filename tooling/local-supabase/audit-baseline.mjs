import {execFileSync} from 'node:child_process';
import {readFile, writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {resolve} from 'node:path';
const [snapshot, financialSource, output] = process.argv.slice(2);
if (!snapshot || !financialSource || !output) throw new Error('Usage: audit-baseline.mjs SNAPSHOT FINANCIAL_SOURCE OUTPUT');
const bytes=await readFile(snapshot), sql=bytes.toString('utf8');
const hash=b=>createHash('sha256').update(b).digest('hex');
const expected='08d6c1d70278da715a5af80bc3a832358d098f9dd72eb1b6c2f56935ed5293ca';
if(hash(bytes)!==expected) throw new Error('Unexpected snapshot; review a new baseline before use');
if(/^COPY\s.+FROM stdin/im.test(sql)) throw new Error('Snapshot unexpectedly contains COPY data');
const schemas=[...sql.matchAll(/^CREATE SCHEMA IF NOT EXISTS "([^"]+)"/gm)].map(m=>m[1]);
if(schemas.some(s=>!['public','private'].includes(s))) throw new Error('Managed schema replacement is not allowed');
const migrations=[
 '20261025101139_atomic_discount_cash_checkout.sql',
 '20261025151217_owner_permission_write_boundary.sql',
 '20261025170000_guard_pre_session_manual_transfer_total.sql',
 '20261025225255_canonical_booking_collections.sql',
 '20261025225913_branch_booking_refund_policy.sql',
 '20261026100000_guard_paid_deposit_payment_quote.sql',
 '20261027150000_manual_refund_reversal_accounting.sql',
 '20261027180000_refund_aware_payout_reconciliation.sql',
];
const candidates=[];
for(const name of migrations){const b=await readFile(resolve(financialSource,'supabase/migrations',name));candidates.push({name,sha256:hash(b),disposition:'review candidate only; not applied'});}
const partialCommit='28184d1aa8821ccc955092ed75970191c4abf9af';
const partialName='20261025000001_open_time_partial_payment_status.sql';
const partial=execFileSync('git',['-C',financialSource,'show',`${partialCommit}:supabase/migrations/${partialName}`]);
candidates.push({name:partialName,sourceCommit:partialCommit,sha256:hash(partial),disposition:'separate unmerged Open Time candidate; review dependency/order before any Open Time journey'});
const requiredSnapshotRoles=[...new Set([
 ...sql.matchAll(/OWNER TO "([^"]+)"/g),
 ...sql.matchAll(/TO "(anon|authenticated|service_role|supabase_[^"]+|authenticator|postgres)"/g),
].map(m=>m[1]))].sort();
const result={requiredSnapshotRoles,snapshot:{sha256:hash(bytes),bytes:bytes.length,schemas,
 functions:[...sql.matchAll(/^CREATE OR REPLACE FUNCTION /gm)].length,
 triggers:[...sql.matchAll(/^CREATE (?:OR REPLACE )?TRIGGER /gm)].length,
 policies:[...sql.matchAll(/^CREATE POLICY /gm)].length,
 grants:[...sql.matchAll(/^GRANT /gm)].length,
 outboundHttpCallSites:[...sql.matchAll(/\bnet\.http_post\s*\(/g)].length,
 authUserTriggerIncluded:/CREATE (?:OR REPLACE )?TRIGGER[^;]+ON "auth"\."users"/s.test(sql),
 canonicalAtomicAlreadyPresent:sql.includes('"checkout_booking_cash_atomic"'),
 movementTableAlreadyPresent:sql.includes('CREATE TABLE "private"."booking_money_movements"')},
 requiredManagedObjects:['auth.users','auth.uid()','auth.jwt()','anon','authenticated','service_role','supabase_auth_admin','extensions','vault.decrypted_secrets','net.http_post'],
 restorationGate:'BLOCKED until fresh managed catalog, extensions, trigger egress overrides and reviewed ACL comparison are verified; no SQL executed',
 candidates,appliedMigrations:[],authenticatedJourney:'NOT EXECUTED'};
await writeFile(output,JSON.stringify(result,null,2)+'\n');
console.log(JSON.stringify({audit:'passed; offline only',snapshotSha256:hash(bytes),candidates:candidates.length,applied:0}));
