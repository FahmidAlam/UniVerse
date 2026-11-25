**UniVerse campus readiness audit — 20 October 2026**

**Decision:** UniVerse is an advanced working prototype with a tested scheduling core. It is suitable for supervised schedule drafting and comparison with the department's official routine. It is not yet ready to be the sole source of truth for departmental teaching, and its data/publication model does not yet support independently managed university departments.

This audit examined the local Flutter application, Python ingestion/solver/render/API, SQL migrations, Edge Function sources, deployment configuration, and automated tests. It traced generation through publication to student/teacher consumption, and examined authentication, resources, notifications, cancellations, room/teacher views, and operational recovery. It is a source audit with local execution, not a live infrastructure or device certification. No live database changes, pushes, invitations, or deployments were performed. Existing user changes were preserved.

**Evidence collected**

| Check | Result | What it establishes |
|---|---|---|
| Engine suite, existing engine virtual environment | 142 passed, 1 skipped in 93.59 seconds | Existing ingestion, solver, semester-shape, eligibility, fixed-rate, and rendering regression checks pass |
| Real distribution suite with `UNIVERSE_SOLVE=1`, `SOLVER_WORKERS=2` | 9 passed in 128.61 seconds | Full Summer 2025 solve passes existing validation with a 120-second solver budget |
| Flutter `test --no-pub` | 60 passed | Existing clock, settings, publish-gate, auth/controller/router/widget tests pass |
| Flutter `analyze --no-pub` | No issues found | Static analysis is clean |
| Six synthetic scheduler probes | All returned `validation.ok = true` | Demonstrates six gaps discussed below; these are not six correctness successes |

The normal engine suite skips the expensive full solve; it was explicitly enabled in the separate run. The system Python lacked pytest; the project's existing engine virtual environment worked. Flutter tests and analysis completed with approved access to the SDK outside the workspace after the initial sandboxed Flutter test stalled.

The real workbook parsed to **325 offerings, 656 weekly meetings, 55 CSE cohort labels, 76 teachers, 18 shared-teacher offerings, and 15 excluded rows** under derived session counts. Of the meetings, 626 are CSE-grid meetings and 30 are service meetings. One real combined cohort is `58-B+C`. With the shipped fixed rate of two meetings/week, the existing regression expects 650 meetings; six offerings that naturally need three are reduced to two.

The README's older 358-offering/686-meeting figures do not describe the current parser. Passing this one historical workbook does not establish a success rate over future semesters, production memory limits, concurrent requests, or campus-approved constraints.

**Readiness by intended use**

| Intended use | Assessment | Remaining gate |
|---|---|---|
| Academic demo and supervised routine drafting | Strong foundation | Clearly communicate known limitations and manually review output |
| One CSE department, official routine pilot | Pre-pilot | Correct audience/resource modeling, enforce publication validation, approve academic rules, and demonstrate recovery |
| Dependable daily campus companion | Incomplete | Cancellation-aware views, offline routine access, trustworthy notifications, access control and release checks |
| Multiple departments publishing independently | Architectural work required | Department/term ownership, scoped publishing, shared-resource coordination |

A percentage would mix implemented screens with unproven correctness. The useful measure is whether these release gates pass. The next work should concentrate on correctness and operational safeguards rather than additional screens.

**Priority 0: prevent incorrect routines from becoming official**

1. **Combined sections are neither overlapping student groups in the solver nor discoverable by individual sections in the app.**

   `engine/ingest.py:279` creates a literal cohort string. `engine/solver.py:331` constrains that exact string. Therefore `66-B` and `66-B+C` are different resources. The probe forces one class for each into the same sole period; both schedule successfully and validation reports no cohort clash. The real distribution contains `58-B+C`, so this is not merely an invented naming convention.

   `lib/features/routine/services/routine_service.dart` fetches students by exact `batch` and `section`. A student registered in B or C does not receive the B+C row. Notification audience matching has the same exact-section assumption.

   **Required change:** model each offering's actual student groups separately from its display label. Reserve every member group in the solver; publish memberships; query and notify through those memberships. Regression: B+C conflicts with B and C, and both groups see the combined class.

2. **A “complete” schedule can omit a required course before validation starts.**

   `engine/ingest.py:275` excludes every row without a teacher; missing batch/code also produce exclusions. `_validate()` reconciles output only against the offerings that survived parsing. In the probe, a second ordinary course has a missing teacher: one exclusion, one scheduled course, `ok=true`.

   Some real exclusions are intentional project/thesis activities. The defect is treating all missing-teacher rows as acceptable exclusions without an explicit academic disposition. Unknown faculty codes also schedule without warning: the solver treats absent availability as unrestricted. Filtering inactive faculty from the outgoing config does not stop a workbook from assigning them.

   **Required change:** preflight the full input against canonical faculty/course/cohort records. Mark every exclusion as approved non-timetabled work or a blocking data error. Reject unknown/inactive faculty. Preserve counts and decisions from raw rows through publication.

3. **Room counts are modeled; room suitability is not.**

   `engine/solver.py:39` reduces rooms to lab/theory name pools. `_assign_rooms()` uses first-fit assignment. Student counts are parsed but explicitly unused (`engine/ingest.py:85`). Capacity, lab equipment, department ownership, external reservations, and travel between buildings are not enforced.

   The synthetic input with 100 students and room capacity 20 is accepted. Adding a `capacity` field to input does not help because normalization ignores it. Similarly, the README claim about department-reserved lab rooms is not implemented in the current solver.

   **Required change:** capture authoritative room capacities, facilities, ownership/access rules and availability. Include eligible room choices in the constraint model, or use a matching model that can feed failures back into scheduling. The current aggregate-pool guarantee only holds when rooms in each pool are interchangeable.

4. **Academic workload policy is ambiguous and can knowingly under-deliver.**

   The default fixed two-meetings/week setting overrides derived requirements. A 38-class offering over 14 weeks receives 28 scheduled meetings; ingestion warns about the missing 10 but validates against the overridden requirement, so `ok=true`.

   This appears deliberate in the fixed-rate regression tests. It should not be silently reversed without department agreement. However, successful validation currently means “matches the chosen weekly policy,” not “delivers the distribution's term requirement.”

   Session duration is also not a solver input. The workbook's duration column is checked for deviation from 1.5, while the default physical periods are 75 minutes. Whether that workbook value denotes actual hours or an institutional class unit needs faculty confirmation. Labs occupy one period per session; lab/theory adjacency is not equivalent to a multi-period lab-duration constraint.

   **Required change:** formally approve contact-minute rules, term length, holidays/makeup treatment, per-course session counts, and lab duration/adjacency. Keep an explicit approved exception record when the weekly policy differs from term totals. Report both requirements and delivered minutes.

5. **Validation can be bypassed through normal publication/edit paths.**

   Generated schedules have a useful client-side gate, but `blockingValidationErrorFor()` at `lib/features/admin/controllers/timetable_gen_controller.dart:251` accepts null/empty validation. The upload controller publishes nonempty rows without rejecting `validation.ok=false`; the upload screen explicitly says the workbook can still be published.

   `supabase/migrations/014_publish_routine_safeupdate.sql:62` checks authorization and nonempty input, then records the supplied validation JSON without independently enforcing it. Manual routine edits use direct CRUD through `RoutineService`, bypassing generation validation and immutable version history.

   The uploaded-workbook validator compares equal start times, not overlapping intervals. A 09:00–10:30 class and a 10:00–11:30 class can evade that clash check.

   **Required change:** apply one authoritative publish validator to generated, imported, and edited drafts. Require verified completeness, resource/audience conflicts, and approved input exceptions. Reject absent validation; do not trust client-supplied success flags. Commit rows, version and audit metadata together.

6. **Period-index clashes are not clock-time clashes at the engine boundary.**

   The solver and validator key conflicts by `(day, period index)`. The probe configures overlapping P1/P2 and schedules the same teacher, room and section in both; `ok=true`.

   The Flutter settings screen already rejects overlapping periods, which protects that UI path. The engine endpoint accepts arbitrary config, and stored configuration may come from other paths. Duplicate indexes/names, overlapping/reversed times, duplicate render columns, invalid day names and unsupported columns need validation at the backend boundary too.

**Priority 1: preserve correctness after generation**

7. **Co-teachers disappear from the published data model.** The solver correctly reserves all teachers in a shared offering, but `RoutineEntry` stores only one `teacher_code`; its conversion drops the `teachers` array. The SQL publish function also inserts only one teacher. Secondary teachers cannot find those meetings through their routine query or teacher locator. There are 18 shared offerings in the real input.

   Preserve offering-teacher relationships and, where teachers alternate during the term, the applicable dates/weeks. Merely copying the meeting into multiple rows would create false room/cohort clashes.

8. **Publication is global rather than department-scoped.** There is one active-version unique index for the whole database. Publishing deletes all routines (`014:79`). No department/term key scopes that replacement. A second department's publish would replace the first department's timetable. Numeric batch labels are also not globally unique student identities.

   Introduce department and academic-term IDs, scoped versions and authorization, and shared faculty/room resources. Independently solving departments does not prevent cross-department conflicts: import authoritative external reservations or coordinate the shared model. Service classes from the CSE workbook represent only the external commitments actually present in that workbook.

9. **A rendered-workbook round trip loses service meetings.** Generation publishes `rows + service_rows`, which is a good correction. Rendering receives only CSE `rows`. Uploading that downloaded workbook later performs a full replacement using the parsed grid, so the service meetings are no longer present. Co-teacher metadata and authoritative offering requirements also cannot be recovered from those cells.

   Include machine-readable full-fidelity data in the export, or treat a printed-grid import as an incomplete draft requiring reconciliation against the complete distribution before publication.

10. **Version history cannot restore the exact previous routine.** Atomic replacement protects against partial SQL failure, but old row sets are deleted. `routine_versions` retains metadata rather than historical meetings; a CSE-only workbook is insufficient for exact restoration. There is no scheduled effective date or term end. Existing cancellation foreign keys are set null on replacement, so they stop matching newly created meeting IDs.

    Store immutable versioned meeting snapshots, activate a chosen version atomically, retain stable occurrence identities where appropriate, and provide tested rollback. Add stale-draft/concurrent-publisher detection rather than relying only on the single-active-version index.

11. **Publication success can be reported as failure after it has committed.** Both controllers publish first and then separately write `timetable_runs`. If the second operation fails, the app shows an error although the routine is already live; retry can create another version. Notifications are best-effort with swallowed failures.

    Use an idempotency key and transactional audit/outbox records. Distinguish “published, notification pending” from “not published.”

12. **Eligibility editing can erase restrictions.** `saveEligibilityFor()` deletes existing rows, then inserts selected eligible rows in a separate request. A failure after deletion loses the rules. Unticking every course leaves no rows; the engine interprets that as “unconfigured,” not “eligible for none.” Teacher preference priority is stored but not optimized; teacher assignment itself is fixed by the workbook.

    Use an atomic replacement operation and explicit “configured with no eligible courses” state. Do not present preference fields as solver behavior until they affect the model.

**Priority 1: service operation and campus trust**

13. **The generation service has no application authentication or job ownership.** `engine/main.py` allows generation and job retrieval without checking user identity. Each request reads the whole upload and starts a daemon thread; requested solve time is unbounded by server policy. Jobs, rows and workbooks remain in `JOBS` indefinitely.

    This permits resource exhaustion and provides no recovery from a process restart. Multiple server processes would each have different job dictionaries. Guess-resistant IDs are not authorization.

    Require admin JWT verification, job ownership, upload/config/time limits, a bounded queue, durable job/result storage, retention cleanup and observability. Verify actual worker memory and concurrent-job behavior on the deployed machine. The local two-worker test does not reproduce the deployment's memory budget.

14. **Flutter generation cannot reliably resume or tolerate transient transport failure.** HTTP operations have no explicit timeout; the poll-count ceiling does not bound a hung HTTP request. One request failure exits polling, job identity is only in controller memory, and there is no persisted resume/cancel flow. Leaving the screen can leave asynchronous work notifying a disposed `ChangeNotifier`.

    Persist job IDs; add request deadlines, bounded retry/backoff, resume/status recovery and lifecycle cancellation. Report solver `UNKNOWN`/timeout separately from proven `INFEASIBLE`; current `_infeasible_message()` suggests structural clashes even when the solver has not proved impossibility.

15. **Storage access is too broad in the checked-in SQL.** Migration 006 grants any authenticated user update/delete access to all storage objects (`storage_auth_update`/`storage_auth_delete`), without bucket, ownership or role restrictions. Students should not be able to replace/delete other users' resources, avatars or routine exports.

    Cancellation insertion verifies staff role and caller ID but not ownership of the affected class. Notification insertion similarly permits staff broadcasts without audience authorization. Migration 016 restricts entry into the teacher role but does not bind `teacher_code` to the authorized identity on ordinary profile edits.

    Restrict storage by bucket and ownership; bind faculty identity; authorize cancellation/notice actions against actual course ownership. Run negative database tests as student, teacher, admin and unauthenticated users. These are findings in supplied policy source; live policies may differ and were not inspected.

16. **Push/invitation deployments are not reproducible from this checkout.** Both `supabase/functions/send-push/index.ts` and `invite-admin/index.ts` contain commented-out implementations only. They do not define executable handlers as checked in. A separately deployed function may work, but repository instructions cannot reproduce it.

    Restore deployable source and verify real deliveries/invitations in a staging environment. Also test cold-start notification navigation: push initialization reads the initial message before `main.dart` assigns the navigation callback.

17. **Cancellation and room-change behavior disagrees across screens.** Student dashboard/routine and room/teacher availability derive state from recurring routine rows without applying cancellation records. A cancelled meeting can still be displayed as live or occupied. A room-change notice does not change the authoritative meeting location.

    Build a dated occurrence view applying cancellations, location overrides, holidays and effective routine versions. All screens should consume the same occurrence state. Describe teacher location as scheduled location, not measured physical presence.

18. **Room/teacher status does not refresh simply because time passes.** Their controllers compute labels at fetch time and on database updates; there is no clock-driven recomputation. The stream subscriptions are not retained/cancelled on disposal, and stream callbacks issue fresh full-table queries. Unused configured rooms and faculty absent from routine rows also disappear from these directories.

    Use a shared clock, directory-backed lists, stored/cancelled subscriptions and the incoming stream data. Show stale/offline status explicitly.

19. **Offline access and campus-scale reads are incomplete.** There is no persisted routine cache in the routine service; the Hive dependency does not implement one. Routine views need the network after restart. Several services fetch complete tables without pagination, and `AdminService._count()` counts returned IDs rather than performing a database count. Results/counts can truncate at the configured API row limit.

    Persist the last verified routine version with last-synced information. Add server-side audience filtering, pagination and aggregate counts. Exercise large datasets, not just the current 656 meetings.

**Scheduling quality and constraints requiring campus confirmation**

The model has good hard rules for exact teacher/cohort/room-pool slots, teacher days off, blocked periods, same-course daily repetition, configured eligibility validation and theory/lab adjacency. It deliberately does not choose teachers.

The objective called compactness penalizes the number of teaching days, not gaps within a day. The `spread` weight is normalized but not used in the objective. There are no explicit limits for daily load, consecutive teaching, student idle hours, teacher partial-day availability, locked sessions, external reservations, travel, or minimum change from an approved previous draft. These are requirements to agree with the university, not assumptions that every department necessarily needs.

Ask the routine committee to approve a concrete policy sheet covering room capacity/equipment, combined groups, lab duration, teaching minutes, faculty availability, service commitments, fixed classes, maximum daily/consecutive classes, breaks, electives/retakes and timetable-change rules. Encode agreed hard constraints as tests; report preferences as quality metrics rather than claiming they are guaranteed.

The renderer is CSE-template-specific, with a documented 88-cohort capacity and fixed day sheets/grid conventions. This is acceptable for a controlled CSE rollout but should be validated against each supported configuration and department. Every export should be round-trip checked against the authoritative meeting dataset.

**Repository and release readiness**

The feature/controller/service structure is understandable, static analysis is clean, and the Python regression coverage is a meaningful asset. Atomic SQL publishing is a substantial improvement over client-side delete/insert loops.

Fresh backend provisioning is incomplete: migration 001 already references an existing notifications table; migration 006 assumes original domain tables; migration 008 explicitly describes config tables created in the dashboard. A complete baseline schema is missing from the migration sequence. README setup directions also stop before the latest migrations and describe an older engine API.

Only a keep-alive workflow is present in `.github/workflows`; it does not run the application/engine tests. Android release configuration still uses debug signing and the example application identifier. There is no demonstrated device acceptance run, staging database/RLS suite, load/restart test, rollback drill or automated publish-to-student integration test in this audit.

Supply a reproducible baseline and staging seed, executable Edge Functions, CI for both stacks and SQL tests, production signing, release configuration checks and a monitored deployment/runbook. Preserve institution-controlled backups and demonstrate restore.

**Ordered implementation and rollout plan**

| Order | Deliverable | Exit condition |
|---|---|---|
| 1 | Approved academic policy and canonical input model | Every raw offering is scheduled or explicitly approved as excluded; active faculty and group memberships resolve |
| 2 | Correct scheduling resources and validation | Combined groups, suitable rooms, contact minutes, durations and interval conflicts covered by independent checks |
| 3 | One safe publishing pipeline | Invalid/missing validation rejected for generation, upload and edits; exact snapshots, rollback and idempotency work |
| 4 | Secure and recoverable service | Owned authenticated jobs, bounded queue/requests, restart recovery; storage/class-action negative access tests pass |
| 5 | Consistent campus consumption | All teachers and group members see their classes; cancellations/overrides/offline states agree across screens |
| 6 | Shadow semester exercise | Committee compares multiple complete outputs against approved requirements before official adoption |
| 7 | Supervised one-department pilot | Named approver, fallback routine, monitoring, tested rollback and support ownership |
| 8 | Multi-department expansion | Department-scoped publication plus coordinated shared-room/faculty conflicts proven |

Suggested pilot evidence: multiple historical/current distributions; repeated full solves on production-sized hardware; an independent audit of zero unapproved omissions, overlaps and room violations; per-group/per-teacher published views; loss-of-network/restart scenarios; simultaneous publication; and a rollback drill. Measure solve success rate, p95 duration, peak memory, violations, timetable quality and post-publication discrepancies. Choose numerical quality thresholds with the committee before measuring them.

The largest uncertainty is not whether CP-SAT can schedule a department: the existing real-data regression demonstrates that it can solve the current model. The uncertainty is whether that model and the published data faithfully represent all of the university's obligations.

**Reproduce the synthetic findings**

Run `engine/.venv/Scripts/python.exe tool/audit_scheduler_probes.py` from the repository root. The script uses only synthetic in-memory workbooks and prints small summaries. It does not access the live backend or expose faculty data. Its outputs intentionally demonstrate current gaps; after fixes, replace those demonstrations with regression assertions for rejection/correct scheduling.
