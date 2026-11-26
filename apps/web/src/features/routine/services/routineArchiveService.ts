import type { RoutineVersionRecord } from "@/features/routine/types";
import { isSupabaseConfigured, supabase } from "@/services/supabase";

export const ARCHIVE_ROUTINE_VERSION_COLUMNS =
  "id, semester_label, source, is_active, row_count, stats, validation, notes, published_at, published_by, created_at";

export const ARCHIVE_TIMETABLE_RUN_COLUMNS =
  "id, semester_label, file_path, status, row_count, stats, validation, created_by, created_at";

export const ARCHIVE_PROFILE_COLUMNS = "id, name, email";

export const ROUTINE_ARCHIVE_QUERY_KEY = ["admin-routine-archive"] as const;

const CORRELATION_WINDOW_MS = 5 * 60 * 1000; // ±5 minutes

export type ArchiveSource = "engine" | "upload" | "manual" | "storage-only";
export type ArchiveCategory = "version" | "run" | "storage-only";

export interface TimetableRunRecord {
  id: string;
  semester_label: string | null;
  file_path: string | null;
  status: string | null;
  row_count: number | null;
  stats: Record<string, unknown> | null;
  validation: Record<string, unknown> | null;
  created_by: string | null;
  created_at: string;
}

export interface TimetableStorageObject {
  id: string | null;
  name: string;
  created_at: string | null;
  updated_at: string | null;
  size_bytes: number | null;
  mimetype: string | null;
}

export interface ProfileSummary {
  id: string;
  name: string | null;
  email: string | null;
}

export interface RoutineArchiveItem {
  id: string;
  category: ArchiveCategory;
  source: ArchiveSource;
  isActive: boolean;
  semesterLabel: string;
  rowCount: number | null;
  timestamp: string | null;
  actorName: string;
  actorId: string | null;
  notes: string | null;
  objectKey: string | null;
  fileName: string | null;
  fileSizeBytes: number | null;
  hasXlsx: boolean;
  stats: Record<string, unknown> | null;
  validation: Record<string, unknown> | null;
  version: RoutineVersionRecord | null;
  run: TimetableRunRecord | null;
  storageFile: TimetableStorageObject | null;
}

export interface RoutineArchiveCounts {
  all: number;
  versions: number;
  runs: number;
  storageOnly: number;
  withXlsx: number;
}

export interface RoutineArchiveDataset {
  items: RoutineArchiveItem[];
  counts: RoutineArchiveCounts;
  isPreviewFixture: boolean;
}

export type ValidationSchemaVariant =
  | "empty"
  | "legacy-upload"
  | "engine-v1"
  | "engine-v2";

export interface ValidationMetricEntry {
  key: string;
  label: string;
  value: string | number | boolean;
  isIssue: boolean;
}

export interface ValidationDetailGroup {
  key: string;
  label: string;
  items: Array<Record<string, unknown>>;
}

export interface ParsedValidationSummary {
  variant: ValidationSchemaVariant;
  ok: boolean | null;
  issueCount: number;
  metrics: ValidationMetricEntry[];
  details: ValidationDetailGroup[];
  sourceContract: Record<string, unknown> | null;
}

/**
 * Normalizes any `timetable_runs.file_path` representation (bare filename,
 * `timetables/...` prefix, or full `/storage/v1/object/{public|sign|authenticated}/timetables/...` URL)
 * to the exact Supabase Storage object key inside the `timetables` bucket.
 */
export function normalizeTimetableObjectKey(
  filePath: string | null | undefined,
): string | null {
  if (!filePath) return null;
  let cleaned = filePath.trim();
  if (!cleaned) return null;

  // Strip query string and fragment if present (e.g. signed URLs)
  const qIdx = cleaned.indexOf("?");
  if (qIdx !== -1) cleaned = cleaned.slice(0, qIdx);
  const hIdx = cleaned.indexOf("#");
  if (hIdx !== -1) cleaned = cleaned.slice(0, hIdx);

  // Extract key after `/storage/v1/object/<mode>/timetables/`
  const storageMarker = /\/storage\/v1\/object\/(?:public|sign|authenticated)\/timetables\/(.+)$/i;
  const storageMatch = cleaned.match(storageMarker);
  if (storageMatch && storageMatch[1]) {
    cleaned = storageMatch[1];
  } else {
    // Strip leading slashes or `./`
    cleaned = cleaned.replace(/^(?:\.\/|\/)+/, "");
    // Strip leading `timetables/` bucket prefix if present
    cleaned = cleaned.replace(/^timetables\//i, "");
  }

  // Safely decode URI components (e.g. `%20` -> space)
  try {
    cleaned = decodeURIComponent(cleaned);
  } catch {
    // Keep as-is if malformed percent-encoding
  }

  cleaned = cleaned.replace(/^\/+/, "").trim();
  return cleaned.length > 0 ? cleaned : null;
}

function normalizeSource(raw: string | null | undefined): ArchiveSource {
  const lower = (raw ?? "").trim().toLowerCase();
  if (lower === "engine" || lower === "upload" || lower === "manual") {
    return lower;
  }
  return "engine";
}

function normalizeSemesterKey(raw: string | null | undefined): string {
  return (raw ?? "").trim().toLowerCase();
}

function toEpochMs(iso: string | null | undefined): number | null {
  if (!iso) return null;
  const ms = Date.parse(iso);
  return Number.isFinite(ms) ? ms : null;
}

function resolveActorName(
  actorId: string | null | undefined,
  profilesById: Readonly<Record<string, ProfileSummary>>,
): string {
  if (!actorId) return "System / Legacy";
  const profile = profilesById[actorId];
  if (!profile) return "System / Legacy";
  const name = profile.name?.trim();
  if (name) return name;
  const email = profile.email?.trim();
  if (email) return email;
  return "System / Legacy";
}

function extractFileName(objectKey: string | null): string | null {
  if (!objectKey) return null;
  const parts = objectKey.split("/");
  return parts[parts.length - 1] || objectKey;
}

function isPlainRecord(val: unknown): val is Record<string, unknown> {
  return typeof val === "object" && val !== null && !Array.isArray(val);
}

/**
 * Deterministically correlates `routine_versions`, `timetable_runs`, and
 * `timetables` Storage objects:
 * - Links a run to a version ONLY when `semester_label` and `row_count` match
 *   within `±5 min` (picking the closest timestamp deterministically).
 * - Matches normalized `file_path` keys against Storage objects.
 * - Preserves unmatched runs and orphan Storage `.xlsx` files truthfully.
 */
export function correlateRoutineArchive(params: {
  versions: readonly RoutineVersionRecord[];
  runs: readonly TimetableRunRecord[];
  storageFiles: readonly TimetableStorageObject[];
  profilesById?: Readonly<Record<string, ProfileSummary>>;
  isPreviewFixture?: boolean;
}): RoutineArchiveDataset {
  const {
    versions,
    runs,
    storageFiles,
    profilesById = {},
    isPreviewFixture = false,
  } = params;

  // Filter out storage placeholder entries
  const validStorageFiles = storageFiles.filter(
    (f) => f.name && f.name !== ".emptyFolderPlaceholder",
  );

  const storageByKey = new Map<string, TimetableStorageObject>();
  for (const file of validStorageFiles) {
    const key = normalizeTimetableObjectKey(file.name);
    if (key) {
      storageByKey.set(key, file);
    }
  }

  const matchedRunIds = new Set<string>();
  const matchedStorageKeys = new Set<string>();

  const items: RoutineArchiveItem[] = [];

  // 1. Process Published Versions and deterministically link matching runs
  for (const version of versions) {
    const vSem = normalizeSemesterKey(version.semester_label);
    const vTime = toEpochMs(version.published_at ?? version.created_at);

    let bestRun: TimetableRunRecord | null = null;
    let bestDelta = Number.POSITIVE_INFINITY;

    if (vTime !== null) {
      for (const run of runs) {
        if (matchedRunIds.has(run.id)) continue;
        if (run.row_count !== version.row_count) continue;
        if (normalizeSemesterKey(run.semester_label) !== vSem) continue;

        const rTime = toEpochMs(run.created_at);
        if (rTime === null) continue;

        const delta = Math.abs(rTime - vTime);
        if (delta <= CORRELATION_WINDOW_MS) {
          if (
            delta < bestDelta ||
            (delta === bestDelta && bestRun && run.id.localeCompare(bestRun.id) < 0)
          ) {
            bestDelta = delta;
            bestRun = run;
          }
        }
      }
    }

    if (bestRun) {
      matchedRunIds.add(bestRun.id);
    }

    const rawKey = normalizeTimetableObjectKey(bestRun?.file_path);
    const storageFile = rawKey ? (storageByKey.get(rawKey) ?? null) : null;
    if (rawKey && storageFile) {
      matchedStorageKeys.add(rawKey);
    }

    const actorId = version.published_by ?? bestRun?.created_by ?? null;
    const stats =
      isPlainRecord(version.stats) && Object.keys(version.stats).length > 0
        ? version.stats
        : isPlainRecord(bestRun?.stats) && Object.keys(bestRun.stats).length > 0
          ? bestRun.stats
          : null;
    const validation =
      isPlainRecord(version.validation) && Object.keys(version.validation).length > 0
        ? version.validation
        : isPlainRecord(bestRun?.validation) &&
            Object.keys(bestRun.validation).length > 0
          ? bestRun.validation
          : null;

    items.push({
      id: `version:${version.id}`,
      category: "version",
      source: normalizeSource(version.source),
      isActive: Boolean(version.is_active),
      semesterLabel: version.semester_label?.trim() || "Untitled Semester",
      rowCount: version.row_count,
      timestamp: version.published_at ?? version.created_at,
      actorName: resolveActorName(actorId, profilesById),
      actorId,
      notes: version.notes ?? null,
      objectKey: storageFile ? rawKey : null,
      fileName: storageFile ? extractFileName(rawKey) : null,
      fileSizeBytes: storageFile?.size_bytes ?? null,
      hasXlsx: Boolean(storageFile && rawKey),
      stats,
      validation,
      version,
      run: bestRun,
      storageFile,
    });
  }

  // 2. Process Unmatched Runs
  for (const run of runs) {
    if (matchedRunIds.has(run.id)) continue;

    const rawKey = normalizeTimetableObjectKey(run.file_path);
    const storageFile = rawKey ? (storageByKey.get(rawKey) ?? null) : null;
    if (rawKey && storageFile) {
      matchedStorageKeys.add(rawKey);
    }

    const stats =
      isPlainRecord(run.stats) && Object.keys(run.stats).length > 0
        ? run.stats
        : null;
    const validation =
      isPlainRecord(run.validation) && Object.keys(run.validation).length > 0
        ? run.validation
        : null;

    items.push({
      id: `run:${run.id}`,
      category: "run",
      source: "engine",
      isActive: false,
      semesterLabel: run.semester_label?.trim() || "Unlabeled Run",
      rowCount: run.row_count,
      timestamp: run.created_at,
      actorName: resolveActorName(run.created_by, profilesById),
      actorId: run.created_by,
      notes: null,
      objectKey: storageFile ? rawKey : null,
      fileName: storageFile ? extractFileName(rawKey) : null,
      fileSizeBytes: storageFile?.size_bytes ?? null,
      hasXlsx: Boolean(storageFile && rawKey),
      stats,
      validation,
      version: null,
      run,
      storageFile,
    });
  }

  // 3. Process Orphan Storage Files
  for (const file of validStorageFiles) {
    const key = normalizeTimetableObjectKey(file.name);
    if (!key || matchedStorageKeys.has(key)) continue;

    items.push({
      id: `storage:${key}`,
      category: "storage-only",
      source: "storage-only",
      isActive: false,
      semesterLabel: extractFileName(key) ?? key,
      rowCount: null,
      timestamp: file.updated_at ?? file.created_at,
      actorName: "System / Legacy",
      actorId: null,
      notes: null,
      objectKey: key,
      fileName: extractFileName(key),
      fileSizeBytes: file.size_bytes,
      hasXlsx: true,
      stats: null,
      validation: null,
      version: null,
      run: null,
      storageFile: file,
    });
  }

  // Deterministic sort: Active version first, then newest timestamp, then id
  items.sort((a, b) => {
    if (a.isActive !== b.isActive) return a.isActive ? -1 : 1;
    const tA = toEpochMs(a.timestamp) ?? 0;
    const tB = toEpochMs(b.timestamp) ?? 0;
    if (tA !== tB) return tB - tA;
    return a.id.localeCompare(b.id);
  });

  const counts: RoutineArchiveCounts = {
    all: items.length,
    versions: items.filter((i) => i.category === "version").length,
    runs: items.filter((i) => i.category === "run").length,
    storageOnly: items.filter((i) => i.category === "storage-only").length,
    withXlsx: items.filter((i) => i.hasXlsx).length,
  };

  return {
    items,
    counts,
    isPreviewFixture,
  };
}

const VIOLATION_KEY_PATTERN =
  /(clash|violation|missing|under_scheduled|over_scheduled|unexpected|ineligible|unplaced|invalid|mismatch|unknown|unresolved|error)/i;

export function formatMetricLabel(key: string): string {
  return key
    .replace(/_/g, " ")
    .replace(/\b\w/g, (ch) => ch.toUpperCase());
}

/**
 * Defensively parses all 3 historical `validation` JSONB schemas:
 * 1. Legacy 4-key upload (`ok`, `row_count`, `warnings`, `errors`)
 * 2. Mid-2026 9–12-key Flutter engine
 * 3. Current 28-key v2 engine (with expandable `details` and `source_contract`)
 * plus null/empty `manual` rows.
 */
export function parseValidationJsonb(
  validation: Record<string, unknown> | null | undefined,
): ParsedValidationSummary {
  if (!isPlainRecord(validation) || Object.keys(validation).length === 0) {
    return {
      variant: "empty",
      ok: null,
      issueCount: 0,
      metrics: [],
      details: [],
      sourceContract: null,
    };
  }

  const keys = Object.keys(validation);
  const ok = typeof validation.ok === "boolean" ? validation.ok : null;

  let variant: ValidationSchemaVariant = "legacy-upload";
  if (
    "details" in validation ||
    "source_contract" in validation ||
    "same_day_rule" in validation ||
    "pending_faculty_assignments" in validation ||
    keys.length >= 16
  ) {
    variant = "engine-v2";
  } else if (
    keys.length >= 7 ||
    "teacher_clashes" in validation ||
    "room_clashes" in validation
  ) {
    variant = "engine-v1";
  }

  const metrics: ValidationMetricEntry[] = [];
  const details: ValidationDetailGroup[] = [];
  let issueCount = 0;
  let sourceContract: Record<string, unknown> | null = null;

  for (const [key, rawVal] of Object.entries(validation)) {
    if (key === "ok") continue;

    if (key === "source_contract" && isPlainRecord(rawVal)) {
      sourceContract = rawVal;
      continue;
    }

    if (key === "details" && isPlainRecord(rawVal)) {
      for (const [dKey, dVal] of Object.entries(rawVal)) {
        if (Array.isArray(dVal) && dVal.length > 0) {
          const normalizedItems = dVal.map((entry) =>
            isPlainRecord(entry) ? entry : { value: entry },
          );
          details.push({
            key: dKey,
            label: formatMetricLabel(dKey),
            items: normalizedItems,
          });
        }
      }
      continue;
    }

    if (Array.isArray(rawVal)) {
      const count = rawVal.length;
      const isIssue = VIOLATION_KEY_PATTERN.test(key) && count > 0;
      if (isIssue) issueCount += count;
      metrics.push({
        key,
        label: formatMetricLabel(key),
        value: count,
        isIssue,
      });
      if (count > 0) {
        details.push({
          key,
          label: formatMetricLabel(key),
          items: rawVal.map((entry) =>
            isPlainRecord(entry) ? entry : { message: String(entry) },
          ),
        });
      }
      continue;
    }

    if (
      typeof rawVal === "number" ||
      typeof rawVal === "string" ||
      typeof rawVal === "boolean"
    ) {
      const isIssue =
        typeof rawVal === "number" &&
        rawVal > 0 &&
        VIOLATION_KEY_PATTERN.test(key);
      if (isIssue) issueCount += rawVal;
      metrics.push({
        key,
        label: formatMetricLabel(key),
        value: rawVal,
        isIssue,
      });
    }
  }

  return {
    variant,
    ok,
    issueCount,
    metrics,
    details,
    sourceContract,
  };
}

export function extractStatsEntries(
  stats: Record<string, unknown> | null | undefined,
): Array<{ key: string; label: string; value: string }> {
  if (!isPlainRecord(stats)) return [];
  const entries: Array<{ key: string; label: string; value: string }> = [];
  for (const [key, raw] of Object.entries(stats)) {
    if (
      typeof raw === "number" ||
      typeof raw === "string" ||
      typeof raw === "boolean"
    ) {
      entries.push({
        key,
        label: formatMetricLabel(key),
        value: String(raw),
      });
    }
  }
  return entries;
}

// ============================================================================
// Dev Preview Illustrative Fixtures (Zero-Network)
// ============================================================================

const DEV_PREVIEW_PROFILES: Record<string, ProfileSummary> = {
  "dev-preview-admin": {
    id: "dev-preview-admin",
    name: "Routine Committee Chair (Preview)",
    email: "committee@lus.ac.bd",
  },
};

const DEV_PREVIEW_VERSIONS: RoutineVersionRecord[] = [
  {
    id: "preview-ver-1",
    semester_label: "Spring 2026 · v2026.2",
    source: "engine",
    is_active: true,
    row_count: 14,
    stats: {
      status: "OPTIMAL",
      solve_ms: 4120,
      meetings: 14,
      service_meetings: 1,
      offerings: 12,
      cohorts: 5,
      teachers: 7,
      objective: 984,
      lab_theory_pairs: 4,
      lab_theory_adjacent: 4,
    },
    validation: {
      ok: true,
      required_offerings: 12,
      scheduled_offerings: 12,
      missing_courses: 0,
      under_scheduled: 0,
      over_scheduled: 0,
      unexpected_courses: 0,
      teacher_clashes: 0,
      cohort_clashes: 0,
      room_clashes: 0,
      same_day_sessions: 0,
      ineligible_assignments: 0,
      dayoff_violations: 0,
      blocked_period_violations: 0,
      lab_room_violations: 0,
      unplaced_rooms: 0,
      lab_theory_violations: 0,
      invalid_time_slots: 0,
      invalid_days: 0,
      teacher_assignment_mismatches: 0,
      unknown_rooms: 0,
      room_capacity_violations: 0,
      unresolved_teachers: 0,
      pending_faculty_assignments: 0,
      same_day_rule: "enforced",
      lab_theory_pairs: 4,
      lab_theory_adjacent: 4,
      details: {},
    },
    notes: "Active committee-approved Spring 2026 schedule (preview fixture).",
    published_at: "2026-11-20T09:30:00.000Z",
    published_by: "dev-preview-admin",
    created_at: "2026-11-20T09:30:00.000Z",
  },
  {
    id: "preview-ver-2",
    semester_label: "Autumn 2025 · v2025.4",
    source: "engine",
    is_active: false,
    row_count: 138,
    stats: { status: "FEASIBLE", solve_ms: 11840, meetings: 138, cohorts: 14 },
    validation: {
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
    },
    notes: "Mid-2026 Flutter engine publish.",
    published_at: "2026-07-12T11:15:00.000Z",
    published_by: "dev-preview-admin",
    created_at: "2026-07-12T11:15:00.000Z",
  },
  {
    id: "preview-ver-3",
    semester_label: "Summer 2025 · Legacy Upload",
    source: "upload",
    is_active: false,
    row_count: 124,
    stats: { sheets_parsed: 3, rows_imported: 124 },
    validation: {
      ok: false,
      row_count: 124,
      warnings: 2,
      errors: ["Room RAB-304 double-booked on Monday P2 (CSE-2201 / CSE-3101)"],
    },
    notes: "Imported from committee Excel workbook.",
    published_at: "2026-03-04T08:00:00.000Z",
    published_by: null,
    created_at: "2026-03-04T08:00:00.000Z",
  },
  {
    id: "preview-ver-4",
    semester_label: "Spring 2025 · Manual Patch",
    source: "manual",
    is_active: false,
    row_count: 118,
    stats: {},
    validation: {},
    notes: "Manual committee hotfix for Friday Jummah slot.",
    published_at: "2026-01-18T14:20:00.000Z",
    published_by: "dev-preview-admin",
    created_at: "2026-01-18T14:20:00.000Z",
  },
];

const DEV_PREVIEW_RUNS: TimetableRunRecord[] = [
  {
    id: "preview-run-1",
    semester_label: "Spring 2026 · v2026.2",
    file_path: "timetables/spring_2026_v2026_2_routine.xlsx",
    status: "published",
    row_count: 14,
    stats: DEV_PREVIEW_VERSIONS[0]!.stats,
    validation: DEV_PREVIEW_VERSIONS[0]!.validation,
    created_by: "dev-preview-admin",
    created_at: "2026-11-20T09:29:30.000Z",
  },
  {
    id: "preview-run-2",
    semester_label: "Spring 2026 · Dry Run Draft",
    file_path: "spring_2026_dry_run_draft.xlsx",
    status: "generated",
    row_count: 142,
    stats: { status: "OPTIMAL", solve_ms: 9420, meetings: 142 },
    validation: {
      ok: false,
      teacher_clashes: 1,
      room_clashes: 0,
      cohort_clashes: 0,
      details: {
        teacher_clashes: [
          {
            teacher: "EBH",
            day: "Sunday",
            period: 2,
            courses: "CSE-3101 vs CSE-4101",
          },
        ],
      },
    },
    created_by: "dev-preview-admin",
    created_at: "2026-11-19T16:40:00.000Z",
  },
];

const DEV_PREVIEW_STORAGE: TimetableStorageObject[] = [
  {
    id: "obj-1",
    name: "spring_2026_v2026_2_routine.xlsx",
    created_at: "2026-11-20T09:29:28.000Z",
    updated_at: "2026-11-20T09:29:28.000Z",
    size_bytes: 48120,
    mimetype:
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
  },
  {
    id: "obj-2",
    name: "spring_2026_dry_run_draft.xlsx",
    created_at: "2026-11-19T16:39:55.000Z",
    updated_at: "2026-11-19T16:39:55.000Z",
    size_bytes: 51904,
    mimetype:
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
  },
  {
    id: "obj-3",
    name: "legacy_fall_2024_final_committee.xlsx",
    created_at: "2025-09-10T10:12:00.000Z",
    updated_at: "2025-09-10T10:12:00.000Z",
    size_bytes: 63488,
    mimetype:
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
  },
];

export async function fetchRoutineArchive(
  isDevPreview: boolean,
): Promise<RoutineArchiveDataset> {
  if (isDevPreview || !isSupabaseConfigured || !supabase) {
    return correlateRoutineArchive({
      versions: DEV_PREVIEW_VERSIONS,
      runs: DEV_PREVIEW_RUNS,
      storageFiles: DEV_PREVIEW_STORAGE,
      profilesById: DEV_PREVIEW_PROFILES,
      isPreviewFixture: true,
    });
  }

  const [versionsRes, runsRes, storageRes] = await Promise.all([
    supabase
      .from("routine_versions")
      .select(ARCHIVE_ROUTINE_VERSION_COLUMNS)
      .order("created_at", { ascending: false })
      .limit(50),
    supabase
      .from("timetable_runs")
      .select(ARCHIVE_TIMETABLE_RUN_COLUMNS)
      .order("created_at", { ascending: false })
      .limit(50),
    supabase.storage.from("timetables").list("", {
      limit: 100,
      sortBy: { column: "created_at", order: "desc" },
    }),
  ]);

  if (versionsRes.error) {
    throw new Error(`Failed to load routine versions: ${versionsRes.error.message}`);
  }
  if (runsRes.error) {
    throw new Error(`Failed to load timetable runs: ${runsRes.error.message}`);
  }
  if (storageRes.error) {
    throw new Error(`Failed to list timetables storage: ${storageRes.error.message}`);
  }

  const versions = (versionsRes.data ?? []) as RoutineVersionRecord[];
  const runs = (runsRes.data ?? []) as TimetableRunRecord[];
  const storageFiles: TimetableStorageObject[] = (storageRes.data ?? []).map(
    (obj) => {
      const meta = isPlainRecord(obj.metadata) ? obj.metadata : null;
      const sizeVal = meta && typeof meta.size === "number" ? meta.size : null;
      const mimeVal =
        meta && typeof meta.mimetype === "string" ? meta.mimetype : null;
      return {
        id: obj.id ?? null,
        name: obj.name,
        created_at: obj.created_at ?? null,
        updated_at: obj.updated_at ?? null,
        size_bytes: sizeVal,
        mimetype: mimeVal,
      };
    },
  );

  // Single bounded profiles lookup for all unique actor UUIDs
  const actorIds = Array.from(
    new Set(
      [
        ...versions.map((v) => v.published_by),
        ...runs.map((r) => r.created_by),
      ].filter((id): id is string => typeof id === "string" && id.trim().length > 0),
    ),
  );

  const profilesById: Record<string, ProfileSummary> = {};
  if (actorIds.length > 0) {
    const { data: profilesData } = await supabase
      .from("profiles")
      .select(ARCHIVE_PROFILE_COLUMNS)
      .in("id", actorIds);

    for (const row of (profilesData ?? []) as ProfileSummary[]) {
      profilesById[row.id] = row;
    }
  }

  return correlateRoutineArchive({
    versions,
    runs,
    storageFiles,
    profilesById,
    isPreviewFixture: false,
  });
}

/**
 * Streams a direct `.xlsx` download from Supabase Storage (`timetables` bucket).
 * Never proxies through the Render engine.
 */
export async function downloadArchiveWorkbook(
  objectKey: string,
  fileName: string,
  isDevPreview: boolean,
): Promise<void> {
  const normalizedKey = normalizeTimetableObjectKey(objectKey);
  if (!normalizedKey) {
    throw new Error("Invalid workbook storage path.");
  }

  let blob: Blob;
  if (isDevPreview || !isSupabaseConfigured || !supabase) {
    blob = new Blob(
      [`UniVerse Dev Preview illustrative workbook placeholder: ${normalizedKey}\n`],
      {
        type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      },
    );
  } else {
    const { data, error } = await supabase.storage
      .from("timetables")
      .download(normalizedKey);
    if (error || !data) {
      throw new Error(error?.message || "Unable to download workbook from Storage.");
    }
    blob = data;
  }

  const url = URL.createObjectURL(blob);
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = fileName || extractFileName(normalizedKey) || "routine.xlsx";
  document.body.appendChild(anchor);
  anchor.click();
  anchor.remove();
  window.setTimeout(() => URL.revokeObjectURL(url), 1000);
}
