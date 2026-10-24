import assert from 'node:assert/strict';
import { test } from 'node:test';
import { spawn, type ChildProcess } from 'node:child_process';
import { mkdtemp, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import type { Permit, Signed, WriterLease } from '../src/contract.ts';
import { Coordinator } from '../src/coordinator.ts';
import { SimulatedAgent } from '../src/agent.ts';
import { keyPair, signed } from '../src/signature.ts';

function worker() {
  const path = fileURLToPath(new URL('./coordinator_worker.ts', import.meta.url));
  const child: ChildProcess = spawn(process.execPath, ['--import', 'tsx', path], { stdio: ['ignore', 'ignore', 'pipe', 'ipc'] });
  const pending = new Map<number, { resolve: (value: unknown) => void; reject: (error: Error) => void }>();
  let nextId = 0;
  let stderr = '';
  child.stderr?.on('data', chunk => { stderr += chunk.toString(); });
  child.on('message', message => {
    const response = message as { id: number; ok: boolean; result?: unknown; error?: string };
    const entry = pending.get(response.id);
    pending.delete(response.id);
    if (response.ok) entry?.resolve(response.result);
    else entry?.reject(new Error(response.error));
  });
  child.on('exit', code => {
    for (const entry of pending.values()) entry.reject(new Error(`WORKER_EXIT_${code}: ${stderr}`));
    pending.clear();
  });
  return {
    request<T = unknown>(type: string, payload: Record<string, unknown> = {}): Promise<T> {
      const id = ++nextId;
      return new Promise<T>((resolve, reject) => {
        pending.set(id, { resolve: value => resolve(value as T), reject });
        child.send({ id, type, payload });
      });
    },
    stop() { child.kill(); },
  };
}

test('two coordinator processes serialize writer takeover and competing cashier commands', async () => {
  const root = await mkdtemp(join(tmpdir(), 'playspot-multiprocess-'));
  const issuer = keyPair();
  const coordinatorKeys = keyPair();
  const device = keyPair();
  const path = join(root, 'coordinator.sqlite');
  const agentPath = join(root, 'agent.json');
  let now = 1_000_000;
  const clock = () => now;
  const local = await Coordinator.open(path, 'venue-1', issuer.publicKey, coordinatorKeys.privateKey, clock);
  const agent = await SimulatedAgent.open(agentPath, 'venue-1', 'pc-1', 1, device.privateKey, coordinatorKeys.publicKey, clock);
  const lease = (writerId: string, generation: number): Signed<WriterLease> => signed({ venueId: 'venue-1', writerId, generation, expiresAt: now + 120_000 }, issuer.privateKey);
  const permit = (writerId: string, generation: number, actions: Permit['actions']): Signed<Permit> => signed({ permitId: `${writerId}-${generation}`, venueId: 'venue-1', stationId: 'pc-1', actorId: writerId, shiftId: 'shift-1', writerId, writerGeneration: generation, epoch: 1, expiresAt: now + 60_000, actions }, issuer.privateKey);
  await local.activateWriter(lease('cashier-1', 1));
  const firstPermit = permit('cashier-1', 1, ['enroll', 'start_session']);
  const token = await local.createEnrollment(firstPermit);
  await local.enroll(agent.enrollmentProof(token, device.publicKey), firstPermit);
  await agent.applyFence(local.fenceFor('pc-1'));
  const stale = await local.queueCommand({ operationId: 'stale', stationId: 'pc-1', kind: 'start_session', sessionId: 's0', expectedState: 'idle' }, firstPermit);
  const a = worker();
  const b = worker();
  try {
    const open = { path, venueId: 'venue-1', issuerPublicKey: issuer.publicKey, coordinatorPrivateKey: coordinatorKeys.privateKey, now };
    await Promise.all([a.request('open', open), b.request('open', open)]);
    await a.request('activate', { lease: lease('cashier-2', 2) });
    assert.equal(local.pending('stale'), null);
    await assert.rejects(local.queueCommand({ operationId: 'late', stationId: 'pc-1', kind: 'start_session', sessionId: 's0', expectedState: 'idle' }, firstPermit), /PERMIT_DENIED/);
    await agent.applyFence(local.fenceFor('pc-1'));
    await assert.rejects(agent.apply(stale), /STALE_WRITER/);
    const secondPermit = permit('cashier-2', 2, ['start_session']);
    const start = await b.request<Signed<Parameters<SimulatedAgent['apply']>[0]['payload']>>('queue', { command: { operationId: 'start', stationId: 'pc-1', kind: 'start_session', sessionId: 's1', expectedState: 'idle' }, permit: secondPermit });
    await local.receiveAck(await agent.apply(start));
    await local.receiveHeartbeat(await agent.heartbeat());
    assert.equal(local.snapshot().stations['pc-1'].observedState, 'running');

    const results = await Promise.allSettled([
      a.request('activate', { lease: lease('cashier-3', 3) }),
      b.request('activate', { lease: lease('cashier-4', 3) }),
    ]);
    assert.equal(results.filter(result => result.status === 'fulfilled').length, 1);
    assert.match(String((results.find(result => result.status === 'rejected') as PromiseRejectedResult).reason), /STALE_WRITER/);
    const winner = results[0].status === 'fulfilled' ? 'cashier-3' : 'cashier-4';
    await agent.applyFence(local.fenceFor('pc-1'));
    const raceCommand = { operationId: 'race', stationId: 'pc-1', kind: 'end_session', sessionId: 's1', expectedState: 'running' };
    const races = await Promise.allSettled([
      a.request('queue', { command: raceCommand, permit: permit('cashier-3', 3, ['end_session']) }),
      b.request('queue', { command: raceCommand, permit: permit('cashier-4', 3, ['end_session']) }),
    ]);
    assert.equal(races.filter(result => result.status === 'fulfilled').length, 1);
    const accepted = (races.find(result => result.status === 'fulfilled') as PromiseFulfilledResult<Signed<Parameters<SimulatedAgent['apply']>[0]['payload']>>).value;
    assert.equal(accepted.payload.writerGeneration, 3);
    assert.equal(accepted.payload.permitId, `${winner}-3`);
    await local.receiveAck(await agent.apply(accepted));
    await local.receiveHeartbeat(await agent.heartbeat());
    assert.equal(local.snapshot().stations['pc-1'].observedState, 'idle');
    assert.equal(local.snapshot().audit.filter(item => item.event === 'command_queued' && item.operationId === 'race').length, 1);
    assert.equal(local.snapshot().audit.filter(item => item.event === 'writer_activated').length, 3);
    const sameWriter = permit(winner, 3, ['start_session']);
    const duplicates = await Promise.allSettled([
      a.request<Signed<Parameters<SimulatedAgent['apply']>[0]['payload']>>('queue', { command: { operationId: 'duplicate', stationId: 'pc-1', kind: 'start_session', sessionId: 's2', expectedState: 'idle' }, permit: sameWriter }),
      b.request<Signed<Parameters<SimulatedAgent['apply']>[0]['payload']>>('queue', { command: { operationId: 'duplicate', stationId: 'pc-1', kind: 'start_session', sessionId: 's3', expectedState: 'idle' }, permit: sameWriter }),
    ]);
    assert.equal(duplicates.filter(result => result.status === 'fulfilled').length, 1);
    assert.match(String((duplicates.find(result => result.status === 'rejected') as PromiseRejectedResult).reason), /OPERATION_ID_REUSED/);
    const duplicateWinner = (duplicates.find(result => result.status === 'fulfilled') as PromiseFulfilledResult<Signed<Parameters<SimulatedAgent['apply']>[0]['payload']>>).value;
    await local.receiveAck(await agent.apply(duplicateWinner));
    assert.equal(local.snapshot().audit.filter(item => item.event === 'command_queued' && item.operationId === 'duplicate').length, 1);

    now += 120_001;
    await Promise.all([a.request('time', { now }), b.request('time', { now })]);
    await assert.rejects(a.request('queue', { command: { operationId: 'expired', stationId: 'pc-1', kind: 'end_session', sessionId: duplicateWinner.payload.sessionId, expectedState: 'running' }, permit: sameWriter }), /PERMIT_DENIED/);
    await b.request('activate', { lease: lease('cashier-5', 4) });
    await agent.applyFence(local.fenceFor('pc-1'));
    const recovered = await a.request<Signed<Parameters<SimulatedAgent['apply']>[0]['payload']>>('queue', { command: { operationId: 'recovered', stationId: 'pc-1', kind: 'end_session', sessionId: duplicateWinner.payload.sessionId, expectedState: 'running' }, permit: permit('cashier-5', 4, ['end_session']) });
    await local.receiveAck(await agent.apply(recovered));
    assert.equal(local.snapshot().audit.filter(item => item.event === 'writer_activated').length, 4);
    const remoteSnapshot = await a.request<ReturnType<Coordinator['snapshot']>>('snapshot');
    assert.deepEqual(remoteSnapshot, local.snapshot());
  } finally {
    a.stop();
    b.stop();
  }
});

test('crashed transaction rolls back; disconnected revocation has a bounded delivery gap', async () => {
  const root = await mkdtemp(join(tmpdir(), 'playspot-crash-'));
  const issuer = keyPair();
  const coordinatorKeys = keyPair();
  const device = keyPair();
  const path = join(root, 'coordinator.sqlite');
  const now = 2_000_000;
  const local = await Coordinator.open(path, 'venue-1', issuer.publicKey, coordinatorKeys.privateKey, () => now);
  const agent = await SimulatedAgent.open(join(root, 'agent.json'), 'venue-1', 'pc-1', 1, device.privateKey, coordinatorKeys.publicKey, () => now);
  await local.activateWriter(signed({ venueId: 'venue-1', writerId: 'cashier-1', generation: 1, expiresAt: now + 120_000 }, issuer.privateKey));
  const permit = (actions: Permit['actions']) => signed({ permitId: 'permit-1', venueId: 'venue-1', stationId: 'pc-1', actorId: 'cashier-1', shiftId: 'shift-1', writerId: 'cashier-1', writerGeneration: 1, epoch: 1, expiresAt: now + 60_000, actions }, issuer.privateKey);
  const authority = permit(['enroll', 'start_session']);
  const token = await local.createEnrollment(authority);
  await local.enroll(agent.enrollmentProof(token, device.publicKey), authority);
  await agent.applyFence(local.fenceFor('pc-1'));
  const command = await local.queueCommand({ operationId: 'op-1', stationId: 'pc-1', kind: 'start_session', sessionId: 's1', expectedState: 'idle' }, authority);
  const remote = worker();
  try {
    await remote.request('open', { path, venueId: 'venue-1', issuerPublicKey: issuer.publicKey, coordinatorPrivateKey: coordinatorKeys.privateKey, now });
    await assert.rejects(remote.request('crash_in_transaction', { path, venueId: 'venue-1' }), /WORKER_EXIT_77/);
    assert.equal(local.snapshot().audit.some(item => item.event === 'never_committed'), false);
    assert.deepEqual(local.pending('op-1'), command);
  } finally {
    remote.stop();
  }
  const restarted = worker();
  try {
    await restarted.request('open', { path, venueId: 'venue-1', issuerPublicKey: issuer.publicKey, coordinatorPrivateKey: coordinatorKeys.privateKey, now });
    const notice = await restarted.request<Signed<Parameters<SimulatedAgent['applyRevocation']>[0]['payload']>>('revoke', { stationId: 'pc-1', permit: permit(['revoke']) });
    assert.equal(local.pending('op-1'), null);
    await assert.rejects(local.queueCommand({ operationId: 'after-revoke', stationId: 'pc-1', kind: 'start_session', sessionId: 's2', expectedState: 'idle' }, authority), /DEVICE_FENCED/);
    // This command was authorized before revocation and reached an offline agent first.
    const staleExecution = await agent.apply(command);
    assert.equal(staleExecution.payload.accepted, true);
    await assert.rejects(local.receiveAck(staleExecution), /ACK_DENIED/);
    await agent.applyRevocation(notice);
    await assert.rejects(agent.apply(command), /COMMAND_DENIED/);
    await assert.rejects(agent.heartbeat(), /DEVICE_REVOKED/);
    const snapshot = await restarted.request<ReturnType<Coordinator['snapshot']>>('snapshot');
    assert.deepEqual(snapshot, local.snapshot());
    assert.equal(snapshot.audit.filter(item => item.event === 'device_revoked').length, 1);
  } finally {
    restarted.stop();
  }
});

test('corrupt coordinator database fails closed', async () => {
  const root = await mkdtemp(join(tmpdir(), 'playspot-corrupt-db-'));
  const path = join(root, 'corrupt.sqlite');
  await writeFile(path, 'not a SQLite database');
  const issuer = keyPair();
  const coordinatorKeys = keyPair();
  await assert.rejects(Coordinator.open(path, 'venue-1', issuer.publicKey, coordinatorKeys.privateKey), /STORE_CORRUPT/);
});

test('two processes can initialize one fresh authoritative store', async () => {
  const root = await mkdtemp(join(tmpdir(), 'playspot-open-race-'));
  const path = join(root, 'coordinator.sqlite');
  const issuer = keyPair();
  const coordinatorKeys = keyPair();
  const a = worker();
  const b = worker();
  try {
    const input = { path, venueId: 'venue-1', issuerPublicKey: issuer.publicKey, coordinatorPrivateKey: coordinatorKeys.privateKey, now: 1_000_000 };
    await Promise.all([a.request('open', input), b.request('open', input)]);
    const snapshots = await Promise.all([a.request<ReturnType<Coordinator['snapshot']>>('snapshot'), b.request<ReturnType<Coordinator['snapshot']>>('snapshot')]);
    assert.deepEqual(snapshots[0], snapshots[1]);
  } finally {
    a.stop();
    b.stop();
  }
});
