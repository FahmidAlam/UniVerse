import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { expect, test, type Page } from "@playwright/test";

const SPEC_DIR = path.dirname(fileURLToPath(import.meta.url));
const SCREENSHOT_DIR = path.resolve(
  SPEC_DIR,
  "../../test-results/e2e-screenshots/web_phase_4",
);

fs.mkdirSync(SCREENSHOT_DIR, { recursive: true });

async function saveScreenshot(page: Page, filename: string, fullPage = true) {
  // Dismiss any transient fixed-position Sonner toast before full-page capture
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

test.describe("UniVerse Academic Ledger — Phase 4B 5-Stage Committee Scheduling Workbench", () => {
  test("Enforces fail-closed Live Gates A-D, runs full 23-offering Design Preview across all 5 stages, and passes 1440/1024/390 responsive checks", async ({
    browser,
  }) => {
    const context = await browser.newContext({
      viewport: { width: 1440, height: 900 },
    });
    const page = await context.newPage();
    const { pageErrors, consoleErrors, remoteRequests } = attachWatchers(page);

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

    // 1. Live Mode default is fail-closed across Gates A-D
    await page.goto("/admin/scheduling?preview=admin", {
      waitUntil: "networkidle",
    });

    await expect(
      page.getByRole("heading", { level: 2, name: "5-Stage Scheduling Workbench" }),
    ).toBeVisible();
    await expect(page.getByTestId("live-gate-a-locked")).toBeVisible();
    await expect(page.getByTestId("gate-pill-A")).toContainText("Locked");
    await expect(page.getByTestId("gate-pill-C")).toContainText("Locked");
    await expect(page.getByTestId("gate-pill-D")).toContainText("Locked");

    // Verify Gates C & D stay fail-closed even when stages are clicked in Live Mode
    await page.getByTestId("workbench-stage-policy").click();
    await expect(page.getByTestId("live-gate-c-policy-locked")).toBeVisible();
    await page.getByTestId("workbench-stage-generate").click();
    await expect(page.getByTestId("live-gate-d-solve-locked")).toBeVisible();
    await page.getByTestId("workbench-stage-distribution").click();

    await expectNoHorizontalOverflow(page, "Phase 4 Live Gated 1440x900");
    await saveScreenshot(page, "05_p4_live_gated_1440x900.png", true);

    // 2. Switch to Design Preview -> strict 23-offering watermarked workflow
    await page.getByTestId("mode-preview-btn").click();
    await expect(page.getByTestId("design-preview-watermark")).toContainText(
      "SIMULATED PREVIEW · 23 CSE sample offerings · ZERO DATABASE WRITES",
    );
    await expect(
      page.getByTestId("workbench-revision-provenance"),
    ).toContainText("23 offerings");

    // Stage 1: inspect Row 18 + Row 32 (formula vs cached Col L) + apply overlay to Row 19 pending teacher
    await page.getByTestId("distribution-row-18").click();
    const inspector = page.getByTestId("distribution-docked-inspector");
    await expect(inspector).toBeVisible();
    await expect(inspector).toContainText("MSA / FK");
    await saveScreenshot(page, "06_p4_distribution_inspector_1440x900.png", true);

    // Close with [X] then reopen Row 19 & resolve pending instructor
    await page.getByTestId("distribution-inspector-close").click();
    await expect(inspector).toBeHidden();

    await page.getByTestId("distribution-row-19").click();
    await expect(inspector).toContainText("Pending teacher declaration");
    await page.getByTestId("open-correction-form-btn").click();
    await page.fill("#correction-effective-input", "NJ / LAB-STAFF");
    await page.fill(
      "#correction-reason-input",
      "Committee assigned NJ for CSE-2202 Sec A lab",
    );
    await page.getByRole("button", { name: "Save Overlay" }).click();
    await expect(inspector).toContainText("NJ / LAB-STAFF");
    await page.keyboard.press("Escape");
    await expect(inspector).toBeHidden();

    // Stage 2: Policy Studio -> toggle R15 to 6-slot grid + Reset back to baseline
    await page.getByTestId("workbench-stage-policy").click();
    await expect(page.getByTestId("r15-slot-grid-control")).toBeVisible();
    await page.getByTestId("r15-select-6").click();
    await expect(page.getByTestId("policy-row-R15")).toContainText(
      "Override Active",
    );
    await saveScreenshot(page, "07_p4_policy_studio_1440x900.png", true);
    await page.getByTestId("reset-all-policies-btn").click();
    await expect(page.getByTestId("policy-row-R15")).toContainText("Baseline");

    // Stage 3: Preflight Readiness -> stale banner from Stage 1/2 edits -> Revalidate -> Go
    await page.getByTestId("workbench-stage-readiness").click();
    await expect(page.getByTestId("preflight-stale-artifacts-banner")).toBeVisible();
    await page
      .getByRole("button", { name: "Re-run Preflight Validation" })
      .click();
    await expect(page.getByTestId("preflight-status-card")).toContainText(
      "READY TO SOLVE",
    );
    await saveScreenshot(page, "08_p4_readiness_preflight_1440x900.png", true);

    // Stage 4: Revision Solve -> infeasible diagnostic jump + clean optimal simulation
    await page.getByTestId("workbench-stage-generate").click();
    await page.getByTestId("simulate-infeasible-solve-btn").click();
    await expect(page.getByTestId("solver-conflict-diagnostics")).toBeVisible({
      timeout: 5000,
    });
    await page.getByTestId("simulate-optimal-solve-btn").click();
    await expect(
      page.getByRole("button", { name: "Review Candidate Schedule" }),
    ).toBeVisible({ timeout: 5000 });

    // Stage 5: Review, Diff & Simulated Publish Gate
    await page.getByTestId("workbench-stage-review").click();
    await expect(page.getByTestId("artifact-freshness-card")).toBeVisible();
    await expect(
      page.getByTestId("stage5-candidate-matrix").locator("tbody tr").first(),
    ).toBeVisible();
    await page.getByTestId("open-publish-gate-btn").click();
    await page.getByTestId("confirm-simulated-publish-btn").click();
    await expect(page.getByTestId("simulated-publish-outcome")).toContainText(
      "Simulated Preview Complete · Zero Database Writes",
    );
    await saveScreenshot(page, "09_p4_review_diff_publish_1440x900.png", true);

    // Responsive checks: Tablet 1024x768 & Mobile 390x844
    await page.getByTestId("workbench-stage-distribution").click();
    await page.setViewportSize({ width: 1024, height: 768 });
    await expectNoHorizontalOverflow(page, "Phase 4 Workbench 1024x768");
    await saveScreenshot(page, "10_p4_workbench_1024x768.png", true);

    await page.setViewportSize({ width: 390, height: 844 });
    await expect(page.getByTestId("distribution-mobile-list")).toBeVisible();
    await expectNoHorizontalOverflow(page, "Phase 4 Workbench 390x844");
    await saveScreenshot(page, "11_p4_workbench_390x844.png", true);

    expect(remoteRequests).toEqual([]);
    expect(pageErrors).toEqual([]);
    expect(consoleErrors).toEqual([]);
    await context.close();
  });
});
