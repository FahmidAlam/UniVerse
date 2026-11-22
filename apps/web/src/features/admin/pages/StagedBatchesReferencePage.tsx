import { ArrowRight, LockSimple, MagnifyingGlass, UsersFour } from "@phosphor-icons/react";
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

interface DerivedCohortRow {
  key: string;
  batch: string;
  section: string;
  semesters: number[];
  weeklySlotCount: number;
  isJoint: boolean;
}

export function StagedBatchesReferencePage() {
  const { isDevPreview } = useAuth();
  const searchInputRef = useRef<HTMLInputElement>(null);
  const [search, setSearch] = useState("");
  const [cohortFilter, setCohortFilter] = useState<"all" | "joint">("all");

  useWorkspaceShortcuts({ searchInputRef });

  const routinesQuery = useQuery({
    queryKey: ["admin-routines", isDevPreview],
    queryFn: () => fetchRoutines(isDevPreview),
    retry: false,
  });

  const derivedCohorts = useMemo<DerivedCohortRow[]>(() => {
    const active = (routinesQuery.data ?? []).filter((r) => r.is_active !== false);
    const byKey = new Map<
      string,
      {
        batch: string;
        section: string;
        semesters: Set<number>;
        count: number;
      }
    >();

    for (const r of active) {
      const batch = r.batch.trim();
      const section = r.section.trim() || "A";
      const key = `${batch}|${section}`;
      let entry = byKey.get(key);
      if (!entry) {
        entry = {
          batch,
          section,
          semesters: new Set<number>(),
          count: 0,
        };
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

  const counts = useMemo(
    () => ({
      all: derivedCohorts.length,
      joint: derivedCohorts.filter((c) => c.isJoint).length,
    }),
    [derivedCohorts],
  );

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    return derivedCohorts.filter((c) => {
      if (cohortFilter === "joint" && !c.isJoint) return false;
      if (!q) return true;
      return (
        c.batch.toLowerCase().includes(q) ||
        c.section.toLowerCase().includes(q) ||
        `batch ${c.batch} ${c.section}`.toLowerCase().includes(q)
      );
    });
  }, [cohortFilter, derivedCohorts, search]);

  return (
    <div className="space-y-4">
      {/* Persistent Staged Catalog Disclosure Banner */}
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
              Native cohort and section management await canonical database table
              promotion. Rows below are derived read-only from the active
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
          Batches &amp; Sections Reference
        </h1>
        <p className="mt-1 max-w-[66ch] text-[13.5px] leading-[1.55] text-[var(--ink-secondary)]">
          Active student batches, single and joint (<span className="font-mono-tabular">B+C</span>)
          sections, semesters, and weekly slot totals derived from published schedules.
        </p>
      </header>

      {/* Toolbar */}
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div
          role="group"
          aria-label="Filter derived cohorts"
          className="flex flex-wrap items-center gap-1.5"
        >
          {(
            [
              { id: "all", label: `All (${counts.all})` },
              { id: "joint", label: `Joint B+C (${counts.joint})` },
            ] as const
          ).map((opt) => (
            <button
              key={opt.id}
              type="button"
              aria-pressed={cohortFilter === opt.id}
              onClick={() => setCohortFilter(opt.id)}
              className={
                cohortFilter === opt.id
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
      ) : routinesQuery.isError ? (
        <LedgerErrorRecovery
          title="Could not load active routine cohorts"
          message={
            routinesQuery.error instanceof Error
              ? routinesQuery.error.message
              : "Supabase routines query failed."
          }
          onRetry={() => void routinesQuery.refetch()}
        />
      ) : derivedCohorts.length === 0 ? (
        <LedgerEmptyState
          icon={<UsersFour size={20} aria-hidden="true" />}
          title="No active routine cohorts published yet"
          description="Publish or add slots in Routine Operations to see active batches and sections derived here."
        />
      ) : filtered.length === 0 ? (
        <LedgerFilterEmpty
          message={`No active cohorts match "${search}".`}
          onReset={() => {
            setSearch("");
            setCohortFilter("all");
          }}
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
              {filtered.map((cohort) => (
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
