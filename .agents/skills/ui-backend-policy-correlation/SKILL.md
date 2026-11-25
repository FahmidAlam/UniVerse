---
name: ui-backend-policy-correlation
description: Enforces strict 1:1 correlation between UI/UX controls (React Web apps/web/ and Flutter Mobile lib/), Supabase/FastAPI backend contracts, and Routine Committee policies (R1-R16, D1-D6, CD1). Prevents fabricated UI matrices, dead controls, and visual redesign drift.
---

# UI/UX & Backend Policy Correlation Skill

## 1. Core Mandate (Zero Fabrication Across Both Clients)
1. **Respect Separated Client Governance:**
   - **React Web (`apps/web/`):** Primary Administrator & Routine Committee console under **UniVerse Academic Ledger** (`tokens.css` — X-Grade Carbon Obsidian Dark + Crisp Daylight Light + X-Azure).
   - **Flutter Mobile (`lib/`):** Student & Teacher mobile app (Android + continuous iOS compatibility) under **Obsidian Orbit** (`AppColors`, `AppTheme.dark`). Legacy Flutter Web (`web/`, `lib/features/admin/`) is **FROZEN** — never build new web features in Flutter.
2. **Zero Unbacked UI Matrices or Fake Persistence:** Never render a UI matrix, chart, toggle, or toast that does not map 1:1 to:
   - A verified Supabase table column or RPC (`supabase/migrations/`),
   - A real FastAPI / CP-SAT payload field (`engine/domain.py`, `engine/solver.py`, `engine/distribution.py`), OR
   - An explicit Routine Committee rule (`docs/timetable-audit-2026-10-20/18-committee-decisions-and-policy-baseline-2026-11-04.md`, `16-committee-traceability-2026-11-04.md`, `docs/Routine Generation System.pdf`) — clearly badged as **Staged / Preview** when its backend contract awaits Wave 2 (`Phase 4A-2` / `Phase 3B`).
3. **Progressive Disclosure ("Invisible UI" Until Needed):** Keep untouched baseline rules in neutral slate ("Checkbox Off = Gray"); reveal conditional fields contextually (e.g., `SUST` compactness or external window controls only for Adjunct/External faculty) and tuck secondary details into docked inspectors or modals.

## 2. Mandatory Pre-Implementation Correlation Check
Before adding or modifying any data-bound control in `apps/web/src/features/` or `lib/features/`, verify:
- **UI Control & Surface:** Exact component/widget and route.
- **State & Type Owner:** Exact TypeScript type/store/TanStack Query hook (`apps/web/`) or Dart model/`SafeChangeNotifier` (`lib/`).
- **Backend / Solver Target:** Exact Supabase table column / RPC or FastAPI payload key.
- **Operational Boundary:** **Live-Wired** (persists to Supabase/FastAPI today) vs. **Fail-Closed / Contract-Staged** (gated truthfully behind `schedulingCapabilities.ts` Gates A–D or staged catalog disclosure).

## 3. Routine Committee Policy-to-UI Rules (`R1`–`R16`, `D1`–`D6`, `CD1`)
- **7-Day Week & Friday Jummah Hard Block (`friday_no_p4`):** All matrices and day strips span `Sun–Sat` (7 days). Friday midday prayer slot is a non-negotiable hard block (`JUMMAH`).
- **Section Calendar & Batch Fairness (`R1`–`R3`, `D1`):** 2 consecutive weekend days off per section (`R1`); max `±1` day off spread within a batch (`R2`); zero 2-slot consecutive section gaps (`R3`).
- **Faculty Categories, Windows & Compactness (`R4`–`R9`, `D3`, `D4`):** `Permanent` (4–5 working days, 2–3 off-days — attendance days, not mandatory daily teaching) vs. `Adjunct` (`2` courses -> `2d`, `3` -> `3–4d`, `>=4` -> `4–5d`); CSE external blocks (`R4`), Guest strict availability (`R5`, undeclared = zero), preferences (`R8`), and `SUST` single-half-day compactness (`R9`).
- **Rooms, Shared Labs & Slot Grid (`R10`–`R15`, `D2`):** EEE-owned `ECL` lab windows (`R10`), `Physics Lab` course binding (`R11`), sessional consecutiveness & scoped break-crossing (`R12`), 1–2 credit CSE theory 1-day 2-slot same-room block (`R13`), active classroom pool (`R14`), and flexible 6-slot vs. 7-slot daily grid (`R15`) with dynamic midday break.
- **Course Distribution (`CD1`, Cols `A`–`L`):** Preserve immutable `.xlsx` SHA-256 provenance, `B+C` joint sections, split/co-teacher arrays, and formula vs. cached value inspection on columns `J` & `L` (`engine/distribution.py`).

## 4. Verification Protocol
- **React Web (`apps/web/`):** `npm --prefix apps/web run typecheck` + `npm --prefix apps/web test` (verify exact DB payload contracts and WCAG AA tokens).
- **Flutter Mobile (`lib/`):** `flutter analyze` + `flutter test --exclude-tags visual_capture`.
- **Engine (`engine/`):** `pytest engine/tests -q` whenever solver/distribution contracts touch Python.
