import {createFixtureDatabase} from './runtime/database.mjs';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';

const db = await createFixtureDatabase();
const actor = '00000000-0000-0000-0000-000000000001';
const lounge = '00000000-0000-0000-0000-000000000010';
const other = '00000000-0000-0000-0000-000000000020';
let passed = 0;
try {
  await db.exec(`
    CREATE ROLE anon; CREATE ROLE authenticated; CREATE ROLE service_role;
    CREATE SCHEMA auth; CREATE SCHEMA private;
    CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql AS
      $$SELECT NULLIF(current_setting('test.actor',true),'')::uuid$$;
    CREATE TABLE auth.users(id uuid PRIMARY KEY, raw_user_meta_data jsonb DEFAULT '{}'::jsonb);
    CREATE TABLE public.profiles(id uuid PRIMARY KEY, role text,
      lounge_id uuid, is_active boolean, is_banned boolean);
    CREATE TABLE public.platform_super_admins(user_id uuid PRIMARY KEY);
    CREATE TABLE public.payments(lounge_id uuid, amount numeric, status text, paid_at timestamptz);
    CREATE FUNCTION private.is_lounge_member(target uuid) RETURNS boolean LANGUAGE sql AS
      $$SELECT EXISTS(SELECT 1 FROM public.profiles WHERE id=auth.uid() AND lounge_id=target)$$;
    INSERT INTO auth.users(id) VALUES ('${actor}');
    INSERT INTO public.profiles VALUES ('${actor}','lounge_owner','${lounge}',true,false);
    INSERT INTO public.payments VALUES
      ('${lounge}',100,'completed','2026-10-01 22:30:00+00'),
      ('${other}',200,'completed','2026-10-01 22:30:00+00'),
      ('${lounge}',999,'pending','2026-10-01 22:30:00+00');
    GRANT USAGE ON SCHEMA public,auth TO anon,authenticated;
    SET test.actor='${actor}';
  `);
  await db.exec(await readFile(new URL('../repairs/active_super_admin_boundary.sql', import.meta.url),'utf8'));
  await db.exec(await readFile(new URL('../repairs/platform_revenue_actor_contract.sql', import.meta.url),'utf8'));
  async function check(name, action, setup='') {
    await db.exec(`RESET ROLE; ${setup} SET ROLE authenticated;`);
    await action(); passed++; console.log('PASS ' + name);
  }
  const read = (target='NULL',period="'day'") => db.query(
    `SELECT public.get_revenue_over_time(${target},${period}) AS result`);
  const amount = async target => Number((await read(target)).rows[0].result[0].revenue);
  const denied = (target='NULL',code='42501',period="'day'") =>
    assert.rejects(read(target,period),error => error.code===code);
  await check('owner reads only own completed payments', async () => assert.equal(await amount(),100));
  await check('Cairo day boundary and stable response keys', async () => {
    const row=(await read()).rows[0].result[0];
    assert.deepEqual(Object.keys(row).sort(),['period','revenue']);
    assert.equal(row.period,'2026-10-02T00:00:00');
  });
  await check('owner cannot read another lounge', () => denied(`'${other}'`));
  await check('authenticated caller cannot read financial tables directly', () =>
    assert.rejects(db.query('SELECT * FROM public.payments'),error => error.code==='42501'));
  await check('metadata cannot elevate financial scope', () => denied(`'${other}'`),
    `UPDATE auth.users SET raw_user_meta_data='{"role":"super_admin"}';`);
  await check('registry admin receives global completed revenue', async () => assert.equal(await amount(),300),
    `INSERT INTO public.platform_super_admins VALUES ('${actor}');`);
  await check('registry admin can select one lounge', async () => assert.equal(await amount(`'${other}'`),200));
  await check('inactive registry admin denied', () => denied(), 'UPDATE public.profiles SET is_active=false;');
  await check('banned registry admin denied', () => denied(), 'UPDATE public.profiles SET is_active=true,is_banned=true;');
  await check('legacy role admin receives global revenue', async () => assert.equal(await amount(),300),
    "DELETE FROM public.platform_super_admins; UPDATE public.profiles SET role='superadmin',is_banned=false;");
  await check('invalid period rejected', () => denied('NULL','22023',"'minute'"));
  await check('null period rejected', () => denied('NULL','22023','NULL'));
  await check('deleted auth identity denied', () => denied(), 'DELETE FROM auth.users;');
  await check('missing profile denied', () => denied(), `INSERT INTO auth.users(id) VALUES ('${actor}'); DELETE FROM public.profiles;`);
  await check('anonymous identity denied', () => denied('NULL','28000'), "SET test.actor='';");
  await db.exec('RESET ROLE; SET ROLE anon;');
  await assert.rejects(read(),error => error.code==='42501');
  passed++; console.log('PASS anonymous execute revoked');
  console.log(JSON.stringify({passed,mode:process.env.PLAYSPOT_NATIVE_PG_PORT?'native PostgreSQL':'PGlite',
    limitations:['Synthetic financial/auth schema','No hosted SQL applied','Not full production RLS or PostgREST integration']}));
} finally {
  await db.close();
}
