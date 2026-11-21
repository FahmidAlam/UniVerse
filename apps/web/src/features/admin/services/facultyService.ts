import { isSupabaseConfigured, supabase } from "@/services/supabase";

/**
 * Strictly pinned to the 8 verified baseline PostgreSQL columns on `public.timetable_faculty`
 * (`20261021214512_reconstructed_baseline.sql`). Zero probes for `home_department_id`.
 */
export const FACULTY_SELECT_COLUMNS =
  "id, acronym, full_name, dept, designation, off_days, is_active, courses";

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

export interface TimetableFacultyRecord {
  id: string;
  acronym: string;
  full_name: string | null;
  dept: string | null;
  designation: string | null;
  off_days: string[];
  is_active: boolean;
  courses: string[];
}

export interface FacultyWriteInput {
  acronym: string;
  full_name?: string | null;
  dept?: string | null;
  designation?: string | null;
  off_days: string[];
  is_active: boolean;
  courses: string[];
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

/**
 * Emits ONLY the 7 writable baseline columns on `public.timetable_faculty`.
 * Never includes Phase A non-DB fields (`employment_type`, `slot_matrix`, etc.).
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

export function isR7OffDayOutsideBounds(offDays: readonly string[]): boolean {
  return offDays.length < 2 || offDays.length > 3;
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

  const { data, error } = await supabase
    .from("timetable_faculty")
    .select(FACULTY_SELECT_COLUMNS)
    .order("acronym");

  if (error) {
    throw new Error(error.message);
  }

  return ((data ?? []) as TimetableFacultyRecord[]).map((row) => ({
    ...row,
    off_days: Array.isArray(row.off_days) ? row.off_days : [],
    courses: Array.isArray(row.courses) ? row.courses : [],
  }));
}

export async function createFaculty(
  input: FacultyWriteInput,
  isDevPreview: boolean,
): Promise<TimetableFacultyRecord> {
  const payload = toFacultyWritePayload(input);

  if (isDevPreview || !isSupabaseConfigured || !supabase) {
    const duplicate = devPreviewFacultyStore.some(
      (f) => f.acronym === payload.acronym,
    );
    if (duplicate) {
      throw new Error(`Faculty acronym "${payload.acronym}" already exists.`);
    }
    const created: TimetableFacultyRecord = {
      id: `preview-fac-${Date.now()}`,
      ...payload,
    };
    devPreviewFacultyStore.push(created);
    return created;
  }

  const { data, error } = await supabase
    .from("timetable_faculty")
    .insert(payload)
    .select(FACULTY_SELECT_COLUMNS)
    .single();

  if (error) {
    throw new Error(error.message);
  }

  return data as TimetableFacultyRecord;
}

export async function updateFaculty(
  id: string,
  input: FacultyWriteInput,
  isDevPreview: boolean,
): Promise<TimetableFacultyRecord> {
  const payload = toFacultyWritePayload(input);

  if (isDevPreview || !isSupabaseConfigured || !supabase) {
    const idx = devPreviewFacultyStore.findIndex((f) => f.id === id);
    if (idx === -1) throw new Error("Faculty record not found.");
    const updated: TimetableFacultyRecord = { id, ...payload };
    devPreviewFacultyStore[idx] = updated;
    return updated;
  }

  const { data, error } = await supabase
    .from("timetable_faculty")
    .update(payload)
    .eq("id", id)
    .select(FACULTY_SELECT_COLUMNS)
    .single();

  if (error) {
    throw new Error(error.message);
  }

  return data as TimetableFacultyRecord;
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
