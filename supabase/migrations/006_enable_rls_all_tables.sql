-- ============================================================
-- MIGRATION 006 — enable RLS on every table + full policy set
-- PURPOSE: Before this, 10 of 12 public tables had RLS disabled —
--   anyone holding the anon key (extractable from the APK) could
--   read/write everything, including granting themselves an admin
--   profile or editing the whitelist.
--
-- DESIGN NOTES
--   • All policies are `to authenticated` — the app requires login,
--     so the anon role gets zero access.
--   • Helper functions are SECURITY DEFINER so policies on `profiles`
--     can check the caller's role without recursing into profiles'
--     own RLS.
--   • The SQL editor (postgres) and the send-push Edge Function
--     (service role) bypass RLS — seeds and admin scripts still work.
--   • Profile creation happens CLIENT-side (handlePostLogin /
--     complete*Registration), so users may insert their own row —
--     but never with role 'admin' unless the whitelist says so.
-- Run once in the Supabase SQL editor (after 004 and 005).
-- ============================================================

-- ─── Helpers ────────────────────────────────────────────────

-- Caller's role from profiles, bypassing RLS (no recursion).
create or replace function public.my_role()
returns text
language sql stable security definer
set search_path = public
as $$
  select role from profiles where id = auth.uid();
$$;

create or replace function public.is_admin()
returns boolean
language sql stable security definer
set search_path = public
as $$
  select coalesce(public.my_role() = 'admin', false);
$$;

revoke execute on function public.my_role(), public.is_admin() from anon, public;
grant  execute on function public.my_role(), public.is_admin() to authenticated;

-- ─── profiles ───────────────────────────────────────────────
alter table public.profiles enable row level security;

drop policy if exists "profiles_select" on public.profiles;
create policy "profiles_select" on public.profiles
  for select to authenticated using (true);

-- Own row only, and the role must be student/teacher unless the
-- caller's email is whitelisted for that exact role (admins).
drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own" on public.profiles
  for insert to authenticated
  with check (
    id = auth.uid()
    and (
      role in ('student', 'teacher')
      or exists (
        select 1 from public.whitelists w
        where lower(w.email) = lower(auth.jwt() ->> 'email')
          and w.role = profiles.role
      )
    )
  );

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own" on public.profiles
  for update to authenticated
  using (id = auth.uid() or public.is_admin())
  with check (
    public.is_admin()
    or (
      id = auth.uid()
      and (
        role in ('student', 'teacher')
        or exists (
          select 1 from public.whitelists w
          where lower(w.email) = lower(auth.jwt() ->> 'email')
            and w.role = profiles.role
        )
      )
    )
  );

drop policy if exists "profiles_delete_admin" on public.profiles;
create policy "profiles_delete_admin" on public.profiles
  for delete to authenticated using (public.is_admin());

-- ─── whitelists ─────────────────────────────────────────────
-- handlePostLogin reads the caller's own row by email before a
-- profile exists; only admins manage the list.
alter table public.whitelists enable row level security;

drop policy if exists "whitelists_select" on public.whitelists;
create policy "whitelists_select" on public.whitelists
  for select to authenticated
  using (lower(email) = lower(auth.jwt() ->> 'email') or public.is_admin());

drop policy if exists "whitelists_write_admin" on public.whitelists;
create policy "whitelists_write_admin" on public.whitelists
  for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- ─── routines ───────────────────────────────────────────────
alter table public.routines enable row level security;

drop policy if exists "routines_select" on public.routines;
create policy "routines_select" on public.routines
  for select to authenticated using (true);

drop policy if exists "routines_write_admin" on public.routines;
create policy "routines_write_admin" on public.routines
  for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- ─── cancellations ──────────────────────────────────────────
alter table public.cancellations enable row level security;

drop policy if exists "cancellations_select" on public.cancellations;
create policy "cancellations_select" on public.cancellations
  for select to authenticated using (true);

drop policy if exists "cancellations_insert_staff" on public.cancellations;
create policy "cancellations_insert_staff" on public.cancellations
  for insert to authenticated
  with check (
    cancelled_by = auth.uid()
    and public.my_role() in ('teacher', 'admin')
  );

drop policy if exists "cancellations_delete" on public.cancellations;
create policy "cancellations_delete" on public.cancellations
  for delete to authenticated
  using (cancelled_by = auth.uid() or public.is_admin());

-- ─── notifications ──────────────────────────────────────────
-- Realtime respects RLS — the select policy keeps the live feed working.
alter table public.notifications enable row level security;

drop policy if exists "notifications_select" on public.notifications;
create policy "notifications_select" on public.notifications
  for select to authenticated using (true);

drop policy if exists "notifications_insert_staff" on public.notifications;
create policy "notifications_insert_staff" on public.notifications
  for insert to authenticated
  with check (
    sent_by = auth.uid()
    and public.my_role() in ('teacher', 'admin')
  );

drop policy if exists "notifications_delete" on public.notifications;
create policy "notifications_delete" on public.notifications
  for delete to authenticated
  using (sent_by = auth.uid() or public.is_admin());

-- ─── resources ──────────────────────────────────────────────
alter table public.resources enable row level security;

drop policy if exists "resources_select" on public.resources;
create policy "resources_select" on public.resources
  for select to authenticated using (true);

drop policy if exists "resources_insert_staff" on public.resources;
create policy "resources_insert_staff" on public.resources
  for insert to authenticated
  with check (
    uploaded_by = auth.uid()
    and public.my_role() in ('teacher', 'admin')
  );

drop policy if exists "resources_modify" on public.resources;
create policy "resources_modify" on public.resources
  for update to authenticated
  using (uploaded_by = auth.uid() or public.is_admin())
  with check (uploaded_by = auth.uid() or public.is_admin());

drop policy if exists "resources_delete" on public.resources;
create policy "resources_delete" on public.resources
  for delete to authenticated
  using (uploaded_by = auth.uid() or public.is_admin());

-- ─── assignments ────────────────────────────────────────────
alter table public.assignments enable row level security;

drop policy if exists "assignments_select" on public.assignments;
create policy "assignments_select" on public.assignments
  for select to authenticated using (true);

drop policy if exists "assignments_insert_teacher" on public.assignments;
create policy "assignments_insert_teacher" on public.assignments
  for insert to authenticated
  with check (
    teacher_id = auth.uid()
    and public.my_role() in ('teacher', 'admin')
  );

drop policy if exists "assignments_modify" on public.assignments;
create policy "assignments_modify" on public.assignments
  for update to authenticated
  using (teacher_id = auth.uid() or public.is_admin())
  with check (teacher_id = auth.uid() or public.is_admin());

drop policy if exists "assignments_delete" on public.assignments;
create policy "assignments_delete" on public.assignments
  for delete to authenticated
  using (teacher_id = auth.uid() or public.is_admin());

-- ─── submissions ────────────────────────────────────────────
-- Students see their own; teachers/admins see all (teachers need to
-- grade). is_late stays trigger-managed — clients can't set it on
-- insert because the column isn't in their payload, and the trigger
-- overwrites it anyway.
alter table public.submissions enable row level security;

drop policy if exists "submissions_select" on public.submissions;
create policy "submissions_select" on public.submissions
  for select to authenticated
  using (
    student_id = auth.uid()
    or public.my_role() in ('teacher', 'admin')
  );

drop policy if exists "submissions_insert_own" on public.submissions;
create policy "submissions_insert_own" on public.submissions
  for insert to authenticated
  with check (student_id = auth.uid());

drop policy if exists "submissions_update_own" on public.submissions;
create policy "submissions_update_own" on public.submissions
  for update to authenticated
  using (student_id = auth.uid())
  with check (student_id = auth.uid());

drop policy if exists "submissions_delete" on public.submissions;
create policy "submissions_delete" on public.submissions
  for delete to authenticated
  using (student_id = auth.uid() or public.is_admin());

-- ─── documents (RAG store) ──────────────────────────────────
-- Read for all signed-in users (the AI assistant queries it via
-- match_documents); ingestion is admin-only.
alter table public.documents enable row level security;

drop policy if exists "documents_select" on public.documents;
create policy "documents_select" on public.documents
  for select to authenticated using (true);

drop policy if exists "documents_write_admin" on public.documents;
create policy "documents_write_admin" on public.documents
  for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- ─── generated_timetable ────────────────────────────────────
-- The FastAPI engine writes with the service key (bypasses RLS).
alter table public.generated_timetable enable row level security;

drop policy if exists "timetable_select" on public.generated_timetable;
create policy "timetable_select" on public.generated_timetable
  for select to authenticated using (true);

drop policy if exists "timetable_write_admin" on public.generated_timetable;
create policy "timetable_write_admin" on public.generated_timetable
  for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- ─── storage: replace anonymous-write "Public Access" ───────
-- Keep public READ (avatars/resources load without signed URLs),
-- but only signed-in users may upload/replace/delete.
drop policy if exists "Public Access" on storage.objects;

drop policy if exists "storage_public_read" on storage.objects;
create policy "storage_public_read" on storage.objects
  for select using (true);

drop policy if exists "storage_auth_insert" on storage.objects;
create policy "storage_auth_insert" on storage.objects
  for insert to authenticated with check (true);

drop policy if exists "storage_auth_update" on storage.objects;
create policy "storage_auth_update" on storage.objects
  for update to authenticated using (true) with check (true);

drop policy if exists "storage_auth_delete" on storage.objects;
create policy "storage_auth_delete" on storage.objects
  for delete to authenticated using (true);
