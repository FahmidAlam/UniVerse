import { afterEach, describe, expect, it, vi } from "vitest";
import {
  getCapabilityById,
  resolveLiveCapabilityDescriptor,
} from "@/core/capabilities";
import {
  buildSectionsHarvestFromRoutines,
  isValidConsecutiveWeekendPair,
  toSectionPolicyWritePayload,
} from "@/features/admin/services/batchesService";
import {
  buildCoursesHarvestFromRoutines,
  toCatalogCourseWritePayload,
} from "@/features/admin/services/coursesService";
import {
  evaluateR7FacultyPolicy,
  toExtendedFacultyWritePayload,
} from "@/features/admin/services/facultyService";
import { toExtendedRoomWritePayload } from "@/features/admin/services/roomsService";
import { getDefaultSettings } from "@/features/admin/services/settingsService";
import { assembleEngineConfigFromRecords } from "@/features/routine/services/buildEngineConfig";
import {
  DEFAULT_POLICY_SNAPSHOT_FORM,
  savePolicySnapshot,
  saveValidationReportArtifact,
  validatePolicyReadiness,
} from "@/features/scheduling/services/policySnapshotService";
import { resolveLiveSchedulingGates } from "@/features/scheduling/services/schedulingCapabilities";

afterEach(() => {
  vi.restoreAllMocks();
});

describe("Stage 5A (Gate C) catalogs, PolicySnapshot, preflight & capability unlock", () => {
  it("unlocks Gate C and catalogs dynamically only when Stage 5A tables exist, while keeping Gate D unconditionally locked", () => {
    const preMigration = resolveLiveSchedulingGates({
      supabaseConfigured: true,
      isDevPreview: false,
      readRpcAvailable: true,
      appendRpcAvailable: true,
      scopeReadAuthorized: true,
      revisionRowExists: true,
      policySnapshotsAvailable: false,
      validationArtifactPayloadAvailable: false,
      catalogCoursesAvailable: false,
      sectionPoliciesAvailable: false,
    });
    expect(preMigration.gateA.unlocked).toBe(true);
    expect(preMigration.gateB.unlocked).toBe(true);
    expect(preMigration.gateC.unlocked).toBe(false);
    expect(preMigration.gateD.unlocked).toBe(false);
    expect(preMigration.catalogs?.coursesLive).toBe(false);

    const postMigration = resolveLiveSchedulingGates({
      supabaseConfigured: true,
      isDevPreview: false,
      readRpcAvailable: true,
      appendRpcAvailable: true,
      scopeReadAuthorized: true,
      revisionRowExists: true,
      policySnapshotsAvailable: true,
      validationArtifactPayloadAvailable: true,
      catalogCoursesAvailable: true,
      sectionPoliciesAvailable: true,
      facultyExtendedAvailable: true,
      roomsExtendedAvailable: true,
    });
    expect(postMigration.gateC.unlocked).toBe(true);
    expect(postMigration.gateD.unlocked).toBe(false);
    expect(postMigration.catalogs?.coursesLive).toBe(true);
    expect(postMigration.catalogs?.batchesLive).toBe(true);

    const coursesCap = resolveLiveCapabilityDescriptor(
      getCapabilityById("admin.courses")!,
      postMigration,
    );
    expect(coursesCap.status).toBe("live-persisted");
    expect(coursesCap.sidebarBadge).toBeUndefined();
  });

  it("validates coursesService normalization and deduplicates active routine seeding", () => {
    const payload = toCatalogCourseWritePayload({
      code: " phy-1104 ",
      title: " Physics Lab ",
      dept_code: " phy ",
      credit: 1.5,
      class_type: "lab",
      is_service: true,
      is_physics_lab: true,
      default_weekly_sessions: 2,
      is_active: true,
    });
    expect(payload.code).toBe("PHY-1104");
    expect(payload.is_physics_lab).toBe(true);

    const harvest = buildCoursesHarvestFromRoutines(
      [
        {
          id: "1",
          day: "Sunday",
          time_start: "08:50:00",
          time_end: "10:05:00",
          subject: "Database Management Systems",
          subject_code: "CSE-3101",
          teacher_name: "EBH",
          teacher_code: "EBH",
          room: "RAB-302",
          batch: "58",
          section: "A",
          semester: 6,
          is_active: true,
          is_service: false,
        },
        {
          id: "2",
          day: "Monday",
          time_start: "10:10:00",
          time_end: "11:25:00",
          subject: "Database Management Systems",
          subject_code: "cse-3101",
          teacher_name: "EBH",
          teacher_code: "EBH",
          room: "RAB-302",
          batch: "58",
          section: "B",
          semester: 6,
          is_active: true,
          is_service: false,
        },
      ],
      [
        {
          id: "existing",
          code: "CSE-1101",
          title: "SPL",
          department_id: null,
          dept_code: "CSE",
          credit: 3,
          class_type: "theory",
          is_service: false,
          is_physics_lab: false,
          default_weekly_sessions: 2,
          is_active: true,
          notes: null,
          created_at: "",
          updated_at: "",
        },
      ],
    );
    expect(harvest.toInsert).toHaveLength(1);
    expect(harvest.toInsert[0]?.code).toBe("CSE-3101");
  });

  it("enforces R1 consecutive 2-day weekend validation (including cyclic Sat+Sun) and batch seeding", () => {
    expect(isValidConsecutiveWeekendPair(["Friday", "Saturday"])).toBe(true);
    expect(isValidConsecutiveWeekendPair(["Saturday", "Sunday"])).toBe(true);
    expect(isValidConsecutiveWeekendPair(["Friday", "Sunday"])).toBe(false);
    expect(isValidConsecutiveWeekendPair(["Friday"])).toBe(false);

    expect(() =>
      toSectionPolicyWritePayload({
        batch: "61",
        section: "A",
        calendar_system: "bi_semester",
        weekend_override_days: ["Friday", "Sunday"],
        student_count: 45,
        is_active: true,
      }),
    ).toThrow(/consecutive/i);

    const harvested = buildSectionsHarvestFromRoutines(
      [
        {
          id: "1",
          day: "Sunday",
          time_start: "08:50:00",
          time_end: "10:05:00",
          subject: "DBMS",
          subject_code: "CSE-3101",
          teacher_name: "EBH",
          teacher_code: "EBH",
          room: "RAB-302",
          batch: "58",
          section: "b+c",
          semester: 6,
          is_active: true,
          is_service: false,
        },
      ],
      [],
    );
    expect(harvested.toInsert).toHaveLength(1);
    expect(harvested.toInsert[0]?.section).toBe("B+C");
  });

  it("enforces D5 allow_sessional_across_break=false default and forwards RPC parameters cleanly", async () => {
    expect(DEFAULT_POLICY_SNAPSHOT_FORM.allowSessionalAcrossBreak).toBe(false);

    const rpcSpy = vi.fn().mockResolvedValue({
      data: {
        id: "snap-1",
        scheduling_scope_id: null,
        revision_id: "rev-1",
        label: "Stage 5A Baseline",
        version: 1,
        is_active: true,
        schema_version: 1,
        default_section_weekend: ["Friday", "Saturday"],
        batch_max_off_day_spread: 1,
        max_section_internal_gap: 1,
        allow_sessional_across_break: false,
        physics_lab_course_codes: ["PHY-1104"],
        policy_payload: DEFAULT_POLICY_SNAPSHOT_FORM.policyPayload,
        policy_hash: "a".repeat(64),
        created_by: "admin-1",
        created_at: "2026-11-27T00:00:00Z",
      },
      error: null,
    });

    const saved = await savePolicySnapshot(
      {
        ...DEFAULT_POLICY_SNAPSHOT_FORM,
        revisionId: "rev-1",
        physicsLabCourseCodes: [" phy-1104 "],
      },
      { rpc: rpcSpy } as never,
    );
    expect(saved.allow_sessional_across_break).toBe(false);
    expect(saved.physics_lab_course_codes).toEqual(["PHY-1104"]);
    expect(rpcSpy).toHaveBeenCalledWith(
      "save_policy_snapshot",
      expect.objectContaining({
        p_revision_id: "rev-1",
        p_allow_sessional_across_break: false,
        p_physics_lab_course_codes: ["PHY-1104"],
      }),
    );

    const artSpy = vi.fn().mockResolvedValue({
      data: { id: "art-1", status: "current", artifact_kind: "validation_report" },
      error: null,
    });
    await saveValidationReportArtifact(
      {
        revisionId: "rev-1",
        policySnapshotId: "snap-1",
        report: {
          ok: false,
          policy_hash: "a".repeat(64),
          allow_sessional_across_break: false,
          checks: [],
          blockers: [
            {
              id: "r5-guest-availability",
              rule_id: "R5",
              category: "Guest Availability",
              status: "blocker",
              severity: "critical",
              title: "Guest missing slots",
              description: "Add available slots",
              target_stage: "policy",
              affected_entities: ["MRH"],
            },
          ],
          warnings: [],
          summary: {
            blocker_count: 1,
            warning_count: 0,
            passed_count: 4,
            active_faculty_count: 2,
            active_room_count: 2,
            active_course_count: 1,
            active_section_count: 1,
            allow_sessional_across_break: false,
          },
          rule_coverage: ["R5"],
        },
      },
      { rpc: artSpy } as never,
    );
    expect(artSpy).toHaveBeenCalledWith(
      "save_validation_report_artifact",
      expect.objectContaining({
        p_revision_id: "rev-1",
        p_policy_snapshot_id: "snap-1",
        p_has_blockers: true,
      }),
    );
  });

  it("maps validatePolicyReadiness errors cleanly and evaluates R7/R5 extended payloads", async () => {
    expect(
      evaluateR7FacultyPolicy({
        employment_type: "permanent",
        off_days: ["Wed", "Thu", "Fri"],
        allow_three_off_days: false,
      }).valid,
    ).toBe(false);
    expect(
      evaluateR7FacultyPolicy({
        employment_type: "permanent",
        off_days: ["Wed", "Thu", "Fri"],
        allow_three_off_days: true,
      }).valid,
    ).toBe(true);

    const extFac = toExtendedFacultyWritePayload({
      acronym: "mrh",
      off_days: [],
      is_active: true,
      courses: ["PHY-1104"],
      employment_type: "guest",
      allow_three_off_days: true, // stripped for non-permanent
      available_slots: [{ day: "Sunday", period_idx: 2 }],
    });
    expect(extFac.allow_three_off_days).toBe(false);
    expect(extFac.available_slots).toEqual([{ day: "Sunday", period_idx: 2 }]);

    const extRoom = toExtendedRoomWritePayload({
      name: "ecl-1",
      is_lab: true,
      is_gallery: false,
      is_active: true,
      available_slots: [{ day: "Monday", period_idx: 1 }],
    });
    expect(extRoom.room_pool_role).toBe("ecl_lab");
    expect(extRoom.available_slots).toHaveLength(1);

    vi.spyOn(globalThis, "fetch").mockResolvedValueOnce(
      new Response(JSON.stringify({ detail: "Admin role required." }), {
        status: 403,
        headers: { "Content-Type": "application/json" },
      }),
    );
    await expect(
      validatePolicyReadiness({
        policy_snapshot: {},
        faculty: [],
        rooms: [],
        courses: [],
        sections: [],
        settings: {},
      }),
    ).rejects.toThrow(/403/);
  });

  it("includes Gate C fields in assembleEngineConfigFromRecords only when includeGateCFields is true", () => {
    const settings = getDefaultSettings();
    const { config } = assembleEngineConfigFromRecords({
      rooms: [
        {
          id: "r1",
          name: "ECL-1",
          building: "RAB",
          is_lab: true,
          is_gallery: false,
          capacity: 40,
          is_active: true,
          dept: "EEE",
          room_pool_role: "ecl_lab",
          available_slots: [{ day: "Monday", period_idx: 2 }],
        },
      ],
      faculty: [
        {
          id: "f1",
          acronym: "MRH",
          full_name: "Guest Physics",
          dept: "PHY",
          designation: "Guest",
          off_days: [],
          is_active: true,
          courses: ["PHY-1104"],
          employment_type: "guest",
          available_slots: [{ day: "Tuesday", period_idx: 1 }],
        },
      ],
      eligibility: [],
      settings,
      hasSettings: true,
      includeGateCFields: true,
    });

    expect(config.rooms[0]?.room_pool_role).toBe("ecl_lab");
    expect(config.teachers[0]?.employment_type).toBe("guest");
    expect(config.teachers[0]?.available_slots).toEqual([
      { day: "Tuesday", period_idx: 1 },
    ]);
  });
});
