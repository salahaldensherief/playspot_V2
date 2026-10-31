import { createClient } from 'npm:@supabase/supabase-js@2.49.8';
import { createLocationHandler, reverseGeocode } from './handler.js';

const url = Deno.env.get('SUPABASE_URL')!;
const key = Deno.env.get('SUPABASE_ANON_KEY')!;
const caller = (authorization: string) => createClient(url, key, {
  auth: { persistSession: false, autoRefreshToken: false },
  global: { headers: { Authorization: authorization } },
});
Deno.serve(createLocationHandler({
  authenticate: async (authorization: string) => {
    const { data, error } = await caller(authorization).auth.getUser();
    return error ? null : data.user;
  },
  geocode: reverseGeocode,
  loadCities: async (authorization: string) => {
    const { data, error } = await caller(authorization).from('cities')
      .select('id,name_ar,name_en').eq('is_active', true);
    if (error) throw error;
    return data ?? [];
  },
  saveLocation: async (authorization: string, userId: string, update: Record<string, unknown>) => {
    // Caller-scoped RLS and a verified Auth identity; no user_id from the body.
    const { data, error } = await caller(authorization).from('profiles')
      .update(update).eq('id', userId).select('id').maybeSingle();
    return !error && data?.id === userId;
  },
  report: (code: string) => console.warn('[LOCATION]', code),
}));
