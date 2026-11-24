import { z } from "zod";
import { ClockTime } from "@/core/utils/clockTime";
import { replaceDevPreviewRoutines } from "@/features/routine/services/routineService";
import {
  assessBaselineConfigForPublish,
  blockingValidationErrorFor,
  findCoTeacherBlockers,
} from "@/features/routine/services/validationGate";
import type {
  BaselineConfigCounts,
  EngineConfigPayload,
  EngineResultResponse,
  EngineStats,
  EngineStatusResponse,
  EngineValidation,
  PublishPipelineResult,
  RetryAuditParams,
  RoutineRow,
} from "@/features/routine/types";
import { getEngineBaseUrl } from "@/services/engineHealth";
import { isSupabaseConfigured, supabase } from "@/services/supabase";

const ENGINE_REQUEST_TIMEOUT_MS = 90_000;
export const DEFAULT_SOLVE_TIME_LIMIT_S = 180;
export const DEFAULT_POLL_INTERVAL_MS = 2_000;
export const DEFAULT_MAX_POLLS = 240;
export const RATE_LIMIT_BACKOFF_MS = 4_000;
export const MAX_CONSECUTIVE_POLL_ERRORS = 4; // Fails on 5th consecutive non-429 error

export type EngineErrorKind =
  | "auth"
  | "engine-restart"
  | "rate-limited"
  | "solver-failed"
  | "network"
  | "timeout"
  | "http";

export class EngineJobError extends Error {
  readonly kind: EngineErrorKind;
  readonly status?: number;

  constructor(kind: EngineErrorKind, message: string, status?: number) {
    super(message);
    this.name = "EngineJobError";
    this.kind = kind;
    this.status = status;
  }
}

const EngineSubmitSchema = z.object({
  job_id: z.string().min(1),
});

const EngineStatusSchema = z.object({
  job_id: z.string().min(1),
  state: z.enum([
    "queued",
    "ingesting",
    "solving",
    "rendering",
    "done",
    "failed",
  ]),
  progress: z.number().default(0),
  stats: z.record(z.string(), z.unknown()).optional(),
  validation: z.record(z.string(), z.unknown()).optional(),
  source_contract: z.record(z.string(), z.unknown()).optional().nullable(),
  error: z.string().optional().nullable(),
});

const EngineRowSchema = z
  .object({
    id: z.union([z.string(), z.number()]).transform(String),
    day: z.string(),
    period: z.number().optional(),
    time_start: z.string(),
    time_end: z.string(),
    subject: z.string(),
    subject_code: z.string(),
    teacher_name: z.string().nullable().optional().default(null),
    teacher_code: z.string().nullable().optional().default(null),
    room: z.string().default("TBA"),
    batch: z.union([z.string(), z.number()]).transform(String),
    section: z.string().default(""),
    semester: z.number().int().default(1),
    is_active: z.boolean().default(true),
    is_service: z.boolean().default(false),
    oid: z.number().optional(),
    teachers: z.array(z.string()).optional(),
    teacher_state: z.enum(["assigned", "pending"]).optional(),
    is_lab: z.boolean().optional(),
  })
  .passthrough();

const EngineResultSchema = z.object({
  job_id: z.string().min(1),
  rows: z.array(EngineRowSchema),
  service_rows: z.array(EngineRowSchema).default([]),
  stats: z.record(z.string(), z.unknown()),
  validation: z
    .object({
      ok: z.boolean(),
    })
    .passthrough(),
  source_contract: z
    .object({
      source_sha256: z.string(),
      revision: z.number(),
      invalidated_artifacts: z.array(z.string()).default([]),
    })
    .passthrough()
    .optional()
    .nullable(),
  report: z
    .object({
      source_contract: z.record(z.string(), z.unknown()).optional().nullable(),
      cohorts: z.array(z.string()).default([]),
      meta: z.record(z.string(), z.unknown()).default({}),
      excluded: z.array(z.record(z.string(), z.unknown())).default([]),
      warnings: z.array(z.string()).default([]),
      offerings: z.array(z.record(z.string(), z.unknown())).default([]),
    })
    .passthrough(),
  has_workbook: z.boolean().default(false),
});

async function fetchWithTimeout(
  url: string,
  init: RequestInit,
  externalSignal?: AbortSignal,
  timeoutMs = ENGINE_REQUEST_TIMEOUT_MS,
): Promise<Response> {
  const controller = new AbortController();
  const onExternalAbort = () => controller.abort();
  if (externalSignal) {
    if (externalSignal.aborted) {
      controller.abort();
    } else {
      externalSignal.addEventListener("abort", onExternalAbort, { once: true });
    }
  }
  const timer = globalThis.setTimeout(() => controller.abort(), timeoutMs);
  try {
    return await fetch(url, { ...init, signal: controller.signal });
  } catch (err) {
    if (err instanceof DOMException && err.name === "AbortError") {
      throw new EngineJobError(
        externalSignal?.aborted ? "network" : "timeout",
        externalSignal?.aborted
          ? "Generation polling cancelled."
          : "Timetable engine request timed out after 90 seconds.",
      );
    }
    throw new EngineJobError(
      "network",
      err instanceof Error ? err.message : "Could not reach timetable engine.",
    );
  } finally {
    globalThis.clearTimeout(timer);
    externalSignal?.removeEventListener("abort", onExternalAbort);
  }
}

async function getEngineAuthHeaders(): Promise<Record<string, string>> {
  if (!isSupabaseConfigured || !supabase) return {};
  try {
    const { data } = await supabase.auth.getSession();
    const token = data.session?.access_token;
    return token ? { Authorization: `Bearer ${token}` } : {};
  } catch {
    return {};
  }
}

async function readErrorDetail(res: Response): Promise<string> {
  try {
    const text = await res.text();
    if (!text) return `HTTP ${res.status}`;
    const parsed = JSON.parse(text) as { detail?: unknown; error?: unknown };
    if (typeof parsed.detail === "string") return parsed.detail;
    if (typeof parsed.error === "string") return parsed.error;
    return text;
  } catch {
    return `HTTP ${res.status}`;
  }
}

export async function submitGenerationJob({
  file,
  configJson,
  timeLimitS = DEFAULT_SOLVE_TIME_LIMIT_S,
  signal,
}: {
  file: Blob | File;
  configJson: string;
  timeLimitS?: number;
  signal?: AbortSignal;
}): Promise<{ job_id: string }> {
  const baseUrl = getEngineBaseUrl();
  const form = new FormData();
  const filename =
    file instanceof File && file.name ? file.name : "distribution.xlsx";
  form.append("file", file, filename);
  form.append("config", configJson);
  form.append("time_limit_s", String(timeLimitS));

  const authHeaders = await getEngineAuthHeaders();
  const res = await fetchWithTimeout(
    `${baseUrl}/api/timetable/generate`,
    {
      method: "POST",
      ...(Object.keys(authHeaders).length > 0 ? { headers: authHeaders } : {}),
      body: form,
    },
    signal,
  );

  if (!res.ok) {
    const detail = await readErrorDetail(res);
    const kind: EngineErrorKind =
      res.status === 401 || res.status === 403
        ? "auth"
        : res.status === 429
          ? "rate-limited"
          : "http";
    throw new EngineJobError(
      kind,
      `Engine submission failed (${res.status}): ${detail}`,
      res.status,
    );
  }

  const parsed = EngineSubmitSchema.safeParse(await res.json());
  if (!parsed.success) {
    throw new EngineJobError(
      "http",
      "Engine did not return a valid job_id.",
    );
  }

  return parsed.data;
}

export async function pollJobStatus(
  jobId: string,
  signal?: AbortSignal,
): Promise<EngineStatusResponse> {
  const baseUrl = getEngineBaseUrl();
  const authHeaders = await getEngineAuthHeaders();
  const res = await fetchWithTimeout(
    `${baseUrl}/api/timetable/status/${encodeURIComponent(jobId)}`,
    {
      method: "GET",
      headers: { Accept: "application/json", ...authHeaders },
    },
    signal,
  );

  if (res.status === 401 || res.status === 403) {
    const detail = await readErrorDetail(res);
    throw new EngineJobError(
      "auth",
      `Engine authorization failed (${res.status}): ${detail}`,
      res.status,
    );
  }

  if (res.status === 429) {
    throw new EngineJobError(
      "rate-limited",
      "Engine edge proxy rate limit (429). Backing off...",
      429,
    );
  }

  if (res.status === 404) {
    const detail = await readErrorDetail(res);
    throw new EngineJobError(
      "engine-restart",
      detail.toLowerCase().includes("unknown job_id")
        ? "Engine restarted mid-solve (404 Unknown job_id) — re-submit workbook."
        : `Job not found (404): ${detail}`,
      404,
    );
  }

  if (!res.ok) {
    const detail = await readErrorDetail(res);
    throw new EngineJobError(
      "http",
      `Could not read job status (${res.status}): ${detail}`,
      res.status,
    );
  }

  const parsed = EngineStatusSchema.safeParse(await res.json());
  if (!parsed.success) {
    throw new EngineJobError(
      "http",
      "Engine returned an unreadable status payload.",
    );
  }

  return parsed.data as EngineStatusResponse;
}

export async function fetchJobResult(
  jobId: string,
  signal?: AbortSignal,
): Promise<EngineResultResponse> {
  const baseUrl = getEngineBaseUrl();
  const authHeaders = await getEngineAuthHeaders();
  const res = await fetchWithTimeout(
    `${baseUrl}/api/timetable/result/${encodeURIComponent(jobId)}`,
    {
      method: "GET",
      headers: { Accept: "application/json", ...authHeaders },
    },
    signal,
  );

  if (res.status === 401 || res.status === 403) {
    const detail = await readErrorDetail(res);
    throw new EngineJobError(
      "auth",
      `Engine authorization failed (${res.status}): ${detail}`,
      res.status,
    );
  }

  if (res.status === 404) {
    throw new EngineJobError(
      "engine-restart",
      "Engine restarted before results were retrieved (404 Unknown job_id) — re-submit workbook.",
      404,
    );
  }

  if (!res.ok) {
    const detail = await readErrorDetail(res);
    throw new EngineJobError(
      "http",
      `Could not fetch generated timetable (${res.status}): ${detail}`,
      res.status,
    );
  }

  const parsed = EngineResultSchema.safeParse(await res.json());
  if (!parsed.success) {
    throw new EngineJobError(
      "http",
      `Generated timetable response schema mismatch: ${parsed.error.issues[0]?.message ?? "invalid payload"}`,
    );
  }

  return parsed.data as unknown as EngineResultResponse;
}

export async function downloadJobWorkbook(
  jobId: string,
  signal?: AbortSignal,
): Promise<Blob> {
  const baseUrl = getEngineBaseUrl();
  const authHeaders = await getEngineAuthHeaders();
  const res = await fetchWithTimeout(
    `${baseUrl}/api/timetable/download/${encodeURIComponent(jobId)}`,
    {
      method: "GET",
      ...(Object.keys(authHeaders).length > 0 ? { headers: authHeaders } : {}),
    },
    signal,
  );

  if (res.status === 401 || res.status === 403) {
    const detail = await readErrorDetail(res);
    throw new EngineJobError(
      "auth",
      `Engine authorization failed (${res.status}): ${detail}`,
      res.status,
    );
  }

  if (res.status === 404) {
    throw new EngineJobError(
      "engine-restart",
      "Engine restarted before workbook download (404 Unknown job_id) — re-submit workbook.",
      404,
    );
  }

  if (!res.ok) {
    const detail = await readErrorDetail(res);
    throw new EngineJobError(
      "http",
      `Could not download workbook (${res.status}): ${detail}`,
      res.status,
    );
  }

  return await res.blob();
}

export function triggerBrowserDownload(data: Blob | string, filename: string): void {
  const blob =
    typeof data === "string"
      ? new Blob([data], { type: "application/json;charset=utf-8" })
      : data;
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = filename;
  document.body.appendChild(anchor);
  anchor.click();
  anchor.remove();
  window.setTimeout(() => URL.revokeObjectURL(url), 1000);
}

function defaultSleep(ms: number, signal?: AbortSignal): Promise<void> {
  return new Promise((resolve, reject) => {
    if (signal?.aborted) {
      reject(new EngineJobError("network", "Polling cancelled."));
      return;
    }
    const timer = globalThis.setTimeout(() => {
      signal?.removeEventListener("abort", onAbort);
      resolve();
    }, ms);
    const onAbort = () => {
      globalThis.clearTimeout(timer);
      reject(new EngineJobError("network", "Polling cancelled."));
    };
    signal?.addEventListener("abort", onAbort, { once: true });
  });
}

export async function runResilientJobPolling({
  jobId,
  onStatus,
  onBackoff,
  signal,
  sleepFn = defaultSleep,
  pollIntervalMs = DEFAULT_POLL_INTERVAL_MS,
  maxPolls = DEFAULT_MAX_POLLS,
  backoffMs = RATE_LIMIT_BACKOFF_MS,
}: {
  jobId: string;
  onStatus?: (status: EngineStatusResponse) => void;
  onBackoff?: (active: boolean) => void;
  signal?: AbortSignal;
  sleepFn?: (ms: number, signal?: AbortSignal) => Promise<void>;
  pollIntervalMs?: number;
  maxPolls?: number;
  backoffMs?: number;
}): Promise<EngineResultResponse> {
  let consecutiveErrors = 0;

  for (let attempt = 0; attempt < maxPolls; attempt++) {
    if (signal?.aborted) {
      throw new EngineJobError("network", "Polling cancelled.");
    }

    let status: EngineStatusResponse | null = null;
    try {
      status = await pollJobStatus(jobId, signal);
      consecutiveErrors = 0;
      onBackoff?.(false);
    } catch (err) {
      if (
        err instanceof EngineJobError &&
        (err.kind === "engine-restart" || err.kind === "auth")
      ) {
        throw err;
      }
      const is429 =
        (err instanceof EngineJobError && err.kind === "rate-limited") ||
        (err instanceof Error && err.message.includes("429"));
      if (is429) {
        onBackoff?.(true);
        await sleepFn(backoffMs, signal);
      } else {
        consecutiveErrors += 1;
        if (consecutiveErrors > MAX_CONSECUTIVE_POLL_ERRORS) {
          throw err;
        }
      }
    }

    if (status) {
      onStatus?.(status);
      if (status.state === "failed") {
        throw new EngineJobError(
          "solver-failed",
          status.error || "The solver could not build a timetable.",
        );
      }
      if (status.state === "done") {
        return await fetchJobResult(jobId, signal);
      }
    }

    await sleepFn(pollIntervalMs, signal);
  }

  throw new EngineJobError(
    "timeout",
    "Timed out waiting for the timetable solver (~8 min poll ceiling reached).",
  );
}

export function buildStorageWorkbookPath(semesterLabel: string | null): string {
  const safe = (semesterLabel ?? "timetable").trim().replace(/\s+/g, "_") || "timetable";
  return `CSE_Routine_${safe}_${Date.now()}.xlsx`;
}

export function toPublishRpcRow(row: RoutineRow): Record<string, unknown> {
  return {
    day: row.day,
    time_start: ClockTime.toHms(row.time_start),
    time_end: ClockTime.toHms(row.time_end),
    subject: row.subject,
    subject_code: row.subject_code,
    teacher_name: row.teacher_name,
    teacher_code: row.teacher_code,
    room: row.room,
    batch: row.batch,
    section: row.section,
    semester: row.semester,
    is_active: row.is_active !== false,
    is_service: Boolean(row.is_service),
  };
}

export async function retryRecordTimetableRun(
  params: RetryAuditParams,
  isDevPreview: boolean,
): Promise<void> {
  if (isDevPreview || !isSupabaseConfigured || !supabase) {
    return;
  }

  const { error } = await supabase.from("timetable_runs").insert({
    semester_label: params.semesterLabel,
    file_path: params.filePath,
    stats: params.stats,
    validation: params.validation,
    row_count: params.rowCount,
    status: "published",
    created_by: params.createdBy,
  });

  if (error) {
    throw new Error(error.message);
  }
}

export async function publishRoutinePipeline({
  jobId,
  result,
  workbookBlob,
  semesterLabel,
  notes,
  notifyUsers,
  baselineCounts,
  isPrivatePreview,
  createdBy,
  isDevPreview,
  onStepChange,
}: {
  jobId: string | null;
  result: EngineResultResponse;
  workbookBlob: Blob | null;
  semesterLabel: string | null;
  notes?: string | null;
  notifyUsers: boolean;
  baselineCounts: BaselineConfigCounts | null;
  isPrivatePreview: boolean;
  createdBy: string | null;
  isDevPreview: boolean;
  onStepChange?: (step: "uploading" | "publishing" | "recording") => void;
}): Promise<PublishPipelineResult> {
  if (isPrivatePreview) {
    throw new Error(
      "Private preview only: source profile is a rehearsal, not publication approval.",
    );
  }
  const allRows = [...result.rows, ...result.service_rows];
  if (allRows.length === 0) {
    throw new Error("Refusing to publish an empty routine.");
  }

  const validationBlocker = blockingValidationErrorFor(result.validation);
  if (validationBlocker) {
    throw new Error(validationBlocker);
  }

  const coTeacherBlockers = findCoTeacherBlockers(
    result.rows,
    result.service_rows,
  );
  if (coTeacherBlockers.length > 0) {
    throw new Error(
      "Shared faculty must be saved in a draft; current hosted storage cannot retain every teacher.",
    );
  }

  const configCheck = assessBaselineConfigForPublish(baselineCounts);
  if (!configCheck.canPublish) {
    throw new Error(
      `Empty-config pre-publish guard blocked publication: ${configCheck.blockingReasons.join(" ")}`,
    );
  }

  // Step 1: Upload rendered .xlsx to Supabase Storage bucket `timetables`
  onStepChange?.("uploading");
  let resolvedBlob = workbookBlob;
  if (!resolvedBlob && jobId && !isDevPreview) {
    resolvedBlob = await downloadJobWorkbook(jobId);
  }

  const filePath = buildStorageWorkbookPath(semesterLabel);
  if (!isDevPreview && isSupabaseConfigured && supabase && resolvedBlob) {
    const { error: uploadError } = await supabase.storage
      .from("timetables")
      .upload(filePath, resolvedBlob, {
        upsert: true,
        contentType:
          "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      });
    if (uploadError) {
      throw new Error(`Storage upload failed (timetables): ${uploadError.message}`);
    }
  }

  // Step 2: Atomic publish via RPC `publish_routine`
  onStepChange?.("publishing");
  const rpcRows = allRows.map(toPublishRpcRow);
  let versionId = "";
  let rowCount = rpcRows.length;

  if (isDevPreview || !isSupabaseConfigured || !supabase) {
    versionId = `preview-ver-${Date.now()}`;
    const normalizedRows: RoutineRow[] = allRows.map((r, idx) => ({
      ...r,
      id: r.id || `pub-${idx}`,
      time_start: ClockTime.toHms(r.time_start),
      time_end: ClockTime.toHms(r.time_end),
      routine_version_id: versionId,
    }));
    replaceDevPreviewRoutines(normalizedRows, {
      id: versionId,
      semester_label: semesterLabel ?? "Spring 2026",
      source: "engine",
      is_active: true,
      row_count: normalizedRows.length,
      stats: result.stats as unknown as Record<string, unknown>,
      validation: result.validation as unknown as Record<string, unknown>,
      notes: notes?.trim() || null,
      published_at: new Date().toISOString(),
      published_by: createdBy,
      created_at: new Date().toISOString(),
    });
  } else {
    const { data, error: rpcError } = await supabase.rpc("publish_routine", {
      p_rows: rpcRows,
      p_semester_label: semesterLabel,
      p_source: "engine",
      p_stats: result.stats,
      p_validation: result.validation,
      p_notes: notes?.trim() || null,
    });

    if (rpcError) {
      throw new Error(`publish_routine RPC failed: ${rpcError.message}`);
    }

    const resMap = (data ?? {}) as Record<string, unknown>;
    versionId = resMap.version_id ? String(resMap.version_id) : "";
    rowCount =
      typeof resMap.row_count === "number" ? resMap.row_count : rpcRows.length;
  }

  // Step 3: Best-effort audit log (`timetable_runs`) + optional broadcast (`notifications`)
  onStepChange?.("recording");
  const retryAuditParams: RetryAuditParams = {
    semesterLabel,
    filePath: resolvedBlob || isDevPreview ? filePath : null,
    stats: result.stats,
    validation: result.validation,
    rowCount,
    createdBy,
  };

  let secondaryAuditError: string | null = null;
  try {
    await retryRecordTimetableRun(retryAuditParams, isDevPreview);
  } catch (err) {
    secondaryAuditError =
      err instanceof Error
        ? err.message
        : "Could not insert timetable_runs audit log.";
  }

  let secondaryBroadcastError: string | null = null;
  if (notifyUsers && !isDevPreview && isSupabaseConfigured && supabase) {
    try {
      const { error: notifError } = await supabase.from("notifications").insert({
        type: "university",
        title: "New class routine published",
        body: `${semesterLabel ?? "The new"} class routine is now live. Open your routine to see the updated schedule.`,
        sent_by: createdBy,
        target_role: null,
        target_batch: null,
        target_section: null,
      });
      if (notifError) {
        secondaryBroadcastError = notifError.message;
      }
    } catch (err) {
      secondaryBroadcastError =
        err instanceof Error ? err.message : "Broadcast failed.";
    }
  }

  return {
    published: true,
    versionId,
    rowCount,
    filePath: retryAuditParams.filePath,
    secondaryAuditError,
    secondaryBroadcastError,
    retryAuditParams: secondaryAuditError ? retryAuditParams : null,
  };
}

export type { EngineConfigPayload, EngineStats, EngineValidation };
