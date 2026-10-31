import { createClient } from "npm:@supabase/supabase-js@2.49.8";
import { GoogleAuth } from "npm:google-auth-library@9.15.1";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const FIREBASE_PROJECT_ID = Deno.env.get("FIREBASE_PROJECT_ID");
const FIREBASE_CLIENT_EMAIL = Deno.env.get("FIREBASE_CLIENT_EMAIL");
const FIREBASE_PRIVATE_KEY = Deno.env.get("FIREBASE_PRIVATE_KEY");

if (!SUPABASE_URL) throw new Error("SUPABASE_URL is required");
if (!SUPABASE_SERVICE_ROLE_KEY) throw new Error("SUPABASE_SERVICE_ROLE_KEY is required");
if (!FIREBASE_PROJECT_ID) throw new Error("FIREBASE_PROJECT_ID is required");
if (!FIREBASE_CLIENT_EMAIL) throw new Error("FIREBASE_CLIENT_EMAIL is required");
if (!FIREBASE_PRIVATE_KEY) throw new Error("FIREBASE_PRIVATE_KEY is required");

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
const privateKey = FIREBASE_PRIVATE_KEY.replace(/\\n/g, "\n");

// ---------------------------------------------------------------------------
// Reuse the credential client so google-auth-library retains its token and
// refreshes it near expiry, grouping concurrent refresh requests.
const firebaseAuth = new GoogleAuth({
  credentials: {
    client_email: FIREBASE_CLIENT_EMAIL,
    private_key: privateKey,
  },
  scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
});

// Caller authentication.
// This function runs with verify_jwt = false because it is called by the database
// (handle_notification_webhook -> net.http_post) which sends a shared secret in the
// `apikey` header (Vault secret `edge_function_key`). Without this check anyone who
// knew the URL could push arbitrary notifications to any user.
// ---------------------------------------------------------------------------
let cachedKey: string | null = null;
let lastKeyLoadAt = 0;

async function loadExpectedKey(force = false): Promise<string | null> {
  if (cachedKey && !force) return cachedKey;
  // Do not hit the database more than once a minute, even for forced refreshes.
  if (force && Date.now() - lastKeyLoadAt < 60_000) return cachedKey;
  lastKeyLoadAt = Date.now();
  const { data, error } = await supabase.rpc("internal_get_edge_function_key");
  if (error || typeof data !== "string" || data.length === 0) {
    console.error("Could not load edge function key:", error?.message);
    return cachedKey;
  }
  cachedKey = data;
  return cachedKey;
}

function safeEqual(a: string, b: string): boolean {
  const enc = new TextEncoder();
  const x = enc.encode(a);
  const y = enc.encode(b);
  if (x.length !== y.length) return false;
  let diff = 0;
  for (let i = 0; i < x.length; i++) diff |= x[i] ^ y[i];
  return diff === 0;
}

async function isAuthorized(req: Request): Promise<boolean> {
  const provided = req.headers.get("apikey") ?? "";
  if (!provided) return false;
  const expected = await loadExpectedKey();
  if (expected && safeEqual(provided, expected)) return true;
  // The secret may have been rotated: refresh (rate limited) and compare again.
  const refreshed = await loadExpectedKey(true);
  return !!refreshed && safeEqual(provided, refreshed);
}

function isEnglish(record: Record<string, unknown>): boolean {
  const language = String(record.language ?? record.locale ?? record.lang ?? "").toLowerCase();
  return language === "en" || language.startsWith("en-");
}

function localizedValue(
  record: Record<string, unknown>,
  arabicKey: string,
  englishKey: string,
  genericKey: string,
  fallback: string,
): string {
  const preferred = isEnglish(record)
    ? [record[englishKey], record[arabicKey], record[genericKey]]
    : [record[arabicKey], record[englishKey], record[genericKey]];

  const value = preferred.find(
    (item) => typeof item === "string" && item.trim().length > 0,
  );
  return typeof value === "string" ? value.trim() : fallback;
}

type NotificationSettings = {
  push_enabled?: boolean | null;
  booking_updates?: boolean | null;
  offers_enabled?: boolean | null;
  events_enabled?: boolean | null;
  system_notifications?: boolean | null;
};

function shouldDeliverPush(
  notificationType: string,
  settings: NotificationSettings | null,
): boolean {
  if (!settings) return true;
  if (settings.push_enabled === false) return false;

  const type = notificationType.toLowerCase().trim();
  if (type.includes("booking") || type.includes("canteen") || type.includes("service")) {
    return settings.booking_updates !== false;
  }
  if (type.includes("offer") || type.includes("promo")) {
    return settings.offers_enabled !== false;
  }
  if (type.includes("tournament") || type.includes("event")) {
    return settings.events_enabled !== false;
  }
  return settings.system_notifications !== false;
}

function stringifyDataValue(value: unknown): string {
  if (value === null || value === undefined) return "";
  if (typeof value === "string") return value;
  if (typeof value === "number" || typeof value === "boolean") return String(value);
  return JSON.stringify(value);
}

Deno.serve(async (req: Request) => {
  try {
    if (!(await isAuthorized(req))) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { "Content-Type": "application/json" },
      });
    }

    const payload = await req.json();
    const record = payload?.record as Record<string, unknown> | undefined;

    if (!record) {
      return new Response(JSON.stringify({ error: "No record found" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    const userId = typeof record.user_id === "string" ? record.user_id : null;
    if (!userId) {
      return new Response(JSON.stringify({ success: true, message: "No user_id" }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    const { data: profile, error: profileError } = await supabase
      .from("profiles")
      .select("fcm_token, notification_preferences")
      .eq("id", userId)
      .maybeSingle();

    if (profileError) {
      console.error("Failed to load user FCM token:", profileError.message);
      return new Response(JSON.stringify({ error: "Failed to load recipient" }), {
        status: 500,
        headers: { "Content-Type": "application/json" },
      });
    }

    const { data: settings, error: settingsError } = await supabase
      .from("notification_settings")
      .select(
        "push_enabled, booking_updates, offers_enabled, events_enabled, system_notifications",
      )
      .eq("user_id", userId)
      .maybeSingle();

    if (settingsError) {
      console.error(
        "Failed to load notification settings:",
        settingsError.message,
      );
    }

    const notificationType = String(record.type ?? "general");
    if (!shouldDeliverPush(notificationType, settings ?? null)) {
      return new Response(
        JSON.stringify({
          success: true,
          message: "Push disabled by user preference",
        }),
        {
          status: 200,
          headers: { "Content-Type": "application/json" },
        },
      );
    }

    if (!profile?.fcm_token) {
      return new Response(JSON.stringify({ success: true, message: "User has no FCM token" }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    const title = localizedValue(
      record,
      "title_ar",
      "title_en",
      "title",
      "إشعار جديد",
    );
    const body = localizedValue(
      record,
      "body_ar",
      "body_en",
      "body",
      "لديك إشعار جديد من PlaySpot",
    );

    const metadata = record.metadata && typeof record.metadata === "object"
      ? record.metadata as Record<string, unknown>
      : {};
    const legacyPushEnabled =
      profile?.notification_preferences &&
      typeof profile.notification_preferences === "object"
        ? (profile.notification_preferences as Record<string, unknown>)[
            "push_notifications_enabled"
          ]
        : null;
    if (legacyPushEnabled === false) {
      return new Response(
        JSON.stringify({
          success: true,
          message: "Push disabled by profile preference",
        }),
        {
          status: 200,
          headers: { "Content-Type": "application/json" },
        },
      );
    }

    const data: Record<string, string> = {
      type: stringifyDataValue(notificationType),
      notification_id: stringifyDataValue(record.id),
      title_ar: stringifyDataValue(record.title_ar ?? record.title),
      title_en: stringifyDataValue(record.title_en ?? record.title),
      body_ar: stringifyDataValue(record.body_ar ?? record.body),
      body_en: stringifyDataValue(record.body_en ?? record.body),
    };

    for (const [key, value] of Object.entries(metadata)) {
      if (/^[a-zA-Z0-9_.-]+$/.test(key)) data[key] = stringifyDataValue(value);
    }

    const client = await firebaseAuth.getClient();
    const accessTokenResponse = await client.getAccessToken();
    const accessToken = accessTokenResponse.token;

    if (!accessToken) throw new Error("Failed to obtain Firebase access token");

    const fcmResponse = await fetch(
      `https://fcm.googleapis.com/v1/projects/${encodeURIComponent(FIREBASE_PROJECT_ID)}/messages:send`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${accessToken}`,
        },
        body: JSON.stringify({
          message: {
            token: profile.fcm_token,
            notification: { title, body },
            data,
          },
        }),
      },
    );

    const fcmResult = await fcmResponse.json().catch(() => ({}));

    if (!fcmResponse.ok) {
      console.error("FCM request failed:", fcmResponse.status, JSON.stringify(fcmResult));

      // Clean up stale or unregistered FCM tokens to prevent repeated failed delivery attempts
      const errStr = JSON.stringify(fcmResult).toUpperCase();
      if (fcmResponse.status === 404 || errStr.includes("UNREGISTERED") || errStr.includes("NOT_FOUND")) {
        console.log(`Clearing unregistered FCM token for user ${userId}`);
        await supabase
          .from("profiles")
          .update({ fcm_token: null })
          .eq("id", userId);
      }

      return new Response(JSON.stringify({ error: "FCM request failed", details: fcmResult }), {
        status: 502,
        headers: { "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify({ success: true }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown error";
    console.error("FCM function error:", message);
    return new Response(JSON.stringify({ error: "Notification delivery failed" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
