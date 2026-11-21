import {
  ArrowsClockwise,
  CalendarBlank,
  ListBullets,
  Lock,
  MagnifyingGlass,
  PencilSimple,
  Plus,
  Table,
  Trash,
  WarningCircle,
  X,
} from "@phosphor-icons/react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useVirtualizer } from "@tanstack/react-virtual";
import { AnimatePresence, motion, useReducedMotion } from "motion/react";
import { useEffect, useMemo, useRef, useState } from "react";
import { toast } from "sonner";
import {
  LedgerEmptyState,
  LedgerErrorRecovery,
  LedgerFilterEmpty,
  LedgerTableSkeleton,
} from "@/components/ui/AsyncStates";
import { Badge } from "@/components/ui/Badge";
import { Button } from "@/components/ui/Button";
import {
  CommandCombobox,
  type ComboboxOption,
} from "@/components/ui/CommandCombobox";
import { ConfirmDialog } from "@/components/ui/ConfirmDialog";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogTitle,
} from "@/components/ui/Dialog";
import {
  Tooltip,
  TooltipContent,
  TooltipTrigger,
} from "@/components/ui/Tooltip";
import { useWorkspaceShortcuts } from "@/core/hooks/useWorkspaceShortcuts";
import { ClockTime } from "@/core/utils/clockTime";
import { matchesJointSection, RoomIdentity } from "@/core/utils/roomIdentity";
import { ACADEMIC_WEEK_DAYS } from "@/features/admin/services/facultyService";
import {
  fetchTimetableSettings,
  ONLINE_SLOT_IDX,
  partitionPeriods,
  type PeriodDefinition,
} from "@/features/admin/services/settingsService";
import { useAuth } from "@/features/auth/AuthProvider";
import { RoutineSlotForm } from "@/features/routine/components/RoutineSlotForm";
import {
  createRoutineSlot,
  deleteRoutineSlots,
  fetchActiveRoutineVersion,
  fetchRoutines,
  updateRoutineSlot,
} from "@/features/routine/services/routineService";
import {
  extractRowTeacherCodes,
  requiresSharedTeacherStorage,
} from "@/features/routine/services/validationGate";
import { useRoutineOperationsStore } from "@/features/routine/store/routineOperationsStore";
import type {
  RoutineMatrixLens,
  RoutineMatrixViewMode,
  RoutineRow,
  RoutineWriteInput,
} from "@/features/routine/types";
import { cn } from "@/lib/utils";

const LENS_ITEMS: readonly { value: RoutineMatrixLens; label: string }[] = [
  { value: "section", label: "Section" },
  { value: "faculty", label: "Faculty" },
  { value: "room", label: "Room" },
];

const VIEW_ITEMS: readonly {
  value: RoutineMatrixViewMode;
  label: string;
  Icon: typeof Table;
}[] = [
  { value: "matrix", label: "Matrix", Icon: Table },
  { value: "list", label: "Compact List", Icon: ListBullets },
];

type InspectorState =
  | { kind: "view"; row: RoutineRow }
  | { kind: "edit"; row: RoutineRow }
  | { kind: "quick-add"; prefill: Partial<RoutineRow> };

type FlatMatrixEntry =
  | { kind: "day-header"; id: string; day: string; slotCount: number }
  | {
      kind: "group-row";
      id: string;
      day: string;
      groupKey: string;
      groupLabel: string;
      groupSub?: string;
    };

function isLabCourse(row: RoutineRow): boolean {
  if (row.is_lab === true) return true;
  const code = row.subject_code.trim();
  const lastDigitMatch = /(\d)\s*$/.exec(code);
  if (lastDigitMatch) {
    const d = Number.parseInt(lastDigitMatch[1]!, 10);
    if (Number.isFinite(d) && d % 2 === 0) return true;
  }
  const title = row.subject.toLowerCase();
  return title.includes("sessional") || title.includes("lab");
}

function slotSemanticClass(
  row: RoutineRow,
  isConflictCell: boolean,
): string {
  if (isConflictCell || requiresSharedTeacherStorage(row)) {
    return "slot-conflict";
  }
  if (row.section.includes("+")) {
    return "slot-joint";
  }
  if (isLabCourse(row)) {
    return "slot-lab";
  }
  return "slot-theory";
}

function getSlotOverrideTooltip(row: RoutineRow): string | null {
  const notes: string[] = [];
  if (requiresSharedTeacherStorage(row)) {
    notes.push(
      `Co-taught (${extractRowTeacherCodes(row).join(" / ")}): blocked from scalar DB publish.`,
    );
  }
  const canonicalRoom = RoomIdentity.currentKey(row.room);
  const rawNormalized = row.room.trim().toUpperCase().replace(/\s+/g, " ");
  if (rawNormalized && canonicalRoom !== rawNormalized) {
    notes.push(`Room alias ${row.room} resolves to ${canonicalRoom}.`);
  }
  if (row.is_service) {
    notes.push("External GED / Service course occupying teacher & room time.");
  }
  return notes.length > 0 ? notes.join(" ") : null;
}

function resolvePeriodIdx(
  row: RoutineRow,
  periods: readonly PeriodDefinition[],
): number | null {
  if (
    typeof row.period === "number" &&
    periods.some((p) => p.idx === row.period)
  ) {
    return row.period;
  }
  const rowStartHm = ClockTime.toHm(row.time_start);
  const exact = periods.find((p) => ClockTime.toHm(p.start) === rowStartHm);
  if (exact) return exact.idx;
  const startMin = ClockTime.toMinutes(row.time_start);
  if (startMin === null) return null;
  const containing = periods.find((p) => {
    const ps = ClockTime.toMinutes(p.start);
    const pe = ClockTime.toMinutes(p.end);
    return ps !== null && pe !== null && startMin >= ps && startMin < pe;
  });
  return containing?.idx ?? null;
}

export function AcademicTimetableMatrix() {
  const { isDevPreview } = useAuth();
  const queryClient = useQueryClient();
  const prefersReducedMotion = useReducedMotion() ?? false;
  const searchInputRef = useRef<HTMLInputElement>(null);
  const matrixScrollRef = useRef<HTMLDivElement>(null);

  const {
    lens,
    viewMode,
    viewModeManuallyChosen,
    selectedDay,
    activeSource,
    includeServiceCourses,
    candidateResult,
    setLens,
    setViewMode,
    setSelectedDay,
    setActiveSource,
    setIncludeServiceCourses,
  } = useRoutineOperationsStore();

  const [searchQuery, setSearchQuery] = useState("");
  const [entityFilter, setEntityFilter] = useState("");
  const [hoveredTeacherCode, setHoveredTeacherCode] = useState<string | null>(
    null,
  );
  const [inspector, setInspector] = useState<InspectorState | null>(null);
  const [deleteTarget, setDeleteTarget] = useState<RoutineRow | null>(null);

  const [isExpandedDesktop, setIsExpandedDesktop] = useState(() =>
    typeof window !== "undefined" && typeof window.matchMedia === "function"
      ? window.matchMedia("(min-width: 1100px)").matches
      : true,
  );

  useEffect(() => {
    if (
      typeof window === "undefined" ||
      typeof window.matchMedia !== "function"
    ) {
      return;
    }
    const mqlWide = window.matchMedia("(min-width: 1100px)");
    const onWideChange = (e: MediaQueryListEvent) =>
      setIsExpandedDesktop(e.matches);
    setIsExpandedDesktop(mqlWide.matches);
    mqlWide.addEventListener("change", onWideChange);

    const mqlMobile = window.matchMedia("(max-width: 767px)");
    if (!viewModeManuallyChosen && mqlMobile.matches) {
      setViewMode("list", false);
    }

    return () => {
      mqlWide.removeEventListener("change", onWideChange);
    };
  }, [setViewMode, viewModeManuallyChosen]);

  useWorkspaceShortcuts({
    searchInputRef,
    onEscape: () => {
      if (deleteTarget) {
        setDeleteTarget(null);
        return;
      }
      if (inspector) {
        setInspector(null);
      }
    },
  });

  const routinesQuery = useQuery({
    queryKey: ["admin-routines", isDevPreview],
    queryFn: () => fetchRoutines(isDevPreview),
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

  const settings = settingsQuery.data;

  const hasCandidate = Boolean(candidateResult);
  const effectiveSource =
    activeSource === "candidate" && hasCandidate ? "candidate" : "live";

  const sourceRows = useMemo<RoutineRow[]>(() => {
    if (effectiveSource === "candidate" && candidateResult) {
      return [...candidateResult.rows, ...candidateResult.service_rows];
    }
    return routinesQuery.data ?? [];
  }, [candidateResult, effectiveSource, routinesQuery.data]);

  const activeSourceRows = useMemo(
    () => sourceRows.filter((r) => r.is_active !== false),
    [sourceRows],
  );

  const serviceCourseCount = useMemo(
    () => activeSourceRows.filter((r) => r.is_service).length,
    [activeSourceRows],
  );

  // Smart default day: Sunday when > 120 slots and user hasn't picked a day filter
  const effectiveDayFilter = useMemo(() => {
    if (selectedDay !== null) return selectedDay;
    return activeSourceRows.length > 120 ? "Sunday" : "ALL";
  }, [activeSourceRows.length, selectedDay]);

  // Day counts computed before day filter so tabs show upfront counts
  const rowsAfterServiceAndSearch = useMemo(() => {
    const q = searchQuery.trim().toLowerCase();
    return activeSourceRows.filter((row) => {
      if (!includeServiceCourses && row.is_service) return false;
      if (entityFilter) {
        if (lens === "section") {
          const [fBatch, fSection] = entityFilter.split("|");
          if (fBatch && row.batch !== fBatch) return false;
          if (fSection && !matchesJointSection(row.section, fSection)) {
            return false;
          }
        } else if (lens === "faculty") {
          const codes = extractRowTeacherCodes(row).map((c) => c.toUpperCase());
          const target = entityFilter.toUpperCase();
          if (target === "TBA") {
            if (codes.length > 0) return false;
          } else if (!codes.includes(target)) {
            return false;
          }
        } else if (lens === "room") {
          if (RoomIdentity.currentKey(row.room) !== entityFilter) {
            return false;
          }
        }
      }
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
  }, [activeSourceRows, entityFilter, includeServiceCourses, lens, searchQuery]);

  const dayCounts = useMemo(() => {
    const map = new Map<string, number>();
    for (const d of ACADEMIC_WEEK_DAYS) map.set(d, 0);
    for (const row of rowsAfterServiceAndSearch) {
      map.set(row.day, (map.get(row.day) ?? 0) + 1);
    }
    return map;
  }, [rowsAfterServiceAndSearch]);

  const filteredRows = useMemo(() => {
    if (effectiveDayFilter === "ALL") return rowsAfterServiceAndSearch;
    return rowsAfterServiceAndSearch.filter((r) => r.day === effectiveDayFilter);
  }, [effectiveDayFilter, rowsAfterServiceAndSearch]);

  const entityOptions = useMemo<ComboboxOption[]>(() => {
    const set = new Map<string, ComboboxOption>();
    for (const row of activeSourceRows) {
      if (lens === "section") {
        const key = `${row.batch}|${row.section}`;
        if (!set.has(key)) {
          set.set(key, {
            value: key,
            label: `Batch ${row.batch} · Section ${row.section}`,
            subtitle: `Sem ${row.semester}`,
          });
        }
      } else if (lens === "faculty") {
        const codes = extractRowTeacherCodes(row);
        if (codes.length === 0) {
          if (!set.has("TBA")) {
            set.set("TBA", { value: "TBA", label: "Pending Faculty" });
          }
        } else {
          for (const c of codes) {
            const up = c.toUpperCase();
            if (!set.has(up)) {
              set.set(up, {
                value: up,
                label: row.teacher_name || up,
              });
            }
          }
        }
      } else {
        const key = RoomIdentity.currentKey(row.room || "TBA");
        if (!set.has(key)) {
          set.set(key, {
            value: key,
            label: key,
            subtitle:
              row.room.trim().toUpperCase() !== key
                ? `Alias: ${row.room}`
                : undefined,
          });
        }
      }
    }
    return Array.from(set.values()).sort((a, b) =>
      a.value.localeCompare(b.value, undefined, { numeric: true }),
    );
  }, [activeSourceRows, lens]);

  const configuredPeriods = useMemo(() => {
    if (!settings) return [];
    const { regularPeriods, onlinePeriod } = partitionPeriods(settings);
    const activeRegular = regularPeriods.filter(
      (p) => !settings.excluded_periods.includes(p.idx),
    );
    const list = [...activeRegular];
    if (settings.allow_online_periods && onlinePeriod) {
      list.push(onlinePeriod);
    }
    return list;
  }, [settings]);

  // Identify midday break divider index (just before first period with col >= "H" or idx >= 4)
  const breakBeforePeriodIdx = useMemo(() => {
    const afternoon = configuredPeriods.find(
      (p) => p.col >= "H" && p.idx < ONLINE_SLOT_IDX,
    );
    return afternoon?.idx ?? null;
  }, [configuredPeriods]);

  const visibleDays = useMemo(() => {
    const baseDays =
      settings?.working_days && settings.working_days.length > 0
        ? ACADEMIC_WEEK_DAYS.filter(
            (d) =>
              settings.working_days.includes(d) || (dayCounts.get(d) ?? 0) > 0,
          )
        : [...ACADEMIC_WEEK_DAYS];
    if (effectiveDayFilter === "ALL") return baseDays;
    return baseDays.filter((d) => d === effectiveDayFilter);
  }, [dayCounts, effectiveDayFilter, settings?.working_days]);

  // O(1) indexed lookup map: `${day}|${groupKey}|${periodIdx}` -> RoutineRow[]
  const { cellLookup, matrixEntries } = useMemo(() => {
    const map = new Map<string, RoutineRow[]>();
    const groupsByDay = new Map<
      string,
      Map<string, { label: string; sub?: string }>
    >();

    for (const d of visibleDays) {
      groupsByDay.set(d, new Map());
    }

    for (const row of filteredRows) {
      const pIdx = resolvePeriodIdx(row, configuredPeriods);
      if (pIdx === null) continue;
      const dayGroups = groupsByDay.get(row.day);
      if (!dayGroups) continue;

      let groupKeys: Array<{ key: string; label: string; sub?: string }> = [];
      if (lens === "section") {
        const label = `${row.batch}-${row.section}`;
        groupKeys = [
          {
            key: label,
            label,
            sub: row.is_service ? "Service" : `Sem ${row.semester}`,
          },
        ];
      } else if (lens === "faculty") {
        const codes = extractRowTeacherCodes(row);
        if (codes.length === 0) {
          groupKeys = [{ key: "TBA", label: "TBA", sub: "Pending" }];
        } else {
          groupKeys = codes.map((c) => ({
            key: c.toUpperCase(),
            label: c.toUpperCase(),
            sub: row.teacher_name ?? undefined,
          }));
        }
      } else {
        const rKey = RoomIdentity.currentKey(row.room || "TBA");
        groupKeys = [
          {
            key: rKey,
            label: rKey,
            sub:
              row.room.trim().toUpperCase() !== rKey
                ? `Alias: ${row.room}`
                : undefined,
          },
        ];
      }

      for (const g of groupKeys) {
        if (!dayGroups.has(g.key)) {
          dayGroups.set(g.key, { label: g.label, sub: g.sub });
        }
        const cellKey = `${row.day}|${g.key}|${pIdx}`;
        const list = map.get(cellKey);
        if (list) {
          list.push(row);
        } else {
          map.set(cellKey, [row]);
        }
      }
    }

    const entries: FlatMatrixEntry[] = [];
    for (const day of visibleDays) {
      const dayGroups = groupsByDay.get(day);
      if (!dayGroups || dayGroups.size === 0) continue;
      const sortedGroups = Array.from(dayGroups.entries()).sort(([a], [b]) =>
        a.localeCompare(b, undefined, { numeric: true }),
      );
      if (visibleDays.length > 1) {
        entries.push({
          kind: "day-header",
          id: `day-${day}`,
          day,
          slotCount: dayCounts.get(day) ?? 0,
        });
      }
      for (const [groupKey, meta] of sortedGroups) {
        entries.push({
          kind: "group-row",
          id: `${day}|${groupKey}`,
          day,
          groupKey,
          groupLabel: meta.label,
          groupSub: meta.sub,
        });
      }
    }

    return { cellLookup: map, matrixEntries: entries };
  }, [configuredPeriods, dayCounts, filteredRows, lens, visibleDays]);

  const shouldVirtualize = matrixEntries.length > 35;
  const rowVirtualizer = useVirtualizer({
    count: shouldVirtualize ? matrixEntries.length : 0,
    getScrollElement: () => matrixScrollRef.current,
    estimateSize: (index) =>
      matrixEntries[index]?.kind === "day-header" ? 38 : 74,
    overscan: 8,
  });

  const saveSlotMutation = useMutation({
    mutationFn: async (input: RoutineWriteInput) => {
      if (inspector?.kind === "edit") {
        return updateRoutineSlot(inspector.row.id, input, isDevPreview);
      }
      return createRoutineSlot(input, isDevPreview);
    },
    onSuccess: (saved) => {
      void queryClient.invalidateQueries({ queryKey: ["admin-routines"] });
      void queryClient.invalidateQueries({
        queryKey: ["admin-dashboard-counts"],
      });
      toast.success(
        inspector?.kind === "edit"
          ? `Updated ${saved.subject_code}`
          : `Added ${saved.subject_code} (${saved.day})`,
      );
      setInspector({ kind: "view", row: saved });
    },
    onError: (err) => {
      toast.error("Could not save routine slot", {
        description: err instanceof Error ? err.message : "Database error.",
      });
    },
  });

  const deleteSlotMutation = useMutation({
    mutationFn: (id: string) => deleteRoutineSlots([id], isDevPreview),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ["admin-routines"] });
      void queryClient.invalidateQueries({
        queryKey: ["admin-dashboard-counts"],
      });
      toast.success("Removed routine slot");
      setDeleteTarget(null);
      setInspector(null);
    },
    onError: (err) => {
      toast.error("Could not remove slot", {
        description: err instanceof Error ? err.message : "Database error.",
      });
    },
  });

  const isCellBlocked = (day: string, periodIdx: number) => {
    if (!settings) return false;
    if (day === "Friday" && periodIdx === 4 && settings.friday_no_p4) {
      return true;
    }
    return Boolean(settings.blocked_periods[day]?.includes(periodIdx));
  };

  const openQuickAdd = (
    day: string,
    groupKey: string,
    period: PeriodDefinition,
  ) => {
    if (effectiveSource !== "live") {
      toast.message("Candidate preview is read-only", {
        description: "Switch to Live Published to edit active slots.",
      });
      return;
    }
    if (isCellBlocked(day, period.idx)) {
      toast.error(`${day} P${period.idx} is blocked by committee policy.`);
      return;
    }
    const prefill: Partial<RoutineRow> = {
      day,
      time_start: `${ClockTime.toHm(period.start)}:00`,
      time_end: `${ClockTime.toHm(period.end)}:00`,
    };
    if (lens === "section") {
      const [b, ...rest] = groupKey.split("-");
      prefill.batch = b ?? "";
      prefill.section = rest.join("-") || "A";
    } else if (lens === "faculty" && groupKey !== "TBA") {
      prefill.teacher_code = groupKey;
    } else if (lens === "room" && groupKey !== "TBA") {
      prefill.room = groupKey;
    }
    setInspector({ kind: "quick-add", prefill });
  };

  if (routinesQuery.isLoading || settingsQuery.isLoading) {
    return <LedgerTableSkeleton rows={6} label="Loading academic timetable" />;
  }

  if (routinesQuery.isError) {
    return (
      <LedgerErrorRecovery
        title="Could not load routine schedule"
        message={
          routinesQuery.error instanceof Error
            ? routinesQuery.error.message
            : "Supabase routines query failed."
        }
        onRetry={() => void routinesQuery.refetch()}
      />
    );
  }

  const renderSlotButton = (
    row: RoutineRow,
    isConflictCell: boolean,
  ) => {
    const overrideNote = getSlotOverrideTooltip(row);
    const teacherCodes = extractRowTeacherCodes(row);
    const primaryTeacher = teacherCodes[0] ?? "TBA";
    const dimmedByCrosshair =
      hoveredTeacherCode !== null &&
      !teacherCodes.some(
        (c) => c.toUpperCase() === hoveredTeacherCode.toUpperCase(),
      );
    const highlightedByCrosshair =
      hoveredTeacherCode !== null &&
      teacherCodes.some(
        (c) => c.toUpperCase() === hoveredTeacherCode.toUpperCase(),
      );
    const isSelected =
      (inspector?.kind === "view" || inspector?.kind === "edit") &&
      inspector.row.id === row.id;

    const primaryLabel =
      lens === "section"
        ? primaryTeacher
        : lens === "faculty"
          ? `${row.batch}-${row.section}`
          : `${row.batch}-${row.section}`;

    const secondaryLabel =
      lens === "room" ? primaryTeacher : row.room;

    const btn = (
      <button
        key={row.id}
        type="button"
        data-testid={`matrix-slot-${row.id}`}
        onClick={() => setInspector({ kind: "view", row })}
        onMouseEnter={() =>
          primaryTeacher !== "TBA" ? setHoveredTeacherCode(primaryTeacher) : null
        }
        onMouseLeave={() => setHoveredTeacherCode(null)}
        className={cn(
          "flex w-full flex-col gap-0.5 rounded-[5px] px-2 py-1.5 text-left transition-all",
          slotSemanticClass(row, isConflictCell),
          overrideNote && "slot-override-corner",
          dimmedByCrosshair && "opacity-40",
          highlightedByCrosshair &&
            "ring-1 ring-[var(--accent-pine)] shadow-[var(--shadow-sheet)]",
          isSelected && "ring-2 ring-[var(--ink-primary)]",
        )}
      >
        <div className="flex items-center justify-between gap-1.5">
          <span className="font-mono-tabular text-[11.5px] font-semibold leading-tight whitespace-nowrap">
            {row.subject_code}
          </span>
          {row.is_service && (
            <span className="rounded bg-[var(--bg-elevated)]/80 px-1 py-[1px] font-mono-tabular text-[9.5px] font-semibold uppercase">
              GED
            </span>
          )}
        </div>
        <div className="flex items-center justify-between gap-1.5 text-[11px] leading-tight">
          <span className="truncate font-medium">
            {primaryLabel}
            {teacherCodes.length > 1 && lens === "section"
              ? ` +${teacherCodes.length - 1}`
              : ""}
          </span>
          <span className="font-mono-tabular shrink-0 whitespace-nowrap">
            {secondaryLabel}
          </span>
        </div>
      </button>
    );

    if (!overrideNote) return btn;

    return (
      <Tooltip key={row.id}>
        <TooltipTrigger asChild>{btn}</TooltipTrigger>
        <TooltipContent>{overrideNote}</TooltipContent>
      </Tooltip>
    );
  };

  const renderGroupRowCells = (entry: Extract<FlatMatrixEntry, { kind: "group-row" }>) => {
    return (
      <tr
        key={entry.id}
        className="border-b border-[var(--border-subtle)] bg-[var(--bg-elevated)] align-top hover:bg-[var(--surface-hover)]/60"
      >
        <th
          scope="row"
          className="sticky left-0 z-10 w-[124px] min-w-[124px] border-r border-[var(--border-subtle)] bg-[var(--bg-elevated)] px-3 py-2 text-left"
        >
          <div className="font-mono-tabular text-[12px] font-semibold text-[var(--ink-primary)] whitespace-nowrap">
            {entry.groupLabel}
          </div>
          {entry.groupSub && (
            <div className="truncate text-[10.5px] font-normal text-[var(--ink-muted)]">
              {entry.groupSub}
            </div>
          )}
        </th>
        {configuredPeriods.map((period) => {
          const isFridayJummah =
            entry.day === "Friday" &&
            period.idx === 4 &&
            Boolean(settings?.friday_no_p4);
          const isBlocked = isCellBlocked(entry.day, period.idx);
          const cellKey = `${entry.day}|${entry.groupKey}|${period.idx}`;
          const slots = cellLookup.get(cellKey) ?? [];
          const hasBreakBefore = breakBeforePeriodIdx === period.idx;

          return (
            <td
              key={`${entry.id}-${period.idx}`}
              data-testid={
                isFridayJummah ? `jummah-cell-${entry.id}` : undefined
              }
              className={cn(
                "min-w-[126px] border-l border-[var(--border-subtle)] p-1.5",
                hasBreakBefore &&
                  "border-l-[3px] border-l-[var(--border-strong)]",
                isFridayJummah && "slot-conflict",
              )}
            >
              {isFridayJummah ? (
                <div
                  aria-label="Friday Period 4 Jummah Break — locked"
                  className="flex min-h-[48px] items-center justify-center gap-1.5 rounded-[5px] px-2 py-1.5 text-[11px] font-semibold text-[var(--sem-conflict-ink)]"
                >
                  <Lock size={13} aria-hidden="true" />
                  <span>Jummah Break</span>
                </div>
              ) : slots.length > 0 ? (
                <div className="flex flex-col gap-1">
                  {slots.map((s) => renderSlotButton(s, slots.length > 1))}
                </div>
              ) : isBlocked ? (
                <div className="flex min-h-[48px] items-center justify-center rounded-[4px] border border-dashed border-[var(--sem-conflict-border)] bg-[var(--sem-conflict-bg)]/45 px-2 text-[10.5px] font-medium text-[var(--sem-conflict-ink)]">
                  Blocked
                </div>
              ) : effectiveSource === "live" ? (
                <button
                  type="button"
                  aria-label={`Quick add slot on ${entry.day} P${period.idx} for ${entry.groupLabel}`}
                  onClick={() => openQuickAdd(entry.day, entry.groupKey, period)}
                  className="flex min-h-[48px] w-full items-center justify-center rounded-[4px] border border-dashed border-[var(--border-subtle)]/70 text-[11px] text-transparent transition-colors hover:border-[var(--accent-pine-border)] hover:bg-[var(--accent-pine-soft)]/50 hover:text-[var(--accent-pine)] focus-visible:text-[var(--accent-pine)]"
                >
                  <Plus size={13} aria-hidden="true" />
                </button>
              ) : (
                <div
                  className="min-h-[48px] rounded-[4px] border border-dashed border-[var(--border-subtle)]/40"
                  aria-hidden="true"
                />
              )}
            </td>
          );
        })}
      </tr>
    );
  };

  const renderInspectorBody = () => {
    if (!inspector) return null;

    if (inspector.kind === "quick-add" && settings) {
      return (
        <RoutineSlotForm
          initialValue={inspector.prefill}
          existingRows={routinesQuery.data ?? []}
          settings={settings}
          isSubmitting={saveSlotMutation.isPending}
          submitLabel="Add Slot"
          onSubmit={async (input) => {
            await saveSlotMutation.mutateAsync(input);
          }}
          onCancel={() => setInspector(null)}
        />
      );
    }

    if (inspector.kind === "edit" && settings) {
      return (
        <RoutineSlotForm
          initialValue={inspector.row}
          existingRows={routinesQuery.data ?? []}
          ignoreId={inspector.row.id}
          settings={settings}
          isSubmitting={saveSlotMutation.isPending}
          submitLabel="Save Slot"
          onSubmit={async (input) => {
            await saveSlotMutation.mutateAsync(input);
          }}
          onCancel={() => setInspector({ kind: "view", row: inspector.row })}
        />
      );
    }

    if (inspector.kind !== "view") return null;

    const row = inspector.row;
    const teacherCodes = extractRowTeacherCodes(row);
    const hasCoTeacherWarning = requiresSharedTeacherStorage(row);
    const canonicalRoom = RoomIdentity.currentKey(row.room);
    const isAliasRoom =
      row.room.trim().toUpperCase().replace(/\s+/g, " ") !== canonicalRoom;

    return (
      <div className="space-y-4 text-[13px]">
        <div className="flex flex-wrap items-center gap-1.5">
          <Badge tone={isLabCourse(row) ? "lab" : "theory"} mono>
            {isLabCourse(row) ? "Lab / Sessional" : "Theory"}
          </Badge>
          {row.section.includes("+") && (
            <Badge tone="joint" mono>
              Joint {row.batch}-{row.section}
            </Badge>
          )}
          {row.is_service && <Badge tone="neutral">Service / GED</Badge>}
          {effectiveSource === "candidate" && (
            <Badge tone="joint">Unpublished Candidate</Badge>
          )}
        </div>

        <div className="divide-y divide-[var(--border-subtle)] rounded-[var(--r-control)] border border-[var(--border-subtle)] bg-[var(--bg-surface)]">
          <div className="flex items-center justify-between gap-2 px-3.5 py-2.5">
            <span className="text-[var(--ink-secondary)]">Course</span>
            <span className="font-mono-tabular font-semibold text-[var(--ink-primary)]">
              {row.subject_code}
            </span>
          </div>
          <div className="px-3.5 py-2.5">
            <div className="text-[11.5px] text-[var(--ink-muted)]">Title</div>
            <div className="mt-0.5 font-medium text-[var(--ink-primary)]">
              {row.subject}
            </div>
          </div>
          <div className="flex items-center justify-between gap-2 px-3.5 py-2.5">
            <span className="text-[var(--ink-secondary)]">Day &amp; Clock</span>
            <span className="font-mono-tabular font-medium text-[var(--ink-primary)]">
              {row.day} · {ClockTime.toHm(row.time_start)}–
              {ClockTime.toHm(row.time_end)}
            </span>
          </div>
          <div className="flex items-center justify-between gap-2 px-3.5 py-2.5">
            <span className="text-[var(--ink-secondary)]">Cohort</span>
            <span className="font-mono-tabular font-medium text-[var(--ink-primary)]">
              Batch {row.batch}-{row.section} (Sem {row.semester})
            </span>
          </div>
          <div className="flex items-center justify-between gap-2 px-3.5 py-2.5">
            <span className="text-[var(--ink-secondary)]">Room</span>
            <span className="font-mono-tabular font-medium text-[var(--ink-primary)]">
              {row.room}
              {isAliasRoom ? ` -> ${canonicalRoom}` : ""}
            </span>
          </div>
          <div className="px-3.5 py-2.5">
            <div className="text-[var(--ink-secondary)]">Faculty</div>
            <div className="mt-1 flex flex-wrap gap-1.5">
              {teacherCodes.length > 0 ? (
                teacherCodes.map((code) => (
                  <Badge key={code} tone="neutral" mono>
                    {code}
                  </Badge>
                ))
              ) : (
                <Badge tone="joint">Pending Faculty</Badge>
              )}
            </div>
            {row.teacher_name && (
              <div className="mt-1 text-[12px] text-[var(--ink-secondary)]">
                {row.teacher_name}
              </div>
            )}
          </div>
        </div>

        {hasCoTeacherWarning && (
          <div
            role="alert"
            className="flex items-start gap-2 rounded-[var(--r-control)] border border-[var(--sem-conflict-border)] bg-[var(--sem-conflict-bg)] p-3 text-[12px] text-[var(--sem-conflict-ink)]"
          >
            <WarningCircle size={16} className="mt-0.5 shrink-0" aria-hidden="true" />
            <span>
              Co-taught slot ({teacherCodes.join(" / ")}) exceeds scalar{" "}
              <code className="font-mono-tabular">teacher_code</code> storage;
              export as a private JSON draft instead of publishing directly.
            </span>
          </div>
        )}

        {effectiveSource === "live" && (
          <div className="flex flex-wrap gap-2 border-t border-[var(--border-subtle)] pt-3">
            <Button
              variant="secondary"
              size="sm"
              onClick={() => setInspector({ kind: "edit", row })}
            >
              <PencilSimple size={14} aria-hidden="true" />
              <span>Edit Slot</span>
            </Button>
            <Button
              variant="destructive"
              size="sm"
              onClick={() => setDeleteTarget(row)}
            >
              <Trash size={14} aria-hidden="true" />
              <span>Delete Slot</span>
            </Button>
          </div>
        )}
      </div>
    );
  };

  const inspectorTitle =
    inspector?.kind === "quick-add"
      ? "Quick Add Routine Slot"
      : inspector?.kind === "edit"
        ? `Edit ${inspector.row.subject_code}`
        : inspector?.kind === "view"
          ? `${inspector.row.subject_code} · Slot Provenance`
          : "";

  const inspectorSubtitle =
    inspector?.kind === "view" || inspector?.kind === "edit"
      ? `${inspector.row.day} · Batch ${inspector.row.batch}-${inspector.row.section}`
      : inspector?.kind === "quick-add"
        ? `${inspector.prefill.day ?? ""} · ${ClockTime.toHm(inspector.prefill.time_start ?? "08:50")}`
        : undefined;

  return (
    <div className="space-y-4">
      {/* Unpublished Candidate Disclosure Banner */}
      {effectiveSource === "candidate" && (
        <div
          role="status"
          data-testid="candidate-preview-banner"
          className="flex flex-wrap items-center justify-between gap-3 rounded-[var(--r-card)] border border-[var(--sem-joint-border)] bg-[var(--sem-joint-bg)] px-4 py-2.5 text-[12.5px] text-[var(--sem-joint-ink)]"
        >
          <div className="flex items-center gap-2 font-medium">
            <WarningCircle size={16} className="shrink-0" aria-hidden="true" />
            <span>
              Viewing unpublished candidate schedule — live student and teacher
              apps still show the published routine.
            </span>
          </div>
          <Button
            variant="secondary"
            size="sm"
            onClick={() => setActiveSource("live")}
          >
            Return to Live Published
          </Button>
        </div>
      )}

      {/* Connected Filter & Lens Bar (Uniform 36px Controls) */}
      <section
        aria-label="Timetable matrix filters and viewing lens"
        className="ledger-card space-y-3 p-4"
      >
        <div className="flex flex-wrap items-center justify-between gap-2.5">
          <div className="flex flex-wrap items-center gap-2.5">
            {/* Unclipped Section | Faculty | Room Lens Switcher */}
            <div
              role="group"
              aria-label="Timetable matrix lens"
              className="inline-flex h-[36px] min-w-[280px] items-center rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] p-0.5"
            >
              {LENS_ITEMS.map((item) => {
                const active = lens === item.value;
                return (
                  <button
                    key={item.value}
                    type="button"
                    aria-pressed={active}
                    onClick={() => {
                      setLens(item.value);
                      setEntityFilter("");
                    }}
                    className={cn(
                      "relative h-[30px] flex-1 rounded-[5px] px-3 text-[12.5px] whitespace-nowrap transition-colors",
                      active
                        ? "font-semibold text-[var(--action-primary-ink)]"
                        : "font-medium text-[var(--ink-secondary)] hover:text-[var(--ink-primary)]",
                    )}
                  >
                    {active && (
                      <motion.span
                        layoutId="routine-matrix-lens-pill"
                        transition={
                          prefersReducedMotion
                            ? { duration: 0 }
                            : { duration: 0.18, ease: [0.16, 1, 0.3, 1] }
                        }
                        className="absolute inset-0 rounded-[5px] bg-[var(--action-primary)]"
                        aria-hidden="true"
                      />
                    )}
                    <span
                      className="reserved-bold relative z-10"
                      data-label={item.label}
                    >
                      {item.label}
                    </span>
                  </button>
                );
              })}
            </div>

            {/* Matrix | Compact List Switcher */}
            <div
              role="group"
              aria-label="Timetable layout format"
              className="inline-flex h-[36px] items-center rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] p-0.5"
            >
              {VIEW_ITEMS.map(({ value, label, Icon }) => {
                const active = viewMode === value;
                return (
                  <button
                    key={value}
                    type="button"
                    aria-pressed={active}
                    onClick={() => setViewMode(value, true)}
                    className={cn(
                      "inline-flex h-[30px] items-center gap-1.5 rounded-[5px] px-3 text-[12.5px] whitespace-nowrap transition-colors",
                      active
                        ? "bg-[var(--accent-pine-soft)] font-semibold text-[var(--accent-pine)]"
                        : "font-medium text-[var(--ink-secondary)] hover:text-[var(--ink-primary)]",
                    )}
                  >
                    <Icon size={14} aria-hidden="true" />
                    <span>{label}</span>
                  </button>
                );
              })}
            </div>
          </div>

          <div className="flex flex-wrap items-center gap-2">
            {hasCandidate && candidateResult && (
              <div
                role="group"
                aria-label="Schedule data source"
                className="inline-flex h-[36px] items-center rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] p-0.5"
              >
                <button
                  type="button"
                  aria-pressed={effectiveSource === "live"}
                  onClick={() => setActiveSource("live")}
                  className={cn(
                    "font-mono-tabular h-[30px] rounded-[5px] px-2.5 text-[12px] whitespace-nowrap",
                    effectiveSource === "live"
                      ? "bg-[var(--action-primary)] font-semibold text-[var(--action-primary-ink)]"
                      : "text-[var(--ink-secondary)] hover:text-[var(--ink-primary)]",
                  )}
                >
                  Live Published ({(routinesQuery.data ?? []).length})
                </button>
                <button
                  type="button"
                  aria-pressed={effectiveSource === "candidate"}
                  onClick={() => setActiveSource("candidate")}
                  className={cn(
                    "font-mono-tabular h-[30px] rounded-[5px] px-2.5 text-[12px] whitespace-nowrap",
                    effectiveSource === "candidate"
                      ? "bg-[var(--sem-joint-bg)] font-semibold text-[var(--sem-joint-ink)]"
                      : "text-[var(--ink-secondary)] hover:text-[var(--ink-primary)]",
                  )}
                >
                  Candidate Preview (
                  {candidateResult.rows.length +
                    candidateResult.service_rows.length}
                  )
                </button>
              </div>
            )}

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
          </div>
        </div>

        {/* Search, cmdk Entity Filter, Service Toggle & Freshness */}
        <div className="flex flex-wrap items-center gap-2.5">
          <div className="relative min-w-[210px] flex-1">
            <MagnifyingGlass
              size={15}
              className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-[var(--ink-muted)]"
              aria-hidden="true"
            />
            <input
              ref={searchInputRef}
              type="search"
              aria-label="Search routine slots"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              placeholder="Search course, faculty, room, batch (/) ..."
              className="h-[36px] w-full rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] pl-9 pr-3 text-[13px] text-[var(--ink-primary)] placeholder:text-[var(--ink-muted)] focus:border-[var(--ink-primary)] focus:outline-none"
            />
          </div>

          <div className="w-full min-w-[220px] sm:w-[250px]">
            <CommandCombobox
              value={entityFilter}
              onChange={setEntityFilter}
              options={[
                {
                  value: "",
                  label:
                    lens === "section"
                      ? "All sections"
                      : lens === "faculty"
                        ? "All faculty"
                        : "All rooms",
                },
                ...entityOptions,
              ]}
              placeholder={
                lens === "section"
                  ? "Filter batch/section..."
                  : lens === "faculty"
                    ? "Filter faculty..."
                    : "Filter room..."
              }
              searchPlaceholder="Type to filter..."
            />
          </div>

          <button
            type="button"
            aria-pressed={includeServiceCourses}
            onClick={() => setIncludeServiceCourses(!includeServiceCourses)}
            className={cn(
              "font-mono-tabular inline-flex h-[36px] items-center gap-2 rounded-[var(--r-control)] border px-3 text-[12px] font-medium whitespace-nowrap transition-colors",
              includeServiceCourses
                ? "border-[var(--accent-pine)] bg-[var(--accent-pine-soft)] text-[var(--accent-pine)]"
                : "border-[var(--border-control)] bg-[var(--bg-elevated)] text-[var(--ink-secondary)] hover:bg-[var(--surface-hover)]",
            )}
          >
            <span>Include Service Courses ({serviceCourseCount})</span>
          </button>

          <div className="font-mono-tabular ml-auto text-[12px] text-[var(--ink-muted)]">
            Showing {filteredRows.length} of {activeSourceRows.length} active
            slots
            {activeVersionQuery.data?.semester_label &&
            effectiveSource === "live"
              ? ` · ${activeVersionQuery.data.semester_label}`
              : ""}
          </div>
        </div>

        {/* Day Selector Pills with Upfront Option-Level Counts */}
        <div
          role="tablist"
          aria-label="Filter by academic day"
          className="flex flex-wrap items-center gap-1.5"
        >
          <button
            type="button"
            role="tab"
            aria-selected={effectiveDayFilter === "ALL"}
            onClick={() => setSelectedDay("ALL")}
            className={cn(
              "font-mono-tabular h-[30px] rounded-[6px] border px-2.5 text-[11.5px] whitespace-nowrap transition-colors",
              effectiveDayFilter === "ALL"
                ? "border-[var(--ink-primary)] bg-[var(--ink-primary)] font-semibold text-[var(--action-primary-ink)]"
                : "border-[var(--border-subtle)] bg-[var(--bg-surface)] text-[var(--ink-secondary)] hover:bg-[var(--surface-hover)]",
            )}
          >
            All Days ({rowsAfterServiceAndSearch.length})
          </button>
          {ACADEMIC_WEEK_DAYS.map((day) => {
            const count = dayCounts.get(day) ?? 0;
            const active = effectiveDayFilter === day;
            return (
              <button
                key={day}
                type="button"
                role="tab"
                aria-selected={active}
                onClick={() => setSelectedDay(day)}
                className={cn(
                  "font-mono-tabular h-[30px] rounded-[6px] border px-2.5 text-[11.5px] whitespace-nowrap transition-colors",
                  active
                    ? "border-[var(--accent-pine)] bg-[var(--accent-pine-soft)] font-semibold text-[var(--accent-pine)]"
                    : "border-[var(--border-subtle)] bg-[var(--bg-surface)] text-[var(--ink-secondary)] hover:bg-[var(--surface-hover)]",
                )}
              >
                {day.slice(0, 3)} ({count})
              </button>
            );
          })}
        </div>
      </section>

      {/* Main Grid + Optional Closable 360px Docked Inspector (>= 1100px) */}
      <div
        className={cn(
          "grid grid-cols-1 items-start gap-5",
          inspector && isExpandedDesktop
            ? "min-[1100px]:grid-cols-[minmax(0,1fr)_360px]"
            : "",
        )}
      >
        <div className="min-w-0">
          {activeSourceRows.length === 0 ? (
            <LedgerEmptyState
              icon={<CalendarBlank size={20} aria-hidden="true" />}
              title="No active routine slots published"
              description="Generate a schedule with the CP-SAT solver or add classes manually from the Manage Published tab."
            />
          ) : filteredRows.length === 0 ? (
            <LedgerFilterEmpty
              message="No routine slots match your active day, search, or lens filters."
              onReset={() => {
                setSearchQuery("");
                setEntityFilter("");
                setIncludeServiceCourses(true);
                setSelectedDay("ALL");
              }}
            />
          ) : viewMode === "matrix" ? (
            <div className="ledger-card overflow-hidden">
              <div
                ref={matrixScrollRef}
                className={cn(
                  "overflow-x-auto",
                  shouldVirtualize && "max-h-[72dvh] overflow-y-auto",
                )}
              >
                <table
                  aria-label="2D Academic Timetable Matrix"
                  className="w-full border-collapse text-left"
                >
                  <thead className="sticky top-0 z-20 border-b border-[var(--border-subtle)] bg-[var(--bg-canvas)]">
                    <tr>
                      <th
                        scope="col"
                        className="sticky left-0 z-30 w-[124px] min-w-[124px] border-r border-[var(--border-subtle)] bg-[var(--bg-canvas)] px-3 py-2.5 text-[11px] font-semibold tracking-[0.04em] text-[var(--ink-muted)] uppercase"
                      >
                        {lens === "section"
                          ? "Cohort"
                          : lens === "faculty"
                            ? "Faculty"
                            : "Room"}
                      </th>
                      {configuredPeriods.map((period) => {
                        const isOnline = period.idx >= ONLINE_SLOT_IDX;
                        const hasBreakBefore =
                          breakBeforePeriodIdx === period.idx;
                        return (
                          <th
                            key={period.idx}
                            scope="col"
                            className={cn(
                              "min-w-[126px] border-l border-[var(--border-subtle)] px-2 py-2 align-bottom",
                              hasBreakBefore &&
                                "border-l-[3px] border-l-[var(--border-strong)]",
                            )}
                          >
                            <div className="flex items-center justify-between gap-1.5">
                              <span className="font-mono-tabular text-[11.5px] font-semibold text-[var(--ink-primary)]">
                                {isOnline
                                  ? `OL P${period.idx}`
                                  : `P${period.idx}`}
                              </span>
                              <span className="font-mono-tabular text-[10px] text-[var(--ink-muted)]">
                                {period.col}
                              </span>
                            </div>
                            <div className="font-mono-tabular mt-0.5 text-[10.5px] font-normal text-[var(--ink-secondary)]">
                              {ClockTime.toHm(period.start)}–
                              {ClockTime.toHm(period.end)}
                            </div>
                          </th>
                        );
                      })}
                    </tr>
                  </thead>
                  <tbody>
                    {shouldVirtualize ? (
                      <>
                        {rowVirtualizer.getVirtualItems().length > 0 &&
                          rowVirtualizer.getVirtualItems()[0]!.start > 0 && (
                            <tr aria-hidden="true">
                              <td
                                colSpan={configuredPeriods.length + 1}
                                style={{
                                  height: `${rowVirtualizer.getVirtualItems()[0]!.start}px`,
                                }}
                              />
                            </tr>
                          )}
                        {rowVirtualizer.getVirtualItems().map((vRow) => {
                          const entry = matrixEntries[vRow.index];
                          if (!entry) return null;
                          if (entry.kind === "day-header") {
                            return (
                              <tr
                                key={entry.id}
                                className="border-b border-[var(--border-subtle)] bg-[var(--bg-surface)]"
                              >
                                <td
                                  colSpan={configuredPeriods.length + 1}
                                  className="px-3 py-1.5 text-[12px] font-semibold text-[var(--ink-primary)]"
                                >
                                  {entry.day}{" "}
                                  <span className="font-mono-tabular ml-1.5 text-[11px] font-normal text-[var(--ink-muted)]">
                                    ({entry.slotCount} slots)
                                  </span>
                                </td>
                              </tr>
                            );
                          }
                          return renderGroupRowCells(entry);
                        })}
                        {rowVirtualizer.getVirtualItems().length > 0 && (
                          <tr aria-hidden="true">
                            <td
                              colSpan={configuredPeriods.length + 1}
                              style={{
                                height: `${Math.max(
                                  0,
                                  rowVirtualizer.getTotalSize() -
                                    (rowVirtualizer.getVirtualItems().at(-1)
                                      ?.end ?? 0),
                                )}px`,
                              }}
                            />
                          </tr>
                        )}
                      </>
                    ) : (
                      matrixEntries.map((entry) => {
                        if (entry.kind === "day-header") {
                          return (
                            <tr
                              key={entry.id}
                              className="border-b border-[var(--border-subtle)] bg-[var(--bg-surface)]"
                            >
                              <td
                                colSpan={configuredPeriods.length + 1}
                                className="px-3 py-1.5 text-[12px] font-semibold text-[var(--ink-primary)]"
                              >
                                {entry.day}{" "}
                                <span className="font-mono-tabular ml-1.5 text-[11px] font-normal text-[var(--ink-muted)]">
                                  ({entry.slotCount} slots)
                                </span>
                              </td>
                            </tr>
                          );
                        }
                        return renderGroupRowCells(entry);
                      })
                    )}
                  </tbody>
                </table>
              </div>

              {/* Matrix Semantic Legend */}
              <div className="flex flex-wrap items-center justify-between gap-2 border-t border-[var(--border-subtle)] bg-[var(--bg-surface)] px-4 py-2.5 text-[11.5px] text-[var(--ink-secondary)]">
                <div className="flex flex-wrap items-center gap-x-4 gap-y-1">
                  <span className="inline-flex items-center gap-1.5">
                    <span className="h-2.5 w-2.5 rounded-[2px] bg-[var(--sem-theory-bar)]" />
                    Theory
                  </span>
                  <span className="inline-flex items-center gap-1.5">
                    <span className="h-2.5 w-2.5 rounded-[2px] bg-[var(--sem-lab-bar)]" />
                    Lab / Sessional
                  </span>
                  <span className="inline-flex items-center gap-1.5">
                    <span className="h-2.5 w-2.5 rounded-[2px] bg-[var(--sem-joint-bar)]" />
                    Joint B+C
                  </span>
                  <span className="inline-flex items-center gap-1.5">
                    <span className="h-2.5 w-2.5 rounded-[2px] bg-[var(--sem-conflict-bar)]" />
                    Jummah Block / Alert
                  </span>
                </div>
                <span className="font-mono-tabular text-[11px] text-[var(--ink-muted)]">
                  Vertical thick rule marks Midday Break (Col G)
                </span>
              </div>
            </div>
          ) : (
            /* Compact List View (Single-axis Agenda) */
            <div
              data-testid="routine-compact-list"
              className="ledger-card divide-y divide-[var(--border-subtle)] overflow-hidden"
            >
              {filteredRows.map((row) => {
                const overrideNote = getSlotOverrideTooltip(row);
                return (
                  <button
                    key={row.id}
                    type="button"
                    onClick={() => setInspector({ kind: "view", row })}
                    className="grid w-full grid-cols-[minmax(0,1fr)_auto] items-center gap-3 px-4 py-3 text-left transition-colors hover:bg-[var(--surface-hover)] sm:grid-cols-[110px_118px_minmax(0,1fr)_auto]"
                  >
                    <span className="font-mono-tabular text-[12px] font-semibold text-[var(--ink-primary)]">
                      {row.day}
                    </span>
                    <span className="font-mono-tabular text-[12px] text-[var(--ink-secondary)] whitespace-nowrap">
                      {ClockTime.toHm(row.time_start)}–
                      {ClockTime.toHm(row.time_end)}
                    </span>
                    <div className="col-span-2 min-w-0 sm:col-span-1">
                      <div className="flex flex-wrap items-center gap-2">
                        <span className="font-mono-tabular font-semibold text-[var(--ink-primary)] whitespace-nowrap">
                          {row.subject_code}
                        </span>
                        <span className="truncate text-[13px] text-[var(--ink-secondary)]">
                          {row.subject}
                        </span>
                        {overrideNote && (
                          <Badge tone="joint" mono>
                            Note
                          </Badge>
                        )}
                      </div>
                      <div className="mt-0.5 text-[12px] text-[var(--ink-muted)]">
                        Batch {row.batch}-{row.section} ·{" "}
                        {row.teacher_code ?? "TBA"}
                      </div>
                    </div>
                    <Badge
                      tone={
                        row.section.includes("+")
                          ? "joint"
                          : isLabCourse(row)
                            ? "lab"
                            : "theory"
                      }
                      mono
                      className="justify-self-end whitespace-nowrap"
                    >
                      {row.room}
                    </Badge>
                  </button>
                );
              })}
            </div>
          )}
        </div>

        {/* Desktop 360px Closable Docked Inspector (>= 1100px) */}
        {isExpandedDesktop && (
          <AnimatePresence initial={false}>
            {inspector && (
              <motion.aside
                aria-label={inspectorTitle}
                data-testid="matrix-docked-inspector"
                initial={prefersReducedMotion ? false : { opacity: 0, x: 14 }}
                animate={{ opacity: 1, x: 0 }}
                exit={
                  prefersReducedMotion
                    ? undefined
                    : {
                        opacity: 0,
                        x: 10,
                        transition: { duration: 0.14, ease: [0.4, 0, 1, 1] },
                      }
                }
                transition={{ duration: 0.19, ease: [0.16, 1, 0.3, 1] }}
                className="ledger-sheet sticky top-[68px] flex max-h-[calc(100dvh-84px)] flex-col overflow-hidden"
              >
                <div className="flex items-start justify-between gap-3 border-b border-[var(--border-subtle)] px-4 py-3.5">
                  <div className="min-w-0">
                    <h2 className="truncate text-[15px] font-semibold text-[var(--ink-primary)]">
                      {inspectorTitle}
                    </h2>
                    {inspectorSubtitle && (
                      <p className="font-mono-tabular mt-0.5 truncate text-[11.5px] text-[var(--ink-secondary)]">
                        {inspectorSubtitle}
                      </p>
                    )}
                  </div>
                  <button
                    type="button"
                    data-testid="matrix-inspector-close"
                    aria-label="Close slot inspector"
                    onClick={() => setInspector(null)}
                    className="flex h-8 w-8 shrink-0 items-center justify-center rounded-[var(--r-control)] border border-[var(--border-subtle)] bg-[var(--bg-surface)] text-[var(--ink-secondary)] hover:bg-[var(--surface-hover)] hover:text-[var(--ink-primary)]"
                  >
                    <X size={16} aria-hidden="true" />
                  </button>
                </div>
                <div className="flex-1 overflow-y-auto px-4 py-4">
                  {renderInspectorBody()}
                </div>
              </motion.aside>
            )}
          </AnimatePresence>
        )}

        {/* Compact / Tablet Radix Slide-Over Drawer (< 1100px) */}
        {!isExpandedDesktop && (
          <Dialog
            open={inspector !== null}
            onOpenChange={(open) => {
              if (!open) setInspector(null);
            }}
          >
            <DialogContent
              aria-describedby={undefined}
              className="fixed inset-y-0 right-0 flex w-full max-w-[420px] flex-col rounded-none border-l border-[var(--border-subtle)] bg-[var(--bg-elevated)] p-0"
            >
              <DialogTitle className="sr-only">{inspectorTitle}</DialogTitle>
              {inspectorSubtitle && (
                <DialogDescription className="sr-only">
                  {inspectorSubtitle}
                </DialogDescription>
              )}
              <div className="flex items-start justify-between gap-3 border-b border-[var(--border-subtle)] px-4 py-3.5">
                <div className="min-w-0">
                  <h2 className="truncate text-[15px] font-semibold text-[var(--ink-primary)]">
                    {inspectorTitle}
                  </h2>
                  {inspectorSubtitle && (
                    <p className="font-mono-tabular mt-0.5 truncate text-[11.5px] text-[var(--ink-secondary)]">
                      {inspectorSubtitle}
                    </p>
                  )}
                </div>
                <button
                  type="button"
                  data-testid="matrix-inspector-close"
                  aria-label="Close slot inspector"
                  onClick={() => setInspector(null)}
                  className="flex h-8 w-8 shrink-0 items-center justify-center rounded-[var(--r-control)] border border-[var(--border-subtle)] bg-[var(--bg-surface)] text-[var(--ink-secondary)] hover:bg-[var(--surface-hover)] hover:text-[var(--ink-primary)]"
                >
                  <X size={16} aria-hidden="true" />
                </button>
              </div>
              <div className="flex-1 overflow-y-auto px-4 py-4">
                {renderInspectorBody()}
              </div>
            </DialogContent>
          </Dialog>
        )}
      </div>

      <ConfirmDialog
        open={deleteTarget !== null}
        onOpenChange={(open) => {
          if (!open) setDeleteTarget(null);
        }}
        title="Delete published routine slot?"
        description={
          deleteTarget
            ? `Remove ${deleteTarget.subject_code} (${deleteTarget.day} ${ClockTime.toHm(deleteTarget.time_start)}) for Batch ${deleteTarget.batch}-${deleteTarget.section}?`
            : ""
        }
        confirmLabel="Delete Slot"
        tone="destructive"
        isPending={deleteSlotMutation.isPending}
        onConfirm={() => {
          if (deleteTarget) {
            deleteSlotMutation.mutate(deleteTarget.id);
          }
        }}
      />
    </div>
  );
}
