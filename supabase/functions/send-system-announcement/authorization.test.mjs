import assert from 'node:assert/strict';
import {test} from 'node:test';
import {isAnnouncementCallerAuthorized, dispatchAuthorizedAnnouncement} from './authorization.js';

const request = headers => new Request('https://example.invalid/announcement', {headers});
const dependencies = overrides => ({
  authenticate: async () => null,
  authorize: async () => false,
  expectedKey: async () => 'fixture-server-secret',
  ...overrides,
});
test('anonymous and public anon-key callers are rejected', async () => {
  for (const headers of [{}, {apikey: 'fixture-public-anon-key'}]) {
    assert.equal(await isAnnouncementCallerAuthorized(request(headers), dependencies()), false);
  }
});
for (const role of ['owner', 'admin', 'cashier', 'user', 'inactive_super_admin', 'banned_super_admin']) {
  test(`${role} cannot broadcast when canonical authority denies access`, async () => {
    assert.equal(await isAnnouncementCallerAuthorized(request({Authorization: 'Bearer fixture-token'}), dependencies({
      authenticate: async () => ({id: 'fixture-user', role}),
      authorize: async () => false,
    })), false);
  });
}
test('verified active platform admin uses the caller authorization', async () => {
  const authorization = 'Bearer fixture-token';
  assert.equal(await isAnnouncementCallerAuthorized(request({Authorization: authorization}), dependencies({
    authenticate: async value => {assert.equal(value, authorization); return {id: 'fixture-admin'};},
    authorize: async value => {assert.equal(value, authorization); return true;},
  })), true);
});
test('invalid bearer token cannot reach platform authorization', async () => {
  assert.equal(await isAnnouncementCallerAuthorized(request({Authorization: 'Bearer invalid'}), dependencies({
    authorize: async () => {assert.fail('Unauthenticated caller must not authorize');},
  })), false);
});
test('trusted database key remains accepted and empty key is rejected', async () => {
  assert.equal(await isAnnouncementCallerAuthorized(request({apikey: 'fixture-server-secret'}), dependencies()), true);
  assert.equal(await isAnnouncementCallerAuthorized(request({apikey: 'anything'}), dependencies({expectedKey: async () => ''})), false);
});

test('caller-controlled topic and role cannot reach mocked FCM without authority', async () => {
  let deliveries = 0;
  const send = async () => {deliveries++; return new Response('sent');};
  for (const role of ['owner','cashier','banned_super_admin']) {
    const req = new Request('https://example.invalid/announcement', {
      method: 'POST', headers: {Authorization: 'Bearer fixture-token'},
      body: JSON.stringify({topic:'all_users',role:'super_admin',data:{type:'system_announcement'}}),
    });
    const response = await dispatchAuthorizedAnnouncement(req,
      r => isAnnouncementCallerAuthorized(r, dependencies({
        authenticate: async () => ({id:'fixture-user',role}),
        authorize: async () => false,
      })), send);
    assert.equal(response.status,403);
  }
  assert.equal(deliveries,0);
});

test('canonical admin and server secret each dispatch once to mocked FCM', async () => {
  let deliveries=0;
  const send = async payload => {deliveries++;assert.equal(payload.topic,'all_users');return new Response('sent');};
  const makeRequest=headers=>new Request('https://example.invalid/announcement',{
    method:'POST',headers,body:JSON.stringify({topic:'all_users'}),
  });
  const admin=makeRequest({Authorization:'Bearer admin-token'});
  assert.equal((await dispatchAuthorizedAnnouncement(admin,
    r=>isAnnouncementCallerAuthorized(r,dependencies({
      authenticate:async()=>({id:'admin'}),authorize:async()=>true,
    })),send)).status,200);
  const service=makeRequest({apikey:'fixture-server-secret'});
  assert.equal((await dispatchAuthorizedAnnouncement(service,
    r=>isAnnouncementCallerAuthorized(r,dependencies()),send)).status,200);
  assert.equal(deliveries,2);
});
