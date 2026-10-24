import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { test } from 'node:test';
import { createFixtureDatabase } from '../runtime/database.mjs';
import { compare } from './compare_schema_fingerprints.mjs';

test('catalog probe detects real PostgreSQL contract drift', async () => {
  const db = await createFixtureDatabase();
  try {
    const sql = await readFile(new URL('./schema_fingerprint.sql', import.meta.url), 'utf8');
    const probe = async () => JSON.parse((await db.query(sql)).rows[0].jsonb_build_object);
    const before = await probe();
    await db.exec(`
      CREATE TABLE public.fingerprint_probe (id integer PRIMARY KEY, amount numeric NOT NULL CHECK (amount >= 0));
      CREATE INDEX fingerprint_probe_amount_idx ON public.fingerprint_probe(amount);
      ALTER TABLE public.fingerprint_probe ENABLE ROW LEVEL SECURITY;
      CREATE POLICY fingerprint_probe_read ON public.fingerprint_probe FOR SELECT USING (true);
      CREATE FUNCTION public.fingerprint_touch() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RETURN NEW; END $$;
      CREATE TRIGGER fingerprint_probe_touch BEFORE INSERT ON public.fingerprint_probe
        FOR EACH ROW EXECUTE FUNCTION public.fingerprint_touch();
    `);
    const after = await probe();
    for (const key of [
      'relation/public/fingerprint_probe',
      'column/public/fingerprint_probe/amount',
      'index/public/fingerprint_probe_amount_idx',
      'policy/public/fingerprint_probe/fingerprint_probe_read',
      'trigger/public/fingerprint_probe/fingerprint_probe_touch',
      'function/public/fingerprint_touch()',
    ]) assert.ok(after.objects[key], `missing fingerprint: ${key}`);
    assert.ok(compare(before, after).includes('Extra: relation/public/fingerprint_probe'));
    await db.exec('ALTER TABLE public.fingerprint_probe ALTER COLUMN amount SET DEFAULT 0');
    const changed = await probe();
    assert.notEqual(changed.objects['column/public/fingerprint_probe/amount'], after.objects['column/public/fingerprint_probe/amount']);
    assert.ok(compare(after, changed).includes('Changed: column/public/fingerprint_probe/amount'));
  } finally {
    await db.close();
  }
});
