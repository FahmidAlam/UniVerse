import fs from "node:fs";
import path from "node:path";
import { describe, expect, it, vi } from "vitest";
import {
  PREVIEW_DISTRIBUTION_RECORDS,
  PREVIEW_POLICY_ITEMS,
  PREVIEW_READINESS_ITEMS,
  PREVIEW_REVISION_CONTEXT,
} from "@/features/scheduling/data/schedulingPreviewFixtures";
import {
  appendCourseDistributionCorrection,
  getEffectiveColumnValue,
  hasFormulaCachedDiscrepancy,
  isStaleRevisionError,
  StaleRevisionError,
} from "@/features/scheduling/services/courseDistributionService";
import { resolveLiveSchedulingGates } from "@/features/scheduling/services/schedulingCapabilities";
import { useSchedulingWorkbenchStore } from "@/features/scheduling/store/schedulingWorkbenchStore";

describe("Track 2 Scheduling Workbench contracts & fail-closed boundaries", () => {
  it("uses exact SQL columns (revision_version, scheduling_scope_id) and never Flutter stub aliases", () => {
    const svcSource = fs.readFileSync(
      path.resolve(
        __dirname,
        "../../src/features/scheduling/services/courseDistributionService.ts",
      ),
      "utf8",
    );

    expect(svcSource).toContain("revision_version");
    expect(svcSource).toContain("scheduling_scope_id");
    expect(svcSource).toContain("read_course_distribution_revision");
    expect(svcSource).toContain("append_course_distribution_correction");
    expect(svcSource).toContain("expected_revision_version");
    expect(svcSource).toContain("prior_formula");
    expect(svcSource).toContain("prior_cached_value");
    expect(svcSource).toContain("next_effective_value");
    expect(svcSource).toContain("academic_terms ( label");
    expect(svcSource).not.toContain("p_revision_id");
    expect(svcSource).not.toContain("revisions.scope_id");

    const capSource = fs.readFileSync(
      path.resolve(
        __dirname,
        "../../src/features/scheduling/services/schedulingCapabilities.ts",
      ),
      "utf8",
    );
    expect(capSource).toContain("course_distribution_sources");
    expect(capSource).toContain("course_distribution_revisions");
    expect(capSource).toContain("course_distribution_corrections");
    expect(capSource).toContain("course_distribution_artifacts");
    expect(capSource).not.toContain("application/openapi+json");
    expect(capSource).not.toContain("00000000-0000-0000-0000-000000000000");
  });

  it("keeps Live Mode gates fail-closed even when revision rows exist, and keeps Gates C & D unconditionally locked", () => {
    // Row exists in DB, but read RPC failed/missing -> Gate A stays LOCKED
    const lockedWithRow = resolveLiveSchedulingGates({
      supabaseConfigured: true,
      isDevPreview: false,
      readRpcAvailable: false,
      appendRpcAvailable: true,
      scopeReadAuthorized: true,
      revisionRowExists: true,
    });
    expect(lockedWithRow.gateA.unlocked).toBe(false);
    expect(lockedWithRow.gateB.unlocked).toBe(false);
    expect(lockedWithRow.gateC.unlocked).toBe(false);
    expect(lockedWithRow.gateD.unlocked).toBe(false);

    // Gate A & B verified -> Gates C & D still remain unconditionally fail-closed in Phase 4B
    const partialLive = resolveLiveSchedulingGates({
      supabaseConfigured: true,
      isDevPreview: false,
      readRpcAvailable: true,
      appendRpcAvailable: true,
      scopeReadAuthorized: true,
      revisionRowExists: true,
    });
    expect(partialLive.gateA.unlocked).toBe(true);
    expect(partialLive.gateB.unlocked).toBe(true);
    expect(partialLive.gateC.unlocked).toBe(false);
    expect(partialLive.gateD.unlocked).toBe(false);
  });

  it("detects PostgreSQL SQLSTATE 40001 optimistic concurrency errors accurately", () => {
    expect(
      isStaleRevisionError({
        code: "40001",
        message: "Stale course distribution revision",
      }),
    ).toBe(true);
    expect(isStaleRevisionError(new StaleRevisionError("Stale", 7))).toBe(true);
    expect(
      isStaleRevisionError({
        code: "42501",
        message: "Permission denied for scope",
      }),
    ).toBe(false);
  });

  it("reconciles Design Preview fixture to 23 CSE offerings, 3 overlays, 2 conflicts, and 16 policy items across 5 pillars", () => {
    expect(PREVIEW_DISTRIBUTION_RECORDS).toHaveLength(23);
    expect(PREVIEW_REVISION_CONTEXT.totalRows).toBe(23);
    expect(PREVIEW_REVISION_CONTEXT.correctionCount).toBe(3);
    expect(PREVIEW_REVISION_CONTEXT.conflictCount).toBe(2);

    const row32 = PREVIEW_DISTRIBUTION_RECORDS.find((r) => r.row === 32)!;
    const discrepancy = hasFormulaCachedDiscrepancy(row32);
    expect(discrepancy).not.toBeNull();
    expect(discrepancy?.column).toBe("L");
    expect(discrepancy?.formula).toBe("=J32/14");
    expect(discrepancy?.cached).toBe(3);
    expect(getEffectiveColumnValue(row32, "L")).toBe("2");

    expect(PREVIEW_POLICY_ITEMS).toHaveLength(16);
    const pillars = new Set(PREVIEW_POLICY_ITEMS.map((i) => i.pillar));
    expect(pillars).toEqual(
      new Set(["calendar", "faculty", "facilities", "distribution", "governance"]),
    );

    const readinessSummary = PREVIEW_READINESS_ITEMS.find(
      (i) => i.id === "chk-dist-accepted",
    )!;
    expect(readinessSummary.description).toContain("23 CSE");
  });

  it("updates Design Preview store counts, artifact freshness, and readiness when applying an overlay or R15 override", () => {
    useSchedulingWorkbenchStore.getState().resetWorkbench();
    const store = useSchedulingWorkbenchStore.getState();
    store.setMode("preview");

    // Assign pending instructor on Row 19 -> resolves blocker & marks validation stale
    store.savePreviewCorrection({
      row: 19,
      column: "I",
      effectiveValue: "NJ",
      reason: "Assigned NJ per lab committee minutes",
    });

    const afterEdit = useSchedulingWorkbenchStore.getState();
    expect(afterEdit.previewRevision.revisionVersion).toBe(8);
    expect(afterEdit.previewRevision.correctionCount).toBe(4);
    expect(afterEdit.previewArtifactFreshness.validationReportStatus).toBe(
      "stale",
    );
    const blockerItem = afterEdit.previewReadinessItems.find(
      (i) => i.id === "chk-teacher-pending",
    )!;
    expect(blockerItem.isResolved).toBe(true);

    // Revalidate restores validationReportStatus to current
    afterEdit.revalidatePreviewArtifacts();
    expect(
      useSchedulingWorkbenchStore.getState().previewArtifactFreshness
        .validationReportStatus,
    ).toBe("current");

    // R15 6-slot override marks artifacts stale; Reset restores baseline
    afterEdit.applyPreviewPolicyOverride({
      ruleId: "R15",
      overrideValue: "6 daily slots",
      effectiveValue: "6 slots",
      typedPayload: { slot_count: 6 },
    });
    expect(
      useSchedulingWorkbenchStore.getState().previewArtifactFreshness
        .validationReportStatus,
    ).toBe("stale");
    afterEdit.resetPreviewPolicyOverride();
    const r15AfterReset = useSchedulingWorkbenchStore
      .getState()
      .previewPolicyItems.find((i) => i.ruleId === "R15");
    expect(r15AfterReset?.overrideValue).toBe("None");
  });

  it("forwards all 8 exact RPC params and surfaces StaleRevisionError on SQLSTATE 40001", async () => {
    const rpcSpy = vi.fn().mockResolvedValue({
      data: null,
      error: {
        code: "40001",
        message: "Stale course distribution revision",
      },
    });
    const fakeClient = { rpc: rpcSpy };

    await expect(
      appendCourseDistributionCorrection(
        {
          target_revision: "rev-1",
          expected_revision_version: 7,
          target_row: 19,
          target_column: "I",
          prior_formula: null,
          prior_cached_value: "Pending teacher declaration",
          next_effective_value: "NJ",
          reason: "Unit boundary test",
        },
        fakeClient as never,
      ),
    ).rejects.toBeInstanceOf(StaleRevisionError);

    expect(rpcSpy).toHaveBeenCalledWith(
      "append_course_distribution_correction",
      {
        target_revision: "rev-1",
        expected_revision_version: 7,
        target_row: 19,
        target_column: "I",
        prior_formula: null,
        prior_cached_value: "Pending teacher declaration",
        next_effective_value: "NJ",
        reason: "Unit boundary test",
      },
    );

    await expect(
      appendCourseDistributionCorrection(
        {
          target_revision: "rev-1",
          expected_revision_version: 7,
          target_row: 19,
          target_column: "I",
          prior_formula: null,
          prior_cached_value: null,
          next_effective_value: "NJ",
          reason: "No session test",
        },
        null,
      ),
    ).rejects.toThrow(/authenticated Supabase session/i);
  });
});
