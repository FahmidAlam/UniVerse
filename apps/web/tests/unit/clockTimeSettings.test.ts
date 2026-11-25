import { describe, expect, it, vi } from "vitest";
import { ClockTime } from "@/core/utils/clockTime";
import {
  getDefaultSettings,
  ONLINE_SLOT_IDX,
  partitionPeriods,
  setOnlineSlotEnabled,
  setRegularSlotCount,
  syncFridayJummahBlock,
  toSettingsUpsertPayload,
} from "@/features/admin/services/settingsService";

describe("ClockTime & TimetableSettings contract", () => {
  it("normalizes 12h/afternoon/fractional strings to 24h HH:MM and HH:MM:SS", () => {
    expect(ClockTime.normalize("8:50")).toBe("08:50:00");
    expect(ClockTime.normalize("1:50")).toBe("13:50:00");
    expect(ClockTime.normalize("1:50 PM")).toBe("13:50:00");
    expect(ClockTime.normalize("12:50 PM")).toBe("12:50:00");
    expect(ClockTime.normalize("12:15 AM")).toBe("00:15:00");
    expect(ClockTime.toHm("13:50:00")).toBe("13:50");
    expect(ClockTime.normalize("0.5")).toBe("12:00:00");
  });

  it("repairs PM sequence across ordered teaching slots", () => {
    const repaired = ClockTime.repairSequence([
      { idx: 1, start: "08:50", end: "10:05" },
      { idx: 4, start: "12:50", end: "2:05" },
      { idx: 5, start: "2:10", end: "3:25" },
    ]);
    expect(repaired[1]).toEqual({ idx: 4, start: "12:50", end: "14:05" });
    expect(repaired[2]).toEqual({ idx: 5, start: "14:10", end: "15:25" });
  });

  it("rejects overlapping or reversed teaching period bounds", () => {
    const overlapErr = ClockTime.validateMonotonicPeriods([
      { idx: 1, start: "08:50", end: "10:05" },
      { idx: 2, start: "10:00", end: "11:25" },
    ]);
    expect(overlapErr).toMatch(/cannot start before Period 1 ends/i);

    const reversedErr = ClockTime.validateMonotonicPeriods([
      { idx: 1, start: "10:05", end: "08:50" },
    ]);
    expect(reversedErr).toMatch(/strictly after its start time/i);
  });

  it("validates weeks_in_term (1..52), fixed_sessions_per_week (null or 0..7), and Friday Jummah P4 sync", () => {
    const base = getDefaultSettings();

    expect(() =>
      toSettingsUpsertPayload({ ...base, weeks_in_term: 0 }),
    ).toThrow(/between 1 and 52/i);

    expect(() =>
      toSettingsUpsertPayload({ ...base, weeks_in_term: 53 }),
    ).toThrow(/between 1 and 52/i);

    expect(() =>
      toSettingsUpsertPayload({ ...base, fixed_sessions_per_week: 8 }),
    ).toThrow(/between 0 and 7/i);

    const validNull = toSettingsUpsertPayload({
      ...base,
      fixed_sessions_per_week: null,
      friday_no_p4: true,
      blocked_periods: { Tuesday: [6] },
    });
    expect(validNull.fixed_sessions_per_week).toBeNull();
    expect(validNull.blocked_periods).toEqual({
      Tuesday: [6],
      Friday: [4],
    });

    expect(
      syncFridayJummahBlock(false, { Friday: [4, 5], Monday: [1] }),
    ).toEqual({ Friday: [5], Monday: [1] });
  });

  it("uses .upsert({ id: 1 }, { onConflict: 'id' }) when saving to live Supabase", async () => {
    vi.resetModules();

    const upsertSpy = vi.fn().mockImplementation((payload: unknown) => ({
      select: () => ({
        single: async () => ({
          data: payload,
          error: null,
        }),
      }),
    }));

    vi.doMock("@/services/supabase", () => ({
      isSupabaseConfigured: true,
      supabase: {
        from: (table: string) => {
          expect(table).toBe("timetable_settings");
          return { upsert: upsertSpy };
        },
      },
    }));

    const mod = await import("@/features/admin/services/settingsService");
    const saved = await mod.saveTimetableSettings(mod.getDefaultSettings(), false);

    expect(upsertSpy).toHaveBeenCalledTimes(1);
    expect(upsertSpy.mock.calls[0]?.[0]).toMatchObject({ id: 1 });
    expect(upsertSpy.mock.calls[0]?.[1]).toEqual({ onConflict: "id" });
    expect(saved.id).toBe(1);

    vi.doUnmock("@/services/supabase");
  });

  it("decouples R15 regular 6-slot vs 7-slot on-campus grid from independent Online Slot toggle", () => {
    const base = getDefaultSettings();
    expect(partitionPeriods(base).regularPeriods).toHaveLength(7);
    expect(base.allow_online_periods).toBe(false);

    // Switching 7-Slot -> 6-Slot keeps allow_online_periods untouched
    const sixSlots = setRegularSlotCount(base, 6);
    expect(partitionPeriods(sixSlots).regularPeriods).toHaveLength(6);
    expect(sixSlots.allow_online_periods).toBe(false);

    // Turning Online Slot ON adds independent online slot (idx 8) without mutating 6 regular slots
    const sixWithOnline = setOnlineSlotEnabled(sixSlots, true);
    expect(sixWithOnline.allow_online_periods).toBe(true);
    expect(sixWithOnline.online_periods).toEqual([ONLINE_SLOT_IDX]);
    expect(partitionPeriods(sixWithOnline).regularPeriods).toHaveLength(6);
    expect(partitionPeriods(sixWithOnline).onlinePeriod?.idx).toBe(ONLINE_SLOT_IDX);

    // Switching back to 7-Slot preserves Online Slot enabled and restores P7 regular on-campus (idx 7)
    const sevenWithOnline = setRegularSlotCount(sixWithOnline, 7);
    expect(partitionPeriods(sevenWithOnline).regularPeriods).toHaveLength(7);
    expect(sevenWithOnline.allow_online_periods).toBe(true);
    expect(partitionPeriods(sevenWithOnline).onlinePeriod?.idx).toBe(ONLINE_SLOT_IDX);

    // Turning Online Slot OFF leaves 7 regular P1..P7 intact
    const sevenNoOnline = setOnlineSlotEnabled(sevenWithOnline, false);
    expect(sevenNoOnline.allow_online_periods).toBe(false);
    expect(partitionPeriods(sevenNoOnline).regularPeriods).toHaveLength(7);
    expect(partitionPeriods(sevenNoOnline).onlinePeriod).toBeNull();
  });
});
