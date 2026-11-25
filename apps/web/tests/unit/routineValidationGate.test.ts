import { describe, expect, it } from "vitest";
import {
  jointSectionsOverlap,
  matchesJointSection,
  RoomIdentity,
} from "@/core/utils/roomIdentity";
import {
  crc32,
  parseGenerationProfile,
  verifyGenerationProfileSource,
} from "@/features/routine/services/generationProfile";
import { detectRoutineClashes } from "@/features/routine/services/routineService";
import {
  assessBaselineConfigForPublish,
  BLOCKING_VALIDATION_COUNTERS,
  blockingValidationErrorFor,
  findCoTeacherBlockers,
  requiresSharedTeacherStorage,
} from "@/features/routine/services/validationGate";
import type { RoutineRow } from "@/features/routine/types";

function makeRow(overrides: Partial<RoutineRow> = {}): RoutineRow {
  return {
    id: "r-1",
    day: "Sunday",
    time_start: "08:50:00",
    time_end: "10:05:00",
    subject: "Database Systems",
    subject_code: "CSE-3101",
    teacher_name: "Md. Ebrahim Hossain",
    teacher_code: "EBH",
    room: "RAB-302",
    batch: "58",
    section: "B+C",
    semester: 6,
    is_active: true,
    is_service: false,
    ...overrides,
  };
}

describe("Phase 3 Validation Gate, Profile CRC32, RoomIdentity, Joint Sections & Clash Detection", () => {
  it("blocks when validation is missing, ok is non-boolean, ok is false, or any of the 20 counters > 0", () => {
    expect(blockingValidationErrorFor(null)).toMatch(/missing or incomplete/i);
    expect(blockingValidationErrorFor({ ok: "yes" })).toMatch(
      /missing or incomplete/i,
    );
    expect(blockingValidationErrorFor({ ok: false })).toMatch(
      /reported this routine as invalid/i,
    );
    expect(blockingValidationErrorFor({ ok: true })).toBeNull();

    expect(BLOCKING_VALIDATION_COUNTERS).toHaveLength(20);
    for (const desc of BLOCKING_VALIDATION_COUNTERS) {
      const msg = blockingValidationErrorFor({ ok: true, [desc.key]: 2 });
      expect(msg, `Counter ${desc.key} must block`).not.toBeNull();
      expect(msg).toContain(desc.formatProblem(2));
    }
  });

  it("enforces co-teacher storage guard across both rows and service_rows (F-22)", () => {
    const clean = makeRow({ teacher_code: "EBH", teachers: ["EBH"] });
    const coTaught = makeRow({
      id: "r-co",
      teacher_code: "EBH",
      teachers: ["EBH", "MSR"],
    });
    const mismatchScalar = makeRow({
      id: "r-svc",
      is_service: true,
      teacher_code: "MRH",
      teachers: ["NT"],
    });

    expect(requiresSharedTeacherStorage(clean)).toBe(false);
    expect(requiresSharedTeacherStorage(coTaught)).toBe(true);
    expect(requiresSharedTeacherStorage(mismatchScalar)).toBe(true);

    expect(findCoTeacherBlockers([clean], [mismatchScalar])).toHaveLength(1);
    expect(findCoTeacherBlockers([coTaught], [])).toHaveLength(1);
  });

  it("enforces empty-config pre-publish guard (F-20)", () => {
    const blocked = assessBaselineConfigForPublish({
      rooms: 0,
      activeRooms: 0,
      faculty: 10,
      activeFaculty: 0,
      eligibility: 0,
      hasSettings: false,
    });
    expect(blocked.canPublish).toBe(false);
    expect(blocked.blockingReasons).toHaveLength(3);
    expect(blocked.warnings).toHaveLength(1);

    const readyNoElig = assessBaselineConfigForPublish({
      rooms: 30,
      activeRooms: 28,
      faculty: 40,
      activeFaculty: 38,
      eligibility: 0,
      hasSettings: true,
    });
    expect(readyNoElig.canPublish).toBe(true);
    expect(readyNoElig.warnings).toHaveLength(1);
  });

  it("computes IEEE CRC32 and verifies GenerationProfileV1 against source workbook bytes", () => {
    const bytes = new TextEncoder().encode("PK\x03\x04sample-xlsx-payload");
    const checksum = crc32(bytes);
    expect(checksum).toBeGreaterThan(0);

    const profileText = JSON.stringify({
      format: "universe-generation-profile-v1",
      label: "Summer 2025 Rehearsal",
      provenance: "Committee baseline archive",
      source_crc32: checksum,
      source_bytes: bytes.byteLength,
      meeting_count_policy: "distribution",
      config: {
        rooms: [{ name: "ACL-1", is_lab: true }],
        teachers: [{ acronym: "EBH", off_days: ["Friday"] }],
        days: ["Sunday", "Monday"],
        room_aliases: { "PHY LAB": "RAB-106" },
        settings: {
          periods: [{ idx: 1, col: "D", start: "08:50", end: "10:05" }],
          weeks_in_term: 14,
          fixed_sessions_per_week: 2,
        },
      },
    });

    const parsed = parseGenerationProfile(profileText);
    expect(parsed.config.settings.fixed_sessions_per_week).toBeNull();
    expect(() => verifyGenerationProfileSource(parsed, bytes)).not.toThrow();

    const altered = new TextEncoder().encode("PK\x03\x04different-xlsx-payload");
    expect(() => verifyGenerationProfileSource(parsed, altered)).toThrow(
      /different distribution file/i,
    );
  });

  it("matches joint B+C cohorts and resolves RoomIdentity aliases safely against cycles", () => {
    expect(matchesJointSection("B+C", "B")).toBe(true);
    expect(matchesJointSection("B+C", "C")).toBe(true);
    expect(matchesJointSection("B+C", "B+C")).toBe(true);
    expect(matchesJointSection("B+C", "A")).toBe(false);
    expect(jointSectionsOverlap("B+C", "C")).toBe(true);
    expect(jointSectionsOverlap("A", "B+C")).toBe(false);

    expect(RoomIdentity.currentKey("  phy   lab ")).toBe("RAB-106");
    expect(() =>
      RoomIdentity.key("R1", { R1: "R2", R2: "R1" }),
    ).toThrow(/Cyclic room aliases/i);
  });

  it("detects teacher, room (alias-aware, ignoring TBA), and B+C cohort clashes", () => {
    const existing = [
      makeRow({
        id: "slot-1",
        day: "Sunday",
        time_start: "08:50:00",
        time_end: "10:05:00",
        teacher_code: "EBH",
        room: "PHY LAB",
        batch: "58",
        section: "B+C",
      }),
      makeRow({
        id: "slot-tba",
        day: "Sunday",
        time_start: "10:10:00",
        time_end: "11:25:00",
        teacher_code: "MSR",
        room: "TBA",
        batch: "59",
        section: "A",
      }),
    ];

    const clashes = detectRoutineClashes(
      {
        day: "Sunday",
        time_start: "09:00:00",
        time_end: "10:00:00",
        teacher_code: "EBH",
        room: "RAB-106",
        batch: "58",
        section: "C",
      },
      existing,
      null,
      { "PHY LAB": "RAB-106" },
    );

    expect(clashes.map((c) => c.type).sort()).toEqual([
      "cohort",
      "room",
      "teacher",
    ]);

    // Ignoring TBA room clashes and ignoring self id
    const noTbaClash = detectRoutineClashes(
      {
        day: "Sunday",
        time_start: "10:10:00",
        time_end: "11:25:00",
        teacher_code: "KJH",
        room: "TBA",
        batch: "60",
        section: "A",
      },
      existing,
    );
    expect(noTbaClash).toEqual([]);

    const ignoreSelf = detectRoutineClashes(
      {
        day: "Sunday",
        time_start: "08:50:00",
        time_end: "10:05:00",
        teacher_code: "EBH",
        room: "RAB-106",
        batch: "58",
        section: "B+C",
      },
      existing,
      "slot-1",
      { "PHY LAB": "RAB-106" },
    );
    expect(ignoreSelf).toEqual([]);
  });
});
