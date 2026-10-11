import {createFixtureDatabase} from './runtime/database.mjs';
import {readFile} from 'node:fs/promises';
import {randomUUID} from 'node:crypto';
import assert from 'node:assert/strict';

const db = await createFixtureDatabase();
const actor=randomUUID(), target=randomUUID(), lounge=randomUUID(), outsider=randomUUID();
let passed=0;
const sqlFile='../migrations/20261011060637_atomic_staff_provisioning.sql';
async function check(name,body){await body();passed++;console.log('PASS '+name);}
const call=(who=actor,role='cashier',name='Fixture Staff')=>db.query(
  'SELECT public.finalize_lounge_staff_provisioning($1,$2,$3,$4,$5,$6) AS result',
  [who,target,lounge,role,name,'01234567890']);
const denied=(action,code='42501')=>assert.rejects(action,e=>e.code===code);
try {
  await db.exec(`CREATE ROLE anon; CREATE ROLE authenticated; CREATE ROLE service_role;
    DO $$ BEGIN CREATE ROLE supabase_auth_admin; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
    CREATE SCHEMA auth; CREATE SCHEMA private;
    CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql AS $$ SELECT nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
    CREATE FUNCTION auth.role() RETURNS text LANGUAGE sql AS $$ SELECT current_setting('request.jwt.claim.role',true) $$;
    CREATE TABLE auth.users(id uuid PRIMARY KEY,email text,raw_app_meta_data jsonb);
    CREATE TABLE public.profiles(id uuid PRIMARY KEY,email text,full_name text,phone text,role text NOT NULL,
      lounge_id uuid,is_active boolean,is_banned boolean,updated_at timestamptz);
    CREATE TABLE public.platform_super_admins(user_id uuid PRIMARY KEY);
    CREATE TABLE public.lounges(id uuid PRIMARY KEY);
    CREATE TABLE public.lounge_staff(user_id uuid PRIMARY KEY,lounge_id uuid NOT NULL REFERENCES public.lounges(id),role text NOT NULL);
    CREATE FUNCTION public.has_lounge_permission(uuid,text) RETURNS boolean LANGUAGE sql AS $$ SELECT auth.uid()='${actor}'::uuid AND $1='${lounge}'::uuid AND $2='staff_manage' $$;
    INSERT INTO auth.users VALUES('${actor}','owner@example.invalid','{}'),('${outsider}','outsider@example.invalid','{}'),
      ('${target}','staff@example.invalid','{"staff_provisioning":{"actor_id":"${actor}","lounge_id":"${lounge}","role":"cashier"}}');
    INSERT INTO public.profiles(id,role,is_active,is_banned) VALUES('${actor}','owner',true,false),('${outsider}','user',true,false),('${target}','cashier',true,false);
    INSERT INTO public.lounges VALUES('${lounge}');
    GRANT USAGE ON SCHEMA public,auth TO anon,authenticated,service_role;
  `);
  await db.exec(await readFile(new URL('../repairs/active_super_admin_boundary.sql',import.meta.url),'utf8'));
  await db.exec(await readFile(new URL(sqlFile,import.meta.url),'utf8'));
  const service=()=>db.exec("RESET ROLE; SET request.jwt.claim.role='service_role'; SET ROLE service_role;");
  const admin=sql=>db.exec(`RESET ROLE; ${sql}`);
  await check('authenticated API cannot provision',async()=>{
    await db.exec("SET request.jwt.claim.role='authenticated'; SET ROLE authenticated;");await denied(call());
  });
  const recover=(who=actor,email='staff@example.invalid',venue=lounge,role='cashier')=>db.query(
    'SELECT public.recover_lounge_staff_provisioning($1,$2,$3,$4) AS id',[who,email,venue,role]);
  await check('recovery API is service-only',async()=>{await denied(recover());});
  await check('lost Auth response recovers only exact trusted actor, venue, role and email',async()=>{
    await service();assert.equal((await recover()).rows[0].id,target);
    for(const args of [[outsider],[actor,'owner@example.invalid'],[actor,'staff@example.invalid',randomUUID()],
      [actor,'staff@example.invalid',lounge,'manager']]) {
      assert.equal((await recover(...args)).rows[0].id,null);
    }
  });
  await check('foreign actor cannot finalize',async()=>{await service();await denied(call(outsider));});
  await check('banned owner is rejected',async()=>{
    await admin(`UPDATE public.profiles SET is_banned=true WHERE id='${actor}'`);await service();await denied(call());
    await admin(`UPDATE public.profiles SET is_banned=false WHERE id='${actor}'`);
  });
  await check('inactive owner is rejected',async()=>{
    await admin(`UPDATE public.profiles SET is_active=false WHERE id='${actor}'`);await service();await denied(call());
    await admin(`UPDATE public.profiles SET is_active=true WHERE id='${actor}'`);
  });
  await check('manager cannot create peer manager',async()=>{
    await admin(`UPDATE public.profiles SET role='manager' WHERE id='${actor}'`);await service();await denied(call(actor,'manager'));
    await admin(`UPDATE public.profiles SET role='owner' WHERE id='${actor}'`);
  });
  await check('trusted Auth provenance prevents account reassignment',async()=>{
    await admin(`UPDATE auth.users SET raw_app_meta_data='{}' WHERE id='${target}'`);await service();await denied(call());
    await admin(`UPDATE auth.users SET raw_app_meta_data='{"staff_provisioning":{"actor_id":"${actor}","lounge_id":"${lounge}","role":"cashier"}}' WHERE id='${target}'`);
  });
  await check('staff write failure rolls back profile and receipt atomically',async()=>{
    await admin(`CREATE FUNCTION public.fixture_fail_staff() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'fixture failure' USING ERRCODE='55000'; END $$;
      CREATE TRIGGER fixture_fail BEFORE INSERT ON public.lounge_staff FOR EACH ROW EXECUTE FUNCTION public.fixture_fail_staff();`);
    await service();await denied(call(),'55000');await admin('');
    assert.equal((await db.query('SELECT lounge_id FROM public.profiles WHERE id=$1',[target])).rows[0].lounge_id,null);
    assert.equal(Number((await db.query('SELECT count(*) FROM private.staff_provisioning_receipts')).rows[0].count),0);
    await admin('DROP TRIGGER fixture_fail ON public.lounge_staff');
  });
  await check('successful retry writes one profile, membership and receipt',async()=>{
    await service();assert.equal((await call()).rows[0].result.success,true);
    assert.equal((await call()).rows[0].result.user_id,target);await admin('');
    assert.equal(Number((await db.query('SELECT count(*) FROM public.lounge_staff')).rows[0].count),1);
    assert.equal(Number((await db.query('SELECT count(*) FROM private.staff_provisioning_receipts')).rows[0].count),1);
    assert.equal((await db.query('SELECT lounge_id FROM public.profiles WHERE id=$1',[target])).rows[0].lounge_id,lounge);
  });
  await check('replay cannot alter name or role',async()=>{
    await service();await denied(call(actor,'cashier','Changed'),'22023');await denied(call(actor,'staff'));
  });
  await check('clients cannot inspect provisioning records',async()=>{
    await db.exec("RESET ROLE; SET ROLE authenticated;");await denied(db.query('SELECT * FROM private.staff_provisioning_receipts'));
  });
  console.log(JSON.stringify({passed,hostedMutations:false}));
} finally {await db.close();}
