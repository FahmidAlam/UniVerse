import { isSupabaseConfigured, supabase } from "@/services/supabase";

export type UserRole = "student" | "teacher" | "admin";

export const PROFILE_SELECT_COLUMNS =
  "id, email, role, name, avatar_url, batch, section, semester, student_id, teacher_code, designation, department, courses, created_at";

export const WHITELIST_SELECT_COLUMNS =
  "email, role, name, teacher_code, batch, section, semester, department, designation";

export interface DirectoryProfileRecord {
  id: string;
  email: string;
  role: UserRole;
  name: string | null;
  avatar_url: string | null;
  batch: string | null;
  section: string | null;
  semester: number | null;
  student_id: string | null;
  teacher_code: string | null;
  designation: string | null;
  department: string | null;
  courses: string[] | null;
  created_at: string;
}

export interface WhitelistRecord {
  email: string;
  role: UserRole;
  name: string | null;
  teacher_code: string | null;
  batch: string | null;
  section: string | null;
  semester: number | null;
  department: string | null;
  designation: string | null;
}

export interface WhitelistWriteInput {
  email: string;
  role: UserRole;
  name?: string | null;
  teacher_code?: string | null;
  batch?: string | null;
  section?: string | null;
  semester?: number | null;
  department?: string | null;
  designation?: string | null;
}

export function toWhitelistWritePayload(
  input: WhitelistWriteInput,
): WhitelistRecord {
  const email = input.email.trim().toLowerCase();
  if (!email || !email.includes("@")) {
    throw new Error("Enter a valid institutional email address.");
  }
  const sem =
    typeof input.semester === "number" &&
    Number.isInteger(input.semester) &&
    input.semester >= 1 &&
    input.semester <= 12
      ? input.semester
      : null;

  return {
    email,
    role: input.role,
    name: input.name?.trim() || null,
    teacher_code: input.teacher_code?.trim().toUpperCase() || null,
    batch: input.batch?.trim() || null,
    section: input.section?.trim().toUpperCase() || null,
    semester: sem,
    department: input.department?.trim() || null,
    designation: input.designation?.trim() || null,
  };
}

export function buildInviteAdminPayload(
  email: string,
  name: string,
  origin: string,
): { email: string; name: string; redirect_to: string } {
  const cleanOrigin = origin.replace(/\/+$/, "");
  return {
    email: email.trim().toLowerCase(),
    name: name.trim(),
    redirect_to: `${cleanOrigin}/`,
  };
}

const devPreviewProfilesStore: DirectoryProfileRecord[] = [
  {
    id: "dev-preview-admin",
    email: "committee.cse@lus.ac.bd",
    role: "admin",
    name: "KJH · Routine Committee Chair",
    avatar_url: null,
    batch: null,
    section: null,
    semester: null,
    student_id: null,
    teacher_code: "KJH",
    designation: "Routine Committee Chair",
    department: "CSE",
    courses: [],
    created_at: "2026-10-01T08:00:00.000Z",
  },
];

const devPreviewWhitelistsStore: WhitelistRecord[] = [];

export async function fetchDirectoryProfiles(
  isDevPreview: boolean,
): Promise<DirectoryProfileRecord[]> {
  if (isDevPreview || !isSupabaseConfigured || !supabase) {
    return structuredClone(devPreviewProfilesStore);
  }

  const { data, error } = await supabase
    .from("profiles")
    .select(PROFILE_SELECT_COLUMNS)
    .order("created_at", { ascending: false });

  if (error) {
    throw new Error(error.message);
  }

  return (data ?? []) as DirectoryProfileRecord[];
}

/**
 * Updates another user's role cleanly while hard-blocking administrator self-demotion.
 */
export async function updateProfileRole(
  targetUserId: string,
  nextRole: UserRole,
  actingAdminId: string | null,
  isDevPreview: boolean,
): Promise<DirectoryProfileRecord> {
  if (actingAdminId && targetUserId === actingAdminId && nextRole !== "admin") {
    throw new Error(
      "Self-demotion is blocked: signed-in administrators cannot downgrade their own role.",
    );
  }

  if (isDevPreview || !isSupabaseConfigured || !supabase) {
    const idx = devPreviewProfilesStore.findIndex((p) => p.id === targetUserId);
    if (idx === -1) {
      throw new Error("Profile record not found in local preview store.");
    }
    const updated: DirectoryProfileRecord = {
      ...devPreviewProfilesStore[idx]!,
      role: nextRole,
    };
    devPreviewProfilesStore[idx] = updated;
    return structuredClone(updated);
  }

  const { data, error } = await supabase
    .from("profiles")
    .update({ role: nextRole })
    .eq("id", targetUserId)
    .select(PROFILE_SELECT_COLUMNS)
    .single();

  if (error) {
    throw new Error(error.message);
  }

  return data as DirectoryProfileRecord;
}

export async function fetchWhitelistEntries(
  isDevPreview: boolean,
): Promise<WhitelistRecord[]> {
  if (isDevPreview || !isSupabaseConfigured || !supabase) {
    return [...devPreviewWhitelistsStore].sort((a, b) =>
      a.email.localeCompare(b.email),
    );
  }

  const { data, error } = await supabase
    .from("whitelists")
    .select(WHITELIST_SELECT_COLUMNS)
    .order("email");

  if (error) {
    throw new Error(error.message);
  }

  return (data ?? []) as WhitelistRecord[];
}

export async function upsertWhitelistEntry(
  input: WhitelistWriteInput,
  isDevPreview: boolean,
): Promise<WhitelistRecord> {
  const payload = toWhitelistWritePayload(input);

  if (isDevPreview || !isSupabaseConfigured || !supabase) {
    const idx = devPreviewWhitelistsStore.findIndex(
      (w) => w.email === payload.email,
    );
    if (idx !== -1) {
      devPreviewWhitelistsStore[idx] = payload;
    } else {
      devPreviewWhitelistsStore.push(payload);
    }
    return structuredClone(payload);
  }

  const { data, error } = await supabase
    .from("whitelists")
    .upsert(payload, { onConflict: "email" })
    .select(WHITELIST_SELECT_COLUMNS)
    .single();

  if (error) {
    throw new Error(error.message);
  }

  return data as WhitelistRecord;
}

export async function deleteWhitelistEntries(
  emails: readonly string[],
  isDevPreview: boolean,
): Promise<void> {
  if (emails.length === 0) return;

  if (isDevPreview || !isSupabaseConfigured || !supabase) {
    const removeSet = new Set(emails.map((e) => e.toLowerCase()));
    for (let i = devPreviewWhitelistsStore.length - 1; i >= 0; i--) {
      if (removeSet.has(devPreviewWhitelistsStore[i]!.email.toLowerCase())) {
        devPreviewWhitelistsStore.splice(i, 1);
      }
    }
    return;
  }

  const { error } = await supabase
    .from("whitelists")
    .delete()
    .in("email", [...emails]);

  if (error) {
    throw new Error(error.message);
  }
}

async function extractEdgeFunctionErrorMessage(
  error: unknown,
): Promise<string> {
  if (!error || typeof error !== "object") {
    return "Failed to invoke invite-admin Edge Function.";
  }

  const errObj = error as {
    message?: unknown;
    status?: unknown;
    context?: unknown;
  };

  if (errObj.context instanceof Response) {
    const status = errObj.context.status;
    let bodyError = "";
    try {
      const text = await errObj.context.clone().text();
      if (text) {
        try {
          const parsed = JSON.parse(text) as { error?: unknown; message?: unknown };
          if (typeof parsed.error === "string") bodyError = parsed.error;
          else if (typeof parsed.message === "string") bodyError = parsed.message;
        } catch {
          bodyError = text;
        }
      }
    } catch {
      // ignore body read error
    }

    if (status === 404) {
      return "Edge Function invite-admin is not deployed (HTTP 404) on this Supabase project.";
    }
    if (bodyError) {
      return `${bodyError} (HTTP ${status})`;
    }
    return `invite-admin returned HTTP ${status}.`;
  }

  if (typeof errObj.message === "string" && errObj.message.trim().length > 0) {
    return errObj.message;
  }

  return "Network error invoking invite-admin Edge Function.";
}

export async function invokeInviteAdmin(
  { email, name }: { email: string; name: string },
  isDevPreview: boolean,
): Promise<{ invitedEmail: string; redirectTo: string }> {
  const origin =
    typeof window !== "undefined" ? window.location.origin : "http://localhost";
  const payload = buildInviteAdminPayload(email, name, origin);

  if (!payload.email || !payload.email.includes("@")) {
    throw new Error("Enter a valid administrator email.");
  }
  if (!payload.name) {
    throw new Error("Enter the invited administrator's full name.");
  }

  if (isDevPreview || !isSupabaseConfigured || !supabase) {
    await upsertWhitelistEntry(
      {
        email: payload.email,
        role: "admin",
        name: payload.name,
        department: "CSE",
      },
      true,
    );
    return {
      invitedEmail: payload.email,
      redirectTo: payload.redirect_to,
    };
  }

  const { data, error } = await supabase.functions.invoke("invite-admin", {
    body: payload,
  });

  if (error) {
    throw new Error(await extractEdgeFunctionErrorMessage(error));
  }

  if (
    data &&
    typeof data === "object" &&
    "error" in data &&
    typeof (data as { error?: unknown }).error === "string"
  ) {
    throw new Error((data as { error: string }).error);
  }

  return {
    invitedEmail: payload.email,
    redirectTo: payload.redirect_to,
  };
}
