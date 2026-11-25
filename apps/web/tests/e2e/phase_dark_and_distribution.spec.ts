import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { expect, test, type Page } from "@playwright/test";

const SPEC_DIR = path.dirname(fileURLToPath(import.meta.url));
const SCREENSHOT_DIR = path.resolve(
  SPEC_DIR,
  process.env.UPDATE_WEB_GALLERY === "1"
    ? "../../../../docs/screenshots/web_theme_v3_x_obsidian_and_print"
    : "../../test-results/e2e-screenshots/web_theme_v3",
);

fs.mkdirSync(SCREENSHOT_DIR, { recursive: true });

async function saveScreenshot(page: Page, filename: string, fullPage = true) {
  await page
    .locator("[data-sonner-toast] button[aria-label]")
    .first()
    .click({ timeout: 250 })
    .catch(() => {});
  await page.waitForTimeout(150);
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

test.describe("UniVerse Academic Ledger v2 — 4-Layer Dual Theme, Dynamic Break & Fluid Full-Width Tables", () => {
  test("Verifies Light/Dark v2 theme, zero-FOUC reload, fluid collapsed-sidebar 14-col table, dynamic break after P4->P3, Stage 5 matrix rows, and Generate metrics across 1440/1024/390", async ({
    browser,
  }) => {
    test.setTimeout(120_000);
    const context = await browser.newContext({
      viewport: { width: 1440, height: 900 },
      acceptDownloads: true,
    });
    const page = await context.newPage();
    const { pageErrors, consoleErrors, http500s, remoteRequests } =
      attachWatchers(page);

    let capturedMultipartGenerate = false;

    await page.route("https://universe-timetable-engine.onrender.com/**", async (route) => {
      const url = route.request().url();
      const method = route.request().method();

      if (method === "POST" && url.endsWith("/api/timetable/generate")) {
        const contentType = route.request().headers()["content-type"] ?? "";
        if (contentType.includes("multipart/form-data")) {
          capturedMultipartGenerate = true;
        }
        await route.fulfill({
          status: 200,
          contentType: "application/json",
          body: JSON.stringify({ job_id: "job-sheet-1" }),
        });
        return;
      }

      if (url.includes("/api/timetable/status/job-sheet-1")) {
        await route.fulfill({
          status: 200,
          contentType: "application/json",
          body: JSON.stringify({
            job_id: "job-sheet-1",
            state: "done",
            progress: 100,
          }),
        });
        return;
      }

      if (url.includes("/api/timetable/result/job-sheet-1")) {
        await route.fulfill({
          status: 200,
          contentType: "application/json",
          body: JSON.stringify({
            job_id: "job-sheet-1",
            rows: [
              {
                id: "cand-1",
                day: "Sunday",
                period: 1,
                time_start: "08:50",
                time_end: "10:05",
                subject: "Structured Programming",
                subject_code: "CSE-1101",
                teacher_name: "Dr. EBH",
                teacher_code: "EBH",
                room: "G2",
                batch: "69",
                section: "A",
                semester: 1,
                is_active: true,
                is_service: false,
              },
              {
                id: "cand-2",
                day: "Sunday",
                period: 2,
                time_start: "10:10",
                time_end: "11:25",
                subject: "Data Structures",
                subject_code: "CSE-2101",
                teacher_name: "MFR",
                teacher_code: "MFR",
                room: "304",
                batch: "67",
                section: "F+G",
                semester: 4,
                is_active: true,
                is_service: false,
              },
            ],
            service_rows: [],
            stats: {
              status: "OPTIMAL",
              solve_ms: 412,
              meetings: 2,
              service_meetings: 0,
              cohorts: 2,
              teachers: 2,
              lab_theory_adjacent: 1,
              lab_theory_pairs: 1,
            },
            validation: { ok: true, hard_violations: 0 },
            report: {
              cohorts: ["69-A", "67-F+G"],
              meta: { semester_label: "Fall 2026" },
              excluded: [],
              warnings: [],
            },
            has_workbook: false,
          }),
        });
        return;
      }

      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({
          service: "universe-timetable-engine",
          version: "2.0.0",
          ok: true,
        }),
      });
    });

    // 1. Landing `/` -> Dark X-Obsidian screenshot & reload persistence
    await page.goto("/", { waitUntil: "networkidle" });
    await page.getByTestId("theme-switcher-trigger").click();
    await page.getByTestId("theme-option-dark").click();
    await expect(page.locator("html")).toHaveAttribute("data-theme", "dark");
    await page.reload({ waitUntil: "networkidle" });
    await expect(page.locator("html")).toHaveAttribute("data-theme", "dark");
    await expectNoHorizontalOverflow(page, "Landing Dark 1440");
    await saveScreenshot(page, "07_landing_dark_x_1440x900.png");

    // 2. Dashboard `/admin/dashboard?preview=admin` Dark & Light
    await page.goto("/admin/dashboard?preview=admin", {
      waitUntil: "networkidle",
    });
    await expect(page.locator("html")).toHaveAttribute("data-theme", "dark");
    await expectNoHorizontalOverflow(page, "Dashboard Dark 1440");
    await saveScreenshot(page, "01_dashboard_dark_x_1440x900.png");

    await page.getByTestId("theme-switcher-trigger").click();
    await page.getByTestId("theme-option-light").click();
    await expectNoHorizontalOverflow(page, "Dashboard Light 1440");
    await saveScreenshot(page, "02_dashboard_light_x_1440x900.png");

    await page.getByTestId("theme-switcher-trigger").click();
    await page.getByTestId("theme-option-dark").click();

    // 2b. Faculty Off-Days Dark-Mode Contrast Check (no white-on-white!)
    await page.goto("/admin/timetable/faculty?preview=admin", {
      waitUntil: "networkidle",
    });
    await expect(page.locator("html")).toHaveAttribute("data-theme", "dark");
    await page.getByRole("button", { name: "Add Faculty" }).click();
    await page.fill("#faculty-acronym", "TFA");
    await page.fill("#faculty-name", "Test Faculty A");
    await page.getByRole("button", { name: /Create Faculty|Save Faculty/i }).click();
    await expect(page.getByTestId("faculty-offday-strip").first()).toBeVisible();
    const offDayContrastOk = await page.evaluate(() => {
      const strips = Array.from(
        document.querySelectorAll<HTMLElement>('[data-testid="faculty-offday-strip"]'),
      );
      if (strips.length === 0) return { ok: false, reason: "No off-day strips found" };
      for (const strip of strips) {
        const pills = Array.from(strip.querySelectorAll<HTMLElement>("span"));
        for (const pill of pills) {
          if (pill.title.includes("Off-day")) {
            const style = window.getComputedStyle(pill);
            if (style.color === style.backgroundColor) {
              return {
                ok: false,
                reason: `Matched fg/bg color ${style.color} on ${pill.textContent}`,
              };
            }
          }
        }
      }
      return { ok: true, reason: "ok" };
    });
    expect(offDayContrastOk.ok, offDayContrastOk.reason).toBe(true);
    await saveScreenshot(page, "03_faculty_offdays_dark_fixed_1440x900.png");

    // 3. Workbench `/admin/scheduling?preview=admin` Live Mode (neutral dot-pills) -> Preview Mode
    await page.goto("/admin/scheduling?preview=admin", {
      waitUntil: "networkidle",
    });
    await saveScreenshot(page, "04_workbench_live_gated_dark_x_1440x900.png");

    await page.getByTestId("mode-preview-btn").click();
    await page.getByTestId("sidebar-collapse-toggle").click();
    await page.waitForTimeout(250);

    const workbenchTableMetrics = await page
      .getByTestId("workbench-distribution-scroll")
      .evaluate((el) => ({
        scrollWidth: el.scrollWidth,
        clientWidth: el.clientWidth,
      }));
    expect(
      workbenchTableMetrics.scrollWidth,
      `Workbench 14-col table overflow (${workbenchTableMetrics.scrollWidth} > ${workbenchTableMetrics.clientWidth})`,
    ).toBeLessThanOrEqual(workbenchTableMetrics.clientWidth);

    // 4. Workbench Stage 5 (Review & Diff) -> verify visible 7-day matrix rows & raised tabs!
    await page.getByTestId("workbench-stage-review").click();
    const stage5Matrix = page.getByTestId("stage5-candidate-matrix");
    await expect(stage5Matrix).toBeVisible();
    const stage5Rows = await stage5Matrix.locator("tbody tr").count();
    expect(stage5Rows, "Stage 5 2D Matrix must render visible rows").toBeGreaterThan(0);
    await saveScreenshot(page, "05_workbench_stage5_dark_x_1440x900.png");

    // 5. Distribution Studio -> Generate Routine From Sheet -> zero "undefined" metrics!
    await page.goto("/admin/routine?tab=distribution&preview=admin", {
      waitUntil: "networkidle",
    });
    await expect(page.getByTestId("distribution-local-draft-banner")).toBeVisible();
    await page.getByTestId("dist-generate-cta").click();
    await expect(page.getByTestId("generate-from-sheet-summary")).toBeVisible();
    await page.getByTestId("run-cpsat-solver-btn").click();
    await expect(page.getByText("CP-SAT routine generation completed")).toBeVisible();
    expect(capturedMultipartGenerate).toBe(true);

    const generateText = await page.locator("main").innerText();
    expect(generateText.toLowerCase()).not.toContain("undefined");

    // 6. Committee Day Sheet Mode + Print Emulation Check (A4 Landscape, zero chrome, zero overflow)
    await page.goto("/admin/timetable/grid?preview=admin", {
      waitUntil: "networkidle",
    });
    await page.getByRole("button", { name: "Committee Sheet" }).click();
    await expect(page.getByTestId("committee-day-sheet-view")).toBeVisible();
    await expect(page.getByTestId("matrix-day-selector")).toHaveCount(0);
    const breakCol = page.getByTestId("committee-break-col");
    await expect(breakCol).toBeVisible();
    await expect(breakCol).toHaveAttribute("data-break-after", "4");
    await expectNoHorizontalOverflow(page, "Committee Sheet Dark 1440");

    await page.setViewportSize({ width: 1122, height: 794 });
    await page.emulateMedia({ media: "print" });
    await page.waitForTimeout(150);
    const printCheck = await page.evaluate(() => {
      const aside = document.querySelector("aside");
      const topbar = document.querySelector('header[data-admin-topbar="true"]');
      const noPrints = Array.from(document.querySelectorAll(".no-print"));
      const sheet = document.querySelector<HTMLElement>(".committee-print-sheet");
      const table = document.querySelector<HTMLElement>(".committee-print-table");
      const sigs = document.querySelector<HTMLElement>(".print-signatures");

      return {
        asideHidden: !aside || getComputedStyle(aside).display === "none",
        topbarHidden: !topbar || getComputedStyle(topbar).display === "none",
        allNoPrintHidden: noPrints.every(
          (el) => getComputedStyle(el).display === "none",
        ),
        sheetVisible: Boolean(sheet) && getComputedStyle(sheet!).display !== "none",
        sheetBg: sheet ? getComputedStyle(sheet).backgroundColor : "",
        tableScrollWidth: table ? table.scrollWidth : 9999,
        tableClientWidth: table ? table.clientWidth : 0,
        sigsVisible: Boolean(sigs) && getComputedStyle(sigs!).display === "grid",
      };
    });
    expect(printCheck.asideHidden, "Sidebar must be hidden in print").toBe(true);
    expect(printCheck.topbarHidden, "Topbar must be hidden in print").toBe(true);
    expect(printCheck.allNoPrintHidden, "All .no-print chrome must be hidden in print").toBe(true);
    expect(printCheck.sheetVisible, "Committee print sheet must be visible").toBe(true);
    expect(printCheck.sheetBg).toBe("rgb(255, 255, 255)");
    expect(
      printCheck.tableScrollWidth,
      `Print table overflow (${printCheck.tableScrollWidth} > ${printCheck.tableClientWidth})`,
    ).toBeLessThanOrEqual(printCheck.tableClientWidth);
    expect(printCheck.sigsVisible, "3-role signature footer must be visible in print").toBe(true);

    await saveScreenshot(page, "06_committee_sheet_print_landscape_a4.png", true);
    await page.emulateMedia({ media: "screen" });
    await page.setViewportSize({ width: 1440, height: 900 });

    // 7. Settings Dynamic Break -> move break from After P4 to After P3
    await page.goto("/admin/timetable/settings?preview=admin", {
      waitUntil: "networkidle",
    });
    await expect(page.getByTestId("settings-midday-break-controls")).toBeVisible();
    await expect(page.getByTestId("break-pos-4")).toHaveAttribute("aria-pressed", "true");
    await page.getByTestId("break-pos-3").click();
    await expect(page.getByTestId("break-pos-3")).toHaveAttribute("aria-pressed", "true");
    await expect(page.getByTestId("timeline-break-block")).toContainText("12:45–13:10");

    // 8. Responsive checks: 1024x768 & 390x844 Dark Mode
    await page.setViewportSize({ width: 1024, height: 768 });
    await page.goto("/admin/dashboard?preview=admin", {
      waitUntil: "networkidle",
    });
    await expectNoHorizontalOverflow(page, "Dashboard Dark 1024");

    await page.setViewportSize({ width: 390, height: 844 });
    await expectNoHorizontalOverflow(page, "Dashboard Dark Mobile 390");
    await saveScreenshot(page, "08_mobile_dark_x_390x844.png");

    expect(pageErrors).toEqual([]);
    expect(consoleErrors).toEqual([]);
    expect(http500s).toEqual([]);
    expect(remoteRequests).toEqual([]);

    await context.close();
  });
});
