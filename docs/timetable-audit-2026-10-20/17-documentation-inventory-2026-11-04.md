# Documentation inventory and maintenance decisions

**Later November 4 synchronization:** [record 18](18-committee-decisions-and-policy-baseline-2026-11-04.md) now governs confirmed policy and editable Course Distribution; [workflow 19](19-specialist-coordination-workflow-2026-11-04.md) and its repository skill prepare five roles. The inventory and PDF extraction results below preserve the initial audit history. At the start of this update `docs/defense/10_Admin_and_Timetable_Engine.pdf` was already deleted in the user's working tree; this task does not delete, restore or re-inspect that missing PDF. Current change manifest appears at the end.

4 November 2026. Companion to the [current audit](15-admin-web-preimplementation-2026-11-04.md) and [committee matrix](16-committee-traceability-2026-11-04.md). Paths below are relative to repository root unless a directory prefix is stated.

## Initial audit authority and inspection scope

The current user request controls scope: audit and Markdown maintenance only. `CLAUDE.md` retains implementation conventions for later authorized work; it does not authorize executing an old plan. No repository AGENTS/GEMINI/SKILL instruction files were found in source-owned paths. External session skills are not repository documents and were not edited. No Pages, external connected service writes, plugin installation or deployment was used.

Markdown was inventoried by source-file search, with purpose, headings, key claims and relevant source/checkpoint comparisons. Detailed scheduling/architecture claims were checked against current code; historical reports were not assumed accurate because they say “verified.” Older long design plans remain proposal/history, rather than undergoing a wholesale retrospective rewrite. Review classification means uncertainty is retained, not silently resolved. Generated `.pytest_cache` README files, dependency documentation, `.task1-local` rehearsal content and build outputs are excluded from maintained-document classification.

The active entrypoints are root README → audit index → report 15/matrix 16/inventory 17. The long October plan gets an explicit priority override. Historical numerical results retain their dates; fresh results belong in report 15. Formal academic calendars, offline access and multi-department goals remain documented for later work.

## Initial audit Markdown classification (source-owned files then present)

“Update” means a useful active entrypoint needs a bounded correction; the action column states what this audit actually does. “Keep (historical)” preserves useful information without making it current authority.

| Path | Classification | Purpose, evidence and action |
|---|---|---|
| `README.md` | Update | Active project entrypoint. Add web-admin-first priority and latest report; correct pending-faculty, combined groups, interval/capacity and backend/function claims against current source. Preserve existing user rewrite and setup conventions. |
| `CLAUDE.md` | Update | Active agent guide. Add current scope/order and audit link; replace stale generator gaps and absent-baseline/function claims. Preserve security, ownership, UI and no-push guardrails. Link archived handoff. |
| `POLISH_HANDOFF.md` | Archive | Obsolete defense task tells agents to create a polish branch/build screens now implemented in AppRouter and contains deployment/branch claims no longer current. Move byte-for-byte to `docs/archive/2026-11-04/POLISH_HANDOFF.md`. Update the two textual references found in CLAUDE and correction register. |
| `COMPLETE_PROJECT_AUDIT_REPORT.md` | Review | Pre-existing untracked October 22 audit mixes useful recovered backend evidence with stale combined-group/capacity claims and unverified severity/deployment assertions. Leave untouched; report 15 is current assessment. Retain pending author/provenance review, rather than moving user work speculatively. |
| `OFFLINE_ARCHITECTURE_AUDIT.md` | Review | Useful long-term offline idea but “100% offline,” timing guarantees and cached-profile snippets are proposals, not acceptance evidence. Leave untouched; no new offline priority or cached admin authority is authorized. Correction register already identifies limitations. |
| `PROJECT_STRUCTURE.md` | Keep | Pre-existing untracked navigation aid with current feature/test/tool inventories. Tree snapshots are descriptive, not a source of runtime/deployment guarantees. Leave untouched; directory listing is not expected to remain exhaustive after every new report. |
| `engine/README.md` | Update | Active engine guide incorrectly describes optional JSON fixture generation, guaranteed room success and sessional adjacency. Replace inaccurate sections with actual multipart pipeline, constraints, limits and current audit link. Keep local setup commands as documentation only. |
| `docs/backend-setup.md` | Keep | Baseline reconstruction/local catalog guidance explicitly distinguishes test evidence, deployment and backfill. Useful reproducibility/security context; no mutation tools run in this audit. |
| `docs/CAMPUS_READINESS_AUDIT_2026-10-20.md` | Keep (historical) | Dated readiness checkpoint; source of earlier prototype findings, not a new implementation order or current test count. |
| `docs/diagrams/README.md` | Update | Keep all five diagrams; add a dated limitation/authority notice to qualify “fully reconciled production” language and distinguish local catalog/new web scope. No diagram rewrite or artwork change. |
| `docs/diagrams/01-er-diagram.md` | Keep (historical) | Legacy 14-active-table schema view, not full additive catalog/current hosted inventory. Read with master-guide notice and catalog SQL; no new schema claim. |
| `docs/diagrams/02-use-case-diagram.md` | Keep (historical) | Role/feature presentation useful for existing actors. Does not specify the new committee workbench or prove backend access control. |
| `docs/diagrams/03-dfd-level-0.md` | Keep (historical) | System-boundary context remains useful. Production status must be independently verified; diagram does not authorize integration changes. |
| `docs/diagrams/04-dfd-level-1.md` | Keep (historical) | Legacy data-flow/store inventory; no claim all new canonical/draft/policy stores exist. |
| `docs/diagrams/05-activity-diagram.md` | Keep (historical) | Existing mobile journeys; preserve teacher/student scope for long-term product. New admin workflow is in report 15. |
| `docs/superpowers/plans/2026-10-20-university-timetable.md` | Update | Valuable design decisions and chronological checkpoints. Add top-level November 4 priority override, preserving prior academic-calendar deferral, no invented progression and no automatic implementation. Older “next task” text is historical. |
| `docs/superpowers/plans/2026-10-22-antigravity-parser-handoff.md` | Keep (historical) | Its resume protocol already stops when completed and records later parser fixes. Tests/current source confirm those regressions exist; do not execute handoff again. |
| `docs/superpowers/plans/2026-11-02-advisor-showcase.md` | Keep (historical) | Completed checked-off showcase work; distinct from production and committee acceptance. No need to archive useful source-profile/co-teacher decisions. |
| `docs/timetable-audit-2026-10-20/README.md` | Update | Central index. Make report 15 current, add matrix/inventory links and web-first priority; label earlier priorities/evidence as historical. |
| `docs/timetable-audit-2026-10-20/01-current-architecture.md` | Keep (historical) | October architecture snapshot plus clarification delta. Some listed defects are fixed in November; use report 15 for current state. Preserve dated evidence. |
| `docs/timetable-audit-2026-10-20/02-workbook-and-rules.md` | Keep | Detailed source/provenance and clarification history; indispensable for counts, joint attendance and seasonal timing. Earlier measured counts are not current pending-inclusive totals. |
| `docs/timetable-audit-2026-10-20/03-static-dynamic-matrix.md` | Keep | Useful policy/invariant separation with calendar deferral; new specific committee traceability is matrix 16, not a replacement of these concepts. |
| `docs/timetable-audit-2026-10-20/04-target-architecture.md` | Keep | Long-term design and explicit calendar deferral. DTOs partly exist locally now, but full proposed pipeline is not implemented. Current milestone order comes from report 15. |
| `docs/timetable-audit-2026-10-20/05-database-migration.md` | Keep (historical proposal) | Recovery/scoped immutable publication design; reconstructed baseline later exists. No need to erase useful rationale or execute proposed migrations. |
| `docs/timetable-audit-2026-10-20/06-testing-and-acceptance.md` | Keep (historical + proposed gates) | October baseline and future acceptance ideas. Old failing-gap claims are dated, not today's results. Committee-specific tests are now in matrix 16. |
| `docs/timetable-audit-2026-10-20/07-documentation-corrections.md` | Update | Preserve correction history; replace archived handoff reference with valid new location. |
| `docs/timetable-audit-2026-10-20/08-advisor-cse-readiness-2026-11-01.md` | Keep (historical) | Superseded retake-removal proposal is explicitly withdrawn; preserve that decision so agents do not revive destructive repair. |
| `docs/timetable-audit-2026-10-20/09-cross-semester-generation-2026-11-01.md` | Keep (historical) | Repeated local source/reconstruction evidence and bounded defects; reconstructed Fall is not the later full distribution. |
| `docs/timetable-audit-2026-10-20/10-merge-deployment-readiness-2026-11-02.md` | Keep (historical) | Production NOT READY findings and evidence. Does not contradict a narrower private demonstration being ready. No new hosted verification in this audit. |
| `docs/timetable-audit-2026-10-20/11-advisor-showcase-2026-11-02.md` | Keep (historical) | Private local Android showcase with limits; preserve 682/796 distinction and profile/identity safeguards. |
| `docs/timetable-audit-2026-10-20/12-delta-merge-readiness-2026-11-02.md` | Keep (historical) | Controlled-team merge assessment, not production certification. Its “room_policy untracked” warning no longer applies: `git ls-files engine/room_policy.py` now lists it. |
| `docs/timetable-audit-2026-10-20/13-lab-allocation-and-tba-report-2026-11-02.md` | Keep (historical) | Recent EEE/CSE restrictions/TBA evidence matches current code and HEAD subject; availability calendars and Physics exclusivity remain missing. |
| `docs/timetable-audit-2026-10-20/14-fall-2026-distribution-verification-2026-11-02.md` | Review | Pre-existing untracked full Fall distribution report. Local counts/profile and 429 code can be inspected, but provider rate-limit root cause requires request/edge logs not supplied here. Leave untouched; no unconditional 65-second solve or zero-failure promise. Its file:// links are historical portability issues, not new active-index links. |
| `ios/Runner/Assets.xcassets/LaunchImage.imageset/README.md` | Keep | Native asset instructions; unrelated to admin policy. Leave untouched. |

New maintained files: report 15, matrix 16, and this inventory 17. No duplicate full architecture rewrite at repository root was created. There is one new archive directory, containing only the obsolete polish handoff; no PDF or user source file is moved there.

## PDF inventory and recommendations

All 16 PDFs were opened read-only using the existing PyMuPDF installation. Text was extracted across all pages; each yielded nonempty text. Subject and sample claims were compared to current code. This was not a page-by-page visual rendering/layout review or proof that all historical statements are accurate. No PDF was modified, moved or deleted; no PDF generator was run.

“Equivalent Markdown” below identifies overlapping current documentation, not a claimed verbatim editable original. Python PDF-generator scripts are useful provenance but are not Markdown equivalents. No PDF is a new approved committee specification.

| File/location | Pages | Main purpose and direction | Equivalent/newer Markdown | Future value | Recommendation and justification |
|---|---:|---|---|---|---|
| `UniVerse_Concepts_Answers.pdf` | 16 | Dart/Flutter viva explanations, initialization and navigation; existing mobile project | Partial overlap with CLAUDE and routing diagrams; no complete Q&A Markdown equivalent found | Educational/team onboarding | **Keep**; distinct learning content. Verify code examples against current source before reuse. |
| `SEARCH_SYSTEM.pdf` | 9 | Find Teacher/room search and status derivation; existing mobile scope | README/CLAUDE and report 15 cover limits; no full equivalent tutorial | Design history for future availability work | **Retain as historical reference; review before reuse.** It says routines plus cancellations feed status; current room/teacher services do not establish that cancellation-aware behavior. |
| `engine/UniVerse_Timetable_Engine_Explained.pdf` | 15 | Detailed engine knowledge transfer/defense; earlier generator | Updated `engine/README.md`, report 15, workbook report 02 | Solver rationale and project history | **Retain as historical reference; review before reuse.** Current pending preservation, hard same-day policy, lab restrictions and publication differ from earlier explanations. |
| `docs/defense/00_START_HERE.pdf` | 7 | Defense pitch, architecture, ownership and reading list; earlier mobile presentation | README, CLAUDE, diagram master guide | Defense history; team communication | **Retain as historical reference.** No complete current equivalent defense pack; broad “clash-free” claims need qualification. |
| `docs/defense/01_Routing_and_Navigation.pdf` | 4 | GoRouter/auth shell navigation tutorial | `docs/diagrams/02-use-case-diagram.md`, `05-activity-diagram.md`, CLAUDE; report 15 web gaps | Navigation reuse | **Keep**, as a dated explainer. Does not prove browser refresh/back/forward behavior or server authorization. |
| `docs/defense/02_Theming_and_Design_System.pdf` | 3 | Colors/type/spacing/theme tokens | CLAUDE UI conventions; no full Markdown tutorial | Desktop admin should reuse theme | **Keep.** Dependency-specific Phosphor statements are stale: current project uses a compatibility shim and commented dependency. |
| `docs/defense/03_Authentication.pdf` | 6 | Email/Google onboarding and whitelist | CLAUDE, README, report 15, migration 016 | Auth rationale | **Retain as historical reference; review before reuse.** PDF says teachers self-register freely; new teacher/admin roles are now whitelist-gated. Browser callbacks need separate work. |
| `docs/defense/04_Routine.pdf` | 3 | Shared student/teacher routine reader | README/CLAUDE and report 15; no exact Markdown tutorial | Preserve actors/read paths | **Retain as historical reference.** Exact teacher/section-query examples predate current matchesStudent/matchesTeacher/paginated active fetch; DB time type should not be inferred from Dart strings. |
| `docs/defense/05_Student_Dashboard.pdf` | 4 | Dashboard live/next/today aggregation | README/CLAUDE describe feature; no complete equivalent | Long-term mobile reference | **Keep.** Outside immediate admin work; no reason to delete useful actor documentation. |
| `docs/defense/06_Teacher_Features.pdf` | 5 | Teacher dashboard, cancellation/notice/undo | README/CLAUDE; report 15 access-control qualification | Future actor support | **Retain as historical reference; review before reuse.** “Cannot cancel another's class” is not established by actor/role-only RLS. |
| `docs/defense/07_Resources.pdf` | 2 | Resource files/links, categories and notifications | README and diagrams; no full tutorial equivalent | Existing academic-management scope | **Keep**, with legacy Storage authorization claims checked before operational reuse. |
| `docs/defense/08_Notifications_and_Push.pdf` | 5 | Notification insert → Realtime/webhook/FCM | CLAUDE, `docs/backend-setup.md`, report 10 historical deployment findings | Messaging architecture | **Retain as historical reference.** One intended event path does not prove end-to-end delivery or deployed handler authentication. |
| `docs/defense/09_Profile.pdf` | 2 | Profile model/read/edit/sign-out | CLAUDE and README; no full equivalent | Actor/account context | **Keep.** No relevance-based reason to remove a small, distinct feature guide. |
| `docs/defense/10_Admin_and_Timetable_Engine.pdf` | 3 | Earlier routine hub, solver/API/publish explanation | Updated engine README, report 15 and matrix 16 substantially supersede runtime details | Defense history only for many claims | **Retain as historical reference; highest-priority manual review.** Blank teachers are now retained; same-day rule is hard by default; export is not fixed at 55 cohorts; publication globally replaces rather than per-batch clearing. |
| `docs/defense/11_Find_Teacher.pdf` | 2 | Schedule-derived faculty status/search | README/CLAUDE limitations; partial overlap with SEARCH_SYSTEM.pdf | Short feature overview | **Keep**, as dated overview. Cancellation-aware design statement is not proof of implementation or real location. |
| `docs/defense/12_Room_Availability.pdf` | 2 | Schedule-derived room occupancy | README/CLAUDE, partial overlap with SEARCH_SYSTEM.pdf | Existing room UI rationale | **Keep**, as dated overview. “Every room” means those represented in routine data, not a complete availability calendar/inventory. |

**Manual deletion recommendation:** none is necessary on current evidence. If the team later wants fewer defense artifacts, `docs/defense/10_Admin_and_Timetable_Engine.pdf` is the strongest candidate to consider deleting manually after keeping a historical copy and adopting the updated engine guide; do not delete it merely because some claims changed. `SEARCH_SYSTEM.pdf`, authentication, teacher and push PDFs need review before being handed to future agents as current implementation guidance. The concepts/theme/student/profile/resource references retain distinct long-term value.

## Initial audit change manifest and reference handling (historical)

Existing files modified by this audit only:

1. `README.md` — current priority/evidence corrections.
2. `CLAUDE.md` — current agent priority and implementation facts.
3. `engine/README.md` — accurate engine contract and limits.
4. `docs/diagrams/README.md` — dated context/authority notice.
5. `docs/superpowers/plans/2026-10-20-university-timetable.md` — latest priority override.
6. `docs/timetable-audit-2026-10-20/README.md` — current report index and historical priority qualification.
7. `docs/timetable-audit-2026-10-20/07-documentation-corrections.md` — archived handoff reference.

Moved, preserving content: `POLISH_HANDOFF.md` → `docs/archive/2026-11-04/POLISH_HANDOFF.md`. Relative file names in its prose describe the original repository-root context; the inventory supplies the current canonical location. It contains no Markdown relative links requiring a path rewrite. It remains historical and must not be executed as a current task.

New: the three numbered November 4 reports (15–17). No other source-owned Markdown is changed. Pre-existing user modifications and untracked work remain. No source, SQL, dependencies, app/build/deployment configuration, raw workbook or PDF content is changed by this audit. Final status/hash/diff verification is recorded in report 15 after checks complete.

## Committee synchronization change manifest — later 4 November

This section describes the current documentation/agent-preparation task, independently of the initial audit manifest above. No files are moved or deleted in this task.

| Modified existing path | Current change |
|---|---|
| `README.md` | Link confirmed policy, CD1 and specialist workflow; distinguish planned requirements from implemented features. |
| `CLAUDE.md` | Current decision authority, accepted source corrections, just-in-time questions, Codex/Antigravity ownership and skill entrypoint. |
| `engine/README.md` | Confirmed but unimplemented policies, source-draft integration gap and truthful failure diagnostics. |
| `docs/superpowers/plans/2026-10-20-university-timetable.md` | Later dated override with confirmed semantics, distribution draft/normalization order and specialist ownership. |
| `docs/timetable-audit-2026-10-20/README.md` | New authority/workflow links and preserved historical ordering. |
| `docs/timetable-audit-2026-10-20/03-static-dynamic-matrix.md` | Policy/attendance/source-correction applicability notice. |
| `docs/timetable-audit-2026-10-20/04-target-architecture.md` | Current policy/CD1 notice; distinguish mandatory gap limits from soft compactness. |
| `docs/timetable-audit-2026-10-20/15-admin-web-preimplementation-2026-11-04.md` | Updated feasibility, attendance distinctions, editable distribution workflow, phases 2a/2b, publication dependencies and remaining questions; original source findings/test history retained. |
| `docs/timetable-audit-2026-10-20/16-committee-traceability-2026-11-04.md` | Updated R1/R2/R6/R7/R12/R13/R16, all 16 retained with 11 fields; separate CD1/D6 contract and tests. |
| `docs/timetable-audit-2026-10-20/17-documentation-inventory-2026-11-04.md` | Preserve initial inventory/history, disclose pre-existing missing PDF and add this manifest. |

Created:

- `docs/timetable-audit-2026-10-20/18-committee-decisions-and-policy-baseline-2026-11-04.md`
- `docs/timetable-audit-2026-10-20/19-specialist-coordination-workflow-2026-11-04.md`
- `.agents/skills/universe-implementation/SKILL.md`
- `.agents/skills/universe-implementation/references/web-platform.md`
- `.agents/skills/universe-implementation/references/admin-distribution-ui.md`
- `.agents/skills/universe-implementation/references/scheduling-cp-sat.md`
- `.agents/skills/universe-implementation/references/backend-data-integrity.md`
- `.agents/skills/universe-implementation/references/testing-reliability.md`

Starting state includes the prior audit's archived polish handoff, source-controller backoff change, backend/config/workbook artifacts, untracked `is.java`, and deletion of `docs/defense/10_Admin_and_Timetable_Engine.pdf`. They are user changes and are preserved. The locked Excel temporary file is unreadable and excluded from byte-comparison verification. No PDF movement/deletion/restoration, app/config/SQL/dependency change, production action, staging, commit, push, reset or checkout is performed here. Current verification results are appended to record 18 after the final checks, rather than replacing historical application-test results.
