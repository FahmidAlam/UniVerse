-- ============================================================
-- 015 — Fix every offering to the same number of weekly classes.
--
-- BACKGROUND
--   The engine derives an offering's weekly meetings from its own term total:
--
--       required_sessions = ceil(No. Of Classes / weeks_in_term)
--
--   In the Summer-2025 distribution that gives 2/week for 319 offerings and
--   3/week for six — all of them CSE-4116, which carries 38 classes. The
--   published Summer-2025 routine schedules those six three times a week too,
--   so the derivation matches what the department actually did.
--
--   The department has nonetheless decided every course should meet exactly
--   twice a week. This column carries that decision as configuration rather
--   than a literal in `ingest.py`, so it is visible, auditable, and can be
--   changed back from the admin screen without a code change or a redeploy.
--
-- COST, DELIBERATELY ACCEPTED
--   A course whose term total needs more meetings than the fixed rate will not
--   be fully taught. At 2/week CSE-4116 delivers 28 of its 38 classes — ten
--   short per section, sixty across the six sections. The engine reports one
--   warning per affected offering (course, cohort, and classes lost) on every
--   run, so the trade-off is never silent.
--
-- NULL or 0 restores the derived behaviour.
-- ============================================================

alter table public.timetable_settings
  add column if not exists fixed_sessions_per_week int default 2;

comment on column public.timetable_settings.fixed_sessions_per_week is
  'Weekly classes every offering gets, overriding ceil(No. Of Classes / '
  'weeks_in_term). NULL or 0 = derive per course from the distribution. '
  'A course needing more than this is under-taught; the engine warns per '
  'offering with the number of classes lost.';

do $$
begin
  if not exists (select 1 from pg_constraint
                 where conname = 'timetable_settings_fixed_sessions_ck') then
    alter table public.timetable_settings
      add constraint timetable_settings_fixed_sessions_ck
      check (fixed_sessions_per_week is null
             or fixed_sessions_per_week between 0 and 7);
  end if;
end $$;

-- The single settings row (id = 1) adopts the department's current rule.
update public.timetable_settings
   set fixed_sessions_per_week = 2
 where id = 1 and fixed_sessions_per_week is null;
