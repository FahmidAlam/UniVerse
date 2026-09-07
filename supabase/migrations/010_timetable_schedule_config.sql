-- ============================================================
-- 010 — Make the university's scheduling rules configuration.
--
-- The engine used to hard-code rules that the university actually
-- changes between terms:
--   * `idx <= 6`      dropped the 7:00pm online period outright
--   * `friday_no_p4`  a named, single-purpose flag
--   * a 14-week term  implied by "every course meets twice a week"
--   * one intake/term implied by `max_batch - batch + 1`
--
-- All four now arrive from this table, so switching summer <-> winter
-- timings, or moving between a bi-semester and tri-semester calendar,
-- is an admin edit rather than a code change and a new APK.
--
-- Idempotent. Existing rows keep today's behaviour exactly:
-- weeks_in_term 14, period 7 held back, Friday P4 blocked.
-- ============================================================

alter table public.timetable_settings
  -- Days taught. NULL = the engine's Sun–Sat default, which must stay in
  -- step with AppConstants.weekDays.
  add column if not exists working_days text[],

  -- Term length in teaching weeks. Drives
  --     required_sessions = ceil(No. Of Classes / weeks_in_term)
  -- so a short term schedules the same course more often.
  add column if not exists weeks_in_term int not null default 14,

  -- Periods unavailable on a specific day, e.g. {"Friday": [4]}.
  -- Generalizes friday_no_p4, which is still read as a fallback.
  add column if not exists blocked_periods jsonb not null default '{}'::jsonb,

  -- Real teachable periods that are not drawn on the printed grid — the
  -- department's 7:00pm "OL Class" column. Held back unless enabled.
  add column if not exists online_periods jsonb not null default '[7]'::jsonb,
  add column if not exists allow_online_periods boolean not null default false,

  -- Periods disabled everywhere, for a term that simply runs shorter days.
  add column if not exists excluded_periods jsonb not null default '[]'::jsonb,

  -- Explicit batch -> study-semester mapping, e.g. {"66": 1, "65": 2}.
  -- Empty = fall back to counting down from the newest batch, which is only
  -- correct when the university takes exactly one intake per term.
  add column if not exists semester_map jsonb not null default '{}'::jsonb;

comment on column public.timetable_settings.weeks_in_term is
  'Teaching weeks in the term; converts a course''s whole-term class count into weekly sessions.';
comment on column public.timetable_settings.blocked_periods is
  'Per-day unavailable periods as {"Day": [period_idx, ...]}.';
comment on column public.timetable_settings.online_periods is
  'Periods that exist but are held back unless allow_online_periods is true.';
comment on column public.timetable_settings.semester_map is
  'Batch -> study semester. Set this under a tri-semester calendar.';

-- Guard the arithmetic that depends on it.
do $$
begin
  if not exists (select 1 from pg_constraint
                 where conname = 'timetable_settings_weeks_in_term_ck') then
    alter table public.timetable_settings
      add constraint timetable_settings_weeks_in_term_ck
      check (weeks_in_term between 1 and 52);
  end if;
end $$;

-- Ensure the singleton row exists so the admin screen always has something
-- to edit. Column defaults supply the rest.
insert into public.timetable_settings (id)
values (1)
on conflict (id) do nothing;
