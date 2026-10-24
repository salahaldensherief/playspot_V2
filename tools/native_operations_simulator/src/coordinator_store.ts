import { mkdirSync } from 'node:fs';
import { dirname } from 'node:path';
import { DatabaseSync } from 'node:sqlite';
import type { CoordinatorState } from './contract.ts';

function parseState(raw: unknown, venueId: string): CoordinatorState {
  try {
    if (typeof raw !== 'string') throw new Error('Missing state');
    const state = JSON.parse(raw) as CoordinatorState;
    if (state.version !== 1 || state.venueId !== venueId || !state.devices || !state.operations || !state.enrollment || !Array.isArray(state.audit)) throw new Error('Invalid state');
    return state;
  } catch (error) {
    throw new Error('STORE_CORRUPT', { cause: error });
  }
}

/** SQLite serializes writes across coordinator processes; callbacks must stay synchronous. */
export class CoordinatorStore {
  private constructor(private readonly database: DatabaseSync, private readonly venueId: string) {}

  static open(path: string, venueId: string): CoordinatorStore {
    mkdirSync(dirname(path), { recursive: true });
    let database: DatabaseSync | undefined;
    try {
      database = new DatabaseSync(path, { timeout: 5_000 });
      database.exec('PRAGMA journal_mode=WAL; PRAGMA synchronous=FULL;');
      database.exec('CREATE TABLE IF NOT EXISTS coordinator_state (venue_id TEXT PRIMARY KEY, state_json TEXT NOT NULL)');
      const initial: CoordinatorState = { version: 1, venueId, writer: null, devices: {}, enrollment: {}, operations: {}, audit: [] };
      database.prepare('INSERT OR IGNORE INTO coordinator_state (venue_id, state_json) VALUES (?, ?)').run(venueId, JSON.stringify(initial));
      const check = database.prepare('PRAGMA quick_check').get() as { quick_check?: string } | undefined;
      if (check?.quick_check !== 'ok') throw new Error('Invalid SQLite database');
      const store = new CoordinatorStore(database, venueId);
      store.read();
      return store;
    } catch (error) {
      database?.close();
      throw new Error('STORE_CORRUPT', { cause: error });
    }
  }

  read(): CoordinatorState {
    const row = this.database.prepare('SELECT state_json FROM coordinator_state WHERE venue_id = ?').get(this.venueId) as { state_json?: unknown } | undefined;
    return parseState(row?.state_json, this.venueId);
  }

  transact<T>(action: (state: CoordinatorState) => T): T {
    this.database.exec('BEGIN IMMEDIATE');
    try {
      const state = this.read();
      const result = action(state);
      this.database.prepare('UPDATE coordinator_state SET state_json = ? WHERE venue_id = ?').run(JSON.stringify(state), this.venueId);
      this.database.exec('COMMIT');
      return result;
    } catch (error) {
      this.database.exec('ROLLBACK');
      throw error;
    }
  }
}
