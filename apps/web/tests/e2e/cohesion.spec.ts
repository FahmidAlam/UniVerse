import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { expect, test, type Page } from "@playwright/test";

const SPEC_DIR = path.dirname(fileURLToPath(import.meta.url));
const SCREENSHOT_DIR = path.resolve(
  SPEC_DIR,
  "../../test-results/e2e-screenshots/web_ux_cohesion",
);

fs.mkdirSync(SCREENSHOT_DIR, { recursive: true });

async function saveScreenshot(page: Page, filename: string, fullPage = true) {
  await page
    .locator("[data-sonner-toast] button[aria-label]")
    .first()
    .click({ timeout: 250 })
    .catch(() => {});
  await page.waitForTimeout(120);
  const buf = await page.screenshot({ fullPage });
  const target = path.join(SCREENSHOT_DIR, filename);
  for (let attempt = 0; attempt < 4; attempt++) {
    try {
      fs.writeFileSync(target, buf);
      return;
    } catch (err) {
      if (attempt === 3) throw err;
      await page.waitForTimeout(250);
    }
  }
}

function attachWatchers(page: Page) {
  const pageErrors: string[] = [];
  const consoleErrors: string[] = [];
  const http500s: string[] = [];
  const remoteRequests: string[] = [];

  page.on("pageerror", (err) => pageErrors.push(err.message));
  page.on("console", (msg) => {
    if (msg.type() === "error") {
      const text = msg.text();
      if (!text.includes("universe-timetable-engine.onrender.com")) {
        consoleErrors.push(text);
      }
    }
  });
  page.on("response", (res) => {
    if (res.status() >= 500) {
      http500s.push(`${res.status()} ${res.url()}`);
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

  return { pageErrors, consoleErrors, http500s, remoteRequests };
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

test.describe("UniVerse Academic Ledger — Admin UX Cohesion & Phase 4B Fixes", () => {
  test("Verifies collapsible sidebar, upgraded Dashboard, Rooms/Faculty/Eligibility/Settings UX, Staged Catalogs, and Stage 5 7-day matrix across 1440/1024/390", async ({
    browser,
  }) => {
    test.setTimeout(90_000);
    const context = await browser.newContext({
      viewport: { width: 1440, height: 900 },
    });
    const page = await context.newPage();
    const { pageErrors, consoleErrors, http500s, remoteRequests } =
      attachWatchers(page);

    await page.route("https://universe-timetable-engine.onrender.com/**", (route) =>
      route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({
          service: "universe-timetable-engine",
          version: "2.0.0",
          ok: true,
        }),
      }),
    );

    // 1. Dashboard: Lifecycle Strip + Daily Slot Load Chart + Expanded Sidebar
    await page.goto("/admin/dashboard?preview=admin", {
      waitUntil: "networkidle",
    });
    await expect(page.getByTestId("dashboard-lifecycle-strip")).toBeVisible();
    await expect(page.getByTestId("dashboard-daily-load-chart")).toBeVisible();
    const sidebar = page.getByTestId("desktop-admin-sidebar");
    await expect(sidebar).toHaveAttribute("data-collapsed", "false");
    await saveScreenshot(page, "01_sidebar_expanded_dashboard_1440x900.png");

    // 2. Collapse sidebar (240px -> 68px) and verify localStorage persistence across reload
    await page.getByTestId("sidebar-collapse-toggle").click();
    await expect(sidebar).toHaveAttribute("data-collapsed", "true");
    await page.reload({ waitUntil: "networkidle" });
    await expect(page.getByTestId("desktop-admin-sidebar")).toHaveAttribute(
      "data-collapsed",
      "true",
    );
    await saveScreenshot(page, "02_sidebar_collapsed_rail_1440x900.png");

    // Expand sidebar back
    await page.getByTestId("sidebar-collapse-toggle").click();
    await expect(page.getByTestId("desktop-admin-sidebar")).toHaveAttribute(
      "data-collapsed",
      "false",
    );

    // 3. Rooms: Pool Capacity Strip + Inline Active Switch + View Room Schedule deep link
    await page
      .locator("aside nav")
      .first()
      .getByRole("link", { name: "Room Pools", exact: true })
      .click();
    await page.getByRole("button", { name: "Add Room" }).click();
    await page.getByLabel("Room Code").fill("RAB-301");
    await page.getByLabel("Building").fill("Academic Building");
    await page.getByRole("button", { name: "Create Room" }).click();
    await expect(page.getByTestId("rooms-capacity-strip")).toBeVisible();
    await page.getByText("RAB-301").first().click();
    await expect(page.getByTestId("view-room-schedule-link")).toBeVisible();
    await page.getByTestId("view-room-schedule-link").click();
    await expect(page).toHaveURL(/\/admin\/timetable\/grid\?lens=room&entity=RAB-301&from=rooms/);
    await expect(page.getByText("Back to Room Pools")).toBeVisible();

    // 4. Faculty: 7-Day Off-Day Visual Strip + Weekly Availability Strip + View Teaching Schedule
    await page
      .locator("aside nav")
      .first()
      .getByRole("link", { name: "Faculty", exact: true })
      .click();
    await page.getByRole("button", { name: "Add Faculty" }).click();
    await page.fill("#faculty-acronym", "TFA");
    await page.fill("#faculty-name", "Test Faculty A");
    await page.getByRole("button", { name: /Create Faculty|Save Faculty/i }).click();
    await expect(
      page.getByTestId("faculty-weekly-availability-strip"),
    ).toBeVisible();
    await expect(page.getByTestId("faculty-offday-strip").first()).toBeVisible();
    await saveScreenshot(page, "04_faculty_offday_strips_1440x900.png");

    // 5. Course Eligibility: Assign by Faculty batch assignment flow
    await page
      .locator("aside nav")
      .first()
      .getByRole("link", { name: "Course Eligibility", exact: true })
      .click();
    await expect(page.getByTestId("eligibility-coverage-strip")).toBeVisible();
    await page.getByTestId("eligibility-assign-by-faculty-tab").click();
    await expect(page.getByTestId("eligibility-by-faculty-panel")).toBeVisible();
    await page.getByLabel("Select Faculty Member").click();
    await page.getByRole("option", { name: /Test Faculty A|TFA/i }).first().click();
    await page.getByLabel("Add custom course code").fill("CSE-1101");
    await page.getByRole("button", { name: "Add", exact: true }).click();
    await saveScreenshot(page, "03_eligibility_assign_by_faculty_1440x900.png");
    await page.getByRole("button", { name: "Save Changes" }).click();

    // 6. Timetable Settings: Visual Daily Timeline Strip + Proportional Weight Bars
    await page.goto("/admin/timetable/settings?preview=admin", {
      waitUntil: "networkidle",
    });
    await expect(page.getByTestId("settings-daily-timeline-strip")).toBeVisible();
    await saveScreenshot(page, "05_settings_visual_timeline_1440x900.png");
    await page.getByRole("tab", { name: "Optimization Weights" }).click();
    await expect(page.getByTestId("weight-bar-different_days")).toBeVisible();

    // 7. Staged Courses & Batches: Read-only derived reference views (zero writable inputs)
    await page.goto("/admin/timetable/courses?preview=admin", {
      waitUntil: "networkidle",
    });
    await expect(page.getByTestId("staged-courses-banner")).toBeVisible();
    await expect(page.locator("input:not([type='search'])")).toHaveCount(0);
    await saveScreenshot(page, "06_staged_courses_reference_1440x900.png");

    await page.goto("/admin/timetable/batches?preview=admin", {
      waitUntil: "networkidle",
    });
    await expect(page.getByTestId("staged-batches-banner")).toBeVisible();
    await expect(page.locator("input:not([type='search'])")).toHaveCount(0);

    // 8. Workbench Phase 4B Fixes: zero filler Verified pills, Row 19 dynamic title, Stage 5 7-day matrix
    await page.goto("/admin/scheduling?preview=admin", {
      waitUntil: "networkidle",
    });
    await page.getByTestId("mode-preview-btn").click();
    await expect(page.getByText("Verified", { exact: true })).toHaveCount(0);
    await saveScreenshot(page, "07_workbench_stage1_no_filler_1440x900.png");

    await page.getByTestId("workbench-stage-readiness").click();
    await expect(
      page.getByTestId("readiness-item-chk-teacher-pending"),
    ).toContainText("Unassigned Lab Instructor on Row 19 (CSE-2202)");
    await saveScreenshot(page, "08_workbench_stage3_readiness_1440x900.png");

    await page.getByTestId("workbench-stage-review").click();
    await expect(page.getByTestId("stage5-candidate-matrix")).toBeVisible();
    await expect(page.getByTestId("stage5-candidate-matrix")).toContainText("Sun");
    await expect(page.getByTestId("stage5-candidate-matrix")).toContainText("Sat");
    await expect(page.getByTestId("open-publish-gate-btn")).toContainText(
      "Preview Publish Flow (Simulated)",
    );
    await saveScreenshot(page, "09_workbench_stage5_7day_matrix_1440x900.png");
    await expectNoHorizontalOverflow(page, "Cohesion 1440x900");

    // 9. Responsive 1024x768 & 390x844 checks
    await page.setViewportSize({ width: 1024, height: 768 });
    await page.goto("/admin/dashboard?preview=admin", {
      waitUntil: "networkidle",
    });
    await expectNoHorizontalOverflow(page, "Cohesion Dashboard 1024x768");
    await saveScreenshot(page, "10_cohesion_1024x768.png");

    await page.setViewportSize({ width: 390, height: 844 });
    await page.goto("/admin/timetable/faculty?preview=admin", {
      waitUntil: "networkidle",
    });
    await expectNoHorizontalOverflow(page, "Cohesion Faculty 390x844");
    await saveScreenshot(page, "11_cohesion_mobile_390x844.png");

    expect(pageErrors).toEqual([]);
    expect(consoleErrors).toEqual([]);
    expect(http500s).toEqual([]);
    expect(remoteRequests).toEqual([]);

    await context.close();
  });
});
