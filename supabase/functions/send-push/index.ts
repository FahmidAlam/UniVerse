// // ============================================================
// // EDGE FUNCTION: send-push
// // PURPOSE: Deliver an OS-level push when an admin creates a broadcast.
// //   Triggered by a Supabase Database Webhook on INSERT into
// //   `notifications`. Resolves the broadcast's audience → looks up those
// //   users' FCM tokens in `device_tokens` → sends via FCM HTTP v1.
// //
// // WHY HTTP v1 (not legacy server key): the legacy FCM endpoint is shut
// //   down. v1 needs a short-lived OAuth token minted from a Firebase
// //   service account — done below with Web Crypto (no external deps).
// //
// // SECRETS (set once):
// //   supabase secrets set FCM_SERVICE_ACCOUNT="$(cat service-account.json)"
// //   (the full JSON you download from Firebase Console →
// //    Project settings → Service accounts → Generate new private key)
// //   SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY are injected automatically.
// //
// // DEPLOY:
// //   supabase functions deploy send-push
// // Then: Dashboard → Database → Webhooks → create webhook on table
// //   `notifications`, event INSERT, type "Supabase Edge Functions",
// //   select send-push. (Use the service-role key / no JWT verification
// //   so the webhook can call it.)
// // ============================================================

// import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

// interface NotificationRow {
//   id: string;
//   type: string;
//   title: string;
//   body: string;
//   target_role: string | null;
//   target_batch: string | null;
//   target_section: string | null;
// }

// // ─── FCM HTTP v1 auth: service account JWT → access token ─────
// let cachedToken: { token: string; exp: number } | null = null;

// function b64url(input: ArrayBuffer | string): string {
//   const bytes =
//     typeof input === 'string'
//       ? new TextEncoder().encode(input)
//       : new Uint8Array(input);
//   let str = '';
//   for (const b of bytes) str += String.fromCharCode(b);
//   return btoa(str).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
// }

// function pemToDer(pem: string): ArrayBuffer {
//   const body = pem
//     .replace(/-----BEGIN PRIVATE KEY-----/, '')
//     .replace(/-----END PRIVATE KEY-----/, '')
//     .replace(/\s+/g, '');
//   const raw = atob(body);
//   const buf = new Uint8Array(raw.length);
//   for (let i = 0; i < raw.length; i++) buf[i] = raw.charCodeAt(i);
//   return buf.buffer;
// }

// async function getAccessToken(sa: {
//   client_email: string;
//   private_key: string;
// }): Promise<string> {
//   const now = Math.floor(Date.now() / 1000);
//   if (cachedToken && cachedToken.exp - 60 > now) return cachedToken.token;

//   const header = b64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
//   const claims = b64url(
//     JSON.stringify({
//       iss: sa.client_email,
//       scope: 'https://www.googleapis.com/auth/firebase.messaging',
//       aud: 'https://oauth2.googleapis.com/token',
//       iat: now,
//       exp: now + 3600,
//     }),
//   );
//   const unsigned = `${header}.${claims}`;

//   const key = await crypto.subtle.importKey(
//     'pkcs8',
//     pemToDer(sa.private_key),
//     { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
//     false,
//     ['sign'],
//   );
//   const sig = await crypto.subtle.sign(
//     'RSASSA-PKCS1-v1_5',
//     key,
//     new TextEncoder().encode(unsigned),
//   );
//   const jwt = `${unsigned}.${b64url(sig)}`;

//   const res = await fetch('https://oauth2.googleapis.com/token', {
//     method: 'POST',
//     headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
//     body: new URLSearchParams({
//       grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
//       assertion: jwt,
//     }),
//   });
//   const data = await res.json();
//   if (!data.access_token) {
//     throw new Error(`Token exchange failed: ${JSON.stringify(data)}`);
//   }
//   cachedToken = { token: data.access_token, exp: now + 3600 };
//   return data.access_token;
// }

// // ─── Main ─────────────────────────────────────────────────────
// Deno.serve(async (req) => {
//   try {
//     const payload = await req.json();
//     const n: NotificationRow = payload.record;
//     if (!n) return new Response('No record', { status: 400 });

//     const url = Deno.env.get('SUPABASE_URL')!;
//     const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
//     const sa = JSON.parse(Deno.env.get('FCM_SERVICE_ACCOUNT')!);
//     const admin = createClient(url, serviceKey);

//     // 1) Resolve the audience → matching profiles.
//     //    A null target = "everyone in that dimension".
//     let q = admin.from('profiles').select('id');
//     if (n.target_role) q = q.eq('role', n.target_role);
//     if (n.target_batch) q = q.eq('batch', n.target_batch);
//     if (n.target_section) q = q.eq('section', n.target_section);
//     const { data: profiles, error: pErr } = await q;
//     if (pErr) throw pErr;

//     const userIds = (profiles ?? []).map((p: { id: string }) => p.id);
//     if (userIds.length === 0) {
//       return new Response(JSON.stringify({ sent: 0, reason: 'no audience' }), {
//         headers: { 'Content-Type': 'application/json' },
//       });
//     }

//     // 2) Their device tokens.
//     const { data: tokenRows, error: tErr } = await admin
//       .from('device_tokens')
//       .select('token')
//       .in('user_id', userIds);
//     if (tErr) throw tErr;

//     const tokens = (tokenRows ?? []).map((t: { token: string }) => t.token);
//     if (tokens.length === 0) {
//       return new Response(JSON.stringify({ sent: 0, reason: 'no tokens' }), {
//         headers: { 'Content-Type': 'application/json' },
//       });
//     }

//     // 3) Send one FCM v1 message per token.
//     const accessToken = await getAccessToken(sa);
//     const endpoint = `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`;

//     let sent = 0;
//     const stale: string[] = [];
//     for (const token of tokens) {
//       const res = await fetch(endpoint, {
//         method: 'POST',
//         headers: {
//           Authorization: `Bearer ${accessToken}`,
//           'Content-Type': 'application/json',
//         },
//         body: JSON.stringify({
//           message: {
//             token,
//             notification: { title: n.title, body: n.body },
//             data: { type: n.type, notification_id: n.id },
//             android: { priority: 'high' },
//           },
//         }),
//       });
//       if (res.ok) {
//         sent++;
//       } else if (res.status === 404 || res.status === 400) {
//         // Token no longer valid — clean it up.
//         stale.push(token);
//       }
//     }

//     if (stale.length > 0) {
//       await admin.from('device_tokens').delete().in('token', stale);
//     }

//     return new Response(JSON.stringify({ sent, pruned: stale.length }), {
//       headers: { 'Content-Type': 'application/json' },
//     });
//   } catch (e) {
//     return new Response(JSON.stringify({ error: String(e) }), {
//       status: 500,
//       headers: { 'Content-Type': 'application/json' },
//     });
//   }
// });
