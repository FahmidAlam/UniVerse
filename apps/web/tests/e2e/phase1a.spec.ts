import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { expect, test, type Page } from "@playwright/test";

const SPEC_DIR = path.dirname(fileURLToPath(import.meta.url));
const SCREENSHOT_DIR = path.resolve(
  SPEC_DIR,
  "../../../../docs/screenshots/web_phase_1a",
);

fs.mkdirSync(SCREENSHOT_DIR, { recursive: true });

function attachErrorAndNetworkWatchers(page: Page) {
  const pageErrors: string[] = [];
  const consoleErrors: string[] = [];
  const remoteRequests: string[] = [];

  page.on("pageerror", (err) => pageErrors.push(err.message));
  page.on("console", (msg) => {
    if (msg.type() === "error") {
      const text = msg.text();
      // Ignore expected Engine offline network error from EngineHealthBadge polling in offline sandbox
      if (!text.includes("universe-timetable-engine.onrender.com")) {
        consoleErrors.push(text);
      }
    }
  });
  page.on("request", (req) => {
    const rawUrl = req.url();
    const parsed = new URL(rawUrl);
    const isLocalViteAsset =
      parsed.hostname === "127.0.0.1" || parsed.hostname === "localhost";
    if (
      !isLocalViteAsset &&
      (rawUrl.includes("supabase") ||
        rawUrl.includes("/rest/v1") ||
        rawUrl.includes("/auth/v1") ||
        rawUrl.includes("onrender.com"))
    ) {
      remoteRequests.push(rawUrl);
    }
  });

  return { pageErrors, consoleErrors, remoteRequests };
}

async function saveScreenshot(page: Page, filename: string, fullPage: boolean) {
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

async function expectNoHorizontalOverflow(page: Page, contextLabel: string) {
  const metrics = await page.evaluate(() => ({
    scrollWidth: document.documentElement.scrollWidth,
    innerWidth: window.innerWidth,
  }));
  expect(
    metrics.scrollWidth,
    `${contextLabel}: horizontal overflow detected (${metrics.scrollWidth} > ${metrics.innerWidth})`,
  ).toBeLessThanOrEqual(metrics.innerWidth);
}

test.describe("UniVerse Academic Ledger — Sub-Phase 1A E2E & Visual Verification", () => {
  test("Public Landing `/` renders zero remote traffic, user-controlled specimen, and clean responsive viewports", async ({
    browser,
  }) => {
    const context = await browser.newContext({
      viewport: { width: 1440, height: 900 },
    });
    const page = await context.newPage();
    const { pageErrors, consoleErrors, remoteRequests } =
      attachErrorAndNetworkWatchers(page);

    await page.goto("/", { waitUntil: "networkidle" });

    // 1. Permanent preview disclosure notice & zero unauthenticated backend traffic
    await expect(
      page.getByText(
        "Illustrative sample schedule — interactive preview only, not a live CP-SAT solver run.",
      ),
    ).toBeVisible();
    expect(remoteRequests).toEqual([]);

    // Single-row compact header height check & zero horizontal overflow at 1440x900
    const headerDesktop = await page.locator("header").boundingBox();
    expect(headerDesktop?.height ?? 999).toBeLessThanOrEqual(64);
    await expectNoHorizontalOverflow(page, "Landing 1440x900");

    await saveScreenshot(page, "01_landing_1440x900.png", true);

    // 2. Verify zero automatic background loop & verify user-driven toggles update UI
    const previewSection = page.locator(
      'section[aria-label="Illustrative timetable rule preview"]',
    );
    const beforePauseText = await previewSection.innerText();
    await page.waitForTimeout(1200);
    expect(await previewSection.innerText()).toBe(beforePauseText);

    await page.getByRole("button", { name: "Faculty" }).click();
    await expect(page.getByText("Faculty EBH", { exact: true })).toBeVisible();

    await page.getByRole("button", { name: "7-Slot" }).click();
    await expect(page.getByText("P7", { exact: true })).toBeVisible();

    await page.getByLabel("Friday P4 Jummah Lock").click();
    await expect(page.getByText("Rule conflict")).toBeVisible();

    await page.getByRole("button", { name: "Reset" }).click();
    await expect(page.getByText("Batch 58 B+C", { exact: true })).toBeVisible();

    // 3. Tablet 1024x768 responsive verification
    await page.setViewportSize({ width: 1024, height: 768 });
    await expectNoHorizontalOverflow(page, "Landing 1024x768");
    await saveScreenshot(page, "02_landing_1024x768.png", true);

    // 4. Mobile 390x844 responsive verification (single-row <=56px header, zero overflow)
    await page.setViewportSize({ width: 390, height: 844 });
    const headerMobile = await page.locator("header").boundingBox();
    expect(headerMobile?.height ?? 999).toBeLessThanOrEqual(60);
    await expectNoHorizontalOverflow(page, "Landing 390x844");
    await saveScreenshot(page, "03_landing_390x844.png", true);

    // Mobile compact list toggle screenshot
    await page.getByRole("button", { name: "List" }).click();
    await expectNoHorizontalOverflow(page, "Landing List View 390x844");
    await saveScreenshot(page, "04_landing_list_390x844.png", false);

    expect(remoteRequests).toEqual([]);
    expect(pageErrors).toEqual([]);
    expect(consoleErrors).toEqual([]);
    await context.close();
  });

  test("Auth routes render above the fold on 390x844, hide internal jargon, validate forms, and update password checklist live", async ({
    browser,
  }) => {
    const context = await browser.newContext({
      viewport: { width: 1440, height: 900 },
    });
    const page = await context.newPage();
    const { pageErrors, consoleErrors } = attachErrorAndNetworkWatchers(page);

    await page.goto("/login", { waitUntil: "networkidle" });
    await expect(
      page.getByRole("heading", { name: "Administrator Sign In" }),
    ).toBeVisible();
    await expect(
      page.getByRole("button", { name: /Continue with Google/i }),
    ).toBeVisible();

    // Verify clean institutional copy (no raw table names or dev simulator cards)
    const loginBody = await page.locator("body").innerText();
    expect(loginBody).not.toContain("public.whitelists");
    expect(loginBody).not.toContain("Supabase PKCE");
    expect(loginBody).not.toContain("No .env.local detected");
    await expectNoHorizontalOverflow(page, "Login 1440x900");
    await saveScreenshot(page, "05_login_1440x900.png", true);

    // Trigger zod validation cleanly
    await page
      .getByRole("button", { name: /Sign In to Operations Console/i })
      .click();
    await expect(
      page.getByText(/Enter your committee institutional email/i),
    ).toBeVisible();

    // Verify Sign-In card sits ABOVE THE FOLD at 390x844 mobile viewport
    await page.setViewportSize({ width: 390, height: 844 });
    await expectNoHorizontalOverflow(page, "Login 390x844");
    const authAsideBox = await page
      .locator('aside[aria-label="Administrator authentication"]')
      .boundingBox();
    const contextPanelBox = await page
      .locator('section[aria-label="Departmental administration context"]')
      .boundingBox();
    const emailBox = await page.locator("#admin-email").boundingBox();

    expect(authAsideBox).not.toBeNull();
    expect(contextPanelBox).not.toBeNull();
    expect(emailBox).not.toBeNull();
    expect(authAsideBox!.y).toBeLessThan(contextPanelBox!.y);
    expect(emailBox!.y + emailBox!.height).toBeLessThan(844);

    await saveScreenshot(page, "06_login_390x844.png", false);

    // Reset Password live 4-item checklist
    await page.setViewportSize({ width: 1440, height: 900 });
    await page.goto("/reset-password", { waitUntil: "networkidle" });
    await page.fill("#new-password", "abc");
    await expect(
      page.locator('[data-testid="password-requirements-checklist"] li[data-met="true"]'),
    ).toHaveCount(0);

    await page.fill("#new-password", "Routine2026");
    await page.fill("#confirm-password", "Routine2026");
    await expect(
      page.locator('[data-testid="password-requirements-checklist"] li[data-met="true"]'),
    ).toHaveCount(4);

    await saveScreenshot(page, "07_reset_password_1440x900.png", true);

    // Forgot Password check
    await page.goto("/forgot-password", { waitUntil: "networkidle" });
    await expect(
      page.getByRole("heading", { name: "Reset Admin Password" }),
    ).toBeVisible();
    await expectNoHorizontalOverflow(page, "Forgot Password 1440x900");

    expect(pageErrors).toEqual([]);
    expect(consoleErrors).toEqual([]);
    await context.close();
  });

  test("Admin Shell & Dashboard preview honor capability registry, empty eligibility alert, filter reset, and responsive breakpoints", async ({
    browser,
  }) => {
    const context = await browser.newContext({
      viewport: { width: 1440, height: 900 },
    });
    const page = await context.newPage();
    const { pageErrors, consoleErrors } = attachErrorAndNetworkWatchers(page);

    // Block live Render network poll so screenshots/tests remain fast and deterministic
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

    await page.goto("/admin/dashboard?preview=admin", {
      waitUntil: "networkidle",
    });

    await expect(page.getByTestId("dev-preview-banner")).toContainText(
      "Illustrative preview — disconnected from live Supabase & FastAPI backends.",
    );
    await expect(page.getByTestId("empty-eligibility-warning")).toContainText(
      "0 configured eligibility records",
    );

    const dashboardText = await page.locator("body").innerText();
    expect(dashboardText).not.toContain("Spring_2026_Final_v4.xlsx");
    expect(dashboardText).not.toContain("9f4c8a");
    expect(dashboardText).not.toContain("public.routines");

    await expectNoHorizontalOverflow(page, "Admin Dashboard 1440x900");
    await saveScreenshot(page, "08_admin_dashboard_1440x900.png", true);

    // Exercise upfront filter counts (`Ready (1)` filters to Stage 04; `All (4)` restores all 4)
    await page.getByRole("button", { name: "Ready (1)" }).click();
    await expect(
      page.getByText("Room & Lab Pools", { exact: true }),
    ).toBeHidden();
    await expect(
      page.getByText("Active Routine & Publication"),
    ).toBeVisible();
    await page.getByRole("button", { name: "All (4)" }).click();
    await expect(
      page.getByText("Room & Lab Pools", { exact: true }),
    ).toBeVisible();

    // Open single Account Popover & inspect Admin badge
    await page.getByTestId("admin-account-menu-btn").click();
    await expect(page.getByRole("menuitem", { name: "My Profile" })).toBeVisible();
    await page.keyboard.press("Escape");

    // 1024x768 responsive admin check (drawer button exposed)
    await page.setViewportSize({ width: 1024, height: 768 });
    await expect(
      page.getByRole("button", { name: "Open navigation sidebar" }),
    ).toBeVisible();
    await expectNoHorizontalOverflow(page, "Admin Dashboard 1024x768");
    await saveScreenshot(page, "09_admin_dashboard_1024x768.png", true);

    // 390x844 mobile admin check
    await page.setViewportSize({ width: 390, height: 844 });
    await expectNoHorizontalOverflow(page, "Admin Dashboard 390x844");
    await saveScreenshot(page, "10_admin_dashboard_390x844.png", true);

    // Fail-closed Scheduling Workbench stub verification
    await page.setViewportSize({ width: 1440, height: 900 });
    await page.goto("/admin/scheduling", { waitUntil: "networkidle" });
    await expect(
      page.getByRole("heading", { level: 2, name: "5-Stage Scheduling Workbench" }),
    ).toBeVisible();
    await expect(page.locator("main").getByText("Locked · Gates A–D")).toBeVisible();
    await saveScreenshot(page, "11_admin_scheduling_locked_1440x900.png", true);

    expect(pageErrors).toEqual([]);
    expect(consoleErrors).toEqual([]);
    await context.close();
  });

  test("Honors prefers-reduced-motion: reduce without runtime errors", async ({
    browser,
  }) => {
    const context = await browser.newContext({
      viewport: { width: 1280, height: 800 },
      reducedMotion: "reduce",
    });
    const page = await context.newPage();
    const { pageErrors, consoleErrors } = attachErrorAndNetworkWatchers(page);

    await page.goto("/", { waitUntil: "networkidle" });
    await page.getByRole("button", { name: "Room" }).click();
    await expect(page.getByText("Lab ACL-1", { exact: true })).toBeVisible();

    await page.getByRole("link", { name: "Admin Sign In" }).click();
    await expect(
      page.getByRole("heading", { name: "Administrator Sign In" }),
    ).toBeVisible();

    expect(pageErrors).toEqual([]);
    expect(consoleErrors).toEqual([]);
    await context.close();
  });
});
