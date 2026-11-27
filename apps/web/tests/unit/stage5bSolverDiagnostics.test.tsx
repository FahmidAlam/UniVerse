import { cleanup, render, screen } from "@testing-library/react";
import { MemoryRouter } from "react-router-dom";
import { afterEach, describe, expect, it, vi } from "vitest";
import { getDefaultSettings } from "@/features/admin/services/settingsService";
import { SolverDiagnosticsPanel } from "@/features/routine/components/SolverDiagnosticsPanel";
import { assembleEngineConfigFromRecords } from "@/features/routine/services/buildEngineConfig";
import {
  EngineJobError,
  extractOutcomeDiagnostics,
  runResilientJobPolling,
} from "@/features/routine/services/timetableEngineService";
import {
  blockingValidationErrorFor,
  inspectPolicyViolations,
} from "@/features/routine/services/validationGate";
import type {
  EngineStatusResponse,
  SolverOutcomeDiagnostics,
  SolverOutcomeStatus,
} from "@/features/routine/types";

afterEach(() => {
  cleanup();
  vi.restoreAllMocks();
});

describe("Stage 5B buildEngineConfig Gate C policy assembly", () => {
  it("merges authoritative Gate C policy_snapshot, section overrides, and physics lab codes", () => {
    type AssemblyInput = Parameters<typeof assembleEngineConfigFromRecords>[0];

    const input: AssemblyInput = {
      settings: getDefaultSettings(),
      hasSettings: true,
      rooms: [
        {
          id: "room-1",
          name: "RAB-301",
          building: "Academic Building",
          is_lab: false,
          is_gallery: false,
          capacity: 60,
          is_active: true,
          dept: "CSE",
          room_pool_role: "general",
          available_slots: [],
        },
      ],
      faculty: [
        {
          id: "fac-1",
          acronym: "TFA",
          full_name: "Dr. Faculty A",
          dept: "CSE",
          designation: "Assistant Professor",
          off_days: ["Friday", "Saturday"],
          is_active: true,
          courses: ["PHY-1102"],
          employment_type: "permanent",
          allow_three_off_days: false,
          is_sust_adjunct: false,
          external_blocked_slots: [],
          available_slots: [],
          preferred_slots: [],
        },
      ],
      eligibility: [
        {
          id: "elig-1",
          acronym: "TFA",
          course_code: "PHY-1102",
          is_eligible: true,
          priority: 1,
          created_at: "2026-11-26T00:00:00Z",
          updated_at: "2026-11-26T00:00:00Z",
        },
      ],
      catalogCourses: [
        {
          id: "course-1",
          code: "PHY-1102",
          title: "Physics Lab",
          department_id: null,
          dept_code: "PHY",
          credit: 1.5,
          class_type: "lab",
          is_service: true,
          is_physics_lab: true,
          default_weekly_sessions: null,
          is_active: true,
          notes: null,
          created_at: "2026-11-26T00:00:00Z",
          updated_at: "2026-11-26T00:00:00Z",
        },
        {
          id: "course-2",
          code: "CSE-9999",
          title: "Retired Physics Lab",
          department_id: null,
          dept_code: "CSE",
          credit: 1.5,
          class_type: "lab",
          is_service: false,
          is_physics_lab: true,
          default_weekly_sessions: null,
          is_active: false,
          notes: null,
          created_at: "2026-11-26T00:00:00Z",
          updated_at: "2026-11-26T00:00:00Z",
        },
      ],
      sectionPolicies: [
        {
          id: "sec-1",
          cohort_id: null,
          student_group_id: null,
          batch: "58",
          section: "B",
          calendar_system: "trimester",
          weekend_override_days: ["Sunday", "Monday"],
          student_count: 40,
          is_active: true,
          notes: null,
          created_at: "2026-11-26T00:00:00Z",
          updated_at: "2026-11-26T00:00:00Z",
        },
      ],
      policySnapshot: {
        id: "snap-10",
        scheduling_scope_id: null,
        revision_id: null,
        label: "Committee Baseline 2026",
        version: 1,
        schema_version: 2,
        is_active: true,
        default_section_weekend: ["Friday", "Saturday"],
        batch_max_off_day_spread: 1,
        max_section_internal_gap: 1,
        allow_sessional_across_break: false,
        physics_lab_course_codes: ["PHY-1202"],
        policy_hash: "hash-stage5b",
        created_by: null,
        created_at: "2026-11-26T00:00:00Z",
        policy_payload: {
          daily_slot_count: 7,
          allow_online_slot: false,
          friday_no_p4: true,
          faculty_preference_weight: 2,
          sust_adjunct_single_half_day: true,
          sust_adjunct_max_gap: 2,
          low_credit_cse_theory_consecutive: true,
          three_credit_theory_spread: true,
          adjunct_day_bands: {
            two_courses_max_days: 2,
            three_courses_min_days: 3,
            three_courses_max_days: 4,
            four_plus_courses_min_days: 4,
            four_plus_courses_max_days: 5,
          },
          schema_version: 99,
          default_section_weekend: ["Monday", "Tuesday"],
          custom_hint: "preserved",
        },
      },
      includeGateCFields: true,
    };

    const assembled = assembleEngineConfigFromRecords(input);
    const snapshot = assembled.config.policy_snapshot as Record<string, unknown>;

    expect(assembled.gateCSummary.policySnapshotActive).toBe(true);
    expect(assembled.gateCSummary.policyLabel).toBe("Committee Baseline 2026");
    expect(assembled.gateCSummary.catalogCoursesCount).toBe(1);
    expect(assembled.gateCSummary.sectionPoliciesCount).toBe(1);
    expect(assembled.gateCSummary.sectionOverrideCount).toBe(1);

    // Authoritative top-level snapshot fields win over stale policy_payload keys.
    expect(snapshot.schema_version).toBe(2);
    expect(snapshot.default_section_weekend).toEqual(["Friday", "Saturday"]);
    expect(snapshot.custom_hint).toBe("preserved");
    expect(snapshot.allow_sessional_across_break).toBe(false);
    expect(snapshot.section_weekend_overrides).toEqual([
      {
        batch: "58",
        section: "B",
        weekend_days: ["Sunday", "Monday"],
        calendar_system: "trimester",
      },
    ]);
    expect(snapshot.physics_lab_course_codes).toEqual(["PHY-1102", "PHY-1202"]);
    expect(assembled.baselineCounts.activeRooms).toBe(1);
    expect(assembled.baselineCounts.activeFaculty).toBe(1);
    expect(assembled.baselineCounts.eligibility).toBe(1);
  });
});

describe("Stage 5B validationGate policy & outcome enforcement", () => {
  it("blocks on failed solver outcomes even before counters exist", () => {
    expect(blockingValidationErrorFor(null, "INFEASIBLE")).toContain(
      "INFEASIBLE",
    );
    expect(blockingValidationErrorFor(null, "TIME_LIMIT_EXHAUSTED")).toContain(
      "TIME_LIMIT_EXHAUSTED",
    );
    expect(blockingValidationErrorFor(null, "INPUT_ERROR")).toContain(
      "INPUT_ERROR",
    );
    expect(blockingValidationErrorFor(null, "UNKNOWN")).toContain("UNKNOWN");
  });

  it("blocks when any hard policy violation counter is non-zero", () => {
    const violations = inspectPolicyViolations({
      ok: false,
      policy_violations: {
        r1_section_weekend_violations: 2,
        r2_batch_fairness_violations: 0,
      },
      policy_violation_count: 2,
    });
    expect(violations).toHaveLength(1);
    expect(violations[0].key).toBe("r1_section_weekend_violations");
    expect(violations[0].label).toBe("R1 Section Weekend Violations");
    expect(violations[0].count).toBe(2);

    const specificErr = blockingValidationErrorFor(
      {
        ok: false,
        policy_violations: { r1_section_weekend_violations: 2 },
        policy_violation_count: 2,
      },
      "OPTIMAL",
    );
    expect(specificErr).toContain("r1 section weekend violations");

    const aggregateErr = blockingValidationErrorFor(
      {
        ok: false,
        policy_violations: {},
        policy_violation_count: 2,
      },
      "OPTIMAL",
    );
    expect(aggregateErr).toContain("committee hard-policy violation(s)");
  });

  it("allows OPTIMAL/FEASIBLE when hard counters are zero and only soft_metrics vary", () => {
    const err = blockingValidationErrorFor(
      {
        ok: true,
        policy_violations: {},
        policy_violation_count: 0,
        soft_metrics: {
          r8_faculty_preferences: {
            matched_slots: 1,
            total_with_preferences: 4,
            satisfaction_pct: 25,
          },
          r9_sust_compactness: {
            sust_faculty_count: 1,
            split_break_days: 2,
          },
        },
      },
      "FEASIBLE",
    );
    expect(err).toBeNull();
  });
});

describe("Stage 5B timetableEngineService D6 diagnostics polling", () => {
  it("extracts D6 diagnostics and attaches them to EngineJobError on solver failure", async () => {
    const statusPayload: EngineStatusResponse = {
      job_id: "job-r7-1",
      state: "failed",
      progress: 100,
      message: "R7 off-day validation failed for TFA",
      error: "R7 off-day validation failed for TFA",
      outcome: "INPUT_ERROR",
      raw_status: "INPUT_ERROR",
      termination_reason: "input_validation_failed",
      proven_infeasible: false,
      conflicts: [
        {
          rule: "R7",
          severity: "blocker",
          code: "r7_invalid_off_day_count",
          entity_type: "faculty",
          entity_id: "TFA",
          message:
            "Permanent faculty TFA has 3 off-days without allow_three_off_days.",
          suggested_route: "/admin/timetable/faculty",
          proven: true,
        },
      ],
    };

    const extracted = extractOutcomeDiagnostics(statusPayload);
    expect(extracted?.outcome).toBe("INPUT_ERROR");
    expect(extracted?.conflicts).toHaveLength(1);

    vi.spyOn(globalThis, "fetch").mockResolvedValueOnce(
      new Response(JSON.stringify(statusPayload), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      }),
    );

    await expect(
      runResilientJobPolling({
        jobId: "job-r7-1",
        pollIntervalMs: 1,
        maxPolls: 2,
      }),
    ).rejects.toMatchObject({
      name: "EngineJobError",
      kind: "solver-failed",
      diagnostics: expect.objectContaining({
        outcome: "INPUT_ERROR",
        conflicts: expect.arrayContaining([
          expect.objectContaining({ rule: "R7", entity_id: "TFA" }),
        ]),
      }),
    });
  });

  it("constructs EngineJobError with diagnostics cleanly", () => {
    const err = new EngineJobError(
      "solver-failed",
      "Infeasible",
      undefined,
      undefined,
      {
        outcome: "INFEASIBLE",
        proven_infeasible: true,
        conflicts: [],
      },
    );
    expect(err.diagnostics?.outcome).toBe("INFEASIBLE");
    expect(err.diagnostics?.proven_infeasible).toBe(true);
  });
});

describe("Stage 5B SolverDiagnosticsPanel D6 outcomes & deep-links", () => {
  const outcomes: SolverOutcomeStatus[] = [
    "OPTIMAL",
    "FEASIBLE",
    "INFEASIBLE",
    "TIME_LIMIT_EXHAUSTED",
    "UNKNOWN",
    "INPUT_ERROR",
  ];

  it.each(outcomes)("renders dedicated D6 outcome banner for %s", (outcome) => {
    const diagnostics: SolverOutcomeDiagnostics = {
      outcome,
      raw_status: outcome,
      proven_infeasible: outcome === "INFEASIBLE",
      conflicts: [],
    };
    render(
      <MemoryRouter>
        <SolverDiagnosticsPanel diagnostics={diagnostics} />
      </MemoryRouter>,
    );
    expect(screen.getByTestId("solver-diagnostics-panel")).toBeTruthy();
    expect(screen.getByTestId(`solver-outcome-banner-${outcome}`)).toBeTruthy();
  });

  it("renders actionable conflict deep-links and Soft Optimization Scorecard", () => {
    const diagnostics: SolverOutcomeDiagnostics = {
      outcome: "FEASIBLE",
      raw_status: "FEASIBLE",
      termination_reason: "feasible_solution_found",
      conflicts: [
        {
          rule: "R7",
          severity: "blocker",
          code: "conflict",
          entity_type: "faculty",
          entity_id: "TFA",
          message: "TFA exceeds permitted off-days.",
          proven: true,
        },
        {
          rule: "R10",
          severity: "blocker",
          code: "conflict",
          entity_type: "room",
          entity_id: "ECL-1",
          message: "ECL room availability window exceeded.",
          proven: true,
        },
        {
          rule: "R11",
          severity: "blocker",
          code: "conflict",
          entity_type: "course",
          entity_id: "PHY-1102",
          message: "Physics lab requires Physics Lab room.",
          proven: true,
        },
        {
          rule: "R1",
          severity: "blocker",
          code: "conflict",
          entity_type: "section",
          entity_id: "58-A",
          message: "Section weekend missing.",
          proven: true,
        },
        {
          rule: "R15",
          severity: "blocker",
          code: "conflict",
          entity_type: "settings",
          entity_id: "friday_no_p4",
          message: "Friday afternoon period blocked.",
          proven: true,
        },
        {
          rule: "R2",
          severity: "blocker",
          code: "conflict",
          entity_type: "policy",
          entity_id: "default",
          message: "Batch spread exceeded.",
          proven: true,
        },
      ],
      soft_metrics: {
        r8_faculty_preferences: {
          matched_slots: 5,
          total_with_preferences: 6,
          satisfaction_pct: 83.3,
        },
        r6_adjunct_workload: [
          {
            teacher: "ADJ1",
            distinct_course_count: 2,
            active_days: 2,
            target_band: [1, 2],
            in_band: true,
          },
        ],
        r9_sust_compactness: {
          sust_faculty_count: 1,
          split_break_days: 0,
        },
        r12_sessional_pairs: {
          total_two_credit_labs: 2,
          paired_two_credit_labs: 2,
          allow_sessional_across_break: false,
        },
        r3_single_slot_holes: 1,
      },
    };

    render(
      <MemoryRouter>
        <SolverDiagnosticsPanel diagnostics={diagnostics} />
      </MemoryRouter>,
    );

    expect(screen.getByTestId("solver-conflict-ledger")).toBeTruthy();
    expect(screen.getByTestId("soft-optimization-scorecard")).toBeTruthy();
    expect(screen.getByText("5/6 (83.3%)")).toBeTruthy();
    expect(screen.getByText("1 hole(s)")).toBeTruthy();

    const links = screen.getAllByRole("link");
    const hrefs = links.map((link) => link.getAttribute("href"));
    expect(hrefs).toContain("/admin/timetable/faculty");
    expect(hrefs).toContain("/admin/timetable/rooms");
    expect(hrefs).toContain("/admin/timetable/courses");
    expect(hrefs).toContain("/admin/timetable/batches");
    expect(hrefs).toContain("/admin/timetable/settings");
    expect(hrefs).toContain("/admin/scheduling");
  });
});
