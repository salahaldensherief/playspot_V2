// Disposable, synthetic schema only. Never loads project credentials or URLs.
import {readFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
import {createFixtureDatabase} from './runtime/database.mjs';
const db = await createFixtureDatabase();
let passed = 0;
const ids = Array.from({length: 8}, (_, i) => `00000000-0000-0000-0000-${String(i + 1).padStart(12,'0')}`);
const [l1,l2,room,provider,integration,actor] = ids;
async function check(name, body) { await body(); ++passed; console.log('PASS ' + name); }
try {
  await db.exec(`CREATE ROLE anon; CREATE ROLE authenticated;
    CREATE SCHEMA private; CREATE SCHEMA auth;
    CREATE TABLE auth.users(id uuid PRIMARY KEY);
    CREATE TABLE public.lounges(id uuid PRIMARY KEY);
    CREATE TABLE public.rooms(id uuid PRIMARY KEY, lounge_id uuid NOT NULL REFERENCES public.lounges(id));`);
  await db.exec(await readFile(process.env.PLAYSPOT_BRIDGE_SCHEMA_FILE ?? 'docs/bridge/proposed_schema.sql','utf8'));
  await db.exec(`INSERT INTO auth.users VALUES ('${actor}');
    INSERT INTO public.lounges VALUES ('${l1}'),('${l2}');
    INSERT INTO public.rooms VALUES ('${room}','${l1}');
    INSERT INTO private.integration_providers(id,slug,display_name,integration_kind)
      VALUES ('${provider}','fixture','Fixture','hybrid');
    INSERT INTO private.lounge_integrations(id,lounge_id,provider_id,channel)
      VALUES ('${integration}','${l1}','${provider}','hybrid');`);
  const columns = (await db.query(`SELECT column_name FROM information_schema.columns
    WHERE table_schema='private' AND table_name='integration_resource_mappings'`)).rows;
  const tenantColumn = columns.some(r => r.column_name === 'lounge_id');
  const mapping = tenant => `INSERT INTO private.integration_resource_mappings
    (integration_id,room_id,external_resource_id${tenantColumn ? ',lounge_id' : ''})
    VALUES ('${integration}','${room}','station'${tenantColumn ? `,'${tenant}'` : ''})`;
  await db.exec(mapping(l1));
  await check('integration parent tenant change is blocked', async () => {
    await assert.rejects(db.exec(`UPDATE private.lounge_integrations SET lounge_id='${l2}' WHERE id='${integration}'`),
      e => ['23503','23001'].includes(e.code));
  });
  await check('room parent tenant change is blocked', async () => {
    await assert.rejects(db.exec(`UPDATE public.rooms SET lounge_id='${l2}' WHERE id='${room}'`),e => ['23503','23001'].includes(e.code));
  });
  await check('cross-lounge mapping cannot be inserted', async () => {
    await db.exec(`INSERT INTO public.rooms VALUES ('${ids[6]}','${l2}')`);
    await assert.rejects(db.exec(`INSERT INTO private.integration_resource_mappings
      (integration_id,room_id,external_resource_id,lounge_id)
      VALUES ('${integration}','${ids[6]}','other-station','${l1}')`), e => e.code === '23503');
  });
  await check('same room or external resource cannot be remapped in an integration', async () => {
    await assert.rejects(db.exec(mapping(l1)),e=>e.code==='23505');
  });
  await check('every proposal table has RLS and denies client table privileges', async () => {
    const tables = (await db.query(`SELECT c.relname,c.relrowsecurity FROM pg_class c
      JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='private' AND c.relkind='r'`)).rows;
    assert.equal(tables.length,8);
    for (const t of tables) {
      assert.equal(t.relrowsecurity,true);
      for (const role of ['anon','authenticated']) for (const privilege of ['SELECT','INSERT','UPDATE','DELETE']) {
        const result=await db.query('SELECT has_table_privilege($1,$2,$3) AS allowed',[role,`private.${t.relname}`,privilege]);
        assert.equal(result.rows[0].allowed,false);
      }
    }
  });
  await check('actual client role cannot select or mutate operational tables', async () => {
    await db.exec('SET ROLE authenticated');
    await assert.rejects(db.exec('SELECT * FROM private.lounge_integrations'),e=>e.code==='42501');
    await assert.rejects(db.exec(`UPDATE private.lounge_integrations SET state='active'`),e=>e.code==='42501');
    await db.exec('RESET ROLE');
  });
  await check('unapproved integration defaults to draft and cannot become active', async () => {
    assert.equal((await db.query('SELECT state FROM private.lounge_integrations')).rows[0].state,'draft');
    await assert.rejects(db.exec(`UPDATE private.lounge_integrations SET state='active'`),e=>e.code==='23514');
  });
  await check('command idempotency keys are unique per integration', async () => {
    const sql=`INSERT INTO private.integration_command_queue(integration_id,idempotency_key,operation_type,request_payload)
      VALUES ('${integration}','key','reserve','{}')`;
    await db.exec(sql); await assert.rejects(db.exec(sql),e=>e.code==='23505');
  });
  console.log(`${passed} bridge proposal checks passed; synthetic fixture, not hosted RLS or full-schema compatibility.`);
} finally { await db.close(); }
