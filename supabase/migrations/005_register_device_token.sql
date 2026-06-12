-- ============================================================
-- MIGRATION 005 — register_device_token RPC
-- PURPOSE: RLS-safe FCM token registration. A plain upsert fails
--   with 42501 when the token row still belongs to ANOTHER user
--   (sign-out that never cleaned up, app reinstall, crash): the
--   update path of the upsert can't touch the old user's row.
--   This SECURITY DEFINER function deletes any stale row for the
--   token, then upserts it for the calling user. user_id is always
--   auth.uid() — callers can't register tokens for someone else.
-- Run once in the Supabase SQL editor (after 004_device_tokens.sql).
-- ============================================================

create or replace function public.register_device_token(
  p_token    text,
  p_platform text default 'android'
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  -- Clear a stale row left by a previous user of this device.
  delete from public.device_tokens
   where token = p_token
     and user_id <> auth.uid();

  insert into public.device_tokens (token, user_id, platform, updated_at)
  values (p_token, auth.uid(), p_platform, now())
  on conflict (token) do update
     set user_id    = excluded.user_id,
         platform   = excluded.platform,
         updated_at = now();
end;
$$;

revoke execute on function public.register_device_token(text, text) from anon, public;
grant  execute on function public.register_device_token(text, text) to authenticated;
