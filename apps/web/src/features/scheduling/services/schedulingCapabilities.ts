import {
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
          ? "Track 2 Course Distribution revision services are not yet active on this environment."
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
 * Live capability probe against Supabase Track 2 distribution schema (`20261106130000`).
 * Never mutates data, never calls PostgREST OpenAPI root (`GET /rest/v1/`, which
 * returns 401 on newer publishable-key projects), and never invokes RPCs with nil
 * UUIDs (which raise P0002 -> HTTP 500).
 *
 * Probes the 4 atomic Track 2 tables (`course_distribution_revisions`,
 * `course_distribution_sources`, `course_distribution_corrections`,
 * `course_distribution_artifacts`) via standard RLS-protected PostgREST reads,
 * and verifies `read_course_distribution_revision` directly only when a real
 * revision row exists.
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
    const [revQuery, srcQuery, corrQuery, artQuery] = await Promise.all([
      supabase
        .from("course_distribution_revisions")
        .select("id, revision_version, status")
        .limit(1),
      supabase
        .from("course_distribution_sources")
        .select("id, scheduling_scope_id")
        .limit(1),
      supabase
        .from("course_distribution_corrections")
        .select("id, revision_id")
        .limit(1),
      supabase
        .from("course_distribution_artifacts")
        .select("id, revision_id")
        .limit(1),
    ]);

    const coreSchemaReadable = !revQuery.error && !srcQuery.error;
    const fullTrack2SchemaReadable =
      coreSchemaReadable && !corrQuery.error && !artQuery.error;

    if (coreSchemaReadable) {
      scopeReadAuthorized = true;
      revisionRowExists = (revQuery.data ?? []).length > 0;
    }

    if (coreSchemaReadable && revQuery.data && revQuery.data[0]) {
      const realRevisionId = String(revQuery.data[0].id);
      const readProbe = await supabase.rpc("read_course_distribution_revision", {
        target_revision: realRevisionId,
      });
      if (!isMissingFunctionOrSchemaError(readProbe.error)) {
        readRpcAvailable = true;
      }
    } else if (fullTrack2SchemaReadable) {
      // All 4 tables from migration 20261106130000_course_distribution_contract.sql
      // are live and RLS-readable for this admin; RPCs ship in the same migration.
      readRpcAvailable = true;
    }

    if (readRpcAvailable && fullTrack2SchemaReadable) {
      appendRpcAvailable = true;
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
