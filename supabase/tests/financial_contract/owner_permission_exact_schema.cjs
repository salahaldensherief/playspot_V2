// Destructive synthetic rows are rolled back. Never point this at a remote DB.
const { Client } = require('../runtime/node_modules/pg');
const { randomUUID } = require('node:crypto');
const assert = require('node:assert/strict');

assert.equal(process.env.PLAYSPOT_EXACT_SCHEMA_TEST, '1');
const target = new URL(process.env.PLAYSPOT_ISOLATED_DB_URL || '');
assert.ok(['localhost', '127.0.0.1'].includes(target.hostname));

async function runAs(db, actor, sql, values = []) {
  await db.query('SAVEPOINT actor_call');
  try {
    await db.query('SET LOCAL ROLE authenticated');
    await db.query("SELECT set_config('request.jwt.claim.sub',$1,true)", [actor]);
    const result = await db.query(sql, values);
    await db.query('ROLLBACK TO SAVEPOINT actor_call');
    return { ok: true, rows: result.rows };
  } catch (error) {
    await db.query('ROLLBACK TO SAVEPOINT actor_call');
    return { ok: false, code: error.code, message: error.message };
  }
}

async function main() {
  const db = new Client({ connectionString: target.toString() });
  await db.connect();
  try {
    assert.equal((await db.query("SELECT token FROM private.playspot_isolated_test_guard WHERE token='PLAYSPOT_DISPOSABLE_EXACT_SCHEMA_20261025'")).rowCount, 1);
    await db.query('BEGIN');
    const owner = randomUUID();
    const manager = randomUUID();
    const cashier = randomUUID();
    const outsider = randomUUID();
    const lounge = randomUUID();
    const foreignLounge = randomUUID();
    for (const id of [owner, manager, cashier, outsider]) {
      await db.query('INSERT INTO auth.users(id) VALUES($1)', [id]);
    }
    for (const [id, role] of [[owner,'owner'],[manager,'manager'],[cashier,'cashier'],[outsider,'owner']]) {
      await db.query('INSERT INTO public.profiles(id,role,is_active,is_banned) VALUES($1,$2,true,false)', [id,role]);
    }
    await db.query("INSERT INTO public.lounges(id,name,owner_id,status,is_active,instapay_account) VALUES($1,'Permission fixture',$2,'active',true,'TEST-ONLY'),($3,'Other fixture',$4,'active',true,'TEST-ONLY')", [lounge, owner, foreignLounge, outsider]);
    for (const [id, scope] of [[owner,lounge],[manager,lounge],[cashier,lounge],[outsider,foreignLounge]]) {
      await db.query('UPDATE public.profiles SET lounge_id=$2 WHERE id=$1', [id,scope]);
    }
    await db.query("INSERT INTO public.app_permissions(key,name_ar,name_en,category) VALUES('staff_manage','fixture','fixture','staff'),('billing_checkout','fixture','fixture','billing') ON CONFLICT (key) DO NOTHING");
    await db.query("INSERT INTO public.staff_permissions(user_id,lounge_id,permission_key,is_enabled) VALUES($1,$2,'staff_manage',true),($1,$2,'billing_checkout',false)", [manager,lounge]);
    await db.query("INSERT INTO public.lounge_staff(lounge_id,user_id,role) VALUES($1,$2,'manager')",[lounge,manager]);

    const directSelf = await runAs(db, manager, "INSERT INTO public.staff_permissions(user_id,lounge_id,permission_key,is_enabled) VALUES($1,$2,'billing_checkout',true)", [manager,lounge]);
    assert.equal(directSelf.ok, false);
    assert.equal(directSelf.code, '42501');
    const directTemplate = await runAs(db, manager, "INSERT INTO public.lounge_role_permissions(lounge_id,role,permission_key,is_enabled) VALUES($1,'manager','billing_checkout',true)", [lounge]);
    assert.equal(directTemplate.ok, false);
    assert.equal(directTemplate.code, '42501');
    const selfPromote = await runAs(db, manager, "UPDATE public.lounge_staff SET role='lounge_owner' WHERE lounge_id=$1 AND user_id=$2", [lounge,manager]);
    assert.equal(selfPromote.code,'42501');

    const managerGrant = await runAs(db, manager, 'SELECT public.update_role_permission($1,$2,$3,$4) AS result', ['cashier','billing_checkout',true,lounge]);
    assert.equal(managerGrant.ok, false);
    assert.equal(managerGrant.code, '42501');
    const managerSelf = await runAs(db, manager, 'SELECT public.set_staff_permission($1,$2,$3,$4) AS result', [lounge,manager,'billing_checkout',true]);
    assert.equal(managerSelf.code, '42501');
    const outsiderGrant = await runAs(db, outsider, 'SELECT public.set_staff_permission($1,$2,$3,$4) AS result', [lounge,cashier,'billing_checkout',true]);
    assert.equal(outsiderGrant.code, '42501', JSON.stringify(outsiderGrant));
    const ownerSelf = await runAs(db, owner, 'SELECT public.set_staff_permission($1,$2,$3,$4) AS result', [lounge,owner,'billing_checkout',true]);
    assert.equal(ownerSelf.code, '42501');

    // Keep only this synthetic mutation inside the outer rollback transaction.
    await db.query('SET LOCAL ROLE authenticated');
    await db.query("SELECT set_config('request.jwt.claim.sub',$1,true)", [owner]);
    const grant = await db.query('SELECT public.set_staff_permission($1,$2,$3,$4) AS result', [lounge,cashier,'billing_checkout',true]);
    assert.equal(grant.rows[0].result.success, true);
    await db.query('RESET ROLE');
    const override = await db.query("SELECT is_enabled FROM public.staff_permissions WHERE user_id=$1 AND lounge_id=$2 AND permission_key='billing_checkout'", [cashier,lounge]);
    assert.equal(override.rows[0].is_enabled, true);
    const audit = await db.query("SELECT actor_user_id,permission_key AS key FROM public.permission_audit_logs WHERE lounge_id=$1 AND target_user_id=$2", [lounge,cashier]);
    assert.equal(audit.rowCount, 1);
    assert.equal(audit.rows[0].actor_user_id, owner);
    assert.equal(audit.rows[0].key, 'billing_checkout');

    const ownerAudit = await runAs(db,owner,'SELECT count(*)::int AS count FROM public.permission_audit_logs WHERE lounge_id=$1',[lounge]);
    assert.equal(ownerAudit.ok,true,JSON.stringify(ownerAudit));
    assert.equal(ownerAudit.rows[0].count,1);
    const outsiderAudit = await runAs(db,outsider,'SELECT count(*)::int AS count FROM public.permission_audit_logs WHERE lounge_id=$1',[lounge]);
    assert.equal(outsiderAudit.rows[0].count,0);
    const tamper = await runAs(db,manager,'DELETE FROM public.permission_audit_logs WHERE lounge_id=$1',[lounge]);
    assert.equal(tamper.code,'42501');

    await db.query('SET LOCAL ROLE authenticated');
    await db.query("SELECT set_config('request.jwt.claim.sub',$1,true)",[owner]);
    await db.query('SELECT public.set_staff_permission($1,$2,$3,$4)',[lounge,cashier,'billing_checkout',false]);
    await db.query('RESET ROLE');
    const revoked = await db.query("SELECT is_enabled FROM public.staff_permissions WHERE user_id=$1 AND lounge_id=$2 AND permission_key='billing_checkout'",[cashier,lounge]);
    assert.equal(revoked.rows[0].is_enabled,false);
    const auditCount = await db.query('SELECT count(*)::int AS count FROM public.permission_audit_logs WHERE lounge_id=$1',[lounge]);
    assert.equal(auditCount.rows[0].count,2);
    await db.query('ROLLBACK');
    process.stdout.write('owner permission exact-schema: direct table writes, staff membership self-promotion, cross-lounge escalation, delegation, grant/revoke and audit passed\n');
  } finally {
    await db.end();
  }
}

main().catch(error => { console.error(error); process.exitCode = 1; });
