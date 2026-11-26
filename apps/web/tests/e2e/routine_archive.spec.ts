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

function attachDevPreviewWatchers(page: Page) {
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
        rawUrl.includes("/auth/v1") ||
        rawUrl.includes("/api/timetable"))
    ) {
      remoteRequests.push(rawUrl);
    }
  });

  return { pageErrors, consoleErrors, remoteRequests };
}

test.describe("Stage 4 — Archive v2a 2D Grid Preview & Phase 3B Upload Routine Tab", () => {
  test("verifies Archive v2a 2D Grid Preview open/close, lens switching, and responsive Light/Dark viewports", async ({
    page,
  }) => {
    const { pageErrors, consoleErrors, remoteRequests } =
      attachDevPreviewWatchers(page);

    await page.setViewportSize({ width: 1440, height: 900 });
    await page.goto("/admin/routine?tab=archive&preview=admin", {
      waitUntil: "networkidle",
    });

    await expect(page.getByTestId("routine-archive-view")).toBeVisible();
    await expect(page.getByRole("tab", { name: /Archive/i })).toHaveAttribute(
      "aria-selected",
      "true",
    );
    await expect(page.getByTestId("archive-active-badge")).toBeVisible();

    // Filter pills work
    await page.getByTestId("archive-filter-storage-only").click();
    await expect(
      page.getByText("legacy_fall_2024_final_committee.xlsx"),
    ).toBeVisible();
    await page.getByTestId("archive-filter-all").click();

    // Open inspector on the active version row
    await page.getByText("Spring 2026 · v2026.2").first().click();
    await expect(page.getByTestId("archive-inspector-body")).toBeVisible();

    // Confirm Phase 4A-2 disclosure only mentions Gate D rollback, and Preview in 2D Grid is live
    await expect(page.getByTestId("archive-preview-grid-btn")).toBeVisible();
    await expect(page.getByRole("button", { name: /Rollback/i })).toHaveCount(0);
    await expect(
      page.getByText(/1-click PostgreSQL version rollback unlocks in Gate D/i),
    ).toBeVisible();

    // Launch 2D Grid Preview -> inspect read-only banner + switch lenses
    await page.getByTestId("archive-preview-grid-btn").click();
    await expect(page.getByTestId("archive-grid-preview-banner")).toContainText(
      "Historical Archive Preview — Read-Only",
    );
    await page.getByRole("button", { name: "Faculty", exact: true }).click();
    await expect(
      page.getByRole("rowheader", { name: /EBH/i }).first(),
    ).toBeVisible();
    await page.getByRole("button", { name: "Room", exact: true }).click();
    await page.getByRole("button", { name: "Section", exact: true }).click();

    const viewports: Array<{ name: string; width: number; height: number }> = [
      { name: "archive-preview-1440", width: 1440, height: 900 },
      { name: "archive-preview-1024", width: 1024, height: 768 },
      { name: "archive-preview-390", width: 390, height: 844 },
    ];

    for (const vp of viewports) {
      await page.setViewportSize({ width: vp.width, height: vp.height });
      for (const theme of ["light", "dark"] as const) {
        await setThemeMode(page, theme);
        await page.waitForTimeout(80);
        await expectNoHorizontalOverflow(page, `${vp.name}-${theme}`);
      }
    }

    // Return to Archive Ledger cleanly
    await page.setViewportSize({ width: 1440, height: 900 });
    await page.getByTestId("archive-back-to-ledger-btn").click();
    await expect(page.getByTestId("routine-archive-view")).toBeVisible();

    expect(pageErrors, `Page errors: ${pageErrors.join("; ")}`).toEqual([]);
    expect(consoleErrors, `Console errors: ${consoleErrors.join("; ")}`).toEqual([]);
    expect(
      remoteRequests,
      `Unexpected remote requests in Dev Preview: ${remoteRequests.join("; ")}`,
    ).toEqual([]);
  });

  test("verifies Phase 3B Upload Routine tab parsing, 2D preview, and responsive Light/Dark viewports", async ({
    page,
  }) => {
    const { pageErrors, consoleErrors, remoteRequests } =
      attachDevPreviewWatchers(page);

    await page.setViewportSize({ width: 1440, height: 900 });
    await page.goto("/admin/routine?tab=upload&preview=admin", {
      waitUntil: "networkidle",
    });

    await expect(page.getByTestId("upload-routine-view")).toBeVisible();
    await expect(page.getByRole("tab", { name: /Upload Routine/i })).toHaveAttribute(
      "aria-selected",
      "true",
    );
    // No stale Phase 3B gate badge on tab
    await expect(page.getByRole("tab", { name: /Phase 3B/i })).toHaveCount(0);

    // Upload synthetic .xlsx and parse in Dev Preview (zero remote requests)
    await page.getByTestId("upload-routine-file-input").setInputFiles({
      name: "Spring_2026_Committee_Rendered.xlsx",
      mimeType:
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      buffer: Buffer.from("PK\x03\x04dev-preview-rendered"),
    });
    await page.getByTestId("parse-workbook-btn").click();

    await expect(page.getByTestId("upload-parsed-summary")).toBeVisible();
    await expect(page.getByTestId("upload-validation-badge")).toContainText(
      "Pass",
    );
    await expect(page.getByTestId("upload-2d-preview")).toBeVisible();

    // Switch lens in embedded 2D matrix
    await page.getByRole("button", { name: "Faculty", exact: true }).click();
    await page.getByRole("button", { name: "Section", exact: true }).click();

    const viewports: Array<{ name: string; width: number; height: number }> = [
      { name: "upload-1440", width: 1440, height: 900 },
      { name: "upload-1024", width: 1024, height: 768 },
      { name: "upload-390", width: 390, height: 844 },
    ];

    for (const vp of viewports) {
      await page.setViewportSize({ width: vp.width, height: vp.height });
      for (const theme of ["light", "dark"] as const) {
        await setThemeMode(page, theme);
        await page.waitForTimeout(80);
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
