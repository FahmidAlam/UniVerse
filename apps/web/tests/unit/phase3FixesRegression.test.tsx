import fs from "node:fs";
import path from "node:path";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { cleanup, fireEvent, render, screen } from "@testing-library/react";
import { MemoryRouter, Route, Routes } from "react-router-dom";
import { afterEach, describe, expect, it, vi } from "vitest";
import { TooltipProvider } from "@/components/ui/Tooltip";
import { AdminShell } from "@/features/admin/AdminShell";
import { AdminRoutinePage } from "@/features/routine/pages/AdminRoutinePage";
import { TimetableGridPage } from "@/features/routine/pages/TimetableGridPage";
import { assessBaselineConfigForPublish } from "@/features/routine/services/validationGate";
import { useRoutineOperationsStore } from "@/features/routine/store/routineOperationsStore";

const dismissSpy = vi.fn();

vi.mock("sonner", () => ({
  Toaster: () => null,
  toast: {
    dismiss: (...args: unknown[]) => dismissSpy(...args),
    success: vi.fn(),
    error: vi.fn(),
    message: vi.fn(),
    warning: vi.fn(),
  },
}));

vi.mock("@/features/auth/AuthProvider", () => ({
  useAuth: () => ({
    status: "authenticated",
    isDevPreview: true,
    profile: {
      id: "admin-1",
      name: "Committee Chair",
      email: "committee.cse@lus.ac.bd",
      role: "admin",
    },
    signOut: vi.fn().mockResolvedValue(undefined),
  }),
}));

afterEach(() => {
  cleanup();
  dismissSpy.mockClear();
  useRoutineOperationsStore.getState().clearWorkbook();
  useRoutineOperationsStore.setState({
    lens: "section",
    viewMode: "matrix",
    viewModeManuallyChosen: false,
    activeSource: "live",
    selectedDay: null,
  });
});

function renderWithRouter(initialEntry: string) {
  const qc = new QueryClient({
    defaultOptions: { queries: { retry: false } },
  });
  return render(
    <QueryClientProvider client={qc}>
      <TooltipProvider>
        <MemoryRouter initialEntries={[initialEntry]}>
          <Routes>
            <Route path="/admin" element={<AdminShell />}>
              <Route path="routine" element={<AdminRoutinePage />} />
              <Route path="timetable/grid" element={<TimetableGridPage />} />
              <Route path="dashboard" element={<div>Dashboard</div>} />
            </Route>
          </Routes>
        </MemoryRouter>
      </TooltipProvider>
    </QueryClientProvider>,
  );
}

describe("Phase 3 visual & UX fixes regression checks", () => {
  it("keeps active tab exclusive and renders readable Phase 3B badge on Upload Routine", () => {
    renderWithRouter("/admin/routine?tab=upload");

    const uploadTab = screen.getByRole("tab", { name: /Upload Routine/i });
    const generateTab = screen.getByRole("tab", { name: /Generate Routine/i });

    expect(uploadTab.getAttribute("aria-selected")).toBe("true");
    expect(uploadTab.className).toContain("bg-[var(--action-primary)]");
    expect(generateTab.getAttribute("aria-selected")).toBe("false");
    expect(generateTab.className).not.toContain("bg-[var(--action-primary)]");

    const phaseBadge = screen.getByText("Phase 3B");
    expect(phaseBadge.className).toContain("bg-[var(--bg-elevated)]");
    expect(phaseBadge.className).toContain("text-[var(--sem-joint-ink)]");
  });

  it("removes sticky topbar clipping, avoids duplicate Generate Routine CTAs on routine/grid routes, and dismisses toasts on navigation", () => {
    renderWithRouter("/admin/timetable/grid");

    const topHeader = document.querySelector("header");
    expect(topHeader).not.toBeNull();
    expect(topHeader!.className).not.toContain("sticky");

    // Topbar should NOT render a second Generate Routine button on /admin/timetable/grid
    const generateLinks = screen.getAllByRole("link", {
      name: /Generate Routine/i,
    });
    expect(generateLinks).toHaveLength(1);
    expect(dismissSpy).toHaveBeenCalled();
  });

  it("places Sonner Toaster at bottom-left with closeButton and 3500ms duration", () => {
    const appSource = fs.readFileSync(
      path.resolve(__dirname, "../../src/App.tsx"),
      "utf8",
    );
    expect(appSource).toContain('position="bottom-left"');
    expect(appSource).toContain("closeButton");
    expect(appSource).toContain("duration={3500}");
  });

  it("strips raw SQL/JSON keys from UI copy across ManagePublishedTab, GenerateRoutineTab, and validationGate", () => {
    const manageSource = fs.readFileSync(
      path.resolve(
        __dirname,
        "../../src/features/routine/components/ManagePublishedTab.tsx",
      ),
      "utf8",
    );
    const generateSource = fs.readFileSync(
      path.resolve(
        __dirname,
        "../../src/features/routine/components/GenerateRoutineTab.tsx",
      ),
      "utf8",
    );

    expect(manageSource).not.toContain("routine_versions");
    expect(manageSource).toContain("version snapshot");

    expect(generateSource).not.toContain("Settings Row (id=1)");
    expect(generateSource).toContain("Timetable Settings");
    expect(generateSource).not.toContain("({item.key})");
    expect(generateSource).not.toContain("public.routines");
    expect(generateSource).not.toContain("publish_routine()");

    const blocked = assessBaselineConfigForPublish({
      rooms: 0,
      activeRooms: 0,
      faculty: 0,
      activeFaculty: 0,
      eligibility: 0,
      hasSettings: false,
    });
    const combinedText = [
      ...blocked.blockingReasons,
      ...blocked.warnings,
    ].join(" ");
    expect(combinedText).not.toMatch(/timetable_rooms|timetable_faculty|timetable_settings|timetable_course_eligibility/);
  });

  it("uses singular '1 slot' grammar, unclipped search placeholder, right-edge scroll cue, and meaningful Compact List badges", async () => {
    const matrixSource = fs.readFileSync(
      path.resolve(
        __dirname,
        "../../src/features/routine/components/AcademicTimetableMatrix.tsx",
      ),
      "utf8",
    );
    expect(matrixSource).toContain('Search course, teacher, room (/)');
    expect(matrixSource).toContain('entry.slotCount === 1');
    expect(matrixSource).toContain('"1 slot"');
    expect(matrixSource).toContain("useHorizontalScrollCue");
    expect(matrixSource).not.toContain(">\n                            Note\n");

    renderWithRouter("/admin/timetable/grid");

    expect(
      await screen.findByPlaceholderText("Search course, teacher, room (/)"),
    ).toBeTruthy();

    fireEvent.click(screen.getByRole("button", { name: "Compact List" }));
    expect(await screen.findByTestId("routine-compact-list")).toBeTruthy();
  });

  it("renders On-Campus as muted plain text in R15 Timetable Settings rather than repetitive blue pills", () => {
    const settingsSource = fs.readFileSync(
      path.resolve(
        __dirname,
        "../../src/features/admin/pages/TimetableSettingsPage.tsx",
      ),
      "utf8",
    );
    expect(settingsSource).not.toContain('<Badge tone="theory">On-Campus</Badge>');
    expect(settingsSource).toContain('text-[var(--ink-muted)]');
    expect(settingsSource).toContain('<Badge tone="joint">Online Slot</Badge>');
  });
});
