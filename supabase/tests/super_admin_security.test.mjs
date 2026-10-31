import {createFixtureDatabase} from './runtime/database.mjs';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';

const db = await createFixtureDatabase();
const actor = '00000000-0000-0000-0000-000000000001';
let passed = 0;
try {
  await db.exec(`
    CREATE ROLE anon; CREATE ROLE authenticated;
    CREATE SCHEMA auth;
    CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql AS
      $$SELECT NULLIF(current_setting('test.actor', true), '')::uuid$$;
    CREATE TABLE auth.users(id uuid PRIMARY KEY, raw_user_meta_data jsonb);
    CREATE TABLE public.profiles(id uuid PRIMARY KEY, role text, is_active boolean, is_banned boolean);
    CREATE TABLE public.platform_super_admins(user_id uuid PRIMARY KEY);
    ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
  `);
  await db.exec(await readFile(new URL('../repairs/active_super_admin_boundary.sql', import.meta.url), 'utf8'));
  await db.exec(`
    CREATE POLICY profile_read ON public.profiles FOR SELECT TO authenticated
      USING (id = auth.uid() OR public.is_super_admin());
    GRANT USAGE ON SCHEMA auth, public TO anon, authenticated;
    GRANT SELECT ON public.profiles TO authenticated;
    INSERT INTO auth.users VALUES ('${actor}', '{"role":"super_admin"}');
    INSERT INTO public.profiles VALUES ('${actor}', 'user', true, false);
    SET test.actor='${actor}';
  `);
  async function check(name, expected, setup = '') {
    await db.exec(`RESET ROLE; ${setup} SET ROLE authenticated;`);
    assert.equal((await db.query('SELECT public.is_super_admin() AS allowed')).rows[0].allowed, expected);
    passed++;
    console.log('PASS ' + name);
  }
  await check('user metadata does not grant administration', false);
  await check('canonical active role grants administration', true, "UPDATE public.profiles SET role='super_admin';");
  await check('legacy canonical role supported', true, "UPDATE public.profiles SET role='superadmin';");
  await check('inactive administrator denied', false, 'UPDATE public.profiles SET is_active=false;');
  await check('banned administrator denied', false, 'UPDATE public.profiles SET is_active=true,is_banned=true;');
  await check('null eligibility fails closed', false, 'UPDATE public.profiles SET is_banned=NULL;');
  await check('active platform membership grants administration', true,
    `UPDATE public.profiles SET role='user',is_banned=false; INSERT INTO public.platform_super_admins VALUES ('${actor}');`);
  await check('membership cannot bypass disabled profile', false, 'UPDATE public.profiles SET is_active=false;');
  await check('membership cannot bypass banned profile', false, 'UPDATE public.profiles SET is_active=true,is_banned=true;');
  await check('deleted Auth identity denies outstanding uid', false, 'UPDATE public.profiles SET is_banned=false; DELETE FROM auth.users;');
  await check('missing profile fails closed', false, 'DELETE FROM public.profiles;');
  await db.exec("RESET ROLE; SET test.actor=''; SET ROLE anon;");
  assert.equal((await db.query('SELECT public.is_super_admin() AS allowed')).rows[0].allowed, false);
  passed++; console.log('PASS anonymous helper returns false');
  await db.exec(`RESET ROLE; INSERT INTO auth.users VALUES ('${actor}', '{}');
    INSERT INTO public.profiles VALUES ('${actor}', 'super_admin', true, false);
    SET test.actor='${actor}'; SET ROLE authenticated;`);
  assert.equal(Number((await db.query('SELECT count(*) AS count FROM public.profiles')).rows[0].count), 1);
  passed++; console.log('PASS profile RLS helper does not recurse');
  await assert.rejects(db.query('SELECT * FROM public.platform_super_admins'), error => error.code === '42501');
  passed++; console.log('PASS membership table not exposed');
  console.log(JSON.stringify({passed, limitations: ['Synthetic Auth/RLS schema', 'No production writes', 'Does not validate session revocation or MFA']}));
} finally {
  await db.close();
}
