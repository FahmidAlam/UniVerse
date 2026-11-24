---
name: universe-implementation
description: Use when coordinating multi-layer UniVerse work across React Web (apps/web/), Course Distribution & Committee Workbench, Python CP-SAT solver (engine/), Supabase SQL/RLS (supabase/), or Wave 2 backend evolution.
---

# UniVerse Implementation Coordinator Skill

Coordinate multi-layer UniVerse engineering across **Standalone React Web (`apps/web/`)**, **Flutter Mobile (`lib/`)**, **FastAPI + OR-Tools CP-SAT (`engine/`)**, and **Supabase PostgreSQL/RLS (`supabase/`)**.

## Operating Rules

1. **Ground Truth & Active Roadmaps:**
   - Start from [`AGENTS.md`](../../../AGENTS.md) / [`CLAUDE.md`](../../../CLAUDE.md).
   - Consult [`docs/architecture/WEB_IMPLEMENTATION_ROADMAP.md`](../../../docs/architecture/WEB_IMPLEMENTATION_ROADMAP.md) for React Web / Cutover / Wave 2 sequencing and [`docs/implementation/UniVerse_Implementation_Master_Plan_v1_1.md`](../../../docs/implementation/UniVerse_Implementation_Master_Plan_v1_1.md) for core scheduling & database specifications (read only the relevant section).
   - **Archive Exclusion:** Never scan or load `docs/archive/**` unless explicitly requested by the user.
2. **Platform & Governance Invariants:**
   - **Web vs. Mobile Split:** All web work belongs exclusively in `apps/web/` (**UniVerse Academic Ledger** — Theme v3: X-Grade Carbon Obsidian Dark + Crisp Daylight Light + X-Azure). Flutter Mobile (`lib/`, **Obsidian Orbit**) serves Android and iOS Students/Teachers (continuous iOS compatibility is mandatory). Legacy Flutter Web (`web/`, `lib/features/admin/`) is **frozen** as a read-only fallback until Production Cutover + Phase 3B complete.
   - **Mandatory UI/UX Approval Gate:** Present grounded alternatives and wait for explicit owner approval before major UI/workflow redesigns. Load only the matching skills from the routing table in [`AGENTS.md`](../../../AGENTS.md) / [`CLAUDE.md`](../../../CLAUDE.md).
   - **No Supabase CLI & Hosted Safety:** Never install or run Supabase CLI. Never mutate Production (`yxqyrjyzxitrgkhgauli`), Staging (`oqwvxplteqtlrhktsplj`), Render, or Cloudflare without explicit owner authorization.
   - **Single-Writer & Git Safety:** Keep gitignored workbooks (`engine/routine generation files/*.xlsx`), `.env.local`, `dart_defines.json`, and uncommitted work safe; never run `git push`, `git reset`, `git clean`, or `git stash`.
3. **Selective Specialist Loading:**
   - Load **only the single role reference** below matching your task (never all five at once).
   - Load [`18-committee-decisions-and-policy-baseline-2026-11-04.md`](../../../docs/timetable-audit-2026-10-20/18-committee-decisions-and-policy-baseline-2026-11-04.md) or [`16-committee-traceability-2026-11-04.md`](../../../docs/timetable-audit-2026-10-20/16-committee-traceability-2026-11-04.md) only when working on workbook semantics (`CD1`) or `R1`–`R16` / `D1`–`D6` solver rules.

## Specialist Role References (Load Only One Per Task)

- [Web Platform, Cloudflare Cutover & Frozen Fallback](references/web-platform.md) — `apps/web/` routing, PKCE + invite bridge, `_headers` CSP, Cloudflare Pages Env A/B, and post-cutover Flutter Web pruning gate.
- [Course Distribution Studio & Committee Workbench UI](references/admin-distribution-ui.md) — `CD1` columns `A`–`L`, provenance overlays, in-browser `.xlsx` studio, `R1`–`R16` policy controls, and fail-closed Gates A–D.
- [Scheduling & CP-SAT Engine (Wave 2 Phase 4A-2 & 3B)](references/scheduling-cp-sat.md) — `engine/distribution.py`, `engine/ingest.py`, `R1`–`R16` CP-SAT modeling, `engine/auth.py` JWT/CORS, and Phase 3B rendered `.xlsx` parse endpoint.
- [Backend, Supabase SQL & RLS Integrity](references/backend-data-integrity.md) — Track 2 distribution schema (`20261106130000`), Phase 5B RLS/storage hardening (`20261122160000`), Staging vs. Production promotion, and Wave 2 Gate C/D contracts.
- [Testing & Full-Stack Verification](references/testing-reliability.md) — Targeted verification across Vitest, Playwright E2E, `pytest`, `flutter analyze`/`test`, and 5-job GitHub Actions CI.
