import { EngineJobError } from "@/features/routine/services/timetableEngineService";
import { getEngineBaseUrl } from "@/services/engineHealth";
import { isSupabaseConfigured, supabase } from "@/services/supabase";

export interface AdjunctDayBandsConfig {
  two_courses_max_days: number;
  three_courses_min_days: number;
  three_courses_max_days: number;
  four_plus_courses_min_days: number;
  four_plus_courses_max_days: number;
}

export interface PolicySnapshotPayload {
  daily_slot_count: 6 | 7;
  allow_online_slot: boolean;
  friday_no_p4: boolean;
  faculty_preference_weight: number;
  sust_adjunct_single_half_day: boolean;
  sust_adjunct_max_gap: number;
  low_credit_cse_theory_consecutive: boolean;
  three_credit_theory_spread: boolean;
  adjunct_day_bands: AdjunctDayBandsConfig;
  [key: string]: unknown;
}

export interface PolicySnapshotRecord {
  id: string;
  scheduling_scope_id: string | null;
  revision_id: string | null;
  label: string;
  version: number;
  is_active: boolean;
  schema_version: number;
  default_section_weekend: [string, string];
  batch_max_off_day_spread: number;
  max_section_internal_gap: number;
  allow_sessional_across_break: boolean;
  physics_lab_course_codes: string[];
  policy_payload: PolicySnapshotPayload;
  policy_hash: string;
  created_by: string | null;
  created_at: string;
}

export interface SavePolicySnapshotInput {
  revisionId?: string | null;
  scopeId?: string | null;
  label: string;
  defaultSectionWeekend: [string, string];
  batchMaxOffDaySpread: number;
  maxSectionInternalGap: number;
  allowSessionalAcrossBreak: boolean;
  physicsLabCourseCodes: string[];
  policyPayload: PolicySnapshotPayload;
}

export interface PreflightCheckItem {
  id: string;
  rule_id: string;
  category: string;
  status: "passed" | "warning" | "blocker";
  severity: "info" | "warning" | "critical";
  title: string;
  description: string;
  target_stage: "distribution" | "policy" | "readiness" | "generate" | "review";
  target_row?: number;
  affected_entities: string[];
}

export interface PreflightValidationReport {
  ok: boolean;
  policy_hash: string;
  allow_sessional_across_break: boolean;
  checks: PreflightCheckItem[];
  blockers: PreflightCheckItem[];
  warnings: PreflightCheckItem[];
  summary: {
    blocker_count: number;
    warning_count: number;
    passed_count: number;
    active_faculty_count: number;
    active_room_count: number;
    active_course_count: number;
    active_section_count: number;
    allow_sessional_across_break: boolean;
  };
  rule_coverage: string[];
}

export interface ValidationArtifactRecord {
  id: string;
  revision_id: string;
  artifact_kind: string;
  status: "current" | "stale";
  invalidated_at: string | null;
  policy_snapshot_id: string | null;
  payload: PreflightValidationReport | Record<string, unknown>;
  summary: Record<string, unknown>;
  has_blockers: boolean;
  created_at: string;
  updated_at: string | null;
}

export const DEFAULT_POLICY_SNAPSHOT_FORM: SavePolicySnapshotInput = {
  revisionId: null,
  scopeId: null,
  label: "Committee Policy Snapshot",
  defaultSectionWeekend: ["Friday", "Saturday"],
  batchMaxOffDaySpread: 1,
  maxSectionInternalGap: 1,
  allowSessionalAcrossBreak: false, // D5 explicit opt-in default false
  physicsLabCourseCodes: [],
  policyPayload: {
    daily_slot_count: 7,
    allow_online_slot: false,
    friday_no_p4: true,
    faculty_preference_weight: 85,
    sust_adjunct_single_half_day: true,
    sust_adjunct_max_gap: 2,
    low_credit_cse_theory_consecutive: true,
    three_credit_theory_spread: true,
    adjunct_day_bands: {
      two_courses_max_days: 2,
      three_courses_min_days: 3,
      three_courses_max_days: 4,
      four_plus_courses_min_days: 4,
      four_plus_courses_max_days: 5,
    },
  },
};

function normalizePolicySnapshotRow(
  raw: Record<string, unknown>,
): PolicySnapshotRecord {
  const rawWeekend = Array.isArray(raw.default_section_weekend)
    ? raw.default_section_weekend.map((d) => String(d))
    : ["Friday", "Saturday"];
  const weekend: [string, string] =
    rawWeekend.length === 2
      ? [rawWeekend[0]!, rawWeekend[1]!]
      : ["Friday", "Saturday"];

  const rawPayload =
    raw.policy_payload && typeof raw.policy_payload === "object"
      ? (raw.policy_payload as Record<string, unknown>)
      : {};
  const defaults = DEFAULT_POLICY_SNAPSHOT_FORM.policyPayload;
  const rawBands =
    rawPayload.adjunct_day_bands &&
    typeof rawPayload.adjunct_day_bands === "object"
      ? (rawPayload.adjunct_day_bands as Record<string, unknown>)
      : {};

  return {
    id: String(raw.id),
    scheduling_scope_id: raw.scheduling_scope_id
      ? String(raw.scheduling_scope_id)
      : null,
    revision_id: raw.revision_id ? String(raw.revision_id) : null,
    label: String(raw.label ?? "Committee Policy Snapshot"),
    version: Number(raw.version ?? 1) || 1,
    is_active: raw.is_active !== false,
    schema_version: Number(raw.schema_version ?? 1) || 1,
    default_section_weekend: weekend,
    batch_max_off_day_spread:
      typeof raw.batch_max_off_day_spread === "number"
        ? raw.batch_max_off_day_spread
        : 1,
    max_section_internal_gap:
      typeof raw.max_section_internal_gap === "number"
        ? raw.max_section_internal_gap
        : 1,
    allow_sessional_across_break: Boolean(raw.allow_sessional_across_break),
    physics_lab_course_codes: Array.isArray(raw.physics_lab_course_codes)
      ? raw.physics_lab_course_codes.map((c) => String(c).toUpperCase())
      : [],
    policy_payload: {
      ...rawPayload,
      daily_slot_count:
        Number(rawPayload.daily_slot_count ?? defaults.daily_slot_count) === 6
          ? 6
          : 7,
      allow_online_slot: Boolean(
        rawPayload.allow_online_slot ?? defaults.allow_online_slot,
      ),
      friday_no_p4: Boolean(rawPayload.friday_no_p4 ?? defaults.friday_no_p4),
      faculty_preference_weight: Number(
        rawPayload.faculty_preference_weight ??
          defaults.faculty_preference_weight,
      ),
      sust_adjunct_single_half_day: Boolean(
        rawPayload.sust_adjunct_single_half_day ??
          defaults.sust_adjunct_single_half_day,
      ),
      sust_adjunct_max_gap: Number(
        rawPayload.sust_adjunct_max_gap ?? defaults.sust_adjunct_max_gap,
      ),
      low_credit_cse_theory_consecutive: Boolean(
        rawPayload.low_credit_cse_theory_consecutive ??
          defaults.low_credit_cse_theory_consecutive,
      ),
      three_credit_theory_spread: Boolean(
        rawPayload.three_credit_theory_spread ??
          defaults.three_credit_theory_spread,
      ),
      adjunct_day_bands: {
        two_courses_max_days: Number(
          rawBands.two_courses_max_days ??
            defaults.adjunct_day_bands.two_courses_max_days,
        ),
        three_courses_min_days: Number(
          rawBands.three_courses_min_days ??
            defaults.adjunct_day_bands.three_courses_min_days,
        ),
        three_courses_max_days: Number(
          rawBands.three_courses_max_days ??
            defaults.adjunct_day_bands.three_courses_max_days,
        ),
        four_plus_courses_min_days: Number(
          rawBands.four_plus_courses_min_days ??
            defaults.adjunct_day_bands.four_plus_courses_min_days,
        ),
        four_plus_courses_max_days: Number(
          rawBands.four_plus_courses_max_days ??
            defaults.adjunct_day_bands.four_plus_courses_max_days,
        ),
      },
    },
    policy_hash: String(raw.policy_hash ?? ""),
    created_by: raw.created_by ? String(raw.created_by) : null,
    created_at: String(raw.created_at ?? new Date().toISOString()),
  };
}

export async function readActivePolicySnapshot(
  params: { revisionId?: string | null; scopeId?: string | null },
  client: Pick<NonNullable<typeof supabase>, "rpc"> | null = supabase,
): Promise<PolicySnapshotRecord | null> {
  if (!isSupabaseConfigured && client === supabase) return null;
  if (!client) return null;

  const { data, error } = await client.rpc("read_active_policy_snapshot", {
    p_revision_id: params.revisionId ?? null,
    p_scope_id: params.scopeId ?? null,
  });

  if (error) {
    throw new Error(error.message);
  }
  if (!data || typeof data !== "object") return null;
  return normalizePolicySnapshotRow(data as Record<string, unknown>);
}

export async function savePolicySnapshot(
  input: SavePolicySnapshotInput,
  client: Pick<NonNullable<typeof supabase>, "rpc"> | null = supabase,
): Promise<PolicySnapshotRecord> {
  if (!client) {
    throw new Error(
      "Saving policy snapshots requires an authenticated Supabase session.",
    );
  }

  const rpcPayload = {
    p_revision_id: input.revisionId ?? null,
    p_scope_id: input.scopeId ?? null,
    p_label: input.label.trim() || "Committee Policy Snapshot",
    p_default_section_weekend: [...input.defaultSectionWeekend],
    p_batch_max_off_day_spread: input.batchMaxOffDaySpread,
    p_max_section_internal_gap: input.maxSectionInternalGap,
    p_allow_sessional_across_break: Boolean(input.allowSessionalAcrossBreak),
    p_physics_lab_course_codes: Array.from(
      new Set(
        input.physicsLabCourseCodes
          .map((c) => c.trim().toUpperCase())
          .filter(Boolean),
      ),
    ),
    p_policy_payload: input.policyPayload,
  };

  const { data, error } = await client.rpc("save_policy_snapshot", rpcPayload);
  if (error) {
    throw new Error(error.message);
  }

  return normalizePolicySnapshotRow(data as Record<string, unknown>);
}

export async function fetchLatestValidationArtifact(
  revisionId: string,
): Promise<ValidationArtifactRecord | null> {
  if (!isSupabaseConfigured || !supabase || !revisionId) return null;

  const { data, error } = await supabase
    .from("course_distribution_artifacts")
    .select(
      "id, revision_id, artifact_kind, status, invalidated_at, policy_snapshot_id, payload, summary, has_blockers, created_at, updated_at",
    )
    .eq("revision_id", revisionId)
    .eq("artifact_kind", "validation_report")
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle();

  if (error) {
    throw new Error(error.message);
  }
  return (data as ValidationArtifactRecord | null) ?? null;
}

export async function saveValidationReportArtifact(
  params: {
    revisionId: string;
    policySnapshotId?: string | null;
    report: PreflightValidationReport;
  },
  client: Pick<NonNullable<typeof supabase>, "rpc"> | null = supabase,
): Promise<ValidationArtifactRecord> {
  if (!client) {
    throw new Error(
      "Persisting validation artifacts requires an authenticated Supabase session.",
    );
  }

  const { data, error } = await client.rpc("save_validation_report_artifact", {
    p_revision_id: params.revisionId,
    p_policy_snapshot_id: params.policySnapshotId ?? null,
    p_payload: params.report,
    p_summary: params.report.summary,
    p_has_blockers: !params.report.ok || params.report.blockers.length > 0,
  });

  if (error) {
    throw new Error(error.message);
  }
  return data as ValidationArtifactRecord;
}

export async function validatePolicyReadiness(
  payload: {
    policy_snapshot: Record<string, unknown>;
    faculty: Array<Record<string, unknown>>;
    rooms: Array<Record<string, unknown>>;
    courses: Array<Record<string, unknown>>;
    sections: Array<Record<string, unknown>>;
    settings: Record<string, unknown>;
    offerings?: Array<Record<string, unknown>>;
  },
  signal?: AbortSignal,
): Promise<PreflightValidationReport> {
  const baseUrl = getEngineBaseUrl();
  let authHeader: Record<string, string> = {};
  if (isSupabaseConfigured && supabase) {
    try {
      const { data } = await supabase.auth.getSession();
      const token = data.session?.access_token;
      if (token) authHeader = { Authorization: `Bearer ${token}` };
    } catch {
      authHeader = {};
    }
  }

  const res = await fetch(`${baseUrl}/api/timetable/validate-policy-readiness`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Accept: "application/json",
      ...authHeader,
    },
    body: JSON.stringify(payload),
    signal,
  });

  if (!res.ok) {
    let detail = `HTTP ${res.status}`;
    try {
      const json = (await res.json()) as { detail?: string };
      if (typeof json.detail === "string") detail = json.detail;
    } catch {
      // ignore non-json
    }
    if (res.status === 401 || res.status === 403) {
      throw new EngineJobError("auth", `Engine authorization failed (${res.status}): ${detail}`, res.status);
    }
    if (res.status === 429) {
      throw new EngineJobError("rate-limited", detail, 429);
    }
    throw new EngineJobError("http", `Preflight validation failed (${res.status}): ${detail}`, res.status);
  }

  return (await res.json()) as PreflightValidationReport;
}
