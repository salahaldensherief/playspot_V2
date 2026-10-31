import test from 'node:test';
import assert from 'node:assert/strict';
import { createLocationHandler, reverseGeocode } from './handler.js';
const req = (body = { latitude: 30, longitude: 31 }, auth = 'Bearer fixture') =>
  new Request('https://fixture.invalid', { method: 'POST', headers: { Authorization: auth }, body: JSON.stringify(body) });
function fixture(overrides = {}) {
  const writes = [];
  const handler = createLocationHandler({
    authenticate: async () => ({ id: 'verified-user' }), geocode: async () => null,
    loadCities: async () => [], saveLocation: async (...args) => { writes.push(args); return true; }, ...overrides,
  });
  return { handler, writes };
}
test('geocoder outage still saves coordinates for verified caller only', async () => {
  const { handler, writes } = fixture({ geocode: async () => { throw Error('unavailable'); } });
  assert.equal((await handler(req({ latitude: 30, longitude: 31, user_id: 'victim' }))).status, 200);
  assert.equal(writes[0][1], 'verified-user');
  assert.equal(writes[0][2].latitude, 30);
  assert.equal('city_id' in writes[0][2], false);
});
test('invalid or missing token never writes', async () => {
  for (const overrides of [{ authenticate: async () => null }, {}]) {
    const { handler, writes } = fixture(overrides);
    assert.equal((await handler(req(undefined, overrides.authenticate ? 'Bearer bad' : ''))).status, 401);
    assert.equal(writes.length, 0);
  }
});
test('null, strings and out-of-range coordinates never write', async () => {
  for (const latitude of [null, '30', 91, -91]) {
    const { handler, writes } = fixture();
    assert.equal((await handler(req({ latitude, longitude: 31 }))).status, 400);
    assert.equal(writes.length, 0);
  }
});
test('unknown city leaves existing profile city unchanged', async () => {
  const { handler, writes } = fixture({ geocode: async () => 'Unconfigured',
    loadCities: async () => [{ id: 'wrong', name_ar: '', name_en: '' }] });
  assert.equal((await handler(req())).status, 200);
  assert.equal('city_id' in writes[0][2], false);
});
test('exact normalized city enriches location', async () => {
  const { handler, writes } = fixture({ geocode: async () => 'القاهرة',
    loadCities: async () => [{ id: 'city', name_ar: 'القَاهِرة', name_en: 'Cairo' }] });
  const response = await handler(req());
  assert.equal((await response.json()).city_id, 'city');
  assert.equal(writes[0][2].city_id, 'city');
});
test('denied or missing updated row never reports success', async () => {
  const { handler } = fixture({ saveLocation: async () => false });
  assert.equal((await handler(req())).status, 500);
});
test('secondary geocoder is used after primary fails', async () => {
  let calls = 0;
  const city = await reverseGeocode(30, 31, async (_url, options) => {
    assert.ok(options.signal);
    return ++calls === 1 ? new Response('', { status: 429 }) : Response.json({ city: 'Cairo' });
  });
  assert.equal(city, 'Cairo'); assert.equal(calls, 2);
});
test('both unavailable geocoders return optional empty enrichment', async () => {
  assert.equal(await reverseGeocode(30, 31, async () => { throw Error('outage'); }), null);
});
test('preflight never authenticates or mutates', async () => {
  const { handler, writes } = fixture({ authenticate: async () => { throw Error('should not run'); } });
  const response = await handler(new Request('https://fixture.invalid', { method: 'OPTIONS' }));
  assert.equal(response.status, 200); assert.equal(writes.length, 0);
});
