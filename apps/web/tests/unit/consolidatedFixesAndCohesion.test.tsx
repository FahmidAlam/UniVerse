import fs from "node:fs";
import path from "node:path";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { MemoryRouter } from "react-router-dom";
import { afterEach, describe, expect, it, vi } from "vitest";
import { TooltipProvider } from "@/components/ui/Tooltip";
import { buildFacultyBatchUpsertPayloads } from "@/features/admin/services/eligibilityService";
import { ManageUsersPage } from "@/features/admin/pages/ManageUsersPage";
import { fetchJobResult } from "@/features/routine/services/timetableEngineService";
import { PREVIEW_CANDIDATE_ROWS } from "@/features/scheduling/data/schedulingPreviewFixtures";
import { useSchedulingWorkbenchStore } from "@/features/scheduling/store/schedulingWorkbenchStore";

const mockDeleteWhitelist = vi.fn().mockResolvedValue(undefined);

vi.mock("@/features/auth/AuthProvider", () => ({
  useAuth: () => ({
    isDevPreview: true,
    profile: {
      id: "admin-1",
      email: "admin@lus.ac.bd",
      name: "Admin Lead",
      role: "admin",
      designation: "Committee Chair",
    },
    signOut: vi.fn(),
  }),
}));

vi.mock("@/features/admin/services/usersService", async (importOriginal) => {
  const actual =
    await importOriginal<typeof import("@/features/admin/services/usersService")>();
  return {
    ...actual,
    fetchAllProfiles: vi.fn().mockResolvedValue([
      {
        id: "admin-1",
        email: "admin@lus.ac.bd",
        name: "Admin Lead",
        role: "admin",
        designation: "Committee Chair",
        created_at: "2026-11-01T00:00:00Z",
      },
    ]),
    fetchWhitelistEntries: vi.fn().mockResolvedValue([
      {
        email: "stage-teacher@example.com",
        role: "teacher",
        name: "Stage Teacher",
        designation: "Lecturer",
        created_at: "2026-11-01T00:00:00Z",
      },
    ]),
    deleteWhitelistEntries: (...args: unknown[]) => mockDeleteWhitelist(...args),
  };
});

afterEach(() => {
  vi.restoreAllMocks();
  mockDeleteWhitelist.mockClear();
});

describe("Consolidated Staging Bug Fixes & Phase 4B Cohesion", () => {
  it("parses live-shaped Render /api/timetable/result/{job_id} response WITHOUT source_contract AND validates source_contract when present", async () => {
    const liveTrack1Payload = {
      job_id: "0e3e83be2545",
      rows: [
        {
          id: "r1",
          day: "Sunday",
          period: 1,
          time_start: "08:50:00",
          time_end: "10:05:00",
          subject: "Structured Programming",
          subject_code: "CSE-1101",
          teacher_code: "TFA",
          room: "RAB-301",
          batch: "58",
          section: "B+C",
          semester: 1,
          is_active: true,
          is_service: false,
        },
      ],
      service_rows: [],
      stats: { status: "OPTIMAL", solve_ms: 120, meetings: 4 },
      validation: { ok: true, teacher_clashes: 0 },
      report: {
        cohorts: ["58-B+C"],
        meta: {},
        excluded: [],
        warnings: [],
        offerings: [],
      },
      has_workbook: true,
    };

    const fetchSpy = vi
      .spyOn(globalThis, "fetch")
      .mockResolvedValueOnce(
        new Response(JSON.stringify(liveTrack1Payload), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        }),
      )
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            ...liveTrack1Payload,
            source_contract: {
              source_sha256: "abc123",
              revision: 4,
              invalidated_artifacts: [],
            },
          }),
          { status: 200, headers: { "Content-Type": "application/json" } },
        ),
      )
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            ...liveTrack1Payload,
            source_contract: { bad_field: true },
          }),
          { status: 200, headers: { "Content-Type": "application/json" } },
        ),
      );

    const resWithout = await fetchJobResult("0e3e83be2545");
    expect(resWithout.job_id).toBe("0e3e83be2545");
    expect(resWithout.source_contract).toBeUndefined();

    const resWith = await fetchJobResult("0e3e83be2545");
    expect(resWith.source_contract?.revision).toBe(4);

    await expect(fetchJobResult("0e3e83be2545")).rejects.toThrow(
      /schema mismatch/i,
    );
    expect(fetchSpy).toHaveBeenCalledTimes(3);
  });

  it("never invokes nil-UUID RPCs in schedulingCapabilities.ts and keeps Gates C & D locked", () => {
    const capSrc = fs.readFileSync(
      path.resolve(
        __dirname,
        "../../src/features/scheduling/services/schedulingCapabilities.ts",
      ),
      "utf8",
    );
    expect(capSrc).not.toContain("00000000-0000-0000-0000-000000000000");
    expect(capSrc).not.toContain("application/openapi+json");
    expect(capSrc).toContain("course_distribution_sources");
    expect(capSrc).toContain("course_distribution_revisions");
    expect(capSrc).toContain("course_distribution_corrections");
    expect(capSrc).toContain("course_distribution_artifacts");
  });

  it("constructs exact timetable_course_eligibility batch upsert payloads with zero non-DB keys", () => {
    const payloads = buildFacultyBatchUpsertPayloads(" ebh ", [
      { courseCode: "cse-3101", checked: true, priority: 1 },
      { courseCode: "CSE-3102", checked: false, priority: 2 },
      { courseCode: "CSE-3101", checked: true, priority: 3 }, // duplicate ignored
      { courseCode: "CSE-4101", checked: true, priority: null },
    ]);

    expect(payloads).toEqual([
      {
        acronym: "EBH",
        course_code: "CSE-3101",
        is_eligible: true,
        priority: 1,
      },
      {
        acronym: "EBH",
        course_code: "CSE-4101",
        is_eligible: true,
        priority: null,
      },
    ]);
    for (const p of payloads) {
      expect(Object.keys(p).sort()).toEqual([
        "acronym",
        "course_code",
        "is_eligible",
        "priority",
      ]);
    }
  });

  it("verifies single-row whitelist delete invokes delete mutation through ConfirmDialog", async () => {
    const qc = new QueryClient({
      defaultOptions: { queries: { retry: false } },
    });

    render(
      <QueryClientProvider client={qc}>
        <TooltipProvider>
          <MemoryRouter>
            <ManageUsersPage />
          </MemoryRouter>
        </TooltipProvider>
      </QueryClientProvider>,
    );

    const whitelistTab = await screen.findByRole("tab", {
      name: /Whitelists & Invites/i,
    });
    fireEvent.click(whitelistTab);

    const deleteBtn = await screen.findByRole("button", {
      name: "Delete whitelist stage-teacher@example.com",
    });
    fireEvent.click(deleteBtn);

    const confirmBtn = await screen.findByRole("button", {
      name: "Remove Entries",
    });
    fireEvent.click(confirmBtn);

    await waitFor(() => {
      expect(mockDeleteWhitelist).toHaveBeenCalledTimes(1);
    });
    expect(mockDeleteWhitelist.mock.calls[0]?.[0]).toEqual([
      "stage-teacher@example.com",
    ]);
  });

  it("updates Row 19 title dynamically on resolve, aligns Stage 5 to Batch 58-61, and removes filler Verified/Baseline pills", () => {
    useSchedulingWorkbenchStore.getState().resetWorkbench();
    const store = useSchedulingWorkbenchStore.getState();
    store.setMode("preview");

    const beforeRow19 = useSchedulingWorkbenchStore
      .getState()
      .previewReadinessItems.find((i) => i.id === "chk-teacher-pending");
    expect(beforeRow19?.title).toBe(
      "Unassigned Lab Instructor on Row 19 (CSE-2202)",
    );

    store.savePreviewCorrection({
      row: 19,
      column: "I",
      effectiveValue: "NJ",
      reason: "Assign lab instructor",
    });

    const afterRow19 = useSchedulingWorkbenchStore
      .getState()
      .previewReadinessItems.find((i) => i.id === "chk-teacher-pending");
    expect(afterRow19?.isResolved).toBe(true);
    expect(afterRow19?.title).toBe(
      "Lab Instructor Assigned on Row 19 (CSE-2202)",
    );

    const batches = new Set(PREVIEW_CANDIDATE_ROWS.map((r) => r.batch));
    expect(batches).toEqual(new Set(["58", "59", "60", "61"]));

    const policySrc = fs.readFileSync(
      path.resolve(
        __dirname,
        "../../src/features/scheduling/components/PolicyStudioStage.tsx",
      ),
      "utf8",
    );
    expect(policySrc).not.toContain('<Badge tone={overridden ? "joint" : "lab"}');

    const readinessSrc = fs.readFileSync(
      path.resolve(
        __dirname,
        "../../src/features/scheduling/components/PreflightReadinessStage.tsx",
      ),
      "utf8",
    );
    expect(readinessSrc).not.toContain('"Verified"');
  });
});
