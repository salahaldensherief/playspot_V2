import {fixedSessionFixture} from './runtime/fixed_session_fixture.mjs';
import {readFile} from 'node:fs/promises';
import {randomUUID} from 'node:crypto';
import assert from 'node:assert/strict';

const f = await fixedSessionFixture();
const {db, actor, lounge, otherLounge, admin, login, operation, send} = f;
const manager = randomUUID();
let passed = 0;
async function check(name, body) {
  await body(); passed++; console.log('PASS ' + name);
}
async function reviewer(who = manager) {
  await admin(`SET test.actor='${who}'; SET ROLE authenticated;`);
}
const approve = (op, review, reason = 'Reviewed room availability and original quoted terms') =>
  db.query('SELECT public.approve_cashier_conflict_retry($1,$2,$3,$4) AS result', [lounge, op.id, review, reason]);
const denied = (action, code = '42501') => assert.rejects(action, e => e.code === code);
try {
  await admin(`
    DO $$ BEGIN CREATE ROLE service_role; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
    DO $$ BEGIN CREATE ROLE supabase_auth_admin; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
    ALTER TABLE private.cashier_writer_authorities ADD COLUMN IF NOT EXISTS released_at timestamptz;
    CREATE TABLE public.fixture_staff_roles(actor uuid,lounge uuid,role text);
    CREATE FUNCTION private.permission_role(uuid,uuid) RETURNS text LANGUAGE sql AS
      $$ SELECT role FROM public.fixture_staff_roles WHERE actor=$1 AND lounge=$2 $$;
    INSERT INTO auth.users VALUES('${manager}');
    INSERT INTO public.profiles VALUES('${manager}','manager',true,false);
    INSERT INTO public.fixture_staff_roles VALUES('${manager}','${lounge}','manager');
    INSERT INTO public.fixture_permissions VALUES('${manager}','${lounge}','sessions_control'),
      ('${manager}','${lounge}','billing_checkout');
  `);
  await db.exec(await readFile(new URL('../migrations/20261005032358_cashier_conflict_review_retry.sql', import.meta.url), 'utf8'));
  const op = operation(), review = randomUUID();
  await admin(`UPDATE public.rooms SET is_available=false`);
  const initial = await send(op);
  assert.equal(initial.status, 'conflict');
  await check('cashier cannot approve own conflict', async () => {
    await login(); await denied(approve(op, review));
  });
  await check('banned manager cannot review', async () => {
    await admin(`UPDATE public.profiles SET is_banned=true WHERE id='${manager}'`);
    await reviewer(); await denied(approve(op, review));
    await admin(`UPDATE public.profiles SET is_banned=false WHERE id='${manager}'`);
  });
  await check('inactive platform role cannot review', async () => {
    await admin(`UPDATE public.profiles SET role='super_admin',is_active=false WHERE id='${actor}'`);
    await reviewer(actor); await denied(approve(op, review));
    await admin(`UPDATE public.profiles SET role='cashier',is_active=true WHERE id='${actor}'`);
  });
  await check('manager cannot list another venue conflicts', async () => {
    await reviewer(); await denied(db.query('SELECT public.get_cashier_sync_conflicts($1)', [otherLounge]));
  });
  await check('reason is required', async () => {
    await reviewer(); await denied(approve(op, review, 'short'), '22023');
  });
  await check('approval retains immutable conflict receipt', async () => {
    await reviewer(); assert.equal((await approve(op, review)).rows[0].result.status, 'approved');
    await admin(''); const r = await db.query('SELECT result FROM private.cashier_operation_receipts WHERE operation_id=$1', [op.id]);
    assert.deepEqual(r.rows[0].result, initial);
  });
  await check('same review is idempotent and changed reason rejected', async () => {
    await reviewer(); await approve(op, review);
    await denied(approve(op, review, 'A different explanation for the same review'), '22023');
  });
  await check('pending approval cannot be duplicated', async () => {
    await reviewer(); await denied(approve(op, randomUUID()), '55000');
  });
  await check('approval never bypasses room availability', async () => {
    assert.equal((await send(op)).status, 'conflict');
    await admin(''); assert.equal(Number((await db.query('SELECT count(*) FROM public.bookings')).rows[0].count), 0);
  });
  await check('failed retry outcome remains immutable', async () => {
    await admin('');
    await denied(db.query('DELETE FROM private.cashier_conflict_outcomes WHERE review_id=$1', [review]), '55000');
  });
  const secondReview = randomUUID();
  await check('repaired resource needs fresh audited approval', async () => {
    await admin(`UPDATE public.rooms SET is_available=true`);
    assert.equal((await send(op)).status, 'conflict');
    await reviewer(); await approve(op, secondReview);
    assert.equal((await send(op)).status, 'applied');
  });
  await check('successful retry advances once without replacing initial evidence', async () => {
    assert.equal((await send(op)).status, 'replayed');
    await admin('');
    assert.equal(Number((await db.query('SELECT count(*) FROM public.bookings')).rows[0].count), 1);
    assert.equal(Number((await db.query('SELECT last_applied_sequence FROM private.cashier_writer_authorities')).rows[0].last_applied_sequence), 1);
    assert.deepEqual((await db.query('SELECT result FROM private.cashier_operation_receipts WHERE operation_id=$1', [op.id])).rows[0].result, initial);
  });
  await check('changed original payload is never replayable', async () => {
    const changed = structuredClone(op); changed.payload.customer_name = 'Changed';
    await denied(send(changed), '22023');
  });
  await check('resolved conflict disappears from manager queue', async () => {
    await reviewer(); assert.deepEqual((await db.query('SELECT public.get_cashier_sync_conflicts($1) AS result', [lounge])).rows[0].result, []);
  });
  await check('API roles cannot read audit tables or call internal authorizer', async () => {
    await reviewer();
    await denied(db.query('SELECT * FROM private.cashier_conflict_reviews'));
    await denied(db.query('SELECT private.assert_cashier_conflict_reviewer($1)', [lounge]));
  });
  console.log(JSON.stringify({passed, hostedMutations: false}));
} finally { await db.close(); }
