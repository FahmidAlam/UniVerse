import { zodResolver } from "@hookform/resolvers/zod";
import {
  CheckCircle,
  MagnifyingGlass,
  PencilSimple,
  Plus,
  Trash,
} from "@phosphor-icons/react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useMemo, useRef, useState } from "react";
import { Controller, useForm } from "react-hook-form";
import { toast } from "sonner";
import { z } from "zod";
import {
  LedgerEmptyState,
  LedgerErrorRecovery,
  LedgerFilterEmpty,
  LedgerTableSkeleton,
  StagedFeatureNotice,
} from "@/components/ui/AsyncStates";
import { Badge } from "@/components/ui/Badge";
import { Button } from "@/components/ui/Button";
import {
  CommandCombobox,
  type ComboboxOption,
} from "@/components/ui/CommandCombobox";
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
  batchSaveFacultyEligibility,
  bulkSetEligibilityStatus,
  deleteEligibilityRecords,
  fetchDynamicCourseOptions,
  fetchEligibilityRecords,
  upsertEligibilityRecord,
  type CourseEligibilityRecord,
  type FacultyCourseAssignmentDraft,
} from "@/features/admin/services/eligibilityService";
import { fetchFaculty } from "@/features/admin/services/facultyService";
import { useAuth } from "@/features/auth/AuthProvider";
import { cn } from "@/lib/utils";

type EligibilityFilter = "all" | "eligible" | "blocked" | "prioritized";

const eligibilitySchema = z.object({
  acronym: z
    .string()
    .trim()
    .min(1, "Select or enter a faculty acronym.")
    .max(24, "Acronym is too long."),
  course_code: z
    .string()
    .trim()
    .min(1, "Select or enter a course code (e.g. CSE-2101).")
    .max(40, "Course code is too long."),
  is_eligible: z.boolean(),
  priority: z
    .string()
    .trim()
    .refine(
      (v) =>
        v === "" ||
        (/^\d+$/.test(v) && Number.parseInt(v, 10) >= 1 && Number.parseInt(v, 10) <= 99),
      "Priority must be a whole number from 1 to 99, or left blank.",
    ),
});

type EligibilityFormValues = z.infer<typeof eligibilitySchema>;

function toFormValues(record: CourseEligibilityRecord | null): EligibilityFormValues {
  if (!record) {
    return {
      acronym: "",
      course_code: "",
      is_eligible: true,
      priority: "",
    };
  }
  return {
    acronym: record.acronym,
    course_code: record.course_code,
    is_eligible: record.is_eligible,
    priority: record.priority !== null ? String(record.priority) : "",
  };
}

export function ManageCourseEligibilityPage() {
  const { isDevPreview } = useAuth();
  const queryClient = useQueryClient();
  const searchInputRef = useRef<HTMLInputElement>(null);

  const [search, setSearch] = useState("");
  const [filter, setFilter] = useState<EligibilityFilter>("all");
  const [viewMode, setViewMode] = useState<"ledger" | "by-faculty">("ledger");
  const [assignFacultyAcronym, setAssignFacultyAcronym] = useState("");
  const [assignCourseSearch, setAssignCourseSearch] = useState("");
  const [customCourses, setCustomCourses] = useState<string[]>([]);
  const [newCustomCourse, setNewCustomCourse] = useState("");
  const [assignDrafts, setAssignDrafts] = useState<
    Record<string, { checked: boolean; priority: number | null }>
  >({});
  const [assignDirty, setAssignDirty] = useState(false);
  const [selectedId, setSelectedId] = useState<string | "new" | null>(null);
  const [pendingSelectId, setPendingSelectId] = useState<
    string | "new" | null | undefined
  >(undefined);
  const [deleteIds, setDeleteIds] = useState<string[] | null>(null);

  const {
    data: records = [],
    isLoading,
    isError,
    error,
    refetch,
  } = useQuery({
    queryKey: ["admin-timetable-eligibility", isDevPreview],
    queryFn: () => fetchEligibilityRecords(isDevPreview),
    retry: false,
  });

  const { data: facultyList = [] } = useQuery({
    queryKey: ["admin-timetable-faculty", isDevPreview],
    queryFn: () => fetchFaculty(isDevPreview),
    retry: false,
  });

  const facultyCoursesUnion = useMemo(() => {
    const all = new Set<string>();
    for (const f of facultyList) {
      for (const c of f.courses) {
        const clean = c.trim().toUpperCase();
        if (clean) all.add(clean);
      }
    }
    return Array.from(all);
  }, [facultyList]);

  const { data: courseOptionsRaw = [] } = useQuery({
    queryKey: [
      "admin-dynamic-courses",
      isDevPreview,
      records.map((r) => r.course_code).join(","),
      facultyCoursesUnion.join(","),
    ],
    queryFn: () =>
      fetchDynamicCourseOptions(isDevPreview, records, facultyCoursesUnion),
    retry: false,
  });

  const facultyNameByAcronym = useMemo(() => {
    const map = new Map<string, string>();
    for (const f of facultyList) {
      map.set(f.acronym.toUpperCase(), f.full_name?.trim() || f.dept || "Faculty");
    }
    return map;
  }, [facultyList]);

  const facultyComboboxOptions = useMemo<ComboboxOption[]>(() => {
    const map = new Map<string, ComboboxOption>();
    for (const f of facultyList) {
      const code = f.acronym.toUpperCase();
      map.set(code, {
        value: code,
        label: f.full_name?.trim() || code,
        subtitle: f.dept ?? f.designation ?? undefined,
      });
    }
    for (const r of records) {
      const code = r.acronym.toUpperCase();
      if (!map.has(code)) {
        map.set(code, { value: code, label: code, subtitle: "Existing rule" });
      }
    }
    return Array.from(map.values()).sort((a, b) =>
      a.value.localeCompare(b.value),
    );
  }, [facultyList, records]);

  const courseTitleByCode = useMemo(() => {
    const map = new Map<string, string>();
    for (const c of courseOptionsRaw) {
      map.set(c.code.toUpperCase(), c.title);
    }
    return map;
  }, [courseOptionsRaw]);

  const courseComboboxOptions = useMemo<ComboboxOption[]>(
    () =>
      courseOptionsRaw.map((c) => ({
        value: c.code,
        label: c.title !== c.code ? c.title : "Detected in catalog / faculty",
      })),
    [courseOptionsRaw],
  );

  const selectedRecord = useMemo(
    () =>
      selectedId && selectedId !== "new"
        ? records.find((r) => r.id === selectedId) ?? null
        : null,
    [records, selectedId],
  );

  const form = useForm<EligibilityFormValues>({
    resolver: zodResolver(eligibilitySchema),
    defaultValues: toFormValues(null),
  });

  const {
    register,
    control,
    handleSubmit,
    reset,
    watch,
    formState: { errors, isDirty },
  } = form;

  const isEligibleValue = watch("is_eligible");

  const openInspector = (target: string | "new" | null) => {
    if (isDirty && target !== selectedId) {
      setPendingSelectId(target);
      return;
    }
    setSelectedId(target);
    if (target === "new") {
      reset(toFormValues(null));
    } else if (target) {
      const rec = records.find((r) => r.id === target) ?? null;
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
    mutationFn: async (values: EligibilityFormValues) => {
      const parsedPriority =
        values.priority.trim() !== ""
          ? Number.parseInt(values.priority.trim(), 10)
          : null;
      return upsertEligibilityRecord(
        {
          acronym: values.acronym,
          course_code: values.course_code,
          is_eligible: values.is_eligible,
          priority: parsedPriority,
        },
        isDevPreview,
      );
    },
    onSuccess: (saved) => {
      void queryClient.invalidateQueries({
        queryKey: ["admin-timetable-eligibility"],
      });
      setSelectedId(saved.id);
      reset(toFormValues(saved));
      toast.success(
        `Saved rule: ${saved.acronym} -> ${saved.course_code}`,
      );
    },
    onError: (err) => {
      toast.error("Could not save eligibility rule", {
        description:
          err instanceof Error ? err.message : "Database write failed.",
      });
    },
  });

  const bulkStatusMutation = useMutation({
    mutationFn: ({
      ids,
      isEligible,
    }: {
      ids: string[];
      isEligible: boolean;
    }) => bulkSetEligibilityStatus(ids, isEligible, isDevPreview),
    onSuccess: (_data, vars) => {
      void queryClient.invalidateQueries({
        queryKey: ["admin-timetable-eligibility"],
      });
      toast.success(
        `${vars.ids.length} rule(s) marked ${vars.isEligible ? "eligible" : "blocked"}`,
      );
    },
    onError: (err) => {
      toast.error("Bulk status update failed", {
        description:
          err instanceof Error ? err.message : "Database write failed.",
      });
    },
  });

  const deleteMutation = useMutation({
    mutationFn: (ids: string[]) => deleteEligibilityRecords(ids, isDevPreview),
    onSuccess: (_data, ids) => {
      void queryClient.invalidateQueries({
        queryKey: ["admin-timetable-eligibility"],
      });
      if (selectedId && ids.includes(selectedId)) {
        setSelectedId(null);
        reset(toFormValues(null));
      }
      setDeleteIds(null);
      toast.success(`Removed ${ids.length} eligibility rule(s)`);
    },
    onError: (err) => {
      toast.error("Could not remove eligibility rules", {
        description:
          err instanceof Error ? err.message : "Database delete failed.",
      });
    },
  });

  const counts = useMemo(
    () => ({
      all: records.length,
      eligible: records.filter((r) => r.is_eligible).length,
      blocked: records.filter((r) => !r.is_eligible).length,
      prioritized: records.filter((r) => r.priority !== null).length,
    }),
    [records],
  );

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    return records.filter((row) => {
      if (filter === "eligible" && !row.is_eligible) return false;
      if (filter === "blocked" && row.is_eligible) return false;
      if (filter === "prioritized" && row.priority === null) return false;
      if (!q) return true;
      const facultyName = (
        facultyNameByAcronym.get(row.acronym.toUpperCase()) ?? ""
      ).toLowerCase();
      const courseTitle = (
        courseTitleByCode.get(row.course_code.toUpperCase()) ?? ""
      ).toLowerCase();
      return (
        row.acronym.toLowerCase().includes(q) ||
        row.course_code.toLowerCase().includes(q) ||
        facultyName.includes(q) ||
        courseTitle.includes(q)
      );
    });
  }, [records, filter, search, facultyNameByAcronym, courseTitleByCode]);

  const columns = useMemo<DataLedgerColumn<CourseEligibilityRecord>[]>(
    () => [
      {
        id: "acronym",
        header: "Faculty",
        accessor: (r) => r.acronym,
        cell: (r) => {
          const fullName = facultyNameByAcronym.get(r.acronym.toUpperCase());
          return (
            <div className="min-w-0">
              <div className="font-mono-tabular font-semibold text-[var(--ink-primary)]">
                {r.acronym}
              </div>
              {fullName && (
                <div className="truncate text-[11.5px] text-[var(--ink-muted)]">
                  {fullName}
                </div>
              )}
            </div>
          );
        },
      },
      {
        id: "course_code",
        header: "Course",
        accessor: (r) => r.course_code,
        cell: (r) => {
          const title = courseTitleByCode.get(r.course_code.toUpperCase());
          return (
            <div className="min-w-0">
              <div className="flex items-center gap-1">
                <span className="font-mono-tabular font-medium text-[var(--ink-primary)]">
                  {r.course_code}
                </span>
                <HoverCopyButton
                  value={r.course_code}
                  label={`course code ${r.course_code}`}
                />
              </div>
              {title && title !== r.course_code && (
                <div className="truncate text-[11.5px] text-[var(--ink-muted)]">
                  {title}
                </div>
              )}
            </div>
          );
        },
      },
      {
        id: "is_eligible",
        header: "Status",
        accessor: (r) => (r.is_eligible ? "Eligible" : "Blocked"),
        cell: (r) => (
          <Badge tone={r.is_eligible ? "pine" : "conflict"}>
            {r.is_eligible ? "Eligible" : "Blocked"}
          </Badge>
        ),
      },
      {
        id: "priority",
        header: "Priority",
        accessor: (r) => r.priority ?? 999,
        align: "right",
        cell: (r) => (
          <span className="font-mono-tabular text-[var(--ink-primary)]">
            {r.priority !== null ? `#${r.priority}` : "—"}
          </span>
        ),
      },
    ],
    [facultyNameByAcronym, courseTitleByCode],
  );

  const bulkActions = useMemo<BulkActionItem[]>(
    () => [
      {
        id: "mark-eligible",
        label: "Mark Eligible",
        tone: "pine",
        disabled: bulkStatusMutation.isPending,
        onAction: (ids) =>
          bulkStatusMutation.mutate({ ids, isEligible: true }),
      },
      {
        id: "mark-blocked",
        label: "Mark Blocked",
        tone: "secondary",
        disabled: bulkStatusMutation.isPending,
        onAction: (ids) =>
          bulkStatusMutation.mutate({ ids, isEligible: false }),
      },
      {
        id: "delete",
        label: "Delete",
        tone: "destructive",
        disabled: deleteMutation.isPending,
        onAction: (ids) => setDeleteIds(ids),
      },
    ],
    [bulkStatusMutation, deleteMutation.isPending],
  );

  const coverageSummary = useMemo(() => {
    const activeFaculty = facultyList.filter((f) => f.is_active);
    const eligibleAcronyms = new Set(
      records.filter((r) => r.is_eligible).map((r) => r.acronym.toUpperCase()),
    );
    const eligibleFacultyCount = activeFaculty.filter((f) =>
      eligibleAcronyms.has(f.acronym.toUpperCase()),
    ).length;

    const coveredCourseCodes = new Set(
      records.filter((r) => r.is_eligible).map((r) => r.course_code.toUpperCase()),
    );
    const totalCoursesCount = courseOptionsRaw.length;
    const coveredCoursesCount = courseOptionsRaw.filter((c) =>
      coveredCourseCodes.has(c.code.toUpperCase()),
    ).length;

    return {
      eligibleFacultyCount,
      activeFacultyCount: activeFaculty.length,
      coveredCoursesCount,
      totalCoursesCount,
    };
  }, [courseOptionsRaw, facultyList, records]);

  const allAssignableCourses = useMemo(() => {
    const map = new Map<string, string>();
    for (const c of courseOptionsRaw) {
      map.set(c.code.toUpperCase(), c.title);
    }
    for (const raw of customCourses) {
      const code = raw.trim().toUpperCase();
      if (code && !map.has(code)) map.set(code, code);
    }
    return Array.from(map.entries())
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([code, title]) => ({ code, title }));
  }, [courseOptionsRaw, customCourses]);

  const selectFacultyForBatch = (acronym: string) => {
    const clean = acronym.trim().toUpperCase();
    setAssignFacultyAcronym(clean);
    const nextDrafts: Record<string, { checked: boolean; priority: number | null }> = {};
    for (const r of records) {
      if (r.acronym.toUpperCase() === clean && r.is_eligible) {
        nextDrafts[r.course_code.toUpperCase()] = {
          checked: true,
          priority: r.priority,
        };
      }
    }
    setAssignDrafts(nextDrafts);
    setAssignDirty(false);
  };

  const batchAssignMutation = useMutation({
    mutationFn: async () => {
      if (!assignFacultyAcronym) return;
      const existingForFaculty = records.filter(
        (r) => r.acronym.toUpperCase() === assignFacultyAcronym.toUpperCase(),
      );
      const drafts: FacultyCourseAssignmentDraft[] = Object.entries(assignDrafts).map(
        ([courseCode, st]) => ({
          courseCode,
          checked: st.checked,
          priority: st.priority,
        }),
      );
      await batchSaveFacultyEligibility(
        assignFacultyAcronym,
        drafts,
        existingForFaculty,
        isDevPreview,
      );
    },
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ["admin-timetable-eligibility"] });
      void queryClient.invalidateQueries({ queryKey: ["admin-dashboard-counts"] });
      setAssignDirty(false);
      toast.success(`Saved eligibility assignments for ${assignFacultyAcronym}`);
    },
    onError: (err) => {
      toast.error("Batch eligibility save failed", {
        description: err instanceof Error ? err.message : "Database write failed.",
      });
    },
  });

  const filterChips: Array<{ id: EligibilityFilter; label: string; count: number }> = [
    { id: "all", label: "All", count: counts.all },
    { id: "eligible", label: "Eligible", count: counts.eligible },
    { id: "blocked", label: "Blocked", count: counts.blocked },
    { id: "prioritized", label: "Prioritized", count: counts.prioritized },
  ];

  return (
    <div className="space-y-4">
      <header className="flex flex-wrap items-end justify-between gap-4 border-b border-[var(--border-subtle)] pb-4">
        <div>
          <h1 className="font-editorial text-[26px] font-semibold tracking-[-0.02em] text-[var(--ink-primary)]">
            Course Eligibility
          </h1>
          <p className="mt-1 max-w-[66ch] text-[13.5px] leading-[1.55] text-[var(--ink-secondary)]">
            Faculty-course pairing permissions and priority order used during pre-publish
            schedule generation.
          </p>
        </div>

        <div className="flex flex-wrap items-center gap-2">
          <div
            role="group"
            aria-label="Eligibility view mode"
            className="inline-flex h-[36px] items-center rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] p-0.5"
          >
            <button
              type="button"
              aria-pressed={viewMode === "ledger"}
              onClick={() => setViewMode("ledger")}
              className={cn(
                "h-[30px] rounded-[5px] px-3 text-[12.5px] font-medium transition-colors",
                viewMode === "ledger"
                  ? "bg-[var(--action-primary)] font-semibold text-[var(--action-primary-ink)]"
                  : "text-[var(--ink-secondary)] hover:text-[var(--ink-primary)]",
              )}
            >
              Flat Ledger
            </button>
            <button
              type="button"
              aria-pressed={viewMode === "by-faculty"}
              data-testid="eligibility-assign-by-faculty-tab"
              onClick={() => setViewMode("by-faculty")}
              className={cn(
                "h-[30px] rounded-[5px] px-3 text-[12.5px] font-medium transition-colors",
                viewMode === "by-faculty"
                  ? "bg-[var(--action-primary)] font-semibold text-[var(--action-primary-ink)]"
                  : "text-[var(--ink-secondary)] hover:text-[var(--ink-primary)]",
              )}
            >
              Assign by Faculty
            </button>
          </div>

          <Button
            variant="primary"
            size="md"
            onClick={() => {
              setViewMode("ledger");
              openInspector("new");
            }}
          >
            <Plus size={15} aria-hidden="true" />
            <span>Add Rule</span>
          </Button>
        </div>
      </header>

      {/* Live Coverage Summary Strip */}
      <div
        data-testid="eligibility-coverage-strip"
        className="ledger-card flex flex-wrap items-center gap-x-5 gap-y-2 px-4 py-2.5 text-[12px]"
      >
        <span className="font-mono-tabular text-[var(--ink-primary)]">
          <strong>Eligible faculty:</strong>{" "}
          {coverageSummary.eligibleFacultyCount} /{" "}
          {coverageSummary.activeFacultyCount} active
        </span>
        <span className="font-mono-tabular text-[var(--ink-primary)]">
          <strong>Courses covered:</strong>{" "}
          {coverageSummary.coveredCoursesCount} /{" "}
          {coverageSummary.totalCoursesCount} derived courses
        </span>
      </div>

      {viewMode === "by-faculty" ? (
        <section
          data-testid="eligibility-by-faculty-panel"
          className="ledger-card space-y-4 p-5"
        >
          <div className="grid grid-cols-1 gap-4 md:grid-cols-[300px_minmax(0,1fr)]">
            <div className="space-y-1.5">
              <label
                htmlFor="assign-faculty-combobox"
                className="block text-[12.5px] font-semibold text-[var(--ink-primary)]"
              >
                Select Faculty Member
              </label>
              <CommandCombobox
                id="assign-faculty-combobox"
                value={assignFacultyAcronym}
                onChange={selectFacultyForBatch}
                options={facultyComboboxOptions}
                placeholder="Choose faculty..."
                searchPlaceholder="Search faculty acronym or name..."
                emptyLabel="No faculty found."
              />
              <p className="text-[12px] text-[var(--ink-secondary)]">
                Check courses this instructor can teach and optionally set
                priority (1 = highest).
              </p>
            </div>

            <div className="space-y-3">
              <div className="flex flex-wrap items-center gap-2">
                <div className="relative flex-1 min-w-[200px]">
                  <MagnifyingGlass
                    size={15}
                    className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-[var(--ink-muted)]"
                    aria-hidden="true"
                  />
                  <input
                    type="search"
                    value={assignCourseSearch}
                    onChange={(e) => setAssignCourseSearch(e.target.value)}
                    placeholder="Filter derived courses..."
                    aria-label="Filter derived courses"
                    className="h-[36px] w-full rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] pl-8 pr-3 text-[13px] text-[var(--ink-primary)] placeholder:text-[var(--ink-muted)] focus:border-[var(--accent-pine)]"
                  />
                </div>
                <div className="flex items-center gap-1.5">
                  <input
                    type="text"
                    value={newCustomCourse}
                    onChange={(e) => setNewCustomCourse(e.target.value)}
                    placeholder="Add code (e.g. CSE-4101)"
                    aria-label="Add custom course code"
                    className="font-mono-tabular h-[36px] w-[170px] rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-2.5 text-[12.5px] text-[var(--ink-primary)] uppercase focus:border-[var(--accent-pine)]"
                  />
                  <Button
                    type="button"
                    variant="secondary"
                    size="sm"
                    onClick={() => {
                      const code = newCustomCourse.trim().toUpperCase();
                      if (!code) return;
                      setCustomCourses((prev) =>
                        prev.includes(code) ? prev : [...prev, code],
                      );
                      if (assignFacultyAcronym) {
                        setAssignDrafts((prev) => ({
                          ...prev,
                          [code]: { checked: true, priority: prev[code]?.priority ?? null },
                        }));
                        setAssignDirty(true);
                      }
                      setNewCustomCourse("");
                    }}
                  >
                    Add
                  </Button>
                </div>
              </div>

              {!assignFacultyAcronym ? (
                <div className="rounded-[var(--r-control)] border border-dashed border-[var(--border-subtle)] bg-[var(--bg-surface)] px-4 py-8 text-center text-[13px] text-[var(--ink-muted)]">
                  Choose a faculty member on the left to batch-assign course
                  eligibility.
                </div>
              ) : allAssignableCourses.length === 0 ? (
                <div className="rounded-[var(--r-control)] border border-dashed border-[var(--border-subtle)] bg-[var(--bg-surface)] px-4 py-8 text-center text-[13px] text-[var(--ink-muted)]">
                  No derived courses yet. Add a custom course code above to
                  begin.
                </div>
              ) : (
                <div className="divide-y divide-[var(--border-subtle)] rounded-[var(--r-control)] border border-[var(--border-subtle)] bg-[var(--bg-elevated)]">
                  {allAssignableCourses
                    .filter((c) => {
                      const q = assignCourseSearch.trim().toLowerCase();
                      if (!q) return true;
                      return (
                        c.code.toLowerCase().includes(q) ||
                        c.title.toLowerCase().includes(q)
                      );
                    })
                    .map((c) => {
                      const draft = assignDrafts[c.code] ?? {
                        checked: false,
                        priority: null,
                      };
                      return (
                        <div
                          key={c.code}
                          className="flex flex-wrap items-center justify-between gap-3 px-3.5 py-2.5"
                        >
                          <label className="flex min-w-0 flex-1 cursor-pointer items-center gap-2.5">
                            <input
                              type="checkbox"
                              checked={draft.checked}
                              onChange={(e) => {
                                const checked = e.target.checked;
                                setAssignDrafts((prev) => ({
                                  ...prev,
                                  [c.code]: {
                                    checked,
                                    priority: prev[c.code]?.priority ?? null,
                                  },
                                }));
                                setAssignDirty(true);
                              }}
                              className="h-4 w-4 accent-[var(--accent-pine)]"
                            />
                            <span className="font-mono-tabular text-[12.5px] font-semibold text-[var(--ink-primary)]">
                              {c.code}
                            </span>
                            {c.title !== c.code && (
                              <span className="truncate text-[12.5px] text-[var(--ink-secondary)]">
                                {c.title}
                              </span>
                            )}
                          </label>

                          <div className="flex items-center gap-2">
                            <label
                              htmlFor={`prio-${c.code}`}
                              className="text-[11.5px] text-[var(--ink-muted)]"
                            >
                              Priority
                            </label>
                            <input
                              id={`prio-${c.code}`}
                              type="number"
                              min={1}
                              max={5}
                              disabled={!draft.checked}
                              value={draft.priority ?? ""}
                              placeholder="—"
                              onChange={(e) => {
                                const raw = e.target.value.trim();
                                const parsed =
                                  raw === "" ? null : Number.parseInt(raw, 10);
                                setAssignDrafts((prev) => ({
                                  ...prev,
                                  [c.code]: {
                                    checked: prev[c.code]?.checked ?? true,
                                    priority:
                                      parsed !== null && Number.isFinite(parsed)
                                        ? Math.min(5, Math.max(1, parsed))
                                        : null,
                                  },
                                }));
                                setAssignDirty(true);
                              }}
                              className="font-mono-tabular h-[30px] w-[58px] rounded-[5px] border border-[var(--border-control)] bg-[var(--bg-surface)] px-2 text-center text-[12px] text-[var(--ink-primary)] disabled:opacity-50"
                            />
                          </div>
                        </div>
                      );
                    })}
                </div>
              )}
            </div>
          </div>

          <StickyDirtyBar
            isDirty={assignDirty && Boolean(assignFacultyAcronym)}
            isSaving={batchAssignMutation.isPending}
            message={`Unsaved eligibility assignments for ${assignFacultyAcronym}`}
            onDiscard={() => selectFacultyForBatch(assignFacultyAcronym)}
            onSave={() => batchAssignMutation.mutate()}
          />
        </section>
      ) : (
        <>
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div
          role="tablist"
          aria-label="Filter eligibility rules"
          className="flex flex-wrap items-center gap-1.5"
        >
          {filterChips.map((chip) => {
            const active = filter === chip.id;
            return (
              <button
                key={chip.id}
                type="button"
                role="tab"
                aria-selected={active}
                onClick={() => setFilter(chip.id)}
                className={cn(
                  "inline-flex h-8 items-center gap-1.5 rounded-[var(--r-control)] border px-2.5 text-[12.5px] font-medium transition-colors",
                  active
                    ? "border-[var(--ink-primary)] bg-[var(--ink-primary)] text-[var(--bg-elevated)]"
                    : "border-[var(--border-subtle)] bg-[var(--bg-elevated)] text-[var(--ink-secondary)] hover:bg-[var(--surface-hover)] hover:text-[var(--ink-primary)]",
                )}
              >
                <span>{chip.label}</span>
                <span
                  className={cn(
                    "font-mono-tabular text-[11px]",
                    active ? "text-[var(--bg-elevated)]/80" : "text-[var(--ink-muted)]",
                  )}
                >
                  {chip.count}
                </span>
              </button>
            );
          })}
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
            placeholder="Search faculty or course... (/)"
            aria-label="Search eligibility rules"
            className="h-[36px] w-full rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] pl-8 pr-3 text-[13px] text-[var(--ink-primary)] placeholder:text-[var(--ink-muted)] focus:border-[var(--ink-primary)] focus:outline-none"
          />
        </div>
      </div>

      <MasterDetailShell
        detailOpen={selectedId !== null}
        onRequestClose={() => openInspector(null)}
        detailTitle={
          selectedId === "new"
            ? "New Eligibility Rule"
            : selectedRecord
              ? `${selectedRecord.acronym} · ${selectedRecord.course_code}`
              : "Eligibility Rule"
        }
        detailSubtitle={
          selectedId === "new"
            ? "Upsert against unique pair (acronym, course_code)."
            : "Update pairing eligibility or departmental priority."
        }
        master={
          isLoading ? (
            <LedgerTableSkeleton label="Loading course eligibility rules" />
          ) : isError ? (
            <LedgerErrorRecovery
              title="Could not load course eligibility"
              message={
                error instanceof Error
                  ? error.message
                  : "Supabase query failed."
              }
              onRetry={() => void refetch()}
            />
          ) : records.length === 0 ? (
            <LedgerEmptyState
              icon={<CheckCircle size={20} aria-hidden="true" />}
              title="No eligibility rules configured yet"
              description="Pair faculty acronyms with course codes from published routines or teaching allocations to guide pre-publish scheduling checks."
              actionLabel="Add First Rule"
              onAction={() => openInspector("new")}
            />
          ) : filtered.length === 0 ? (
            <LedgerFilterEmpty
              message="No eligibility rules match your active search or filter."
              onReset={() => {
                setSearch("");
                setFilter("all");
              }}
            />
          ) : (
            <DataLedgerTable
              data={filtered}
              columns={columns}
              getRowId={(r) => r.id}
              selectedRowId={selectedId}
              onRowClick={(row) => openInspector(row.id)}
              isInactiveRow={(row) => !row.is_eligible}
              bulkActions={bulkActions}
              ariaLabel="Course eligibility matrix"
              renderRowActions={(row) => (
                <>
                  <button
                    type="button"
                    aria-label={`Edit rule ${row.acronym} ${row.course_code}`}
                    onClick={() => openInspector(row.id)}
                    className="flex h-7 w-7 items-center justify-center rounded-[5px] text-[var(--ink-secondary)] hover:bg-[var(--surface-hover)] hover:text-[var(--ink-primary)]"
                  >
                    <PencilSimple size={14} aria-hidden="true" />
                  </button>
                  <button
                    type="button"
                    aria-label={`Delete rule ${row.acronym} ${row.course_code}`}
                    onClick={() => setDeleteIds([row.id])}
                    className="flex h-7 w-7 items-center justify-center rounded-[5px] text-[var(--ink-secondary)] hover:bg-[var(--sem-conflict-bg)] hover:text-[var(--sem-conflict-ink)]"
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
            id="eligibility-inspector-form"
            onSubmit={handleSubmit((values) => saveMutation.mutate(values))}
            className="space-y-4"
            noValidate
          >
            <div>
              <label
                htmlFor="elig-acronym"
                className="mb-1.5 block text-[12.5px] font-medium text-[var(--ink-primary)]"
              >
                Faculty Acronym
              </label>
              <Controller
                control={control}
                name="acronym"
                render={({ field }) => (
                  <CommandCombobox
                    id="elig-acronym"
                    value={field.value}
                    onChange={field.onChange}
                    options={facultyComboboxOptions}
                    placeholder="Select or type acronym..."
                    searchPlaceholder="Filter faculty by acronym or name..."
                    emptyLabel="No matching faculty found."
                    allowCustom
                    normalizeValue={(raw) => raw.toUpperCase()}
                    aria-invalid={Boolean(errors.acronym)}
                  />
                )}
              />
              {errors.acronym && (
                <p className="mt-1 text-[12px] text-[var(--sem-conflict-ink)]">
                  {errors.acronym.message}
                </p>
              )}
            </div>

            <div>
              <label
                htmlFor="elig-course-code"
                className="mb-1.5 block text-[12.5px] font-medium text-[var(--ink-primary)]"
              >
                Course Code
              </label>
              <Controller
                control={control}
                name="course_code"
                render={({ field }) => (
                  <CommandCombobox
                    id="elig-course-code"
                    value={field.value}
                    onChange={field.onChange}
                    options={courseComboboxOptions}
                    placeholder="Select or enter course code..."
                    searchPlaceholder="Filter dynamic courses..."
                    emptyLabel="No catalog course matches. Type to add custom code."
                    allowCustom
                    normalizeValue={(raw) => raw.toUpperCase()}
                    aria-invalid={Boolean(errors.course_code)}
                  />
                )}
              />
              <p className="mt-1 text-[11.5px] text-[var(--ink-muted)]">
                Course suggestions merge published routines, saved faculty allocations,
                and existing eligibility rules.
              </p>
              {errors.course_code && (
                <p className="mt-1 text-[12px] text-[var(--sem-conflict-ink)]">
                  {errors.course_code.message}
                </p>
              )}
            </div>

            <div className="flex items-center justify-between gap-3 rounded-[var(--r-control)] border border-[var(--border-subtle)] bg-[var(--bg-canvas)]/60 px-3.5 py-2.5">
              <div>
                <div className="text-[13px] font-medium text-[var(--ink-primary)]">
                  Pairing Status
                </div>
                <div className="text-[11.5px] text-[var(--ink-secondary)]">
                  {isEligibleValue
                    ? "Permitted to teach this course during allocation checks."
                    : "Explicitly blocked from taking this course."}
                </div>
              </div>
              <Controller
                control={control}
                name="is_eligible"
                render={({ field }) => (
                  <Switch
                    checked={field.value}
                    onCheckedChange={field.onChange}
                    aria-label="Course eligibility status"
                  />
                )}
              />
            </div>

            <div>
              <label
                htmlFor="elig-priority"
                className="mb-1.5 block text-[12.5px] font-medium text-[var(--ink-primary)]"
              >
                Priority Order (optional)
              </label>
              <input
                id="elig-priority"
                type="text"
                inputMode="numeric"
                placeholder="Blank or 1, 2, 3..."
                aria-invalid={Boolean(errors.priority)}
                {...register("priority")}
                className="font-mono-tabular h-[40px] w-full rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-3 text-[13.5px] text-[var(--ink-primary)] placeholder:text-[var(--ink-muted)] focus:border-[var(--ink-primary)] focus:outline-none"
              />
              {errors.priority && (
                <p className="mt-1 text-[12px] text-[var(--sem-conflict-ink)]">
                  {errors.priority.message}
                </p>
              )}
            </div>

            <StagedFeatureNotice
              title="Pre-publish validation gate"
              description="Each faculty acronym and course code pair stays unique. Full course distribution spreadsheet validation opens in a later release."
            />

            {selectedRecord && (
              <div className="border-t border-[var(--border-subtle)] pt-3">
                <Button
                  variant="ghost"
                  size="sm"
                  onClick={() => setDeleteIds([selectedRecord.id])}
                  className="text-[var(--sem-conflict-ink)] hover:bg-[var(--sem-conflict-bg)]"
                >
                  <Trash size={14} aria-hidden="true" />
                  <span>Delete Rule</span>
                </Button>
              </div>
            )}

            <StickyDirtyBar
              isDirty={isDirty || selectedId === "new"}
              isSaving={saveMutation.isPending}
              message={
                selectedId === "new"
                  ? "Ready to save new eligibility rule"
                  : "Unsaved rule changes"
              }
              saveLabel={selectedId === "new" ? "Save Rule" : "Save Changes"}
              formId="eligibility-inspector-form"
              onDiscard={() => {
                if (selectedId === "new") {
                  setSelectedId(null);
                  reset(toFormValues(null));
                } else {
                  reset(toFormValues(selectedRecord));
                }
              }}
            />
          </form>
        }
      />
        </>
      )}

      <ConfirmDialog
        open={pendingSelectId !== undefined}
        onOpenChange={(open) => {
          if (!open) setPendingSelectId(undefined);
        }}
        title="Discard unsaved rule changes?"
        description="Your edits to this eligibility rule have not been saved yet."
        confirmLabel="Discard Changes"
        tone="destructive"
        onConfirm={() => {
          const target = pendingSelectId ?? null;
          setPendingSelectId(undefined);
          setSelectedId(target);
          if (target === "new") {
            reset(toFormValues(null));
          } else if (target) {
            const rec = records.find((r) => r.id === target) ?? null;
            reset(toFormValues(rec));
          }
        }}
      />

      <ConfirmDialog
        open={deleteIds !== null}
        onOpenChange={(open) => {
          if (!open) setDeleteIds(null);
        }}
        title={`Delete ${deleteIds?.length ?? 0} eligibility rule(s)?`}
        description="This immediately removes the selected faculty-course pairing rules from `timetable_course_eligibility`."
        confirmLabel="Delete Rules"
        tone="destructive"
        isPending={deleteMutation.isPending}
        onConfirm={() => {
          if (deleteIds) deleteMutation.mutate(deleteIds);
        }}
      />
    </div>
  );
}
