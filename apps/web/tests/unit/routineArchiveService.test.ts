import { afterEach, describe, expect, it, vi } from "vitest";
import {
  ARCHIVE_TIMETABLE_RUN_COLUMNS,
  correlateRoutineArchive,
  extractStatsEntries,
  normalizeTimetableObjectKey,
  parseValidationJsonb,
  type TimetableRunRecord,
  type TimetableStorageObject,
} from "@/features/routine/services/routineArchiveService";
import type { RoutineVersionRecord } from "@/features/routine/types";

afterEach(() => {
  vi.restoreAllMocks();
  vi.doUnmock("@/services/supabase");
});

describe("normalizeTimetableObjectKey", () => {
  it("normalizes bare filenames, bucket-prefixed paths, and full Storage URLs", () => {
    expect(normalizeTimetableObjectKey("spring_2026_routine.xlsx")).toBe(
      "spring_2026_routine.xlsx",
    );
    expect(normalizeTimetableObjectKey("./spring_2026_routine.xlsx")).toBe(
      "spring_2026_routine.xlsx",
    );
    expect(normalizeTimetableObjectKey("timetables/spring_2026_routine.xlsx")).toBe(
      "spring_2026_routine.xlsx",
    );
    expect(normalizeTimetableObjectKey("/timetables/nested/spring_2026.xlsx")).toBe(
      "nested/spring_2026.xlsx",
    );
    expect(
      normalizeTimetableObjectKey(
        "https://oqwvxplteqtlrhktsplj.supabase.co/storage/v1/object/public/timetables/spring_2026_routine.xlsx",
      ),
    ).toBe("spring_2026_routine.xlsx");
    expect(
      normalizeTimetableObjectKey(
        "/storage/v1/object/sign/timetables/Spring%202026%20Final.xlsx?token=abc123",
      ),
    ).toBe("Spring 2026 Final.xlsx");
    expect(
      normalizeTimetableObjectKey(
        "https://yxqyrjyzxitrgkhgauli.supabase.co/storage/v1/object/authenticated/timetables/dir/routine.xlsx#frag",
      ),
    ).toBe("dir/routine.xlsx");
  });

  it("returns null for empty or whitespace paths", () => {
    expect(normalizeTimetableObjectKey(null)).toBeNull();
    expect(normalizeTimetableObjectKey(undefined)).toBeNull();
    expect(normalizeTimetableObjectKey("")).toBeNull();
    expect(normalizeTimetableObjectKey("   ")).toBeNull();
  });
});

describe("correlateRoutineArchive (43-file / 23-run / 6-version cardinality)", () => {
  it("correlates versions, runs within ±5 min, orphan storage files, and manual null-stats rows", () => {
    const baseMs = Date.parse("2026-11-20T10:00:00.000Z");

    // 6 published versions:
    // - ver-1 (active, engine, matches run-1 within 90s + storage file)
    // - ver-2 (engine, matches run-2 within 4m59s + storage file via full URL)
    // - ver-3 (upload, matches run-3 within 2m + storage file via timetables/ prefix)
    // - ver-4 (engine, NO match because run-4 is 6 minutes away -> outside ±5 min)
    // - ver-5 (manual, null/empty stats & validation, no run)
    // - ver-6 (engine, NO match because row_count differs from run-5)
    const versions: RoutineVersionRecord[] = [
      {
        id: "ver-1",
        semester_label: "Spring 2026",
        source: "engine",
        is_active: true,
        row_count: 150,
        stats: { status: "OPTIMAL", solve_ms: 4200 },
        validation: { ok: true },
        notes: "Active version",
        published_at: new Date(baseMs).toISOString(),
        published_by: "admin-1",
        created_at: new Date(baseMs).toISOString(),
      },
      {
        id: "ver-2",
        semester_label: "Autumn 2025",
        source: "engine",
        is_active: false,
        row_count: 140,
        stats: { status: "FEASIBLE" },
        validation: { ok: true },
        notes: null,
        published_at: new Date(baseMs - 86_400_000).toISOString(),
        published_by: "admin-1",
        created_at: new Date(baseMs - 86_400_000).toISOString(),
      },
      {
        id: "ver-3",
        semester_label: "Summer 2025",
        source: "upload",
        is_active: false,
        row_count: 130,
        stats: { rows_imported: 130 },
        validation: { ok: false, errors: ["Clash"] },
        notes: null,
        published_at: new Date(baseMs - 2 * 86_400_000).toISOString(),
        published_by: null,
        created_at: new Date(baseMs - 2 * 86_400_000).toISOString(),
      },
      {
        id: "ver-4",
        semester_label: "Spring 2025",
        source: "engine",
        is_active: false,
        row_count: 120,
        stats: {},
        validation: {},
        notes: "Outside 5-min window",
        published_at: new Date(baseMs - 3 * 86_400_000).toISOString(),
        published_by: null,
        created_at: new Date(baseMs - 3 * 86_400_000).toISOString(),
      },
      {
        id: "ver-5",
        semester_label: "Manual Patch 2025",
        source: "manual",
        is_active: false,
        row_count: 115,
        stats: {},
        validation: {},
        notes: "Manual hotfix",
        published_at: new Date(baseMs - 4 * 86_400_000).toISOString(),
        published_by: "admin-1",
        created_at: new Date(baseMs - 4 * 86_400_000).toISOString(),
      },
      {
        id: "ver-6",
        semester_label: "Fall 2024",
        source: "engine",
        is_active: false,
        row_count: 110,
        stats: {},
        validation: {},
        notes: null,
        published_at: new Date(baseMs - 5 * 86_400_000).toISOString(),
        published_by: null,
        created_at: new Date(baseMs - 5 * 86_400_000).toISOString(),
      },
    ];

    // 23 runs:
    // - 3 matched to ver-1, ver-2, ver-3
    // - 20 unmatched (including run-4 outside ±5m, run-5 wrong row_count, and 18 other runs)
    const runs: TimetableRunRecord[] = [
      {
        id: "run-1",
        semester_label: "Spring 2026",
        file_path: "file_01.xlsx",
        status: "published",
        row_count: 150,
        stats: { status: "OPTIMAL" },
        validation: { ok: true },
        created_by: "admin-1",
        created_at: new Date(baseMs - 90_000).toISOString(), // 1.5m before ver-1
      },
      {
        id: "run-2",
        semester_label: "autumn 2025", // case-insensitive match
        file_path:
          "https://example.supabase.co/storage/v1/object/public/timetables/file_02.xlsx",
        status: "published",
        row_count: 140,
        stats: null,
        validation: null,
        created_by: "admin-1",
        created_at: new Date(baseMs - 86_400_000 + 299_000).toISOString(), // +4m59s
      },
      {
        id: "run-3",
        semester_label: "Summer 2025",
        file_path: "timetables/file_03.xlsx",
        status: "published",
        row_count: 130,
        stats: null,
        validation: null,
        created_by: null,
        created_at: new Date(baseMs - 2 * 86_400_000 - 120_000).toISOString(),
      },
      {
        id: "run-4",
        semester_label: "Spring 2025",
        file_path: "file_04.xlsx",
        status: "generated",
        row_count: 120,
        stats: null,
        validation: null,
        created_by: null,
        created_at: new Date(baseMs - 3 * 86_400_000 - 360_000).toISOString(), // 6m -> outside ±5m
      },
      {
        id: "run-5",
        semester_label: "Fall 2024",
        file_path: "file_05.xlsx",
        status: "generated",
        row_count: 999, // mismatch row_count
        stats: null,
        validation: null,
        created_by: null,
        created_at: new Date(baseMs - 5 * 86_400_000).toISOString(),
      },
      ...Array.from({ length: 18 }, (_, i): TimetableRunRecord => ({
        id: `run-${i + 6}`,
        semester_label: `Draft Run ${i + 6}`,
        file_path: `file_${String(i + 6).padStart(2, "0")}.xlsx`,
        status: "generated",
        row_count: 100 + i,
        stats: null,
        validation: null,
        created_by: null,
        created_at: new Date(baseMs - (i + 10) * 86_400_000).toISOString(),
      })),
    ];

    // 43 storage files: 23 linked to runs (3 via versions + 20 via unmatched runs) + 20 orphan storage-only
    const storageFiles: TimetableStorageObject[] = Array.from(
      { length: 43 },
      (_, i) => ({
        id: `obj-${i + 1}`,
        name: `file_${String(i + 1).padStart(2, "0")}.xlsx`,
        created_at: new Date(baseMs - i * 3_600_000).toISOString(),
        updated_at: new Date(baseMs - i * 3_600_000).toISOString(),
        size_bytes: 40_000 + i * 100,
        mimetype:
          "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      }),
    );

    const dataset = correlateRoutineArchive({
      versions,
      runs,
      storageFiles,
      profilesById: {
        "admin-1": { id: "admin-1", name: "Dr. Committee Chair", email: "chair@lus.ac.bd" },
      },
    });

    // 6 versions + 20 unmatched runs + 20 orphan storage files = 46 total items
    expect(dataset.counts.versions).toBe(6);
    expect(dataset.counts.runs).toBe(20);
    expect(dataset.counts.storageOnly).toBe(20);
    expect(dataset.counts.all).toBe(46);
    expect(dataset.counts.withXlsx).toBe(43);

    // Active version is sorted first
    expect(dataset.items[0]?.id).toBe("version:ver-1");
    expect(dataset.items[0]?.isActive).toBe(true);
    expect(dataset.items[0]?.hasXlsx).toBe(true);
    expect(dataset.items[0]?.objectKey).toBe("file_01.xlsx");
    expect(dataset.items[0]?.actorName).toBe("Dr. Committee Chair");

    // Manual null-stats row preserved cleanly
    const manualItem = dataset.items.find((i) => i.id === "version:ver-5");
    expect(manualItem?.source).toBe("manual");
    expect(manualItem?.stats).toBeNull();
    expect(manualItem?.validation).toBeNull();
    expect(manualItem?.hasXlsx).toBe(false);

    // System / Legacy fallback for null actor
    const legacyUpload = dataset.items.find((i) => i.id === "version:ver-3");
    expect(legacyUpload?.actorName).toBe("System / Legacy");
    expect(legacyUpload?.objectKey).toBe("file_03.xlsx");

    // Orphan storage-only item
    const orphan = dataset.items.find((i) => i.id === "storage:file_43.xlsx");
    expect(orphan?.category).toBe("storage-only");
    expect(orphan?.source).toBe("storage-only");
    expect(orphan?.hasXlsx).toBe(true);
    expect(orphan?.rowCount).toBeNull();
  });
});

describe("parseValidationJsonb & extractStatsEntries (3 historical schemas)", () => {
  it("handles null / empty manual payloads safely", () => {
    expect(parseValidationJsonb(null)).toEqual({
      variant: "empty",
      ok: null,
      issueCount: 0,
      metrics: [],
      details: [],
      sourceContract: null,
    });
    expect(extractStatsEntries(null)).toEqual([]);
  });

  it("parses legacy 4-key upload validation with ok === false issues", () => {
    const parsed = parseValidationJsonb({
      ok: false,
      row_count: 124,
      warnings: 2,
      errors: ["Room RAB-304 double-booked"],
    });
    expect(parsed.variant).toBe("legacy-upload");
    expect(parsed.ok).toBe(false);
    expect(parsed.issueCount).toBe(1);
    expect(parsed.metrics.map((m) => m.key)).toEqual([
      "row_count",
      "warnings",
      "errors",
    ]);
    expect(parsed.details).toHaveLength(1);
    expect(parsed.details[0]?.key).toBe("errors");
  });

  it("parses mid-2026 10-key Flutter engine validation", () => {
    const parsed = parseValidationJsonb({
      ok: true,
      teacher_clashes: 0,
      room_clashes: 0,
      cohort_clashes: 0,
      missing_courses: 0,
      under_scheduled: 0,
      over_scheduled: 0,
      dayoff_violations: 0,
      blocked_period_violations: 0,
      lab_room_violations: 0,
    });
    expect(parsed.variant).toBe("engine-v1");
    expect(parsed.ok).toBe(true);
    expect(parsed.issueCount).toBe(0);
    expect(parsed.metrics).toHaveLength(9);
  });

  it("parses current 28-key v2 engine validation with expandable details and source_contract", () => {
    const parsed = parseValidationJsonb({
      ok: false,
      required_offerings: 84,
      scheduled_offerings: 83,
      missing_courses: 1,
      teacher_clashes: 2,
      same_day_rule: "enforced",
      pending_faculty_assignments: 0,
      source_contract: { source_sha256: "abc123", revision: 2 },
      details: {
        teacher_clashes: [
          { teacher: "EBH", day: "Sunday", period: 2 },
          { teacher: "MSR", day: "Monday", period: 3 },
        ],
      },
    });
    expect(parsed.variant).toBe("engine-v2");
    expect(parsed.ok).toBe(false);
    expect(parsed.issueCount).toBe(3); // 1 missing_courses + 2 teacher_clashes
    expect(parsed.sourceContract).toEqual({ source_sha256: "abc123", revision: 2 });
    expect(parsed.details).toHaveLength(1);
    expect(parsed.details[0]?.items).toHaveLength(2);
  });
});

describe("fetchRoutineArchive Supabase query contracts", () => {
  it("selects only valid timetable_runs columns and does not select source or notes", async () => {
    const selectedColumns = ARCHIVE_TIMETABLE_RUN_COLUMNS.split(",").map((c) =>
      c.trim(),
    );
    expect(selectedColumns).not.toContain("source");
    expect(selectedColumns).not.toContain("notes");
    expect(selectedColumns).toEqual([
      "id",
      "semester_label",
      "file_path",
      "status",
      "row_count",
      "stats",
      "validation",
      "created_by",
      "created_at",
    ]);

    vi.resetModules();

    const selectCallsByTable: Record<string, string> = {};
    const makeTableBuilder = (table: string) => ({
      select: (columns: string) => {
        selectCallsByTable[table] = columns;
        return {
          order: () => ({
            limit: async () => ({ data: [], error: null }),
          }),
          in: async () => ({ data: [], error: null }),
        };
      },
    });

    vi.doMock("@/services/supabase", () => ({
      isSupabaseConfigured: true,
      supabase: {
        from: (table: string) => makeTableBuilder(table),
        storage: {
          from: () => ({
            list: async () => ({ data: [], error: null }),
          }),
        },
      },
    }));

    const mod = await import(
      "@/features/routine/services/routineArchiveService"
    );
    const dataset = await mod.fetchRoutineArchive(false);

    expect(dataset.isPreviewFixture).toBe(false);
    const runSelect = selectCallsByTable.timetable_runs;
    expect(runSelect).toBeDefined();
    const runSelectCols = runSelect!.split(",").map((c) => c.trim());
    expect(runSelectCols).not.toContain("source");
    expect(runSelectCols).not.toContain("notes");
    expect(runSelectCols).toEqual([
      "id",
      "semester_label",
      "file_path",
      "status",
      "row_count",
      "stats",
      "validation",
      "created_by",
      "created_at",
    ]);
  });
});
