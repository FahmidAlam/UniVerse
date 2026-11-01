# Documentation correction register

The root README and CLAUDE guide were corrected only after code, SQL, workbook and test inspection. Useful team ownership, UI conventions, auth caveats, clock handling, raw-workbook protection and deployment boundaries were preserved. Historical figures and branch claims were replaced with current evidence or explicitly labeled uncertainty.

| Previous claim/instruction | Evidence | Correction and reason |
|---|---|---|
| README feature-complete, deployed/live, guaranteed conflict-free | Unvalidated upload/manual/RPC paths; live services not inspected | Describe implemented features and readiness limits separately |
| Flutter ~3.35/Dart ^3.9.2; CLAUDE 3.44.9/3.12.2 | pubspec SDK range; local SDK cache 3.47.0/3.13.0 | Separate declared constraints, local test toolchain and supported deployment |
| Migration range 001–010 creates full schema | Files 001–009, 011–016; missing base tables | Correct inventory and explain baseline prerequisite; no blind replay recipe |
| Schedule config 010; versions 011 | Actual 011 and 012; 014 replaces publish function | Fix migration references |
| Routines written exclusively through publish RPC | RoutineAdminController calls direct RoutineService CRUD | State current bypass and desired future invariant distinctly |
| At most one active index described as “exactly one” | Partial unique index only forbids multiple true rows | Correct wording; no guarantee of at least one |
| Full rollback/history implied by routine_versions | Only metadata retained, old routines deleted | Explain incomplete reconstruction and propose immutable snapshots |
| Everyone can self-register as teacher; google_sign_in unused | AuthService native flow; migration 016 | Teacher/admin whitelist gate and native Google sign-in documented |
| Auth controller has hundreds of obsolete commented lines | Current controller begins at line 1, active class at line 22 | Remove stale cleanup instruction |
| All tables have read_all/admin_write | 001/004 owner policies, 006 mixed policies, 013 public-target read | Describe actual per-table patterns and unknown grants |
| Service role exists only in invite-admin | Intended send-push also needs server privileges | Secrets only on server; neither function deployment verified |
| Both Edge Functions can simply be deployed from checkout | Entire source files commented | Mark source/deployment reconciliation as prerequisite |
| Guaranteed automatic push on any notification insert | Webhook/secrets/live source not verified | Document intended path and verification requirement |
| Engine optional JSON dataset API | main.py multipart file/config/time limit | Replace stale root instructions with actual contract; flag engine README historical |
| Room department reservations/course overrides implemented | Existing CSE pools work; workbook Weekdays!G270 and Weekend!E18:E19 contain allocation notes, but permission rules are not consumed by config/solver | Reuse inventory/pools, verify aliases/applicability and extend the missing rule; Course Assignments checks eligibility rather than replacing imported teachers |
| Credit ignored / always two / build completeness validator | Current ingest derives counts, checks consistency and validates; 015 fixed override | Explain both modes and policy conflict |
| Renderer fixed to 55 rows | Dynamic capacity check against template furniture | Explain remaining column/layout coupling without old row-count claim |
| Same-day duplicates only soft | Current hard default and exemptions | Correct policy description |
| 358 offerings / 686 sessions presented as current | Actual 325 offerings / 656 derived sessions | Replace figures; distinguish rows, offerings and sessions |
| Timetable periods SQL-only | Settings screen and tests exist | Document editable settings; map and some solver options remain unexposed |
| Phosphor package used | Commented dependency and Material shim | Preserve shim imports, explain actual icons |
| AGP 8.9.1 / Kotlin 2.1.0 | settings.gradle.kts 8.11.1 / 2.2.20 | Correct versions; retain Gradle/JDK caution without absolute unverified compatibility claims |
| Render automatic deployment/no downtime/free-tier timing guaranteed | Blueprint does not prove account linkage/runtime | Treat runtime and linkage as operational configuration to verify |
| Old feature branches must be merged | No current branch investigation establishes this necessity | Remove automatic merge instruction; investigate actual diff before any merge |

## Other documentation reviewed, preserved as existing work

- `engine/README.md` describes an old fixture/optional-JSON API. Root documentation now gives the current multipart contract and labels that file historical. It should be rewritten with the engine API task, not used as implementation authority.
- `docs/diagrams/README.md` says four diagrams while listing five, omits current version/eligibility objects, allows teacher self-registration, and treats push as verified. The root docs now identify these diagrams as historical. Redraw them after the new schema is approved; do not mistake their table count for a production introspection.
- `OFFLINE_ARCHITECTURE_AUDIT.md` proposes caching but overstates “100% offline” behavior, sub-5-ms performance and immediate reconnection guarantees. Its cached-profile fallback must distinguish explicit denial from network failure and cannot confer admin authority. The new target replaces those guarantees with measurable targets and read-only semantics.
- `docs/CAMPUS_READINESS_AUDIT_2026-10-20.md` contains useful prior evidence, including a full real-data solve. Current tests/probes were independently rerun; this report does not claim to have repeated that full solve.
- `POLISH_HANDOFF.md` is historical handoff context, not evidence that its branch, counts or priorities still apply. The user's audit-only boundary takes precedence.
- `frontend_ux_audit.md` is a separate existing work item. No unrelated visual redesign was undertaken.

## Verification policy

Current facts are grounded in paths/symbols in the architecture report. Proposed designs are labeled as proposals. No live schema, service deployment, bucket visibility, FCM delivery or operational uptime is certified. This audit modifies documentation only; it does not silently turn a recommendation into a code or data change.


## User clarification corrections (22 October 2026)

- Formal term/calendar modeling is deferred. Two senior batches currently use
  trimester, others bi-semester (user-confirmed); current batch applicability
  requires current evidence and must never be hardcoded from 2025 sources.
- Historical semester/stage is an as-of observation; workbook has no semester
  column. Solver/parser fallback arithmetic does not verify current progression.
- B+C means joint B and C attendance, verified in source rows 315-318/349-350;
  no routine control may invent combinations. WD+WE remains separately unresolved.
- Imported teacher cells are authoritative. Preserve existing eligibility,
  off-day and CSE room functions; manual routine edits bypass source provenance.
- Replace the earlier phrase '125 invalid same-day intervals' with '125 anomalous
  stored intervals'. A noon/spacing parser defect is reproduced; original import
  lineage and the cause of all 96 midnight-end rows remain unproven. No blanket
  rejection, timezone assumption or data rewrite follows from the numeric check.
- Summer/winter times are dynamic configuration, not permanent legacy constants.
  Bind verified effective timing grids to source/publication revisions and reuse
  the existing settings editor; formal term modeling is not required for this.
- Re-provided `workbook/` files are byte-identical to the audited originals;
  their hashes and actual cell types were verified again, not assumed by name.

See [detailed evidence](02-workbook-and-rules.md#verified-clarification-corrections---22-october-2026).
