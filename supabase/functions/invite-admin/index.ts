// // ============================================================
// // EDGE FUNCTION: invite-admin
// // PURPOSE: Securely provision a new ADMIN. Account creation needs the
// // service-role key, which must NEVER live in the Flutter app — so it
// // happens here, server-side.
// //
// // FLOW:
// //   1. Verify the CALLER is an admin (from their JWT).
// //   2. Upsert a `whitelists` row (role='admin') so the gate in
// //      auth_service.handlePostLogin() assigns admin on first sign-in.
// //   3. inviteUserByEmail() → creates the auth user (no password) and
// //      emails an invite link that lands on the set-password screen
// //      (reset-callback deep link → ResetPasswordScreen).
// //
// // DEPLOY (either one):
// //   • Dashboard → Edge Functions → create "invite-admin" → paste this.
// //   • CLI: supabase functions deploy invite-admin
// // SUPABASE_URL / SUPABASE_ANON_KEY / SUPABASE_SERVICE_ROLE_KEY are
// // injected automatically — no secrets to set.
// // NOTE: invites send via your project's email (Auth → SMTP). The
// // built-in sender works for testing (low rate limit).
// // ============================================================

// import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

// const corsHeaders = {
//   'Access-Control-Allow-Origin': '*',
//   'Access-Control-Allow-Headers':
//     'authorization, x-client-info, apikey, content-type',
//   'Access-Control-Allow-Methods': 'POST, OPTIONS',
// };

// function json(body: unknown, status = 200) {
//   return new Response(JSON.stringify(body), {
//     status,
//     headers: { ...corsHeaders, 'Content-Type': 'application/json' },
//   });
// }

// Deno.serve(async (req) => {
//   if (req.method === 'OPTIONS') {
//     return new Response('ok', { headers: corsHeaders });
//   }

//   try {
//     const authHeader = req.headers.get('Authorization');
//     if (!authHeader) return json({ error: 'Missing authorization header.' }, 401);

//     const url = Deno.env.get('SUPABASE_URL')!;
//     const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
//     const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

//     // 1) Who is calling? (their JWT)
//     const callerClient = createClient(url, anonKey, {
//       global: { headers: { Authorization: authHeader } },
//     });
//     const {
//       data: { user: caller },
//       error: callerErr,
//     } = await callerClient.auth.getUser();
//     if (callerErr || !caller) return json({ error: 'Invalid session.' }, 401);

//     // 2) Caller must be an admin (service client bypasses RLS).
//     const admin = createClient(url, serviceKey);
//     const { data: callerProfile } = await admin
//       .from('profiles')
//       .select('role')
//       .eq('id', caller.id)
//       .maybeSingle();
//     if (!callerProfile || callerProfile.role !== 'admin') {
//       return json({ error: 'Only admins can invite admins.' }, 403);
//     }

//     // 3) Validate input.
//     const body = await req.json().catch(() => ({}));
//     const rawEmail = (body.email ?? '').toString().trim().toLowerCase();
//     const name = body.name ? body.name.toString().trim() : null;
//     if (!rawEmail || !rawEmail.includes('@')) {
//       return json({ error: 'A valid email is required.' }, 400);
//     }

//     // 4) Pre-authorize as admin (the gate reads this on first sign-in).
//     const { error: wlErr } = await admin
//       .from('whitelists')
//       .upsert({ email: rawEmail, role: 'admin', name }, { onConflict: 'email' });
//     if (wlErr) return json({ error: `Whitelist failed: ${wlErr.message}` }, 400);

//     // 5) Send the invite. The link lands on the set-password screen.
//     const { error: inviteErr } = await admin.auth.admin.inviteUserByEmail(
//       rawEmail,
//       {
//         data: { full_name: name ?? '' },
//         redirectTo: 'com.example.universe_v1://reset-callback/',
//       },
//     );
//     if (inviteErr) {
//       return json({ error: inviteErr.message }, 400);
//     }

//     return json({ success: true });
//   } catch (e) {
//     return json({ error: String(e) }, 500);
//   }
// });
