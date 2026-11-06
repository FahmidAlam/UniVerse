---
name: universe-implementation
description: Use when coordinating UniVerse admin-web, editable course distribution, scheduling-domain, backend-integrity, or independent reliability specialist tasks. Apply during planning or authorized implementation; do not use for unrelated Flutter work.
---

# UniVerse Implementation Skill

Coordinate UniVerse work across the CSE routine committee workbench, Course Distribution contract/editor, CP-SAT scheduling engine, and Supabase backend.

## Operating Rules

1. **Follow the Master Plan & Permanent Constraints:**
   - Start from [`AGENTS.md`](../../../AGENTS.md) / [`CLAUDE.md`](../../../CLAUDE.md) and read only **§2 (Checkpoint)** and the **relevant phase section** of [`docs/implementation/UniVerse_Implementation_Master_Plan_v1_1.md`](../../../docs/implementation/UniVerse_Implementation_Master_Plan_v1_1.md) (do not read the entire master plan unless needed).
   - **Implementation-first:** Do not repeat completed audits or re-run unchanged test suites that already have passing evidence. Preserve the distinction between *implemented*, *SQL-reviewed*, and *database-verified*.
   - **UI/UX Gate & Skills:** Never design or implement new UI screens in Phase 2b, Phase 5, or major redesigns without presenting grounded alternatives/trade-offs and receiving explicit user approval first. When performing UI/UX design, implementation, styling, animation, accessibility, or review work, consult the UI/UX skill-routing table in [`AGENTS.md`](../../../AGENTS.md) / [`CLAUDE.md`](../../../CLAUDE.md) and load only the relevant skills from `.agents/skills/`.
   - **No Supabase CLI:** Never recommend, install, or use Supabase CLI. Use the connected Supabase plugin or provide exact SQL queries for the user to execute in **Supabase Dashboard → SQL Editor**.
   - **No iOS Work:** iOS tasks are out of scope for now.
2. **Load Context Selectively:**
   - Load **only the single role reference** below that matches your current task (never all five).
   - Load [`18-committee-decisions-and-policy-baseline-2026-11-04.md`](../../../docs/timetable-audit-2026-10-20/18-committee-decisions-and-policy-baseline-2026-11-04.md) or [`16-committee-traceability-2026-11-04.md`](../../../docs/timetable-audit-2026-10-20/16-committee-traceability-2026-11-04.md) only when working on workbook semantics or R1–R16 scheduling rules.
3. **Single-Writer Discipline:**
   - Never allow concurrent edits to the same file. Keep gitignored source workbooks (`engine/routine generation files/*.xlsx`), credentials, and untracked user work untouched.

## Specialist Role References (Load Only When Relevant)

- [Web Platform & Admin Shell](references/web-platform.md) — Phase 1 browser foundation, `AdminDesktopShell`, `GoRouter`, web file pickers/downloads.
- [Course Distribution & Configuration UI](references/admin-distribution-ui.md) — Phase 2a/2b Course Distribution contract & editor (`CD1`), configuration workspace (requires UI/UX approval gate before Phase 2b UI code).
- [Scheduling & CP-SAT Engine](references/scheduling-cp-sat.md) — Phase 2a/4 Python normalization (`engine/distribution.py`, `engine/ingest.py`), `R1`–`R16` CP-SAT modeling, solver diagnostics.
- [Backend & Data Integrity](references/backend-data-integrity.md) — Phase 2a/3 Supabase schema, revision/provenance tables, capability-checked RPCs, RLS, server-authoritative validation.
- [Testing & Independent Reliability](references/testing-reliability.md) — Targeted verification across Python, Flutter, browser, and Supabase SQL.
