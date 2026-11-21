import fs from "node:fs";
import path from "node:path";
import { cleanup, fireEvent, render, screen } from "@testing-library/react";
import { MemoryRouter } from "react-router-dom";
import { afterEach, describe, expect, it, vi } from "vitest";
import { AdminDashboardView } from "@/features/admin/pages/AdminDashboardPage";
import type { AdminDashboardCounts } from "@/features/admin/services/adminDashboardService";

afterEach(cleanup);

function makeCounts(
  overrides: Partial<AdminDashboardCounts> = {},
): AdminDashboardCounts {
  return {
    profiles: 148,
    routines: 796,
    notifications: 18,
    timetableRooms: 0,
    timetableFaculty: 0,
    timetableCourseEligibility: 0,
    activeVersionLabel: "Spring 2026 · v2026.2",
    checkedAt: "2026-11-21T14:00:00.000Z",
    source: "dev-preview",
    ...overrides,
  };
}

describe("Backend-derived AdminDashboardView (Phase 1A honesty & async states)", () => {
  it("contains zero hardcoded illustrative .xlsx filenames or SHA digests in source or DOM", () => {
    const sourcePath = path.resolve(
      __dirname,
      "../../src/features/admin/pages/AdminDashboardPage.tsx",
    );
    const sourceText = fs.readFileSync(sourcePath, "utf8");
    expect(sourceText).not.toContain("Spring_2026_Final_v4.xlsx");
    expect(sourceText).not.toContain("9f4c8a");
    expect(sourceText).not.toContain("public.routines");
    expect(sourceText).not.toContain("Walmart");

    render(
      <MemoryRouter>
        <AdminDashboardView
          data={makeCounts()}
          isLoading={false}
          isFetching={false}
          isError={false}
          onRefresh={vi.fn()}
        />
      </MemoryRouter>,
    );

    expect(screen.getByTestId("dev-preview-banner").textContent).toContain(
      "Illustrative preview — disconnected from live Supabase & FastAPI backends.",
    );
    expect(
      screen.getByTestId("empty-eligibility-warning").textContent,
    ).toContain("0 configured eligibility records");
    expect(document.body.textContent).not.toMatch(/\.xlsx/i);
  });

  it("derives 4-stage readiness completion counts cleanly when backend baseline is populated", () => {
    render(
      <MemoryRouter>
        <AdminDashboardView
          data={makeCounts({
            source: "supabase",
            timetableRooms: 30,
            timetableFaculty: 56,
            timetableCourseEligibility: 142,
            routines: 796,
          })}
          isLoading={false}
          isFetching={false}
          isError={false}
          onRefresh={vi.fn()}
        />
      </MemoryRouter>,
    );

    expect(screen.queryByTestId("dev-preview-banner")).toBeNull();
    expect(screen.queryByTestId("empty-eligibility-warning")).toBeNull();
    expect(document.body.textContent).toContain("4 of 4 stages configured");
    expect(document.body.textContent).toContain("30 configured");
    expect(document.body.textContent).toContain("142 eligibility records");
  });

  it("handles filter-empty state with upfront filter counts and 1-click reset", () => {
    render(
      <MemoryRouter>
        <AdminDashboardView
          data={makeCounts({
            source: "supabase",
            routines: 0,
            timetableRooms: 0,
            timetableFaculty: 0,
            timetableCourseEligibility: 0,
          })}
          isLoading={false}
          isFetching={false}
          isError={false}
          onRefresh={vi.fn()}
        />
      </MemoryRouter>,
    );

    const readyFilterBtn = screen.getByRole("button", { name: "Ready (0)" });
    fireEvent.click(readyFilterBtn);
    expect(screen.getByTestId("readiness-filter-empty")).toBeTruthy();

    fireEvent.click(screen.getByRole("button", { name: "Clear Filter" }));
    expect(screen.queryByTestId("readiness-filter-empty")).toBeNull();
    expect(document.body.textContent).toContain("Room & Lab Pools");
  });

  it("renders loading skeleton and error recovery state with retry callback", () => {
    const onRefresh = vi.fn();
    const { rerender } = render(
      <MemoryRouter>
        <AdminDashboardView
          isLoading={true}
          isFetching={false}
          isError={false}
          onRefresh={onRefresh}
        />
      </MemoryRouter>,
    );
    expect(screen.getByLabelText("Loading command center")).toBeTruthy();

    rerender(
      <MemoryRouter>
        <AdminDashboardView
          isLoading={false}
          isFetching={false}
          isError={true}
          errorMessage="Database request timed out"
          onRefresh={onRefresh}
        />
      </MemoryRouter>,
    );

    expect(screen.getByRole("alert").textContent).toContain(
      "Database request timed out",
    );
    fireEvent.click(screen.getByRole("button", { name: /Retry Refresh/i }));
    expect(onRefresh).toHaveBeenCalledTimes(1);
  });
});
