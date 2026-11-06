// Runtime dependencies are injected so the production handler can be tested
// without network, service credentials, account writes or email delivery.
import { resolveInvitationCallback } from './callback_policy.js';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function json(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

export function createInvitationHandler({ createClient, getEnv }) {
  return async (req) => {
    if (req.method === 'OPTIONS') {
      return new Response('ok', { headers: corsHeaders });
    }

    try {
      const authHeader = req.headers.get('Authorization');
      if (!authHeader) return json({ error: 'Missing authorization header.' }, 401);

      const url = getEnv('SUPABASE_URL');
      const anonKey = getEnv('SUPABASE_ANON_KEY');
      const serviceKey = getEnv('SUPABASE_SERVICE_ROLE_KEY');

      // 1) Who is calling? (their JWT)
      const callerClient = createClient(url, anonKey, {
        global: { headers: { Authorization: authHeader } },
      });
      const {
        data: { user: caller },
        error: callerErr,
      } = await callerClient.auth.getUser();
      if (callerErr || !caller) return json({ error: 'Invalid session.' }, 401);

      // 2) Caller must be an admin (service client bypasses RLS).
      const admin = createClient(url, serviceKey);
      const { data: callerProfile } = await admin
        .from('profiles')
        .select('role')
        .eq('id', caller.id)
        .maybeSingle();
      if (!callerProfile || callerProfile.role !== 'admin') {
        return json({ error: 'Only admins can invite admins.' }, 403);
      }

      // 3) Validate input.
      const body = await req.json().catch(() => ({}));
      const rawEmail = (body.email ?? '').toString().trim().toLowerCase();
      const name = body.name ? body.name.toString().trim() : null;
      if (!rawEmail || !rawEmail.includes('@')) {
        return json({ error: 'A valid email is required.' }, 400);
      }
      // Callback rejection must precede both whitelist writes and invitation email.
      // This is server-controlled exact approval, independent of the request Origin.
      let redirectTo;
      try {
        redirectTo = resolveInvitationCallback(
          body.redirect_to,
          getEnv('AUTH_WEB_CALLBACK_URLS') ?? '',
        );
      } catch {
        return json({ error: 'Invitation callback is not approved.' }, 400);
      }

      // 4) Pre-authorize as admin (the gate reads this on first sign-in).
      const { error: wlErr } = await admin
        .from('whitelists')
        .upsert({ email: rawEmail, role: 'admin', name }, { onConflict: 'email' });
      if (wlErr) return json({ error: `Whitelist failed: ${wlErr.message}` }, 400);

      // 5) Send the invite. The link lands on the set-password screen.
      const { error: inviteErr } = await admin.auth.admin.inviteUserByEmail(
        rawEmail,
        {
          data: { full_name: name ?? '' },
          redirectTo,
        },
      );
      if (inviteErr) {
        return json({ error: inviteErr.message }, 400);
      }

      return json({ success: true });
    } catch (e) {
      return json({ error: String(e) }, 500);
    }
  };
}
