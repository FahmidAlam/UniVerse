-- ============================================================
-- SEED — demo accounts for the TIMETABLE ENGINE demo
-- PURPOSE: Point your demo student + teacher at the cohort the
--   engine generates (batch 63), so that after the admin runs
--   Generate Timetable → Publish, those accounts immediately see
--   the freshly generated routine in the existing routine viewer.
--
-- WHY THIS EXISTS: profiles extend auth.users and are created on
--   first sign-in, so they can't be INSERTed from SQL without the
--   service-role key. Instead, sign the accounts up in the app
--   FIRST, then run these UPDATEs to align them with the demo.
--
-- HOW TO USE (do in this order):
--   1. In the app, create a STUDENT account (email sign-up) and a
--      TEACHER account. Verify both via email.
--   2. Replace the two emails below with those accounts' emails.
--   3. Run this file in the Supabase SQL editor.
--   4. Admin → Generate Timetable → Publish (writes batch 63).
--   5. Log in as the student → routine screen shows section A.
--      Log in as the teacher (AMI) → shows their classes across
--      sections A & C.
--
-- The engine fixture (engine/fixtures/offerings.json) generates
--   batch 63, sections A–D, semester 5, with teacher AMI teaching
--   Operating Systems for sections A & C — these values match below.
-- Idempotent: UPDATE by email; re-running just re-applies the same
--   values (0 rows if the account doesn't exist yet).
-- ============================================================

-- ─── Demo STUDENT → batch 63, section A, semester 5 ──────────
update public.profiles
set role     = 'student',
    batch    = '63',
    section  = 'A',
    semester = 5
where email = 'student@universe.app';   -- ← replace with your demo student email

-- ─── Demo TEACHER → teacher_code AMI (Dr. Aminul Islam) ──────
update public.profiles
set role         = 'teacher',
    teacher_code = 'AMI'
where email = 'teacher@universe.app';    -- ← replace with your demo teacher email
