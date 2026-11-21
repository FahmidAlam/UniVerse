import {
  ArrowRight,
  ArrowsClockwise,
  CheckCircle,
  Info,
  LockSimple,
  WarningCircle,
} from "@phosphor-icons/react";
import { useQuery } from "@tanstack/react-query";
import { useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { toast } from "sonner";
import { Badge } from "@/components/ui/Badge";
import {
  formatCapabilityStatusLabel,
  SUBFEATURE_CAPABILITIES,
} from "@/core/capabilities";
import {
  fetchAdminDashboardCounts,
  type AdminDashboardCounts,
} from "@/features/admin/services/adminDashboardService";
import { useAuth } from "@/features/auth/AuthProvider";
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

export interface AdminDashboardViewProps {
  data?: AdminDashboardCounts;
  isLoading: boolean;
  isFetching: boolean;
  isError: boolean;
  errorMessage?: string;
  onRefresh: () => void;
}

export function AdminDashboardView({
  data,
  isLoading,
  isFetching,
  isError,
  errorMessage,
  onRefresh,
}: AdminDashboardViewProps) {
  const [stageFilter, setStageFilter] = useState<ReadinessFilter>("all");

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
          <div className="h-[170px] animate-pulse rounded-[var(--r-card)] border border-[var(--border-subtle)] bg-[var(--bg-elevated)]" />
          <div className="h-[170px] animate-pulse rounded-[var(--r-card)] border border-[var(--border-subtle)] bg-[var(--bg-elevated)]" />
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
  const hasMissingBaseline =
    data.timetableRooms === 0 ||
    data.timetableFaculty === 0 ||
    hasEmptyEligibility;

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
          className="flex flex-wrap items-center justify-between gap-3 rounded-[var(--r-card)] border border-[var(--accent-pine-border)] bg-[var(--accent-pine-soft)] px-4 py-2.5 text-[12.5px] text-[var(--accent-pine)]"
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
                Current counts show {data.timetableRooms} room pools,{" "}
                {data.timetableFaculty} faculty profiles, and{" "}
                {data.timetableCourseEligibility} course eligibility links.
                Complete all three baseline stages before publishing a new
                semester schedule.
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

      {/* 4-Stage Routine Readiness Checklist (Dissolved 1px Ledger Rows + Upfront Counts) */}
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
                      ? "border-[var(--accent-pine)] bg-[var(--accent-pine-soft)] font-semibold text-[var(--accent-pine)]"
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
                className="group grid grid-cols-[24px_24px_minmax(0,1fr)_auto] items-center gap-3 px-5 py-3.5 transition-colors hover:bg-[var(--surface-hover)] sm:grid-cols-[24px_24px_minmax(0,1fr)_170px_150px]"
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
                  <div className="truncate text-[12px] text-[var(--ink-secondary)]">
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
                <div className="row-reveal-action col-span-4 flex justify-end sm:col-span-1">
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

        <div className="ledger-card overflow-hidden">
          <div className="flex items-center justify-between gap-2 border-b border-[var(--border-subtle)] px-4 py-3">
            <span className="text-[13.5px] font-semibold text-[var(--ink-primary)]">
              Track 2 &amp; Feature Governance
            </span>
            <Badge tone="joint" mono>
              <LockSimple size={12} aria-hidden="true" />
              <span>Gates A–D</span>
            </Badge>
          </div>
          <div className="divide-y divide-[var(--border-subtle)] text-[12.5px]">
            {SUBFEATURE_CAPABILITIES.map((cap) => (
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
                  {formatCapabilityStatusLabel(cap.status)}
                </Badge>
              </div>
            ))}
          </div>
        </div>
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
      isLoading={isLoading}
      isFetching={isFetching}
      isError={isError}
      errorMessage={error instanceof Error ? error.message : undefined}
      onRefresh={handleRefresh}
    />
  );
}
