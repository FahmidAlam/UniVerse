import { isSupabaseConfigured, supabase } from "@/services/supabase";

/**
 * Exact 6-value enum matching SQL constraint `check_notif_type` on `public.notifications`.
 */
export const NOTIFICATION_TYPES = [
  "university",
  "class_cancel",
  "room_change",
  "test_reminder",
  "assignment",
  "exam",
] as const;

export type NotificationType = (typeof NOTIFICATION_TYPES)[number];

export const NOTIFICATION_TYPE_LABELS: Record<NotificationType, string> = {
  university: "University Notice",
  class_cancel: "Class Cancelled",
  room_change: "Room Change",
  test_reminder: "Class Test",
  assignment: "Assignment",
  exam: "Examination",
};

export const NOTIFICATION_SELECT_COLUMNS =
  "id, title, body, type, sent_by, target_role, target_batch, target_section, created_at";

export interface BroadcastRecord {
  id: string;
  title: string;
  body: string;
  type: NotificationType;
  sent_by: string | null;
  target_role: string | null;
  target_batch: string | null;
  target_section: string | null;
  created_at: string;
}

export interface BroadcastCreateInput {
  title: string;
  body: string;
  type: NotificationType;
  target_role: "all" | "student" | "teacher" | "admin";
  target_batch?: string | null;
  target_section?: string | null;
}

export interface BroadcastInsertPayload {
  title: string;
  body: string;
  type: NotificationType;
  sent_by: string | null;
  target_role: "student" | "teacher" | "admin" | null;
  target_batch: string | null;
  target_section: string | null;
}

/**
 * Normalizes audience filters to match Flutter `NotificationItem.matchesAudience`:
 * - `target_role: "all"` -> `null`
 * - blank `target_batch` / `target_section` -> `null`
 * - author column strictly `sent_by` (verified SQL column)
 */
export function toBroadcastInsertPayload(
  input: BroadcastCreateInput,
  sentByUserId: string | null,
): BroadcastInsertPayload {
  const title = input.title.trim();
  const body = input.body.trim();
  if (!title) throw new Error("Enter a broadcast headline.");
  if (!body) throw new Error("Enter the announcement message body.");
  if (!NOTIFICATION_TYPES.includes(input.type)) {
    throw new Error(`Unsupported notification type: ${String(input.type)}`);
  }

  const target_role =
    input.target_role === "all" ? null : input.target_role;
  const target_batch = input.target_batch?.trim() || null;
  const target_section =
    input.target_section?.trim().toUpperCase() || null;

  return {
    title,
    body,
    type: input.type,
    sent_by: sentByUserId,
    target_role,
    target_batch,
    target_section,
  };
}

export function formatBroadcastAudienceLabel(
  row: Pick<BroadcastCreateInput, "target_role" | "target_batch" | "target_section"> |
    Pick<BroadcastRecord, "target_role" | "target_batch" | "target_section">,
): string {
  const rolePart =
    !row.target_role || row.target_role === "all"
      ? "All Students & Teachers"
      : row.target_role === "student"
        ? "Students"
        : row.target_role === "teacher"
          ? "Faculty"
          : "Administrators";
  const scopeParts: string[] = [rolePart];
  if (row.target_batch) scopeParts.push(`Batch ${row.target_batch}`);
  if (row.target_section) scopeParts.push(`Section ${row.target_section}`);
  return scopeParts.join(" · ");
}

const devPreviewBroadcastStore: BroadcastRecord[] = [];

export async function fetchBroadcastHistory(
  isDevPreview: boolean,
): Promise<BroadcastRecord[]> {
  if (isDevPreview || !isSupabaseConfigured || !supabase) {
    return [...devPreviewBroadcastStore].sort((a, b) =>
      b.created_at.localeCompare(a.created_at),
    );
  }

  const { data, error } = await supabase
    .from("notifications")
    .select(NOTIFICATION_SELECT_COLUMNS)
    .order("created_at", { ascending: false });

  if (error) {
    throw new Error(error.message);
  }

  return (data ?? []) as BroadcastRecord[];
}

export async function createBroadcast(
  input: BroadcastCreateInput,
  sentByUserId: string | null,
  isDevPreview: boolean,
): Promise<BroadcastRecord> {
  const payload = toBroadcastInsertPayload(input, sentByUserId);

  if (isDevPreview || !isSupabaseConfigured || !supabase) {
    const created: BroadcastRecord = {
      id: `preview-notif-${Date.now()}`,
      ...payload,
      created_at: new Date().toISOString(),
    };
    devPreviewBroadcastStore.unshift(created);
    return structuredClone(created);
  }

  const { data, error } = await supabase
    .from("notifications")
    .insert(payload)
    .select(NOTIFICATION_SELECT_COLUMNS)
    .single();

  if (error) {
    throw new Error(error.message);
  }

  return data as BroadcastRecord;
}

export async function deleteBroadcasts(
  ids: readonly string[],
  isDevPreview: boolean,
): Promise<void> {
  if (ids.length === 0) return;

  if (isDevPreview || !isSupabaseConfigured || !supabase) {
    const dropSet = new Set(ids);
    for (let i = devPreviewBroadcastStore.length - 1; i >= 0; i--) {
      if (dropSet.has(devPreviewBroadcastStore[i]!.id)) {
        devPreviewBroadcastStore.splice(i, 1);
      }
    }
    return;
  }

  const { error } = await supabase
    .from("notifications")
    .delete()
    .in("id", [...ids]);

  if (error) {
    throw new Error(error.message);
  }
}
