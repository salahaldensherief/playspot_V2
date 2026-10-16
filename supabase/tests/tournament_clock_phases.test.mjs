import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {createFixtureDatabase} from './runtime/database.mjs';

const db=await createFixtureDatabase();
const id=n=>`00000000-0000-0000-0000-${String(n).padStart(12,'0')}`;
let passed=0;
async function check(name,body){
  await db.exec('BEGIN');
  try{await body();passed++;console.log('PASS '+name);}
  finally{await db.exec('ROLLBACK');}
}
async function advance(){return (await db.query('SELECT private.advance_tournament_clock_phases() n')).rows[0].n;}
async function insert(status,opens,closes,checkOpens,checkCloses,n=10){
  await db.query(`INSERT INTO public.tournaments(id,lounge_id,status,registration_opens_at,registration_closes_at,check_in_opens_at,check_in_closes_at)
    VALUES($1,$2,$3,now()+$4::interval,now()+$5::interval,now()+$6::interval,now()+$7::interval)`,[id(n),id(1),status,opens,closes,checkOpens,checkCloses]);
}
async function status(n=10){return (await db.query('SELECT status FROM public.tournaments WHERE id=$1',[id(n)])).rows[0].status;}
try{
  await db.exec(await readFile(new URL('./fixtures/tournament_progression_fixture.sql',import.meta.url),'utf8'));
  await db.exec('ALTER TABLE public.tournaments ADD registration_opens_at timestamptz,ADD registration_closes_at timestamptz,ADD check_in_opens_at timestamptz,ADD check_in_closes_at timestamptz');
  const sql=await readFile(new URL('../migrations/20261015220755_tournament_clock_phase_transitions.sql',import.meta.url),'utf8');
  // Test the real worker in native Postgres; job scheduling is independently
  // exercised in the contained full Supabase stack with pg_cron installed.
  await db.exec(sql.slice(0,sql.indexOf('-- pg_cron'))+'COMMIT;');
  for(const [initial,opens,closes,checkOpens,checkCloses,expected] of [
    ['draft','-4 hours','-3 hours','-2 hours','-1 hour','draft'],
    ['published','1 hour','2 hours','3 hours','4 hours','published'],
    ['published','-1 hour','1 hour','2 hours','3 hours','registration_open'],
    ['registration_open','-2 hours','-1 hour','1 hour','2 hours','registration_closed'],
    ['registration_closed','-3 hours','-2 hours','-1 hour','1 hour','check_in_open'],
    ['check_in_open','-4 hours','-3 hours','-2 hours','-1 hour','check_in_closed'],
    ['published','-4 hours','-3 hours','-2 hours','-1 hour','check_in_closed'],
  ])await check(`${initial} follows server dates to ${expected}`,async()=>{
    await insert(initial,opens,closes,checkOpens,checkCloses);
    await advance();assert.equal(await status(),expected);
  });
  for(const terminal of ['draw_completed','in_progress','completed','cancelled'])await check(`${terminal} is never reopened by the clock`,async()=>{
    await insert(terminal,'-4 hours','-3 hours','-2 hours','-1 hour');
    assert.equal(await advance(),0);assert.equal(await status(),terminal);
  });
  await check('repeated worker runs do not duplicate the same transition or audit',async()=>{
    await insert('published','-1 hour','1 hour','2 hours','3 hours');
    assert.equal(await advance(),1);assert.equal(await advance(),0);
    assert.equal((await db.query('SELECT count(*)::int n FROM public.fixture_audit')).rows[0].n,1);
  });
  await check('a delayed worker catches up to the latest phase in one transition',async()=>{
    await insert('published','-4 hours','-3 hours','-2 hours','-1 hour');
    assert.equal(await advance(),1);assert.equal(await status(),'check_in_closed');
    assert.equal((await db.query('SELECT count(*)::int n FROM public.fixture_audit')).rows[0].n,1);
  });
  await check('client roles cannot invoke the private scheduler worker',async()=>{
    assert.equal((await db.query("SELECT has_function_privilege('authenticated','private.advance_tournament_clock_phases()','EXECUTE') allowed")).rows[0].allowed,false);
    assert.equal((await db.query("SELECT has_function_privilege('service_role','private.advance_tournament_clock_phases()','EXECUTE') allowed")).rows[0].allowed,false);
  });
  console.log(JSON.stringify({passed,synthetic:true,hostedConnections:0,jobSchedulerTestedSeparately:true}));
}finally{await db.close();}
