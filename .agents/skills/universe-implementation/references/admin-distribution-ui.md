# Role 2 — Course Distribution Studio & Committee Workbench UI

## Scope

- **React Web Track 2 Workbench (`apps/web/src/features/scheduling/`):** 5-stage Committee Scheduling Workbench (`Distribution`, `Configuration`, `Readiness`, `Generate`, `Review & Publish`) + in-browser Course Distribution `.xlsx` Studio (`distributionXlsxBuilder.ts`).
- **Source & Provenance Fidelity (`CD1`, Cols `A`–`L`):** Immutable `.xlsx` SHA-256 identity, `B+C` joint-section preservation, split/co-teacher arrays, formula vs. cached-value discrepancy inspection on columns `J` (`No. of Classes`) and `L` (`Class/Week`), and audited cell corrections (`expected_revision_version`, `SQLSTATE 40001` optimistic concurrency).
- **Live Capability Gates (`schedulingCapabilities.ts`):**
  - **Gates A & B:** Verified via 4-table RLS-protected PostgREST probe (`course_distribution_revisions`, `course_distribution_sources`, `course_distribution_corrections`, `course_distribution_artifacts`) — never `GET /rest/v1/` OpenAPI root (`401`) and never nil-UUID RPCs (`500`).
  - **Gates C & D:** Unconditionally fail-closed in Live Mode until Wave 2 (`Phase 4A-2`) backend contracts ship. Zero preview fixtures may leak into Live Mode.

## R1–R16 Committee Policy Surface Rules

Expose clear, human-readable controls across `/admin/timetable/*` and `/admin/scheduling` mapped 1:1 to [`18-committee-decisions-and-policy-baseline-2026-11-04.md`](../../../../docs/timetable-audit-2026-10-20/18-committee-decisions-and-policy-baseline-2026-11-04.md):
- **7-Day Week & Jummah Block (`friday_no_p4`):** All matrices span `Sun–Sat`; Friday midday prayer slot is permanently locked (`JUMMAH`).
- **Section Calendar (`R1`–`R3`, `D1`):** 2 consecutive weekend days off per section (`R1`); max `±1` day off spread per batch (`R2`); zero 2-slot consecutive gaps (`R3`).
- **Faculty Rules (`R4`–`R9`, `D3`, `D4`):** CSE external teaching blocks (`R4`); External/Guest strict availability (`R5`); `Permanent` (4–5 work / 2–3 off) vs. `Adjunct` course-band days (`R6`, `R7`); slot preferences (`R8`); `SUST` single-half-day compactness (`R9`).
- **Rooms, Shared Labs & Grid (`R10`–`R15`, `D2`):** EEE `ECL` windows (`R10`); `Physics Lab` course binding (`R11`); sessional consecutiveness & scoped break-crossing (`R12`); 1–2 credit theory 1-day 2-slot block (`R13`); active classroom pool (`R14`); 6-slot vs. 7-slot daily grid (`R15`) with dynamic midday break.

## Guardrails

- Load [`react-web-academic-design-system`](../../react-web-academic-design-system/SKILL.md) + [`ui-backend-policy-correlation`](../../ui-backend-policy-correlation/SKILL.md) before modifying workbench or configuration controls.
- Obtain explicit owner approval before material workflow or layout redesigns.
- Keep baseline rules neutral ("Checkbox Off = Gray") and mark manual overrides with corner-triangle provenance indicators + Radix Tooltips.
