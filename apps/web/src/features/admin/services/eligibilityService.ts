import { isSupabaseConfigured, supabase } from "@/services/supabase";

export const ELIGIBILITY_SELECT_COLUMNS =
  "id, acronym, course_code, is_eligible, priority, created_at, updated_at";

export interface CourseEligibilityRecord {
  id: string;
  acronym: string;
  course_code: string;
  is_eligible: boolean;
  priority: number | null;
  created_at: string;
  updated_at: string;
}

export interface EligibilityWriteInput {
  acronym: string;
  course_code: string;
  is_eligible: boolean;
  priority?: number | null;
}

export interface EligibilityWritePayload {
  acronym: string;
  course_code: string;
  is_eligible: boolean;
  priority: number | null;
}

export interface DynamicCourseOption {
  code: string;
  title: string;
}

export function toEligibilityWritePayload(
  input: EligibilityWriteInput,
): EligibilityWritePayload {
  const priority =
    typeof input.priority === "number" &&
    Number.isFinite(input.priority) &&
    input.priority >= 1
      ? Math.trunc(input.priority)
      : null;

  return {
    acronym: input.acronym.trim().toUpperCase(),
    course_code: input.course_code.trim().toUpperCase(),
    is_eligible: Boolean(input.is_eligible),
    priority,
  };
}

const devPreviewEligibilityStore: CourseEligibilityRecord[] = [];

export async function fetchEligibilityRecords(
  isDevPreview: boolean,
): Promise<CourseEligibilityRecord[]> {
  if (isDevPreview || !isSupabaseConfigured || !supabase) {
    return [...devPreviewEligibilityStore].sort((a, b) =>
      a.acronym.localeCompare(b.acronym) ||
      (a.priority ?? 999) - (b.priority ?? 999) ||
      a.course_code.localeCompare(b.course_code),
    );
  }

  const { data, error } = await supabase
    .from("timetable_course_eligibility")
    .select(ELIGIBILITY_SELECT_COLUMNS)
    .order("acronym")
    .order("priority", { ascending: true, nullsFirst: false })
    .order("course_code");

  if (error) {
    throw new Error(error.message);
  }

  return (data ?? []) as CourseEligibilityRecord[];
}

/**
 * Dynamically derives course options from live `public.routines`, existing
 * `timetable_course_eligibility` rows, and `timetable_faculty.courses` (zero hardcoded fixtures).
 */
export async function fetchDynamicCourseOptions(
  isDevPreview: boolean,
  eligibilityRows: readonly CourseEligibilityRecord[],
  facultyCourses: readonly string[],
): Promise<DynamicCourseOption[]> {
  const byCode = new Map<string, string>();

  for (const row of eligibilityRows) {
    const code = row.course_code.trim().toUpperCase();
    if (code && !byCode.has(code)) byCode.set(code, code);
  }

  for (const raw of facultyCourses) {
    const code = raw.trim().toUpperCase();
    if (code && !byCode.has(code)) byCode.set(code, code);
  }

  if (!isDevPreview && isSupabaseConfigured && supabase) {
    const { data, error } = await supabase
      .from("routines")
      .select("subject_code, subject");

    if (error) {
      throw new Error(`routines: ${error.message}`);
    }

    for (const row of data ?? []) {
      const code =
        typeof row.subject_code === "string"
          ? row.subject_code.trim().toUpperCase()
          : "";
      if (!code) continue;
      const title =
        typeof row.subject === "string" && row.subject.trim().length > 0
          ? row.subject.trim()
          : code;
      if (!byCode.has(code) || byCode.get(code) === code) {
        byCode.set(code, title);
      }
    }
  }

  return Array.from(byCode.entries())
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([code, title]) => ({ code, title }));
}

export async function upsertEligibilityRecord(
  input: EligibilityWriteInput,
  isDevPreview: boolean,
): Promise<CourseEligibilityRecord> {
  const payload = toEligibilityWritePayload(input);
  const now = new Date().toISOString();

  if (isDevPreview || !isSupabaseConfigured || !supabase) {
    const idx = devPreviewEligibilityStore.findIndex(
      (r) =>
        r.acronym === payload.acronym && r.course_code === payload.course_code,
    );
    if (idx !== -1) {
      const updated: CourseEligibilityRecord = {
        ...devPreviewEligibilityStore[idx]!,
        ...payload,
        updated_at: now,
      };
      devPreviewEligibilityStore[idx] = updated;
      return updated;
    }
    const created: CourseEligibilityRecord = {
      id: `preview-elig-${Date.now()}`,
      ...payload,
      created_at: now,
      updated_at: now,
    };
    devPreviewEligibilityStore.push(created);
    return created;
  }

  const { data, error } = await supabase
    .from("timetable_course_eligibility")
    .upsert(payload, { onConflict: "acronym,course_code" })
    .select(ELIGIBILITY_SELECT_COLUMNS)
    .single();

  if (error) {
    throw new Error(error.message);
  }

  return data as CourseEligibilityRecord;
}

export async function bulkSetEligibilityStatus(
  ids: readonly string[],
  isEligible: boolean,
  isDevPreview: boolean,
): Promise<void> {
  if (ids.length === 0) return;

  if (isDevPreview || !isSupabaseConfigured || !supabase) {
    const now = new Date().toISOString();
    for (const r of devPreviewEligibilityStore) {
      if (ids.includes(r.id)) {
        r.is_eligible = isEligible;
        r.updated_at = now;
      }
    }
    return;
  }

  const { error } = await supabase
    .from("timetable_course_eligibility")
    .update({ is_eligible: isEligible })
    .in("id", [...ids]);

  if (error) {
    throw new Error(error.message);
  }
}

export async function deleteEligibilityRecords(
  ids: readonly string[],
  isDevPreview: boolean,
): Promise<void> {
  if (ids.length === 0) return;

  if (isDevPreview || !isSupabaseConfigured || !supabase) {
    for (let i = devPreviewEligibilityStore.length - 1; i >= 0; i--) {
      if (ids.includes(devPreviewEligibilityStore[i]!.id)) {
        devPreviewEligibilityStore.splice(i, 1);
      }
    }
    return;
  }

  const { error } = await supabase
    .from("timetable_course_eligibility")
    .delete()
    .in("id", [...ids]);

  if (error) {
    throw new Error(error.message);
  }
}
