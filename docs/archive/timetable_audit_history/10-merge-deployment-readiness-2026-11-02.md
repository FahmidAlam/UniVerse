# Application, merge and deployment readiness — 2 November 2026

**Assessment: NOT READY for the proposed production-backed team rollout.**
The updated engine passes its bounded generation tests, the local API works,
and a new Android release APK builds. Application-wide correctness and deployed
authorization blockers remain. Several are pre-existing; this is not a claim
that the engine changes introduced them. No merge, checkout, push, reset,
deployment, hosted migration or live-data mutation was performed.

## Progress recovered and continuation completed

Before interruption: architecture/client/API/database review, independent
source security review, read-only production policy/function inspection,
Render public GET probes, local API smoke test, analysis, tool tests and a
two-worker generation profile completed. The isolated APK build was running.
Two small local fixes were already applied: raw `workbook/*.xlsx` files are
ignored, and invite-admin's reset callback matches Android/AuthService.

Continuation verified the build actually completed, checked APK metadata/hash/
signature, compared its 140 Dart source files with current `lib/`, refreshed
the read-only Git comparison and wrote this assessment. No generation suite or
completed modification was repeated. No readiness build/process remained active.

## Verified evidence

| Check | Actual result |
|---|---|
| Existing engine acceptance checkpoint | 205 Python tests passed, 1 optional skipped; three Summer and three corrected Fall runs passed; six app-parser round trips. See [09](09-cross-semester-generation-2026-11-01.md). |
| Existing Flutter suite | 104 passed; source preserved during this audit. |
| Full Flutter analysis | No issues; log `readiness-flutter-analyze.log`. |
| Tool regression suite | 18 passed; `readiness-tool-tests.log`. |
| Local FastAPI multipart integration | Synthetic upload → status done → result → XLSX download passed; one expected row and validation true. No hosted generation POST. |
| Deployment-style worker profile | `SOLVER_WORKERS=2`, current captured app configuration: 676 meetings, 73.19 seconds, validation true; peak actual Python-process working set 394.85 MiB on Windows/Python 3.11.4. **Not Linux/Render or concurrent-load certification.** |
| Public Render inspection | Root and OpenAPI returned 200; version 2.0.0, expected five routes. Initial GET 52.49 s, subsequent OpenAPI 0.36 s. No security scheme advertised. Health version does not identify deployed commit. |
| Live database inspection | 18 public tables, all RLS enabled; profile role guard trigger enabled; routine writes admin-only. Atomic publish RPC exists but accepts caller validation without enforcing scheduling correctness. |
| Hosted history/catalog | Migration history returned empty; canonical `academic_catalog()` absent. This does not mean the deployed legacy schema is absent. |
| APK build | Release build succeeded in isolated `.task1-local/readiness-apk-20261101`; original APK left untouched. Signature verifier exit 0; v2 signature valid. |

The first memory-monitor attempt sampled the virtualenv launcher (4.22 MiB)
and is invalid. Only the later in-process peak above is meaningful.

## Issues and required disposition

| ID / severity | Component and confirmed evidence | Impact / recommended fix |
|---|---|---|
| R1 **High** | Live `storage.objects` policies allow authenticated INSERT/UPDATE/DELETE unconditionally, across all buckets. Confirmed read-only; source counterpart `006_enable_rls_all_tables.sql:279`. | A student can replace/delete other users' stored files through the API. Rehearse bucket/owner/admin-specific policies, then arrange a separately authorized deployment. UI restrictions do not protect storage. |
| R2 **High** | Deployed `send-push` v2 has `verify_jwt=false`; its handler accepts `payload.record`, uses service-role access and FCM credentials, with no caller/secret gate. Local source already adds a dedicated gate. | Forged push requests are possible if FCM credentials are configured. No attack/delivery was attempted. Deploy the hardened function only with a coordinated `PUSH_WEBHOOK_SECRET` and matching webhook header; verify denial and intended delivery in a disposable environment. A Render merge does not deploy Edge Functions. |
| R3 **High** | `engine/main.py:83-104`: unauthenticated uploads, caller-controlled solve duration, a thread per request, no job expiry/admission bound. Public Render OpenAPI agrees with exposed routes. | Resource exhaustion and unstable team generation. Add server admin authorization, upload/parser/duration limits, bounded concurrency/queue and retention. Preserve client compatibility when introducing auth. Two solver workers do not limit simultaneous jobs. |
| R4 **High** | `routine_service.dart:17` fetches exact section; line 27 fetches only printed teacher. `RoutineEntry.toMap()` omits engine co-teacher arrays. | B/C students miss B+C meetings; secondary teachers miss shared assignments after persistence. Preserve reviewed group/teacher relationships through storage and readers; verify real student/teacher views before calling the rollout accurate. Do not guess combined groups. |
| R5 **High** | `buildEngineConfig()` does not transport scoped room aliases/unavailability, `break_col`, or same-day policy. Live settings remain historical Summer/fixed two. Actual app-profile rehearsal produced **676**, versus **682** in the derived-count acceptance profile. | The APK cannot reproduce the successful Fall CLI profile simply by deploying the engine. Establish an approved input/profile path and meeting-count policy; do not silently change global settings or infer current batch stages. Six Summer offerings require source review of the fixed-rate shortfall. |
| R6 **High** | `publish_routine` checks admin/nonempty input, then globally replaces routines; manual CRUD in `routine_service.dart:40-52` bypasses scheduling validation. | Client gates alone cannot ensure valid publication; old APKs/manual edits can bypass newer checks. Enforce required validation at publication/write boundaries and retain explicit CSE-only scope until scoped publication exists. |
| R7 **Medium** | `rooms_controller.dart:60-63` groups literal room strings; room detail also matches exact text. | PHY LAB/RAB-106 can still appear as different physical rooms in application availability views. Wire verified scoped identity rules into readers; do not infer the possible RKB-106 typo. |
| R8 **Medium** | Local `dart_defines.json` selects emulator HTTP; old root APK predates fixes. New audit APK explicitly uses Render HTTPS. HTTP service methods lack request deadlines; jobs are process-local memory. | Ordinary build commands can create an APK that cannot reach a laptop from team phones; cold starts/restarts may hang or lose jobs. Use explicit environment/build metadata, HTTP deadlines/recovery and one supported worker process until job storage is durable. |
| R9 **Medium** | Python requirements have lower bounds only; local verification uses 3.11.4 while blueprint requests 3.12.7. Hosted effective environment/branch/autodeploy/logs are unavailable through connected tools. | Dependency/build drift and unverified deployment capacity. Pin a tested resolution and verify the actual Render dashboard/runtime, Linux build and monitored single-job/concurrency limits. Do not infer dashboard settings from `render.yaml`. |
| R10 **Medium** | New workflow is untracked and covers canonical contracts/tools/local SQL, not the full engine and Flutter suites. | Merge checks can miss scheduling/UI regressions. Include relevant runtime files and CI coverage in the reviewed commit. |
| R11 **Warning / contract decision** | Live notification SELECT allows every authenticated user; audience filtering happens in the client. Realtime publication currently contains cancellations only. | If audiences imply confidentiality, enforce it in SELECT policies. Do not promise live routine stream updates without integration verification. No notification or push was sent during audit. |
| R12 **Local fix; hosted pending** | Invite callback changed from `com.example.universe_v1://...` to `com.example.universe://reset-callback/`; static cross-component check passed. | Local source now matches manifest/AuthService. Hosted invite source remains separately deployed; allowlist, email and complete on-device invite flow still need verification. |

The live routine's 116 stored clock errors and two repeated retake overlap
pairs remain as documented in [08](08-advisor-cse-readiness-2026-11-01.md).
No correction or retake deactivation was authorized or performed by this audit.

## Render, database and secrets

Blueprint: `rootDir: engine`, Python runtime, `pip install -r requirements.txt`,
`uvicorn main:app --host 0.0.0.0 --port $PORT`, `PYTHON_VERSION=3.12.7`,
`SOLVER_WORKERS=2`, free plan, health `/`. Required engine/template/config files
exist locally. The engine itself currently needs no Supabase service-role or
FCM secret. Those privileged secrets belong to Edge Functions, never the APK.
Gemini constants have no application consumer found; no Gemini key was needed
for the audited build.

Render documents free-service idle spin-down and roughly one-minute startup;
the measured initial request delay is consistent with that behavior, not proof
of a specific dashboard cause. See [Render free services](https://render.com/docs/free).
Python selection must be checked against effective settings; environment
`PYTHON_VERSION` takes precedence. See [Render Python versions](https://render.com/docs/python-version).

No database migration is required merely to deploy the engine/parser fixes.
The canonical catalog is opt-in and not called by current legacy generation;
using it requires its separately rehearsed additive migration. Do not blindly
push the historical migration directory: production history is unreconciled,
and the local config deliberately disables automatic historical replay.
Storage/function hardening requires its own reviewed live rollout.

FCM credential presence, SMTP, Auth redirect allowlist and Google SHA registration
were not read or changed. Supabase advisors flag mutable search paths for two
functions, vector in public, security-definer execution reviews and leaked-password
protection. These are review items, not proof every flagged function is exploitable.
See [search-path guidance](https://supabase.com/docs/guides/database/database-linter?lint=0011_function_search_path_mutable)
and [password protection](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection).

## Git and APK

Branch remains `fix/google-oauth`, HEAD `47e2291`. Read-only remote inspection
confirms main `4de37c6`; HEAD is one merge commit behind origin/main, with
**identical committed file trees**. Local main is older. No unmerged index paths
were found. New engine/application changes exist in the working tree, not a new
commit: merging the current branch tip alone would not deliver them.

Required files such as `engine/room_policy.py`, `room_identity.dart`, tests,
academic services and workflow remain untracked. Presentation deletions and
diagram edits are existing user work; curate their inclusion yourself. No staged
changes or prospective curated commit were evaluated. No merge conflict can be
guaranteed against a future main revision; no merge simulation altered Git.

Audit APK: `.task1-local/readiness-apk-20261101/build/app/outputs/flutter-apk/app-release.apk`.
Package `com.example.universe`, version `1.0.0+1`, minSdk 24, targetSdk 36,
ARM32/ARM64/x86-64, 81,286,295 bytes. SHA-256:
`283f25989ed3892ef1aa881367bc2af083d0b19d46d49828a2744e7536e2c94b`.
It uses Render HTTPS, an empty unused Gemini key and the existing default
Supabase project. It is **debug-signed**, with the same certificate digest as
the older APK. This proves compilation/signature compatibility, not installation,
OAuth, push or end-to-end phone operation. It is not approved for distribution
against production while the blockers remain. Gradle/Kotlin deprecation warnings
did not fail the build; update them in a separately verified build change.

## Manual steps before merging / rollout

1. Curate and commit the intended source/tests/configuration; include imported
   untracked runtime files, exclude private originals and review unrelated edits.
   You perform all Git state changes and the merge.
2. Resolve R1-R6 or establish an explicitly isolated, access-controlled test
   environment with documented limitations. Verify the actual app-generated
   configuration and student/shared-teacher readers, not only CLI profiles.
3. Confirm Render's connected repository, deployment branch, root, commands,
   Python/workers, instance capacity and automatic-deploy behavior. Test a pinned
   Linux build. Do not assume merging changes Supabase functions/schema.
4. Arrange separate authorization and coordinated verification for Storage,
   push webhook/function and any migration changes. Do not send secrets in chat.
5. Build a clearly versioned APK with explicit intended backend/Supabase URLs;
   check signing/SHA registration. On test accounts/devices verify login,
   registration/reset/invite, generation/download, valid/invalid publication,
   combined-section/shared-teacher views, room aliases, cancellation, resources,
   push, cold start, reconnect and app restart. Test both Android notification
   permission states. No phone/SMTP/FCM operation was attempted here.

Audit evidence is in ignored `.task1-local/readiness-*` logs/JSON. Security
review was manual, including an independent source review and read-only live
metadata inspection. The managed security-scan MCP was unavailable, so no
managed scan or exhaustive security certification is claimed. Dashboard-only
configuration, Linux capacity and device behavior remain explicitly unverified.
