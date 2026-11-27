import type { SlotMatrixEntry } from "@/features/admin/components/DaySlotMatrixPicker";
import { isSupabaseConfigured, supabase } from "@/services/supabase";

/**
 * Strictly pinned to the 8 verified baseline PostgreSQL columns on `public.timetable_faculty`
 * (`20261021214512_reconstructed_baseline.sql`). Zero probes for `home_department_id`.
 */
export const FACULTY_SELECT_COLUMNS =
  "id, acronym, full_name, dept, designation, off_days, is_active, courses";

export const FACULTY_EXTENDED_SELECT_COLUMNS =
  `${FACULTY_SELECT_COLUMNS}, employment_type, allow_three_off_days, is_sust_adjunct, external_blocked_slots, available_slots, preferred_slots`;

export const ACADEMIC_WEEK_DAYS = [
  "Sunday",
  "Monday",
  "Tuesday",
  "Wednesday",
  "Thursday",
  "Friday",
  "Saturday",
] as const;

export const FACULTY_DESIGNATIONS = [
  "Professor",
  "Associate Professor",
  "Assistant Professor",
  "Senior Lecturer",
  "Lecturer",
] as const;

export const INSTITUTIONAL_DEPARTMENTS = [
  "CSE",
  "EEE",
  "BBA",
  "English",
  "GED",
  "CE",
  "Law",
] as const;

export type FacultyEmploymentType = "permanent" | "adjunct" | "guest";

export interface TimetableFacultyRecord {
  id: string;
  acronym: string;
  full_name: string | null;
  dept: string | null;
  designation: string | null;
  off_days: string[];
  is_active: boolean;
  courses: string[];
  // Stage 5A extended columns (populated when Stage 5A schema is live)
  employment_type?: FacultyEmploymentType;
  allow_three_off_days?: boolean;
  is_sust_adjunct?: boolean;
  external_blocked_slots?: SlotMatrixEntry[];
  available_slots?: SlotMatrixEntry[];
  preferred_slots?: SlotMatrixEntry[];
}

export interface FacultyWriteInput {
  acronym: string;
  full_name?: string | null;
  dept?: string | null;
  designation?: string | null;
  off_days: string[];
  is_active: boolean;
  courses: string[];
  employment_type?: FacultyEmploymentType;
  allow_three_off_days?: boolean;
  is_sust_adjunct?: boolean;
  external_blocked_slots?: SlotMatrixEntry[];
  available_slots?: SlotMatrixEntry[];
  preferred_slots?: SlotMatrixEntry[];
}

export interface FacultyWritePayload {
  acronym: string;
  full_name: string | null;
  dept: string | null;
  designation: string | null;
  off_days: string[];
  is_active: boolean;
  courses: string[];
}

export interface ExtendedFacultyWritePayload extends FacultyWritePayload {
  employment_type: FacultyEmploymentType;
  allow_three_off_days: boolean;
  is_sust_adjunct: boolean;
  external_blocked_slots: SlotMatrixEntry[];
  available_slots: SlotMatrixEntry[];
  preferred_slots: SlotMatrixEntry[];
}

function normalizeSlotList(raw: unknown): SlotMatrixEntry[] {
  if (!Array.isArray(raw)) return [];
  const validDays = new Set<string>(ACADEMIC_WEEK_DAYS);
  const seen = new Set<string>();
  const out: SlotMatrixEntry[] = [];
  for (const item of raw) {
    if (!item || typeof item !== "object") continue;
    const obj = item as { day?: unknown; period_idx?: unknown };
    const day = String(obj.day ?? "").trim();
    const periodIdx = Number(obj.period_idx);
    if (!validDays.has(day) || !Number.isInteger(periodIdx) || periodIdx < 1 || periodIdx > 12) {
      continue;
    }
    const key = `${day}|${periodIdx}`;
    if (seen.has(key)) continue;
    seen.add(key);
    out.push({ day, period_idx: periodIdx });
  }
  return out;
}

/**
 * Emits ONLY the 7 writable baseline columns on `public.timetable_faculty`.
 * Never includes Stage 5A extended columns when targeting pre-migration DBs.
 */
export function toFacultyWritePayload(
  input: FacultyWriteInput,
): FacultyWritePayload {
  const acronym = input.acronym.trim().toUpperCase();
  const full_name = input.full_name?.trim() ? input.full_name.trim() : null;
  const dept = input.dept?.trim() ? input.dept.trim() : null;
  const designation = input.designation?.trim()
    ? input.designation.trim()
    : null;

  const validDaySet = new Set<string>(ACADEMIC_WEEK_DAYS);
  const off_days = ACADEMIC_WEEK_DAYS.filter(
    (day) => validDaySet.has(day) && input.off_days.includes(day),
  );

  const courses = Array.from(
    new Set(
      input.courses
        .map((c) => c.trim().toUpperCase())
        .filter((c) => c.length > 0),
    ),
  );

  return {
    acronym,
    full_name,
    dept,
    designation,
    off_days,
    is_active: Boolean(input.is_active),
    courses,
  };
}

export function toExtendedFacultyWritePayload(
  input: FacultyWriteInput,
): ExtendedFacultyWritePayload {
  const base = toFacultyWritePayload(input);
  const emp: FacultyEmploymentType =
    input.employment_type === "adjunct" || input.employment_type === "guest"
      ? input.employment_type
      : "permanent";

  return {
    ...base,
    employment_type: emp,
    allow_three_off_days: emp === "permanent" ? Boolean(input.allow_three_off_days) : false,
    is_sust_adjunct: emp === "adjunct" ? Boolean(input.is_sust_adjunct) : false,
    external_blocked_slots: normalizeSlotList(input.external_blocked_slots),
    available_slots: emp === "guest" ? normalizeSlotList(input.available_slots) : [],
    preferred_slots: normalizeSlotList(input.preferred_slots),
  };
}

export function isR7OffDayOutsideBounds(offDays: readonly string[]): boolean {
  return offDays.length < 2 || offDays.length > 3;
}

export function isR7OffDayHardConflict(fac: {
  employment_type?: FacultyEmploymentType;
  off_days: readonly string[];
  allow_three_off_days?: boolean;
}): boolean {
  const emp = fac.employment_type ?? "permanent";
  if (emp !== "permanent") return false;
  const n = fac.off_days.length;
  return n > 3 || (n === 3 && !fac.allow_three_off_days);
}

export function evaluateR7FacultyPolicy(fac: {
  employment_type?: FacultyEmploymentType;
  off_days: readonly string[];
  allow_three_off_days?: boolean;
}): {
  valid: boolean;
  severity: "ok" | "warning" | "blocker";
  hybridAutoResolve?: boolean;
  message: string;
} {
  const emp = fac.employment_type ?? "permanent";
  if (emp !== "permanent") {
    return {
      valid: true,
      severity: "ok",
      message: `${emp === "guest" ? "Guest" : "Adjunct"} faculty governed by R5/R6 bands.`,
    };
  }
  const n = fac.off_days.length;
  if (n === 2) {
    return { valid: true, severity: "ok", message: "2 off-days (R7 standard)" };
  }
  if (n === 3 && fac.allow_three_off_days) {
    return { valid: true, severity: "ok", message: "3 off-days (authorized D3)" };
  }
  if (n === 3) {
    return {
      valid: false,
      severity: "warning",
      message: "3 off-days requires explicit D3 authorization",
    };
  }
  if (n === 0 || n === 1) {
    return {
      valid: true,
      severity: "ok",
      hybridAutoResolve: true,
      message: "Hybrid: Solver will assign remaining off-day(s)",
    };
  }
  return {
    valid: false,
    severity: "blocker",
    message: `R7 permits at most 2 off-days (or 3 authorized); currently ${n}`,
  };
}

function isMissingColumnError(err: { code?: string; message?: string } | null): boolean {
  if (!err) return false;
  const code = err.code ?? "";
  const msg = (err.message ?? "").toLowerCase();
  return code === "42703" || code === "PGRST204" || msg.includes("column");
}

function normalizeFacultyRow(
  raw: Record<string, unknown>,
  extended: boolean,
): TimetableFacultyRecord {
  const base: TimetableFacultyRecord = {
    id: String(raw.id),
    acronym: String(raw.acronym ?? "").trim().toUpperCase(),
    full_name: raw.full_name ? String(raw.full_name) : null,
    dept: raw.dept ? String(raw.dept) : null,
    designation: raw.designation ? String(raw.designation) : null,
    off_days: Array.isArray(raw.off_days) ? raw.off_days.map(String) : [],
    is_active: raw.is_active !== false,
    courses: Array.isArray(raw.courses) ? raw.courses.map(String) : [],
  };

  if (!extended) return base;

  const empRaw = String(raw.employment_type ?? "permanent").toLowerCase();
  const employment_type: FacultyEmploymentType =
    empRaw === "adjunct" || empRaw === "guest" ? empRaw : "permanent";

  return {
    ...base,
    employment_type,
    allow_three_off_days: Boolean(raw.allow_three_off_days),
    is_sust_adjunct: Boolean(raw.is_sust_adjunct),
    external_blocked_slots: normalizeSlotList(raw.external_blocked_slots),
    available_slots: normalizeSlotList(raw.available_slots),
    preferred_slots: normalizeSlotList(raw.preferred_slots),
  };
}

let cachedFacultyExtendedSupported: boolean | null = null;

export async function isFacultyExtendedSchemaLive(
  isDevPreview: boolean,
): Promise<boolean> {
  if (isDevPreview || !isSupabaseConfigured || !supabase) return true;
  if (cachedFacultyExtendedSupported !== null) {
    return cachedFacultyExtendedSupported;
  }
  const { error } = await supabase
    .from("timetable_faculty")
    .select("id, employment_type, allow_three_off_days")
    .limit(1);
  cachedFacultyExtendedSupported = !error || !isMissingColumnError(error);
  return cachedFacultyExtendedSupported;
}

const devPreviewFacultyStore: TimetableFacultyRecord[] = [];

export async function fetchFaculty(
  isDevPreview: boolean,
): Promise<TimetableFacultyRecord[]> {
  if (isDevPreview || !isSupabaseConfigured || !supabase) {
    return [...devPreviewFacultyStore].sort((a, b) =>
      a.acronym.localeCompare(b.acronym),
    );
  }

  const extRes = await supabase
    .from("timetable_faculty")
    .select(FACULTY_EXTENDED_SELECT_COLUMNS)
    .order("acronym");

  if (!extRes.error) {
    cachedFacultyExtendedSupported = true;
    return ((extRes.data ?? []) as unknown as Record<string, unknown>[]).map((r) =>
      normalizeFacultyRow(r, true),
    );
  }

  if (!isMissingColumnError(extRes.error)) {
    throw new Error(extRes.error.message);
  }

  cachedFacultyExtendedSupported = false;
  const { data, error } = await supabase
    .from("timetable_faculty")
    .select(FACULTY_SELECT_COLUMNS)
    .order("acronym");

  if (error) {
    throw new Error(error.message);
  }

  return ((data ?? []) as unknown as Record<string, unknown>[]).map((r) =>
    normalizeFacultyRow(r, false),
  );
}

export async function createFaculty(
  input: FacultyWriteInput,
  isDevPreview: boolean,
): Promise<TimetableFacultyRecord> {
  if (isDevPreview || !isSupabaseConfigured || !supabase) {
    const extPayload = toExtendedFacultyWritePayload(input);
    const duplicate = devPreviewFacultyStore.some(
      (f) => f.acronym === extPayload.acronym,
    );
    if (duplicate) {
      throw new Error(`Faculty acronym "${extPayload.acronym}" already exists.`);
    }
    const created: TimetableFacultyRecord = {
      id: `preview-fac-${Date.now()}`,
      ...extPayload,
    };
    devPreviewFacultyStore.push(created);
    return created;
  }

  if (cachedFacultyExtendedSupported !== false) {
    const extPayload = toExtendedFacultyWritePayload(input);
    const { data, error } = await supabase
      .from("timetable_faculty")
      .insert(extPayload)
      .select(FACULTY_EXTENDED_SELECT_COLUMNS)
      .single();

    if (!error) {
      cachedFacultyExtendedSupported = true;
      return normalizeFacultyRow(data as unknown as Record<string, unknown>, true);
    }
    if (!isMissingColumnError(error)) {
      throw new Error(error.message);
    }
    cachedFacultyExtendedSupported = false;
  }

  const payload = toFacultyWritePayload(input);
  const { data, error } = await supabase
    .from("timetable_faculty")
    .insert(payload)
    .select(FACULTY_SELECT_COLUMNS)
    .single();

  if (error) {
    throw new Error(error.message);
  }

  return normalizeFacultyRow(data as unknown as Record<string, unknown>, false);
}

export async function updateFaculty(
  id: string,
  input: FacultyWriteInput,
  isDevPreview: boolean,
): Promise<TimetableFacultyRecord> {
  if (isDevPreview || !isSupabaseConfigured || !supabase) {
    const extPayload = toExtendedFacultyWritePayload(input);
    const idx = devPreviewFacultyStore.findIndex((f) => f.id === id);
    if (idx === -1) throw new Error("Faculty record not found.");
    const updated: TimetableFacultyRecord = { id, ...extPayload };
    devPreviewFacultyStore[idx] = updated;
    return updated;
  }

  if (cachedFacultyExtendedSupported !== false) {
    const extPayload = toExtendedFacultyWritePayload(input);
    const { data, error } = await supabase
      .from("timetable_faculty")
      .update(extPayload)
      .eq("id", id)
      .select(FACULTY_EXTENDED_SELECT_COLUMNS)
      .single();

    if (!error) {
      cachedFacultyExtendedSupported = true;
      return normalizeFacultyRow(data as unknown as Record<string, unknown>, true);
    }
    if (!isMissingColumnError(error)) {
      throw new Error(error.message);
    }
    cachedFacultyExtendedSupported = false;
  }

  const payload = toFacultyWritePayload(input);
  const { data, error } = await supabase
    .from("timetable_faculty")
    .update(payload)
    .eq("id", id)
    .select(FACULTY_SELECT_COLUMNS)
    .single();

  if (error) {
    throw new Error(error.message);
  }

  return normalizeFacultyRow(data as unknown as Record<string, unknown>, false);
}

export async function bulkSetFacultyActive(
  ids: readonly string[],
  isActive: boolean,
  isDevPreview: boolean,
): Promise<void> {
  if (ids.length === 0) return;

  if (isDevPreview || !isSupabaseConfigured || !supabase) {
    for (const f of devPreviewFacultyStore) {
      if (ids.includes(f.id)) f.is_active = isActive;
    }
    return;
  }

  const { error } = await supabase
    .from("timetable_faculty")
    .update({ is_active: isActive })
    .in("id", [...ids]);

  if (error) {
    throw new Error(error.message);
  }
}

export async function deleteFacultyRecords(
  ids: readonly string[],
  isDevPreview: boolean,
): Promise<void> {
  if (ids.length === 0) return;

  if (isDevPreview || !isSupabaseConfigured || !supabase) {
    for (let i = devPreviewFacultyStore.length - 1; i >= 0; i--) {
      if (ids.includes(devPreviewFacultyStore[i]!.id)) {
        devPreviewFacultyStore.splice(i, 1);
      }
    }
    return;
  }

  const { error } = await supabase
    .from("timetable_faculty")
    .delete()
    .in("id", [...ids]);

  if (error) {
    throw new Error(error.message);
  }
}
