import {createClient} from 'npm:@supabase/supabase-js@2.49.8';
import {reconcileAuthDisabling} from './worker.ts';
const url = Deno.env.get('SUPABASE_URL');
const key = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
if (!url || !key) throw new Error('Recovery service configuration required');
const service = createClient(url,key,{auth:{persistSession:false,autoRefreshToken:false}});
Deno.serve(async (request: Request) => {
  if (request.method !== 'POST') return new Response('Method not allowed',{status:405});
  // Scheduler only. No customer/admin JWT or request-selected target is accepted.
  if (request.headers.get('authorization') !== `Bearer ${key}`) {
    return new Response('Unauthorized',{status:401});
  }
  try {
    const result = await reconcileAuthDisabling(service);
    if (result.deferred || (result.recovery as {failed?: number}).failed) {
      console.error('AUTH_RECOVERY_REQUIRES_ATTENTION', result);
    }
    return Response.json(result);
  } catch {
    console.error('AUTH_RECOVERY_BATCH_FAILED');
    return Response.json({error:'AUTH_RECOVERY_BATCH_FAILED'},{status:503});
  }
});
