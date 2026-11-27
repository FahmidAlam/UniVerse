import type { SlotMatrixEntry } from "@/features/admin/components/DaySlotMatrixPicker";
import { ACADEMIC_WEEK_DAYS } from "@/features/admin/services/facultyService";
import { isSupabaseConfigured, supabase } from "@/services/supabase";

/**
 * Strictly pinned to the 8 verified baseline PostgreSQL columns on `public.timetable_rooms`
 * (`20261021214512_reconstructed_baseline.sql`). Zero probes for `campus`/`features`.
 */
export const ROOM_SELECT_COLUMNS =
  "id, name, building, is_lab, is_gallery, capacity, is_active, dept";

export const ROOM_EXTENDED_SELECT_COLUMNS =
  `${ROOM_SELECT_COLUMNS}, room_pool_role, available_slots`;

export type RoomPoolRole =
  | "general"
  | "cse_lab"
  | "ecl_lab"
  | "physics_lab"
  | "gallery"
  | "other";

export const ROOM_POOL_ROLE_LABELS: Record<RoomPoolRole, string> = {
  general: "General Classroom",
  cse_lab: "CSE Lab",
  ecl_lab: "ECL Lab (EEE-Shared · R10)",
  physics_lab: "Physics Lab (R11)",
  gallery: "Gallery Hall",
  other: "Other / Special",
};

export interface TimetableRoomRecord {
  id: string;
  name: string;
  building: string | null;
  is_lab: boolean;
  is_gallery: boolean;
  capacity: number | null;
  is_active: boolean;
  dept: string | null;
  room_pool_role?: RoomPoolRole;
  available_slots?: SlotMatrixEntry[];
}

export interface RoomWriteInput {
  name: string;
  building?: string | null;
  is_lab: boolean;
  is_gallery: boolean;
  capacity?: number | null;
  is_active: boolean;
  dept?: string | null;
  room_pool_role?: RoomPoolRole;
  available_slots?: SlotMatrixEntry[];
}

export interface RoomWritePayload {
  name: string;
  building: string | null;
  is_lab: boolean;
  is_gallery: boolean;
  capacity: number | null;
  is_active: boolean;
  dept: string | null;
}

export interface ExtendedRoomWritePayload extends RoomWritePayload {
  room_pool_role: RoomPoolRole;
  available_slots: SlotMatrixEntry[];
}

function normalizeSlotList(raw: unknown): SlotMatrixEntry[] {
  if (!Array.isArray(raw)) return [];
  const validDays = new Set<string>(ACADEMIC_WEEK_DAYS);
  const seen = new Set<string>();
  const out: SlotMatrixEntry[] = [];
  for (const item of raw) {
    if (!item || typeof item !== "object") continue;
    const obj = item as { day?: unknown; period_idx?: unknown };
    const day = String(obj.day ?? "").trim();
    const periodIdx = Number(obj.period_idx);
    if (!validDays.has(day) || !Number.isInteger(periodIdx) || periodIdx < 1 || periodIdx > 12) {
      continue;
    }
    const key = `${day}|${periodIdx}`;
    if (seen.has(key)) continue;
    seen.add(key);
    out.push({ day, period_idx: periodIdx });
  }
  return out;
}

export function inferRoomPoolRole(input: {
  name: string;
  is_lab: boolean;
  is_gallery: boolean;
  room_pool_role?: RoomPoolRole;
}): RoomPoolRole {
  if (input.room_pool_role) return input.room_pool_role;
  if (input.is_gallery) return "gallery";
  if (/^ECL([-_ \d]|$)/i.test(input.name.trim())) return "ecl_lab";
  if (input.is_lab && /(^|[^a-z])phy(sics)?([-_ \d]|$)/i.test(input.name.trim())) {
    return "physics_lab";
  }
  if (input.is_lab) return "cse_lab";
  return "general";
}

/**
 * Emits ONLY the 7 writable baseline columns on `public.timetable_rooms`.
 * Never includes Stage 5A extended columns when targeting pre-migration DBs.
 */
export function toRoomWritePayload(input: RoomWriteInput): RoomWritePayload {
  const normalizedName = input.name.trim().toUpperCase();
  const building = input.building?.trim() ? input.building.trim() : null;
  const dept = input.dept?.trim() ? input.dept.trim() : null;
  const capacity =
    typeof input.capacity === "number" && Number.isFinite(input.capacity)
      ? Math.trunc(input.capacity)
      : null;

  return {
    name: normalizedName,
    building,
    is_lab: Boolean(input.is_lab),
    is_gallery: Boolean(input.is_gallery),
    capacity,
    is_active: Boolean(input.is_active),
    dept,
  };
}

export function toExtendedRoomWritePayload(
  input: RoomWriteInput,
): ExtendedRoomWritePayload {
  const base = toRoomWritePayload(input);
  const role = inferRoomPoolRole({
    name: base.name,
    is_lab: base.is_lab,
    is_gallery: base.is_gallery,
    room_pool_role: input.room_pool_role,
  });
  const requiresSlots = role === "ecl_lab" || role === "physics_lab";
  return {
    ...base,
    room_pool_role: role,
    available_slots: requiresSlots ? normalizeSlotList(input.available_slots) : [],
  };
}

function isMissingColumnError(err: { code?: string; message?: string } | null): boolean {
  if (!err) return false;
  const code = err.code ?? "";
  const msg = (err.message ?? "").toLowerCase();
  return code === "42703" || code === "PGRST204" || msg.includes("column");
}

function normalizeRoomRow(
  raw: Record<string, unknown>,
  extended: boolean,
): TimetableRoomRecord {
  const base: TimetableRoomRecord = {
    id: String(raw.id),
    name: String(raw.name ?? "").trim().toUpperCase(),
    building: raw.building ? String(raw.building) : null,
    is_lab: Boolean(raw.is_lab),
    is_gallery: Boolean(raw.is_gallery),
    capacity: typeof raw.capacity === "number" ? raw.capacity : null,
    is_active: raw.is_active !== false,
    dept: raw.dept ? String(raw.dept) : null,
  };
  if (!extended) return base;

  const rawRole = String(raw.room_pool_role ?? "general").toLowerCase();
  const validRoles = new Set<RoomPoolRole>([
    "general",
    "cse_lab",
    "ecl_lab",
    "physics_lab",
    "gallery",
    "other",
  ]);
  const room_pool_role = validRoles.has(rawRole as RoomPoolRole)
    ? (rawRole as RoomPoolRole)
    : inferRoomPoolRole(base);

  return {
    ...base,
    room_pool_role,
    available_slots: normalizeSlotList(raw.available_slots),
  };
}

let cachedRoomExtendedSupported: boolean | null = null;

export async function isRoomExtendedSchemaLive(
  isDevPreview: boolean,
): Promise<boolean> {
  if (isDevPreview || !isSupabaseConfigured || !supabase) return true;
  if (cachedRoomExtendedSupported !== null) return cachedRoomExtendedSupported;
  const { error } = await supabase
    .from("timetable_rooms")
    .select("id, room_pool_role, available_slots")
    .limit(1);
  cachedRoomExtendedSupported = !error || !isMissingColumnError(error);
  return cachedRoomExtendedSupported;
}

const devPreviewRoomsStore: TimetableRoomRecord[] = [];

export async function fetchRooms(
  isDevPreview: boolean,
): Promise<TimetableRoomRecord[]> {
  if (isDevPreview || !isSupabaseConfigured || !supabase) {
    return [...devPreviewRoomsStore].sort((a, b) => a.name.localeCompare(b.name));
  }

  const extRes = await supabase
    .from("timetable_rooms")
    .select(ROOM_EXTENDED_SELECT_COLUMNS)
    .order("is_lab", { ascending: false })
    .order("name");

  if (!extRes.error) {
    cachedRoomExtendedSupported = true;
    return ((extRes.data ?? []) as unknown as Record<string, unknown>[]).map((r) =>
      normalizeRoomRow(r, true),
    );
  }

  if (!isMissingColumnError(extRes.error)) {
    throw new Error(extRes.error.message);
  }

  cachedRoomExtendedSupported = false;
  const { data, error } = await supabase
    .from("timetable_rooms")
    .select(ROOM_SELECT_COLUMNS)
    .order("is_lab", { ascending: false })
    .order("name");

  if (error) {
    throw new Error(error.message);
  }

  return ((data ?? []) as unknown as Record<string, unknown>[]).map((r) =>
    normalizeRoomRow(r, false),
  );
}

export async function createRoom(
  input: RoomWriteInput,
  isDevPreview: boolean,
): Promise<TimetableRoomRecord> {
  if (isDevPreview || !isSupabaseConfigured || !supabase) {
    const extPayload = toExtendedRoomWritePayload(input);
    const duplicate = devPreviewRoomsStore.some((r) => r.name === extPayload.name);
    if (duplicate) {
      throw new Error(`Room "${extPayload.name}" already exists.`);
    }
    const created: TimetableRoomRecord = {
      id: `preview-room-${Date.now()}`,
      ...extPayload,
    };
    devPreviewRoomsStore.push(created);
    return created;
  }

  if (cachedRoomExtendedSupported !== false) {
    const extPayload = toExtendedRoomWritePayload(input);
    const { data, error } = await supabase
      .from("timetable_rooms")
      .insert(extPayload)
      .select(ROOM_EXTENDED_SELECT_COLUMNS)
      .single();

    if (!error) {
      cachedRoomExtendedSupported = true;
      return normalizeRoomRow(data as unknown as Record<string, unknown>, true);
    }
    if (!isMissingColumnError(error)) {
      throw new Error(error.message);
    }
    cachedRoomExtendedSupported = false;
  }

  const payload = toRoomWritePayload(input);
  const { data, error } = await supabase
    .from("timetable_rooms")
    .insert(payload)
    .select(ROOM_SELECT_COLUMNS)
    .single();

  if (error) {
    throw new Error(error.message);
  }

  return normalizeRoomRow(data as unknown as Record<string, unknown>, false);
}

export async function updateRoom(
  id: string,
  input: RoomWriteInput,
  isDevPreview: boolean,
): Promise<TimetableRoomRecord> {
  if (isDevPreview || !isSupabaseConfigured || !supabase) {
    const extPayload = toExtendedRoomWritePayload(input);
    const idx = devPreviewRoomsStore.findIndex((r) => r.id === id);
    if (idx === -1) throw new Error("Room record not found.");
    const updated: TimetableRoomRecord = { id, ...extPayload };
    devPreviewRoomsStore[idx] = updated;
    return updated;
  }

  if (cachedRoomExtendedSupported !== false) {
    const extPayload = toExtendedRoomWritePayload(input);
    const { data, error } = await supabase
      .from("timetable_rooms")
      .update(extPayload)
      .eq("id", id)
      .select(ROOM_EXTENDED_SELECT_COLUMNS)
      .single();

    if (!error) {
      cachedRoomExtendedSupported = true;
      return normalizeRoomRow(data as unknown as Record<string, unknown>, true);
    }
    if (!isMissingColumnError(error)) {
      throw new Error(error.message);
    }
    cachedRoomExtendedSupported = false;
  }

  const payload = toRoomWritePayload(input);
  const { data, error } = await supabase
    .from("timetable_rooms")
    .update(payload)
    .eq("id", id)
    .select(ROOM_SELECT_COLUMNS)
    .single();

  if (error) {
    throw new Error(error.message);
  }

  return normalizeRoomRow(data as unknown as Record<string, unknown>, false);
}

export async function bulkSetRoomsActive(
  ids: readonly string[],
  isActive: boolean,
  isDevPreview: boolean,
): Promise<void> {
  if (ids.length === 0) return;

  if (isDevPreview || !isSupabaseConfigured || !supabase) {
    for (const r of devPreviewRoomsStore) {
      if (ids.includes(r.id)) r.is_active = isActive;
    }
    return;
  }

  const { error } = await supabase
    .from("timetable_rooms")
    .update({ is_active: isActive })
    .in("id", [...ids]);

  if (error) {
    throw new Error(error.message);
  }
}

export async function deleteRooms(
  ids: readonly string[],
  isDevPreview: boolean,
): Promise<void> {
  if (ids.length === 0) return;

  if (isDevPreview || !isSupabaseConfigured || !supabase) {
    for (let i = devPreviewRoomsStore.length - 1; i >= 0; i--) {
      if (ids.includes(devPreviewRoomsStore[i]!.id)) {
        devPreviewRoomsStore.splice(i, 1);
      }
    }
    return;
  }

  const { error } = await supabase
    .from("timetable_rooms")
    .delete()
    .in("id", [...ids]);

  if (error) {
    throw new Error(error.message);
  }
}
