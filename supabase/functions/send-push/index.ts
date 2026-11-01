// TEST-ONLY AUTHORIZATION CHANGE - NOT DEPLOYED.
// Recovered handler is wrapped with the approved dedicated-secret gate.
// Isolated authorization and synthetic audience checks passed in the test project.
// Production rollout still requires separately authorized webhook/secret changes
// and end-to-end delivery verification; no production rollout occurred.
// See Task 1 in docs/superpowers/plans/2026-10-20-university-timetable.md.
// ============================================================
// EDGE FUNCTION: send-push
// PURPOSE: Deliver an OS-level push when an admin creates a broadcast.
//   Triggered by a Supabase Database Webhook on INSERT into
//   `notifications`. Resolves the broadcast's audience → looks up those
//   users' FCM tokens in `device_tokens` → sends via FCM HTTP v1.
//
// WHY HTTP v1 (not legacy server key): the legacy FCM endpoint is shut
//   down. v1 needs a short-lived OAuth token minted from a Firebase
//   service account — done below with Web Crypto (no external deps).
//
// SECRETS (set once):
//   supabase secrets set FCM_SERVICE_ACCOUNT="$(cat service-account.json)"
//   (the full JSON you download from Firebase Console →
//    Project settings → Service accounts → Generate new private key)
//   SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY are injected automatically.
//
// AUTH CONTRACT (test-project setup is a separate reviewed step):
//   PUSH_WEBHOOK_SECRET must contain a dedicated high-entropy random secret.
//   The caller must provide the identical value in x-webhook-secret.
//   Missing configuration fails closed; bearer JWT alone is insufficient.
//   Do not create a live notification webhook or deploy from these comments.
// ============================================================

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { protectWebhook } from './webhook_auth.js';
import { resolveNotificationTargets } from './audience.js';

interface NotificationRow {
  id: string;
  type: string;
  title: string;
  body: string;
  target_role: string | null;
  target_batch: string | null;
  target_section: string | null;
}

// ─── FCM HTTP v1 auth: service account JWT → access token ─────
let cachedToken: { token: string; exp: number } | null = null;

function b64url(input: ArrayBuffer | string): string {
  const bytes =
    typeof input === 'string'
      ? new TextEncoder().encode(input)
      : new Uint8Array(input);
  let str = '';
  for (const b of bytes) str += String.fromCharCode(b);
  return btoa(str).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function pemToDer(pem: string): ArrayBuffer {
  const body = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s+/g, '');
  const raw = atob(body);
  const buf = new Uint8Array(raw.length);
  for (let i = 0; i < raw.length; i++) buf[i] = raw.charCodeAt(i);
  return buf.buffer;
}

async function getAccessToken(sa: {
  client_email: string;
  private_key: string;
}): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedToken && cachedToken.exp - 60 > now) return cachedToken.token;

  const header = b64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claims = b64url(
    JSON.stringify({
      iss: sa.client_email,
      scope: 'https://www.googleapis.com/auth/firebase.messaging',
      aud: 'https://oauth2.googleapis.com/token',
      iat: now,
      exp: now + 3600,
    }),
  );
  const unsigned = `${header}.${claims}`;

  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToDer(sa.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const sig = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(unsigned),
  );
  const jwt = `${unsigned}.${b64url(sig)}`;

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });
  const data = await res.json();
  if (!data.access_token) {
    throw new Error(`Token exchange failed: ${JSON.stringify(data)}`);
  }
  cachedToken = { token: data.access_token, exp: now + 3600 };
  return data.access_token;
}

// ─── Main ─────────────────────────────────────────────────────
Deno.serve(protectWebhook(async (req: Request) => {
  try {
    const payload = await req.json();
    const n: NotificationRow = payload.record;
    if (!n) return new Response('No record', { status: 400 });

    const url = Deno.env.get('SUPABASE_URL')!;
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const sa = JSON.parse(Deno.env.get('FCM_SERVICE_ACCOUNT')!);
    const admin = createClient(url, serviceKey);

    // 1) Resolve the audience → matching profiles.
    //    A null target = "everyone in that dimension".
    const { tokens, reason } = await resolveNotificationTargets(admin, n);
    if (reason) {
      return new Response(JSON.stringify({ sent: 0, reason }), {
        headers: { 'Content-Type': 'application/json' },
      });
    }

    // 3) Send one FCM v1 message per token.
    const accessToken = await getAccessToken(sa);
    const endpoint = `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`;

    let sent = 0;
    const stale: string[] = [];
    for (const token of tokens) {
      const res = await fetch(endpoint, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          message: {
            token,
            notification: { title: n.title, body: n.body },
            data: { type: n.type, notification_id: n.id },
            android: { priority: 'high' },
          },
        }),
      });
      if (res.ok) {
        sent++;
      } else if (res.status === 404 || res.status === 400) {
        // Token no longer valid — clean it up.
        stale.push(token);
      }
    }

    if (stale.length > 0) {
      await admin.from('device_tokens').delete().in('token', stale);
    }

    return new Response(JSON.stringify({ sent, pruned: stale.length }), {
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }
}, () => Deno.env.get('PUSH_WEBHOOK_SECRET'), (status: number) =>
  new Response(status === 503 ? 'Webhook authorization unavailable' : 'Unauthorized', {
    status,
    headers: { 'Cache-Control': 'no-store' },
  })
));
