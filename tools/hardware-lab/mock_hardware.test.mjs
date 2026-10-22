import test from 'node:test';
import assert from 'node:assert/strict';
import {MockMttlAdapter, MockWindowsConnector, BridgeLabCommandService} from './mock_hardware.mjs';

const owner = {tenantId: 'lab', installationId: 'windows', actorId: 'owner', hardwareTestAllowed: true};
const foreign = {...owner, tenantId: 'other'};
function fixture(enabled = true) {
  let now = 1000;
  const adapter = new MockMttlAdapter(['strip-1','strip-2'].map(deviceId => ({...owner, deviceId})));
  const connector = new MockWindowsConnector(adapter);
  const service = new BridgeLabCommandService({connector, enabled, clock: () => now});
  return {adapter, connector, service, advance: ms => now += ms};
}
const command = (overrides = {}) => ({commandId: 'op-1', deviceId: 'strip-1', type: 'set_outlet',
  channel: 1, on: true, sequence: 1, expectedRevision: 0, deadlineMs: 2000, ...overrides});

test('disabled by default and only a mock transport can be constructed', () => {
  const {connector} = fixture();
  const service = new BridgeLabCommandService({connector});
  assert.equal(service.execute(owner, command()).reason, 'LAB_DISABLED');
  assert.throws(() => new MockWindowsConnector({}), /MOCK_ONLY/);
});
test('discovery yields two unique identities and four channels each, with no network', () => {
  const {service} = fixture();
  const devices = service.discover(owner);
  assert.deepEqual(devices.map(d => d.deviceId), ['strip-1','strip-2']);
  for (const d of devices) { assert.deepEqual(d.channels, [1,2,3,4]); assert.equal(d.simulated, true); }
  assert.deepEqual(service.discover(foreign), []);
  assert.throws(() => new MockMttlAdapter([{...owner, deviceId:'x'}, {...owner, deviceId:'x'}]), /DUPLICATE/);
});
test('four independent outlets on each independent device', () => {
  const {service} = fixture();
  for (const deviceId of ['strip-1','strip-2']) for (let channel = 1; channel <= 4; ++channel) {
    const c = command({deviceId, channel, commandId: `${deviceId}-${channel}`,
      sequence: channel, expectedRevision: channel - 1});
    assert.equal(service.execute(owner, c).status, 'confirmed');
  }
  assert.equal(service.status(owner, 'strip-1').effects, 4);
  assert.equal(service.status(owner, 'strip-2').effects, 4);
});
test('duplicate delivery and reordered object keys have one effect and immutable receipts', () => {
  const {service} = fixture(); const c = command();
  const receipt = service.execute(owner, c); receipt.status = 'corrupted';
  assert.equal(service.execute(owner, Object.fromEntries(Object.entries(c).reverse())).status, 'confirmed');
  assert.equal(service.status(owner, c.deviceId).effects, 1);
  assert.equal(service.execute(owner, {...c, deviceId: 'strip-2'}).reason, 'IDEMPOTENCY_CONFLICT');
  assert.equal(service.status(owner, 'strip-2').effects, 0);
});
test('lost ACK blocks further device writes; reconnect reconciles without replay', () => {
  const {service, adapter} = fixture(); const c = command();
  assert.equal(service.execute(owner, c, {fault: 'timeout-after'}).status, 'unknown');
  assert.equal(service.execute(owner, c).status, 'unknown');
  const next = command({commandId:'op-2', sequence:2, expectedRevision:1, channel:2});
  assert.equal(service.execute(owner, next).reason, 'RECONCILIATION_REQUIRED');
  // Device 2 remains usable while device 1 is ambiguous.
  assert.equal(service.execute(owner, command({deviceId:'strip-2', commandId:'independent'})).status, 'confirmed');
  adapter.setOnline(owner, 'strip-1', false);
  assert.equal(service.status(owner, 'strip-1').outlets[0].state, 'unknown');
  assert.equal(service.reconcile(owner, 'op-1').reason, 'DEVICE_OFFLINE');
  adapter.setOnline(owner, 'strip-1', true);
  service.disconnect(owner); service.reconnect(owner);
  assert.equal(service.status(owner, 'strip-1').effects, 1);
  assert.equal(service.reconcile(owner, 'op-1').reconciled, true);
  assert.equal(service.execute(owner, next).status, 'confirmed');
});
test('timeout before execution never becomes success or automatically retries', () => {
  const {service} = fixture();
  assert.equal(service.execute(owner, command(), {fault:'timeout-before'}).status, 'unknown');
  assert.equal(service.reconcile(owner, 'op-1').reason, 'MANUAL_REVIEW_REQUIRED');
  assert.equal(service.execute(owner, command()).status, 'unknown');
  assert.equal(service.status(owner, 'strip-1').effects, 0);
});
test('expiry and offline outcomes stay stable after reconnect', () => {
  const {service,adapter,advance} = fixture();
  adapter.setOnline(owner,'strip-1',false);
  assert.equal(service.execute(owner,command()).status,'offline');
  adapter.setOnline(owner,'strip-1',true);
  assert.equal(service.execute(owner,command()).status,'offline');
  advance(1001);
  assert.equal(service.execute(owner,command({commandId:'expired',sequence:2})).status,'expired');
  assert.equal(service.status(owner,'strip-1').effects,0);
});
test('cross tenant, installation and permission checks prevent commands and reads', () => {
  const {service} = fixture();
  for (const scope of [foreign,{...owner,installationId:'other'}]) {
    assert.equal(service.execute(scope,command()).reason,'DEVICE_SCOPE_DENIED');
    assert.throws(() => service.status(scope,'strip-1'),/DEVICE_SCOPE_DENIED/);
  }
  assert.equal(service.execute({...owner,hardwareTestAllowed:false},command()).reason,'SCOPE_DENIED');
  assert.equal(service.status(owner,'strip-1').effects,0);
});
test('disconnect and revoke reject old receipts and prevent reconnect after revocation', () => {
  const {service} = fixture();
  service.execute(owner,command()); service.disconnect(owner);
  assert.equal(service.execute(owner,command()).reason,'CONNECTOR_DISCONNECTED');
  service.reconnect(owner); service.revoke(owner);
  assert.equal(service.execute(owner,command()).reason,'INSTALLATION_REVOKED');
  assert.throws(() => service.reconnect(owner),/INSTALLATION_REVOKED/);
  assert.throws(() => service.discover(owner),/INSTALLATION_REVOKED/);
});
test('stale revision, sequence, invalid channel, injected payload and unknown command fail closed', () => {
  const {service} = fixture(); service.execute(owner,command());
  assert.equal(service.execute(owner,command({commandId:'stale',sequence:2})).reason,'STALE_REVISION');
  assert.equal(service.execute(owner,command({commandId:'old',expectedRevision:1})).reason,'STALE_SEQUENCE');
  for (const change of [{channel:0},{channel:5},{on:'true'},{type:'toggle'}, {shell:'unsafe'}, {sequence:NaN}]) {
    assert.equal(service.execute(owner,command(change)).reason,'INVALID_COMMAND');
  }
  assert.equal(service.status(owner,'strip-1').effects,1);
});
test('audit includes success, duplicate and rejection without payloads, and is isolated and immutable', () => {
  const {service} = fixture(); service.execute(owner,command()); service.execute(owner,command());
  service.execute(owner,command({commandId:'invalid',password:'not-logged'}));
  const events=service.audit(owner);
  assert.deepEqual(events.map(e=>e.status),['confirmed','duplicate','INVALID_COMMAND']);
  assert.equal(JSON.stringify(events).includes('not-logged'),false);
  events[0].status='changed'; assert.equal(service.audit(owner)[0].status,'confirmed');
  assert.deepEqual(service.audit(foreign),[]);
});
