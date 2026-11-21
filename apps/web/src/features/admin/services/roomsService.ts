import { isSupabaseConfigured, supabase } from "@/services/supabase";

/**
 * Strictly pinned to the 8 verified baseline PostgreSQL columns on `public.timetable_rooms`
 * (`20261021214512_reconstructed_baseline.sql`). Zero probes for `campus`/`features`.
 */
export const ROOM_SELECT_COLUMNS =
  "id, name, building, is_lab, is_gallery, capacity, is_active, dept";

export interface TimetableRoomRecord {
  id: string;
  name: string;
  building: string | null;
  is_lab: boolean;
  is_gallery: boolean;
  capacity: number | null;
  is_active: boolean;
  dept: string | null;
}

export interface RoomWriteInput {
  name: string;
  building?: string | null;
  is_lab: boolean;
  is_gallery: boolean;
  capacity?: number | null;
  is_active: boolean;
  dept?: string | null;
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

/**
 * Emits ONLY the 7 writable baseline columns on `public.timetable_rooms`.
 * Never includes Phase A non-DB fields (`classification`, `declared_window_matrix`, etc.).
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

const devPreviewRoomsStore: TimetableRoomRecord[] = [];

export async function fetchRooms(
  isDevPreview: boolean,
): Promise<TimetableRoomRecord[]> {
  if (isDevPreview || !isSupabaseConfigured || !supabase) {
    return [...devPreviewRoomsStore].sort((a, b) => a.name.localeCompare(b.name));
  }

  const { data, error } = await supabase
    .from("timetable_rooms")
    .select(ROOM_SELECT_COLUMNS)
    .order("is_lab", { ascending: false })
    .order("name");

  if (error) {
    throw new Error(error.message);
  }

  return (data ?? []) as TimetableRoomRecord[];
}

export async function createRoom(
  input: RoomWriteInput,
  isDevPreview: boolean,
): Promise<TimetableRoomRecord> {
  const payload = toRoomWritePayload(input);

  if (isDevPreview || !isSupabaseConfigured || !supabase) {
    const duplicate = devPreviewRoomsStore.some((r) => r.name === payload.name);
    if (duplicate) {
      throw new Error(`Room "${payload.name}" already exists.`);
    }
    const created: TimetableRoomRecord = {
      id: `preview-room-${Date.now()}`,
      ...payload,
    };
    devPreviewRoomsStore.push(created);
    return created;
  }

  const { data, error } = await supabase
    .from("timetable_rooms")
    .insert(payload)
    .select(ROOM_SELECT_COLUMNS)
    .single();

  if (error) {
    throw new Error(error.message);
  }

  return data as TimetableRoomRecord;
}

export async function updateRoom(
  id: string,
  input: RoomWriteInput,
  isDevPreview: boolean,
): Promise<TimetableRoomRecord> {
  const payload = toRoomWritePayload(input);

  if (isDevPreview || !isSupabaseConfigured || !supabase) {
    const idx = devPreviewRoomsStore.findIndex((r) => r.id === id);
    if (idx === -1) throw new Error("Room record not found.");
    const updated: TimetableRoomRecord = { id, ...payload };
    devPreviewRoomsStore[idx] = updated;
    return updated;
  }

  const { data, error } = await supabase
    .from("timetable_rooms")
    .update(payload)
    .eq("id", id)
    .select(ROOM_SELECT_COLUMNS)
    .single();

  if (error) {
    throw new Error(error.message);
  }

  return data as TimetableRoomRecord;
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
