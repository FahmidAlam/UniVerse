import {
  CheckCircle,
  Eye,
  LockSimple,
  UploadSimple,
  WarningCircle,
  X,
} from "@phosphor-icons/react";
import { useState } from "react";
import { toast } from "sonner";
import { Badge } from "@/components/ui/Badge";
import { Button } from "@/components/ui/Button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogTitle,
} from "@/components/ui/Dialog";
import { AcademicTimetableMatrix } from "@/features/routine/components/AcademicTimetableMatrix";
import {
  PREVIEW_CANDIDATE_DIFF,
  PREVIEW_CANDIDATE_ROWS,
} from "@/features/scheduling/data/schedulingPreviewFixtures";
import { useSchedulingWorkbenchStore } from "@/features/scheduling/store/schedulingWorkbenchStore";
import type { GateStatusInfo, WorkbenchMode } from "@/features/scheduling/types";

export function ReviewDiffPublishStage({
  mode,
  gateD,
}: {
  mode: WorkbenchMode;
  gateD: GateStatusInfo;
}) {
  const {
    previewRevision,
    previewArtifactFreshness,
    previewSolverResult,
    previewSimulatedPublishedAt,
    simulatePreviewPublish,
  } = useSchedulingWorkbenchStore();

  const [publishOpen, setPublishOpen] = useState(false);

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
