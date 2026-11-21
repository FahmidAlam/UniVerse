import { isSupabaseConfigured, supabase } from "@/services/supabase";

export const OWN_PROFILE_SELECT_COLUMNS =
  "id, email, role, name, avatar_url, teacher_code, designation, department, created_at";

export interface OwnAdminProfileRecord {
  id: string;
  email: string;
  role: string;
  name: string | null;
  avatar_url: string | null;
  teacher_code: string | null;
  designation: string | null;
  department: string | null;
  created_at: string;
}

export interface OwnProfileUpdateInput {
  name: string;
  department?: string | null;
  designation?: string | null;
  teacher_code?: string | null;
}

export interface OwnProfileUpdatePayload {
  name: string;
  department: string | null;
  designation: string | null;
  teacher_code: string | null;
}

/**
 * Emits ONLY allowed self-editable profile fields. Never mutates `role` or `avatar_url` (F-30).
 */
export function toOwnProfileUpdatePayload(
  input: OwnProfileUpdateInput,
): OwnProfileUpdatePayload {
  const name = input.name.trim();
  if (!name) {
    throw new Error("Display name is required.");
  }
  return {
    name,
    department: input.department?.trim() || null,
    designation: input.designation?.trim() || null,
    teacher_code: input.teacher_code?.trim().toUpperCase() || null,
  };
}

let devPreviewOwnProfile: OwnAdminProfileRecord = {
  id: "dev-preview-admin",
  email: "committee.cse@lus.ac.bd",
  role: "admin",
  name: "KJH · Routine Committee Chair",
  avatar_url: null,
  teacher_code: "KJH",
  designation: "Routine Committee Chair",
  department: "CSE",
  created_at: "2026-10-01T08:00:00.000Z",
};

export async function fetchOwnProfile(
  userId: string | null,
  isDevPreview: boolean,
): Promise<OwnAdminProfileRecord> {
  if (isDevPreview || !isSupabaseConfigured || !supabase || !userId) {
    return structuredClone(devPreviewOwnProfile);
  }

  const { data, error } = await supabase
    .from("profiles")
    .select(OWN_PROFILE_SELECT_COLUMNS)
    .eq("id", userId)
    .single();

  if (error) {
    throw new Error(error.message);
  }

  return data as OwnAdminProfileRecord;
}

export async function updateOwnProfile(
  userId: string | null,
  input: OwnProfileUpdateInput,
  isDevPreview: boolean,
): Promise<OwnAdminProfileRecord> {
  const payload = toOwnProfileUpdatePayload(input);

  if (isDevPreview || !isSupabaseConfigured || !supabase || !userId) {
    devPreviewOwnProfile = {
      ...devPreviewOwnProfile,
      ...payload,
    };
    return structuredClone(devPreviewOwnProfile);
  }

  const { data, error } = await supabase
    .from("profiles")
    .update(payload)
    .eq("id", userId)
    .select(OWN_PROFILE_SELECT_COLUMNS)
    .single();

  if (error) {
    throw new Error(error.message);
  }

  return data as OwnAdminProfileRecord;
}

export async function requestOwnPasswordReset(
  email: string,
  origin: string,
  isDevPreview: boolean,
): Promise<void> {
  const cleanOrigin = origin.replace(/\/+$/, "");

  if (isDevPreview || !isSupabaseConfigured || !supabase) {
    return;
  }

  const { error } = await supabase.auth.resetPasswordForEmail(email, {
    redirectTo: `${cleanOrigin}/`,
  });

  if (error) {
    throw new Error(error.message);
  }
}
