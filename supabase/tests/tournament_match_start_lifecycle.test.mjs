import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {createFixtureDatabase} from './runtime/database.mjs';
const db=await createFixtureDatabase();
const id=n=>`00000000-0000-0000-0000-${String(n).padStart(12,'0')}`;
let passed=0;
async function check(name,body){
  await db.exec('BEGIN');
  try{await body();passed++;console.log('PASS '+name);}finally{await db.exec('ROLLBACK');}
}
async function denied(action,code){
  await db.exec('SAVEPOINT expected_error');
  try{await assert.rejects(action,e=>e.code===code);}
  finally{await db.exec('ROLLBACK TO SAVEPOINT expected_error; RELEASE SAVEPOINT expected_error');}
}
async function fixture(){
  await db.query(`INSERT INTO public.tournaments(id,lounge_id,status,tournament_starts_at)
    VALUES($1,$2,'draw_completed',now()-interval '1 minute')`,[id(1),id(2)]);
  await db.query('INSERT INTO public.tournament_participants VALUES($1,$2),($3,$4)',[id(101),id(201),id(102),id(202)]);
  await db.query(`INSERT INTO public.tournament_matches(id,tournament_id,round_number,match_order,player1_id,player2_id)
    VALUES($1,$2,1,1,$3,$4)`,[id(301),id(1),id(101),id(102)]);
  await db.exec(`SET test.active='true'; SET test.manager='true'`);
  await db.query("SELECT set_config('test.actor',$1,true)",[id(201)]);
}
async function start(){return (await db.query('SELECT * FROM public.start_tournament_match($1,NULL)',[id(301)])).rows[0];}
async function submit(){return (await db.query('SELECT * FROM public.submit_match_result($1,3,1,NULL)',[id(301)])).rows[0];}
try{
  await db.exec(await readFile(new URL('./fixtures/tournament_progression_fixture.sql',import.meta.url),'utf8'));
  await db.exec(`ALTER TABLE public.tournaments ADD COLUMN tournament_starts_at timestamptz;
    ALTER TABLE public.tournament_matches ADD COLUMN room_id uuid,ADD COLUMN started_at timestamptz,
      ADD COLUMN proof_image_url text,ADD COLUMN result_submitted_at timestamptz,ADD COLUMN confirmation_deadline timestamptz;
    CREATE TABLE public.rooms(id uuid PRIMARY KEY,lounge_id uuid,is_active boolean,status text);
    CREATE FUNCTION private.require_active_booking_actor() RETURNS void LANGUAGE plpgsql AS $$
      BEGIN IF current_setting('test.active',true)='false' THEN RAISE EXCEPTION 'inactive_actor' USING ERRCODE='42501'; END IF; END $$;`);
  await db.exec(await readFile(new URL('../migrations/20261015193610_tournament_resolved_bracket_progression.sql',import.meta.url),'utf8'));
  await db.exec(await readFile(new URL('../migrations/20261016103116_tournament_match_start_lifecycle.sql',import.meta.url),'utf8'));
  await check('starting a ready match advances the tournament to in_progress',async()=>{
    await fixture();const match=await start();
    assert.equal(match.status,'in_progress');assert.ok(match.started_at);
    assert.equal((await db.query('SELECT status FROM public.tournaments')).rows[0].status,'in_progress');
  });
  await check('server start time blocks both starting and result submission',async()=>{
    await fixture();await db.exec("UPDATE public.tournaments SET tournament_starts_at=now()+interval '1 hour'");
    await denied(start,'55000');await denied(submit,'55000');
    assert.equal((await db.query('SELECT status FROM public.tournament_matches')).rows[0].status,'scheduled');
  });
  for(const status of ['draft','check_in_open','completed','cancelled']) await check(`${status} cannot start a match`,async()=>{
    await fixture();await db.query('UPDATE public.tournaments SET status=$1',[status]);await denied(start,'55000');
  });
  await check('a scheduled match cannot bypass management start by submitting a result',async()=>{
    await fixture();await denied(submit,'55000');
  });
  await check('a missing opponent prevents match start',async()=>{
    await fixture();await db.exec('UPDATE public.tournament_matches SET player2_id=NULL');await denied(start,'55000');
  });
  await check('a foreign or inactive assigned room is rejected',async()=>{
    await fixture();await db.query("INSERT INTO public.rooms VALUES($1,$2,false,'active')",[id(401),id(2)]);
    await db.query('UPDATE public.tournament_matches SET room_id=$1',[id(401)]);await denied(start,'22023');
    await db.exec('UPDATE public.rooms SET is_active=true');
    await db.query('UPDATE public.rooms SET lounge_id=$1',[id(3)]);await denied(start,'22023');
  });
  await check('unauthenticated, inactive and unauthorized actors cannot start',async()=>{
    await fixture();await db.exec("SET test.actor=''");await denied(start,'28000');
    await db.query("SELECT set_config('test.actor',$1,true)",[id(201)]);
    await db.exec("SET test.active='false'");await denied(start,'42501');
    await db.exec("SET test.active='true'; SET test.manager='false'");await denied(start,'42501');
  });
  await check('a second start neither resets the clock nor duplicates its audit',async()=>{
    await fixture();const before=await start();await denied(start,'55000');
    const after=(await db.query('SELECT * FROM public.tournament_matches')).rows[0];
    assert.equal(after.started_at.toISOString(),before.started_at.toISOString());
    assert.equal((await db.query("SELECT count(*)::int n FROM public.fixture_audit WHERE event='match_started'")).rows[0].n,1);
  });
  await check('started match supports submit and opponent confirmation',async()=>{
    await fixture();await start();assert.equal((await submit()).status,'pending_confirmation');
    await db.exec("SET test.manager='false'");
    await denied(()=>db.query('SELECT public.confirm_match_result($1)',[id(301)]),'42501');
    await db.query("SELECT set_config('test.actor',$1,true)",[id(202)]);
    await db.exec("SET test.manager='false'");
    await db.query('SELECT public.confirm_match_result($1)',[id(301)]);
    assert.equal((await db.query('SELECT winner_id FROM public.tournament_matches')).rows[0].winner_id,id(101));
  });
  await check('deadline worker confirms only once and never changes a closed tournament',async()=>{
    await fixture();await start();await submit();
    await db.exec("UPDATE public.tournament_matches SET confirmation_deadline=now()-interval '1 minute'");
    assert.equal((await db.query('SELECT public.auto_confirm_tournament_results() n')).rows[0].n,1);
    assert.equal((await db.query('SELECT public.auto_confirm_tournament_results() n')).rows[0].n,0);
    await db.exec("UPDATE public.tournament_matches SET status='pending_confirmation'; UPDATE public.tournaments SET status='cancelled'");
    assert.equal((await db.query('SELECT public.auto_confirm_tournament_results() n')).rows[0].n,0);
  });
  await check('deadline worker has no client execute privileges',async()=>{
    for(const role of ['anon','authenticated'])
      assert.equal((await db.query("SELECT has_function_privilege($1,'public.auto_confirm_tournament_results()','EXECUTE') allowed",[role])).rows[0].allowed,false);
    for(const role of ['service_role','supabase_auth_admin'])
      assert.equal((await db.query("SELECT has_function_privilege($1,'public.auto_confirm_tournament_results()','EXECUTE') allowed",[role])).rows[0].allowed,true);
  });
  // Real parallel database sessions, not a timing-only simulation.
  await db.exec('BEGIN');
  await fixture();await start();await submit();
  await db.exec("UPDATE public.tournament_matches SET confirmation_deadline=now()-interval '1 minute'");
  await db.exec('COMMIT');
  const peer=await db.connect();
  try{
    await peer.query('BEGIN');await peer.query('SELECT id FROM public.tournaments WHERE id=$1 FOR NO KEY UPDATE',[id(1)]);
    await db.exec("SET lock_timeout='300ms'");
    assert.equal((await db.query('SELECT public.auto_confirm_tournament_results() n')).rows[0].n,0);
    passed++;console.log('PASS deadline worker skips a tournament locked by another writer');
  }finally{await peer.query('ROLLBACK');await peer.end();}
  console.log(JSON.stringify({passed,hostedConnections:0}));
}finally{await db.close();}
