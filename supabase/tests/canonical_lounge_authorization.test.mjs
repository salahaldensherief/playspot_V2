import {createFixtureDatabase} from './runtime/database.mjs';
import {readFile} from 'node:fs/promises';
import assert from 'node:assert/strict';

const db = await createFixtureDatabase();
const actor = '10000000-0000-0000-0000-000000000001';
const lounge = '20000000-0000-0000-0000-000000000001';
const foreign = '20000000-0000-0000-0000-000000000002';
const read = path => readFile(new URL(path, import.meta.url), 'utf8');
let passed = 0;
async function reset() {
  await db.exec(`RESET ROLE; SET test.actor='${actor}';
    INSERT INTO auth.users VALUES('${actor}') ON CONFLICT DO NOTHING;
    DELETE FROM public.platform_super_admins; DELETE FROM public.lounge_staff;
    UPDATE public.profiles SET role='cashier',is_active=true,is_banned=false,lounge_id='${lounge}';
    UPDATE public.lounges SET owner_id=NULL; SET ROLE authenticated;`);
}
async function values(id = lounge) {
  return (await db.query(`SELECT private.can_operate_playspot_lounge($1) operate,
    private.can_manage_playspot_lounge($1) manage, private.is_lounge_member($1) member,
    public.is_lounge_member_or_admin($1) public_member,
    private.current_user_role() role, private.permission_role(auth.uid(),$1) permission_role`, [id])).rows[0];
}
async function denied() {
  assert.deepEqual(await values(), {operate:false, manage:false, member:false, public_member:false, role:null, permission_role:null});
  assert.equal((await db.query('SELECT * FROM public.lounges')).rows.length, 0);
  await assert.rejects(db.query('SELECT public.test_shift_write($1)', [lounge]), /forbidden/);
  await db.exec('RESET ROLE');
  assert.equal((await db.query('SELECT count(*)::int count FROM public.test_shift_writes')).rows[0].count, 0);
}
async function check(name, body) {
  await reset(); await body(); passed++; console.log('PASS ' + name);
}
try {
  await db.exec(`CREATE SCHEMA auth; CREATE SCHEMA private;
    CREATE TABLE auth.users(id uuid PRIMARY KEY);
    CREATE TABLE public.profiles(id uuid PRIMARY KEY,role text,is_active boolean,is_banned boolean,lounge_id uuid);
    CREATE TABLE public.platform_super_admins(user_id uuid PRIMARY KEY);
    CREATE TABLE public.lounges(id uuid PRIMARY KEY,owner_id uuid);
    CREATE TABLE public.lounge_staff(lounge_id uuid,user_id uuid,role text);
    CREATE TABLE public.test_shift_writes(id uuid);
    CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql AS $$SELECT NULLIF(current_setting('test.actor',true),'')::uuid$$;
    INSERT INTO auth.users VALUES('${actor}');
    INSERT INTO public.profiles VALUES('${actor}','cashier',true,false,'${lounge}');
    INSERT INTO public.lounges VALUES('${lounge}',NULL),('${foreign}',NULL);
    GRANT USAGE ON SCHEMA public,auth,private TO authenticated;
    GRANT SELECT ON public.lounges TO authenticated;`);
  await db.exec(await read('../repairs/active_super_admin_boundary.sql'));
  await db.exec(await read('./fixtures/hosted_canonical_lounge_authorization.sql'));
  if (!process.env.PLAYSPOT_CANONICAL_ACCESS_BASELINE) {
    await db.exec(await read('../migrations/20261010131519_eligible_canonical_lounge_authorization.sql'));
  }
  await db.exec(`ALTER TABLE public.lounges ENABLE ROW LEVEL SECURITY;
    CREATE POLICY member_scope ON public.lounges FOR SELECT TO authenticated USING(private.is_lounge_member(id));
    CREATE FUNCTION public.test_shift_write(p_id uuid) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
    BEGIN
      IF NOT private.can_operate_playspot_lounge(p_id) THEN RAISE EXCEPTION 'forbidden'; END IF;
      INSERT INTO public.test_shift_writes VALUES(p_id);
    END; $$;`);
  for (const [name, alteration] of [
    ['banned owner', `UPDATE public.lounges SET owner_id='${actor}'; UPDATE public.profiles SET is_banned=true`],
    ['inactive manager', "UPDATE public.profiles SET role='manager',is_active=false"],
    ['banned staff membership', `INSERT INTO public.lounge_staff VALUES('${lounge}','${actor}','manager'); UPDATE public.profiles SET is_banned=true`],
    ['missing Auth user with retained profile', 'DELETE FROM auth.users'],
    ['NULL eligibility', 'UPDATE public.profiles SET is_active=NULL,is_banned=NULL'],
    ['banned platform member', `INSERT INTO public.platform_super_admins VALUES('${actor}'); UPDATE public.profiles SET is_banned=true`],
    ['missing profile', 'DELETE FROM public.profiles'],
  ]) {
    await check(name + ' has no read or write authority', async () => {
      await db.exec('RESET ROLE; ' + alteration + '; SET ROLE authenticated'); await denied();
      if (name === 'missing profile') await db.exec(`INSERT INTO public.profiles VALUES('${actor}','cashier',true,false,'${lounge}')`);
    });
  }
  await check('cashier has own operating scope and no management or foreign scope', async () => {
    assert.deepEqual(await values(), {operate:true,manage:false,member:true,public_member:true,role:'cashier',permission_role:'cashier'});
    const result=await values(foreign); assert.equal(result.operate,false); assert.equal(result.manage,false); assert.equal(result.member,false); assert.equal(result.public_member,false); assert.equal(result.permission_role,null);
    assert.equal((await db.query('SELECT * FROM public.lounges')).rows.length,1);
  });
  await check('eligible owner identified by ownership retains management', async () => {
    await db.exec(`RESET ROLE; UPDATE public.profiles SET role='user',lounge_id=NULL; UPDATE public.lounges SET owner_id='${actor}' WHERE id='${lounge}'; SET ROLE authenticated`);
    const result=await values(); assert.equal(result.operate,true); assert.equal(result.manage,true); assert.equal(result.member,true); assert.equal(result.public_member,true);
    assert.equal((await values(foreign)).operate,false);
  });
  await check('manager membership retains management within its lounge', async () => {
    await db.exec(`RESET ROLE; UPDATE public.profiles SET lounge_id=NULL; INSERT INTO public.lounge_staff VALUES('${lounge}','${actor}','manager'); SET ROLE authenticated`);
    assert.equal((await values()).manage,true); assert.equal((await values()).permission_role,'manager'); assert.equal((await values(foreign)).manage,false);
  });
  await check('canonical platform registry authority is consistent across helpers', async () => {
    await db.exec(`RESET ROLE; UPDATE public.profiles SET role='user',lounge_id=NULL; INSERT INTO public.platform_super_admins VALUES('${actor}'); SET ROLE authenticated`);
    assert.deepEqual(await values(foreign), {operate:true,manage:true,member:true,public_member:true,role:'user',permission_role:'super_admin'});
  });
  await check('no JWT actor fails closed', async () => {
    await db.exec("SET test.actor=''"); await denied();
  });
  console.log(JSON.stringify({passed}));
} finally { await db.close(); }
