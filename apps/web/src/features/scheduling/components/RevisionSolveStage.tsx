import {
  ArrowRight,
  CheckCircle,
  CircleNotch,
  Cpu,
  LockSimple,
  Play,
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
import { cn } from "@/lib/utils";

const SOLVER_TIMELINE_NODES = [
  { step: "1", label: "Queued" },
  { step: "2", label: "Ingesting Revision" },
  { step: "3", label: "CP-SAT Solving" },
  { step: "4", label: "Rendering Matrix" },
] as const;

interface RevisionSolveStageProps {
  mode: WorkbenchMode;
  gateD: GateStatusInfo;
  onJumpToStage: (stage: WorkbenchStageId, row?: number) => void;
}

export function RevisionSolveStage({
  mode,
  gateD,
  onJumpToStage,
}: RevisionSolveStageProps) {
  const {
    previewRevision,
    previewSolverConfig,
    previewSolverResult,
    previewSolverStepIndex,
    updatePreviewSolverConfig,
    startPreviewSimulation,
    setPreviewSolverStep,
    completePreviewSimulation,
  } = useSchedulingWorkbenchStore();

  if (mode === "live" && !gateD.unlocked) {
    return (
      <section
        data-testid="live-gate-d-solve-locked"
        className="ledger-card flex max-w-[760px] flex-col gap-3 p-6"
      >
        <div className="flex flex-wrap items-center justify-between gap-2">
          <span className="font-mono-tabular text-[12px] font-medium text-[var(--accent-brand)]">
            Stage 4 · Gate D Required
          </span>
          <Badge tone="joint" mono>
            <LockSimple size={12} aria-hidden="true" />
            <span>Locked · Gate D</span>
          </Badge>
        </div>
        <h2 className="text-[17px] font-semibold text-[var(--ink-primary)]">
          Revision-Bound Solver Pipeline Locked in Live Mode
        </h2>
        <p className="text-[13.5px] leading-[1.55] text-[var(--ink-secondary)]">
          {gateD.reason} Track 1 manual workbook CP-SAT generation remains
          operational in{" "}
          <span className="font-semibold text-[var(--ink-primary)]">
            Routine Operations
          </span>
          .
        </p>
      </section>
    );
  }

  const isRunning = previewSolverStepIndex >= 0 && previewSolverStepIndex < 4;

  const triggerSimulatedRun = (outcome: "optimal" | "infeasible") => {
    startPreviewSimulation();
    window.setTimeout(() => setPreviewSolverStep(1), 80);
    window.setTimeout(() => setPreviewSolverStep(2), 160);
    window.setTimeout(() => setPreviewSolverStep(3), 240);
    window.setTimeout(() => completePreviewSimulation(outcome), 320);
  };

  return (
    <div className="space-y-4">
      {/* Bound Source Contract Header */}
      <section className="ledger-card flex flex-wrap items-center justify-between gap-3 p-4">
        <div className="flex items-start gap-3">
          <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-[var(--r-control)] border border-[var(--border-subtle)] bg-[var(--bg-surface)] text-[var(--accent-brand)]">
            <Cpu size={18} aria-hidden="true" />
          </div>
          <div>
            <div className="text-[14px] font-semibold text-[var(--ink-primary)]">
              OR-Tools CP-SAT Binding Summary
            </div>
            <div className="font-mono-tabular mt-0.5 text-[12px] text-[var(--ink-secondary)]">
              Rev #{previewRevision.revisionNumber} (v{previewRevision.revisionVersion}) ·{" "}
              {previewRevision.totalRows} offerings · hash{" "}
              {previewRevision.sourceHash.slice(0, 10)}
            </div>
          </div>
        </div>
        <Badge tone="neutral" mono>
          {previewSolverConfig.engineProfile}
        </Badge>
      </section>

      {/* Tiered Objective Weights (Mirrors engine/solver.py soft objectives) */}
      <section className="ledger-card space-y-4 p-5">
        <div className="flex flex-wrap items-center justify-between gap-2">
          <div>
            <h2 className="text-[15px] font-semibold text-[var(--ink-primary)]">
              Tiered Soft-Objective Weights &amp; Budget
            </h2>
            <p className="text-[12.5px] text-[var(--ink-secondary)]">
              Hard constraints (R1–R7, R10–R13) are non-relaxable. Tune tiered
              preference penalties below.
            </p>
          </div>
          <span className="font-mono-tabular text-[12px] text-[var(--ink-muted)]">
            Budget: {previewSolverConfig.timeLimitSeconds}s
          </span>
        </div>

        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
          {(
            [
              {
                key: "cohortCompactnessWeight",
                label: "Tier 1 · Cohort Compactness (R3 / R9)",
              },
              {
                key: "facultyPreferenceWeight",
                label: "Tier 2 · Faculty Preferred Windows (R8)",
              },
              {
                key: "theorySpreadWeight",
                label: "Tier 3 · Theory Non-Adjacent Spread (R13)",
              },
              {
                key: "latePeriodAvoidanceWeight",
                label: "Tier 4 · Late Period Avoidance (R15)",
              },
            ] as const
          ).map((slider) => {
            const val = previewSolverConfig[slider.key];
            return (
              <label
                key={slider.key}
                className="flex flex-col gap-1.5 rounded-[var(--r-control)] border border-[var(--border-subtle)] bg-[var(--bg-surface)] px-3.5 py-2.5 text-[12.5px]"
              >
                <div className="flex items-center justify-between">
                  <span className="font-medium text-[var(--ink-primary)]">
                    {slider.label}
                  </span>
                  <span className="font-mono-tabular font-semibold text-[var(--accent-brand)]">
                    {val.toFixed(2)}
                  </span>
                </div>
                <input
                  type="range"
                  min={0}
                  max={1}
                  step={0.05}
                  value={val}
                  onChange={(e) =>
                    updatePreviewSolverConfig({
                      [slider.key]: Number.parseFloat(e.target.value),
                    })
                  }
                  className="accent-[var(--accent-brand)]"
                />
              </label>
            );
          })}
        </div>

        <div className="flex flex-wrap items-center justify-between gap-2 border-t border-[var(--border-subtle)] pt-3">
          <div className="flex flex-wrap items-center gap-2">
            <Button
              variant="primary"
              size="md"
              disabled={isRunning}
              data-testid="simulate-optimal-solve-btn"
              onClick={() => triggerSimulatedRun("optimal")}
            >
              {isRunning ? (
                <CircleNotch size={15} className="animate-spin" aria-hidden="true" />
              ) : (
                <Play size={15} aria-hidden="true" />
              )}
              <span>Simulate Optimal Solve</span>
            </Button>
            <Button
              variant="secondary"
              size="md"
              disabled={isRunning}
              data-testid="simulate-infeasible-solve-btn"
              onClick={() => triggerSimulatedRun("infeasible")}
            >
              <span>Simulate Infeasible Conflict</span>
            </Button>
          </div>

          {previewSolverResult?.outcome === "optimal" && (
            <Button
              variant="secondary"
              size="sm"
              onClick={() => onJumpToStage("review")}
            >
              <span>Review Candidate Schedule</span>
              <ArrowRight size={14} aria-hidden="true" />
            </Button>
          )}
        </div>
      </section>

      {/* Honest 4-Node Solver Timeline (No fabricated progress bar) */}
      <section className="ledger-card space-y-4 p-5">
        <div className="flex flex-wrap items-center justify-between gap-2">
          <h3 className="text-[14px] font-semibold text-[var(--ink-primary)]">
            4-Node CP-SAT Execution Timeline
          </h3>
          {previewSolverResult && (
            <Badge
              tone={
                previewSolverResult.outcome === "optimal" ? "lab" : "conflict"
              }
              mono
            >
              {previewSolverResult.outcomeLabel}
            </Badge>
          )}
        </div>

        <ol className="grid grid-cols-2 gap-2.5 sm:grid-cols-4">
          {SOLVER_TIMELINE_NODES.map((node, idx) => {
            const completed = previewSolverStepIndex > idx;
            const current = isRunning && previewSolverStepIndex === idx;
            return (
              <li
                key={node.step}
                className={cn(
                  "flex items-center gap-2 rounded-[var(--r-control)] border px-3 py-2 text-[12px]",
                  completed
                    ? "border-[var(--sem-lab-border)] bg-[var(--sem-lab-bg)] text-[var(--sem-lab-ink)]"
                    : current
                      ? "border-[var(--accent-brand)] bg-[var(--accent-brand-soft)] font-semibold text-[var(--accent-brand)]"
                      : "border-[var(--border-subtle)] bg-[var(--bg-surface)] text-[var(--ink-muted)]",
                )}
              >
                {completed ? (
                  <CheckCircle size={15} weight="fill" aria-hidden="true" />
                ) : current ? (
                  <CircleNotch size={15} className="animate-spin" aria-hidden="true" />
                ) : (
                  <span className="font-mono-tabular flex h-4 w-4 items-center justify-center rounded-full border border-current text-[10px]">
                    {node.step}
                  </span>
                )}
                <span>{node.label}</span>
              </li>
            );
          })}
        </ol>

        {previewSolverResult && (
          <div className="grid grid-cols-2 gap-2.5 sm:grid-cols-4">
            {Object.entries(previewSolverResult.diagnostics).map(([k, v]) => (
              <div
                key={k}
                className="rounded-[var(--r-control)] border border-[var(--border-subtle)] bg-[var(--bg-surface)] px-3 py-2"
              >
                <div className="text-[11px] text-[var(--ink-muted)]">{k}</div>
                <div className="font-mono-tabular mt-0.5 text-[13.5px] font-semibold text-[var(--ink-primary)]">
                  {v}
                </div>
              </div>
            ))}
          </div>
        )}

        {previewSolverResult &&
          previewSolverResult.conflictDiagnostics.length > 0 && (
            <div
              data-testid="solver-conflict-diagnostics"
              className="space-y-2 border-t border-[var(--border-subtle)] pt-3"
            >
              {previewSolverResult.conflictDiagnostics.map((diag) => (
                <div
                  key={diag.constraintId}
                  className="flex flex-wrap items-start justify-between gap-3 rounded-[var(--r-control)] border border-[var(--sem-conflict-border)] bg-[var(--sem-conflict-bg)] p-3.5 text-[12.5px] text-[var(--sem-conflict-ink)]"
                >
                  <div className="space-y-1">
                    <div className="flex items-center gap-2 font-semibold">
                      <WarningCircle size={15} aria-hidden="true" />
                      <span>
                        {diag.constraintId}: {diag.title}
                      </span>
                    </div>
                    <p>{diag.humanExplanation}</p>
                    <p className="text-[11.5px]">
                      Suggested action: {diag.suggestedAction}
                    </p>
                  </div>
                  <Button
                    variant="secondary"
                    size="sm"
                    onClick={() => onJumpToStage(diag.targetStage, diag.targetRow)}
                  >
                    <span>Fix Source</span>
                    <ArrowRight size={13} aria-hidden="true" />
                  </Button>
                </div>
              ))}
            </div>
          )}
      </section>
    </div>
  );
}
