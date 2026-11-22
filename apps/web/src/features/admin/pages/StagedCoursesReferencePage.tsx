import { ArrowRight, BookOpen, LockSimple, MagnifyingGlass } from "@phosphor-icons/react";
import { useQuery } from "@tanstack/react-query";
import { useMemo, useRef, useState } from "react";
import { Link } from "react-router-dom";
import {
  LedgerEmptyState,
  LedgerErrorRecovery,
  LedgerFilterEmpty,
  LedgerTableSkeleton,
} from "@/components/ui/AsyncStates";
import { Badge } from "@/components/ui/Badge";
import { useWorkspaceShortcuts } from "@/core/hooks/useWorkspaceShortcuts";
import { useAuth } from "@/features/auth/AuthProvider";
import { fetchRoutines } from "@/features/routine/services/routineService";

interface DerivedCourseRow {
  subjectCode: string;
  subject: string;
  semesters: number[];
  isService: boolean;
  facultyAcronyms: string[];
  weeklySlotCount: number;
}

export function StagedCoursesReferencePage() {
  const { isDevPreview } = useAuth();
  const searchInputRef = useRef<HTMLInputElement>(null);
  const [search, setSearch] = useState("");
  const [typeFilter, setTypeFilter] = useState<"all" | "cse" | "service">("all");

  useWorkspaceShortcuts({ searchInputRef });

  const routinesQuery = useQuery({
    queryKey: ["admin-routines", isDevPreview],
    queryFn: () => fetchRoutines(isDevPreview),
    retry: false,
  });

  const derivedCourses = useMemo<DerivedCourseRow[]>(() => {
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

  const counts = useMemo(
    () => ({
      all: derivedCourses.length,
      cse: derivedCourses.filter((c) => !c.isService).length,
      service: derivedCourses.filter((c) => c.isService).length,
    }),
    [derivedCourses],
  );

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    return derivedCourses.filter((c) => {
      if (typeFilter === "cse" && c.isService) return false;
      if (typeFilter === "service" && !c.isService) return false;
      if (!q) return true;
      return (
        c.subjectCode.toLowerCase().includes(q) ||
        c.subject.toLowerCase().includes(q) ||
        c.facultyAcronyms.some((f) => f.toLowerCase().includes(q))
      );
    });
  }, [derivedCourses, search, typeFilter]);

  return (
    <div className="space-y-4">
      {/* Persistent Staged Catalog Disclosure Banner */}
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
              Native course catalog creation and editing await canonical database
              table promotion. Rows below are derived read-only from the active
              published routine.
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

      {/* Toolbar */}
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div
          role="group"
          aria-label="Filter derived courses"
          className="flex flex-wrap items-center gap-1.5"
        >
          {(
            [
              { id: "all", label: `All (${counts.all})` },
              { id: "cse", label: `CSE (${counts.cse})` },
              { id: "service", label: `Service (${counts.service})` },
            ] as const
          ).map((opt) => (
            <button
              key={opt.id}
              type="button"
              aria-pressed={typeFilter === opt.id}
              onClick={() => setTypeFilter(opt.id)}
              className={
                typeFilter === opt.id
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
      ) : routinesQuery.isError ? (
        <LedgerErrorRecovery
          title="Could not load active routine courses"
          message={
            routinesQuery.error instanceof Error
              ? routinesQuery.error.message
              : "Supabase routines query failed."
          }
          onRetry={() => void routinesQuery.refetch()}
        />
      ) : derivedCourses.length === 0 ? (
        <LedgerEmptyState
          icon={<BookOpen size={20} aria-hidden="true" />}
          title="No active routine courses published yet"
          description="Publish or add slots in Routine Operations to see active courses derived here."
        />
      ) : filtered.length === 0 ? (
        <LedgerFilterEmpty
          message={`No active courses match "${search}".`}
          onReset={() => {
            setSearch("");
            setTypeFilter("all");
          }}
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
              {filtered.map((course) => (
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
