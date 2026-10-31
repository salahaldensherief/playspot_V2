import { createClient } from 'npm:@supabase/supabase-js@2.49.8';
import { createOwnerHandler } from './handler.js';

const url = Deno.env.get('SUPABASE_URL')!;
const key = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const options = { auth: { persistSession: false, autoRefreshToken: false } };
const service = createClient(url, key, options);

Deno.serve(createOwnerHandler({
  authenticate: async (authorization: string) => {
    const { data, error } = await service.auth.getUser(authorization.replace(/^Bearer\s+/i, ''));
    return error ? null : data.user;
  },
  authorize: async (authorization: string) => {
    const caller = createClient(url, key, { ...options, global: { headers: { Authorization: authorization } } });
    const { data, error } = await caller.rpc('is_super_admin');
    return !error && data === true;
  },
  createAccount: async ({ email, password, name }: { email: string; password: string; name: string }) => {
    const { data, error } = await service.auth.admin.createUser({
      email, password, email_confirm: true, user_metadata: { full_name: name },
    });
    return { id: data.user?.id, duplicate: /already|registered|exists/i.test(error?.message ?? '') };
  },
  finalize: async (parameters: Record<string, unknown>) => {
    const { data, error } = await service.rpc('finalize_owner_lounge_provisioning_v2', parameters);
    return error ? null : data;
  },
  reportUnconfirmed: (ownerId: string) => console.error('Owner provisioning requires recovery', ownerId),
}));
