export const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};
const json = (body, status) => new Response(JSON.stringify(body), {
  status, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
});

export function createOwnerHandler(dependencies) {
  return async (request) => {
    let createdOwnerId;
    try {
    if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
    if (request.method !== 'POST') return json({ error: 'owner_method_not_allowed' }, 405);
    const authorization = request.headers.get('Authorization') ?? '';
    if (!/^Bearer\s+\S+$/i.test(authorization)) return json({ error: 'owner_session_expired' }, 401);
    const actor = await dependencies.authenticate(authorization);
    if (!actor) return json({ error: 'owner_session_expired' }, 401);
    if (!await dependencies.authorize(authorization)) return json({ error: 'owner_permission_denied' }, 403);
    let body;
    try { body = await request.json(); } catch { return json({ error: 'owner_invalid_details' }, 400); }
    if (!body || typeof body !== 'object') return json({ error: 'owner_invalid_details' }, 400);
    const email = typeof body.email === 'string' ? body.email.trim().toLowerCase() : '';
    const password = typeof body.password === 'string' ? body.password : '';
    const ownerName = typeof body.owner_name === 'string' ? body.owner_name.trim() : '';
    const loungeName = typeof body.lounge_name === 'string' ? body.lounge_name.trim() : '';
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || password.length < 8 ||
        !ownerName || !loungeName || ownerName.length > 160 || loungeName.length > 160) {
      return json({ error: 'owner_invalid_details' }, 400);
    }
    const optionalText = (key) => typeof body[key] === 'string' ? body[key].trim().slice(0, 500) : null;
    const created = await dependencies.createAccount({ email, password, name: ownerName });
    if (!created.id) return json({ error: created.duplicate ? 'owner_email_exists' : 'owner_account_create_failed' }, created.duplicate ? 409 : 400);
    createdOwnerId = created.id;
    const parameters = {
      p_actor_id: actor.id, p_owner_id: created.id, p_owner_name: ownerName,
      p_lounge_name: loungeName, p_city: optionalText('city'),
      p_address: optionalText('address'), p_phone: optionalText('phone'),
      p_owner_phone: optionalText('owner_phone'),
    };
    // Idempotent server finalization handles a lost response without a second lounge.
    for (let attempt = 0; attempt < 2; attempt++) {
      let result;
      try { result = await dependencies.finalize(parameters); } catch { result = null; }
      if (result?.success === true) return json(result, 201);
    }
    // An uncertain response must never delete an account whose transaction may
    // have committed. Keep the identifier for server-side recovery, without secrets.
    dependencies.reportUnconfirmed?.(created.id);
    return json({ error: 'owner_provisioning_unconfirmed' }, 503);
    } catch {
      if (createdOwnerId) dependencies.reportUnconfirmed?.(createdOwnerId);
      return json({ error: createdOwnerId ? 'owner_provisioning_unconfirmed' : 'owner_account_create_failed' }, 503);
    }
  };
}
