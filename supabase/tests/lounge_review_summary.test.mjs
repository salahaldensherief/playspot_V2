import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {createFixtureDatabase} from './runtime/database.mjs';

const db = await createFixtureDatabase();
const migration = await readFile(
  new URL('../migrations/20261020151000_sync_lounge_review_summary.sql', import.meta.url),
  'utf8',
);
const lounge = '00000000-0000-0000-0000-000000000001';
const secondLounge = '00000000-0000-0000-0000-000000000002';
const review = '00000000-0000-0000-0000-000000000003';

async function summary(id = lounge) {
  return (await db.query(
    'SELECT total_reviews, rating::numeric AS rating FROM public.lounges WHERE id = $1',
    [id],
  )).rows[0];
}

try {
  await db.exec(`
    CREATE TABLE public.lounges (id uuid PRIMARY KEY, total_reviews integer DEFAULT 0, rating numeric DEFAULT 0);
    CREATE TABLE public.lounge_reviews (id uuid PRIMARY KEY, lounge_id uuid NOT NULL REFERENCES public.lounges(id), rating numeric NOT NULL);
    INSERT INTO public.lounges (id,total_reviews,rating) VALUES
      ('${lounge}', 0, 4.125), ('${secondLounge}', 126, 5);
    INSERT INTO public.lounge_reviews (id,lounge_id,rating) VALUES
      ('${review}','${lounge}',4);
  `);
  await db.exec(migration);
  assert.equal((await summary()).total_reviews, 1);
  assert.equal((await summary(secondLounge)).total_reviews, 0);
  assert.equal(Number((await summary(secondLounge)).rating), 0);

  await db.query('INSERT INTO public.lounge_reviews VALUES ($1,$2,$3)',
    ['00000000-0000-0000-0000-000000000004', lounge, 2]);
  assert.equal((await summary()).total_reviews, 2);
  assert.equal(Number((await summary()).rating), 3);

  await db.query('UPDATE public.lounge_reviews SET rating = 5 WHERE id = $1', [review]);
  assert.equal(Number((await summary()).rating), 3.5);

  await db.query('UPDATE public.lounge_reviews SET lounge_id = $1 WHERE id = $2',
    [secondLounge, review]);
  assert.equal((await summary()).total_reviews, 1);
  assert.equal((await summary(secondLounge)).total_reviews, 1);

  await db.query('DELETE FROM public.lounge_reviews WHERE id = $1', [review]);
  assert.equal((await summary(secondLounge)).total_reviews, 0);
  assert.equal(Number((await summary(secondLounge)).rating), 0);
  console.log('PASS lounge review summary backfill and insert/update/delete sync');
} finally {
  await db.close();
}
