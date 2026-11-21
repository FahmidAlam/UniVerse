import {
  CheckCircle,
  Eye,
  LockSimple,
  UploadSimple,
  WarningCircle,
  X,
} from "@phosphor-icons/react";
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
import { ClockTime } from "@/core/utils/clockTime";
import { ACADEMIC_WEEK_DAYS } from "@/features/admin/services/facultyService";
import {
  PREVIEW_CANDIDATE_DIFF,
  PREVIEW_CANDIDATE_ROWS,
} from "@/features/scheduling/data/schedulingPreviewFixtures";
import { useSchedulingWorkbenchStore } from "@/features/scheduling/store/schedulingWorkbenchStore";
import type { GateStatusInfo, WorkbenchMode } from "@/features/scheduling/types";
import { cn } from "@/lib/utils";

const CANDIDATE_PERIODS = [
  { idx: 1, label: "P1", time: "08:50–09:40" },
  { idx: 2, label: "P2", time: "09:50–10:40" },
  { idx: 3, label: "P3", time: "10:50–11:40" },
  { idx: 4, label: "P4", time: "12:00–12:50" },
  { idx: 5, label: "P5", time: "13:00–13:50" },
  { idx: 6, label: "P6", time: "13:55–14:45" },
] as const;

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

  const [selectedDay, setSelectedDay] = useState<string>("Sunday");
  const [publishOpen, setPublishOpen] = useState(false);

  const dayRows = useMemo(
    () => PREVIEW_CANDIDATE_ROWS.filter((r) => r.day === selectedDay),
    [selectedDay],
  );

  if (mode === "live" && !gateD.unlocked) {
    return (
      <section
        data-testid="live-gate-d-review-locked"
        className="ledger-card flex max-w-[760px] flex-col gap-3 p-6"
      >
        <div className="flex flex-wrap items-center justify-between gap-2">
          <span className="font-mono-tabular text-[12px] font-medium text-[var(--accent-pine)]">
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
          variant="primary"
          size="md"
          disabled={!canSimulatePublish}
          data-testid="open-publish-gate-btn"
          onClick={() => setPublishOpen(true)}
        >
          <UploadSimple size={15} aria-hidden="true" />
          <span>Confirm &amp; Publish Preview</span>
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

      {/* Embedded Candidate Matrix Preview */}
      <section className="ledger-card space-y-3 p-5">
        <div className="flex flex-wrap items-center justify-between gap-2">
          <div>
            <h2 className="text-[15px] font-semibold text-[var(--ink-primary)]">
              Candidate 2D Routine Matrix (Preview Sample)
            </h2>
            <p className="text-[12.5px] text-[var(--ink-secondary)]">
              Inspect scheduled placements across day tabs prior to confirmation.
            </p>
          </div>
          <div
            role="tablist"
            aria-label="Filter candidate day"
            className="flex flex-wrap gap-1"
          >
            {ACADEMIC_WEEK_DAYS.slice(0, 4).map((day) => {
              const active = selectedDay === day;
              return (
                <button
                  key={day}
                  type="button"
                  role="tab"
                  aria-selected={active}
                  onClick={() => setSelectedDay(day)}
                  className={cn(
                    "font-mono-tabular h-[30px] rounded-[6px] border px-2.5 text-[11.5px]",
                    active
                      ? "border-[var(--action-primary)] bg-[var(--action-primary)] font-semibold text-[var(--action-primary-ink)]"
                      : "border-[var(--border-subtle)] bg-[var(--bg-surface)] text-[var(--ink-secondary)]",
                  )}
                >
                  {day.slice(0, 3)}
                </button>
              );
            })}
          </div>
        </div>

        <div className="overflow-x-auto rounded-[var(--r-control)] border border-[var(--border-subtle)]">
          <table className="w-full border-collapse text-left">
            <thead className="border-b border-[var(--border-subtle)] bg-[var(--bg-canvas)]">
              <tr>
                <th className="px-3 py-2 text-[11px] font-semibold text-[var(--ink-muted)] uppercase">
                  Cohort
                </th>
                {CANDIDATE_PERIODS.map((p) => (
                  <th
                    key={p.idx}
                    className={cn(
                      "min-w-[132px] border-l border-[var(--border-subtle)] px-2.5 py-2 text-[11px]",
                      p.idx === 5 &&
                        "border-l-[3px] border-l-[var(--border-strong)]",
                    )}
                  >
                    <div className="font-mono-tabular font-semibold text-[var(--ink-primary)]">
                      {p.label}
                    </div>
                    <div className="font-mono-tabular text-[10px] font-normal text-[var(--ink-muted)]">
                      {p.time}
                    </div>
                  </th>
                ))}
              </tr>
            </thead>
            <tbody className="divide-y divide-[var(--border-subtle)] bg-[var(--bg-elevated)]">
              {Array.from(
                new Set(dayRows.map((r) => `${r.batch}-${r.section}`)),
              ).map((cohort) => (
                <tr key={cohort}>
                  <th
                    scope="row"
                    className="font-mono-tabular px-3 py-2.5 text-[12px] font-semibold text-[var(--ink-primary)] whitespace-nowrap"
                  >
                    Batch {cohort}
                  </th>
                  {CANDIDATE_PERIODS.map((p) => {
                    const hit = dayRows.find(
                      (r) =>
                        `${r.batch}-${r.section}` === cohort &&
                        r.period === p.idx,
                    );
                    if (!hit) {
                      return (
                        <td
                          key={p.idx}
                          className={cn(
                            "border-l border-[var(--border-subtle)] p-2",
                            p.idx === 5 &&
                              "border-l-[3px] border-l-[var(--border-strong)]",
                          )}
                        />
                      );
                    }
                    const slotCls = hit.section.includes("+")
                      ? "slot-joint"
                      : hit.is_lab
                        ? "slot-lab"
                        : "slot-theory";
                    return (
                      <td
                        key={p.idx}
                        className={cn(
                          "border-l border-[var(--border-subtle)] p-1.5",
                          p.idx === 5 &&
                            "border-l-[3px] border-l-[var(--border-strong)]",
                        )}
                      >
                        <div className={cn("rounded-[5px] px-2 py-1.5", slotCls)}>
                          <div className="font-mono-tabular text-[11.5px] font-semibold">
                            {hit.subject_code}
                          </div>
                          <div className="font-mono-tabular flex justify-between text-[10.5px]">
                            <span>
                              {(hit.teachers ?? [hit.teacher_code ?? "TBA"]).join(
                                " / ",
                              )}
                            </span>
                            <span>{hit.room}</span>
                          </div>
                          <div className="font-mono-tabular text-[10px] opacity-80">
                            {ClockTime.toHm(hit.time_start)}
                          </div>
                        </div>
                      </td>
                    );
                  })}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
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

          <div className="mt-4 rounded-[var(--r-control)] border border-[var(--sem-joint-border)] bg-[var(--sem-joint-bg)] p-3 text-[12.5px] text-[var(--sem-joint-ink)]">
            <div className="flex items-start gap-2 font-semibold">
              <WarningCircle size={16} className="mt-0.5 shrink-0" aria-hidden="true" />
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
