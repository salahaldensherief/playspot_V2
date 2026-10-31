import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {createFixtureDatabase} from './runtime/database.mjs';

const db=await createFixtureDatabase();
const id=n=>`00000000-0000-0000-0000-${String(n).padStart(12,'0')}`;
let passed=0;
async function check(name,body) {
  await db.exec('BEGIN');
  try {await body(); passed++;console.log('PASS '+name);}
  finally {await db.exec('ROLLBACK');}
}
async function bracket(count) {
  await db.exec(`INSERT INTO public.tournaments(id,lounge_id,status) VALUES('${id(10)}','${id(11)}','draw_completed')`);
  for(let i=1;i<=count;i++) await db.query('INSERT INTO public.tournament_participants VALUES($1,$2)',[id(100+i),id(200+i)]);
  let offset=0;
  for(let round=1;round<=3;round++) {
    for(let order=1;order<=8/(2**round);order++) {
      offset++;
      const next=round===1?4+Math.ceil(order/2):round===2?7:null;
      await db.query(`INSERT INTO public.tournament_matches(id,tournament_id,round_number,match_order,next_match_id,next_match_slot)
        VALUES($1,$2,$3,$4,$5,$6)`,[id(300+offset),id(10),round,order,next?id(300+next):null,next?(order%2?1:2):null]);
    }
  }
  for(let order=1;order<=4;order++) await db.query('UPDATE public.tournament_matches SET player1_id=$1,player2_id=$2 WHERE id=$3',[
    order*2-1<=count?id(100+order*2-1):null,order*2<=count?id(100+order*2):null,id(300+order)]);
  await db.query('SELECT public.apply_tournament_walkovers($1)',[id(10)]);
}
async function confirm(match) {
  const user=(await db.query('SELECT user_id FROM public.tournament_participants WHERE id=$1',[match.player2_id])).rows[0].user_id;
  await db.query('UPDATE public.tournament_matches SET status=$1,score_player1=3,score_player2=1 WHERE id=$2',['pending_confirmation',match.id]);
  await db.query("SELECT set_config('test.actor',$1,true)",[user]);
  await db.exec("SET test.manager='false'");
  await db.query('SELECT public.confirm_match_result($1)',[match.id]);
  await db.exec("SET test.manager='true'");
}
try {
  await db.exec(await readFile(new URL('./fixtures/tournament_progression_fixture.sql',import.meta.url),'utf8'));
  await db.exec(await readFile(new URL('../migrations/20261015193610_tournament_resolved_bracket_progression.sql',import.meta.url),'utf8'));
  for(const count of [2,3,4,5,6,7,8]) await check(`${count} players advance through every required match and empty branch`,async()=>{
    await bracket(count);
    assert.equal((await db.query('SELECT winner_id FROM public.tournament_matches WHERE id=$1',[id(307)])).rows[0].winner_id,null);
    let played=0;
    while(true) {
      const ready=(await db.query("SELECT * FROM public.tournament_matches WHERE status='scheduled' AND player1_id IS NOT NULL AND player2_id IS NOT NULL ORDER BY round_number,match_order LIMIT 1")).rows[0];
      if(!ready) break;
      await confirm(ready);played++;
    }
    assert.equal(played,count-1);
    assert.equal((await db.query("SELECT count(*)::int n FROM public.tournament_matches WHERE status='scheduled'")).rows[0].n,0);
    const final=(await db.query('SELECT * FROM public.tournament_matches WHERE id=$1',[id(307)])).rows[0];
    assert.ok(final.winner_id);
    const completed=(await db.query('SELECT (public.complete_tournament($1)).*',[id(10)])).rows[0];
    assert.equal(completed.status,'completed');
    assert.equal(completed.champion_participant_id,final.winner_id);
    const auditCount=Number((await db.query("SELECT count(*) n FROM public.fixture_audit WHERE event='tournament_completed'")).rows[0].n);
    await db.query('SELECT public.complete_tournament($1)',[id(10)]);
    assert.equal(Number((await db.query("SELECT count(*) n FROM public.fixture_audit WHERE event='tournament_completed'")).rows[0].n),auditCount);
  });
  await check('a scheduled match cannot be resolved as a dispute',async()=>{
    await bracket(8);
    await assert.rejects(db.query('SELECT public.resolve_tournament_dispute($1,$2,3,1,$3)',[id(301),id(101),'reviewed']),e=>e.code==='55000');
  });
  await check('a disputed winner must agree with the scores',async()=>{
    await bracket(8);
    await db.query("UPDATE public.tournament_matches SET status='disputed' WHERE id=$1",[id(301)]);
    await assert.rejects(db.query('SELECT public.resolve_tournament_dispute($1,$2,3,1,$3)',[id(301),id(102),'reviewed']),e=>e.code==='22023');
  });
  await check('a manager can resolve a genuine dispute and the winner advances',async()=>{
    await bracket(2);
    await db.query("UPDATE public.tournament_matches SET status='disputed' WHERE id=$1",[id(301)]);
    await db.query('SELECT public.resolve_tournament_dispute($1,$2,3,1,$3)',[id(301),id(101),'reviewed']);
    const completed=(await db.query('SELECT (public.complete_tournament($1)).*',[id(10)])).rows[0];
    assert.equal(completed.champion_participant_id,id(101));
  });
  await check('a completed tournament cannot reopen',async()=>{
    await bracket(8);
    await db.exec("UPDATE public.tournaments SET status='completed'");
    await assert.rejects(db.query('SELECT public.publish_tournament($1,true)',[id(10)]),e=>e.code==='55000');
  });
  await check('an actor without management authority cannot publish',async()=>{
    await bracket(8);
    await db.exec("SET test.manager='false'");
    await assert.rejects(db.query('SELECT public.publish_tournament($1,true)',[id(10)]),e=>e.code==='42501');
  });
  await check('ordinary clients cannot manufacture walkovers directly',async()=>{
    assert.equal((await db.query("SELECT has_function_privilege('authenticated','public.apply_tournament_walkovers(uuid)','EXECUTE') allowed")).rows[0].allowed,false);
  });
  console.log(JSON.stringify({passed,synthetic:true,hostedConnections:0,limitations:['Permission helpers are synthetic; full Auth/RLS integration is tested separately']}));
} finally {await db.close();}
