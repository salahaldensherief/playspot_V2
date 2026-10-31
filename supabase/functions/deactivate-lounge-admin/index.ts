import { createClient } from "npm:@supabase/supabase-js@2.49.8";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

if (!SUPABASE_URL) throw new Error("SUPABASE_URL is required");
if (!SERVICE_ROLE_KEY) throw new Error("SUPABASE_SERVICE_ROLE_KEY is required");

const service = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { persistSession: false, autoRefreshToken: false },
});

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const authorization = req.headers.get("Authorization")?.trim() ?? "";
  if (!/^Bearer\s+\S+$/i.test(authorization)) {
    return json({ error: "Authentication required" }, 401);
  }

  const token = authorization.replace(/^Bearer\s+/i, "");
  const { data: callerData, error: callerError } = await service.auth.getUser(token);
  const caller = callerData.user;
  if (callerError || !caller) return json({ error: "Invalid or expired session" }, 401);

  let body: Record<string, unknown>;
  try {
    body = await req.json() as Record<string, unknown>;
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }

  const targetUserId = String(body.target_user_id ?? "").trim();
  if (!/^[0-9a-fA-F-]{36}$/.test(targetUserId)) {
    return json({ error: "Valid target_user_id is required" }, 400);
  }

  const callerClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: isSuperAdmin, error: authzError } =
    await callerClient.rpc("is_super_admin");
  if (authzError || isSuperAdmin !== true) {
    return json({ error: "Super admin permission required" }, 403);
  }

  const { data: deactivation, error: deactivateError } = await callerClient.rpc(
    "deactivate_lounge_admin",
    { p_target_user_id: targetUserId },
  );

  if (deactivateError || !deactivation || deactivation.success !== true) {
    console.error("deactivate_lounge_admin failed", deactivateError?.message);
    return json({ error: deactivateError?.message ?? "Account deactivation failed" }, 400);
  }

  let banErrorMessage: string | null = null;
  for (let attempt = 0; attempt < 2; attempt++) {
    const { error: banError } = await service.auth.admin.updateUserById(
      targetUserId,
      { ban_duration: "876000h" },
    );
    if (!banError) {
      banErrorMessage = null;
      break;
    }
    banErrorMessage = banError.message;
  }

  if (banErrorMessage) {
    console.error("Auth account ban failed after DB deactivation", {
      targetUserId,
      banErrorMessage,
    });
    return json({
      error: "Account deactivated in PlaySpot but auth disabling requires attention",
      deactivated: true,
    }, 503);
  }

  return json({ ...deactivation, auth_disabled: true });
});
