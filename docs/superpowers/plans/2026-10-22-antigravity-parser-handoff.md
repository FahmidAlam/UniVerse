# Ready-to-paste Antigravity prompt

You are continuing UniVerse in `D:\flutter projects\universe_v1`.

Work on ONE bounded task: source-preserving regression tests for the routine
workbook parser and seasonal timing behavior. Do not fix runtime behavior or
advance to another task under this handoff.

First inspect these exact files:

- `docs/superpowers/plans/2026-10-20-university-timetable.md`: clarification
  priority override, bounded unit, and latest parser regression checkpoint.
- `docs/timetable-audit-2026-10-20/02-workbook-and-rules.md`: verified
  clarification corrections and seasonal timings. Do not repeat the audit.
- `lib/features/admin/services/routine_workbook_parser.dart`
- `lib/core/utils/clock_time.dart`
- `lib/core/models/routine_model.dart`
- `test/routine_workbook_parser_test.dart`, if present
- `test/clock_time_test.dart`

Verified context:

- Task 1 recovery and Task 2 catalog/service checks passed. Actual institutional
  identity backfill was not performed. Do not revisit those tasks.
- Formal academic calendars are deferred. Historical batch/stage observations
  do not establish current progression. Never invent term dates or current stages.
- Summer/winter times change. Use explicit synthetic grids in tests, not a
  universal clock grid, campus-hour assumption or month-to-season rule.
- Imported teachers are authoritative. B+C is one source-backed joint class for
  B and C; ordinary routine controls must not create combined groups. Preserve
  existing eligibility/off-day controls and CSE room pools.
- The current parser reproduces `11:10-12:15 PM` as 23:10 to 12:15; attached PM
  parses correctly. Explicit 06:10:00 is shifted to 18:10. A workbook/config
  timing mismatch originally produced no warning. These were reproduced defects,
  subsequently fixed in the later parser-fixes checkpoint. Do not recreate them.
- The sanitized snapshot has 96 midnight-end and 29 late-night-start anomalies.
  Their complete historical source lineage is unresolved. Do not rewrite them.
- Re-provided `workbook/` files match the historical Summer 2025 copies exactly;
  do not copy raw workbooks or personal data into tests.

Resume protocol:

1. Inspect git status and the latest checkpoint before editing. Many unrelated
   user changes exist. Never reset, stash, clean, overwrite or stage broadly.
2. If Codex partially completed the checkpoint, inspect its tests/results and
   finish only explicitly recorded remaining test cases.
3. If Codex completed and verified this checkpoint, report the checkpoint and
   STOP. Do not redo it or begin a parser fix automatically. The latest recorded
   result is 91 passing full-suite tests, zero skipped regressions, and clean
   targeted analysis after the later parser fixes. Verify the plan rather than
   assuming this remains current. This handoff does not authorize the next unit.
4. If fixtures are still needed, use small in-memory OOXML ZIP/XML fixtures and
   the parser's public API. Cover attached/spaced meridiems, noon/midnight,
   numeric Excel fractions/styles, explicit 24-hour input, source/config
   mismatch and two synthetic timing revisions. Do not use real source records.
5. Keep passing compatibility tests separate from correct-expectation known-bug
   tests. Reproduce failures before recording explicit skips. Do not assert
   broken output is correct or leave normal tests intentionally failing.
6. Run focused checks after any test edits:

   ```text
   flutter test --no-pub test/routine_workbook_parser_test.dart test/clock_time_test.dart test/timetable_settings_test.dart test/publish_gate_test.dart
   dart analyze test/routine_workbook_parser_test.dart
   ```

7. Update the existing implementation plan with exact progress, changed files,
   commands/results, skipped defects, blockers and next task. Claim only actual
   results. If SDK access is blocked, report the error instead of claiming tests
   passed or altering security/tool configuration.

Allowed edits: `test/routine_workbook_parser_test.dart`, small synthetic helpers
under `test/` only if necessary, and this checkpoint's progress in the existing
implementation plan. Runtime Dart/Python changes, dependency upgrades, schema
changes, migrations, database writes, production access, deployments, destructive
operations, unrelated refactoring and replacement authorization/allocation logic
are forbidden. Preserve existing user work and completed tests.

Stop and report a precise blocker if evidence or prerequisites are insufficient.
Never guess institutional policy, widen scope, or claim unverified success.
