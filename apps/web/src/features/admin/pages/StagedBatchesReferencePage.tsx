import { zodResolver } from "@hookform/resolvers/zod";
import {
  ArrowCounterClockwise,
  ArrowRight,
  LockSimple,
  MagnifyingGlass,
  PencilSimple,
  Plus,
  Sparkle,
  Trash,
  UsersFour,
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
  type BulkActionItem,
  type DataLedgerColumn,
} from "@/components/ui/DataLedgerTable";
import { MasterDetailShell } from "@/components/ui/MasterDetailShell";
import { StickyDirtyBar } from "@/components/ui/StickyDirtyBar";
import { Switch } from "@/components/ui/Switch";
import { useWorkspaceShortcuts } from "@/core/hooks/useWorkspaceShortcuts";
import {
  CONSECUTIVE_WEEKEND_PAIRS,
  bulkSetSectionPoliciesActive,
  createSectionPolicy,
  deleteSectionPolicies,
  fetchSectionPolicies,
  seedSectionsFromActiveRoutine,
  updateSectionPolicy,
  type SectionPolicyRecord,
} from "@/features/admin/services/batchesService";
import { useAuth } from "@/features/auth/AuthProvider";
import { fetchRoutines } from "@/features/routine/services/routineService";
import { cn } from "@/lib/utils";

type BatchFilter = "all" | "bi_semester" | "trimester" | "overridden" | "joint";

const sectionFormSchema = z.object({
  batch: z.string().trim().min(1, "Batch is required.").max(30),
  section: z.string().trim().min(1, "Section is required.").max(30),
  calendar_system: z.enum(["trimester", "bi_semester"]),
  has_weekend_override: z.boolean(),
  weekend_pair_key: z.string(),
  student_count: z
    .string()
    .trim()
    .refine(
      (v) =>
        v === "" ||
        (/^\d+$/.test(v) && Number.parseInt(v, 10) >= 1 && Number.parseInt(v, 10) <= 500),
      "Headcount must be 1–500 or blank.",
    ),
  is_active: z.boolean(),
  notes: z.string().trim().max(400).optional(),
});

type SectionFormValues = z.infer<typeof sectionFormSchema>;

function pairToKey(pair: readonly string[]): string {
  return `${pair[0]}|${pair[1]}`;
}

function keyToPair(key: string): string[] {
  const parts = key.split("|");
  return parts.length === 2 ? parts : ["Friday", "Saturday"];
}

function toFormValues(sec: SectionPolicyRecord | null): SectionFormValues {
  if (!sec) {
    return {
      batch: "",
      section: "A",
      calendar_system: "bi_semester",
      has_weekend_override: false,
      weekend_pair_key: "Friday|Saturday",
      student_count: "",
      is_active: true,
      notes: "",
    };
  }
  return {
    batch: sec.batch,
    section: sec.section,
    calendar_system: sec.calendar_system,
    has_weekend_override: Boolean(sec.weekend_override_days),
    weekend_pair_key: sec.weekend_override_days
      ? pairToKey(sec.weekend_override_days)
      : "Friday|Saturday",
    student_count: sec.student_count !== null ? String(sec.student_count) : "",
    is_active: sec.is_active,
    notes: sec.notes ?? "",
  };
}

export function ManageBatchesPage() {
  const { isDevPreview } = useAuth();
  const queryClient = useQueryClient();
  const searchInputRef = useRef<HTMLInputElement>(null);
  const [search, setSearch] = useState("");
  const [filter, setFilter] = useState<BatchFilter>("all");
  const [legacyFilter, setLegacyFilter] = useState<"all" | "joint">("all");
  const [selectedId, setSelectedId] = useState<string | "new" | null>(null);
  const [pendingSelectId, setPendingSelectId] = useState<
    string | "new" | null | undefined
  >(undefined);
  const [deleteIds, setDeleteIds] = useState<string[] | null>(null);

  const sectionsQuery = useQuery({
    queryKey: ["admin-section-policies", isDevPreview],
    queryFn: () => fetchSectionPolicies(isDevPreview),
    retry: false,
  });

  const routinesQuery = useQuery({
    queryKey: ["admin-routines", isDevPreview],
    queryFn: () => fetchRoutines(isDevPreview),
    retry: false,
  });

  const isLiveSections = sectionsQuery.data?.live ?? false;
  const sections = useMemo(
    () => sectionsQuery.data?.sections ?? [],
    [sectionsQuery.data?.sections],
  );

  const selectedSection = useMemo(
    () =>
      selectedId && selectedId !== "new"
        ? sections.find((s) => s.id === selectedId) ?? null
        : null,
    [sections, selectedId],
  );

  const form = useForm<SectionFormValues>({
    resolver: zodResolver(sectionFormSchema),
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

  const watchedHasOverride = watch("has_weekend_override");

  const openInspector = (target: string | "new" | null) => {
    if (isDirty && target !== selectedId) {
      setPendingSelectId(target);
      return;
    }
    setSelectedId(target);
    if (target === "new") {
      reset(toFormValues(null));
    } else if (target) {
      const rec = sections.find((s) => s.id === target) ?? null;
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
    mutationFn: async (values: SectionFormValues) => {
      const input = {
        batch: values.batch,
        section: values.section,
        calendar_system: values.calendar_system,
        weekend_override_days: values.has_weekend_override
          ? keyToPair(values.weekend_pair_key)
          : null,
        student_count: values.student_count.trim()
          ? Number.parseInt(values.student_count.trim(), 10)
          : null,
        is_active: values.is_active,
        notes: values.notes ?? null,
      };
      if (selectedId === "new" || !selectedSection) {
        return createSectionPolicy(input, isDevPreview);
      }
      return updateSectionPolicy(selectedSection.id, input, isDevPreview);
    },
    onSuccess: (saved) => {
      void queryClient.invalidateQueries({ queryKey: ["admin-section-policies"] });
      setSelectedId(saved.id);
      reset(toFormValues(saved));
      toast.success(`Saved Batch ${saved.batch}-${saved.section}`);
    },
    onError: (err) => {
      toast.error("Could not save section policy", {
        description: err instanceof Error ? err.message : "Database write failed.",
      });
    },
  });

  const resetWeekendMutation = useMutation({
    mutationFn: async (sec: SectionPolicyRecord) =>
      updateSectionPolicy(
        sec.id,
        {
          batch: sec.batch,
          section: sec.section,
          calendar_system: sec.calendar_system,
          weekend_override_days: null,
          student_count: sec.student_count,
          is_active: sec.is_active,
          notes: sec.notes,
        },
        isDevPreview,
      ),
    onSuccess: (saved) => {
      void queryClient.invalidateQueries({ queryKey: ["admin-section-policies"] });
      if (selectedId === saved.id) {
        reset(toFormValues(saved));
      }
      toast.success(`Reset ${saved.batch}-${saved.section} to committee weekend`);
    },
    onError: (err) => {
      toast.error("Could not reset weekend override", {
        description: err instanceof Error ? err.message : "Update failed.",
      });
    },
  });

  const seedMutation = useMutation({
    mutationFn: async () => {
      const routines = routinesQuery.data ?? (await fetchRoutines(isDevPreview));
      return seedSectionsFromActiveRoutine(routines, sections, isDevPreview);
    },
    onSuccess: (res) => {
      void queryClient.invalidateQueries({ queryKey: ["admin-section-policies"] });
      if (res.insertedCount === 0) {
        toast.info("All active routine sections are already configured", {
          description: `${res.skippedCount} existing section(s) preserved.`,
        });
      } else {
        toast.success(`Imported ${res.insertedCount} section(s) from active routine`);
      }
    },
    onError: (err) => {
      toast.error("Could not seed sections", {
        description: err instanceof Error ? err.message : "Import failed.",
      });
    },
  });

  const bulkStatusMutation = useMutation({
    mutationFn: ({ ids, isActive }: { ids: string[]; isActive: boolean }) =>
      bulkSetSectionPoliciesActive(ids, isActive, isDevPreview),
    onSuccess: (_, vars) => {
      void queryClient.invalidateQueries({ queryKey: ["admin-section-policies"] });
      toast.success(
        `${vars.ids.length} section(s) marked ${vars.isActive ? "active" : "inactive"}`,
      );
    },
  });

  const deleteMutation = useMutation({
    mutationFn: (ids: string[]) => deleteSectionPolicies(ids, isDevPreview),
    onSuccess: (_, ids) => {
      void queryClient.invalidateQueries({ queryKey: ["admin-section-policies"] });
      if (selectedId && ids.includes(selectedId)) {
        setSelectedId(null);
        reset(toFormValues(null));
      }
      setDeleteIds(null);
      toast.success(`Removed ${ids.length} section(s)`);
    },
  });

  const filterCounts = useMemo(
    () => ({
      all: sections.length,
      bi_semester: sections.filter((s) => s.calendar_system === "bi_semester").length,
      trimester: sections.filter((s) => s.calendar_system === "trimester").length,
      overridden: sections.filter((s) => Boolean(s.weekend_override_days)).length,
      joint: sections.filter((s) => s.section.includes("+")).length,
    }),
    [sections],
  );

  const filteredLive = useMemo(() => {
    const q = search.trim().toLowerCase();
    return sections.filter((s) => {
      if (filter === "bi_semester" && s.calendar_system !== "bi_semester") return false;
      if (filter === "trimester" && s.calendar_system !== "trimester") return false;
      if (filter === "overridden" && !s.weekend_override_days) return false;
      if (filter === "joint" && !s.section.includes("+")) return false;
      if (!q) return true;
      return (
        s.batch.toLowerCase().includes(q) ||
        s.section.toLowerCase().includes(q) ||
        `${s.batch}-${s.section}`.toLowerCase().includes(q)
      );
    });
  }, [filter, search, sections]);

  const columns: DataLedgerColumn<SectionPolicyRecord>[] = [
    {
      id: "batch",
      header: "Batch",
      accessor: (s) => s.batch,
      cell: (s) => (
        <span className="font-mono-tabular font-semibold">Batch {s.batch}</span>
      ),
    },
    {
      id: "section",
      header: "Section",
      accessor: (s) => s.section,
      cell: (s) =>
        s.section.includes("+") ? (
          <Badge tone="joint" mono>
            {s.section}
          </Badge>
        ) : (
          <span className="font-mono-tabular font-medium">{s.section}</span>
        ),
    },
    {
      id: "calendar_system",
      header: "Calendar",
      accessor: (s) => s.calendar_system,
      cell: (s) => (
        <span className="font-mono-tabular text-[12px] text-[var(--ink-secondary)]">
          {s.calendar_system === "trimester" ? "Trimester" : "Bi-Semester"}
        </span>
      ),
    },
    {
      id: "student_count",
      header: "Students",
      align: "right",
      accessor: (s) => s.student_count ?? 0,
      cell: (s) => (
        <span className="font-mono-tabular">
          {s.student_count !== null ? s.student_count : "—"}
        </span>
      ),
    },
    {
      id: "weekend",
      header: "R1 Weekend",
      accessor: (s) =>
        s.weekend_override_days ? s.weekend_override_days.join(" + ") : "Inherit",
      cell: (s) =>
        s.weekend_override_days ? (
          <div
            className="flex items-center gap-1.5"
            onClick={(e) => e.stopPropagation()}
          >
            <Badge tone="joint" mono>
              {s.weekend_override_days.map((d) => d.slice(0, 3)).join(" + ")}
            </Badge>
            <button
              type="button"
              title="Reset to Committee Weekend"
              aria-label={`Reset weekend override for ${s.batch}-${s.section}`}
              onClick={() => resetWeekendMutation.mutate(s)}
              className="inline-flex h-6 w-6 items-center justify-center rounded text-[var(--ink-muted)] hover:bg-[var(--surface-hover)] hover:text-[var(--ink-primary)]"
            >
              <ArrowCounterClockwise size={12} aria-hidden="true" />
            </button>
          </div>
        ) : (
          <span className="font-mono-tabular text-[12px] text-[var(--ink-muted)]">
            Inherit Committee Weekend
          </span>
        ),
    },
    {
      id: "is_active",
      header: "Status",
      accessor: (s) => (s.is_active ? "Active" : "Inactive"),
      cell: (s) => (
        <span
          className={cn(
            "font-mono-tabular text-[12px] font-medium",
            s.is_active ? "text-[var(--sem-lab-ink)]" : "text-[var(--ink-muted)]",
          )}
        >
          {s.is_active ? "Active" : "Inactive"}
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

  const derivedCohorts = useMemo(() => {
    const active = (routinesQuery.data ?? []).filter((r) => r.is_active !== false);
    const byKey = new Map<
      string,
      { batch: string; section: string; semesters: Set<number>; count: number }
    >();
    for (const r of active) {
      const batch = r.batch.trim();
      const section = r.section.trim() || "A";
      const key = `${batch}|${section}`;
      let entry = byKey.get(key);
      if (!entry) {
        entry = { batch, section, semesters: new Set<number>(), count: 0 };
        byKey.set(key, entry);
      }
      entry.semesters.add(r.semester);
      entry.count += 1;
    }
    return Array.from(byKey.entries())
      .map(([key, e]) => ({
        key,
        batch: e.batch,
        section: e.section,
        semesters: Array.from(e.semesters).sort((a, b) => a - b),
        weeklySlotCount: e.count,
        isJoint: e.section.includes("+"),
      }))
      .sort(
        (a, b) =>
          a.batch.localeCompare(b.batch, undefined, { numeric: true }) ||
          a.section.localeCompare(b.section),
      );
  }, [routinesQuery.data]);

  const filteredLegacy = useMemo(() => {
    const q = search.trim().toLowerCase();
    return derivedCohorts.filter((c) => {
      if (legacyFilter === "joint" && !c.isJoint) return false;
      if (!q) return true;
      return (
        c.batch.toLowerCase().includes(q) ||
        c.section.toLowerCase().includes(q) ||
        `batch ${c.batch} ${c.section}`.toLowerCase().includes(q)
      );
    });
  }, [derivedCohorts, legacyFilter, search]);

  if (sectionsQuery.isLoading) {
    return <LedgerTableSkeleton rows={6} label="Checking section policy schema" />;
  }

  if (sectionsQuery.isError) {
    return (
      <LedgerErrorRecovery
        title="Could not load batches & section policies"
        message={
          sectionsQuery.error instanceof Error
            ? sectionsQuery.error.message
            : "Supabase section_policies query failed."
        }
        onRetry={() => void sectionsQuery.refetch()}
      />
    );
  }

  if (!isLiveSections) {
    return (
      <div className="space-y-4">
        <div
          role="status"
          data-testid="staged-batches-banner"
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
                Native cohort and section management await Stage 5A database table
                promotion (`section_policies`). Rows below are derived read-only.
              </p>
            </div>
          </div>
          <Badge tone="neutral" mono>
            Staged · No DB
          </Badge>
        </div>

        <header className="border-b border-[var(--border-subtle)] pb-4">
          <h1 className="font-editorial text-[24px] font-semibold tracking-[-0.02em] text-[var(--ink-primary)]">
            Batches &amp; Sections Reference
          </h1>
          <p className="mt-1 max-w-[66ch] text-[13.5px] leading-[1.55] text-[var(--ink-secondary)]">
            Active student batches, single and joint (<span className="font-mono-tabular">B+C</span>)
            sections, semesters, and weekly slot totals derived from published schedules.
          </p>
        </header>

        <div className="flex flex-wrap items-center justify-between gap-3">
          <div className="flex flex-wrap items-center gap-1.5">
            {(
              [
                { id: "all", label: `All (${derivedCohorts.length})` },
                {
                  id: "joint",
                  label: `Joint B+C (${derivedCohorts.filter((c) => c.isJoint).length})`,
                },
              ] as const
            ).map((opt) => (
              <button
                key={opt.id}
                type="button"
                aria-pressed={legacyFilter === opt.id}
                onClick={() => setLegacyFilter(opt.id)}
                className={
                  legacyFilter === opt.id
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
              placeholder="Search batch or section... (/)"
              aria-label="Search derived cohorts"
              className="h-[36px] w-full rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] pl-8 pr-3 text-[13px] text-[var(--ink-primary)] placeholder:text-[var(--ink-muted)] focus:border-[var(--accent-brand)]"
            />
          </div>
        </div>

        {routinesQuery.isLoading ? (
          <LedgerTableSkeleton rows={6} label="Loading derived batches" />
        ) : filteredLegacy.length === 0 ? (
          <LedgerEmptyState
            icon={<UsersFour size={20} aria-hidden="true" />}
            title="No active routine cohorts published yet"
            description="Publish or add slots in Routine Operations to see active batches and sections derived here."
          />
        ) : (
          <div className="ledger-card overflow-x-auto">
            <table className="w-full border-collapse text-left text-[13px]">
              <thead className="border-b border-[var(--border-subtle)] bg-[var(--bg-canvas)] text-[11px] font-semibold tracking-[0.04em] text-[var(--ink-muted)] uppercase">
                <tr>
                  <th className="px-4 py-2.5">Batch</th>
                  <th className="px-4 py-2.5">Section</th>
                  <th className="px-4 py-2.5">Semester</th>
                  <th className="px-4 py-2.5 text-right">Weekly Slots</th>
                  <th className="px-4 py-2.5 text-right">Matrix</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-[var(--border-subtle)] bg-[var(--bg-elevated)]">
                {filteredLegacy.map((cohort) => (
                  <tr key={cohort.key} className="hover:bg-[var(--surface-hover)]">
                    <td className="font-mono-tabular px-4 py-2.5 font-semibold text-[var(--ink-primary)]">
                      Batch {cohort.batch}
                    </td>
                    <td className="px-4 py-2.5">
                      {cohort.isJoint ? (
                        <Badge tone="joint" mono>
                          {cohort.section}
                        </Badge>
                      ) : (
                        <span className="font-mono-tabular text-[12.5px] font-medium text-[var(--ink-primary)]">
                          {cohort.section}
                        </span>
                      )}
                    </td>
                    <td className="font-mono-tabular px-4 py-2.5 text-[var(--ink-secondary)]">
                      {cohort.semesters.map((s) => `Sem ${s}`).join(", ")}
                    </td>
                    <td className="font-mono-tabular px-4 py-2.5 text-right font-semibold text-[var(--ink-primary)]">
                      {cohort.weeklySlotCount}
                    </td>
                    <td className="px-4 py-2.5 text-right">
                      <Link
                        to={`/admin/timetable/grid?lens=section&entity=${encodeURIComponent(cohort.key)}&from=batches`}
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
    <div className="flex flex-col gap-5" data-testid="live-section-policies-page">
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
              placeholder="Search batch or section (/)"
              aria-label="Search batches and sections"
              className="h-[36px] w-full rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] pl-9 pr-3 text-[13px] text-[var(--ink-primary)] placeholder:text-[var(--ink-muted)] focus:border-[var(--accent-brand)]"
            />
          </div>

          <div role="group" aria-label="Filter sections" className="flex flex-wrap gap-1.5">
            {(
              [
                { key: "all", label: `All (${filterCounts.all})` },
                { key: "bi_semester", label: `Bi-Sem (${filterCounts.bi_semester})` },
                { key: "trimester", label: `Trimester (${filterCounts.trimester})` },
                { key: "overridden", label: `R1 Overridden (${filterCounts.overridden})` },
                { key: "joint", label: `Joint B+C (${filterCounts.joint})` },
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
            data-testid="seed-sections-from-routine-btn"
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
            data-testid="add-section-policy-btn"
            onClick={() => openInspector("new")}
          >
            <Plus size={15} aria-hidden="true" />
            <span>Add Section</span>
          </Button>
        </div>
      </div>

      <MasterDetailShell
        detailOpen={selectedId !== null}
        onRequestClose={() => openInspector(null)}
        detailTitle={
          selectedId === "new"
            ? "Add Batch & Section"
            : selectedSection
              ? `Batch ${selectedSection.batch}-${selectedSection.section}`
              : "Section Details"
        }
        detailSubtitle="Calendar system, headcount, and R1 consecutive 2-day weekend override"
        master={
          sections.length === 0 ? (
            <LedgerEmptyState
              icon={<UsersFour size={20} aria-hidden="true" />}
              title="No batch or section policies configured yet"
              description="Add sections directly or import active batches and sections from the published routine."
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
              ariaLabel="Batches and section policies"
              data={filteredLive}
              columns={columns}
              getRowId={(s) => s.id}
              selectedRowId={selectedId}
              onRowClick={(s) => openInspector(s.id)}
              isInactiveRow={(s) => !s.is_active}
              bulkActions={bulkActions}
              renderRowActions={(s) => (
                <>
                  <button
                    type="button"
                    aria-label={`Edit ${s.batch}-${s.section}`}
                    onClick={() => openInspector(s.id)}
                    className="inline-flex h-7 w-7 items-center justify-center rounded-[5px] text-[var(--ink-secondary)] hover:bg-[var(--surface-active)] hover:text-[var(--ink-primary)]"
                  >
                    <PencilSimple size={14} aria-hidden="true" />
                  </button>
                  <button
                    type="button"
                    aria-label={`Delete ${s.batch}-${s.section}`}
                    onClick={() => setDeleteIds([s.id])}
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
            id="section-inspector-form"
            onSubmit={handleSubmit((vals) => saveMutation.mutate(vals))}
            className="flex flex-col gap-4"
            noValidate
          >
            <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
              <div className="flex flex-col gap-1.5">
                <label
                  htmlFor="section-batch"
                  className="text-[12.5px] font-semibold text-[var(--ink-primary)]"
                >
                  Batch
                </label>
                <input
                  id="section-batch"
                  type="text"
                  placeholder="61"
                  {...register("batch")}
                  className="font-mono-tabular h-[40px] rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-3 text-[13.5px] focus:border-[var(--accent-brand)]"
                />
                {errors.batch && (
                  <p className="text-[12px] text-[var(--sem-conflict-ink)]">
                    {errors.batch.message}
                  </p>
                )}
              </div>

              <div className="flex flex-col gap-1.5">
                <label
                  htmlFor="section-code"
                  className="text-[12.5px] font-semibold text-[var(--ink-primary)]"
                >
                  Section
                </label>
                <input
                  id="section-code"
                  type="text"
                  placeholder="A or B+C"
                  {...register("section")}
                  className="font-mono-tabular h-[40px] rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-3 text-[13.5px] uppercase focus:border-[var(--accent-brand)]"
                />
                {errors.section && (
                  <p className="text-[12px] text-[var(--sem-conflict-ink)]">
                    {errors.section.message}
                  </p>
                )}
              </div>
            </div>

            <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
              <div className="flex flex-col gap-1.5">
                <span className="text-[12.5px] font-semibold text-[var(--ink-primary)]">
                  Calendar System
                </span>
                <Controller
                  name="calendar_system"
                  control={control}
                  render={({ field }) => (
                    <div
                      role="group"
                      aria-label="Calendar system"
                      className="inline-flex h-[40px] rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-surface)] p-0.5"
                    >
                      {(
                        [
                          { id: "bi_semester", label: "Bi-Semester" },
                          { id: "trimester", label: "Trimester" },
                        ] as const
                      ).map((opt) => (
                        <button
                          key={opt.id}
                          type="button"
                          aria-pressed={field.value === opt.id}
                          onClick={() => field.onChange(opt.id)}
                          className={cn(
                            "flex-1 rounded-[5px] px-2.5 text-[12px] font-medium transition-colors",
                            field.value === opt.id
                              ? "bg-[var(--bg-raised)] font-semibold text-[var(--ink-primary)]"
                              : "text-[var(--ink-secondary)] hover:text-[var(--ink-primary)]",
                          )}
                        >
                          {opt.label}
                        </button>
                      ))}
                    </div>
                  )}
                />
              </div>

              <div className="flex flex-col gap-1.5">
                <label
                  htmlFor="section-student-count"
                  className="text-[12.5px] font-semibold text-[var(--ink-primary)]"
                >
                  Student Headcount
                </label>
                <input
                  id="section-student-count"
                  type="number"
                  min={1}
                  max={500}
                  placeholder="Optional"
                  {...register("student_count")}
                  className="font-mono-tabular h-[40px] rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-3 text-[13px] focus:border-[var(--accent-brand)]"
                />
                {errors.student_count && (
                  <p className="text-[12px] text-[var(--sem-conflict-ink)]">
                    {errors.student_count.message}
                  </p>
                )}
              </div>
            </div>

            {/* R1 Weekend Override with Checkbox Off = Gray */}
            <div
              className={cn(
                "flex flex-col gap-3 rounded-[var(--r-control)] border p-3.5 transition-colors",
                watchedHasOverride
                  ? "border-[var(--sem-joint-border)] bg-[var(--sem-joint-bg)]/35"
                  : "border-[var(--border-subtle)] bg-[var(--bg-surface)]",
              )}
            >
              <label
                htmlFor="section-weekend-override-toggle"
                className="flex cursor-pointer items-center justify-between gap-3 text-[13px]"
              >
                <div>
                  <div className="font-medium text-[var(--ink-primary)]">
                    Override Committee Weekend (R1)
                  </div>
                  <div className="text-[11.5px] text-[var(--ink-muted)]">
                    {watchedHasOverride
                      ? "Section uses an explicit 2-day consecutive weekend"
                      : "Inherit Committee Weekend (neutral baseline)"}
                  </div>
                </div>
                <Controller
                  name="has_weekend_override"
                  control={control}
                  render={({ field }) => (
                    <Switch
                      id="section-weekend-override-toggle"
                      checked={field.value}
                      onCheckedChange={field.onChange}
                    />
                  )}
                />
              </label>

              {watchedHasOverride && (
                <div className="flex flex-wrap items-center gap-2">
                  <select
                    aria-label="Consecutive 2-day weekend override"
                    {...register("weekend_pair_key")}
                    className="font-mono-tabular h-[36px] flex-1 rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-2.5 text-[12.5px] focus:border-[var(--accent-brand)]"
                  >
                    {CONSECUTIVE_WEEKEND_PAIRS.map((pair) => {
                      const key = pairToKey(pair);
                      return (
                        <option key={key} value={key}>
                          {pair[0]} + {pair[1]}
                        </option>
                      );
                    })}
                  </select>
                  <Button
                    type="button"
                    variant="secondary"
                    size="sm"
                    onClick={() => {
                      setValue("has_weekend_override", false, { shouldDirty: true });
                      setValue("weekend_pair_key", "Friday|Saturday", {
                        shouldDirty: true,
                      });
                    }}
                  >
                    <ArrowCounterClockwise size={12} aria-hidden="true" />
                    <span>Reset</span>
                  </Button>
                </div>
              )}
            </div>

            <label
              htmlFor="section-is-active"
              className="flex cursor-pointer items-center justify-between gap-3 rounded-[var(--r-control)] border border-[var(--border-subtle)] bg-[var(--bg-surface)] px-3.5 py-3 text-[13px]"
            >
              <div>
                <div className="font-medium text-[var(--ink-primary)]">
                  Active Cohort / Section
                </div>
                <div className="text-[11.5px] text-[var(--ink-muted)]">
                  Inactive sections are excluded from preflight &amp; solve
                </div>
              </div>
              <Controller
                name="is_active"
                control={control}
                render={({ field }) => (
                  <Switch
                    id="section-is-active"
                    checked={field.value}
                    onCheckedChange={field.onChange}
                  />
                )}
              />
            </label>

            <div className="flex flex-col gap-1.5">
              <label
                htmlFor="section-notes"
                className="text-[12.5px] font-semibold text-[var(--ink-primary)]"
              >
                Notes
              </label>
              <textarea
                id="section-notes"
                rows={2}
                {...register("notes")}
                className="rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] p-2.5 text-[12.5px] focus:border-[var(--accent-brand)]"
              />
            </div>

            <StickyDirtyBar
              docked
              isDirty={isDirty}
              isSaving={saveMutation.isPending}
              formId="section-inspector-form"
              saveLabel={selectedId === "new" ? "Create Section" : "Save Section"}
              onDiscard={() => {
                if (selectedId === "new") {
                  setSelectedId(null);
                  reset(toFormValues(null));
                } else {
                  reset(toFormValues(selectedSection));
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
        title="Discard unsaved section edits?"
        description="You have unsaved changes in the Section Inspector. Discard them?"
        confirmLabel="Discard Changes"
        tone="destructive"
        onConfirm={() => {
          const target = pendingSelectId ?? null;
          setPendingSelectId(undefined);
          setSelectedId(target);
          if (target === "new") {
            reset(toFormValues(null));
          } else if (target) {
            const rec = sections.find((s) => s.id === target) ?? null;
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
        title={`Delete ${deleteIds?.length ?? 0} section policy(s)?`}
        description="Removes the selected batch/section policies."
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

export const StagedBatchesReferencePage = ManageBatchesPage;
