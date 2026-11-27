import { ClockTime } from "@/core/utils/clockTime";
import { jointSectionsOverlap, RoomIdentity } from "@/core/utils/roomIdentity";
import type {
  RoutineClash,
  RoutineRow,
  RoutineVersionRecord,
  RoutineWriteInput,
} from "@/features/routine/types";
import { isSupabaseConfigured, supabase } from "@/services/supabase";

export const ROUTINE_SELECT_COLUMNS =
  "id, day, time_start, time_end, subject, subject_code, teacher_name, teacher_code, room, batch, section, semester, is_active, is_service, routine_version_id";

export const ROUTINE_EXTENDED_SELECT_COLUMNS = `${ROUTINE_SELECT_COLUMNS}, teacher_codes`;

export const ROUTINE_VERSION_SELECT_COLUMNS =
  "id, semester_label, source, is_active, row_count, stats, validation, notes, published_at, published_by, created_at";

const DAY_ORDER: Record<string, number> = {
  Sunday: 0,
  Monday: 1,
  Tuesday: 2,
  Wednesday: 3,
  Thursday: 4,
  Friday: 5,
  Saturday: 6,
};

export interface RoutineWritePayload {
  day: string;
  time_start: string;
  time_end: string;
  subject: string;
  subject_code: string;
  teacher_name: string | null;
  teacher_code: string | null;
  teacher_codes?: string[];
  room: string;
  batch: string;
  section: string;
  semester: number;
  is_active: boolean;
  is_service: boolean;
  routine_version_id?: string | null;
}

function isMissingTeacherCodesColumnError(err: {
  code?: string;
  message?: string;
} | null): boolean {
  if (!err) return false;
  const code = err.code ?? "";
  const msg = (err.message ?? "").toLowerCase();
  return (
    code === "42703" ||
    code === "PGRST204" ||
    (msg.includes("teacher_codes") && msg.includes("does not exist")) ||
    (msg.includes("teacher_codes") && msg.includes("could not find"))
  );
}

export function toRoutineWritePayload(
  input: RoutineWriteInput,
  includeTeacherCodes = false,
): RoutineWritePayload {
  const timeStart = ClockTime.toHms(input.time_start);
  const timeEnd = ClockTime.toHms(input.time_end);
  const startMin = ClockTime.toMinutes(timeStart);
  const endMin = ClockTime.toMinutes(timeEnd);
  if (startMin === null || endMin === null || endMin <= startMin) {
    throw new Error("End time must be strictly after start time (HH:MM:SS).");
  }

  const subject = input.subject.trim();
  const subjectCode = input.subject_code.trim().toUpperCase();
  const room = input.room.trim().toUpperCase() || "TBA";
  const batch = input.batch.trim();
  const section = input.section.trim().toUpperCase();
  if (!subject || !subjectCode) {
    throw new Error("Course code and title are required.");
  }
  if (!batch || !section) {
    throw new Error("Batch and section are required.");
  }

  const orderedCodes = Array.from(
    new Set(
      [
        ...(input.teacher_codes ?? []),
        ...(input.teacher_code ? [input.teacher_code] : []),
      ]
        .map((c) => c.trim().toUpperCase())
        .filter((c) => c.length > 0),
    ),
  );
  const teacherCode =
    (input.teacher_code?.trim()
      ? input.teacher_code.trim().toUpperCase()
      : orderedCodes[0]) ?? null;
  const teacherName = input.teacher_name?.trim()
    ? input.teacher_name.trim()
    : null;

  return {
    day: input.day.trim(),
    time_start: timeStart,
    time_end: timeEnd,
    subject,
    subject_code: subjectCode,
    teacher_name: teacherName,
    teacher_code: teacherCode,
    ...(includeTeacherCodes ? { teacher_codes: orderedCodes } : {}),
    room,
    batch,
    section,
    semester: Number.isFinite(input.semester) ? Math.max(0, Math.trunc(input.semester)) : 1,
    is_active: Boolean(input.is_active),
    is_service: Boolean(input.is_service),
    ...(input.routine_version_id !== undefined
      ? { routine_version_id: input.routine_version_id }
      : {}),
  };
}

function timesOverlap(
  startA: string,
  endA: string,
  startB: string,
  endB: string,
): boolean {
  const a0 = ClockTime.toMinutes(startA);
  const a1 = ClockTime.toMinutes(endA);
  const b0 = ClockTime.toMinutes(startB);
  const b1 = ClockTime.toMinutes(endB);
  if (a0 === null || a1 === null || b0 === null || b1 === null) {
    return (
      ClockTime.toHm(startA) === ClockTime.toHm(startB) &&
      ClockTime.toHm(endA) === ClockTime.toHm(endB)
    );
  }
  return a0 < b1 && b0 < a1;
}

function normalizedTeacherCodes(row: {
  teacher_code?: string | null;
  teacher_codes?: string[];
  teachers?: string[];
}): string[] {
  const raw = [
    ...(row.teacher_codes ?? []),
    ...(row.teachers ?? []),
    ...(row.teacher_code ? [row.teacher_code] : []),
  ];
  return Array.from(
    new Set(
      raw
        .map((c) => c.trim().toUpperCase())
        .filter(
          (c) =>
            c.length > 0 &&
            c !== "TBA" &&
            c !== "PENDING" &&
            c !== "FACULTY-PENDING",
        ),
    ),
  );
}

/**
 * Client-side pre-save clash detector checking Teacher, Room (ignoring TBA,
 * cycle-safe alias resolution), and Cohort (`B+C` joint section) overlaps.
 */
export function detectRoutineClashes(
  candidate: Pick<
    RoutineWriteInput,
    "day" | "time_start" | "time_end" | "teacher_code" | "room" | "batch" | "section"
  > & { teachers?: string[] },
  existingRows: readonly RoutineRow[],
  ignoreId?: string | null,
  roomAliases: Record<string, string> = {},
): RoutineClash[] {
  const clashes: RoutineClash[] = [];
  const candDay = candidate.day.trim().toLowerCase();
  const candTeachers = normalizedTeacherCodes(candidate);
  const candRoomRaw = candidate.room.trim().toUpperCase();
  const candRoomKey =
    candRoomRaw && candRoomRaw !== "TBA"
      ? RoomIdentity.key(candRoomRaw, roomAliases)
      : null;
  const candBatch = candidate.batch.trim().toUpperCase();

  for (const row of existingRows) {
    if (row.id === ignoreId) continue;
    if (row.is_active === false) continue;
    if (row.day.trim().toLowerCase() !== candDay) continue;
    if (!timesOverlap(candidate.time_start, candidate.time_end, row.time_start, row.time_end)) {
      continue;
    }

    const rowTeachers = normalizedTeacherCodes(row);
    const sharedTeacher = candTeachers.find((t) => rowTeachers.includes(t));
    if (sharedTeacher) {
      clashes.push({
        type: "teacher",
        message: `Teacher clash: ${sharedTeacher} is already assigned to ${row.subject_code} (${row.batch}-${row.section}) at ${ClockTime.toHm(row.time_start)}–${ClockTime.toHm(row.time_end)}.`,
        conflictingRow: row,
      });
    }

    const rowRoomRaw = row.room.trim().toUpperCase();
    if (candRoomKey && rowRoomRaw && rowRoomRaw !== "TBA") {
      const rowRoomKey = RoomIdentity.key(rowRoomRaw, roomAliases);
      if (candRoomKey === rowRoomKey) {
        clashes.push({
          type: "room",
          message: `Room clash: ${row.room} is already occupied by ${row.subject_code} (${row.batch}-${row.section}) at ${ClockTime.toHm(row.time_start)}–${ClockTime.toHm(row.time_end)}.`,
          conflictingRow: row,
        });
      }
    }

    if (
      candBatch &&
      row.batch.trim().toUpperCase() === candBatch &&
      jointSectionsOverlap(candidate.section, row.section)
    ) {
      clashes.push({
        type: "cohort",
        message: `Cohort clash: Batch ${row.batch}-${row.section} already has ${row.subject_code} (${row.room}) at ${ClockTime.toHm(row.time_start)}–${ClockTime.toHm(row.time_end)}.`,
        conflictingRow: row,
      });
    }
  }

  return clashes;
}

export function sortRoutineRows(rows: readonly RoutineRow[]): RoutineRow[] {
  return [...rows].sort((a, b) => {
    const dayDiff = (DAY_ORDER[a.day] ?? 99) - (DAY_ORDER[b.day] ?? 99);
    if (dayDiff !== 0) return dayDiff;
    const tDiff = a.time_start.localeCompare(b.time_start);
    if (tDiff !== 0) return tDiff;
    const bDiff = a.batch.localeCompare(b.batch, undefined, { numeric: true });
    if (bDiff !== 0) return bDiff;
    return a.section.localeCompare(b.section);
  });
}

const initialDevPreviewRoutines: RoutineRow[] = [
  {
    id: "prev-1",
    day: "Sunday",
    time_start: "08:50:00",
    time_end: "10:05:00",
    subject: "Database Management Systems",
    subject_code: "CSE-3101",
    teacher_name: "Md. Ebrahim Hossain",
    teacher_code: "EBH",
    room: "RAB-302",
    batch: "58",
    section: "B+C",
    semester: 6,
    is_active: true,
    is_service: false,
    routine_version_id: "preview-ver-1",
  },
  {
    id: "prev-2",
    day: "Sunday",
    time_start: "10:10:00",
    time_end: "11:25:00",
    subject: "Database Management Systems Sessional",
    subject_code: "CSE-3102",
    teacher_name: "Mohammad Shoaib Rahman",
    teacher_code: "MSR",
    room: "ACL-1",
    batch: "58",
    section: "B",
    semester: 6,
    is_active: true,
    is_service: false,
    is_lab: true,
    routine_version_id: "preview-ver-1",
  },
  {
    id: "prev-3",
    day: "Sunday",
    time_start: "11:30:00",
    time_end: "12:45:00",
    subject: "Database Management Systems Sessional",
    subject_code: "CSE-3102",
    teacher_name: "Mohammad Shoaib Rahman",
    teacher_code: "MSR",
    room: "ACL-1",
    batch: "58",
    section: "C",
    semester: 6,
    is_active: true,
    is_service: false,
    is_lab: true,
    routine_version_id: "preview-ver-1",
  },
  {
    id: "prev-4",
    day: "Sunday",
    time_start: "08:50:00",
    time_end: "10:05:00",
    subject: "Structured Programming Language",
    subject_code: "CSE-1101",
    teacher_name: "Kazi Md. Jahid Hasan",
    teacher_code: "KJH",
    room: "G1",
    batch: "61",
    section: "A",
    semester: 1,
    is_active: true,
    is_service: false,
    routine_version_id: "preview-ver-1",
  },
  {
    id: "prev-5",
    day: "Sunday",
    time_start: "13:10:00",
    time_end: "14:25:00",
    subject: "Algorithms",
    subject_code: "CSE-2201",
    teacher_name: "Sabia Akter Bhuiyan",
    teacher_code: "SAB",
    room: "RAB-304",
    batch: "59",
    section: "A",
    semester: 4,
    is_active: true,
    is_service: false,
    routine_version_id: "preview-ver-1",
  },
  {
    id: "prev-6",
    day: "Sunday",
    time_start: "14:30:00",
    time_end: "15:45:00",
    subject: "Algorithms Sessional",
    subject_code: "CSE-2202",
    teacher_name: "Sabia Akter Bhuiyan",
    teacher_code: "SAB",
    room: "ACL-2",
    batch: "59",
    section: "A",
    semester: 4,
    is_active: true,
    is_service: false,
    is_lab: true,
    routine_version_id: "preview-ver-1",
  },
  {
    id: "prev-7",
    day: "Sunday",
    time_start: "15:50:00",
    time_end: "17:05:00",
    subject: "Physics for Computing",
    subject_code: "PHY-1101",
    teacher_name: "Md. Rashidul Hasan",
    teacher_code: "MRH",
    room: "PHY LAB",
    batch: "61",
    section: "A",
    semester: 1,
    is_active: true,
    is_service: true,
    is_lab: true,
    routine_version_id: "preview-ver-1",
  },
  {
    id: "prev-8",
    day: "Monday",
    time_start: "10:10:00",
    time_end: "11:25:00",
    subject: "Database Management Systems",
    subject_code: "CSE-3101",
    teacher_name: "Md. Ebrahim Hossain",
    teacher_code: "EBH",
    room: "RAB-302",
    batch: "58",
    section: "B+C",
    semester: 6,
    is_active: true,
    is_service: false,
    routine_version_id: "preview-ver-1",
  },
  {
    id: "prev-9",
    day: "Monday",
    time_start: "11:30:00",
    time_end: "12:45:00",
    subject: "Operating Systems",
    subject_code: "CSE-3201",
    teacher_name: "Soumik Paul Jisun",
    teacher_code: "SPJ",
    room: "RKB-401",
    batch: "58",
    section: "A",
    semester: 6,
    is_active: true,
    is_service: false,
    routine_version_id: "preview-ver-1",
  },
  {
    id: "prev-10",
    day: "Tuesday",
    time_start: "08:50:00",
    time_end: "10:05:00",
    subject: "Artificial Intelligence",
    subject_code: "CSE-4101",
    teacher_name: "Kazi Md. Jahid Hasan",
    teacher_code: "KJH",
    room: "RAB-306",
    batch: "56",
    section: "A",
    semester: 8,
    is_active: true,
    is_service: false,
    routine_version_id: "preview-ver-1",
  },
  {
    id: "prev-11",
    day: "Tuesday",
    time_start: "13:10:00",
    time_end: "14:25:00",
    subject: "Digital Logic Design Sessional",
    subject_code: "EEE-2102",
    teacher_name: "Rafiqul Islam",
    teacher_code: "MRI",
    room: "ECL-1",
    batch: "60",
    section: "A",
    semester: 3,
    is_active: true,
    is_service: false,
    is_lab: true,
    routine_version_id: "preview-ver-1",
  },
  {
    id: "prev-12",
    day: "Wednesday",
    time_start: "10:10:00",
    time_end: "11:25:00",
    subject: "Computer Networks",
    subject_code: "CSE-3203",
    teacher_name: "Md. Arifuzzaman",
    teacher_code: "AFZ",
    room: "NL",
    batch: "57",
    section: "A",
    semester: 7,
    is_active: true,
    is_service: false,
    is_lab: true,
    routine_version_id: "preview-ver-1",
  },
  {
    id: "prev-13",
    day: "Friday",
    time_start: "08:50:00",
    time_end: "10:05:00",
    subject: "Software Engineering",
    subject_code: "CSE-3105",
    teacher_name: "Md. Jamaner Rahaman",
    teacher_code: "MJR",
    room: "RAB-304",
    batch: "58",
    section: "A",
    semester: 6,
    is_active: true,
    is_service: false,
    routine_version_id: "preview-ver-1",
  },
  {
    id: "prev-14",
    day: "Friday",
    time_start: "14:30:00",
    time_end: "15:45:00",
    subject: "Operating Systems Sessional",
    subject_code: "CSE-3202",
    teacher_name: "Mohammad Shoaib Rahman",
    teacher_code: "MSR",
    room: "ACL-1",
    batch: "58",
    section: "C",
    semester: 6,
    is_active: true,
    is_service: false,
    is_lab: true,
    routine_version_id: "preview-ver-1",
  },
];

let devPreviewRoutinesStore: RoutineRow[] = structuredClone(initialDevPreviewRoutines);
let devPreviewActiveVersion: RoutineVersionRecord | null = {
  id: "preview-ver-1",
  semester_label: "Spring 2026 · v2026.2",
  source: "engine",
  is_active: true,
  row_count: initialDevPreviewRoutines.length,
  stats: { status: "OPTIMAL", solve_ms: 4120 },
  validation: { ok: true },
  notes: "Local preview snapshot",
  published_at: "2026-11-20T09:30:00.000Z",
  published_by: "dev-preview-admin",
  created_at: "2026-11-20T09:30:00.000Z",
};

export function replaceDevPreviewRoutines(
  rows: readonly RoutineRow[],
  version: RoutineVersionRecord,
): void {
  devPreviewRoutinesStore = structuredClone([...rows]);
  devPreviewActiveVersion = structuredClone(version);
}

export async function isRoutineTeacherCodesLive(
  isDevPreview: boolean,
): Promise<boolean> {
  if (isDevPreview || !isSupabaseConfigured || !supabase) {
    return false;
  }
  try {
    const { error } = await supabase
      .from("routines")
      .select("id, teacher_codes")
      .limit(1);
    return !error;
  } catch {
    return false;
  }
}

export async function fetchRoutines(
  isDevPreview: boolean,
): Promise<RoutineRow[]> {
  if (isDevPreview || !isSupabaseConfigured || !supabase) {
    return sortRoutineRows(
      devPreviewRoutinesStore.filter((r) => r.is_active !== false),
    );
  }

  let { data, error } = await supabase
    .from("routines")
    .select(ROUTINE_EXTENDED_SELECT_COLUMNS)
    .eq("is_active", true)
    .order("day")
    .order("time_start");

  if (error && isMissingTeacherCodesColumnError(error)) {
    const fallback = await supabase
      .from("routines")
      .select(ROUTINE_SELECT_COLUMNS)
      .eq("is_active", true)
      .order("day")
      .order("time_start");
    data = fallback.data as typeof data;
    error = fallback.error;
  }

  if (error) {
    throw new Error(error.message);
  }

  return sortRoutineRows((data ?? []) as RoutineRow[]);
}

export async function fetchActiveRoutineVersion(
  isDevPreview: boolean,
): Promise<RoutineVersionRecord | null> {
  if (isDevPreview || !isSupabaseConfigured || !supabase) {
    return devPreviewActiveVersion ? structuredClone(devPreviewActiveVersion) : null;
  }

  const { data, error } = await supabase
    .from("routine_versions")
    .select(ROUTINE_VERSION_SELECT_COLUMNS)
    .eq("is_active", true)
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle();

  if (error) {
    throw new Error(error.message);
  }

  return (data as RoutineVersionRecord | null) ?? null;
}

export async function createRoutineSlot(
  input: RoutineWriteInput,
  isDevPreview: boolean,
): Promise<RoutineRow> {
  const payload = toRoutineWritePayload(input, true);

  if (isDevPreview || !isSupabaseConfigured || !supabase) {
    const created: RoutineRow = {
      id: `preview-slot-${Date.now()}-${Math.floor(Math.random() * 1000)}`,
      ...payload,
      routine_version_id: devPreviewActiveVersion?.id ?? null,
    };
    devPreviewRoutinesStore.push(created);
    return structuredClone(created);
  }

  let { data, error } = await supabase
    .from("routines")
    .insert(payload)
    .select(ROUTINE_EXTENDED_SELECT_COLUMNS)
    .single();

  if (error && isMissingTeacherCodesColumnError(error)) {
    const fallbackPayload = toRoutineWritePayload(input, false);
    const fallback = await supabase
      .from("routines")
      .insert(fallbackPayload)
      .select(ROUTINE_SELECT_COLUMNS)
      .single();
    data = fallback.data as typeof data;
    error = fallback.error;
  }

  if (error) {
    throw new Error(error.message);
  }

  return data as RoutineRow;
}

export async function updateRoutineSlot(
  id: string,
  input: RoutineWriteInput,
  isDevPreview: boolean,
): Promise<RoutineRow> {
  const payload = toRoutineWritePayload(input, true);

  if (isDevPreview || !isSupabaseConfigured || !supabase) {
    const idx = devPreviewRoutinesStore.findIndex((r) => r.id === id);
    if (idx === -1) throw new Error("Routine slot not found.");
    const updated: RoutineRow = {
      ...devPreviewRoutinesStore[idx]!,
      ...payload,
      id,
    };
    devPreviewRoutinesStore[idx] = updated;
    return structuredClone(updated);
  }

  let { data, error } = await supabase
    .from("routines")
    .update(payload)
    .eq("id", id)
    .select(ROUTINE_EXTENDED_SELECT_COLUMNS)
    .single();

  if (error && isMissingTeacherCodesColumnError(error)) {
    const fallbackPayload = toRoutineWritePayload(input, false);
    const fallback = await supabase
      .from("routines")
      .update(fallbackPayload)
      .eq("id", id)
      .select(ROUTINE_SELECT_COLUMNS)
      .single();
    data = fallback.data as typeof data;
    error = fallback.error;
  }

  if (error) {
    throw new Error(error.message);
  }

  return data as RoutineRow;
}

export async function deleteRoutineSlots(
  ids: readonly string[],
  isDevPreview: boolean,
): Promise<void> {
  if (ids.length === 0) return;

  if (isDevPreview || !isSupabaseConfigured || !supabase) {
    const dropSet = new Set(ids);
    devPreviewRoutinesStore = devPreviewRoutinesStore.filter(
      (r) => !dropSet.has(r.id),
    );
    return;
  }

  const { error } = await supabase
    .from("routines")
    .delete()
    .in("id", [...ids]);

  if (error) {
    throw new Error(error.message);
  }
}
