import { Printer } from "@phosphor-icons/react";
import { Fragment, useMemo, useState } from "react";
import { Button } from "@/components/ui/Button";
import { resolveMiddayBreak } from "@/core/utils/breakPolicy";
import { ClockTime } from "@/core/utils/clockTime";
import { ACADEMIC_WEEK_DAYS } from "@/features/admin/services/facultyService";
import {
  ONLINE_SLOT_IDX,
  type PeriodDefinition,
} from "@/features/admin/services/settingsService";
import type { RoutineRow } from "@/features/routine/types";
import { cn } from "@/lib/utils";

interface CohortEntry {
  key: string;
  batch: string;
  section: string;
  semester: number;
  isService: boolean;
}

function compareBatchesDescending(a: CohortEntry, b: CohortEntry): number {
  const na = Number(a.batch);
  const nb = Number(b.batch);
  const aIsNum = Number.isFinite(na) && /^\d+$/.test(a.batch.trim());
  const bIsNum = Number.isFinite(nb) && /^\d+$/.test(b.batch.trim());
  if (aIsNum && bIsNum) {
    if (na !== nb) return nb - na; // Descending: 69 -> 61
    return a.section.localeCompare(b.section, undefined, { numeric: true });
  }
  if (aIsNum) return -1;
  if (bIsNum) return 1;

  // M. Sc. before Retake/Service
  const rank = (batch: string) => {
    const low = batch.toLowerCase();
    if (low.includes("m. sc") || low.includes("msc")) return 1;
    if (low.includes("retake") || low.includes("improvement")) return 2;
    return 3;
  };
  const ra = rank(a.batch);
  const rb = rank(b.batch);
  if (ra !== rb) return ra - rb;
  const cmp = a.batch.localeCompare(b.batch, undefined, { numeric: true });
  return cmp !== 0 ? cmp : a.section.localeCompare(b.section);
}

function resolvePeriodIdx(
  row: RoutineRow,
  periods: readonly PeriodDefinition[],
): number | null {
  if (typeof row.period === "number" && Number.isFinite(row.period)) {
    return row.period;
  }
  const startHm = ClockTime.toHm(row.time_start);
  const match = periods.find((p) => ClockTime.toHm(p.start) === startHm);
  return match ? match.idx : null;
}

function isLabCourse(row: RoutineRow): boolean {
  if (row.is_lab === true) return true;
  const m = /(\d)\s*$/.exec(row.subject_code.trim());
  if (m) {
    const d = Number.parseInt(m[1]!, 10);
    if (Number.isFinite(d) && d % 2 === 0) return true;
  }
  const t = row.subject.toLowerCase();
  return t.includes("sessional") || t.includes("lab");
}

function slotToneClass(row: RoutineRow): string {
  if (row.section.includes("+")) return "slot-joint";
  if (isLabCourse(row)) return "slot-lab";
  return "slot-theory";
}

export function CommitteeDaySheetView({
  allSourceRows,
  filteredRows,
  configuredPeriods,
  breakBeforePeriodIdx,
  semesterLabel,
  activeDay,
  onSelectDay,
  blockedPeriods,
  onInspectSlot,
  onQuickAdd,
  canEdit,
}: {
  allSourceRows: readonly RoutineRow[];
  filteredRows: readonly RoutineRow[];
  configuredPeriods: readonly PeriodDefinition[];
  breakBeforePeriodIdx: number | null;
  semesterLabel: string;
  activeDay: string;
  onSelectDay: (day: string) => void;
  blockedPeriods: Record<string, number[]>;
  onInspectSlot: (row: RoutineRow) => void;
  onQuickAdd: (prefill: Partial<RoutineRow>) => void;
  canEdit: boolean;
}) {
  const [showOffDaySections, setShowOffDaySections] = useState(true);

  const cohorts = useMemo(() => {
    const map = new Map<string, CohortEntry>();
    for (const r of allSourceRows) {
      const key = `${r.batch}::${r.section}`;
      if (!map.has(key)) {
        map.set(key, {
          key,
          batch: r.batch,
          section: r.section,
          semester: r.semester,
          isService: r.is_service,
        });
      }
    }
    return Array.from(map.values()).sort(compareBatchesDescending);
  }, [allSourceRows]);

  const daySlotLookup = useMemo(() => {
    const map = new Map<string, RoutineRow[]>();
    for (const r of filteredRows) {
      if (r.day !== activeDay) continue;
      const pIdx = resolvePeriodIdx(r, configuredPeriods);
      if (pIdx === null) continue;
      const key = `${r.batch}::${r.section}::${pIdx}`;
      const list = map.get(key) ?? [];
      list.push(r);
      map.set(key, list);
    }
    return map;
  }, [filteredRows, activeDay, configuredPeriods]);

  const visibleCohorts = useMemo(() => {
    if (showOffDaySections) return cohorts;
    return cohorts.filter((c) =>
      configuredPeriods.some((p) => {
        const list = daySlotLookup.get(`${c.key}::${p.idx}`);
        return list && list.length > 0;
      }),
    );
  }, [cohorts, showOffDaySections, configuredPeriods, daySlotLookup]);

  const dayBlockedSet = useMemo(() => {
    return new Set(blockedPeriods[activeDay] ?? []);
  }, [blockedPeriods, activeDay]);

  const regularPeriods = configuredPeriods.filter(
    (p) => p.idx < ONLINE_SLOT_IDX,
  );
  const onlinePeriods = configuredPeriods.filter(
    (p) => p.idx >= ONLINE_SLOT_IDX,
  );

  const dayCounts = useMemo(() => {
    const map = new Map<string, number>();
    for (const d of ACADEMIC_WEEK_DAYS) map.set(d, 0);
    for (const r of filteredRows) {
      map.set(r.day, (map.get(r.day) ?? 0) + 1);
    }
    return map;
  }, [filteredRows]);

  const middayBreak = useMemo(
    () => resolveMiddayBreak(configuredPeriods),
    [configuredPeriods],
  );

  const breakColumnIndex = useMemo(() => {
    if (breakBeforePeriodIdx === null) return -1;
    return regularPeriods.findIndex((p) => p.idx === breakBeforePeriodIdx);
  }, [regularPeriods, breakBeforePeriodIdx]);

  return (
    <div
      className="space-y-3"
      data-testid="committee-day-sheet-view"
    >
      {/* Single-Day Tab Bar + Print / Off-Day Controls */}
      <div className="no-print flex flex-wrap items-center justify-between gap-3 rounded-[var(--r-card)] border border-[var(--border-subtle)] bg-[var(--bg-elevated)] px-3.5 py-2.5">
        <div
          role="tablist"
          aria-label="Committee day sheet weekday selector"
          className="flex flex-wrap gap-1"
        >
          {ACADEMIC_WEEK_DAYS.map((day) => {
            const active = day === activeDay;
            const count = dayCounts.get(day) ?? 0;
            return (
              <button
                key={day}
                type="button"
                role="tab"
                aria-selected={active}
                data-testid={`committee-day-tab-${day}`}
                onClick={() => onSelectDay(day)}
                className={cn(
                  "inline-flex h-[32px] items-center gap-1.5 rounded-[var(--r-control)] border px-2.5 text-[12.5px] transition-colors",
                  active
                    ? "border-[var(--border-strong)] bg-[var(--bg-raised)] font-semibold text-[var(--ink-primary)] shadow-[inset_0_-2px_0_var(--accent-brand)]"
                    : "border-[var(--border-subtle)] bg-[var(--bg-surface)] font-medium text-[var(--ink-secondary)] hover:bg-[var(--surface-hover)] hover:text-[var(--ink-primary)]",
                )}
              >
                <span>{day}</span>
                <span
                  className={cn(
                    "font-mono-tabular text-[11px]",
                    active
                      ? "text-[var(--ink-secondary)]"
                      : "text-[var(--ink-muted)]",
                  )}
                >
                  ({count})
                </span>
              </button>
            );
          })}
        </div>

        <div className="flex flex-wrap items-center gap-3">
          <label className="flex cursor-pointer items-center gap-2 text-[12.5px] text-[var(--ink-secondary)]">
            <input
              type="checkbox"
              checked={showOffDaySections}
              onChange={(e) => setShowOffDaySections(e.target.checked)}
              data-testid="committee-show-off-days-toggle"
              className="h-3.5 w-3.5 accent-[var(--accent-brand)]"
            />
            <span>Show Off-Day Sections</span>
          </label>

          <Button
            type="button"
            variant="secondary"
            size="sm"
            onClick={() => window.print()}
            data-testid="committee-print-btn"
          >
            <Printer size={14} aria-hidden="true" />
            <span>Print / Save PDF</span>
          </Button>
        </div>
      </div>

      {/* Institutional Official Day Sheet */}
      <div className="ledger-sheet committee-sheet-print-root committee-print-sheet overflow-hidden">
        {/* Institutional Header Bar */}
        <div className="border-b border-[var(--border-subtle)] bg-[var(--bg-canvas)] px-4 py-3 text-center">
          <div className="font-serif-editorial text-[16px] font-semibold tracking-[-0.01em] text-[var(--ink-primary)]">
            Leading University · Dept. of CSE · Class Routine
          </div>
          <div className="mt-0.5 font-mono-tabular text-[12px] text-[var(--ink-secondary)]">
            {semesterLabel} · {activeDay} ({visibleCohorts.length} cohorts)
          </div>
        </div>

        <div className="committee-print-scroll overflow-x-auto">
          <table
            aria-label={`Official Committee Day Sheet for ${activeDay}`}
            className="committee-print-table w-full border-collapse text-left"
          >
            <thead>
              <tr className="border-b border-[var(--border-strong)] bg-[var(--bg-elevated)]">
                <th
                  scope="col"
                  className="sticky left-0 z-20 w-[108px] min-w-[108px] border-r border-[var(--border-subtle)] bg-[var(--bg-elevated)] px-2.5 py-2 font-mono-tabular text-[11px] font-semibold uppercase tracking-[0.04em] text-[var(--ink-primary)]"
                >
                  Batch / Sec
                </th>
                {regularPeriods.map((period, idx) => (
                  <Fragment key={period.idx}>
                    {idx === breakColumnIndex && (
                      <th
                        key="break-col-header"
                        scope="col"
                        data-testid="committee-break-col"
                        data-break-after={middayBreak.afterPeriodIdx ?? "none"}
                        aria-label={`Midday Break ${middayBreak.start} to ${middayBreak.end}`}
                        title={`Midday Break (${middayBreak.start}–${middayBreak.end})`}
                        className="committee-break-col w-[52px] min-w-[52px] border-x border-[var(--border-strong)] bg-[var(--bg-canvas)] px-1 py-2 text-center font-mono-tabular text-[10px] font-semibold tracking-[0.14em] text-[var(--ink-muted)]"
                      >
                        <div>BREAK</div>
                        {middayBreak.start && (
                          <div className="mt-0.5 text-[9px] font-normal leading-[1.15] tracking-normal text-[var(--ink-muted)]">
                            <div>{middayBreak.start}</div>
                            {middayBreak.end && <div>{middayBreak.end}</div>}
                          </div>
                        )}
                      </th>
                    )}
                    <th
                      scope="col"
                      className="min-w-[116px] border-l border-[var(--border-subtle)] px-2 py-2 text-center"
                    >
                      <div className="font-mono-tabular text-[11.5px] font-semibold text-[var(--ink-primary)]">
                        P{period.idx}
                      </div>
                      <div className="font-mono-tabular text-[10.5px] text-[var(--ink-secondary)]">
                        {ClockTime.toHm(period.start)}–
                        {ClockTime.toHm(period.end)}
                      </div>
                    </th>
                  </Fragment>
                ))}
                {onlinePeriods.map((period) => (
                  <th
                    key={period.idx}
                    scope="col"
                    className="min-w-[116px] border-l-2 border-[var(--border-strong)] bg-[var(--bg-canvas)] px-2 py-2 text-center"
                  >
                    <div className="font-mono-tabular text-[11.5px] font-semibold text-[var(--ink-primary)]">
                      Online P{period.idx}
                    </div>
                    <div className="font-mono-tabular text-[10.5px] text-[var(--ink-secondary)]">
                      {ClockTime.toHm(period.start)}–
                      {ClockTime.toHm(period.end)}
                    </div>
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {visibleCohorts.length === 0 ? (
                <tr>
                  <td
                    colSpan={
                      1 +
                      regularPeriods.length +
                      onlinePeriods.length +
                      (breakColumnIndex >= 0 ? 1 : 0)
                    }
                    className="px-4 py-10 text-center text-[13px] text-[var(--ink-muted)]"
                  >
                    No cohorts scheduled for {activeDay}.
                  </td>
                </tr>
              ) : (
                visibleCohorts.map((cohort, rowIdx) => {
                  const rowHasAnyClass = configuredPeriods.some((p) => {
                    const list = daySlotLookup.get(`${cohort.key}::${p.idx}`);
                    return list && list.length > 0;
                  });
                  return (
                    <tr
                      key={cohort.key}
                      data-testid={`committee-row-${cohort.batch}-${cohort.section}`}
                      className={cn(
                        "border-b border-[var(--border-subtle)]",
                        !rowHasAnyClass && "bg-[var(--bg-surface)]/70",
                      )}
                    >
                      <th
                        scope="row"
                        className="sticky left-0 z-10 border-r border-[var(--border-subtle)] bg-[var(--bg-elevated)] px-2.5 py-2 text-left font-mono-tabular text-[12px] font-semibold text-[var(--ink-primary)]"
                      >
                        <div className="flex items-center justify-between gap-1">
                          <span>
                            {cohort.batch}
                            {cohort.section ? `-${cohort.section}` : ""}
                          </span>
                          {!rowHasAnyClass && (
                            <span className="text-[10px] font-normal text-[var(--ink-muted)]">
                              OFF
                            </span>
                          )}
                        </div>
                      </th>

                      {regularPeriods.map((period, idx) => {
                        const cellRows =
                          daySlotLookup.get(`${cohort.key}::${period.idx}`) ??
                          [];
                        const isBlocked = dayBlockedSet.has(period.idx);
                        return (
                          <Fragment key={period.idx}>
                            {idx === breakColumnIndex && rowIdx === 0 && (
                              <td
                                key="break-vertical-cell"
                                rowSpan={visibleCohorts.length}
                                data-testid="committee-break-column"
                                className="border-x border-[var(--border-strong)] bg-[var(--bg-canvas)] text-center align-middle"
                              >
                                <div
                                  className="mx-auto select-none font-mono-tabular text-[11px] font-semibold tracking-[0.38em] text-[var(--ink-muted)]"
                                  style={{
                                    writingMode: "vertical-rl",
                                    textOrientation: "upright",
                                  }}
                                >
                                  BREAK
                                </div>
                              </td>
                            )}
                            <td
                              className={cn(
                                "border-l border-[var(--border-subtle)] p-1 align-top",
                                isBlocked && "hatch-blocked",
                              )}
                            >
                              {isBlocked && cellRows.length === 0 ? (
                                <div className="px-1.5 py-2 text-center font-mono-tabular text-[10px] font-semibold tracking-[0.06em] uppercase">
                                  Jummah
                                </div>
                              ) : cellRows.length === 0 ? (
                                canEdit ? (
                                  <button
                                    type="button"
                                    aria-label={`Add slot for ${cohort.batch}-${cohort.section} P${period.idx}`}
                                    onClick={() =>
                                      onQuickAdd({
                                        day: activeDay,
                                        time_start: period.start,
                                        time_end: period.end,
                                        batch: cohort.batch,
                                        section: cohort.section,
                                        semester: cohort.semester,
                                        is_service: cohort.isService,
                                      })
                                    }
                                    className="print:hidden h-[38px] w-full rounded-[4px] border border-transparent text-[11px] text-transparent transition-colors hover:border-dashed hover:border-[var(--border-control)] hover:text-[var(--ink-muted)]"
                                  >
                                    +
                                  </button>
                                ) : (
                                  <div className="h-[38px]" />
                                )
                              ) : (
                                <div className="space-y-1">
                                  {cellRows.map((slot) => (
                                    <button
                                      key={slot.id}
                                      type="button"
                                      onClick={() => onInspectSlot(slot)}
                                      className={cn(
                                        "w-full rounded-[4px] px-1.5 py-1 text-left transition-opacity hover:opacity-90",
                                        slotToneClass(slot),
                                      )}
                                    >
                                      <div className="truncate font-mono-tabular text-[11px] font-semibold leading-tight">
                                        {slot.subject_code}
                                      </div>
                                      <div className="truncate font-mono-tabular text-[10px] leading-tight opacity-90">
                                        {slot.teacher_code || "TBA"} ·{" "}
                                        {slot.room || "TBA"}
                                      </div>
                                    </button>
                                  ))}
                                </div>
                              )}
                            </td>
                          </Fragment>
                        );
                      })}

                      {onlinePeriods.map((period) => {
                        const cellRows =
                          daySlotLookup.get(`${cohort.key}::${period.idx}`) ??
                          [];
                        return (
                          <td
                            key={period.idx}
                            className="border-l-2 border-[var(--border-strong)] bg-[var(--bg-canvas)]/40 p-1 align-top"
                          >
                            {cellRows.length > 0 ? (
                              <div className="space-y-1">
                                {cellRows.map((slot) => (
                                  <button
                                    key={slot.id}
                                    type="button"
                                    onClick={() => onInspectSlot(slot)}
                                    className={cn(
                                      "w-full rounded-[4px] px-1.5 py-1 text-left transition-opacity hover:opacity-90",
                                      slotToneClass(slot),
                                    )}
                                  >
                                    <div className="truncate font-mono-tabular text-[11px] font-semibold leading-tight">
                                      {slot.subject_code}
                                    </div>
                                    <div className="truncate font-mono-tabular text-[10px] leading-tight opacity-90">
                                      {slot.teacher_code || "TBA"} ·{" "}
                                      {slot.room || "Online"}
                                    </div>
                                  </button>
                                ))}
                              </div>
                            ) : (
                              <div className="h-[38px]" />
                            )}
                          </td>
                        );
                      })}
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>

        {/* Footnote & Print-Only 3-Role Committee Signature Footer */}
        <div className="border-t border-[var(--border-subtle)] bg-[var(--bg-surface)] px-4 py-2.5 text-[11.5px] text-[var(--ink-muted)]">
          <div className="flex flex-wrap items-center justify-between gap-2">
            <span>
              <strong>TBA</strong> = To Be Announced (Faculty not yet assigned)
              <span className="print:hidden">
                {" "}· Click any cell to open Slot Provenance Inspector.
              </span>
            </span>
            <span className="font-mono-tabular">
              Leading University · CSE Routine Committee
            </span>
          </div>

          <div className="print-only-footer print-signatures mt-8 grid-cols-3 gap-8 pt-6 text-center text-[11.5px] text-[var(--ink-primary)]">
            <div className="border-t border-[var(--border-strong)] pt-1.5">
              Member Secretary, Routine Committee
            </div>
            <div className="border-t border-[var(--border-strong)] pt-1.5">
              Convener, Routine Committee
            </div>
            <div className="border-t border-[var(--border-strong)] pt-1.5">
              Head, Dept. of CSE
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
