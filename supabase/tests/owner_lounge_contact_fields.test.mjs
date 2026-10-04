import { createFixtureDatabase } from './runtime/database.mjs';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const db = await createFixtureDatabase();
const actor = '00000000-0000-0000-0000-000000000001';
const owner = '00000000-0000-0000-0000-000000000002';
const outsider = '00000000-0000-0000-0000-000000000003';
let passed = 0;
try {
  await db.exec(`CREATE ROLE anon; CREATE ROLE authenticated; CREATE ROLE service_role;
    DO $$ BEGIN IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='supabase_auth_admin') THEN CREATE ROLE supabase_auth_admin; END IF; END $$;
    CREATE SCHEMA auth; CREATE SCHEMA private;
    CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql AS $$ SELECT NULLIF(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
    CREATE FUNCTION auth.role() RETURNS text LANGUAGE sql AS $$ SELECT current_setting('request.jwt.claim.role',true) $$;
    CREATE TABLE auth.users(id uuid PRIMARY KEY, email text);
    CREATE TABLE public.profiles(id uuid PRIMARY KEY, email text, full_name text, phone text, role text,
      lounge_id uuid,is_active boolean,is_banned boolean,is_setup_completed boolean,updated_at timestamptz);
    CREATE TABLE public.platform_super_admins(user_id uuid PRIMARY KEY);
    CREATE TABLE public.lounges(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),name text,city text,location text,
      owner_id uuid,status text,is_open boolean,is_active boolean,address text,contact_phone text);
    CREATE FUNCTION public.super_admin_create_lounge_with_owner(text,text,text,text,text) RETURNS jsonb LANGUAGE sql AS $$ SELECT '{}'::jsonb $$;
    GRANT EXECUTE ON FUNCTION public.super_admin_create_lounge_with_owner(text,text,text,text,text) TO authenticated;
    GRANT USAGE ON SCHEMA public,auth TO authenticated,anon,service_role;
    INSERT INTO auth.users VALUES ('${actor}','admin@example.invalid'),('${owner}','owner@example.invalid'),('${outsider}','outsider@example.invalid');
    INSERT INTO public.profiles(id,role,is_active,is_banned) VALUES
      ('${actor}','user',true,false),('${owner}','user',true,false),('${outsider}','user',true,false);
    INSERT INTO public.platform_super_admins VALUES ('${actor}');
  `);
  await db.exec(await readFile(new URL('../repairs/active_super_admin_boundary.sql', import.meta.url), 'utf8'));
  await db.exec(await readFile(new URL('../migrations/20261003110859_owner_auth_provisioning.sql', import.meta.url), 'utf8'));
  await db.exec(await readFile(new URL('../migrations/20261003185714_owner_lounge_contact_fields_v2.sql', import.meta.url), 'utf8'));
  await db.exec(await readFile(new URL('../migrations/20261004194130_pending_owner_onboarding_access.sql', import.meta.url), 'utf8'));
  const call = (who = actor, target = owner) => `SELECT public.finalize_owner_lounge_provisioning_v2('${who}','${target}','Owner','Venue','Cairo','Address','01234567890','01987654321') AS result`;
  const denied = async (name, sql, code='42501') => {
    await assert.rejects(db.query(sql), e => e.code === code); passed++; console.log('PASS '+name);
  };
  await db.exec(`SET request.jwt.claim.role='authenticated'; SET ROLE authenticated;`);
  await denied('client cannot invoke service provisioning', call());
  await denied('legacy SQL Auth writer is retired', `SELECT public.super_admin_create_lounge_with_owner('e','p','n','l','c')`);
  await db.exec(`RESET ROLE; SET request.jwt.claim.role='service_role'; SET ROLE service_role;`);
  await denied('customer actor cannot provision owners', call(outsider));
  await db.exec(`RESET ROLE; UPDATE public.profiles SET is_active=false WHERE id='${actor}'; SET ROLE service_role;`);
  await denied('disabled registered super admin is denied', call());
  await db.exec(`RESET ROLE; UPDATE public.profiles SET is_active=true,is_banned=true WHERE id='${actor}'; SET ROLE service_role;`);
  await denied('banned registered super admin is denied', call());
  await db.exec(`RESET ROLE; UPDATE public.profiles SET is_banned=false WHERE id='${actor}'; SET ROLE service_role;`);
  await denied('self reassignment is rejected', call(actor,actor), '22023');
  const first = (await db.query(call())).rows[0].result;
  assert.equal(first.success,true); assert.equal(first.owner_id,owner); assert.equal(first.status,'pending'); passed++;
  assert.deepEqual((await db.query(call())).rows[0].result,first); passed++;
  await db.exec('RESET ROLE');
  const venue=(await db.query('SELECT * FROM public.lounges')).rows[0];
  assert.equal(venue.is_open,false); assert.equal(venue.is_active,false); assert.equal(venue.location,'Address'); passed++;
  assert.equal(venue.address,'Address'); passed++;
  assert.equal(venue.contact_phone,'01234567890'); passed++;
  const profile=(await db.query(`SELECT * FROM public.profiles WHERE id='${owner}'`)).rows[0];
  assert.equal(profile.phone,'01987654321'); passed++;
  assert.equal(profile.is_active,true); passed++; console.log('PASS owner account can enter onboarding while venue stays inactive');
  assert.equal(profile.role,'owner'); assert.equal(profile.is_setup_completed,false); assert.equal(profile.lounge_id,first.lounge_id); passed++;
  assert.equal(Number((await db.query('SELECT count(*) FROM public.lounges')).rows[0].count),1); passed++;
  await db.exec('SET ROLE service_role');
  assert.deepEqual((await db.query(`SELECT public.finalize_owner_lounge_provisioning('${actor}','${owner}','Owner','Venue') AS result`)).rows[0].result,first); passed++;
  await db.exec('RESET ROLE');
  await db.exec(`UPDATE public.profiles SET role='super_admin' WHERE id='${outsider}'; SET ROLE service_role;`);
  await denied('another administrator cannot replay provisioning',call(outsider));
  await db.exec(`RESET ROLE; UPDATE public.profiles SET role='cashier' WHERE id='${outsider}'; SET ROLE service_role;`);
  await denied('existing staff accounts are never reassigned',call(actor,outsider),'22023');
  await db.exec(`RESET ROLE; SET ROLE authenticated;`);
  await denied('clients cannot read provisioning audit records','SELECT * FROM private.owner_lounge_provisioning');
  await db.exec(`RESET ROLE; UPDATE public.profiles SET is_active=false,is_banned=true WHERE id='${owner}'; SET ROLE service_role;`);
  assert.deepEqual((await db.query(call())).rows[0].result,first);
  await db.exec('RESET ROLE');
  const moderated=(await db.query(`SELECT is_active,is_banned FROM public.profiles WHERE id='${owner}'`)).rows[0];
  assert.deepEqual(moderated,{is_active:false,is_banned:true}); passed++; console.log('PASS provisioning retry cannot reactivate a moderated owner');
  const legacyOwner='00000000-0000-0000-0000-000000000004';
  await db.exec(`INSERT INTO auth.users VALUES('${legacyOwner}','legacy@example.invalid'); INSERT INTO public.profiles(id,role,is_active,is_banned) VALUES('${legacyOwner}','user',true,false); SET ROLE service_role;`);
  const legacy=(await db.query(`SELECT public.finalize_owner_lounge_provisioning('${actor}','${legacyOwner}','Owner','Legacy venue') AS result`)).rows[0].result;
  await db.exec('RESET ROLE');
  assert.equal((await db.query(`SELECT is_active FROM public.profiles WHERE id='${legacyOwner}'`)).rows[0].is_active,true);
  assert.equal((await db.query(`SELECT is_active FROM public.lounges WHERE id='${legacy.lounge_id}'`)).rows[0].is_active,false); passed++; console.log('PASS v1 also separates account access from venue approval');
  console.log(JSON.stringify({passed,liveMutations:false,fixtureSchema:true}));
} finally { await db.close(); }

