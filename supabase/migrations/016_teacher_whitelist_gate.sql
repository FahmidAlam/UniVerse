-- ============================================================
-- 016 — Teacher accounts need a whitelist entry, like admins.
--
-- BEFORE
--   The RLS policies from 006 let any signed-in user create their own
--   profile with role 'teacher' and any teacher_code. Nothing checked either,
--   so anyone with a Google account could become a "teacher" and use
--   teacher-only features (cancelling classes, sending notices). Only 'admin'
--   needed a `whitelists` row.
--
-- NOW
--   A BEFORE INSERT/UPDATE trigger on `profiles` lets users give THEMSELVES a
--   non-student role only when `whitelists` holds their email with that role.
--   • Students still sign up freely.
--   • Admins, the SQL editor and the service role may set any role, so role
--     changes from Manage Users keep working.
--   • Existing profiles are untouched. A write that keeps the role is always
--     allowed, so teachers who registered before this migration keep their
--     access and can still edit their profile. Review them in Manage Users.
--   • The refusal carries hint 'not_whitelisted'; the app turns it into the
--     Not Whitelisted screen (AuthService.isNotWhitelistedError).
--
--   Admins add teachers from Admin Registration → "Add a teacher". On first
--   sign-in, handlePostLogin creates the teacher profile from that row.
--
-- Also adds `department` / `designation` to `whitelists`. handlePostLogin has
-- always copied them into the profile it creates, but the columns never
-- existed, so they were silently null.
--
-- Run once in the Supabase SQL editor. Re-running is safe.
-- ============================================================

alter table public.whitelists
  add column if not exists department  text,
  add column if not exists designation text;

create or replace function public.guard_profile_role()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- No end-user JWT (SQL editor, service role) or an admin: any role.
  if auth.uid() is null or public.is_admin() then
    return new;
  end if;

  -- The role is not changing: ordinary profile edits.
  if tg_op = 'UPDATE' and new.role is not distinct from old.role then
    return new;
  end if;

  -- Same, for an upsert of an existing row. Postgres fires BEFORE INSERT
  -- before it detects the conflict, so the existing row is looked up here.
  if tg_op = 'INSERT' and exists (
    select 1 from profiles p where p.id = new.id and p.role = new.role
  ) then
    return new;
  end if;

  if new.role = 'student' then
    return new;
  end if;

  if exists (
    select 1 from whitelists w
    where lower(w.email) = lower(auth.jwt() ->> 'email')
      and w.role = new.role
  ) then
    return new;
  end if;

  raise exception 'The % role needs to be added by the department admin.', new.role
    using errcode = '42501', hint = 'not_whitelisted';
end;
$$;

drop trigger if exists profiles_guard_role on public.profiles;
create trigger profiles_guard_role
  before insert or update on public.profiles
  for each row execute function public.guard_profile_role();

-- ─── VERIFY ─────────────────────────────────────────────────
-- 1. The trigger exists:
--      select tgname from pg_trigger
--      where tgrelid = 'public.profiles'::regclass and not tgisinternal;
--    → profiles_guard_role
-- 2. The columns exist:
--      select column_name from information_schema.columns
--      where table_name = 'whitelists' and column_name in ('department', 'designation');
-- 3. In the app, a Google account that is NOT whitelisted choosing Teacher
--    gets the "Teacher Access" message, and a whitelisted one lands on the
--    teacher dashboard.
