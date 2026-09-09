-- 013_faculty_course_eligibility.sql
--
-- Faculty <-> course eligibility and preference.
--
-- WHY THIS IS A VALIDATION GATE, NOT A SOLVER INPUT
-- -------------------------------------------------
-- The Course Distribution workbook names the teacher for every offering, and
-- the CP-SAT model only chooses (day, period) — it has never selected a
-- teacher and does not now. So eligibility cannot "stop the solver assigning
-- the wrong person"; there is no such assignment to stop. What it CAN do, and
-- what this table is for, is catch a distribution row that hands a course to a
-- faculty member who is not qualified for it, BEFORE the routine is published.
-- The engine reports those rows and the publish gate refuses them.
--
-- `priority` is stored for preference-ordering. Nothing optimises against it
-- yet — it would only bind if teacher selection ever moved into the solver.
--
-- Unconfigured means unknown, not ineligible: a teacher with no rows here is
-- never reported, so turning the feature on does not fail every offering at
-- once. Only a teacher who HAS a configured course list can violate it.

create table if not exists public.timetable_course_eligibility (
  id            uuid primary key default gen_random_uuid(),
  acronym       text not null,
  course_code   text not null,
  is_eligible   boolean not null default true,
  priority      int,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  constraint timetable_course_eligibility_unique unique (acronym, course_code),
  constraint timetable_course_eligibility_priority_positive
    check (priority is null or priority > 0)
);

create index if not exists timetable_course_eligibility_acronym_idx
  on public.timetable_course_eligibility (acronym);

alter table public.timetable_course_eligibility enable row level security;

-- Same pattern as the other timetable_* config tables (migration 008):
-- everyone may read the configuration, only an admin may change it.
drop policy if exists read_all on public.timetable_course_eligibility;
create policy read_all on public.timetable_course_eligibility
  for select using (true);

drop policy if exists admin_write on public.timetable_course_eligibility;
create policy admin_write on public.timetable_course_eligibility
  for all
  using (public.is_admin())
  with check (public.is_admin());
