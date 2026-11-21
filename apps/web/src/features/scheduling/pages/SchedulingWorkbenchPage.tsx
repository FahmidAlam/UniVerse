import { useQuery } from "@tanstack/react-query";
import { useCallback, useEffect, useMemo, useState } from "react";
import { useSearchParams } from "react-router-dom";
import { LedgerTableSkeleton } from "@/components/ui/AsyncStates";
import { useAuth } from "@/features/auth/AuthProvider";
import { DistributionLedgerStage } from "@/features/scheduling/components/DistributionLedgerStage";
import { PolicyStudioStage } from "@/features/scheduling/components/PolicyStudioStage";
import { PreflightReadinessStage } from "@/features/scheduling/components/PreflightReadinessStage";
import { ReviewDiffPublishStage } from "@/features/scheduling/components/ReviewDiffPublishStage";
import { RevisionSolveStage } from "@/features/scheduling/components/RevisionSolveStage";
import { SchedulingWorkbenchHeader } from "@/features/scheduling/components/SchedulingWorkbenchHeader";
import {
  fetchRevisionArtifactsFreshness,
  fetchScopedRevisions,
  readCourseDistributionRevision,
} from "@/features/scheduling/services/courseDistributionService";
import { probeLiveSchedulingCapabilities } from "@/features/scheduling/services/schedulingCapabilities";
import { useSchedulingWorkbenchStore } from "@/features/scheduling/store/schedulingWorkbenchStore";
import type {
  DistributionSourceRecord,
  WorkbenchStageId,
} from "@/features/scheduling/types";

function resolveStage(raw: string | null): WorkbenchStageId {
  if (
    raw === "policy" ||
    raw === "readiness" ||
    raw === "generate" ||
    raw === "review"
  ) {
    return raw;
  }
  return "distribution";
}

export function SchedulingWorkbenchPage() {
  const { isDevPreview } = useAuth();
  const [searchParams, setSearchParams] = useSearchParams();
  const activeStage = resolveStage(searchParams.get("stage"));
  const [highlightRow, setHighlightRow] = useState<number | null>(null);

  const {
    mode,
    liveGates,
    liveRevisions,
    liveSelectedRevisionId,
    liveRecords,
    liveArtifactFreshness,
    previewRevision,
    previewRecords,
    previewArtifactFreshness,
    previewReadinessItems,
    setMode,
    setLiveGates,
    setLiveRevisions,
    setLiveSelectedRevisionId,
    setLiveLoadedData,
    setSelectedRowNumber,
  } = useSchedulingWorkbenchStore();

  const probeQuery = useQuery({
    queryKey: ["scheduling-live-gates", isDevPreview],
    queryFn: () => probeLiveSchedulingCapabilities(isDevPreview),
    retry: false,
  });

  useEffect(() => {
    if (probeQuery.data) {
      setLiveGates(probeQuery.data);
    }
  }, [probeQuery.data, setLiveGates]);

  const revisionsQuery = useQuery({
    queryKey: [
      "scheduling-live-revisions",
      mode,
      liveGates.gateA.unlocked,
    ],
    enabled: mode === "live" && liveGates.gateA.unlocked,
    queryFn: () => fetchScopedRevisions(),
    retry: false,
  });

  useEffect(() => {
    if (revisionsQuery.data) {
      setLiveRevisions(revisionsQuery.data);
    }
  }, [revisionsQuery.data, setLiveRevisions]);

  const activeLiveRevision = useMemo(
    () =>
      liveRevisions.find((r) => r.revisionId === liveSelectedRevisionId) ??
      liveRevisions[0] ??
      null,
    [liveRevisions, liveSelectedRevisionId],
  );

  const loadSelectedLiveRevision = useCallback(async () => {
    if (mode !== "live" || !liveGates.gateA.unlocked || !activeLiveRevision) {
      return;
    }
    const [payload, freshness] = await Promise.all([
      readCourseDistributionRevision(activeLiveRevision.revisionId),
      fetchRevisionArtifactsFreshness(
        activeLiveRevision.revisionId,
        activeLiveRevision.revisionVersion,
      ),
    ]);

    const overlayRows: DistributionSourceRecord[] = [];
    const byRow = new Map<number, typeof payload.corrections>();
    for (const c of payload.corrections ?? []) {
      const list = byRow.get(c.source_row) ?? [];
      list.push(c);
      byRow.set(c.source_row, list);
    }

    for (const [rowNum, cols] of byRow.entries()) {
      const findCol = (colName: string) =>
        cols.find((c) => c.source_column === colName)?.effective_value;
      overlayRows.push({
        row: rowNum,
        batch: String(findCol("A") ?? ""),
        section: String(findCol("B") ?? ""),
        courseCode: String(findCol("C") ?? `ROW-${rowNum}`),
        courseTitle: String(findCol("D") ?? "Course Distribution Offering"),
        credit: Number(findCol("E") ?? 3) || 3,
        prerequisite: findCol("F") ? String(findCol("F")) : null,
        conductingDept: String(findCol("G") ?? "CSE"),
        studentCount: findCol("H") ? Number(findCol("H")) || null : null,
        teacher: String(findCol("I") ?? "Pending"),
        classes: Number(findCol("J") ?? 28) || 28,
        durationMinutes: Number(findCol("K") ?? 50) || 50,
        classesPerWeek: Number(findCol("L") ?? 2) || 2,
        formulaJ:
          cols.find((c) => c.source_column === "J")?.original_formula ?? null,
        formulaL:
          cols.find((c) => c.source_column === "L")?.original_formula ?? null,
        cachedJ:
          Number(
            cols.find((c) => c.source_column === "J")?.original_cached_value,
          ) || null,
        cachedL:
          Number(
            cols.find((c) => c.source_column === "L")?.original_cached_value,
          ) || null,
        corrections: cols.map((c, idx) => ({
          id: `live-corr-${payload.revision_id}-${c.source_row}-${c.source_column}-${idx}`,
          row: c.source_row,
          column: c.source_column,
          originalValue: String(c.original_cached_value ?? ""),
          originalFormula: c.original_formula,
          originalCachedValue: c.original_cached_value,
          effectiveValue: String(c.effective_value ?? ""),
          reason: "Verified committee overlay",
          author: "Supabase Track 2 Ledger",
          timestamp: activeLiveRevision.acceptedAt,
          revisionVersion: payload.revision_version,
        })),
        conflicts: [],
      });
    }

    setLiveLoadedData({
      revision: {
        ...activeLiveRevision,
        revisionVersion: payload.revision_version,
        status: payload.status,
        sourceHash: payload.source_sha256,
        sheetName: payload.sheet_name,
        totalRows: overlayRows.length,
        correctionCount: (payload.corrections ?? []).length,
      },
      records: overlayRows,
      freshness,
    });
  }, [activeLiveRevision, liveGates.gateA.unlocked, mode, setLiveLoadedData]);

  useEffect(() => {
    void loadSelectedLiveRevision();
  }, [loadSelectedLiveRevision]);

  const selectStage = (stage: WorkbenchStageId, row?: number) => {
    setSearchParams({ stage }, { replace: false });
    if (typeof row === "number") {
      setHighlightRow(row);
      setSelectedRowNumber(row);
    }
  };

  const isPreview = mode === "preview";
  const headerRevision = isPreview ? previewRevision : activeLiveRevision;
  const headerFreshness = isPreview
    ? previewArtifactFreshness
    : liveArtifactFreshness;
  const criticalCount = previewReadinessItems.filter(
    (i) => i.severity === "critical" && !i.isResolved,
  ).length;

  return (
    <div className="space-y-4">
      <SchedulingWorkbenchHeader
        mode={mode}
        onModeChange={setMode}
        activeStage={activeStage}
        onSelectStage={(stage) => selectStage(stage)}
        gates={liveGates}
        revision={headerRevision}
        freshness={headerFreshness}
        criticalReadinessCount={criticalCount}
      />

      {!isPreview && probeQuery.isLoading ? (
        <LedgerTableSkeleton
          rows={5}
          label="Verifying Track 2 distribution capability gates"
        />
      ) : (
        <>
          {activeStage === "distribution" && (
            <DistributionLedgerStage
              mode={mode}
              gateA={liveGates.gateA}
              gateB={liveGates.gateB}
              revision={headerRevision}
              records={isPreview ? previewRecords : liveRecords}
              revisionsList={liveRevisions}
              selectedRevisionId={liveSelectedRevisionId}
              onSelectRevision={setLiveSelectedRevisionId}
              onReloadLiveRevision={loadSelectedLiveRevision}
              onSwitchToPreview={() => setMode("preview")}
              highlightRow={highlightRow}
            />
          )}

          {activeStage === "policy" && (
            <PolicyStudioStage mode={mode} gateC={liveGates.gateC} />
          )}

          {activeStage === "readiness" && (
            <PreflightReadinessStage
              mode={mode}
              gateC={liveGates.gateC}
              onJumpToStage={selectStage}
            />
          )}

          {activeStage === "generate" && (
            <RevisionSolveStage
              mode={mode}
              gateD={liveGates.gateD}
              onJumpToStage={selectStage}
            />
          )}

          {activeStage === "review" && (
            <ReviewDiffPublishStage mode={mode} gateD={liveGates.gateD} />
          )}
        </>
      )}
    </div>
  );
}
