import {createFixtureDatabase} from './runtime/database.mjs';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';

const db = await createFixtureDatabase();
const user='00000000-0000-0000-0000-000000000001';
const other='00000000-0000-0000-0000-000000000002';
const staff='00000000-0000-0000-0000-000000000003';
const lounge='00000000-0000-0000-0000-000000000010';
const foreign='00000000-0000-0000-0000-000000000020';
const room='00000000-0000-0000-0000-000000000100';
let passed=0;
try {
  await db.exec(`
    CREATE ROLE anon; CREATE ROLE authenticated;
    CREATE SCHEMA auth;
    CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql AS
      $$SELECT NULLIF(current_setting('test.actor',true),'')::uuid$$;
    CREATE TABLE public.profiles(id uuid PRIMARY KEY,is_active boolean,is_banned boolean,lounge_id uuid);
    CREATE TABLE public.rooms(id uuid PRIMARY KEY,lounge_id uuid);
    CREATE TABLE public.booking_waitlist(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),user_id uuid,
      lounge_id uuid,room_id uuid,requested_date date,duration_minutes int,preferred_start_time time,
      start_at timestamp,end_at timestamp,status text,created_at timestamptz DEFAULT now());
    ALTER TABLE public.booking_waitlist ENABLE ROW LEVEL SECURITY;
    CREATE POLICY read_scope ON public.booking_waitlist FOR SELECT TO authenticated
      USING (user_id=auth.uid() OR lounge_id=(SELECT lounge_id FROM public.profiles WHERE id=auth.uid()));
    CREATE POLICY insert_own ON public.booking_waitlist FOR INSERT TO authenticated WITH CHECK(user_id=auth.uid());
    ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
    CREATE POLICY own_profile ON public.profiles FOR SELECT TO authenticated USING (id=auth.uid());
    GRANT USAGE ON SCHEMA public,auth TO anon,authenticated;
    GRANT SELECT ON public.profiles,public.rooms TO authenticated;
    GRANT SELECT,INSERT ON public.booking_waitlist TO authenticated;
    INSERT INTO public.profiles VALUES
      ('${user}',true,false,NULL),('${other}',true,false,NULL),('${staff}',true,false,'${lounge}');
    INSERT INTO public.rooms VALUES ('${room}','${lounge}');
    INSERT INTO public.booking_waitlist(user_id,lounge_id,room_id,requested_date,status) VALUES
      ('${user}','${lounge}','${room}','2026-10-04','active'),
      ('${other}','${lounge}','${room}','2026-10-04','active'),
      ('${other}','${foreign}','${room}','2026-10-04','active');
    CREATE VIEW public.slot_waitlist AS SELECT id,user_id,lounge_id,room_id,requested_date AS date,
      preferred_start_time AS slot_time,status,created_at FROM public.booking_waitlist;
    GRANT SELECT,INSERT ON public.slot_waitlist TO authenticated;
    SET test.actor='${user}'; SET ROLE authenticated;
  `);
  // Reproduce the legacy view's RLS bypass before applying the candidate locally.
  assert.equal(Number((await db.query('SELECT count(*) AS n FROM public.slot_waitlist')).rows[0].n),3);
  passed++;console.log('PASS legacy view leak reproduced on synthetic rows');
  await db.exec('RESET ROLE;');
  await db.exec(await readFile(new URL('../repairs/slot_waitlist_view_boundary.sql',import.meta.url),'utf8'));
  await db.exec(`CREATE TRIGGER trg_slot_waitlist_insert INSTEAD OF INSERT ON public.slot_waitlist
    FOR EACH ROW EXECUTE FUNCTION public.fn_slot_waitlist_insert();`);
  async function as(id,role='authenticated') {await db.exec(`RESET ROLE; SET test.actor='${id}'; SET ROLE ${role};`);}
  async function check(name,action) {await action();passed++;console.log('PASS '+name);}
  const count=async()=>Number((await db.query('SELECT count(*) AS n FROM public.slot_waitlist')).rows[0].n);
  const insert=(owner='NULL',venue=lounge,status='active')=>db.query(`INSERT INTO public.slot_waitlist
    (user_id,lounge_id,room_id,date,slot_time,status) VALUES
    (${owner},'${venue}','${room}','2026-10-05','19:30','${status}') RETURNING *`);
  const denial=call=>assert.rejects(call,error=>error.code==='42501');
  await as(user);
  await check('customer sees own request only',async()=>assert.equal(await count(),1));
  await as(staff);
  await check('staff sees assigned venue only',async()=>assert.equal(await count(),2));
  await as(other);
  await check('other customer sees own requests only',async()=>assert.equal(await count(),2));
  await as(user);
  await check('omitted user is bound to actor with preserved timing',async()=>{
    const row=(await insert()).rows[0];assert.equal(row.user_id,user);assert.equal(row.slot_time,'19:30:00');
    const result=(await db.query(`SELECT duration_minutes,EXTRACT(EPOCH FROM (end_at-start_at)) AS duration_seconds FROM public.booking_waitlist WHERE id='${row.id}'`)).rows[0];
    assert.equal(result.duration_minutes,60);assert.equal(Number(result.duration_seconds),3600);
  });
  await check('another customer cannot be impersonated',()=>denial(insert(`'${other}'`)));
  await check('room cannot be paired with another venue',()=>denial(insert('NULL',foreign)));
  await check('notification state cannot be forged',()=>denial(insert('NULL',lounge,'notified')));
  await db.exec('RESET ROLE;');await db.exec(`UPDATE public.profiles SET is_active=false WHERE id='${user}';`);await as(user);
  await check('inactive actor cannot insert',()=>denial(insert()));
  await db.exec('RESET ROLE;');await db.exec(`UPDATE public.profiles SET is_active=true,is_banned=true WHERE id='${user}';`);await as(user);
  await check('banned actor cannot insert',()=>denial(insert()));
  await as('', 'anon');
  await check('anonymous view read denied',()=>denial(db.query('SELECT * FROM public.slot_waitlist')));
  await check('anonymous view insert denied',()=>denial(insert()));
  await as(user);
  await check('view direct update denied',()=>denial(db.query("UPDATE public.slot_waitlist SET status='notified'")));
  console.log(JSON.stringify({passed,engine:process.env.PLAYSPOT_NATIVE_PG_PORT?'native PostgreSQL':'PGlite',
    limitations:['Synthetic RLS schema','No live record queried through the view','No hosted repair applied','Canonical waitlist RPC concurrency not proven']}));
} finally {await db.close();}
