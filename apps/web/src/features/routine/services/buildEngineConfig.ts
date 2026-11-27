import { ClockTime } from "@/core/utils/clockTime";
import {
  fetchSectionPolicies,
  type SectionPolicyRecord,
} from "@/features/admin/services/batchesService";
import {
  fetchCatalogCourses,
  type CatalogCourseRecord,
} from "@/features/admin/services/coursesService";
import {
  ELIGIBILITY_SELECT_COLUMNS,
  fetchEligibilityRecords,
  type CourseEligibilityRecord,
} from "@/features/admin/services/eligibilityService";
import {
  fetchFaculty,
  isFacultyExtendedSchemaLive,
  type TimetableFacultyRecord,
} from "@/features/admin/services/facultyService";
import {
  fetchRooms,
  isRoomExtendedSchemaLive,
  type TimetableRoomRecord,
} from "@/features/admin/services/roomsService";
import {
  ensureSolverSafePeriods,
  fetchTimetableSettings,
  SETTINGS_SELECT_COLUMNS,
  type TimetableSettingsRecord,
} from "@/features/admin/services/settingsService";
import {
  DEFAULT_POLICY_SNAPSHOT_FORM,
  readActivePolicySnapshot,
  type PolicySnapshotRecord,
} from "@/features/scheduling/services/policySnapshotService";
import type {
  BaselineConfigCounts,
  EngineConfigPayload,
  GateCPreflightSummary,
} from "@/features/routine/types";
import { isSupabaseConfigured, supabase } from "@/services/supabase";

export interface AssembledEngineConfig {
  config: EngineConfigPayload;
  configJson: string;
  baselineCounts: BaselineConfigCounts;
  gateCSummary: GateCPreflightSummary;
  settings: TimetableSettingsRecord;
}

/**
 * Pure assembly matching Flutter `TimetableConfigService.buildEngineConfig()`:
 * - Emits strictly baseline columns when `includeGateCFields` is omitted/false
 *   (ensuring 100% pre-migration backward compatibility).
 * - When `includeGateCFields` is true, forwards Stage 5A extended fields +
 *   optional `policySnapshot`, `sectionPolicies`, and `catalogCourses`.
 * - Normalizes `periods` via `ensureSolverSafePeriods` + `ClockTime.toHm`.
 */
export function assembleEngineConfigFromRecords({
  rooms,
  faculty,
  eligibility,
  settings,
  hasSettings,
  includeGateCFields = false,
  policySnapshot = null,
  sectionPolicies = [],
  catalogCourses = [],
}: {
  rooms: readonly TimetableRoomRecord[];
  faculty: readonly TimetableFacultyRecord[];
  eligibility: readonly CourseEligibilityRecord[];
  settings: TimetableSettingsRecord;
  hasSettings: boolean;
  includeGateCFields?: boolean;
  policySnapshot?: PolicySnapshotRecord | null;
  sectionPolicies?: readonly SectionPolicyRecord[];
  catalogCourses?: readonly CatalogCourseRecord[];
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

  const activeSectionOverrides = sectionPolicies
    .filter(
      (s) =>
        s.is_active &&
        Array.isArray(s.weekend_override_days) &&
        s.weekend_override_days.length === 2,
    )
    .map((s) => ({
      batch: s.batch,
      section: s.section,
      weekend_days: s.weekend_override_days!,
      calendar_system: s.calendar_system,
    }));

  const mergedPhysicsCodes = Array.from(
    new Set([
      ...(policySnapshot?.physics_lab_course_codes ?? []).map((c) =>
        c.trim().toUpperCase(),
      ),
      ...catalogCourses
        .filter((c) => c.is_active && c.is_physics_lab)
        .map((c) => c.code.trim().toUpperCase()),
    ].filter(Boolean)),
  ).sort();

  const config: EngineConfigPayload = {
    rooms: activeRooms.map((r) => ({
      name: r.name,
      is_lab: r.is_lab,
      is_gallery: r.is_gallery,
      ...(r.capacity !== null && r.capacity !== undefined
        ? { capacity: r.capacity }
        : {}),
      ...(includeGateCFields
        ? {
            room_pool_role: r.room_pool_role ?? "general",
            available_slots: [...(r.available_slots ?? [])],
          }
        : {}),
    })),
    teachers: activeFaculty.map((f) => ({
      acronym: f.acronym,
      full_name: f.full_name,
      dept: f.dept,
      off_days: [...f.off_days],
      ...(includeGateCFields
        ? {
            employment_type: f.employment_type ?? "permanent",
            allow_three_off_days: Boolean(f.allow_three_off_days),
            is_sust_adjunct: Boolean(f.is_sust_adjunct),
            external_blocked_slots: [...(f.external_blocked_slots ?? [])],
            available_slots: [...(f.available_slots ?? [])],
            preferred_slots: [...(f.preferred_slots ?? [])],
          }
        : {}),
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
    ...(includeGateCFields && policySnapshot
      ? {
          policy_snapshot: {
            ...policySnapshot.policy_payload,
            schema_version: policySnapshot.schema_version ?? 1,
            default_section_weekend: policySnapshot.default_section_weekend,
            section_weekend_overrides: activeSectionOverrides,
            batch_max_off_day_spread: policySnapshot.batch_max_off_day_spread,
            max_section_internal_gap: policySnapshot.max_section_internal_gap,
            allow_sessional_across_break:
              policySnapshot.allow_sessional_across_break,
            physics_lab_course_codes: mergedPhysicsCodes,
          },
        }
      : {}),
    ...(includeGateCFields && sectionPolicies.length > 0
      ? {
          sections: sectionPolicies
            .filter((s) => s.is_active)
            .map((s) => ({
              batch: s.batch,
              section: s.section,
              calendar_system: s.calendar_system,
              weekend_override_days: s.weekend_override_days,
              student_count: s.student_count,
            })),
        }
      : {}),
    ...(includeGateCFields && catalogCourses.length > 0
      ? {
          courses: catalogCourses
            .filter((c) => c.is_active)
            .map((c) => ({
              code: c.code,
              title: c.title,
              dept_code: c.dept_code,
              credit: c.credit,
              class_type: c.class_type,
              is_service: c.is_service,
              is_physics_lab: c.is_physics_lab,
              default_weekly_sessions: c.default_weekly_sessions,
              notes: c.notes,
            })),
        }
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

  const gateCSummary: GateCPreflightSummary = {
    policySnapshotActive: Boolean(includeGateCFields && policySnapshot),
    policyLabel: policySnapshot?.label ?? null,
    policyHash: policySnapshot?.policy_hash ?? null,
    defaultSectionWeekend: policySnapshot?.default_section_weekend ?? [
      "Friday",
      "Saturday",
    ],
    sectionOverrideCount: activeSectionOverrides.length,
    allowSessionalAcrossBreak: Boolean(
      policySnapshot?.allow_sessional_across_break,
    ),
    physicsLabCourseCount: mergedPhysicsCodes.length,
    catalogCoursesCount: catalogCourses.filter((c) => c.is_active).length,
    sectionPoliciesCount: sectionPolicies.filter((s) => s.is_active).length,
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
    gateCSummary,
    settings,
  };
}

export async function fetchBaselineConfigAndBuild(
  isDevPreview: boolean,
): Promise<AssembledEngineConfig> {
  if (isDevPreview || !isSupabaseConfigured || !supabase) {
    const [rooms, faculty, eligibility, settings, coursesRes, sectionsRes] =
      await Promise.all([
        fetchRooms(true),
        fetchFaculty(true),
        fetchEligibilityRecords(true),
        fetchTimetableSettings(true),
        fetchCatalogCourses(true),
        fetchSectionPolicies(true),
      ]);
    const previewSnapshot: PolicySnapshotRecord = {
      id: "preview-policy-snapshot",
      scheduling_scope_id: null,
      revision_id: null,
      label: DEFAULT_POLICY_SNAPSHOT_FORM.label,
      version: 1,
      is_active: true,
      schema_version: 1,
      default_section_weekend: DEFAULT_POLICY_SNAPSHOT_FORM.defaultSectionWeekend,
      batch_max_off_day_spread: DEFAULT_POLICY_SNAPSHOT_FORM.batchMaxOffDaySpread,
      max_section_internal_gap: DEFAULT_POLICY_SNAPSHOT_FORM.maxSectionInternalGap,
      allow_sessional_across_break:
        DEFAULT_POLICY_SNAPSHOT_FORM.allowSessionalAcrossBreak,
      physics_lab_course_codes:
        DEFAULT_POLICY_SNAPSHOT_FORM.physicsLabCourseCodes,
      policy_payload: DEFAULT_POLICY_SNAPSHOT_FORM.policyPayload,
      policy_hash: "dev-preview-policy",
      created_by: null,
      created_at: new Date().toISOString(),
    };
    return assembleEngineConfigFromRecords({
      rooms,
      faculty,
      eligibility,
      settings,
      hasSettings: true,
      includeGateCFields: true,
      policySnapshot: previewSnapshot,
      sectionPolicies: sectionsRes.sections,
      catalogCourses: coursesRes.courses,
    });
  }

  const [
    rooms,
    faculty,
    eligibilityResp,
    settingsResp,
    settingsObj,
    facultyExt,
    roomsExt,
    coursesRes,
    sectionsRes,
    policySnap,
  ] = await Promise.all([
    fetchRooms(false),
    fetchFaculty(false),
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
    isFacultyExtendedSchemaLive(false).catch(() => false),
    isRoomExtendedSchemaLive(false).catch(() => false),
    fetchCatalogCourses(false).catch(() => ({ live: false, courses: [] })),
    fetchSectionPolicies(false).catch(() => ({ live: false, sections: [] })),
    readActivePolicySnapshot({}).catch(() => null),
  ]);

  if (eligibilityResp.error) {
    throw new Error(
      `timetable_course_eligibility: ${eligibilityResp.error.message}`,
    );
  }
  if (settingsResp.error) {
    throw new Error(`timetable_settings: ${settingsResp.error.message}`);
  }

  return assembleEngineConfigFromRecords({
    rooms,
    faculty,
    eligibility: (eligibilityResp.data ?? []) as CourseEligibilityRecord[],
    settings: settingsObj,
    hasSettings: settingsResp.data !== null,
    includeGateCFields: facultyExt || roomsExt || Boolean(policySnap),
    policySnapshot: policySnap,
    sectionPolicies: sectionsRes.sections,
    catalogCourses: coursesRes.courses,
  });
}
