# Repeated generation and cross-semester evaluation

Scope: local tests against the supplied Summer 2025 distribution and a fresh,
read-only capture of the current Fall 2026 publication. No hosted writes,
deployments, migrations or edits to original workbooks.

## Inputs and independent checks

- Summer: `workbook/Main_Distribution_Summer25.xlsx`, with its original row-5
  headers. Reconcile directly from source cells, separately from the production
  validator. Derived-count rehearsal uses 14 weeks, not the deployed fixed-two
  override. Missing faculty remains pending; two no-batch rows remain explicitly
  excluded, not silently scheduled under guessed groups.
- Fall: fresh capture of 796 active rows from the unchanged inspected version.
  Match every source identity and multiplicity to the recovered Fall workbook.
  Normalize exactly 116 reviewed 23:50 starts to 11:50 in the private rehearsal
  only; require all corrected clocks to match the parsed workbook. Preserve all
  repeated retake meetings and UUIDs in the raw snapshot.
- The reconstructed distribution copies the supplied sheet format, retaining
  its header names/order and styles, and appends explicit `Is Service`. It has
  no copied Summer routine/teacher sheets. `Class/Week` records observed meeting
  counts. Credits, enrollment, duration and whole-term class totals remain blank
  because the live routine cannot establish them. Its notes label it OBSERVED
  ONLY, not an authoritative distribution.
- Every run checks source offering/count/teacher preservation, pending faculty,
  course titles, allowed clocks/days, teacher off-days, physical-room identity,
  room inventory/type/known capacity and atomic combined-section overlaps.
  Independent resource checks use actual half-open clock intervals. Solver
  validation alone is insufficient.
- Export checks compare exact class-cell multiplicities and configured period/
  break headers. Generated workbooks also pass through the actual Flutter
  parser, comparing day/group/course/teacher/room/start/end against engine rows.
  Service meetings are checked in engine output separately from the main grid.

## Results

Three Summer generations produced distinct schedules, each preserving **338
offerings / 682 meetings**: 652 main-grid meetings plus 30 service meetings.
All retained 26 pending-faculty meetings. Source reconciliation and resource
checks passed on every run. All three exports were regenerated with the final
renderer and independently rechecked, including class cells and headers.

Fall reconstructs **415 offerings / 796 observed weekly meetings**. Initial
repeats found no solver/resource failures but exposed a source-classification
gap: four M. Sc meetings were incorrectly treated as service by a nonnumeric
batch heuristic. Final repeats use the explicit live service classification,
the source snapshot's study-stage map and the Fall 60-minute grid with its break
in column H. All three corrected generations were FEASIBLE, retained all 796
meetings on the main grid, and passed independent reconciliation/resource checks.
Their exported class cells and headers passed after the final renderer fix.

| Final profile | Runs | Offerings | Meetings/run | Independent errors | Export errors |
|---|---:|---:|---:|---:|---:|
| Summer 2025 derived-count rehearsal | 3 | 338 | 682 | 0 | 0 |
| Fall 2026 observed-only reconstruction | 3 | 415 | 796 | 0 | 0 |

Each profile produced three distinct schedule hashes with identical required
counts. All six final workbooks round-tripped exactly through the app parser:
Summer 652/652 main-grid rows per file (30 service meetings checked separately),
Fall 796/796 rows per file, matching teacher/group/course/room/clocks.
Final Python regression: **205 passed, 1 skipped** (the optional real-file solve
is covered separately by the repeated rehearsals). Flutter suite: **104 passed**.
Focused render/acceptance verification: **31 passed**; final review additionally
verified the Friday-header correction. Whitespace checks passed. A final
read-only content fingerprint matched the original 796-row live capture.

## Defects found and bounded fixes

1. An extra configured period column beyond the old D:K grid could retain stale
   template classes. Clear the union of original and configured class columns.
   Reject duplicate columns or overlap with Batch/Section/the configured break.
2. Nonnumeric local groups could be hidden as service teaching. Optional source
   `Is Service` explicitly overrides the legacy heuristic; invalid values or
   contradictory rows within an offering fail rather than being guessed.
3. The old break position was tied to Summer's layout. Run-specific
   `settings.break_col` now controls the break, including Fall's fourth morning
   period in G. Clear template merges before writing headers; a Friday-only
   regression found by review otherwise omitted the H2 break label.

Each defect was reproduced by a failing regression before its fix. Synthetic
season-change cases run three times per season and change batch, course code/
title, teacher, room, configured time and explicit study stage together. They
retain pending faculty and source combined sections. Negative checks detect a
removed faculty member without substitution, corrupted clocks/missing meetings,
invalid classification and unsafe template columns.

## Interpretation and unresolved prerequisites

The Fall rehearsal deliberately admits the 84 observed teacher codes with no
asserted off-days: appearance in a published routine does not prove current
employment or availability. Nine observed physical rooms are absent from the
captured catalog. No room metadata was fabricated; generated room choices use
the catalog pools plus the user-confirmed alias and RAB-104 exclusion. These
are test-profile constraints, not verified current room permissions/capacities.

Two observed offerings use different teachers across their live meetings.
The distribution model conservatively reserves all their known teachers and
prints the first source teacher; it cannot reconstruct each teacher's separate
meeting quota from aggregate rows. Twenty-one offerings have multiple meetings
on a source day, so this rehearsal explicitly allows same-day meetings. Neither
choice is an approved academic policy for future semesters.

The source Summer duration of 1.5 hours versus 75-minute configured periods
remains unresolved. The deployed fixed-two rule still differs from derived
delivery for six offerings. Summer current study stages are not approved;
existing fallback semester values must not be treated as current academic fact.
Course parity/lab inference, row-5 distribution layout and template layout
remain CSE adapter conventions. A passing test does not certify arbitrary
departments, unknown formats or unprovided academic requirements.

Live data still requires its separately reviewed clock-only correction and
source review of the two overlapping retake pairs. No repeated meeting was
removed. No inference resolves the possible RAB-106/RKB-106 typo. New per-run
break/room policies are engine inputs; UI persistence/deployment is not included.

## Reproduction and deliverables

`engine/.venv/Scripts/python.exe tool/cross_semester_rehearsal.py --repeats 3 --seconds 60`

Requires the already-authorized private live capture/parsed source and captured
configuration. The tool has no hosted write path. Original-file hashes guard
against source changes; raw/source identity and clock mismatches abort.
Private artifacts live in ignored `.task1-local/cross-semester/`: reconstructed
distribution, six generated JSON/workbook pairs, configs, provenance, inventory
gaps, per-run summaries and Flutter round-trip results. Do not commit them.
