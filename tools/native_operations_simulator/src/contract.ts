export type DeviceState = 'idle' | 'running';
export type CommandKind = 'start_session' | 'end_session';
export type PermitAction = CommandKind | 'enroll' | 'revoke';

export interface WriterLease {
  venueId: string;
  writerId: string;
  generation: number;
  expiresAt: number;
}

export interface Permit {
  permitId: string;
  venueId: string;
  stationId: string;
  actorId: string;
  shiftId: string;
  writerId: string;
  writerGeneration: number;
  epoch: number;
  expiresAt: number;
  actions: PermitAction[];
}

export interface Signed<T> {
  payload: T;
  signature: string;
}

export interface DeviceCommand {
  operationId: string;
  permitId: string;
  venueId: string;
  stationId: string;
  kind: CommandKind;
  sessionId: string;
  sequence: number;
  epoch: number;
  writerGeneration: number;
  expiresAt: number;
  expectedState: DeviceState;
}

export interface DeviceAck {
  operationId: string;
  stationId: string;
  sequence: number;
  epoch: number;
  accepted: boolean;
  observedState: DeviceState;
  sessionId: string | null;
  reason: string | null;
}

export interface Heartbeat {
  stationId: string;
  epoch: number;
  writerGeneration: number;
  sequence: number;
  lastCommandSequence: number;
  observedState: DeviceState;
  sessionId: string | null;
}

export interface EnrollmentProof {
  token: string;
  venueId: string;
  stationId: string;
  publicKey: string;
}

export interface WriterFence {
  venueId: string;
  stationId: string;
  epoch: number;
  writerGeneration: number;
  nextSequence: number;
}

export interface DeviceRevocation {
  venueId: string;
  stationId: string;
  oldEpoch: number;
  newEpoch: number;
}

export interface AuditEvent {
  at: number;
  event: string;
  stationId: string;
  operationId?: string;
  actorId?: string;
}

export interface StoredOperation {
  command: Signed<DeviceCommand>;
  ack: Signed<DeviceAck> | null;
  cancelledAt?: number;
}

export interface CoordinatorState {
  version: 1;
  venueId: string;
  writer?: WriterLease | null;
  devices: Record<string, { publicKey: string; epoch: number; revoked?: boolean; nextSequence: number; fenceSequence?: number; lastAckSequence: number; lastHeartbeatSequence: number; lastHeartbeatAt: number | null; observedState: DeviceState | 'unknown'; sessionId: string | null }>;
  enrollment: Record<string, { stationId: string; permitId: string; epoch: number; expiresAt: number; used: boolean }>;
  operations: Record<string, StoredOperation>;
  audit: AuditEvent[];
}

export interface AgentState {
  version: 1;
  venueId: string;
  stationId: string;
  epoch: number;
  revoked?: boolean;
  writerGeneration?: number;
  lastSequence: number;
  heartbeatSequence: number;
  observedState: DeviceState;
  sessionId: string | null;
  operations: Record<string, { digest: string; ack: Signed<DeviceAck> }>;
}
