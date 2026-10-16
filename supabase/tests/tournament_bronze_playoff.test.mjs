import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {createFixtureDatabase} from './runtime/database.mjs';

const db = await createFixtureDatabase();
const id = n => `00000000-0000-0000-0000-${String(n).padStart(12, '0')}`;
let passed = 0;
async function check(name, body) {
  await db.exec('BEGIN');
  try { await body(); passed++; console.log('PASS ' + name); }
  finally { await db.exec('ROLLBACK'); }
}
async function draw(count, size = 8) {
  await db.query(`INSERT INTO public.tournaments(id,lounge_id,status,bracket_size)
    VALUES($1,$2,'check_in_closed',$3)`, [id(1), id(2), size]);
  for (let n = 1; n <= count; n++) await db.query(`INSERT INTO public.tournament_participants
    (id,user_id,tournament_id,payment_status,is_checked_in,registration_status)
    VALUES($1,$2,$3,'paid',true,'checked_in')`, [id(100+n),id(200+n),id(1)]);
  return (await db.query('SELECT public.draw_tournament_bracket($1) n',[id(1)])).rows[0].n;
}
async function finish(match, dispute = false) {
  await db.query(`UPDATE public.tournament_matches SET status=$1,score_player1=3,score_player2=1 WHERE id=$2`,
    [dispute ? 'disputed' : 'pending_confirmation',match.id]);
  if (dispute) await db.query('SELECT public.resolve_tournament_dispute($1,$2,3,1,$3)',[match.id,match.player1_id,'Evidence reviewed']);
  else await db.query('SELECT public.confirm_match_result($1)',[match.id]);
}
async function allMatches() { return (await db.query('SELECT * FROM public.tournament_matches ORDER BY round_number,match_order')).rows; }
async function finishBracket() {
  let played = 0;
  while (true) {
    const match = (await allMatches()).find(m => m.match_type === 'bracket' && m.status === 'scheduled' && m.player1_id && m.player2_id);
    if (!match) break;
    await finish(match); played++;
  }
  return played;
}
try {
  await db.exec(await readFile(new URL('./fixtures/tournament_progression_fixture.sql',import.meta.url),'utf8'));
  await db.exec(`ALTER TABLE public.tournaments ADD COLUMN bracket_size integer;
    ALTER TABLE public.tournament_participants ADD COLUMN tournament_id uuid,
      ADD COLUMN payment_status text, ADD COLUMN is_checked_in boolean, ADD COLUMN registration_status text;
    ALTER TABLE public.tournament_matches ALTER COLUMN id SET DEFAULT gen_random_uuid();
    CREATE FUNCTION private.require_active_booking_actor() RETURNS void LANGUAGE plpgsql AS $$ BEGIN END $$;`);
  await db.exec(await readFile(new URL('../migrations/20261015193610_tournament_resolved_bracket_progression.sql',import.meta.url),'utf8'));
  await db.exec(await readFile(new URL('../migrations/20261015223039_tournament_balanced_draw_bronze_playoff.sql',import.meta.url),'utf8'));
  for (const size of [8,16,32]) for (const count of [...new Set([2,3,4,5,6,7,8,size-1,size])]) {
    await check(`${count}/${size}: balanced final, real bronze opponents and exact podium`,async()=>{
      assert.equal(await draw(count,size), size-1 + (count>=4 ? 1 : 0));
      const before = await allMatches();
      const bronzeBefore = before.find(m => m.match_type==='third_place');
      if(count>=4) { assert.equal(bronzeBefore.status,'scheduled'); assert.equal(bronzeBefore.winner_id,null); }
      assert.equal(await finishBracket(),count-1);
      let rows=await allMatches();
      const final=rows.find(m => m.match_type==='bracket' && !m.next_match_id);
      assert.equal(final.status,'completed','two qualified halves must contest the final');
      assert.ok(final.player1_id && final.player2_id);
      const bronze=rows.find(m => m.match_type==='third_place');
      if(bronze) {
        assert.equal(bronze.status,'scheduled');
        const losers=rows.filter(m => m.match_type==='bracket' && m.round_number===final.round_number-1)
          .map(m => m.winner_id===m.player1_id ? m.player2_id : m.player1_id);
        assert.deepEqual([bronze.player1_id,bronze.player2_id],losers);
        assert.ok(losers.every(Boolean));
        await db.exec('SAVEPOINT premature');
        await assert.rejects(db.query('SELECT public.complete_tournament($1)',[id(1)]),e=>e.code==='55000');
        await db.exec('ROLLBACK TO SAVEPOINT premature');
        await finish(bronze);
      }
      await db.query('SELECT public.complete_tournament($1)',[id(1)]);
      const podium=(await db.query('SELECT * FROM public.tournament_placements ORDER BY placement')).rows;
      assert.equal(podium.length,Math.min(count,3));
      assert.equal(podium[0].participant_id,final.winner_id);
      assert.equal(podium[1].participant_id,final.player2_id);
      if(bronze) assert.equal(podium[2].participant_id,bronze.player1_id);
      assert.equal(new Set(podium.map(p=>p.participant_id)).size,podium.length);
      await db.query('SELECT public.complete_tournament($1)',[id(1)]);
      assert.equal((await db.query('SELECT count(*)::int n FROM public.tournament_placements')).rows[0].n,podium.length);
    });
  }
  await check('one resolved semifinal cannot prematurely award bronze',async()=>{
    await draw(4);
    const semi=(await allMatches()).find(m=>m.round_number===2 && m.match_type==='bracket');
    await finish(semi,true);
    const bronze=(await allMatches()).find(m=>m.match_type==='third_place');
    assert.equal(bronze.status,'scheduled'); assert.equal(bronze.winner_id,null);
    assert.equal(bronze.player1_id,null); assert.equal(bronze.player2_id,null);
  });
  await check('dispute resolution supplies the actual loser to the playoff',async()=>{
    await draw(4);
    for(const semi of (await allMatches()).filter(m=>m.round_number===2 && m.match_type==='bracket')) await finish(semi,true);
    const rows=await allMatches(); const bronze=rows.find(m=>m.match_type==='third_place');
    assert.ok(bronze.player1_id && bronze.player2_id); assert.equal(bronze.winner_id,null);
    await finish(bronze,true);
    assert.equal((await allMatches()).find(m=>m.match_type==='third_place').winner_id,bronze.player1_id);
  });
  await check('outsider cannot draw and a repeated draw preserves existing rows',async()=>{
    await draw(4);
    const idsBefore=(await allMatches()).map(m=>m.id);
    await db.exec('SAVEPOINT denied');
    await assert.rejects(db.query('SELECT public.draw_tournament_bracket($1)',[id(1)]),e=>e.code==='55000');
    await db.exec('ROLLBACK TO SAVEPOINT denied');
    await db.exec("SET test.manager='false'");
    await assert.rejects(db.query('SELECT public.draw_tournament_bracket($1)',[id(1)]),e=>e.code==='42501');
    await db.exec('ROLLBACK TO SAVEPOINT denied');
    assert.deepEqual((await allMatches()).map(m=>m.id),idsBefore);
  });
  await check('a historical drawn bracket is not rebuilt or assigned an arbitrary third place',async()=>{
    await draw(4);
    // A disposable fixture with the legacy seven-match shape, never hosted data.
    await db.exec("DELETE FROM public.tournament_matches WHERE match_type='third_place'");
    const existingIds=(await allMatches()).map(m=>m.id);
    await finishBracket();
    await db.query('SELECT public.complete_tournament($1)',[id(1)]);
    assert.deepEqual((await allMatches()).map(m=>m.id),existingIds);
    const podium=(await db.query('SELECT placement FROM public.tournament_placements ORDER BY placement')).rows;
    assert.deepEqual(podium.map(p=>p.placement),[1,2]);
  });
  console.log(JSON.stringify({passed,hostedConnections:0,limitations:['Synthetic permission helpers; real Auth/RLS integration is separate']}));
} finally { await db.close(); }
