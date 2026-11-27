import { z } from "zod";
import type { RoutineRow } from "@/features/routine/types";
import { isSupabaseConfigured, supabase } from "@/services/supabase";

export const CATALOG_COURSES_SELECT_COLUMNS =
  "id, code, title, department_id, dept_code, credit, class_type, is_service, is_physics_lab, default_weekly_sessions, is_active, notes, created_at, updated_at";

export type CourseClassType = "theory" | "lab";

export interface CatalogCourseRecord {
  id: string;
  code: string;
  title: string;
  department_id: string | null;
  dept_code: string;
  credit: number;
  class_type: CourseClassType;
  is_service: boolean;
  is_physics_lab: boolean;
  default_weekly_sessions: number | null;
  is_active: boolean;
  notes: string | null;
  created_at: string;
  updated_at: string;
}

export interface CatalogCourseWriteInput {
  code: string;
  title: string;
  dept_code: string;
  credit: number;
  class_type: CourseClassType;
  is_service: boolean;
  is_physics_lab: boolean;
  default_weekly_sessions: number | null;
  is_active: boolean;
  notes?: string | null;
}

export interface CatalogCourseWritePayload {
  code: string;
  title: string;
  dept_code: string;
  credit: number;
  class_type: CourseClassType;
  is_service: boolean;
  is_physics_lab: boolean;
  default_weekly_sessions: number | null;
  is_active: boolean;
  notes: string | null;
}

export const catalogCourseWriteSchema = z.object({
  code: z
    .string()
    .trim()
    .min(2, "Course code must be at least 2 characters.")
    .max(30, "Course code is too long."),
  title: z
    .string()
    .trim()
    .min(2, "Course title is required.")
    .max(160, "Course title is too long."),
  dept_code: z
    .string()
    .trim()
    .min(1, "Department code is required.")
    .max(20, "Department code is too long."),
  credit: z
    .number()
    .finite()
    .gt(0, "Credit must be greater than 0.")
    .lte(12, "Credit cannot exceed 12."),
  class_type: z.enum(["theory", "lab"]),
  is_service: z.boolean(),
  is_physics_lab: z.boolean(),
  default_weekly_sessions: z
    .number()
    .int()
    .min(1, "Weekly sessions must be 1–14.")
    .max(14, "Weekly sessions must be 1–14.")
    .nullable(),
  is_active: z.boolean(),
  notes: z.string().trim().max(400).nullable().optional(),
});

export function toCatalogCourseWritePayload(
  input: CatalogCourseWriteInput,
): CatalogCourseWritePayload {
  const parsed = catalogCourseWriteSchema.parse({
    ...input,
    code: input.code.trim().toUpperCase(),
    title: input.title.trim(),
    dept_code: input.dept_code.trim().toUpperCase() || "CSE",
    credit: Number(input.credit),
    is_physics_lab: input.class_type === "lab" ? Boolean(input.is_physics_lab) : false,
    notes: input.notes?.trim() ? input.notes.trim() : null,
  });

  return {
    code: parsed.code,
    title: parsed.title,
    dept_code: parsed.dept_code,
    credit: Number(parsed.credit.toFixed(1)),
    class_type: parsed.class_type,
    is_service: parsed.is_service,
    is_physics_lab: parsed.is_physics_lab,
    default_weekly_sessions: parsed.default_weekly_sessions,
    is_active: parsed.is_active,
    notes: parsed.notes ?? null,
  };
}

function isMissingTableError(err: { code?: string; message?: string } | null): boolean {
  if (!err) return false;
  const code = err.code ?? "";
  const msg = (err.message ?? "").toLowerCase();
  return (
    code === "42P01" ||
    code === "PGRST205" ||
    msg.includes("does not exist") ||
    msg.includes("could not find the table")
  );
}

function normalizeCourseRow(raw: Record<string, unknown>): CatalogCourseRecord {
  return {
    id: String(raw.id),
    code: String(raw.code ?? "").trim().toUpperCase(),
    title: String(raw.title ?? "").trim(),
    department_id: raw.department_id ? String(raw.department_id) : null,
    dept_code: String(raw.dept_code ?? "CSE").trim().toUpperCase(),
    credit: Number(raw.credit ?? 3) || 3,
    class_type: raw.class_type === "lab" ? "lab" : "theory",
    is_service: Boolean(raw.is_service),
    is_physics_lab: Boolean(raw.is_physics_lab),
    default_weekly_sessions:
      typeof raw.default_weekly_sessions === "number"
        ? raw.default_weekly_sessions
        : null,
    is_active: raw.is_active !== false,
    notes: raw.notes ? String(raw.notes) : null,
    created_at: String(raw.created_at ?? new Date().toISOString()),
    updated_at: String(raw.updated_at ?? new Date().toISOString()),
  };
}

const devPreviewCoursesStore: CatalogCourseRecord[] = [
  {
    id: "preview-course-1",
    code: "CSE-1101",
    title: "Structured Programming Language",
    department_id: null,
    dept_code: "CSE",
    credit: 3.0,
    class_type: "theory",
    is_service: false,
    is_physics_lab: false,
    default_weekly_sessions: 2,
    is_active: true,
    notes: null,
    created_at: "2026-11-20T00:00:00.000Z",
    updated_at: "2026-11-20T00:00:00.000Z",
  },
  {
    id: "preview-course-2",
    code: "PHY-1104",
    title: "Physics Lab",
    department_id: null,
    dept_code: "PHY",
    credit: 1.5,
    class_type: "lab",
    is_service: true,
    is_physics_lab: true,
    default_weekly_sessions: 2,
    is_active: true,
    notes: "Bound to Physics Lab under R11",
    created_at: "2026-11-20T00:00:00.000Z",
    updated_at: "2026-11-20T00:00:00.000Z",
  },
];

export async function fetchCatalogCourses(
  isDevPreview: boolean,
): Promise<{ live: boolean; courses: CatalogCourseRecord[] }> {
  if (isDevPreview || !isSupabaseConfigured || !supabase) {
    return {
      live: true,
      courses: [...devPreviewCoursesStore].sort((a, b) =>
        a.code.localeCompare(b.code),
      ),
    };
  }

  const { data, error } = await supabase
    .from("catalog_courses")
    .select(CATALOG_COURSES_SELECT_COLUMNS)
    .order("code");

  if (error) {
    if (isMissingTableError(error)) {
      return { live: false, courses: [] };
    }
    throw new Error(error.message);
  }

  return {
    live: true,
    courses: ((data ?? []) as Record<string, unknown>[]).map(normalizeCourseRow),
  };
}

export async function createCatalogCourse(
  input: CatalogCourseWriteInput,
  isDevPreview: boolean,
): Promise<CatalogCourseRecord> {
  const payload = toCatalogCourseWritePayload(input);

  if (isDevPreview || !isSupabaseConfigured || !supabase) {
    if (devPreviewCoursesStore.some((c) => c.code === payload.code)) {
      throw new Error(`Course "${payload.code}" already exists.`);
    }
    const now = new Date().toISOString();
    const created: CatalogCourseRecord = {
      id: `preview-course-${Date.now()}-${Math.floor(Math.random() * 1000)}`,
      department_id: null,
      ...payload,
      created_at: now,
      updated_at: now,
    };
    devPreviewCoursesStore.push(created);
    return created;
  }

  const { data, error } = await supabase
    .from("catalog_courses")
    .insert(payload)
    .select(CATALOG_COURSES_SELECT_COLUMNS)
    .single();

  if (error) {
    throw new Error(error.message);
  }

  return normalizeCourseRow(data as Record<string, unknown>);
}

export async function updateCatalogCourse(
  id: string,
  input: CatalogCourseWriteInput,
  isDevPreview: boolean,
): Promise<CatalogCourseRecord> {
  const payload = toCatalogCourseWritePayload(input);

  if (isDevPreview || !isSupabaseConfigured || !supabase) {
    const idx = devPreviewCoursesStore.findIndex((c) => c.id === id);
    if (idx === -1) throw new Error("Course record not found.");
    const updated: CatalogCourseRecord = {
      ...devPreviewCoursesStore[idx]!,
      ...payload,
      updated_at: new Date().toISOString(),
    };
    devPreviewCoursesStore[idx] = updated;
    return updated;
  }

  const { data, error } = await supabase
    .from("catalog_courses")
    .update(payload)
    .eq("id", id)
    .select(CATALOG_COURSES_SELECT_COLUMNS)
    .single();

  if (error) {
    throw new Error(error.message);
  }

  return normalizeCourseRow(data as Record<string, unknown>);
}

export async function bulkSetCatalogCoursesActive(
  ids: readonly string[],
  isActive: boolean,
  isDevPreview: boolean,
): Promise<void> {
  if (ids.length === 0) return;
  if (isDevPreview || !isSupabaseConfigured || !supabase) {
    for (const c of devPreviewCoursesStore) {
      if (ids.includes(c.id)) c.is_active = isActive;
    }
    return;
  }

  const { error } = await supabase
    .from("catalog_courses")
    .update({ is_active: isActive })
    .in("id", [...ids]);

  if (error) {
    throw new Error(error.message);
  }
}

export async function deleteCatalogCourses(
  ids: readonly string[],
  isDevPreview: boolean,
): Promise<void> {
  if (ids.length === 0) return;
  if (isDevPreview || !isSupabaseConfigured || !supabase) {
    for (let i = devPreviewCoursesStore.length - 1; i >= 0; i--) {
      if (ids.includes(devPreviewCoursesStore[i]!.id)) {
        devPreviewCoursesStore.splice(i, 1);
      }
    }
    return;
  }

  const { error } = await supabase
    .from("catalog_courses")
    .delete()
    .in("id", [...ids]);

  if (error) {
    throw new Error(error.message);
  }
}

export function buildCoursesHarvestFromRoutines(
  routines: readonly RoutineRow[],
  existingCourses: readonly CatalogCourseRecord[],
): { toInsert: CatalogCourseWritePayload[]; skippedCount: number } {
  const existingCodes = new Set(
    existingCourses.map((c) => c.code.trim().toUpperCase()),
  );
  const seen = new Map<string, CatalogCourseWritePayload>();
  let skippedCount = 0;

  for (const row of routines) {
    if (row.is_active === false) continue;
    const code = row.subject_code.trim().toUpperCase();
    if (!code) continue;
    if (existingCodes.has(code)) {
      skippedCount += 1;
      continue;
    }
    if (seen.has(code)) continue;

    const deptMatch = code.match(/^([A-Z]+)/);
    const deptCode = deptMatch?.[1] || (row.is_service ? "GEN" : "CSE");
    const lastDigitMatch = code.match(/(\d)$/);
    const evenDigit = lastDigitMatch
      ? Number.parseInt(lastDigitMatch[1]!, 10) % 2 === 0
      : false;
    const isLab =
      Boolean(row.is_lab) ||
      row.subject.toLowerCase().includes("lab") ||
      row.subject.toLowerCase().includes("sessional") ||
      evenDigit;
    const isPhysicsLab =
      isLab &&
      (code.startsWith("PHY") ||
        row.subject.toLowerCase().includes("physics"));

    seen.set(
      code,
      toCatalogCourseWritePayload({
        code,
        title: row.subject.trim() || code,
        dept_code: deptCode,
        credit: isLab ? 1.5 : 3.0,
        class_type: isLab ? "lab" : "theory",
        is_service: Boolean(row.is_service),
        is_physics_lab: isPhysicsLab,
        default_weekly_sessions: null,
        is_active: true,
        notes: "Seeded from active published routine",
      }),
    );
  }

  return { toInsert: Array.from(seen.values()), skippedCount };
}

export async function seedCoursesFromActiveRoutine(
  routines: readonly RoutineRow[],
  existingCourses: readonly CatalogCourseRecord[],
  isDevPreview: boolean,
): Promise<{ insertedCount: number; skippedCount: number }> {
  const { toInsert, skippedCount } = buildCoursesHarvestFromRoutines(
    routines,
    existingCourses,
  );
  if (toInsert.length === 0) {
    return { insertedCount: 0, skippedCount };
  }

  if (isDevPreview || !isSupabaseConfigured || !supabase) {
    for (const item of toInsert) {
      await createCatalogCourse(item, true);
    }
    return { insertedCount: toInsert.length, skippedCount };
  }

  const { error } = await supabase.from("catalog_courses").insert(toInsert);
  if (error) {
    throw new Error(error.message);
  }

  return { insertedCount: toInsert.length, skippedCount };
}
