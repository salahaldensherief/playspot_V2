// SIMULATION ONLY. No sockets, HTTP, processes, Supabase or physical devices.
// All state is ephemeral. This is NOT a production authorization boundary.
const copy = value => structuredClone(value);
const id = value => typeof value === 'string' && /^[A-Za-z0-9_-]{1,80}$/.test(value);

export class MockMttlAdapter {
  #devices = new Map();
  constructor(devices = []) {
    for (const device of devices) {
      if (![device.deviceId, device.tenantId, device.installationId].every(id) ||
          this.#devices.has(device.deviceId)) throw new Error('INVALID_OR_DUPLICATE_DEVICE');
      this.#devices.set(device.deviceId, {...device, online: true, generation: 1,
        revision: 0, outlets: [false, false, false, false], effects: 0});
    }
  }
  discover(scope) {
    return [...this.#devices.values()].filter(d => d.tenantId === scope.tenantId &&
      d.installationId === scope.installationId).map(d => ({
      deviceId: d.deviceId, adapter: 'mock-mttl-w01', simulated: true,
      firmware: 'SIMULATED-UNKNOWN', channels: [1, 2, 3, 4],
    }));
  }
  status(scope, deviceId) {
    const d = this.#scoped(scope, deviceId);
    return copy({deviceId, simulated: true, online: d.online, generation: d.generation,
      revision: d.revision, effects: d.effects,
      outlets: d.outlets.map((on, i) => ({channel: i + 1, state: d.online ? (on ? 'on' : 'off') : 'unknown'}))});
  }
  #scoped(scope, deviceId) {
    const d = this.#devices.get(deviceId);
    if (!d || d.tenantId !== scope.tenantId || d.installationId !== scope.installationId) {
      throw new Error('DEVICE_SCOPE_DENIED');
    }
    return d;
  }
  // Test harness fault injection only, never a device command.
  setOnline(scope, deviceId, online) {
    const d = this.#scoped(scope, deviceId);
    if (typeof online !== 'boolean') throw new Error('INVALID_ONLINE');
    if (d.online !== online) { d.online = online; ++d.generation; }
  }
  apply(scope, c, {fault = 'none'} = {}) {
    if (!c || c.type !== 'set_outlet' || !Number.isInteger(c.channel) ||
        c.channel < 1 || c.channel > 4 || typeof c.on !== 'boolean' ||
        !['none', 'timeout-before', 'timeout-after'].includes(fault)) throw new Error('INVALID_COMMAND');
    const d = this.#scoped(scope, c.deviceId);
    if (!d.online) return {status: 'offline'};
    if (fault === 'timeout-before') return {status: 'unknown'};
    if (d.revision !== c.expectedRevision) return {status: 'rejected', reason: 'STALE_REVISION'};
    d.outlets[c.channel - 1] = c.on;
    ++d.effects; ++d.revision;
    if (fault === 'timeout-after') return {status: 'unknown'};
    return {status: 'confirmed', observedRevision: d.revision};
  }
}

export class MockWindowsConnector {
  #adapter;
  constructor(adapter) {
    if (!(adapter instanceof MockMttlAdapter)) throw new Error('MOCK_ONLY');
    this.#adapter = adapter;
  }
  discover(scope) { return this.#adapter.discover(scope); }
  status(scope, deviceId) { return this.#adapter.status(scope, deviceId); }
  send(scope, command, options) { return this.#adapter.apply(scope, command, options); }
}

export class BridgeLabCommandService {
  #connector; #enabled; #clock; #receipts = new Map(); #audit = [];
  #revoked = new Set(); #disconnected = new Set(); #sequence = new Map(); #unresolved = new Set();
  constructor({connector, enabled = false, clock = () => Date.now()} = {}) {
    if (!(connector instanceof MockWindowsConnector)) throw new Error('MOCK_ONLY');
    this.#connector = connector; this.#enabled = enabled === true; this.#clock = clock;
  }
  #scopeKey(scope) { return JSON.stringify([scope.tenantId, scope.installationId]); }
  #gate(scope) {
    if (!this.#enabled) throw new Error('LAB_DISABLED');
    if (!scope || ![scope.tenantId, scope.installationId, scope.actorId].every(id) ||
        scope.hardwareTestAllowed !== true) throw new Error('SCOPE_DENIED');
    const key = this.#scopeKey(scope);
    if (this.#revoked.has(key)) throw new Error('INSTALLATION_REVOKED');
    if (this.#disconnected.has(key)) throw new Error('CONNECTOR_DISCONNECTED');
  }
  #log(scope, command, status) {
    this.#audit.push(Object.freeze({at: this.#clock(), actorId: id(scope?.actorId) ? scope.actorId : null,
      tenantId: id(scope?.tenantId) ? scope.tenantId : null,
      installationId: id(scope?.installationId) ? scope.installationId : null,
      deviceId: id(command?.deviceId) ? command.deviceId : null,
      commandId: id(command?.commandId) ? command.commandId : null, status}));
  }
  discover(scope) { this.#gate(scope); return this.#connector.discover(scope); }
  status(scope, deviceId) { this.#gate(scope); return this.#connector.status(scope, deviceId); }
  audit(scope) {
    this.#gate(scope);
    return copy(this.#audit.filter(e => e.tenantId === scope.tenantId && e.installationId === scope.installationId));
  }
  revoke(scope) { this.#gate(scope); this.#revoked.add(this.#scopeKey(scope)); this.#log(scope, null, 'revoked'); }
  disconnect(scope) { this.#gate(scope); this.#disconnected.add(this.#scopeKey(scope)); this.#log(scope, null, 'disconnected'); }
  reconnect(scope) {
    const key = this.#scopeKey(scope);
    this.#disconnected.delete(key);
    try { this.#gate(scope); } catch (error) { this.#disconnected.add(key); throw error; }
    this.#log(scope, null, 'reconnected-reconcile-required');
    // No queue drain or replay. An unknown command stays blocked until reconciliation.
  }
  execute(scope, command, options = {}) {
    const c = command;
    try {
      this.#gate(scope);
      if (!c || ![c.commandId, c.deviceId].every(id) || c.type !== 'set_outlet' ||
          !Number.isInteger(c.channel) || c.channel < 1 || c.channel > 4 || typeof c.on !== 'boolean' ||
          !Number.isSafeInteger(c.sequence) || c.sequence < 1 ||
          !Number.isSafeInteger(c.expectedRevision) || c.expectedRevision < 0 ||
          !Number.isSafeInteger(c.deadlineMs) ||
          Object.keys(c).some(k => !['commandId','deviceId','type','channel','on','sequence','expectedRevision','deadlineMs'].includes(k))) {
        throw new Error('INVALID_COMMAND');
      }
      const observed = this.#connector.status(scope, c.deviceId); // scope check even on replay
      const key = JSON.stringify([scope.tenantId, scope.installationId, c.commandId]);
      const fingerprint = JSON.stringify([c.deviceId,c.type,c.channel,c.on,c.sequence,c.expectedRevision,c.deadlineMs]);
      const prior = this.#receipts.get(key);
      if (prior) {
        if (prior.fingerprint !== fingerprint) throw new Error('IDEMPOTENCY_CONFLICT');
        this.#log(scope, c, 'duplicate'); return copy(prior.receipt);
      }
      const deviceKey = JSON.stringify([scope.tenantId, scope.installationId, c.deviceId]);
      if (this.#unresolved.has(deviceKey)) throw new Error('RECONCILIATION_REQUIRED');
      if (c.sequence <= (this.#sequence.get(deviceKey) ?? 0)) throw new Error('STALE_SEQUENCE');
      let receipt;
      if (c.deadlineMs <= this.#clock()) receipt = {status: 'expired'};
      else if (!observed.online) receipt = {status: 'offline'};
      else receipt = this.#connector.send(scope, copy(c), options);
      this.#sequence.set(deviceKey, c.sequence);
      if (receipt.status === 'unknown') this.#unresolved.add(deviceKey);
      this.#receipts.set(key, {fingerprint, receipt: copy(receipt), command: copy(c), deviceKey});
      this.#log(scope, c, receipt.status);
      return copy(receipt);
    } catch (error) {
      this.#log(scope, c, error.message);
      return {status: 'rejected', reason: error.message};
    }
  }
  reconcile(scope, commandId) {
    this.#gate(scope);
    const key = JSON.stringify([scope.tenantId, scope.installationId, commandId]);
    const entry = this.#receipts.get(key);
    if (!entry) throw new Error('UNKNOWN_COMMAND');
    if (entry.receipt.status !== 'unknown') return copy(entry.receipt);
    const observed = this.#connector.status(scope, entry.command.deviceId);
    if (!observed.online) return {status: 'unknown', reason: 'DEVICE_OFFLINE'};
    // This mock uses a revision and desired-state readback; stock MTTL has no
    // transaction ID, so real readback cannot prove command causation.
    const matches = observed.revision === entry.command.expectedRevision + 1 &&
      observed.outlets[entry.command.channel - 1].state === (entry.command.on ? 'on' : 'off');
    if (!matches) return {status: 'unknown', reason: 'MANUAL_REVIEW_REQUIRED'};
    entry.receipt = {status: 'confirmed', observedRevision: observed.revision, reconciled: true};
    this.#unresolved.delete(entry.deviceKey);
    this.#log(scope, entry.command, 'reconciled');
    return copy(entry.receipt);
  }
}
