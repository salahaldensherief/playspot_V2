import {createFixtureDatabase} from './runtime/database.mjs';
import {lockedRace} from './runtime/locked_race.mjs';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';

const db=await createFixtureDatabase();
const actor='00000000-0000-0000-0000-000000000001';
const other='00000000-0000-0000-0000-000000000002';
const lounge='10000000-0000-0000-0000-000000000001';
const device='20000000-0000-0000-0000-000000000001';
let passed=0;
try {
  await db.exec(`CREATE ROLE anon;CREATE ROLE authenticated;CREATE SCHEMA auth; CREATE SCHEMA private;
    CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql AS $$SELECT NULLIF(current_setting('test.actor',true),'')::uuid$$;
    CREATE TABLE auth.users(id uuid PRIMARY KEY);
    CREATE TABLE public.profiles(id uuid PRIMARY KEY,role text,is_active boolean,is_banned boolean);
    CREATE TABLE public.platform_super_admins(user_id uuid PRIMARY KEY);
    CREATE TABLE public.lounges(id uuid PRIMARY KEY,status text,is_active boolean,is_open boolean);
    CREATE TABLE public.rooms(id uuid PRIMARY KEY,lounge_id uuid);
    CREATE TABLE public.bookings(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),user_id uuid,lounge_id uuid,room_id uuid,
      status text DEFAULT 'pending',date date,start_time time,end_time time);
    CREATE TABLE public.fixture_permissions(actor uuid,lounge uuid,permission text);
    CREATE FUNCTION private.user_permission_value(uuid,uuid,text) RETURNS boolean LANGUAGE sql AS
      $$SELECT EXISTS(SELECT 1 FROM public.fixture_permissions WHERE actor=$1 AND lounge=$2 AND permission=$3)$$;
    CREATE FUNCTION public.has_lounge_permission(uuid,text) RETURNS boolean LANGUAGE sql SECURITY DEFINER SET search_path='' AS
      $$SELECT EXISTS(SELECT 1 FROM public.fixture_permissions WHERE actor=auth.uid() AND lounge=$1 AND permission=$2)$$;
    INSERT INTO auth.users VALUES('${actor}'),('${other}');
    INSERT INTO public.profiles VALUES('${actor}','cashier',true,false),('${other}','cashier',true,false);
    INSERT INTO public.lounges VALUES('${lounge}','active',true,true);
    INSERT INTO public.fixture_permissions VALUES('${actor}','${lounge}','sessions_control'),('${actor}','${lounge}','billing_checkout');
    GRANT USAGE ON SCHEMA public,auth TO authenticated,anon;
    GRANT INSERT,SELECT,UPDATE ON public.bookings TO authenticated;
  `);
  await db.exec(await readFile(new URL('../repairs/active_super_admin_boundary.sql',import.meta.url),'utf8'));
  await db.exec(await readFile(new URL('../repairs/cashier_writer_permits.sql',import.meta.url),'utf8'));
  await db.exec(await readFile(new URL('../repairs/cashier_writer_availability.sql',import.meta.url),'utf8'));
  const refresh=`SELECT public.refresh_cashier_writer('${lounge}','${device}',true) AS authority`;
  async function actorAs(id){await db.exec(`RESET ROLE;SET test.actor='${id??''}';SET ROLE authenticated;`);}
  async function deny(name,sql,code){await assert.rejects(db.query(sql),error=>error.code===code);passed++;console.log('PASS '+name);}
  async function online(expected,name){assert.equal((await db.query(`SELECT public.get_lounge_online_availability('${lounge}') AS available`)).rows[0].available,expected);passed++;console.log('PASS '+name);}
  await actorAs(null); await deny('missing identity denied',refresh,'28000');
  await actorAs(other); await deny('another unassigned cashier denied',refresh,'42501');
  await actorAs(actor);
  const first=(await db.query(refresh)).rows[0].authority;
  assert.equal(first.permissions.sessions_control,true);assert.equal(first.permissions['bookings.manage'],false);passed++;console.log('PASS authority returns actual effective grants');
  await online(true,'fresh heartbeat admits online availability');
  const retry=(await db.query(refresh)).rows[0].authority;assert.equal(retry.permit_id,first.permit_id);passed++;console.log('PASS writer refresh retains stable permit identity');
  await deny('second device cannot become simultaneous writer',`SELECT public.refresh_cashier_writer('${lounge}','20000000-0000-0000-0000-000000000002',true)`,'55000');
  await db.exec(`RESET ROLE;UPDATE private.cashier_writer_authorities SET heartbeat_expires_at=now()-interval '1 second';SET ROLE authenticated;`);
  await online(false,'expired heartbeat closes online availability');
  await deny('expired heartbeat never authorizes device takeover',`SELECT public.refresh_cashier_writer('${lounge}','20000000-0000-0000-0000-000000000002',true)`,'55000');
  await db.query(refresh);
  await db.query(`SELECT public.refresh_cashier_writer('${lounge}','${device}',false)`);
  await online(false,'explicit offline mode closes online availability');
  await db.exec(`RESET ROLE;UPDATE public.lounges SET status='pending';SET ROLE authenticated;`);
  await deny('pending venue cannot receive offline authority',refresh,'42501');await online(false,'pending venue remains closed online');
  await db.exec(`RESET ROLE;UPDATE public.lounges SET status='active';SET ROLE authenticated;`);
  await db.query(refresh);
  await online(true,'approved writer can restore fresh availability');
  await db.exec(`RESET ROLE;UPDATE public.profiles SET is_banned=true WHERE id='${actor}';SET ROLE authenticated;`);
  await online(false,'banned writer closes availability immediately');
  await deny('banned cashier cannot refresh authority',refresh,'42501');
  await db.exec(`RESET ROLE;UPDATE public.profiles SET is_banned=false,is_active=false WHERE id='${actor}';SET ROLE authenticated;`);
  await deny('disabled cashier cannot refresh authority',refresh,'42501');
  await db.exec(`RESET ROLE;UPDATE public.profiles SET is_active=true WHERE id='${actor}';DELETE FROM auth.users WHERE id='${actor}';SET ROLE authenticated;`);
  await deny('deleted Auth identity cannot refresh authority',refresh,'42501');
  await deny('client cannot edit writer rows','UPDATE private.cashier_writer_authorities SET online_requested=true','42501');
  await db.exec(`RESET ROLE;SET ROLE anon;`);
  await deny('anonymous writer execution revoked',refresh,'42501');await online(false,'public availability remains readable and narrow');
  if (db.connect) {
    const secondLounge='10000000-0000-0000-0000-000000000002';
    await db.exec(`RESET ROLE; INSERT INTO auth.users VALUES('${actor}');
      UPDATE public.profiles SET is_active=true,is_banned=false WHERE id='${actor}';
      INSERT INTO public.lounges VALUES('${secondLounge}','active',true,true);
      INSERT INTO public.fixture_permissions VALUES('${actor}','${secondLounge}','sessions_control');`);
    const a=await db.connect(); const b=await db.connect();
    try {
      for (const peer of [a,b]) await peer.query(`SET test.actor='${actor}';SET ROLE authenticated;SET statement_timeout='10s';`);
      await a.query('BEGIN');
      await a.query(`SELECT public.refresh_cashier_writer('${secondLounge}','${device}',true)`);
      const pid=(await b.query('SELECT pg_backend_pid() AS pid')).rows[0].pid;
      const pending=b.query(`SELECT public.refresh_cashier_writer('${secondLounge}','20000000-0000-0000-0000-000000000002',true)`)
        .then(value=>({value}),error=>({error}));
      let blocked=false; const deadline=Date.now()+5000;
      while (Date.now()<deadline) {
        const activity=(await db.query('SELECT wait_event_type FROM pg_stat_activity WHERE pid=$1',[pid])).rows[0];
        if (activity?.wait_event_type==='Lock') {blocked=true;break;}
        await new Promise(resolve=>setTimeout(resolve,10));
      }
      assert.equal(blocked,true,'Second device must actually wait on the writer claim');
      await a.query('COMMIT');
      assert.equal((await pending).error?.code,'55000');
      const row=(await db.query('SELECT device_id FROM private.cashier_writer_authorities WHERE lounge_id=$1',[secondLounge])).rows[0];
      assert.equal(row.device_id,device);
      passed++;console.log('PASS simultaneous distinct device claims admit exactly one writer');
    } finally {await a.query('ROLLBACK');await a.end();await b.end();}
  }
  const room='50000000-0000-0000-0000-000000000001';
  await db.exec(`RESET ROLE;INSERT INTO public.rooms VALUES('${room}','${lounge}');
    INSERT INTO public.fixture_permissions VALUES('${actor}','${lounge}','bookings.manage');
    UPDATE private.cashier_writer_authorities SET online_requested=true,heartbeat_expires_at=now()+interval '90 seconds' WHERE lounge_id='${lounge}';`);
  await actorAs(other);
  const insert=`INSERT INTO public.bookings(user_id,lounge_id,room_id) VALUES('${other}','${lounge}','${room}')`;
  await db.query(insert);passed++;console.log('PASS fresh online venue accepts customer booking');
  await db.exec(`RESET ROLE;UPDATE private.cashier_writer_authorities SET heartbeat_expires_at=now()-interval '1 second' WHERE lounge_id='${lounge}';SET ROLE authenticated;`);
  await deny('expired heartbeat blocks actual booking insertion',insert,'55000');
  await deny('expired heartbeat blocks confirmation of an earlier pending booking',`UPDATE public.bookings SET status='upcoming' WHERE user_id='${other}'`,'55000');
  await deny('expired heartbeat blocks rescheduling to new capacity',`UPDATE public.bookings SET start_time='11:00' WHERE user_id='${other}'`,'55000');
  await db.query(`UPDATE public.bookings SET status='cancelled' WHERE user_id='${other}'`);
  passed++;console.log('PASS offline availability does not block cancelling an existing booking');
  await deny('omitted lounge cannot bypass offline room guard',`INSERT INTO public.bookings(user_id,room_id) VALUES('${other}','${room}')`,'55000');
  await deny('forged lounge cannot bypass room ownership guard',`INSERT INTO public.bookings(user_id,lounge_id,room_id) VALUES('${other}','10000000-0000-0000-0000-000000000002','${room}')`,'42501');
  await actorAs(actor);
  await deny('ordinary cashier cannot bypass offline gate without server proof',`INSERT INTO public.bookings(lounge_id,room_id) VALUES('${lounge}','${room}')`,'55000');
  await deny('client cannot forge reconciliation transaction proof',`INSERT INTO private.cashier_sync_context VALUES(txid_current(),'${lounge}','${actor}',gen_random_uuid())`,'42501');
  await db.exec(`RESET ROLE;BEGIN;INSERT INTO private.cashier_sync_context SELECT txid_current(),lounge_id,actor_id,permit_id FROM private.cashier_writer_authorities WHERE lounge_id='${lounge}';SET ROLE authenticated;`);
  await db.query(`INSERT INTO public.bookings(lounge_id,room_id) VALUES('${lounge}','${room}')`);
  await db.exec('COMMIT');passed++;console.log('PASS trusted transaction proof allows reviewed reconciliation insertion');
  await deny('committed proof cannot be reused by another transaction',`INSERT INTO public.bookings(lounge_id,room_id) VALUES('${lounge}','${room}')`,'55000');
  await db.exec(`RESET ROLE;UPDATE public.profiles SET role='super_admin' WHERE id='${actor}';
    DELETE FROM public.fixture_permissions WHERE actor='${actor}';SET ROLE authenticated;`);
  const adminAuthority=(await db.query(refresh)).rows[0].authority;
  assert.deepEqual(adminAuthority.permissions,{'bookings.manage':true,sessions_control:true,billing_checkout:true});
  passed++;console.log('PASS canonical active super admin receives effective offline permissions');
  await db.query(`SELECT public.refresh_cashier_writer('${lounge}','${device}',false)`);
  await db.exec(`RESET ROLE;BEGIN;INSERT INTO private.cashier_sync_context SELECT txid_current(),lounge_id,actor_id,permit_id
    FROM private.cashier_writer_authorities WHERE lounge_id='${lounge}';SET ROLE authenticated;`);
  await db.query(`INSERT INTO public.bookings(lounge_id,room_id) VALUES('${lounge}','${room}')`);
  await db.exec('COMMIT');passed++;console.log('PASS canonical super admin uses trusted offline booking proof without a staff grant');
  await db.exec(`RESET ROLE;UPDATE public.profiles SET role='cashier' WHERE id='${actor}';
    INSERT INTO public.platform_super_admins VALUES('${actor}');SET ROLE authenticated;`);
  const listedAuthority=(await db.query(refresh)).rows[0].authority;
  assert.deepEqual(listedAuthority.permissions,{'bookings.manage':true,sessions_control:true,billing_checkout:true});
  passed++;console.log('PASS canonical listed super admin receives effective offline permissions');
  await db.exec(`RESET ROLE;UPDATE public.profiles SET is_banned=true WHERE id='${actor}';SET ROLE authenticated;`);
  await deny('banned listed super admin cannot issue offline permissions',refresh,'42501');
  await online(false,'banned listed super admin closes online availability');
  await db.exec(`RESET ROLE;UPDATE public.profiles SET is_banned=false,is_active=false WHERE id='${actor}';SET ROLE authenticated;`);
  await deny('disabled listed super admin cannot issue offline permissions',refresh,'42501');
  await db.exec(`RESET ROLE;UPDATE public.profiles SET is_active=true WHERE id='${actor}';
    DELETE FROM public.platform_super_admins WHERE user_id='${actor}';SET ROLE authenticated;`);
  await deny('removed platform membership does not leave stale admin permissions',refresh,'42501');
  await online(false,'removed admin membership closes online availability');
  if(db.connect) {
    await db.exec(`RESET ROLE;INSERT INTO public.fixture_permissions VALUES('${actor}','${lounge}','sessions_control')`);
    for(const change of [`UPDATE public.profiles SET is_banned=true WHERE id='${actor}'`,
      `DELETE FROM auth.users WHERE id='${actor}'`]) {
      await db.exec(`RESET ROLE;UPDATE public.profiles SET is_active=true,is_banned=false WHERE id='${actor}'`);
      const [issued,revoked]=await lockedRace(db,{sql:refresh,args:[]},{sql:'RESET ROLE;'+change,args:[]},actor);
      assert.equal(issued.rows[0].authority.actor_id,actor);assert.equal(revoked.error,undefined);
      await actorAs(actor);await online(false,'identity revocation waits for issuance then closes availability: '+change.split(' ')[0]);
    }
  }
  console.log(JSON.stringify({passed,limitations:['Synthetic schema and permission helper','Discovery/checkout/hold responses still need availability wiring','Proof creation here uses admin; actual apply RPC has a separate integrated suite','No hosted writes','Concurrency exercised only on native PostgreSQL']}));
} finally {await db.close();}
