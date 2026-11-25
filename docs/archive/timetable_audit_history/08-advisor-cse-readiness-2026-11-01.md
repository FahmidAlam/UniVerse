# CSE advisor-meeting readiness - 1 November 2026

Latest repeated-generation results and bounded fixes are in the
[cross-semester evaluation](09-cross-semester-generation-2026-11-01.md): three
Summer and three corrected Fall reconstruction runs, with final workbook and
actual app-parser reconciliation. The live publication remains unchanged.

**Superseded proposal notice:** the later user clarification did not approve
deactivating retake records. The 794-row proposal and its combined live repair
are withdrawn; the private SQL now raises an exception before any action. All
retake records and all hosted data remain untouched. Retakes are legitimate
offerings; repeated physical-resource overlaps require audience/source review,
not automatic removal. See the clarification checkpoint in the implementation
plan for pending-faculty and scoped-room behavior; the earlier 325/656 rehearsal
below predates preservation of 13 pending-faculty requirements.

Latest verified checkpoint: 190 Python tests passed, one skipped; 104 Flutter
tests passed; targeted Dart analysis clean. The Summer 2025 rehearsal now retains
338 offerings / 682 meetings, including 26 meetings with pending faculty, with
no reported teacher, room or student-group clashes. This is a historical
generator rehearsal, not certification of the Fall 2026 publication.

Room aliases and unavailable-room rules are explicit per-run inputs, with no
permanent RAB-104 exclusion. The reviewed Fall profile maps PHY LAB to RAB-106
and marks RAB-104 unavailable; existing UI profile persistence/selection and
deployment remain outstanding. For Sunday batch 62/I, CSE-4161 at 15:10-16:10,
both RAB-106 (apart from that meeting) and RKB-106 are free in the inspected
routine. Availability cannot establish which room was intended; retain the
source room pending confirmation. No hosted rows were changed. The 116 stored
23:50 starts still require a separately reviewed clock-only correction; no
retake deactivation is authorized. Next: prepare that bounded correction with
fresh version/content guards and retain all source meetings, then review the
two repeated resource-overlap pairs against authoritative audience information.

Meeting target: 2 November 2026, Asia/Dhaka. This distinguishes verified local
software/candidates from the live publication. No hosted changes have been made
by this audit. Academic completeness is not certified from a historical source.

## Current Fall 2026 publication

The live publication changed during inspection: an initial 128-row trimester
upload was replaced by a full 796-row upload. Final inspected source is
`9-5PM CSE Routine Fall_26.xlsx`, stored object
`timetables/CSE_Routine_Summer_2025_1793547700905.xlsx`, 356245 bytes, SHA-256
`371b2393c5416db7385eafb6a6bb4f711ac980613381e69aa804a3e5e33acdc9`.
Its Fall-2026 banner disagrees with the saved Summer 2025 metadata/settings.
Source timing is now 60-minute daytime periods, not the historical 75-minute
Summer 2025 grid. Batches/sections were read from each file, never hardcoded.

Verified live/source comparison:

- 796 published rows; the hash over day, batch, section, course, teacher code
  and room matches the fixed parser's source output exactly:
  `b01aaf676563105728f2337a17d4cfbf`. Teachers/rooms were not substituted.
- 116 stored intervals read 23:50-12:50. The source header is 11:50-12:50 PM;
  this is the already reproduced old-parser noon defect, not a timezone shift
  or permission to rewrite arbitrary AM values. The fixed parser reads these
  correctly. Source and live clock hashes therefore differ.
- Two exact duplicate Sunday Retake/DLD CSE-2221 meeting pairs occur in source
  D70/D73 and E70/E73. They cause two teacher, room and group overlap pairs.
  Both copies are identical in every stored column except UUID; no cancellation
  references either pair. No user triggers exist on routines.
- 368 live rows use teacher codes absent from the faculty catalog; 127 use room
  names absent from the room catalog. These are catalog-resolution gaps, not
  proof that the source teacher/room assignment itself is wrong. Do not invent
  aliases. The current Fall Course Distribution is not available, so current
  offering requirements cannot be independently reconciled against it.

## Reviewable Fall candidate and guarded correction

Private files are gitignored and contain original source data:

- `.task1-local/advisor-fall2026-PROPOSED-794.xlsx`: copy of the source with only
  redundant Sunday D73/E73 cells cleared. Original source bytes unchanged.
- `.task1-local/advisor-fall2026-PROPOSED-794.json`: proposed parsed rows.
- `.task1-local/advisor-live-correction-PROPOSED.sql`: not executed on hosted DB.

The candidate has 794 rows, zero invalid intervals and zero reported teacher,
room or participating-group overlaps. It preserves source teacher/course/room
labels, including the source's combined sections. This is structural validation,
not verification of room departmental permissions, capacity where unknown,
faculty identity aliases or current curriculum requirements.

Proposed live action requires approval: back up the current rows and active
version privately; correct exactly 116 start times to 11:50; deactivate one
redundant occurrence per duplicate pair (two rows retained, not deleted); update
active version label/count to Fall 2026 / 794. Preserve UUIDs, source files,
cancellations and all other fields. Do not change global generation settings.

The script pins the inspected version, count and full clock-content hash, locks
affected tables, rejects changed source/content or cancellation dependencies,
checks exact duplicate metadata equality and enforces final interval/overlap
checks and the exact reviewed 794-row clock hash
`1276323b61ec90f91fa66506eb5798bf`. It aborts rather than overriding drift.
An owned isolated PostgreSQL 15 rehearsal passed both stale-content refusal and
the correction: 796 UUID-preserved rows total, 794 active, no active bad clocks,
and exact candidate hash. This is not a claim of hosted execution.

A read-only private backup of all 796 affected IDs/clock/active fields and the
active version's label/count/validation has been saved as
`.task1-local/advisor-before-correction-private-backup.json`. No hosted mutation
has been performed; the requested correction approval remains pending.

## Historical Summer 2025 generator rehearsal

The unchanged distribution hash is
`3acf7cce904d3711898a127f89e344990c1411fda8d45e79dd3f77b7b7d27008`.
Used its own local config/timing grid and source-derived meeting counts; did not
change the live fixed-two/week setting or infer current semester progression.

- 325 retained offerings, 656 weekly meetings: 626 rendered and 30 service.
- CP-SAT returned OPTIMAL within a 120-second budget.
- All retained source offerings/teacher lists reconciled; no reported missing,
  extra or under/over-scheduled retained offerings, resource clashes, unknown
  generated rooms/teachers, blocked-day violations or unplaced rooms.
- All 178 modeled theory/lab pairs adjacent. Workbook rendered successfully.
- Private demo artifacts: `.task1-local/advisor-summer2025-generated.xlsx` and
  `.task1-local/advisor-summer2025-generated.json`.

Limits: 15 original source exclusions (including missing-teacher project rows)
and source warnings remain explicit, not academically approved by this audit.
The source's 1.5 duration versus period lengths and fixed-two/week shortfalls
need academic disposition. Unknown enrollment/capacity/departmental room access
cannot be certified. Historical split/co-teacher metadata is retained inside
the engine but not completely represented by legacy published routine rows.
Therefore this is a labelled generator demonstration, not a new current routine.

## Software defects fixed and verification

- Rendered upload now blocks publication for invalid validation; the UI no
  longer says clashes may be published. Missing/incomplete validation is denied.
- Workbook validation uses actual half-open time intervals, source-provided
  joint-section participation and invalid-clock counts, instead of equal-start
  comparisons that missed partial overlaps. Raw source rows remain visible.
- Engine rejects overlapping configured period grids, reserves each member of
  source joint sections and verifies output teacher lists against the source.
- Unconfigured rooms, unresolved faculty and known capacity violations are
  explicit failures. Nullable room capacity survives app config serialization.
  Known enrollment is allocated largest first with smallest suitable rooms;
  unknown capacity remains unknown. Room-kind pools and existing eligibility
  and off-day logic are reused, without inventing departmental room permissions.

Verification: 184 Python tests passed, one optional real-workbook solve test
skipped in the suite (the explicit real rehearsal above was run separately).
100 Flutter tests passed; targeted Dart analysis clean. New defects were
reproduced with failing tests first. Independent review found a capacity
first-fit issue; its regression was reproduced, fixed and reviewed again.

## Publication boundary and meeting demonstration

The live routine is not yet error-free: its 116 stored noon errors and two
duplicate occurrences remain until the guarded correction is approved/applied.
Local source changes are not proof the deployed app/engine has these fixes.
Direct manual writes and the existing SQL publish RPC do not yet enforce the
new client checks server-side; do not claim every API write is protected.
Global publication replaces all rows, so do not publish a trimester-only file
as though it merges with the full CSE routine.

For the advisor, show the labelled historical generated workbook and its measured
checks, plus the full Fall source/candidate and exact differences. If approved,
apply the guarded source-backed live correction, verify fresh readback and
student/teacher views, and record the result here. Keep unresolved academic and
catalog questions visible rather than advertising universal accuracy.
