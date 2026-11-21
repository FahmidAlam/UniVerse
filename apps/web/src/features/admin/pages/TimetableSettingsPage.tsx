import {
  Clock,
  Lock,
  Plus,
  Sliders,
  Sparkle,
  Trash,
  WarningCircle,
} from "@phosphor-icons/react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useEffect, useMemo, useState } from "react";
import { toast } from "sonner";
import {
  LedgerErrorRecovery,
  LedgerTableSkeleton,
} from "@/components/ui/AsyncStates";
import { Badge } from "@/components/ui/Badge";
import { Button } from "@/components/ui/Button";
import { ConfirmDialog } from "@/components/ui/ConfirmDialog";
import { StickyDirtyBar } from "@/components/ui/StickyDirtyBar";
import { Switch } from "@/components/ui/Switch";
import { ClockTime } from "@/core/utils/clockTime";
import { ACADEMIC_WEEK_DAYS } from "@/features/admin/services/facultyService";
import {
  fetchTimetableSettings,
  ONLINE_SLOT_COL,
  ONLINE_SLOT_IDX,
  partitionPeriods,
  REGULAR_PERIOD_COLS,
  saveTimetableSettings,
  setOnlineSlotEnabled,
  setRegularSlotCount,
  syncFridayJummahBlock,
  WEIGHT_PRESETS,
  type SolverWeights,
  type TimetableSettingsRecord,
} from "@/features/admin/services/settingsService";
import { useAuth } from "@/features/auth/AuthProvider";
import { cn } from "@/lib/utils";

type SettingsTabId = "clock" | "rules" | "weights";

const COMMITTEE_POLICY_LEDGER: ReadonlyArray<{
  code: string;
  rule: string;
  pillar: string;
}> = [
  {
    code: "R1",
    rule: "Consecutive 2-day section weekends across the 7-day week (Sunday–Saturday).",
    pillar: "Batch & Section Structure",
  },
  {
    code: "R2",
    rule: "Balanced weekly days-off parity across sections in the same batch (max +/- 1 day variance).",
    pillar: "Batch & Section Structure",
  },
  {
    code: "R3",
    rule: "Compact section schedules — no gaps of 2 consecutive periods between classes (1-slot gap acceptable).",
    pillar: "Batch & Section Structure",
  },
  {
    code: "R4",
    rule: "Block CSE faculty periods committed to external department teaching.",
    pillar: "Faculty Availability & Workload",
  },
  {
    code: "R5",
    rule: "Schedule guest faculty from external departments (GED, EEE, Physics, English) strictly within declared available windows.",
    pillar: "Faculty Availability & Workload",
  },
  {
    code: "R6",
    rule: "Category-based workload spread (Permanent: 4–5 working days; Adjunct: 2 crs <=2d, 3 crs 3–4d, 4+ crs 4–5d).",
    pillar: "Faculty Availability & Workload",
  },
  {
    code: "R7",
    rule: "Permanent faculty weekly off-day bounds (minimum 2 days off, maximum 3 days off per 7-day week).",
    pillar: "Faculty Availability & Workload",
  },
  {
    code: "R8",
    rule: "Prioritize declared individual faculty day and time-slot preferences.",
    pillar: "Faculty Availability & Workload",
  },
  {
    code: "R9",
    rule: "SUST traveling adjunct compactness (all daily classes before or after break; max daily gap <=2 slots).",
    pillar: "Faculty Availability & Workload",
  },
  {
    code: "R10",
    rule: "EEE-owned ECL laboratory allocation strictly within declared available windows.",
    pillar: "Laboratories & Course Placement",
  },
  {
    code: "R11",
    rule: "Physics laboratory exclusivity for Physics lab courses within declared availability.",
    pillar: "Laboratories & Course Placement",
  },
  {
    code: "R12",
    rule: "Sessional weekly class counts by credit (1–1.5 Cr = 2/wk; 2 Cr = 3/wk, 2 consecutive slots preferred).",
    pillar: "Laboratories & Course Placement",
  },
  {
    code: "R13",
    rule: "1–2 credit CSE theory courses scheduled in 2 consecutive slots on a single day in the same room.",
    pillar: "Laboratories & Course Placement",
  },
  {
    code: "R14",
    rule: "Dynamic general classroom pool management per semester.",
    pillar: "Classroom & Daily Grid",
  },
  {
    code: "R15",
    rule: "Flexible 6-slot or 7-slot regular daily on-campus period configuration (independent of optional online slots).",
    pillar: "Classroom & Daily Grid",
  },
];

const WEIGHT_LABELS: ReadonlyArray<{
  key: keyof SolverWeights;
  title: string;
  hint: string;
}> = [
  {
    key: "different_days",
    title: "Spread Across Different Days",
    hint: "Penalizes placing repeat sessions of the same course on the same day.",
  },
  {
    key: "compactness",
    title: "Schedule Compactness",
    hint: "Reduces idle multi-hour gaps between teaching periods for a batch.",
  },
  {
    key: "spread",
    title: "Balanced Daily Load",
    hint: "Evens session density across active departmental teaching days.",
  },
  {
    key: "late_slot",
    title: "Avoid Late Afternoon Slots",
    hint: "Preferentially fills morning and midday teaching slots before late afternoon.",
  },
];

export function TimetableSettingsPage() {
  const { isDevPreview } = useAuth();
  const queryClient = useQueryClient();

  const [activeTab, setActiveTab] = useState<SettingsTabId>("clock");
  const [draft, setDraft] = useState<TimetableSettingsRecord | null>(null);
  const [fixedInput, setFixedInput] = useState<string>("");
  const [newBatchKey, setNewBatchKey] = useState("");
  const [newBatchSemester, setNewBatchSemester] = useState("1");
  const [discardDialogOpen, setDiscardDialogOpen] = useState(false);

  const {
    data: savedSettings,
    isLoading,
    isError,
    error,
    refetch,
  } = useQuery({
    queryKey: ["admin-timetable-settings", isDevPreview],
    queryFn: () => fetchTimetableSettings(isDevPreview),
    retry: false,
  });

  useEffect(() => {
    if (savedSettings) {
      setDraft(structuredClone(savedSettings));
      setFixedInput(
        savedSettings.fixed_sessions_per_week !== null
          ? String(savedSettings.fixed_sessions_per_week)
          : "",
      );
    }
  }, [savedSettings]);

  const { regularPeriods, onlinePeriod } = useMemo(
    () =>
      draft
        ? partitionPeriods(draft)
        : { regularPeriods: [], onlinePeriod: null },
    [draft],
  );

  const isDirty = useMemo(() => {
    if (!draft || !savedSettings) return false;
    return JSON.stringify(draft) !== JSON.stringify(savedSettings);
  }, [draft, savedSettings]);

  const validationError = useMemo(() => {
    if (!draft) return null;
    const periodError = ClockTime.validateMonotonicPeriods(draft.periods);
    if (periodError) return periodError;
    if (
      !Number.isInteger(draft.weeks_in_term) ||
      draft.weeks_in_term < 1 ||
      draft.weeks_in_term > 52
    ) {
      return "Teaching weeks in term must be between 1 and 52.";
    }
    if (draft.working_days.length === 0) {
      return "Select at least one active working day.";
    }
    const fixed = draft.fixed_sessions_per_week;
    if (fixed !== null && (!Number.isInteger(fixed) || fixed < 0 || fixed > 7)) {
      return "Fixed sessions per week must be empty (derived) or between 0 and 7.";
    }
    return null;
  }, [draft]);

  const saveMutation = useMutation({
    mutationFn: (nextSettings: TimetableSettingsRecord) =>
      saveTimetableSettings(nextSettings, isDevPreview),
    onSuccess: (persisted) => {
      void queryClient.invalidateQueries({
        queryKey: ["admin-timetable-settings"],
      });
      void queryClient.invalidateQueries({
        queryKey: ["admin-dashboard-counts"],
      });
      setDraft(structuredClone(persisted));
      setFixedInput(
        persisted.fixed_sessions_per_week !== null
          ? String(persisted.fixed_sessions_per_week)
          : "",
      );
      toast.success("Saved timetable settings (row id=1)");
    },
    onError: (err) => {
      toast.error("Could not save timetable settings", {
        description:
          err instanceof Error ? err.message : "Database upsert failed.",
      });
    },
  });

  const handleDiscard = () => {
    if (!savedSettings) return;
    setDraft(structuredClone(savedSettings));
    setFixedInput(
      savedSettings.fixed_sessions_per_week !== null
        ? String(savedSettings.fixed_sessions_per_week)
        : "",
    );
    setDiscardDialogOpen(false);
    toast.message("Reverted unsaved settings edits");
  };

  const toggleWorkingDay = (day: string) => {
    setDraft((prev) => {
      if (!prev) return prev;
      const exists = prev.working_days.includes(day);
      const rawNext = exists
        ? prev.working_days.filter((d) => d !== day)
        : [...prev.working_days, day];
      const ordered = ACADEMIC_WEEK_DAYS.filter((d) => rawNext.includes(d));
      return { ...prev, working_days: ordered };
    });
  };

  const updatePeriodTime = (
    idx: number,
    field: "start" | "end",
    raw: string,
  ) => {
    setDraft((prev) => {
      if (!prev) return prev;
      const nextPeriods = prev.periods.map((p) => {
        if (p.idx !== idx) return p;
        const updated = { ...p, [field]: raw };
        return {
          ...updated,
          label: `${updated.start}-${updated.end}`,
        };
      });
      return { ...prev, periods: nextPeriods };
    });
  };

  const repairAllPeriodClocks = () => {
    setDraft((prev) => {
      if (!prev) return prev;
      const repaired = ClockTime.repairSequence(prev.periods).map((p, i) => ({
        ...p,
        label: `${p.start}-${p.end}`,
        col:
          p.col ||
          (p.idx >= ONLINE_SLOT_IDX
            ? ONLINE_SLOT_COL
            : (REGULAR_PERIOD_COLS[i] ?? "K")),
      }));
      toast.message("Normalized 24-hour teaching sequence");
      return { ...prev, periods: repaired };
    });
  };

  const toggleExcludedPeriod = (idx: number) => {
    setDraft((prev) => {
      if (!prev) return prev;
      const exists = prev.excluded_periods.includes(idx);
      const next = exists
        ? prev.excluded_periods.filter((n) => n !== idx)
        : [...prev.excluded_periods, idx].sort((a, b) => a - b);
      return { ...prev, excluded_periods: next };
    });
  };

  const toggleFridayJummah = (checked: boolean) => {
    setDraft((prev) => {
      if (!prev) return prev;
      return {
        ...prev,
        friday_no_p4: checked,
        blocked_periods: syncFridayJummahBlock(checked, prev.blocked_periods),
      };
    });
  };

  const toggleBlockedCell = (day: string, periodIdx: number) => {
    setDraft((prev) => {
      if (!prev) return prev;
      if (day === "Friday" && periodIdx === 4 && prev.friday_no_p4) {
        return prev;
      }
      const dayList = prev.blocked_periods[day] ?? [];
      const exists = dayList.includes(periodIdx);
      const nextDayList = exists
        ? dayList.filter((n) => n !== periodIdx)
        : [...dayList, periodIdx].sort((a, b) => a - b);
      const nextBlocked = { ...prev.blocked_periods };
      if (nextDayList.length > 0) {
        nextBlocked[day] = nextDayList;
      } else {
        delete nextBlocked[day];
      }
      return {
        ...prev,
        blocked_periods: syncFridayJummahBlock(prev.friday_no_p4, nextBlocked),
      };
    });
  };

  const addSemesterMapping = () => {
    const batch = newBatchKey.trim().toUpperCase();
    const sem = Number.parseInt(newBatchSemester, 10);
    if (!batch || !Number.isInteger(sem) || sem < 1 || sem > 12) {
      toast.error("Enter a valid batch label and semester (1–12).");
      return;
    }
    setDraft((prev) => {
      if (!prev) return prev;
      return {
        ...prev,
        semester_map: { ...prev.semester_map, [batch]: sem },
      };
    });
    setNewBatchKey("");
  };

  const removeSemesterMapping = (batch: string) => {
    setDraft((prev) => {
      if (!prev) return prev;
      const next = { ...prev.semester_map };
      delete next[batch];
      return { ...prev, semester_map: next };
    });
  };

  const tabs: Array<{
    id: SettingsTabId;
    label: string;
    icon: typeof Clock;
  }> = [
    { id: "clock", label: "Term Clock & R15 Grid", icon: Clock },
    { id: "rules", label: "Committee Rules & Blocked Slots", icon: Lock },
    { id: "weights", label: "Optimization Weights", icon: Sliders },
  ];

  return (
    <div className={cn("space-y-4", isDirty && "pb-10")}>
      <header className="flex flex-wrap items-end justify-between gap-4 border-b border-[var(--border-subtle)] pb-4">
        <div>
          <h1 className="font-editorial text-[26px] font-semibold tracking-[-0.02em] text-[var(--ink-primary)]">
            Timetable Settings
          </h1>
          <p className="mt-1 max-w-[68ch] text-[13.5px] leading-[1.55] text-[var(--ink-secondary)]">
            Singleton departmental schedule policy controlling term clocks, R15
            daily on-campus slots, separate online slots, blocked windows, and
            solver weights.
          </p>
        </div>

        {draft && (
          <div className="flex flex-wrap items-center gap-2">
            <Badge tone="neutral" mono>
              {regularPeriods.length}-Slot On-Campus
            </Badge>
            <Badge tone={draft.allow_online_periods ? "joint" : "neutral"} mono>
              {draft.allow_online_periods
                ? "Online Slot Enabled"
                : "Online Slot Off"}
            </Badge>
            <Badge tone={draft.friday_no_p4 ? "pine" : "neutral"}>
              {draft.friday_no_p4 ? "Friday P4 Locked" : "Friday P4 Open"}
            </Badge>
          </div>
        )}
      </header>

      {isLoading || !draft ? (
        <LedgerTableSkeleton rows={5} label="Loading timetable settings" />
      ) : isError ? (
        <LedgerErrorRecovery
          title="Could not load timetable settings"
          message={
            error instanceof Error ? error.message : "Supabase query failed."
          }
          onRetry={() => void refetch()}
        />
      ) : (
        <>
          <div className="flex flex-wrap items-center justify-between gap-3 border-b border-[var(--border-subtle)] pb-3">
            <div
              role="tablist"
              aria-label="Timetable settings sections"
              className="flex flex-wrap gap-1.5"
            >
              {tabs.map((tab) => {
                const Icon = tab.icon;
                const active = activeTab === tab.id;
                return (
                  <button
                    key={tab.id}
                    type="button"
                    role="tab"
                    aria-selected={active}
                    onClick={() => setActiveTab(tab.id)}
                    className={cn(
                      "inline-flex h-9 items-center gap-2 rounded-[var(--r-control)] border px-3 text-[13px] font-medium transition-colors",
                      active
                        ? "border-[var(--ink-primary)] bg-[var(--ink-primary)] text-[var(--bg-elevated)]"
                        : "border-[var(--border-subtle)] bg-[var(--bg-elevated)] text-[var(--ink-secondary)] hover:bg-[var(--surface-hover)] hover:text-[var(--ink-primary)]",
                    )}
                  >
                    <Icon size={15} aria-hidden="true" />
                    <span>{tab.label}</span>
                  </button>
                );
              })}
            </div>
          </div>

          {validationError && (
            <div
              role="alert"
              className="flex items-start gap-2.5 rounded-[var(--r-control)] border border-[var(--sem-conflict-border)] bg-[var(--sem-conflict-bg)] px-3.5 py-2.5 text-[13px] text-[var(--sem-conflict-ink)]"
            >
              <WarningCircle
                size={16}
                className="mt-0.5 shrink-0"
                aria-hidden="true"
              />
              <span>{validationError}</span>
            </div>
          )}

          {activeTab === "clock" && (
            <div className="space-y-4">
              <section className="ledger-card grid gap-4 p-5 md:grid-cols-3">
                <div>
                  <label
                    htmlFor="settings-semester-label"
                    className="mb-1.5 block text-[12.5px] font-medium text-[var(--ink-primary)]"
                  >
                    Active Term Label
                  </label>
                  <input
                    id="settings-semester-label"
                    type="text"
                    value={draft.semester_label ?? ""}
                    onChange={(e) =>
                      setDraft((prev) =>
                        prev
                          ? { ...prev, semester_label: e.target.value }
                          : prev,
                      )
                    }
                    placeholder="e.g. Spring 2026"
                    className="h-[38px] w-full rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-3 text-[13.5px] text-[var(--ink-primary)] focus:border-[var(--ink-primary)] focus:outline-none"
                  />
                </div>

                <div>
                  <label
                    htmlFor="settings-weeks"
                    className="mb-1.5 block text-[12.5px] font-medium text-[var(--ink-primary)]"
                  >
                    Teaching Weeks (1–52)
                  </label>
                  <input
                    id="settings-weeks"
                    type="number"
                    min={1}
                    max={52}
                    value={draft.weeks_in_term}
                    onChange={(e) => {
                      const val = Number.parseInt(e.target.value, 10);
                      setDraft((prev) =>
                        prev
                          ? {
                              ...prev,
                              weeks_in_term: Number.isFinite(val) ? val : 0,
                            }
                          : prev,
                      );
                    }}
                    className="font-mono-tabular h-[38px] w-full rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-3 text-[13.5px] text-[var(--ink-primary)] focus:border-[var(--ink-primary)] focus:outline-none"
                  />
                </div>

                <div>
                  <label
                    htmlFor="settings-fixed-sessions"
                    className="mb-1.5 block text-[12.5px] font-medium text-[var(--ink-primary)]"
                  >
                    Fixed Sessions / Week (optional 0–7)
                  </label>
                  <input
                    id="settings-fixed-sessions"
                    type="text"
                    inputMode="numeric"
                    value={fixedInput}
                    onChange={(e) => {
                      const raw = e.target.value;
                      setFixedInput(raw);
                      const trimmed = raw.trim();
                      setDraft((prev) => {
                        if (!prev) return prev;
                        if (trimmed === "") {
                          return { ...prev, fixed_sessions_per_week: null };
                        }
                        if (/^\d+$/.test(trimmed)) {
                          return {
                            ...prev,
                            fixed_sessions_per_week: Number.parseInt(
                              trimmed,
                              10,
                            ),
                          };
                        }
                        return { ...prev, fixed_sessions_per_week: -1 };
                      });
                    }}
                    placeholder="Blank = derived from credit"
                    className="font-mono-tabular h-[38px] w-full rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-3 text-[13.5px] text-[var(--ink-primary)] placeholder:text-[var(--ink-muted)] focus:border-[var(--ink-primary)] focus:outline-none"
                  />
                </div>
              </section>

              <section className="ledger-card p-5">
                <div className="flex flex-wrap items-center justify-between gap-3">
                  <div>
                    <h2 className="text-[15px] font-semibold text-[var(--ink-primary)]">
                      Active Departmental Teaching Days
                    </h2>
                    <p className="mt-0.5 text-[12.5px] text-[var(--ink-secondary)]">
                      Days enabled for solver placement across the 7-day academic
                      calendar.
                    </p>
                  </div>
                  <div className="flex flex-wrap gap-1.5">
                    {ACADEMIC_WEEK_DAYS.map((day) => {
                      const active = draft.working_days.includes(day);
                      return (
                        <button
                          key={day}
                          type="button"
                          aria-pressed={active}
                          onClick={() => toggleWorkingDay(day)}
                          className={cn(
                            "h-8 rounded-[var(--r-control)] border px-2.5 text-[12px] font-medium transition-colors",
                            active
                              ? "border-[var(--accent-pine)] bg-[var(--accent-pine-soft)] text-[var(--accent-pine)]"
                              : "border-[var(--border-subtle)] bg-[var(--bg-elevated)] text-[var(--ink-secondary)] hover:bg-[var(--surface-hover)]",
                          )}
                        >
                          {day.slice(0, 3)}
                        </button>
                      );
                    })}
                  </div>
                </div>
              </section>

              {/* R15 Regular Daily On-Campus Slots (6-Slot vs 7-Slot, decoupled from Online Slot) */}
              <section className="ledger-card space-y-4 p-5">
                <div className="flex flex-wrap items-center justify-between gap-3">
                  <div>
                    <h2 className="text-[15px] font-semibold text-[var(--ink-primary)]">
                      R15 Regular Daily On-Campus Period Clock
                    </h2>
                    <p className="mt-0.5 text-[12.5px] text-[var(--ink-secondary)]">
                      24-hour <code className="font-mono-tabular">HH:MM</code>{" "}
                      boundaries for regular on-campus classes across workbook
                      columns{" "}
                      <code className="font-mono-tabular">D, E, F, H, I, J, K</code>.
                    </p>
                  </div>

                  <div className="flex flex-wrap items-center gap-2">
                    <div
                      role="group"
                      aria-label="R15 regular on-campus daily slots"
                      className="inline-flex items-center gap-1 rounded-[var(--r-control)] border border-[var(--border-subtle)] bg-[var(--bg-canvas)] p-0.5"
                    >
                      <Button
                        variant={
                          regularPeriods.length === 6 ? "primary" : "ghost"
                        }
                        size="sm"
                        aria-pressed={regularPeriods.length === 6}
                        onClick={() =>
                          setDraft((prev) =>
                            prev ? setRegularSlotCount(prev, 6) : prev,
                          )
                        }
                      >
                        6-Slot Grid
                      </Button>
                      <Button
                        variant={
                          regularPeriods.length >= 7 ? "primary" : "ghost"
                        }
                        size="sm"
                        aria-pressed={regularPeriods.length >= 7}
                        onClick={() =>
                          setDraft((prev) =>
                            prev ? setRegularSlotCount(prev, 7) : prev,
                          )
                        }
                      >
                        7-Slot Grid
                      </Button>
                    </div>
                    <Button
                      variant="secondary"
                      size="sm"
                      onClick={repairAllPeriodClocks}
                    >
                      <Sparkle size={14} aria-hidden="true" />
                      <span>Repair 24h Clocks</span>
                    </Button>
                  </div>
                </div>

                <div className="overflow-x-auto">
                  <table className="w-full border-collapse text-left text-[13px]">
                    <thead>
                      <tr className="border-b border-[var(--border-subtle)] text-[11px] font-semibold uppercase tracking-[0.06em] text-[var(--ink-muted)]">
                        <th className="py-2 pr-3">Period</th>
                        <th className="py-2 pr-3">Excel Col</th>
                        <th className="py-2 pr-3">Start (HH:MM)</th>
                        <th className="py-2 pr-3">End (HH:MM)</th>
                        <th className="py-2 pr-3">Mode</th>
                        <th className="py-2 text-right">Excluded</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-[var(--border-subtle)]">
                      {regularPeriods.map((period) => {
                        const isExcluded = draft.excluded_periods.includes(
                          period.idx,
                        );
                        return (
                          <tr key={period.idx}>
                            <td className="font-mono-tabular py-2.5 pr-3 font-semibold text-[var(--ink-primary)]">
                              P{period.idx}
                            </td>
                            <td className="py-2.5 pr-3">
                              <Badge tone="neutral" mono>
                                Col {period.col}
                              </Badge>
                            </td>
                            <td className="py-2.5 pr-3">
                              <input
                                type="text"
                                aria-label={`Period ${period.idx} start time`}
                                value={period.start}
                                onChange={(e) =>
                                  updatePeriodTime(
                                    period.idx,
                                    "start",
                                    e.target.value,
                                  )
                                }
                                className="font-mono-tabular h-8 w-[108px] rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-2.5 text-[13px] text-[var(--ink-primary)] focus:border-[var(--ink-primary)] focus:outline-none"
                              />
                            </td>
                            <td className="py-2.5 pr-3">
                              <input
                                type="text"
                                aria-label={`Period ${period.idx} end time`}
                                value={period.end}
                                onChange={(e) =>
                                  updatePeriodTime(
                                    period.idx,
                                    "end",
                                    e.target.value,
                                  )
                                }
                                className="font-mono-tabular h-8 w-[108px] rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-2.5 text-[13px] text-[var(--ink-primary)] focus:border-[var(--ink-primary)] focus:outline-none"
                              />
                            </td>
                            <td className="py-2.5 pr-3">
                              <Badge tone="theory">On-Campus</Badge>
                            </td>
                            <td className="py-2.5 text-right">
                              <Switch
                                checked={isExcluded}
                                onCheckedChange={() =>
                                  toggleExcludedPeriod(period.idx)
                                }
                                aria-label={`Exclude period P${period.idx}`}
                              />
                            </td>
                          </tr>
                        );
                      })}
                    </tbody>
                  </table>
                </div>
              </section>

              {/* Separate Optional Online Slot Configuration (Independent of R15 6- vs 7-Slot Regular Grid) */}
              <section
                data-testid="online-slot-config-card"
                className="ledger-card space-y-3 p-5"
              >
                <div className="flex items-center justify-between gap-3">
                  <div>
                    <h2 className="text-[15px] font-semibold text-[var(--ink-primary)]">
                      Optional Online Slot Allocation
                    </h2>
                    <p className="mt-0.5 text-[12.5px] text-[var(--ink-secondary)]">
                      Configured separately from regular daily on-campus P1–P6 /
                      P1–P7 slots. Enables the reserved evening online lane when
                      permitted by committee policy.
                    </p>
                  </div>
                  <Switch
                    id="allow-online-slot-switch"
                    checked={draft.allow_online_periods}
                    onCheckedChange={(checked) =>
                      setDraft((prev) =>
                        prev ? setOnlineSlotEnabled(prev, checked) : prev,
                      )
                    }
                    aria-label="Allow online slot allocation"
                  />
                </div>

                {draft.allow_online_periods && onlinePeriod && (
                  <div className="flex flex-wrap items-center gap-4 rounded-[var(--r-control)] border border-[var(--border-subtle)] bg-[var(--bg-canvas)]/60 px-4 py-3 text-[13px]">
                    <div className="flex items-center gap-2">
                      <span className="font-mono-tabular font-semibold text-[var(--ink-primary)]">
                        Online (P{onlinePeriod.idx})
                      </span>
                      <Badge tone="neutral" mono>
                        Col {onlinePeriod.col}
                      </Badge>
                      <Badge tone="joint">Online Slot</Badge>
                    </div>
                    <div className="flex flex-wrap items-center gap-2.5">
                      <label
                        htmlFor="online-slot-start"
                        className="text-[12px] text-[var(--ink-secondary)]"
                      >
                        Start
                      </label>
                      <input
                        id="online-slot-start"
                        type="text"
                        aria-label="Online slot start time"
                        value={onlinePeriod.start}
                        onChange={(e) =>
                          updatePeriodTime(
                            onlinePeriod.idx,
                            "start",
                            e.target.value,
                          )
                        }
                        className="font-mono-tabular h-8 w-[104px] rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-2.5 text-[13px] text-[var(--ink-primary)] focus:border-[var(--ink-primary)] focus:outline-none"
                      />
                      <label
                        htmlFor="online-slot-end"
                        className="text-[12px] text-[var(--ink-secondary)]"
                      >
                        End
                      </label>
                      <input
                        id="online-slot-end"
                        type="text"
                        aria-label="Online slot end time"
                        value={onlinePeriod.end}
                        onChange={(e) =>
                          updatePeriodTime(
                            onlinePeriod.idx,
                            "end",
                            e.target.value,
                          )
                        }
                        className="font-mono-tabular h-8 w-[104px] rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-2.5 text-[13px] text-[var(--ink-primary)] focus:border-[var(--ink-primary)] focus:outline-none"
                      />
                    </div>
                  </div>
                )}
              </section>

              <section className="ledger-card space-y-3 p-5">
                <div>
                  <h2 className="text-[15px] font-semibold text-[var(--ink-primary)]">
                    Batch to Semester Map
                  </h2>
                  <p className="mt-0.5 text-[12.5px] text-[var(--ink-secondary)]">
                    Maps intake batch labels (e.g.{" "}
                    <code className="font-mono-tabular">60</code>) to numeric
                    semester levels (1–12).
                  </p>
                </div>

                <div className="flex flex-wrap items-center gap-2">
                  <input
                    type="text"
                    value={newBatchKey}
                    onChange={(e) => setNewBatchKey(e.target.value)}
                    placeholder="e.g. Batch 60"
                    aria-label="Batch label"
                    className="font-mono-tabular h-[36px] min-w-[160px] w-[184px] rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-3 text-[13px]"
                  />
                  <input
                    type="number"
                    min={1}
                    max={12}
                    value={newBatchSemester}
                    onChange={(e) => setNewBatchSemester(e.target.value)}
                    aria-label="Semester number"
                    className="font-mono-tabular h-[36px] w-[96px] rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-3 text-[13px]"
                  />
                  <Button
                    variant="secondary"
                    size="sm"
                    onClick={addSemesterMapping}
                  >
                    <Plus size={14} aria-hidden="true" />
                    <span>Add Mapping</span>
                  </Button>
                </div>

                {Object.keys(draft.semester_map).length === 0 ? (
                  <p className="text-[12.5px] text-[var(--ink-muted)]">
                    No explicit batch-to-semester overrides configured yet.
                  </p>
                ) : (
                  <div className="flex flex-wrap gap-2">
                    {Object.entries(draft.semester_map)
                      .sort(([a], [b]) => a.localeCompare(b))
                      .map(([batch, sem]) => (
                        <div
                          key={batch}
                          className="inline-flex items-center gap-2 rounded-[var(--r-control)] border border-[var(--border-subtle)] bg-[var(--bg-canvas)] px-2.5 py-1 text-[12.5px]"
                        >
                          <span className="font-mono-tabular font-semibold text-[var(--ink-primary)]">
                            {batch}
                          </span>
                          <span className="text-[var(--ink-muted)]">-&gt;</span>
                          <span className="font-mono-tabular text-[var(--ink-secondary)]">
                            Sem {sem}
                          </span>
                          <button
                            type="button"
                            onClick={() => removeSemesterMapping(batch)}
                            aria-label={`Remove batch ${batch}`}
                            className="text-[var(--ink-muted)] hover:text-[var(--sem-conflict-ink)]"
                          >
                            <Trash size={13} aria-hidden="true" />
                          </button>
                        </div>
                      ))}
                  </div>
                )}
              </section>
            </div>
          )}

          {activeTab === "rules" && (
            <div className="space-y-4">
              <section className="ledger-card space-y-4 p-5">
                <div className="flex items-center justify-between gap-4 rounded-[var(--r-control)] border border-[var(--border-subtle)] bg-[var(--bg-canvas)]/60 px-4 py-3">
                  <div>
                    <div className="text-[14px] font-semibold text-[var(--ink-primary)]">
                      Friday Period 4 Jummah Lock
                    </div>
                    <div className="mt-0.5 text-[12.5px] text-[var(--ink-secondary)]">
                      Automatically reserves Period 4 on Friday inside the
                      blocked slot matrix to protect Friday prayer hours.
                    </div>
                  </div>
                  <Switch
                    checked={draft.friday_no_p4}
                    onCheckedChange={toggleFridayJummah}
                    aria-label="Friday Period 4 Jummah lock"
                  />
                </div>

                <div>
                  <h2 className="text-[15px] font-semibold text-[var(--ink-primary)]">
                    Weekly Blocked Slot Matrix
                  </h2>
                  <p className="mt-0.5 text-[12.5px] text-[var(--ink-secondary)]">
                    Toggle cells to block the solver from scheduling sessions on
                    specific day/period combinations.
                  </p>
                  <div className="mt-3 overflow-x-auto">
                    <table className="w-full border-collapse text-center text-[12px]">
                      <thead>
                        <tr className="border-b border-[var(--border-subtle)] text-[11px] font-semibold uppercase tracking-[0.06em] text-[var(--ink-muted)]">
                          <th className="py-2 pr-3 text-left">Day</th>
                          {draft.periods.map((p) => (
                            <th
                              key={p.idx}
                              className="px-1.5 py-2 font-mono-tabular"
                            >
                              {p.idx >= ONLINE_SLOT_IDX ? `OL P${p.idx}` : `P${p.idx}`}
                            </th>
                          ))}
                        </tr>
                      </thead>
                      <tbody className="divide-y divide-[var(--border-subtle)]">
                        {ACADEMIC_WEEK_DAYS.map((day) => {
                          const dayWorking = draft.working_days.includes(day);
                          return (
                            <tr
                              key={day}
                              className={cn(!dayWorking && "opacity-55")}
                            >
                              <td className="py-2 pr-3 text-left font-medium text-[var(--ink-primary)]">
                                {day}
                              </td>
                              {draft.periods.map((p) => {
                                const blocked = Boolean(
                                  draft.blocked_periods[day]?.includes(p.idx),
                                );
                                const isJummahLocked =
                                  day === "Friday" &&
                                  p.idx === 4 &&
                                  draft.friday_no_p4;
                                return (
                                  <td key={p.idx} className="px-1.5 py-1.5">
                                    <button
                                      type="button"
                                      disabled={isJummahLocked}
                                      aria-pressed={blocked}
                                      aria-label={`${day} P${p.idx} ${
                                        blocked ? "blocked" : "open"
                                      }`}
                                      onClick={() =>
                                        toggleBlockedCell(day, p.idx)
                                      }
                                      className={cn(
                                        "h-8 w-full min-w-[54px] rounded-[5px] border font-mono-tabular text-[11.5px] font-medium transition-colors",
                                        blocked
                                          ? "border-[var(--sem-conflict-border)] bg-[var(--sem-conflict-bg)] text-[var(--sem-conflict-ink)]"
                                          : "border-[var(--border-subtle)] bg-[var(--bg-elevated)] text-[var(--ink-muted)] hover:bg-[var(--surface-hover)] hover:text-[var(--ink-primary)]",
                                        isJummahLocked && "cursor-not-allowed",
                                      )}
                                    >
                                      {isJummahLocked
                                        ? "Jummah"
                                        : blocked
                                          ? "Blocked"
                                          : "Open"}
                                    </button>
                                  </td>
                                );
                              })}
                            </tr>
                          );
                        })}
                      </tbody>
                    </table>
                  </div>
                </div>
              </section>

              <section className="ledger-card space-y-3 p-5">
                <div>
                  <h2 className="text-[15px] font-semibold text-[var(--ink-primary)]">
                    External Service Course Handling
                  </h2>
                  <p className="mt-0.5 text-[12.5px] text-[var(--ink-secondary)]">
                    Controls how cross-department GED or service-course records
                    are treated during schedule validation.
                  </p>
                </div>

                <div className="grid gap-3 md:grid-cols-2">
                  {[
                    {
                      value: "resource_only" as const,
                      title: "Track Room & Batch Resources",
                      desc: "Reserves rooms and batch slots while respecting home-department allocation limits.",
                    },
                    {
                      value: "ignore" as const,
                      title: "Ignore Service Records",
                      desc: "Excludes external service rows completely from active departmental solver constraints.",
                    },
                  ].map((opt) => {
                    const selected = draft.service_scope === opt.value;
                    return (
                      <button
                        key={opt.value}
                        type="button"
                        aria-pressed={selected}
                        onClick={() =>
                          setDraft((prev) =>
                            prev ? { ...prev, service_scope: opt.value } : prev,
                          )
                        }
                        className={cn(
                          "rounded-[var(--r-control)] border p-3.5 text-left transition-colors",
                          selected
                            ? "border-[var(--accent-pine)] bg-[var(--accent-pine-soft)]"
                            : "border-[var(--border-subtle)] bg-[var(--bg-elevated)] hover:bg-[var(--surface-hover)]",
                        )}
                      >
                        <div className="text-[13px] font-semibold text-[var(--ink-primary)]">
                          {opt.title}
                        </div>
                        <p className="mt-1 text-[12px] leading-[1.45] text-[var(--ink-secondary)]">
                          {opt.desc}
                        </p>
                      </button>
                    );
                  })}
                </div>
              </section>

              <section className="ledger-card overflow-hidden">
                <div className="border-b border-[var(--border-subtle)] px-5 py-3.5">
                  <h2 className="text-[15px] font-semibold text-[var(--ink-primary)]">
                    Routine Committee Policy Ledger (R1–R15)
                  </h2>
                  <p className="mt-0.5 text-[12px] text-[var(--ink-secondary)]">
                    Official Leading University CSE Routine Committee
                    constraints enforced across automated schedule generation.
                  </p>
                </div>
                <div className="divide-y divide-[var(--border-subtle)]">
                  {COMMITTEE_POLICY_LEDGER.map((item) => (
                    <div
                      key={item.code}
                      className="flex flex-wrap items-center justify-between gap-3 px-5 py-3 text-[13px]"
                    >
                      <div className="flex min-w-0 items-center gap-3">
                        <Badge tone="neutral" mono>
                          {item.code}
                        </Badge>
                        <span className="text-[var(--ink-primary)]">
                          {item.rule}
                        </span>
                      </div>
                      <span className="shrink-0 text-[12px] text-[var(--ink-muted)]">
                        {item.pillar}
                      </span>
                    </div>
                  ))}
                </div>
              </section>
            </div>
          )}

          {activeTab === "weights" && (
            <section className="ledger-card space-y-5 p-5">
              <div className="flex flex-wrap items-center justify-between gap-3">
                <div>
                  <h2 className="text-[15px] font-semibold text-[var(--ink-primary)]">
                    CP-SAT Soft Objective Weights
                  </h2>
                  <p className="mt-0.5 text-[12.5px] text-[var(--ink-secondary)]">
                    Adjust trade-offs between multi-day spacing, student gap
                    compactness, and late afternoon avoidance.
                  </p>
                </div>

                <div className="flex flex-wrap gap-1.5">
                  {(
                    Object.entries(WEIGHT_PRESETS) as Array<
                      [
                        keyof typeof WEIGHT_PRESETS,
                        (typeof WEIGHT_PRESETS)[keyof typeof WEIGHT_PRESETS],
                      ]
                    >
                  ).map(([presetKey, preset]) => (
                    <Button
                      key={presetKey}
                      variant="secondary"
                      size="sm"
                      onClick={() =>
                        setDraft((prev) =>
                          prev
                            ? { ...prev, weights: { ...preset.weights } }
                            : prev,
                        )
                      }
                    >
                      {preset.label}
                    </Button>
                  ))}
                </div>
              </div>

              <div className="grid gap-4 md:grid-cols-2">
                {WEIGHT_LABELS.map((item) => {
                  const val = draft.weights[item.key];
                  return (
                    <div
                      key={item.key}
                      className="rounded-[var(--r-control)] border border-[var(--border-subtle)] bg-[var(--bg-canvas)]/55 p-4"
                    >
                      <div className="flex items-center justify-between gap-2">
                        <label
                          htmlFor={`weight-${item.key}`}
                          className="text-[13.5px] font-semibold text-[var(--ink-primary)]"
                        >
                          {item.title}
                        </label>
                        <span className="font-mono-tabular rounded-[4px] border border-[var(--border-subtle)] bg-[var(--bg-elevated)] px-2 py-0.5 text-[12px] font-semibold text-[var(--accent-pine)]">
                          {val}
                        </span>
                      </div>
                      <p className="mt-1 text-[12px] text-[var(--ink-secondary)]">
                        {item.hint}
                      </p>
                      <input
                        id={`weight-${item.key}`}
                        type="range"
                        min={0}
                        max={20}
                        step={1}
                        value={val}
                        onChange={(e) => {
                          const parsed = Number.parseInt(e.target.value, 10);
                          setDraft((prev) =>
                            prev
                              ? {
                                  ...prev,
                                  weights: {
                                    ...prev.weights,
                                    [item.key]: Number.isFinite(parsed)
                                      ? parsed
                                      : 0,
                                  },
                                }
                              : prev,
                          );
                        }}
                        className="mt-3 w-full accent-[var(--accent-pine)]"
                      />
                    </div>
                  );
                })}
              </div>
            </section>
          )}

          <StickyDirtyBar
            docked
            isDirty={isDirty}
            isSaving={saveMutation.isPending}
            message={
              validationError
                ? "Fix validation errors before saving settings"
                : "Unsaved timetable policy edits"
            }
            saveLabel="Save Settings"
            onDiscard={() => setDiscardDialogOpen(true)}
            onSave={() => {
              if (!draft) return;
              if (validationError) {
                toast.error(validationError);
                return;
              }
              saveMutation.mutate(draft);
            }}
          />

          <ConfirmDialog
            open={discardDialogOpen}
            onOpenChange={setDiscardDialogOpen}
            title="Discard timetable settings changes?"
            description="All modified period clocks, blocked slots, and weight adjustments will revert to the last saved snapshot."
            confirmLabel="Discard Changes"
            tone="destructive"
            onConfirm={handleDiscard}
          />
        </>
      )}
    </div>
  );
}
