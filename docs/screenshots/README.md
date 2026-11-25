# UniVerse Active Visual Evidence & Golden Baselines

This directory holds **only** current, active visual reference galleries and test-referenced golden baselines. Superseded intermediate web themes (v1/v2), early phase milestones (`web_phase_1a`..`4`), legacy Flutter desktop/admin captures, and old golden diff dumps have been archived under [`../archive/screenshots/`](../archive/screenshots/).

## 1. Standalone React Web (`apps/web/` — Current Theme v3)
- **[`web_theme_v3_x_obsidian_and_print/`](web_theme_v3_x_obsidian_and_print/)** — Canonical visual reference gallery for **UniVerse Academic Ledger (Theme v3: X-Grade Carbon Obsidian Dark + Crisp Daylight Light + X-Azure)**:
  - `01_dashboard_dark_x_1440x900.png` — Admin Command Center in Carbon Obsidian Dark (`1440×900`)
  - `02_dashboard_light_x_1440x900.png` — Admin Command Center in Crisp Daylight Light (`1440×900`)
  - `03_faculty_offdays_dark_fixed_1440x900.png` — Faculty management & 7-day (`Sun–Sat`) R6/R7 off-day strips
  - `04_distribution_studio_dark_1440x900.png` — In-browser Course Distribution `.xlsx` Studio
  - `05_workbench_stage5_dark_x_1440x900.png` — Track 2 Committee Scheduling Workbench Stage 5 Review Matrix
  - `06_committee_sheet_print_landscape_a4.png` — Official Leading University Committee Day Sheet (`@media print` Landscape A4)
  - `07_landing_dark_x_1440x900.png` — Public Institutional Entry (`/`) interactive timetable specimen
  - `08_mobile_dark_x_390x844.png` — Responsive mobile Admin view (`390×844`)
- *Note on Playwright E2E:* Routine `npm --prefix apps/web run test:e2e` runs write transient screenshots to gitignored `apps/web/test-results/e2e-screenshots/` so tracked gallery files are never dirtied unintentionally. Set `UPDATE_WEB_GALLERY=1` only when deliberately refreshing `web_theme_v3_x_obsidian_and_print/`.

## 2. Flutter Mobile (`lib/` — Active Golden Baselines & Mobile Reference)
- **[`phase_3/`](phase_3/)** — Active golden baseline directory referenced by `test/phase35_visual_capture_test.dart` (`visual_capture` tag) covering **Obsidian Orbit** pre-auth onboarding, authentication, and mobile responsive layouts (`VISUAL_REVIEW_GALLERY.md`).
- **[`phase_7/`](phase_7/)** — Active closure gallery and `regression/` golden baseline directory referenced by `test/phase5_visual_capture_test.dart` and `test/phase_7_final_ui_ux_closure_test.dart` covering Student/Teacher mobile views and frozen fallback baselines (`VISUAL_REVIEW_GALLERY.md`).
