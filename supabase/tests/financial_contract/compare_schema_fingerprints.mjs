#!/usr/bin/env node
import { readFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';

export function compare(reference, candidate) {
  for (const [label, manifest] of [['reference', reference], ['candidate', candidate]]) {
    if (manifest?.format !== 1 || !Number.isInteger(manifest.server_major) || !manifest.objects ||
        typeof manifest.objects !== 'object' || Array.isArray(manifest.objects)) {
      throw new Error(`Invalid ${label} schema fingerprint`);
    }
  }
  const differences = [];
  if (reference.server_major !== candidate.server_major) {
    differences.push(`Postgres major: ${reference.server_major} != ${candidate.server_major}`);
  }
  const keys = new Set([...Object.keys(reference.objects), ...Object.keys(candidate.objects)]);
  for (const key of [...keys].sort()) {
    const expected = reference.objects[key];
    const actual = candidate.objects[key];
    if (expected === undefined) differences.push(`Extra: ${key}`);
    else if (actual === undefined) differences.push(`Missing: ${key}`);
    else if (expected !== actual) differences.push(`Changed: ${key}`);
  }
  return differences;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  if (process.argv.length !== 4) {
    console.error('Usage: node compare_schema_fingerprints.mjs reference.json restored.json');
    process.exitCode = 2;
  } else {
    try {
      const reference = JSON.parse(readFileSync(process.argv[2], 'utf8'));
      const candidate = JSON.parse(readFileSync(process.argv[3], 'utf8'));
      const differences = compare(reference, candidate);
      if (differences.length) {
        console.error(`Schema mismatch (${differences.length}):\n${differences.join('\n')}`);
        process.exitCode = 1;
      } else {
        console.log(`Schema fingerprints match (${Object.keys(reference.objects).length} objects).`);
      }
    } catch (error) {
      console.error(error instanceof Error ? error.message : String(error));
      process.exitCode = 2;
    }
  }
}
