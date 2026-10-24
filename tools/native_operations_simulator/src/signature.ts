import { createHash, generateKeyPairSync, sign, verify, type KeyObject } from 'node:crypto';
import type { Signed } from './contract.ts';

export function keyPair(): { publicKey: string; privateKey: string } {
  const keys = generateKeyPairSync('ed25519');
  return {
    publicKey: keys.publicKey.export({ type: 'spki', format: 'pem' }).toString(),
    privateKey: keys.privateKey.export({ type: 'pkcs8', format: 'pem' }).toString(),
  };
}

function canonical(value: unknown): string {
  if (value === null || typeof value !== 'object') return JSON.stringify(value);
  if (Array.isArray(value)) return `[${value.map(canonical).join(',')}]`;
  const entries = Object.entries(value as Record<string, unknown>).sort(([a], [b]) => a.localeCompare(b));
  return `{${entries.map(([key, item]) => `${JSON.stringify(key)}:${canonical(item)}`).join(',')}}`;
}

export function digest(value: unknown): string {
  return createHash('sha256').update(canonical(value)).digest('hex');
}

export function signed<T>(payload: T, privateKey: string | KeyObject): Signed<T> {
  return { payload, signature: sign(null, Buffer.from(canonical(payload)), privateKey).toString('base64url') };
}

export function valid<T>(message: Signed<T>, publicKey: string | KeyObject): boolean {
  try {
    return verify(null, Buffer.from(canonical(message.payload)), publicKey, Buffer.from(message.signature, 'base64url'));
  } catch {
    return false;
  }
}
