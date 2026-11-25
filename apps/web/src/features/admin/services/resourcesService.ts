import { isSupabaseConfigured, supabase } from "@/services/supabase";

/** Exact categories matching Flutter `AppConstants.resourceCategories` (excluding filter "All"). */
export const RESOURCE_CATEGORIES = [
  "PYQ",
  "Notes",
  "Slides",
  "Assignments",
] as const;

export type ResourceCategory = (typeof RESOURCE_CATEGORIES)[number];

/** Exact semesters matching Flutter `AppConstants.semesters`. */
export const RESOURCE_SEMESTERS = [1, 2, 3, 4, 5, 6, 7, 8] as const;

export const RESOURCE_BUCKET = "resources";

export const RESOURCE_SELECT_COLUMNS =
  "id, title, category, semester, subject_code, drive_link, file_url, uploaded_by, created_at";

export interface ResourceRecord {
  id: string;
  title: string;
  category: ResourceCategory;
  semester: number;
  subject_code: string | null;
  drive_link: string | null;
  file_url: string | null;
  uploaded_by: string | null;
  created_at: string;
}

export interface ResourceCreateInput {
  title: string;
  category: ResourceCategory;
  semester: number;
  subject_code?: string | null;
  drive_link?: string | null;
  file_url?: string | null;
}

export interface ResourceInsertPayload {
  title: string;
  category: ResourceCategory;
  semester: number;
  subject_code: string | null;
  drive_link: string | null;
  file_url: string | null;
  uploaded_by: string | null;
}

/**
 * Exact parity with Flutter `ResourceService.uploadFile`:
 * `${semester}/${epochMs}_${filename.replace(/[^A-Za-z0-9._-]/g, "_")}`
 */
export function buildResourceStoragePath(
  semester: number,
  filename: string,
  epochMs: number = Date.now(),
): string {
  const safe = filename.replace(/[^A-Za-z0-9._-]/g, "_");
  return `${semester}/${epochMs}_${safe}`;
}

export function extractResourceStoragePath(fileUrl: string | null): string | null {
  if (!fileUrl) return null;
  const marker = `/storage/v1/object/public/${RESOURCE_BUCKET}/`;
  const idx = fileUrl.indexOf(marker);
  if (idx === -1) return null;
  const raw = fileUrl.slice(idx + marker.length).split("?")[0] ?? "";
  return raw.trim() || null;
}

export function toResourceInsertPayload(
  input: ResourceCreateInput,
  uploadedByUserId: string | null,
): ResourceInsertPayload {
  const title = input.title.trim();
  if (!title) throw new Error("Enter a resource title.");
  if (!RESOURCE_CATEGORIES.includes(input.category)) {
    throw new Error("Select a valid resource category.");
  }
  if (
    !Number.isInteger(input.semester) ||
    input.semester < 1 ||
    input.semester > 8
  ) {
    throw new Error("Semester must be between 1 and 8.");
  }

  const drive_link = input.drive_link?.trim() || null;
  const file_url = input.file_url?.trim() || null;
  if (!drive_link && !file_url) {
    throw new Error("Upload a file or provide an external HTTPS Drive link.");
  }
  if (drive_link && !/^https:\/\//i.test(drive_link)) {
    throw new Error("External Drive link must start with https://");
  }

  return {
    title,
    category: input.category,
    semester: input.semester,
    subject_code: input.subject_code?.trim().toUpperCase() || null,
    drive_link,
    file_url,
    uploaded_by: uploadedByUserId,
  };
}

const devPreviewResourcesStore: ResourceRecord[] = [];

export async function fetchResources(
  isDevPreview: boolean,
): Promise<ResourceRecord[]> {
  if (isDevPreview || !isSupabaseConfigured || !supabase) {
    return [...devPreviewResourcesStore].sort((a, b) =>
      b.created_at.localeCompare(a.created_at),
    );
  }

  const { data, error } = await supabase
    .from("resources")
    .select(RESOURCE_SELECT_COLUMNS)
    .order("created_at", { ascending: false });

  if (error) {
    throw new Error(error.message);
  }

  return (data ?? []) as ResourceRecord[];
}

export async function uploadResourceFile(
  file: File,
  semester: number,
  isDevPreview: boolean,
): Promise<string> {
  const storagePath = buildResourceStoragePath(semester, file.name);

  if (isDevPreview || !isSupabaseConfigured || !supabase) {
    return `https://preview.local/storage/v1/object/public/resources/${storagePath}`;
  }

  const { error: uploadError } = await supabase.storage
    .from(RESOURCE_BUCKET)
    .upload(storagePath, file, {
      contentType: file.type || "application/octet-stream",
      upsert: false,
    });

  if (uploadError) {
    throw new Error(uploadError.message);
  }

  const { data } = supabase.storage
    .from(RESOURCE_BUCKET)
    .getPublicUrl(storagePath);

  return data.publicUrl;
}

export async function createResource(
  input: ResourceCreateInput,
  uploadedByUserId: string | null,
  isDevPreview: boolean,
): Promise<ResourceRecord> {
  const payload = toResourceInsertPayload(input, uploadedByUserId);

  if (isDevPreview || !isSupabaseConfigured || !supabase) {
    const created: ResourceRecord = {
      id: `preview-res-${Date.now()}`,
      ...payload,
      created_at: new Date().toISOString(),
    };
    devPreviewResourcesStore.unshift(created);
    return structuredClone(created);
  }

  const { data, error } = await supabase
    .from("resources")
    .insert(payload)
    .select(RESOURCE_SELECT_COLUMNS)
    .single();

  if (error) {
    throw new Error(error.message);
  }

  return data as ResourceRecord;
}

export async function deleteResourceWithCleanup(
  resource: ResourceRecord,
  isDevPreview: boolean,
): Promise<{ storageWarning: string | null }> {
  if (isDevPreview || !isSupabaseConfigured || !supabase) {
    const idx = devPreviewResourcesStore.findIndex((r) => r.id === resource.id);
    if (idx !== -1) devPreviewResourcesStore.splice(idx, 1);
    return { storageWarning: null };
  }

  const { error } = await supabase
    .from("resources")
    .delete()
    .eq("id", resource.id);

  if (error) {
    throw new Error(error.message);
  }

  const storagePath = extractResourceStoragePath(resource.file_url);
  if (storagePath) {
    const { error: storageError } = await supabase.storage
      .from(RESOURCE_BUCKET)
      .remove([storagePath]);

    if (storageError) {
      return {
        storageWarning: `Record removed from database, but Storage object cleanup failed: ${storageError.message}`,
      };
    }
  }

  return { storageWarning: null };
}
