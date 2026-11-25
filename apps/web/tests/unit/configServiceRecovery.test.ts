import { afterEach, describe, expect, it, vi } from "vitest";

describe("Phase 2A Supabase error transparency (zero silent failure)", () => {
  afterEach(() => {
    vi.doUnmock("@/services/supabase");
  });

  it("surfaces 400/403/409/500 errors from rooms, faculty, eligibility, and settings services", async () => {
    vi.resetModules();

    vi.doMock("@/services/supabase", () => ({
      isSupabaseConfigured: true,
      supabase: {
        from: (table: string) => {
          if (table === "timetable_rooms") {
            return {
              select: () => ({
                order: () => ({
                  order: async () => ({
                    data: null,
                    error: { status: 403, message: "RLS policy denied room select" },
                  }),
                }),
              }),
              insert: () => ({
                select: () => ({
                  single: async () => ({
                    data: null,
                    error: { status: 409, message: "duplicate room name RAB-302" },
                  }),
                }),
              }),
            };
          }
          if (table === "timetable_faculty") {
            return {
              select: () => ({
                order: async () => ({
                  data: null,
                  error: { status: 500, message: "database connection reset" },
                }),
              }),
            };
          }
          if (table === "timetable_course_eligibility") {
            return {
              upsert: () => ({
                select: () => ({
                  single: async () => ({
                    data: null,
                    error: { status: 400, message: "invalid priority constraint" },
                  }),
                }),
              }),
            };
          }
          return {
            select: () => ({
              eq: () => ({
                maybeSingle: async () => ({
                  data: null,
                  error: { status: 500, message: "settings read failed" },
                }),
              }),
            }),
          };
        },
      },
    }));

    const roomsMod = await import("@/features/admin/services/roomsService");
    const facultyMod = await import("@/features/admin/services/facultyService");
    const eligMod = await import("@/features/admin/services/eligibilityService");
    const settingsMod = await import("@/features/admin/services/settingsService");

    await expect(roomsMod.fetchRooms(false)).rejects.toThrow(
      /RLS policy denied room select/i,
    );
    await expect(
      roomsMod.createRoom(
        { name: "RAB-302", is_lab: false, is_gallery: false, is_active: true },
        false,
      ),
    ).rejects.toThrow(/duplicate room name RAB-302/i);

    await expect(facultyMod.fetchFaculty(false)).rejects.toThrow(
      /database connection reset/i,
    );

    await expect(
      eligMod.upsertEligibilityRecord(
        { acronym: "MHK", course_code: "CSE-2101", is_eligible: true },
        false,
      ),
    ).rejects.toThrow(/invalid priority constraint/i);

    await expect(settingsMod.fetchTimetableSettings(false)).rejects.toThrow(
      /settings read failed/i,
    );
  });
});
