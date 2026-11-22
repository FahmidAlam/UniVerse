import {
  ArrowRight,
  ArrowsClockwise,
  CheckCircle,
  LockSimple,
  WarningCircle,
} from "@phosphor-icons/react";
import { Badge } from "@/components/ui/Badge";
import { Button } from "@/components/ui/Button";
import { useSchedulingWorkbenchStore } from "@/features/scheduling/store/schedulingWorkbenchStore";
import type {
  GateStatusInfo,
  WorkbenchMode,
  WorkbenchStageId,
} from "@/features/scheduling/types";

interface PreflightReadinessStageProps {
  mode: WorkbenchMode;
  gateC: GateStatusInfo;
  onJumpToStage: (stage: WorkbenchStageId, row?: number) => void;
}

export function PreflightReadinessStage({
  mode,
  gateC,
  onJumpToStage,
}: PreflightReadinessStageProps) {
  const {
    previewReadinessItems,
    previewArtifactFreshness,
    revalidatePreviewArtifacts,
  } = useSchedulingWorkbenchStore();

  if (mode === "live" && !gateC.unlocked) {
    return (
      <section
        data-testid="live-gate-c-readiness-locked"
        className="ledger-card flex max-w-[760px] flex-col gap-3 p-6"
      >
        <div className="flex flex-wrap items-center justify-between gap-2">
          <span className="font-mono-tabular text-[12px] font-medium text-[var(--accent-brand)]">
            Stage 3 · Gate C Required
          </span>
          <Badge tone="joint" mono>
            <LockSimple size={12} aria-hidden="true" />
            <span>Locked · Gate C</span>
          </Badge>
        </div>
        <h2 className="text-[17px] font-semibold text-[var(--ink-primary)]">
          Server Preflight Validation Awaits Phase 4A
        </h2>
        <p className="text-[13.5px] leading-[1.55] text-[var(--ink-secondary)]">
          {gateC.reason} Track 1 validation diagnostics remain active in{" "}
          <span className="font-semibold text-[var(--ink-primary)]">
            Routine Operations
          </span>
          .
        </p>
      </section>
    );
  }

  const criticalOpen = previewReadinessItems.filter(
    (i) => i.severity === "critical" && !i.isResolved,
  );
  const warningsOpen = previewReadinessItems.filter(
    (i) => i.severity === "warning" && !i.isResolved,
  );
  const isStale = previewArtifactFreshness.validationReportStatus === "stale";
  const isGoForSolve = criticalOpen.length === 0 && !isStale;

  return (
    <div className="space-y-4">
      {isStale && (
        <div
          role="alert"
          data-testid="preflight-stale-artifacts-banner"
          className="flex flex-wrap items-center justify-between gap-3 rounded-[var(--r-card)] border border-[var(--border-subtle)] border-l-[3px] border-l-[var(--sem-joint-bar)] bg-[var(--bg-elevated)] p-4 text-[12.5px] text-[var(--ink-secondary)]"
        >
          <div className="flex items-start gap-2.5">
            <WarningCircle
              size={18}
              className="mt-0.5 shrink-0 text-[var(--sem-joint-bar)]"
              aria-hidden="true"
            />
            <div>
              <div className="font-semibold text-[var(--ink-primary)]">
                Validation report marked stale after distribution/policy edits
              </div>
              <p className="mt-0.5">
                Re-run preflight verification so checks bind to the updated
                revision overlay and R1–R16 configuration.
              </p>
            </div>
          </div>
          <Button
            variant="secondary"
            size="sm"
            onClick={revalidatePreviewArtifacts}
          >
            <ArrowsClockwise size={14} aria-hidden="true" />
            <span>Re-run Preflight Validation</span>
          </Button>
        </div>
      )}

      {/* Overall Go/No-Go Header */}
      <section
        data-testid="preflight-status-card"
        className="ledger-card flex flex-wrap items-center justify-between gap-4 p-5"
      >
        <div className="space-y-1">
          <div className="flex items-center gap-2">
            <Badge tone={isGoForSolve ? "lab" : "conflict"} mono>
              {isGoForSolve ? "READY TO SOLVE" : `${criticalOpen.length} BLOCKER(S)`}
            </Badge>
            <Badge tone={warningsOpen.length > 0 ? "joint" : "neutral"} mono>
              {warningsOpen.length} Advisory
            </Badge>
          </div>
          <h2 className="text-[16px] font-semibold text-[var(--ink-primary)]">
            {isGoForSolve
              ? "All preflight readiness checks satisfied"
              : "Resolve critical distribution blockers before running CP-SAT"}
          </h2>
          <p className="text-[12.5px] text-[var(--ink-secondary)]">
            Verifies accepted revision rows, instructor completeness, R7
            off-days, R10/R11 lab windows, and R14 room pool capacity.
          </p>
        </div>

        <Button
          variant="primary"
          size="md"
          disabled={!isGoForSolve}
          onClick={() => onJumpToStage("generate")}
        >
          <span>Proceed to Revision Solve</span>
          <ArrowRight size={15} aria-hidden="true" />
        </Button>
      </section>

      {/* Checkpoints Ledger */}
      <section className="ledger-card divide-y divide-[var(--border-subtle)] overflow-hidden">
        {previewReadinessItems.map((item) => {
          const isBlocker = item.severity === "critical" && !item.isResolved;
          const isWarning = item.severity === "warning" && !item.isResolved;
          return (
            <div
              key={item.id}
              data-testid={`readiness-item-${item.id}`}
              className="flex flex-wrap items-start justify-between gap-3 px-5 py-3.5"
            >
              <div className="flex min-w-0 flex-1 items-start gap-3">
                {isBlocker ? (
                  <WarningCircle
                    size={18}
                    className="mt-0.5 shrink-0 text-[var(--sem-conflict-bar)]"
                    aria-hidden="true"
                  />
                ) : isWarning ? (
                  <WarningCircle
                    size={18}
                    className="mt-0.5 shrink-0 text-[var(--sem-joint-bar)]"
                    aria-hidden="true"
                  />
                ) : (
                  <CheckCircle
                    size={18}
                    weight="fill"
                    className="mt-0.5 shrink-0 text-[var(--sem-lab-bar)]"
                    aria-hidden="true"
                  />
                )}

                <div className="min-w-0 space-y-1">
                  <div className="flex flex-wrap items-center gap-2">
                    <span className="font-mono-tabular text-[11px] font-semibold text-[var(--ink-muted)] uppercase">
                      {item.category}
                    </span>
                    {isBlocker ? (
                      <Badge tone="conflict" mono>
                        Blocker
                      </Badge>
                    ) : isWarning ? (
                      <Badge tone="joint" mono>
                        Advisory
                      </Badge>
                    ) : (
                      <span className="font-mono-tabular text-[11px] font-medium text-[var(--ink-muted)]">
                        Ready
                      </span>
                    )}
                  </div>
                  <div className="text-[13.5px] font-semibold text-[var(--ink-primary)]">
                    {item.isResolved &&
                    item.id === "chk-teacher-pending" &&
                    item.title.startsWith("Unassigned")
                      ? "Lab Instructor Assigned on Row 19 (CSE-2202)"
                      : item.title}
                  </div>
                  <p className="text-[12.5px] text-[var(--ink-secondary)]">
                    {item.description}
                  </p>
                  <div className="flex flex-wrap gap-1.5 pt-0.5">
                    {item.affectedEntities.map((ent) => (
                      <Badge key={ent} tone="neutral" mono>
                        {ent}
                      </Badge>
                    ))}
                  </div>
                </div>
              </div>

              <Button
                variant="secondary"
                size="sm"
                onClick={() => onJumpToStage(item.targetStage, item.targetRow)}
              >
                <span>
                  {item.targetRow
                    ? `Inspect Row ${item.targetRow}`
                    : "Inspect Stage"}
                </span>
                <ArrowRight size={13} aria-hidden="true" />
              </Button>
            </div>
          );
        })}
      </section>
    </div>
  );
}
