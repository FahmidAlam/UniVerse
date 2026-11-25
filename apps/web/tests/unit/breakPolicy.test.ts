import { describe, expect, it } from "vitest";
import {
  applyMiddayBreakToPeriods,
  resolveBreakBeforePeriodIdx,
  resolveMiddayBreak,
} from "@/core/utils/breakPolicy";
import { ClockTime } from "@/core/utils/clockTime";
import {
  getDefaultOnlinePeriod,
  getDefaultPeriods6,
  getDefaultPeriods7,
  getDefaultSettings,
} from "@/features/admin/services/settingsService";
import { assembleEngineConfigFromRecords } from "@/features/routine/services/buildEngineConfig";

describe("breakPolicy dynamic midday break", () => {
  it("defaults to break after P4 on 7-slot grids and after P3 on 6-slot grids", () => {
    const p7 = getDefaultPeriods7();
    const b7 = resolveMiddayBreak(p7);
    expect(b7.afterPeriodIdx).toBe(4);
    expect(b7.start).toBe("14:05");
    expect(b7.end).toBe("14:30");
    expect(b7.durationMinutes).toBe(25);
    expect(resolveBreakBeforePeriodIdx(p7)).toBe(5);

    const p6 = getDefaultPeriods6();
    const b6 = resolveMiddayBreak(p6);
    expect(b6.afterPeriodIdx).toBe(3);
    expect(b6.start).toBe("12:45");
    expect(b6.end).toBe("13:10");
    expect(b6.durationMinutes).toBe(25);
    expect(resolveBreakBeforePeriodIdx(p6)).toBe(4);
  });

  it("moves midday break to after P3, P5, or No Break cleanly without clock overlaps", () => {
    const base = [...getDefaultPeriods7(), getDefaultOnlinePeriod()];

    const afterP3 = applyMiddayBreakToPeriods(base, 3, 30);
    expect(resolveMiddayBreak(afterP3)).toEqual({
      afterPeriodIdx: 3,
      start: "12:45",
      end: "13:15",
      durationMinutes: 30,
    });
    expect(resolveBreakBeforePeriodIdx(afterP3)).toBe(4);
    expect(ClockTime.validateMonotonicPeriods(afterP3.slice(0, 7))).toBeNull();

    const afterP5 = applyMiddayBreakToPeriods(base, 5, 25);
    expect(resolveMiddayBreak(afterP5).afterPeriodIdx).toBe(5);
    expect(resolveBreakBeforePeriodIdx(afterP5)).toBe(6);
    expect(ClockTime.validateMonotonicPeriods(afterP5.slice(0, 7))).toBeNull();

    const noBreak = applyMiddayBreakToPeriods(base, null, 25);
    expect(resolveMiddayBreak(noBreak)).toEqual({
      afterPeriodIdx: null,
      start: "",
      end: "",
      durationMinutes: 0,
    });
    expect(resolveBreakBeforePeriodIdx(noBreak)).toBeNull();
    expect(ClockTime.validateMonotonicPeriods(noBreak.slice(0, 7))).toBeNull();
    // Online slot P8 remains untouched
    expect(noBreak.find((p) => p.idx === 8)?.start).toBe("19:00");
  });

  it("produces engine/render.py-safe column letters in assembleEngineConfigFromRecords()", () => {
    const settings = getDefaultSettings();
    settings.periods = applyMiddayBreakToPeriods(settings.periods, 3, 25);
    const { config } = assembleEngineConfigFromRecords({
      rooms: [],
      faculty: [],
      eligibility: [],
      settings,
      hasSettings: true,
    });
    expect(config.settings.periods.map((p) => p.col)).toEqual([
      "D",
      "E",
      "F",
      "H",
      "I",
      "J",
      "K",
    ]);
  });
});
