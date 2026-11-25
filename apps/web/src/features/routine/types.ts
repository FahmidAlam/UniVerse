export type AcademicDay =
  | "Sunday"
  | "Monday"
  | "Tuesday"
  | "Wednesday"
  | "Thursday"
  | "Friday"
  | "Saturday";

export type RoutineMatrixLens = "section" | "faculty" | "room";
export type RoutineMatrixViewMode = "matrix" | "committee" | "list";
export type RoutineDataSource = "live" | "candidate";

export interface RoutineRow {
  id: string;
  day: string;
  time_start: string;
  time_end: string;
  subject: string;
  subject_code: string;
  teacher_name: string | null;
  teacher_code: string | null;
  room: string;
  batch: string;
  section: string;
  semester: number;
  is_active: boolean;
  is_service: boolean;
  routine_version_id?: string | null;
  // Optional engine metadata present on candidate results / private drafts
  period?: number;
  oid?: number;
  teachers?: string[];
  teacher_state?: "assigned" | "pending";
  is_lab?: boolean;
}

export interface RoutineWriteInput {
  day: string;
  time_start: string;
  time_end: string;
  subject: string;
  subject_code: string;
  teacher_name?: string | null;
  teacher_code?: string | null;
  room: string;
  batch: string;
  section: string;
  semester: number;
  is_active: boolean;
  is_service: boolean;
  routine_version_id?: string | null;
}

export interface RoutineVersionRecord {
  id: string;
  semester_label: string | null;
  source: "engine" | "upload" | "manual";
  is_active: boolean;
  row_count: number;
  stats: Record<string, unknown>;
  validation: Record<string, unknown>;
  notes: string | null;
  published_at: string | null;
  published_by: string | null;
  created_at: string;
}

export interface RoutineClash {
  type: "teacher" | "room" | "cohort";
  message: string;
  conflictingRow: RoutineRow;
}

export interface BaselineConfigCounts {
  rooms: number;
  activeRooms: number;
  faculty: number;
  activeFaculty: number;
  eligibility: number;
  hasSettings: boolean;
}

export interface EngineConfigPayload {
  rooms: Array<{
    name: string;
    is_lab: boolean;
    is_gallery: boolean;
    capacity?: number;
  }>;
  teachers: Array<{
    acronym: string;
    full_name: string | null;
    dept: string | null;
    off_days: string[];
  }>;
  eligibility: Array<{
    acronym: string;
    course_code: string;
    eligible: boolean;
    priority: number | null;
  }>;
  days?: string[];
  room_aliases?: Record<string, string>;
  settings: {
    semester_label: string | null;
    periods: Array<{
      idx: number;
      label: string;
      start: string;
      end: string;
      col: string;
    }>;
    weeks_in_term: number;
    fixed_sessions_per_week?: number | null;
    blocked_periods: Record<string, number[]>;
    online_periods: number[];
    allow_online_periods: boolean;
    excluded_periods: number[];
    semester_map: Record<string, number>;
    friday_no_p4: boolean;
    service_scope: "resource_only" | "ignore";
    weights: {
      different_days: number;
      compactness: number;
      spread: number;
      late_slot: number;
    };
  };
}

export type EngineJobState =
  | "queued"
  | "ingesting"
  | "solving"
  | "rendering"
  | "done"
  | "failed";

export interface EngineSourceContract {
  source_sha256: string;
  revision: number;
  invalidated_artifacts: string[];
  source_id?: string;
  revision_id?: string;
  revision_number?: number;
  revision_version?: number;
}

export interface EngineStats {
  status: string;
  solve_ms: number;
  meetings: number;
  service_meetings: number;
  offerings: number;
  cohorts: number;
  teachers: number;
  objective: number;
  lab_theory_pairs: number;
  lab_theory_adjacent: number;
}

export interface EngineValidation {
  required_offerings?: number;
  scheduled_offerings?: number;
  missing_courses?: number;
  under_scheduled?: number;
  over_scheduled?: number;
  unexpected_courses?: number;
  teacher_clashes?: number;
  cohort_clashes?: number;
  room_clashes?: number;
  same_day_sessions?: number;
  ineligible_assignments?: number;
  dayoff_violations?: number;
  blocked_period_violations?: number;
  lab_room_violations?: number;
  unplaced_rooms?: number;
  lab_theory_violations?: number;
  invalid_time_slots?: number;
  invalid_days?: number;
  teacher_assignment_mismatches?: number;
  unknown_rooms?: number;
  room_capacity_violations?: number;
  unresolved_teachers?: number;
  pending_faculty_assignments?: number;
  same_day_rule?: "enforced" | "off";
  lab_theory_pairs?: number;
  lab_theory_adjacent?: number;
  details?: Record<string, Array<Record<string, unknown>>>;
  source_contract?: EngineSourceContract | null;
  ok: boolean;
  [key: string]: unknown;
}

export interface EngineReport {
  source_contract?: EngineSourceContract | null;
  cohorts: string[];
  meta: Record<string, unknown>;
  excluded: Array<Record<string, unknown>>;
  warnings: string[];
  offerings: Array<Record<string, unknown>>;
}

export interface EngineStatusResponse {
  job_id: string;
  state: EngineJobState;
  progress: number;
  stats?: EngineStats;
  validation?: EngineValidation;
  source_contract?: EngineSourceContract | null;
  error?: string;
}

export interface EngineResultResponse {
  job_id: string;
  rows: RoutineRow[];
  service_rows: RoutineRow[];
  stats: EngineStats;
  validation: EngineValidation;
  source_contract?: EngineSourceContract | null;
  report: EngineReport;
  has_workbook: boolean;
}

export interface RetryAuditParams {
  semesterLabel: string | null;
  filePath: string | null;
  stats: EngineStats;
  validation: EngineValidation;
  rowCount: number;
  createdBy: string | null;
}

export interface PublishPipelineResult {
  published: boolean;
  versionId: string;
  rowCount: number;
  filePath: string | null;
  secondaryAuditError: string | null;
  secondaryBroadcastError: string | null;
  retryAuditParams: RetryAuditParams | null;
}
