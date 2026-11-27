import { render, screen } from "@testing-library/react";
import { MemoryRouter } from "react-router-dom";
import { describe, expect, it } from "vitest";
import {
  getCapabilityById,
  resolveLiveCapabilityDescriptor,
} from "@/core/capabilities";
import { SolverDiagnosticsPanel } from "@/features/routine/components/SolverDiagnosticsPanel";
import {
  correlateRoutineArchive,
  restoreRoutineVersion,
} from "@/features/routine/services/routineArchiveService";
import {
  extractOutcomeDiagnostics,
  toPublishRpcRow,
} from "@/features/routine/services/timetableEngineService";
import {
  extractRowTeacherCodes,
  findCoTeacherBlockers,
} from "@/features/routine/services/validationGate";
import type { RoutineRow } from "@/features/routine/types";
import { resolveLiveSchedulingGates } from "@/features/scheduling/services/schedulingCapabilities";

describe("Stage 5C Gate D, Hybrid R7, Co-Teachers & Archive Rollback", () => {
  it("unlocks Gate D and coTeacherStorageLive only when Stage 5C contracts exist", () => {
    const preStage5c = resolveLiveSchedulingGates({
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
      solverJobsAvailable: false,
      routineVersionSnapshotAvailable: false,
      routineTeacherCodesAvailable: false,
    });
    expect(preStage5c.gateC.unlocked).toBe(true);
    expect(preStage5c.gateD.unlocked).toBe(false);
    expect(preStage5c.catalogs?.coTeacherStorageLive).toBe(false);

    const postStage5c = resolveLiveSchedulingGates({
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
    });
    expect(postStage5c.gateD.unlocked).toBe(true);
    expect(postStage5c.catalogs?.coTeacherStorageLive).toBe(true);

    const schedCap = resolveLiveCapabilityDescriptor(
      getCapabilityById("admin.scheduling")!,
      postStage5c,
    );
    expect(schedCap.status).toBe("live-persisted");
    expect(schedCap.sidebarBadge).toBeUndefined();
  });

  it("extracts ordered co-teachers, emits teacher_codes on publish, and lifts blockers when storage is live", () => {
    const coRow: RoutineRow = {
      id: "r-1",
      day: "Sunday",
      time_start: "08:50:00",
      time_end: "10:05:00",
      subject: "Compiler Lab",
      subject_code: "CSE-3312",
      teacher_name: "AA / BB",
      teacher_code: "AA",
      teacher_codes: ["AA", "BB"],
      teachers: ["BB", "AA"],
      room: "ACL-1",
      batch: "58",
      section: "B+C",
      semester: 6,
      is_active: true,
      is_service: false,
    };

    expect(extractRowTeacherCodes(coRow)).toEqual(["AA", "BB"]);
    expect(findCoTeacherBlockers([coRow], [])).toHaveLength(1);
    expect(
      findCoTeacherBlockers([coRow], [], { coTeacherStorageLive: true }),
    ).toEqual([]);

    const rpcRow = toPublishRpcRow(coRow);
    expect(rpcRow.teacher_code).toBe("AA");
    expect(rpcRow.teacher_codes).toEqual(["AA", "BB"]);
  });

  it("forwards Hybrid R7 resolved_faculty_off_days in extractOutcomeDiagnostics and renders table", () => {
    const diagnostics = extractOutcomeDiagnostics({
      outcome: "OPTIMAL",
      raw_status: "OPTIMAL",
      termination_reason: "optimal",
      proven_infeasible: false,
      conflicts: [],
      stats: {
        status: "OPTIMAL",
        resolved_faculty_off_days: [
          {
            acronym: "AA",
            employment_type: "permanent",
            declared_off_days: [],
            resolved_off_days: ["Friday", "Saturday"],
            active_teaching_days: ["Sunday", "Monday", "Tuesday"],
            provenance: "solver_resolved",
          },
        ],
      },
      validation: { ok: true },
    });

    expect(diagnostics?.resolved_faculty_off_days).toHaveLength(1);
    expect(diagnostics?.resolved_faculty_off_days?.[0]?.acronym).toBe("AA");

    render(
      <MemoryRouter>
        <SolverDiagnosticsPanel
          diagnostics={diagnostics!}
          validation={{ ok: true }}
          policyViolations={[]}
          failingCounters={[]}
        />
      </MemoryRouter>,
    );

    const panel = screen.getByTestId("resolved-faculty-offdays-panel");
    expect(panel).toBeTruthy();
    expect(panel.textContent).toContain("AA");
  });

  it("enables Archive v2b snapshot rollback and correlates rollback source badge", async () => {
    const dataset = correlateRoutineArchive({
      versions: [
        {
          id: "v-active",
          semester_label: "Fall 2026",
          source: "rollback",
          is_active: true,
          row_count: 14,
          stats: {},
          validation: { ok: true },
          notes: "Restored snapshot",
          published_at: "2026-11-27T10:00:00.000Z",
          published_by: null,
          created_at: "2026-11-27T10:00:00.000Z",
          snapshot_rows: [{ id: "1" }],
        },
        {
          id: "v-old",
          semester_label: "Spring 2026",
          source: "engine",
          is_active: false,
          row_count: 14,
          stats: {},
          validation: { ok: true },
          notes: null,
          published_at: "2026-09-01T10:00:00.000Z",
          published_by: null,
          created_at: "2026-09-01T10:00:00.000Z",
          snapshot_rows: [{ id: "2" }],
        },
      ],
      runs: [],
      storageFiles: [],
    });

    const activeItem = dataset.items.find((i) => i.versionId === "v-active");
    const oldItem = dataset.items.find((i) => i.versionId === "v-old");
    expect(activeItem?.source).toBe("rollback");
    expect(activeItem?.canRestore).toBe(false);
    expect(oldItem?.hasSnapshot).toBe(true);
    expect(oldItem?.canRestore).toBe(true);

    const previewRestore = await restoreRoutineVersion({
      versionId: "preview-ver-2",
      notes: "Stage 5C rollback test",
      isDevPreview: true,
    });
    expect(previewRestore.restoredFromVersionId).toBe("preview-ver-2");
    expect(previewRestore.rowCount).toBeGreaterThan(0);
  });
});
