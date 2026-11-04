# UniVerse Timetable Engine

FastAPI + OR-Tools CP-SAT + openpyxl. Current contract reviewed 4 November 2026.
Immediate product priority: browser-based admin extension of the existing Flutter
application, then complete CSE committee configuration/generation. This guide
and the [audit roadmap](../docs/timetable-audit-2026-10-20/15-admin-web-preimplementation-2026-11-04.md)
do not authorize implementation or deployment.

## Pipeline and inputs

The [later committee decisions](../docs/timetable-audit-2026-10-20/18-committee-decisions-and-policy-baseline-2026-11-04.md) now confirm independent section weekend defaults/overrides and batch off-day spread <=1, permanent attendance distinct from teaching, adjunct distinct-course counting, exactly two same-day consecutive same-room meetings for 1/1.5/2-credit CSE theory, and explicit permission for the relevant sessional pair across break. They are not yet implemented. Three-credit counts/spread and adjunct band strictness remain unresolved until dependent implementation. Existing `off_days` is reusable faculty configuration, not a section-weekend model.

CD1 adds an editable distribution draft: preserve original bytes/formulas/cached values; accept traceable validated source corrections; normalize one pinned effective revision for generation, validation, preview, export and publication. The current multipart file/config endpoint and generated-routine draft JSON do not supply this contract. Agree the normalization/revision boundary before adding consumers; no second UI-only truth or silent original workbook edits.

The Flutter client submits a required distribution `.xlsx` plus optional engine
configuration. `main.py:_run_job` normalizes config, ingests grouped offerings,
solves day/period placement, assigns concrete rooms greedily, validates, and
renders the template workbook. It returns main and service rows separately;
service rows reserve real faculty/rooms but are not drawn on the main grid.

`ingest.py` reads `Course Distribution`, headers at row 5 and data from row 6.
Header names determine columns. One cohort/course is an offering; split-teacher
rows preserve attached teachers. Blank faculty remains pending instead of being
dropped. No-code/no-batch exclusions and source warnings remain explicit.
Optional `Is Service` accepts true/false, yes/no or 1/0; contradictory values
within an offering fail. Without it, legacy CSE classification applies.

Meeting counts use a positive fixed override, otherwise ceil(term class total /
teaching weeks), then per-week hint, then two. Fixed-rate source under-delivery
is warned about; matching that fixed count is not proof of approved contact-hour
compliance. Credit-based committee policies are not yet implemented.

Normal config shape is `rooms[]`, `teachers[]`, `days[]`, `eligibility[]`,
`settings{periods, weeks_in_term, ...}`. `GenerationProfile` in Flutter can supply
a source-matched complete run configuration, always as private preview. Local
canonical records in `domain.py` are additive contracts; legacy solving does not
yet consume `NormalizedInput.external_reservations` or all canonical identities.

## Existing mandatory checks and preferences

- Place every imported weekly meeting once; reserve all attached teachers and
  source-backed atomic members of joint sections such as B+C.
- Respect faculty whole-day exclusions and global day/period blocks. Overlapping
  usable clock periods are rejected during configuration normalization.
- Bound simultaneous lab/theory usage and EEE/ECL versus CSE lab usage by pool
  counts. Concrete allocation checks known capacities and canonical room aliases.
- An offering normally cannot meet twice in a day. Engine config allows explicit
  exemptions/global relaxation; relaxed repeats can still be penalized.
- Default hard adjacency pairs sibling theory and sessional courses using the
  legacy odd/even code rule. This is not two meetings of one sessional course.
  Engine `lab_adjacency` can be hard/soft/off; normal DB UI does not expose every
  engine option.
- Objective terms favor fewer active section days and avoid the final period;
  optional same-day repeats and soft adjacency have penalties. A `spread` weight
  may be stored by the UI but is not currently a load-balancing objective.
- Validation checks counts, identities, clashes, day/slot restrictions, lab
  category, eligibility, known capacity and room allocation. Unknown nonblank
  faculty is fatal; pending faculty is counted separately and is not inherently
  fatal. Error examples are capped at 50 while counts remain exact.

A feasible time placement does not guarantee successful greedy room assignment.
Failures produce TBA diagnostics and invalid validation. Per-slot faculty/room
availability, section weekends/fairness/gaps, employment-category workloads,
SUST travel preferences, exclusive Physics course-code routing, and the new
credit/block rules remain missing or partial. See the
[16-rule matrix](../docs/timetable-audit-2026-10-20/16-committee-traceability-2026-11-04.md).
Do not describe every result as guaranteed conflict-free or academically approved.

## Renderer and publication boundaries

Conflict reporting must follow confirmed D6. Current `_infeasible_message()` calls nonaccepted solver statuses “No feasible timetable” and suggests relaxing adjacency; that is an implementation gap. Future outcomes must separate proven infeasibility, timeout/budget, unknown, invalid/incomplete input, allocation failure and network/service failure. Do not automatically enable break crossing or weaken a mandatory rule. Authorized traceable configuration changes require validation/generation again.

`render.py` uses `templates/CSE_Routine_TEMPLATE.xlsx` with explicit period
columns (`col`) and `break_col` (default G). Columns must be unique and may not
overlap Batch/Section or the break. Cohort capacity is checked against template
furniture, not fixed at 55 rows. Pending teachers print as TBA with a Sunday
legend. The template still needs validation for each approved grid revision.

Flutter generation/upload uses a client gate then `publish_routine`; migration
014 globally replaces current rows atomically. It is not a department merge or
full historical snapshot store. The RPC checks admin/nonempty input, not an
independent recomputation of supplied validation. Manual CRUD remains a separate
write path, and workbook-upload validation is narrower than generator validation.

## API

| Method/path | Contract |
|---|---|
| `GET /` | Health/version JSON |
| `POST /api/timetable/generate` | Multipart required `file`, optional JSON-string `config`, `time_limit_s` default 60; returns job_id |
| `GET /api/timetable/status/{job_id}` | queued/ingesting/solving/rendering/done/failed, progress, metadata/error |
| `GET /api/timetable/result/{job_id}` | rows, service_rows, stats, validation, report, has_workbook |
| `GET /api/timetable/download/{job_id}` | Rendered XLSX bytes |

The old optional-JSON/fixtures generation contract is obsolete. The filename
check accepts `.xls`, but openpyxl requires `.xlsx`. Jobs live in process memory,
with a daemon thread per request, wildcard CORS, no authenticated ownership,
no bounded admission/eviction and no restart recovery. This needs operational
hardening before broader use; CORS is not authorization.

## Local run and verification

Use an already approved environment. The following are setup/reference commands,
not instructions to install dependencies during a documentation-only audit.
Deployment files request Python 3.12.7; validate the actual interpreter separately.

```powershell
Set-Location engine
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements-dev.txt
.\.venv\Scripts\python.exe -m uvicorn main:app --reload --port 8000
.\.venv\Scripts\python.exe -m pytest tests -q
```

Android emulator local access uses `http://10.0.2.2:8000`; browser origins and
physical devices need appropriate separately approved endpoints. Private
workbooks/profiles are test inputs, not CI fixtures or authorization to publish.
`tool/cross_semester_rehearsal.py` records source/reconstruction rehearsals;
observed published meetings are not an approved academic distribution.
`tools/seed_config.py` rewrites configuration/seed files; do not run for inspection.

Fresh audit checks, 4 November: 210 engine tests passed, one optional full solve
skipped; 115 Flutter tests passed. No browser build, hosted mutation, deployment
or end-to-end push verification occurred. Render/Procfile declarations describe
hosting commands, not verified account linkage, uptime or automatic deployment.
