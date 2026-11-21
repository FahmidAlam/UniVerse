import {
  GridFour,
  ListChecks,
  LockSimple,
  Play,
  UploadSimple,
} from "@phosphor-icons/react";
import { Link, useSearchParams } from "react-router-dom";
import { Badge } from "@/components/ui/Badge";
import { AcademicTimetableMatrix } from "@/features/routine/components/AcademicTimetableMatrix";
import { GenerateRoutineTab } from "@/features/routine/components/GenerateRoutineTab";
import { ManagePublishedTab } from "@/features/routine/components/ManagePublishedTab";
import { UploadRoutineGatedTab } from "@/features/routine/components/UploadRoutineGatedTab";
import { useRoutineOperationsStore } from "@/features/routine/store/routineOperationsStore";
import { cn } from "@/lib/utils";

export type RoutineTabId = "grid" | "manage" | "generate" | "upload";

const ROUTINE_TABS: readonly {
  id: RoutineTabId;
  label: string;
  Icon: typeof GridFour;
  badge?: string;
}[] = [
  { id: "grid", label: "2D Grid", Icon: GridFour },
  { id: "manage", label: "Manage Published", Icon: ListChecks },
  { id: "generate", label: "Generate Routine", Icon: Play },
  {
    id: "upload",
    label: "Upload Routine",
    Icon: UploadSimple,
    badge: "Phase 3B",
  },
];

function resolveRoutineTab(raw: string | null): RoutineTabId {
  if (raw === "manage" || raw === "generate" || raw === "upload") return raw;
  return "grid";
}

export function AdminRoutinePage() {
  const [searchParams, setSearchParams] = useSearchParams();
  const activeTab = resolveRoutineTab(searchParams.get("tab"));
  const { solverPhase, setActiveSource } = useRoutineOperationsStore();

  const selectTab = (tab: RoutineTabId) => {
    setSearchParams({ tab }, { replace: false });
  };

  return (
    <div className="space-y-4">
      <header className="flex flex-wrap items-end justify-between gap-4 border-b border-[var(--border-subtle)] pb-4">
        <div>
          <h1 className="font-editorial text-[24px] font-semibold tracking-[-0.02em] text-[var(--ink-primary)]">
            Routine Operations
          </h1>
          <p className="mt-1 max-w-[68ch] text-[13.5px] leading-[1.55] text-[var(--ink-secondary)]">
            Track 1 operational console for inspecting the 2D weekly timetable,
            managing published class slots, and running CP-SAT schedule
            generation.
          </p>
        </div>

        {/* Compact non-intrusive Track 2 Workbench status link */}
        <Link
          to="/admin/scheduling"
          className="inline-flex h-[34px] items-center gap-2 rounded-[var(--r-control)] border border-[var(--border-subtle)] bg-[var(--bg-elevated)] px-3 text-[12px] font-medium text-[var(--ink-secondary)] no-underline hover:bg-[var(--surface-hover)] hover:text-[var(--ink-primary)]"
        >
          <LockSimple size={13} aria-hidden="true" />
          <span>Track 2 Workbench</span>
          <Badge tone="joint" mono>
            Locked · Gates A–D
          </Badge>
        </Link>
      </header>

      {/* URL-Synced Tab Strip (Lazy mounts ONLY the active tab) */}
      <div className="flex flex-wrap items-center justify-between gap-3 border-b border-[var(--border-subtle)] pb-3">
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
                  "inline-flex h-9 items-center gap-2 rounded-[var(--r-control)] border px-3 text-[13px] font-medium whitespace-nowrap transition-colors",
                  active
                    ? "border-[var(--ink-primary)] bg-[var(--ink-primary)] text-[var(--action-primary-ink)]"
                    : "border-[var(--border-subtle)] bg-[var(--bg-elevated)] text-[var(--ink-secondary)] hover:bg-[var(--surface-hover)] hover:text-[var(--ink-primary)]",
                )}
              >
                <Icon size={15} aria-hidden="true" />
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
                  <span
                    className={cn(
                      "font-mono-tabular rounded px-1.5 py-[1px] text-[10px]",
                      active
                        ? "bg-[var(--bg-elevated)]/20 text-[var(--action-primary-ink)]"
                        : "bg-[var(--bg-canvas)] text-[var(--ink-muted)]",
                    )}
                  >
                    {badge}
                  </span>
                )}
              </button>
            );
          })}
        </div>
      </div>

      {/* Lazy-Mounted Active Tab Content */}
      {activeTab === "grid" && <AcademicTimetableMatrix />}
      {activeTab === "manage" && <ManagePublishedTab />}
      {activeTab === "generate" && (
        <GenerateRoutineTab
          onInspectInGrid={() => {
            setActiveSource("candidate");
            selectTab("grid");
          }}
        />
      )}
      {activeTab === "upload" && <UploadRoutineGatedTab />}
    </div>
  );
}
