import { z } from "zod";
import { RoomIdentity } from "@/core/utils/roomIdentity";
import type {
  EngineConfigPayload,
  EngineSourceContract,
  EngineValidation,
  RoutineRow,
} from "@/features/routine/types";

const MAX_PROFILE_BYTES = 1024 * 1024;
const HH_MM_REGEX = /^([01]\d|2[0-3]):[0-5]\d$/;

const CRC32_TABLE = (() => {
  const table = new Uint32Array(256);
  for (let i = 0; i < 256; i++) {
    let c = i;
    for (let k = 0; k < 8; k++) {
      c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    }
    table[i] = c >>> 0;
  }
  return table;
})();

/**
 * Unsigned 32-bit IEEE CRC32 matching Dart `archive` `getCrc32()`.
 */
export function crc32(bytes: Uint8Array): number {
  let crc = 0xffffffff;
  for (let i = 0; i < bytes.length; i++) {
    crc = CRC32_TABLE[(crc ^ bytes[i]!) & 0xff]! ^ (crc >>> 8);
  }
  return (crc ^ 0xffffffff) >>> 0;
}

function clockToMinutes(value: string): number {
  const [h, m] = value.split(":").map((part) => Number.parseInt(part, 10));
  return (h ?? 0) * 60 + (m ?? 0);
}

const ProfilePeriodSchema = z.object({
  idx: z.number().int(),
  col: z.string().regex(/^[A-Z]+$/, "Period columns must be uppercase letters."),
  start: z.string().regex(HH_MM_REGEX, "Use explicit 24-hour HH:MM clocks."),
  end: z.string().regex(HH_MM_REGEX, "Use explicit 24-hour HH:MM clocks."),
  label: z.string().optional(),
});

const GenerationProfileSchema = z.object({
  format: z.literal("universe-generation-profile-v1"),
  label: z.string().trim().min(1, "Incomplete run profile label."),
  provenance: z.string().trim().min(1, "Incomplete run profile provenance."),
  source_crc32: z.number().int().nonnegative(),
  source_bytes: z.number().int().nonnegative(),
  meeting_count_policy: z.enum(["distribution", "fixed"]),
  config: z.object({
    rooms: z
      .array(
        z
          .object({
            name: z.string().min(1),
            is_lab: z.boolean().optional(),
            is_gallery: z.boolean().optional(),
            capacity: z.number().int().positive().optional(),
          })
          .passthrough(),
      )
      .min(1, "Run profile needs at least one room."),
    teachers: z.array(z.record(z.string(), z.unknown())),
    days: z.array(z.string()).min(1, "Run profile needs teaching days."),
    room_aliases: z.record(z.string(), z.string()).optional(),
    settings: z
      .object({
        periods: z.array(ProfilePeriodSchema).min(1, "Run profile needs explicit periods."),
        weeks_in_term: z.number().int().min(1, "Run profile needs a positive week-count basis."),
        fixed_sessions_per_week: z.number().int().nullable().optional(),
      })
      .passthrough(),
  }),
});

export type GenerationProfileV1 = z.infer<typeof GenerationProfileSchema>;

export function parseGenerationProfile(text: string): GenerationProfileV1 {
  if (new TextEncoder().encode(text).byteLength > MAX_PROFILE_BYTES) {
    throw new Error("Run profile is too large (max 1 MB).");
  }

  let raw: unknown;
  try {
    raw = JSON.parse(text);
  } catch {
    throw new Error("Run profile is not valid JSON.");
  }

  const parsed = GenerationProfileSchema.safeParse(raw);
  if (!parsed.success) {
    throw new Error(parsed.error.issues[0]?.message ?? "Incomplete run profile.");
  }

  const profile = structuredClone(parsed.data);
  const { periods, weeks_in_term: _weeks, ...restSettings } = profile.config.settings;
  const ids = new Set<number>();
  const cols = new Set<string>();

  for (const p of periods) {
    if (ids.has(p.idx) || cols.has(p.col)) {
      throw new Error("Period identifiers/columns must be explicit and unique.");
    }
    ids.add(p.idx);
    cols.add(p.col);
    if (clockToMinutes(p.end) <= clockToMinutes(p.start)) {
      throw new Error("Periods must end after their start.");
    }
  }

  if (profile.meeting_count_policy === "distribution") {
    restSettings.fixed_sessions_per_week = null;
  } else if (
    typeof profile.config.settings.fixed_sessions_per_week !== "number" ||
    profile.config.settings.fixed_sessions_per_week < 1
  ) {
    throw new Error("Fixed-count policy needs a positive count.");
  }

  const aliases = profile.config.room_aliases ?? {};
  for (const key of Object.keys(aliases)) {
    RoomIdentity.key(key, aliases);
  }

  profile.config.settings = {
    ...profile.config.settings,
    ...restSettings,
  };

  return profile;
}

export function verifyGenerationProfileSource(
  profile: GenerationProfileV1,
  fileBytes: Uint8Array,
): void {
  const actualCrc = crc32(fileBytes);
  if (
    fileBytes.byteLength !== profile.source_bytes ||
    actualCrc !== profile.source_crc32
  ) {
    throw new Error(
      `This run profile belongs to a different distribution file (expected ${profile.source_bytes} bytes / CRC32 ${profile.source_crc32}, got ${fileBytes.byteLength} bytes / CRC32 ${actualCrc}).`,
    );
  }
}

export interface RoutineDraftV1 {
  format: "universe-routine-draft-v1";
  preview_only: true;
  profile_label: string | null;
  provenance: string | null;
  source_contract: EngineSourceContract | null;
  config: EngineConfigPayload | Record<string, unknown> | null;
  validation: EngineValidation | null;
  rows: Array<Record<string, unknown>>;
}

export function buildRoutineDraftPayload({
  rows,
  serviceRows,
  profile,
  sourceContract,
  config,
  validation,
}: {
  rows: readonly RoutineRow[];
  serviceRows: readonly RoutineRow[];
  profile: GenerationProfileV1 | null;
  sourceContract: EngineSourceContract | null;
  config: EngineConfigPayload | Record<string, unknown> | null;
  validation: EngineValidation | null;
}): RoutineDraftV1 {
  const allRows = [...rows, ...serviceRows];
  return {
    format: "universe-routine-draft-v1",
    preview_only: true,
    profile_label: profile?.label ?? null,
    provenance: profile?.provenance ?? null,
    source_contract: sourceContract,
    config,
    validation,
    rows: allRows.map((r) => {
      const teacherCodes = Array.from(
        new Set(
          [
            ...(r.teacher_code ? [r.teacher_code.trim()] : []),
            ...(r.teachers ?? []).map((t) => t.trim()),
          ].filter((t) => t.length > 0),
        ),
      );
      return {
        id: r.id,
        day: r.day,
        time_start: r.time_start,
        time_end: r.time_end,
        subject: r.subject,
        subject_code: r.subject_code,
        teacher_name: r.teacher_name,
        teacher_code: r.teacher_code,
        room: r.room,
        batch: r.batch,
        section: r.section,
        semester: r.semester,
        is_active: r.is_active,
        is_service: r.is_service,
        teachers: teacherCodes,
      };
    }),
  };
}
