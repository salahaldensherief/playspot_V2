import {createFixtureDatabase} from './runtime/database.mjs';
import {readFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
const db=await createFixtureDatabase();let passed=0;
const actor='10000000-0000-0000-0000-000000000001',other='10000000-0000-0000-0000-000000000002';
const tables=['points_transactions','user_vouchers','notifications','notification_settings','favorites'];
async function check(name,body){await body();passed++;console.log('PASS '+name);}
async function call(id=actor){return (await db.query('SELECT public.anonymize_account_for_deletion($1) AS result',[id])).rows[0].result;}
try{
 await db.exec(`CREATE ROLE anon;CREATE ROLE authenticated;
 CREATE TABLE public.profiles(id uuid PRIMARY KEY,full_name text,phone text,email text,avatar_url text,fcm_token text,is_active boolean,is_banned boolean,updated_at timestamptz);
 INSERT INTO public.profiles VALUES('${actor}','Fixture','synthetic','fixture@example.invalid',null,'token',true,false,now()),('${other}','Other',null,null,null,null,true,false,now());
 ${[...tables,'bookings','payments'].map(t=>`CREATE TABLE public.${t}(user_id uuid);INSERT INTO public.${t} VALUES('${actor}'),('${other}');`).join('\n')}
 CREATE FUNCTION public.fail_fixture_delete() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN RAISE EXCEPTION 'synthetic failure' USING ERRCODE='23514';END$$;
 CREATE TRIGGER fail_delete BEFORE DELETE ON public.favorites FOR EACH ROW EXECUTE FUNCTION public.fail_fixture_delete();`);
 const migration=await readFile(new URL('../migrations/20261009000004_account_anonymization_transaction.sql',import.meta.url),'utf8');
 await db.exec(migration);
 await check('late delete failure rolls back every preceding delete, profile and retry record',async()=>{
  await db.exec('SET ROLE service_role');await assert.rejects(call(),e=>e.code==='23514');await db.exec('RESET ROLE');
  for(const t of tables)assert.equal((await db.query(`SELECT count(*)::int AS n FROM public.${t}`)).rows[0].n,2);
  assert.equal((await db.query('SELECT count(*)::int AS n FROM public.account_deletion_requests')).rows[0].n,0);
  assert.equal((await db.query(`SELECT is_active FROM public.profiles WHERE id='${actor}'`)).rows[0].is_active,true);
 });
 await db.exec('DROP TRIGGER fail_delete ON public.favorites;SET ROLE service_role');
 await check('successful deletion atomically disables and anonymizes only the requested user',async()=>{
  assert.equal((await call()).deactivated,true);await db.exec('RESET ROLE');
  const p=(await db.query(`SELECT * FROM public.profiles WHERE id='${actor}'`)).rows[0];
  assert.equal(p.is_active,false);assert.equal(p.is_banned,true);assert.equal(p.full_name,'Deleted User');
  for(const f of ['phone','email','avatar_url','fcm_token'])assert.equal(p[f],null);
  for(const t of tables)assert.deepEqual((await db.query(`SELECT user_id FROM public.${t}`)).rows.map(r=>r.user_id),[other]);
  assert.equal((await db.query(`SELECT full_name FROM public.profiles WHERE id='${other}'`)).rows[0].full_name,'Other');
 });
 await check('bookings and payments are preserved',async()=>{
  for(const t of ['bookings','payments'])assert.equal((await db.query(`SELECT count(*)::int AS n FROM public.${t}`)).rows[0].n,2);
 });
 await check('Auth outage leaves a durable pending record; retry is idempotent',async()=>{
  const before=(await db.query(`SELECT * FROM public.account_deletion_requests WHERE user_id='${actor}'`)).rows[0];
  assert.equal(before.auth_disabled_at,null);await db.exec('SET ROLE service_role');await call();await db.exec('RESET ROLE');
  const after=(await db.query(`SELECT * FROM public.account_deletion_requests WHERE user_id='${actor}'`)).rows[0];
  assert.equal(after.requested_at.getTime(),before.requested_at.getTime());
 });
 await check('completion survives a duplicate request',async()=>{
  await db.exec(`SET ROLE service_role;UPDATE public.account_deletion_requests SET auth_disabled_at=now() WHERE user_id='${actor}'`);
  await call();await db.exec('RESET ROLE');assert.notEqual((await db.query('SELECT auth_disabled_at FROM public.account_deletion_requests')).rows[0].auth_disabled_at,null);
 });
 await check('anonymous and authenticated callers cannot select a victim through the service RPC',async()=>{
  for(const role of ['anon','authenticated']){await db.exec(`SET ROLE ${role}`);await assert.rejects(call(other),e=>e.code==='42501');await db.exec('RESET ROLE');}
 });
 await check('retry records are not readable or writable by ordinary clients',async()=>{
  await db.exec('SET ROLE authenticated');await assert.rejects(db.query('SELECT * FROM public.account_deletion_requests'),e=>e.code==='42501');
  await assert.rejects(db.query('UPDATE public.account_deletion_requests SET auth_disabled_at=now()'),e=>e.code==='42501');await db.exec('RESET ROLE');
 });
 await check('missing profile and null target fail without recording success',async()=>{
  await db.exec('SET ROLE service_role');await assert.rejects(call(null),e=>e.code==='22023');
  await assert.rejects(call('10000000-0000-0000-0000-000000000099'),e=>e.code==='P0002');await db.exec('RESET ROLE');
 });
 await check('containment rollback blocks execution and preserves records; reapply restores the contract',async()=>{
  await db.exec(await readFile(new URL('../review/rollbacks/20261009000004_account_anonymization_transaction.sql',import.meta.url),'utf8'));
  await db.exec('SET ROLE service_role');await assert.rejects(call(),e=>e.code==='42501');await db.exec('RESET ROLE');
  assert.equal((await db.query('SELECT count(*)::int AS n FROM public.account_deletion_requests')).rows[0].n,1);
  await db.exec(migration);await db.exec('SET ROLE service_role');assert.equal((await call()).success,true);
 });
 console.log(JSON.stringify({passed}));
}finally{await db.close();}
