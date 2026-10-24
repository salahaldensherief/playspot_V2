import { randomBytes } from 'node:crypto';
import type { CommandKind, CoordinatorState, DeviceAck, DeviceCommand, DeviceRevocation, DeviceState, EnrollmentProof, Heartbeat, Permit, Signed, WriterFence, WriterLease } from './contract.ts';
import { digest, signed, valid } from './signature.ts';
import { JsonStore } from './store.ts';

type Clock = () => number;

export class Coordinator {
  private queue: Promise<void> = Promise.resolve();

  private constructor(
    private readonly store: JsonStore<CoordinatorState>,
    private state: CoordinatorState,
    private readonly issuerPublicKey: string,
    private readonly coordinatorPrivateKey: string,
    private readonly clock: Clock,
  ) {}

  static async open(path: string, venueId: string, issuerPublicKey: string, coordinatorPrivateKey: string, clock: Clock = Date.now): Promise<Coordinator> {
    const store = new JsonStore<CoordinatorState>(path);
    const state = await store.load(() => ({ version: 1, venueId, writer: null, devices: {}, enrollment: {}, operations: {}, audit: [] }));
    if (state.venueId !== venueId || !state.devices || !state.operations || !state.enrollment || !Array.isArray(state.audit)) throw new Error('STORE_INVALID');
    return new Coordinator(store, state, issuerPublicKey, coordinatorPrivateKey, clock);
  }

  private async change<T>(action: (copy: CoordinatorState) => T): Promise<T> {
    const run = this.queue.then(async () => {
      const copy = structuredClone(this.state);
      const result = action(copy);
      await this.store.save(copy);
      this.state = copy;
      return result;
    });
    this.queue = run.then(() => undefined, () => undefined);
    return run;
  }

  private authorize(message: Signed<Permit>, stationId: string, action: CommandKind | 'enroll' | 'revoke', state: CoordinatorState): Permit {
    const permit = message.payload;
    const writer = state.writer;
    if (!valid(message, this.issuerPublicKey) || permit.venueId !== state.venueId || permit.stationId !== stationId || permit.expiresAt <= this.clock() || !permit.actions.includes(action) || !Number.isSafeInteger(permit.epoch) || permit.epoch < 1 || !permit.actorId || !permit.shiftId || !writer || writer.expiresAt <= this.clock() || writer.writerId !== permit.writerId || writer.generation !== permit.writerGeneration) {
      throw new Error('PERMIT_DENIED');
    }
    return permit;
  }

  async activateWriter(message: Signed<WriterLease>): Promise<void> {
    await this.change(state => {
      const lease = message.payload;
      if (!valid(message, this.issuerPublicKey) || lease.venueId !== state.venueId || !lease.writerId || !Number.isSafeInteger(lease.generation) || lease.generation < 1 || lease.expiresAt <= this.clock()) throw new Error('WRITER_DENIED');
      const current = state.writer;
      if (current && lease.generation <= current.generation) {
        if (digest(current) === digest(lease)) return;
        throw new Error('STALE_WRITER');
      }
      state.writer = lease;
      for (const device of Object.values(state.devices)) {
        device.fenceSequence = device.nextSequence;
        device.lastHeartbeatAt = null;
      }
      for (const operation of Object.values(state.operations)) {
        if (!operation.ack && !operation.cancelledAt) operation.cancelledAt = this.clock();
      }
      state.audit.push({ at: this.clock(), event: 'writer_activated', stationId: '*' });
    });
  }

  fenceFor(stationId: string): Signed<WriterFence> {
    const writer = this.state.writer;
    const device = this.state.devices[stationId];
    if (!writer || writer.expiresAt <= this.clock() || !device || device.revoked) throw new Error('FENCE_DENIED');
    return signed({ venueId: this.state.venueId, stationId, epoch: device.epoch, writerGeneration: writer.generation, nextSequence: device.fenceSequence ?? device.nextSequence }, this.coordinatorPrivateKey);
  }

  async createEnrollment(permitMessage: Signed<Permit>): Promise<string> {
    const token = randomBytes(32).toString('base64url');
    await this.change(state => {
      const permit = this.authorize(permitMessage, permitMessage.payload.stationId, 'enroll', state);
      if (state.devices[permit.stationId]) throw new Error('DEVICE_ALREADY_ENROLLED');
      state.enrollment[digest(token)] = { stationId: permit.stationId, permitId: permit.permitId, epoch: permit.epoch, expiresAt: Math.min(permit.expiresAt, this.clock() + 60_000), used: false };
      state.audit.push({ at: this.clock(), event: 'enrollment_created', stationId: permit.stationId, actorId: permit.actorId });
    });
    return token;
  }

  async enroll(proof: Signed<EnrollmentProof>, permitMessage: Signed<Permit>): Promise<void> {
    const input = proof.payload;
    if (input.venueId !== this.state.venueId || !valid(proof, input.publicKey)) throw new Error('ENROLLMENT_DENIED');
    await this.change(state => {
      const permit = this.authorize(permitMessage, input.stationId, 'enroll', state);
      const enrollment = state.enrollment[digest(input.token)];
      if (!enrollment || enrollment.used || enrollment.stationId !== input.stationId || enrollment.permitId !== permit.permitId || enrollment.epoch !== permit.epoch || enrollment.expiresAt <= this.clock() || state.devices[input.stationId]) throw new Error('ENROLLMENT_DENIED');
      enrollment.used = true;
      state.devices[input.stationId] = { publicKey: input.publicKey, epoch: permit.epoch, revoked: false, nextSequence: 1, fenceSequence: 1, lastAckSequence: 0, lastHeartbeatSequence: 0, lastHeartbeatAt: null, observedState: 'unknown', sessionId: null };
      state.audit.push({ at: this.clock(), event: 'device_enrolled', stationId: input.stationId, actorId: permit.actorId });
    });
  }

  async revokeDevice(stationId: string, permitMessage: Signed<Permit>): Promise<Signed<DeviceRevocation>> {
    return this.change(state => {
      const permit = this.authorize(permitMessage, stationId, 'revoke', state);
      const device = state.devices[stationId];
      if (!device || device.revoked || device.epoch !== permit.epoch) throw new Error('DEVICE_FENCED');
      const notice = signed({ venueId: state.venueId, stationId, oldEpoch: device.epoch, newEpoch: device.epoch + 1 }, this.coordinatorPrivateKey);
      device.epoch += 1;
      device.revoked = true;
      device.lastHeartbeatAt = null;
      device.observedState = 'unknown';
      device.sessionId = null;
      for (const operation of Object.values(state.operations)) {
        if (operation.command.payload.stationId === stationId && !operation.ack && !operation.cancelledAt) operation.cancelledAt = this.clock();
      }
      state.audit.push({ at: this.clock(), event: 'device_revoked', stationId, actorId: permit.actorId });
      return notice;
    });
  }

  async queueCommand(input: { operationId: string; stationId: string; kind: CommandKind; sessionId: string; expectedState: DeviceState }, permitMessage: Signed<Permit>): Promise<Signed<DeviceCommand>> {
    if (!input.operationId || !input.sessionId || !['start_session', 'end_session'].includes(input.kind)) throw new Error('COMMAND_INVALID');
    return this.change(state => {
      const permit = this.authorize(permitMessage, input.stationId, input.kind, state);
      const device = state.devices[input.stationId];
      if (!device || device.revoked || device.epoch !== permit.epoch) throw new Error('DEVICE_FENCED');
      const existing = state.operations[input.operationId];
      if (existing) {
        if (existing.cancelledAt) throw new Error('OPERATION_CANCELLED');
        const original = existing.command.payload;
        if (original.stationId !== input.stationId || original.kind !== input.kind || original.sessionId !== input.sessionId || original.expectedState !== input.expectedState || original.permitId !== permit.permitId) throw new Error('OPERATION_ID_REUSED');
        return existing.command;
      }
      const command: DeviceCommand = { ...input, permitId: permit.permitId, venueId: state.venueId, sequence: device.nextSequence++, epoch: permit.epoch, writerGeneration: permit.writerGeneration, expiresAt: Math.min(permit.expiresAt, state.writer!.expiresAt, this.clock() + 30_000) };
      const envelope = signed(command, this.coordinatorPrivateKey);
      state.operations[input.operationId] = { command: envelope, ack: null };
      state.audit.push({ at: this.clock(), event: 'command_queued', stationId: input.stationId, operationId: input.operationId, actorId: permit.actorId });
      return envelope;
    });
  }

  async receiveAck(message: Signed<DeviceAck>): Promise<void> {
    await this.change(state => {
      const ack = message.payload;
      const operation = state.operations[ack.operationId];
      const command = operation?.command.payload;
      const device = state.devices[ack.stationId];
      if (!operation || operation.cancelledAt || !command || !device || device.revoked || !valid(message, device.publicKey) || command.stationId !== ack.stationId || command.sequence !== ack.sequence || command.epoch !== ack.epoch) throw new Error('ACK_DENIED');
      if (operation.ack) {
        if (digest(operation.ack) !== digest(message)) throw new Error('ACK_CHANGED');
        return;
      }
      operation.ack = message;
      if (ack.sequence >= device.lastAckSequence) {
        device.lastAckSequence = ack.sequence;
        device.observedState = ack.observedState;
        device.sessionId = ack.sessionId;
      }
      state.audit.push({ at: this.clock(), event: ack.accepted ? 'command_applied' : 'command_rejected', stationId: ack.stationId, operationId: ack.operationId });
    });
  }

  async receiveHeartbeat(message: Signed<Heartbeat>): Promise<void> {
    await this.change(state => {
      const beat = message.payload;
      const device = state.devices[beat.stationId];
      if (!device || device.revoked || !valid(message, device.publicKey) || beat.epoch !== device.epoch || beat.writerGeneration !== state.writer?.generation || beat.sequence <= device.lastHeartbeatSequence || beat.lastCommandSequence < device.lastAckSequence) throw new Error('HEARTBEAT_DENIED');
      device.lastHeartbeatSequence = beat.sequence;
      device.lastHeartbeatAt = this.clock();
      device.observedState = beat.observedState;
      device.sessionId = beat.sessionId;
      state.audit.push({ at: this.clock(), event: 'heartbeat', stationId: beat.stationId });
    });
  }

  snapshot(staleAfterMs = 15_000): { stations: Record<string, { connectivity: 'connected' | 'unknown'; observedState: DeviceState | 'unknown'; sessionId: string | null }>; pendingOperations: string[]; audit: CoordinatorState['audit'] } {
    const stations = Object.fromEntries(Object.entries(this.state.devices).map(([stationId, device]) => {
      const hasPending = Object.values(this.state.operations).some(operation => operation.command.payload.stationId === stationId && !operation.ack && !operation.cancelledAt);
      const fresh = !device.revoked && !hasPending && device.lastHeartbeatAt !== null && this.clock() - device.lastHeartbeatAt <= staleAfterMs;
      return [stationId, { connectivity: fresh ? 'connected' as const : 'unknown' as const, observedState: fresh ? device.observedState : 'unknown' as const, sessionId: fresh ? device.sessionId : null }];
    }));
    return { stations, pendingOperations: Object.entries(this.state.operations).filter(([, operation]) => !operation.ack && !operation.cancelledAt).map(([id]) => id), audit: structuredClone(this.state.audit) };
  }

  pending(operationId: string): Signed<DeviceCommand> | null {
    const operation = this.state.operations[operationId];
    return operation && !operation.ack && !operation.cancelledAt ? structuredClone(operation.command) : null;
  }
}
