# Database and data migration plan

**Design only. No migration was created or executed.** Proposed names below are contracts for implementation review, not claims about existing tables. Use Supabase migration tooling after establishing the actual baseline; do not rename already-applied migration history.

## Baseline and recovery first

Obtain a sanitized schema-only export and migration-history list from the authorized project. Include grants, RLS policies, function bodies/owners/search paths, triggers, FKs/checks/indexes, extensions, Realtime publication, Storage bucket flags/policies and deployed Edge Function source. Compare against 001–009/011–016. Record dashboard-only objects and drift.

Reconstruct a replayable baseline in an isolated test project before adding domain migrations. 006 assumes objects not created by this migration chain; the seed files are not a substitute. Never run old destructive migrations or demo-account seeds against production to “make it match.”

Back up current routines, routine_versions, cancellations, profiles and config plus bucket object manifests; test restore into an isolated project. Only the current routine rows can be preserved from current tables: older version metadata cannot recreate deleted historic rows. Record missing historical snapshots explicitly.

Migrations should be versioned, reviewed and rehearsed locally/staging before production. [Supabase database migration workflow](https://supabase.com/docs/guides/local-development/database-migrations)

## Proposed schema

All new exposed tables have explicit grants and RLS at creation, before data is loaded. IDs are UUIDs unless specified. FK indexes are added for access and join paths.

| Table/change | Key fields and relationships | Constraints and indexes |
|---|---|---|
| `departments` | code, name, active | Unique normalized code |
| `programs` | department_id, code, title, calendar_id | Unique department+code; indexed FKs |
| `academic_calendars`, `academic_years`, `academic_terms` | calendar timezone; year; term sequence/label/start/end | Unique calendar/year/sequence; start≤end; no fixed term count |
| `term_teaching_dates` | term_id, date, teaching_day, exception kind | PK term+date; date in term; valid timezone/calendar interpretation |
| `cohorts`, `student_groups`, `cohort_terms` | program/intake; cohort/section; term/study_stage | Unique program+intake and cohort+group code; unique cohort+term |
| `courses` | owning department, code, title, credits, session type | Unique department+code; nonnegative credits; explicit type |
| Reuse `timetable_faculty`, `timetable_rooms` | Stable existing ID if present, otherwise add; active, aliases; faculty home department; room capacity/type/features/campus | Unique reviewed alias namespace; positive known capacity; no fabricated capacity |
| `faculty_profile_links` | faculty_id, profile_id, effective dates | Verified link; no end-user reassignment |
| `department_memberships` | user_id, department_id/program scope, capabilities, validity | Unique membership scope; indexed authorization paths; managed by authorized admin |
| `scheduling_scopes` | department_id, program_id, term_id, active_version_id, revision bigint | Unique ownership tuple; active version must belong to same scope |
| `policy_revisions` | scope_id, revision, periods/rules/weights, hash, approver | Unique scope+revision; immutable after use; schema-validated JSON |
| `resource_availability` | faculty or room ID, effective dates, recurring/datetime intervals, reason | Exactly one resource; valid interval; resource/date indexes |
| `import_batches`, `import_rows`, `input_revisions` | scope, object path/hash, adapter version, source coordinates, dispositions, approved snapshot/hash | Idempotency key; all candidate rows accounted; scope-safe Storage path |
| `course_offerings` | input revision, course, duration, meeting/contact target | Positive duration/count; requirement source and approval |
| `offering_groups`, `offering_teachers` | offering→atomic groups and faculty; effective weeks/assignment kind | Composite uniqueness; FKs; no acronym-only identity |
| `timetable_jobs` | actor, scope, input/policy/resource revision, state, lease, attempt, result ref, idempotency key | Unique actor+scope+request key; state check; queue state/lease index |
| `schedule_versions`, `schedule_entries` | scope/input/policy revisions, parent, draft revision/state; offering, day/date pattern, start/end, room | Immutable published rows; positive intervals; scope/version/offering indexes |
| `entry_teachers`, `entry_groups` | Entry assignment links | Unique entry+resource; teacher/group lookup indexes |
| `schedule_decisions` | version+revision, actor, action, reason, timestamp | Append-only; review binds exact draft revision/hash |
| `active_reservations` | publication scope, version/entry, resource_kind, resource_id, dated `tstzrange` | Exclusion: same kind/id cannot overlap; index scope/version; `[start,end)` |
| `schedule_exceptions` | version+entry, local date, cancel/relocate, replacement assignment, revision | Unique current exception per entry/date; actor ownership; relocation conflicts checked |
| `schedule_change_log` | monotonically increasing sequence, scope, object type/ID, revision, tombstone | Indexed scope+sequence; retention watermark |
| `notification_outbox` | event id, publication/exception id, audience, attempt/state | Unique event/channel; retry index; no client writes |

A generic reservation row per teacher, room and atomic group avoids separate collision logic. Materialize occurrences only over finite confirmed term dates. Holidays remove occurrences; makeups add explicit dates. Expansion size is measured before enabling large scopes. Tentative drafts have validator checks; only active published occurrences are in the authoritative reservation table.

PostgreSQL range exclusion constraints can prevent concurrent overlapping reservations, with equality supported by `btree_gist` where appropriate. Confirm extension availability and actual Postgres version in staging. Do not replace the broader academic validator with an exclusion constraint: it only proves the represented overlap rule. [PostgreSQL range constraints](https://www.postgresql.org/docs/current/rangetypes.html)

## Publication transaction contract

Proposed RPC:

`publish_schedule_version(p_version_id uuid, p_expected_scope_revision bigint, p_request_id uuid) -> {version_id, scope_revision, row_count, event_id}`

1. Verify current user and scoped `publish` capability; require exact approved immutable draft revision. Reject caller-supplied “ok” as proof.
2. Acquire a transaction-scoped university publication lock; lock target scope row. An already successful identical request returns the prior result; same request ID with different content fails.
3. Check expected scope revision. Resolve trusted validation attestation bound to input, policy, draft and resource revisions. If stale, require revalidation; publication rechecks resource reservations and essential DB invariants.
4. Within the transaction, remove only this scope's old active reservations and insert the new dated reservations. Cross-scope overlaps fail the transaction through constraints.
5. Set this scope's active pointer, increment revision, preserve immutable old rows, and update any supported legacy projection. Insert change-log and notification-outbox events.
6. Commit once. Any failure leaves old pointer/reservations/projection unchanged. Notification delivery occurs afterward and cannot retroactively fail the publication.

The trusted validator runs in Python using the same approved domain snapshot for generation, upload and manual paths. Only a protected worker identity can write attestations; clients cannot manufacture them. A narrow definer RPC may be needed once direct table writes are revoked: qualify objects, pin search_path, check `auth.uid()` and membership, revoke PUBLIC/anon execute and grant only intended roles. Test this explicitly. Do not casually convert the current invoker function to definer.

Manual saves use `save_schedule_draft(version_id, expected_revision, patch, request_id)` with optimistic concurrency, typed patches and audit records. Eligibility replacement similarly becomes one scoped transaction. No public API directly mutates published rows.

## RLS and ownership model

| Actor | Read | Write |
|---|---|---|
| Signed-out | No timetable/admin data by default | None |
| Student | Published entries through own group membership; permitted minimal campus directory/availability | Own receipt/preferences only |
| Teacher | Own assigned entries (including co-teaching); permitted directory | Own dated class exceptions via checked RPC; no arbitrary cancellation |
| Committee editor | Draft/import/policy data only for granted scope | Draft edits/import; no automatic publication capability |
| Reviewer/publisher | Granted scope | Approve/publish only through stateful RPC |
| Global admin | Administrative recovery and authorized scope management | Audited exceptional operations; no untracked client bypass |
| Worker | Minimum job/input/result/attestation access | Lease/result/validation/outbox processing; secrets only server-side |

Authorization depends on DB-owned membership, not self-edited profile department/teacher code. RLS policies and grants are both required; audit policies left under old names because PostgreSQL permissive policies combine with OR. Protect private import objects by scope and uploader; generated publications use signed URLs or authorized snapshots. Remove broad authenticated bucket mutations only after replacing every existing resource/profile workflow. [Supabase RLS and grants](https://supabase.com/docs/guides/database/postgres/row-level-security)

Index group/user membership lookups and scope/version filters used in policies. Use security-invoker views where applicable; views must not accidentally bypass RLS. Negative tests include direct REST/RPC access, not only hidden buttons.

## Ordered expand–migrate–contract rollout

| Stage | Data operation and compatibility | Proof / rollback |
|---|---|---|
| M0 baseline | Export/reconcile deployed definitions, backup and restore drill | Clean replay and restore; no production mutation in audit |
| M1 additive catalog | Add departments/programs/terms/groups and nullable FK columns beside legacy text | Existing clients still read identical rows; disable new UI to roll back |
| M2 reviewed mapping | Create explicit legacy CSE scope; map numeric CSE cohorts only after confirmation; review service cohorts separately | Zero orphaned mapped rows; ambiguous rows quarantined; old strings retained |
| M3 input/policy records | Snapshot current settings and current published rows; import histories only where source exists | Counts and checksums match; no fabricated old versions |
| M4 new draft/job APIs | Shadow generation and validation; new RLS and private Storage | New paths gated; legacy reads untouched; queued jobs cancellable |
| M5 new reader release | New clients use group/teacher links, scope manifest and immutable snapshots | Regression tests across roles and shared groups |
| M6 scoped publication cutover | Replace writable legacy admin paths; revoke old global publish once replacement usable; activate per-scope pointers/reservations/outbox | Two-scope concurrency proof; rollback before expansion can restore captured legacy projection |
| M7 offline release | Enable identity-bound snapshots and exception cursor | Airplane-mode/crash/account-switch proofs; disable cache feature without backend loss |
| M8 contract | After supported clients are upgraded and rollback window expires, retire obsolete fields/APIs | Separate approved migration; never drop labels/source/history merely to simplify |

### Legacy compatibility limit

An old client filtering only batch+section cannot safely distinguish two departments sharing those labels, and cannot represent combined groups or co-teachers. Additive fields alone do not solve that. Before enabling non-CSE publication, require compatible readers or provide a server-filtered legacy projection restricted to the original CSE cohort audience. Do not expose an ambiguous combined university `routines` table to old readers.

Keep existing UUID profile/auth identities. Backfill links through reviewed mappings, never name matching alone. Current CSE schedules remain visible throughout the additive phase. Preserve resource-folder semester numbers until program/study-stage selection is added; no bulk relabeling.

Cancellations already detached by SET NULL remain historical records. Do not reattach by approximate subject/time. Future exceptions target immutable entries and dates; revision must explicitly migrate or retire applicable exceptions with an audit decision.

### Rollback after multi-department launch

Do not restore the old global-deleting RPC as a rollback: it would destroy scoped schedules. Freeze writes, retain new tables/history, revert to the last compatible reader/API release and republish a prior immutable version after current cross-scope validation. A rollback publication can fail if another department now uses its rooms; resolve that conflict, do not bypass constraints. Restore from backup only as a separately authorized recovery procedure.

### Lifecycle and pending-assignment migration considerations

The proposed cohort/group and cohort-term relationships must enforce program scope, cohort-owned section uniqueness and valid calendar/term membership without fixed counts. Record lifecycle transitions and effective dates under approved rules; archive rather than cascade-delete referenced cohorts or sections. Bind published versions to snapshots of relevant identities, labels, calendar/policy revision and assignments so later edits cannot change historical meaning. Exact constraints and names depend on the recovered baseline and confirmed institutional rules.

Backfill CSE only from reviewed evidence, preserving legacy labels and current reads; quarantine ambiguous cohort, section, term or teacher mappings instead of guessing. Preserve null teacher values as pending where the offering is otherwise valid, distinct from invalid course data and unresolved nonblank teacher codes. Proposed teacher links may be empty with an explicit pending state; actual links require valid faculty references. Reconcile counts and references in a restored isolated copy before cutover. Older deleted schedule rows cannot be reconstructed from version metadata. Later assignment requires a new revision and conflict revalidation; publication eligibility for pending assignments needs an approved policy.

### Task 2 implemented schema and mapping boundary (22 October 2026)

`20261022140809_academic_catalog.sql` adds departments, calendars, academic years,
programs, terms, cohorts, atomic groups, explicit cohort-term progression,
scheduling scopes, scoped capability memberships, reviewed aliases/member links,
routine-group links and approved mapping/quarantine records. Nullable canonical
references sit beside existing profile/routine fields; faculty and room UUIDs
remain their existing identifiers. Null-program scope and membership uniqueness
use `NULLS NOT DISTINCT`. Referenced identities/ownership cannot be reassigned.

New catalog tables have RLS; authenticated users receive only scoped DML, and
anonymous catalog access is closed. Membership authority is administratively
managed. Definer helpers have an empty search path and qualified references;
the catalog snapshot and approved mapping application are invoker functions.
Readable scopes include their calendar hierarchy in the snapshot even when a
program-scoped member cannot read the other program using that calendar.
Existing legacy table policies are preserved, so this migration is not the
later multi-department publication cutover or a legacy authorization redesign.

Service RPCs: `academic_catalog()`, `save_academic_alias(uuid,uuid,text,uuid[])`,
`replace_academic_alias_members(uuid,uuid[])`, `review_academic_alias(uuid)` and
`apply_academic_mapping(uuid)`. Alias members cannot cross cohorts or become an
empty committed list. Member/label edits invalidate review. Approved batch links
are immutable; apply locks original rows, verifies exact legacy JSON, validates
reviewed identities and adds links atomically. No data backfill is embedded in
the migration. Quarantine read-only assessment: `task2-backfill-status.json`.
User-confirmed status is **not approved**: 795 rows held, zero mapped, including
125 anomalous stored intervals; this does not establish invalid source classes. Production and hosted test data are untouched.

The engine exposes schema-v1 identity/revision carrier records in `domain.py`.
`PolicySnapshot` currently carries policy identity, scope, term, resource revision
and teaching dates; academic policy rules/approval belong to Task 3. Constructing
a `NormalizedInput` does not certify that requirements were institutionally
approved. Existing ingestion, solver and publication paths are unchanged.


### Clarification override and seasonal timing (22 October 2026)

Formal academic-term/calendar rollout is deferred, not an outstanding approval
needed to finish the present parser/UI audit. The local Task 2 schema/carriers
already include terms; leave them intact and unused rather than inventing dates
or applying more migrations in this documentation task. A later integration
must review that contract before wiring it into current imports.

Version effective summer/winter timing configurations separately from a batch's
historical study-stage observation. Freeze each routine's source/config revision;
changing the active settings must not reinterpret old clocks or promote batches.
Imported Teacher cells and verified combined-section membership remain source
authority. Alias approval alone does not prove a combination came from source;
future input approval must retain cell provenance and ordinary routine controls
must not create memberships. Reuse existing CSE room pools and verified workbook
allocation notes; resolve room aliases before introducing eligibility constraints.

The quarantine report is a read-only hold of identity links, not a statement
that all 795 classes are invalid. Of 125 anomalous stored intervals, 96 are
11:10->00:15 and 29 are 23:10->12:15. A current parser probe reproduced the latter
from a spaced PM suffix; exact historical source/deployment lineage is unknown.
No stored-time rewrite, validation relaxation or bulk 12-hour repair is approved.
See the workbook audit for evidence and the bounded next-step plan.
