import { expect, test, type Page } from "@playwright/test";

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

async function setThemeMode(page: Page, mode: "light" | "dark") {
  await page.evaluate((theme) => {
    document.documentElement.setAttribute("data-theme", theme);
    try {
      window.localStorage.setItem("universe_theme", theme);
    } catch {
      // ignore
    }
  }, mode);
}

test.describe("Published Routines Archive v1 (/admin/routine?tab=archive)", () => {
  test("renders archive, filters, inspector, and responsive Light/Dark viewports with zero errors", async ({
    page,
  }) => {
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

    await page.setViewportSize({ width: 1440, height: 900 });
    await page.goto("/admin/routine?tab=archive&preview=admin", {
      waitUntil: "networkidle",
    });

    // Archive tab is active and view loads
    await expect(page.getByTestId("routine-archive-view")).toBeVisible();
    await expect(page.getByRole("tab", { name: /Archive/i })).toHaveAttribute(
      "aria-selected",
      "true",
    );

    // Active version dot-pill is visible
    await expect(page.getByTestId("archive-active-badge")).toBeVisible();

    // Filter pills work
    await page.getByTestId("archive-filter-storage-only").click();
    await expect(page.getByText("legacy_fall_2024_final_committee.xlsx")).toBeVisible();
    await page.getByTestId("archive-filter-all").click();

    // Open inspector on the active version row
    await page.getByText("Spring 2026 · v2026.2").first().click();
    await expect(page.getByTestId("archive-inspector-body")).toBeVisible();

    // Confirm Wave 2 disclosure: NO disabled Grid Preview or Rollback buttons, only muted footer note
    await expect(page.getByRole("button", { name: /Grid Preview/i })).toHaveCount(0);
    await expect(page.getByRole("button", { name: /Rollback/i })).toHaveCount(0);
    await expect(
      page.getByText(/2D archive grid preview unlocks in Phase 3B/i),
    ).toBeVisible();

    // Responsive + Light & Dark mode overflow checks
    const viewports: Array<{ name: string; width: number; height: number }> = [
      { name: "desktop-1440", width: 1440, height: 900 },
      { name: "tablet-1024", width: 1024, height: 768 },
      { name: "mobile-390", width: 390, height: 844 },
    ];

    for (const vp of viewports) {
      await page.setViewportSize({ width: vp.width, height: vp.height });
      for (const theme of ["light", "dark"] as const) {
        await setThemeMode(page, theme);
        await page.waitForTimeout(100);
        await expectNoHorizontalOverflow(page, `${vp.name}-${theme}`);
      }
    }

    expect(pageErrors, `Page errors: ${pageErrors.join("; ")}`).toEqual([]);
    expect(consoleErrors, `Console errors: ${consoleErrors.join("; ")}`).toEqual([]);
    expect(
      remoteRequests,
      `Unexpected remote requests in Dev Preview: ${remoteRequests.join("; ")}`,
    ).toEqual([]);
  });
});
