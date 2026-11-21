import { ClockTime } from "@/core/utils/clockTime";
import {
  ELIGIBILITY_SELECT_COLUMNS,
  fetchEligibilityRecords,
  type CourseEligibilityRecord,
} from "@/features/admin/services/eligibilityService";
import {
  FACULTY_SELECT_COLUMNS,
  fetchFaculty,
  type TimetableFacultyRecord,
} from "@/features/admin/services/facultyService";
import {
  fetchRooms,
  ROOM_SELECT_COLUMNS,
  type TimetableRoomRecord,
} from "@/features/admin/services/roomsService";
import {
  ensureSolverSafePeriods,
  fetchTimetableSettings,
  SETTINGS_SELECT_COLUMNS,
  type TimetableSettingsRecord,
} from "@/features/admin/services/settingsService";
import type {
  BaselineConfigCounts,
  EngineConfigPayload,
} from "@/features/routine/types";
import { isSupabaseConfigured, supabase } from "@/services/supabase";

export interface AssembledEngineConfig {
  config: EngineConfigPayload;
  configJson: string;
  baselineCounts: BaselineConfigCounts;
  settings: TimetableSettingsRecord;
}

/**
 * Pure assembly matching Flutter `TimetableConfigService.buildEngineConfig()`:
 * - Emits strictly baseline columns on active rooms and active faculty (zero Phase A non-DB keys)
 * - Normalizes `periods` via `ensureSolverSafePeriods` + `ClockTime.toHm` (`HH:MM` for `engine/render.py`)
 */
export function assembleEngineConfigFromRecords({
  rooms,
  faculty,
  eligibility,
  settings,
  hasSettings,
}: {
  rooms: readonly TimetableRoomRecord[];
  faculty: readonly TimetableFacultyRecord[];
  eligibility: readonly CourseEligibilityRecord[];
  settings: TimetableSettingsRecord;
  hasSettings: boolean;
}): AssembledEngineConfig {
  const activeRooms = rooms.filter((r) => r.is_active);
  const activeFaculty = faculty.filter((f) => f.is_active);

  const normalizedPeriods = ensureSolverSafePeriods(settings.periods).map(
    (p) => ({
      idx: p.idx,
      label: `${ClockTime.toHm(p.start)}-${ClockTime.toHm(p.end)}`,
      start: ClockTime.toHm(p.start),
      end: ClockTime.toHm(p.end),
      col: p.col,
    }),
  );

  const config: EngineConfigPayload = {
    rooms: activeRooms.map((r) => ({
      name: r.name,
      is_lab: r.is_lab,
      is_gallery: r.is_gallery,
      ...(r.capacity !== null && r.capacity !== undefined
        ? { capacity: r.capacity }
        : {}),
    })),
    teachers: activeFaculty.map((f) => ({
      acronym: f.acronym,
      full_name: f.full_name,
      dept: f.dept,
      off_days: [...f.off_days],
    })),
    eligibility: eligibility.map((e) => ({
      acronym: e.acronym,
      course_code: e.course_code,
      eligible: e.is_eligible,
      priority: e.priority,
    })),
    ...(settings.working_days.length > 0
      ? { days: [...settings.working_days] }
      : {}),
    settings: {
      semester_label: settings.semester_label,
      periods: normalizedPeriods,
      weeks_in_term: settings.weeks_in_term,
      ...(settings.fixed_sessions_per_week !== null &&
      settings.fixed_sessions_per_week > 0
        ? { fixed_sessions_per_week: settings.fixed_sessions_per_week }
        : {}),
      blocked_periods: settings.blocked_periods,
      online_periods: [...settings.online_periods],
      allow_online_periods: settings.allow_online_periods,
      excluded_periods: [...settings.excluded_periods],
      semester_map: { ...settings.semester_map },
      friday_no_p4: settings.friday_no_p4,
      service_scope: settings.service_scope,
      weights: { ...settings.weights },
    },
  };

  return {
    config,
    configJson: JSON.stringify(config),
    baselineCounts: {
      rooms: rooms.length,
      activeRooms: activeRooms.length,
      faculty: faculty.length,
      activeFaculty: activeFaculty.length,
      eligibility: eligibility.length,
      hasSettings,
    },
    settings,
  };
}

export async function fetchBaselineConfigAndBuild(
  isDevPreview: boolean,
): Promise<AssembledEngineConfig> {
  if (isDevPreview || !isSupabaseConfigured || !supabase) {
    const [rooms, faculty, eligibility, settings] = await Promise.all([
      fetchRooms(true),
      fetchFaculty(true),
      fetchEligibilityRecords(true),
      fetchTimetableSettings(true),
    ]);
    return assembleEngineConfigFromRecords({
      rooms,
      faculty,
      eligibility,
      settings,
      hasSettings: true,
    });
  }

  const [roomsResp, facultyResp, eligibilityResp, settingsResp, settingsObj] =
    await Promise.all([
      supabase
        .from("timetable_rooms")
        .select(ROOM_SELECT_COLUMNS)
        .order("is_lab", { ascending: false })
        .order("name"),
      supabase
        .from("timetable_faculty")
        .select(FACULTY_SELECT_COLUMNS)
        .order("acronym"),
      supabase
        .from("timetable_course_eligibility")
        .select(ELIGIBILITY_SELECT_COLUMNS)
        .order("acronym"),
      supabase
        .from("timetable_settings")
        .select(SETTINGS_SELECT_COLUMNS)
        .eq("id", 1)
        .maybeSingle(),
      fetchTimetableSettings(false),
    ]);

  if (roomsResp.error) throw new Error(`timetable_rooms: ${roomsResp.error.message}`);
  if (facultyResp.error) throw new Error(`timetable_faculty: ${facultyResp.error.message}`);
  if (eligibilityResp.error) {
    throw new Error(`timetable_course_eligibility: ${eligibilityResp.error.message}`);
  }
  if (settingsResp.error) {
    throw new Error(`timetable_settings: ${settingsResp.error.message}`);
  }

  return assembleEngineConfigFromRecords({
    rooms: (roomsResp.data ?? []) as TimetableRoomRecord[],
    faculty: ((facultyResp.data ?? []) as TimetableFacultyRecord[]).map((f) => ({
      ...f,
      off_days: Array.isArray(f.off_days) ? f.off_days : [],
      courses: Array.isArray(f.courses) ? f.courses : [],
    })),
    eligibility: (eligibilityResp.data ?? []) as CourseEligibilityRecord[],
    settings: settingsObj,
    hasSettings: settingsResp.data !== null,
  });
}
