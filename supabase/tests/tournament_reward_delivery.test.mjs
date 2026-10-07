import {createFixtureDatabase} from './runtime/database.mjs';
import {readFile} from 'node:fs/promises';
import assert from 'node:assert/strict';

const db = await createFixtureDatabase();
const id = n => `00000000-0000-0000-0000-${String(n).padStart(12, '0')}`;
let passed = 0;
async function check(name, body) {
  await db.exec('BEGIN');
  try { await body(); passed++; console.log('PASS '+name); }
  finally { await db.exec('ROLLBACK'); }
}
async function award() {
  return (await db.query('SELECT award_tournament_prizes($1) count', [id(1)])).rows[0].count;
}
try {
  await db.exec(`
    CREATE ROLE anon; CREATE ROLE authenticated; CREATE ROLE service_role;
    CREATE SCHEMA private;
    CREATE FUNCTION public.is_super_admin() RETURNS boolean LANGUAGE sql AS $$ SELECT false $$;
    CREATE FUNCTION private.is_lounge_manager(uuid) RETURNS boolean LANGUAGE sql AS
      $$ SELECT current_setting('fixture.manager', true) = 'true' $$;
    CREATE FUNCTION public.tournament_audit(uuid,text,uuid,uuid,uuid,jsonb) RETURNS void LANGUAGE sql AS $$ SELECT $$;
    CREATE TABLE tournaments(id uuid PRIMARY KEY,lounge_id uuid,status text,title_en text,title_ar text);
    CREATE TABLE tournament_prizes(id uuid PRIMARY KEY,tournament_id uuid,placement integer,points integer,bonus integer);
    CREATE TABLE tournament_placements(tournament_id uuid,placement integer,participant_id uuid);
    CREATE TABLE tournament_participants(id uuid PRIMARY KEY,user_id uuid);
    CREATE TABLE tournament_prize_rewards(id uuid PRIMARY KEY,prize_id uuid,reward_type text,
      is_delivered boolean DEFAULT false,delivered_at timestamptz,updated_at timestamptz);
    CREATE TABLE points_transactions(user_id uuid,points integer,type text,reference_id uuid,description text,
      source_type text,source_id uuid,idempotency_key text UNIQUE,metadata jsonb);
    CREATE TABLE notifications(user_id uuid,lounge_id uuid,title_ar text,title_en text,body_ar text,body_en text,type text,metadata jsonb);
    INSERT INTO tournaments VALUES('${id(1)}','${id(2)}','completed','Fixture','Fixture');
    INSERT INTO tournament_prizes VALUES('${id(3)}','${id(1)}',1,100,20);
    INSERT INTO tournament_placements VALUES('${id(1)}',1,'${id(4)}');
    INSERT INTO tournament_participants VALUES('${id(4)}','${id(5)}');
    INSERT INTO tournament_prize_rewards(id,prize_id,reward_type) VALUES
      ('${id(6)}','${id(3)}','points'),('${id(7)}','${id(3)}','cash'),
      ('${id(8)}','${id(3)}','trophy'),('${id(9)}','${id(3)}','voucher'),('${id(10)}','${id(3)}','custom');
    SET fixture.manager='true';
  `);
  await db.exec(await readFile(new URL('../migrations/20261007000020_tournament_point_delivery_status.sql',import.meta.url),'utf8'));
  await check('points delivery follows the ledger; other rewards stay pending', async () => {
    assert.equal(await award(),1);
    assert.equal((await db.query('SELECT points FROM points_transactions')).rows[0].points,120);
    const rewards=(await db.query('SELECT * FROM tournament_prize_rewards')).rows;
    assert.equal(rewards.find(r=>r.reward_type==='points').is_delivered,true);
    assert.ok(rewards.find(r=>r.reward_type==='points').delivered_at);
    assert.ok(rewards.filter(r=>r.reward_type!=='points').every(r=>!r.is_delivered && !r.delivered_at));
    assert.equal(await award(),0);
    assert.equal((await db.query('SELECT count(*)::int count FROM points_transactions')).rows[0].count,1);
    assert.equal((await db.query('SELECT count(*)::int count FROM notifications')).rows[0].count,1);
  });
  await check('replaying an existing award repairs its points delivery without another credit',async () => {
    await award();
    await db.exec("UPDATE tournament_prize_rewards SET is_delivered=false,delivered_at=null WHERE reward_type='points'");
    assert.equal(await award(),0);
    assert.equal((await db.query("SELECT is_delivered FROM tournament_prize_rewards WHERE reward_type='points'")).rows[0].is_delivered,true);
    assert.equal((await db.query('SELECT count(*)::int count FROM points_transactions')).rows[0].count,1);
  });
  await check('a placement without a winner cannot be marked delivered',async () => {
    await db.exec('DELETE FROM tournament_placements');
    assert.equal(await award(),0);
    assert.ok((await db.query('SELECT is_delivered FROM tournament_prize_rewards')).rows.every(r=>!r.is_delivered));
  });
  await check('incomplete tournaments cannot award prizes',async () => {
    await db.exec("UPDATE tournaments SET status='in_progress'");
    await assert.rejects(award(),e=>e.message==='tournament_not_completed');
  });
  await check('an actor without lounge authority cannot award prizes',async () => {
    await db.exec("SET fixture.manager='false'");
    await assert.rejects(award(),e=>e.code==='42501');
  });
  console.log(JSON.stringify({passed,liveMutations:false,productionFunctions:true,limitations:['Synthetic ledger and permission helper; physical reward fulfillment is not automated']}));
} finally { await db.close(); }
