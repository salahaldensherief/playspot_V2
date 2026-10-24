import { mkdir, open, readFile, rename, rm } from 'node:fs/promises';
import { dirname } from 'node:path';
import { randomUUID } from 'node:crypto';

export class JsonStore<T extends { version: 1 }> {
  constructor(readonly path: string) {}

  async load(initial: () => T): Promise<T> {
    try {
      const state: unknown = JSON.parse(await readFile(this.path, 'utf8'));
      if (!state || typeof state !== 'object' || (state as T).version !== 1) throw new Error('STORE_INVALID');
      return state as T;
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code === 'ENOENT') {
        const state = initial();
        await this.save(state);
        return state;
      }
      throw new Error('STORE_CORRUPT', { cause: error });
    }
  }

  async save(state: T): Promise<void> {
    await mkdir(dirname(this.path), { recursive: true });
    const temporary = `${this.path}.${randomUUID()}.tmp`;
    const file = await open(temporary, 'wx', 0o600);
    try {
      await file.writeFile(JSON.stringify(state));
      await file.sync();
    } finally {
      await file.close();
    }
    try {
      await rename(temporary, this.path);
    } catch (error) {
      await rm(temporary, { force: true });
      throw error;
    }
  }
}
