import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { test } from 'node:test';
import { compare } from './compare_schema_fingerprints.mjs';

const reference = JSON.parse(readFileSync(fileURLToPath(new URL('./deployed_schema_fingerprint_20261024.json', import.meta.url)), 'utf8'));

test('deployed reference records the real financial contract surface', () => {
  assert.equal(reference.format, 1);
  assert.equal(reference.server_major, 17);
  assert.equal(Object.keys(reference.objects).length, 3607);
  assert.equal(Object.keys(reference.objects).filter(key => key.startsWith('trigger/public/bookings/')).length, 23);
  assert.ok(reference.objects['constraint/public/payments/payments_booking_id_unique']);
  assert.deepEqual(compare(reference, structuredClone(reference)), []);
});

test('restore comparison identifies missing, extra and changed objects', () => {
  const candidate = structuredClone(reference);
  delete candidate.objects['constraint/public/payments/payments_booking_id_unique'];
  candidate.objects['relation/public/bookings'] = '00000000000000000000000000000000';
  candidate.objects['relation/public/unexpected'] = '00000000000000000000000000000000';
  assert.deepEqual(compare(reference, candidate), [
    'Missing: constraint/public/payments/payments_booking_id_unique',
    'Changed: relation/public/bookings',
    'Extra: relation/public/unexpected',
  ]);
});

test('restore comparison refuses different Postgres major versions', () => {
  const candidate = structuredClone(reference);
  candidate.server_major = 16;
  assert.deepEqual(compare(reference, candidate), ['Postgres major: 17 != 16']);
});
