# Advisor showcase implementation plan

> Execute inline using executing-plans. User owns every Git state change and
> deployment. Preserve the current dirty branch and all unrelated edits.

Objective: demonstrate real Flutter file â†’ configured engine â†’ validation â†’
preview for Summer distribution and observed-only Fall reconstruction on 3 Nov.
No hosted writes, production publication or speculative academic data changes.

- [x] R5: add validated, explicit per-run JSON profile import to Generate UI.
  Profiles carry full run configuration, source provenance and count policy;
  never mutate database settings. Source-derived Summer totals require six
  CSE-4116 offerings to meet three/week (38/14 rounded up), explaining 682 vs
  fixed-two 676. Fall profile preserves observed weekly counts, not invented
  term totals. Imported profiles are private previews, not publication approval.
- [x] R4/R6: retain co-teachers in RoutineEntry/draft serialization and preview;
  match source combined sections in readers; block publication when legacy
  storage would discard shared-teacher identities. Keep validation fail-closed.
- [x] R7: physical identity comparison in current room readers and draft
  inspection; use confirmed alias only, never RAB-106 â†’ RKB-106 or a permanent
  RAB-104 purpose assumption.
- [x] Add narrow service/controller injection to exercise the actual screen
  and real multipart/poll/result/download integration without production writes.
  Make local draft download avoid incidental Storage upload for preview runs.
- [x] TDD focused configuration/identity/gate/UI tests, then real generation
  through Flutter with both required files and actual result widgets. Check
  invalid-result presentation, shared identities and source reconciliation.
- [x] Run necessary regression/analysis checks; attempt existing Pixel_9 device
  verification. Record exactly what ran and any unverified device steps.
- [x] Update original plan/readiness checkpoint and write a short showcase
  handoff/runbook with classification and private artifact locations.

Deferred: broad R1-R3/R8-R12 hardening, notifications/OAuth rollout, historical
schema replay, canonical backfill and production data correction. No successful
CLI solve or APK build alone establishes SHOWCASE READY.

Checkpoint: completed for the private local showcase; see
[actual device evidence and remaining limits](../../timetable-audit-2026-10-20/11-advisor-showcase-2026-11-02.md).
113 full Flutter tests, then 34 focused tests after text polish; analysis clean;
3 source-count checks passed. Two real Android positive runs (682/796), exact
draft reconciliation, workbook reconciliation and one visible INFEASIBLE run.
Normal login, Render/physical-phone workflow and production rollout remain unverified.
