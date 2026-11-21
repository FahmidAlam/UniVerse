import { ClockTime } from "@/core/utils/clockTime";
import { ACADEMIC_WEEK_DAYS } from "@/features/admin/services/facultyService";
import { isSupabaseConfigured, supabase } from "@/services/supabase";

export const SETTINGS_SELECT_COLUMNS =
  "id, semester_label, working_days, periods, weeks_in_term, fixed_sessions_per_week, friday_no_p4, blocked_periods, online_periods, allow_online_periods, excluded_periods, semester_map, service_scope, weights";

export const REGULAR_PERIOD_COLS = ["D", "E", "F", "H", "I", "J", "K"] as const;
export const ONLINE_SLOT_IDX = 8;
export const ONLINE_SLOT_COL = "L";

export const WEIGHT_DEFAULTS = {
  different_days: 8,
  compactness: 3,
  spread: 2,
  late_slot: 1,
} as const;

export const WEIGHT_PRESETS = {
  strict: {
    label: "Strict Off-Day & Spread",
    weights: { different_days: 10, compactness: 6, spread: 4, late_slot: 2 },
  },
  balanced: {
    label: "Balanced Departmental",
    weights: { different_days: 8, compactness: 3, spread: 2, late_slot: 1 },
  },
  relaxed: {
    label: "Relaxed Packing",
    weights: { different_days: 5, compactness: 2, spread: 1, late_slot: 0 },
  },
} as const;

export interface PeriodDefinition {
  idx: number;
  label: string;
  start: string;
  end: string;
  col: string;
}

export interface SolverWeights {
  different_days: number;
  compactness: number;
  spread: number;
  late_slot: number;
}

export interface TimetableSettingsRecord {
  id: 1;
  semester_label: string | null;
  working_days: string[];
  periods: PeriodDefinition[];
  weeks_in_term: number;
  fixed_sessions_per_week: number | null;
  friday_no_p4: boolean;
  blocked_periods: Record<string, number[]>;
  online_periods: number[];
  allow_online_periods: boolean;
  excluded_periods: number[];
  semester_map: Record<string, number>;
  service_scope: "resource_only" | "ignore";
  weights: SolverWeights;
}

export function getDefaultPeriods6(): PeriodDefinition[] {
  return [
    { idx: 1, label: "08:50-10:05", start: "08:50", end: "10:05", col: "D" },
    { idx: 2, label: "10:10-11:25", start: "10:10", end: "11:25", col: "E" },
    { idx: 3, label: "11:30-12:45", start: "11:30", end: "12:45", col: "F" },
    { idx: 4, label: "13:10-14:25", start: "13:10", end: "14:25", col: "H" },
    { idx: 5, label: "14:30-15:45", start: "14:30", end: "15:45", col: "I" },
    { idx: 6, label: "15:50-17:05", start: "15:50", end: "17:05", col: "J" },
  ];
}

export function getDefaultPeriods7(): PeriodDefinition[] {
  return [
    ...getDefaultPeriods6(),
    { idx: 7, label: "17:10-18:25", start: "17:10", end: "18:25", col: "K" },
  ];
}

export function getDefaultOnlinePeriod(): PeriodDefinition {
  return {
    idx: ONLINE_SLOT_IDX,
    label: "19:00-20:20",
    start: "19:00",
    end: "20:20",
    col: ONLINE_SLOT_COL,
  };
}

export function getDefaultSettings(): TimetableSettingsRecord {
  return {
    id: 1,
    semester_label: "Spring 2026",
    working_days: [...ACADEMIC_WEEK_DAYS],
    periods: getDefaultPeriods7(),
    weeks_in_term: 14,
    fixed_sessions_per_week: 2,
    friday_no_p4: true,
    blocked_periods: { Friday: [4] },
    online_periods: [ONLINE_SLOT_IDX],
    allow_online_periods: false,
    excluded_periods: [],
    semester_map: {},
    service_scope: "resource_only",
    weights: { ...WEIGHT_DEFAULTS },
  };
}

/**
 * Splits `periods` into regular on-campus R15 periods (`P1..P6` or `P1..P7`)
 * and the optional separate online slot (`online_periods`, defaulting to `idx = 8`).
 * Ensures regular slots 6 vs. 7 NEVER turn P7 into an online slot or mutate `allow_online_periods`.
 */
export function partitionPeriods(settings: TimetableSettingsRecord): {
  regularPeriods: PeriodDefinition[];
  onlinePeriod: PeriodDefinition | null;
} {
  const onlineSet = new Set(settings.online_periods);
  const explicitSeparateOnline = settings.periods.find(
    (p) => onlineSet.has(p.idx) && p.idx >= ONLINE_SLOT_IDX,
  );
  const regularPeriods = settings.periods.filter(
    (p) => !(onlineSet.has(p.idx) && p.idx >= ONLINE_SLOT_IDX),
  );
  return {
    regularPeriods,
    onlinePeriod: explicitSeparateOnline ?? null,
  };
}

/**
 * Switches R15 regular on-campus daily slots between 6 (`P1..P6`, cols `D..J`)
 * and 7 (`P1..P7`, cols `D..K`) without altering `allow_online_periods` or the
 * independent online slot entry.
 */
export function setRegularSlotCount(
  settings: TimetableSettingsRecord,
  count: 6 | 7,
): TimetableSettingsRecord {
  const { regularPeriods, onlinePeriod } = partitionPeriods(settings);
  const defaults7 = getDefaultPeriods7();

  let nextRegular: PeriodDefinition[];
  if (count === 6) {
    nextRegular = (regularPeriods.length >= 6 ? regularPeriods : defaults7).slice(
      0,
      6,
    );
  } else {
    const base6 =
      regularPeriods.length >= 6
        ? regularPeriods.slice(0, 6)
        : defaults7.slice(0, 6);
    const existingP7 = regularPeriods.find((p) => p.idx === 7);
    const seventh = existingP7 ?? defaults7[6]!;
    nextRegular = [...base6, { ...seventh, idx: 7, col: "K" }];
  }

  const nextPeriods = onlinePeriod
    ? [...nextRegular, onlinePeriod]
    : nextRegular;

  const validRegularIds = new Set(nextRegular.map((p) => p.idx));
  const nextExcluded = settings.excluded_periods.filter(
    (id) => validRegularIds.has(id) || id >= ONLINE_SLOT_IDX,
  );

  return {
    ...settings,
    periods: nextPeriods,
    excluded_periods: nextExcluded,
  };
}

/**
 * Toggles the separate Online Slot independently from regular 6-vs-7 on-campus R15 periods.
 */
export function setOnlineSlotEnabled(
  settings: TimetableSettingsRecord,
  enabled: boolean,
): TimetableSettingsRecord {
  const { regularPeriods, onlinePeriod } = partitionPeriods(settings);
  if (!enabled) {
    return {
      ...settings,
      allow_online_periods: false,
      periods: regularPeriods,
      online_periods: [ONLINE_SLOT_IDX],
      excluded_periods: settings.excluded_periods.filter(
        (id) => id !== ONLINE_SLOT_IDX,
      ),
    };
  }

  const ensuredOnline = onlinePeriod ?? getDefaultOnlinePeriod();
  return {
    ...settings,
    allow_online_periods: true,
    online_periods: [ensuredOnline.idx],
    periods: [...regularPeriods, ensuredOnline],
  };
}

export function syncFridayJummahBlock(
  fridayNoP4: boolean,
  blocked: Record<string, number[]>,
): Record<string, number[]> {
  const next: Record<string, number[]> = {};
  for (const [day, list] of Object.entries(blocked)) {
    next[day] = Array.from(new Set(list)).sort((a, b) => a - b);
  }
  const fridaySet = new Set(next.Friday ?? []);
  if (fridayNoP4) {
    fridaySet.add(4);
  } else {
    fridaySet.delete(4);
  }
  if (fridaySet.size > 0) {
    next.Friday = Array.from(fridaySet).sort((a, b) => a - b);
  } else {
    delete next.Friday;
  }
  return next;
}

function normalizeFetchedSettings(
  raw: Record<string, unknown> | null,
): TimetableSettingsRecord {
  const defaults = getDefaultSettings();
  if (!raw) return defaults;

  const rawPeriods = Array.isArray(raw.periods) ? raw.periods : defaults.periods;
  const periods: PeriodDefinition[] = rawPeriods
    .map((item, idx) => {
      if (!item || typeof item !== "object") return null;
      const obj = item as Record<string, unknown>;
      const start = ClockTime.toHm(String(obj.start ?? "08:50"));
      const end = ClockTime.toHm(String(obj.end ?? "10:05"));
      const periodIdx =
        typeof obj.idx === "number" && Number.isFinite(obj.idx)
          ? Math.trunc(obj.idx)
          : idx + 1;
      const col =
        typeof obj.col === "string" && obj.col.trim().length > 0
          ? obj.col.trim().toUpperCase()
          : periodIdx >= ONLINE_SLOT_IDX
            ? ONLINE_SLOT_COL
            : (REGULAR_PERIOD_COLS[idx] ?? "K");
      return {
        idx: periodIdx,
        start,
        end,
        label:
          typeof obj.label === "string" && obj.label.trim().length > 0
            ? obj.label.trim()
            : `${start}-${end}`,
        col,
      };
    })
    .filter((p): p is PeriodDefinition => p !== null);

  const validDays = new Set<string>(ACADEMIC_WEEK_DAYS);
  const rawWorkingDays = Array.isArray(raw.working_days)
    ? (raw.working_days as unknown[])
    : null;
  const workingDays = rawWorkingDays
    ? ACADEMIC_WEEK_DAYS.filter(
        (d) =>
          validDays.has(d) &&
          rawWorkingDays.some((item) => String(item) === d),
      )
    : defaults.working_days;

  const rawBlocked =
    raw.blocked_periods && typeof raw.blocked_periods === "object"
      ? (raw.blocked_periods as Record<string, unknown>)
      : {};
  const blockedPeriods: Record<string, number[]> = {};
  for (const [day, list] of Object.entries(rawBlocked)) {
    if (!Array.isArray(list)) continue;
    const nums = list
      .map((v) => (typeof v === "number" ? v : Number(v)))
      .filter((v) => Number.isInteger(v) && v >= 1 && v <= 10);
    if (nums.length > 0) blockedPeriods[day] = Array.from(new Set(nums)).sort();
  }

  const fridayNoP4 =
    typeof raw.friday_no_p4 === "boolean"
      ? raw.friday_no_p4
      : Boolean(blockedPeriods.Friday?.includes(4));

  const syncedBlocked = syncFridayJummahBlock(fridayNoP4, blockedPeriods);

  const allowOnline = Boolean(raw.allow_online_periods);
  const rawOnline = Array.isArray(raw.online_periods)
    ? raw.online_periods
        .map((n) => Number(n))
        .filter((n) => Number.isInteger(n) && n >= 1 && n <= 10)
    : defaults.online_periods;

  // Preserve decoupled online_periods idx=8 when allow_online_periods is false
  const resolvedPeriods = periods.length > 0 ? periods : defaults.periods;
  const normalizedOnline =
    allowOnline && rawOnline.length > 0 ? rawOnline : [ONLINE_SLOT_IDX];

  const rawExcluded = Array.isArray(raw.excluded_periods)
    ? raw.excluded_periods
        .map((n) => Number(n))
        .filter((n) => Number.isInteger(n) && n >= 1 && n <= 10)
    : [];

  const rawSemMap =
    raw.semester_map && typeof raw.semester_map === "object"
      ? (raw.semester_map as Record<string, unknown>)
      : {};
  const semesterMap: Record<string, number> = {};
  for (const [batch, sem] of Object.entries(rawSemMap)) {
    const semNum = Number(sem);
    if (batch.trim() && Number.isInteger(semNum) && semNum >= 1 && semNum <= 12) {
      semesterMap[batch.trim()] = semNum;
    }
  }

  const rawWeights =
    raw.weights && typeof raw.weights === "object"
      ? (raw.weights as Record<string, unknown>)
      : {};
  const weights: SolverWeights = {
    different_days: Number(
      rawWeights.different_days ?? WEIGHT_DEFAULTS.different_days,
    ),
    compactness: Number(rawWeights.compactness ?? WEIGHT_DEFAULTS.compactness),
    spread: Number(rawWeights.spread ?? WEIGHT_DEFAULTS.spread),
    late_slot: Number(rawWeights.late_slot ?? WEIGHT_DEFAULTS.late_slot),
  };

  return {
    id: 1,
    semester_label:
      typeof raw.semester_label === "string" ? raw.semester_label : null,
    working_days: workingDays,
    periods: resolvedPeriods,
    weeks_in_term:
      typeof raw.weeks_in_term === "number" ? raw.weeks_in_term : 14,
    fixed_sessions_per_week:
      raw.fixed_sessions_per_week === null
        ? null
        : typeof raw.fixed_sessions_per_week === "number"
          ? raw.fixed_sessions_per_week
          : 2,
    friday_no_p4: fridayNoP4,
    blocked_periods: syncedBlocked,
    online_periods: normalizedOnline,
    allow_online_periods: allowOnline,
    excluded_periods: rawExcluded,
    semester_map: semesterMap,
    service_scope: raw.service_scope === "ignore" ? "ignore" : "resource_only",
    weights,
  };
}

export function toSettingsUpsertPayload(
  settings: TimetableSettingsRecord,
): TimetableSettingsRecord {
  const normalizedPeriods = settings.periods.map((p, idx) => {
    const start = ClockTime.toHm(ClockTime.normalizeOr(p.start));
    const end = ClockTime.toHm(ClockTime.normalizeOr(p.end));
    const periodIdx = p.idx || idx + 1;
    return {
      idx: periodIdx,
      start,
      end,
      label: `${start}-${end}`,
      col:
        p.col ||
        (periodIdx >= ONLINE_SLOT_IDX
          ? ONLINE_SLOT_COL
          : (REGULAR_PERIOD_COLS[idx] ?? "K")),
    };
  });

  const periodError = ClockTime.validateMonotonicPeriods(normalizedPeriods);
  if (periodError) {
    throw new Error(periodError);
  }

  if (
    !Number.isInteger(settings.weeks_in_term) ||
    settings.weeks_in_term < 1 ||
    settings.weeks_in_term > 52
  ) {
    throw new Error("Teaching weeks in term must be an integer between 1 and 52.");
  }

  const fixed = settings.fixed_sessions_per_week;
  if (
    fixed !== null &&
    (!Number.isInteger(fixed) || fixed < 0 || fixed > 7)
  ) {
    throw new Error(
      "Fixed sessions per week must be empty (derived) or between 0 and 7.",
    );
  }

  return {
    id: 1,
    semester_label: settings.semester_label?.trim()
      ? settings.semester_label.trim()
      : null,
    working_days: [...settings.working_days],
    periods: normalizedPeriods,
    weeks_in_term: settings.weeks_in_term,
    fixed_sessions_per_week: fixed,
    friday_no_p4: Boolean(settings.friday_no_p4),
    blocked_periods: syncFridayJummahBlock(
      settings.friday_no_p4,
      settings.blocked_periods,
    ),
    online_periods: settings.allow_online_periods
      ? settings.online_periods.length > 0
        ? settings.online_periods
        : [ONLINE_SLOT_IDX]
      : [ONLINE_SLOT_IDX],
    allow_online_periods: Boolean(settings.allow_online_periods),
    excluded_periods: settings.excluded_periods,
    semester_map: settings.semester_map,
    service_scope: settings.service_scope === "ignore" ? "ignore" : "resource_only",
    weights: { ...settings.weights },
  };
}

let devPreviewSettingsStore: TimetableSettingsRecord = getDefaultSettings();

export async function fetchTimetableSettings(
  isDevPreview: boolean,
): Promise<TimetableSettingsRecord> {
  if (isDevPreview || !isSupabaseConfigured || !supabase) {
    return structuredClone(devPreviewSettingsStore);
  }

  const { data, error } = await supabase
    .from("timetable_settings")
    .select(SETTINGS_SELECT_COLUMNS)
    .eq("id", 1)
    .maybeSingle();

  if (error) {
    throw new Error(error.message);
  }

  return normalizeFetchedSettings(
    (data as Record<string, unknown> | null) ?? null,
  );
}

export async function saveTimetableSettings(
  settings: TimetableSettingsRecord,
  isDevPreview: boolean,
): Promise<TimetableSettingsRecord> {
  const payload = toSettingsUpsertPayload(settings);

  if (isDevPreview || !isSupabaseConfigured || !supabase) {
    devPreviewSettingsStore = structuredClone(payload);
    return structuredClone(devPreviewSettingsStore);
  }

  const { data, error } = await supabase
    .from("timetable_settings")
    .upsert(payload, { onConflict: "id" })
    .select(SETTINGS_SELECT_COLUMNS)
    .single();

  if (error) {
    throw new Error(error.message);
  }

  return normalizeFetchedSettings(data as Record<string, unknown>);
}
