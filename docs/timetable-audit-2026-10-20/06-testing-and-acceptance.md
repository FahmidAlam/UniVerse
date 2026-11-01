# Testing and measurable acceptance

## Current baseline, executed 20 October 2026

| Check | Result / scope |
|---|---|
| `flutter test` | 60 passed; clock, settings, publication gate, auth/controller/router and registration widget tests |
| `flutter analyze` | No issues; 27.4 s |
| `cd engine`; `.\.venv\Scripts\python.exe -m pytest tests -q` | 142 passed, 1 skipped; 74.10 s |
| Existing synthetic `tool/audit_scheduler_probes.py` | Six semantic gaps reproduced with false-positive `validation.ok=true` |
| Workbook inspection | Structural/count evidence in workbook report; no formula recalculation |

The skipped test is the optional real-distribution full solve requiring `UNIVERSE_SOLVE=1`. Real-file ingestion tests ran because files were present. This audit did not rerun the full solve, build an APK, exercise live RLS/Edge Functions, or certify physical devices. Existing tests encode some behavior now being challenged: for example, missing validation currently does not block the Dart publish gate.

## Required test layers

| Layer | Fixtures and assertions | Gate |
|---|---|---|
| Domain/unit | Two departments share label 66/A; 2-term and 3-term calendars; arbitrary study stages; aliases; B+C membership | Distinct IDs, correct term/stage, no ambiguous alias acceptance |
| Parser/unit | Header reordering, duplicate headers, empty teacher, formulas with/without caches, duplicate/split rows, numeric/string batches, malformed ZIP/XML, hidden sheets, oversized data | Every candidate row accounted; required unresolved inputs block; no execution/network side effects |
| Historical workbook | Private original hashes; sanitized synthetic equivalents for CI | Derived-mode 325 offerings, 656 sessions, 626+30 split, 18 shared, 15 exclusions; do not treat all exclusions as approved |
| Policy | 38 meetings/14 weeks/fixed 2; 1.5 units versus 75 minutes; holidays; online/break modes | Zero unresolved mandatory requirement conflicts permitted |
| Solver/validator | Shared faculty across departments, room equipment/capacity, combined sections, overlapping clock intervals, pins, uneven durations, unavailable teacher | Zero hard violations; deterministic valid/invalid verdict independent of solver success |
| Infeasibility | No slots, insufficient rooms, conflicting pins, timeout, MODEL_INVALID | Structured reason and identity; UNKNOWN never claimed proof of infeasibility |
| Export/import | >100 groups, >7 periods, Unicode, formula-leading titles; legacy day-sheet roundtrip | No dropped/phantom assignments; exact content count; no executable cells from untrusted text |
| Database/RLS | anon, student, teacher A/B, editor A/B, reviewer, publisher, admin; direct REST/RPC/storage tests | 100% unauthorized operations denied, no cross-scope PII/draft access |
| Publication/concurrency | Same-scope races, different-scope shared-room races, request replay, stale report, midway error | One consistent winner or safe conflict; no partial rows/pointers; one outbox event per request |
| Migration | Sanitized production-shape clone, nullable backfill, ambiguous mapping, old clients | Current CSE counts/checksums preserved; no orphaned mappings; ambiguous clients gated |
| Committee integration | edit→review→approve→publish, edit after approval, regeneration pins, rollback | Published history immutable; approvals invalidated by edits; rollback revalidated |
| Adjacent regression | Native Google and email flows, teacher/admin whitelist, tab/deep-link navigation, resources, receipts, cancellations, profile, token cleanup | Existing supported paths remain functional under tightened policies |
| Availability | Dated cancellation, relocation, holiday, term boundary, unused resource, timezone change | Scheduled status correct at half-open boundary and clearly distinguished from physical presence |
| Offline/reconnect | Airplane-mode cold start, no cache, revoked user, 401/403 vs transport error, interrupted pages, corrupt hash, deleted exceptions | Good prior snapshot retained; denials not bypassed; tombstones applied; full resync on expired cursor |
| Account isolation | Account switch/logout during download, late callback, key loss | Zero cross-account activation; owned cache/key purged; no cached admin writes |
| Job recovery | Process killed after queue/lease/result stages; duplicate request | Job terminal/retryable state persists; no lost silent job and no duplicate side effect |
| Notifications | Event retries, duplicate webhook, FCM unavailable, wrong audience | Publication still succeeds; deduped eventual send; no claim of delivery without evidence |

## Performance gates (proposed, not measured guarantees)

Record hardware, OS, Python/Flutter versions, worker count, memory limit, input size, network conditions and warm/cold runs. Use at least 20 runs for p95 and include failed runs rather than discarding them.

- **Import:** 10 MiB compressed maximum; expanded XML 100 MiB; 100 sheets; 50,000 nonempty input rows; 1,000,000 processed cells. Reject over-limit input before expensive allocation where possible. Process a representative 10,000-row workbook within 10 s p95 and below 256 MiB incremental RSS on declared staging hardware. Adjust by reviewed capacity data, not silently.
- **Solver pilot:** a curated set of 20 known-feasible fixtures, including a combined 1,500-meeting, 150-teacher, 60-room, mixed-calendar case. Target at least 19/20 feasible within 180 s on two workers; every returned accepted candidate must have zero hard errors. Measure peak RSS; keep total process memory below 80% of hosting limit. Failure to meet gates means resize/reduce model cost before release, not relax hard rules.
- **Publication:** 20 simultaneous attempted publishes across ten scopes, including conflicts; zero lost or mixed versions, p95 transaction time under 2 s for 1,500 meetings on the declared DB tier. Batch/date expansion size must be included.
- **Offline read:** on the minimum supported Android device, a saved 10,000-entry snapshot renders the initial routine within 1 s p95 and a room/teacher search within 200 ms p95; no network required.
- **Sync:** 5 s p95 from committed publication/exception to connected foreground display under the staging fixture; fallback manifest poll 30 s; stale after 60 s without a successful server check.
- **Local status:** boundary transitions within 1 s when foregrounded; recompute immediately on resume. No background or disconnected update SLA.
- **Recovery:** kill the client at each staged-download/activation boundary for 20 cycles; every restart yields either previous complete snapshot or new complete snapshot, never a mixture.

## Database test practice

Tests must use an isolated local/staging database and explicit JWT roles. Test grants as well as RLS, and exact changed functions, including owner/definer behavior. A SQL-editor superuser success is not an authorization test. Test trigger behavior for unchanged-role profile edits and code reassignment. Include direct object Storage updates/deletes.

Constraint tests cover positive duration/count, valid term dates, FK integrity, non-overlap reservations, one active pointer per scope, and immutability. Test migration replay from both clean baseline and realistic pre-versioning data; test backup restoration and post-multi-department rollback without re-enabling global deletion.

## Release acceptance and evidence

No release while any A01–A11 issue lacks either remediation evidence or an explicit scope restriction preventing the affected use. One historical CSE solve is not university acceptance. Each pilot department must approve import mappings, exclusions, duration/contact rules, resource inventory and generated/manual examples.

Publish a test report with command, commit, environment, counts, failures/skips, timing, fixture hashes and unresolved limitations. Do not log contact data, raw tokens or private workbook contents. A skipped live integration is an open release gate, not a pass.

## Academic lifecycle and pending assignment cases

- Create successive cohorts with different section counts, including one and multiple, then add another intake without code changes; identical section labels in different cohorts remain distinct and authorized queries remain scoped.
- Exercise departments on two-term and three-term calendars with different dates and explicit cohort progression; no batch-label arithmetic or shared calendar is assumed.
- Graduate or archive a cohort and change current sections or calendar policy; published schedules and authorized historical reads retain their original identities, labels and policy. Verify no cascading data loss.
- Retain a valid course with an initially unassigned teacher, distinguish it from missing course data and an unknown nonblank teacher, and apply the approved pending-assignment gate. Assign a teacher later in a new revision; check availability and conflicts and verify the previous publication is unchanged.
- Rehearse CSE mapping in isolation with null and ambiguous values; compare counts, legacy reads and historical snapshots, and deny unauthorized lifecycle and assignment changes.


## Clarification acceptance delta (22 October 2026)

Formal term/calendar expansion is deferred; those scenarios above are future
acceptance, not prerequisites for the next bounded parser correction. Add the
following source-preserving regression cases before changing runtime behavior:

- Summer and winter use different verified period grids; retain each revision's
  grid when active settings change. Import header/config mismatch must be
  surfaced, not silently interpreted against current-season settings.
- Attached versus spaced PM on noon-crossing headers, explicit AM/24-hour inputs,
  numeric Excel fractions with cell formats, and noon/midnight are distinct.
  Current diagnostic: 11:10-12:15 PM gives 23:10->12:15; attached PM gives
  11:10->12:15. Preserve raw cell/type and parser/config revision in evidence.
- Source-verified B+C reserves both groups and renders as one class, visible to
  both. Normal routine controls cannot create/redefine combined memberships.
- Imported teachers survive eligibility checks unchanged; violations report
  problems rather than substituting a teacher. Manual corrections need source
  revision provenance and validation.
- Source room-allocation notes constrain eligible rooms only after verified
  aliases/applicability; retain existing CSE pool behavior and TBA diagnostics.
- Historical batch-stage values remain historical after a newer verified
  observation; no progression by batch arithmetic or stale workbook data.

Current audit evidence: one ignored read-only Flutter probe passed; it exercised
four header forms and parsed 629 companion-workbook rows without reversed
intervals. This is not a shipped regression suite or a data repair. The 795-row
snapshot has 96 plus 29 reversed intervals; original import lineage is unresolved.
No live storage/publish replay was performed in this documentation task.
