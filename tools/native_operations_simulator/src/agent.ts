import type { AgentState, DeviceAck, DeviceCommand, DeviceRevocation, EnrollmentProof, Heartbeat, Signed, WriterFence } from './contract.ts';
import { digest, signed, valid } from './signature.ts';
import { JsonStore } from './store.ts';

type Clock = () => number;

export class SimulatedAgent {
  private queue: Promise<void> = Promise.resolve();

  private constructor(private readonly store: JsonStore<AgentState>, private state: AgentState, private readonly devicePrivateKey: string, private readonly coordinatorPublicKey: string, private readonly clock: Clock) {}

  static async open(path: string, venueId: string, stationId: string, epoch: number, devicePrivateKey: string, coordinatorPublicKey: string, clock: Clock = Date.now): Promise<SimulatedAgent> {
    const store = new JsonStore<AgentState>(path);
    const state = await store.load(() => ({ version: 1, venueId, stationId, epoch, revoked: false, writerGeneration: 0, lastSequence: 0, heartbeatSequence: 0, observedState: 'idle', sessionId: null, operations: {} }));
    if (state.venueId !== venueId || state.stationId !== stationId || state.epoch !== epoch || !state.operations) throw new Error('STORE_INVALID');
    return new SimulatedAgent(store, state, devicePrivateKey, coordinatorPublicKey, clock);
  }

  enrollmentProof(token: string, publicKey: string): Signed<EnrollmentProof> {
    if (this.state.revoked) throw new Error('DEVICE_REVOKED');
    return signed({ token, venueId: this.state.venueId, stationId: this.state.stationId, publicKey }, this.devicePrivateKey);
  }

  async applyFence(message: Signed<WriterFence>): Promise<void> {
    const run = this.queue.then(async () => {
      const fence = message.payload;
      if (!valid(message, this.coordinatorPublicKey) || this.state.revoked || fence.venueId !== this.state.venueId || fence.stationId !== this.state.stationId || fence.epoch !== this.state.epoch || !Number.isSafeInteger(fence.writerGeneration) || !Number.isSafeInteger(fence.nextSequence) || fence.nextSequence < 1 || fence.writerGeneration < (this.state.writerGeneration ?? 0)) throw new Error('FENCE_DENIED');
      const copy = structuredClone(this.state);
      if (fence.writerGeneration > (copy.writerGeneration ?? 0)) {
        copy.writerGeneration = fence.writerGeneration;
        copy.lastSequence = Math.max(copy.lastSequence, fence.nextSequence - 1);
      }
      await this.store.save(copy);
      this.state = copy;
    });
    this.queue = run.then(() => undefined, () => undefined);
    return run;
  }

  async applyRevocation(message: Signed<DeviceRevocation>): Promise<void> {
    const run = this.queue.then(async () => {
      const notice = message.payload;
      if (!valid(message, this.coordinatorPublicKey) || notice.venueId !== this.state.venueId || notice.stationId !== this.state.stationId || !Number.isSafeInteger(notice.newEpoch) || notice.newEpoch !== notice.oldEpoch + 1) throw new Error('REVOCATION_DENIED');
      if (this.state.revoked && this.state.epoch === notice.newEpoch) return;
      if (this.state.revoked || this.state.epoch !== notice.oldEpoch) throw new Error('REVOCATION_DENIED');
      const copy = structuredClone(this.state);
      copy.epoch = notice.newEpoch;
      copy.revoked = true;
      await this.store.save(copy);
      this.state = copy;
    });
    this.queue = run.then(() => undefined, () => undefined);
    return run;
  }

  async apply(envelope: Signed<DeviceCommand>): Promise<Signed<DeviceAck>> {
    const run = this.queue.then(async () => {
      const command = envelope.payload;
      if (!valid(envelope, this.coordinatorPublicKey) || this.state.revoked || command.venueId !== this.state.venueId || command.stationId !== this.state.stationId || command.epoch !== this.state.epoch) throw new Error('COMMAND_DENIED');
      if (command.writerGeneration !== this.state.writerGeneration) throw new Error('STALE_WRITER');
      const previous = this.state.operations[command.operationId];
      if (previous) {
        if (previous.digest !== digest(envelope)) throw new Error('OPERATION_ID_REUSED');
        return previous.ack;
      }
      if (command.expiresAt <= this.clock() || command.sequence !== this.state.lastSequence + 1) throw new Error('COMMAND_EXPIRED_OR_OUT_OF_ORDER');
      const copy = structuredClone(this.state);
      const accepted = command.expectedState === copy.observedState && (
        command.kind === 'start_session' ? copy.observedState === 'idle' : copy.observedState === 'running' && copy.sessionId === command.sessionId
      );
      if (accepted) {
        copy.observedState = command.kind === 'start_session' ? 'running' : 'idle';
        copy.sessionId = command.kind === 'start_session' ? command.sessionId : null;
      }
      const ack: DeviceAck = { operationId: command.operationId, stationId: command.stationId, sequence: command.sequence, epoch: command.epoch, accepted, observedState: copy.observedState, sessionId: copy.sessionId, reason: accepted ? null : 'STATE_CONFLICT' };
      const message = signed(ack, this.devicePrivateKey);
      copy.lastSequence = command.sequence;
      copy.operations[command.operationId] = { digest: digest(envelope), ack: message };
      await this.store.save(copy);
      this.state = copy;
      return message;
    });
    this.queue = run.then(() => undefined, () => undefined);
    return run;
  }

  async heartbeat(): Promise<Signed<Heartbeat>> {
    const run = this.queue.then(async () => {
      if (this.state.revoked) throw new Error('DEVICE_REVOKED');
      const copy = structuredClone(this.state);
      copy.heartbeatSequence += 1;
      const message = signed({ stationId: copy.stationId, epoch: copy.epoch, writerGeneration: copy.writerGeneration ?? 0, sequence: copy.heartbeatSequence, lastCommandSequence: copy.lastSequence, observedState: copy.observedState, sessionId: copy.sessionId }, this.devicePrivateKey);
      await this.store.save(copy);
      this.state = copy;
      return message;
    });
    this.queue = run.then(() => undefined, () => undefined);
    return run;
  }
}
