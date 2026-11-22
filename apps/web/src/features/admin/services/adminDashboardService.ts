import { ACADEMIC_WEEK_DAYS } from "@/features/admin/services/facultyService";
import { isSupabaseConfigured, supabase } from "@/services/supabase";

export interface BatchLoadDatum {
  batch: string;
  slots: number;
}

export interface DailySlotLoadDatum {
  day: string;
  shortDay: string;
  slots: number;
}

export interface RoomCategoryDatum {
  category: string;
  active: number;
  inactive: number;
  total: number;
}

export interface AdminDashboardCounts {
  profiles: number;
  routines: number;
  notifications: number;
  timetableRooms: number;
  timetableFaculty: number;
  timetableCourseEligibility: number;
  activeVersionLabel: string | null;
  checkedAt: string;
  source: "supabase" | "dev-preview";
  batchLoadSummary: BatchLoadDatum[];
  roomCategorySummary: RoomCategoryDatum[];
  dailySlotLoadSummary?: DailySlotLoadDatum[];
  r7AdvisoryCount?: number;
}

export function getDevPreviewCounts(): AdminDashboardCounts {
  return {
    profiles: 148,
    routines: 796,
    notifications: 18,
    timetableRooms: 0,
    timetableFaculty: 0,
    timetableCourseEligibility: 0,
    activeVersionLabel: "Spring 2026 · v2026.2",
    checkedAt: new Date().toISOString(),
    source: "dev-preview",
    batchLoadSummary: [
      { batch: "Batch 56", slots: 92 },
      { batch: "Batch 57", slots: 114 },
      { batch: "Batch 58", slots: 138 },
      { batch: "Batch 59", slots: 142 },
      { batch: "Batch 60", slots: 156 },
      { batch: "Batch 61", slots: 154 },
    ],
    roomCategorySummary: [],
    dailySlotLoadSummary: [
      { day: "Sunday", shortDay: "Sun", slots: 138 },
      { day: "Monday", shortDay: "Mon", slots: 142 },
      { day: "Tuesday", shortDay: "Tue", slots: 134 },
      { day: "Wednesday", shortDay: "Wed", slots: 128 },
      { day: "Thursday", shortDay: "Thu", slots: 118 },
      { day: "Friday", shortDay: "Fri", slots: 48 },
      { day: "Saturday", shortDay: "Sat", slots: 88 },
    ],
    r7AdvisoryCount: 0,
  };
}

export function aggregateDailySlotLoad(
  rows: ReadonlyArray<{ day?: unknown; is_active?: unknown }>,
): DailySlotLoadDatum[] {
  const activeRows = rows.filter((r) => r.is_active !== false);
  if (activeRows.length === 0) return [];
  const counts = new Map<string, number>();
  for (const d of ACADEMIC_WEEK_DAYS) counts.set(d, 0);
  for (const row of activeRows) {
    if (typeof row.day === "string" && counts.has(row.day)) {
      counts.set(row.day, (counts.get(row.day) ?? 0) + 1);
    }
  }
  return ACADEMIC_WEEK_DAYS.map((day) => ({
    day,
    shortDay: day.slice(0, 3),
    slots: counts.get(day) ?? 0,
  }));
}

export function countR7Advisories(
  rows: ReadonlyArray<{ off_days?: unknown; is_active?: unknown }>,
): number {
  let count = 0;
  for (const r of rows) {
    if (r.is_active === false) continue;
    const offDays = Array.isArray(r.off_days) ? r.off_days : [];
    if (offDays.length < 2 || offDays.length > 3) {
      count += 1;
    }
  }
  return count;
}

async function countTable(table: string): Promise<number> {
  if (!supabase) return 0;
  const { count, error } = await supabase
    .from(table)
    .select("*", { count: "exact", head: true });
  if (error) throw new Error(`${table}: ${error.message}`);
  return count ?? 0;
}

export function aggregateBatchLoad(
  rows: ReadonlyArray<{ batch?: unknown; is_active?: unknown }>,
): BatchLoadDatum[] {
  const counts = new Map<string, number>();
  for (const row of rows) {
    if (row.is_active === false) continue;
    const rawBatch =
      typeof row.batch === "string" && row.batch.trim().length > 0
        ? row.batch.trim()
        : "Unassigned";
    counts.set(rawBatch, (counts.get(rawBatch) ?? 0) + 1);
  }
  return Array.from(counts.entries())
    .sort(([a], [b]) => a.localeCompare(b, undefined, { numeric: true }))
    .map(([batch, slots]) => ({ batch, slots }));
}

export function aggregateRoomCategories(
  rows: ReadonlyArray<{
    is_lab?: unknown;
    is_gallery?: unknown;
    is_active?: unknown;
  }>,
): RoomCategoryDatum[] {
  if (rows.length === 0) return [];
  const buckets: Record<"Theory Rooms" | "Labs" | "Galleries", RoomCategoryDatum> = {
    "Theory Rooms": { category: "Theory Rooms", active: 0, inactive: 0, total: 0 },
    Labs: { category: "Labs", active: 0, inactive: 0, total: 0 },
    Galleries: { category: "Galleries", active: 0, inactive: 0, total: 0 },
  };
  for (const r of rows) {
    const bucket = r.is_lab
      ? buckets.Labs
      : r.is_gallery
        ? buckets.Galleries
        : buckets["Theory Rooms"];
    if (r.is_active === false) {
      bucket.inactive += 1;
    } else {
      bucket.active += 1;
    }
    bucket.total += 1;
  }
  return [buckets["Theory Rooms"], buckets.Labs, buckets.Galleries];
}

/**
 * Queries live production/staging Supabase counts matching `AdminService.counts()`,
 * plus compact chart aggregates strictly derived from `routines` and `timetable_rooms`.
 */
export async function fetchAdminDashboardCounts(
  isDevPreview: boolean,
): Promise<AdminDashboardCounts> {
  if (isDevPreview || !isSupabaseConfigured || !supabase) {
    return getDevPreviewCounts();
  }

  const [
    profiles,
    routines,
    notifications,
    timetableRooms,
    timetableFaculty,
    timetableCourseEligibility,
    activeVerResp,
    routinesLoadResp,
    roomsSummaryResp,
    facultySummaryResp,
  ] = await Promise.all([
    countTable("profiles"),
    countTable("routines"),
    countTable("notifications"),
    countTable("timetable_rooms"),
    countTable("timetable_faculty"),
    countTable("timetable_course_eligibility"),
    supabase
      .from("routine_versions")
      .select("semester_label")
      .eq("is_active", true)
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle(),
    supabase.from("routines").select("batch, day, is_active").eq("is_active", true),
    supabase.from("timetable_rooms").select("is_lab, is_gallery, is_active"),
    supabase.from("timetable_faculty").select("off_days, is_active"),
  ]);

  if (activeVerResp.error) {
    throw new Error(`routine_versions: ${activeVerResp.error.message}`);
  }
  if (routinesLoadResp.error) {
    throw new Error(`routines: ${routinesLoadResp.error.message}`);
  }
  if (roomsSummaryResp.error) {
    throw new Error(`timetable_rooms: ${roomsSummaryResp.error.message}`);
  }
  if (facultySummaryResp.error) {
    throw new Error(`timetable_faculty: ${facultySummaryResp.error.message}`);
  }

  return {
    profiles,
    routines,
    notifications,
    timetableRooms,
    timetableFaculty,
    timetableCourseEligibility,
    activeVersionLabel:
      typeof activeVerResp.data?.semester_label === "string"
        ? activeVerResp.data.semester_label
        : null,
    checkedAt: new Date().toISOString(),
    source: "supabase",
    batchLoadSummary: aggregateBatchLoad(routinesLoadResp.data ?? []),
    roomCategorySummary: aggregateRoomCategories(roomsSummaryResp.data ?? []),
    dailySlotLoadSummary: aggregateDailySlotLoad(routinesLoadResp.data ?? []),
    r7AdvisoryCount: countR7Advisories(facultySummaryResp.data ?? []),
  };
}
