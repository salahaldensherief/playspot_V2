// Global announcements require the same active platform-admin boundary as SQL.
// Profile role labels alone do not establish this authority.
export async function isAnnouncementCallerAuthorized(request, dependencies) {
  const authorization = request.headers.get('Authorization') ?? '';
  if (/^Bearer\s+\S+$/i.test(authorization)) {
    const user = await dependencies.authenticate(authorization);
    if (user && await dependencies.authorize(authorization) === true) return true;
  }
  // Retain the trusted database webhook path; never treat the public anon key
  // as this secret. The lookup stays on the server and is not logged.
  const provided = request.headers.get('apikey');
  if (!provided) return false;
  const expected = await dependencies.expectedKey();
  return typeof expected === 'string' && expected.length > 0 && provided === expected;
}

// Keep the authorization gate outside payload parsing and FCM delivery.
export async function dispatchAuthorizedAnnouncement(request, authorize, send) {
  if (!(await authorize(request))) {
    return new Response(JSON.stringify({ error: 'Unauthorized: Admin privileges required' }), {
      status: 403,
      headers: { 'Content-Type': 'application/json' },
    });
  }
  return send(await request.json());
}
