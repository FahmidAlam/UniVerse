---
name: universe-implementation
description: Use when coordinating multi-layer UniVerse work across React Web (apps/web/), Course Distribution & Committee Workbench, Python CP-SAT solver (engine/), Supabase SQL/RLS (supabase/), or Wave 2 backend evolution.
---

# UniVerse Implementation Coordinator Skill

Coordinate multi-layer UniVerse engineering across **Standalone React Web (`apps/web/`)**, **Flutter Mobile (`lib/`)**, **FastAPI + OR-Tools CP-SAT (`engine/`)**, and **Supabase PostgreSQL/RLS (`supabase/`)**.

## Operating Rules

1. **Ground Truth & Active Checkpoint:**
   - Start from [`AGENTS.md`](../../../AGENTS.md) / [`CLAUDE.md`](../../../CLAUDE.md).
   - **Live & Implemented (2026-11-28):** Environment B Production (`https://universe-admin-exi.pages.dev`) connected to hardened Production Supabase (`yxqyrjyzxitrgkhgauli`, 37 tables + Phase 5B `20261122160000` + Storage limits) and Environment A Staging (`https://universe-bfi.pages.dev` → `oqwvxplteqtlrhktsplj`); Render FastAPI (`https://universe-timetable-engine.onrender.com`, `Engine v2.0.0`, `ENGINE_AUTH_MODE=enforced`, Render 512 MB tuning `SOLVER_WORKERS=1`/`SOLVER_MAX_MEMORY_MB=320`/`SOLVER_LINEARIZATION_LEVEL=0`, startup orphan-job sweep, 2027 `sb_secret_...` compatibility, OOXML/rate-limit guards, Phase 3B `POST /api/timetable/parse-rendered-workbook`, dynamic 3-tier room-pool classification, and Hybrid R7/R6 off-day resolution); React Web preflight modals (`CourseRoomPoolReviewModal.tsx`, `ImportMissingFacultyModal.tsx`), resilient `58s` polling backoff + reconnect, `?tab=upload`, Archive v2a/v2b, and 5-job GitHub Actions CI.
   - **Wave 2B (`Phase 4A-2` / Stage 5C · Gate D):** Implemented in code (`20261127120000`, `20261127180000`, durable `solver_jobs`, `routines.teacher_codes text[]`, archiving `publish_routine()`, `restore_routine_version()`, and pruned Flutter Web `web/` + `lib/features/admin/`); owner-gated SQL promotion from Staging to Production.
   - Consult [`docs/architecture/WEB_IMPLEMENTATION_ROADMAP.md`](../../../docs/architecture/WEB_IMPLEMENTATION_ROADMAP.md) and [`docs/implementation/UniVerse_Implementation_Master_Plan_v1_1.md`](../../../docs/implementation/UniVerse_Implementation_Master_Plan_v1_1.md) (only the relevant phase section).
   - **Archive Exclusion:** Never scan or load `docs/archive/**` unless explicitly requested by the user.
2. **Platform, Security & Verification Invariants:**
   - **Web vs. Mobile Split:** All web work belongs exclusively in `apps/web/` (**UniVerse Academic Ledger**). Flutter Mobile (`lib/`, **Obsidian Orbit**) serves Android and iOS Students/Teachers (continuous iOS compatibility is mandatory). Legacy Flutter Web (`web/`, `lib/features/admin/`) has been **pruned** post-cutover (Stage 5C).
   - **Mandatory UI/UX Approval Gate:** Present grounded alternatives and wait for explicit owner approval before major UI/workflow redesigns. Load only the matching skills from the routing table in [`AGENTS.md`](../../../AGENTS.md) / [`CLAUDE.md`](../../../CLAUDE.md).
   - **Companion Core Skills:** Enforce [`system-security-and-hardening`](../system-security-and-hardening/SKILL.md) on all auth/RLS/Storage/API/CI boundaries, [`backend-evolution-and-resilience`](../backend-evolution-and-resilience/SKILL.md) on migrations/RPCs/contracts/durable jobs, and [`fullstack-verification-and-ci`](../fullstack-verification-and-ci/SKILL.md) before handoff.
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
