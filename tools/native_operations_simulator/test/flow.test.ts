import assert from 'node:assert/strict';
import { test } from 'node:test';
import { mkdtemp, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { once } from 'node:events';
import type { DeviceCommand, Permit, Signed } from '../src/contract.ts';
import { Coordinator } from '../src/coordinator.ts';
import { SimulatedAgent } from '../src/agent.ts';
import { keyPair, signed } from '../src/signature.ts';
import { startLoopbackServer } from '../src/server.ts';

async function fixture() {
  const root = await mkdtemp(join(tmpdir(), 'playspot-native-'));
  const issuer = keyPair();
  const coordinatorKeys = keyPair();
  const device = keyPair();
  let now = 1_000_000;
  const clock = () => now;
  const coordinatorPath = join(root, 'coordinator.json');
  const agentPath = join(root, 'agent.json');
  const coordinator = await Coordinator.open(coordinatorPath, 'venue-1', issuer.publicKey, coordinatorKeys.privateKey, clock);
  const agent = await SimulatedAgent.open(agentPath, 'venue-1', 'pc-1', 1, device.privateKey, coordinatorKeys.publicKey, clock);
  await coordinator.activateWriter(signed({ venueId: 'venue-1', writerId: 'cashier-1', generation: 1, expiresAt: now + 120_000 }, issuer.privateKey));
  const permit = (actions: Permit['actions'], changes: Partial<Permit> = {}) => signed({ permitId: 'permit-1', venueId: 'venue-1', stationId: 'pc-1', actorId: 'cashier-1', shiftId: 'shift-1', writerId: 'cashier-1', writerGeneration: 1, epoch: 1, expiresAt: now + 60_000, actions, ...changes }, issuer.privateKey);
  const enroll = async () => {
    const authority = permit(['enroll', 'start_session', 'end_session']);
    const token = await coordinator.createEnrollment(authority);
    await coordinator.enroll(agent.enrollmentProof(token, device.publicKey), authority);
    await agent.applyFence(coordinator.fenceFor('pc-1'));
    return { authority, token };
  };
  return { root, issuer, coordinatorKeys, device, coordinatorPath, agentPath, coordinator, agent, permit, enroll, clock, advance: (ms: number) => { now += ms; } };
}

test('authorized enrollment, command, ACK, heartbeat, disconnect, restart and reconciliation', async () => {
  const f = await fixture();
  const { authority, token } = await f.enroll();
  await assert.rejects(f.coordinator.enroll(f.agent.enrollmentProof(token, f.device.publicKey), authority), /ENROLLMENT_DENIED/);
  const command = await f.coordinator.queueCommand({ operationId: 'op-1', stationId: 'pc-1', kind: 'start_session', sessionId: 'session-1', expectedState: 'idle' }, authority);
  assert.deepEqual(f.coordinator.snapshot().pendingOperations, ['op-1']);
  assert.equal(f.coordinator.snapshot().stations['pc-1'].connectivity, 'unknown');
  const ack = await f.agent.apply(command);
  assert.equal(ack.payload.accepted, true);
  // Simulate a lost ACK and both processes restarting. The saved command is replayed.
  const coordinator = await Coordinator.open(f.coordinatorPath, 'venue-1', f.issuer.publicKey, f.coordinatorKeys.privateKey, f.clock);
  const agent = await SimulatedAgent.open(f.agentPath, 'venue-1', 'pc-1', 1, f.device.privateKey, f.coordinatorKeys.publicKey, f.clock);
  assert.deepEqual(await agent.apply(coordinator.pending('op-1')!), ack);
  await coordinator.receiveAck(ack);
  await coordinator.receiveAck(ack);
  await coordinator.receiveHeartbeat(await agent.heartbeat());
  assert.deepEqual(coordinator.snapshot().stations['pc-1'], { connectivity: 'connected', observedState: 'running', sessionId: 'session-1' });
  f.advance(15_001);
  assert.equal(coordinator.snapshot().stations['pc-1'].connectivity, 'unknown');
  await coordinator.receiveHeartbeat(await agent.heartbeat());
  assert.equal(coordinator.snapshot().stations['pc-1'].connectivity, 'connected');
  const end = await coordinator.queueCommand({ operationId: 'op-2', stationId: 'pc-1', kind: 'end_session', sessionId: 'session-1', expectedState: 'running' }, authority);
  assert.equal(coordinator.snapshot().stations['pc-1'].connectivity, 'unknown');
  await coordinator.receiveAck(await agent.apply(end));
  await coordinator.receiveHeartbeat(await agent.heartbeat());
  assert.equal(coordinator.snapshot().stations['pc-1'].observedState, 'idle');
  assert.equal(coordinator.snapshot().audit.filter(item => item.event === 'command_applied').length, 2);
});

test('authorization, fencing, duplicate operation and signed command rejection', async () => {
  const f = await fixture();
  const { authority } = await f.enroll();
  const input = { operationId: 'op-1', stationId: 'pc-1', kind: 'start_session' as const, sessionId: 'session-1', expectedState: 'idle' as const };
  const command = await f.coordinator.queueCommand(input, authority);
  assert.deepEqual(await f.coordinator.queueCommand(input, authority), command);
  await assert.rejects(f.coordinator.queueCommand({ ...input, sessionId: 'other' }, authority), /OPERATION_ID_REUSED/);
  await assert.rejects(f.coordinator.queueCommand({ ...input, operationId: 'op-2' }, f.permit(['start_session'], { epoch: 2 })), /DEVICE_FENCED/);
  await assert.rejects(f.coordinator.queueCommand({ ...input, operationId: 'op-2' }, f.permit(['end_session'])), /PERMIT_DENIED/);
  await assert.rejects(f.agent.apply({ ...command, payload: { ...command.payload, sessionId: 'tampered' } }), /COMMAND_DENIED/);
  const rogue = keyPair();
  await assert.rejects(f.agent.apply(signed(command.payload, rogue.privateKey)), /COMMAND_DENIED/);
  const ack = await f.agent.apply(command);
  await f.coordinator.receiveAck(ack);
  await assert.rejects(f.coordinator.receiveAck({ ...ack, payload: { ...ack.payload, accepted: false } }), /ACK_DENIED/);
  f.advance(60_001);
  await assert.rejects(f.coordinator.queueCommand({ ...input, operationId: 'op-2' }, authority), /PERMIT_DENIED/);
});

test('out-of-order, expired, conflict and stale heartbeat cannot claim a new state', async () => {
  const f = await fixture();
  const { authority } = await f.enroll();
  const first = await f.coordinator.queueCommand({ operationId: 'op-1', stationId: 'pc-1', kind: 'start_session', sessionId: 's1', expectedState: 'idle' }, authority);
  const second = await f.coordinator.queueCommand({ operationId: 'op-2', stationId: 'pc-1', kind: 'end_session', sessionId: 's1', expectedState: 'running' }, authority);
  await assert.rejects(f.agent.apply(second), /COMMAND_EXPIRED_OR_OUT_OF_ORDER/);
  const before = await f.agent.heartbeat();
  await f.coordinator.receiveAck(await f.agent.apply(first));
  await assert.rejects(f.coordinator.receiveHeartbeat(before), /HEARTBEAT_DENIED/);
  const conflict = await f.agent.apply({ ...second, payload: { ...second.payload } });
  assert.equal(conflict.payload.accepted, true);
  await f.coordinator.receiveAck(conflict);
  await f.coordinator.receiveHeartbeat(await f.agent.heartbeat());
  assert.equal(f.coordinator.snapshot().stations['pc-1'].observedState, 'idle');
  const third = await f.coordinator.queueCommand({ operationId: 'op-3', stationId: 'pc-1', kind: 'end_session', sessionId: 's2', expectedState: 'running' }, authority);
  const rejected = await f.agent.apply(third);
  assert.equal(rejected.payload.accepted, false);
  assert.equal(rejected.payload.reason, 'STATE_CONFLICT');
  f.advance(30_001);
  const late = await f.coordinator.queueCommand({ operationId: 'op-4', stationId: 'pc-1', kind: 'start_session', sessionId: 's3', expectedState: 'idle' }, authority);
  f.advance(30_001);
  await assert.rejects(f.agent.apply(late), /COMMAND_EXPIRED_OR_OUT_OF_ORDER/);
});

test('loopback HTTP server exchanges signed messages with simulated agent', async () => {
  const f = await fixture();
  const { server, url } = await startLoopbackServer(f.coordinator);
  const post = async (path: string, input: unknown) => {
    const response = await fetch(`${url}${path}`, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(input) });
    return { status: response.status, value: await response.json() };
  };
  try {
    const permit = f.permit(['enroll', 'start_session']);
    const token = (await post('/enrollment-token', { permit })).value.token as string;
    assert.equal((await post('/enroll', { proof: f.agent.enrollmentProof(token, f.device.publicKey), permit })).status, 200);
    await f.agent.applyFence(f.coordinator.fenceFor('pc-1'));
    const result = await post('/commands', { command: { operationId: 'op-1', stationId: 'pc-1', kind: 'start_session', sessionId: 's1', expectedState: 'idle' }, permit });
    assert.equal(result.status, 200);
    const ack = await f.agent.apply(result.value as Signed<DeviceCommand>);
    assert.equal((await post('/ack', { ack })).status, 200);
    assert.equal((await post('/heartbeat', { heartbeat: await f.agent.heartbeat() })).status, 200);
    const snapshot = await (await fetch(`${url}/snapshot`)).json();
    assert.equal(snapshot.stations['pc-1'].observedState, 'running');
    assert.equal((await post('/commands', { command: { operationId: 'denied', stationId: 'pc-1', kind: 'end_session', sessionId: 's1', expectedState: 'running' }, permit })).status, 400);
  } finally {
    server.close();
    await once(server, 'close');
  }
});

test('corrupt persisted state fails closed', async () => {
  const f = await fixture();
  await writeFile(f.agentPath, '{invalid');
  await assert.rejects(SimulatedAgent.open(f.agentPath, 'venue-1', 'pc-1', 1, f.device.privateKey, f.coordinatorKeys.publicKey, f.clock), /STORE_CORRUPT/);
});

test('two stations, two cashiers: signed takeover fences old writer and reconciles missed commands', async () => {
  const f = await fixture();
  const { authority: oldPermit } = await f.enroll();
  const secondKeys = keyPair();
  const second = await SimulatedAgent.open(join(f.root, 'pc-2.json'), 'venue-1', 'pc-2', 1, secondKeys.privateKey, f.coordinatorKeys.publicKey, f.clock);
  const oldSecond = f.permit(['enroll', 'start_session'], { permitId: 'permit-2', stationId: 'pc-2' });
  const token = await f.coordinator.createEnrollment(oldSecond);
  await f.coordinator.enroll(second.enrollmentProof(token, secondKeys.publicKey), oldSecond);
  await second.applyFence(f.coordinator.fenceFor('pc-2'));
  const stale = await f.coordinator.queueCommand({ operationId: 'old', stationId: 'pc-1', kind: 'start_session', sessionId: 'old-session', expectedState: 'idle' }, oldPermit);
  const oldHeartbeat = await f.agent.heartbeat();
  await f.coordinator.activateWriter(signed({ venueId: 'venue-1', writerId: 'cashier-2', generation: 2, expiresAt: f.clock() + 120_000 }, f.issuer.privateKey));
  assert.equal(f.coordinator.pending('old'), null);
  assert.deepEqual(f.coordinator.snapshot().pendingOperations, []);
  await assert.rejects(f.coordinator.receiveHeartbeat(oldHeartbeat), /HEARTBEAT_DENIED/);
  await assert.rejects(f.coordinator.queueCommand({ operationId: 'old-cashier', stationId: 'pc-2', kind: 'start_session', sessionId: 's2', expectedState: 'idle' }, oldSecond), /PERMIT_DENIED/);
  await f.agent.applyFence(f.coordinator.fenceFor('pc-1'));
  await second.applyFence(f.coordinator.fenceFor('pc-2'));
  await assert.rejects(f.agent.apply(stale), /STALE_WRITER/);
  const newFirst = f.permit(['start_session'], { permitId: 'new-1', writerId: 'cashier-2', writerGeneration: 2, actorId: 'cashier-2' });
  const newSecond = f.permit(['start_session'], { permitId: 'new-2', stationId: 'pc-2', writerId: 'cashier-2', writerGeneration: 2, actorId: 'cashier-2' });
  const [firstCommand, secondCommand] = await Promise.all([
    f.coordinator.queueCommand({ operationId: 'new-1', stationId: 'pc-1', kind: 'start_session', sessionId: 's1', expectedState: 'idle' }, newFirst),
    f.coordinator.queueCommand({ operationId: 'new-2', stationId: 'pc-2', kind: 'start_session', sessionId: 's2', expectedState: 'idle' }, newSecond),
  ]);
  assert.equal(firstCommand.payload.sequence, 2);
  assert.equal(secondCommand.payload.sequence, 1);
  await Promise.all([f.coordinator.receiveAck(await f.agent.apply(firstCommand)), f.coordinator.receiveAck(await second.apply(secondCommand))]);
  await Promise.all([f.coordinator.receiveHeartbeat(await f.agent.heartbeat()), f.coordinator.receiveHeartbeat(await second.heartbeat())]);
  assert.equal(f.coordinator.snapshot().stations['pc-1'].observedState, 'running');
  assert.equal(f.coordinator.snapshot().stations['pc-2'].observedState, 'running');
  await assert.rejects(f.coordinator.activateWriter(signed({ venueId: 'venue-1', writerId: 'cashier-1', generation: 1, expiresAt: f.clock() + 120_000 }, f.issuer.privateKey)), /STALE_WRITER/);
  assert.equal(f.coordinator.snapshot().audit.filter(item => item.event === 'writer_activated').length, 2);
});

test('revocation survives restart and rejects stale signed commands and heartbeats', async () => {
  const f = await fixture();
  const { authority } = await f.enroll();
  const command = await f.coordinator.queueCommand({ operationId: 'pending', stationId: 'pc-1', kind: 'start_session', sessionId: 's1', expectedState: 'idle' }, authority);
  const heartbeat = await f.agent.heartbeat();
  const notice = await f.coordinator.revokeDevice('pc-1', f.permit(['revoke']));
  assert.equal(f.coordinator.pending('pending'), null);
  await assert.rejects(f.coordinator.receiveHeartbeat(heartbeat), /HEARTBEAT_DENIED/);
  await assert.rejects(f.coordinator.queueCommand({ operationId: 'other', stationId: 'pc-1', kind: 'start_session', sessionId: 's1', expectedState: 'idle' }, authority), /DEVICE_FENCED/);
  await f.agent.applyRevocation(notice);
  await f.agent.applyRevocation(notice);
  const restarted = await SimulatedAgent.open(f.agentPath, 'venue-1', 'pc-1', 2, f.device.privateKey, f.coordinatorKeys.publicKey, f.clock);
  await assert.rejects(restarted.apply(command), /COMMAND_DENIED/);
  await assert.rejects(restarted.heartbeat(), /DEVICE_REVOKED/);
  await assert.rejects(restarted.applyRevocation(signed({ ...notice.payload, newEpoch: 99 }, f.issuer.privateKey)), /REVOCATION_DENIED/);
  assert.equal(f.coordinator.snapshot().stations['pc-1'].connectivity, 'unknown');
});

test('writer expiry stops commands and takeover requires a valid issuer signature', async () => {
  const f = await fixture();
  const { authority } = await f.enroll();
  f.advance(120_001);
  await assert.rejects(f.coordinator.queueCommand({ operationId: 'expired', stationId: 'pc-1', kind: 'start_session', sessionId: 's1', expectedState: 'idle' }, authority), /PERMIT_DENIED/);
  const rogue = keyPair();
  await assert.rejects(f.coordinator.activateWriter(signed({ venueId: 'venue-1', writerId: 'cashier-2', generation: 2, expiresAt: f.clock() + 60_000 }, rogue.privateKey)), /WRITER_DENIED/);
  await f.coordinator.activateWriter(signed({ venueId: 'venue-1', writerId: 'cashier-2', generation: 2, expiresAt: f.clock() + 60_000 }, f.issuer.privateKey));
  await f.agent.applyFence(f.coordinator.fenceFor('pc-1'));
  const permit = f.permit(['start_session'], { permitId: 'new', writerId: 'cashier-2', writerGeneration: 2 });
  const command = await f.coordinator.queueCommand({ operationId: 'new', stationId: 'pc-1', kind: 'start_session', sessionId: 's1', expectedState: 'idle' }, permit);
  assert.equal((await f.agent.apply(command)).payload.accepted, true);
});

test('out-of-order ACK delivery never rolls observed state backward', async () => {
  const f = await fixture();
  const { authority } = await f.enroll();
  const start = await f.coordinator.queueCommand({ operationId: 'start', stationId: 'pc-1', kind: 'start_session', sessionId: 's1', expectedState: 'idle' }, authority);
  const end = await f.coordinator.queueCommand({ operationId: 'end', stationId: 'pc-1', kind: 'end_session', sessionId: 's1', expectedState: 'running' }, authority);
  const firstAck = await f.agent.apply(start);
  const secondAck = await f.agent.apply(end);
  await f.coordinator.receiveAck(secondAck);
  await f.coordinator.receiveAck(firstAck);
  await f.coordinator.receiveHeartbeat(await f.agent.heartbeat());
  assert.equal(f.coordinator.snapshot().stations['pc-1'].observedState, 'idle');
  assert.equal(f.coordinator.snapshot().audit.filter(item => item.event === 'command_applied').length, 2);
});
