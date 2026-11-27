import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { cleanup, fireEvent, render, screen, waitFor } from "@testing-library/react";
import { MemoryRouter, Route, Routes } from "react-router-dom";
import { afterEach, describe, expect, it, vi } from "vitest";
import { TooltipProvider } from "@/components/ui/Tooltip";
import { RoutineArchiveTab } from "@/features/routine/components/RoutineArchiveTab";
import { UploadRoutineTab } from "@/features/routine/components/UploadRoutineTab";
import { AdminRoutinePage } from "@/features/routine/pages/AdminRoutinePage";
import {
  EngineJobError,
  MAX_WORKBOOK_UPLOAD_BYTES,
  parseRenderedWorkbook,
} from "@/features/routine/services/timetableEngineService";
import { resolveLiveSchedulingGates } from "@/features/scheduling/services/schedulingCapabilities";

const { probeMock } = vi.hoisted(() => ({
  probeMock: vi.fn(),
}));

vi.mock("sonner", () => ({
  Toaster: () => null,
  toast: {
    dismiss: vi.fn(),
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

vi.mock("@/features/scheduling/services/schedulingCapabilities", async (importOriginal) => {
  const actual =
    await importOriginal<
      typeof import("@/features/scheduling/services/schedulingCapabilities")
    >();
  return {
    ...actual,
    probeLiveSchedulingCapabilities: (...args: unknown[]) => probeMock(...args),
  };
});

function renderWithProviders(ui: React.ReactElement, initialEntry = "/admin/routine") {
  const qc = new QueryClient({
    defaultOptions: { queries: { retry: false } },
  });
  return render(
    <QueryClientProvider client={qc}>
      <TooltipProvider>
        <MemoryRouter initialEntries={[initialEntry]}>
          <Routes>
            <Route path="/admin/routine" element={ui} />
            <Route path="/admin/scheduling" element={<div>Scheduling</div>} />
            <Route path="/admin/timetable/grid" element={<div>Grid</div>} />
          </Routes>
        </MemoryRouter>
      </TooltipProvider>
    </QueryClientProvider>,
  );
}

afterEach(() => {
  cleanup();
  vi.restoreAllMocks();
  probeMock.mockReset();
});

describe("parseRenderedWorkbook client contract", () => {
  it("rejects files exceeding 15 MiB before hitting the network", async () => {
    const fetchSpy = vi.spyOn(globalThis, "fetch");
    const bigBlob = new Blob([new Uint8Array(MAX_WORKBOOK_UPLOAD_BYTES + 16)]);
    await expect(parseRenderedWorkbook(bigBlob)).rejects.toMatchObject({
      kind: "payload-too-large",
      status: 413,
    });
    expect(fetchSpy).not.toHaveBeenCalled();
  });

  it("maps 401, 413, and 429 (with Retry-After) into typed EngineJobError", async () => {
    const file = new File([new Uint8Array([0x50, 0x4b, 0x03, 0x04])], "routine.xlsx", {
      type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    });

    vi.spyOn(globalThis, "fetch").mockResolvedValueOnce(
      new Response(JSON.stringify({ detail: "Admin role required." }), {
        status: 403,
        headers: { "Content-Type": "application/json" },
      }),
    );
    await expect(parseRenderedWorkbook(file)).rejects.toMatchObject({
      kind: "auth",
      status: 403,
    });

    vi.spyOn(globalThis, "fetch").mockResolvedValueOnce(
      new Response(JSON.stringify({ detail: "ZIP bomb detected" }), {
        status: 413,
        headers: { "Content-Type": "application/json" },
      }),
    );
    await expect(parseRenderedWorkbook(file)).rejects.toMatchObject({
      kind: "payload-too-large",
      status: 413,
    });

    vi.spyOn(globalThis, "fetch").mockResolvedValueOnce(
      new Response(JSON.stringify({ detail: "Rate limit exceeded" }), {
        status: 429,
        headers: { "Content-Type": "application/json", "Retry-After": "18" },
      }),
    );
    try {
      await parseRenderedWorkbook(file);
      expect.unreachable("Should have thrown 429");
    } catch (err) {
      expect(err).toBeInstanceOf(EngineJobError);
      expect((err as EngineJobError).kind).toBe("rate-limited");
      expect((err as EngineJobError).retryAfterSeconds).toBe(18);
      expect((err as EngineJobError).message).toContain("18s");
    }
  });

  it("parses valid server response cleanly", async () => {
    const file = new File([new Uint8Array([0x50, 0x4b, 0x03, 0x04])], "routine.xlsx", {
      type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    });
    vi.spyOn(globalThis, "fetch").mockResolvedValueOnce(
      new Response(
        JSON.stringify({
          rows: [
            {
              id: "upload-0",
              day: "Sunday",
              period: 1,
              time_start: "08:50:00",
              time_end: "10:05:00",
              subject: "Database Systems",
              subject_code: "CSE-3101",
              teacher_name: "Md. Ebrahim Hossain",
              teacher_code: "EBH",
              teachers: ["EBH"],
              teacher_state: "assigned",
              room: "RAB-302",
              batch: "58",
              section: "B+C",
              semester: 6,
              is_active: true,
              is_service: false,
            },
          ],
          service_rows: [],
          warnings: [],
          stats: {
            meetings: 1,
            service_meetings: 0,
            total_meetings: 1,
            cohorts: 1,
            teachers: 1,
            days: 1,
            sheets_parsed: 1,
          },
          validation: { ok: true, teacher_clashes: 0, cohort_clashes: 0, room_clashes: 0 },
          detected_format: "UniVerse day sheets",
          sheet_names: ["Sunday"],
        }),
        { status: 200, headers: { "Content-Type": "application/json" } },
      ),
    );

    const parsed = await parseRenderedWorkbook(file);
    expect(parsed.rows).toHaveLength(1);
    expect(parsed.detected_format).toBe("UniVerse day sheets");
    expect(parsed.validation.ok).toBe(true);
  });
});

describe("UploadRoutineTab, RoutineArchiveTab v2a preview & Gate A/B badge", () => {
  it("rejects non-.xlsx files and parses valid .xlsx into 2D preview in UploadRoutineTab", async () => {
    renderWithProviders(<UploadRoutineTab />);

    const input = screen.getByTestId("upload-routine-file-input") as HTMLInputElement;

    const badFile = new File(["macro"], "bad.xlsm", { type: "application/octet-stream" });
    fireEvent.change(input, { target: { files: [badFile] } });
    expect(screen.getByTestId("upload-file-error")).toBeTruthy();

    const goodFile = new File(["PK\x03\x04valid"], "Spring_2026_Final.xlsx", {
      type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    });
    fireEvent.change(input, { target: { files: [goodFile] } });
    expect(screen.queryByTestId("upload-file-error")).toBeNull();

    fireEvent.click(screen.getByTestId("parse-workbook-btn"));
    expect(await screen.findByTestId("upload-parsed-summary")).toBeTruthy();
    expect(screen.getByTestId("upload-validation-badge").textContent).toContain("Pass");
    expect(screen.getByTestId("upload-2d-preview")).toBeTruthy();
  });

  it("opens and closes Historical Archive Preview — Read-Only in RoutineArchiveTab", async () => {
    renderWithProviders(<RoutineArchiveTab />);

    const activeRow = await screen.findByText("Spring 2026 · v2026.2");
    fireEvent.click(activeRow);

    const previewBtn = await screen.findByTestId("archive-preview-grid-btn");
    fireEvent.click(previewBtn);

    const banner = await screen.findByTestId("archive-grid-preview-banner");
    expect(banner.textContent).toContain("Historical Archive Preview — Read-Only");

    fireEvent.click(screen.getByTestId("archive-back-to-ledger-btn"));
    expect(await screen.findByTestId("routine-archive-view")).toBeTruthy();
  });

  it("renders Gates A–B Live · C–D Locked when probe unlocks A & B, and Locked · Gates A–D otherwise", async () => {
    probeMock.mockResolvedValueOnce(
      resolveLiveSchedulingGates({
        supabaseConfigured: true,
        isDevPreview: false,
        readRpcAvailable: true,
        appendRpcAvailable: true,
        scopeReadAuthorized: true,
        revisionRowExists: false,
      }),
    );

    renderWithProviders(<AdminRoutinePage />, "/admin/routine?tab=archive");

    await waitFor(() => {
      expect(screen.getByTestId("track2-workbench-gate-badge").textContent).toContain(
        "Gates A–B Live · C–D Locked",
      );
    });

    cleanup();

    probeMock.mockResolvedValueOnce(
      resolveLiveSchedulingGates({
        supabaseConfigured: true,
        isDevPreview: false,
        readRpcAvailable: false,
        appendRpcAvailable: false,
        scopeReadAuthorized: false,
        revisionRowExists: false,
      }),
    );

    renderWithProviders(<AdminRoutinePage />, "/admin/routine?tab=archive");

    await waitFor(() => {
      expect(screen.getByTestId("track2-workbench-gate-badge").textContent).toContain(
        "Locked · Gates A–D",
      );
    });

    cleanup();

    probeMock.mockResolvedValueOnce(
      resolveLiveSchedulingGates({
        supabaseConfigured: true,
        isDevPreview: false,
        readRpcAvailable: true,
        appendRpcAvailable: true,
        scopeReadAuthorized: true,
        revisionRowExists: true,
        policySnapshotsAvailable: true,
        validationArtifactPayloadAvailable: true,
        catalogCoursesAvailable: true,
        sectionPoliciesAvailable: true,
        facultyExtendedAvailable: true,
        roomsExtendedAvailable: true,
        solverJobsAvailable: true,
        routineVersionSnapshotAvailable: true,
        routineTeacherCodesAvailable: true,
      }),
    );

    renderWithProviders(<AdminRoutinePage />, "/admin/routine?tab=archive");

    await waitFor(() => {
      expect(screen.getByTestId("track2-workbench-gate-badge").textContent).toContain(
        "Gates A–D Live",
      );
    });
  });
});
