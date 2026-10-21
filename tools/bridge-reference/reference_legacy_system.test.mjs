import test from 'node:test';
import assert from 'node:assert/strict';
import {ReferenceLegacySystem} from './reference_legacy_system.mjs';

const base = {
  integrationId: 'L-1', resourceId: 'PS-04',
  fromUtc: '2026-10-22T19:00:00Z',
  toUtc: '2026-10-22T20:00:00Z',
};
const reserve = (id, overrides = {}) =>
  ({...base, type: 'reserve', idempotencyKey: id, ...overrides});

for (const mode of ['cloud_api', 'local_agent', 'hybrid']) {
  test(`${mode}: collision rejects another reservation`, () => {
    const adapter = new ReferenceLegacySystem({mode});
    assert.equal(adapter.execute(reserve('one')).status, 'acknowledged');
    assert.deepEqual(adapter.execute(reserve('two')), {
      status: 'rejected', reason: 'SLOT_OCCUPIED',
    });
    assert.equal(adapter.reservations.size, 1);
  });

  test(`${mode}: same idempotency key has one effect`, () => {
    const adapter = new ReferenceLegacySystem({mode});
    const first = adapter.execute(reserve('one'));
    assert.deepEqual(adapter.execute(reserve('one')), first);
    assert.equal(adapter.reservations.size, 1);
    assert.deepEqual(adapter.execute(reserve('one', {resourceId: 'PS-05'})), {
      status: 'rejected', reason: 'IDEMPOTENCY_KEY_REUSED',
    });
  });

  test(`${mode}: offline is NOT authoritative availability`, () => {
    const adapter = new ReferenceLegacySystem({mode});
    adapter.setOnline(false);
    assert.equal(adapter.execute(reserve('one')).status, 'unavailable');
    assert.equal(adapter.reservations.size, 0);
  });
}

test('a lost acknowledgement is AMBIGUOUS and replay has same stored effect', () => {
  const adapter = new ReferenceLegacySystem();
  const command = reserve('lost');
  assert.equal(adapter.execute(command, {simulateLostAck: true}).status, 'ambiguous');
  assert.equal(adapter.reservations.size, 1);
  assert.equal(adapter.execute(command).status, 'acknowledged');
  assert.equal(adapter.reservations.size, 1);
});

test('session state changes must follow reservation and not duplicate', () => {
  const adapter = new ReferenceLegacySystem({mode: 'local_agent'});
  const id = adapter.execute(reserve('initial')).reservationId;
  const start = {...base, type: 'start_session', reservationId: id, idempotencyKey: 'start-1'};
  const end = {...base, type: 'end_session', reservationId: id, idempotencyKey: 'end-1'};
  assert.equal(adapter.execute({...end, idempotencyKey: 'end-too-early'}).status, 'rejected');
  assert.equal(adapter.execute(start).status, 'acknowledged');
  assert.equal(adapter.execute(start).status, 'acknowledged');
  assert.equal(adapter.execute({...base, type: 'extend_session',
    reservationId: id, idempotencyKey: 'ext-1', additionalMinutes: 30}).reason,
    'EXTENSION_CAPACITY_NOT_CHECKED');
  assert.equal(adapter.execute(end).status, 'acknowledged');
  assert.equal(adapter.execute({...end, idempotencyKey: 'end-2'}).status, 'rejected');
});

test('malformed time range is rejected, and adjacent times are permitted', () => {
  const adapter = new ReferenceLegacySystem();
  assert.equal(adapter.execute(reserve('bad', {toUtc: '2026-10-22T18:00:00Z'})).status, 'rejected');
  assert.equal(adapter.execute(reserve('first')).status, 'acknowledged');
  assert.equal(adapter.execute(reserve('adjacent', {
    fromUtc: '2026-10-22T20:00:00Z', toUtc: '2026-10-22T21:00:00Z',
  })).status, 'acknowledged');
});

test('integration scope cannot control another integration reservation', () => {
  const adapter = new ReferenceLegacySystem();
  const id = adapter.execute(reserve('first')).reservationId;
  assert.equal(adapter.execute({...base,
    type: 'start_session', idempotencyKey: 'foreign',
    integrationId: 'L-2', reservationId: id}).reason, 'BAD_RESERVATION');
});

test('unsupported operation fails closed', () => {
  const adapter = new ReferenceLegacySystem();
  assert.equal(adapter.execute({...base,
    type: 'charge_card', idempotencyKey: 'charge-1'}).reason, 'UNSUPPORTED_COMMAND');
});

test('cancelling a running session cannot release occupied capacity', () => {
  const adapter = new ReferenceLegacySystem();
  const reservationId = adapter.execute(reserve('first')).reservationId;
  adapter.execute({...base, type:'start_session', idempotencyKey:'start', reservationId});
  assert.equal(adapter.execute({...base,type:'cancel_reservation',idempotencyKey:'cancel',reservationId}).status,'rejected');
  assert.equal(adapter.execute(reserve('collision')).reason,'SLOT_OCCUPIED');
});

test('receipt mutation and object key order do not alter deduplication', () => {
  const adapter = new ReferenceLegacySystem(); const command = reserve('one');
  const receipt = adapter.execute(command); receipt.status = 'corrupted';
  assert.equal(adapter.execute(Object.fromEntries(Object.entries(command).reverse())).status,'acknowledged');
  assert.equal(adapter.reservations.size,1);
});

test('non-string identities cannot bypass integration scope', () => {
  const adapter = new ReferenceLegacySystem();
  assert.equal(adapter.execute(reserve('one',{integrationId:{id:'L-1'}})).reason,'INVALID_COMMAND');
  assert.equal(adapter.reservations.size,0);
});
