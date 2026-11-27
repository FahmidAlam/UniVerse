import { z } from "zod";
import { ACADEMIC_WEEK_DAYS } from "@/features/admin/services/facultyService";
import type { RoutineRow } from "@/features/routine/types";
import { isSupabaseConfigured, supabase } from "@/services/supabase";

export const SECTION_POLICIES_SELECT_COLUMNS =
  "id, cohort_id, student_group_id, batch, section, calendar_system, weekend_override_days, student_count, is_active, notes, created_at, updated_at";

export type CalendarSystem = "trimester" | "bi_semester";

export const CONSECUTIVE_WEEKEND_PAIRS: ReadonlyArray<
  readonly [string, string]
> = [
  ["Friday", "Saturday"],
  ["Saturday", "Sunday"],
  ["Sunday", "Monday"],
  ["Monday", "Tuesday"],
  ["Tuesday", "Wednesday"],
  ["Wednesday", "Thursday"],
  ["Thursday", "Friday"],
] as const;

export function isValidConsecutiveWeekendPair(
  days: readonly string[] | null | undefined,
): boolean {
  if (!days || days.length !== 2) return false;
  const idxA = ACADEMIC_WEEK_DAYS.indexOf(
    days[0] as (typeof ACADEMIC_WEEK_DAYS)[number],
  );
  const idxB = ACADEMIC_WEEK_DAYS.indexOf(
    days[1] as (typeof ACADEMIC_WEEK_DAYS)[number],
  );
  if (idxA === -1 || idxB === -1 || idxA === idxB) return false;
  const diff = (idxB - idxA + 7) % 7;
  return diff === 1 || diff === 6;
}

export interface SectionPolicyRecord {
  id: string;
  cohort_id: string | null;
  student_group_id: string | null;
  batch: string;
  section: string;
  calendar_system: CalendarSystem;
  weekend_override_days: string[] | null;
  student_count: number | null;
  is_active: boolean;
  notes: string | null;
  created_at: string;
  updated_at: string;
}

export interface SectionPolicyWriteInput {
  batch: string;
  section: string;
  calendar_system: CalendarSystem;
  weekend_override_days: string[] | null;
  student_count: number | null;
  is_active: boolean;
  notes?: string | null;
}

export interface SectionPolicyWritePayload {
  batch: string;
  section: string;
  calendar_system: CalendarSystem;
  weekend_override_days: string[] | null;
  student_count: number | null;
  is_active: boolean;
  notes: string | null;
}

export const sectionPolicyWriteSchema = z.object({
  batch: z.string().trim().min(1, "Batch is required.").max(30),
  section: z.string().trim().min(1, "Section is required.").max(30),
  calendar_system: z.enum(["trimester", "bi_semester"]),
  weekend_override_days: z
    .array(z.string())
    .nullable()
    .refine(
      (val) => val === null || isValidConsecutiveWeekendPair(val),
      "Weekend override must be 2 consecutive weekdays.",
    ),
  student_count: z
    .number()
    .int()
    .positive("Headcount must be positive.")
    .max(500)
    .nullable(),
  is_active: z.boolean(),
  notes: z.string().trim().max(400).nullable().optional(),
});

export function toSectionPolicyWritePayload(
  input: SectionPolicyWriteInput,
): SectionPolicyWritePayload {
  const parsed = sectionPolicyWriteSchema.parse({
    ...input,
    batch: input.batch.trim(),
    section: input.section.trim().toUpperCase(),
    weekend_override_days: input.weekend_override_days
      ? [...input.weekend_override_days]
      : null,
    notes: input.notes?.trim() ? input.notes.trim() : null,
  });

  return {
    batch: parsed.batch,
    section: parsed.section,
    calendar_system: parsed.calendar_system,
    weekend_override_days: parsed.weekend_override_days,
    student_count: parsed.student_count,
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

function normalizeSectionRow(raw: Record<string, unknown>): SectionPolicyRecord {
  const rawWeekend = Array.isArray(raw.weekend_override_days)
    ? raw.weekend_override_days.map((d) => String(d))
    : null;
  return {
    id: String(raw.id),
    cohort_id: raw.cohort_id ? String(raw.cohort_id) : null,
    student_group_id: raw.student_group_id ? String(raw.student_group_id) : null,
    batch: String(raw.batch ?? "").trim(),
    section: String(raw.section ?? "").trim().toUpperCase(),
    calendar_system:
      raw.calendar_system === "trimester" ? "trimester" : "bi_semester",
    weekend_override_days:
      rawWeekend && rawWeekend.length === 2 ? rawWeekend : null,
    student_count:
      typeof raw.student_count === "number" ? raw.student_count : null,
    is_active: raw.is_active !== false,
    notes: raw.notes ? String(raw.notes) : null,
    created_at: String(raw.created_at ?? new Date().toISOString()),
    updated_at: String(raw.updated_at ?? new Date().toISOString()),
  };
}

const devPreviewSectionsStore: SectionPolicyRecord[] = [
  {
    id: "preview-sec-1",
    cohort_id: null,
    student_group_id: null,
    batch: "61",
    section: "A",
    calendar_system: "bi_semester",
    weekend_override_days: ["Saturday", "Sunday"],
    student_count: 48,
    is_active: true,
    notes: "Staggered R1 override",
    created_at: "2026-11-20T00:00:00.000Z",
    updated_at: "2026-11-20T00:00:00.000Z",
  },
  {
    id: "preview-sec-2",
    cohort_id: null,
    student_group_id: null,
    batch: "58",
    section: "B+C",
    calendar_system: "trimester",
    weekend_override_days: null,
    student_count: 88,
    is_active: true,
    notes: null,
    created_at: "2026-11-20T00:00:00.000Z",
    updated_at: "2026-11-20T00:00:00.000Z",
  },
];

export async function fetchSectionPolicies(
  isDevPreview: boolean,
): Promise<{ live: boolean; sections: SectionPolicyRecord[] }> {
  if (isDevPreview || !isSupabaseConfigured || !supabase) {
    return {
      live: true,
      sections: [...devPreviewSectionsStore].sort(
        (a, b) =>
          a.batch.localeCompare(b.batch, undefined, { numeric: true }) ||
          a.section.localeCompare(b.section),
      ),
    };
  }

  const { data, error } = await supabase
    .from("section_policies")
    .select(SECTION_POLICIES_SELECT_COLUMNS)
    .order("batch")
    .order("section");

  if (error) {
    if (isMissingTableError(error)) {
      return { live: false, sections: [] };
    }
    throw new Error(error.message);
  }

  return {
    live: true,
    sections: ((data ?? []) as Record<string, unknown>[]).map(normalizeSectionRow),
  };
}

export async function createSectionPolicy(
  input: SectionPolicyWriteInput,
  isDevPreview: boolean,
): Promise<SectionPolicyRecord> {
  const payload = toSectionPolicyWritePayload(input);

  if (isDevPreview || !isSupabaseConfigured || !supabase) {
    const dup = devPreviewSectionsStore.some(
      (s) =>
        s.batch.toLowerCase() === payload.batch.toLowerCase() &&
        s.section.toLowerCase() === payload.section.toLowerCase(),
    );
    if (dup) {
      throw new Error(
        `Section "${payload.batch}-${payload.section}" already exists.`,
      );
    }
    const now = new Date().toISOString();
    const created: SectionPolicyRecord = {
      id: `preview-sec-${Date.now()}-${Math.floor(Math.random() * 1000)}`,
      cohort_id: null,
      student_group_id: null,
      ...payload,
      created_at: now,
      updated_at: now,
    };
    devPreviewSectionsStore.push(created);
    return created;
  }

  const { data, error } = await supabase
    .from("section_policies")
    .insert(payload)
    .select(SECTION_POLICIES_SELECT_COLUMNS)
    .single();

  if (error) {
    throw new Error(error.message);
  }

  return normalizeSectionRow(data as Record<string, unknown>);
}

export async function updateSectionPolicy(
  id: string,
  input: SectionPolicyWriteInput,
  isDevPreview: boolean,
): Promise<SectionPolicyRecord> {
  const payload = toSectionPolicyWritePayload(input);

  if (isDevPreview || !isSupabaseConfigured || !supabase) {
    const idx = devPreviewSectionsStore.findIndex((s) => s.id === id);
    if (idx === -1) throw new Error("Section policy record not found.");
    const updated: SectionPolicyRecord = {
      ...devPreviewSectionsStore[idx]!,
      ...payload,
      updated_at: new Date().toISOString(),
    };
    devPreviewSectionsStore[idx] = updated;
    return updated;
  }

  const { data, error } = await supabase
    .from("section_policies")
    .update(payload)
    .eq("id", id)
    .select(SECTION_POLICIES_SELECT_COLUMNS)
    .single();

  if (error) {
    throw new Error(error.message);
  }

  return normalizeSectionRow(data as Record<string, unknown>);
}

export async function bulkSetSectionPoliciesActive(
  ids: readonly string[],
  isActive: boolean,
  isDevPreview: boolean,
): Promise<void> {
  if (ids.length === 0) return;
  if (isDevPreview || !isSupabaseConfigured || !supabase) {
    for (const s of devPreviewSectionsStore) {
      if (ids.includes(s.id)) s.is_active = isActive;
    }
    return;
  }

  const { error } = await supabase
    .from("section_policies")
    .update({ is_active: isActive })
    .in("id", [...ids]);

  if (error) {
    throw new Error(error.message);
  }
}

export async function deleteSectionPolicies(
  ids: readonly string[],
  isDevPreview: boolean,
): Promise<void> {
  if (ids.length === 0) return;
  if (isDevPreview || !isSupabaseConfigured || !supabase) {
    for (let i = devPreviewSectionsStore.length - 1; i >= 0; i--) {
      if (ids.includes(devPreviewSectionsStore[i]!.id)) {
        devPreviewSectionsStore.splice(i, 1);
      }
    }
    return;
  }

  const { error } = await supabase
    .from("section_policies")
    .delete()
    .in("id", [...ids]);

  if (error) {
    throw new Error(error.message);
  }
}

export function buildSectionsHarvestFromRoutines(
  routines: readonly RoutineRow[],
  existingSections: readonly SectionPolicyRecord[],
): { toInsert: SectionPolicyWritePayload[]; skippedCount: number } {
  const existingKeys = new Set(
    existingSections.map(
      (s) => `${s.batch.trim().toUpperCase()}|${s.section.trim().toUpperCase()}`,
    ),
  );
  const seen = new Map<string, SectionPolicyWritePayload>();
  let skippedCount = 0;

  for (const row of routines) {
    if (row.is_active === false) continue;
    const batch = row.batch.trim();
    const section = (row.section.trim() || "A").toUpperCase();
    if (!batch) continue;
    const key = `${batch.toUpperCase()}|${section}`;
    if (existingKeys.has(key)) {
      skippedCount += 1;
      continue;
    }
    if (seen.has(key)) continue;

    seen.set(
      key,
      toSectionPolicyWritePayload({
        batch,
        section,
        calendar_system: "bi_semester",
        weekend_override_days: null,
        student_count: null,
        is_active: true,
        notes: "Seeded from active published routine",
      }),
    );
  }

  return { toInsert: Array.from(seen.values()), skippedCount };
}

export async function seedSectionsFromActiveRoutine(
  routines: readonly RoutineRow[],
  existingSections: readonly SectionPolicyRecord[],
  isDevPreview: boolean,
): Promise<{ insertedCount: number; skippedCount: number }> {
  const { toInsert, skippedCount } = buildSectionsHarvestFromRoutines(
    routines,
    existingSections,
  );
  if (toInsert.length === 0) {
    return { insertedCount: 0, skippedCount };
  }

  if (isDevPreview || !isSupabaseConfigured || !supabase) {
    for (const item of toInsert) {
      await createSectionPolicy(item, true);
    }
    return { insertedCount: toInsert.length, skippedCount };
  }

  const { error } = await supabase.from("section_policies").insert(toInsert);
  if (error) {
    throw new Error(error.message);
  }

  return { insertedCount: toInsert.length, skippedCount };
}
