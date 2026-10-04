import {fixedSessionFixture} from './runtime/fixed_session_fixture.mjs';
import {readFile} from 'node:fs/promises';
import {randomUUID} from 'node:crypto';
import assert from 'node:assert/strict';
import {lockedRace} from './runtime/locked_race.mjs';

const f=await fixedSessionFixture();
const {db,actor,customer,lounge,room,shift,otherShift,admin,login}=f;
let passed=0;
const releaseRequest=(options={})=>({
  sql:'SELECT public.release_cashier_writer($1,$2,$3,$4) AS receipt',
  args:[lounge,options.device??f.device,options.permit??f.permit,options.sequence??0],
});
const release=async(options={})=>{
  await login();const req=releaseRequest(options);
  return (await db.query(req.sql,req.args)).rows[0].receipt;
};
const closeShift=()=>admin(`UPDATE public.shifts SET status='closed',closed_at=now() WHERE id='${shift}'`);
const check=async(name,body)=>{
  await f.reset();await admin(`UPDATE private.cashier_writer_authorities SET released_at=NULL,
    actor_id='${actor}',device_id='${f.device}';
    INSERT INTO private.cashier_permit_generations SELECT '${f.permit}',writer_generation FROM private.cashier_writer_authorities WHERE lounge_id='${lounge}';
    INSERT INTO public.fixture_permissions VALUES('${actor}','${lounge}','bookings.view'),('${actor}','${lounge}','menu_view')`);
  await body();passed++;console.log('PASS '+name);
};
try {
  await admin(`ALTER TABLE public.rooms ADD pricing_model text DEFAULT 'single_multi_hour';
    CREATE TABLE public.booking_holds(id uuid PRIMARY KEY,lounge_id uuid,room_id uuid,start_at timestamp,end_at timestamp,expires_at timestamptz,released_at timestamptz,user_id uuid);`);
  await db.exec(await readFile(new URL('../repairs/offline_cashier_bootstrap.sql',import.meta.url),'utf8'));
  await db.exec(await readFile(process.env.PLAYSPOT_WRITER_RELEASE_SQL ?? new URL('../repairs/cashier_writer_release.sql',import.meta.url),'utf8'));
  await check('writer must close own shift before an explicit release',async()=>{
    await assert.rejects(release(),e=>e.code==='55000' && e.message==='CASHIER_RELEASE_CLOSE_OWN_SHIFT_FIRST');
  });
  await check('another cashier shift does not prevent release after own shift closes',async()=>{
    await closeShift();assert.equal((await release()).released,true);
  });
  await check('release retains authority and immutable permits while leaving venue offline',async()=>{
    await closeShift();await release();await admin('');
    const r=(await db.query(`SELECT (SELECT count(*) FROM private.cashier_writer_authorities)::int AS writers,
      EXISTS(SELECT FROM private.cashier_writer_permits WHERE permit_id=$1) AS old_permit,
      public.get_lounge_online_availability($2) AS online`,[f.permit,lounge])).rows[0];
    assert.equal(r.writers,1);assert.equal(r.old_permit,true);assert.equal(r.online,false);
  });
  await check('release retry is stable and does not rotate permits or release timestamp',async()=>{
    await closeShift();const a=await release(),b=await release();assert.deepEqual(a,b);
  });
  for (const [name,options,error] of [
    ['device',{device:randomUUID()},'CASHIER_RELEASE_WRITER_MISMATCH'],
    ['permit',{permit:randomUUID()},'CASHIER_RELEASE_WRITER_MISMATCH'],
    ['sequence',{sequence:1},'CASHIER_RELEASE_SEQUENCE_MISMATCH'],
  ]) await check('release refuses mismatched '+name,async()=>{
    await closeShift();await assert.rejects(release(options),e=>e.message===error);
  });
  await check('another actor cannot release the current writer even with venue permission',async()=>{
    await closeShift();await admin(`INSERT INTO public.fixture_permissions VALUES('${customer}','${lounge}','sessions_control'),('${customer}','${lounge}','bookings.view'),('${customer}','${lounge}','menu_view');
      SET test.actor='${customer}'; SET ROLE authenticated`);
    const req=releaseRequest();await assert.rejects(db.query(req.sql,req.args),e=>e.code==='42501');
  });
  await check('banned and inactive owners cannot release a previously issued writer',async()=>{
    await closeShift();
    for (const patch of ['is_banned=true','is_active=false']) {
      await admin(`UPDATE public.profiles SET is_active=true,is_banned=false WHERE id='${actor}';
        UPDATE public.profiles SET ${patch} WHERE id='${actor}'`);
      await assert.rejects(release(),e=>e.code==='42501');
    }
  });
  await check('revoked scoped session permission prevents release',async()=>{
    await closeShift();await admin("DELETE FROM public.fixture_permissions WHERE permission='sessions_control'");
    await assert.rejects(release(),e=>e.code==='42501');
  });
  await check('unresolved recorded conflict cannot be bypassed by writer release',async()=>{
    const op=f.operation();op.quoted_total_minor=9999;
    assert.equal((await f.send(op)).status,'conflict');await closeShift();
    await assert.rejects(release(),e=>e.message==='CASHIER_RELEASE_UNRESOLVED_CONFLICT');
  });
  await check('physical active session blocks release even if shift was closed elsewhere',async()=>{
    await f.seedBooking(randomUUID(),'in_progress');await closeShift();
    await assert.rejects(release(),e=>e.message==='CASHIER_RELEASE_ACTIVE_SESSION');
  });
  await check('released authority cannot synchronize old commands or private proof',async()=>{
    const op=f.operation();await closeShift();await release();
    await assert.rejects(f.send(op),e=>e.code==='42501' && e.message==='OFFLINE_WRITER_MISMATCH');
    await admin('');assert.equal((await db.query('SELECT private.cashier_sync_permit_matches_writer($1,$2,$3) AS matches',
      [lounge,actor,f.permit])).rows[0].matches,false);
  });
  await check('next authorized actor claims only explicit release and receives a fresh permit',async()=>{
    await closeShift();await release();await admin(`INSERT INTO public.fixture_permissions VALUES('${customer}','${lounge}','sessions_control'),('${customer}','${lounge}','bookings.view'),('${customer}','${lounge}','menu_view');
      SET test.actor='${customer}';SET ROLE authenticated;`);
    const device=randomUUID(),r=(await db.query("SELECT public.bootstrap_offline_cashier($1,$2,true)->'authority' AS authority",[lounge,device])).rows[0].authority;
    assert.equal(r.actor_id,customer);assert.equal(r.device_id,device);assert.notEqual(r.permit_id,f.permit);
    assert.equal(r.last_applied_sequence,0);
    assert.equal((await release()).released,true);
  });
  await check('next writer keeps global operation sequence rather than restarting at one',async()=>{
    assert.equal((await f.send(f.operation())).status,'applied');
    await closeShift();await release({sequence:1});
    await admin(`UPDATE public.shifts SET status='open',closed_at=NULL WHERE id='${shift}'`);await login();
    const r=(await db.query("SELECT public.bootstrap_offline_cashier($1,$2,false)->'authority' AS authority",[lounge,randomUUID()])).rows[0].authority;
    assert.equal(r.last_applied_sequence,1);assert.notEqual(r.permit_id,f.permit);
  });
  await check('heartbeat expiry alone still cannot authorize a device takeover',async()=>{
    await closeShift();await login();
    await assert.rejects(db.query('SELECT public.refresh_cashier_writer($1,$2,false)',[lounge,randomUUID()]),
      e=>e.message==='CASHIER_WRITER_ALREADY_ASSIGNED');
  });
  await check('release RPC is authenticated-only with no system-role execution leak',async()=>{
    await admin('');for(const role of ['anon','authenticated','service_role','supabase_auth_admin']) {
      assert.equal((await db.query(`SELECT has_function_privilege($1,
        'public.release_cashier_writer(uuid,uuid,uuid,bigint)','execute') AS allowed`,[role])).rows[0].allowed,
        role==='authenticated');
    }
  });
  if(db.connect) await check('competing next-device claims serialize and admit exactly one released writer',async()=>{
    await closeShift();await release();
    await admin(`UPDATE public.shifts SET status='open',closed_at=NULL WHERE id='${shift}'`);
    const req=device=>({sql:"SELECT public.bootstrap_offline_cashier($1,$2,false)->'authority' AS authority",args:[lounge,device]});
    const [first,second]=await lockedRace(db,req(randomUUID()),req(randomUUID()),actor);
    assert.equal(first.rows[0].authority.actor_id,actor);assert.equal(second.error?.message,'CASHIER_WRITER_ALREADY_ASSIGNED');
  });
  await check('delayed heartbeat cannot reclaim a released writer from a closed shift',async()=>{
    await closeShift();await release();await login();
    await assert.rejects(db.query('SELECT public.refresh_cashier_writer($1,$2,true)',[lounge,f.device]),
      e=>e.message==='CASHIER_RECLAIM_REQUIRES_BOOTSTRAP');
    assert.equal((await db.query('SELECT public.get_lounge_online_availability($1) AS online',[lounge])).rows[0].online,false);
  });
  await check('lost release receipt remains recoverable after another writer claims',async()=>{
    await closeShift();const original=await release();
    await admin(`UPDATE public.shifts SET status='open',closed_at=NULL WHERE id='${shift}'`);await login();
    await db.query("SELECT public.bootstrap_offline_cashier($1,$2,false)",[lounge,randomUUID()]);
    assert.deepEqual(await release(),original);
  });
  await check('same actor and device reclaim cannot reuse an old generation permit',async()=>{
    const op=f.operation();await closeShift();await release();
    await admin(`UPDATE public.shifts SET status='open',closed_at=NULL WHERE id='${shift}'`);await login();
    await db.query("SELECT public.bootstrap_offline_cashier($1,$2,false)",[lounge,f.device]);
    await assert.rejects(f.send(op),e=>e.code==='42501' && e.message==='OFFLINE_WRITER_GENERATION_MISMATCH');
  });
  await check('heartbeat cannot reclaim even after own shift reopens',async()=>{
    await closeShift();await release();
    await admin(`UPDATE public.shifts SET status='open',closed_at=NULL WHERE id='${shift}'`);await login();
    await assert.rejects(db.query('SELECT public.refresh_cashier_writer($1,$2,false)',[lounge,f.device]),
      e=>e.message==='CASHIER_RECLAIM_REQUIRES_BOOTSTRAP');
  });
  await check('failed bootstrap rolls back reclaim and private claim context',async()=>{
    await closeShift();await release();
    await admin(`UPDATE public.shifts SET status='open',closed_at=NULL WHERE id='${shift}';
      DELETE FROM public.fixture_permissions WHERE permission='bookings.view'`);await login();
    await assert.rejects(db.query('SELECT public.bootstrap_offline_cashier($1,$2,false)',[lounge,randomUUID()]),
      e=>e.code==='42501');await admin('');
    const r=(await db.query('SELECT released_at IS NOT NULL AS released,(SELECT count(*)::int FROM private.cashier_bootstrap_claim_context) AS contexts FROM private.cashier_writer_authorities')).rows[0];
    assert.equal(r.released,true);assert.equal(r.contexts,0);
  });
  await check('renewed permit preserves generation so the original release request succeeds',async()=>{
    const original=f.permit;
    await admin(`DELETE FROM public.fixture_permissions WHERE actor='${actor}' AND permission='bookings.manage'`);
    await login();const authority=(await db.query('SELECT public.refresh_cashier_writer($1,$2,false) AS authority',[lounge,f.device])).rows[0].authority;
    assert.notEqual(authority.permit_id,original);
    await closeShift();assert.equal((await release({permit:original})).released,true);
  });
  await check('private release records deny all client and system role table access',async()=>{
    await admin('');
    for(const table of ['cashier_permit_generations','cashier_writer_release_receipts','cashier_bootstrap_claim_context'])
      for(const role of ['anon','authenticated','service_role','supabase_auth_admin'])
        assert.equal((await db.query("SELECT has_table_privilege($1,$2,'SELECT,INSERT,UPDATE,DELETE') AS allowed",[role,'private.'+table])).rows[0].allowed,false);
    await closeShift();await release();await admin('');
    await assert.rejects(db.query('DELETE FROM private.cashier_writer_release_receipts'),e=>e.code==='55000');
    await assert.rejects(db.query('UPDATE private.cashier_permit_generations SET writer_generation=$1',[randomUUID()]),e=>e.code==='55000');
  });
  console.log(JSON.stringify({passed,limitations:['Review source only; no hosted release or writer mutation',
    'Server cannot observe unsent client operations: a durable local release barrier is mandatory',
    'Requires closed own shift and no physical active session; advanced handover is not implemented']}));
} finally {await db.close();}
