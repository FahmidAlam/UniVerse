import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { expect, test, type Page } from "@playwright/test";

const SPEC_DIR = path.dirname(fileURLToPath(import.meta.url));
const SCREENSHOT_DIR = path.resolve(
  SPEC_DIR,
  "../../../../docs/screenshots/web_phase_2b",
);

fs.mkdirSync(SCREENSHOT_DIR, { recursive: true });

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

async function stubEngineRoot(page: Page) {
  await page.route("https://universe-timetable-engine.onrender.com/", (route) =>
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
}

test.describe("UniVerse Academic Ledger — Phase 2A Fixes & Sub-Phase 2B E2E", () => {
  test("Verifies all 5 Phase 2A fixes (R15 vs Online Slot, official R1-R15 ledger, non-occluding StickyDirtyBar, unclipped 240px sidebar)", async ({
    browser,
  }) => {
    const context = await browser.newContext({
      viewport: { width: 1440, height: 900 },
    });
    const page = await context.newPage();
    const { pageErrors, consoleErrors, remoteRequests } = attachWatchers(page);
    await stubEngineRoot(page);

    await page.goto("/admin/dashboard?preview=admin", {
      waitUntil: "networkidle",
    });

    // Fix 4: 240px sidebar renders unclipped "Workbench" + "LOCKED" without ellipsis truncation
    const aside = page.locator("aside").first();
    const workbenchLabel = aside.getByText("Workbench", { exact: true });
    await expect(workbenchLabel).toBeVisible();
    const ellipsisMetrics = await workbenchLabel.evaluate((el) => ({
      scrollWidth: el.scrollWidth,
      clientWidth: el.clientWidth,
    }));
    expect(ellipsisMetrics.scrollWidth).toBeLessThanOrEqual(
      ellipsisMetrics.clientWidth + 1,
    );

    // Fix 1 & Fix 3 & Fix 5: Timetable Settings Tab 1 decoupled 6-Slot vs 7-Slot + Online Slot
    await aside.getByRole("link", { name: "Timetable Settings" }).click();
    await expect(page.getByText("Col K")).toBeVisible();
    await expect(page.getByText("Online Optional")).toHaveCount(0);

    await page.getByRole("switch", { name: "Allow online slot allocation" }).click();
    await expect(page.getByText("Col L")).toBeVisible();
    await expect(page.getByTestId("sticky-dirty-bar")).toBeVisible();

    // Verify docked StickyDirtyBar never overlaps P5/P6 rows vertically
    const p6Box = await page.getByText("P6", { exact: true }).boundingBox();
    const dirtyBox = await page.getByTestId("sticky-dirty-bar").boundingBox();
    expect(p6Box).not.toBeNull();
    expect(dirtyBox).not.toBeNull();
    expect(dirtyBox!.y).toBeGreaterThan(p6Box!.y + p6Box!.height);

    await page.evaluate(() => window.scrollTo(0, 0));
    await page.screenshot({
      path: path.join(SCREENSHOT_DIR, "06_settings_clock_1440x900.png"),
      fullPage: true,
    });

    // Fix 2: Tab 2 R1-R15 Policy Ledger shows exact official R1-R15 rules & non-occluding bar
    await page
      .getByRole("tab", { name: /Committee Rules & Blocked Slots/i })
      .click();
    await expect(
      page.getByText(
        "Consecutive 2-day section weekends across the 7-day week (Sunday–Saturday).",
      ),
    ).toBeVisible();
    await expect(
      page.getByText(
        "Flexible 6-slot or 7-slot regular daily on-campus period configuration (independent of optional online slots).",
      ),
    ).toBeVisible();

    const serviceBox = await page
      .getByRole("heading", { name: "External Service Course Handling" })
      .boundingBox();
    const dirtyRulesBox = await page
      .getByTestId("sticky-dirty-bar")
      .boundingBox();
    expect(serviceBox).not.toBeNull();
    expect(dirtyRulesBox).not.toBeNull();
    expect(dirtyRulesBox!.y).toBeGreaterThan(serviceBox!.y + serviceBox!.height);

    await page.evaluate(() => window.scrollTo(0, 0));
    await page.screenshot({
      path: path.join(SCREENSHOT_DIR, "07_settings_rules_1440x900.png"),
      fullPage: true,
    });

    expect(remoteRequests).toEqual([]);
    expect(pageErrors).toEqual([]);
    expect(consoleErrors).toEqual([]);
    await context.close();
  });

  test("Exercises all 4 Sub-Phase 2B live screens (Users, Broadcast, Resources, Profile) across desktop, tablet, and mobile", async ({
    browser,
  }) => {
    const context = await browser.newContext({
      viewport: { width: 1440, height: 900 },
    });
    const page = await context.newPage();
    const { pageErrors, consoleErrors, remoteRequests } = attachWatchers(page);
    await stubEngineRoot(page);

    await page.goto("/admin/dashboard?preview=admin", {
      waitUntil: "networkidle",
    });

    // --- 1. USERS DIRECTORY, WHITELISTS & INVITES ---
    await page
      .locator("aside nav")
      .first()
      .getByRole("link", { name: "User Whitelist" })
      .click();
    await expect(
      page
        .locator("main")
        .getByRole("heading", { name: "Authorized Users & Invites" }),
    ).toBeVisible();

    // Inspect own profile row -> self-demotion guard visible
    await page.locator("table tbody tr").first().click();
    await expect(page.getByTestId("self-demotion-guard-notice")).toBeVisible();
    await page.keyboard.press("Escape");

    // Switch to Whitelists tab -> add entry -> invite admin modal
    await page
      .getByRole("tab", { name: /Whitelists & Invites/i })
      .click();
    await page.getByRole("button", { name: /Add Whitelist Entry/i }).click();
    await page.fill("#wl-email", "faculty.new@lus.ac.bd");
    await page.fill("#wl-name", "Dr. Nadia Karim");
    await page.fill("#wl-teacher-code", "NDK");
    await page.getByRole("button", { name: "Save Entry" }).click();
    await expect(
      page.locator("table").getByText("faculty.new@lus.ac.bd"),
    ).toBeVisible();

    await page.getByRole("button", { name: /Invite Administrator/i }).click();
    await page.fill("#invite-admin-name", "Prof. Zahid Hasan");
    await page.fill("#invite-admin-email", "chair.invite@lus.ac.bd");
    await page.getByRole("button", { name: "Send Admin Invite" }).click();
    await expect(
      page.locator("table").getByText("chair.invite@lus.ac.bd"),
    ).toBeVisible();

    await expectNoHorizontalOverflow(page, "Users 1440x900");
    await page.screenshot({
      path: path.join(SCREENSHOT_DIR, "01_users_1440x900.png"),
      fullPage: true,
    });

    // --- 2. CAMPUS BROADCAST ---
    await page
      .locator("aside nav")
      .first()
      .getByRole("link", { name: "Campus Broadcast" })
      .click();
    await page.fill("#bc-title", "CSE-3101 Class Relocated");
    await page.selectOption("#bc-type", "room_change");
    await page.selectOption("#bc-role", "student");
    await page.fill("#bc-batch", "58");
    await page.fill("#bc-section", "B");
    await page.fill("#bc-body", "Session moved to RAB-302 at 10:10 AM.");
    await page.getByRole("button", { name: /Review & Publish Notice/i }).click();
    await page.getByRole("button", { name: "Publish Now" }).click();

    await expect(
      page.locator("table").getByText("CSE-3101 Class Relocated"),
    ).toBeVisible();

    await expectNoHorizontalOverflow(page, "Broadcast 1440x900");
    await page.screenshot({
      path: path.join(SCREENSHOT_DIR, "02_broadcast_1440x900.png"),
      fullPage: true,
    });

    // --- 3. ACADEMIC RESOURCES ---
    await page
      .locator("aside nav")
      .first()
      .getByRole("link", { name: "Academic Resources" })
      .click();
    await page.getByRole("button", { name: /Add Resource/i }).click();
    await page.fill("#res-title", "Algorithms Midterm Question Bank");
    await page.selectOption("#res-category", "PYQ");
    await page.selectOption("#res-semester", "4");
    await page.fill("#res-subject-code", "CSE-2201");
    await page.fill(
      "#res-drive-link",
      "https://drive.google.com/file/d/sample-algo-pyq",
    );
    await page.getByRole("button", { name: "Publish Resource" }).click();

    await expect(
      page.locator("table").getByText("Algorithms Midterm Question Bank"),
    ).toBeVisible();

    await expectNoHorizontalOverflow(page, "Resources 1440x900");
    await page.screenshot({
      path: path.join(SCREENSHOT_DIR, "03_resources_1440x900.png"),
      fullPage: true,
    });

    // --- 4. MY PROFILE (F-30 zero avatar upload) ---
    await page
      .locator("aside nav")
      .first()
      .getByRole("link", { name: "My Profile" })
      .click();
    await expect(page.locator('input[type="file"]')).toHaveCount(0);
    await page.fill("#prof-name", "Committee Chair Updated");
    await page.getByRole("button", { name: "Save Profile" }).click();
    await expect(page.getByText("Committee Chair Updated")).toBeVisible();

    await expectNoHorizontalOverflow(page, "Profile 1440x900");
    await page.screenshot({
      path: path.join(SCREENSHOT_DIR, "04_profile_1440x900.png"),
      fullPage: true,
    });

    // --- 5. RESPONSIVE TABLET (1024x768) & MOBILE (390x844) ---
    await page.setViewportSize({ width: 1024, height: 768 });
    await page.getByRole("button", { name: "Open navigation sidebar" }).click();
    await page
      .getByRole("dialog")
      .getByRole("link", { name: "User Whitelist" })
      .click();
    await expectNoHorizontalOverflow(page, "Users 1024x768");
    await page.screenshot({
      path: path.join(SCREENSHOT_DIR, "05_users_1024x768.png"),
      fullPage: true,
    });

    await page.setViewportSize({ width: 390, height: 844 });
    await page.getByRole("button", { name: "Open navigation sidebar" }).click();
    await page
      .getByRole("dialog")
      .getByRole("link", { name: "Campus Broadcast" })
      .click();
    await expectNoHorizontalOverflow(page, "Broadcast 390x844");
    await page.screenshot({
      path: path.join(SCREENSHOT_DIR, "08_broadcast_390x844.png"),
      fullPage: true,
    });

    expect(remoteRequests).toEqual([]);
    expect(pageErrors).toEqual([]);
    expect(consoleErrors).toEqual([]);
    await context.close();
  });
});
