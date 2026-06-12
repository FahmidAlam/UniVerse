-- ============================================================
-- MIGRATION 004 — device_tokens
-- PURPOSE: Store each user's FCM registration token(s) so the
--   send-push Edge Function knows where to deliver a broadcast.
--   A user can have several devices → token is the primary key,
--   user_id is the lookup. Tokens rotate, so the app upserts on
--   every login / onTokenRefresh and deletes on sign-out.
-- Run once in the Supabase SQL editor.
-- ============================================================

create table if not exists public.device_tokens (
  token       text        primary key,
  user_id     uuid        not null references auth.users(id) on delete cascade,
  platform    text        not null default 'android',
  updated_at  timestamptz not null default now()
);

-- Fast "all tokens for these users" lookups from the Edge Function.
create index if not exists idx_device_tokens_user
  on public.device_tokens (user_id);

-- ── RLS: a user may only read / write their OWN tokens. ──
-- The send-push function uses the service-role key, which bypasses
-- RLS, so it can still read every target user's token.
alter table public.device_tokens enable row level security;

drop policy if exists "own_tokens_select" on public.device_tokens;
create policy "own_tokens_select" on public.device_tokens
  for select using (user_id = auth.uid());

drop policy if exists "own_tokens_insert" on public.device_tokens;
create policy "own_tokens_insert" on public.device_tokens
  for insert with check (user_id = auth.uid());

drop policy if exists "own_tokens_update" on public.device_tokens;
create policy "own_tokens_update" on public.device_tokens
  for update using (user_id = auth.uid());

drop policy if exists "own_tokens_delete" on public.device_tokens;
create policy "own_tokens_delete" on public.device_tokens
  for delete using (user_id = auth.uid());
