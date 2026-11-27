export type CapabilityStatus =
  | "live-persisted"
  | "read-only"
  | "staged-no-db"
  | "fail-closed-gate";

export type CapabilityGroup =
  | "operations"
  | "configuration"
  | "directory";

export type CapabilityIconKey =
  | "dashboard"
  | "routine"
  | "matrix"
  | "workbench"
  | "courses"
  | "batches"
  | "rooms"
  | "faculty"
  | "eligibility"
  | "settings"
  | "broadcast"
  | "users"
  | "resources"
  | "profile";

export interface CapabilityDescriptor {
  id: string;
  path: string;
  label: string;
  pageTitle: string;
  group: CapabilityGroup;
  iconKey: CapabilityIconKey;
  status: CapabilityStatus;
  implementedInPhase1A: boolean;
  plannedPhaseLabel: string;
  sidebarBadge?: "LOCKED" | "STAGED" | "GATED" | "READ-ONLY";
  summary: string;
  governanceNote: string;
  /** Internal architectural contract reference for engineering verification (not UI wallpaper). */
  backendContract: string;
}

export const CAPABILITY_REGISTRY: readonly CapabilityDescriptor[] = [
  {
    id: "admin.dashboard",
    path: "/admin/dashboard",
    label: "Dashboard",
    pageTitle: "Routine Command Center",
    group: "operations",
    iconKey: "dashboard",
    status: "live-persisted",
    implementedInPhase1A: true,
    plannedPhaseLabel: "Phase 1A Active",
    summary:
      "Live departmental readiness checklist, active published slot counts, and engine availability.",
    governanceNote: "Verified live database readiness & engine status view.",
    backendContract:
      "GET /, profiles, routines, notifications, timetable_rooms, timetable_faculty, timetable_course_eligibility, routine_versions",
  },
  {
    id: "admin.routine",
    path: "/admin/routine",
    label: "Routine Operations",
    pageTitle: "Routine Operations",
    group: "operations",
    iconKey: "routine",
    status: "live-persisted",
    implementedInPhase1A: false,
    plannedPhaseLabel: "Phase 3B Active",
    summary:
      "Manage published timetable slots, inspect the 2D weekly matrix, upload rendered .xlsx routines, inspect historical archives, and launch CP-SAT schedule generation.",
    governanceNote:
      "Track 1 operational console active with Phase 3B rendered .xlsx upload and Archive v2a 2D grid preview.",
    backendContract:
      "POST /api/timetable/generate, POST /api/timetable/parse-rendered-workbook, GET /api/timetable/status|result|download/{job_id}, RPC publish_routine, storage bucket timetables",
  },
  {
    id: "admin.routine-grid",
    path: "/admin/timetable/grid",
    label: "Routine Matrix",
    pageTitle: "Operational Routine Matrix",
    group: "operations",
    iconKey: "matrix",
    status: "read-only",
    implementedInPhase1A: false,
    plannedPhaseLabel: "Phase 3A Active · Inspector",
    summary:
      "Full-canvas 2D weekly routine grid filterable by batch section, faculty acronym, and room.",
    governanceNote: "Interactive 2D matrix over published or candidate semester allocations.",
    backendContract: "routines, routine_versions",
  },
  {
    id: "admin.scheduling",
    path: "/admin/scheduling",
    label: "Workbench",
    pageTitle: "5-Stage Scheduling Workbench",
    group: "operations",
    iconKey: "workbench",
    status: "fail-closed-gate",
    implementedInPhase1A: false,
    plannedPhaseLabel: "Phase 4B · Track 2 Workbench",
    sidebarBadge: "GATED",
    summary:
      "5-stage committee workbook distribution ledger, R1–R16 policy studio, preflight readiness, CP-SAT solve, and candidate diff/publish workbench (live mode gated per Gate A–D; Design Preview available).",
    governanceNote: "Fail-closed in live mode until Track 2 Gates A–D verify cleanly.",
    backendContract:
      "course_distribution_sources, course_distribution_revisions(revision_version), RPC read_course_distribution_revision, RPC append_course_distribution_correction",
  },
  {
    id: "admin.rooms",
    path: "/admin/timetable/rooms",
    label: "Room Pools",
    pageTitle: "Room & Lab Pools",
    group: "configuration",
    iconKey: "rooms",
    status: "live-persisted",
    implementedInPhase1A: false,
    plannedPhaseLabel: "Configuration Phase",
    summary:
      "Manage active lecture rooms, gallery halls, computer labs, capacities, and campus building tags.",
    governanceNote: "Backed by persisted institutional room inventory.",
    backendContract: "timetable_rooms (live baseline columns)",
  },
  {
    id: "admin.faculty",
    path: "/admin/timetable/faculty",
    label: "Faculty",
    pageTitle: "Faculty & Off-Day Bounds",
    group: "configuration",
    iconKey: "faculty",
    status: "live-persisted",
    implementedInPhase1A: false,
    plannedPhaseLabel: "Configuration Phase",
    summary:
      "Maintain instructor acronyms, designations, permanent weekly off-days, and active teaching status.",
    governanceNote: "Backed by persisted faculty roster & R7 rules.",
    backendContract: "timetable_faculty (live baseline columns)",
  },
  {
    id: "admin.course-eligibility",
    path: "/admin/timetable/course-eligibility",
    label: "Course Eligibility",
    pageTitle: "Course Eligibility Matrix",
    group: "configuration",
    iconKey: "eligibility",
    status: "live-persisted",
    implementedInPhase1A: false,
    plannedPhaseLabel: "Configuration Phase",
    summary:
      "Bind qualified instructors to courses with assignment priority order prior to solver execution.",
    governanceNote: "Required before automated schedule publication.",
    backendContract: "timetable_course_eligibility",
  },
  {
    id: "admin.settings",
    path: "/admin/timetable/settings",
    label: "Timetable Settings",
    pageTitle: "Timetable Settings",
    group: "configuration",
    iconKey: "settings",
    status: "live-persisted",
    implementedInPhase1A: false,
    plannedPhaseLabel: "Configuration Phase",
    summary:
      "Configure working days, period durations, 6-slot vs 7-slot regular daily clocks, optional online slot, and Friday prayer blocks.",
    governanceNote: "Departmental scheduling policy baseline.",
    backendContract: "timetable_settings (singleton)",
  },
  {
    id: "admin.courses",
    path: "/admin/timetable/courses",
    label: "Courses",
    pageTitle: "Courses Catalog",
    group: "configuration",
    iconKey: "courses",
    status: "staged-no-db",
    implementedInPhase1A: false,
    plannedPhaseLabel: "Catalog Pending Schema",
    sidebarBadge: "STAGED",
    summary:
      "Course catalog management is staged without database writes until institutional catalog storage is promoted to production.",
    governanceNote: "Staged preview — writes disabled to avoid silent data loss.",
    backendContract: "Pending canonical course catalog persistence",
  },
  {
    id: "admin.batches",
    path: "/admin/timetable/batches",
    label: "Batches & Sections",
    pageTitle: "Batches & Sections",
    group: "configuration",
    iconKey: "batches",
    status: "staged-no-db",
    implementedInPhase1A: false,
    plannedPhaseLabel: "Catalog Pending Schema",
    sidebarBadge: "STAGED",
    summary:
      "Cohort, section, and joint offering management remains staged without persistence until academic grouping tables are enabled in production.",
    governanceNote: "Staged preview — writes disabled to avoid silent data loss.",
    backendContract: "Pending canonical cohort & student group persistence",
  },
  {
    id: "admin.broadcast",
    path: "/admin/broadcast",
    label: "Campus Broadcast",
    pageTitle: "Campus Broadcasts",
    group: "directory",
    iconKey: "broadcast",
    status: "live-persisted",
    implementedInPhase1A: false,
    plannedPhaseLabel: "Directory & Alerts Phase",
    summary:
      "Compose targeted notices to student cohorts or faculty and review previously sent campus announcements.",
    governanceNote: "Delivers push alerts via mobile notifications.",
    backendContract: "notifications",
  },
  {
    id: "admin.users",
    path: "/admin/users",
    label: "User Whitelist",
    pageTitle: "Authorized Users & Invites",
    group: "directory",
    iconKey: "users",
    status: "live-persisted",
    implementedInPhase1A: false,
    plannedPhaseLabel: "Directory & Alerts Phase",
    summary:
      "Review registered accounts, manage approved departmental emails, and issue committee administrator invitations.",
    governanceNote: "Server-verified committee invitation workflow.",
    backendContract: "profiles, whitelists, Edge Function invite-admin",
  },
  {
    id: "admin.resources",
    path: "/admin/resources",
    label: "Academic Resources",
    pageTitle: "Academic Resources",
    group: "directory",
    iconKey: "resources",
    status: "live-persisted",
    implementedInPhase1A: false,
    plannedPhaseLabel: "Directory & Alerts Phase",
    summary:
      "Upload official semester syllabi, calendars, and student reference materials for mobile access.",
    governanceNote: "Published directly to student and teacher apps.",
    backendContract: "resources, storage bucket resources",
  },
  {
    id: "admin.profile",
    path: "/admin/profile",
    label: "My Profile",
    pageTitle: "Administrator Profile",
    group: "directory",
    iconKey: "profile",
    status: "live-persisted",
    implementedInPhase1A: false,
    plannedPhaseLabel: "Sub-Phase 2B Live Profile",
    summary:
      "Inspect your administrator account metadata and update permitted departmental profile details.",
    governanceNote: "Editable own profile record (excluding avatar uploads).",
    backendContract: "profiles (own row)",
  },
] as const;

export interface SecondaryFeatureCapability {
  id: string;
  label: string;
  status: CapabilityStatus;
  badgeLabel?: string;
  summary: string;
}

export const SUBFEATURE_CAPABILITIES: readonly SecondaryFeatureCapability[] = [
  {
    id: "track1.workbook-upload",
    label: "Rendered Routine Upload",
    status: "live-persisted",
    summary:
      "Parse, validate, preview in 2D, and publish pre-rendered Excel routine workbooks via Phase 3B server parser.",
  },
  {
    id: "track2.course-distribution",
    label: "5-Stage Scheduling Workbench",
    status: "fail-closed-gate",
    summary: "Fail-closed behind governance Gates A–D.",
  },
  {
    id: "catalog.courses-batches",
    label: "Courses & Batches Catalog",
    status: "staged-no-db",
    summary: "Staged without database persistence until catalog approval.",
  },
  {
    id: "solver.co-teacher-guard",
    label: "Single-Teacher Publication Guard",
    status: "live-persisted",
    summary: "Co-teacher conflicts are blocked prior to semester publish.",
  },
] as const;

export const CAPABILITY_GROUP_LABELS: Record<CapabilityGroup, string> = {
  operations: "Operations",
  configuration: "Configuration",
  directory: "Directory & Alerts",
};

import type { SchedulingGateState } from "@/features/scheduling/types";

export function getCapabilityByPath(path: string): CapabilityDescriptor | undefined {
  return CAPABILITY_REGISTRY.find((cap) => cap.path === path);
}

export function getCapabilityById(id: string): CapabilityDescriptor | undefined {
  return CAPABILITY_REGISTRY.find((cap) => cap.id === id);
}

export function getCapabilitiesByGroup(group: CapabilityGroup): CapabilityDescriptor[] {
  return CAPABILITY_REGISTRY.filter((cap) => cap.group === group);
}

/**
 * Resolves live Stage 5A catalog unlocks dynamically without mutating the static
 * fail-closed defaults in `CAPABILITY_REGISTRY`.
 */
export function resolveLiveCapabilityDescriptor(
  cap: CapabilityDescriptor,
  gates?: SchedulingGateState | null,
): CapabilityDescriptor {
  if (!gates) return cap;
  if (cap.id === "admin.courses" && gates.catalogs?.coursesLive) {
    return {
      ...cap,
      status: "live-persisted",
      sidebarBadge: undefined,
      plannedPhaseLabel: "Stage 5A Active",
      summary:
        "Manage persistent institutional courses, credits, service flags, R11 Physics Lab tags, and default weekly session counts.",
      governanceNote: "Backed by persisted public.catalog_courses.",
      backendContract: "public.catalog_courses",
    };
  }
  if (cap.id === "admin.batches" && gates.catalogs?.batchesLive) {
    return {
      ...cap,
      status: "live-persisted",
      sidebarBadge: undefined,
      plannedPhaseLabel: "Stage 5A Active",
      summary:
        "Manage cohort batches, sections, calendar systems, headcounts, and R1 consecutive 2-day weekend overrides.",
      governanceNote: "Backed by persisted public.section_policies.",
      backendContract: "public.section_policies",
    };
  }
  return cap;
}

export function formatCapabilityStatusLabel(status: CapabilityStatus): string {
  switch (status) {
    case "live-persisted":
      return "Live Persisted";
    case "read-only":
      return "Read Only";
    case "staged-no-db":
      return "Staged · No DB";
    case "fail-closed-gate":
      return "Locked · Gates A–D";
  }
}
