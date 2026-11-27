import {
  CheckCircle,
  Eye,
  GitBranch,
  LockSimple,
  ShieldCheck,
  Table,
} from "@phosphor-icons/react";
import { Badge } from "@/components/ui/Badge";
import type {
  ArtifactFreshnessSummary,
  RevisionContext,
  SchedulingGateState,
  WorkbenchMode,
  WorkbenchStageId,
} from "@/features/scheduling/types";
import { cn } from "@/lib/utils";

export const WORKBENCH_STAGES: readonly {
  id: WorkbenchStageId;
  step: string;
  label: string;
  shortLabel: string;
  requiredGate?: "gateA" | "gateC" | "gateD";
}[] = [
  {
    id: "distribution",
    step: "1",
    label: "Distribution Ledger",
    shortLabel: "Distribution",
    requiredGate: "gateA",
  },
  {
    id: "policy",
    step: "2",
    label: "Policy Studio",
    shortLabel: "Policy",
    requiredGate: "gateC",
  },
  {
    id: "readiness",
    step: "3",
    label: "Preflight & Readiness",
    shortLabel: "Readiness",
    requiredGate: "gateC",
  },
  {
    id: "generate",
    step: "4",
    label: "Revision Solve",
    shortLabel: "Solve",
    requiredGate: "gateD",
  },
  {
    id: "review",
    step: "5",
    label: "Review, Diff & Publish",
    shortLabel: "Review",
    requiredGate: "gateD",
  },
];

interface SchedulingWorkbenchHeaderProps {
  mode: WorkbenchMode;
  onModeChange: (mode: WorkbenchMode) => void;
  activeStage: WorkbenchStageId;
  onSelectStage: (stage: WorkbenchStageId) => void;
  gates: SchedulingGateState;
  revision: RevisionContext | null;
  freshness: ArtifactFreshnessSummary;
  criticalReadinessCount: number;
}

export function SchedulingWorkbenchHeader({
  mode,
  onModeChange,
  activeStage,
  onSelectStage,
  gates,
  revision,
  freshness,
  criticalReadinessCount,
}: SchedulingWorkbenchHeaderProps) {
  const isPreview = mode === "preview";
  const allLiveGatesLocked =
    !gates.gateA.unlocked &&
    !gates.gateB.unlocked &&
    !gates.gateC.unlocked &&
    !gates.gateD.unlocked;
  const liveGateBadgeLabel = allLiveGatesLocked
    ? "Live · Fail-Closed"
    : gates.gateD.unlocked
      ? "Live · Gates A–D"
      : gates.gateC.unlocked
        ? "Live · Gates A–C"
        : gates.gateB.unlocked
          ? "Live · Gates A/B"
          : "Live · Gate A";

  return (
    <div className="space-y-4">
      {/* Mode Switch + Fail-Closed / Preview Status Banner */}
      <header className="flex flex-wrap items-start justify-between gap-4 border-b border-[var(--border-subtle)] pb-4">
        <div className="space-y-1.5">
          <div className="flex flex-wrap items-center gap-2">
            <h1 className="font-serif-editorial text-[24px] font-semibold tracking-[-0.02em] text-[var(--ink-primary)]">
              Committee Scheduling Workbench
            </h1>
            {!isPreview && (
              <Badge tone="joint" mono>
                <LockSimple size={12} aria-hidden="true" />
                <span>{liveGateBadgeLabel}</span>
              </Badge>
            )}
          </div>
          <p className="max-w-[70ch] text-[13.5px] leading-[1.55] text-[var(--ink-secondary)]">
            Track 2 institutional workbench binding immutable Course Distribution
            revisions, committee R1–R16 scheduling policy rules, and audited
            overlay governance.
          </p>
        </div>

        {/* Explicit Mode Switcher: Live Backend vs Design Preview */}
        <div
          role="group"
          aria-label="Workbench data mode"
          className="inline-flex h-[38px] items-center gap-0.5 rounded-[var(--r-control)] border border-[var(--border-subtle)] bg-[var(--bg-surface)] p-0.5"
        >
          <button
            type="button"
            data-testid="mode-live-btn"
            aria-pressed={!isPreview}
            onClick={() => onModeChange("live")}
            className={cn(
              "inline-flex h-[32px] items-center gap-1.5 rounded-[5px] border px-3 text-[12.5px] whitespace-nowrap transition-colors",
              !isPreview
                ? "border-[var(--border-strong)] bg-[var(--bg-raised)] font-semibold text-[var(--ink-primary)]"
                : "border-transparent font-medium text-[var(--ink-secondary)] hover:text-[var(--ink-primary)]",
            )}
          >
            <ShieldCheck
              size={14}
              className={!isPreview ? "text-[var(--accent-brand)]" : undefined}
              aria-hidden="true"
            />
            <span>Live Backend</span>
          </button>
          <button
            type="button"
            data-testid="mode-preview-btn"
            aria-pressed={isPreview}
            onClick={() => onModeChange("preview")}
            className={cn(
              "inline-flex h-[32px] items-center gap-1.5 rounded-[5px] border px-3 text-[12.5px] whitespace-nowrap transition-colors",
              isPreview
                ? "border-[var(--border-strong)] bg-[var(--bg-raised)] font-semibold text-[var(--ink-primary)]"
                : "border-transparent font-medium text-[var(--ink-secondary)] hover:text-[var(--ink-primary)]",
            )}
          >
            <Eye
              size={14}
              className={isPreview ? "text-[var(--sem-joint-bar)]" : undefined}
              aria-hidden="true"
            />
            <span>Design Preview</span>
          </button>
        </div>
      </header>

      {/* Watermarked Design Preview Banner (Zero Database Writes) */}
      {isPreview && (
        <div
          role="status"
          data-testid="design-preview-watermark"
          className="flex flex-wrap items-center justify-between gap-3 rounded-[var(--r-card)] border border-[var(--border-subtle)] border-l-[3px] border-l-[var(--sem-joint-bar)] bg-[var(--bg-elevated)] px-4 py-2.5 text-[12.5px] text-[var(--ink-secondary)]"
        >
          <div className="flex items-center gap-2 font-mono-tabular font-semibold text-[var(--ink-primary)]">
            <Eye size={16} className="shrink-0 text-[var(--sem-joint-bar)]" aria-hidden="true" />
            <span>
              SIMULATED PREVIEW · 23 CSE sample offerings · ZERO DATABASE WRITES
            </span>
          </div>
          <span className="text-[12px]">
            Inspect all 5 committee stages locally; live database persistence and
            publication remain disabled.
          </span>
        </div>
      )}

      {/* Compact Gate Status + Provenance Ribbon */}
      <div className="ledger-card flex flex-col gap-3 px-4 py-3">
        <div className="flex flex-wrap items-center justify-between gap-2.5">
          <div
            aria-label="Track 2 capability gate status"
            className="flex flex-wrap items-center gap-1.5"
          >
            {[gates.gateA, gates.gateB, gates.gateC, gates.gateD].map((gate) => (
              <Badge
                key={gate.key}
                tone={
                  isPreview
                    ? "neutral"
                    : gate.unlocked
                      ? "lab"
                      : "joint"
                }
                dot={false}
                mono
                data-testid={`gate-pill-${gate.code}`}
                title={gate.reason}
              >
                {isPreview ? (
                  <Eye size={11} className="text-[var(--ink-muted)]" aria-hidden="true" />
                ) : gate.unlocked ? (
                  <CheckCircle size={11} weight="fill" className="text-[var(--sem-lab-bar)]" aria-hidden="true" />
                ) : (
                  <LockSimple size={11} className="text-[var(--sem-joint-bar)]" aria-hidden="true" />
                )}
                <span>
                  Gate {gate.code}:{" "}
                  {isPreview
                    ? "Simulated"
                    : gate.unlocked
                      ? "Verified"
                      : "Locked"}
                </span>
              </Badge>
            ))}
          </div>

          {revision ? (
            <div
              data-testid="workbench-revision-provenance"
              className="font-mono-tabular flex flex-wrap items-center gap-2 text-[11.5px] text-[var(--ink-secondary)]"
            >
              <span className="inline-flex items-center gap-1 font-semibold text-[var(--ink-primary)]">
                <GitBranch size={13} aria-hidden="true" />
                Rev #{revision.revisionNumber} (v{revision.revisionVersion})
              </span>
              <span aria-hidden="true">·</span>
              <span>{revision.semester}</span>
              <span aria-hidden="true">·</span>
              <span>{revision.totalRows} offerings</span>
              <span aria-hidden="true">·</span>
              <span>
                hash {revision.sourceHash ? revision.sourceHash.slice(0, 8) : "unverified"}
              </span>
              <Badge
                tone={
                  freshness.validationReportStatus === "current"
                    ? "lab"
                    : "joint"
                }
                mono
              >
                Artifacts:{" "}
                {freshness.validationReportStatus === "current"
                  ? "Current"
                  : freshness.validationReportStatus === "stale"
                    ? "Stale"
                    : "Pending"}
              </Badge>
            </div>
          ) : (
            <div className="font-mono-tabular flex items-center gap-1.5 text-[11.5px] text-[var(--ink-muted)]">
              <Table size={13} aria-hidden="true" />
              <span>No active distribution revision loaded in Live Mode</span>
            </div>
          )}
        </div>

        {/* 5-Stage URL-Synced Stepper */}
        <nav
          aria-label="Scheduling workbench stages"
          className="grid grid-cols-2 gap-1.5 border-t border-[var(--border-subtle)] pt-3 sm:grid-cols-5"
        >
          {WORKBENCH_STAGES.map((stage) => {
            const active = activeStage === stage.id;
            const gateLocked =
              !isPreview &&
              Boolean(stage.requiredGate && !gates[stage.requiredGate].unlocked);
            const showCriticalBadge =
              stage.id === "readiness" &&
              criticalReadinessCount > 0 &&
              (isPreview || gates.gateC.unlocked);

            return (
              <button
                key={stage.id}
                type="button"
                role="tab"
                aria-selected={active}
                data-testid={`workbench-stage-${stage.id}`}
                onClick={() => onSelectStage(stage.id)}
                className={cn(
                  "flex min-h-[38px] items-center justify-between gap-2 rounded-[var(--r-control)] border px-2.5 py-1.5 text-left text-[12.5px] transition-colors",
                  active
                    ? "border-[var(--border-strong)] bg-[var(--bg-raised)] font-semibold text-[var(--ink-primary)] shadow-[inset_0_-2px_0_var(--accent-brand)]"
                    : "border-[var(--border-subtle)] bg-[var(--bg-surface)] font-medium text-[var(--ink-secondary)] hover:bg-[var(--surface-hover)] hover:text-[var(--ink-primary)]",
                )}
              >
                <span className="flex min-w-0 items-center gap-1.5">
                  <span
                    className={cn(
                      "font-mono-tabular inline-flex h-[18px] w-[18px] shrink-0 items-center justify-center rounded-full border text-[10px]",
                      active
                        ? "border-[var(--accent-brand)] bg-[var(--accent-brand-soft)] text-[var(--accent-brand)]"
                        : "border-[var(--border-control)] text-[var(--ink-muted)]",
                    )}
                  >
                    {stage.step}
                  </span>
                  <span className="truncate lg:hidden">{stage.shortLabel}</span>
                  <span className="hidden truncate lg:inline">
                    {stage.label}
                  </span>
                </span>
                {gateLocked && (
                  <LockSimple
                    size={12}
                    className="shrink-0 text-[var(--sem-joint-bar)]"
                    aria-hidden="true"
                  />
                )}
                {showCriticalBadge && (
                  <span className="font-mono-tabular shrink-0 rounded bg-[var(--sem-conflict-bg)] px-1.5 py-[1px] text-[10px] font-semibold text-[var(--sem-conflict-ink)]">
                    {criticalReadinessCount}
                  </span>
                )}
              </button>
            );
          })}
        </nav>
      </div>
    </div>
  );
}
