// RECOVERED BASELINE SOURCE: four test-project handler denial checks passed.
// Positive invitation/email behavior remains untested; no production rollout.
// No deployment is authorized by this file. See Task 1 in the implementation plan.
// ============================================================
// EDGE FUNCTION: invite-admin
// PURPOSE: Securely provision a new ADMIN. Account creation needs the
// service-role key, which must NEVER live in the Flutter app — so it
// happens here, server-side.
//
// FLOW:
//   1. Verify the CALLER is an admin (from their JWT).
//   2. Upsert a `whitelists` row (role='admin') so the gate in
//      auth_service.handlePostLogin() assigns admin on first sign-in.
//   3. inviteUserByEmail() creates the auth user and emails an invite link.
//      Completion requires a verified invitation callback bridge. Selecting
//      a browser URL alone does not make implicit invite tokens work with PKCE.
//
// DEPLOY (either one):
//   • Dashboard → Edge Functions → create "invite-admin" → paste this.
//   • CLI: supabase functions deploy invite-admin
// SUPABASE_URL / SUPABASE_ANON_KEY / SUPABASE_SERVICE_ROLE_KEY are
// injected automatically — no secrets to set.
// NOTE: invites send via your project's email (Auth → SMTP). The
// built-in sender works for testing (low rate limit).
// ============================================================

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { createInvitationHandler } from './handler.js';

Deno.serve(createInvitationHandler({
  createClient,
  getEnv: (name: string) => Deno.env.get(name),
}));
