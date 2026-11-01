# University timetable architecture audit

Audit date: 20 October 2026 (Asia/Dhaka). Repository baseline: `47e2291`, including the working tree present at the start of the audit. **Status: proposal for review; implementation is not authorized by this document.**

## Executive decision

**Extend the existing Flutter/Supabase/Python architecture with selective refactoring.** Keep CP-SAT, the feature-first Flutter layout, ChangeNotifier, GoRouter, Supabase Auth/Postgres/Storage, and Firebase messaging. A rewrite or a second authoritative database is not justified.

The system has a useful CSE scheduling foundation, but is **not ready for independent university-wide publication**. Its global settings and globally replacing publication RPC cannot isolate departments or overlapping terms. Its validators accept several academically invalid inputs. Published rows lose co-teacher and student-group identity, and there is no persistent timetable cache.

## Deliverables

Advisor demonstration: [2 November local Android showcase — READY WITH LIMITATIONS](11-advisor-showcase-2026-11-02.md).
This is a private preview checkpoint, not production rollout approval.

Current application/merge/deployment decision:
[2 November readiness assessment — NOT READY](10-merge-deployment-readiness-2026-11-02.md).

Latest local generation evidence: [cross-semester evaluation, 1 November 2026](09-cross-semester-generation-2026-11-01.md).
The historical audit results below remain dated evidence; see that checkpoint
for repeated generation, fixes and current limits.

| Requested deliverable | Artifact |
|---|---|
| 1. Current architecture audit | [01-current-architecture.md](01-current-architecture.md) |
| 2. Excel data and scheduling rules | [02-workbook-and-rules.md](02-workbook-and-rules.md) |
| 3. Static/dynamic matrix | [03-static-dynamic-matrix.md](03-static-dynamic-matrix.md) |
| 4. Target architecture and offline strategy | [04-target-architecture.md](04-target-architecture.md) |
| 5. Database and migration plan | [05-database-migration.md](05-database-migration.md) |
| 6. Ordered implementation roadmap | [Implementation plan](../superpowers/plans/2026-10-20-university-timetable.md) |
| 7. Testing and acceptance strategy | [06-testing-and-acceptance.md](06-testing-and-acceptance.md) |
| 8. Corrected project documentation | [README](../../README.md), [CLAUDE](../../CLAUDE.md), [correction register](07-documentation-corrections.md) |

## Priorities

1. **Critical before expansion:** enforce validated publication and department/source-revision isolation before a second department publishes. Formal term/calendar rollout is deferred; see the clarification override in the plan.
2. **High:** preserve student-group membership and all teacher assignments; reject unknown resources, unapproved exclusions, overlapping clock intervals, and academic under-delivery.
3. **High:** reconcile the missing database baseline, RLS/grants, and commented-out Edge Function sources with the deployed system.
4. **High:** protect and bound engine jobs, retain immutable versions, and make concurrent publication deterministic.
5. **Medium:** replace template-dependent rendering, add cancellation-aware availability, and introduce verified offline snapshots.

The static model holds identity, authorization, referential integrity, conflict prevention, and publication validity. Department/calendar policies are versioned data. Imports, drafts, decisions, assignments, publication history, and synchronization cursors are operational records. A committee may amend a policy or input with a reason; it may not publish a collision by overriding an invariant.

## Evidence and limits

This audit inspected frontend/service/controller/model/router paths, all 15 checked-in SQL migrations, both Edge Function files, engine modules and tests, build/deployment files, and both original local workbooks. Macro instructions in a workbook were treated as data and never executed. No original workbook was saved, modified, or imported into a backend.

| Locally executed check | Result |
|---|---|
| `flutter test` | 60 passed |
| `flutter analyze` | No issues; 27.4 seconds |
| From `engine`: `.\.venv\Scripts\python.exe -m pytest tests -q` | 142 passed, 1 skipped; 74.10 seconds |
| `.\engine\.venv\Scripts\python.exe tool/audit_scheduler_probes.py` | All six gap probes reproduced; each misleadingly returned `validation.ok = true` |
| Read-only ZIP/XML/openpyxl inspection | Both workbook structures and input totals independently measured |

The optional full real-workbook solver test was **not enabled in this audit**. An existing readiness report records a prior full solve; that is historical evidence, not a new result. No live Supabase query, RLS execution, migration, deployment, push delivery, APK build, or device test was performed. Tests passing do not establish production correctness.

Local SDK cache reports Flutter 3.47.0 / Dart 3.13.0. The `flutter --version` command stalled and was interrupted; versions came from `C:/src/flutter/bin/cache/flutter.version.json`. Engine tests used Python 3.11.4, OR-Tools 9.15.6755, openpyxl 3.1.5, FastAPI 0.136.3 and pytest 9.1.1; deployment files request Python 3.12.7.

Existing edits to `.gitignore`, `admin_service.dart`, removed presentation files, `.claude/settings.local.json`, other audit documents, and the existing probe script were preserved. Only documentation was changed for this task.

## Decisions and access needed before implementation

| Need | Why it matters | Interim planning assumption |
|---|---|---|
| Sanitized production schema, grants, policies, migration history, extensions and function definitions | Repository migrations cannot bootstrap the backend | Treat SQL files as intended definitions, not verified deployment |
| Deployed Edge Function source, webhook authentication/configuration, Realtime publication and Storage policies | Both checked-in function files are comments only | Preserve Firebase; recover actual behavior before changes |
| Current workbooks from each department and a named academic approver | The available files describe Summer 2025 CSE, not all departments or the current term | Use them as historical regression fixtures only |
| Approved calendars, dates, holidays, campus timezone and study-stage mappings | Two/three-term labels do not define overlapping teaching dates | Asia/Dhaka campus timezone is proposed, not verified university policy |
| Meaning of 1.5-hour source duration versus 75-minute configured periods | Meeting counts alone cannot prove contact-hour compliance | Block unresolved duration conversion for new imports |
| Fixed two-session rule versus whole-term totals | Six offerings are short under the repository fixed-rate policy | Require an approved academic requirement before solving |
| Canonical teacher identities, merged-section membership, room capacities/equipment and shared reservations | Prevent cross-department and shared-resource collisions | Missing capacity remains unknown, never silently unlimited |
| Committee scopes, approval separation and emergency revision policy | Existing `admin` role is global | Add scoped capabilities without renaming existing roles |
| Cache retention, offline grace and minimum supported devices; expected campus scale | Security and performance targets need operational agreement | Read-only offline access, seven-day grace, proposed performance gates |

**Approval boundary:** review this package and resolve the academic requirements and deployment evidence before implementation. No production migrations, imports, service replacement, or major implementation work were performed.


## Clarification update (22 October 2026)

Read the [verified workbook/code/UI corrections](02-workbook-and-rules.md#verified-clarification-corrections---22-october-2026)
and implementation-plan priority override before using older proposals. Seasonal
summer/winter times and current batch progression are changeable configuration;
formal academic terms are deferred. B+C is authoritative source attendance,
imported teachers are retained, and existing CSE room functionality is reused.
The 125 observations flag stored anomalies, not invalid source classes. The
next bounded unit is parser/seasonal timing regressions; no runtime/data changes
were made during this documentation correction.
