import { isSupabaseConfigured, supabase } from "@/services/supabase";

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
  };
}

async function countTable(table: string): Promise<number> {
  if (!supabase) return 0;
  const { count, error } = await supabase
    .from(table)
    .select("*", { count: "exact", head: true });
  if (error) throw new Error(`${table}: ${error.message}`);
  return count ?? 0;
}

/**
 * Queries live production/staging Supabase counts matching `AdminService.counts()`
 * (`profiles`, `routines`, `notifications`, `timetable_rooms`, `timetable_course_eligibility`,
 * plus `timetable_faculty` and active `routine_versions`).
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
  ]);

  if (activeVerResp.error) {
    throw new Error(`routine_versions: ${activeVerResp.error.message}`);
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
  };
}
