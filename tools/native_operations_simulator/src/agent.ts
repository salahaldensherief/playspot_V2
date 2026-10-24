import type { AgentState, DeviceAck, DeviceCommand, EnrollmentProof, Heartbeat, Signed } from './contract.ts';
import { digest, signed, valid } from './signature.ts';
import { JsonStore } from './store.ts';

type Clock = () => number;

export class SimulatedAgent {
  private queue: Promise<void> = Promise.resolve();

  private constructor(private readonly store: JsonStore<AgentState>, private state: AgentState, private readonly devicePrivateKey: string, private readonly coordinatorPublicKey: string, private readonly clock: Clock) {}

  static async open(path: string, venueId: string, stationId: string, epoch: number, devicePrivateKey: string, coordinatorPublicKey: string, clock: Clock = Date.now): Promise<SimulatedAgent> {
    const store = new JsonStore<AgentState>(path);
    const state = await store.load(() => ({ version: 1, venueId, stationId, epoch, lastSequence: 0, heartbeatSequence: 0, observedState: 'idle', sessionId: null, operations: {} }));
    if (state.venueId !== venueId || state.stationId !== stationId || state.epoch !== epoch || !state.operations) throw new Error('STORE_INVALID');
    return new SimulatedAgent(store, state, devicePrivateKey, coordinatorPublicKey, clock);
  }

  enrollmentProof(token: string, publicKey: string): Signed<EnrollmentProof> {
    return signed({ token, venueId: this.state.venueId, stationId: this.state.stationId, publicKey }, this.devicePrivateKey);
  }

  async apply(envelope: Signed<DeviceCommand>): Promise<Signed<DeviceAck>> {
    const run = this.queue.then(async () => {
      const command = envelope.payload;
      if (!valid(envelope, this.coordinatorPublicKey) || command.venueId !== this.state.venueId || command.stationId !== this.state.stationId || command.epoch !== this.state.epoch) throw new Error('COMMAND_DENIED');
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
      const copy = structuredClone(this.state);
      copy.heartbeatSequence += 1;
      const message = signed({ stationId: copy.stationId, epoch: copy.epoch, sequence: copy.heartbeatSequence, lastCommandSequence: copy.lastSequence, observedState: copy.observedState, sessionId: copy.sessionId }, this.devicePrivateKey);
      await this.store.save(copy);
      this.state = copy;
      return message;
    });
    this.queue = run.then(() => undefined, () => undefined);
    return run;
  }
}
