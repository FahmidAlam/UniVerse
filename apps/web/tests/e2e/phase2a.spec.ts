import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { expect, test, type Page } from "@playwright/test";

const SPEC_DIR = path.dirname(fileURLToPath(import.meta.url));
const SCREENSHOT_DIR = path.resolve(
  SPEC_DIR,
  "../../../../docs/screenshots/web_phase_2a",
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

async function stubEngineHealth(page: Page) {
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
}

test.describe("UniVerse Academic Ledger — Sub-Phase 2A E2E & Visual QA", () => {
  test("Verifies all Phase 1A polish carry-overs across Landing, Login, Shell, and Registry", async ({
    browser,
  }) => {
    const context = await browser.newContext({
      viewport: { width: 1440, height: 900 },
    });
    const page = await context.newPage();
    const { pageErrors, consoleErrors, remoteRequests } = attachWatchers(page);
    await stubEngineHealth(page);

    // 1. Public Landing `/` — zero "01 —" eyebrow text, mobile <768px defaults to compact list
    await page.goto("/", { waitUntil: "networkidle" });
    await expect(page.locator("body")).not.toContainText("01 —");

    await page.setViewportSize({ width: 390, height: 844 });
    await page.goto("/", { waitUntil: "networkidle" });
    const listToggleBtn = page.getByRole("button", { name: "List" });
    await expect(listToggleBtn).toHaveAttribute("aria-pressed", "true");
    await expectNoHorizontalOverflow(page, "Landing 390x844");

    // 2. Public `/login` — renamed "Back to Home", zero "01 —" eyebrow
    await page.setViewportSize({ width: 1440, height: 900 });
    await page.goto("/login", { waitUntil: "networkidle" });
    await expect(page.getByRole("link", { name: "Back to Home" })).toBeVisible();
    await expect(page.locator("body")).not.toContainText("01 —");

    // 3. Admin Shell & Dashboard — 240px rail, zero READ-ONLY pill, Engine · Preview, full-contrast readiness CTAs
    await page.goto("/admin/dashboard?preview=admin", {
      waitUntil: "networkidle",
    });

    const railBox = await page.locator("aside").first().boundingBox();
    expect(railBox).not.toBeNull();
    expect(Math.round(railBox!.width)).toBe(240);

    await expect(page.locator("aside").first()).not.toContainText("READ-ONLY");
    await expect(page.getByText("Engine · Preview")).toBeVisible();

    // Readiness CTA buttons must stay visible (not hidden by row-reveal-action opacity: 0)
    const readinessCta = page.getByRole("link", { name: "Configure Rooms" });
    await expect(readinessCta).toBeVisible();
    const ctaOpacity = await readinessCta.evaluate((el) =>
      Number.parseFloat(window.getComputedStyle(el).opacity),
    );
    expect(ctaOpacity).toBe(1);

    // Charts on Dashboard (Recharts v3 batch load rendered + honest empty fallback on rooms)
    await expect(
      page.getByTestId("dashboard-batch-load-chart"),
    ).toContainText("Batch 56");
    await expect(
      page.getByTestId("dashboard-batch-load-chart").locator("svg").first(),
    ).toBeVisible();
    await expect(
      page.getByTestId("dashboard-room-breakdown-chart"),
    ).toContainText("0 rooms configured in baseline inventory.");

    await expectNoHorizontalOverflow(page, "Dashboard 1440x900");
    await page.screenshot({
      path: path.join(SCREENSHOT_DIR, "01_dashboard_1440x900.png"),
      fullPage: true,
    });

    // 4. Dashboard Feature Governance ledger shows "Rendered Routine Upload" / "Gated · Phase 3B"
    await expect(page.getByText("Rendered Routine Upload")).toBeVisible();
    await expect(page.getByText("Gated · Phase 3B")).toBeVisible();

    expect(remoteRequests).toEqual([]);
    expect(pageErrors).toEqual([]);
    expect(consoleErrors).toEqual([]);
    await context.close();
  });

  test("Completes Rooms, Faculty (R7 advisory, zero Permanent chip), Course Eligibility (cmdk), Settings (3 tabs), and Staged routes across viewports", async ({
    browser,
  }) => {
    const context = await browser.newContext({
      viewport: { width: 1440, height: 900 },
    });
    const page = await context.newPage();
    const { pageErrors, consoleErrors, remoteRequests } = attachWatchers(page);
    await stubEngineHealth(page);

    // Boot into authenticated dev-preview session
    await page.goto("/admin/dashboard?preview=admin", {
      waitUntil: "networkidle",
    });

    // --- 1. ROOM POOLS ---
    await page
      .locator("aside nav")
      .first()
      .getByRole("link", { name: "Room Pools" })
      .click();
    await expect(page.getByTestId("ledger-empty-state")).toBeVisible();

    // Open new inspector, create RAB-302 Gallery room
    await page.getByRole("button", { name: /Add Room/i }).click();
    await page.fill("#room-name", "RAB-302");
    await page.fill("#room-building", "RAB");
    await page.fill("#room-capacity", "120");
    await page.locator("#room-is-gallery").click();
    await page.getByRole("button", { name: "Create Room" }).click();

    await expect(
      page.locator("table").getByText("RAB-302", { exact: true }),
    ).toBeVisible();

    await page.screenshot({
      path: path.join(SCREENSHOT_DIR, "02_rooms_inspector_1440x900.png"),
      fullPage: true,
    });

    // Close inspector with Escape, add ACL-1 Lab
    await page.keyboard.press("Escape");
    await expect(page.locator("#room-name")).toBeHidden();

    await page.getByRole("button", { name: /Add Room/i }).click();
    await page.fill("#room-name", "ACL-1");
    await page.fill("#room-capacity", "42");
    await page.locator("#room-is-lab").click();
    await page.getByRole("button", { name: "Create Room" }).click();
    await expect(
      page.locator("table").getByText("ACL-1", { exact: true }),
    ).toBeVisible();
    await page.keyboard.press("Escape");

    // Exercise bulk action bar
    await page.getByLabel("Select all visible rows").click();
    await expect(page.getByTestId("bulk-action-bar")).toContainText(
      "2 selected",
    );
    await page.getByLabel("Select all visible rows").click();

    await expectNoHorizontalOverflow(page, "Rooms 1440x900");
    await page.screenshot({
      path: path.join(SCREENSHOT_DIR, "03_rooms_ledger_1440x900.png"),
      fullPage: true,
    });

    // --- 2. FACULTY (Zero Permanent chip, `/` shortcut, R7 off-day advisory) ---
    await page
      .locator("aside nav")
      .first()
      .getByRole("link", { name: "Faculty", exact: true })
      .click();
    await expect(
      page.getByRole("tab", { name: /Permanent/i }),
    ).toHaveCount(0);

    await page.getByRole("button", { name: /Add Faculty/i }).click();
    await page.fill("#faculty-acronym", "MHK");
    await page.fill("#faculty-name", "Mahbub Hasan Khan");
    // Uncheck default Thursday (`Thu`) so only Friday remains (triggers R7 advisory 1)
    await page.getByRole("button", { name: "Thu", exact: true }).click();
    await expect(page.getByTestId("r7-offday-advisory")).toBeVisible();
    await page.getByRole("button", { name: "Create Faculty" }).click();
    await expect(
      page.locator("table").getByText("MHK", { exact: true }),
    ).toBeVisible();
    await page.keyboard.press("Escape");

    // Verify `/` keyboard shortcut focuses search box
    await page.keyboard.press("/");
    await expect(page.getByLabel("Search faculty")).toBeFocused();

    await expectNoHorizontalOverflow(page, "Faculty 1440x900");
    await page.screenshot({
      path: path.join(SCREENSHOT_DIR, "04_faculty_1440x900.png"),
      fullPage: true,
    });

    // --- 3. COURSE ELIGIBILITY (cmdk Combobox selectors) ---
    await page
      .locator("aside nav")
      .first()
      .getByRole("link", { name: "Course Eligibility" })
      .click();
    await page.getByRole("button", { name: /Add Rule/i }).click();

    // Pick faculty MHK from cmdk combobox
    await page.locator("#elig-acronym").click();
    await page.getByRole("option", { name: /MHK/i }).first().click();

    // Enter custom course code CSE-2101 into cmdk combobox
    await page.locator("#elig-course-code").click();
    await page
      .getByPlaceholder("Filter dynamic courses...")
      .fill("CSE-2101");
    await page.getByRole("option", { name: /Use CSE-2101/i }).click();

    await page.fill("#elig-priority", "1");
    await page.getByRole("button", { name: "Save Rule" }).click();
    await expect(
      page.locator("table").getByText("CSE-2101", { exact: true }),
    ).toBeVisible();

    await expectNoHorizontalOverflow(page, "Eligibility 1440x900");
    await page.screenshot({
      path: path.join(SCREENSHOT_DIR, "05_eligibility_1440x900.png"),
      fullPage: true,
    });

    // --- 4. TIMETABLE SETTINGS (3 tabs, 7-slot toggle, Jummah lock, weights, sticky dirty + discard modal) ---
    await page
      .locator("aside nav")
      .first()
      .getByRole("link", { name: "Timetable Settings" })
      .click();
    await expect(
      page.getByRole("tab", { name: /Term Clock & R15 Grid/i }),
    ).toBeVisible();

    await page.getByRole("button", { name: "6-Slot Grid" }).click();
    await page.getByRole("button", { name: "7-Slot Grid" }).click();
    await page.getByRole("switch", { name: "Allow online slot allocation" }).click();
    await expect(page.getByText("Col L")).toBeVisible();
    await expect(page.getByTestId("sticky-dirty-bar")).toBeVisible();

    // Test discard confirmation dialog cleanly (cancel keeps edits, save persists)
    await page.getByTestId("sticky-dirty-bar").getByRole("button", { name: "Discard" }).click();
    await expect(
      page.getByText("Discard timetable settings changes?"),
    ).toBeVisible();
    await page.getByRole("button", { name: "Cancel" }).click();

    await page.evaluate(() => window.scrollTo(0, 0));
    await page.screenshot({
      path: path.join(SCREENSHOT_DIR, "06_settings_clock_1440x900.png"),
      fullPage: true,
    });

    await page
      .getByRole("tab", { name: /Committee Rules & Blocked Slots/i })
      .click();
    await expect(
      page.getByRole("button", { name: /Friday P4 blocked/i }),
    ).toBeDisabled();
    await expect(
      page.getByRole("button", { name: /Friday P4 blocked/i }),
    ).toContainText("Jummah");

    await page.evaluate(() => window.scrollTo(0, 0));
    await page.screenshot({
      path: path.join(SCREENSHOT_DIR, "07_settings_rules_1440x900.png"),
      fullPage: true,
    });

    await page.getByRole("tab", { name: /Optimization Weights/i }).click();
    await page.getByRole("button", { name: "Strict Off-Day & Spread" }).click();
    await page
      .getByTestId("sticky-dirty-bar")
      .getByRole("button", { name: "Save Settings" })
      .click();
    await expect(page.getByTestId("sticky-dirty-bar")).toBeHidden();

    // --- 5. COMMAND PALETTE (`Ctrl+K`) + STAGED ROUTES ---
    await page.keyboard.press("Control+k");
    const palette = page.getByTestId("command-palette-dialog");
    await expect(palette).toBeVisible();
    await palette.getByPlaceholder(/Jump to rooms/i).fill("Courses");
    await palette.locator('[cmdk-item]').first().click();
    await expect(page).toHaveURL(/\/admin\/timetable\/courses/);
    await expect(page.locator("main")).toContainText("Staged · No DB");

    await page
      .locator("aside nav")
      .first()
      .getByRole("link", { name: "Batches" })
      .click();
    await expect(page.locator("main")).toContainText("Staged · No DB");

    // Navigate back to Dashboard via Command Palette (`Ctrl+K`)
    await page.keyboard.press("Control+k");
    await palette.getByPlaceholder(/Jump to rooms/i).fill("Dashboard");
    await palette.locator('[cmdk-item]').first().click();
    await expect(
      page.getByTestId("dashboard-room-breakdown-chart"),
    ).toContainText("0 rooms configured in baseline inventory.");

    // --- 6. RESPONSIVE TABLET (1024x768) & MOBILE (390x844) CHECKS ---
    await page.setViewportSize({ width: 1024, height: 768 });
    await page.keyboard.press("Control+k");
    await palette.getByPlaceholder(/Jump to rooms/i).fill("Timetable Settings");
    await palette.locator('[cmdk-item]').first().click();
    await expectNoHorizontalOverflow(page, "Settings 1024x768");
    await page.screenshot({
      path: path.join(SCREENSHOT_DIR, "08_settings_1024x768.png"),
      fullPage: true,
    });

    await page.setViewportSize({ width: 390, height: 844 });
    await page.keyboard.press("Control+k");
    await palette.getByPlaceholder(/Jump to rooms/i).fill("Room Pools");
    await palette.locator('[cmdk-item]').first().click();
    await expectNoHorizontalOverflow(page, "Rooms 390x844");
    await page.screenshot({
      path: path.join(SCREENSHOT_DIR, "09_rooms_390x844.png"),
      fullPage: true,
    });

    // Verify detail inspector renders as modal dialog on < 1024px mobile
    await page.getByRole("button", { name: /Add Room/i }).click();
    await expect(page.getByRole("dialog")).toBeVisible();
    await page.keyboard.press("Escape");

    expect(remoteRequests).toEqual([]);
    expect(pageErrors).toEqual([]);
    expect(consoleErrors).toEqual([]);
    await context.close();
  });
});
