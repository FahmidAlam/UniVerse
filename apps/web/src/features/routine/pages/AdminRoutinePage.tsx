import {
  ArrowUpRight,
  ClockCounterClockwise,
  GridFour,
  ListChecks,
  LockSimple,
  Play,
  Table,
  UploadSimple,
} from "@phosphor-icons/react";
import { useQuery } from "@tanstack/react-query";
import { motion, useReducedMotion } from "motion/react";
import { lazy, Suspense } from "react";
import { Link, useSearchParams } from "react-router-dom";
import { LedgerTableSkeleton } from "@/components/ui/AsyncStates";
import { Badge } from "@/components/ui/Badge";
import { useAuth } from "@/features/auth/AuthProvider";
import { AcademicTimetableMatrix } from "@/features/routine/components/AcademicTimetableMatrix";
import { DistributionStudioTab } from "@/features/routine/components/DistributionStudioTab";
import { GenerateRoutineTab } from "@/features/routine/components/GenerateRoutineTab";
import { ManagePublishedTab } from "@/features/routine/components/ManagePublishedTab";
import { useRoutineOperationsStore } from "@/features/routine/store/routineOperationsStore";
import { probeLiveSchedulingCapabilities } from "@/features/scheduling/services/schedulingCapabilities";
import { cn } from "@/lib/utils";

const RoutineArchiveTab = lazy(
  () => import("@/features/routine/components/RoutineArchiveTab"),
);

const UploadRoutineTab = lazy(
  () => import("@/features/routine/components/UploadRoutineTab"),
);

export type RoutineTabId =
  | "distribution"
  | "grid"
  | "manage"
  | "generate"
  | "archive"
  | "upload";

const ROUTINE_TABS: readonly {
  id: RoutineTabId;
  label: string;
  Icon: typeof GridFour;
  badge?: string;
}[] = [
  { id: "distribution", label: "Distribution Sheet", Icon: Table },
  { id: "grid", label: "2D Grid", Icon: GridFour },
  { id: "manage", label: "Manage Published", Icon: ListChecks },
  { id: "generate", label: "Generate Routine", Icon: Play },
  { id: "archive", label: "Archive", Icon: ClockCounterClockwise },
  { id: "upload", label: "Upload Routine", Icon: UploadSimple },
];

function resolveRoutineTab(raw: string | null): RoutineTabId {
  if (
    raw === "distribution" ||
    raw === "manage" ||
    raw === "generate" ||
    raw === "archive" ||
    raw === "upload"
  ) {
    return raw;
  }
  return "grid";
}

export function AdminRoutinePage() {
  const { isDevPreview } = useAuth();
  const [searchParams, setSearchParams] = useSearchParams();
  const activeTab = resolveRoutineTab(searchParams.get("tab"));
  const { solverPhase, setActiveSource, setGenerateInputMode } =
    useRoutineOperationsStore();
  const prefersReducedMotion = useReducedMotion() ?? false;

  const gateProbeQuery = useQuery({
    queryKey: ["scheduling-live-gates", isDevPreview],
    queryFn: () => probeLiveSchedulingCapabilities(isDevPreview),
    staleTime: 60_000,
    retry: false,
  });

  const gates = gateProbeQuery.data;
  const gatesABCLive = Boolean(
    gates?.gateA.unlocked && gates?.gateB.unlocked && gates?.gateC.unlocked,
  );
  const gatesABLive = Boolean(gates?.gateA.unlocked && gates?.gateB.unlocked);
  const gateAOnlyLive = Boolean(gates?.gateA.unlocked && !gates?.gateB.unlocked);
  const workbenchBadgeLabel = gatesABCLive
    ? "Gates A–C Live · D Locked"
    : gatesABLive
      ? "Gates A–B Live · C–D Locked"
      : gateAOnlyLive
        ? "Gate A Live · B–D Locked"
        : "Locked · Gates A–D";

  const selectTab = (tab: RoutineTabId) => {
    setSearchParams({ tab }, { replace: false });
  };

  return (
    <div className="space-y-4">
      <header className="no-print flex flex-wrap items-end justify-between gap-4 border-b border-[var(--border-subtle)] pb-4">
        <div>
          <h1 className="font-editorial text-[24px] font-semibold tracking-[-0.02em] text-[var(--ink-primary)]">
            Routine Operations
          </h1>
          <p className="mt-1 max-w-[68ch] text-[13.5px] leading-[1.55] text-[var(--ink-secondary)]">
            Track 1 operational console for inspecting the 2D weekly timetable,
            managing published class slots, uploading rendered workbooks, and
            running CP-SAT schedule generation.
          </p>
        </div>

        {/* Compact truthful Track 2 Workbench gate status link */}
        <Link
          to="/admin/scheduling"
          data-testid="track2-workbench-status-link"
          className="inline-flex h-[34px] items-center gap-2 rounded-[var(--r-control)] border border-[var(--border-subtle)] bg-[var(--bg-elevated)] px-3 text-[12px] font-medium text-[var(--ink-secondary)] no-underline hover:bg-[var(--surface-hover)] hover:text-[var(--ink-primary)]"
        >
          <LockSimple size={13} aria-hidden="true" />
          <span>Track 2 Workbench</span>
          <Badge
            tone={gatesABLive || gateAOnlyLive ? "theory" : "joint"}
            dot={false}
            mono
            data-testid="track2-workbench-gate-badge"
          >
            <span
              className={cn(
                "h-1.5 w-1.5 rounded-full",
                gatesABLive || gateAOnlyLive
                  ? "bg-[var(--sem-pine-bar)]"
                  : "bg-[var(--sem-joint-bar)]",
              )}
              aria-hidden="true"
            />
            {workbenchBadgeLabel}
          </Badge>
        </Link>
      </header>

      {/* URL-Synced Tab Strip (Lazy mounts ONLY the active tab) */}
      <div className="no-print flex flex-wrap items-center justify-between gap-3 border-b border-[var(--border-subtle)] pb-3">
        <div
          role="tablist"
          aria-label="Routine operations workspaces"
          className="flex flex-wrap gap-1.5"
        >
          {ROUTINE_TABS.map(({ id, label, Icon, badge }) => {
            const active = activeTab === id;
            return (
              <button
                key={id}
                type="button"
                role="tab"
                aria-selected={active}
                onClick={() => selectTab(id)}
                className={cn(
                  "inline-flex h-9 items-center gap-2 rounded-[var(--r-control)] border px-3 text-[13px] whitespace-nowrap transition-colors",
                  active
                    ? "border-[var(--border-strong)] bg-[var(--bg-raised)] font-semibold text-[var(--ink-primary)] shadow-[inset_0_-2px_0_var(--accent-brand)]"
                    : "border-[var(--border-subtle)] bg-[var(--bg-elevated)] font-medium text-[var(--ink-secondary)] hover:bg-[var(--surface-hover)] hover:text-[var(--ink-primary)]",
                )}
              >
                <Icon
                  size={15}
                  className={active ? "text-[var(--accent-brand)]" : undefined}
                  aria-hidden="true"
                />
                <span>{label}</span>
                {id === "generate" &&
                  (solverPhase === "submitting" ||
                    solverPhase === "polling") && (
                    <span
                      className="h-2 w-2 animate-pulse rounded-full bg-[var(--sem-joint-bar)]"
                      aria-label="Solver running"
                    />
                  )}
                {badge && (
                  <span className="font-mono-tabular inline-flex items-center gap-1 rounded-[var(--r-pill)] border border-[var(--border-strong)] bg-[var(--bg-surface)] px-1.5 py-[1px] text-[10px] font-medium text-[var(--ink-secondary)]">
                    <span className="h-1.5 w-1.5 rounded-full bg-[var(--sem-joint-bar)]" aria-hidden="true" />
                    {badge}
                  </span>
                )}
              </button>
            );
          })}
        </div>

        {activeTab === "grid" && (
          <Link
            to="/admin/timetable/grid"
            className="btn-secondary !h-[34px] !px-3 !text-[12px] no-underline"
          >
            <span>Full-Screen Matrix</span>
            <ArrowUpRight size={14} aria-hidden="true" />
          </Link>
        )}
      </div>

      {/* Lazy-Mounted Active Tab Content */}
      <motion.div
        key={activeTab}
        initial={prefersReducedMotion ? false : { opacity: 0, y: 4 }}
        animate={{ opacity: 1, y: 0 }}
        transition={
          prefersReducedMotion
            ? { duration: 0 }
            : { duration: 0.15, ease: [0.16, 1, 0.3, 1] }
        }
      >
        {activeTab === "distribution" && (
          <DistributionStudioTab
            onGenerateFromSheet={() => {
              setGenerateInputMode("sheet");
              selectTab("generate");
            }}
          />
        )}
        {activeTab === "grid" && <AcademicTimetableMatrix />}
        {activeTab === "manage" && <ManagePublishedTab />}
        {activeTab === "generate" && (
          <GenerateRoutineTab
            onInspectInGrid={() => {
              setActiveSource("candidate");
              selectTab("grid");
            }}
            onOpenDistributionSheet={() => selectTab("distribution")}
          />
        )}
        {activeTab === "archive" && (
          <Suspense
            fallback={
              <LedgerTableSkeleton rows={6} label="Loading routine archive" />
            }
          >
            <RoutineArchiveTab />
          </Suspense>
        )}
        {activeTab === "upload" && (
          <Suspense
            fallback={
              <LedgerTableSkeleton rows={5} label="Loading routine uploader" />
            }
          >
            <UploadRoutineTab />
          </Suspense>
        )}
      </motion.div>
    </div>
  );
}
