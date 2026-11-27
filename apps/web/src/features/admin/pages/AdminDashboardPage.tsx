import {
  ArrowRight,
  ArrowsClockwise,
  CheckCircle,
  Info,
  LockSimple,
  ShieldCheck,
  WarningCircle,
} from "@phosphor-icons/react";
import { useQuery } from "@tanstack/react-query";
import { useMemo, useState } from "react";
import { Link } from "react-router-dom";
import {
  Bar,
  BarChart,
  CartesianGrid,
  Cell,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import { toast } from "sonner";
import { Badge } from "@/components/ui/Badge";
import {
  formatCapabilityStatusLabel,
  resolveLiveSubfeatureCapabilities,
} from "@/core/capabilities";
import {
  fetchAdminDashboardCounts,
  type AdminDashboardCounts,
} from "@/features/admin/services/adminDashboardService";
import { useAuth } from "@/features/auth/AuthProvider";
import { probeLiveSchedulingCapabilities } from "@/features/scheduling/services/schedulingCapabilities";
import type { SchedulingGateState } from "@/features/scheduling/types";
import { cn } from "@/lib/utils";

type ReadinessFilter = "all" | "needs-setup" | "ready";

interface ReadinessStageRow {
  step: string;
  title: string;
  description: string;
  count: number;
  countLabel: string;
  actionLabel: string;
  actionTo: string;
  ready: boolean;
}

function formatClock(iso: string): string {
  try {
    return new Date(iso).toLocaleTimeString([], {
      hour: "2-digit",
      minute: "2-digit",
      second: "2-digit",
    });
  } catch {
    return "--:--:--";
  }
}

function buildReadinessStages(data: AdminDashboardCounts): ReadinessStageRow[] {
  return [
    {
      step: "01",
      title: "Room & Lab Pools",
      description:
        "Lecture rooms, gallery rooms, computing labs, and shared lab scheduling windows.",
      count: data.timetableRooms,
      countLabel: `${data.timetableRooms} configured`,
      actionLabel: "Configure Rooms",
      actionTo: "/admin/timetable/rooms",
      ready: data.timetableRooms > 0,
    },
    {
      step: "02",
      title: "Faculty Roster & Off-Day Bounds",
      description:
        "Instructor acronyms, designations, permanent weekly off-days, and active status.",
      count: data.timetableFaculty,
      countLabel: `${data.timetableFaculty} configured`,
      actionLabel: "Manage Faculty",
      actionTo: "/admin/timetable/faculty",
      ready: data.timetableFaculty > 0,
    },
    {
      step: "03",
      title: "Course Eligibility & Time Grid",
      description:
        "Approved instructor-to-course assignments and active period grid rules.",
      count: data.timetableCourseEligibility,
      countLabel: `${data.timetableCourseEligibility} eligibility records`,
      actionLabel: "Set Eligibility",
      actionTo: "/admin/timetable/course-eligibility",
      ready: data.timetableCourseEligibility > 0,
    },
    {
      step: "04",
      title: "Active Routine & Publication",
      description:
        "Published weekly class allocations synchronized to student and faculty mobile apps.",
      count: data.routines,
      countLabel: `${data.routines} active slots`,
      actionLabel: "Open Operations",
      actionTo: "/admin/routine",
      ready: data.routines > 0,
    },
  ];
}

function BatchLoadTooltip({
  active,
  payload,
  label,
}: {
  active?: boolean;
  payload?: ReadonlyArray<{ value?: number }>;
  label?: string;
}) {
  if (!active || !payload?.length) return null;
  return (
    <div className="ledger-popover px-3 py-2 text-[12px]">
      <div className="font-semibold text-[var(--ink-primary)]">{label}</div>
      <div className="font-mono-tabular mt-0.5 text-[var(--accent-brand)]">
        {payload[0]?.value ?? 0} active weekly slots
      </div>
    </div>
  );
}

function RoomBreakdownTooltip({
  active,
  payload,
  label,
}: {
  active?: boolean;
  payload?: ReadonlyArray<{ name?: string; value?: number }>;
  label?: string;
}) {
  if (!active || !payload?.length) return null;
  return (
    <div className="ledger-popover px-3 py-2 text-[12px]">
      <div className="font-semibold text-[var(--ink-primary)]">{label}</div>
      {payload.map((entry) => (
        <div
          key={entry.name}
          className="font-mono-tabular mt-0.5 text-[var(--ink-secondary)]"
        >
          {entry.name}: {entry.value ?? 0}
        </div>
      ))}
    </div>
  );
}

export interface AdminDashboardViewProps {
  data?: AdminDashboardCounts;
  liveGates?: SchedulingGateState | null;
  isLoading: boolean;
  isFetching: boolean;
  isError: boolean;
  errorMessage?: string;
  onRefresh: () => void;
}

export function AdminDashboardView({
  data,
  liveGates,
  isLoading,
  isFetching,
  isError,
  errorMessage,
  onRefresh,
}: AdminDashboardViewProps) {
  const [stageFilter, setStageFilter] = useState<ReadinessFilter>("all");
  const [hoveredBatchIndex, setHoveredBatchIndex] = useState<number | null>(
    null,
  );
  const [hoveredRoomIndex, setHoveredRoomIndex] = useState<number | null>(null);
  const [hoveredDayIndex, setHoveredDayIndex] = useState<number | null>(null);

  const stages = useMemo(
    () => (data ? buildReadinessStages(data) : []),
    [data],
  );

  const readyCount = stages.filter((s) => s.ready).length;
  const needsSetupCount = stages.length - readyCount;

  const visibleStages = useMemo(() => {
    if (stageFilter === "ready") return stages.filter((s) => s.ready);
    if (stageFilter === "needs-setup") return stages.filter((s) => !s.ready);
    return stages;
  }, [stages, stageFilter]);

  if (isLoading) {
    return (
      <div className="flex flex-col gap-5" aria-label="Loading command center">
        <div className="h-[52px] animate-pulse rounded-[var(--r-card)] border border-[var(--border-subtle)] bg-[var(--bg-elevated)]" />
        <div className="h-[290px] animate-pulse rounded-[var(--r-card)] border border-[var(--border-subtle)] bg-[var(--bg-elevated)]" />
        <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
          <div className="h-[240px] animate-pulse rounded-[var(--r-card)] border border-[var(--border-subtle)] bg-[var(--bg-elevated)]" />
          <div className="h-[240px] animate-pulse rounded-[var(--r-card)] border border-[var(--border-subtle)] bg-[var(--bg-elevated)]" />
        </div>
      </div>
    );
  }

  if (isError || !data) {
    return (
      <div
        role="alert"
        className="ledger-card flex flex-col items-start gap-3 border-[var(--sem-conflict-border)] bg-[var(--sem-conflict-bg)] p-5 text-[var(--sem-conflict-ink)]"
      >
        <div className="flex items-center gap-2 text-[16px] font-semibold">
          <WarningCircle size={20} aria-hidden="true" />
          <span>Unable to load departmental readiness summary</span>
        </div>
        <p className="text-[13.5px]">
          {errorMessage ??
            "Could not reach the backend data service. Check your connection or session permissions and try again."}
        </p>
        <button
          type="button"
          onClick={onRefresh}
          className="btn-secondary !h-[36px]"
        >
          <ArrowsClockwise size={15} aria-hidden="true" />
          <span>Retry Refresh</span>
        </button>
      </div>
    );
  }

  const hasEmptyEligibility = data.timetableCourseEligibility === 0;
  const missingParts: string[] = [];
  if (data.timetableRooms === 0) missingParts.push("0 room pools");
  if (data.timetableFaculty === 0) missingParts.push("0 faculty profiles");
  if (data.timetableCourseEligibility === 0) {
    missingParts.push("0 course eligibility links");
  }
  const hasMissingBaseline = missingParts.length > 0;

  const isBrandNewWorkspace =
    data.routines === 0 &&
    data.timetableRooms === 0 &&
    data.timetableFaculty === 0;

  return (
    <div className="flex flex-col gap-5">
      {/* Mandatory Static Preview Banner when running disconnected dev preview */}
      {data.source === "dev-preview" && (
        <div
          role="status"
          data-testid="dev-preview-banner"
          className="flex flex-wrap items-center justify-between gap-3 rounded-[var(--r-card)] border border-[var(--accent-brand-border)] bg-[var(--accent-brand-soft)] px-4 py-2.5 text-[12.5px] text-[var(--accent-brand)]"
        >
          <div className="flex items-center gap-2 font-medium">
            <Info size={16} className="shrink-0" aria-hidden="true" />
            <span>
              Illustrative preview — disconnected from live Supabase &amp;
              FastAPI backends.
            </span>
          </div>
          <span className="font-mono-tabular text-[11px]">
            Zero database writes
          </span>
        </div>
      )}

      {/* High-Contrast Empty Eligibility & Baseline Warning */}
      {hasMissingBaseline && (
        <div
          role="alert"
          data-testid="empty-eligibility-warning"
          className="flex flex-wrap items-center justify-between gap-3 rounded-[var(--r-card)] border border-[var(--sem-conflict-border)] bg-[var(--sem-conflict-bg)] px-4 py-3 text-[var(--sem-conflict-ink)]"
        >
          <div className="flex items-start gap-2.5 text-[13px]">
            <WarningCircle
              size={18}
              className="mt-0.5 shrink-0"
              aria-hidden="true"
            />
            <div>
              <strong className="font-semibold">
                {hasEmptyEligibility
                  ? "0 configured eligibility records — routine generation requires baseline setup"
                  : "Departmental configuration incomplete"}
              </strong>
              <p className="mt-0.5 text-[12.5px]">
                Missing baseline setup: {missingParts.join(", ")}. Complete all
                three baseline stages before publishing a new semester schedule.
              </p>
            </div>
          </div>
          <div className="flex flex-wrap items-center gap-2">
            {hasEmptyEligibility && (
              <Link
                to="/admin/timetable/course-eligibility"
                className="btn-secondary !h-[34px] !px-3 !text-[12px] no-underline"
              >
                <span>Configure Eligibility</span>
                <ArrowRight size={13} aria-hidden="true" />
              </Link>
            )}
            <Link
              to="/admin/timetable/rooms"
              className="btn-secondary !h-[34px] !px-3 !text-[12px] no-underline"
            >
              <span>Inspect Baseline</span>
            </Link>
          </div>
        </div>
      )}

      {/* Routine Lifecycle Workflow Strip */}
      <section
        aria-label="Routine lifecycle workflow"
        data-testid="dashboard-lifecycle-strip"
        className="ledger-card grid grid-cols-1 divide-y divide-[var(--border-subtle)] overflow-hidden md:grid-cols-4 md:divide-x md:divide-y-0"
      >
        {[
          {
            step: "01",
            label: "Configure Baseline",
            sub: `${data.timetableRooms} rooms · ${data.timetableFaculty} faculty · ${data.timetableCourseEligibility} elig`,
            done:
              data.timetableRooms > 0 &&
              data.timetableFaculty > 0 &&
              data.timetableCourseEligibility > 0,
            to: "/admin/timetable/rooms",
          },
          {
            step: "02",
            label: "Manage / Generate",
            sub: "Track 1 CP-SAT solver & slot editor",
            done: data.routines > 0,
            to: "/admin/routine?tab=generate",
          },
          {
            step: "03",
            label: "Validate & Review",
            sub: "20-counter ledger & 2D matrix",
            done: data.routines > 0,
            to: "/admin/timetable/grid?from=dashboard",
          },
          {
            step: "04",
            label: "Active Schedule",
            sub: data.activeVersionLabel ?? `${data.routines} live slots`,
            done: data.routines > 0,
            to: "/admin/routine?tab=manage",
          },
        ].map((item) => (
          <Link
            key={item.step}
            to={item.to}
            className="flex items-start justify-between gap-2.5 px-4 py-3 text-left no-underline transition-colors hover:bg-[var(--surface-hover)]"
          >
            <div className="min-w-0">
              <div className="flex items-center gap-1.5">
                <span className="font-mono-tabular text-[11px] font-semibold text-[var(--ink-muted)]">
                  {item.step}
                </span>
                <span className="truncate text-[13px] font-semibold text-[var(--ink-primary)]">
                  {item.label}
                </span>
              </div>
              <div className="font-mono-tabular mt-0.5 truncate text-[11.5px] text-[var(--ink-secondary)]">
                {item.sub}
              </div>
            </div>
            {item.done ? (
              <CheckCircle
                size={15}
                weight="fill"
                className="mt-0.5 shrink-0 text-[var(--accent-brand)]"
                aria-hidden="true"
              />
            ) : (
              <ArrowRight
                size={14}
                className="mt-0.5 shrink-0 text-[var(--ink-muted)]"
                aria-hidden="true"
              />
            )}
          </Link>
        ))}
      </section>

      {/* Live R7 Off-Day Advisory Link */}
      {(data.r7AdvisoryCount ?? 0) > 0 && (
        <div
          role="status"
          data-testid="dashboard-r7-advisory-link"
          className="flex flex-wrap items-center justify-between gap-3 rounded-[var(--r-card)] border border-[var(--border-subtle)] border-l-[3px] border-l-[var(--sem-joint-bar)] bg-[var(--bg-elevated)] px-4 py-2.5 text-[12.5px] text-[var(--ink-secondary)]"
        >
          <div className="flex items-center gap-2">
            <WarningCircle size={16} className="shrink-0 text-[var(--sem-joint-bar)]" aria-hidden="true" />
            <span>
              <strong className="font-semibold text-[var(--ink-primary)]">
                {data.r7AdvisoryCount} active faculty{" "}
                {data.r7AdvisoryCount === 1 ? "member has" : "members have"} an R7
                off-day advisory
              </strong>{" "}
              (fewer than 2 or more than 3 declared off-days).
            </span>
          </div>
          <Link
            to="/admin/timetable/faculty?filter=r7"
            className="btn-secondary !h-[30px] !px-2.5 !text-[12px] no-underline"
          >
            <span>Inspect R7 Faculty</span>
            <ArrowRight size={13} aria-hidden="true" />
          </Link>
        </div>
      )}

      {/* First-Use Empty State Nudge */}
      {isBrandNewWorkspace && (
        <div className="ledger-card flex flex-wrap items-center justify-between gap-4 p-5">
          <div>
            <h2 className="text-[16px] font-semibold text-[var(--ink-primary)]">
              Prepare your semester configuration
            </h2>
            <p className="mt-1 text-[13px] text-[var(--ink-secondary)]">
              Seed campus rooms and faculty off-day policies first, then review
              course eligibility prior to running schedule generation.
            </p>
          </div>
          <Link to="/admin/timetable/rooms" className="btn-primary no-underline">
            Configure Room Pools
          </Link>
        </div>
      )}

      {/* Live Freshness Header Row (Focus-Refetch + Manual Refresh + Clock) */}
      <div className="flex flex-wrap items-center justify-between gap-3 rounded-[var(--r-card)] border border-[var(--border-subtle)] bg-[var(--bg-elevated)] px-4 py-3">
        <div className="flex flex-wrap items-center gap-x-5 gap-y-1 text-[13px] text-[var(--ink-secondary)]">
          <span>
            Active Version:{" "}
            <strong className="font-mono-tabular font-semibold text-[var(--ink-primary)]">
              {data.activeVersionLabel ?? "None published"}
            </strong>
          </span>
          <span className="font-mono-tabular text-[12.5px]">
            {data.routines} slots · {data.profiles} profiles ·{" "}
            {data.notifications} broadcasts
          </span>
        </div>

        <div className="flex items-center gap-3">
          <span className="font-mono-tabular text-[12px] text-[var(--ink-muted)]">
            Last checked {formatClock(data.checkedAt)}
          </span>
          <button
            type="button"
            disabled={isFetching}
            onClick={onRefresh}
            className="btn-secondary !h-[36px] !px-3 !text-[12.5px]"
          >
            <ArrowsClockwise
              size={14}
              className={isFetching ? "animate-spin" : undefined}
              aria-hidden="true"
            />
            <span>Refresh</span>
          </button>
        </div>
      </div>

      {/* 4-Stage Routine Readiness Checklist (Primary Action CTAs always full contrast at rest) */}
      <section
        aria-labelledby="readiness-heading"
        className="ledger-card overflow-hidden"
      >
        <div className="flex flex-wrap items-center justify-between gap-3 border-b border-[var(--border-subtle)] px-5 py-3.5">
          <div className="flex flex-wrap items-center gap-3">
            <h2
              id="readiness-heading"
              className="text-[16px] font-semibold tracking-[-0.015em] text-[var(--ink-primary)]"
            >
              4-Stage Routine Readiness Checklist
            </h2>
            <span className="font-mono-tabular text-[12px] text-[var(--ink-muted)]">
              {readyCount} of 4 stages configured
            </span>
          </div>

          {/* Upfront Option-Level Filter Counts */}
          <div
            role="group"
            aria-label="Filter readiness stages"
            className="flex flex-wrap items-center gap-1.5"
          >
            {(
              [
                { key: "all", label: `All (${stages.length})` },
                { key: "needs-setup", label: `Needs Setup (${needsSetupCount})` },
                { key: "ready", label: `Ready (${readyCount})` },
              ] as const
            ).map((opt) => {
              const active = stageFilter === opt.key;
              return (
                <button
                  key={opt.key}
                  type="button"
                  aria-pressed={active}
                  onClick={() => setStageFilter(opt.key)}
                  className={cn(
                    "h-[30px] rounded-[6px] border px-2.5 font-mono-tabular text-[11.5px] transition-colors whitespace-nowrap",
                    active
                      ? "border-[var(--accent-brand)] bg-[var(--accent-brand-soft)] font-semibold text-[var(--accent-brand)]"
                      : "border-[var(--border-subtle)] bg-[var(--bg-surface)] text-[var(--ink-secondary)] hover:bg-[var(--surface-hover)] hover:text-[var(--ink-primary)]",
                  )}
                >
                  {opt.label}
                </button>
              );
            })}
          </div>
        </div>

        {visibleStages.length === 0 ? (
          <div
            data-testid="readiness-filter-empty"
            className="flex flex-wrap items-center justify-between gap-3 px-5 py-6 text-[13px] text-[var(--ink-secondary)]"
          >
            <span>No readiness stages match the selected filter.</span>
            <button
              type="button"
              onClick={() => setStageFilter("all")}
              className="btn-secondary !h-[32px] !px-3 !text-[12px]"
            >
              Clear Filter
            </button>
          </div>
        ) : (
          <div className="divide-y divide-[var(--border-subtle)]">
            {visibleStages.map((stage) => (
              <div
                key={stage.step}
                className="grid grid-cols-[24px_24px_minmax(0,1fr)_auto] items-center gap-3 px-5 py-3.5 transition-colors hover:bg-[var(--surface-hover)] sm:grid-cols-[24px_24px_minmax(0,1fr)_170px_150px]"
              >
                <span className="font-mono-tabular text-[12px] text-[var(--ink-muted)]">
                  {stage.step}
                </span>
                {stage.ready ? (
                  <CheckCircle
                    size={18}
                    weight="fill"
                    className="text-[var(--sem-lab-ink)]"
                    aria-label="Configured"
                  />
                ) : (
                  <WarningCircle
                    size={18}
                    className="text-[var(--sem-conflict-ink)]"
                    aria-label="Needs setup"
                  />
                )}
                <div className="min-w-0">
                  <div className="text-[13.5px] font-semibold text-[var(--ink-primary)]">
                    {stage.title}
                  </div>
                  <div className="line-clamp-2 text-[12px] leading-snug text-[var(--ink-secondary)] sm:truncate">
                    {stage.description}
                  </div>
                </div>
                <div
                  className="font-mono-tabular text-right text-[12px] font-medium whitespace-nowrap"
                  style={{
                    color: stage.ready
                      ? "var(--sem-lab-ink)"
                      : "var(--sem-conflict-ink)",
                  }}
                >
                  {stage.countLabel}
                </div>
                <div className="col-span-4 flex justify-end sm:col-span-1">
                  <Link
                    to={stage.actionTo}
                    className="btn-secondary !h-[32px] !px-3 !text-[12px] no-underline"
                  >
                    {stage.actionLabel}
                  </Link>
                </div>
              </div>
            ))}
          </div>
        )}
      </section>

      {/* Backend-Derived Recharts v3 Operational Analytics */}
      <section
        aria-label="Departmental load and room breakdown charts"
        className="grid grid-cols-1 gap-4 md:grid-cols-2"
      >
        <div
          data-testid="dashboard-batch-load-chart"
          className="ledger-card flex flex-col gap-3 p-4"
        >
          <div className="flex items-center justify-between gap-2 border-b border-[var(--border-subtle)] pb-2.5">
            <div>
              <h2 className="text-[14px] font-semibold text-[var(--ink-primary)]">
                Weekly Published Slot Load by Batch
              </h2>
              <p className="text-[12px] text-[var(--ink-secondary)]">
                Active weekly allocations across cohorts
              </p>
            </div>
            <Link
              to="/admin/timetable/settings"
              className="text-[12px] font-medium text-[var(--accent-brand)] no-underline hover:underline"
            >
              Grid Settings
            </Link>
          </div>

          {data.batchLoadSummary.length === 0 ? (
            <div className="flex h-[210px] items-center justify-center rounded-[var(--r-control)] border border-dashed border-[var(--border-subtle)] bg-[var(--bg-surface)] px-4 text-center text-[13px] text-[var(--ink-muted)]">
              No active routine slots published yet.
            </div>
          ) : (
            <div className="h-[210px] w-full">
              <ResponsiveContainer width="100%" height="100%">
                <BarChart
                  data={data.batchLoadSummary}
                  margin={{ top: 8, right: 8, left: -16, bottom: 4 }}
                >
                  <CartesianGrid
                    strokeDasharray="3 3"
                    vertical={false}
                    stroke="var(--border-subtle)"
                  />
                  <XAxis
                    dataKey="batch"
                    axisLine={{ stroke: "var(--border-subtle)" }}
                    tickLine={false}
                    tick={{ fontSize: 11.5, fill: "var(--ink-muted)" }}
                  />
                  <YAxis
                    allowDecimals={false}
                    axisLine={{ stroke: "var(--border-subtle)" }}
                    tickLine={false}
                    tick={{ fontSize: 11.5, fill: "var(--ink-muted)" }}
                  />
                  <Tooltip
                    cursor={{ fill: "var(--surface-hover)" }}
                    content={<BatchLoadTooltip />}
                  />
                  <Bar
                    dataKey="slots"
                    isAnimationActive={false}
                    radius={[0, 0, 0, 0]}
                    onMouseEnter={(_, idx) => setHoveredBatchIndex(idx)}
                    onMouseLeave={() => setHoveredBatchIndex(null)}
                  >
                    {data.batchLoadSummary.map((entry, idx) => (
                      <Cell
                        key={entry.batch}
                        fill="var(--chart-1)"
                        fillOpacity={
                          hoveredBatchIndex === null || hoveredBatchIndex === idx
                            ? 1
                            : 0.34
                        }
                      />
                    ))}
                  </Bar>
                </BarChart>
              </ResponsiveContainer>
            </div>
          )}
        </div>

        <div
          data-testid="dashboard-room-breakdown-chart"
          className="ledger-card flex flex-col gap-3 p-4"
        >
          <div className="flex items-center justify-between gap-2 border-b border-[var(--border-subtle)] pb-2.5">
            <div>
              <h2 className="text-[14px] font-semibold text-[var(--ink-primary)]">
                Configured Room Inventory Breakdown
              </h2>
              <p className="text-[12px] text-[var(--ink-secondary)]">
                Active vs. inactive rooms across physical types
              </p>
            </div>
            <Link
              to="/admin/timetable/rooms"
              className="text-[12px] font-medium text-[var(--accent-brand)] no-underline hover:underline"
            >
              Manage Rooms
            </Link>
          </div>

          {data.roomCategorySummary.length === 0 ? (
            <div className="flex h-[210px] flex-col items-center justify-center gap-2 rounded-[var(--r-control)] border border-dashed border-[var(--border-subtle)] bg-[var(--bg-surface)] px-4 text-center text-[13px] text-[var(--ink-muted)]">
              <span>0 rooms configured in baseline inventory.</span>
              <Link
                to="/admin/timetable/rooms"
                className="text-[12.5px] font-medium text-[var(--accent-brand)] no-underline hover:underline"
              >
                Open Room &amp; Lab Pools
              </Link>
            </div>
          ) : (
            <div className="h-[210px] w-full">
              <ResponsiveContainer width="100%" height="100%">
                <BarChart
                  data={data.roomCategorySummary}
                  margin={{ top: 8, right: 8, left: -16, bottom: 4 }}
                >
                  <CartesianGrid
                    strokeDasharray="3 3"
                    vertical={false}
                    stroke="var(--border-subtle)"
                  />
                  <XAxis
                    dataKey="category"
                    axisLine={{ stroke: "var(--border-subtle)" }}
                    tickLine={false}
                    tick={{ fontSize: 11.5, fill: "var(--ink-muted)" }}
                  />
                  <YAxis
                    allowDecimals={false}
                    axisLine={{ stroke: "var(--border-subtle)" }}
                    tickLine={false}
                    tick={{ fontSize: 11.5, fill: "var(--ink-muted)" }}
                  />
                  <Tooltip
                    cursor={{ fill: "var(--surface-hover)" }}
                    content={<RoomBreakdownTooltip />}
                  />
                  <Bar
                    dataKey="active"
                    name="Active"
                    isAnimationActive={false}
                    radius={[0, 0, 0, 0]}
                    onMouseEnter={(_, idx) => setHoveredRoomIndex(idx)}
                    onMouseLeave={() => setHoveredRoomIndex(null)}
                  >
                    {data.roomCategorySummary.map((entry, idx) => {
                      const catLow = entry.category.toLowerCase();
                      const barFill = catLow.includes("lab")
                        ? "var(--chart-3)"
                        : catLow.includes("gallery")
                          ? "var(--chart-4)"
                          : "var(--chart-2)";
                      return (
                        <Cell
                          key={`${entry.category}-active`}
                          fill={barFill}
                          fillOpacity={
                            hoveredRoomIndex === null || hoveredRoomIndex === idx
                              ? 1
                              : 0.34
                          }
                        />
                      );
                    })}
                  </Bar>
                  <Bar
                    dataKey="inactive"
                    name="Inactive"
                    isAnimationActive={false}
                    radius={[0, 0, 0, 0]}
                    onMouseEnter={(_, idx) => setHoveredRoomIndex(idx)}
                    onMouseLeave={() => setHoveredRoomIndex(null)}
                  >
                    {data.roomCategorySummary.map((entry, idx) => (
                      <Cell
                        key={`${entry.category}-inactive`}
                        fill="var(--ink-muted)"
                        fillOpacity={
                          hoveredRoomIndex === null || hoveredRoomIndex === idx
                            ? 0.72
                            : 0.25
                        }
                      />
                    ))}
                  </Bar>
                </BarChart>
              </ResponsiveContainer>
            </div>
          )}
        </div>
      </section>

      <section aria-label="Weekly slot distribution by day">
        <div
          data-testid="dashboard-daily-load-chart"
          className="ledger-card flex flex-col gap-3 p-4"
        >
          <div className="flex items-center justify-between gap-2 border-b border-[var(--border-subtle)] pb-2.5">
            <div>
              <h2 className="text-[14px] font-semibold text-[var(--ink-primary)]">
                Weekly Published Slot Load by Day
              </h2>
              <p className="text-[12px] text-[var(--ink-secondary)]">
                Active slots distributed across Sun–Sat
              </p>
            </div>
            <Link
              to="/admin/timetable/grid?from=dashboard"
              className="text-[12px] font-medium text-[var(--accent-brand)] no-underline hover:underline"
            >
              Open Matrix
            </Link>
          </div>

          {(data.dailySlotLoadSummary ?? []).length === 0 ? (
            <div className="flex h-[210px] items-center justify-center rounded-[var(--r-control)] border border-dashed border-[var(--border-subtle)] bg-[var(--bg-surface)] px-4 text-center text-[13px] text-[var(--ink-muted)]">
              No active routine slots published yet.
            </div>
          ) : (
            <div className="h-[210px] w-full">
              <ResponsiveContainer width="100%" height="100%">
                <BarChart
                  data={data.dailySlotLoadSummary}
                  margin={{ top: 8, right: 8, left: -16, bottom: 4 }}
                >
                  <CartesianGrid
                    strokeDasharray="3 3"
                    vertical={false}
                    stroke="var(--border-subtle)"
                  />
                  <XAxis
                    dataKey="shortDay"
                    axisLine={{ stroke: "var(--border-subtle)" }}
                    tickLine={false}
                    tick={{ fontSize: 11.5, fill: "var(--ink-muted)" }}
                  />
                  <YAxis
                    allowDecimals={false}
                    axisLine={{ stroke: "var(--border-subtle)" }}
                    tickLine={false}
                    tick={{ fontSize: 11.5, fill: "var(--ink-muted)" }}
                  />
                  <Tooltip
                    cursor={{ fill: "var(--surface-hover)" }}
                    content={<BatchLoadTooltip />}
                  />
                  <Bar
                    dataKey="slots"
                    isAnimationActive={false}
                    radius={[0, 0, 0, 0]}
                    onMouseEnter={(_, idx) => setHoveredDayIndex(idx)}
                    onMouseLeave={() => setHoveredDayIndex(null)}
                  >
                    {(data.dailySlotLoadSummary ?? []).map((entry, idx) => (
                      <Cell
                        key={entry.day}
                        fill="var(--chart-2)"
                        fillOpacity={
                          hoveredDayIndex === null || hoveredDayIndex === idx
                            ? 1
                            : 0.34
                        }
                      />
                    ))}
                  </Bar>
                </BarChart>
              </ResponsiveContainer>
            </div>
          )}
        </div>
      </section>

      {/* Operational Totals + Separate Track 2 Scheduling Workbench Status */}
      <section className="grid grid-cols-1 gap-4 md:grid-cols-2">
        <div className="ledger-card overflow-hidden">
          <div className="border-b border-[var(--border-subtle)] px-4 py-3 text-[13.5px] font-semibold text-[var(--ink-primary)]">
            Persisted Operational Totals
          </div>
          <div className="divide-y divide-[var(--border-subtle)] text-[13px]">
            <div className="flex items-center justify-between px-4 py-3">
              <span className="text-[var(--ink-secondary)]">
                Registered University Profiles
              </span>
              <span className="font-mono-tabular font-semibold text-[var(--ink-primary)]">
                {data.profiles}
              </span>
            </div>
            <div className="flex items-center justify-between px-4 py-3">
              <span className="text-[var(--ink-secondary)]">
                Active Published Routine Slots
              </span>
              <span className="font-mono-tabular font-semibold text-[var(--ink-primary)]">
                {data.routines}
              </span>
            </div>
            <div className="flex items-center justify-between px-4 py-3">
              <span className="text-[var(--ink-secondary)]">
                Sent Campus Broadcasts
              </span>
              <span className="font-mono-tabular font-semibold text-[var(--ink-primary)]">
                {data.notifications}
              </span>
            </div>
          </div>
        </div>

        {(() => {
          const resolvedSubfeatures =
            resolveLiveSubfeatureCapabilities(liveGates);
          const allGatesLive = Boolean(
            liveGates?.gateA.unlocked &&
              liveGates?.gateB.unlocked &&
              liveGates?.gateC.unlocked &&
              liveGates?.gateD.unlocked,
          );
          const gatesABCLive = Boolean(
            liveGates?.gateA.unlocked &&
              liveGates?.gateB.unlocked &&
              liveGates?.gateC.unlocked,
          );
          const headerLabel = allGatesLive
            ? "Gates A–D Live"
            : gatesABCLive
              ? "Gates A–C Live"
              : "Gates A–D";
          return (
            <div className="ledger-card overflow-hidden">
              <div className="flex items-center justify-between gap-2 border-b border-[var(--border-subtle)] px-4 py-3">
                <span className="text-[13.5px] font-semibold text-[var(--ink-primary)]">
                  Track 2 &amp; Feature Governance
                </span>
                <Badge tone={allGatesLive ? "lab" : "joint"} mono>
                  {allGatesLive ? (
                    <ShieldCheck size={12} aria-hidden="true" />
                  ) : (
                    <LockSimple size={12} aria-hidden="true" />
                  )}
                  <span>{headerLabel}</span>
                </Badge>
              </div>
              <div className="divide-y divide-[var(--border-subtle)] text-[12.5px]">
                {resolvedSubfeatures.map((cap) => (
                  <div
                    key={cap.id}
                    className="flex items-center justify-between gap-3 px-4 py-2.5"
                  >
                    <div className="min-w-0">
                      <div className="font-medium text-[var(--ink-primary)]">
                        {cap.label}
                      </div>
                      <div className="truncate text-[11.5px] text-[var(--ink-muted)]">
                        {cap.summary}
                      </div>
                    </div>
                    <Badge
                      tone={
                        cap.status === "fail-closed-gate"
                          ? "joint"
                          : cap.status === "staged-no-db"
                            ? "neutral"
                            : "lab"
                      }
                      mono
                    >
                      {cap.badgeLabel ?? formatCapabilityStatusLabel(cap.status)}
                    </Badge>
                  </div>
                ))}
              </div>
            </div>
          );
        })()}
      </section>
    </div>
  );
}

export function AdminDashboardPage() {
  const { isDevPreview } = useAuth();

  const { data, isLoading, isFetching, isError, error, refetch } = useQuery({
    queryKey: ["admin-dashboard-counts", isDevPreview],
    queryFn: () => fetchAdminDashboardCounts(isDevPreview),
    retry: false,
  });

  const liveGatesQuery = useQuery({
    queryKey: ["scheduling-live-gates", isDevPreview],
    queryFn: () => probeLiveSchedulingCapabilities(isDevPreview),
    staleTime: 60_000,
    retry: false,
  });

  const handleRefresh = () => {
    void refetch().then((res) => {
      if (res.isError) {
        toast.error("Could not refresh dashboard counts", {
          description:
            res.error instanceof Error
              ? res.error.message
              : "Backend query returned an error.",
        });
      }
    });
  };

  return (
    <AdminDashboardView
      data={data}
      liveGates={liveGatesQuery.data}
      isLoading={isLoading}
      isFetching={isFetching}
      isError={isError}
      errorMessage={error instanceof Error ? error.message : undefined}
      onRefresh={handleRefresh}
    />
  );
}
