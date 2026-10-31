import assert from 'node:assert/strict';
import {createFixtureDatabase} from './runtime/database.mjs';
import {fixtureSessionStart} from './runtime/fixture_session_clock.mjs';

const db = await createFixtureDatabase();
try {
  for (const [name, now, expected] of [
    ['ordinary day retains original preference', '2026-10-28T22:30:00Z', '2026-10-28T20:30:00Z'],
    ['autumn repeated hour is avoided', '2026-10-29T22:30:00Z', '2026-10-29T17:30:00Z'],
    ['spring gap is avoided', '2026-04-23T23:30:00Z', '2026-04-23T19:30:00Z'],
  ]) {
    assert.equal(new Date(await fixtureSessionStart(db, Date.parse(now))).toISOString(),
      new Date(expected).toISOString(), name);
    console.log('PASS ' + name);
  }
  console.log(JSON.stringify({passed:3, environment:'isolated fixture clock; backend DST guard unchanged'}));
} finally { await db.close(); }
