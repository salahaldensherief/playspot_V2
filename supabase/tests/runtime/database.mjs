import {createRequire} from 'node:module';
import {resolve} from 'node:path';
import {randomUUID} from 'node:crypto';

const runtime = process.env.PLAYSPOT_TEST_RUNTIME ?? resolve('supabase/tests/runtime');
const require = createRequire(resolve(runtime, 'package.json'));

export async function createFixtureDatabase() {
  if (!process.env.PLAYSPOT_NATIVE_PG_PORT) {
    const {PGlite} = require('@electric-sql/pglite');
    return new PGlite();
  }
  // This fixture never accepts a server URL or production connection string.
  const port = Number(process.env.PLAYSPOT_NATIVE_PG_PORT);
  if (port !== 55439) throw new Error('Synthetic PostgreSQL must use local port 55439');
  const {Client} = require('pg');
  const options = {host: '127.0.0.1', port, user: 'playspot_fixture', database: 'postgres'};
  const control = new Client(options);
  await control.connect();
  const database = `playspot_fixture_${randomUUID().replaceAll('-', '')}`;
  try {
    for (const role of ['anon', 'authenticated', 'service_role', 'supabase_auth_admin']) {
      await control.query(`DO $$ BEGIN CREATE ROLE ${role}; EXCEPTION WHEN duplicate_object THEN NULL; END $$`);
    }
    await control.query(`CREATE DATABASE "${database}"`);
    const client = new Client({...options, database});
    await client.connect();
    console.log('Fixture database:', (await client.query('SHOW server_version')).rows[0].server_version);
    let closed = false;
    return {
      database,
      async connect() {
        const peer = new Client({...options, database});
        await peer.connect();
        return peer;
      },
      async exec(sql) {
        // Roles are cluster-wide in native PostgreSQL; bootstrap creates only fixture roles.
        return client.query(sql.replace(/CREATE ROLE (anon|authenticated|service_role)\s*;/gi, ''));
      },
      query: (...args) => client.query(...args),
      async close() {
        if (closed) return;
        closed = true;
        await client.end();
        await control.query(`DROP DATABASE "${database}"`);
        await control.end();
      },
    };
  } catch (error) {
    await control.end();
    throw error;
  }
}
