import {
  getSupabaseConfig,
  isSupabaseConfigured,
  supabase,
} from "@/services/supabase";
import type { GateStatusInfo, SchedulingGateState } from "@/features/scheduling/types";

export interface LiveGateProbeInput {
  supabaseConfigured: boolean;
  isDevPreview: boolean;
  readRpcAvailable: boolean;
  appendRpcAvailable: boolean;
  scopeReadAuthorized: boolean;
  revisionRowExists: boolean;
}

/**
 * Pure fail-closed Gate A–D resolver.
 * Never unlocks Gate A simply because a row exists unless both the scope query
 * and `read_course_distribution_revision` RPC contract pass.
 * Keeps Gates C and D unconditionally locked in Phase 4B Live Mode until Phase 4A
 * backend contracts (`publish_routine` archival + revision-bound policy/validation) ship.
 */
export function resolveLiveSchedulingGates(
  probe: LiveGateProbeInput,
): SchedulingGateState {
  const probedAt = new Date().toISOString();

  const canAttemptLive = probe.supabaseConfigured && !probe.isDevPreview;
  const gateAUnlocked =
    canAttemptLive && probe.scopeReadAuthorized && probe.readRpcAvailable;
  const gateBUnlocked = gateAUnlocked && probe.appendRpcAvailable;

  const gateA: GateStatusInfo = {
    key: "gateA",
    code: "A",
    label: "Scoped Source Read",
    contractName: "read_course_distribution_revision",
    unlocked: gateAUnlocked,
    reason: gateAUnlocked
      ? "Verified read_course_distribution_revision RPC and scheduling_scope_id contract."
      : !canAttemptLive
        ? "Disconnected from live Supabase RPC contract."
        : !probe.readRpcAvailable
          ? "read_course_distribution_revision RPC or revision_version schema is unavailable."
          : "Scoped distribution read permission denied or unverified.",
  };

  const gateB: GateStatusInfo = {
    key: "gateB",
    code: "B",
    label: "Audited Corrections",
    contractName: "append_course_distribution_correction",
    unlocked: gateBUnlocked,
    reason: gateBUnlocked
      ? "Verified 8-parameter append_course_distribution_correction RPC with SQLSTATE 40001 guard."
      : !gateAUnlocked
        ? "Requires Gate A before audited corrections can be appended."
        : "append_course_distribution_correction RPC could not be verified on this project.",
  };

  const gateC: GateStatusInfo = {
    key: "gateC",
    code: "C",
    label: "Policy Snapshot & Preflight",
    contractName: "Phase 4A · Validation Artifact Contract",
    unlocked: false,
    reason:
      "Fail-closed in Phase 4B: revision-bound PolicySnapshot and validation_report server contract await Phase 4A backend authorization.",
  };

  const gateD: GateStatusInfo = {
    key: "gateD",
    code: "D",
    label: "CP-SAT Solve & Archive Publish",
    contractName: "Phase 4A · Archiving publish_routine()",
    unlocked: false,
    reason:
      "Fail-closed in Phase 4B: revision-bound solver pipeline and archiving publish_routine() await Phase 4A backend authorization.",
  };

  return { gateA, gateB, gateC, gateD, probedAt };
}

export const ALL_GATES_LOCKED_STATE: SchedulingGateState =
  resolveLiveSchedulingGates({
    supabaseConfigured: false,
    isDevPreview: false,
    readRpcAvailable: false,
    appendRpcAvailable: false,
    scopeReadAuthorized: false,
    revisionRowExists: false,
  });

function isMissingFunctionOrSchemaError(err: {
  code?: string;
  message?: string;
} | null): boolean {
  if (!err) return false;
  const code = err.code ?? "";
  const msg = (err.message ?? "").toLowerCase();
  return (
    code === "PGRST202" ||
    code === "42883" ||
    code === "42P01" ||
    code === "42703" ||
    msg.includes("could not find the function") ||
    msg.includes("does not exist")
  );
}

/**
 * Inspects PostgREST OpenAPI root schema (`GET /rest/v1/`) for RPC path presence
 * without invoking PL/pgSQL functions with nil UUIDs (which raise P0002 -> HTTP 500).
 */
async function probeRpcPathsViaOpenApi(): Promise<{
  readRpcAvailable: boolean;
  appendRpcAvailable: boolean;
} | null> {
  const { url, anonKey } = getSupabaseConfig();
  if (!url || !anonKey || typeof fetch !== "function") return null;

  try {
    const sessionRes = supabase ? await supabase.auth.getSession() : null;
    const accessToken = sessionRes?.data?.session?.access_token;
    const headers: Record<string, string> = {
      Accept: "application/openapi+json",
      apikey: anonKey,
    };
    if (accessToken) {
      headers.Authorization = `Bearer ${accessToken}`;
    }

    const res = await fetch(`${url.replace(/\/+$/, "")}/rest/v1/`, {
      method: "GET",
      headers,
    });
    if (!res.ok) return null;

    const spec = (await res.json()) as { paths?: Record<string, unknown> } | null;
    const paths = spec?.paths;
    if (!paths || typeof paths !== "object") return null;

    return {
      readRpcAvailable: Boolean(paths["/rpc/read_course_distribution_revision"]),
      appendRpcAvailable: Boolean(
        paths["/rpc/append_course_distribution_correction"],
      ),
    };
  } catch {
    return null;
  }
}

/**
 * Live capability probe against Supabase Track 2 distribution schema (`20261106130000`).
 * Never mutates data and never invokes RPCs with nil UUIDs: queries
 * `course_distribution_revisions(id, revision_version, status)` +
 * `course_distribution_sources(id, scheduling_scope_id)` and checks PostgREST OpenAPI
 * RPC exposure (falling back to `read_course_distribution_revision` only when a real
 * revision ID exists).
 */
export async function probeLiveSchedulingCapabilities(
  isDevPreview: boolean,
): Promise<SchedulingGateState> {
  if (isDevPreview || !isSupabaseConfigured || !supabase) {
    return resolveLiveSchedulingGates({
      supabaseConfigured: isSupabaseConfigured,
      isDevPreview,
      readRpcAvailable: false,
      appendRpcAvailable: false,
      scopeReadAuthorized: false,
      revisionRowExists: false,
    });
  }

  let scopeReadAuthorized = false;
  let revisionRowExists = false;
  let readRpcAvailable = false;
  let appendRpcAvailable = false;

  try {
    const [revQuery, srcQuery] = await Promise.all([
      supabase
        .from("course_distribution_revisions")
        .select("id, revision_version, status")
        .limit(1),
      supabase
        .from("course_distribution_sources")
        .select("id, scheduling_scope_id")
        .limit(1),
    ]);

    if (!revQuery.error && !srcQuery.error) {
      scopeReadAuthorized = true;
      revisionRowExists = (revQuery.data ?? []).length > 0;
    }

    const openApiResult = await probeRpcPathsViaOpenApi();
    if (openApiResult) {
      readRpcAvailable = openApiResult.readRpcAvailable;
      appendRpcAvailable = openApiResult.appendRpcAvailable;
    } else if (!revQuery.error && revQuery.data && revQuery.data[0]) {
      const realRevisionId = String(revQuery.data[0].id);
      const readProbe = await supabase.rpc("read_course_distribution_revision", {
        target_revision: realRevisionId,
      });
      if (!isMissingFunctionOrSchemaError(readProbe.error)) {
        readRpcAvailable = true;
      }
    }
  } catch {
    return ALL_GATES_LOCKED_STATE;
  }

  return resolveLiveSchedulingGates({
    supabaseConfigured: true,
    isDevPreview: false,
    readRpcAvailable,
    appendRpcAvailable,
    scopeReadAuthorized,
    revisionRowExists,
  });
}
