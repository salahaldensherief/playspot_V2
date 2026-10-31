import { createClient } from "npm:@supabase/supabase-js@2.49.1";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SECRET_KEYS_RAW = Deno.env.get("SUPABASE_SECRET_KEYS");

if (!SUPABASE_URL) throw new Error("SUPABASE_URL is required");
if (!SECRET_KEYS_RAW) throw new Error("SUPABASE_SECRET_KEYS is required");

const SECRET_KEYS = JSON.parse(SECRET_KEYS_RAW) as Record<string, string>;
const SECRET_KEY = SECRET_KEYS.default;
if (!SECRET_KEY) throw new Error('Secret key "default" is required in SUPABASE_SECRET_KEYS');

const admin = createClient(SUPABASE_URL, SECRET_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
});

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: corsHeaders,
  });
}

function getBearerToken(req: Request): string | null {
  const header = req.headers.get("authorization");
  if (!header) return null;
  const match = header.match(/^Bearer\s+(.+)$/i);
  return match?.[1] ?? null;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const token = getBearerToken(req);
  if (!token) return json({ error: "Missing bearer token" }, 401);

  // The platform verifies JWTs by default; this additionally resolves the caller's user ID.
  const { data: userData, error: userError } = await admin.auth.getUser(token);
  if (userError || !userData.user) return json({ error: "Unauthorized" }, 401);

  const userId = userData.user.id;

  // One transaction owns deletion, application deactivation and the durable Auth retry record.
  // The request body cannot choose another account.
  const { data: deletion, error: profileError } = await admin.rpc(
    "anonymize_account_for_deletion", { p_user_id: userId },
  );
  if (profileError || deletion?.success !== true || deletion?.deactivated !== true) {
    console.error("Failed anonymizing profile", { userId, error: profileError?.message });
    return json({ error: "Account anonymization failed" }, 500);
  }

  // Disable future authentication without deleting the auth record.
  let banErrorMessage: string | null = null;
  for (let attempt = 0; attempt < 2; attempt++) {
    const { error } = await admin.auth.admin.updateUserById(userId, {
      ban_duration: "876000h",
    });
    banErrorMessage = error?.message ?? null;
    if (!error) break;
  }
  if (banErrorMessage) {
    console.error("Failed disabling auth account", { userId, error: banErrorMessage });
    return json({ error: "Account deactivated; authentication disabling requires retry", deactivated: true }, 503);
  }
  const { data: completed, error: completionError } = await admin
    .from("account_deletion_requests")
    .update({ auth_disabled_at: new Date().toISOString() })
    .eq("user_id", userId).select("user_id").maybeSingle();
  if (completionError || !completed) {
    console.error("Failed recording auth disable completion", { userId, error: completionError?.message });
    return json({ error: "Account disabled; completion record requires reconciliation", deactivated: true, auth_disabled: true }, 503);
  }

  return json({
    success: true,
    message: "Account anonymized and authentication disabled",
  });
});
