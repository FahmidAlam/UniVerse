import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { expect, test, type Page } from "@playwright/test";

const SPEC_DIR = path.dirname(fileURLToPath(import.meta.url));
const SCREENSHOT_DIR = path.resolve(
  SPEC_DIR,
  "../../../../docs/screenshots/web_phase_3",
);

fs.mkdirSync(SCREENSHOT_DIR, { recursive: true });

function attachWatchers(page: Page, isExpected404Active: () => boolean) {
  const pageErrors: string[] = [];
  const consoleErrors: string[] = [];
  const remoteRequests: string[] = [];

  page.on("pageerror", (err) => pageErrors.push(err.message));
  page.on("console", (msg) => {
    if (msg.type() === "error") {
      const text = msg.text();
      if (
        isExpected404Active() &&
        text.includes("status of 404 (Not Found)")
      ) {
        return;
      }
      if (!text.includes("universe-timetable-engine.onrender.com")) {
        consoleErrors.push(text);
      }
    }
  });
  page.on("request", (req) => {
    const rawUrl = req.url();
    const parsed = new URL(rawUrl);
    const isLocal =
      parsed.hostname === "127.0.0.1" || parsed.hostname === "localhost";
    if (
      !isLocal &&
      (rawUrl.includes("supabase") ||
        rawUrl.includes("/rest/v1") ||
        rawUrl.includes("/auth/v1"))
    ) {
      remoteRequests.push(rawUrl);
    }
  });

  return { pageErrors, consoleErrors, remoteRequests };
}

async function expectNoHorizontalOverflow(page: Page, contextLabel: string) {
  const metrics = await page.evaluate(() => ({
    scrollWidth: document.documentElement.scrollWidth,
    innerWidth: window.innerWidth,
  }));
  expect(
    metrics.scrollWidth,
    `${contextLabel}: horizontal overflow (${metrics.scrollWidth} > ${metrics.innerWidth})`,
  ).toBeLessThanOrEqual(metrics.innerWidth);
}

const CANDIDATE_ROWS = [
  {
    id: "gen-0",
    day: "Sunday",
    period: 1,
    time_start: "08:50",
    time_end: "10:05",
    subject: "Database Management Systems",
    subject_code: "CSE-3101",
    teacher_name: "Md. Ebrahim Hossain",
    teacher_code: "EBH",
    room: "RAB-302",
    batch: "58",
    section: "B+C",
    semester: 6,
    is_active: true,
    is_service: false,
    teachers: ["EBH"],
  },
  {
    id: "gen-1",
    day: "Monday",
    period: 2,
    time_start: "10:10",
    time_end: "11:25",
    subject: "Algorithms",
    subject_code: "CSE-2201",
    teacher_name: "Sabia Akter Bhuiyan",
    teacher_code: "SAB",
    room: "RAB-304",
    batch: "59",
    section: "A",
    semester: 4,
    is_active: true,
    is_service: false,
    teachers: ["SAB"],
  },
];

const CANDIDATE_SERVICE_ROWS = [
  {
    id: "gen-2",
    day: "Tuesday",
    period: 3,
    time_start: "11:30",
    time_end: "12:45",
    subject: "Physics for Computing",
    subject_code: "PHY-1101",
    teacher_name: "Md. Rashidul Hasan",
    teacher_code: "MRH",
    room: "RAB-106",
    batch: "61",
    section: "A",
    semester: 1,
    is_active: true,
    is_service: true,
    teachers: ["MRH"],
  },
];

test.describe("UniVerse Academic Ledger — Phase 3 Operational Routine Console & 2D Matrix", () => {
  test("Verifies 2D Matrix, Manage Published CRUD + Clash Warnings, Generate Wizard + 404/Publish, Gated Upload, Single Settings Dirty Bar, and Responsive Viewports", async ({
    browser,
  }) => {
    const context = await browser.newContext({
      viewport: { width: 1440, height: 900 },
    });
    const page = await context.newPage();
    let engineScenario: "restart-404" | "coteacher-blocked" | "clean-done" =
      "restart-404";
    let expectingIntentional404 = false;
    const { pageErrors, consoleErrors, remoteRequests } = attachWatchers(
      page,
      () => expectingIntentional404,
    );
    let statusPollCount = 0;

    await page.route(
      "https://universe-timetable-engine.onrender.com/**",
      async (route) => {
        const req = route.request();
        const url = new URL(req.url());
        const pathname = url.pathname;

        if (pathname === "/") {
          await route.fulfill({
            status: 200,
            contentType: "application/json",
            body: JSON.stringify({
              service: "universe-timetable-engine",
              version: "2.0.0",
              ok: true,
            }),
          });
          return;
        }

        if (pathname === "/api/timetable/generate") {
          statusPollCount = 0;
          await route.fulfill({
            status: 200,
            contentType: "application/json",
            body: JSON.stringify({ job_id: `job-${engineScenario}` }),
          });
          return;
        }

        if (pathname.startsWith("/api/timetable/status/")) {
          if (engineScenario === "restart-404") {
            await route.fulfill({
              status: 404,
              contentType: "application/json",
              body: JSON.stringify({ detail: "Unknown job_id." }),
            });
            return;
          }

          statusPollCount += 1;
          const states = [
            { state: "queued", progress: 0.0 },
            { state: "ingesting", progress: 0.08 },
            { state: "solving", progress: 0.5 },
            { state: "rendering", progress: 0.97 },
            { state: "done", progress: 1.0 },
          ];
          const snap = states[Math.min(statusPollCount - 1, states.length - 1)]!;
          await route.fulfill({
            status: 200,
            contentType: "application/json",
            body: JSON.stringify({
              job_id: `job-${engineScenario}`,
              ...snap,
            }),
          });
          return;
        }

        if (pathname.startsWith("/api/timetable/result/")) {
          const rows =
            engineScenario === "coteacher-blocked"
              ? [
                  {
                    ...CANDIDATE_ROWS[0]!,
                    teachers: ["EBH", "MSR"],
                  },
                  CANDIDATE_ROWS[1]!,
                ]
              : CANDIDATE_ROWS;

          await route.fulfill({
            status: 200,
            contentType: "application/json",
            body: JSON.stringify({
              job_id: `job-${engineScenario}`,
              rows,
              service_rows: CANDIDATE_SERVICE_ROWS,
              stats: {
                status: "OPTIMAL",
                solve_ms: 1420,
                meetings: rows.length,
                service_meetings: CANDIDATE_SERVICE_ROWS.length,
                offerings: 3,
                cohorts: 3,
                teachers: 3,
                objective: 18,
                lab_theory_pairs: 1,
                lab_theory_adjacent: 1,
              },
              validation: {
                ok: true,
                missing_courses: 0,
                teacher_clashes: 0,
                cohort_clashes: 0,
                room_clashes: 0,
                details: {},
              },
              source_contract: {
                source_sha256: "sha256-mock-fixture",
                revision: 0,
                invalidated_artifacts: [],
              },
              report: {
                source_contract: {
                  source_sha256: "sha256-mock-fixture",
                  revision: 0,
                  invalidated_artifacts: [],
                },
                cohorts: ["58-B+C", "59-A", "61-A"],
                meta: {},
                excluded: [],
                warnings: [],
                offerings: [],
              },
              has_workbook: true,
            }),
          });
          return;
        }

        if (pathname.startsWith("/api/timetable/download/")) {
          await route.fulfill({
            status: 200,
            contentType:
              "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            body: Buffer.from("PK\x03\x04rendered-xlsx"),
          });
          return;
        }

        await route.fallback();
      },
    );

    // Boot into authenticated dev-preview session
    await page.goto("/admin/dashboard?preview=admin", {
      waitUntil: "networkidle",
    });

    // --- 0. SETTINGS MICRO-FIX: SINGLE NON-REDUNDANT DIRTY BAR ---
    await page
      .locator("aside nav")
      .first()
      .getByRole("link", { name: "Timetable Settings" })
      .click();
    await page.getByRole("switch", { name: "Allow online slot allocation" }).click();
    await expect(page.getByTestId("sticky-dirty-bar")).toHaveCount(1);
    await expect(page.getByText("Unsaved policy edits")).toHaveCount(0);
    await page.evaluate(() => window.scrollTo(0, 0));
    await page.screenshot({
      path: path.join(SCREENSHOT_DIR, "09_settings_dirty_fixed_1440x900.png"),
      fullPage: true,
    });
    // Save so dirty bar resets cleanly
    await page
      .getByTestId("sticky-dirty-bar")
      .getByRole("button", { name: "Save Settings" })
      .click();

    // Seed 1 Room + 1 Faculty in dev preview so Generate preflight passes baseline guard
    await page
      .locator("aside nav")
      .first()
      .getByRole("link", { name: "Room Pools" })
      .click();
    await page.getByRole("button", { name: /Add Room/i }).click();
    await page.fill("#room-name", "RAB-302");
    await page.fill("#room-capacity", "60");
    await page.getByRole("button", { name: "Create Room" }).click();

    await page
      .locator("aside nav")
      .first()
      .getByRole("link", { name: "Faculty", exact: true })
      .click();
    await page.getByRole("button", { name: /Add Faculty/i }).click();
    await page.fill("#faculty-acronym", "EBH");
    await page.fill("#faculty-name", "Md. Ebrahim Hossain");
    await page.getByRole("button", { name: "Create Faculty" }).click();

    // --- 1. 2D TIMETABLE MATRIX (/admin/timetable/grid) ---
    await page
      .locator("aside nav")
      .first()
      .getByRole("link", { name: "Routine Matrix" })
      .click();
    await expect(
      page
        .locator("main")
        .getByRole("heading", { name: "Operational Routine Matrix" }),
    ).toBeVisible();
    await expect(page.getByTestId("matrix-docked-inspector")).toHaveCount(0);

    // Unclipped Section | Faculty | Room lens labels
    for (const label of ["Section", "Faculty", "Room"]) {
      const btn = page.getByRole("button", { name: label, exact: true });
      await expect(btn).toBeVisible();
      const box = await btn.evaluate((el) => ({
        sw: el.scrollWidth,
        cw: el.clientWidth,
      }));
      expect(box.sw).toBeLessThanOrEqual(box.cw + 1);
    }

    // Friday P4 Jummah Hard-Block Hatch visible
    await expect(
      page.getByLabel("Friday Period 4 Jummah Break — locked").first(),
    ).toBeVisible();

    await expectNoHorizontalOverflow(page, "Routine Grid Section 1440x900");
    await page.screenshot({
      path: path.join(SCREENSHOT_DIR, "01_routine_grid_section_1440x900.png"),
      fullPage: true,
    });

    // Click slot -> opens 360px docked inspector, verify [X] and Esc close
    await page.getByTestId("matrix-slot-prev-1").click();
    const dockedInspector = page.getByTestId("matrix-docked-inspector");
    await expect(dockedInspector).toBeVisible();
    const inspBox = await dockedInspector.boundingBox();
    expect(Math.round(inspBox!.width)).toBe(360);
    await page.screenshot({
      path: path.join(SCREENSHOT_DIR, "02_routine_grid_inspector_1440x900.png"),
      fullPage: true,
    });

    await page.getByTestId("matrix-inspector-close").click();
    await expect(dockedInspector).toBeHidden();

    // Re-open and close with Escape
    await page.getByTestId("matrix-slot-prev-1").click();
    await expect(dockedInspector).toBeVisible();
    await page.keyboard.press("Escape");
    await expect(dockedInspector).toBeHidden();

    // Switch lens -> Faculty + Compact List toggle
    await page.getByRole("button", { name: "Faculty", exact: true }).click();
    await expect(page.getByRole("rowheader", { name: /EBH/i }).first()).toBeVisible();
    await page.screenshot({
      path: path.join(SCREENSHOT_DIR, "03_routine_grid_faculty_1440x900.png"),
      fullPage: true,
    });

    await page.getByRole("button", { name: "Compact List", exact: true }).click();
    await expect(page.getByTestId("routine-compact-list")).toBeVisible();
    await page.getByRole("button", { name: "Matrix", exact: true }).click();
    await page.getByRole("button", { name: "Section", exact: true }).click();

    // --- 2. ROUTINE OPERATIONS: MANAGE PUBLISHED TAB (?tab=manage) ---
    await page
      .locator("aside nav")
      .first()
      .getByRole("link", { name: "Routine Operations" })
      .click();
    await page.getByRole("tab", { name: "Manage Published" }).click();
    await expect(page).toHaveURL(/\/admin\/routine\?tab=manage/);
    await expect(page.getByTestId("f23-manual-edit-disclosure")).toBeVisible();

    // Open Add Slot -> trigger live clash warning against Sunday 08:50 EBH / RAB-302 / 58-B+C
    await page.getByRole("button", { name: /Add Slot/i }).click();
    await page.selectOption("#slot-day", "Sunday");
    await page.fill("#slot-start", "08:50");
    await page.fill("#slot-end", "10:05");
    await page.fill("#slot-subject-code", "CSE-3199");
    await page.fill("#slot-subject", "Clash Verification Course");
    await page.fill("#slot-teacher-code", "EBH");
    await page.fill("#slot-room", "RAB-302");
    await page.fill("#slot-batch", "58");
    await page.fill("#slot-section", "B");

    await expect(page.getByTestId("routine-slot-clash-warning")).toContainText(
      "Teacher clash: EBH",
    );
    await expect(page.getByTestId("routine-slot-clash-warning")).toContainText(
      "Room clash: RAB-302",
    );
    await expect(page.getByTestId("routine-slot-clash-warning")).toContainText(
      "Cohort clash: Batch 58-B+C",
    );

    await expectNoHorizontalOverflow(page, "Routine Manage 1440x900");
    await page.screenshot({
      path: path.join(SCREENSHOT_DIR, "04_routine_manage_1440x900.png"),
      fullPage: true,
    });

    // Fix slot to Saturday (non-clashing) and create
    await page.selectOption("#slot-day", "Saturday");
    await page.fill("#slot-room", "RAB-309");
    await page.fill("#slot-section", "A");
    await page.getByRole("button", { name: "Create Slot" }).click();
    await expect(
      page.locator("table").getByText("CSE-3199", { exact: true }),
    ).toBeVisible();

    // Exercise contextual bulk selection bar
    await page.getByLabel("Select all visible rows").click();
    await expect(page.getByTestId("bulk-action-bar")).toBeVisible();
    await page.getByLabel("Select all visible rows").click();

    // --- 3. GENERATE ROUTINE TAB (?tab=generate): 404 RESTART, CO-TEACHER BLOCK, CLEAN SOLVE & PUBLISH ---
    await page.getByRole("tab", { name: "Generate Routine" }).click();
    await expect(page).toHaveURL(/\/admin\/routine\?tab=generate/);

    await page
      .getByTestId("workbook-file-input")
      .setInputFiles({
        name: "Main_Distribution_Spring2026_Committee_Verified_Draft.xlsx",
        mimeType:
          "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        buffer: Buffer.from("PK\x03\x04mock-distribution-workbook"),
      });

    // 3a. Render 404 Unknown job_id recovery
    engineScenario = "restart-404";
    expectingIntentional404 = true;
    await page.getByRole("button", { name: "Run CP-SAT Solver" }).click();
    await expect(page.getByTestId("solver-service-recovery-card")).toContainText(
      "Engine restarted mid-solve — re-submit workbook",
    );
    expectingIntentional404 = false;

    // 3b. Co-teacher storage guard check (F-22)
    engineScenario = "coteacher-blocked";
    await page.getByRole("button", { name: "Retry Generation" }).click();
    await expect(
      page.getByTestId("coteacher-storage-guard-banner"),
    ).toBeVisible({ timeout: 15000 });
    await expect(
      page.getByRole("button", { name: "Publish to Active Routine" }),
    ).toBeDisabled();

    // Expand 20-counter validation diagnostic ledger
    await page
      .getByRole("button", { name: /20-Counter Validation Diagnostic Ledger/i })
      .click();
    await expect(page.getByText("Missing Courses")).toBeVisible();

    // 3c. Clean single-teacher solve -> Inspect in 2D Grid -> Guarded 3-Step Publish
    engineScenario = "clean-done";
    await page.getByRole("button", { name: "Run CP-SAT Solver" }).click();
    await expect(page.getByTestId("validation-verdict-badge")).toContainText(
      "Passed (20/20)",
      { timeout: 15000 },
    );
    await expect(
      page.getByRole("button", { name: "Publish to Active Routine" }),
    ).toBeEnabled();

    await expectNoHorizontalOverflow(page, "Routine Generate 1440x900");
    await page.screenshot({
      path: path.join(SCREENSHOT_DIR, "05_routine_generate_1440x900.png"),
      fullPage: true,
    });

    // Inspect in 2D Grid candidate preview
    await page.getByRole("button", { name: "Inspect in 2D Grid" }).click();
    await expect(page).toHaveURL(/\/admin\/routine\?tab=grid/);
    await expect(page.getByTestId("candidate-preview-banner")).toBeVisible();

    // Return to Generate & execute 3-step guarded publish modal
    await page.getByRole("tab", { name: "Generate Routine" }).click();
    await page.getByRole("button", { name: "Publish to Active Routine" }).click();
    await expect(
      page.getByRole("heading", { name: "Confirm Atomic Routine Publication" }),
    ).toBeVisible();
    await page.getByRole("button", { name: "Publish Now" }).click();
    await expect(page.getByTestId("publish-outcome-banner")).toContainText(
      "Routine is live (3 slots published)",
    );

    // --- 4. UPLOAD ROUTINE GATED TAB (?tab=upload) ---
    await page.getByRole("tab", { name: /Upload Routine/i }).click();
    await expect(page).toHaveURL(/\/admin\/routine\?tab=upload/);
    await expect(page.getByTestId("upload-gated-card")).toContainText(
      "Gated · Phase 3B",
    );
    await expect(page.locator('main input[type="file"]')).toHaveCount(0);
    await page.screenshot({
      path: path.join(SCREENSHOT_DIR, "06_routine_upload_gated_1440x900.png"),
      fullPage: true,
    });

    // --- 5. RESPONSIVE TABLET (1024x768) & MOBILE (390x844) ---
    await page.setViewportSize({ width: 1024, height: 768 });
    await page.goto("/admin/timetable/grid?preview=admin", {
      waitUntil: "networkidle",
    });
    await expectNoHorizontalOverflow(page, "Routine Grid 1024x768");
    await page.screenshot({
      path: path.join(SCREENSHOT_DIR, "07_routine_grid_1024x768.png"),
      fullPage: true,
    });

    await page.setViewportSize({ width: 390, height: 844 });
    // Clear manual view choice by switching to Compact List explicitly or verifying single-axis readability
    await page.getByRole("button", { name: "Compact List", exact: true }).click();
    await expect(page.getByTestId("routine-compact-list")).toBeVisible();
    await expectNoHorizontalOverflow(page, "Routine Grid 390x844");
    await page.screenshot({
      path: path.join(SCREENSHOT_DIR, "08_routine_grid_390x844.png"),
      fullPage: true,
    });

    expect(remoteRequests).toEqual([]);
    expect(pageErrors).toEqual([]);
    expect(consoleErrors).toEqual([]);
    await context.close();
  });
});
