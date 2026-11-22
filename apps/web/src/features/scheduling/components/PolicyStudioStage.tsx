import {
  ArrowCounterClockwise,
  CheckCircle,
  LockSimple,
  ShieldCheck,
  SlidersHorizontal,
} from "@phosphor-icons/react";
import { Badge } from "@/components/ui/Badge";
import { Button } from "@/components/ui/Button";
import { useSchedulingWorkbenchStore } from "@/features/scheduling/store/schedulingWorkbenchStore";
import type {
  GateStatusInfo,
  PolicyConfigItem,
  PolicyPillarId,
  WorkbenchMode,
} from "@/features/scheduling/types";
import { cn } from "@/lib/utils";

const PILLARS: readonly {
  id: PolicyPillarId;
  title: string;
  subtitle: string;
}[] = [
  {
    id: "calendar",
    title: "1. Term Grid & Section Calendar (R1–R3, R15)",
    subtitle: "6- vs 7-slot daily grid, 7-day staggered weekends, and gap bounds.",
  },
  {
    id: "faculty",
    title: "2. Faculty Workload, Categories & Compactness (R4–R9)",
    subtitle: "Permanent off-day bounds, adjunct scaling, and blackout windows.",
  },
  {
    id: "facilities",
    title: "3. Shared Labs & Dynamic Classroom Pools (R10, R11, R14)",
    subtitle: "EEE-shared ECL windows, Physics exclusivity, and capacity matching.",
  },
  {
    id: "distribution",
    title: "4. Credit-Based Course Distribution Rules (R12, R13)",
    subtitle: "Sessional break boundaries and 3-credit non-adjacent day spacing.",
  },
  {
    id: "governance",
    title: "5. UI Governance & Impact Warnings (R16)",
    subtitle: "Revision hash snapshot integrity and impact guardrails.",
  },
];

function hasActiveOverride(item: PolicyConfigItem): boolean {
  const ov = item.overrideValue.trim();
  if (!ov) return false;
  if (ov.toLowerCase().startsWith("none")) return false;
  return ov !== item.defaultValue.trim();
}

export function PolicyStudioStage({
  mode,
  gateC,
}: {
  mode: WorkbenchMode;
  gateC: GateStatusInfo;
}) {
  const {
    previewPolicyItems,
    applyPreviewPolicyOverride,
    resetPreviewPolicyOverride,
  } = useSchedulingWorkbenchStore();

  if (mode === "live" && !gateC.unlocked) {
    return (
      <section
        data-testid="live-gate-c-policy-locked"
        className="ledger-card flex max-w-[760px] flex-col gap-3 p-6"
      >
        <div className="flex flex-wrap items-center justify-between gap-2">
          <span className="font-mono-tabular text-[12px] font-medium text-[var(--accent-brand)]">
            Stage 2 · Gate C Required
          </span>
          <Badge tone="joint" mono>
            <LockSimple size={12} aria-hidden="true" />
            <span>Locked · Gate C</span>
          </Badge>
        </div>
        <h2 className="text-[17px] font-semibold text-[var(--ink-primary)]">
          Revision-Bound Policy Studio Locked in Live Mode
        </h2>
        <p className="text-[13.5px] leading-[1.55] text-[var(--ink-secondary)]">
          {gateC.reason} Track 1 baseline settings remain active on{" "}
          <span className="font-semibold text-[var(--ink-primary)]">
            Timetable Settings
          </span>
          . Switch to Design Preview above to inspect the R1–R16 3-step policy
          override studio.
        </p>
      </section>
    );
  }

  const r15Item = previewPolicyItems.find((p) => p.ruleId === "R15");
  const r15Slots =
    Number(r15Item?.typedPayload.slot_count ?? 7) === 6 ? 6 : 7;
  const r15Online = Boolean(r15Item?.typedPayload.allow_online_slot);
  const activeOverrideCount = previewPolicyItems.filter(hasActiveOverride).length;

  return (
    <div className="space-y-4">
      <div className="ledger-card flex flex-wrap items-center justify-between gap-3 p-4">
        <div className="flex items-start gap-2.5">
          <ShieldCheck
            size={18}
            className="mt-0.5 shrink-0 text-[var(--accent-brand)]"
            aria-hidden="true"
          />
          <div>
            <div className="text-[14px] font-semibold text-[var(--ink-primary)]">
              Committee Policy Studio (R1–R16 · 5 Pillars)
            </div>
            <p className="text-[12.5px] text-[var(--ink-secondary)]">
              Baseline rules remain quiet neutral until overridden. Any change
              marks the preflight report stale and requires revalidation.
            </p>
          </div>
        </div>
        <div className="flex items-center gap-2">
          <Badge tone={activeOverrideCount > 0 ? "joint" : "neutral"} mono>
            {activeOverrideCount} Active Overrides
          </Badge>
          {activeOverrideCount > 0 && (
            <Button
              variant="secondary"
              size="sm"
              data-testid="reset-all-policies-btn"
              onClick={() => resetPreviewPolicyOverride()}
            >
              <ArrowCounterClockwise size={13} aria-hidden="true" />
              <span>Reset All to Baseline</span>
            </Button>
          )}
        </div>
      </div>

      {/* Prominent Interactive R15 6/7-Slot Grid Editor */}
      {r15Item && (
        <section
          data-testid="r15-slot-grid-control"
          className="ledger-card space-y-3 p-5"
        >
          <div className="flex flex-wrap items-center justify-between gap-3">
            <div>
              <div className="flex items-center gap-2">
                <Badge tone="pine" mono>
                  R15
                </Badge>
                <h2 className="text-[15px] font-semibold text-[var(--ink-primary)]">
                  Daily Period Dimension &amp; Visual Break Strip
                </h2>
              </div>
              <p className="mt-1 text-[12.5px] text-[var(--ink-secondary)]">
                Switch between 6-slot and 7-slot regular daily on-campus grids.
              </p>
            </div>

            <div className="flex flex-wrap items-center gap-2">
              <div
                role="group"
                aria-label="R15 daily slot count"
                className="inline-flex h-[34px] rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] p-0.5"
              >
                {[6, 7].map((slots) => {
                  const active = r15Slots === slots;
                  return (
                    <button
                      key={slots}
                      type="button"
                      data-testid={`r15-select-${slots}`}
                      aria-pressed={active}
                      onClick={() =>
                        applyPreviewPolicyOverride({
                          ruleId: "R15",
                          overrideValue:
                            slots === 6 ? "6 daily slots (compact day)" : "None",
                          effectiveValue: `${slots} slots (Period 4 Midday Break)`,
                          typedPayload: {
                            ...r15Item.typedPayload,
                            slot_count: slots,
                          },
                        })
                      }
                      className={cn(
                        "font-mono-tabular h-[28px] rounded-[5px] border px-3 text-[12px] transition-colors",
                        active
                          ? "border-[var(--border-strong)] bg-[var(--bg-raised)] font-semibold text-[var(--ink-primary)]"
                          : "border-transparent text-[var(--ink-secondary)] hover:text-[var(--ink-primary)]",
                      )}
                    >
                      {slots}-Slot Grid
                    </button>
                  );
                })}
              </div>

              {/* Checkbox Off = Gray discipline */}
              <label
                className={cn(
                  "inline-flex h-[34px] cursor-pointer items-center gap-2 rounded-[var(--r-control)] border px-3 text-[12px] font-medium transition-colors",
                  r15Online
                    ? "border-[var(--sem-joint-border)] bg-[var(--sem-joint-bg)] text-[var(--sem-joint-ink)]"
                    : "border-[var(--border-subtle)] bg-[var(--bg-surface)] text-[var(--ink-muted)]",
                )}
              >
                <input
                  type="checkbox"
                  checked={r15Online}
                  onChange={(e) =>
                    applyPreviewPolicyOverride({
                      ruleId: "R15",
                      overrideValue: e.target.checked
                        ? `${r15Slots} daily + Online evening slot`
                        : r15Slots === 6
                          ? "6 daily slots (compact day)"
                          : "None",
                      effectiveValue: `${r15Slots} on-campus slots${e.target.checked ? " + Online P8" : ""}`,
                      typedPayload: {
                        ...r15Item.typedPayload,
                        allow_online_slot: e.target.checked,
                      },
                    })
                  }
                  className="h-3.5 w-3.5 accent-[var(--accent-brand)]"
                />
                <span>Enable Online Slot</span>
              </label>
            </div>
          </div>

          <div
            aria-label="R15 period strip preview"
            className="grid grid-cols-3 gap-1.5 sm:grid-cols-8"
          >
            {[1, 2, 3, 4, 5, 6, 7].map((idx) => {
              const hidden = r15Slots === 6 && idx === 7;
              const isBreak = idx === 4;
              return (
                <div
                  key={idx}
                  className={cn(
                    "font-mono-tabular rounded-[6px] border px-2.5 py-2 text-center text-[11.5px]",
                    hidden
                      ? "border-dashed border-[var(--border-subtle)] bg-[var(--bg-surface)] text-[var(--ink-muted)] opacity-55"
                      : isBreak
                        ? "border-[var(--sem-joint-border)] bg-[var(--sem-joint-bg)] font-semibold text-[var(--sem-joint-ink)]"
                        : "border-[var(--border-subtle)] bg-[var(--bg-surface)] text-[var(--ink-primary)]",
                  )}
                >
                  <div>P{idx}</div>
                  <div className="text-[10px] text-[var(--ink-muted)]">
                    {hidden ? "Omitted" : isBreak ? "Break/Jummah" : "On-Campus"}
                  </div>
                </div>
              );
            })}
            <div
              className={cn(
                "font-mono-tabular rounded-[6px] border px-2.5 py-2 text-center text-[11.5px]",
                r15Online
                  ? "border-[var(--sem-joint-border)] bg-[var(--sem-joint-bg)] font-semibold text-[var(--sem-joint-ink)]"
                  : "border-[var(--border-subtle)] bg-[var(--bg-surface)] text-[var(--ink-muted)]",
              )}
            >
              <div>P8</div>
              <div className="text-[10px]">
                {r15Online ? "Online Slot" : "Inactive"}
              </div>
            </div>
          </div>
        </section>
      )}

      {/* 5 Committee Pillars */}
      <div className="space-y-4">
        {PILLARS.map((pillar) => {
          const items = previewPolicyItems.filter((i) => i.pillar === pillar.id);
          return (
            <section
              key={pillar.id}
              aria-label={pillar.title}
              className="ledger-card overflow-hidden"
            >
              <div className="border-b border-[var(--border-subtle)] bg-[var(--bg-canvas)]/55 px-5 py-3">
                <h3 className="text-[14px] font-semibold text-[var(--ink-primary)]">
                  {pillar.title}
                </h3>
                <p className="text-[12px] text-[var(--ink-secondary)]">
                  {pillar.subtitle}
                </p>
              </div>
              <div className="divide-y divide-[var(--border-subtle)]">
                {items.map((item) => {
                  const overridden = hasActiveOverride(item);
                  return (
                    <div
                      key={item.ruleId}
                      data-testid={`policy-row-${item.ruleId.replace(/[^A-Za-z0-9]/g, "-")}`}
                      className={cn(
                        "flex flex-col gap-2 px-5 py-3.5 transition-colors",
                        overridden ? "bg-[var(--sem-joint-bg)]/35" : "bg-[var(--bg-elevated)]",
                      )}
                    >
                      <div className="flex flex-wrap items-center justify-between gap-2">
                        <div className="flex flex-wrap items-center gap-2">
                          <Badge tone={overridden ? "joint" : "neutral"} mono>
                            {item.ruleId}
                          </Badge>
                          <span className="text-[13.5px] font-semibold text-[var(--ink-primary)]">
                            {item.label}
                          </span>
                        </div>
                        <div className="flex items-center gap-2">
                          {overridden ? (
                            <Badge tone="joint" mono>
                              <SlidersHorizontal size={11} aria-hidden="true" />
                              <span>Override Active</span>
                            </Badge>
                          ) : (
                            <span className="font-mono-tabular inline-flex items-center gap-1 text-[11px] font-medium text-[var(--ink-muted)]">
                              <CheckCircle size={12} aria-hidden="true" />
                              <span>Baseline</span>
                            </span>
                          )}
                          {overridden && (
                            <button
                              type="button"
                              onClick={() => resetPreviewPolicyOverride(item.ruleId)}
                              className="inline-flex items-center gap-1 rounded px-2 py-0.5 text-[11px] font-medium text-[var(--ink-secondary)] hover:bg-[var(--surface-hover)] hover:text-[var(--ink-primary)]"
                            >
                              <ArrowCounterClockwise size={11} aria-hidden="true" />
                              <span>Reset</span>
                            </button>
                          )}
                        </div>
                      </div>

                      <p className="text-[12.5px] text-[var(--ink-secondary)]">
                        {item.description}
                      </p>

                      {/* 3-Step Policy Resolution Chain: Default -> Override -> Effective */}
                      <div className="grid grid-cols-1 gap-2 rounded-[var(--r-control)] border border-[var(--border-subtle)] bg-[var(--bg-surface)] px-3 py-2 text-[12px] sm:grid-cols-3">
                        <div>
                          <div className="text-[10.5px] text-[var(--ink-muted)] uppercase">
                            1. Committee Default
                          </div>
                          <div className="mt-0.5 text-[var(--ink-secondary)]">
                            {item.defaultValue}
                          </div>
                        </div>
                        <div>
                          <div className="text-[10.5px] text-[var(--ink-muted)] uppercase">
                            2. Revision Override
                          </div>
                          <div
                            className={cn(
                              "mt-0.5",
                              overridden
                                ? "font-semibold text-[var(--sem-joint-ink)]"
                                : "text-[var(--ink-muted)]",
                            )}
                          >
                            {item.overrideValue}
                          </div>
                        </div>
                        <div>
                          <div className="text-[10.5px] text-[var(--ink-muted)] uppercase">
                            3. Effective Policy
                          </div>
                          <div className="mt-0.5 font-medium text-[var(--ink-primary)]">
                            {item.effectiveValue}
                          </div>
                        </div>
                      </div>
                    </div>
                  );
                })}
              </div>
            </section>
          );
        })}
      </div>
    </div>
  );
}
