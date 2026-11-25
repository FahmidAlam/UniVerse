import { zodResolver } from "@hookform/resolvers/zod";
import {
  ArrowRight,
  CaretDown,
  ChalkboardTeacher,
  Info,
  MagnifyingGlass,
  PencilSimple,
  Plus,
  Trash,
  WarningCircle,
  X,
} from "@phosphor-icons/react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useEffect, useMemo, useRef, useState } from "react";
import { Controller, useForm } from "react-hook-form";
import { Link, useSearchParams } from "react-router-dom";
import { toast } from "sonner";
import { z } from "zod";
import {
  LedgerEmptyState,
  LedgerErrorRecovery,
  LedgerFilterEmpty,
  LedgerTableSkeleton,
  StagedFeatureNotice,
} from "@/components/ui/AsyncStates";
import { Button } from "@/components/ui/Button";
import { ConfirmDialog } from "@/components/ui/ConfirmDialog";
import {
  DataLedgerTable,
  HoverCopyButton,
  type BulkActionItem,
  type DataLedgerColumn,
} from "@/components/ui/DataLedgerTable";
import { MasterDetailShell } from "@/components/ui/MasterDetailShell";
import { StickyDirtyBar } from "@/components/ui/StickyDirtyBar";
import { Switch } from "@/components/ui/Switch";
import { useWorkspaceShortcuts } from "@/core/hooks/useWorkspaceShortcuts";
import {
  ACADEMIC_WEEK_DAYS,
  bulkSetFacultyActive,
  createFaculty,
  deleteFacultyRecords,
  FACULTY_DESIGNATIONS,
  fetchFaculty,
  INSTITUTIONAL_DEPARTMENTS,
  isR7OffDayOutsideBounds,
  updateFaculty,
  type TimetableFacultyRecord,
} from "@/features/admin/services/facultyService";
import { useAuth } from "@/features/auth/AuthProvider";
import { cn } from "@/lib/utils";

type FacultyFilter = "all" | "active" | "inactive" | "r7-advisory";

const facultySchema = z.object({
  acronym: z
    .string()
    .trim()
    .min(2, "Acronym must be 2–10 characters.")
    .max(10, "Acronym must be 2–10 characters."),
  full_name: z.string().trim().max(120).optional(),
  dept: z.string().trim().max(40).optional(),
  designation: z.string().trim().max(60).optional(),
  off_days: z.array(z.string()),
  courses: z.array(z.string()),
  is_active: z.boolean(),
});

type FacultyFormValues = z.infer<typeof facultySchema>;

function toFormValues(fac: TimetableFacultyRecord | null): FacultyFormValues {
  if (!fac) {
    return {
      acronym: "",
      full_name: "",
      dept: "CSE",
      designation: "Lecturer",
      off_days: ["Thursday", "Friday"],
      courses: [],
      is_active: true,
    };
  }
  return {
    acronym: fac.acronym,
    full_name: fac.full_name ?? "",
    dept: fac.dept ?? "",
    designation: fac.designation ?? "",
    off_days: [...fac.off_days],
    courses: [...fac.courses],
    is_active: fac.is_active,
  };
}

export function ManageFacultyPage() {
  const { isDevPreview } = useAuth();
  const queryClient = useQueryClient();
  const [searchParams] = useSearchParams();
  const searchInputRef = useRef<HTMLInputElement>(null);

  const [search, setSearch] = useState("");
  const [filter, setFilter] = useState<FacultyFilter>(() =>
    searchParams.get("filter") === "r7" ? "r7-advisory" : "all",
  );
  const [availabilityOpen, setAvailabilityOpen] = useState(true);
  const [deptFilter, setDeptFilter] = useState<string>("all");

  useEffect(() => {
    if (searchParams.get("filter") === "r7") {
      setFilter("r7-advisory");
    }
  }, [searchParams]);
  const [courseInput, setCourseInput] = useState("");
  const [selectedId, setSelectedId] = useState<string | "new" | null>(null);
  const [pendingSelectId, setPendingSelectId] = useState<
    string | "new" | null | undefined
  >(undefined);
  const [deleteIds, setDeleteIds] = useState<string[] | null>(null);

  const {
    data: faculty = [],
    isLoading,
    isError,
    error,
    refetch,
  } = useQuery({
    queryKey: ["admin-timetable-faculty", isDevPreview],
    queryFn: () => fetchFaculty(isDevPreview),
    retry: false,
  });

  const selectedFaculty = useMemo(
    () =>
      selectedId && selectedId !== "new"
        ? faculty.find((f) => f.id === selectedId) ?? null
        : null,
    [faculty, selectedId],
  );

  const form = useForm<FacultyFormValues>({
    resolver: zodResolver(facultySchema),
    defaultValues: toFormValues(null),
  });

  const {
    register,
    control,
    watch,
    setValue,
    handleSubmit,
    reset,
    formState: { errors, isDirty },
  } = form;

  const watchedOffDays = watch("off_days");
  const watchedCourses = watch("courses");

  const openInspector = (target: string | "new" | null) => {
    if (isDirty && target !== selectedId) {
      setPendingSelectId(target);
      return;
    }
    setSelectedId(target);
    setCourseInput("");
    if (target === "new") {
      reset(toFormValues(null));
    } else if (target) {
      const rec = faculty.find((f) => f.id === target) ?? null;
      reset(toFormValues(rec));
    }
  };

  useWorkspaceShortcuts({
    searchInputRef,
    onEscape: () => {
      if (
        selectedId !== null &&
        pendingSelectId === undefined &&
        deleteIds === null
      ) {
        openInspector(null);
      }
    },
  });

  const saveMutation = useMutation({
    mutationFn: async (values: FacultyFormValues) => {
      const input = {
        acronym: values.acronym,
        full_name: values.full_name ?? null,
        dept: values.dept ?? null,
        designation: values.designation ?? null,
        off_days: values.off_days,
        courses: values.courses,
        is_active: values.is_active,
      };
      if (selectedId === "new" || !selectedFaculty) {
        return createFaculty(input, isDevPreview);
      }
      return updateFaculty(selectedFaculty.id, input, isDevPreview);
    },
    onSuccess: (saved) => {
      void queryClient.invalidateQueries({ queryKey: ["admin-timetable-faculty"] });
      void queryClient.invalidateQueries({ queryKey: ["admin-dashboard-counts"] });
      setSelectedId(saved.id);
      reset(toFormValues(saved));
      toast.success(`Saved faculty profile ${saved.acronym}`);
    },
    onError: (err) => {
      toast.error("Could not save faculty profile", {
        description:
          err instanceof Error ? err.message : "Database write failed.",
      });
    },
  });

  const bulkStatusMutation = useMutation({
    mutationFn: ({ ids, isActive }: { ids: string[]; isActive: boolean }) =>
      bulkSetFacultyActive(ids, isActive, isDevPreview),
    onSuccess: (_, vars) => {
      void queryClient.invalidateQueries({ queryKey: ["admin-timetable-faculty"] });
      void queryClient.invalidateQueries({ queryKey: ["admin-dashboard-counts"] });
      toast.success(
        `${vars.ids.length} faculty record${vars.ids.length > 1 ? "s" : ""} marked ${vars.isActive ? "active" : "inactive"}`,
      );
    },
    onError: (err) => {
      toast.error("Bulk update failed", {
        description: err instanceof Error ? err.message : "Update failed.",
      });
    },
  });

  const deleteMutation = useMutation({
    mutationFn: (ids: string[]) => deleteFacultyRecords(ids, isDevPreview),
    onSuccess: (_, ids) => {
      void queryClient.invalidateQueries({ queryKey: ["admin-timetable-faculty"] });
      void queryClient.invalidateQueries({ queryKey: ["admin-dashboard-counts"] });
      if (selectedId && ids.includes(selectedId)) {
        setSelectedId(null);
        reset(toFormValues(null));
      }
      setDeleteIds(null);
      toast.success(
        `Removed ${ids.length} faculty profile${ids.length > 1 ? "s" : ""}`,
      );
    },
    onError: (err) => {
      toast.error("Could not delete faculty profiles", {
        description: err instanceof Error ? err.message : "Delete failed.",
      });
    },
  });

  const deptOptions = useMemo(() => {
    const counts = new Map<string, number>();
    for (const f of faculty) {
      const d = f.dept?.trim() || "Unspecified";
      counts.set(d, (counts.get(d) ?? 0) + 1);
    }
    return Array.from(counts.entries()).sort(([a], [b]) => a.localeCompare(b));
  }, [faculty]);

  const filterCounts = useMemo(() => {
    const active = faculty.filter((f) => f.is_active).length;
    const inactive = faculty.filter((f) => !f.is_active).length;
    const r7 = faculty.filter((f) => isR7OffDayOutsideBounds(f.off_days)).length;
    return {
      all: faculty.length,
      active,
      inactive,
      r7,
    };
  }, [faculty]);

  const filteredFaculty = useMemo(() => {
    const q = search.trim().toLowerCase();
    return faculty.filter((f) => {
      if (filter === "active" && !f.is_active) return false;
      if (filter === "inactive" && f.is_active) return false;
      if (filter === "r7-advisory" && !isR7OffDayOutsideBounds(f.off_days)) {
        return false;
      }
      if (deptFilter !== "all") {
        const d = f.dept?.trim() || "Unspecified";
        if (d !== deptFilter) return false;
      }
      if (!q) return true;
      return (
        f.acronym.toLowerCase().includes(q) ||
        (f.full_name?.toLowerCase().includes(q) ?? false) ||
        (f.dept?.toLowerCase().includes(q) ?? false) ||
        f.courses.some((c) => c.toLowerCase().includes(q))
      );
    });
  }, [deptFilter, faculty, filter, search]);

  const addCourseTag = () => {
    const cleaned = courseInput.trim().toUpperCase();
    if (!cleaned) return;
    if (!watchedCourses.includes(cleaned)) {
      setValue("courses", [...watchedCourses, cleaned], { shouldDirty: true });
    }
    setCourseInput("");
  };

  const toggleOffDay = (day: string) => {
    const exists = watchedOffDays.includes(day);
    const next = exists
      ? watchedOffDays.filter((d) => d !== day)
      : ACADEMIC_WEEK_DAYS.filter(
          (d) => d === day || watchedOffDays.includes(d),
        );
    setValue("off_days", [...next], { shouldDirty: true });
  };

  const columns: DataLedgerColumn<TimetableFacultyRecord>[] = [
    {
      id: "acronym",
      header: "Acronym",
      accessor: (f) => f.acronym,
      cell: (f) => (
        <div className="flex items-center gap-1.5">
          <span className="font-mono-tabular font-semibold whitespace-nowrap">
            {f.acronym}
          </span>
          <HoverCopyButton value={f.acronym} label="faculty acronym" />
        </div>
      ),
    },
    {
      id: "full_name",
      header: "Name & Designation",
      accessor: (f) => f.full_name ?? "",
      cell: (f) => (
        <div className="min-w-0">
          <div className="truncate font-medium">
            {f.full_name ?? "Unnamed Instructor"}
          </div>
          {f.designation && (
            <div className="truncate text-[11.5px] text-[var(--ink-muted)]">
              {f.designation}
            </div>
          )}
        </div>
      ),
    },
    {
      id: "dept",
      header: "Dept",
      accessor: (f) => f.dept ?? "",
      cell: (f) => (
        <span className="font-mono-tabular text-[12.5px]">
          {f.dept ?? "—"}
        </span>
      ),
    },
    {
      id: "off_days",
      header: "Weekly Off-Days (R7)",
      accessor: (f) => f.off_days.length,
      cell: (f) => {
        const outsideR7 = isR7OffDayOutsideBounds(f.off_days);
        const offSet = new Set(f.off_days);
        return (
          <div className="flex flex-wrap items-center gap-2">
            <div
              data-testid="faculty-offday-strip"
              role="img"
              aria-label={
                f.off_days.length > 0
                  ? `Off-days: ${f.off_days.join(", ")}`
                  : "No declared off-days"
              }
              className={cn(
                "inline-flex items-center gap-0.5 rounded-[5px] p-0.5",
                outsideR7
                  ? "border border-[var(--sem-conflict-border)] bg-[var(--sem-conflict-bg)]/40"
                  : "border border-[var(--border-subtle)] bg-[var(--bg-surface)]",
              )}
            >
              {ACADEMIC_WEEK_DAYS.map((day) => {
                const isOff = offSet.has(day);
                return (
                  <span
                    key={day}
                    title={`${day}: ${isOff ? "Off-day" : "Available"}`}
                    className={cn(
                      "font-mono-tabular inline-flex h-[18px] w-[18px] items-center justify-center rounded-[3px] border text-[10px] font-semibold",
                      isOff
                        ? outsideR7
                          ? "border-[var(--sem-conflict-bar)]/45 bg-[var(--sem-conflict-bg)] text-[var(--sem-conflict-ink)]"
                          : "border-[var(--accent-brand)]/35 bg-[var(--accent-brand-soft)] text-[var(--accent-brand)]"
                        : "border-transparent bg-[var(--bg-surface)] text-[var(--ink-muted)]",
                    )}
                  >
                    {day.charAt(0)}
                  </span>
                );
              })}
            </div>
            {outsideR7 && (
              <span className="font-mono-tabular text-[11px] font-medium text-[var(--sem-conflict-ink)]">
                R7 ({f.off_days.length})
              </span>
            )}
          </div>
        );
      },
    },
    {
      id: "courses",
      header: "Courses",
      align: "right",
      accessor: (f) => f.courses.length,
      cell: (f) => <span className="font-mono-tabular">{f.courses.length}</span>,
    },
    {
      id: "is_active",
      header: "Status",
      accessor: (f) => (f.is_active ? "Active" : "Inactive"),
      cell: (f) => (
        <span
          className={cn(
            "font-mono-tabular text-[12px] font-medium",
            f.is_active ? "text-[var(--sem-lab-ink)]" : "text-[var(--ink-muted)]",
          )}
        >
          {f.is_active ? "Active" : "Inactive"}
        </span>
      ),
    },
  ];

  const bulkActions: BulkActionItem[] = [
    {
      id: "activate",
      label: "Activate",
      tone: "pine",
      disabled: bulkStatusMutation.isPending,
      onAction: (ids) => bulkStatusMutation.mutate({ ids, isActive: true }),
    },
    {
      id: "deactivate",
      label: "Deactivate",
      tone: "secondary",
      disabled: bulkStatusMutation.isPending,
      onAction: (ids) => bulkStatusMutation.mutate({ ids, isActive: false }),
    },
    {
      id: "delete",
      label: "Delete",
      tone: "destructive",
      disabled: deleteMutation.isPending,
      onAction: (ids) => setDeleteIds(ids),
    },
  ];

  return (
    <div className="flex flex-col gap-5">
      {isDevPreview && (
        <div
          role="status"
          className="flex items-center gap-2 rounded-[var(--r-card)] border border-[var(--accent-brand-border)] bg-[var(--accent-brand-soft)] px-4 py-2.5 text-[12.5px] text-[var(--accent-brand)]"
        >
          <Info size={16} className="shrink-0" aria-hidden="true" />
          <span>
            Illustrative preview — disconnected from live Supabase &amp; FastAPI
            backends. Edits remain local to this browser session.
          </span>
        </div>
      )}

      {/* Collapsible Weekly Faculty Availability Strip (Sun-Sat) */}
      {faculty.length > 0 && (
        <section
          data-testid="faculty-weekly-availability-strip"
          className="ledger-card overflow-hidden"
        >
          <button
            type="button"
            onClick={() => setAvailabilityOpen((v) => !v)}
            aria-expanded={availabilityOpen}
            className="flex w-full items-center justify-between gap-2 px-4 py-2 text-left text-[12px] font-semibold text-[var(--ink-primary)] hover:bg-[var(--surface-hover)]"
          >
            <span>
              Weekly Active Faculty Availability (
              {faculty.filter((f) => f.is_active).length} active)
            </span>
            <CaretDown
              size={13}
              aria-hidden="true"
              className={cn(
                "text-[var(--ink-muted)] transition-transform",
                !availabilityOpen && "-rotate-90",
              )}
            />
          </button>
          {availabilityOpen && (
            <div className="grid grid-cols-4 gap-px border-t border-[var(--border-subtle)] bg-[var(--border-subtle)] sm:grid-cols-7">
              {ACADEMIC_WEEK_DAYS.map((day) => {
                const activeFac = faculty.filter((f) => f.is_active);
                const avail = activeFac.filter(
                  (f) => !f.off_days.includes(day),
                ).length;
                return (
                  <div
                    key={day}
                    className="flex flex-col items-center justify-center bg-[var(--bg-elevated)] px-2 py-2"
                  >
                    <span className="font-mono-tabular text-[10.5px] font-semibold text-[var(--ink-muted)] uppercase">
                      {day.slice(0, 3)}
                    </span>
                    <span className="font-mono-tabular text-[13.5px] font-semibold text-[var(--ink-primary)]">
                      {avail}
                      <span className="text-[11px] font-normal text-[var(--ink-muted)]">
                        /{activeFac.length}
                      </span>
                    </span>
                  </div>
                );
              })}
            </div>
          )}
        </section>
      )}

      {/* Uniform 36px Schema-Backed Toolbar (No non-DB Permanent chip) */}
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="flex min-w-0 flex-1 flex-wrap items-center gap-2">
          <div className="relative flex w-full max-w-[260px] items-center">
            <MagnifyingGlass
              size={15}
              className="pointer-events-none absolute left-3 text-[var(--ink-muted)]"
              aria-hidden="true"
            />
            <input
              ref={searchInputRef}
              type="search"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Search faculty or course (/)"
              aria-label="Search faculty"
              className="h-[36px] w-full rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] pl-9 pr-3 text-[13px] text-[var(--ink-primary)] placeholder:text-[var(--ink-muted)] focus:border-[var(--accent-brand)]"
            />
          </div>

          <div
            role="group"
            aria-label="Filter faculty roster"
            className="flex flex-wrap items-center gap-1.5"
          >
            {(
              [
                { key: "all", label: `All (${filterCounts.all})` },
                { key: "active", label: `Active (${filterCounts.active})` },
                { key: "inactive", label: `Inactive (${filterCounts.inactive})` },
                {
                  key: "r7-advisory",
                  label: `R7 Off-Day Advisory (${filterCounts.r7})`,
                },
              ] as const
            ).map((opt) => {
              const active = filter === opt.key;
              return (
                <button
                  key={opt.key}
                  type="button"
                  aria-pressed={active}
                  onClick={() => setFilter(opt.key)}
                  className={cn(
                    "h-[36px] rounded-[var(--r-control)] border px-3 font-mono-tabular text-[12px] transition-colors whitespace-nowrap",
                    active
                      ? "border-[var(--accent-brand)] bg-[var(--accent-brand-soft)] font-semibold text-[var(--accent-brand)]"
                      : "border-[var(--border-subtle)] bg-[var(--bg-elevated)] text-[var(--ink-secondary)] hover:bg-[var(--surface-hover)] hover:text-[var(--ink-primary)]",
                  )}
                >
                  {opt.label}
                </button>
              );
            })}
          </div>

          <select
            aria-label="Filter by department"
            value={deptFilter}
            onChange={(e) => setDeptFilter(e.target.value)}
            className="h-[36px] rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-2.5 text-[12.5px] text-[var(--ink-primary)] focus:border-[var(--accent-brand)]"
          >
            <option value="all">All Depts ({faculty.length})</option>
            {deptOptions.map(([dept, count]) => (
              <option key={dept} value={dept}>
                {dept} ({count})
              </option>
            ))}
          </select>
        </div>

        <Button
          variant="primary"
          size="md"
          onClick={() => openInspector("new")}
        >
          <Plus size={15} aria-hidden="true" />
          <span>Add Faculty</span>
        </Button>
      </div>

      {/* Main Master-Detail Workspace */}
      <MasterDetailShell
        detailOpen={selectedId !== null}
        onRequestClose={() => openInspector(null)}
        detailTitle={
          selectedId === "new"
            ? "Add Faculty Profile"
            : selectedFaculty
              ? `Edit ${selectedFaculty.acronym}`
              : "Faculty Details"
        }
        detailSubtitle="Baseline faculty attributes & R7 off-day policy bounds"
        master={
          isLoading ? (
            <LedgerTableSkeleton label="Loading faculty roster" />
          ) : isError ? (
            <LedgerErrorRecovery
              title="Could not load faculty roster"
              message={
                error instanceof Error
                  ? error.message
                  : "Failed to read faculty from Supabase."
              }
              onRetry={() => void refetch()}
            />
          ) : faculty.length === 0 ? (
            <LedgerEmptyState
              icon={<ChalkboardTeacher size={20} aria-hidden="true" />}
              title="No faculty profiles configured yet"
              description="Add instructor acronyms, departments, designations, and weekly R7 off-day bounds prior to routine generation."
              actionLabel="Add First Faculty"
              onAction={() => openInspector("new")}
            />
          ) : filteredFaculty.length === 0 ? (
            <LedgerFilterEmpty
              onReset={() => {
                setSearch("");
                setFilter("all");
                setDeptFilter("all");
              }}
            />
          ) : (
            <DataLedgerTable
              ariaLabel="Faculty roster"
              data={filteredFaculty}
              columns={columns}
              getRowId={(f) => f.id}
              selectedRowId={selectedId}
              onRowClick={(f) => openInspector(f.id)}
              isInactiveRow={(f) => !f.is_active}
              bulkActions={bulkActions}
              renderRowActions={(f) => (
                <>
                  <button
                    type="button"
                    aria-label={`Edit ${f.acronym}`}
                    onClick={() => openInspector(f.id)}
                    className="inline-flex h-7 w-7 items-center justify-center rounded-[5px] text-[var(--ink-secondary)] hover:bg-[var(--surface-active)] hover:text-[var(--ink-primary)]"
                  >
                    <PencilSimple size={14} aria-hidden="true" />
                  </button>
                  <button
                    type="button"
                    aria-label={`Delete ${f.acronym}`}
                    onClick={() => setDeleteIds([f.id])}
                    className="inline-flex h-7 w-7 items-center justify-center rounded-[5px] text-[var(--sem-conflict-ink)] hover:bg-[var(--sem-conflict-bg)]"
                  >
                    <Trash size={14} aria-hidden="true" />
                  </button>
                </>
              )}
            />
          )
        }
        detail={
          <form
            id="faculty-inspector-form"
            onSubmit={handleSubmit((vals) => saveMutation.mutate(vals))}
            className="flex flex-col gap-4"
            noValidate
          >
            {selectedId && selectedId !== "new" && selectedFaculty && (
              <div className="flex items-center justify-between gap-2 rounded-[var(--r-control)] border border-[var(--border-subtle)] bg-[var(--bg-canvas)] px-3 py-2">
                <span className="font-mono-tabular text-[12px] text-[var(--ink-secondary)]">
                  Inspect weekly teaching slots
                </span>
                <Link
                  to={`/admin/timetable/grid?lens=faculty&entity=${encodeURIComponent(selectedFaculty.acronym)}&from=faculty`}
                  data-testid="view-faculty-schedule-link"
                  className="inline-flex items-center gap-1 text-[12px] font-semibold text-[var(--accent-brand)] no-underline hover:underline"
                >
                  <span>View Teaching Schedule</span>
                  <ArrowRight size={13} aria-hidden="true" />
                </Link>
              </div>
            )}

            {saveMutation.isError && (
              <div
                role="alert"
                className="rounded-[var(--r-control)] border border-[var(--sem-conflict-border)] bg-[var(--sem-conflict-bg)] px-3 py-2.5 text-[12.5px] text-[var(--sem-conflict-ink)]"
              >
                {saveMutation.error instanceof Error
                  ? saveMutation.error.message
                  : "Save failed."}
              </div>
            )}

            <div className="grid grid-cols-1 gap-3 sm:grid-cols-[120px_minmax(0,1fr)]">
              <div className="flex flex-col gap-1.5">
                <label
                  htmlFor="faculty-acronym"
                  className="text-[12.5px] font-semibold text-[var(--ink-primary)]"
                >
                  Acronym
                </label>
                <input
                  id="faculty-acronym"
                  type="text"
                  placeholder="EBH"
                  aria-invalid={Boolean(errors.acronym)}
                  {...register("acronym")}
                  className="font-mono-tabular h-[40px] rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-3 text-[13.5px] text-[var(--ink-primary)] uppercase focus:border-[var(--accent-brand)]"
                />
                {errors.acronym && (
                  <p className="text-[12px] font-medium text-[var(--sem-conflict-ink)]">
                    {errors.acronym.message}
                  </p>
                )}
              </div>

              <div className="flex flex-col gap-1.5">
                <label
                  htmlFor="faculty-name"
                  className="text-[12.5px] font-semibold text-[var(--ink-primary)]"
                >
                  Full Name
                </label>
                <input
                  id="faculty-name"
                  type="text"
                  placeholder="Instructor full name"
                  {...register("full_name")}
                  className="h-[40px] rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-3 text-[13.5px] text-[var(--ink-primary)] focus:border-[var(--accent-brand)]"
                />
              </div>
            </div>

            <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
              <div className="flex flex-col gap-1.5">
                <label
                  htmlFor="faculty-dept"
                  className="text-[12.5px] font-semibold text-[var(--ink-primary)]"
                >
                  Department
                </label>
                <input
                  id="faculty-dept"
                  list="faculty-dept-list"
                  placeholder="CSE"
                  {...register("dept")}
                  className="h-[40px] rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-3 text-[13.5px] text-[var(--ink-primary)] focus:border-[var(--accent-brand)]"
                />
                <datalist id="faculty-dept-list">
                  {INSTITUTIONAL_DEPARTMENTS.map((d) => (
                    <option key={d} value={d} />
                  ))}
                </datalist>
              </div>

              <div className="flex flex-col gap-1.5">
                <label
                  htmlFor="faculty-designation"
                  className="text-[12.5px] font-semibold text-[var(--ink-primary)]"
                >
                  Designation
                </label>
                <input
                  id="faculty-designation"
                  list="faculty-designation-list"
                  placeholder="Assistant Professor"
                  {...register("designation")}
                  className="h-[40px] rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-3 text-[13.5px] text-[var(--ink-primary)] focus:border-[var(--accent-brand)]"
                />
                <datalist id="faculty-designation-list">
                  {FACULTY_DESIGNATIONS.map((d) => (
                    <option key={d} value={d} />
                  ))}
                </datalist>
              </div>
            </div>

            {/* R7 Off-Day Bounds */}
            <div className="flex flex-col gap-2">
              <div className="flex items-center justify-between gap-2">
                <span className="text-[12.5px] font-semibold text-[var(--ink-primary)]">
                  Permanent Weekly Off-Days (R7)
                </span>
                <span className="font-mono-tabular text-[11.5px] text-[var(--ink-muted)]">
                  {watchedOffDays.length} selected
                </span>
              </div>

              <div className="flex flex-wrap gap-1.5">
                {ACADEMIC_WEEK_DAYS.map((day) => {
                  const selected = watchedOffDays.includes(day);
                  return (
                    <button
                      key={day}
                      type="button"
                      aria-pressed={selected}
                      onClick={() => toggleOffDay(day)}
                      className={cn(
                        "h-[34px] rounded-[var(--r-control)] border px-2.5 text-[12px] font-medium transition-colors",
                        selected
                          ? "border-[var(--accent-brand)] bg-[var(--accent-brand-soft)] font-semibold text-[var(--accent-brand)]"
                          : "border-[var(--border-control)] bg-[var(--bg-elevated)] text-[var(--ink-secondary)] hover:bg-[var(--surface-hover)]",
                      )}
                    >
                      {day.slice(0, 3)}
                    </button>
                  );
                })}
              </div>

              {isR7OffDayOutsideBounds(watchedOffDays) && (
                <div
                  role="status"
                  data-testid="r7-offday-advisory"
                  className="flex items-start gap-2 rounded-[var(--r-control)] border border-[var(--sem-joint-border)] bg-[var(--sem-joint-bg)] px-3 py-2 text-[12px] text-[var(--sem-joint-ink)]"
                >
                  <WarningCircle
                    size={15}
                    className="mt-0.5 shrink-0"
                    aria-hidden="true"
                  />
                  <span>
                    Rule R7 expects 2–3 off-days per 7-day week for permanent
                    faculty ({watchedOffDays.length} currently chosen). Save if
                    intentional for adjunct or special terms.
                  </span>
                </div>
              )}
            </div>

            {/* Courses Array Tag Editor */}
            <div className="flex flex-col gap-2">
              <label
                htmlFor="faculty-course-input"
                className="text-[12.5px] font-semibold text-[var(--ink-primary)]"
              >
                Associated Course Codes
              </label>
              <div className="flex gap-2">
                <input
                  id="faculty-course-input"
                  type="text"
                  value={courseInput}
                  onChange={(e) => setCourseInput(e.target.value)}
                  onKeyDown={(e) => {
                    if (e.key === "Enter") {
                      e.preventDefault();
                      addCourseTag();
                    }
                  }}
                  placeholder="e.g. CSE-3101"
                  className="font-mono-tabular h-[36px] flex-1 rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-3 text-[13px] uppercase focus:border-[var(--accent-brand)]"
                />
                <Button variant="secondary" size="md" onClick={addCourseTag}>
                  Add
                </Button>
              </div>
              {watchedCourses.length > 0 && (
                <div className="flex flex-wrap gap-1.5">
                  {watchedCourses.map((code) => (
                    <span
                      key={code}
                      className="inline-flex items-center gap-1 rounded-[5px] border border-[var(--border-subtle)] bg-[var(--bg-surface)] px-2 py-0.5 font-mono-tabular text-[12px] text-[var(--ink-primary)]"
                    >
                      <span>{code}</span>
                      <button
                        type="button"
                        aria-label={`Remove course ${code}`}
                        onClick={() =>
                          setValue(
                            "courses",
                            watchedCourses.filter((c) => c !== code),
                            { shouldDirty: true },
                          )
                        }
                        className="text-[var(--ink-muted)] hover:text-[var(--sem-conflict-ink)]"
                      >
                        <X size={12} aria-hidden="true" />
                      </button>
                    </span>
                  ))}
                </div>
              )}
            </div>

            <label
              htmlFor="faculty-is-active"
              className="flex cursor-pointer items-center justify-between gap-3 rounded-[var(--r-control)] border border-[var(--border-subtle)] bg-[var(--bg-surface)] px-3.5 py-3 text-[13px]"
            >
              <div>
                <div className="font-medium text-[var(--ink-primary)]">
                  Active Teaching Status
                </div>
                <div className="text-[11.5px] text-[var(--ink-muted)]">
                  Inactive faculty are retained without solver assignment
                </div>
              </div>
              <Controller
                name="is_active"
                control={control}
                render={({ field }) => (
                  <Switch
                    id="faculty-is-active"
                    checked={field.value}
                    onCheckedChange={field.onChange}
                  />
                )}
              />
            </label>

            <StagedFeatureNotice
              title="Staged Faculty Rules (R4, R5, R8, R9)"
              description="External service blocks (R4), adjunct guest 2-day windows (R5), preferred teaching slots (R8), and SUST half-day compactness flags (R9) remain staged pending database schema promotion."
            />

            <StickyDirtyBar
              isDirty={isDirty}
              isSaving={saveMutation.isPending}
              formId="faculty-inspector-form"
              saveLabel={
                selectedId === "new" ? "Create Faculty" : "Save Faculty"
              }
              onDiscard={() => {
                if (selectedId === "new") {
                  setSelectedId(null);
                  reset(toFormValues(null));
                } else {
                  reset(toFormValues(selectedFaculty));
                }
              }}
            />
          </form>
        }
      />

      <ConfirmDialog
        open={pendingSelectId !== undefined}
        onOpenChange={(open) => {
          if (!open) setPendingSelectId(undefined);
        }}
        title="Discard unsaved faculty edits?"
        description="You have unsaved changes in the Faculty Inspector. Discard them before switching or closing?"
        confirmLabel="Discard Changes"
        tone="destructive"
        onConfirm={() => {
          const target = pendingSelectId ?? null;
          setPendingSelectId(undefined);
          setSelectedId(target);
          setCourseInput("");
          if (target === "new") {
            reset(toFormValues(null));
          } else if (target) {
            const rec = faculty.find((f) => f.id === target) ?? null;
            reset(toFormValues(rec));
          } else {
            reset(toFormValues(null));
          }
        }}
      />

      <ConfirmDialog
        open={deleteIds !== null}
        onOpenChange={(open) => {
          if (!open) setDeleteIds(null);
        }}
        title={`Delete ${deleteIds?.length ?? 0} faculty profile${(deleteIds?.length ?? 0) === 1 ? "" : "s"}?`}
        description="This permanently removes the selected faculty records from baseline configuration."
        confirmLabel="Delete"
        tone="destructive"
        isPending={deleteMutation.isPending}
        onConfirm={() => {
          if (deleteIds) deleteMutation.mutate(deleteIds);
        }}
      />
    </div>
  );
}
