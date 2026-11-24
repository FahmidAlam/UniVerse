# Fall 2026 Course Distribution Verification & Resolution Report

**Classification:** `FIXED AND VERIFIED`<br>
**Date:** 2 November 2026<br>
**Auditor:** Antigravity<br>
**File Under Test:** [`workbook/new/Main_Distribution_Fall 2026.xlsx`](file:///d:/flutter%20projects/universe_v1/workbook/new/Main_Distribution_Fall%202026.xlsx) (481,749 bytes)<br>
**Matched Run Profile Generated:** [`workbook/new/fall-2026-profile.json`](file:///d:/flutter%20projects/universe_v1/workbook/new/fall-2026-profile.json)<br>
**Resulting Generated Routine:** [`workbook/new/CSE_Routine_Fall_2026_Generated.xlsx`](file:///d:/flutter%20projects/universe_v1/workbook/new/CSE_Routine_Fall_2026_Generated.xlsx) (340,603 bytes)<br>

---

## 1. Executive Summary

The user provided a new course distribution workbook in `workbook/new/Main_Distribution_Fall 2026.xlsx` and reported an error in the Flutter Android app:
> **Generation failed: Could not read job status (429).**

### Key Findings
1. **The Engine CAN successfully solve and generate the routine for `Main_Distribution_Fall 2026.xlsx`:**<br>
   - Solved in **65.44 seconds** with CP-SAT (`status: FEASIBLE`).
   - Scheduled **all 466 offerings** (934 total meetings: 884 regular + 50 service across 65 cohorts).
   - **0 lab room violations**: All 38 EEE lab sessions assigned strictly to ECL laboratories; all 228 CSE lab sessions assigned strictly to CSE laboratories (`ACL-1..4`, `GL`, `NL`). Zero cross-violations.
   - **0 FACULTY-PENDING occurrences**: All 31 unassigned faculty meetings rendered with the concise label `TBA`.
   - **Sunday Explanatory Legend present**: Placed on Sunday at row 69 below the routine.
   - Generated workbook saved to [`workbook/new/CSE_Routine_Fall_2026_Generated.xlsx`](file:///d:/flutter%20projects/universe_v1/workbook/new/CSE_Routine_Fall_2026_Generated.xlsx).

2. **Root Cause of the App Error:**
   - **Semester Mismatch in Database:** When no `.json` profile was imported, the app defaulted to the live Supabase database configuration, which was configured for **Summer 2025** (76 teachers, Summer off-days). In Fall 2026, teachers like `SRR` and `AMH` teach 20 sessions each. With Summer 2025 off-day blocks, they only had 18 available time slots, causing a structural `INFEASIBLE` failure in CP-SAT.
   - **HTTP 429 Status Polling:** During the 60-second CP-SAT solve, the mobile client polled `/api/timetable/status/{jobId}` every 2 seconds (over 30 requests in 60s). Render's Free tier edge router flagged the burst as rate-limited (`429 Too Many Requests`). When 5 consecutive polls returned 429, the app threw `Could not read job status (429).`

3. **Solutions Provided:**
   - Generated the matched [`workbook/new/fall-2026-profile.json`](file:///d:/flutter%20projects/universe_v1/workbook/new/fall-2026-profile.json) with exact byte and CRC32 bindings for `Main_Distribution_Fall 2026.xlsx`.
   - Updated [`lib/features/admin/controllers/timetable_gen_controller.dart`](file:///d:/flutter%20projects/universe_v1/lib/features/admin/controllers/timetable_gen_controller.dart) to back off gracefully on HTTP 429 rather than aborting the generation job.

---

## 2. Ingest and Dataset Metrics

Ingestion of `workbook/new/Main_Distribution_Fall 2026.xlsx` produced:
- **Total Rows Parsed:** 482
- **Valid Offerings:** 466 (338 in Summer 2025)
- **Sessions Generated:** 934 sessions (884 regular grid + 50 service)
- **Unique Cohorts:** 65 cohorts (55 in Summer 2025)
- **Faculty Count:** 84 faculty members (76 in Summer 2025, 39 newly introduced)
- **Pending Faculty Offerings:** 15 offerings retained

---

## 3. Solver & Render Verification (`CSE_Routine_Fall_2026_Generated.xlsx`)

| Metric | Verification Result | Status |
|---|---|---|
| **CP-SAT Solve Status** | `FEASIBLE` in 65.44s | **PASSED** |
| **Total Meetings Scheduled** | 934 (884 regular + 50 service) | **100% COMPLETE** |
| **EEE Lab Violations** | 0 / 38 (all in ECL-1, ECL-2) | **PASSED** |
| **CSE Lab Violations** | 0 / 228 (all in ACL-1..4, GL, NL) | **PASSED** |
| **`FACULTY-PENDING` Cells** | 0 | **PASSED** |
| **`TBA` Cells** | 31 (cleanly formatted, no clipping) | **PASSED** |
| **Sunday Explanatory Legend** | Present at Row 69 | **PASSED** |
| **Other Days Duplicate Legend** | 0 (Monday..Friday clean) | **PASSED** |
| **Teacher Clashes** | 0 | **PASSED** |
| **Room Clashes** | 0 | **PASSED** |
| **Cohort Clashes** | 0 | **PASSED** |

---

## 4. How to Generate in the Mobile App

To generate the Fall 2026 timetable in your mobile app:

1. Open the app and navigate to **Routine -> Generate**.
2. Tap **"Tap to change"** and select `Main_Distribution_Fall 2026.xlsx`.
3. Under **Run profile (optional)**, tap **"Import run profile (.json)"**.
4. Select the matched profile file: [`workbook/new/fall-2026-profile.json`](file:///d:/flutter%20projects/universe_v1/workbook/new/fall-2026-profile.json).
5. Tap **Generate Timetable**.
   - The app will verify the CRC32 binding.
   - It will apply the Fall 2026 configuration.
   - The solver will complete in ~60s and display the conflict-free routine with zero violations and `TBA` formatting.
