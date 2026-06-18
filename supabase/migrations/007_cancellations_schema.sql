-- ============================================================
-- MIGRATION 007 — canonical `cancellations` schema (+ RLS, Realtime)
-- PURPOSE: The teacher "Manage Classes" screen cancels a specific
--   class occurrence. Migration 006 already enabled RLS + policies
--   on `cancellations` (referencing `cancelled_by`), but the table's
--   COLUMNS were never captured in the repo. This migration pins the
--   canonical column set so the Flutter TeacherService inserts/reads
--   a known shape, and (re)states the policies so running this file
--   alone is sufficient.
--
-- IDEMPOTENT: safe to run on a fresh DB or over the existing table.
--   `create table if not exists` covers a missing/placeholder table;
--   the `add column if not exists` block guarantees every column the
--   app uses exists even if the table predates this migration.
--
-- DESIGN: a cancellation is per (routine row, calendar date). We
--   denormalize the cohort + class identity (batch/section/subject/
--   day/time_start) so the row stays meaningful even if the routine
--   is later edited, and so the student-facing alert can be built
--   without a join. `cancelled_by` ties to the staff member (RLS).
-- Run once in the Supabase SQL editor (after 006).
-- ============================================================

-- ─── Table ──────────────────────────────────────────────────
create table if not exists public.cancellations (
  id            uuid primary key default gen_random_uuid(),
  routine_id    uuid references public.routines(id) on delete cascade,
  class_date    date not null,
  reason        text,
  batch         text,
  section       text,
  subject       text,
  day           text,
  time_start    text,
  cancelled_by  uuid references auth.users(id),
  created_at    timestamptz not null default now()
);

-- Harden an already-existing table: ensure every app-used column is
-- present regardless of the table's original shape.
alter table public.cancellations add column if not exists routine_id   uuid references public.routines(id) on delete cascade;
alter table public.cancellations add column if not exists class_date   date;
alter table public.cancellations add column if not exists reason       text;
alter table public.cancellations add column if not exists batch        text;
alter table public.cancellations add column if not exists section      text;
alter table public.cancellations add column if not exists subject      text;
alter table public.cancellations add column if not exists day          text;
alter table public.cancellations add column if not exists time_start   text;
alter table public.cancellations add column if not exists cancelled_by uuid references auth.users(id);
alter table public.cancellations add column if not exists created_at   timestamptz not null default now();

-- Legacy reconciliation: an older cancellations table shipped a NOT NULL
-- `cancel_date` column. The app writes `class_date` instead, so relax the
-- legacy column so inserts don't fail. No-op if the column doesn't exist.
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'cancellations'
      and column_name = 'cancel_date'
  ) then
    alter table public.cancellations alter column cancel_date drop not null;
  end if;
end $$;

-- One active cancellation per occurrence (lets the app "undo" by a
-- clean delete and prevents duplicate alerts for the same class/date).
create unique index if not exists cancellations_routine_date_uniq
  on public.cancellations (routine_id, class_date);

-- Fast lookup of upcoming cancellations for a set of routine rows.
create index if not exists cancellations_date_idx
  on public.cancellations (class_date);

-- ─── RLS (restate 006 so this file is self-sufficient) ──────
alter table public.cancellations enable row level security;

drop policy if exists "cancellations_select" on public.cancellations;
create policy "cancellations_select" on public.cancellations
  for select to authenticated using (true);

-- Only the acting teacher/admin may insert, and only as themselves.
drop policy if exists "cancellations_insert_staff" on public.cancellations;
create policy "cancellations_insert_staff" on public.cancellations
  for insert to authenticated
  with check (
    cancelled_by = auth.uid()
    and public.my_role() in ('teacher', 'admin')
  );

-- A teacher can undo their own; admins can undo any.
drop policy if exists "cancellations_delete" on public.cancellations;
create policy "cancellations_delete" on public.cancellations
  for delete to authenticated
  using (cancelled_by = auth.uid() or public.is_admin());

-- ─── Realtime ───────────────────────────────────────────────
-- Add to the realtime publication so the student routine view can
-- react live (guarded — adding twice raises an error otherwise).
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename  = 'cancellations'
  ) then
    alter publication supabase_realtime add table public.cancellations;
  end if;
end $$;
