# University Timetable Implementation Plan

> **For agentic workers:** Use `superpowers:executing-plans` for approved inline execution, or `superpowers:subagent-driven-development` only if delegation is authorized. This plan is for review; do not begin implementation until the user approves it.

**Goal:** Evolve UniVerse into a configurable multi-department timetable system with safe committee publication and reliable offline reading.

**Architecture:** Extend the current Flutter/Supabase/Python stack. Introduce approved domain snapshots, scoped immutable schedules and a shared validator; keep CP-SAT and add resource-aware placement. Add local published snapshots after the domain and publication contracts are stable.

**Tech stack:** Flutter, ChangeNotifier, GoRouter, Supabase Auth/Postgres/Storage/Realtime, FastAPI, OR-Tools, openpyxl, existing FCM; Hive initially evaluated behind a repository interface.

**Spec:** [Target architecture](../../timetable-audit-2026-10-20/04-target-architecture.md), [migration contract](../../timetable-audit-2026-10-20/05-database-migration.md), [workbook evidence](../../timetable-audit-2026-10-20/02-workbook-and-rules.md).


## Clarification priority override - 22 October 2026

This overrides conflicting dependencies/priorities below; it records audit
corrections, not authorization for new application changes or deployment.
Evidence: [workbook/code/UI trace](../../timetable-audit-2026-10-20/02-workbook-and-rules.md#verified-clarification-corrections---22-october-2026).

- Defer formal academic-term/year/calendar rollout. User reports that the two
  most senior batches currently use trimester and the rest bi-semester. Verify
  applicable current cohort configuration before implementing; never assign it
  permanently by batch number. Do not invent dates to populate local carriers.
- Treat batch/study-stage values as source-revision observations. The inspected
  distribution has no semester column. Current engine/parser arithmetic is a
  compatibility limitation, not verified progression. Use a current verified
  observation with provenance/as-of applicability; no automatic promotion.
- Summer/winter clock times change. Reuse Timetable Settings and freeze the
  verified timing grid with each distribution/generated/published revision.
  Do not hardcode a seasonal grid, infer season from month, or reinterpret old
  rows using a newer active configuration. Period index is not permanent time.
- Source Teacher cells determine assignments for that distribution. Keep the
  existing eligibility/off-day controls; do not replace imported teachers from
  eligibility priorities or add a competing assignment UI. Direct manual edits
  need explicit correction provenance and revalidation in the future plan.
- B+C is one joint class for B and C, only when verified in source. Preserve one
  meeting and both atomic groups through solver, renderer and student queries.
  Do not create/guess combined groups through routine controls. Other labels
  such as WD+WE require their own verified meaning.
- Reuse existing CSE lab/theory room pools, inventory, config screen and TBA
  diagnostics. Source notes already name CSE and EEE room allocations; verify
  aliases/applicability before extending eligibility, not another allocator.
- Reclassify the 125 end-before-start observations as stored time anomalies,
  not invalid source classes. The diagnostic reproduced a noon/spacing parser
  defect; exact lineage of the 795-row import remains unresolved. Preserve all
  rows and source values; no blanket clock correction or relaxed validation.

### Bounded unit and continuation checkpoint

1. Add source-preserving parser/formatter regression fixtures: noon crossing
   with attached/spaced AM/PM, numeric Excel serials/styles, explicit 24-hour
   input, day-header/config mismatch, and two verified seasonal grid revisions.
2. Trace the current `_timeRange` endpoint propagation and `_daySheetSlots`
   overwrite behavior; propose a bounded parsing fix with expected values from
   authoritative source. Capture source/parser/config revision in the decision.
3. Verify the source lineage of stored anomalies if matching bytes are available;
   the re-provided `workbook/` files are byte-identical to the 2025 originals and
   do not themselves match the 795-row batch/time grid. Missing lineage does not
   prevent reproducing the current bug, but does prevent automatic stored repair.
4. Only after a separately reviewable fix, reconcile affected historical rows
   against their actual source. Keep identity/progression/calendar rollout and
   unrelated solver/UI work outside this unit.

### Parser regression checkpoint - 22 October 2026

**Status:** test-only checkpoint complete and verified. Runtime parser fixes,
stored-row repair, timing-policy persistence and formal calendar integration are
not completed by this checkpoint. Resume here; do not repeat the workbook audit.

**Files changed:** `test/routine_workbook_parser_test.dart` (new), this plan,
and `2026-10-22-antigravity-parser-handoff.md` (ready-to-paste test-only handoff).
Fixtures are small in-memory OOXML ZIPs, with inline/shared strings and styled
numeric time cells. No original workbook bytes or personal data are included.
Synthetic summer/winter grids are explicit test inputs, not institutional times.

- Nine new passing tests cover attached PM across noon, independently explicit
  endpoint meridiems, preservation of explicit midnight, styled Excel fractions,
  afternoon 24-hour input, source bytes/teacher/B+C/stage preservation, separate
  supplied timing grids, matching headers and detached earlier parsed output.
- Three correct-expectation regressions were run and failed before being marked
  skipped. Their skips identify unresolved defects; incorrect output is not the
  accepted contract and the parser is not claimed fixed:
  - **PARSER-01:** spaced `11:10-12:15 PM` starts at 23:10, expected 11:10.
  - **PARSER-02:** explicit `06:10:00` becomes 18:10 through the campus-hour
    heuristic; an explicit 24-hour source must retain 06:10.
  - **PARSER-03:** conflicting workbook header/config timing silently returns
    rows with no warning. A visible mismatch is expected; neither source nor
    current settings should be silently treated as the other season.
- Literal B+C preservation does not demonstrate atomic-member retrieval or
  collision handling. Detached parser results do not prove persisted timing
  revisions. These remain separate future integration work.

**Verification actually run:**

```text
flutter test --no-pub test/routine_workbook_parser_test.dart
  Initial run: 9 passed, 3 failed at the expected assertions above.
flutter test --no-pub test/routine_workbook_parser_test.dart test/clock_time_test.dart test/timetable_settings_test.dart test/publish_gate_test.dart
  Final run: 52 passed, 3 explicitly skipped known defects, zero failures.
dart analyze test/routine_workbook_parser_test.dart
  No issues found.
```

**Ruling:** keep this unit test-only, preserve correct expected assertions as
explicitly skipped regressions, and do not change production behavior merely to
make the suite green. The user requested one bounded unit. No runtime code,
dependencies, SQL, workbook, authorization or stored data was changed; no commit,
deployment or hosted action was performed.

**Remaining blocker:** the exact source/config/deployment lineage of the 125
historical anomalies is unresolved. This blocks automatic stored-data repair,
not the reproduced parser correction. Current winter times and current batch
progression have not been inferred from historical files.

**Next task:** a bounded runtime parser correction for PARSER-01, with source
evidence and focused compatibility tests, then re-enable that regression. Review
PARSER-02 and PARSER-03 separately before expanding the fix: preserve existing
bare-hour compatibility and explicitly define header/config mismatch handling.
Do not start calendar/backfill work. An Antigravity agent using the test-only
handoff must stop at this completed checkpoint rather than begin runtime edits.

### Parser fixes checkpoint - 22 October 2026

**Status:** PARSER-01, PARSER-02 and PARSER-03 fixed and verified after the
user requested "fix those". This supersedes the prior skipped-defect status;
the three regression tests are enabled. Do not repeat the audit or test-only
checkpoint. No historical source times or database rows were repaired.

**Files changed:**

- `lib/features/admin/services/routine_workbook_parser.dart`: share a missing
  meridiem only for bare clock endpoints when inheritance preserves a forward
  interval; handle attached/spaced/dotted suffixes and parentheses. Explicit
  seconds and Excel fractional-day endpoints retain their own interpretation.
  Surface supplied-period/header mismatches with source/config times, retaining
  the workbook times. Built-in fallback times are not called supplied config.
- `lib/core/utils/clock_time.dart`: explicit two-digit `HH:MM:SS` values bypass
  the legacy bare-hour PM heuristic. Ambiguous bare-hour compatibility remains;
  no summer/winter grid or season is inferred.
- `test/routine_workbook_parser_test.dart`: enable all three regressions and
  add evening/shared-AM/dotted-suffix, mixed numeric/24-hour endpoint,
  parenthesized-range and fallback-warning compatibility coverage. Assert that
  mismatch warnings retain workbook times and identify configured times.
- This plan and the saved Antigravity handoff status.

**Actual verification:** re-enabled tests initially reproduced all three
expected failures (9 passed, 3 failed). A focused review caught a parenthesized
range regression and misleading fallback warnings; both were reproduced in
failing tests before correction. Final checks:

```text
flutter test --no-pub
  91 passed, zero failures, zero skipped tests.
dart analyze lib/core/utils/clock_time.dart lib/features/admin/services/routine_workbook_parser.dart test/routine_workbook_parser_test.dart
  No issues found.
git diff --check -- lib/core/utils/clock_time.dart lib/features/admin/services/routine_workbook_parser.dart
  Passed.
```

Focused independent review of the final deltas found no remaining important
issues. The mismatch behavior is a visible warning with workbook times retained,
not a new publish prohibition or persisted timing-policy implementation.
Auth code, authorization, schema, database content, original workbooks, teacher
assignment controls and room allocation were unchanged. No deployment performed.

**Remaining limits / next task:** actual source/config/deployment lineage of the
125 stored anomalies is still unresolved, so automatic stored repair remains
blocked. Next reviewable unit is source/config timing-revision provenance and
mismatch acknowledgement in the existing import flow; specify that contract
before implementing persistence or approval changes. Formal calendars, current
batch progression and historical backfill remain separate deferred work.

## Global constraints

### Application and deployment audit completed — 2 November 2026

Resumed from private readiness logs; verified the interrupted isolated APK build
finished successfully, signature verifier exit 0, source matches all 140 current
lib Dart files. Recovered analysis clean, 18 tool tests, local API smoke pass,
two-worker profile 73.19 s / 394.85 MiB on Windows. Prior 205 Python / 104 Flutter
and repeated-generation evidence retained, not rerun. Read-only Git comparison
refreshed: HEAD and origin/main have identical file trees; all new work remains
uncommitted/untracked. No Git state change or hosted write/deployment.

Report: `docs/timetable-audit-2026-10-20/10-merge-deployment-readiness-2026-11-02.md`.
Status **NOT READY** for production-backed team rollout: confirmed live Storage
mutation policies, deployed push authorization gap, unbounded public engine,
group/co-teacher reader loss and app/test-profile differences. Publication
validation remains client-dependent. No correctness certification inferred from
the successful APK build. Before interruption, only two bounded local fixes:
ignore raw workbook originals and align invite callback with Android; hosted
invite remains unchanged. Continuation adds the report and index/checkpoint.
Next work is to resolve those documented blockers and verify an intended test
environment; the user retains merge/deployment ownership. No broad rewrite or
automatic historical migration is authorized by this checkpoint.

### Cross-semester generation checkpoint - 1 November 2026

User requested repeated generation against both supplied distribution and fresh
live-derived input, independent source reconciliation and controlled semester
changes. See `docs/timetable-audit-2026-10-20/09-cross-semester-generation-2026-11-01.md`.
Three Summer runs preserved 338 offerings / 682 meetings with independent checks
passing. Fresh Fall capture retains all 796 meetings, reconstructing 415
observed offerings. No guessed whole-term totals, credits, enrollment or faculty
availability. All source retake multiplicities remain.

Changed `engine/ingest.py`, `engine/solver.py`, `engine/render.py`,
`engine/README.md`; added `engine/tests/test_cross_semester_acceptance.py` and
`tool/cross_semester_rehearsal.py`. Red/green fixes address stale extra-column
classes, explicit source service classification and scoped break placement /
Friday merged-header ordering. Completed: three corrected Fall runs retained
796/796 meetings with independent checks passing. All six final exports have
zero missing/unexpected cells or header errors and exact actual-app parser
round trips (Summer 652 main-grid rows plus 30 separately checked service
meetings; Fall 796 main-grid rows). Final Python suite 205 passed / 1 optional
skipped, Flutter suite 104 passed, focused render/acceptance 31 passed. Final
read-only live fingerprint unchanged; source workbooks preserved. No deployment
or hosted data write. This local testing checkpoint is complete within the
documented test profiles; current academic correctness is not certified.

Next: obtain/verify Fall distribution and resource policy before certification.
Publication still requires verified Fall distribution/resource policy and
separate live clock-only correction approval; do not deactivate retake rows.

### User scheduling clarification checkpoint - 1 November 2026

The response to the live-correction question supplied rules, not approval of
retake deactivation. Withdraw the earlier 794-row proposal. Its private SQL has
an explicit exception guard; no hosted data/source file/UUID was changed.

Implemented and tested in local code:

- Blank faculty requirements are retained with an empty teacher list and null
  primary teacher, rather than excluded or replaced with an available person.
  Generation still reserves the student group and room. Validation reports
  pending faculty separately and does not invalidate a class solely for that.
  Renderer emits FACULTY-PENDING, parser retains null teacher, and display says
  Faculty pending. Named-but-unmapped faculty retain their full source name;
  no acronym is invented and identical names still participate in clash checks.
  Mixed assigned/pending rows retain pending source-row provenance; the known
  teacher is not automatically made primary for the pending portion. Known
  teachers remain conservatively reserved, while the printed assignment stays
  pending until source allocation is resolved.
- CSE adapter Retake/Improvement cohorts remain valid rendered offerings rather
  than being hidden as external service merely because the batch is nonnumeric.
  A resource conflict is independent of a course being a retake; do not merge
  audiences or deactivate repeated records without verified intent.
- Physical room keys normalize casing/whitespace and apply explicit per-run
  aliases. Confirmed current alias: PHY LAB (any casing) = RAB-106. Inventory
  aliases cannot inflate physical capacity, including legacy room arrays;
  conflicting type/capacity declarations require review rather than guessing.
- Explicit unavailable_rooms config is scoped to a run. Current user rule is
  RAB-104 unavailable for classes because it is a faculty room. This is NOT a
  permanent engine default or a retrospective restriction on Summer 2025.
  An explicit current review profile is saved privately as
  `.task1-local/advisor-fall2026-room-policy.json`.

APIs: solver accepts room_aliases/unavailable_rooms in supplied configuration;
RoutineWorkbookParser accepts them in its constructor. The existing UI does not
yet persist/select semester room-policy revisions; callers must explicitly
supply the applicable profile. Do not claim automatic policy rollout or invent
schema/calendar dates to fill this integration boundary.

Targeted source AND read-only live check confirmed the user's Sunday batch 62/I
CSE-4161 (SDJ), 15:10-16:10, is recorded in RAB-106. After PHY LAB aliasing, there
are no other RAB-106 overlaps and RKB-106 is also unoccupied at that time.
Therefore availability does not prove a typo; no room correction was made.
No active RAB-104 classes were found. Current source with the explicit room
profile retains 796 rows and two repeated-event overlap pairs; no rows removed.

Historical distribution normalization now retains 338 offerings / 682 derived
meetings, including 13 pending-faculty offerings (26 meetings); fixed-two mode
retains 338 / 676. Only the two no-batch rows remain excluded. Older 325/656/650
counts described the prior automatic blank-faculty exclusions and are historical,
not the new acceptance target. Updated source regression tests preserve class
counts and row provenance without changing source bytes or academic fixed-rate
policy. New pending/room regressions failed before their fixes. Focused review
found two additional cases (name-only clashes and legacy room aliases); both
were reproduced, fixed and reviewed. Final verification results follow below.

Verification: historical source rehearsal after the clarification returned
FEASIBLE for 338 offerings / 682 meetings with zero reported teacher/group/room
clashes, including 13 pending-faculty offerings / 26 meetings; two no-batch rows
remain excluded. Rendered workbook is private
`.task1-local/advisor-summer2025-pending-preserved.xlsx`, not a current publication.
Full Flutter suite passed 104 tests; targeted Dart analysis clean. The full
Python suite passed 190 tests with one optional skipped, including the mixed-row
regression (final complete run). Do not equate pending faculty with verified
teacher identity or publish guessed allocation weeks. This clarification
checkpoint is locally verified; hosted correction/publication remains pending.

Next: configure a reviewed room-policy revision in the existing app flow before
claiming automatic current-semester room enforcement; resolve the possible room
typo/audience ambiguity with authoritative source evidence. A separate clock-only
live correction may be proposed, preserving all retake/pending rows, but no live
write is approved by the clarification itself.

### Advisor readiness checkpoint - 1 November 2026

User requested a CSE generator/publication audit for the advisor meeting on
2 November and confirmed cross-checking both historical Summer and current Fall
sources. See `docs/timetable-audit-2026-10-20/08-advisor-cse-readiness-2026-11-01.md`
for source hashes, exact results, limits and private review artifact paths.

Completed: upload fail-closed gate, actual interval and source joint-group checks,
engine period-grid/source-teacher/inventory/faculty validation, known capacity
propagation and suitable-room ordering, regression tests. Preserved existing
fixed-rate academic policy and all hosted data/settings. No calendar rollout or
batch progression inference. Changes are local; deployment is not implied.

Actual verification: Python 184 passed / 1 optional skipped; Flutter 100 passed;
targeted Dart analysis clean. Independent review and red/green capacity regression
completed. Historical distribution rehearsal produced OPTIMAL 656 meetings for
325 retained offerings and all 178 theory/lab pairs adjacent; rendered workbook
saved privately, not published. Original exclusions/duration-policy questions
remain unresolved. Do not certify current offering completeness from that file.

Current live source changed during inspection to a full 796-row Fall upload.
All source teacher/course/room label hashes match, but 116 stored noon starts
retain the old parser defect and two exact source duplicates cause conflicts.
Prepared a private 794-row candidate with zero structural errors and a guarded
SQL correction preserving all UUIDs/rows (two become inactive), source files and
cancellations. Isolated PostgreSQL rehearsal passed, including stale-content
refusal. Hosted changes require approval of this concrete correction and a
private backup; no hosted action has yet been performed.

Next: obtain the correction decision, then apply only with pinned version/hash
guards and verify fresh readback. Verify applicable faculty/room permissions and
current distribution before claiming full academic correctness. Do not publish
a partial trimester routine through the global replacement RPC.

- No production migration, workbook import, deployment or data overwrite without explicit authorization.
- Preserve Supabase auth user/profile IDs, existing roles, CSE schedules and adjacent features.
- Do not commit original PII workbooks, credentials or production row exports.
- Hard conflicts, authorization and referential integrity cannot be overridden.
- All producers use the same backend validation/publication contract.
- Proposed import limits: 10 MiB compressed, 100 MiB expanded XML, 100 sheets, 50,000 nonempty input rows, 1,000,000 processed cells.
- Proposed job limits: one running job per scope, two per instance, 180 seconds solving, 240 seconds total.
- Proposed online freshness: 5 seconds p95; fallback poll 30 seconds; stale indicator after 60 seconds without successful check.
- Initial offline access is read-only; proposed authorization grace is seven days and requires institutional acceptance.
- Fixed-duration same-day meetings first; overnight meetings reject explicitly.
- Follow existing service/controller/widget patterns; no unrelated state-management or backend replacement.

## Review focus

1. Shared group B+C must reserve both B and C and be visible to both (Tasks 2, 5, 9).
2. Same teacher across different departments, grids and overlapping term dates must conflict (Tasks 5, 7).
3. A lost publish response followed by retry must not duplicate publication/notifications (Task 7).
4. Account changes during a paginated sync must never activate another user's cache (Task 11).
5. Missing formula cache, unknown teacher or unresolved 1.5-hour duration must not be “fixed” through fallback defaults (Tasks 3, 4).

## Execution model

Tasks are ordered and independently reviewable. Each task follows: write the named failing tests, run them to confirm the gap, implement the defined contract, rerun the targeted suite, review the diff and commit only the authorized files. Production rollout is separate. Tests named below are **proposed new tests**, not existing passing checks.

**Pacing correction — user requested faster progress toward proper routine generation:** Keep one small independently testable unit per run and preserve the dependency graph, but batch all independent manual checks for that unit into one prepared script/checklist. Complete available local work before handing off; do not ask for repeated acknowledgments or split each expected status code into a separate turn. Reuse supplied exports and passing evidence; update a concise status rather than expand unrelated audits. Keep production untouched.

For Task 1, prioritize the remaining baseline-fidelity/assertion work, focused invite-admin caller checks, sanitized schedule restore with exact count/checksum, and two clean replay/restore passes. Resolve or explicitly retain deployment gaps as the original acceptance requires; do not mark Task 1 complete prematurely. Real-device push delivery, live Realtime latency/client-lifecycle testing and production hardening rollout belong to the later integration/rollout tasks; they are not additional Task 1 acceptance gates. Preserve known gaps in the record. After actual Task 1 acceptance, continue Tasks 2–6 in order toward domain, policy, ingestion, validation and solver work. No dependency waiver is implied by this pacing correction.

## Task 1 — Reproducible backend baseline and deployment reconciliation

**Objective:** Establish a trustworthy database and notification baseline before schema evolution.

**Files:** Create `supabase/config.toml`, a CLI-generated baseline/reconciliation migration, `supabase/tests/baseline.test.sql`, `docs/backend-setup.md`; reconcile `supabase/functions/invite-admin/index.ts` and `send-push/index.ts` against exported deployed source. Add `.github/workflows/validate.yml` once local replay works.

**Prerequisites/infrastructure:** Authorized schema-only export, migration history, test project/local Supabase runtime, deployed function source and webhook metadata. No production credentials in fixtures.

**Interface/output:** Reproducible isolated database with current contracts, sanitized fixtures and verified function deployment instructions.

- [x] Capture and compare tables, constraints, policies, grants, functions, triggers, Storage and Realtime definitions; record drift without running old destructive migrations.
- [x] Write baseline assertions for the objects actually used by Dart, and deny anonymous privileged operations.
- [x] Reconcile migrations without renaming applied history; restore a sanitized current schedule and check its checksum/count.
- [x] Recover real Edge Function source, verify caller/webhook authorization in the test project, and preserve notification audience behavior.
- [x] Discover installed CLI commands with `supabase --help`; run the supported isolated reset/test workflow and record exact versions.

**Acceptance:** Clean replay and backup restore succeed twice; 100% used objects accounted for; both functions have executable reviewed source or remain an explicitly blocking deployment gap.

**Risk/rollback:** Historical drift or dashboard-only secrets. Stop at reconciliation when access is missing; keep production untouched; discard only the disposable test database.

### Task 1 acceptance completed - 22 October 2026

**Status: COMPLETE for the reproducible isolated baseline. Task 2 is now eligible.**
This acceptance record supersedes the incomplete statuses and manual handoffs in
historical Task 1 checkpoints below. It does not authorize production rollout.

- Added CLI-generated local config, a CLI-named reconstructed baseline review
  artifact, guarded `tool/task1_local_checks.py`, regression tests and CI workflow.
  Historical migration files/names and hosted migration history remain unchanged.
- The final verifier completed two fresh local resets in the actual public
  namespace. Each passed provisioned-role/token/role-escalation/legacy-publication
  checks, exact catalog/Storage/Realtime checks and **44 pgTAP assertions**.
- Each rebuilt database restored and compared all **795 routine rows and four
  version records**, checksum `07da7d69a5d0b0dd816133f41716eae7`, then rolled back
  and verified fixture cleanup. The owned local stack stopped successfully.
- **18 Python tests passed**; Deno 2.5.6 passed both suites containing 11 webhook
  authorization and 13 audience cases. CI YAML parsed; equivalent commands ran
  locally. GitHub Actions itself has not been triggered or claimed passing.
- Actual versions: CLI 2.121.0, Docker 29.9.2, PostgreSQL 17.11 (image
  17.11.0.004), vector 0.8.2, pgTAP 1.3.3. CLI init/migration/reset/test help was
  inspected; downloaded CLI/Deno binaries were checksum-verified, not installed
  globally. No production query, migration, deployment or secret changes occurred.
- All 17 Dart table constants and both currently used bucket constants are
  accounted for. The unused submissions bucket constant has no matching source
  bucket; this drift is recorded without changing the client or adding a bucket.
- Focused fresh-context review found a Docker context precedence issue. Added a
  failing regression, removed inherited context overrides and pinned the verified
  local socket; tests and the final two-pass runtime verification passed afterward.

**Retained limits:** baseline grants deliberately exclude legacy maintenance
privileges; source vector 0.8.0 differs from test/local 0.8.2; source migration
history is unavailable rather than fabricated. This is a sanitized current-schedule
backup, not full Auth/config/Storage/deleted-history recovery. Both recovered Edge
Functions have executable reviewed source and isolated authorization evidence;
positive invitation/email, real FCM delivery, live Realtime and production
webhook/secret rollout remain later integration/rollout work. Broad legacy Storage
ownership behavior is recorded, not approved or remediated by this baseline.

**Ruling:** keep the unsafe historical chain intact and reconstruct only inside a
new owned local project - source history is unavailable and production is out of
scope. Cost/limit: this proves the documented restricted compatibility baseline,
not exact source environment or production disaster recovery.

**Next unit:** Task 2 canonical departments, terms, faculty, rooms and student
 groups. No further Task 1 manual SQL handoff is required.

### Historical Task 1 checkpoints (superseded by acceptance above)


**Execution checkpoint — 22 October 2026:** Task 1 remains incomplete. Read-only prerequisite checks found no repository schema-only export, baseline, migration-history export or `supabase/config.toml`. `supabase --help` failed because the CLI is not on PATH. Docker is installed, but `docker info` could not connect to its daemon (and reported denied access to its user configuration). The connected Supabase project list returned only the active UniVerse project, with no disposable test project identified. No database queries, migrations, function changes, resets, deployments or data writes were performed. Existing user changes were preserved. No implementation tests ran because no executable implementation was changed; `git diff --check` was run for this documentation checkpoint. Next: make the CLI and an isolated runtime available, then recover and compare the authorized schema/history/function definitions as Task 1 specifies. Do not infer a baseline from historical migrations or start Task 2 before Task 1 acceptance passes.

### Task 1 split and repository checkpoint — 22 October 2026

Task 1 is **partially prepared, not accepted**. The runtime blocker does not prevent repository inspection or existing local tests. This checkpoint supersedes the earlier suggestion that CLI availability must precede all useful work.

**Repository-verifiable work:**

- [x] Compare the Dart table constants and relevant service calls with the checked-in SQL. All 17 table constants are covered by the initial `supabase/tests/baseline.test.sql` existence/RLS assertions. These are expected application contracts, not recovered deployed definitions. RPC assertions cover `register_device_token(text,text)`, `my_role()`, `is_admin()` and `publish_routine(jsonb,text,text,jsonb,jsonb,text)`; also check the routine version reference and profile role trigger. Full columns, constraints, policies, Storage, Realtime and `match_documents` remain outside this initial test slice.
- [x] Reconfirm the existing migration evidence without replay: 15 files, 001–009/011–016; 001 references pre-existing notifications, 006 references cancellations before 007 creates it, and 008 explicitly describes dashboard-created timetable catalogs. 009 drops generated_timetable; 012 adopts existing routine rows; 014 globally deletes/replaces routines. Preserve history; do not synthesize a baseline or blindly replay it.
- [x] Inspect both local Edge Function files: all implementation lines are commented out. Their sketches describe admin invitation and role/batch/section notification audiences, but provide no executable deployment evidence. In particular the send-push sketch cannot establish webhook caller authorization. Do not uncomment or deploy either file as reconciliation.
- [x] Prepare initial catalog/anonymous-RPC-grant assertions in `supabase/tests/baseline.test.sql`, inside a rollback transaction and with no application writes. This completes preparation only, not the parent baseline/authorization checkbox. Effective anonymous EXECUTE denial is an explicit security expectation to reconcile, not an assertion that historical grants already satisfy it.

**Checks without CLI/Docker:**

- [x] `flutter test --no-pub test/publish_gate_test.dart test/timetable_settings_test.dart`: **34 passed**. These verify existing client publish-gate/settings behavior, not database enforcement. The gate suite explicitly permits absent validation under the current legacy behavior; future server-side validation remains required by Tasks 5–7.
- [x] Python standard-library static check: all 17 Dart table constants appear in both SQL table assertion lists; rollback present; no application DML/DDL. Passed. This is coverage/text validation, not SQL parsing or execution.
- [x] Whitespace checks: new SQL and plan checked separately because they are untracked. Repository-wide `git diff --check` still reports pre-existing whitespace in diagram documents and `tool/er_diagram.py`; unrelated user changes remain untouched.

**Requires external artifacts and/or an isolated runtime (still outstanding):**

- [ ] Obtain an authorized sanitized schema-only export and applied migration-history list, including full function bodies/owners/search paths, grants/RLS, triggers/constraints/indexes, extensions, Storage configuration and Realtime definitions. Existing `supabase/diagnostics.sql` is partial introspection, not a replayable schema export.
- [ ] Obtain exported deployed Edge Function source plus sanitized webhook/deployment metadata (including authorization configuration; no secret values).
- [ ] Obtain a sanitized current-schedule backup with expected exact count/checksum and a disposable database/runtime. Discover installed CLI help/version when available; generate config/reconciliation via supported tooling, without renaming applied history.
- [ ] Run the initial pgTAP file (requires pgTAP available), expand to complete contract/role-based denial and Edge Function audience tests, reconcile actual drift, and demonstrate replay/restore twice. Initial SQL tests have **not run**; no database security success is claimed. Add CI only after replay works.

**Dependency decision / next action:** No later task is independently eligible under the approved dependency graph: Task 2 requires Task 1, and Tasks 3–12 depend transitively on it. Next actionable unit is comparison against the authorized schema/history export; no CLI is needed to inspect supplied artifacts. Runtime verification still requires an isolated database. No tools were installed, machine settings changed, production accessed, migrations applied or application code changed during this checkpoint.

### User-supplied deployment evidence — 22 October 2026

- Received user-run diagnostics, seven application function definitions with effective anon/authenticated EXECUTE privileges, and constraint/index metadata (45 constraints, 32 indexes). These are supplied observations, not an independently executed database test or a replayable schema dump.
- Diagnostics show all 17 Dart table contracts plus `timetable_courses`, with RLS enabled and policies present; this does not establish policy correctness. They show public buckets `assignments`, `avatars`, `resources`, `timetables`, but no `submissions` bucket despite its Dart constant. Broad Storage write policies still require reconciliation. Row estimates are not exact backup counts.
- Supplied function metadata denies anon EXECUTE on all four RPC/helper signatures in the initial baseline test. `profiles_guard_role` and the routine version reference exist. Catalog assertions have not been run through pgTAP. The returned global active-version unique index and global-delete publish body confirm legacy publication semantics; do not expand department publication under this contract.
- The user's migration-history query returned 42P01 for `supabase_migrations.schema_migrations`. Record applied history as unavailable; do not invent version records or infer that no SQL changes were applied.
- Received executable `invite-admin` source in chat and `send-push` source as an attachment. A local comparison confirmed send-push executable lines match the commented repository sketch after removing its outer comment prefix (comments/indentation ignored). Invite source visibly verifies the caller with Auth and checks the stored admin role before privileged writes; no live invitation was attempted. Local function files remain unchanged pending runtime reconciliation.
- Supplied send-push code has no in-handler caller authorization check; actual gateway JWT verification/caller restrictions remain unknown. It resolves role/batch/section audiences and prunes tokens on HTTP 400/404. Authorization, delivery and pruning behavior require isolated tests; no function was invoked. Obtain gateway verification settings before treating the webhook as authorized.
- Earlier diagnostics included a webhook credential. Do not copy raw diagnostics into the repository; the user was advised to arrange coordinated credential rotation. Rotation status is unknown. No secret values are recorded here.
- Next manual collection: function gateway JWT verification settings (values only, no keys), effective table privileges, extension versions and Realtime membership. Full typed schema/export, isolated replay/restore and sanitized backup remain outstanding; Task 1 stays incomplete and downstream dependencies stay blocked.

### Gateway and remaining metadata checkpoint — 22 October 2026

- User screenshots show legacy JWT verification OFF for `send-push`, ON for `invite-admin`. Combined with the supplied send-push handler's absent caller authorization, this establishes an authorization gap in the supplied deployment evidence: a caller reaching that handler can submit a record that drives privileged audience/token queries and FCM delivery. No live request/exploit was attempted. Sending a credential in the webhook does not enforce receipt/validation of that credential. Do not treat simply turning legacy JWT verification on as service-role-only authorization; remediation requires an explicit caller contract and isolated tests, with separately authorized production rollout.
- Parsed the user-supplied remaining_metadata JSON: 587 table-grant entries; anon and authenticated each have 142 entries across public/Storage objects. These are catalog grant rows, not a complete effective-privilege calculation or proof of row access. RLS and actual role behavior still need isolated verification. Preserve existing grants until reviewed.
- Extension versions supplied: pg_net 0.20.0, pg_stat_statements 1.11, pgcrypto 1.3, plpgsql 1.0, supabase_vault 0.3.1, uuid-ossp 1.1, vector 0.8.0 (vector in public; other schemas recorded in attachment). pgTAP is not in the supplied extension list; provision it only in the disposable test runtime when preparing tests.
- Realtime membership supplied lists only public.cancellations in supabase_realtime. Do not assume routines or routine_versions currently publish changes. No publication was modified.
- Metadata parsing and screenshot/source inspection completed; no database, Edge Function or delivery tests ran. Updated-plan whitespace check found no whitespace errors. Task 1 remains incomplete: replayable typed schema/export (including non-public dependencies and relevant configuration), sanitized restore fixture and isolated runtime are still required. Next manual prerequisite check: start Docker Desktop locally and report Docker server availability plus existing Node/npm versions, so supported CLI/runtime steps can be selected without guessing or installing tools automatically.

### Hosted runtime and typed-column checkpoint — 22 October 2026

- User created a separate `universe-timetable-test` project in Mumbai with no repository connected. User-run runtime check returned PostgreSQL 17.11 (aarch64), UTC and zero public base tables. Hosted SQL Editor is the selected runtime path; Docker/Node/CLI installation is not required for this path. Keep the existing migration filenames/history intact; any reviewed manual baseline must be identified as reconstructed, not CLI-generated or proven applied history.
- Parsed the latest typed-column attachment: exactly 100 columns across 12 tables, ending partway through timetable_course_eligibility. It confirms documents.embedding is vector(768) and profiles.courses is text[], but is incomplete relative to the earlier diagnostics. Do not infer the missing definitions. Next: collect the typed-column query as one aggregate JSON cell with explicit count to avoid result-row truncation, then reconcile coverage before preparing the baseline. No database changes or runtime tests performed at this checkpoint.

### Complete column reconciliation / test table stage — 22 October 2026

- Received and parsed the aggregate complete_columns export: declared and actual count both 161, across 18 tables. Table/column keys exactly match the earlier diagnostics, resolving the 100-row truncation. No identity/generated columns were reported. Exact types include vector(768), text[] and the legacy time-without-time-zone fields.
- Prepared `supabase/reconciliation/001_test_tables.sql` from the supplied exact types/defaults/nullability, 45 constraints and 32 indexes (22 constraint-owned, 10 explicit). This is a reconstructed hosted-test stage, not a CLI-generated migration or a complete backend baseline. It preserves deployed definitions, including legacy single-scope constraints; it adds no domain redesign.
- Safety: transaction; abort if public has any base/partitioned tables; vector dependency requested at supplied version 0.8.0; all 18 tables have RLS enabled and PUBLIC/anon/authenticated table privileges revoked during this incomplete stage. No row data, users, credentials, functions, webhook triggers, Storage policies or Realtime changes included. Client access intentionally remains denied until separately reviewed policy/grant stages. Run only in the empty user-created test project, never the original UniVerse project.
- Verification: local Python check compared all 161 generated column definitions against the supplied source, checked 18 RLS/revoke statements, 45 constraints, 10 explicit indexes, transaction/guard placement and absence of DML/drop/triggers: passed. This is static validation; SQL parsing/execution and database contract tests have NOT run. Changed-file whitespace checks passed. Task 1 remains incomplete.
- Next manual action: run the reviewed table stage in universe-timetable-test SQL Editor and return success/error plus public table count. If it fails, report the exact error; do not remove guards, replay old migrations or manually improvise repairs. Then reconcile functions/policies/grants in the test project before fixtures or role-based tests.

### Hosted function/policy stage prepared — 22 October 2026

- User returned public_table_count = 18 after the table stage. This confirms the count in the supplied test-project output; full schema fidelity and replay remain unverified.
- Prepared `supabase/reconciliation/002_test_functions_policies.sql`: seven exact supplied function definitions (dependency ordered), supplied postgres owners and observed anon/authenticated EXECUTE behavior, 50 public policies, and the two local BEFORE INSERT OR UPDATE row triggers for profiles/submissions. PUBLIC function EXECUTE is explicitly revoked before observed client-role grants are restored; broader role/grant fidelity remains a later reconciliation item. No production webhook, Storage, Realtime, data fixtures or Edge Function deployment is included.
- The stage preserves supplied legacy policy expressions and function behavior for comparison, including permissive PUBLIC policies and trigger-function anon EXECUTE metadata; this is not security approval. Existing helper/publish/token RPC anon denials are retained. All client table grants remain denied pending a separate reviewed grant stage, so readers and client-role behavioral tests are not yet functional.
- Guards require 18 public tables, expected stage-001 objects, no existing public policies and denied client table privileges. The entire stage is transactional. Guards are misuse checks, not cryptographic project identity checks: user must select universe-timetable-test explicitly. Never run on UniVerse or remove guards to bypass a failure.
- Added `supabase/tests/reconciliation_stage2.sql`, a no-pgTAP, rollback-only hosted catalog smoke check for table/RLS/policy counts, seven signatures, four protected RPC grants, correct local trigger events/functions, absent notification webhook, and continued client table denial. Expected to fail before stage 002 and pass after it. It does not exercise role-based row access or function side effects.
- Verification performed locally: exact source comparison of all seven function bodies and all 50 policy definitions, statement counts, absence of network URLs/credential strings/table grants and transaction boundaries: passed. Changed-file whitespace checks passed; repository-wide diff check continues to flag unrelated pre-existing diagram/tool whitespace. SQL smoke tests have NOT been executed; no red/green runtime claim, deployment or database mutation made by the agent.
- Next manual action: in universe-timetable-test, run the smoke check before stage 002 (expect failure), run stage 002, then rerun the smoke check and return its result/error. Stop after that checkpoint. Task 1 remains incomplete; follow with table-grant/role tests, remaining Storage/Realtime reconciliation, sanitized restore and repeated clean replay.

### Hosted stage 002 result received — 22 October 2026

- User returned `PASS: stage 002 catalog smoke checks; table grants remain closed` from `supabase/tests/reconciliation_stage2.sql` in the hosted-test workflow. Record this as user-executed passing catalog evidence: 18 tables/RLS, 50 policies, seven expected function signatures, protected RPC grants, the two expected local triggers, absent notification webhook and denied client table privileges.
- No pre-install failure output was supplied; do not claim an observed red/green cycle. This passing smoke check does not prove exact definition fidelity, role-based row authorization, successful publication/restore, Edge Function authorization/delivery or twice-repeated replay. Task 1 remains incomplete.
- Next independent unit within Task 1: prepare a reviewed test-only table-grant stage from supplied deployment grants, paired with rollback-only role/fixture authorization tests. Do not apply broad grants, change production, connect the app or start Task 2 at this checkpoint.

### Restricted hosted DML/authorization stage prepared — 22 October 2026

- Inspected supplied public table grants: anon and authenticated each hold SELECT/INSERT/UPDATE/DELETE/TRUNCATE/REFERENCES/TRIGGER on all 18 public tables (252 observed entries). TRUNCATE bypasses row filtering; do not silently reproduce it or treat RLS as protection against it. No production grants were changed.
- Prepared `supabase/reconciliation/003_test_dml_grants.sql` as an explicitly restricted test variant: 144 observed DML privileges (18 tables × 2 roles × 4 operations), omitting all 108 maintenance privileges. This is a deliberate test/production difference, not exact grant reconciliation or a production remediation. Requires stages 001/002, enabled RLS, closed prior client grants and absent notification webhook; transaction aborts on mismatch. No schema-wide or future-table grants, data writes, Storage, Realtime or application changes.
- Added `supabase/tests/reconciliation_stage3.sql`, requiring empty routine/profile/whitelist/version fixtures and no notification webhook. It uses a synthetic routine in a rollback transaction without auth.users inserts, FK bypasses or real identities. Tests establish anon and authenticated-without-profile JWT/SQL role contexts; check anon cannot read/insert routines, publish or register tokens; check authenticated read succeeds while routine insert/update/delete and publication deny; verify fixture/version state before rollback. Maintenance privileges must remain absent. These tests do NOT cover provisioned student/teacher/admin roles, token ownership/reassignment, successful publication or restoration.
- Static verification passed: every intended DML grant exists in supplied metadata; maintenance grants omitted; guarded transaction, role-context/reset pairs, explicit affected-row/denial assertions, rollback and absence of credential/network calls checked. Changed-file whitespace checks passed. SQL has NOT run, so no authorization-test success or observed red/green cycle is claimed. Existing stage-002 smoke test intentionally becomes obsolete after stage 003 grants (its closed-grant assertion should fail); use stage-003 test for this checkpoint.
- Next manual action only in universe-timetable-test: run stage-003 test first (expected missing-client-DML error), apply stage 003, rerun the test and return its final PASS/error. On failure stop and report exact output; do not alter guards or clear data. Task 1 remains incomplete; full grant reconciliation, provisioned role tests, Storage/Realtime, Edge Function authorization, sanitized backup/restore and repeated replay remain outstanding.

### Hosted stage 003 result received — 22 October 2026

- User returned `PASS: stage 003 DML grants, anon denials, authenticated read/non-admin denials; fixture rolled back` from the hosted-test workflow. Record user-executed passing evidence for the stage-003 assertions: DML privileges available, maintenance privileges absent, RLS enabled, anonymous routine read/write and protected RPC denials, authenticated-without-profile routine read with mutation/publication denials, unchanged fixture/version state, and rollback reached.
- No before-install failure output was supplied; do not claim an observed red/green cycle. This result does not establish provisioned student/teacher/admin behavior, successful publication, ownership isolation, Storage/Realtime or Edge Function safety, restore, or twice-repeated replay. The restricted test grants still intentionally differ from production maintenance grants. Task 1 remains incomplete.
- Next eligible unit within Task 1: prepare rollback-only provisioned-role/ownership and publication tests with synthetic auth identities in the disposable project, first verifying the test runtime's auth fixture requirements. Production remains untouched; no downstream task is eligible yet.

### Provisioned-role/publication test prepared — 22 October 2026

- Added only `supabase/tests/reconciliation_stage4.sql` for this unit; no stage-004 persistent schema/grant change is needed. The hosted SQL Editor test uses four synthetic auth.users/profile identities (admin, teacher, two students) and synthetic tokens/schedules with FKs intact, all inside one rollback transaction. It never invokes Auth APIs, Edge Functions or email delivery.
- Preflight requires postgres, 18 empty public tables/50 policies with RLS, empty auth.users, no custom auth.users triggers, only two public user triggers and no notification webhook. Auth catalog inspection rejects additional mandatory fixture columns without defaults before inserting users. A failed guard is a request for evidence, not permission to remove a guard or clear data. Bootstrap uses postgres with no end-user JWT, then exercises authenticated role/JWT contexts.
- Assertions cover token read/write/reassignment ownership isolation, positive own-token RPC registration and own-profile edit, denied cross-profile edit and student self-promotion, denied student/teacher publication, successful admin publication, empty-payload rejection, failed second-row publication preserving prior rows/version pointer, and legacy replacement leaving exactly one active version. After rollback, checks confirm all touched Auth/profile/token/routine/version tables are empty before emitting PASS.
- Scope limits: this tests legacy single-scope replacement, not independent schedule correctness, new immutable history, cross-scope concurrency, retry idempotency, Auth login/session issuance, token-reclaim policy, Storage/Realtime or push delivery. No fixture data is production-derived. Direct SQL Auth fixtures validate database behavior only, not the Auth service workflow.
- Local static checks passed: role/reset pairs, expected SQLSTATE-specific denial handlers, guarded fixture insertion, rollback-before-PASS and post-rollback cleanup checks, fixture JSON validity, and absence of DDL/grants/commit/network calls/credentials. Changed-file whitespace checks passed; full git diff --check still reports pre-existing unrelated diagram/tool whitespace. SQL has NOT been executed and no runtime PASS or red/green cycle is claimed. Task 1 remains incomplete.
- Next manual action: run reconciliation_stage4.sql only in universe-timetable-test SQL Editor as postgres, then return the final result or exact error. No other script or settings change is needed; stop on failure. After a passing result, resume remaining baseline/Storage/Realtime/Edge Function/restore/replay prerequisites in dependency order.

### Hosted stage 004 result received — 22 October 2026

- User returned `PASS: stage 004 provisioned roles, token ownership, escalation denials, legacy publish atomicity; fixtures rolled back`. Record as user-executed passing evidence for the stage-004 script: synthetic student/teacher/admin contexts, tested token ownership restrictions and own registration, profile-edit/escalation restrictions, student/teacher publish denials, successful admin publish, empty-payload rejection, malformed replacement preserving previous rows/version pointer, successful legacy replacement and post-rollback fixture cleanup.
- This establishes the tested database paths only, with restricted test grants. It does not establish Auth API login behavior, complete policy coverage, schedule semantic correctness, cross-scope publication, concurrent publication/retry guarantees, or full deployment fidelity. No test mutation remains according to the supplied post-rollback PASS; the agent did not access production or execute hosted SQL.
- Next eligible unit within Task 1: reconcile the supplied Storage bucket/policy configuration and Realtime membership in the disposable runtime, with focused authorization checks. Edge Function authorization/delivery remains unresolved, as do sanitized backup/restore and two clean replay/restore passes; do not mark Task 1 complete or start Task 2.

### Storage/Realtime prerequisite collection prepared — 22 October 2026

- Reused the supplied evidence: four public buckets, four broad storage.objects policies and cancellations-only Realtime membership. The earlier exports omit bucket MIME/file-size limits, storage.buckets policies, policy permissiveness, full publication flags/column lists/row filters and replica identities; the test project's managed Storage configuration is also unverified. Do not invent or overwrite these settings.
- Prepared `supabase/reconciliation/storage_realtime_inventory.sql`, one read-only aggregate query for both projects. It collects those missing definitions plus managed table owners/RLS and effective client table privileges, without object contents/names, user rows, secrets or webhook definitions. It performs no managed Storage writes or publication changes.
- Static validation passed: single top-level SELECT, expected metadata fields and no mutation statements, function/trigger definitions, credentials or object-data reads. Changed-file whitespace checks passed. Query has NOT been executed; no new hosted test success is claimed. Task 1 remains incomplete.
- Next manual action: run this same query separately in original UniVerse and universe-timetable-test, and return two clearly labeled complete result cells (or exact errors). Then prepare only the narrowly scoped test-project reconciliation supported by those results. Do not add public bucket defaults, copy permissive write policies blindly, upload files, or change Realtime membership at this checkpoint.

### Storage/Realtime inventories compared; Realtime stage prepared — 22 October 2026

- Parsed both supplied inventory attachments. The empty-bucket/no-policy/no-Realtime-member output matches the known test-project state; the four-bucket/four-policy/cancellations-member output matches the known UniVerse state. Both show UTC, identical managed Storage owners/RLS/effective client privileges, identical publication flags/owner, and default replica identity on all 18 public tables.
- Source buckets assignments/avatars/resources/timetables are public with null bucket-specific size/MIME restrictions; source storage.objects policies are the same four permissive policies already observed, with no storage.buckets policy returned. These broad policies remain a reconciliation/security concern; do not silently introduce them as a safe target or mutate managed Storage metadata directly. Test Storage remains empty/unchanged.
- Selected only Realtime membership as this independently testable unit. Prepared `supabase/reconciliation/004_test_realtime.sql`: transactionally add only public.cancellations to the empty test supabase_realtime publication. Guards verify postgres, reconstructed table/policy counts, supplied publication flags/owner, no prior members, default cancellations replica identity/RLS and no notification webhook. Original project's existing membership would fail the guard. No flags, replica identities, Storage settings, rows or app code are changed.
- Added `supabase/tests/reconciliation_stage5.sql`, a rollback-only catalog check for exact cancellations-only membership, all 11 source columns, no row filter, matching publication flags/owner and intact replica identity/RLS. Explicitly does not test WebSocket delivery, client subscriptions or latency.
- Static comparison/verification passed: matching inventory invariants, exact source membership/column list/flags, one guarded publication addition, no data/Storage mutations and read-only test with rollback-before-PASS. Changed-file whitespace checks passed. Neither SQL file has been executed; Task 1 remains incomplete.
- Next manual action: only in universe-timetable-test run the stage-005 test (expected membership error), apply 004_test_realtime.sql, then rerun the test and report PASS/error. Stop on unexpected failure. Storage bucket/policy reconciliation and API authorization tests, Edge Function authorization/delivery, sanitized backup/restore and repeated clean replay remain outstanding.

### Hosted stage 005 result received — 22 October 2026

- User returned `PASS: stage 005 cancellations-only Realtime configuration matches supplied baseline; delivery not tested`. Record user-executed catalog evidence for exact cancellations-only membership/all 11 source columns/no row filter, supplied publication flags/owner, default cancellations replica identity with RLS enabled, and absent notification webhook. No pre-install failure output was supplied; do not claim an observed red/green cycle.
- Live WebSocket delivery, subscription authorization, latency and client lifecycle remain untested. This result does not complete Task 1 or authorize expanding publication membership to routines/routine_versions.
- Next eligible unit within Task 1: test-project Storage bucket/policy reconciliation with explicit treatment of the supplied public buckets and broad authenticated write policies, followed by focused Storage API authorization tests. Edge Function authorization/delivery, sanitized backup/restore and two clean replay/restore passes remain outstanding. Production and application code remain untouched at this checkpoint.

### Test Storage buckets observed / policy stage prepared — 22 October 2026

- User screenshots show assignments/avatars/resources/timetables created in universe-timetable-test, all public, zero policies, size limit displayed as Unset (50 MB), MIME Any. Treat the displayed 50 MB as an effective service limit, not a bucket-specific limit; supplied source metadata has null bucket limits. No files were requested or observed uploaded.
- Prepared `supabase/reconciliation/005_test_storage_policies.sql` to recreate exactly the four supplied legacy storage.objects policies in the empty test project. Broad PUBLIC read and unrestricted authenticated writes are explicitly marked as insecure legacy behavior to reconcile, not endorsed target authorization. Stage requires four exact source-matching bucket settings, no existing bucket/object policies, no objects/Auth users, expected reconstructed public objects and unchanged managed Storage ownership/RLS. No Storage rows, grants, application code or production settings are changed by the script.
- Added `supabase/tests/reconciliation_stage6.sql`, rollback-only catalog assertions for exact buckets/settings, four source policy names/roles/commands/permissiveness/expressions and no bucket policies, managed ownership/RLS and empty object metadata. It does not upload/download files or prove Storage API authorization; that remains a subsequent unit using dummy files/controlled users.
- Static checks passed: all four generated policy statements match supplied catalog definitions; test/setup guards and transaction boundaries, absence of managed Storage row mutations/network calls and read-only test verified. Changed-file whitespace checks passed. SQL execution is pending; Task 1 remains incomplete.
- Next manual action only in universe-timetable-test: run stage-006 catalog test first (expect missing-policy error), run 005_test_storage_policies.sql, then rerun test and return result/error. If managed-table ownership prevents policy creation, report exact error; do not change owner/disable RLS. Keep project disconnected from the app and free of real files/users. Production policy hardening requires separate authorization.

### Hosted stage 006 result received — 22 October 2026

- User returned `PASS: stage 006 bucket and legacy Storage-policy catalog match; API authorization not tested`. Record user-executed catalog evidence for four exact buckets/settings, four legacy object-policy definitions with no bucket policies, managed Storage ownership/RLS flags and empty object metadata. No pre-install failure output was supplied; do not claim an observed red/green cycle.
- The replicated broad legacy permissions are not a security endorsement. This result does not prove upload/download/list/update/delete API behavior, owner isolation, or effective service-wide upload limits. Keep real files/users and application connections out of this disposable project.
- Next eligible unit within Task 1: prepare focused Storage API tests using controlled test identities and dummy files, including anonymous-write denial and explicit evidence of the legacy authenticated cross-owner write behavior, with API-based cleanup. Do not mutate storage.objects directly or claim broad legacy policies enforce ownership. Edge Function authorization/delivery, complete baseline fidelity, sanitized backup/restore and two clean replay/restore passes remain outstanding. Task 1 remains incomplete.

### Storage API probe prepared — 22 October 2026

- User screenshot shows the two requested controlled Auth users storage-a@example.invalid and storage-b@example.invalid in universe-timetable-test. No passwords/keys were provided or requested in chat. Read-only connector project listing confirmed test reference oqwvxplteqtlrhktsplj and Mumbai region; no database query or API mutation was executed by the agent.
- Prepared `tool/storage_api_probe.py`, Python-standard-library-only interactive probe pinned to that exact project reference. It rejects all other targets and privileged/non-public keys, suppresses response bodies/errors that could expose credentials, refuses redirects and noninteractive secret input, and uses only local hidden prompts for public key/passwords. Requests follow official storage-js upload/update/list/remove endpoints. Changelog markdown fetch failed; relevant endpoint conventions were checked against official source instead. No dependencies installed, application config changed or production access performed.
- Probe tests one dummy resource object in a random run-specific namespace: positive A upload/public credential-free download; anonymous upload/update denials and delete-no-effect; B cross-user list/update/delete reflecting the broad legacy permission gap. It checks downloaded bytes and actual resulting listings, not HTTP status alone. Deletes only the two exact attempted paths in finally and verifies an empty listing; prints a run-specific cleanup location on failure. Never deletes buckets, other paths or Auth users. A pre-existing namespace aborts before cleanup is enabled. API outcomes remain unverified until user runs it.
- Added `tool/tests/test_storage_api_probe.py`. Local TDD: four initial safety tests failed before implementation; passed after it; an additional existing-namespace deletion regression failed then passed after fixing cleanup guard placement. Final `python -m unittest discover -s tool/tests -v`: 5 passed. `python tool/storage_api_probe.py --help` passed. Changed-file whitespace checks passed; full git diff --check still flags unrelated pre-existing diagram/tool whitespace. These offline tests do not prove Storage API behavior.
- Next manual action: in a local interactive terminal run `python tool/storage_api_probe.py`, enter the confirmed test reference plus its publishable/legacy anon key and the two test passwords at hidden prompts, then return only printed PASS/FAIL/OBSERVED/CLEANUP output. Do not use secret/service-role keys or paste credentials into chat. If login fails, report the safe error; do not weaken Auth settings. Keep the two test accounts until results are reviewed; empty-auth fixture scripts (stages 004/005 policy setup) must not be rerun while these accounts exist. Task 1 remains incomplete.

### Hosted stage 007 Storage API result received — 22 October 2026

- User returned the complete successful probe output: A upload/public credential-free download passed; anonymous upload/update denied and delete had no effect; B could list, replace and delete A's dummy under the replicated legacy policies; exact dummy paths removed and run folder verified empty; final stage-007 PASS. Record as user-executed live Auth/Storage API evidence in the disposable test project, not production execution.
- The observed cross-user mutation is a confirmed legacy permission gap, not a secure ownership-isolation result. No production hardening was applied or authorized by this test. Evidence covers only the tested resources-bucket dummy operations, not every bucket, size/MIME limits or all Storage endpoints. The two controlled Auth users remain; object cleanup does not remove users/sessions. Do not run empty-auth fixture scripts until these test accounts are separately cleaned up.
- Storage catalog and focused API baseline checks now have supplied passing results. Next eligible unit within Task 1: reconcile executable Edge Function source and prepare isolated authorization/audience tests, addressing the known send-push caller-authorization gap without production deployment. Full baseline fidelity, notification delivery verification, sanitized backup/restore and two clean replay/restore passes remain outstanding. Task 1 remains incomplete.

### Local Edge Function source recovery — 22 October 2026

- Recovered executable local implementations in `supabase/functions/invite-admin/index.ts` and `supabase/functions/send-push/index.ts` by removing the outer comment layer only, preserving executable lines and dependency versions. Recovery aborted if unexpected executable/user-edited lines were present; neither file was modified in the starting git status. The send-push executable lines were compared with the supplied deployed-source attachment and matched. Invite-admin was recovered from the existing sketch previously compared with the user-pasted source; no independent exported invite attachment was available for automated full-source comparison.
- Added explicit source-recovery/runtime-status comments. send-push is prominently marked DEPLOYMENT BLOCKED because its supplied handler lacks caller authorization and observed legacy gateway verification was OFF. This unit does not fix that gap or authorize any deployment. Existing audience/pruning/invitation behavior was not redesigned. No functions invoked, secrets provisioned, webhook created or production settings changed.
- Verification: local executable-line/source-fidelity checks passed; `python -m unittest discover -s tool/tests -v`: existing 5 probe safety tests passed as regression only, not Edge Function behavioral evidence. Changed-function and plan whitespace checks passed. Deno is unavailable on PATH, so no TypeScript check or Edge Function runtime tests ran. Do not mark Edge Function acceptance complete.
- Next eligible unit: define and implement the send-push caller-authorization test contract in isolation, retain supplied source provenance, then prepare the reviewed test-only function deployment/audience checks. Do not deploy recovered legacy send-push as-is. Task 1 remains incomplete; full baseline fidelity, notification verification, sanitized backup/restore and repeated replay remain outstanding.

### Approved test-only webhook authorization gate implemented — 22 October 2026

- User approved the bounded dedicated-secret design in chat: test-only PUSH_WEBHOOK_SECRET plus x-webhook-secret, checked before parsing/query/FCM; reject absent/wrong caller secret and fail closed when server configuration is missing. No production rollout or deployment was authorized by that approval.
- Added dependency-free `supabase/functions/send-push/webhook_auth.js` and wrapped the recovered handler in index.ts. Missing/blank server secret returns generic 503; missing/empty/mismatched caller secret returns generic 401; only matching secret enters the handler. Bearer JWT alone is insufficient. Rejection responses contain no secret and are no-store. Configuration is read each invocation. Comparison scans all code units without early mismatch exit; JavaScript is not claimed formally constant-time. Generate a high-entropy dedicated secret for any subsequent test setup.
- Added portable `webhook_auth_test.js` with 11 cases: missing/blank server config, missing/empty/wrong/prefix/suffixed caller secrets, JWT-only denial, valid authorization, and fail-closed behavior after secret removal. Tests assert handler-call/body-read counters remain zero for rejected requests; no network/FCM dependencies are used.
- TDD: portable JS suite failed before implementation (protectWebhook undefined); after implementation 11 cases passed in the tool's isolated V8 engine, evaluating the actual helper and test source with ES-module import/export syntax removed solely for that runner. This is real helper execution, NOT Deno/HTTP/deployment verification. Node and Deno were unavailable on PATH; none installed. Source comparison also confirmed the original notification handler body unchanged inside the wrapper. Existing Python probe safety suite: 5 passed. Changed-file whitespace checks passed; repository-wide check continues to flag pre-existing unrelated whitespace.
- No secrets generated/provided, functions invoked/deployed, webhook created or database/production config changed. Authorization/audience/notification acceptance is still incomplete. Next unit: prepare safe hosted test-function deployment and API gate checks with no live webhook/FCM delivery; include webhook_auth.js alongside index.ts. Audience/delivery tests, invite-admin verification, full baseline fidelity, sanitized backup/restore and two replay/restore passes remain outstanding. Task 1 remains incomplete.

### Hosted webhook gate: missing configuration verified — 22 October 2026

- User screenshot shows separate send-push-auth-test in universe-timetable-test with index.ts and webhook_auth.js, followed by POST {} without x-webhook-secret returning HTTP 503 and `Webhook authorization unavailable`. Record this as user-executed hosted missing-server-secret fail-closed evidence. It demonstrates the custom rejection response is reachable; no database/FCM handler branch was entered by this guarded request. No claim of complete deployed-source identity or caller-secret cases is made.
- Next manual check: generate a dedicated random test secret locally, set only PUSH_WEBHOOK_SECRET in the test project's Edge Function secrets, and repeat POST {} without the header; expect HTTP 401 Unauthorized. Never share its value, provision FCM, create a webhook or change original UniVerse. Wrong/correct-secret checks remain after that; Task 1 remains incomplete.

### Hosted webhook gate: missing caller header verified — 22 October 2026

- After the test-secret setup instructions, user screenshot shows POST {} to send-push-auth-test with no x-webhook-secret header returning HTTP 401 and `Unauthorized`. Record this as user-executed missing-header rejection after configuration; no secret value was shared. Together with the prior 503, this supports the hosted fail-closed configuration/absent-header paths only.
- Next manual checks in the same test function: POST {} with x-webhook-secret set to an intentionally wrong non-secret value (expect 401 Unauthorized), then with the actual privately stored test secret (expect 400 No record). The authorized empty payload returns before database/FCM setup in the recovered handler. Do not supply a record, FCM credentials or a webhook; do not share the real header value in screenshots. Task 1 remains incomplete.

### Hosted webhook gate: wrong/correct caller header confirmed — 22 October 2026

- User reported both requested responses occurred as expected: POST {} with intentionally wrong x-webhook-secret returned 401 Unauthorized; with the privately stored correct secret returned 400 No record. Record as user-confirmed outcomes, not independently captured response bodies. No secret value was shared.
- Together with supplied 503 and missing-header 401 screenshots, the focused hosted gate checks now cover missing configuration, missing/wrong caller header, and successful authorization reaching empty-record rejection. The correct-header empty payload exits before database/FCM setup in the checked source. This does not establish audience selection, notification delivery, webhook integration, production remediation or complete handler safety. No real record/FCM/webhook was requested.
- Next eligible unit: isolated notification-audience tests using synthetic profiles/tokens and a substituted delivery dependency, followed by reviewed invite-admin authorization checks. Keep production untouched. Full baseline fidelity, sanitized backup/restore, two replay/restore passes and final reproducible setup remain outstanding; Task 1 is incomplete.

### Isolated legacy notification audience tests — 22 October 2026

- Extracted only the existing profile/token query sequence into `supabase/functions/send-push/audience.js`; index.ts now calls it and returns the same no-audience/no-token response reasons. Preserve truthy target checks, role/batch/section AND equality, all matched users' device tokens and propagation of database errors. No canonical scopes, shared-group or co-teacher behavior added. FCM setup/order, delivery and pruning remain unchanged.
- Added portable `audience_test.js` with six synthetic profiles/five device tokens and a fixture query adapter at the external Supabase boundary. Thirteen cases cover each dimension, combined filters, section isolation, multiple devices, tokenless users, unmatched/null data, legacy empty targets and both query-error paths. No live database, tokens, HTTP, OAuth or FCM delivery used.
- TDD: suite failed before resolver implementation (resolveNotificationTargets undefined), then 13 passed using actual helper code in isolated V8. The same 13 cases passed against the supplied legacy audience block after removing its two TypeScript-only map annotations and adapting empty HTTP responses to test result objects. Deliberately removing the role filter caused the suite to fail, confirming it detects broadened recipients. Gate regression: 11 passed. Python probe regression: 5 passed. FCM delivery/pruning source block comparison passed unchanged. Changed-file whitespace checks passed. No Deno TypeScript check or hosted audience query/delivery was performed.
- No deployment or production changes. Existing hosted send-push-auth-test remains at its previously tested two-file version; future deployment of current index.ts also requires audience.js alongside webhook_auth.js. Next unit: prepare isolated hosted audience checks without real delivery, then invite-admin authorization checks. Task 1 remains incomplete; notification delivery, full baseline fidelity, sanitized restore and repeated replay are still outstanding.

### Hosted synthetic audience probe prepared — 22 October 2026

- Prepared `supabase/functions/send-push/audience_probe.ts` for a separate send-push-audience-test function in universe-timetable-test. It reuses the approved secret gate, accepts only POST {}, runs the existing 13 synthetic audience cases and returns passed/data/delivery metadata. No Supabase client, network, OAuth, DB credential or FCM code is imported by this probe. Rejection occurs before body parsing for failed authorization; nonempty/invalid payloads reject. This is hosted synthetic coverage, not real database/audience or delivery verification.
- Moved the unchanged fixture suite into side-effect-free `audience_cases.js`; audience_test.js now only registers it with Deno.test. Probe deployment mapping: index.ts = audience_probe.ts, plus sibling audience_cases.js, audience.js, webhook_auth.js. Do not deploy production send-push/index.ts for this probe. Existing hosted auth-test and production are unchanged.
- Local isolated V8 execution passed: 13 audience cases, 11 gate cases, 8 actual probe-wrapper cases using substituted Deno env/serve and Response interfaces (two TypeScript parameter annotations removed for that runner). Cases include unconfigured/missing/wrong secret, method rejection, invalid JSON, real-record/array rejection and exact successful synthetic response. No network access was available to the test engine. Existing Python safety tests: 5 passed. Changed-file whitespace checks passed. No hosted probe deployment or Deno TypeScript check performed.
- Next manual action: deploy the four mapped files as send-push-audience-test only in universe-timetable-test; disable legacy gateway JWT verification only for this separate test function; POST {} with the existing privately stored test x-webhook-secret. Expect HTTP 200 with passed=13, data=synthetic_only, delivery=not_attempted. Return only status/body, never the header value. Task 1 remains incomplete; actual audience DB selection, invite-admin checks, delivery, complete fidelity and replay/restore remain outstanding.

### Hosted synthetic audience probe result received — 22 October 2026

- User returned `{ "passed": 13, "data": "synthetic_only", "delivery": "not_attempted" }` from the requested hosted-probe workflow. Record as user-supplied passing synthetic audience-suite result in the hosted environment; HTTP status was not separately supplied. No actual audience query or delivery is implied by this result.
- The fixture adapter substitutes Supabase and the probe has no database/network/FCM code. Actual database selection, real notification delivery, production webhook behavior and deployment/source fidelity remain outside this evidence. Production was not changed by this checkpoint.
- Next eligible unit within Task 1: prepare focused test-project invite-admin authorization checks with controlled identities and no invitation/email side effects for denial cases. Subsequent work still includes actual DB audience integration, delivery reconciliation, complete baseline fidelity, sanitized backup/restore, twice-repeated clean replay/restore and reproducible setup. Task 1 remains incomplete.

### Consolidated Task 1 handoff prepared — 22 October 2026

- Added planned `docs/backend-setup.md` as one three-part checklist: deploy recovered invite-admin only as test-only invite-admin-auth-test and run one denial probe; run one read-only test-catalog verification batch; run one read-only original-project sanitized current-schedule export. User can return all three outputs in one reply. No repeated prior gate/Storage tests or intermediate acknowledgments are required.
- Added `tool/task1_invite_checks.py`, reusing the existing pinned-project/hidden-input API client. Four requests cover absent header, invalid session and two ordinary callers. Every request body is {}, so no valid invitation recipient is ever supplied; exact handler error messages distinguish actual handler checks from gateway rejection. No function/SQL deployed or invoked by the agent.
- Added `supabase/tests/task1_catalog_checks.sql`, read-only, comparing supplied definitions for 161 columns, 45 constraints, 32 indexes, 50 public policies, seven non-extension application functions (definition/owner/settings/client EXECUTE), 18 RLS flags and 252 client privilege expectations. Preserves documented maintenance-grant differences and ignores obsolete physical column gaps. Includes prior Storage/Realtime catalog checks in the same batch. No pgTAP install or row writes. Full deployment identity/default privileges/managed schemas are not inferred from this check.
- Added `supabase/reconciliation/export_sanitized_schedule.sql`, single read-only source snapshot with deterministic within-export teacher aliases/remapped version keys, no original UUIDs/teacher names/codes/publisher IDs/notes, exact routine/version counts and MD5 of exported payload text. Retained display text requires user privacy review. This current-schedule fixture deliberately omits teacher profile FKs and is not a complete account/config/Storage backup; those limitations must not be hidden when assessing acceptance. No snapshot has been obtained or committed yet.
- Verification: three new invite-probe safety tests failed before implementation, then full `python -m unittest discover -s tool/tests -v` passed 8 tests. Probe --help passed. Static SQL/source checks confirmed expected metadata coverage, restricted grants, read-only statements and snapshot sanitization/checksum construction. Changed-file whitespace checks passed; repository-wide diff check still flags unrelated pre-existing whitespace. Hosted scripts and restore/replay remain unrun; Task 1 is incomplete.
- Next: receive the three checklist outputs, investigate any actual mismatch, validate snapshot checksum/counts and prepare guarded test-only restore/replay against that real sanitized fixture. Do not reset or delete anything before a concrete reviewed rehearsal is available. Remaining full-backup/deployment gaps stay explicit; two clean replay/restore passes remain required before actual Task 1 acceptance.

### Consolidated handoff results / catalog-checker fix — 22 October 2026

- User supplied all requested outputs: 4 invite-admin handler denial checks passed with empty payloads; catalog batch failed in columns; sanitized schedule snapshot attached. Record denial results as user-executed test-project evidence; no invitations were requested. Positive invitation/email flow remains outside this result.
- Root cause of the column failure was the checker, not schema drift: its explicit public,extensions,pg_catalog search path let pgcrypto's gen_random_uuid shadow the core function during deparsing, causing pg_get_expr to emit pg_catalog.gen_random_uuid(). Confirmed using a read-only catalog query against the confirmed test project only. Corrected transaction-local precedence to pg_catalog,public,extensions; no database defaults, expected metadata or persistent config changed. Re-ran the entire strict batch via the test-project connector: PASS for baseline catalog fidelity, restricted grants, Storage and Realtime. No user rerun is required. Existing assertions served as the observed failing/passing regression; comparisons were not weakened.
- Validated attached snapshot locally: MD5 07da7d69a5d0b0dd816133f41716eae7 matches exact UTF-8 payload, 795 routines, four version metadata records, one active version, complete sequential fixture row keys, all version references resolve, teacher labels are synthetic and no original UUIDs appear. Historical version metadata counts are not historical snapshots. Teacher FKs/publisher IDs/notes remain omitted as declared; not a full account/config/Storage backup. Snapshot has not been restored or committed.
- Verification: full hosted read-only strict catalog batch passed; snapshot structural/checksum checks passed; Python regression suite 8 passed; changed-file whitespace checks passed. No test/production row writes or deployment performed by the agent. Task 1 still requires actual restore/replay evidence and explicit treatment of remaining backup/deployment limitations.
- Next eligible unit: prepare the guarded rollback-only restore/replay rehearsal using the validated 795-row sanitized fixture, preserving the current test-project setup and controlled users. No destructive reset is authorized by these results. Keep production untouched; do not start Task 2 before Task 1 acceptance.

### Guarded rollback-only replay/restore rehearsal prepared — 22 October 2026

- Added `tool/build_replay_rehearsal.py` and generated `supabase/tests/task1_replay_rehearsal.sql` from the validated user-supplied sanitized snapshot and current baseline stages. It never executes SQL. Preserves existing user edits to source stages. Embedded fixture contains 795 sanitized routine rows/four metadata versions; no original UUIDs/teacher names/codes are retained. Source snapshot limitations stay embedded.
- Rehearsal uses a fresh timetable_replay schema and timetable_replay_publication inside one transaction, namespace-adapts stages 001-004 without moving/installing extensions, restores deterministic synthetic row/version IDs with teacher/publisher FKs omitted, verifies every projected field/count and checksum, runs adapted strict catalog/Realtime assertions, rolls back and checks scratch absence. No DROP/RESET/COMMIT, Auth writes, managed Storage mutations, existing publication changes or public-table writes are performed. Guards refuse populated public tables/Storage, existing scratch objects, unexpected baseline or vector version. Existing test identities stay intact.
- Namespace adaptation is intentional and must not be described as exact public-namespace or fresh hosted-project replay. Test-only client maintenance-grant differences remain explicit. This is limited current-schedule restore, not full accounts/config/Storage recovery; historical version metadata cannot reconstruct deleted rows. Task 1 acceptance still needs honest treatment of these gaps.
- Read-only preflight additionally found vector 0.8.2 installed in the test project, versus 0.8.0 in supplied source metadata. Updated only the rehearsal guard to match the observed test runtime and recorded this environment difference; no extension change attempted. Existing strict schema/index catalog comparison had passed against that runtime. Do not claim exact extension-version reproduction.
- TDD: four builder safety tests failed before implementation; full Python suite then passed 12 tests, including checksum-tamper/original-identity rejection, role/managed-schema preservation and rollback/no-drop/no-commit output. Generator successfully produced the actual fixture rehearsal. Changed-file whitespace checks passed. Test-project read-only preflight checked known counts/scratch absence/Storage emptiness/vector version; no rehearsal executed by the agent and no hosted restore success claimed.
- Updated docs/backend-setup.md with one manual instruction: run the complete rehearsal twice in universe-timetable-test as postgres, return both final results (795 routines, four versions, MD5 07da7d69a5d0b0dd816133f41716eae7). Stop on errors without modifying guards or deleting anything. Task 1 remains incomplete; assess actual results and remaining full recovery/deployment evidence before Task 2.

## Task 2 — Canonical departments, terms, faculty, rooms and student groups

### Source recovery checkpoint - 22 October 2026

**Reconciliation decision checkpoint (22 October 2026):** completed the bounded,
read-only reconciliation analysis and generated .task1-local/task2-private-decision-report.md.
No application code, database rows, migrations, or schema definitions were modified.

- **Actual progress:**
  - 100% cell coordinate alignment achieved: all 795 parsed routine rows and all
    191 review queue rows were mapped to their exact worksheet name, column, and
    row coordinates in .task1-local/source-795.xlsx.
  - Grouped the 36 ambiguous stored rows by candidate relationship:
    - 16 pairs (32 stored routine IDs) represent intra-day multi-period class
      sessions (such as 2-hour labs) located on the same Excel row in adjacent
      period columns. Each stored routine record matches one of the two period
      slots 1-to-1 by start/end time.
    - 2 pairs (4 stored routine IDs) represent an authentic duplicate entry in
      the workbook (Sunday Row 70 and Sunday Row 73, Retake DLD). Both source rows
      and both database records per slot have identical fields; they are symmetrical
      and remain unresolved duplicates.
  - Formulated a 5-way separation of concerns: 640 exact source matches; 29
    parser-related late-night starts (28 in queue + 1 ambiguous; parser fixed in
    memory, database repair pending authorization); 96 explicit source AM noon-end
    intervals (91 in queue + 5 ambiguous; source typo in 11:10 - 12:15 AM,
    requiring source-owner confirmation); 36 ambiguous occurrences; and external
    catalog gaps (356 unmatched faculty rows, 127 unmatched room rows, and deferred
    academic calendar progression).
  - Consolidated all pending choices into 7 concrete, issue-grouped decision questions
    for user and routine committee review.
- **Files changed:**
  - .task1-local/task2-private-decision-report.md (new, gitignored)
  - .task1-local/generate_decision_report.py (diagnostic helper, gitignored)
  - docs/superpowers/plans/2026-10-20-university-timetable.md (updated this checkpoint)
- **Verification performed:**
  - Source workbook hash verified before and after inspection: SHA-256
    466157f8d40742f247f79376e8d2ffc522f156b0bf39853a2fb0675b0ff56542 (295,039 bytes,
    openpyxl read-only; never saved or recalculated).
  - Approved routine export verified: exactly 795 unique routine UUIDs.
  - Four reconciliation buckets verified: 640 + 91 + 28 + 36 = 795.
  - Review queue verified: 191 lines, 155 distinct routine UUIDs; all routine IDs exist
    in approved export, all candidate parsed row indices in bounds [1, 795].
  - 100% cell coordinate alignment verified across all 795 parsed rows.
  - Private deliverables verified gitignored under .task1-local/.
  - No database writes, production contact, or runtime code modifications occurred.
- **Remaining blockers:**
  - Source-owner written confirmation for the 96 explicit AM rows (11:10 - 12:15 AM).
  - Administrative authorization for database repair of the 29 parser-discrepancy
    rows (23:10:00).
  - Administrative decision on the duplicate Sunday Retake DLD entries (Row 70 vs 73).
  - Administrative provision of faculty and room alias mapping tables (356 faculty gaps,
    127 room gaps).
  - Formal academic calendar configuration (deferred per user clarification override).
  - Task 2 is NOT marked fully complete.
- **Next bounded task:**
  - Review the decision report with the user / routine committee to resolve the 7
    decision issues before authoring any canonical backfill migration.

**Prior continuation context:** the user explicitly authorized the private export.
The approved routine fields were exported into ignored
.task1-local/task2-approved-routine-identities.json; 795 distinct canonical
UUIDs and the exact approved field set were checked. The rejection/approval
history below is resolved; no further permission for this same local export is
needed. No hosted write was made.

Private reconciliation against the recovered workbook accounts for all rows:
640 unique source identity-label matches with equal times; 91 unique matches
with the source's reversed AM interval; 28 unique matches with parser-related
time differences; 36 ambiguous source occurrences. The ambiguous bucket includes
the remaining time anomalies; do not sum these status buckets with the separate
96/29 anomaly totals as if they were disjoint. Source matches use day, batch,
section, course, room and original teacher code, not inferred semester/stage.
These are source matches, not applied canonical foreign keys.

The private actionable review queue is
.task1-local/task2-private-review-queue.csv. Source indices in it refer to
normalized parsed rows, not original Excel cell coordinates. The downloaded
original is .task1-local/source-795.xlsx. Both and the private JSON artifacts
are gitignored; no original IDs/teacher codes were placed in the public summary.
The summary remains 	ask2-backfill-status.json in the audit directory.

The recovered source teacher rosters cover 625 parsed rows and omit codes used
by 170; its room legend covers 234 and omits names used by 561. These are source
coverage checks, not an intersection with the separate live catalog checks
(356 unmatched teacher rows, 127 unmatched room rows). Missing legend entries
alone do not establish invalid rooms. Do not invent person aliases or room
permissions to fill gaps.

**Completion boundary:** safe read-only source/identity reconciliation is done.
Actual canonical mapping acceptance is still incomplete: catalog gaps and
ambiguous occurrences need verified resolution; explicit AM source values need
source-owner correction before data repair; the existing mapper's term/stage
requirements cannot be met by inventing the deferred calendar configuration.
Do not silently waive that acceptance item or claim full Task 2 completion.
Next task is review of this concrete queue and a source-revision scope contract,
not another generic request to locate the already recovered workbook.

Verification: approved-export structure/hash/unique-ID checks passed; gitignore
checks passed for all private artifacts; python -m pytest
engine/tests/test_legacy_mapping.py -q passed 3 tests. Current parser source
probe passed and produced exactly 795 rows. No schema/authorization/runtime code
changed during this continuation and no stored row was rewritten.

Read-only connected metadata recovered the actual 795-row upload: original name
`DOC-20261009-WA0035.xlsx`, stored as
`timetables/CSE_Routine_Summer_2025_1791562982460.xlsx`, 295039 bytes, SHA-256
`466157f8d40742f247f79376e8d2ffc522f156b0bf39853a2fb0675b0ff56542`.
Its banner says Fall-2026 despite the saved Summer 2025 metadata. The file was
downloaded only into ignored `.task1-local/source-795.xlsx` and inspected without
modifying it. This supersedes the missing-source explanation below; the earlier
Summer 2025 source comparison remains historical evidence only.

The fixed current parser produces exactly 795 rows. Of the original 125 time
anomalies, 96 are reproduced from explicit AM noon-end headers on Sunday through
Thursday; 29 become 11:10-12:15 from Friday/Saturday PM headers after the parser
fix. Preserve the 96 raw source values pending a reviewed source correction;
do not silently assume PM or change stored rows. The other 29 historical stored
values also remain untouched. No historical backfill/repair has been applied.

Read-only aggregate catalog checks: only 439 of 795 routine rows have a teacher
code matching the existing faculty catalog; 356 do not. Room names match the
catalog for 668 rows; 127 do not. These are exact-label checks, not approved
identity links. The recovered Teacher Information acronym is column E, not the
older seed script's column C: do not blindly reuse old column bindings. Private
contacts in that sheet are irrelevant and must not be included in reconciliation.

Automatic approval review rejected export of the 795 production records because
it includes sensitive IDs, schedules, rooms and teacher codes. Explicit user
approval for a private, ignored local identity export has been requested and is
pending. Do not bypass that rejection. Aggregate queries and source inspection
completed without hosted writes. After approval, the next task is a bounded
local identity/catalog reconciliation against the recovered source, with tests;
unverified new identities, semester/calendar mappings and source time corrections
must not be guessed. Task 2 remains unaccepted until actual mapping acceptance
or an explicit reviewed scope deferral; do not claim it complete from synthetic
mapping tests alone.

**Current acceptance status (22 October 2026): implementation complete;
actual-data reconciliation blocked, so Task 2 is not fully accepted.** This
supersedes older calendar-approval explanations below. No missing calendar
configuration is being invented or required for the present audit.

The latest read-only source comparison is recorded in
`docs/timetable-audit-2026-10-20/task2-backfill-status.json`. The supplied
Summer 2025 distribution has numeric batches 58-66; the sanitized snapshot has
61-69. Only 18 of 795 stored rows share the same exact batch/section/course
labels; 777 do not. Label agreement is not identity verification. Source
combined labels include batch 58 B+C, while snapshot combinations include
65 E+F, 67 F+G and M. Sc 6+7. Do not transfer membership across these labels.
The snapshot deliberately omits original routine UUIDs and pseudonymizes teacher
codes, so it cannot supply the original identities required by approved mapping
batches. No source or database records were rewritten during this comparison.

**To finish the outstanding checklist item:** obtain the matching distribution
and a private identity-preserving export/mapping for the actual routine/faculty
records (IDs and original teacher codes, no credentials), then prepare and review
canonical links in the isolated runtime. Verify every linked FK, source-row
equality, counts and idempotency before considering hosted application. The
existing 795-row sanitized snapshot remains a restore fixture, not a source of
original identities. Do not mark the mapping checkbox complete or substitute
synthetic test identities. Parser fixes do not remove this data prerequisite.

**Objective:** Separate identifiers from display strings before expanding scheduling.

**Files:** Create `lib/core/models/academic_model.dart`, `lib/features/admin/services/academic_config_service.dart`, `engine/domain.py`, `engine/tests/test_domain.py`, `test/academic_model_test.dart`, `supabase/tests/academic_domain.test.sql`; add CLI-generated catalog/membership migrations. Modify `profile_model.dart`, `routine_model.dart` additively and `timetable_config_service.dart`.

**Dependencies:** Task 1; verified source identities/aliases for actual backfill. Formal academic-calendar rollout is deferred. Preserve existing local catalog carriers without inventing institutional dates or current study stages.

**Interfaces:** `NormalizedInput`, `Offering`, `TeacherAssignment`, `StudentGroup`, `Room`, `SourceRef`, `PolicySnapshot`, `Assignment`, `ValidationIssue`, `ValidationReport` typed records in `engine/domain.py`. JSON uses snake_case and `schema_version: 1`. IDs, minutes, dates and required revisions match the spec.

- [x] Test distinct scoped `66/A` labels, cohort-owned sections with one or multiple sections, new intake and graduation/archive; B+C links to two atomic groups; mixed calendars use explicit cohort-term progression, not batch arithmetic.
- [x] Add nullable canonical references beside legacy fields and scoped memberships with RLS.
- [ ] Reconcile actual CSE source identities through a reviewed source-revision mapping; hold unresolved links and stored clock anomalies without declaring the source invalid. Formal calendar rollout is deferred; do not force it to unblock this audit.
- [x] Expose catalog reads/edits through the service layer; preserve current profile IDs and roles.
- [x] Run `python -m pytest tests/test_domain.py -q` from the engine environment, `flutter test test/academic_model_test.dart`, and database tests in the isolated runtime.

**Acceptance:** No legacy row lost; all mapped FKs resolve; alias ambiguity blocks approval; every new scope has a distinct canonical key. If nullable scope dimensions are used, uniqueness must treat nulls consistently, not allow duplicate null scopes.

**Risk/rollback:** Incorrect identity matching. Disable new catalog UI, retain labels and mapping provenance; additive tables remain safe to inspect.

### Task 2 first slice - canonical catalog contract (22 October 2026)

Task 2 is **in progress**, not complete. Added immutable `AcademicCatalog`
records in `engine/domain.py` and `lib/core/models/academic_model.dart`, using
one synthetic JSON fixture in `test/fixtures/academic_catalog_v1.json`.
Both sides strictly require `schema_version: 1`, snake_case fields, canonical
UUIDs, ISO date-only values, exact field names and explicit nullable values.

- Catalog records cover departments, programs, calendars, academic years/terms,
  cohorts, atomic student groups, explicit cohort-term study stages, faculty,
  rooms, nullable-program scheduling scopes and reviewed group aliases.
- Program/cohort keys disambiguate identical `66/A` labels. Reviewed `B+C`
  aliases contain two explicit atomic IDs; unknown, unreviewed, ambiguous or
  cross-cohort aliases fail. No string splitting or batch arithmetic is used.
- New intakes may have one or many sections. Lifecycle status/effective dates
  preserve existing group identities; graduation rules are not inferred.
  Programs/cohort terms must agree on calendar, with no fixed yearly term count.
- Duplicate scopes also reject when program_id is null. Unknown room capacity
  stays null. Existing faculty/room IDs are input identities, not display labels.
- Python and Dart share explicit Unicode White_Space-plus-BOM edge trimming;
  a review-discovered whitespace parity defect was reproduced with a failing
  Python regression and corrected on both sides.
- Verification: **21 new Python domain tests passed**; with the existing semester
  shape regression suite, **38 passed**. **Eight Flutter model tests passed**;
  targeted Dart analysis found no issues; changed-file whitespace checks passed.
  Initial Python tests failed before the models existed. Initial Flutter test
  attempts were blocked by SDK/local-state permissions; the successful retry used
  the permitted tooling access, so no Flutter red/green claim is made.
- Focused independent review found the whitespace issue above and no additional
  reference/lifecycle/null-scope defects in this slice. No database, Auth,
  production, existing profile/routine fields, solver or ingestion path changed.

**Next Task 2 unit:** additive catalog/membership schema and local RLS/FK tests,
followed by service adapters and nullable legacy references. Real CSE backfill
still requires reviewed aliases/calendar evidence; synthetic test fixture values
are not approved institutional mappings. `NormalizedInput`/offering/assignment/
validation records remain for subsequent slices, using this catalog foundation.

### Task 2 remaining implementation (22 October 2026)

Completed the additive schema, capability memberships/RLS, catalog service,
nullable legacy references and schema-v1 engine interface records. Added
transactional alias save/review, immutable approved mapping batches, strict
source-row verification and quarantine assessment. Existing solver/ingestion
and publication behavior remains unchanged. `PolicySnapshot` is an identity
carrier; academic policy approval remains Task 3 work.

Verification: full Python regression suite passed 174 tests with one optional
full-workbook solve skipped; subsequent carrier/quarantine suite passed 34 tests
(including an additional policy carrier test). Full Flutter suite passed 72 tests;
targeted Dart analysis passed. Tool safety tests passed 18 tests. Isolated local
Supabase rebuilds passed the original 44 baseline and 61 academic pgTAP tests,
with exact preservation of all 795 legacy routine rows. Review found and fixed
a mixed-calendar snapshot visibility defect; the regression checks calendar
closure for a program-scoped member.

**Acceptance remains pending only for real reviewed CSE backfill:** the user
confirmed academic decisions are not approved. The sanitized assessment holds
795 rows and applies zero mappings; 125 anomalous stored intervals remain (source validity/root-cause attribution is not established for all rows)
unchanged. See `task2-backfill-status.json` and `docs/backend-setup.md`. Synthetic
approved mapping tests are evidence for the implementation, not institutional
approval or proof of an actual hosted CSE backfill. No hosted migration executed.

## Task 3 — Versioned academic policy and requirement approval

**Objective:** Make verified timing/duration/meeting policy explicit and enforceable. Formal term structure, admission/graduation automation and calendar rollout are deferred; the bounded parser investigation above takes priority.

**Files:** Create `engine/policy.py`, `engine/tests/test_policy.py`; modify `timetable_config_model.dart`, `timetable_config_service.dart`, `timetable_settings_controller.dart`, `timetable_settings_screen.dart`, `test/timetable_settings_test.dart`; plan policy revision storage only when the next implementation scope is approved; calendar migrations are deferred.

**Dependencies:** Applicable verified distribution/timing configuration and Task 2 identity compatibility review. Do not require a fabricated term/date model for parser correctness work.

**Interfaces:** `validate_policy(policy: PolicySnapshot) -> list[ValidationIssue]`; `approve_requirements(input: NormalizedInput, policy: PolicySnapshot) -> ValidationReport`.

- [ ] Test verified summer/winter timing revisions, attached/spaced meridiems, numeric cell times, header/config mismatch and same-day intervals; diagnose ingestion defects before classifying source rows. Arbitrary terms/year tests belong to the deferred calendar work.
- [ ] Test 38 classes at fixed 2/week over 14 weeks blocks unless the academic requirement itself has been formally amended; test unresolved 1.5 hours versus 75 minutes blocks.
- [ ] Plan immutable timing/source revisions from existing settings without rewriting published rows. DEFER teaching-date calendars, admission/progression/graduation automation and calendar migrations until required and verified.
- [ ] Edit policy in the existing settings flow; preserve `ClockTime` boundaries (`HH:MM` engine, `HH:MM:SS` legacy DB).
- [ ] Run targeted Python/Dart policy tests and database policy immutability/authorization tests.

**Acceptance:** All mandatory counts/durations have explicit provenance; no unknown setting silently ignored; policy edits invalidate dependent approval.

**Risk/rollback:** Academic policy mistaken for software defaults. Keep old policy revision active until approved; rollback by selecting/reviewing a previous policy revision, not erasing history.

## Task 4 — Safe staged Excel ingestion

**Objective:** Turn workbook evidence into an approved domain snapshot.

**Files:** Create `engine/import_pipeline.py`, `engine/tests/test_import_pipeline.py`, sanitized `engine/fixtures/imports/` fixtures, `lib/features/admin/controllers/timetable_import_controller.dart`, `lib/features/admin/screens/timetable_import_review_screen.dart`; modify `engine/ingest.py`, `engine/main.py`, generation/upload services; add private-import/staging migrations.

**Dependencies:** Tasks 2–3; source retention and mapping approval. No raw workbook fixture committed.

**Interfaces:** `inspect_workbook(data: bytes, limits: ImportLimits) -> WorkbookInventory`; `normalize_import(data: bytes, mapping: MappingProfile, context: ImportContext) -> StagedImport`. Supporting typed records live in `engine/import_pipeline.py`; resulting approved snapshot is `NormalizedInput`.

- [ ] Test ZIP expansion/cell limits, macro/embedded-object rejection, malformed XML, ambiguous/missing headers, missing/error formula caches and reordered columns.
- [ ] Test every candidate row ends in retained/merged/approved-excluded/blocking status; retain a valid blank-teacher course as pending, distinguish missing course data and unknown nonblank teacher, and apply the approved pending-assignment gate.
- [ ] Reuse the CSE row-5 adapter; retain authoritative teacher cells and all merged-row provenance. Resolve rare source-backed B+C into both atomic groups; never manufacture combinations in routine UI. Preserve duplicate versus split/co-teacher distinctions.
- [ ] Persist private original/hash and staged issues; require committee decisions before input approval.
- [ ] Run `python -m pytest tests/test_import_pipeline.py tests/test_ingest.py -q`; test Dart review state and Storage negative access.

**Acceptance:** Historical source yields measured 325 offerings/656 derived sessions before policy resolution; every exclusion is visible. Same hash+mapping+scope import is idempotent. No link/macro/formula execution.

**Risk/rollback:** Changes to legacy interpretation. Keep adapter version and frozen raw bytes; reject rather than guess; retain legacy parser for supervised comparison.

## Task 5 — Independent interval validator

**Objective:** One correctness definition for generated, uploaded and manually edited drafts.

**Files:** Create `engine/validation.py`, `engine/tests/test_validation.py`; modify `engine/solver.py`; add validator-attestation schema with worker-only write permission.

**Dependencies:** Approved input/policy contract from Tasks 2–4.

**Interface:** `validate_schedule(input: NormalizedInput, assignments: list[Assignment], external_reservations: list[Reservation]) -> ValidationReport`; `Reservation` is defined in `engine/domain.py`. Report includes hard errors, preferences, complete counts and bounded examples.

- [ ] Convert the six existing gap probes into tests expecting rejection under the new contract.
- [ ] Assert half-open adjacent periods are allowed, partly overlapping periods reject, and B+C conflicts with either member.
- [ ] Assert unknown/inactive faculty, missing mandatory room capacity, incomplete contact time and stale policy revisions reject.
- [ ] Validate every teacher/group link and actual teaching date; distinguish proven infeasibility from time-budget exhaustion.
- [ ] Run `python -m pytest tests/test_validation.py -q` and differential legacy fixtures; store reports bound to input/policy/draft/resource hashes.

**Acceptance:** All six demonstrated invalid cases fail with stable rule IDs; a known valid fixture passes; changing any bound revision invalidates attestation.

**Risk/rollback:** False positives from unresolved policy. Use shadow reports until approved, but never publish a known new hard violation.

## Task 6 — Generalize CP-SAT and bound durable jobs

**Objective:** Add resource eligibility and mixed calendars without replacing the solver.

**Files:** Modify `engine/solver.py`, `engine/main.py`, `requirements.txt` and deployment config as justified; create `engine/jobs.py`, `engine/tests/test_jobs.py`, `engine/tests/test_multi_department.py`; add job/lease tables; update `timetable_engine_service.dart`.

**Dependencies:** Tasks 2–5; hosting budget and authenticated test identities.

**Interfaces:** `solve_schedule(input: NormalizedInput, policy: PolicySnapshot, pinned: list[Assignment], budget_seconds: int) -> SolveResult`; `SolveResult` in domain.py contains status, candidate assignments, objective/bound and report. Jobs expose persisted state behind existing status polling.

- [ ] Test actual interval conflicts across department grids and date-overlapping terms; disjoint terms may reuse a room.
- [ ] Test eligible-room capacities/equipment and all assigned co-teachers; represent unassigned teachers explicitly without fictitious reservations, subject to the approved generation/publication policy.
- [ ] Add candidate room choices/intervals and pinned placements; keep hard/soft semantics explicit.
- [ ] Verify JWT and membership, bound admission/uploads/solve time, persist leases and idempotent requests; test worker restart and expired lease.
- [ ] Run `python -m pytest tests/test_jobs.py tests/test_multi_department.py tests/test_solver.py -q` plus representative two-worker performance fixture.

**Acceptance:** Valid schedules have zero hard conflicts under independent validator; UNKNOWN never labeled proven INFEASIBLE; unauthorized job/result access denies; job survives restart or reports a recoverable failure.

**Risk/rollback:** Variable growth/hosting memory. Keep deployment concurrency bounded and feature-gate new solver mode; continue supervised legacy scope until performance gates pass.

## Task 7 — Scoped atomic publication and immutable recovery

**Objective:** Prevent cross-department replacement, stale writes and unvalidated active schedules.

**Files:** Add schedule-version/reservation/outbox/publication migrations and `supabase/tests/publication.test.sql`; modify `timetable_engine_service.dart`, `routine_service.dart`, generation/upload controllers and `test/publish_gate_test.dart`.

**Dependencies:** Tasks 1–6; new tables and trusted validation worker.

**Interfaces:** `publish_schedule_version(version_id, expected_scope_revision, request_id)` and `save_schedule_draft(version_id, expected_revision, patch, request_id)` exactly as migration spec. Return typed publish result including event/version/revision.

- [ ] Database tests: publish A then B in different scopes preserves A; invalid row halfway through leaves prior pointer/reservations unchanged.
- [ ] Test concurrent same-scope publishers yield one success and one stale-revision error; cross-scope room conflicts reject atomically.
- [ ] Test lost-response replay returns same publication/event; direct writes and forged validation fail for all client roles.
- [ ] Implement locked publication, exclusion constraints, immutable entry history, outbox and legacy projection.
- [ ] Route all producers through the API; block absent validation, remove manual active-row writes after compatible client rollout.

**Acceptance:** Zero mixed versions observed by snapshot readers; previous versions remain reconstructable; one logical outbox event per request; no supported UI/API bypass.

**Risk/rollback:** Legacy client global-write calls. Keep reads compatible, disable legacy admin writes at cutover; after multi-department launch never roll back to the global-delete RPC.

## Task 8 — Committee review, manual pins and revision UI

**Objective:** Preserve human control through auditable draft operations.

**Files:** Create `lib/features/admin/services/schedule_draft_service.dart`, `controllers/schedule_review_controller.dart`, `screens/schedule_review_screen.dart`, `test/schedule_review_test.dart`; modify routine hub, management and grid screens.

**Dependencies:** Tasks 5–7; agreed committee capability policy.

**Interfaces:** `ScheduleDraftService.save(versionId, expectedRevision, patch, requestId)`, `validate(versionId)`, `submit(versionId, expectedRevision)`, `approve(versionId, expectedRevision, reason)`, `publish(...)`; methods return typed revision/state/errors.

- [ ] Test edit-after-approval invalidates approval, two-device edits expose a conflict, and readonly committee roles cannot save.
- [ ] Add draft differences, source issues, validation explanations, reasons, review and publish states to the existing hub.
- [ ] Add pin/unpin with reasons; regenerate as child draft and retain pins or report an explicit infeasible pin set.
- [ ] Test clone/revise/rollback and later teacher assignment create revisions, leave published history untouched and revalidate against other scopes.
- [ ] Run `flutter test test/schedule_review_test.dart` and role-based database workflow tests.

**Acceptance:** No committee edit mutates a published version; approval binds exact revision; an invalid hard constraint has no “publish anyway” action.

**Risk/rollback:** Workflow overhead. Keep old viewer intact; disable new edit capability while preserving saved drafts.

## Task 9 — Compatible readers, dates, exceptions and availability

**Objective:** Make published semantics reach the existing application correctly.

**Files:** Modify routine/dashboard/teacher/rooms/find_teacher services and controllers, `profile_model.dart`, resource semester selection and notification audience model; create `lib/core/services/availability_projector.dart`, `test/availability_projector_test.dart`; add exception/manifest RPCs.

**Dependencies:** Tasks 2, 7–8; tested CSE compatibility and directory access policy.

**Interfaces:** `AvailabilityProjector.project(snapshot, campusNow)` is pure; `fetchScheduleManifest()` returns authorized version/reference revisions and a consistent exception cursor.

- [ ] Test B and C both see B+C; every scheduled co-teacher sees assigned weeks; other departments with same labels do not leak.
- [ ] Apply holidays, term dates, cancellations and relocations consistently to routine/dashboard/room/teacher views.
- [ ] List authorized unused rooms/faculty distinctly from missing data; calculate class boundaries in campus timezone.
- [ ] Retain/dispose subscriptions and boundary timers; avoid fetching again for every payload and preserve search filters.
- [ ] Run `flutter test test/availability_projector_test.dart` plus device regression through auth, routine, resources, notices and profile.

**Acceptance:** Boundary change within one second; cancellation visible in all relevant views; no old-client label collision at rollout.

**Risk/rollback:** Changed reader audience semantics. Roll back to the last scope-aware reader; never expose ambiguous university rows to old clients.

## Task 10 — Generic export and safe rendered-workbook import

**Objective:** Remove CSE layout limits without breaking historical exports.

**Files:** Create `engine/export.py`, `engine/tests/test_generic_export.py`; modify `engine/render.py`, `routine_workbook_parser.dart`, upload controller/screen; create `test/routine_workbook_parser_test.dart`.

**Dependencies:** Tasks 4–8.

**Interfaces:** `render_schedule(version: PublishedSchedule, layout: ExportLayout) -> bytes`; types live in export.py; imported rendered assignments are staged against a `NormalizedInput`, never directly published.

- [ ] Test 100+ cohorts, eight or more periods, two departments, nonnumeric intake labels and Unicode course names without dropped cells.
- [ ] Implement generic tabular/department exports; keep the CSE template adapter for supported historical layout.
- [ ] Include version/term/timezone provenance; escape formula-leading untrusted text; no source macros or external links.
- [ ] Test import/export row reconciliation and rendered uploads with unequal start times that overlap.
- [ ] Run Python export tests and `flutter test test/routine_workbook_parser_test.dart`.

**Acceptance:** Exported assignment counts match source exactly; legacy template overflow is explicit; uploads cannot bypass common validation.

**Risk/rollback:** Spreadsheet presentation expectations. Retain legacy export option; exports do not alter published data.

## Task 11 — Read-only offline snapshots and recoverable synchronization

**Objective:** Support cold-start offline viewing without cached administrative authority.

**Files:** Create `lib/core/services/schedule_repository.dart`, `schedule_local_store.dart`, `schedule_sync_service.dart`, `test/schedule_repository_test.dart`, `integration_test/offline_schedule_test.dart`; modify `main.dart`, auth controller/router, relevant feature services; add secure key storage dependency only after platform review.

**Dependencies:** Tasks 7 and 9; manifest/delta endpoints, approved cache grace/retention.

**Interfaces:** `ScheduleRepository.watchAuthorizedSnapshot()`, `refresh()`, `clearForSignOut()`; `ScheduleSnapshot` contains account/scope/schema/permission epoch, publication hashes/counts, exception cursor and last successful sync time.

- [ ] Test offline cold start after sync, no-cache first launch, transport error versus 401/403, expired seven-day grace, logout and account switch during sync.
- [ ] Implement immutable staged local snapshots and crash-recoverable activation; validate checksums before replacing a good cache.
- [ ] Add incremental changed-version download and exception tombstones; force full snapshot if cursor expires.
- [ ] Revalidate on resume/reconnect; Realtime/FCM trigger refresh hints; add 30-second fallback and 60-second stale indicator.
- [ ] Benchmark Hive with campus fixture; use SQLite behind the same interface only if justified. Run `flutter test test/schedule_repository_test.dart` and device offline integration tests.

**Acceptance:** Corrupt/interrupted download never removes last good data; zero cross-account rows; offline administration disabled; foreground freshness and load targets met.

**Risk/rollback:** Cache confidentiality or startup regression. Feature-disable offline mode, purge only owned cache, preserve server data and online auth behavior.

## Task 12 — Staging pilot, migration rehearsal and controlled rollout

**Objective:** Demonstrate the complete system under realistic scale and recovery conditions.

**Files:** Update `README.md`, `CLAUDE.md`, `docs/backend-setup.md`; create `docs/timetable-rollout.md`, `engine/tests/test_scale.py`, `integration_test/timetable_workflow_test.dart`; complete CI.

**Dependencies:** Tasks 1–11, actual departmental inputs and authorized staging identities.

- [ ] Run full Flutter/engine/database suites; run supported Android device flows and recovered FCM integration.
- [ ] Rehearse CSE backfill, concurrent publication, failed publish, notification retry, old-client gate, offline reconnection and rollback.
- [ ] Meet the quantitative gates in the testing report; capture solver feasibility rate, p95 time, peak RSS and sync latency on declared hardware.
- [ ] Pilot CSE plus one department with shared teachers/rooms and a different calendar; obtain committee acceptance of actual output.
- [ ] Present migration diff, backups, rollback evidence and rollout schedule for explicit production approval.

**Acceptance:** No unresolved Critical/High publication or authorization issue; academic approvers sign off fixture/output mappings; restore and scope-safe rollback demonstrated.

**Risk/rollback:** Unknown campus scale or operational practices. Keep second-department publication disabled until gates pass; use compatible last release and immutable snapshots for recovery.

## Checkpoints

2 November 2026 priority override: the user requested the actual Flutter advisor
showcase before broad production hardening. Completed the bounded
[showcase plan](2026-11-02-advisor-showcase.md). Two real Android file-picker →
local engine → validation → grid runs produced 682 Summer and 796 observed Fall
meetings, with exact draft/source reconciliation. An impossible lab-room profile
failed visibly. Final focused tests: 34 passed; analysis clean; Python source
counts: 3 passed. Full Flutter regression before final text polish: 113 passed.
[Checkpoint/runbook](../../timetable-audit-2026-10-20/11-advisor-showcase-2026-11-02.md)
records changed files, private evidence and remaining blockers. Imported profiles
are preview-only; no hosted data or Git state changes. Production NOT READY
findings remain open. Next eligible step is the visible local rehearsal, then a
separately authorized test deployment and normal authenticated APK verification.

22 October 2026 replay correction: fixed the generator's accidental conversion of
`public.vector` into nonexistent `timetable_replay.vector`; regenerated the SQL.
All 13 Python tool tests passed, including the new extension-type regression.
Executed the guarded rollback-only rehearsal twice against `oqwvxplteqtlrhktsplj`:
both passed exact catalog/content checks for 795 routines and 4 versions with MD5
`07da7d69a5d0b0dd816133f41716eae7`, and verified scratch cleanup after rollback.
No production changes. This namespaced rehearsal does not complete full-project
provisioning/restore acceptance or mark Task 1 complete.

Review after Tasks 1–3 (truth and policy), 4–7 (correct generation/publication), 8–10 (human workflow/readers), and 11–12 (offline and rollout). Foundational data changes precede engine expansion; offline synchronization comes after publication identity stabilizes.

The original audit completed investigation and planning only. Implementation status is recorded in the task acceptance checkpoints above; Task 1 is now complete for its isolated baseline scope.

## Academic decisions before implementation

Confirm department/program calendar and cohort admission, progression and graduation rules, section mappings, and the policy for generating or publishing an offering with a pending teacher. Until that policy is approved, retain pending offerings and do not claim complete teacher conflict validation or publish them as fully validated. Verify the deployed schema and current CSE mappings before migration design is finalized; preserve existing history and do not infer missing snapshots. Pending-teacher support is secondary and should not delay independent core timetable design work.
