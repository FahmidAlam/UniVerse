# CLAUDE.md — UniVerse Project Context & Engineering Guide

> Load this at the start of every session. Dense reference only — no fluff.
> Last updated: September 2026 — **post-demo. The goal is now a reliable,
> maintainable, configurable, secure, production-ready system.**
> The app is BUILT and runs end-to-end. It is NOT production-ready.
> **The timetable / routine generation engine is the core of this product and the
> highest engineering priority.** Nothing else ships until it is academically correct.
> The agent never pushes — Fahmid merges + rebuilds the APK.

---

## 0. PRIORITY LADDER — READ BEFORE PICKING UP ANY WORK

Work top-down. Do not start a lower band while a higher one has open **Critical**
or **High** items, unless Fahmid explicitly redirects.

| # | Band | Scope |
|---|---|---|
| **P0** | **Timetable correctness** | Distribution completeness, credit→session allocation, post-generation validation, traceable failures |
| **P1** | **Routine persistence / DB state** | Full routine replacement, atomicity, routine identity/versioning, no stale rows |
| **P2** | **Distribution normalization** | `Raw workbook → Normalized academic data → Engine`; decouple engine from spreadsheet artifacts |
| **P3** | **Configurability** | Summer/winter periods, working days, breaks, term structure — all admin-editable, no rebuild |
| **P4** | **Engine tests** | Automated tests for every invariant below |
| **P5** | **Auth / OAuth reliability** | Root-cause the OAuth flow; never weaken security to make it "work" |
| **P6** | **Security audit** | Least privilege, secrets, RLS, input validation, uploads, logging |
| **P7** | **App-wide issue backlog** | Prioritized Critical → High → Medium → Low, root-cause fixes. Includes performance + UX polish: loading/empty states, redundant network calls, caching |
| **P8** | **University API integration** | Only behind an isolated, failure-tolerant abstraction layer |
| **P9** | **App update strategy** | Version check + prompt; **never** a custom APK-replacement mechanism |

### Working method — mandatory for every non-trivial change
1. **Identify current behavior** (read the code; run it if you can).
2. **Identify the root problem** — not the symptom.
3. **Explain the proposed fix** and get agreement before large architectural moves.
4. **Implement.**
5. **Test** (automated where practical).
6. **Verify existing functionality still works** (`flutter analyze`, `flutter test`, engine self-validation).

Never hide a defect behind a UI workaround. Never rewrite a working component because
you'd have designed it differently — improve in place unless there is a real problem.

---

## ⚠️ READ FIRST — GUARDRAILS

This is a working app with a **live backend**. Breaking these breaks the whole system.

**Never change one side without the matching change everywhere:**
- **Engine row shape ↔ `routines` columns.** The Python engine emits rows shaped exactly
  like the `routines` table. There are **two producers** of `routines` rows — the engine AND
  the Upload Routine workbook parser (`routine_workbook_parser.dart`). Both must stay in sync
  with the row shape, and both publish through the same path.
- **`routines` is written ONLY by the `publish_routine()` RPC** (migration 011). It replaces
  the entire routine in one transaction. Never insert into or delete from `routines` directly,
  and never reintroduce a per-batch delete — that is exactly the bug that let two routines
  merge. See §P1.
- **A routine that fails validation must not be publishable.** The distribution is a hard
  constraint; `TimetableGenController.blockingValidationError` is the gate. See §P0.
- **Config tables (`timetable_rooms` / `timetable_faculty` / `timetable_settings` /
  `timetable_courses`).** Edited by admin screens, read by
  `TimetableConfigService.buildEngineConfig()`, consumed by the engine's
  `_normalize_config()`. Rename a column → update all three.
- **DB schema / RLS / Storage buckets.** Only the `services/` layer touches Supabase. Any
  SQL change needs the matching Dart service + an `app_constants` table constant + a
  numbered migration in `supabase/migrations/`.
- **`TIMETABLE_BASE_URL` default** in `app_constants.dart` — the shipped APK depends on it
  pointing at the live engine. Don't change it without rebuilding the APK.
- **Week days = Sun–Sat (7 days).** `AppConstants.weekDays`/`weekDaysShort` are the single
  source of truth and MUST match the engine config "days" order. The university teaches all
  7 days. Every controller maps `DateTime.weekday`→day via these — never reintroduce a
  Sun–Thu (5-day) assumption.
- **`cancellations` table (migration 007) is LIVE.** Teacher Manage Classes writes one dated
  row (`routine_id`+`class_date`) per cancelled occurrence AND a `class_cancel` notification.
  `cancellations.routine_id` is `ON DELETE SET NULL` since migration 011 — it used to be
  CASCADE, which silently wiped the whole cancellation history on every republish.
- **Notifications ⇒ push (automatic).** Any INSERT into `notifications` fires the deployed
  `send-push` Edge Function (DB webhook) → OS push to the audience. Creating a notification
  row = in-app alert + push; don't add a second push path.
- **Clock text ⇒ always through `ClockTime` (`core/utils/clock_time.dart`).** Period
  boundaries arrive hand-typed ("13:10", "1:50", "1:50 PM"). A bare `1:50` written straight
  to Postgres lands as **01:50 — 1:50 AM**, which put afternoon classes in the middle of the
  night. Both producers of `routines` rows normalize with it. **Two output shapes — do not
  mix them:** Postgres gets `HH:MM:SS`; the **engine gets `HH:MM` only**, because
  `render.py::_fmt_clock` unpacks with `h, m = hhmm.split(":")`. Covered by
  `test/clock_time_test.dart`.
- **Never commit a merge with conflict markers.** It has happened (commit `893d96f` shipped
  `>>>>>>> origin/main` inside four `.dart` files and broke every build). After any merge:
  `grep -rn "^<<<<<<< \|^>>>>>>> " lib/ engine/` must return nothing, then `flutter analyze`.
  Resolve **additively** — taking "theirs" blindly once would have deleted
  `fetchSubjectTitleMap()` and `_registerPushToken()`.

**Never touch / never commit:**
- Supabase URL + anon key live as defaults in `app_constants.dart` (anon key is safe to
  ship). The **service-role key lives only in the `invite-admin` Edge Function** — never in
  the app, never in git.
- **Raw distribution workbooks** (`engine/routine generation files/`) — real teacher PII
  (phone/email); gitignored. Never commit them or the explainer PDF. Derive fixtures from
  them (PII-stripped) instead.
- `dart_defines.json` (gitignored). `google-services.json` / `firebase_options.dart` are
  committed (Android client config, not secret).
- **Don't downgrade Gradle below 8.14** — the dev machine runs JDK 24.
  ⚠️ **Gradle 8.14 / AGP 8.9.1 top out at Java 24.** If the JDK is upgraded (e.g. Temurin 25),
  Gradle reports the bare version string as the whole error — `* What went wrong: 25.0.4`.
  Fix by pointing Flutter back at JDK 24, **not** by editing Gradle:
  `flutter config --jdk-dir "C:\Program Files\Java\jdk-24"` (verify `flutter doctor -v`).

**Don't re-add the AI assistant** without first running the `documents` table migration
(intentionally descoped — see that section).

**Deployment is automatic:** push to `main` → Render rebuilds the engine. Don't deploy
manually. The engine is stateless (in-memory job dict) — no DB on the engine side.

---

## APP IDENTITY

| Field | Value |
|---|---|
| Name | **UniVerse — A Campus Companion** |
| Platform | Android (Flutter) |
| University | Leading University, Sylhet, Bangladesh |
| Department | CSE · Course CSE-3240 (Project I) · Team **Sherlocked** |
| Advisor | Md. Jamaner Rahaman, Assistant Professor |
| Flutter package | `universe` · applicationId `com.example.universe` ⚠️ *(blocks Play Store — see §P9)* |
| Actors | Student · Teacher · Admin |
| **Core differentiator** | **Automatic department timetable generator (OR-Tools CP-SAT)** |

---

# ═══ P0 — TIMETABLE / ROUTINE GENERATION ENGINE ═══

**This is the heart of the product.** A routine that merely *looks* valid is not done.
It must be **academically valid**: every required course present, every course given the
teaching time its credit demands, every conflict absent, every failure explained.

## P0.1 — The distribution is a HARD CONSTRAINT

The Course Distribution workbook is the **authoritative source of required courses**.

Non-negotiable rules:
- Every required offering in the distribution **must** appear in the generated routine.
- A required course missing from the output is a **generation failure**, not a warning.
- The engine must **never silently drop** a course because scheduling was difficult.
- Any offering deliberately excluded (project/thesis with no teacher, non-timetabled
  administrative rows) must be **explicitly classified with a typed reason**, surfaced to
  the admin, and counted — never quietly skipped.
- **Fail loudly.** When something cannot be scheduled, the error must name: which course,
  which cohort, which teacher, why, which constraint bound it, and what was tried.

## P0.2 — Credits → required sessions (do NOT assume 1 course = 1 slot)

The current engine hard-codes **exactly two weekly sessions per distribution row**
(`for occ in (1, 2)` in `ingest.py`). That is wrong in two directions. The real rule is
derivable from the distribution itself:

Columns present in `Course Distribution` (header row 5, data from row 6):

| Column | Role |
|---|---|
| Batch, Section | cohort identity (**required**) |
| Course Code | offering identity (**required**) |
| Course Title | display |
| **Credit** | academic credit value — **currently ignored by the engine** |
| Prerequisite | not used by scheduling |
| Conducting Department | service/non-CSE detection |
| No. Of Students | capacity — not yet used (relevant to gallery/room sizing) |
| **Teacher** | teacher acronym (**required**; blank ⇒ non-timetabled) |
| **No. Of Classes** | **total sessions for the whole term** — the real driver |
| Class Duration | 1.5 h uniformly in the Summer-25 file |
| Class/Week | 2 uniformly in the Summer-25 file — **misleading; do not trust it** |

**Derived rule (verified against the official Summer-2025 published routine):**

```
weekly_occurrences(offering) = ceil( sum(No. Of Classes over all teacher rows) / weeks_in_term )
```

with `weeks_in_term = 14` for Summer-2025. Evidence:

| Total No. Of Classes | Derived | Official routine actually shows |
|---|---|---|
| 28 (3.0 cr theory, 1.5 cr lab) | 2/week | 2 slots ✔ |
| 19 (2.0 cr, 1.0 cr) | 2/week | 2 slots ✔ (usually a **consecutive double** on one day) |
| 38 (CSE-4116, 2.0 cr) | 3/week | **3 slots** (Sun P1, Mon P1, Tue P4) ✔ |

`weeks_in_term` must become **configuration**, not a literal. `Credit` should be validated
against `No. Of Classes` and a mismatch reported, rather than either being ignored.

## P0.3 — Team-taught / split offerings share slots ✅ FIXED (commit 23a6b03)

**Was a confirmed defect; keep the rule.** When a cohort's course is split between two teachers, the workbook
carries **two rows** whose `No. Of Classes` sum to the full term total (14+14=28, or 9+10=19).
The published routine gives that course its **normal weekly slots with ONE teacher shown** —
the second row is an administrative record of who teaches which half of the term, *not*
extra timetable slots.

`ingest.py` used to treat each row independently and emit 2 sessions per row, so a split
offering got **4 weekly slots instead of 2**.

Measured on `Main_Distribution_Summer25.xlsx`:
- 356 offerings ingested, 686 sessions emitted.
- **18 offerings are taught by 2 teachers** → **36 phantom weekly classes**.
- Affected: `66-D CSE-1101/1102`, `64-A/B CSE-2111/2112`, `62-F/G/H/I CSE-3121`,
  `60-A…E CSE-4113`, `58-B+C CSE-4233/4234`, `BuA-GED-A GED-1122`.
- Ground truth check: official routine shows `64-A CSE-2111` on Thu P5 + Sat P1, teacher
  **DCP only** — the ABM row adds nothing.

The fix is at the **offering** level, not the row level: `ingest.py` groups distribution
rows by `(cohort, course_code)`, sums `No. Of Classes`, derives the weekly occurrence count
once, and carries the co-teachers on the session. Never fix this by de-duplicating output
rows.

**The first row in sheet order owns the printed slot** — verified against the published
routine for every case checked (`64-A CSE-2111`→DCP, `66-D CSE-1101`→PRP,
`60-A CSE-4113`→ZMM). Co-teachers are still held free at that time, because they take the
same slot in the second half of the term; the solver's teacher-clash and day-off constraints
apply to **every** teacher on `session["teachers"]`, not just the printed one.

## P0.4 — Post-generation validation layer (build this)

`solver.py::_validate()` today checks clashes, day-offs, Friday-P4, lab rooms, TBA rooms,
and `offerings_not_twice`. That last check **bakes in the wrong "2" assumption** and must be
replaced. A proper validator compares **Distribution → Generated Routine** and reports:

| Check | Failure condition |
|---|---|
| **Course completeness** | any required offering absent from the routine |
| **Unexpected courses** | routine contains an offering not in the distribution |
| **Duplicates** | more sessions for an offering than its derived requirement |
| **Session/credit allocation** | scheduled weekly sessions ≠ derived requirement |
| **Section/cohort validity** | routine cohort not present in the distribution |
| **Teacher conflicts** | same teacher, two places, same (day, period) |
| **Cohort conflicts** | same batch+section double-booked |
| **Room conflicts** | same room double-booked |
| **Room-type validity** | a lab scheduled into a non-lab room |
| **Unassigned rooms** | any `TBA` room |
| **Time-slot validity** | any session outside the configured period set / working days |
| **Rule violations** | teacher day-off used; no-class-period rule broken |
| **Traceability** | for every failure: course, cohort, teacher, constraint, attempted slots |

The validation result must be **exposed to the admin before publish**, and a routine that
fails course-completeness or credit-allocation **must not be publishable** without an
explicit, logged override.

## P0.5 — Engine defect register

Each is a root-cause item — fix the cause, not the output. Fixed rows stay here so the
behaviour is not "simplified" back later; the tests named are the ones that would break.

| # | Severity | Status | Defect | Location |
|---|---|---|---|---|
| 1 | Critical | ✅ 23a6b03 | Split/team-taught offerings produced double the required weekly slots (36 phantom classes in Summer-25) | `ingest.py` — was a per-row `for occ in (1, 2)`; now grouped per offering. `test_ingest.py::test_split_teacher_rows_collapse_into_one_offering` |
| 2 | Critical | ✅ 23a6b03 | Weekly occurrence count hard-coded to 2; `No. Of Classes` ignored. `CSE-4116` needs 3/week, got 2 | `ingest.derive_required_sessions`. `test_ingest.py::test_required_sessions_follow_the_class_count` |
| 3 | Critical | ✅ 23a6b03 | No Distribution→Routine completeness validation at all | `solver.py::_validate` now reconciles both ways; `offerings_not_twice` is gone. `test_solver.py` validation group |
| 4 | High | ✅ 23a6b03 | Rows with a blank Teacher were silently excluded (13 in Summer-25: `CSE-3240`, `CSE-4140`, `CSE-4801` — project/thesis; plus `ACM-1000/2000` with no batch) | `ingest.py` — typed `EXCLUDE_*` reasons + `detail`, surfaced in `report.excluded` |
| 5 | High | ✅ 23a6b03 | Period 7 (the 19:00 "OL Class" slot, real in the published routine) was dropped by `int(p["idx"]) <= 6` | now `online_periods` + `allow_online_periods` in config; default reproduces the old behaviour |
| 6 | High | ✅ 23a6b03 | `friday_no_p4` was a hard-coded, named, single-purpose rule | generalized to `blocked_periods {day: [idx]}`; the legacy flag is still folded in |
| 7 | High | ⚠️ partial | `semester_for(batch) = max_batch - batch + 1` assumes one batch per term — wrong under tri-semester | `semester_map` config now overrides it, but there is **no admin UI for the map yet** and the fallback is unchanged |
| 8 | Medium | ❌ open | `different_days` penalty applies to every offering, but the real routine deliberately places low-credit courses as **consecutive doubles on one day** (`58-B+C CSE-4233` Tue P4+P5). Should be occurrence-count-aware | `solver.py` |
| 9 | Medium | ❌ open | Renderer is bound to a fixed 55-row template and to spreadsheet column letters (`period.col`) carried inside the engine config — layout leaking into the data model. This is why the settings screen caps the grid at 7 periods | `render.py`, `config.json` |
| 10 | Medium | ❌ open | Room assignment is greedy first-fit with no capacity awareness; `No. Of Students` is parsed but unused | `solver.py::_assign_rooms` |
| 11 | Low | ❌ open | Job state is an in-memory dict on a free Render dyno — jobs vanish on sleep/restart mid-generation | `main.py::JOBS` |

### Verified result on the real Summer-2025 distribution
356 rows → **325 offerings** → **656 sessions** (was 686: −36 phantom, +6 for `CSE-4116`).
Solves with `missing_courses 0 · under/over_scheduled 0 · unexpected 0 · all clashes 0 ·
178/178 lab-theory pairs adjacent · ok: true`.

## P0.6 — Current pipeline (preserve this shape; fix inside it)

```
Admin picks Main Distribution .xlsx  +  app loads DB config
   → POST multipart {file, config(JSON), time_limit_s}
   → ingest.py   parse "Course Distribution" sheet (header-text binding, even-digit lab
                 rule, exclude blank-teacher and blank-batch rows, detect service/non-CSE)
   → solver.py   PHASE 1 CP-SAT: assign (day, period). HARD: each session once; no
                 teacher/cohort/room double-book; teacher day-offs; Friday no-P4;
                 room-count ≤ pool; theory↔lab adjacency (`lab_adjacency: hard|soft`).
                 SOFT: a course's sessions on different days; cohort compactness; avoid
                 last period. PHASE 2 greedy room assign (labs→lab rooms, theory→theory/
                 galleries). Self-validates. Service/non-CSE = resource-only (hold
                 teacher+room time, not rendered).
   → render.py   clone templates/CSE_Routine_TEMPLATE.xlsx, write ONE canonical 55-row
                 cohort map to all 7 day-sheets, cells "CODE TEACHER ROOM"
   → app polls status → report + validation + grid → Download .xlsx / Publish
```

### HTTP contract (`engine/main.py`)
- `POST /api/timetable/generate` — multipart: `file` (.xlsx), `config` (JSON string),
  `time_limit_s` (default 60) → `{job_id}`. Background thread, in-memory job dict.
- `GET /api/timetable/status/{job_id}` → `{state, progress, [stats, validation, error]}`;
  state: queued→ingesting→solving→rendering→done|failed.
- `GET /api/timetable/result/{job_id}` → `{rows, stats, validation, report}`.
- `GET /api/timetable/download/{job_id}` → the rendered `.xlsx`.

### Engine files (`engine/`)
`main.py` (API) · `solver.py` (CP-SAT + greedy + validation; `SOLVER_WORKERS` env) ·
`ingest.py` (xlsx parser) · `render.py` (workbook writer) · `config.json` (fallback config) ·
`templates/CSE_Routine_TEMPLATE.xlsx` (PII-stripped) · `tools/seed_config.py` (regenerates
`config.json` + seed SQL from raw workbooks) · `requirements.txt` · `Procfile` ·
`runtime.txt` / `.python-version` (3.12.7).
Gitignored: `.venv/`, `__pycache__/`, `routine generation files/` (PII), output `.xlsx`.

**Live:** `https://universe-timetable-engine.onrender.com` · Render free tier, deployed from
`main` via root `render.yaml`. Env: `PYTHON_VERSION=3.12.7`, `SOLVER_WORKERS=2`. Free tier
sleeps after ~15 min → first request ~50 s cold start. Pre-warm before a demo.

### Flutter side (`lib/features/admin/`)
- Services: `timetable_engine_service.dart` (HTTP + upload-to-bucket + publish + record run),
  `timetable_config_service.dart` (config CRUD + `buildEngineConfig()`).
- Controllers: `timetable_gen_controller.dart`, `timetable_rooms/faculty/settings_controller.dart`,
  `routine_upload_controller.dart`.
- Screens: `generate_timetable_screen.dart`, `manage_rooms/faculty_screen.dart`,
  `timetable_settings_screen.dart`, `timetable_grid_screen.dart`, `upload_routine_screen.dart`.
- Local run override: `--dart-define=TIMETABLE_BASE_URL=http://10.0.2.2:8000` (emulator).
  `android/app/src/main/res/xml/network_security_config.xml` permits cleartext to
  10.0.2.2/localhost only.
- Real-data sanity (Summer 2025): 356 offerings → 654 CSE + 32 service sessions, 55 cohorts,
  76 teachers, solves clash-free — **but with the 36 phantom classes from defect #1.**

---

# ═══ P1 — ROUTINE REPLACEMENT & DATABASE STATE ✅ FIXED (commit 116269c) ═══

## The defect (kept here so it is not reintroduced)

`TimetableEngineService.publishToRoutines()` used to be:

```dart
final batches = rows.map((r) => r.batch).toSet();   // batches in the NEW routine only
for (final batch in batches) { delete().eq('batch', batch); }
await insert(payload);
```

It deletes only the batches **present in the incoming payload**. Consequences:

| Problem | Effect |
|---|---|
| **Stale batches survive** | Routine A had batch 58; Routine B doesn't → batch-58 classes from A remain active forever. Users see **A + B merged**. |
| **Not atomic** | Delete-loop then insert, no transaction. A failure between them leaves the DB **partially cleared** — students see an empty or half routine. |
| **Cancellations cascade-deleted** | `cancellations.routine_id → routines(id) ON DELETE CASCADE`. Every republish **silently wipes all cancellation history**, while the `class_cancel` notifications stay — students keep an alert for a class that is no longer marked cancelled. |
| **Service rows never published** | Only `rows` are published, not `service_rows`. GED/non-CSE classes hold real teacher+room time, so **Find Teacher and Room Availability report those rooms free and those teachers idle.** |
| **No routine identity** | `routines` has no `routine_id` / term / version / publish-batch column. `is_active` exists but is always `true` and is never used to deactivate anything. |
| **Unbounded growth** | Nothing is ever archived. |

Both producers (engine publish **and** Upload Routine) call this same method, so one correct
fix covers both.

## Required behavior

1. Identify the currently active routine.
2. Deactivate/remove **all** rows belonging to it — not just colliding ones.
3. Insert the new routine.
4. Mark the new routine active.
5. The UI must read only the active routine.

## How it works now (migration 011) — do not route around this

- **`routine_versions`** — one row per published routine (`semester_label`, `source`
  engine|upload|manual, `is_active`, `row_count`, `stats`, `validation`, `published_by`).
  A **partial unique index** `where is_active` makes "exactly one active routine" a database
  guarantee, not a convention.
- **`routines.routine_version_id`** (FK, cascade) + **`routines.is_service`** + lookup
  indexes on `(batch, section, day)` and `(teacher_code, day)`.
- **`publish_routine(p_rows, p_semester_label, p_source, p_stats, p_validation, p_notes)`**
  RPC — admin-only, `security invoker`, one transaction: insert version → deactivate the old
  one → `delete from routines` (**all** of it) → insert the new rows → flip active. Returns
  `{version_id, row_count}`. It **refuses an empty payload** rather than wiping the routine.
- `routines` holds only the **active** routine, so republishing does not grow the table;
  history lives in `routine_versions` and `timetable_runs`.
- **`cancellations.routine_id` is now `ON DELETE SET NULL`**, not cascade. The row carries
  its own `batch/section/subject/day/time_start/class_date`, so cancellation history
  survives a republish.
- **Service rows are published** (flagged `is_service`), so Room Availability and Find
  Teacher see the teacher/room time they occupy.

**Rules that follow:**
- Publishing a routine goes through `publishToRoutines()` → the RPC. Never insert into or
  delete from `routines` directly, and never re-add a per-batch delete.
- Both producers (engine generate, Upload Routine) share that one path — fix it once.
- An academically invalid routine is **not publishable**: `TimetableGenController
  .blockingValidationError` disables the button and names the offending courses.

### Still open in this area
- Stale `SharedPreferences` notification-dismiss sets (`dismissed_notifs_<uid>`) can point at
  deleted rows after a republish — harmless today, but unbounded.
- `class_cancel` notifications for a class that no longer exists are not reconciled.
- Nothing yet **reads** `routine_versions` in the UI (no "active routine / published at"
  banner on the admin Routine hub). `fetchActiveVersion()` exists for it.

---

# ═══ P2 — DISTRIBUTION FILE ANALYSIS & NORMALIZATION ═══

**Do not delete or "clean" anything in the distribution file on your own initiative.**
Analyze, classify, **report to Fahmid**, and let him decide.

## What the workbook actually contains

`Main_Distribution_Summer25.xlsx` — 14 sheets:
`Course Distribution` (the only one the engine reads), `Distribution_Stats`, `Routine_Stats`,
`Sunday`…`Saturday`, `Weekdays`, `Weekend`, `Teachers`, `Instructions`.

`Course Distribution`: titles in rows 1–4, **header row 5**, data from **row 6**,
~531 rows × 26 columns (cols 13–26 empty). 358 data rows → 356 usable offerings.

Field classification (initial pass — confirm with Fahmid before acting):

| Class | Fields |
|---|---|
| **Authoritative / required** | Batch, Section, Course Code, Teacher, No. Of Classes |
| **Authoritative / should be used but currently isn't** | Credit, Conducting Department, No. Of Students |
| **Display** | Course Title |
| **Metadata / not scheduling input** | Prerequisite |
| **Suspicious — verify, don't assume** | Class/Week (constant `2` everywhere; contradicts No. Of Classes), Class Duration (constant `1.5`) |
| **Formatting artifacts** | rows 1–4 banners, empty cols 13–26, mixed int/float typing (`66.0` vs `66`, `28` vs `14.0`) indicating hand-edits vs formulas |
| **Layout-only markers in the rendered routine** | `B` / `R` cells in the break column; the `OL Class 7:00pm-8:20pm` column |

Note the ordering artifact: rows ~346–363 are a **later-appended block** of second-teacher
assignments for already-listed offerings. Position in the sheet carries meaning that no
parser should depend on — another reason to normalize.

## Required architecture

```
Raw Distribution workbook  →  Normalized Academic Data  →  Timetable Engine
      (messy, changes)          (typed, validated,           (pure scheduling;
                                 spreadsheet-agnostic)        no xlsx knowledge)
```

The normalized layer is the contract. It should carry typed offerings —
`(term, cohort{batch, section}, course{code, title, credit, dept}, teachers[],
required_sessions, session_duration, is_lab, is_service, exclusion_reason?)` — and be
independently testable from JSON fixtures with **no** Excel dependency. The solver must not
know that a spreadsheet exists. Parsing failures and ambiguities are reported by this layer,
loudly, with row numbers.

Keep header-**text** binding (never fixed column indexes) so column reordering is survivable.

---

# ═══ P3 — CONFIGURATION, NOT CONSTANTS ═══

The university changes class timings between **summer and winter**, and may change working
days, breaks and term structure. **None of this may live in code.**

Target flow: **Admin UI → stored configuration (`timetable_*` tables) → engine reads it.**
Changing summer/winter timings must require **no backend edit and no new APK**.

## P3.1 — Class periods ✅ EDITABLE (commit pending, migration 010)

`timetable_settings_screen.dart` now edits the whole grid: add/remove periods, start and end
times, which days each period is **not** taught, and whether it is an online/reserve slot.
Term length (`weeks_in_term`) and working days are on the same screen. Saving validates via
`TimetableSettings.validatePeriods()` (non-empty, parseable, ordered, non-overlapping, unique
indices) before the row reaches Postgres.

Admin-editable today:
- academic term / session label · solver weights · service scope
- period list: index, start, end (label derived)
- working days (which of Sun–Sat are taught)
- per-day disabled periods — generalizes the hard-coded `friday_no_p4`
- online / reserve periods + a switch to let the solver use them (was `idx <= 6`)
- `weeks_in_term` — the credit→sessions divisor (was an implicit 14)

Still not editable:
- **breaks** — still an implicit gap that `render.py` computes between consecutive periods
- **`semester_map`** — stored and honoured by the engine, but no UI (defect #7)

Rules:
- Every period boundary passes through `ClockTime`. `HH:MM:SS` → Postgres, `HH:MM` → engine.
- The grid is capped at **7 periods** because `render.py` places each one by a spreadsheet
  column letter (`period.col`) into a fixed template. That coupling is engine defect #9;
  raise the cap only by fixing the renderer, not by widening the constant.
- Saving must keep going through `TimetableSettings.validatePeriods()`.

## P3.2 — Academic term structure (bi-semester / tri-semester)

The university may run **2 or 3 terms per year**. Do not hard-code any term count, and do not
assume "semester 1 + semester 2 = one academic year".

Current assumptions that break this — all must be generalized:
- `solver.py::_assign_rooms::semester_for()` = `max_batch - batch + 1`, clamped to 8.
  This assumes **exactly one new batch per term** and that batch numbers count down by one
  per term. Under tri-semester it silently mislabels the `semester` on every published row.
- `routines.semester` is an `int` with no term context.
- Nothing anywhere records which academic term a routine belongs to.

Target conceptual model (configurable, not hard-coded):

```
Academic Year → Academic Term (2 | 3 | n per year) → Department/Program
              → Batch/Cohort → Courses → Sections → Routine (versioned, per term)
```

The scheduling algorithm itself is term-agnostic — it schedules one term's offerings at a
time. The generalization work is in the **data model and labelling**, not in CP-SAT. Prefer
storing the term explicitly and deriving `semester` from a batch↔term mapping table rather
than from arithmetic on batch numbers.

---

# ═══ P4 — TIMETABLE TESTING (required before the engine is "done") ═══

Run: `flutter test` (Dart side) · `pytest` / direct module runs (engine side).
Existing: `test/clock_time_test.dart` (AM/PM normalization rules).

Build fixtures from the real workbook with **PII stripped**, committed under
`engine/fixtures/`. Never commit the raw workbook.

Minimum coverage:

| Area | Test |
|---|---|
| **Course completeness** | every distribution offering appears in the routine |
| **Credit compliance** | scheduled sessions == derived requirement for every offering |
| **Split offerings** | a 2-teacher offering yields the single-offering session count, not double |
| **Variable occurrences** | 19 → 2/week, 28 → 2/week, 38 → 3/week |
| **No duplicates** | no offering exceeds its requirement |
| **No collisions** | teacher / room / cohort double-booking detected |
| **Time validity** | every session falls in a configured period on a working day |
| **Rule compliance** | teacher day-offs honoured; per-day disabled periods honoured |
| **Lab rules** | labs land in lab rooms; theory↔lab adjacency holds when `hard` |
| **Distribution consistency** | Distribution ↔ Generated Routine diff is empty |
| **Replacement** | publish A then B ⇒ only B is active; **zero** A rows remain |
| **Atomicity** | a failed publish leaves the previous routine intact |
| **Config change** | editing periods (summer→winter) changes generated times, no code change |
| **Term structure** | 2-term and 3-term configurations both produce correct labelling |
| **Invalid input** | malformed/missing columns produce a clear, row-numbered error |
| **Infeasibility** | an over-constrained teacher produces a message naming the teacher and the binding constraint — never a bare `INFEASIBLE` |

A visually valid routine is not a passing test.

---

# ═══ P5 — AUTHENTICATION / OAUTH ═══

OAuth is currently unreliable. **Root-cause it. Never weaken security to make it appear to
work** (no disabling PKCE, no long-lived tokens, no client-side secrets, no skipping the
admin whitelist gate).

## Current implementation
- **Google OAuth** via `supabase.auth.signInWithOAuth(OAuthProvider.google, redirectTo:
  'com.example.universe://login-callback/', authScreenLaunchMode:
  LaunchMode.externalApplication)` — i.e. an **external-browser redirect flow**, returning
  through an Android deep link. `AuthFlowType.pkce` is set in `Supabase.initialize`.
- **Email/Password** signup → email verify → signin.
- **Whitelist gate = ADMIN ONLY.** Students/teachers sign up freely; admins must exist in
  `whitelists`. Enforced in `auth_service.handlePostLogin()`; a non-whitelisted admin is
  signed out → `NotWhitelistedScreen`.
- `AuthStatus`: `initial · loading · authenticated · unauthenticated · registering ·
  notWhitelisted · awaitingVerification · error`.
- Deep links: `com.example.universe://login-callback/` and `://reset-callback/`, declared in
  `AndroidManifest.xml` (`launchMode="singleTop"`, `taskAffinity=""`).
- Admin provisioning via the **`invite-admin` Edge Function** (holds the service-role key).
- On sign-in `PushService.registerToken(userId)`; on sign-out the FCM token is deleted
  **before** the session drops (deleting after would run as anon and leave a stale row).

## Findings to investigate first (do not assume; verify each)
1. **The browser-redirect flow is the prime suspect.** The `google_sign_in` package is a
   declared dependency but is **never used** — `GoogleSignInButton` is a local UI widget
   only. Native Google Sign-In + `supabase.auth.signInWithIdToken()` avoids browser hand-off,
   app-switch loss, and the "returns to a dead screen" class of failure. Evaluate migrating.
2. **Deep-link redelivery.** Nothing in `main.dart` handles incoming links explicitly —
   the app relies entirely on `supabase_flutter`'s internal handler. Confirm cold-start vs
   warm-start callback behavior, and behavior when the browser is a custom tab vs a full
   browser.
3. **Scheme is tied to `applicationId`.** `com.example.universe` must change before Play
   Store release (§P9); that change breaks the OAuth deep link **and** the Firebase
   package binding at the same time. Plan them as one coordinated change.
4. **Dead code.** `lib/features/auth/controllers/auth_controller.dart` is 1017 lines of
   which **479 are commented-out** — two complete superseded copies of `AuthController`
   before the live class at line 599. Delete them; they make the real flow unreadable and
   hide which code path actually runs.
5. `AuthController extends ChangeNotifier`, not `SafeChangeNotifier` — check for
   notify-after-dispose during sign-out navigation.

## Audit checklist
login · OAuth callback · session creation · session persistence across cold start ·
token refresh · expiry handling · logout completeness (tokens, cached role, push token,
dismissed-notification prefs) · account linking (same email via Google and password) ·
unauthorized access · admin authorization · error surfaces (never a silent failure).

---

# ═══ P6 — SECURITY ═══

Treat this as a real production system handling student and faculty data, not a demo.

**Rules:**
- **Never** place secrets in source. The service-role key lives **only** in Edge Function
  secrets. Nothing privileged reaches the client.
- The Supabase **anon key is safe to ship**; RLS is what protects data. Every table must
  have RLS on with correct policies — verify, don't assume.
- **Least privilege.** The current blanket pattern `read_all` (SELECT using true) +
  `admin_write` is convenient but over-permissive for personal data: audit `profiles`,
  `device_tokens`, `whitelists`, `submissions` specifically. A student should not be able
  to read every other student's profile row.
- Server-side authorization for anything privileged — never trust a client-side role check
  alone. The admin whitelist gate must hold at the DB/policy layer too.
- Validate and constrain **file uploads**: type, size, path, and who may write to
  `resources` / `avatars` / `assignments` / `timetables`.
- Use parameterized queries / the Supabase client — no string-built SQL. Review every RPC
  and Edge Function for injection and for IDOR (object ids taken from the client).
- **Never log** tokens, emails, phone numbers, or FCM tokens. Teacher PII from distribution
  workbooks must never be logged or committed.
- Review Edge Functions for auth checks on every entry point (`invite-admin` especially —
  it holds the service-role key).
- Keep the debug-signing / `com.example` issues in §P9 on the security list: a debug-signed
  release APK is not a production artifact.

---

# ═══ P7 — APPLICATION ISSUE BACKLOG ═══

Maintain a prioritized list. Investigate before changing. Fix causes, not symptoms.

**Order:** 1 Critical functionality/data → 2 Timetable correctness → 3 Auth/OAuth →
4 Security → 5 Database consistency → 6 Performance → 7 UX/UI → 8 Nice-to-have.

Look for: broken functionality · inconsistent state · race conditions · poor error handling ·
missing loading/empty states · validation gaps · stale cache · redundant API calls ·
performance bottlenecks · permission problems · admin/user separation.

### Known open items (carry these into the list)

| Severity | Item |
|---|---|
| High | `find_teacher` + `rooms` controllers extend plain `ChangeNotifier`, not `SafeChangeNotifier`, **and** never cancel their `streamAllRoutines().listen(...)` subscription → a Realtime event after the screen is popped notifies a disposed notifier |
| High | Those list screens ignore `cancellations` — a cancelled class still shows the teacher "In Class" and the room occupied (the **detail** screens ignore cancellations deliberately; the **list** screens should not) |
| Medium | `subscribeToRealTimeUpdates()` assigns the streamed rows then immediately re-fetches over the network, discarding the payload it was just handed |
| Medium | Both duplicate a local `['Sunday', …]` list instead of using `AppConstants.weekDays` |
| Medium | ~590 lines of dead commented `AuthController` code (see §P5) |
| Medium | Existing `routines` rows published before the AM/PM fix still hold wrong times — the write path is fixed, the data is not. Re-upload or re-generate. |
| Low | `timetable_settings.periods` editable only via SQL (see §P3.1) |

### Unmerged branches — resolve before large engine work
- `engine/theory-lab-adjacency` (commit `4e07ee0`, ~5.4k insertions): migration 010
  (`timetable_rooms.dept`, `timetable_faculty.courses`, `timetable_courses` catalog with
  `assigned_teacher` overrides), dept-aware lab-room routing, admin teacher overrides at
  ingest, Course Assignments UI, `SELF_SERVICE_GUIDE.md`, doc pass. **It rewrites
  `ingest.py`, `solver.py`, `render.py`** — merge or drop it *before* rewriting the engine,
  or the conflict will be brutal.
- `fix/push-permission-double-request`: single push-permission request, Firebase rebound to
  `com.example.universe`, AGP 8.11.1 / Kotlin 2.2.20, back-button fix.

---

# ═══ P8 — UNIVERSITY WEBSITE / API INTEGRATION (future) ═══

Before writing any integration code:
1. Determine whether an **official/public API** exists. Read their terms.
2. Identify authentication, authorization, and rate limits.
3. Determine what data may **legally and technically** be accessed.
4. **Never bypass** authentication, access controls, rate limits, or other protections.
   No scraping around a login. If there is no sanctioned access path, stop and report.

Architecture: isolate every external call behind a service-layer abstraction
(`lib/features/<x>/services/university_*_service.dart`) with a typed domain model of *our*
shape, never theirs. Treat the dependency as **unreliable by default**:

timeouts · bounded retries with backoff (idempotent reads only) · explicit error types ·
caching with a stated TTL · rate-limit awareness · structured logging (no PII, no tokens) ·
**graceful degradation** — a university API outage must never break an unrelated screen.

---

# ═══ P9 — APP UPDATE STRATEGY ═══

Users must learn about new versions without hand-delivered APKs. **Do not build a custom
APK download/replace mechanism** — it is unsafe and blocked on modern Android.

Separate the three update channels:

| Channel | Mechanism |
|---|---|
| **Backend** | Engine deploys from `main` → Render, automatic. Supabase migrations + Edge Functions deploy independently. Already decoupled from the APK. |
| **Configuration / content** | Anything in `timetable_*`, `resources`, `notifications` is remote already. **Push as much university-specific behavior here as possible** (§P3) so fewer changes need a build. |
| **Application code** | Requires a new build. Distribute through **Google Play** (in-app updates via the Play Core API give flexible + immediate update flows for free). |

Required, in order:
1. **Fix the release blockers first:** `applicationId` is `com.example.universe` (Play
   rejects `com.example.*`) and the release APK uses **debug signing** (no keystore).
   Changing the applicationId also requires a new Firebase Android app + regenerated
   `google-services.json` + `firebase_options.dart`, and updated OAuth deep-link scheme
   and Supabase redirect allow-list. Plan it as one coordinated change.
2. Version metadata endpoint or table (min supported version, latest version, release notes).
3. In-app version check on launch → non-blocking update prompt.
4. Optional **mandatory** update for critical releases (hard gate when below min version).
5. Graceful handling when an outdated client hits a changed backend contract.

---

## CURRENT STATUS (what exists)

| Area | State |
|---|---|
| Auth (Google OAuth + email/password, whitelist gate for admin) | ⚠️ built, **unreliable — see §P5** |
| Role-aware tab navigation (AppShell + bottom nav) | ✅ |
| Student / Teacher routine views | ✅ |
| Student + Teacher dashboards (live/next-class hero, countdown, stats, today's list) | ✅ |
| Teacher Manage Classes — cancel occurrence (+alert/push) · notice/room-change · undo | ✅ |
| Resources hub — semester folders, admin upload (file / Drive link) | ✅ |
| Notifications (Realtime feed + per-user local multi-select dismiss) · Profile | ✅ |
| Admin: dashboard, Routine hub (Manage / Generate / Upload), broadcast, registration, users, Manage Resources | ✅ |
| Push (FCM) — `send-push` Edge Function deployed, DB webhook on `notifications` INSERT | ✅ |
| Auto-notify: resource upload → students · routine publish → everyone | ✅ |
| **Timetable engine (Excel→CP-SAT→workbook) + admin config + publish** | ✅ distribution is a hard constraint; sessions derived from credits; validated against the distribution — open items in §P0.5 |
| **Routine publish/replace** | ✅ atomic full replacement via `publish_routine` RPC (migration 011) |
| Find Teacher — real-time teacher locator | ⚠️ built, ignores cancellations |
| Room Availability — real-time room occupancy | ⚠️ built; service rows are now published, but it still ignores `cancellations` |
| Room / Teacher weekly detail (`weekly_schedule_view.dart`) | ✅ (cancellations deliberately not applied) |
| Explore FAB · App drawer (all three dashboards) | ✅ |
| Admin Upload Routine (rendered workbook → `routines`) | ✅ (shares the fixed publish path) |
| Automated tests | ⚠️ 47 engine (pytest) + 22 Dart. No widget/integration tests; the publish RPC is untested |
| Play Store readiness | ❌ `com.example` id + debug signing |
| AI assistant (RAG/Gemini) | ⛔ descoped → future scope |

---

## TEAM ROLES — FEATURE-BASED OWNERSHIP

> Vertical slices: screen + controller + service. Shared infrastructure (`core/`,
> `shared/widgets/`, `main.dart`, `pubspec.yaml`, `AndroidManifest.xml`, `engine/`)
> = **Fahmid only**.

- **Fahmid Alam** (0182320012101309) — architecture, shared infra, auth, **admin + timetable
  engine** (`lib/features/admin/`, `engine/`), `lib/core/`, `lib/shared/widgets/`, build/deploy.
- **Swadheen Islam Robi** (0182320012101278) — `lib/features/routine/`, `resources/`,
  dashboards, teacher screens, `find_teacher/`, `rooms/`.
- **Shahriar Rashid Ratul** (0182320012101276) — `notifications/`, `profile/`, push, QA,
  seeding, README/screenshots.

**Conflict-free rule:** changes outside your feature folder → PR + tag Fahmid. Never directly
edit `app_router.dart`, `route_names.dart`, `app_constants.dart`, `pubspec.yaml`,
`app_shell.dart`.

---

## TECH STACK (see `pubspec.yaml`)

```
Dart SDK: >=3.0.0 <4.0.0   (toolchain: Flutter 3.44.9 / Dart 3.12.2)
supabase_flutter: ^2.12.4      go_router: ^17.2.3
google_sign_in: ^6.2.1  ⚠️ declared but UNUSED (see §P5)
google_fonts: ^8.1.0           phosphor_flutter: REMOVED — see note below
archive: ^4.0.9                xml: ^6.6.1        (Upload Routine .xlsx parsing)
hive_flutter: ^1.1.0           flutter_local_notifications: ^17.2.2
firebase_core: ^4.10.0         firebase_messaging: ^16.3.0
file_picker: ^8.1.2            flutter_pdfview: ^1.3.2
cached_network_image: ^3.3.1   http: ^1.6.0
shared_preferences: ^2.5.5     path_provider: ^2.1.4   open_filex: ^4.5.0
url_launcher: ^6.3.2           flutter_launcher_icons: ^0.14.4 (dev)
```

> ⚠️ **Icons: `phosphor_flutter` is NOT installed.** It is commented out in `pubspec.yaml`
> and replaced by a Material-Icons shim, `lib/shared/widgets/utils/phosphor_compat.dart`
> (re-exported from `lib/shared/utils/phosphor_compat.dart`, which every screen imports). It
> exposes `PhosphorIcons` / `PhosphorIconsRegular` with the same member names, so existing
> code compiles unchanged — but the app renders **Material** icons. **Adding a new icon means
> adding a member to the shim.** To restore real Phosphor: un-comment the dep at a
> Dart-3.12-compatible version, repoint the two `phosphor_compat.dart` files, delete the shim.

### Backend / services
- **Supabase** (project ref `yxqyrjyzxitrgkhgauli`) — Postgres + Auth + Storage + Realtime.
- **Firebase** — Cloud Messaging only (Android), via `firebase_options.dart` +
  `android/app/google-services.json`.
- **Timetable engine** — FastAPI + OR-Tools CP-SAT on Render free tier.
- **Google OAuth** — via Supabase Auth, PKCE, external-browser redirect.

### Build environment
- Gradle wrapper **8.14** (required for JDK 24). AGP **8.9.1**, Kotlin **2.1.0**,
  `com.google.gms.google-services` **4.4.2**.
- Release APK uses **debug signing** — sideloadable only, **not shippable** (§P9).
- Build: `flutter build apk --release` → `build/app/outputs/flutter-apk/app-release.apk`.
- **App icon:** `flutter_launcher_icons` (config in `pubspec.yaml`). Sources in
  `assets/icon/` generated by `python tool/generate_app_icon.py`. Regenerate:
  `dart run flutter_launcher_icons`.

### Auth deep links
```
com.example.universe://login-callback/   ← Google OAuth + email verify
com.example.universe://reset-callback/   ← password reset
```

---

## DESIGN SYSTEM

> All tokens in `lib/core/theme/`. **Never hardcode hex or raw numbers in widgets.**

### Colors (`app_colors.dart`)
```
bgPrimary #0F0F10 · bgCard #1A1A1C · bgElevated #222325 · bgSubtle #1C1C1E
primary #FF7A00 · primaryDark #E66A00 · primarySoft #2A1A0A · primaryMuted #3D2000
textPrimary #FFFFFF · textSecondary #B0B3B8 · textMuted #6E7278 · textDisabled #4A4D52
border #2A2C30 · borderFocus #FF7A00 · borderError #EF4444 · navBg #111113
success #22C55E/successSoft #0D2E1A · info #3B82F6/infoSoft #0D1F3C
warning #F59E0B/warningSoft #2D1E00 · error #EF4444/errorSoft #2D0D0D · done #6E7278
roleStudent / roleTeacher / roleAdmin accent colors also exist.
```

### Text styles (`app_text_styles.dart`)
`h1` 24/700 · `h2` 18/600 · `h3` 16/600 · `h4` 14/600 · `body` 14/400 · `bodyMedium` 14/500 ·
`bodySm` 13/400 · `bodySmMedium` 13/500 · `chip` 12/500 · `label` 12/500 · `labelCaps` 11/600
caps · `caption` 11/400 · `captionMedium` 11/500 · `badge` 10/700 · `button` 15/600 ·
`link` 13/500 · `danger` 14/500 · `input` · `placeholder` · `countdown` · `statNumber` ·
`onboardTitle`. Use `.copyWith()` for overrides.

### Spacing (`app_spacing.dart`)
`xs4 sm8 md12 lg16 xl20 xxl24 x3l32 x4l40 x5l48` · gaps `xsGap smGap smHGap cardGap mdGap
lgGap sectionGap` · radius objects `radiusSm/Md/Lg/Xl/Xxl/Full` + doubles
`radiusSmD..radiusXlD` · `buttonHeight52 inputHeight52 chipHeight34 appBarHeight56` ·
icons `iconSm16 iconMd20 iconLg24 iconXl32` · borders `borderThin0.5 ..Thick2`.

### Theme
`AppTheme.dark` → `MaterialApp.router(theme:)`. `AppTheme.setSystemUI()` in `main()`.
Font **Inter** via `GoogleFonts.interTextTheme()` (global — never set fontFamily).
Icons: always `PhosphorIconsRegular.*` from `package:universe/shared/utils/phosphor_compat.dart`.

---

## ARCHITECTURE

### Folder structure
```
lib/
  main.dart                       Firebase+Push init, Supabase init, router, deep links
  firebase_options.dart           generated (Android only)
  core/
    theme/  router/  constants/  models/  utils/  services/push_service.dart
  shared/widgets/                 u_* primitives + composite cards + explore_fab_menu.dart
  features/
    auth/  routine/  resources/  notifications/  profile/  admin/
    dashboard/     (student Home)
    teacher/       (teacher Home + Manage Classes)
    find_teacher/  (real-time teacher locator — secondary screen)
    rooms/         (real-time room availability — secondary screen)
engine/                           FastAPI + CP-SAT timetable engine (Python)
supabase/  migrations/  seed/  functions/
test/                             Dart tests
```

### Layer rules (enforced)
- Screen → controller → service → Supabase. Screens/controllers **never** touch Supabase.
- Each feature: `screens/ controllers/ services/`. Shared widgets only from `shared/widgets/`.
- State: **`ChangeNotifier` + `ListenableBuilder`** only (no Riverpod/Bloc/Provider).
  Screen-scoped controllers should extend **`SafeChangeNotifier`**. `setState` for local UI only.
- **Keep business logic separated:** raw parsing · normalization · generation · validation ·
  persistence · API · UI. This applies to the engine as much as to Dart.

### Navigation (GoRouter ^17 + ShellRoute)
- Single `AppRouter` in `main.dart`; `authController` is `refreshListenable`.
- **`AppShell`** (`core/router/app_shell.dart`) owns ONE Scaffold + bottom nav for all
  top-level tabs; tab screens render content only.
- **`AppBottomNav`** (`shared/widgets/app_bottom_nav.dart`) — single source of truth for each
  role's tabs (`destinationsFor(role)`). Notification badge wired to a shared
  `NotificationController`.
- **Secondary screens** (Resources, Admin Registration, Manage Rooms/Faculty, Timetable
  Settings, Timetable Grid, Manage Resources, Resource Library, Broadcast History, Find
  Teacher, Room Availability, Room/Teacher Detail) are **pushed**, not tabs.
- **`ExploreFabMenu`** — FAB on all three dashboards → bottom sheet with **Rooms** (`/rooms`)
  and **Find Teacher** (`/find-teacher`).
- **Admin "Routine" tab = `AdminRoutineScreen` hub** — segmented control hosting **Manage**
  (`RoutineManagementScreen`), **Generate** (`GenerateTimetableScreen`) and **Upload**
  (`UploadRoutineScreen`), all `embedded: true`. `?tab=generate` opens on the generator.
  There is NO standalone `generateTimetable` route.
- **`AppDrawer`** — right-side `endDrawer` opened by `UDrawerButton` in the top-right of all
  three dashboards. Every role opens with **Profile · Find Teacher · Room Availability**, then
  role-specific links, then Sign Out. `_destinationsFor(role)` mirrors `AppBottomNav`. The
  drawer lives on each **screen's** Scaffold while the Explore FAB lives on the **shell's**,
  so a shared `drawerOpenNotifier` (driven by `Scaffold.onEndDrawerChanged`) lets `AppShell`
  scale the FAB away while the drawer is open.
- Tab sets: **Student** Home·Routine·Alerts·Profile · **Teacher** Home·Routine·Classes·
  Alerts·Profile · **Admin** Dashboard·Broadcast·Routine·Users·Profile.
- All paths are `RouteNames.*` constants. Redirect logic lives only in `AppRouter.redirect()`.
- Routes: `rooms = '/rooms'` · `findTeacher = '/find-teacher'` · `roomDetail =
  '/rooms/detail'` (`extra` = room name) · `teacherDetail = '/find-teacher/detail'`
  (`extra` = `TeacherDetailArgs(code, name)`) · `teacherDirectory = '/teacher-directory'`
  (defined, not wired).

---

## SUPABASE SCHEMA (live)

| Table | Key detail |
|---|---|
| `whitelists` | admin gate; `role` ∈ student/teacher/admin |
| `profiles` | extends `auth.users`; created on first login |
| `routines` | weekly schedule; filtered by batch+section (student) or teacher_code (teacher). `teacher_name`/`teacher_code` are TEXT (003); `teacher_id` nullable. **011** adds `routine_version_id` + `is_service` + lookup indexes. Holds **only the active routine**. Written exclusively by `publish_routine()`. Also read by `FindTeacherService` + `RoomStatusService` |
| `cancellations` | (007) one dated row per cancelled occurrence: `routine_id, class_date, reason, batch, section, subject, day, time_start, cancelled_by` + unique `(routine_id, class_date)`. RLS: read-all; insert/delete by `cancelled_by = auth.uid()` & teacher/admin. `routine_id` is **ON DELETE SET NULL** since 011, so history survives a republish |
| `notifications` | typed (CHECK constraint); `notification_reads` tracks per-user read state |
| `resources` | files in the `resources` bucket + Drive links; browsed by semester folder + category; `uploaded_by` from session (RLS) |
| `assignments` / `submissions` | `submissions.is_late` set by a DB trigger — **never compute in Dart** |
| `documents` | RAG vector store (`VECTOR(768)`) — unused (AI descoped) |
| `device_tokens` | FCM tokens per device/user |
| `timetable_rooms` | engine room pool: `name, building, is_lab, is_gallery, is_active` (+ `dept` on the unmerged branch). RLS: 008 |
| `timetable_faculty` | `acronym, full_name, dept, designation, off_days text[], is_active` (off_days TRUE-semantics = unavailable). RLS: 008 |
| `timetable_settings` | single row (id=1): `semester_label, periods jsonb, friday_no_p4, service_scope, weights jsonb` + **010**: `working_days text[], weeks_in_term, blocked_periods, online_periods, allow_online_periods, excluded_periods, semester_map`. All editable from Timetable Settings except `semester_map`. RLS: 008 |
| `timetable_runs` | generation history: `semester_label, file_path, stats jsonb, validation jsonb, status, row_count, created_by`. RLS: 008 |

**RLS pattern (all tables):** `read_all` (SELECT using true) + `admin_write` (INSERT/… with
check: caller is admin in `profiles`). ⚠️ Over-permissive for personal data — see §P6.

**Storage buckets:** `avatars` · `resources` · `assignments` · `timetables`. All public
for the MVP — revisit under §P6.

**Migrations** (`supabase/migrations/`): 001 notification_reads · 002 drop profiles photo_url ·
003 routines teacher text · 004 device_tokens · 005 register_device_token · 006 RLS on all
tables (+ `my_role()`/`is_admin()`) · 007 cancellations schema · 008 RLS on `timetable_*` ·
009 drop unused objects · **010 timetable schedule config** (working_days, weeks_in_term,
blocked/online/excluded periods, semester_map) · **011 routine versions** (`routine_versions`,
`routines.routine_version_id`/`is_service`, `publish_routine()` RPC, cancellations FK relaxed).
*(The abandoned `engine/theory-lab-adjacency` branch also carries a 010 — it is **not** being
merged; do not renumber ours to accommodate it.)*

**Edge Functions** (`supabase/functions/`): `invite-admin` (service-role; admin provisioning) ·
`send-push` (FCM v1; triggered by the `notifications` INSERT webhook).

**Seeds** (`supabase/seed/`): `seed_timetable_config.sql` (rooms/faculty/settings generated
from the real workbooks), plus demo accounts/routine/resources/notifications/whitelist.

---

## PUSH NOTIFICATIONS (FCM)

- `main.dart` inits Firebase + `PushService.instance.init()` (mobile only).
- Local-notification channel id `pushChannelId = 'universe_high_importance'` **must match**
  AndroidManifest's `default_notification_channel_id`.
- Permissions: `INTERNET`, `POST_NOTIFICATIONS`. The `<queries>` block allows `https` VIEW
  intents so `url_launcher` can open resource links.
- **Data-only messages**: FCM *notification* messages are drawn by Android; **data-only
  messages are drawn by nobody**. Both handlers now fall back to `data['title']`/`data['body']`
  via `_contentOf()` + `_displayLocal()`; the background isolate initializes its own plugin +
  channel and returns early when a `notification` block is present (Android already drew it).
- **Net effect:** inserting a `notifications` row = in-app Realtime alert **+** OS push. Used
  by admin broadcast, teacher cancel/notice, resource upload, routine publish.
- ⚠️ **Unverified server-side links:** whether the DB Webhook on `notifications` INSERT is
  configured, and whether `FCM_SERVICE_ACCOUNT` is set. `send-push` IS deployed (a bare POST
  returns `"No record"`, not 404). Check Edge Functions → send-push → Logs.

---

## AI ASSISTANT — ⛔ DESCOPED (future scope)

Removed from UI: the student "AI" bottom-nav tab and the `/student/ai-assistant` route.
Kept for restore: `RouteNames.aiAssistant`, `shared/widgets/chat_bubble.dart`, the
`documents` table.

To restore: re-add the nav destination + GoRoute, build `lib/features/ai_assistant/`
(service+controller+chat screen), then run the `documents` hybrid-search migration (add
`namespace` + `content_tsv`, GIN index, rewrite `match_documents()` RPC) — and update every
`documents` INSERT in the same sitting. Do NOT run that migration before the service exists.

---

## HARD CONSTRAINTS — NEVER VIOLATE

**Timetable**
- The distribution is a hard constraint. A missing required course = failure, never a warning.
- Never hard-code weekly session counts. Derive them from the distribution + configured
  `weeks_in_term`.
- Never silently drop an offering. Classify, count, surface.
- The engine row shape ↔ `routines` columns ↔ `timetable_*` config ↔ `buildEngineConfig()` ↔
  engine `_normalize_config()` must move together.
- Publishing a routine replaces the previous routine **completely** and **atomically**.
- All clock text through `ClockTime` — `HH:MM:SS` to Postgres, `HH:MM` to the engine.
- University scheduling rules (periods, days, breaks, term count, weeks) live in
  configuration, never in code.

**Code**
- No hardcoded hex → `AppColors.*` · no raw spacing → `AppSpacing.*` · no raw `TextStyle()`
  → `AppTextStyles.*` (+ `.copyWith`).
- No conflict markers in a commit. Grep + `flutter analyze` before every merge commit.
- No `MaterialPageRoute` → `context.go/push` with `RouteNames.*`. No hardcoded route strings.
- No Supabase in screens/controllers → services only. `is_late` is a DB trigger.
- `ChangeNotifier` only (no Riverpod/Bloc/Provider); screen-scoped → `SafeChangeNotifier`.
- Icons `PhosphorIconsRegular.*` via `shared/utils/phosphor_compat.dart`. Font Inter (global).
  One theme: `AppTheme.dark`. App name "UniVerse".
- `DropdownButtonFormField`: use `initialValue:` (not deprecated `value:`).
- Shared infra (`app_router`, `route_names`, `app_constants`, `pubspec.yaml`, `main.dart`,
  `app_shell.dart`) → Fahmid only.
- Don't downgrade Gradle < 8.14. Don't commit secrets / PII workbooks / `dart_defines.json`.

---

## IMPORT CONVENTION
```dart
// Always package imports — never relative.
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/router/route_names.dart';
```

## GITHUB / BUILD
- `main` = integration + release branch (the engine deploys from it). Feature branches merge
  to `main`. The agent never pushes; Fahmid merges + rebuilds the APK.
- Commit format: `feat|fix|chore|refactor(module): description`.
- After a merge conflict, resolve **additively** — keep both features.
- Deploy: push `main` → Render auto-rebuilds the engine (same URL, no downtime).

## QUICK REFERENCE
- **Add screen:** file in `features/<f>/screens/` → `RouteNames` const → `GoRoute` in
  `app_router` (tab → inside `ShellRoute`; secondary → top-level).
- **Add table:** SQL migration + RLS → `app_constants` table const → service method.
- **Add widget:** `shared/widgets/`, import only theme tokens, config via constructor.
- **Change engine behavior:** edit `engine/*.py`, test locally
  (`uvicorn main:app --port 8000` + `--dart-define=TIMETABLE_BASE_URL=http://10.0.2.2:8000`),
  then push `main` to auto-deploy.
- **Run the engine offline against a real workbook:**
  `engine/.venv/Scripts/python.exe solver.py "routine generation files/<file>.xlsx" 90`
  — prints stats + the full validation block. Ingest only (fast, shows shared offerings,
  odd session counts and typed exclusions):
  `engine/.venv/Scripts/python.exe ingest.py "routine generation files/<file>.xlsx" 14`.
- **Regenerate engine config/seed from workbooks:** `python engine/tools/seed_config.py`.
- **Run tests:** `flutter test` (Dart) · `engine/.venv/Scripts/python.exe -m pytest tests -q`
  (engine; `pip install -r engine/requirements-dev.txt` once). Add `UNIVERSE_SOLVE=1` to also
  run the full CP-SAT solve against the real workbook (~2 min, skipped by default and skipped
  entirely when the gitignored workbook is absent).
- **Build won't start / cryptic Gradle version error:** see the JDK note in GUARDRAILS.
- **Routine times look wrong (AM instead of PM):** the write path is fixed, existing rows are
  not — re-upload or re-generate. `timetable_settings.periods` is the source and is currently
  SQL-only (§P3.1).
