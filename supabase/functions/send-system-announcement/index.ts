import { createClient } from "npm:@supabase/supabase-js@2.49.8";
import { GoogleAuth } from "npm:google-auth-library@9.15.1";
import { isAnnouncementCallerAuthorized, dispatchAuthorizedAnnouncement } from './authorization.js';

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

async function isCallerAdmin(req: Request): Promise<boolean> {
  return isAnnouncementCallerAuthorized(req, {
    authenticate: async (authorization: string) => {
      const { data, error } = await supabase.auth.getUser(authorization.replace(/^Bearer\s+/i, ''));
      return error ? null : data.user;
    },
    authorize: async (authorization: string) => {
      const caller = createClient(SUPABASE_URL!, SUPABASE_SERVICE_ROLE_KEY!, {
        auth: { persistSession: false, autoRefreshToken: false },
        global: { headers: { Authorization: authorization } },
      });
      const { data, error } = await caller.rpc('is_super_admin');
      return !error && data === true;
    },
    expectedKey: async () => {
      const { data, error } = await supabase.rpc('internal_get_edge_function_key');
      return error ? null : data;
    },
  });
}

Deno.serve(async (req: Request) => {
  try {
    return await dispatchAuthorizedAnnouncement(req, isCallerAdmin, async (payload: any) => {
    const topic = payload?.topic ?? "all_users";
    const title = payload?.title ?? "تنبيه جديد من إدراة PlaySpot";
    const body = payload?.body ?? "";
    const announcementId = payload?.announcement_id ?? "";
    const extraData = payload?.data ?? {};

    const auth = new GoogleAuth({
      credentials: {
        client_email: FIREBASE_CLIENT_EMAIL,
        private_key: privateKey,
      },
      scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
    });

    const client = await auth.getClient();
    const accessTokenResponse = await client.getAccessToken();
    const accessToken = accessTokenResponse.token;

    if (!accessToken) throw new Error("Failed to obtain Firebase access token");

    const fcmMessage = {
      message: {
        topic: topic,
        notification: { title, body },
        data: {
          announcement_id: String(announcementId),
          type: String(extraData.type ?? "system_announcement"),
        },
      },
    };

    const fcmResponse = await fetch(
      `https://fcm.googleapis.com/v1/projects/${encodeURIComponent(FIREBASE_PROJECT_ID)}/messages:send`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${accessToken}`,
        },
        body: JSON.stringify(fcmMessage),
      },
    );

    const fcmResult = await fcmResponse.json().catch(() => ({}));

    if (!fcmResponse.ok) {
      console.error("FCM broadcast failed:", fcmResponse.status, JSON.stringify(fcmResult));
      return new Response(JSON.stringify({ error: "FCM broadcast failed", details: fcmResult }), {
        status: 502,
        headers: { "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify({ success: true, messageId: fcmResult.name }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown error";
    console.error("System announcement error:", message);
    return new Response(JSON.stringify({ error: message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
