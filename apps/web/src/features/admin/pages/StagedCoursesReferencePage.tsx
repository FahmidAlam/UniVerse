import { zodResolver } from "@hookform/resolvers/zod";
import {
  ArrowRight,
  BookOpen,
  LockSimple,
  MagnifyingGlass,
  PencilSimple,
  Plus,
  Sparkle,
  Trash,
} from "@phosphor-icons/react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useMemo, useRef, useState } from "react";
import { Controller, useForm } from "react-hook-form";
import { Link } from "react-router-dom";
import { toast } from "sonner";
import { z } from "zod";
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
import { StickyDirtyBar } from "@/components/ui/StickyDirtyBar";
import { Switch } from "@/components/ui/Switch";
import { useWorkspaceShortcuts } from "@/core/hooks/useWorkspaceShortcuts";
import {
  bulkSetCatalogCoursesActive,
  createCatalogCourse,
  deleteCatalogCourses,
  fetchCatalogCourses,
  seedCoursesFromActiveRoutine,
  updateCatalogCourse,
  type CatalogCourseRecord,
} from "@/features/admin/services/coursesService";
import { INSTITUTIONAL_DEPARTMENTS } from "@/features/admin/services/facultyService";
import { useAuth } from "@/features/auth/AuthProvider";
import { fetchRoutines } from "@/features/routine/services/routineService";
import { cn } from "@/lib/utils";

type CourseFilter = "all" | "theory" | "lab" | "service" | "physics_lab" | "inactive";

const courseFormSchema = z.object({
  code: z.string().trim().min(2, "Course code is required.").max(30),
  title: z.string().trim().min(2, "Course title is required.").max(160),
  dept_code: z.string().trim().min(1, "Department is required.").max(20),
  credit: z
    .string()
    .trim()
    .refine(
      (v) => {
        const n = Number(v);
        return Number.isFinite(n) && n > 0 && n <= 12;
      },
      "Credit must be between 0.5 and 12.",
    ),
  class_type: z.enum(["theory", "lab"]),
  is_service: z.boolean(),
  is_physics_lab: z.boolean(),
  default_weekly_sessions: z
    .string()
    .trim()
    .refine(
      (v) =>
        v === "" ||
        (/^\d+$/.test(v) && Number.parseInt(v, 10) >= 1 && Number.parseInt(v, 10) <= 14),
      "Weekly sessions must be 1–14 or blank.",
    ),
  is_active: z.boolean(),
  notes: z.string().trim().max(400).optional(),
});

type CourseFormValues = z.infer<typeof courseFormSchema>;

function toFormValues(course: CatalogCourseRecord | null): CourseFormValues {
  if (!course) {
    return {
      code: "",
      title: "",
      dept_code: "CSE",
      credit: "3.0",
      class_type: "theory",
      is_service: false,
      is_physics_lab: false,
      default_weekly_sessions: "",
      is_active: true,
      notes: "",
    };
  }
  return {
    code: course.code,
    title: course.title,
    dept_code: course.dept_code,
    credit: String(course.credit),
    class_type: course.class_type,
    is_service: course.is_service,
    is_physics_lab: course.is_physics_lab,
    default_weekly_sessions:
      course.default_weekly_sessions !== null
        ? String(course.default_weekly_sessions)
        : "",
    is_active: course.is_active,
    notes: course.notes ?? "",
  };
}

export function ManageCoursesPage() {
  const { isDevPreview } = useAuth();
  const queryClient = useQueryClient();
  const searchInputRef = useRef<HTMLInputElement>(null);
  const [search, setSearch] = useState("");
  const [filter, setFilter] = useState<CourseFilter>("all");
  const [legacyTypeFilter, setLegacyTypeFilter] = useState<"all" | "cse" | "service">("all");
  const [selectedId, setSelectedId] = useState<string | "new" | null>(null);
  const [pendingSelectId, setPendingSelectId] = useState<
    string | "new" | null | undefined
  >(undefined);
  const [deleteIds, setDeleteIds] = useState<string[] | null>(null);

  const catalogQuery = useQuery({
    queryKey: ["admin-catalog-courses", isDevPreview],
    queryFn: () => fetchCatalogCourses(isDevPreview),
    retry: false,
  });

  const routinesQuery = useQuery({
    queryKey: ["admin-routines", isDevPreview],
    queryFn: () => fetchRoutines(isDevPreview),
    retry: false,
  });

  const isLiveCatalog = catalogQuery.data?.live ?? false;
  const courses = useMemo(
    () => catalogQuery.data?.courses ?? [],
    [catalogQuery.data?.courses],
  );

  const selectedCourse = useMemo(
    () =>
      selectedId && selectedId !== "new"
        ? courses.find((c) => c.id === selectedId) ?? null
        : null,
    [courses, selectedId],
  );

  const form = useForm<CourseFormValues>({
    resolver: zodResolver(courseFormSchema),
    defaultValues: toFormValues(null),
  });

  const {
    register,
    control,
    watch,
    handleSubmit,
    reset,
    formState: { errors, isDirty },
  } = form;

  const watchedClassType = watch("class_type");

  const openInspector = (target: string | "new" | null) => {
    if (isDirty && target !== selectedId) {
      setPendingSelectId(target);
      return;
    }
    setSelectedId(target);
    if (target === "new") {
      reset(toFormValues(null));
    } else if (target) {
      const rec = courses.find((c) => c.id === target) ?? null;
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
    mutationFn: async (values: CourseFormValues) => {
      const input = {
        code: values.code,
        title: values.title,
        dept_code: values.dept_code,
        credit: Number.parseFloat(values.credit),
        class_type: values.class_type,
        is_service: values.is_service,
        is_physics_lab:
          values.class_type === "lab" ? values.is_physics_lab : false,
        default_weekly_sessions: values.default_weekly_sessions.trim()
          ? Number.parseInt(values.default_weekly_sessions.trim(), 10)
          : null,
        is_active: values.is_active,
        notes: values.notes ?? null,
      };
      if (selectedId === "new" || !selectedCourse) {
        return createCatalogCourse(input, isDevPreview);
      }
      return updateCatalogCourse(selectedCourse.id, input, isDevPreview);
    },
    onSuccess: (saved) => {
      void queryClient.invalidateQueries({ queryKey: ["admin-catalog-courses"] });
      setSelectedId(saved.id);
      reset(toFormValues(saved));
      toast.success(`Saved course ${saved.code}`);
    },
    onError: (err) => {
      toast.error("Could not save course", {
        description: err instanceof Error ? err.message : "Database write failed.",
      });
    },
  });

  const seedMutation = useMutation({
    mutationFn: async () => {
      const routines = routinesQuery.data ?? (await fetchRoutines(isDevPreview));
      return seedCoursesFromActiveRoutine(routines, courses, isDevPreview);
    },
    onSuccess: (res) => {
      void queryClient.invalidateQueries({ queryKey: ["admin-catalog-courses"] });
      if (res.insertedCount === 0) {
        toast.info("All active routine courses are already in the catalog", {
          description: `${res.skippedCount} existing course(s) preserved.`,
        });
      } else {
        toast.success(`Imported ${res.insertedCount} course(s) from active routine`);
      }
    },
    onError: (err) => {
      toast.error("Could not seed courses from active routine", {
        description: err instanceof Error ? err.message : "Import failed.",
      });
    },
  });

  const bulkStatusMutation = useMutation({
    mutationFn: ({ ids, isActive }: { ids: string[]; isActive: boolean }) =>
      bulkSetCatalogCoursesActive(ids, isActive, isDevPreview),
    onSuccess: (_, vars) => {
      void queryClient.invalidateQueries({ queryKey: ["admin-catalog-courses"] });
      toast.success(
        `${vars.ids.length} course(s) marked ${vars.isActive ? "active" : "inactive"}`,
      );
    },
    onError: (err) => {
      toast.error("Bulk update failed", {
        description: err instanceof Error ? err.message : "Update failed.",
      });
    },
  });

  const deleteMutation = useMutation({
    mutationFn: (ids: string[]) => deleteCatalogCourses(ids, isDevPreview),
    onSuccess: (_, ids) => {
      void queryClient.invalidateQueries({ queryKey: ["admin-catalog-courses"] });
      if (selectedId && ids.includes(selectedId)) {
        setSelectedId(null);
        reset(toFormValues(null));
      }
      setDeleteIds(null);
      toast.success(`Removed ${ids.length} course(s)`);
    },
    onError: (err) => {
      toast.error("Could not delete courses", {
        description: err instanceof Error ? err.message : "Delete failed.",
      });
    },
  });

  const filterCounts = useMemo(
    () => ({
      all: courses.length,
      theory: courses.filter((c) => c.class_type === "theory").length,
      lab: courses.filter((c) => c.class_type === "lab").length,
      service: courses.filter((c) => c.is_service).length,
      physics_lab: courses.filter((c) => c.is_physics_lab).length,
      inactive: courses.filter((c) => !c.is_active).length,
    }),
    [courses],
  );

  const filteredLive = useMemo(() => {
    const q = search.trim().toLowerCase();
    return courses.filter((c) => {
      if (filter === "theory" && c.class_type !== "theory") return false;
      if (filter === "lab" && c.class_type !== "lab") return false;
      if (filter === "service" && !c.is_service) return false;
      if (filter === "physics_lab" && !c.is_physics_lab) return false;
      if (filter === "inactive" && c.is_active) return false;
      if (!q) return true;
      return (
        c.code.toLowerCase().includes(q) ||
        c.title.toLowerCase().includes(q) ||
        c.dept_code.toLowerCase().includes(q)
      );
    });
  }, [courses, filter, search]);

  const columns: DataLedgerColumn<CatalogCourseRecord>[] = [
    {
      id: "code",
      header: "Code",
      accessor: (c) => c.code,
      cell: (c) => (
        <div className="flex items-center gap-1.5">
          <span className="font-mono-tabular font-semibold whitespace-nowrap">
            {c.code}
          </span>
          <HoverCopyButton value={c.code} label="course code" />
        </div>
      ),
    },
    {
      id: "title",
      header: "Course Title",
      accessor: (c) => c.title,
      cell: (c) => (
        <div className="min-w-0">
          <div className="truncate font-medium text-[var(--ink-primary)]">
            {c.title}
          </div>
          {c.is_physics_lab && (
            <span className="font-mono-tabular text-[11px] font-medium text-[var(--sem-joint-ink)]">
              R11 Physics Lab Bound
            </span>
          )}
        </div>
      ),
    },
    {
      id: "dept_code",
      header: "Dept",
      accessor: (c) => c.dept_code,
      cell: (c) => (
        <span className="font-mono-tabular text-[12px]">{c.dept_code}</span>
      ),
    },
    {
      id: "credit",
      header: "Cr",
      align: "right",
      accessor: (c) => c.credit,
      cell: (c) => (
        <span className="font-mono-tabular">{c.credit.toFixed(1)}</span>
      ),
    },
    {
      id: "class_type",
      header: "Type",
      accessor: (c) => c.class_type,
      cell: (c) => (
        <div className="flex flex-wrap items-center gap-1.5">
          <Badge tone={c.class_type === "lab" ? "lab" : "theory"} mono>
            {c.class_type === "lab" ? "Lab" : "Theory"}
          </Badge>
          {c.is_service && (
            <Badge tone="joint" mono>
              Service
            </Badge>
          )}
        </div>
      ),
    },
    {
      id: "default_weekly_sessions",
      header: "Sessions/Wk",
      align: "right",
      accessor: (c) => c.default_weekly_sessions ?? 0,
      cell: (c) => (
        <span className="font-mono-tabular text-[12px] text-[var(--ink-secondary)]">
          {c.default_weekly_sessions ?? "Auto"}
        </span>
      ),
    },
    {
      id: "is_active",
      header: "Status",
      accessor: (c) => (c.is_active ? "Active" : "Inactive"),
      cell: (c) => (
        <span
          className={cn(
            "font-mono-tabular text-[12px] font-medium",
            c.is_active ? "text-[var(--sem-lab-ink)]" : "text-[var(--ink-muted)]",
          )}
        >
          {c.is_active ? "Active" : "Inactive"}
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

  // Fallback derived reference rows when connected DB is pre-Stage-5A
  const derivedCourses = useMemo(() => {
    const active = (routinesQuery.data ?? []).filter((r) => r.is_active !== false);
    const byCode = new Map<
      string,
      {
        subjectCode: string;
        subject: string;
        semesters: Set<number>;
        isService: boolean;
        faculty: Set<string>;
        count: number;
      }
    >();
    for (const r of active) {
      const code = r.subject_code.trim().toUpperCase();
      if (!code) continue;
      let entry = byCode.get(code);
      if (!entry) {
        entry = {
          subjectCode: code,
          subject: r.subject,
          semesters: new Set<number>(),
          isService: Boolean(r.is_service),
          faculty: new Set<string>(),
          count: 0,
        };
        byCode.set(code, entry);
      }
      entry.semesters.add(r.semester);
      if (r.is_service) entry.isService = true;
      if (r.teacher_code) entry.faculty.add(r.teacher_code);
      for (const t of r.teachers ?? []) {
        if (t) entry.faculty.add(t);
      }
      entry.count += 1;
    }
    return Array.from(byCode.values())
      .map((e) => ({
        subjectCode: e.subjectCode,
        subject: e.subject,
        semesters: Array.from(e.semesters).sort((a, b) => a - b),
        isService: e.isService,
        facultyAcronyms: Array.from(e.faculty).sort(),
        weeklySlotCount: e.count,
      }))
      .sort((a, b) => a.subjectCode.localeCompare(b.subjectCode));
  }, [routinesQuery.data]);

  const filteredLegacy = useMemo(() => {
    const q = search.trim().toLowerCase();
    return derivedCourses.filter((c) => {
      if (legacyTypeFilter === "cse" && c.isService) return false;
      if (legacyTypeFilter === "service" && !c.isService) return false;
      if (!q) return true;
      return (
        c.subjectCode.toLowerCase().includes(q) ||
        c.subject.toLowerCase().includes(q) ||
        c.facultyAcronyms.some((f) => f.toLowerCase().includes(q))
      );
    });
  }, [derivedCourses, legacyTypeFilter, search]);

  if (catalogQuery.isLoading) {
    return <LedgerTableSkeleton rows={6} label="Checking course catalog schema" />;
  }

  if (catalogQuery.isError) {
    return (
      <LedgerErrorRecovery
        title="Could not load course catalog"
        message={
          catalogQuery.error instanceof Error
            ? catalogQuery.error.message
            : "Supabase catalog_courses query failed."
        }
        onRetry={() => void catalogQuery.refetch()}
      />
    );
  }

  // Graceful read-only fallback when connected DB is pre-Stage-5A
  if (!isLiveCatalog) {
    return (
      <div className="space-y-4">
        <div
          role="status"
          data-testid="staged-courses-banner"
          className="flex flex-wrap items-center justify-between gap-3 rounded-[var(--r-card)] border border-[var(--border-subtle)] bg-[var(--bg-canvas)] px-4 py-3 text-[12.5px] text-[var(--ink-secondary)]"
        >
          <div className="flex items-start gap-2.5">
            <LockSimple
              size={16}
              className="mt-0.5 shrink-0 text-[var(--ink-primary)]"
              aria-hidden="true"
            />
            <div>
              <strong className="font-semibold text-[var(--ink-primary)]">
                Staged Catalog · Read-Only Reference Derived From Active Published Routine
              </strong>
              <p className="mt-0.5 text-[12px]">
                Native course catalog creation and editing await Stage 5A database
                table promotion (`catalog_courses`). Rows below are derived read-only.
              </p>
            </div>
          </div>
          <Badge tone="neutral" mono>
            Staged · No DB
          </Badge>
        </div>

        <header className="border-b border-[var(--border-subtle)] pb-4">
          <h1 className="font-editorial text-[24px] font-semibold tracking-[-0.02em] text-[var(--ink-primary)]">
            Courses Reference
          </h1>
          <p className="mt-1 max-w-[66ch] text-[13.5px] leading-[1.55] text-[var(--ink-secondary)]">
            Active courses, conducting classification, assigned faculty acronyms,
            and weekly slot counts derived from the currently published routine.
          </p>
        </header>

        <div className="flex flex-wrap items-center justify-between gap-3">
          <div className="flex flex-wrap items-center gap-1.5">
            {(
              [
                { id: "all", label: `All (${derivedCourses.length})` },
                {
                  id: "cse",
                  label: `CSE (${derivedCourses.filter((c) => !c.isService).length})`,
                },
                {
                  id: "service",
                  label: `Service (${derivedCourses.filter((c) => c.isService).length})`,
                },
              ] as const
            ).map((opt) => (
              <button
                key={opt.id}
                type="button"
                aria-pressed={legacyTypeFilter === opt.id}
                onClick={() => setLegacyTypeFilter(opt.id)}
                className={
                  legacyTypeFilter === opt.id
                    ? "font-mono-tabular h-[34px] rounded-[var(--r-control)] border border-[var(--border-strong)] bg-[var(--bg-raised)] px-3 text-[12px] font-semibold text-[var(--ink-primary)] shadow-[inset_0_-2px_0_var(--accent-brand)]"
                    : "font-mono-tabular h-[34px] rounded-[var(--r-control)] border border-[var(--border-subtle)] bg-[var(--bg-elevated)] px-3 text-[12px] font-medium text-[var(--ink-secondary)] hover:bg-[var(--surface-hover)] hover:text-[var(--ink-primary)]"
                }
              >
                {opt.label}
              </button>
            ))}
          </div>
          <div className="relative w-full sm:w-[270px]">
            <MagnifyingGlass
              size={15}
              className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-[var(--ink-muted)]"
              aria-hidden="true"
            />
            <input
              ref={searchInputRef}
              type="search"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Search course or faculty... (/)"
              aria-label="Search derived courses"
              className="h-[36px] w-full rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] pl-8 pr-3 text-[13px] text-[var(--ink-primary)] placeholder:text-[var(--ink-muted)] focus:border-[var(--accent-brand)]"
            />
          </div>
        </div>

        {routinesQuery.isLoading ? (
          <LedgerTableSkeleton rows={6} label="Loading derived courses" />
        ) : filteredLegacy.length === 0 ? (
          <LedgerEmptyState
            icon={<BookOpen size={20} aria-hidden="true" />}
            title="No active routine courses published yet"
            description="Publish or add slots in Routine Operations to see active courses derived here."
          />
        ) : (
          <div className="ledger-card overflow-x-auto">
            <table className="w-full border-collapse text-left text-[13px]">
              <thead className="border-b border-[var(--border-subtle)] bg-[var(--bg-canvas)] text-[11px] font-semibold tracking-[0.04em] text-[var(--ink-muted)] uppercase">
                <tr>
                  <th className="px-4 py-2.5">Code</th>
                  <th className="px-4 py-2.5">Course Title</th>
                  <th className="px-4 py-2.5">Semester</th>
                  <th className="px-4 py-2.5">Scope</th>
                  <th className="px-4 py-2.5">Faculty</th>
                  <th className="px-4 py-2.5 text-right">Weekly Slots</th>
                  <th className="px-4 py-2.5 text-right">Matrix</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-[var(--border-subtle)] bg-[var(--bg-elevated)]">
                {filteredLegacy.map((course) => (
                  <tr key={course.subjectCode} className="hover:bg-[var(--surface-hover)]">
                    <td className="font-mono-tabular px-4 py-2.5 font-semibold text-[var(--ink-primary)] whitespace-nowrap">
                      {course.subjectCode}
                    </td>
                    <td className="px-4 py-2.5 text-[var(--ink-secondary)]">
                      {course.subject}
                    </td>
                    <td className="font-mono-tabular px-4 py-2.5 text-[var(--ink-primary)]">
                      {course.semesters.map((s) => `S${s}`).join(", ")}
                    </td>
                    <td className="px-4 py-2.5">
                      {course.isService ? (
                        <Badge tone="joint" mono>
                          Service
                        </Badge>
                      ) : (
                        <span className="font-mono-tabular text-[12px] text-[var(--ink-muted)]">
                          CSE
                        </span>
                      )}
                    </td>
                    <td className="font-mono-tabular px-4 py-2.5 text-[12px] text-[var(--ink-primary)]">
                      {course.facultyAcronyms.length > 0
                        ? course.facultyAcronyms.join(", ")
                        : "TBA"}
                    </td>
                    <td className="font-mono-tabular px-4 py-2.5 text-right font-semibold text-[var(--ink-primary)]">
                      {course.weeklySlotCount}
                    </td>
                    <td className="px-4 py-2.5 text-right">
                      <Link
                        to={`/admin/timetable/grid?search=${encodeURIComponent(course.subjectCode)}&from=courses`}
                        className="inline-flex items-center gap-1 text-[12px] font-semibold text-[var(--accent-brand)] no-underline hover:underline whitespace-nowrap"
                      >
                        <span>Inspect in Matrix</span>
                        <ArrowRight size={12} aria-hidden="true" />
                      </Link>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-5" data-testid="live-catalog-courses-page">
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
              placeholder="Search course code or title (/)"
              aria-label="Search catalog courses"
              className="h-[36px] w-full rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] pl-9 pr-3 text-[13px] text-[var(--ink-primary)] placeholder:text-[var(--ink-muted)] focus:border-[var(--accent-brand)]"
            />
          </div>

          <div role="group" aria-label="Filter catalog courses" className="flex flex-wrap gap-1.5">
            {(
              [
                { key: "all", label: `All (${filterCounts.all})` },
                { key: "theory", label: `Theory (${filterCounts.theory})` },
                { key: "lab", label: `Lab (${filterCounts.lab})` },
                { key: "service", label: `Service (${filterCounts.service})` },
                { key: "physics_lab", label: `Physics Lab (${filterCounts.physics_lab})` },
                { key: "inactive", label: `Inactive (${filterCounts.inactive})` },
              ] as const
            ).map((opt) => (
              <button
                key={opt.key}
                type="button"
                aria-pressed={filter === opt.key}
                onClick={() => setFilter(opt.key)}
                className={cn(
                  "h-[36px] rounded-[var(--r-control)] border px-3 font-mono-tabular text-[12px] transition-colors whitespace-nowrap",
                  filter === opt.key
                    ? "border-[var(--accent-brand)] bg-[var(--accent-brand-soft)] font-semibold text-[var(--accent-brand)]"
                    : "border-[var(--border-subtle)] bg-[var(--bg-elevated)] text-[var(--ink-secondary)] hover:bg-[var(--surface-hover)] hover:text-[var(--ink-primary)]",
                )}
              >
                {opt.label}
              </button>
            ))}
          </div>
        </div>

        <div className="flex flex-wrap items-center gap-2">
          <Button
            variant="secondary"
            size="md"
            data-testid="seed-courses-from-routine-btn"
            disabled={seedMutation.isPending}
            onClick={() => seedMutation.mutate()}
          >
            <Sparkle size={15} aria-hidden="true" />
            <span>
              {seedMutation.isPending ? "Importing..." : "Seed from Active Routine"}
            </span>
          </Button>
          <Button
            variant="primary"
            size="md"
            data-testid="add-catalog-course-btn"
            onClick={() => openInspector("new")}
          >
            <Plus size={15} aria-hidden="true" />
            <span>Add Course</span>
          </Button>
        </div>
      </div>

      <MasterDetailShell
        detailOpen={selectedId !== null}
        onRequestClose={() => openInspector(null)}
        detailTitle={
          selectedId === "new"
            ? "Add Course to Catalog"
            : selectedCourse
              ? `Edit ${selectedCourse.code}`
              : "Course Details"
        }
        detailSubtitle="Canonical course credit, theory/lab pattern, service & R11 Physics Lab tags"
        master={
          courses.length === 0 ? (
            <LedgerEmptyState
              icon={<BookOpen size={20} aria-hidden="true" />}
              title="No courses in canonical catalog yet"
              description="Add courses directly or seed unique courses from the currently published routine."
              actionLabel="Seed from Active Routine"
              onAction={() => seedMutation.mutate()}
            />
          ) : filteredLive.length === 0 ? (
            <LedgerFilterEmpty
              onReset={() => {
                setSearch("");
                setFilter("all");
              }}
            />
          ) : (
            <DataLedgerTable
              ariaLabel="Persistent course catalog"
              data={filteredLive}
              columns={columns}
              getRowId={(c) => c.id}
              selectedRowId={selectedId}
              onRowClick={(c) => openInspector(c.id)}
              isInactiveRow={(c) => !c.is_active}
              bulkActions={bulkActions}
              renderRowActions={(c) => (
                <>
                  <button
                    type="button"
                    aria-label={`Edit ${c.code}`}
                    onClick={() => openInspector(c.id)}
                    className="inline-flex h-7 w-7 items-center justify-center rounded-[5px] text-[var(--ink-secondary)] hover:bg-[var(--surface-active)] hover:text-[var(--ink-primary)]"
                  >
                    <PencilSimple size={14} aria-hidden="true" />
                  </button>
                  <button
                    type="button"
                    aria-label={`Delete ${c.code}`}
                    onClick={() => setDeleteIds([c.id])}
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
            id="course-inspector-form"
            onSubmit={handleSubmit((vals) => saveMutation.mutate(vals))}
            className="flex flex-col gap-4"
            noValidate
          >
            <div className="grid grid-cols-1 gap-3 sm:grid-cols-[140px_minmax(0,1fr)]">
              <div className="flex flex-col gap-1.5">
                <label
                  htmlFor="course-code"
                  className="text-[12.5px] font-semibold text-[var(--ink-primary)]"
                >
                  Course Code
                </label>
                <input
                  id="course-code"
                  type="text"
                  placeholder="CSE-3101"
                  {...register("code")}
                  className="font-mono-tabular h-[40px] rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-3 text-[13.5px] uppercase focus:border-[var(--accent-brand)]"
                />
                {errors.code && (
                  <p className="text-[12px] text-[var(--sem-conflict-ink)]">
                    {errors.code.message}
                  </p>
                )}
              </div>

              <div className="flex flex-col gap-1.5">
                <label
                  htmlFor="course-title"
                  className="text-[12.5px] font-semibold text-[var(--ink-primary)]"
                >
                  Course Title
                </label>
                <input
                  id="course-title"
                  type="text"
                  placeholder="Database Management Systems"
                  {...register("title")}
                  className="h-[40px] rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-3 text-[13.5px] focus:border-[var(--accent-brand)]"
                />
                {errors.title && (
                  <p className="text-[12px] text-[var(--sem-conflict-ink)]">
                    {errors.title.message}
                  </p>
                )}
              </div>
            </div>

            <div className="grid grid-cols-1 gap-3 sm:grid-cols-3">
              <div className="flex flex-col gap-1.5">
                <label
                  htmlFor="course-dept"
                  className="text-[12.5px] font-semibold text-[var(--ink-primary)]"
                >
                  Dept Code
                </label>
                <input
                  id="course-dept"
                  list="course-dept-list"
                  {...register("dept_code")}
                  className="font-mono-tabular h-[40px] rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-3 text-[13px] uppercase focus:border-[var(--accent-brand)]"
                />
                <datalist id="course-dept-list">
                  {INSTITUTIONAL_DEPARTMENTS.map((d) => (
                    <option key={d} value={d} />
                  ))}
                  <option value="PHY" />
                  <option value="MAT" />
                </datalist>
              </div>

              <div className="flex flex-col gap-1.5">
                <label
                  htmlFor="course-credit"
                  className="text-[12.5px] font-semibold text-[var(--ink-primary)]"
                >
                  Credits (R12/R13)
                </label>
                <input
                  id="course-credit"
                  type="number"
                  step="0.5"
                  min="0.5"
                  max="12"
                  {...register("credit")}
                  className="font-mono-tabular h-[40px] rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-3 text-[13px] focus:border-[var(--accent-brand)]"
                />
                {errors.credit && (
                  <p className="text-[12px] text-[var(--sem-conflict-ink)]">
                    {errors.credit.message}
                  </p>
                )}
              </div>

              <div className="flex flex-col gap-1.5">
                <label
                  htmlFor="course-sessions"
                  className="text-[12.5px] font-semibold text-[var(--ink-primary)]"
                >
                  Weekly Sessions
                </label>
                <input
                  id="course-sessions"
                  type="number"
                  min="1"
                  max="14"
                  placeholder="Auto"
                  {...register("default_weekly_sessions")}
                  className="font-mono-tabular h-[40px] rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-3 text-[13px] focus:border-[var(--accent-brand)]"
                />
              </div>
            </div>

            <div className="flex flex-col gap-1.5">
              <span className="text-[12.5px] font-semibold text-[var(--ink-primary)]">
                Class Type
              </span>
              <Controller
                name="class_type"
                control={control}
                render={({ field }) => (
                  <div
                    role="group"
                    aria-label="Course class type"
                    className="inline-flex h-[36px] w-fit rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-surface)] p-0.5"
                  >
                    {(["theory", "lab"] as const).map((t) => (
                      <button
                        key={t}
                        type="button"
                        aria-pressed={field.value === t}
                        onClick={() => field.onChange(t)}
                        className={cn(
                          "rounded-[5px] px-3 text-[12.5px] font-medium transition-colors",
                          field.value === t
                            ? "bg-[var(--bg-raised)] font-semibold text-[var(--ink-primary)]"
                            : "text-[var(--ink-secondary)] hover:text-[var(--ink-primary)]",
                        )}
                      >
                        {t === "theory" ? "Theory" : "Lab / Sessional"}
                      </button>
                    ))}
                  </div>
                )}
              />
            </div>

            <div className="divide-y divide-[var(--border-subtle)] rounded-[var(--r-control)] border border-[var(--border-subtle)] bg-[var(--bg-surface)] px-3.5">
              <label
                htmlFor="course-is-service"
                className="flex cursor-pointer items-center justify-between gap-3 py-3 text-[13px]"
              >
                <div>
                  <div className="font-medium text-[var(--ink-primary)]">
                    Service Course
                  </div>
                  <div className="text-[11.5px] text-[var(--ink-muted)]">
                    Conducted for external departments (resource-reserved)
                  </div>
                </div>
                <Controller
                  name="is_service"
                  control={control}
                  render={({ field }) => (
                    <Switch
                      id="course-is-service"
                      checked={field.value}
                      onCheckedChange={field.onChange}
                    />
                  )}
                />
              </label>

              {watchedClassType === "lab" && (
                <label
                  htmlFor="course-is-physics-lab"
                  className="flex cursor-pointer items-center justify-between gap-3 py-3 text-[13px]"
                >
                  <div>
                    <div className="font-medium text-[var(--ink-primary)]">
                      Physics Lab Course (R11)
                    </div>
                    <div className="text-[11.5px] text-[var(--ink-muted)]">
                      Bind exclusively to Physics Lab rooms during preflight &amp; solve
                    </div>
                  </div>
                  <Controller
                    name="is_physics_lab"
                    control={control}
                    render={({ field }) => (
                      <Switch
                        id="course-is-physics-lab"
                        checked={field.value}
                        onCheckedChange={field.onChange}
                      />
                    )}
                  />
                </label>
              )}

              <label
                htmlFor="course-is-active"
                className="flex cursor-pointer items-center justify-between gap-3 py-3 text-[13px]"
              >
                <div>
                  <div className="font-medium text-[var(--ink-primary)]">
                    Active in Catalog
                  </div>
                  <div className="text-[11.5px] text-[var(--ink-muted)]">
                    Inactive courses remain archived
                  </div>
                </div>
                <Controller
                  name="is_active"
                  control={control}
                  render={({ field }) => (
                    <Switch
                      id="course-is-active"
                      checked={field.value}
                      onCheckedChange={field.onChange}
                    />
                  )}
                />
              </label>
            </div>

            <div className="flex flex-col gap-1.5">
              <label
                htmlFor="course-notes"
                className="text-[12.5px] font-semibold text-[var(--ink-primary)]"
              >
                Committee Notes
              </label>
              <textarea
                id="course-notes"
                rows={2}
                {...register("notes")}
                className="rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] p-2.5 text-[12.5px] focus:border-[var(--accent-brand)]"
              />
            </div>

            <StickyDirtyBar
              docked
              isDirty={isDirty}
              isSaving={saveMutation.isPending}
              formId="course-inspector-form"
              saveLabel={selectedId === "new" ? "Create Course" : "Save Course"}
              onDiscard={() => {
                if (selectedId === "new") {
                  setSelectedId(null);
                  reset(toFormValues(null));
                } else {
                  reset(toFormValues(selectedCourse));
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
        title="Discard unsaved course edits?"
        description="You have unsaved changes in the Course Inspector. Discard them?"
        confirmLabel="Discard Changes"
        tone="destructive"
        onConfirm={() => {
          const target = pendingSelectId ?? null;
          setPendingSelectId(undefined);
          setSelectedId(target);
          if (target === "new") {
            reset(toFormValues(null));
          } else if (target) {
            const rec = courses.find((c) => c.id === target) ?? null;
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
        title={`Delete ${deleteIds?.length ?? 0} course(s)?`}
        description="Removes the selected course entries from the persistent catalog."
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

export const StagedCoursesReferencePage = ManageCoursesPage;
