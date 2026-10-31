import { createClient } from "npm:@supabase/supabase-js@2.49.8";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

if (!SUPABASE_URL) throw new Error("SUPABASE_URL is required");
if (!SUPABASE_SERVICE_ROLE_KEY) {
  throw new Error("SUPABASE_SERVICE_ROLE_KEY is required");
}

const service = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: { persistSession: false, autoRefreshToken: false },
});

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function normalizeRole(value: unknown): "manager" | "cashier" | "staff" | null {
  const role = String(value ?? "").trim().toLowerCase();
  if (["manager", "admin", "lounge_admin"].includes(role)) return "manager";
  if (["cashier", "role_cashier"].includes(role)) return "cashier";
  if (["staff", "role_staff"].includes(role)) return "staff";
  return null;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  const authHeader = req.headers.get("Authorization")?.trim() ?? "";
  if (!authHeader.toLowerCase().startsWith("bearer ")) {
    return json({ error: "Authentication required" }, 401);
  }

  const token = authHeader.replace(/^Bearer\s+/i, "").trim();
  const { data: userData, error: userError } = await service.auth.getUser(token);
  const caller = userData.user;
  if (userError || !caller) {
    return json({ error: "Invalid or expired session" }, 401);
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json() as Record<string, unknown>;
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }
  if (!body || Array.isArray(body) || typeof body !== "object") {
    return json({ error: "JSON object is required" }, 400);
  }

  const email = String(body.email ?? "").trim().toLowerCase();
  const password = String(body.password ?? "");
  const fullName = String(body.full_name ?? "").trim();
  const phone = String(body.phone ?? "").trim();
  const loungeId = String(body.lounge_id ?? "").trim();
  const staffRole = normalizeRole(body.role);

  if (!email || !email.includes("@")) {
    return json({ error: "Valid email is required" }, 400);
  }
  if (password.length < 6) {
    return json({ error: "Password must be at least 6 characters" }, 400);
  }
  if (!fullName || !loungeId) {
    return json({ error: "full_name and lounge_id are required" }, 400);
  }
  if (!staffRole) {
    return json({ error: "Unsupported staff role" }, 400);
  }

  const { data: profile, error: profileError } = await service
    .from("profiles")
    .select("id, role, lounge_id, is_active, is_banned")
    .eq("id", caller.id)
    .maybeSingle();

  if (profileError || !profile || profile.is_active !== true || profile.is_banned !== false) {
    return json({ error: "Active staff profile is required" }, 403);
  }

  const callerClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: canonicalSuperAdmin, error: authorityError } =
    await callerClient.rpc("is_super_admin");
  if (authorityError) {
    return json({ error: "Could not verify administrator authority" }, 403);
  }
  const isSuperAdmin = canonicalSuperAdmin === true;
  const actorRole = String(profile.role ?? "").trim().toLowerCase();
  if (!isSuperAdmin && !["owner", "lounge_owner", "manager", "lounge_admin"].includes(actorRole)) {
    return json({ error: "Only lounge administrators can manage staff" }, 403);
  }

  if (!isSuperAdmin) {
    const { data: allowed, error: permissionError } = await callerClient.rpc(
      "has_lounge_permission",
      {
        p_lounge_id: loungeId,
        p_permission_key: "staff_manage",
      },
    );

    if (permissionError || allowed !== true) {
      return json({ error: "Missing staff_manage permission" }, 403);
    }
  }

  if (!isSuperAdmin && ["manager", "lounge_admin"].includes(actorRole) && staffRole === "manager") {
    return json({ error: "Managers cannot create peer managers" }, 403);
  }

  const recoveryUserId = String(body.recovery_user_id ?? "").trim();
  let newUserId = recoveryUserId;
  if (!newUserId) {
    try {
    const { data: created, error: createError } = await service.auth.admin.createUser({
      email, password, email_confirm: true,
      user_metadata: { full_name: fullName, name: fullName },
      app_metadata: { staff_provisioning: { actor_id: caller.id, lounge_id: loungeId, role: staffRole } },
    });
    if (createError || !created.user) {
      const message = createError?.message ?? "Could not create staff account";
      if (!/already|registered|exists/i.test(message)) {
        return json({ error: message }, 400);
      }
    } else {
      newUserId = created.user.id;
    }
    } catch {
      // Auth may have committed even when its response did not arrive.
    }
    if (!newUserId) {
      try {
        const { data, error } = await service.rpc("recover_lounge_staff_provisioning", {
          p_actor_id: caller.id, p_email: email, p_lounge_id: loungeId, p_role: staffRole,
        });
        if (error) throw error;
        if (typeof data !== "string" || !data) {
          return json({ error: "Account creation was not confirmed; retry the original details", provisioning_confirmed: false }, 503);
        }
        newUserId = data;
      } catch {
        return json({ error: "Account creation was not confirmed; retry the original details", provisioning_confirmed: false }, 503);
      }
    }
  }
  try {
    const { data, error } = await service.rpc("finalize_lounge_staff_provisioning", {
      p_actor_id: caller.id, p_user_id: newUserId, p_lounge_id: loungeId,
      p_role: staffRole, p_full_name: fullName, p_phone: phone,
    });
    if (error || data?.success !== true || data?.user_id !== newUserId || data?.role !== staffRole) {
      throw new Error("Staff finalization was not confirmed");
    }
    return json(data, 201);
  } catch {
    console.error("STAFF_PROVISIONING_REQUIRES_RECOVERY", newUserId);
    return json({ error: "Staff provisioning requires recovery", recovery_user_id: newUserId,
      provisioning_confirmed: false }, 503);
  }
});
