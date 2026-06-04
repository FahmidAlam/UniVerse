-- ============================================================
-- MIGRATION 001 — notification_reads
-- PURPOSE: Per-user read tracking for BROADCAST notifications.
--   notifications are targeted by role/batch/section, so a single
--   row is seen by many users. Read-state therefore cannot live on
--   the notification row — it lives here, one row per (user, notif).
-- Run once in the Supabase SQL editor.
-- ============================================================

create table if not exists public.notification_reads (
  user_id         uuid        not null references auth.users(id)        on delete cascade,
  notification_id uuid        not null references public.notifications(id) on delete cascade,
  read_at         timestamptz not null default now(),
  primary key (user_id, notification_id)
);

-- Fast "what has this user read" lookups.
create index if not exists idx_notification_reads_user
  on public.notification_reads (user_id);

-- ── RLS: a user may only see / write their OWN read-marks ──
alter table public.notification_reads enable row level security;

drop policy if exists "own_reads_select" on public.notification_reads;
create policy "own_reads_select" on public.notification_reads
  for select using (user_id = auth.uid());

drop policy if exists "own_reads_insert" on public.notification_reads;
create policy "own_reads_insert" on public.notification_reads
  for insert with check (user_id = auth.uid());

drop policy if exists "own_reads_update" on public.notification_reads;
create policy "own_reads_update" on public.notification_reads
  for update using (user_id = auth.uid());

drop policy if exists "own_reads_delete" on public.notification_reads;
create policy "own_reads_delete" on public.notification_reads
  for delete using (user_id = auth.uid());
