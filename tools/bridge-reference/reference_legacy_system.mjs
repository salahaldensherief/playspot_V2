// OFFLINE IN-MEMORY REFERENCE ONLY. Not a connector, server, or Windows agent.
// No network, credentials, real booking data, payments, or Supabase access.
export class ReferenceLegacySystem {
  constructor({mode = 'cloud_api'} = {}) {
    if (!['cloud_api', 'local_agent', 'hybrid'].includes(mode)) {
      throw new Error('UNSUPPORTED_MODE');
    }
    this.mode = mode;
    this.online = true;
    this.receipts = new Map();
    this.reservations = new Map();
  }

  setOnline(online) { this.online = Boolean(online); }

  // Use vendor-side persistent dedupe in real integrations. This map is
  // deliberately ephemeral so it cannot be used as a production reference.
  execute(command, {simulateLostAck = false} = {}) {
    if (!this.online) return {status: 'unavailable'};
    if (!command || !command.integrationId || !command.idempotencyKey ||
        !command.type || !command.resourceId) {
      return {status: 'rejected', reason: 'INVALID_COMMAND'};
    }
    const key = JSON.stringify([command.integrationId, command.idempotencyKey]);
    const fingerprint = JSON.stringify(command);
    if (this.receipts.has(key)) {
      const prior = this.receipts.get(key);
      return prior.fingerprint === fingerprint
        ? {...prior.receipt}
        : {status: 'rejected', reason: 'IDEMPOTENCY_KEY_REUSED'};
    }

    let receipt;
    const reservationId = command.reservationId;
    if (command.type === 'reserve') {
      const start = Date.parse(command.fromUtc);
      const end = Date.parse(command.toUtc);
      if (!Number.isFinite(start) || !Number.isFinite(end) || start >= end) {
        return {status: 'rejected', reason: 'INVALID_RANGE'};
      }
      const overlap = [...this.reservations.values()].some(r =>
        r.integrationId === command.integrationId &&
        r.resourceId === command.resourceId &&
        r.status !== 'cancelled' &&
        start < r.end && end > r.start
      );
      if (overlap) {
        receipt = {status: 'rejected', reason: 'SLOT_OCCUPIED'};
      } else {
        const id = key;
        this.reservations.set(id, {
          integrationId: command.integrationId,
          resourceId: command.resourceId,
          start, end, status: 'reserved', minutesAdded: 0,
        });
        receipt = {status: 'acknowledged', reservationId: id};
      }
    } else if (command.type === 'cancel_reservation') {
      const r = this.reservations.get(reservationId);
      if (!r || r.integrationId !== command.integrationId ||
          r.resourceId !== command.resourceId || r.status === 'ended') {
        receipt = {status: 'rejected', reason: 'BAD_RESERVATION'};
      } else {
        r.status = 'cancelled';
        receipt = {status: 'acknowledged', reservationId};
      }
    } else if (['start_session', 'extend_session', 'end_session'].includes(command.type)) {
      const r = this.reservations.get(reservationId);
      if (!r || r.integrationId !== command.integrationId ||
          r.resourceId !== command.resourceId) {
        receipt = {status: 'rejected', reason: 'BAD_RESERVATION'};
      } else if (command.type === 'start_session' && r.status === 'reserved') {
        r.status = 'running';
        receipt = {status: 'acknowledged', reservationId};
      } else if (command.type === 'extend_session' && r.status === 'running' &&
          Number.isInteger(command.additionalMinutes) &&
          command.additionalMinutes > 0) {
        // Demonstration only: a real extension must also atomically check
        // the next booking. Intentionally reject until that is implemented.
        receipt = {status: 'rejected', reason: 'EXTENSION_CAPACITY_NOT_CHECKED'};
      } else if (command.type === 'end_session' && r.status === 'running') {
        r.status = 'ended';
        receipt = {status: 'acknowledged', reservationId};
      } else {
        receipt = {status: 'rejected', reason: 'ILLEGAL_STATE_TRANSITION'};
      }
    } else {
      receipt = {status: 'rejected', reason: 'UNSUPPORTED_COMMAND'};
    }

    this.receipts.set(key, {fingerprint, receipt});
    if (simulateLostAck && receipt.status === 'acknowledged') {
      return {status: 'ambiguous', reason: 'EXECUTED_BUT_ACK_LOST'};
    }
    return receipt;
  }
}
