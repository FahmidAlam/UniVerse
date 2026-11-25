import { describe, expect, it } from "vitest";
import {
  ensureSolverSafePeriods,
  getDefaultSettings,
  ONLINE_SLOT_COL,
  ONLINE_SLOT_IDX,
  setOnlineSlotEnabled,
  setRegularSlotCount,
} from "@/features/admin/services/settingsService";
import { assembleEngineConfigFromRecords } from "@/features/routine/services/buildEngineConfig";

describe("buildEngineConfig & idx:8 Col L solver/renderer parity", () => {
  const sampleRooms = [
    {
      id: "r1",
      name: "ACL-1",
      building: "RAB",
      is_lab: true,
      is_gallery: false,
      capacity: 45,
      is_active: true,
      dept: "CSE",
      // Simulate extra fields that must NEVER leak into engine payload
      classification: "cse_lab",
      declared_window_matrix: { Sunday: [1, 2] },
    } as never,
    {
      id: "r2",
      name: "RAB-999",
      building: "RAB",
      is_lab: false,
      is_gallery: false,
      capacity: 50,
      is_active: false, // inactive must be excluded
      dept: "CSE",
    },
  ];

  const sampleFaculty = [
    {
      id: "f1",
      acronym: "EBH",
      full_name: "Md. Ebrahim Hossain",
      dept: "CSE",
      designation: "Assistant Professor",
      off_days: ["Thursday", "Friday"],
      is_active: true,
      courses: ["CSE-3101"],
      // Extra non-DB Phase A keys that must NEVER leak
      employment_type: "permanent",
      slot_matrix: { Sunday: [1] },
    } as never,
    {
      id: "f2",
      acronym: "OLD",
      full_name: "Retired Faculty",
      dept: "CSE",
      designation: "Lecturer",
      off_days: [],
      is_active: false, // inactive must be excluded
      courses: [],
    },
  ];

  const sampleEligibility = [
    {
      id: "e1",
      acronym: "EBH",
      course_code: "CSE-3101",
      is_eligible: true,
      priority: 1,
      created_at: "2026-01-01T00:00:00Z",
      updated_at: "2026-01-01T00:00:00Z",
    },
  ];

  it("emits strictly baseline active rooms & faculty (zero non-DB Phase A keys) and HH:MM period clocks", () => {
    const settings = getDefaultSettings();
    const { config, baselineCounts } = assembleEngineConfigFromRecords({
      rooms: sampleRooms,
      faculty: sampleFaculty,
      eligibility: sampleEligibility,
      settings,
      hasSettings: true,
    });

    expect(baselineCounts).toEqual({
      rooms: 2,
      activeRooms: 1,
      faculty: 2,
      activeFaculty: 1,
      eligibility: 1,
      hasSettings: true,
    });

    expect(config.rooms).toEqual([
      { name: "ACL-1", is_lab: true, is_gallery: false, capacity: 45 },
    ]);
    expect(Object.keys(config.rooms[0]!)).not.toContain("classification");
    expect(Object.keys(config.rooms[0]!)).not.toContain("declared_window_matrix");

    expect(config.teachers).toEqual([
      {
        acronym: "EBH",
        full_name: "Md. Ebrahim Hossain",
        dept: "CSE",
        off_days: ["Thursday", "Friday"],
      },
    ]);
    expect(Object.keys(config.teachers[0]!)).not.toContain("employment_type");
    expect(Object.keys(config.teachers[0]!)).not.toContain("slot_matrix");

    for (const p of config.settings.periods) {
      expect(p.start).toMatch(/^\d{2}:\d{2}$/);
      expect(p.end).toMatch(/^\d{2}:\d{2}$/);
    }
  });

  it("produces valid unique idx & col across (a) 7-slot + online off, (b) 7-slot + idx 8 Col L, and (c) 6-slot + idx 8 Col L", () => {
    // Mode (a): 7 regular on-campus slots, online disabled
    const modeA = setOnlineSlotEnabled(
      setRegularSlotCount(getDefaultSettings(), 7),
      false,
    );
    const cfgA = assembleEngineConfigFromRecords({
      rooms: sampleRooms,
      faculty: sampleFaculty,
      eligibility: sampleEligibility,
      settings: modeA,
      hasSettings: true,
    }).config;

    expect(cfgA.settings.allow_online_periods).toBe(false);
    expect(cfgA.settings.online_periods).toEqual([ONLINE_SLOT_IDX]);
    expect(cfgA.settings.periods.map((p) => p.idx)).toEqual([1, 2, 3, 4, 5, 6, 7]);
    expect(cfgA.settings.periods.map((p) => p.col)).toEqual([
      "D",
      "E",
      "F",
      "H",
      "I",
      "J",
      "K",
    ]);

    // Mode (b): 7 regular slots + separate online slot (idx 8, Col L)
    const modeB = setOnlineSlotEnabled(modeA, true);
    const cfgB = assembleEngineConfigFromRecords({
      rooms: sampleRooms,
      faculty: sampleFaculty,
      eligibility: sampleEligibility,
      settings: modeB,
      hasSettings: true,
    }).config;

    expect(cfgB.settings.allow_online_periods).toBe(true);
    expect(cfgB.settings.online_periods).toEqual([ONLINE_SLOT_IDX]);
    expect(cfgB.settings.periods.map((p) => p.idx)).toEqual([
      1, 2, 3, 4, 5, 6, 7, 8,
    ]);
    expect(cfgB.settings.periods.map((p) => p.col)).toEqual([
      "D",
      "E",
      "F",
      "H",
      "I",
      "J",
      "K",
      ONLINE_SLOT_COL,
    ]);

    // Mode (c): 6 regular slots + separate online slot (idx 8, Col L)
    const modeC = setRegularSlotCount(modeB, 6);
    const cfgC = assembleEngineConfigFromRecords({
      rooms: sampleRooms,
      faculty: sampleFaculty,
      eligibility: sampleEligibility,
      settings: modeC,
      hasSettings: true,
    }).config;

    expect(cfgC.settings.allow_online_periods).toBe(true);
    expect(cfgC.settings.online_periods).toEqual([ONLINE_SLOT_IDX]);
    expect(cfgC.settings.periods.map((p) => p.idx)).toEqual([
      1, 2, 3, 4, 5, 6, 8,
    ]);
    expect(cfgC.settings.periods.map((p) => p.col)).toEqual([
      "D",
      "E",
      "F",
      "H",
      "I",
      "J",
      ONLINE_SLOT_COL,
    ]);
    // Ensure no break-column 'G' collisions and all cols/idx unique
    for (const cfg of [cfgA, cfgB, cfgC]) {
      const cols = cfg.settings.periods.map((p) => p.col);
      const idxs = cfg.settings.periods.map((p) => p.idx);
      expect(new Set(cols).size).toBe(cols.length);
      expect(new Set(idxs).size).toBe(idxs.length);
      expect(cols).not.toContain("G");
    }
  });

  it("repairs colliding break column G or duplicate idx in ensureSolverSafePeriods", () => {
    const fixed = ensureSolverSafePeriods([
      { idx: 1, label: "a", start: "08:50:00", end: "10:05:00", col: "g" },
      { idx: 1, label: "b", start: "10:10", end: "11:25", col: "D" },
      { idx: 8, label: "ol", start: "19:00", end: "20:20", col: "l" },
    ]);

    expect(fixed.map((p) => p.idx)).toEqual([1, 2, 8]);
    expect(fixed.map((p) => p.col)).not.toContain("G");
    expect(new Set(fixed.map((p) => p.col)).size).toBe(3);
    expect(fixed[2]?.col).toBe("L");
    expect(fixed[0]?.start).toBe("08:50");
  });
});
