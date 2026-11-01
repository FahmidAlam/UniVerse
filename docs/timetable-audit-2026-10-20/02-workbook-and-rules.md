# Workbook evidence and scheduling rules

Both files were inspected read-only with ZIP/XML and openpyxl, with formulas and cached values loaded separately. No Excel process, VBA, formula calculation, hyperlink traversal, seed script or import ran. Contact data is omitted.

## Source identity and scope

| File under `engine/routine generation files/` | Bytes | SHA-256 |
|---|---:|---|
| `Main_Distribution_Summer25.xlsx` | 487599 | `3acf7cce904d3711898a127f89e344990c1411fda8d45e79dd3f77b7b7d27008` |
| `CSE Routine Summer'25 Version 2.0.xlsx` | 401046 | `8fe97782c8108477b301e8ba87ed1edc103122b869115a2c27a6a02a1013fe8a` |

These are historical Summer 2025 sources. Their names and content do not establish current-term authorization. Preserve them as regression evidence; do not import their rows into a 2026 term automatically. No workbook for a full non-CSE department was available.

## Distribution workbook inventory

All 14 worksheets are visible. “Missing cache” means a formula cell has no cached value; it does not prove every such formula is erroneous.

| Sheet | Used dimensions reported by workbook | Formula cells | Missing cache | Treatment |
|---|---:|---:|---:|---|
| Course Distribution | 531 × 26 | 646 | 0 | Candidate offering input, header row 5 |
| Distribution_Stats | 350 × 26 | 869 | 288 | Historical derived checks; not requirements |
| Routine_Stats | 574 × 43 | 2799 | 152 | Historical cross-sheet calculations |
| Sunday | 238 × 31 | 455 | 4 | Existing timetable reference, not offering input |
| Monday | 238 × 31 | 452 | 4 | Same |
| Tuesday | 238 × 31 | 454 | 4 | Same |
| Wednesday | 238 × 31 | 455 | 4 | Same |
| Thursday | 238 × 31 | 455 | 4 | Same |
| Friday | 238 × 31 | 455 | 4 | Same |
| Saturday | 238 × 31 | 455 | 4 | Same |
| Weekdays | 297 × 26 | 1738 | 244 | Derived layout; 130 hidden rows |
| Weekend | 29 × 9 | 0 | 0 | Historical layout |
| Teachers | 778 × 26 | 3077 | 120 | Derived/reference material, sensitive fields excluded |
| Instructions | 25 × 9 | 0 | 0 | Historical workbook operation instructions only |

Hidden rows/columns exist in supporting sheets: Distribution_Stats has one hidden row; Routine_Stats one hidden column; day sheets two hidden columns each and most one hidden row; Teachers three hidden rows and one hidden column. Merged banners and extensive formatted empty regions mean worksheet dimensions are not record counts.

No VBA parts, Excel macro sheets, ActiveX parts, external-link parts or external relationships were found in the distribution archive. Its Instructions sheet nevertheless says “enable macros” and contains legacy formula-repair/layout directions and a 2018 marker. These directions are obsolete scaffolding, not instructions for the importer. No macros were found to execute or remove.

### Companion published routine

12 visible sheets: Sunday–Saturday, Student Day Off, Teacher Day Off, Teacher Information, GED Teacher Info, Room Acronym. Day-sheet dimensions are 705–707 rows × 15 columns, with five hidden rows each; much of this is formatting. Teacher Information has two hidden columns.

The three formula-bearing sheets have 54, 38 and 1 formulas respectively, all with cached values. There are four external **hyperlink** relationships, no external workbook links, VBA, macro sheets or ActiveX. Hyperlink destinations were not followed or reproduced.

`engine/tools/seed_config.py` documents a separate historical extraction path:

- Teacher Information: acronym C, name D, home department E, designation F, data from row 4.
- GED Teacher Info: home department C, acronym D, name E, designation F, data from row 8.
- Teacher Day Off: acronym B and Sunday–Saturday booleans C:I, from row 5; true means unavailable in that extractor.
- Room Acronym: room token B, augmented by rooms mined from day grids.

Those are existing extractor bindings, not proof that historical availability or room inventory remains valid today. Never run this script as an audit step: it rewrites config and seed files. Student Day Off is potential policy evidence but is not consumed by the current importer.

## Source-to-domain mapping

Proposed target names are defined in the target architecture and migration plan. Every staging value retains file hash, sheet, row, column, raw value/type and normalization decision.

| Source / column | Current behavior | Proposed target and validation |
|---|---|---|
| Course Distribution A `Batch` | Numeric strings normalized, used in cohort label | `cohorts.intake_label`, scoped by program; reject fractional numeric labels rather than truncate |
| B `Section` | Literal string; blank allowed; `B+C` is one label | `student_groups.code`, explicit offering-group links; B+C means joint attendance of B and C (user-confirmed); require source-cell evidence for each occurrence; do not assume WD+WE semantics |
| C `Course Code` | Offering key, even last digit means lab | `courses.code` with owning department; case/alias normalization, no universal digit rule |
| D `Course Title` | Display, falls back to code | Course title/version; disagreement between grouped rows is a review issue |
| E `Credit` | Parsed; modal-count warnings | Nonnegative decimal credits on course/offering; academic contact-hours rule separate |
| F `Prerequisite` | Ignored | Optional curriculum metadata; not a weekly collision constraint |
| G `Conducting Department` | `course_dept`, not solver ownership | `courses.department_id` through reviewed alias map; distinct from host student program and teacher home department |
| H `No. Of Students` | Parsed, unused for rooms | Offering enrollment estimate or group count; positive known count, otherwise explicitly unknown |
| I `Teacher` | Acronym; blank excluded; co-teachers grouped in sheet order | Proposed teacher links with role and effective weeks; retain an explicitly unassigned offering when blank; resolve nonblank identities and reject unresolved or inactive assignments |
| J `No. Of Classes` | Sum all grouped rows, derive ceil(total/weeks) | Approved term meeting/contact requirement; distinguish team teaching, split teaching and duplicate rows before summing |
| K `Class Duration` | Warn unless 1.5; not retained on sessions | `duration_minutes` after approved unit conversion; preserve raw 1.5 value; validate against contact-time rules |
| L `Class/Week` | Fallback hint, overridden by total/fixed count | Requirement evidence only; compare with total and approved weeks; disagreement requires resolution |
| File/context and banners | No reliable explicit term identity | Bind department/program and immutable distribution/source revision; formal calendar/term modeling is deferred, not an import prerequisite now; never infer current progression from filename |
| Companion day grids, time headers | Rendered-routine parser reads cells | Historical assignments or staged manual import; cannot establish all required offerings alone |
| Companion teacher/room sheets | Seed script mines reference records | Staged aliases/availability/resource metadata, approved before updating canonical records |

## Measured quality and ambiguity

- 358 rows have a course code; 356 also have a batch. Current normalization produces **325 offerings**, **18 shared-teacher offerings**, **55 non-service cohort labels**, **76 teacher codes**, and **15 exclusions** (13 no teacher, 2 no batch).
- Derived mode at 14 weeks produces **656 sessions: 626 rendered + 30 service**. Required-frequency histogram: 319 offerings at two/week, six at three/week.
- Fixed two/week mode produces **650 sessions: 620 rendered + 30 service**. Six offerings with 38 term classes are reduced from three/week to two/week. A 14-week repeat delivers 28 rather than 38 meetings.
- All 358 duration cells are 1.5; all weekly hints are numerically 2. The configured main periods are 75 minutes, with an 80-minute online slot. It is unresolved whether 1.5 means literal hours, academic units, or obsolete metadata.
- All 325 retained offerings lack a usable student-count value. No capacity compliance can be claimed from this source.
- Retained offering department values: blank 224, MAT 28, GED 44, EEE 21, `EEE` repeated across a newline 2, BuA 6. Raw excluded project rows use `Project`. Blank is not evidence of CSE ownership; Project is not necessarily a department. The application list uses BBA/English where workbook labels include BuA/ENG; aliases require confirmation.
- Combined section labels include **B+C** and **WD+WE**. Literal string equality cannot detect membership overlap.
- 308 formulas occur in J and 338 in L; no cached Excel error values were found in the input sheet. Cached results can still be stale; this audit did not recalculate formulas.
- No identical full 12-column course rows were found. Repeated cohort+course rows do exist for split teachers; deduplicating them indiscriminately would lose requirements.
- Current code treats numeric batches as home cohorts and nonnumeric/GED/WD/WE labels as service. That classification is not a university-wide rule.

## Proposed import contract

1. Authenticate uploader and bind import to an authorized department/program and an identified distribution revision; formal term/calendar binding is deferred. Compute file hash and store an immutable private original with an import record.
2. Preflight OOXML structure before loading: compressed upload ≤10 MiB, total expanded XML ≤100 MiB, ≤100 sheets, ≤50,000 nonempty input rows, ≤1,000,000 cells processed. These are proposed initial limits, subject to measured campus scale. Reject macros/embedded executable objects and encrypted/unsupported formats; do not execute or follow links.
3. Inspect formulas and caches separately. Reject missing/error cached values in required input cells; warn on cached formulas requiring confirmation. No server-side Excel automation or arbitrary formula execution.
4. Select a versioned mapping profile. Current CSE profile recognizes row 5; new profiles may locate headers in a bounded first 20 rows. Require exactly one match per required header and reject ambiguous prefixes.
5. Normalize to staging, resolving aliases through approved catalogs. Detect duplicates, split/co-teaching ambiguity, durations, counts, group membership and missing resources.
6. Account for every nonblank candidate row as retained, merged, approved exclusion, or blocking issue. Preserve references from merged offerings to every input row.
7. Committee reviews a manifest with counts and decisions. A blank teacher is an unassigned state, not evidence of an invalid course or an automatic exclusion. Retain the offering and flag its assignment as pending; a nonblank unknown teacher remains an unresolved identity. Whether pending assignments block generation or publication requires academic approval. Historical sheets are excluded with an adapter-level reason, never silently deleted.
8. Freeze approved normalized input and policy/resource revisions. Generate only from that snapshot. Re-import of the same hash+mapping+destination is idempotent; corrected source creates a new revision.

Historical distributions remain archival. When dated scheduling is introduced, date-based exclusion needs verified effective dates, not the current clock alone. Do not copy timetable cells from obsolete day sheets into a new generation request. Importing a rendered routine is a distinct staged-assignment path and must reconcile against approved requirements before publication.

openpyxl reads cached values but does not calculate formulas; that is why the importer needs a cache policy rather than assuming `data_only=True` validates calculations. [openpyxl usage documentation](https://openpyxl.readthedocs.io/en/stable/usage.html)

## Academic structure clarification

The workbook is a historical snapshot, not a permanent cohort or section inventory, admission schedule, or proof of a universal academic calendar. Cohorts enter and progress under approved program rules and can graduate or be archived; sections belong to their cohort and their number can vary. Department/program calendars may differ in term count, progression and scheduling rules. Confirm actual policies and mappings before configuring them. The 15 exclusions above describe current parser behavior, not approved exclusions or proof that every blank-teacher row is non-timetabled.


## Verified clarification corrections - 22 October 2026

**Later source recovery:** read-only hosted metadata located the actual 795-row
upload, originally `DOC-20261009-WA0035.xlsx`. The stored object
`timetables/CSE_Routine_Summer_2025_1791562982460.xlsx` is 295039 bytes, SHA-256
`466157f8d40742f247f79376e8d2ffc522f156b0bf39853a2fb0675b0ff56542`.
Its banner reads Fall-2026, so the saved Summer 2025 label is stale metadata.
An ignored local copy parsed through the fixed parser produces exactly 795 rows:
96 at 11:10-00:15 from Sunday-Thursday F2 strings explicitly ending AM, and
29 at 11:10-12:15 from Friday/Saturday F2 strings ending PM. This supersedes
the missing-source conclusion below. The 29 late-night starts are explained by
the reproduced uploader suffix defect; the other 96 preserve an explicit source
AM value that requires source-owner correction before changing data. No stored
row was modified. These recovered times describe that source revision, not a
universal fall/winter or summer clock grid.

Exact-label aggregate checks also found 356 routine rows without a matching
faculty acronym and 127 without a matching room name in the existing catalogs.
Only reviewed identity reconciliation can address those gaps. Bulk sensitive
production identity export was rejected by automatic review; explicit approval
is pending. No record export or hosted backfill has been performed.

This section supersedes conflicting priority/authority language above. Inspection
was read-only: original workbooks were neither recalculated nor saved, and no
source/config/seed script or database write was executed. An ignored local Flutter
probe exercised the existing public parser and `RoutineEntry.timeLabel`; it is
an audit observation, not a committed regression test or a fix.

### Academic configuration and progression

**User-confirmed current policy:** the two most senior batches follow trimester;
the others follow bi-semester. This is changeable configuration, not a formula
based on numeric batch labels. The two available originals are Summer 2025
snapshots (hashes above), not evidence identifying today's two senior batches.
A scan found no explicit trimester/bi-semester declaration in these workbooks.
Formal term/year/calendar modeling is deferred; do not request invented term
dates or make that larger feature a prerequisite for import/clock corrections.

`Course Distribution!A5:L5` contains no semester/study-stage column. A historical
semester value, when explicitly supplied elsewhere, is an observation at that
source revision, not today's status. The current engine's `solver._assign_rooms`
uses `semester_map` if supplied, otherwise newest-batch arithmetic clamped to
1-8. `RoutineWorkbookParser._finish/_semesterFor` uses an explicit tabular
semester or similar arithmetic; the rendered-workbook path ignores
`semester_map`. Settings preserves that map but has no dedicated map editor.
These are current compatibility behaviors, not verified academic progression.
Even the solver comment claiming the fallback is correct for bi-semester must
not be treated as evidence that it is correct for the current university.

Next design decision: retain a versioned batch -> study-stage observation with
source revision, verification/approver and effective/as-of context. Confirm a
current observation from the current authoritative distribution or academic
record; if stage is absent, leave it unresolved instead of incrementing from a
2025 workbook, course code, elapsed year, or batch rank. Historical routine and
profile values must not be bulk promoted. Calendar-system assignments can later
be separately versioned with effective applicability when that feature is needed.

### Combined attendance is source data

**User-confirmed meaning:** B+C is one class attended by both B and C. Verified
occurrences are in `Course Distribution!B315:B318`, `B349:B350`, batch 58.
Rows 316/350 and 317/349 share course/group keys with different teacher rows;
retain all source rows when grouping, rather than duplicating the class or
losing teacher provenance. This does not authorize creating combinations for
other batches. WD+WE also appears (rows 326-329 and 343), but its atomic-group
meaning is not established by the B+C clarification.

Use one offering/meeting with explicit atomic B and C links, each linked to the
verified source cells. Rendering may retain B+C as the display label; conflict
checking, retrieval, notifications and availability must include both members.
`ingest.py` and current student queries still use literal section keys, so that
end-to-end behavior is not implemented merely because Task 2 has group links.
`routine_management_screen.dart` has a free-text Section field and can currently
save arbitrary B+C text; that is a gap, not an authorized source of combinations.
Future routine controls may select a verified existing group relationship but
must not infer, concatenate, create or redefine one. Do not add a generic
combined-section editor or treat the alias RPC as source verification by itself.

### Imported teachers and existing controls

`Course Distribution!I5` is Teacher; `ingest.py` reads I for each row, groups
teacher rows and `solver.py` schedules the supplied teachers. The distribution
is authoritative for its own assignments. An unconfigured/missing database
eligibility list does not authorize substituting another teacher.

The current screen titled **Course Assignments** is
`manage_course_eligibility_screen.dart` / `CourseEligibilityController`: it edits
faculty-course eligibility and priority, not distribution offering assignments.
No eligibility rows means unconfigured; configured violations are reported by
the engine and block the generation screen's publish gate. Priority is parsed
but does not cause teacher reassignment. **Manage Faculty** edits identity,
department, active status and off-days. **Routine Management** independently
allows direct teacher code/name edits through `RoutineAdminController` and
`RoutineService`, bypassing an import assignment manifest. Record this bypass;
future reconciled edits need explicit source correction/revision and validation,
not a second competing assignment system. Keep working eligibility/off-day UI.

### Department room evidence and existing allocation

The distribution has explicit historical notes:

| Source cell | Exact allocation note |
|---|---|
| Weekdays!G270 | R-302/304/306/309 - CSE Rooms |
| Weekend!E18 | R-302/304/306/309 - CSE Rooms |
| Weekend!E19 | R-202, 206 - EEE Rooms |

These notes establish source evidence, not a current complete access matrix.
Do not equate R-302 with RAB-302 or another building without verified aliases.
The companion Room Acronym sheet lists names/buildings, not per-department
permission. Existing `seed_config.mine_rooms` mines that legend and day-cell
room tokens into inventory; it does not consume these allocation notes and was
not run. Manage Rooms edits name/building/type/active; config serialization sends
active name/lab/gallery only. The current CSE solution does enforce distinct
lab/theory pools, simultaneous pool limits, first-fit unoccupied rooms and TBA
failure reporting. It does not enforce per-department eligibility: department,
capacity and features do not survive `_normalize_config` into room allocation.

Reuse that working inventory, screen, room pools and failure reporting. First
normalize verified source room aliases and allocation applicability, then extend
eligible-room selection only where the existing solution lacks the rule. Do
not build another inventory/allocator or claim departments have no source rules.

### Time anomaly: source -> parser -> stored value -> display

The sanitized stored-row snapshot contains **96** `11:10:00 -> 00:15:00` and
**29** `23:10:00 -> 12:15:00` observations, totaling **125**. These are anomalous
stored intervals, **not a finding that 125 source classes are invalid**.

Source types were checked with openpyxl and raw OOXML. The distribution's
historical Sunday headers E1/I1/M1 are numeric serials
`0.3958333333333333`, `0.4583333333333333`, `0.5208333333333334`, formatted
`h:mm AM/PM` (09:30, 11:00, 12:30). The companion Sunday D2/E2/F2 are shared
strings, `08:50-10:05AM`, `10:05-11:20AM`, `11:20-12:35PM`, with General format.
Do not treat all Excel times as strings, or all strings as numeric serials.

| Boundary | Verified current behavior / audit observation |
|---|---|
| Original companion -> public Dart parser | 629 rows parsed; six daytime intervals; 115 at 11:20-12:35; no end-before-start intervals. Available template, expanded file and generated workbook use the same historical header times. |
| Numeric XML values -> parsing | `_cellText` returns raw cached text without applying Excel styles; `ClockTime.normalize` supports fractional-day numbers. Distribution ingestion consumes Course Distribution, not these historical day-sheet clocks. |
| Header parsing -> transformation | `_timeRange` copies a detected endpoint meridiem to the other endpoint. `_meridiemOf` uses word boundaries: `12:15 PM` matches, `12:15PM` does not. Current public parser reproduces `11:10-12:15 PM` as **23:10 -> 12:15**, but `11:10-12:15PM` as **11:10 -> 12:15**. This is a verified spacing-sensitive noon-crossing parser defect. |
| Other representative header | `11:10-12:15AM` reproduces **11:10 -> 00:15**; this demonstrates one possible input path, not proof that the unavailable original 96 headers contained AM. No silent AM/PM correction is justified from this alone. |
| Settings/engine/render | Config periods are normalized/repaired before engine use; engine room assignment copies period start/end; `render._period_label` prints only the end meridiem. `_daySheetSlots` can overwrite repaired config slots with parsed headers without repairing the resulting header list. A source/header/config mismatch therefore needs explicit provenance. |
| Publish/storage | `RoutineEntry.toMap` transmits the parsed strings; `publish_routine` casts them to `time`; `routines` columns are `time without time zone`. The reconciled snapshot already contains the anomalous values. No timezone conversion is present in these inspected write steps. |
| Retrieval/UI | `RoutineService` reads/orders stored strings; `RoutineEntry.fromMap` preserves them; `_to12h/timeLabel` formats them without AM/PM repair. Probe outputs are `11:10 PM - 12:15 PM` and `11:10 AM - 12:15 AM`. `startOn/endOn` use the same local date, so status/countdown can also be affected. Rendering alone cannot explain anomalous values already present in the snapshot. |

**Proven root cause for the reproduced 23:10 path:** shared-meridiem propagation
across noon plus whitespace-dependent detection in the uploader. **Unresolved:**
which source bytes, parser/deployment revision and settings produced each of
the 125 stored observations, especially the 00:15 class. Available sources use
batches 58-66 and 08:50/11:20/12:35 periods; the snapshot uses batches 61-69 and
09:00/11:10/12:15. They are not interchangeable provenance. No live publish or
storage write was executed during this trace; storage/retrieval conclusions use
inspected code/schema and the supplied reconciled snapshot, not a claimed live
re-enactment of its unavailable original import.

**Next safe work:** capture these parser/formatter cases as source-preserving
regressions and design a bounded fix for independent start/end meridiems and
header/config agreement, after matching the missing source if obtainable.
Keep the 125 observations and their original values for review. Do not weaken
same-day validation, discard rows, mass-add 12 hours, or rewrite stored times.


### Re-provided source files and seasonal timings

The user re-provided `workbook/Main_Distribution_Summer25.xlsx` and
`workbook/CSE Routine Summer'25 Version 2.0.xlsx` during this review. Both were
opened read-only and their SHA-256 hashes exactly match the originals listed
above. The renewed copies therefore confirm the same source-cell evidence,
batches 58-66 and historical timing grid; they do not establish the source
lineage of the later 795-row snapshot. No further file request blocks the
present documentation correction. Keep that historical lineage unresolved.

**User-confirmed:** class timing changes between summer and winter. Clock
boundaries are configurable operational policy, not a permanent legacy grid.
The available files establish Summer 2025 times only, not a winter grid or a
current-season default. A numeric period index/Excel column is a layout key,
not a permanent time or duration.

Reuse the existing Timetable Settings period editor, config normalization and
renderer header generation. Bind each imported/generated/published revision to
its verified effective timing configuration (season/applicability and source).
Do not infer the selected season from today's month, overwrite an old routine
when settings change, or repair historical times against the active season's
grid. Compare source workbook headers with the selected configuration and
surface differences before approval. Formal academic-term modeling is not
required to describe this timing revision boundary. Fixed template columns,
parser fallback slots, `AppConstants.timeSlots`, and ClockTime's campus-hour/
12-hour repair assumptions require explicit compatibility tests; their existing
constants are not institutional invariants. No current winter times are known
from the inspected evidence, so none have been invented.
