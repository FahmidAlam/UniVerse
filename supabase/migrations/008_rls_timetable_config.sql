-- ============================================================
-- MIGRATION 008 — RLS for the timetable_* config tables
-- PURPOSE: 006 enabled RLS on every table that existed then, but the
--   timetable_rooms / timetable_faculty / timetable_settings tables were
--   created later (directly in the dashboard, alongside the seed) and
--   shipped with RLS OFF + zero policies. With the anon key extractable
--   from the APK, anyone could read AND rewrite the faculty directory
--   (76 rows), room pool, and solver settings. This closes that gap with
--   the same read_all + admin_write pattern as 006.
--
--   Also harmonises timetable_runs: its existing policies target role
--   `public` (so anon could SELECT it) with an inline admin check —
--   re-create them `to authenticated` using the is_admin() helper, to
--   match every other table.
--
--   Relies on the helpers from 006: public.my_role() / public.is_admin().
-- Run once in the Supabase SQL editor (after 006/007). Idempotent.
-- ============================================================

do $$
declare t text;
begin
  foreach t in array array['timetable_rooms', 'timetable_faculty',
                           'timetable_settings'] loop
    execute format('alter table public.%I enable row level security;', t);

    -- read: any signed-in user (the app reads the config to build the
    -- engine request and to render the admin config screens).
    execute format('drop policy if exists "%1$s_select" on public.%1$s;', t);
    execute format($f$create policy "%1$s_select" on public.%1$s
        for select to authenticated using (true);$f$, t);

    -- write: admins only.
    execute format('drop policy if exists "%1$s_write_admin" on public.%1$s;', t);
    execute format($f$create policy "%1$s_write_admin" on public.%1$s
        for all to authenticated
        using (public.is_admin()) with check (public.is_admin());$f$, t);
  end loop;
end $$;
-- ─── timetable_runs: harmonise to the standard pattern ──────
alter table public.timetable_runs enable row level security;

drop policy if exists "read_all"    on public.timetable_runs;
drop policy if exists "admin_write" on public.timetable_runs;

drop policy if exists "timetable_runs_select" on public.timetable_runs;
create policy "timetable_runs_select" on public.timetable_runs
  for select to authenticated using (true);

drop policy if exists "timetable_runs_write_admin" on public.timetable_runs;
create policy "timetable_runs_write_admin" on public.timetable_runs
  for all to authenticated
  using (public.is_admin()) with check (public.is_admin());
