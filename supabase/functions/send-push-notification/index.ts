// Supabase Edge Function: send-push-notification
//
// Sends an FCM push whenever a row is inserted into public.notifications.
// Wire it up with a Supabase Database Webhook (INSERT on `notifications`)
// so it fires for every in-app notification created by the DB triggers.
//
//   Required secret : FIREBASE_SERVICE_ACCOUNT  (full service-account JSON)
//   Required secret : WEBHOOK_SECRET            (shared-secret for webhook auth)
//   Auto-provided   : SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
//
//   Deploy: supabase functions deploy send-push-notification
//
// Full setup guide: docs/push-notifications.md

import { createClient } from "npm:@supabase/supabase-js@2";

interface ServiceAccount {
  client_email: string;
  private_key: string;
  project_id: string;
}

// notification.type -> push title. The row's `message` is used as the body.
const TITLES: Record<string, string> = {
  task_assigned: "New task assigned",
  event_posted: "New event",
  announcement: "New announcement",
  poll_created: "New poll",
  membership_approved: "Membership approved",
  join_request: "New join request",
};

function base64url(input: ArrayBuffer | string): string {
  let binary: string;
  if (typeof input === "string") {
    binary = input;
  } else {
    const bytes = new Uint8Array(input);
    binary = "";
    for (const b of bytes) binary += String.fromCharCode(b);
  }
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function pemToPkcs8(pem: string): ArrayBuffer {
  const b64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s+/g, "");
  const binary = atob(b64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes.buffer;
}

// Mint a short-lived OAuth2 access token for the FCM HTTP v1 API,
// signing the JWT with the service-account private key (RS256).
async function getAccessToken(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = base64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = base64url(
    JSON.stringify({
      iss: sa.client_email,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: "https://oauth2.googleapis.com/token",
      iat: now,
      exp: now + 3600,
    }),
  );
  const unsigned = `${header}.${claims}`;

  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToPkcs8(sa.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(unsigned),
  );
  const jwt = `${unsigned}.${base64url(signature)}`;

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  if (!res.ok) {
    throw new Error(
      `OAuth token exchange failed: ${res.status} ${await res.text()}`,
    );
  }
  const json = await res.json();
  return json.access_token as string;
}

Deno.serve(async (req) => {
  try {
    // WEBHOOK_SECRET is mandatory — fail closed if not configured.
    const expected = Deno.env.get("WEBHOOK_SECRET");
    if (!expected) {
      return new Response("WEBHOOK_SECRET not configured", { status: 500 });
    }
    if (req.headers.get("x-webhook-secret") !== expected) {
      return new Response("Unauthorized", { status: 401 });
    }

    // Database Webhook sends { type, table, record, old_record }.
    // Fall back to the raw body so the function is also directly testable.
    const body = await req.json();
    const record = body.record ?? body;
    const userId: string | undefined = record?.user_id;
    const type: string = record?.type ?? "notification";
    const message: string = record?.message ?? "";

    if (!userId) {
      return Response.json({ error: "missing user_id" }, { status: 400 });
    }

    const sa: ServiceAccount = JSON.parse(
      Deno.env.get("FIREBASE_SERVICE_ACCOUNT") ?? "{}",
    );
    if (!sa.project_id) {
      return Response.json(
        { error: "FIREBASE_SERVICE_ACCOUNT not configured" },
        { status: 500 },
      );
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // All of the recipient's device tokens (service role bypasses RLS).
    const { data: tokens, error } = await supabase
      .from("fcm_tokens")
      .select("token")
      .eq("user_id", userId);
    if (error) throw error;
    if (!tokens || tokens.length === 0) {
      return Response.json({ sent: 0, reason: "no tokens" });
    }

    const accessToken = await getAccessToken(sa);
    const title = TITLES[type] ?? "ClubOS";
    const endpoint =
      `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`;

    let sent = 0;
    const deadTokens: string[] = [];

    for (const row of tokens) {
      const token = row.token as string;
      const res = await fetch(endpoint, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          message: {
            token,
            notification: { title, body: message },
            data: { type, click_action: "FLUTTER_NOTIFICATION_CLICK" },
            android: { priority: "high" },
            apns: { payload: { aps: { sound: "default" } } },
          },
        }),
      });

      if (res.ok) {
        sent++;
      } else {
        const errText = await res.text();
        console.error(`FCM send failed (${res.status}): ${errText}`);
        // Prune only tokens FCM reports as gone, so a payload bug can never
        // wipe valid tokens.
        if (res.status === 404 || errText.includes("UNREGISTERED")) {
          deadTokens.push(token);
        }
      }
    }

    if (deadTokens.length > 0) {
      await supabase.from("fcm_tokens").delete().in("token", deadTokens);
    }

    return Response.json({ sent, cleaned: deadTokens.length });
  } catch (e) {
    console.error(e);
    return Response.json({ error: String(e) }, { status: 500 });
  }
});
