import {
  ArrowRight,
  CaretDown,
  CaretRight,
  CheckCircle,
  Clock,
  Question,
  ShieldWarning,
  SlidersHorizontal,
  WarningCircle,
} from "@phosphor-icons/react";
import { useState } from "react";
import { Link } from "react-router-dom";
import { Badge } from "@/components/ui/Badge";
import type {
  ResolvedFacultyOffDay,
  SolverConflictItem,
  SolverOutcomeDiagnostics,
  SolverOutcomeStatus,
} from "@/features/routine/types";
import { cn } from "@/lib/utils";

const ROUTE_CTA_LABELS: Record<string, string> = {
  "/admin/timetable/faculty": "Fix in Faculty",
  "/admin/timetable/rooms": "Fix in Rooms",
  "/admin/timetable/batches": "Fix in Batches",
  "/admin/timetable/courses": "Fix in Courses",
  "/admin/scheduling": "Open Policy Studio",
  "/admin/timetable/settings": "Fix in Settings",
};

function resolveConflictRoute(conflict: SolverConflictItem): {
  to: string;
  label: string;
} {
  if (conflict.suggested_route && ROUTE_CTA_LABELS[conflict.suggested_route]) {
    return {
      to: conflict.suggested_route,
      label: ROUTE_CTA_LABELS[conflict.suggested_route]!,
    };
  }
  switch (conflict.entity_type) {
    case "faculty":
      return { to: "/admin/timetable/faculty", label: "Fix in Faculty" };
    case "room":
      return { to: "/admin/timetable/rooms", label: "Fix in Rooms" };
    case "section":
      return { to: "/admin/timetable/batches", label: "Fix in Batches" };
    case "course":
      return { to: "/admin/timetable/courses", label: "Fix in Courses" };
    case "settings":
      return { to: "/admin/timetable/settings", label: "Fix in Settings" };
    default:
      return { to: "/admin/scheduling", label: "Open Policy Studio" };
  }
}

interface OutcomeBannerMeta {
  title: string;
  description: string;
  toneClass: string;
  badgeTone: "lab" | "theory" | "joint" | "conflict" | "neutral";
  Icon: typeof CheckCircle;
}

function getOutcomeMeta(
  outcome: SolverOutcomeStatus,
  diagnostics: SolverOutcomeDiagnostics,
): OutcomeBannerMeta {
  switch (outcome) {
    case "OPTIMAL":
      return {
        title: "Optimal Schedule Found",
        description:
          "All mandatory R1–R16 academic constraints are satisfied with minimal soft preference penalty.",
        toneClass:
          "border-[var(--sem-lab-border)] bg-[var(--sem-lab-bg)] text-[var(--sem-lab-ink)]",
        badgeTone: "lab",
        Icon: CheckCircle,
      };
    case "FEASIBLE":
      return {
        title: "Feasible Schedule Found",
        description:
          diagnostics.termination_reason === "time_limit_with_incumbent"
            ? "Returned the best feasible incumbent when the solver budget elapsed; independently verified against R1–R16."
            : "All mandatory R1–R16 academic constraints are satisfied.",
        toneClass:
          "border-[var(--sem-theory-border)] bg-[var(--sem-theory-bg)] text-[var(--sem-theory-ink)]",
        badgeTone: "theory",
        Icon: CheckCircle,
      };
    case "INFEASIBLE":
      return {
        title: diagnostics.proven_infeasible
          ? "No Feasible Schedule (Proven Infeasible)"
          : "No Feasible Schedule Found",
        description:
          "Mandatory constraints cannot all be satisfied together. Resolve the flagged items below — hard rules are never silently relaxed.",
        toneClass:
          "border-[var(--sem-conflict-border)] bg-[var(--sem-conflict-bg)] text-[var(--sem-conflict-ink)]",
        badgeTone: "conflict",
        Icon: ShieldWarning,
      };
    case "TIME_LIMIT_EXHAUSTED":
      return {
        title: "Time Limit Exhausted (No Incumbent)",
        description:
          "The solver exhausted its time budget before finding a valid placement. This is not mathematical impossibility — raise the budget or ease tight windows.",
        toneClass:
          "border-[var(--sem-joint-border)] bg-[var(--sem-joint-bg)] text-[var(--sem-joint-ink)]",
        badgeTone: "joint",
        Icon: Clock,
      };
    case "UNKNOWN":
      return {
        title: "Solver Stopped (Unknown Outcome)",
        description:
          "OR-Tools terminated without proving feasibility or infeasibility. Inspect inputs or retry with a clean budget.",
        toneClass:
          "border-[var(--sem-joint-border)] bg-[var(--sem-joint-bg)] text-[var(--sem-joint-ink)]",
        badgeTone: "joint",
        Icon: Question,
      };
    case "INPUT_ERROR":
    default:
      return {
        title: "Pre-Solve Input Validation Failed",
        description:
          "Invalid or incomplete resource/policy declarations prevented solver execution. Correct the flagged items below and run again.",
        toneClass:
          "border-[var(--sem-conflict-border)] bg-[var(--sem-conflict-bg)] text-[var(--sem-conflict-ink)]",
        badgeTone: "conflict",
        Icon: WarningCircle,
      };
  }
}

export function SolverDiagnosticsPanel({
  diagnostics,
  className,
}: {
  diagnostics: SolverOutcomeDiagnostics;
  className?: string;
}) {
  const meta = getOutcomeMeta(diagnostics.outcome, diagnostics);
  const StatusIcon = meta.Icon;
  const conflicts = diagnostics.conflicts ?? [];
  const soft = diagnostics.soft_metrics ?? null;
  const resolvedOffDays: ResolvedFacultyOffDay[] =
    diagnostics.resolved_faculty_off_days ??
    soft?.resolved_faculty_off_days ??
    [];
  const hasHybridResolved = resolvedOffDays.some(
    (r) =>
      r.provenance === "solver_resolved" || r.provenance === "partial_hybrid",
  );
  const [offDaysExpanded, setOffDaysExpanded] = useState(hasHybridResolved);

  const showSoftScorecard =
    soft !== null &&
    (diagnostics.outcome === "OPTIMAL" || diagnostics.outcome === "FEASIBLE");

  return (
    <div
      data-testid="solver-diagnostics-panel"
      className={cn("space-y-3", className)}
    >
      {/* D6 Semantic Outcome Banner */}
      <div
        role={
          diagnostics.outcome === "OPTIMAL" || diagnostics.outcome === "FEASIBLE"
            ? "status"
            : "alert"
        }
        data-testid={`solver-outcome-banner-${diagnostics.outcome}`}
        className={cn(
          "flex flex-wrap items-start justify-between gap-3 rounded-[var(--r-control)] border p-3.5 text-[12.5px]",
          meta.toneClass,
        )}
      >
        <div className="flex min-w-0 items-start gap-2.5">
          <StatusIcon
            size={18}
            weight={
              diagnostics.outcome === "OPTIMAL" ||
              diagnostics.outcome === "FEASIBLE"
                ? "fill"
                : "regular"
            }
            className="mt-0.5 shrink-0"
            aria-hidden="true"
          />
          <div className="min-w-0 space-y-0.5">
            <div className="font-semibold">{meta.title}</div>
            <p className="leading-[1.45]">{meta.description}</p>
            {diagnostics.error &&
              diagnostics.outcome !== "OPTIMAL" &&
              diagnostics.outcome !== "FEASIBLE" &&
              conflicts.length === 0 && (
                <p className="font-mono-tabular mt-1 text-[11.5px] opacity-90">
                  {diagnostics.error}
                </p>
              )}
          </div>
        </div>

        <div className="flex shrink-0 flex-wrap items-center gap-1.5">
          <Badge tone={meta.badgeTone} mono>
            {diagnostics.outcome}
          </Badge>
          {diagnostics.termination_reason && (
            <Badge tone="neutral" mono>
              {diagnostics.termination_reason}
            </Badge>
          )}
        </div>
      </div>

      {/* Actionable D6 Conflict Ledger */}
      {conflicts.length > 0 && (
        <div
          data-testid="solver-conflict-ledger"
          className="rounded-[var(--r-control)] border border-[var(--border-subtle)] bg-[var(--bg-surface)]"
        >
          <div className="flex flex-wrap items-center justify-between gap-2 border-b border-[var(--border-subtle)] px-3.5 py-2.5">
            <span className="text-[12.5px] font-semibold text-[var(--ink-primary)]">
              Actionable Policy &amp; Conflict Ledger
            </span>
            <span className="font-mono-tabular text-[11.5px] text-[var(--ink-muted)]">
              {conflicts.length} item(s)
            </span>
          </div>

          <ul className="divide-y divide-[var(--border-subtle)]">
            {conflicts.map((conflict, idx) => {
              const route = resolveConflictRoute(conflict);
              const isBlocker = conflict.severity === "blocker";
              return (
                <li
                  key={`${conflict.rule}-${conflict.code}-${conflict.entity_id}-${idx}`}
                  data-testid={`conflict-item-${conflict.rule}`}
                  className="flex flex-wrap items-start justify-between gap-3 px-3.5 py-3 text-[12.5px]"
                >
                  <div className="min-w-0 flex-1 space-y-1">
                    <div className="flex flex-wrap items-center gap-1.5">
                      <Badge tone={isBlocker ? "conflict" : "joint"} mono>
                        {conflict.rule}
                      </Badge>
                      <Badge tone="neutral" mono>
                        {conflict.proven ? "Proven Conflict" : "Diagnostic Hint"}
                      </Badge>
                      {conflict.entity_id && (
                        <span className="font-mono-tabular text-[12px] font-semibold text-[var(--ink-primary)]">
                          {conflict.entity_id}
                        </span>
                      )}
                    </div>
                    <p className="leading-[1.45] text-[var(--ink-secondary)]">
                      {conflict.message}
                    </p>
                  </div>

                  <Link
                    to={route.to}
                    className="inline-flex h-8 shrink-0 items-center gap-1.5 rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-2.5 text-[12px] font-medium text-[var(--ink-primary)] no-underline hover:bg-[var(--surface-hover)]"
                  >
                    <span>{route.label}</span>
                    <ArrowRight size={13} aria-hidden="true" />
                  </Link>
                </li>
              );
            })}
          </ul>
        </div>
      )}

      {/* Soft Optimization Scorecard (Strictly separated from hard compliance) */}
      {showSoftScorecard && soft && (
        <div
          data-testid="soft-optimization-scorecard"
          className="rounded-[var(--r-control)] border border-[var(--border-subtle)] bg-[var(--bg-surface)]"
        >
          <div className="flex flex-wrap items-center justify-between gap-2 border-b border-[var(--border-subtle)] px-3.5 py-2.5">
            <div className="flex items-center gap-2">
              <SlidersHorizontal
                size={15}
                className="text-[var(--accent-brand)]"
                aria-hidden="true"
              />
              <span className="text-[12.5px] font-semibold text-[var(--ink-primary)]">
                Soft Optimization Scorecard
              </span>
            </div>
            <span className="text-[11.5px] text-[var(--ink-muted)]">
              Advisory preferences only · never blocks publication
            </span>
          </div>

          <div className="grid grid-cols-2 divide-y divide-[var(--border-subtle)] sm:grid-cols-4 sm:divide-x sm:divide-y-0">
            <div className="px-3.5 py-2.5">
              <div className="text-[11px] text-[var(--ink-muted)]">
                R8 Faculty Preferences
              </div>
              <div className="font-mono-tabular mt-0.5 text-[13.5px] font-semibold text-[var(--ink-primary)]">
                {soft.r8_faculty_preferences &&
                soft.r8_faculty_preferences.total_with_preferences > 0
                  ? `${soft.r8_faculty_preferences.matched_slots}/${soft.r8_faculty_preferences.total_with_preferences} (${soft.r8_faculty_preferences.satisfaction_pct ?? 0}%)`
                  : "None declared"}
              </div>
            </div>

            <div className="px-3.5 py-2.5">
              <div className="text-[11px] text-[var(--ink-muted)]">
                R9 SUST Break Splits
              </div>
              <div className="font-mono-tabular mt-0.5 text-[13.5px] font-semibold text-[var(--ink-primary)]">
                {soft.r9_sust_compactness
                  ? soft.r9_sust_compactness.sust_faculty_count > 0
                    ? `${soft.r9_sust_compactness.split_break_days} split day(s)`
                    : "0 SUST faculty"
                  : "—"}
              </div>
            </div>

            <div className="px-3.5 py-2.5">
              <div className="text-[11px] text-[var(--ink-muted)]">
                R12 Sessional Lab Pairs
              </div>
              <div className="font-mono-tabular mt-0.5 flex flex-wrap items-center gap-1.5 text-[13.5px] font-semibold text-[var(--ink-primary)]">
                <span>
                  {soft.r12_sessional_pairs
                    ? soft.r12_sessional_pairs.total_two_credit_labs > 0
                      ? `${soft.r12_sessional_pairs.paired_two_credit_labs}/${soft.r12_sessional_pairs.total_two_credit_labs} paired`
                      : "0 2-cr labs"
                    : "—"}
                </span>
                {soft.r12_sessional_pairs && (
                  <Badge
                    tone={
                      soft.r12_sessional_pairs.allow_sessional_across_break
                        ? "joint"
                        : "neutral"
                    }
                    mono
                  >
                    {soft.r12_sessional_pairs.allow_sessional_across_break
                      ? "D5 Break On"
                      : "D5 Break Off"}
                  </Badge>
                )}
              </div>
            </div>

            <div className="px-3.5 py-2.5">
              <div className="text-[11px] text-[var(--ink-muted)]">
                R3 Single-Slot Gaps
              </div>
              <div className="font-mono-tabular mt-0.5 text-[13.5px] font-semibold text-[var(--ink-primary)]">
                {typeof soft.r3_single_slot_holes === "number"
                  ? `${soft.r3_single_slot_holes} hole(s)`
                  : "—"}
              </div>
            </div>
          </div>

          {soft.r6_adjunct_workload && soft.r6_adjunct_workload.length > 0 && (
            <div className="border-t border-[var(--border-subtle)] px-3.5 py-2.5">
              <div className="mb-1.5 text-[11px] font-medium text-[var(--ink-muted)]">
                R6 Adjunct Distinct-Course Workload Span
              </div>
              <div className="flex flex-wrap gap-1.5">
                {soft.r6_adjunct_workload.map((adj) => (
                  <Badge
                    key={adj.teacher}
                    tone={adj.in_band ? "lab" : "joint"}
                    mono
                  >
                    {adj.teacher}: {adj.distinct_course_count} crse ·{" "}
                    {adj.active_days}d
                    {adj.target_band
                      ? ` (${adj.target_band[0]}–${adj.target_band[1]}d)`
                      : ""}
                  </Badge>
                ))}
              </div>
            </div>
          )}
        </div>
      )}

      {/* Hybrid R7 / R6 Resolved Faculty Off-Days Provenance Table */}
      {hasHybridResolved && (
        <div
          data-testid="resolved-faculty-offdays-panel"
          className="rounded-[var(--r-control)] border border-[var(--border-subtle)] bg-[var(--bg-surface)]"
        >
          <button
            type="button"
            aria-expanded={offDaysExpanded}
            onClick={() => setOffDaysExpanded((v) => !v)}
            className="flex w-full items-center justify-between gap-2 px-3.5 py-2.5 text-left hover:bg-[var(--surface-hover)]"
          >
            <div className="flex flex-wrap items-center gap-2">
              {offDaysExpanded ? (
                <CaretDown size={14} aria-hidden="true" />
              ) : (
                <CaretRight size={14} aria-hidden="true" />
              )}
              <span className="text-[12.5px] font-semibold text-[var(--ink-primary)]">
                Resolved Faculty Off-Days (Hybrid R7/R6)
              </span>
              <Badge tone="lab" mono>
                {resolvedOffDays.filter((r) => r.provenance !== "declared").length} auto-resolved
              </Badge>
            </div>
            <span className="font-mono-tabular text-[11.5px] text-[var(--ink-muted)]">
              {resolvedOffDays.length} faculty
            </span>
          </button>

          {offDaysExpanded && (
            <div className="overflow-x-auto border-t border-[var(--border-subtle)]">
              <table className="w-full border-collapse text-left text-[12px]">
                <thead>
                  <tr className="border-b border-[var(--border-subtle)] bg-[var(--bg-elevated)] text-[11px] font-semibold text-[var(--ink-muted)] uppercase">
                    <th className="px-3 py-2">Faculty</th>
                    <th className="px-3 py-2">Category</th>
                    <th className="px-3 py-2">Declared</th>
                    <th className="px-3 py-2">Resolved Off-Days</th>
                    <th className="px-3 py-2">Teaching Days</th>
                    <th className="px-3 py-2">Provenance</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-[var(--border-subtle)]">
                  {resolvedOffDays.map((entry) => (
                    <tr key={entry.acronym}>
                      <td className="font-mono-tabular px-3 py-2 font-semibold text-[var(--ink-primary)]">
                        {entry.acronym}
                      </td>
                      <td className="px-3 py-2 capitalize text-[var(--ink-secondary)]">
                        {entry.employment_type}
                      </td>
                      <td className="font-mono-tabular px-3 py-2 text-[var(--ink-secondary)]">
                        {entry.declared_off_days.length > 0
                          ? entry.declared_off_days.map((d) => d.slice(0, 3)).join(", ")
                          : "—"}
                      </td>
                      <td className="font-mono-tabular px-3 py-2 font-medium text-[var(--ink-primary)]">
                        {entry.resolved_off_days.length > 0
                          ? entry.resolved_off_days.map((d) => d.slice(0, 3)).join(", ")
                          : "—"}
                      </td>
                      <td className="font-mono-tabular px-3 py-2 text-[var(--ink-secondary)]">
                        {entry.active_teaching_days.length > 0
                          ? entry.active_teaching_days.map((d) => d.slice(0, 3)).join(", ")
                          : "0d"}
                      </td>
                      <td className="px-3 py-2">
                        <Badge
                          tone={
                            entry.provenance === "declared"
                              ? "neutral"
                              : entry.provenance === "partial_hybrid"
                                ? "joint"
                                : "theory"
                          }
                          mono
                        >
                          {entry.provenance}
                        </Badge>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
