-- ============================================================
-- SEED — whitelists (admin gate)
-- PURPOSE: Pre-register the demo ADMIN account. The whitelist is
--   enforced ONLY for admins (see auth_service.handlePostLogin):
--   an admin email must exist here BEFORE first sign-in, otherwise
--   the account is signed out to the NotWhitelistedScreen.
--
-- HOW TO MINT THE ADMIN (do in this order):
--   1. Run this file in the Supabase SQL editor (adds the email
--      with role='admin').
--   2. In the app: "Create account" -> Email sign up with the SAME
--      email + a password -> open the verification email link.
--   3. handlePostLogin() reads this row, sees role='admin', creates
--      a profile with role='admin' -> lands on /admin/dashboard.
--
-- Replace the email/name below with the address you will sign up with.
-- Idempotent: target-less ON CONFLICT DO NOTHING (safe regardless of
-- which column carries the unique/primary-key constraint).
--
-- NOTE: this inserts only email/role/name (all that an admin needs).
-- If your `whitelists` table has extra NOT-NULL columns without a
-- default, the Step 0 schema check will surface them and we add them.
-- ============================================================

insert into public.whitelists (email, role, name)
values
  ('admin@universe.app', 'admin', 'UniVerse Admin')
on conflict do nothing;
