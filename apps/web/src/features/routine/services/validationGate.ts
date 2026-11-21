import type {
  BaselineConfigCounts,
  EngineValidation,
  RoutineRow,
} from "@/features/routine/types";

export interface ValidationCounterDescriptor {
  key: keyof EngineValidation & string;
  label: string;
  formatProblem: (count: number) => string;
}

/**
 * Exact 20 blocking validation counters mirrored 1:1 from
 * `blockingValidationErrorFor` in `lib/features/admin/controllers/timetable_gen_controller.dart`.
 */
export const BLOCKING_VALIDATION_COUNTERS: readonly ValidationCounterDescriptor[] =
  [
    {
      key: "missing_courses",
      label: "Missing Courses",
      formatProblem: (n) => `${n} course(s) from the distribution are missing`,
    },
    {
      key: "under_scheduled",
      label: "Under-Scheduled",
      formatProblem: (n) =>
        `${n} course(s) have too few classes for their credit`,
    },
    {
      key: "over_scheduled",
      label: "Over-Scheduled",
      formatProblem: (n) => `${n} course(s) have too many classes`,
    },
    {
      key: "unexpected_courses",
      label: "Unexpected Courses",
      formatProblem: (n) => `${n} course(s) are not in the distribution`,
    },
    {
      key: "teacher_clashes",
      label: "Teacher Clashes",
      formatProblem: (n) => `${n} teacher clash(es)`,
    },
    {
      key: "cohort_clashes",
      label: "Cohort Clashes",
      formatProblem: (n) => `${n} section clash(es)`,
    },
    {
      key: "room_clashes",
      label: "Room Clashes",
      formatProblem: (n) => `${n} room clash(es)`,
    },
    {
      key: "same_day_sessions",
      label: "Same-Day Sessions",
      formatProblem: (n) =>
        `${n} course(s) scheduled twice on the same day`,
    },
    {
      key: "ineligible_assignments",
      label: "Ineligible Assignments",
      formatProblem: (n) =>
        `${n} class(es) assigned to a teacher who is not eligible for that course`,
    },
    {
      key: "dayoff_violations",
      label: "Day-Off Violations",
      formatProblem: (n) => `${n} class(es) on a day off`,
    },
    {
      key: "blocked_period_violations",
      label: "Blocked Period Violations",
      formatProblem: (n) => `${n} class(es) in a blocked period`,
    },
    {
      key: "lab_room_violations",
      label: "Lab Room Violations",
      formatProblem: (n) => `${n} lab(s) in a non-lab room`,
    },
    {
      key: "unplaced_rooms",
      label: "Unplaced Rooms (TBA)",
      formatProblem: (n) => `${n} class(es) with no room assigned`,
    },
    {
      key: "lab_theory_violations",
      label: "Lab–Theory Adjacency Violations",
      formatProblem: (n) =>
        `${n} lab(s) not adjacent to their theory class`,
    },
    {
      key: "invalid_time_slots",
      label: "Invalid Time Slots",
      formatProblem: (n) => `${n} class(es) at an unconfigured time`,
    },
    {
      key: "invalid_days",
      label: "Invalid Days",
      formatProblem: (n) => `${n} class(es) on a day that is not taught`,
    },
    {
      key: "teacher_assignment_mismatches",
      label: "Teacher Assignment Mismatches",
      formatProblem: (n) =>
        `${n} teacher assignment(s) differ from the distribution`,
    },
    {
      key: "unknown_rooms",
      label: "Unknown Rooms",
      formatProblem: (n) => `${n} class(es) use an unconfigured room`,
    },
    {
      key: "room_capacity_violations",
      label: "Room Capacity Violations",
      formatProblem: (n) => `${n} class(es) exceed known room capacity`,
    },
    {
      key: "unresolved_teachers",
      label: "Unresolved Teachers",
      formatProblem: (n) =>
        `${n} teacher assignment(s) need faculty verification`,
    },
  ] as const;

function readCounter(
  validation: Record<string, unknown>,
  key: string,
): number {
  const val = validation[key];
  return typeof val === "number" && Number.isFinite(val)
    ? Math.trunc(val)
    : 0;
}

export interface ValidationCounterInspection {
  key: string;
  label: string;
  count: number;
  summary: string;
  details: Array<Record<string, unknown>>;
}

export function inspectValidationCounters(
  validation: EngineValidation | Record<string, unknown> | null | undefined,
): ValidationCounterInspection[] {
  if (!validation) return [];
  const detailsMap =
    validation.details && typeof validation.details === "object"
      ? (validation.details as Record<string, Array<Record<string, unknown>>>)
      : {};

  return BLOCKING_VALIDATION_COUNTERS.map((desc) => {
    const count = readCounter(validation, desc.key);
    const rawDetails = detailsMap[desc.key];
    return {
      key: desc.key,
      label: desc.label,
      count,
      summary: desc.formatProblem(count),
      details: Array.isArray(rawDetails) ? rawDetails : [],
    };
  });
}

export function blockingValidationErrorFor(
  validation: EngineValidation | Record<string, unknown> | null | undefined,
): string | null {
  if (!validation || typeof validation.ok !== "boolean") {
    return "Validation is missing or incomplete. Review the routine before publishing.";
  }

  const problems: string[] = [];
  for (const desc of BLOCKING_VALIDATION_COUNTERS) {
    const count = readCounter(validation, desc.key);
    if (count > 0) {
      problems.push(desc.formatProblem(count));
    }
  }

  if (problems.length === 0) {
    if (validation.ok === false) {
      return "The engine reported this routine as invalid. Open the validation details, fix the cause, and generate again.";
    }
    return null;
  }

  return `This routine does not match the distribution: ${problems.join(", ")}. Fix the distribution or the settings and generate again.`;
}

/**
 * Exact parity with `RoutineEntry.requiresSharedTeacherStorage` (`lib/core/models/routine_model.dart`).
 * `public.routines` persists only a single scalar `teacher_code` column (`F-22`).
 */
export function extractRowTeacherCodes(
  row: Pick<RoutineRow, "teacher_code" | "teachers">,
): string[] {
  const scalar = row.teacher_code?.trim();
  const list = (row.teachers ?? [])
    .map((c) => c.trim())
    .filter((c) => c.length > 0);
  return Array.from(
    new Set([...(scalar ? [scalar] : []), ...list]),
  );
}

export function requiresSharedTeacherStorage(
  row: Pick<RoutineRow, "teacher_code" | "teachers">,
): boolean {
  const scalar = row.teacher_code?.trim() ?? "";
  const codes = extractRowTeacherCodes(row);
  if (codes.length > 1) return true;
  return codes.some((code) => code !== scalar);
}

export function findCoTeacherBlockers(
  rows: readonly RoutineRow[],
  serviceRows: readonly RoutineRow[] = [],
): RoutineRow[] {
  return [...rows, ...serviceRows].filter((row) =>
    requiresSharedTeacherStorage(row),
  );
}

export interface EmptyConfigAssessment {
  blockingReasons: string[];
  warnings: string[];
  canPublish: boolean;
}

/**
 * Empty-Config Pre-Publish Guard (`F-20`): prevents publishing an unconstrained
 * routine over live schedules when baseline tables are empty.
 */
export function assessBaselineConfigForPublish(
  counts: BaselineConfigCounts | null | undefined,
): EmptyConfigAssessment {
  if (!counts) {
    return {
      blockingReasons: [
        "Baseline room, faculty, and settings counts have not been verified yet.",
      ],
      warnings: [],
      canPublish: false,
    };
  }

  const blockingReasons: string[] = [];
  const warnings: string[] = [];

  if (counts.activeRooms === 0) {
    blockingReasons.push(
      counts.rooms === 0
        ? "0 rooms configured in Room Pools."
        : "0 active rooms enabled in Room Pools.",
    );
  }
  if (counts.activeFaculty === 0) {
    blockingReasons.push(
      counts.faculty === 0
        ? "0 faculty members configured in the Faculty roster."
        : "0 active faculty members enabled in the Faculty roster.",
    );
  }
  if (!counts.hasSettings) {
    blockingReasons.push("Timetable Settings have not been saved yet.");
  }
  if (counts.eligibility === 0) {
    warnings.push(
      "0 course eligibility rules configured; faculty qualification checks are relaxed until rules are added.",
    );
  }

  return {
    blockingReasons,
    warnings,
    canPublish: blockingReasons.length === 0,
  };
}
