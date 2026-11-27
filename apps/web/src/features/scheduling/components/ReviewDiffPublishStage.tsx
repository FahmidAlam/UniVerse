import {
  ArrowsClockwise,
  CheckCircle,
  Eye,
  LockSimple,
  UploadSimple,
  WarningCircle,
  X,
} from "@phosphor-icons/react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useMemo, useState } from "react";
import { toast } from "sonner";
import { Badge } from "@/components/ui/Badge";
import { Button } from "@/components/ui/Button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogTitle,
} from "@/components/ui/Dialog";
import { useAuth } from "@/features/auth/AuthProvider";
import { AcademicTimetableMatrix } from "@/features/routine/components/AcademicTimetableMatrix";
import { fetchBaselineConfigAndBuild } from "@/features/routine/services/buildEngineConfig";
import { fetchRoutines } from "@/features/routine/services/routineService";
import { publishRoutinePipeline } from "@/features/routine/services/timetableEngineService";
import { extractRowTeacherCodes } from "@/features/routine/services/validationGate";
import type { RoutineRow } from "@/features/routine/types";
import {
  PREVIEW_CANDIDATE_DIFF,
  PREVIEW_CANDIDATE_ROWS,
} from "@/features/scheduling/data/schedulingPreviewFixtures";
import { isStaleRevisionError } from "@/features/scheduling/services/courseDistributionService";
import { useSchedulingWorkbenchStore } from "@/features/scheduling/store/schedulingWorkbenchStore";
import type {
  GateStatusInfo,
  RevisionContext,
  WorkbenchMode,
  WorkbenchStageId,
} from "@/features/scheduling/types";

interface RoutineDiffEntry {
  id: string;
  subjectCode: string;
  cohort: string;
  kind: "added" | "removed" | "modified";
  beforeSummary: string;
  afterSummary: string;
  reason: string;
}

function computeRoutineDiff(
  activeRows: readonly RoutineRow[],
  candidateRows: readonly RoutineRow[],
): RoutineDiffEntry[] {
  const sigKey = (r: RoutineRow) =>
    `${r.subject_code.trim().toUpperCase()}::${r.batch.trim()}::${r.section.trim().toUpperCase()}`;
  const slotSig = (r: RoutineRow) =>
    `${r.day.trim()} ${r.time_start.slice(0, 5)} · ${r.room} · ${extractRowTeacherCodes(r).join("/") || "TBA"}`;

  const oldMap = new Map<string, RoutineRow[]>();
  const newMap = new Map<string, RoutineRow[]>();
  for (const r of activeRows) {
    const arr = oldMap.get(sigKey(r)) ?? [];
    arr.push(r);
    oldMap.set(sigKey(r), arr);
  }
  for (const r of candidateRows) {
    const arr = newMap.get(sigKey(r)) ?? [];
    arr.push(r);
    newMap.set(sigKey(r), arr);
  }

  const allKeys = Array.from(new Set([...oldMap.keys(), ...newMap.keys()])).sort();
  const diffs: RoutineDiffEntry[] = [];

  for (const k of allKeys) {
    const beforeList = [...(oldMap.get(k) ?? [])].sort((a, b) =>
      slotSig(a).localeCompare(slotSig(b)),
    );
    const afterList = [...(newMap.get(k) ?? [])].sort((a, b) =>
      slotSig(a).localeCompare(slotSig(b)),
    );
    const maxLen = Math.max(beforeList.length, afterList.length);
    for (let i = 0; i < maxLen; i += 1) {
      const b = beforeList[i];
      const a = afterList[i];
      if (!b && a) {
        diffs.push({
          id: `add-${k}-${i}`,
          subjectCode: a.subject_code,
          cohort: `${a.batch}-${a.section}`,
          kind: "added",
          beforeSummary: "Unscheduled",
          afterSummary: slotSig(a),
          reason: "New placement in candidate solve",
        });
      } else if (b && !a) {
        diffs.push({
          id: `rem-${k}-${i}`,
          subjectCode: b.subject_code,
          cohort: `${b.batch}-${b.section}`,
          kind: "removed",
          beforeSummary: slotSig(b),
          afterSummary: "Removed",
          reason: "Slot removed in candidate distribution",
        });
      } else if (b && a && slotSig(b) !== slotSig(a)) {
        diffs.push({
          id: `mod-${k}-${i}`,
          subjectCode: a.subject_code,
          cohort: `${a.batch}-${a.section}`,
          kind: "modified",
          beforeSummary: slotSig(b),
          afterSummary: slotSig(a),
          reason: "Reassigned day, room, time, or instructor",
        });
      }
    }
  }
  return diffs;
}

export function ReviewDiffPublishStage({
  mode,
  gateD,
  revision = null,
  coTeacherStorageLive = true,
  onReloadLiveRevision,
  onJumpToStage,
}: {
  mode: WorkbenchMode;
  gateD: GateStatusInfo;
  revision?: RevisionContext | null;
  coTeacherStorageLive?: boolean;
  onReloadLiveRevision?: () => Promise<void> | void;
  onJumpToStage?: (stage: WorkbenchStageId, row?: number) => void;
}) {
  const { profile } = useAuth();
  const queryClient = useQueryClient();
  const {
    liveArtifactFreshness,
    livePolicySnapshot,
    liveJobId,
    liveSolverResult,
    liveSolvedRevisionVersion,
    liveWorkbookBlob,
    livePublishedVersionId,
    setLivePublishedVersionId,
    previewRevision,
    previewArtifactFreshness,
    previewSolverResult,
    previewSimulatedPublishedAt,
    simulatePreviewPublish,
  } = useSchedulingWorkbenchStore();

  const [publishOpen, setPublishOpen] = useState(false);
  const [publishNotes, setPublishNotes] = useState("");
  const [notifyUsers, setNotifyUsers] = useState(false);
  const [staleRevisionError, setStaleRevisionError] = useState<string | null>(null);

  const isLiveUnlocked = mode === "live" && gateD.unlocked;

  const liveActiveRoutinesQuery = useQuery({
    queryKey: ["admin-routines", false],
    enabled: isLiveUnlocked,
    queryFn: () => fetchRoutines(false),
    retry: false,
  });

  const baselineQuery = useQuery({
    queryKey: ["admin-engine-baseline-config", false],
    enabled: isLiveUnlocked,
    queryFn: () => fetchBaselineConfigAndBuild(false),
    retry: false,
  });

  const liveCandidateAllRows = useMemo(
    () =>
      liveSolverResult
        ? [...liveSolverResult.rows, ...liveSolverResult.service_rows]
        : [],
    [liveSolverResult],
  );

  const liveDiffs = useMemo(
    () =>
      isLiveUnlocked && liveCandidateAllRows.length > 0
        ? computeRoutineDiff(
            liveActiveRoutinesQuery.data ?? [],
            liveCandidateAllRows,
          )
        : [],
    [isLiveUnlocked, liveActiveRoutinesQuery.data, liveCandidateAllRows],
  );

  const publishLiveMutation = useMutation({
    mutationFn: async () => {
      if (!liveSolverResult || !revision) {
        throw new Error("A current revision solve result is required to publish.");
      }
      return publishRoutinePipeline({
        jobId: liveJobId,
        result: liveSolverResult,
        workbookBlob: liveWorkbookBlob,
        semesterLabel: revision.semester,
        notes: publishNotes,
        notifyUsers,
        baselineCounts: baselineQuery.data?.baselineCounts ?? null,
        isPrivatePreview: false,
        createdBy: profile?.id ?? null,
        isDevPreview: false,
        source: "engine",
        allowCoTeachers: coTeacherStorageLive,
        schedulingScopeId: revision.scopeId || null,
        revisionId: revision.revisionId,
        revisionVersion: revision.revisionVersion,
        policySnapshotId: livePolicySnapshot?.id ?? null,
        requireFreshValidation: true,
      });
    },
    onSuccess: (outcome) => {
      setPublishOpen(false);
      setStaleRevisionError(null);
      setLivePublishedVersionId(outcome.versionId);
      void queryClient.invalidateQueries({ queryKey: ["admin-routines"] });
      void queryClient.invalidateQueries({
        queryKey: ["admin-routine-active-version"],
      });
      void queryClient.invalidateQueries({
        queryKey: ["admin-routine-archive"],
      });
      void queryClient.invalidateQueries({
        queryKey: ["admin-dashboard-counts"],
      });
      toast.success(
        `Published ${outcome.rowCount} routine slots with non-destructive archival`,
      );
    },
    onError: (err) => {
      if (isStaleRevisionError(err)) {
        setPublishOpen(false);
        setStaleRevisionError(
          err instanceof Error
            ? err.message
            : "Revision was modified concurrently (SQLSTATE 40001). Reload latest revision and re-solve before publishing.",
        );
        return;
      }
      toast.error("Live routine publish failed", {
        description: err instanceof Error ? err.message : "RPC failed.",
      });
    },
  });

  if (mode === "live" && !gateD.unlocked) {
    return (
      <section
        data-testid="live-gate-d-review-locked"
        className="ledger-card flex max-w-[760px] flex-col gap-3 p-6"
      >
        <div className="flex flex-wrap items-center justify-between gap-2">
          <span className="font-mono-tabular text-[12px] font-medium text-[var(--accent-brand)]">
            Stage 5 · Gate D Required
          </span>
          <Badge tone="joint" mono>
            <LockSimple size={12} aria-hidden="true" />
            <span>Locked · Gate D</span>
          </Badge>
        </div>
        <h2 className="text-[17px] font-semibold text-[var(--ink-primary)]">
          Candidate Diff &amp; Archiving Publication Locked in Live Mode
        </h2>
        <p className="text-[13.5px] leading-[1.55] text-[var(--ink-secondary)]">
          {gateD.reason} Track 1 direct schedule publication and published
          routine management remain available on{" "}
          <span className="font-semibold text-[var(--ink-primary)]">
            Routine Operations
          </span>
          .
        </p>
      </section>
    );
  }

  if (isLiveUnlocked) {
    const versionMatches =
      revision !== null &&
      liveSolvedRevisionVersion !== null &&
      liveSolvedRevisionVersion === revision.revisionVersion;
    const validationCurrent =
      liveArtifactFreshness.validationReportStatus === "current";
    const solverOk =
      liveSolverResult !== null &&
      (liveSolverResult.outcome === "OPTIMAL" ||
        liveSolverResult.outcome === "FEASIBLE" ||
        liveSolverResult.validation.ok);
    const canPublishLive =
      liveCandidateAllRows.length > 0 &&
      versionMatches &&
      validationCurrent &&
      solverOk;

    return (
      <div className="space-y-4" data-testid="live-gate-d-review-panel">
        {staleRevisionError && (
          <div
            role="alert"
            data-testid="live-publish-stale-error"
            className="flex flex-wrap items-center justify-between gap-3 rounded-[var(--r-card)] border border-[var(--sem-conflict-border)] bg-[var(--sem-conflict-bg)] px-4 py-3 text-[12.5px] text-[var(--sem-conflict-ink)]"
          >
            <div className="flex items-start gap-2">
              <WarningCircle size={16} className="mt-0.5 shrink-0" aria-hidden="true" />
              <span>{staleRevisionError}</span>
            </div>
            <Button
              type="button"
              variant="secondary"
              size="sm"
              onClick={() => {
                setStaleRevisionError(null);
                void onReloadLiveRevision?.();
              }}
            >
              <ArrowsClockwise size={14} aria-hidden="true" />
              <span>Reload Latest Revision</span>
            </Button>
          </div>
        )}

        {/* Freshness & Archiving Publish Gate */}
        <section
          data-testid="live-freshness-publish-card"
          className="ledger-card flex flex-wrap items-center justify-between gap-3 p-4"
        >
          <div className="space-y-1">
            <div className="flex flex-wrap items-center gap-2">
              <Badge tone={validationCurrent ? "lab" : "conflict"} mono>
                Validation: {liveArtifactFreshness.validationReportStatus}
              </Badge>
              <Badge tone={versionMatches && solverOk ? "lab" : "conflict"} mono>
                Solve Output:{" "}
                {versionMatches && solverOk ? "current" : "stale / missing"}
              </Badge>
              <Badge tone={coTeacherStorageLive ? "lab" : "neutral"} mono>
                Co-Teachers:{" "}
                {coTeacherStorageLive ? "text[] array live" : "scalar guard"}
              </Badge>
            </div>
            <p className="text-[12.5px] text-[var(--ink-secondary)]">
              {canPublishLive
                ? `Revision #${revision?.revisionNumber} (v${revision?.revisionVersion}) is verified and ready for atomic archival publication.`
                : "Run Stage 3 Server Preflight and Stage 4 Revision Solve against the latest revision before publishing."}
            </p>
          </div>

          <div className="flex flex-wrap items-center gap-2">
            {!canPublishLive && onJumpToStage && (
              <Button
                type="button"
                variant="secondary"
                size="sm"
                onClick={() => onJumpToStage("generate")}
              >
                <span>Go to Stage 4 Solve</span>
              </Button>
            )}
            <Button
              type="button"
              variant="primary"
              size="md"
              data-testid="live-open-publish-btn"
              disabled={!canPublishLive}
              onClick={() => setPublishOpen(true)}
            >
              <UploadSimple size={15} aria-hidden="true" />
              <span>Archive &amp; Publish Routine</span>
            </Button>
          </div>
        </section>

        {livePublishedVersionId && (
          <div
            role="status"
            data-testid="live-publish-success-banner"
            className="flex flex-wrap items-center justify-between gap-2 rounded-[var(--r-card)] border border-[var(--sem-lab-border)] bg-[var(--sem-lab-bg)] px-4 py-3 text-[12.5px] text-[var(--sem-lab-ink)]"
          >
            <div className="flex items-center gap-2 font-semibold">
              <CheckCircle size={16} weight="fill" aria-hidden="true" />
              <span>
                Routine version {livePublishedVersionId} published with non-destructive archival.
              </span>
            </div>
          </div>
        )}

        {liveCandidateAllRows.length > 0 && (
          <>
            <section className="space-y-3" data-testid="live-candidate-matrix">
              <div className="px-1">
                <h2 className="text-[15px] font-semibold text-[var(--ink-primary)]">
                  Candidate 2D Routine Matrix ({liveCandidateAllRows.length} Slots)
                </h2>
              </div>
              <AcademicTimetableMatrix
                overrideRows={liveCandidateAllRows}
                overrideSourceLabel={`Candidate · ${revision?.semester ?? "Revision"}`}
                coTeacherStorageLive={coTeacherStorageLive}
              />
            </section>

            <section className="ledger-card overflow-hidden">
              <div className="border-b border-[var(--border-subtle)] bg-[var(--bg-canvas)]/55 px-5 py-3">
                <h3 className="text-[14px] font-semibold text-[var(--ink-primary)]">
                  Candidate vs Active Routine Diff ({liveDiffs.length} Changes)
                </h3>
              </div>
              {liveDiffs.length === 0 ? (
                <div className="px-5 py-4 text-[12.5px] text-[var(--ink-muted)]">
                  No slot-level changes relative to the currently active routine.
                </div>
              ) : (
                <div className="max-h-[420px] divide-y divide-[var(--border-subtle)] overflow-y-auto">
                  {liveDiffs.slice(0, 120).map((diff) => (
                    <div
                      key={diff.id}
                      className="flex flex-wrap items-start justify-between gap-3 px-5 py-3 text-[12.5px]"
                    >
                      <div className="space-y-1">
                        <div className="flex items-center gap-2">
                          <Badge
                            tone={
                              diff.kind === "added"
                                ? "lab"
                                : diff.kind === "removed"
                                  ? "conflict"
                                  : "joint"
                            }
                            mono
                          >
                            {diff.kind.toUpperCase()}
                          </Badge>
                          <span className="font-mono-tabular font-semibold text-[var(--ink-primary)]">
                            {diff.subjectCode}
                          </span>
                          <span className="font-mono-tabular text-[var(--ink-muted)]">
                            Batch {diff.cohort}
                          </span>
                        </div>
                        <p className="text-[var(--ink-secondary)]">{diff.reason}</p>
                      </div>
                      <div className="font-mono-tabular text-right text-[11.5px]">
                        <div className="text-[var(--ink-muted)] line-through">
                          {diff.beforeSummary}
                        </div>
                        <div className="font-semibold text-[var(--ink-primary)]">
                          {diff.afterSummary}
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </section>
          </>
        )}

        <Dialog
          open={publishOpen}
          onOpenChange={(open) => {
            if (!open && !publishLiveMutation.isPending) {
              setPublishOpen(false);
            }
          }}
        >
          <DialogContent className="fixed left-1/2 top-1/2 w-[calc(100%-32px)] max-w-[480px] -translate-x-1/2 -translate-y-1/2 p-5">
            <div className="flex items-start justify-between gap-3">
              <div>
                <DialogTitle className="text-[17px] font-semibold text-[var(--ink-primary)]">
                  Archive &amp; Publish Routine Version
                </DialogTitle>
                <DialogDescription className="mt-1 text-[13px] text-[var(--ink-secondary)]">
                  Archives outgoing active rows non-destructively (
                  <code className="font-mono-tabular">is_active = false</code> +{" "}
                  <code className="font-mono-tabular">snapshot_rows</code>) and activates{" "}
                  {liveCandidateAllRows.length} slots for {revision?.semester}.
                </DialogDescription>
              </div>
              <button
                type="button"
                aria-label="Close publish confirmation modal"
                disabled={publishLiveMutation.isPending}
                onClick={() => setPublishOpen(false)}
                className="flex h-7 w-7 items-center justify-center rounded-[5px] text-[var(--ink-secondary)] hover:bg-[var(--surface-hover)]"
              >
                <X size={15} aria-hidden="true" />
              </button>
            </div>

            <div className="mt-4 space-y-3 text-[12.5px]">
              <label className="block space-y-1">
                <span className="font-medium text-[var(--ink-primary)]">
                  Release Notes (optional)
                </span>
                <input
                  type="text"
                  value={publishNotes}
                  onChange={(e) => setPublishNotes(e.target.value)}
                  placeholder="Committee approval notes..."
                  className="h-9 w-full rounded-[var(--r-control)] border border-[var(--border-subtle)] bg-[var(--bg-elevated)] px-3 text-[13px] text-[var(--ink-primary)] outline-none focus:border-[var(--accent-brand)]"
                />
              </label>

              <label className="flex cursor-pointer items-center gap-2 text-[var(--ink-primary)]">
                <input
                  type="checkbox"
                  checked={notifyUsers}
                  onChange={(e) => setNotifyUsers(e.target.checked)}
                />
                <span>Broadcast routine publication notification to students &amp; faculty</span>
              </label>
            </div>

            <div className="mt-5 flex justify-end gap-2">
              <Button
                type="button"
                variant="secondary"
                size="md"
                disabled={publishLiveMutation.isPending}
                onClick={() => setPublishOpen(false)}
              >
                Cancel
              </Button>
              <Button
                type="button"
                variant="primary"
                size="md"
                data-testid="confirm-live-publish-btn"
                disabled={publishLiveMutation.isPending}
                onClick={() => publishLiveMutation.mutate()}
              >
                <UploadSimple size={15} aria-hidden="true" />
                <span>
                  {publishLiveMutation.isPending
                    ? "Publishing…"
                    : "Confirm Archiving Publish"}
                </span>
              </Button>
            </div>
          </DialogContent>
        </Dialog>
      </div>
    );
  }

  const artifactsCurrent =
    previewArtifactFreshness.validationReportStatus === "current" &&
    previewArtifactFreshness.generationOutputStatus === "current";
  const solverOk = previewSolverResult?.outcome === "optimal";
  const canSimulatePublish = artifactsCurrent && solverOk;

  return (
    <div className="space-y-4">
      {/* Artifact Freshness Gate */}
      <section
        data-testid="artifact-freshness-card"
        className="ledger-card flex flex-wrap items-center justify-between gap-3 p-4"
      >
        <div className="space-y-1">
          <div className="flex flex-wrap items-center gap-2">
            <Badge
              tone={
                previewArtifactFreshness.normalizedInputStatus === "current"
                  ? "lab"
                  : "joint"
              }
              mono
            >
              Normalized Input: {previewArtifactFreshness.normalizedInputStatus}
            </Badge>
            <Badge
              tone={
                previewArtifactFreshness.validationReportStatus === "current"
                  ? "lab"
                  : "conflict"
              }
              mono
            >
              Validation Report: {previewArtifactFreshness.validationReportStatus}
            </Badge>
            <Badge
              tone={
                previewArtifactFreshness.generationOutputStatus === "current"
                  ? "lab"
                  : "conflict"
              }
              mono
            >
              Generation Output: {previewArtifactFreshness.generationOutputStatus}
            </Badge>
          </div>
          <p className="text-[12.5px] text-[var(--ink-secondary)]">
            {canSimulatePublish
              ? `Candidate output bound to Revision #${previewRevision.revisionNumber} (v${previewRevision.revisionVersion}) passes freshness verification.`
              : "Candidate artifacts are stale or non-optimal. Revalidate and re-run Stage 4 before publishing."}
          </p>
        </div>

        <Button
          variant="secondary"
          size="md"
          disabled={!canSimulatePublish}
          data-testid="open-publish-gate-btn"
          onClick={() => setPublishOpen(true)}
        >
          <UploadSimple size={15} aria-hidden="true" />
          <span>Preview Publish Flow (Simulated)</span>
        </Button>
      </section>

      {previewSimulatedPublishedAt && (
        <div
          role="status"
          data-testid="simulated-publish-outcome"
          className="flex flex-wrap items-center justify-between gap-2 rounded-[var(--r-card)] border border-[var(--sem-lab-border)] bg-[var(--sem-lab-bg)] px-4 py-3 text-[12.5px] text-[var(--sem-lab-ink)]"
        >
          <div className="flex items-center gap-2 font-semibold">
            <CheckCircle size={16} weight="fill" aria-hidden="true" />
            <span>
              Simulated Preview Complete · Zero Database Writes (
              {PREVIEW_CANDIDATE_ROWS.length} candidate slots verified)
            </span>
          </div>
          <Badge tone="joint" mono>
            <Eye size={11} aria-hidden="true" />
            <span>Preview Only</span>
          </Badge>
        </div>
      )}

      {/* Embedded Candidate 7-Day Matrix Preview (Reusing Real AcademicTimetableMatrix) */}
      <section className="space-y-3" data-testid="stage5-candidate-matrix">
        <div className="flex flex-wrap items-center justify-between gap-2 px-1">
          <div>
            <h2 className="text-[15px] font-semibold text-[var(--ink-primary)]">
              Candidate 2D Routine Matrix (7-Day Preview)
            </h2>
            <p className="text-[12.5px] text-[var(--ink-secondary)]">
              Inspect scheduled 75-minute placements across Section, Faculty, and Room lenses with Friday P4 Jummah Lock.
            </p>
          </div>
        </div>

        <AcademicTimetableMatrix
          overrideRows={PREVIEW_CANDIDATE_ROWS}
          overrideSourceLabel="Simulated Candidate · Batch 58–61"
        />
      </section>

      {/* Candidate vs Active Diff Ledger */}
      <section className="ledger-card overflow-hidden">
        <div className="border-b border-[var(--border-subtle)] bg-[var(--bg-canvas)]/55 px-5 py-3">
          <h3 className="text-[14px] font-semibold text-[var(--ink-primary)]">
            Candidate vs Active Routine Diff ({PREVIEW_CANDIDATE_DIFF.length}{" "}
            Changes)
          </h3>
        </div>
        <div className="divide-y divide-[var(--border-subtle)]">
          {PREVIEW_CANDIDATE_DIFF.map((diff) => (
            <div
              key={diff.id}
              className="flex flex-wrap items-start justify-between gap-3 px-5 py-3 text-[12.5px]"
            >
              <div className="space-y-1">
                <div className="flex items-center gap-2">
                  <Badge
                    tone={
                      diff.kind === "added"
                        ? "lab"
                        : diff.kind === "removed"
                          ? "conflict"
                          : "joint"
                    }
                    mono
                  >
                    {diff.kind.toUpperCase()}
                  </Badge>
                  <span className="font-mono-tabular font-semibold text-[var(--ink-primary)]">
                    {diff.subjectCode}
                  </span>
                  <span className="font-mono-tabular text-[var(--ink-muted)]">
                    Batch {diff.cohort}
                  </span>
                </div>
                <p className="text-[var(--ink-secondary)]">{diff.reason}</p>
              </div>
              <div className="font-mono-tabular text-right text-[11.5px]">
                <div className="text-[var(--ink-muted)] line-through">
                  {diff.beforeSummary}
                </div>
                <div className="font-semibold text-[var(--ink-primary)]">
                  {diff.afterSummary}
                </div>
              </div>
            </div>
          ))}
        </div>
      </section>

      {/* Publish Confirmation Modal (Simulated Preview Only — Zero DB Writes) */}
      <Dialog open={publishOpen} onOpenChange={setPublishOpen}>
        <DialogContent className="fixed left-1/2 top-1/2 w-[calc(100%-32px)] max-w-[480px] -translate-x-1/2 -translate-y-1/2 p-5">
          <div className="flex items-start justify-between gap-3">
            <div>
              <DialogTitle className="text-[17px] font-semibold text-[var(--ink-primary)]">
                Simulated Preview Publication Confirmation
              </DialogTitle>
              <DialogDescription className="mt-1 text-[13px] text-[var(--ink-secondary)]">
                Design Preview verifies the 3-step publication gate locally with
                zero writes to Supabase.
              </DialogDescription>
            </div>
            <button
              type="button"
              aria-label="Close publish preview modal"
              onClick={() => setPublishOpen(false)}
              className="flex h-7 w-7 items-center justify-center rounded-[5px] text-[var(--ink-secondary)] hover:bg-[var(--surface-hover)]"
            >
              <X size={15} aria-hidden="true" />
            </button>
          </div>

          <div className="mt-4 rounded-[var(--r-control)] border border-[var(--border-subtle)] border-l-[3px] border-l-[var(--sem-joint-bar)] bg-[var(--bg-surface)] p-3 text-[12.5px] text-[var(--ink-secondary)]">
            <div className="flex items-start gap-2 font-semibold text-[var(--ink-primary)]">
              <WarningCircle size={16} className="mt-0.5 shrink-0 text-[var(--sem-joint-bar)]" aria-hidden="true" />
              <span>Zero Database Writes Guarantee</span>
            </div>
            <p className="mt-1">
              Confirming here closes the Design Preview walkthrough without
              touching live active student or teacher schedules.
            </p>
          </div>

          <div className="mt-5 flex justify-end gap-2">
            <Button
              variant="secondary"
              size="md"
              onClick={() => setPublishOpen(false)}
            >
              Cancel
            </Button>
            <Button
              variant="primary"
              size="md"
              data-testid="confirm-simulated-publish-btn"
              onClick={() => {
                simulatePreviewPublish();
                setPublishOpen(false);
                toast.success(
                  "Simulated Preview Complete · Zero Database Writes",
                );
              }}
            >
              Confirm Preview Publish
            </Button>
          </div>
        </DialogContent>
      </Dialog>
    </div>
  );
}
