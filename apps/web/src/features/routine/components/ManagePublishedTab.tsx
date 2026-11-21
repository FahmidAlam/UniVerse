import {
  ArrowsClockwise,
  CalendarBlank,
  Info,
  MagnifyingGlass,
  PencilSimple,
  Plus,
  Trash,
} from "@phosphor-icons/react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useMemo, useRef, useState } from "react";
import { toast } from "sonner";
import {
  LedgerEmptyState,
  LedgerErrorRecovery,
  LedgerFilterEmpty,
  LedgerTableSkeleton,
} from "@/components/ui/AsyncStates";
import { Badge } from "@/components/ui/Badge";
import { Button } from "@/components/ui/Button";
import { ConfirmDialog } from "@/components/ui/ConfirmDialog";
import {
  DataLedgerTable,
  HoverCopyButton,
  type BulkActionItem,
  type DataLedgerColumn,
} from "@/components/ui/DataLedgerTable";
import { MasterDetailShell } from "@/components/ui/MasterDetailShell";
import { useWorkspaceShortcuts } from "@/core/hooks/useWorkspaceShortcuts";
import { ClockTime } from "@/core/utils/clockTime";
import { ACADEMIC_WEEK_DAYS } from "@/features/admin/services/facultyService";
import { fetchTimetableSettings } from "@/features/admin/services/settingsService";
import { useAuth } from "@/features/auth/AuthProvider";
import { RoutineSlotForm } from "@/features/routine/components/RoutineSlotForm";
import {
  createRoutineSlot,
  deleteRoutineSlots,
  fetchActiveRoutineVersion,
  fetchRoutines,
  updateRoutineSlot,
} from "@/features/routine/services/routineService";
import type { RoutineRow, RoutineWriteInput } from "@/features/routine/types";
import { cn } from "@/lib/utils";

type ScopeFilter = "all" | "cse" | "service" | "inactive";

export function ManagePublishedTab() {
  const { isDevPreview } = useAuth();
  const queryClient = useQueryClient();
  const searchInputRef = useRef<HTMLInputElement>(null);

  const [scopeFilter, setScopeFilter] = useState<ScopeFilter>("all");
  const [dayFilter, setDayFilter] = useState<string>("ALL");
  const [batchFilter, setBatchFilter] = useState<string>("ALL");
  const [searchQuery, setSearchQuery] = useState("");
  const [inspectorMode, setInspectorMode] = useState<
    { kind: "create" } | { kind: "edit"; row: RoutineRow } | null
  >(null);
  const [deleteIds, setDeleteIds] = useState<string[] | null>(null);
  const [lastCheckedAt, setLastCheckedAt] = useState<string>(() =>
    new Date().toLocaleTimeString([], {
      hour: "2-digit",
      minute: "2-digit",
      second: "2-digit",
    }),
  );

  useWorkspaceShortcuts({
    searchInputRef,
    onEscape: () => {
      if (deleteIds) {
        setDeleteIds(null);
        return;
      }
      if (inspectorMode) setInspectorMode(null);
    },
  });

  const routinesQuery = useQuery({
    queryKey: ["admin-routines", isDevPreview],
    queryFn: async () => {
      const rows = await fetchRoutines(isDevPreview);
      setLastCheckedAt(
        new Date().toLocaleTimeString([], {
          hour: "2-digit",
          minute: "2-digit",
          second: "2-digit",
        }),
      );
      return rows;
    },
    retry: false,
  });

  const activeVersionQuery = useQuery({
    queryKey: ["admin-routine-active-version", isDevPreview],
    queryFn: () => fetchActiveRoutineVersion(isDevPreview),
    retry: false,
  });

  const settingsQuery = useQuery({
    queryKey: ["admin-timetable-settings", isDevPreview],
    queryFn: () => fetchTimetableSettings(isDevPreview),
    retry: false,
  });

  const allRows = useMemo(() => routinesQuery.data ?? [], [routinesQuery.data]);

  const counts = useMemo(
    () => ({
      all: allRows.length,
      cse: allRows.filter((r) => !r.is_service && r.is_active !== false).length,
      service: allRows.filter((r) => r.is_service).length,
      inactive: allRows.filter((r) => r.is_active === false).length,
    }),
    [allRows],
  );

  const batchOptions = useMemo(
    () =>
      Array.from(new Set(allRows.map((r) => r.batch).filter(Boolean))).sort(
        (a, b) => a.localeCompare(b, undefined, { numeric: true }),
      ),
    [allRows],
  );

  const filteredRows = useMemo(() => {
    const q = searchQuery.trim().toLowerCase();
    return allRows.filter((row) => {
      if (scopeFilter === "cse" && (row.is_service || !row.is_active)) {
        return false;
      }
      if (scopeFilter === "service" && !row.is_service) return false;
      if (scopeFilter === "inactive" && row.is_active !== false) return false;
      if (dayFilter !== "ALL" && row.day !== dayFilter) return false;
      if (batchFilter !== "ALL" && row.batch !== batchFilter) return false;
      if (!q) return true;
      return (
        row.subject_code.toLowerCase().includes(q) ||
        row.subject.toLowerCase().includes(q) ||
        (row.teacher_code ?? "").toLowerCase().includes(q) ||
        (row.teacher_name ?? "").toLowerCase().includes(q) ||
        row.room.toLowerCase().includes(q) ||
        `${row.batch}-${row.section}`.toLowerCase().includes(q)
      );
    });
  }, [allRows, batchFilter, dayFilter, scopeFilter, searchQuery]);

  const saveMutation = useMutation({
    mutationFn: async (input: RoutineWriteInput) => {
      if (inspectorMode?.kind === "edit") {
        return updateRoutineSlot(inspectorMode.row.id, input, isDevPreview);
      }
      return createRoutineSlot(
        {
          ...input,
          routine_version_id: activeVersionQuery.data?.id ?? null,
        },
        isDevPreview,
      );
    },
    onSuccess: (saved) => {
      void queryClient.invalidateQueries({ queryKey: ["admin-routines"] });
      void queryClient.invalidateQueries({
        queryKey: ["admin-dashboard-counts"],
      });
      toast.success(
        inspectorMode?.kind === "edit"
          ? `Updated ${saved.subject_code}`
          : `Added ${saved.subject_code} (${saved.day})`,
      );
      setInspectorMode(null);
    },
    onError: (err) => {
      toast.error("Could not save routine slot", {
        description: err instanceof Error ? err.message : "Database error.",
      });
    },
  });

  const deleteMutation = useMutation({
    mutationFn: (ids: readonly string[]) =>
      deleteRoutineSlots(ids, isDevPreview),
    onSuccess: (_, ids) => {
      void queryClient.invalidateQueries({ queryKey: ["admin-routines"] });
      void queryClient.invalidateQueries({
        queryKey: ["admin-dashboard-counts"],
      });
      toast.success(`Removed ${ids.length} slot(s) from active routine`);
      if (
        inspectorMode?.kind === "edit" &&
        ids.includes(inspectorMode.row.id)
      ) {
        setInspectorMode(null);
      }
      setDeleteIds(null);
    },
    onError: (err) => {
      toast.error("Could not delete routine slot(s)", {
        description: err instanceof Error ? err.message : "Database error.",
      });
    },
  });

  const columns = useMemo<DataLedgerColumn<RoutineRow>[]>(
    () => [
      {
        id: "day_clock",
        header: "Day & Clock",
        accessor: (r) => `${r.day} ${r.time_start}`,
        cell: (r) => (
          <div>
            <div className="font-medium text-[var(--ink-primary)]">{r.day}</div>
            <div className="font-mono-tabular text-[11.5px] text-[var(--ink-muted)] whitespace-nowrap">
              {ClockTime.toHm(r.time_start)}–{ClockTime.toHm(r.time_end)}
            </div>
          </div>
        ),
      },
      {
        id: "course",
        header: "Course",
        accessor: (r) => r.subject_code,
        cell: (r) => (
          <div className="min-w-0">
            <div className="flex items-center gap-1.5">
              <span className="font-mono-tabular font-semibold whitespace-nowrap">
                {r.subject_code}
              </span>
              <HoverCopyButton value={r.subject_code} label="course code" />
              {r.is_service && (
                <Badge tone="neutral" mono>
                  Service
                </Badge>
              )}
            </div>
            <div className="max-w-[260px] truncate text-[12px] text-[var(--ink-secondary)]">
              {r.subject}
            </div>
          </div>
        ),
      },
      {
        id: "cohort",
        header: "Cohort",
        accessor: (r) => `${r.batch}-${r.section}`,
        cell: (r) => (
          <div className="flex items-center gap-1.5">
            <Badge tone={r.section.includes("+") ? "joint" : "neutral"} mono>
              {r.batch}-{r.section}
            </Badge>
          </div>
        ),
      },
      {
        id: "faculty",
        header: "Faculty",
        accessor: (r) => r.teacher_code ?? "TBA",
        cell: (r) => (
          <div className="flex items-center gap-1.5">
            <span className="font-mono-tabular font-medium">
              {r.teacher_code ?? "TBA"}
            </span>
            {r.teacher_code && (
              <HoverCopyButton value={r.teacher_code} label="teacher code" />
            )}
          </div>
        ),
      },
      {
        id: "room",
        header: "Room",
        accessor: (r) => r.room,
        cell: (r) => (
          <span className="font-mono-tabular whitespace-nowrap">{r.room}</span>
        ),
      },
    ],
    [],
  );

  const bulkActions = useMemo<BulkActionItem[]>(
    () => [
      {
        id: "bulk-delete",
        label: "Delete Selected",
        tone: "destructive",
        disabled: deleteMutation.isPending,
        onAction: (ids) => setDeleteIds(ids),
      },
    ],
    [deleteMutation.isPending],
  );

  if (routinesQuery.isLoading || settingsQuery.isLoading) {
    return <LedgerTableSkeleton rows={6} label="Loading published routine rows" />;
  }

  if (routinesQuery.isError) {
    return (
      <LedgerErrorRecovery
        title="Could not load active routine rows"
        message={
          routinesQuery.error instanceof Error
            ? routinesQuery.error.message
            : "Supabase routines query failed."
        }
        onRetry={() => void routinesQuery.refetch()}
      />
    );
  }

  return (
    <div className="space-y-4">
      {/* Honest F-23 Manual Edit Audit Disclosure */}
      <div
        role="status"
        data-testid="f23-manual-edit-disclosure"
        className="flex flex-wrap items-center justify-between gap-3 rounded-[var(--r-card)] border border-[var(--sem-joint-border)] bg-[var(--sem-joint-bg)] px-4 py-2.5 text-[12.5px] text-[var(--sem-joint-ink)]"
      >
        <div className="flex items-start gap-2">
          <Info size={16} className="mt-0.5 shrink-0" aria-hidden="true" />
          <span>
            Manual edits update live student and teacher schedules immediately
            without creating a new{" "}
            <code className="font-mono-tabular font-semibold">
              routine_versions
            </code>{" "}
            archive.
          </span>
        </div>
        {activeVersionQuery.data?.semester_label && (
          <Badge tone="neutral" mono>
            Active: {activeVersionQuery.data.semester_label}
          </Badge>
        )}
      </div>

      {/* Connected Filter Toolbar */}
      <div className="ledger-card flex flex-col gap-3 p-4">
        <div className="flex flex-wrap items-center justify-between gap-2.5">
          <div
            role="tablist"
            aria-label="Filter routine rows by category"
            className="flex flex-wrap items-center gap-1.5"
          >
            {(
              [
                { key: "all", label: `All (${counts.all})` },
                { key: "cse", label: `CSE Routine (${counts.cse})` },
                { key: "service", label: `Service Courses (${counts.service})` },
                { key: "inactive", label: `Inactive (${counts.inactive})` },
              ] as const
            ).map((opt) => {
              const active = scopeFilter === opt.key;
              return (
                <button
                  key={opt.key}
                  type="button"
                  role="tab"
                  aria-selected={active}
                  onClick={() => setScopeFilter(opt.key)}
                  className={cn(
                    "font-mono-tabular h-[32px] rounded-[6px] border px-3 text-[12px] whitespace-nowrap transition-colors",
                    active
                      ? "border-[var(--accent-pine)] bg-[var(--accent-pine-soft)] font-semibold text-[var(--accent-pine)]"
                      : "border-[var(--border-subtle)] bg-[var(--bg-surface)] text-[var(--ink-secondary)] hover:bg-[var(--surface-hover)]",
                  )}
                >
                  {opt.label}
                </button>
              );
            })}
          </div>

          <div className="flex flex-wrap items-center gap-2">
            <span className="font-mono-tabular text-[11.5px] text-[var(--ink-muted)]">
              Last checked {lastCheckedAt}
            </span>
            <Button
              variant="secondary"
              size="sm"
              disabled={routinesQuery.isFetching}
              onClick={() => void routinesQuery.refetch()}
            >
              <ArrowsClockwise
                size={14}
                className={routinesQuery.isFetching ? "animate-spin" : undefined}
                aria-hidden="true"
              />
              <span>Refresh</span>
            </Button>
            <Button
              variant="primary"
              size="sm"
              onClick={() => setInspectorMode({ kind: "create" })}
            >
              <Plus size={14} aria-hidden="true" />
              <span>Add Slot</span>
            </Button>
          </div>
        </div>

        <div className="flex flex-wrap items-center gap-2.5">
          <div className="relative min-w-[200px] flex-1">
            <MagnifyingGlass
              size={15}
              className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-[var(--ink-muted)]"
              aria-hidden="true"
            />
            <input
              ref={searchInputRef}
              type="search"
              aria-label="Search published routine rows"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              placeholder="Search code, title, teacher, room, batch (/) ..."
              className="h-[36px] w-full rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] pl-9 pr-3 text-[13px] text-[var(--ink-primary)] placeholder:text-[var(--ink-muted)] focus:border-[var(--ink-primary)] focus:outline-none"
            />
          </div>

          <select
            aria-label="Filter by day"
            value={dayFilter}
            onChange={(e) => setDayFilter(e.target.value)}
            className="h-[36px] rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-2.5 text-[12.5px] text-[var(--ink-primary)]"
          >
            <option value="ALL">All Days</option>
            {ACADEMIC_WEEK_DAYS.map((d) => (
              <option key={d} value={d}>
                {d}
              </option>
            ))}
          </select>

          <select
            aria-label="Filter by batch"
            value={batchFilter}
            onChange={(e) => setBatchFilter(e.target.value)}
            className="font-mono-tabular h-[36px] rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-2.5 text-[12.5px] text-[var(--ink-primary)]"
          >
            <option value="ALL">All Batches</option>
            {batchOptions.map((b) => (
              <option key={b} value={b}>
                Batch {b}
              </option>
            ))}
          </select>

          <span className="font-mono-tabular ml-auto text-[12px] text-[var(--ink-muted)]">
            Showing {filteredRows.length} of {allRows.length} slots
          </span>
        </div>
      </div>

      {/* Master-Detail Table + Slot Inspector */}
      <MasterDetailShell
        detailOpen={inspectorMode !== null}
        onRequestClose={() => setInspectorMode(null)}
        detailTitle={
          inspectorMode?.kind === "edit"
            ? `Edit ${inspectorMode.row.subject_code}`
            : "Add Routine Slot"
        }
        detailSubtitle={
          inspectorMode?.kind === "edit"
            ? `${inspectorMode.row.day} · Batch ${inspectorMode.row.batch}-${inspectorMode.row.section}`
            : "Direct write to active schedule with clash validation"
        }
        master={
          allRows.length === 0 ? (
            <LedgerEmptyState
              icon={<CalendarBlank size={20} aria-hidden="true" />}
              title="No published routine slots yet"
              description="Use the Generate Routine tab to solve a Course Distribution workbook, or add individual classes manually."
              actionLabel="Add First Slot"
              onAction={() => setInspectorMode({ kind: "create" })}
            />
          ) : filteredRows.length === 0 ? (
            <LedgerFilterEmpty
              message="No published slots match your current search or filter criteria."
              onReset={() => {
                setScopeFilter("all");
                setDayFilter("ALL");
                setBatchFilter("ALL");
                setSearchQuery("");
              }}
            />
          ) : (
            <DataLedgerTable
              data={filteredRows}
              columns={columns}
              getRowId={(r) => r.id}
              selectedRowId={
                inspectorMode?.kind === "edit" ? inspectorMode.row.id : null
              }
              isInactiveRow={(r) => r.is_active === false}
              onRowClick={(r) => setInspectorMode({ kind: "edit", row: r })}
              bulkActions={bulkActions}
              ariaLabel="Published routine slots"
              renderRowActions={(row) => (
                <>
                  <button
                    type="button"
                    aria-label={`Edit ${row.subject_code}`}
                    onClick={() => setInspectorMode({ kind: "edit", row })}
                    className="inline-flex h-7 w-7 items-center justify-center rounded-[5px] border border-[var(--border-subtle)] bg-[var(--bg-surface)] text-[var(--ink-secondary)] hover:bg-[var(--surface-hover)] hover:text-[var(--ink-primary)]"
                  >
                    <PencilSimple size={14} aria-hidden="true" />
                  </button>
                  <button
                    type="button"
                    aria-label={`Delete ${row.subject_code}`}
                    onClick={() => setDeleteIds([row.id])}
                    className="inline-flex h-7 w-7 items-center justify-center rounded-[5px] border border-[var(--border-subtle)] bg-[var(--bg-surface)] text-[var(--sem-conflict-ink)] hover:bg-[var(--sem-conflict-bg)]"
                  >
                    <Trash size={14} aria-hidden="true" />
                  </button>
                </>
              )}
            />
          )
        }
        detail={
          inspectorMode && settingsQuery.data ? (
            <RoutineSlotForm
              key={
                inspectorMode.kind === "edit"
                  ? inspectorMode.row.id
                  : "create-slot"
              }
              initialValue={
                inspectorMode.kind === "edit" ? inspectorMode.row : undefined
              }
              existingRows={allRows}
              ignoreId={
                inspectorMode.kind === "edit" ? inspectorMode.row.id : null
              }
              settings={settingsQuery.data}
              isSubmitting={saveMutation.isPending}
              submitLabel={
                inspectorMode.kind === "edit" ? "Save Slot" : "Create Slot"
              }
              onSubmit={async (input) => {
                await saveMutation.mutateAsync(input);
              }}
              onCancel={() => setInspectorMode(null)}
            />
          ) : null
        }
      />

      <ConfirmDialog
        open={deleteIds !== null}
        onOpenChange={(open) => {
          if (!open) setDeleteIds(null);
        }}
        title={
          deleteIds && deleteIds.length > 1
            ? `Delete ${deleteIds.length} routine slots?`
            : "Delete routine slot?"
        }
        description="Selected slots will be removed immediately from live student and faculty schedules."
        confirmLabel="Delete Slot(s)"
        tone="destructive"
        isPending={deleteMutation.isPending}
        onConfirm={() => {
          if (deleteIds && deleteIds.length > 0) {
            deleteMutation.mutate(deleteIds);
          }
        }}
      />
    </div>
  );
}
