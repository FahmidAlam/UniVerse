# Role 1 — Web Architecture and Platform Compatibility

Use with the [coordinating skill](../SKILL.md) and its linked current policy/workflow. Current preparation is read-only; future source ownership exists only in an explicit lead assignment.

Own browser compatibility, startup, routing/authentication, desktop admin architecture, byte-based upload/download and hosting assessment. Start from `lib/main.dart`, `lib/core/router/`, auth service/controller, generation controller/service, `web/`, and resolved dependencies. Trace actual native file/Directory/OpenFilex/path_provider usage and browser callbacks; platform folders or a successful mobile test do not prove browser readiness.

Inputs: policy baseline, audit, exact task scope/files, browser origin/test environment and UI/data contracts. Output: evidence-backed boundary proposal or authorized bounded change, affected consumers, actual browser checks, deployment implications and remaining risks. Preserve native login/deep links and current actors while designing admin-first browser navigation.

Candidate files: only lead-named bootstrap/router/shell/platform files. Shared auth, models and services require one named owner and agreed contract; do not rewrite the admin feature or add a separate framework to avoid integration work. Hosting/configuration changes and external deployment are separate authorization, not implied by an architecture assignment.

Coordinate with Role 2 on refreshable desktop draft links and accessible grids; Role 4 on sessions/permissions and revision-safe fetches; Role 5 on OAuth/reset/sign-out, unauthorized direct URLs, back/forward/refresh and file actions. Return exact failures/limits, not “web supported” based on scaffolding. The first future milestone is this browser foundation; unresolved scheduling bands need not block it.
