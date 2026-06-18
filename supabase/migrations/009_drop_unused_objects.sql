-- ============================================================
-- MIGRATION 009 — drop genuinely-dead leftovers
-- PURPOSE: Light cleanup only. The scaffolded feature tables
--   (assignments, submissions, documents) and the legacy
--   generated_timetable are KEPT — they're empty but RLS-protected
--   (migration 006) and reserved for future scope (assignment/
--   submission feature, AI assistant). Nothing here removes them.
--
--   The only active change is dropping a dead legacy COLUMN.
-- Run after 008. Idempotent.
-- ============================================================

-- ─── legacy column: cancellations.cancel_date ──────────────
-- 007 relaxed its old NOT NULL; the app writes `class_date` instead and
-- nothing reads `cancel_date`. Drop the leftover to avoid two-date confusion.
alter table public.cancellations drop column if exists cancel_date;

-- ─── legacy table: generated_timetable ─────────────────────
-- Pure legacy, superseded by `routines` (its columns don't match what the
-- engine emits). 0 rows, no code references, nothing FKs into it. `cascade`
-- removes its two RLS policies with it.
drop table if exists public.generated_timetable cascade;

-- ============================================================
-- OPTIONAL — future cleanup, DISABLED by request.
-- Uncomment ONLY if you decide to abandon these features. Drop order
-- respects FKs (submissions -> assignments). `cascade` removes dependent
-- policies / triggers / constraints. These are destructive & irreversible.
-- ============================================================
-- drop table    if exists public.documents          cascade;   -- RAG store (AI assistant)
-- drop table    if exists public.submissions        cascade;   -- assignment/submission feature
-- drop table    if exists public.assignments        cascade;
-- drop function if exists public.calculate_is_late() cascade;
-- delete from storage.buckets where id in ('assignments', 'avatars', 'submissions');
-- alter table public.routines drop column if exists teacher_id;  -- unused FK (teacher is text)
