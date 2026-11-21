import { isSupabaseConfigured, supabase } from "@/services/supabase";
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
 * Live capability probe against Supabase Track 2 distribution schema (`20261106130000`).
 * Never mutates data: queries `course_distribution_revisions(revision_version)` and probes
 * RPC signatures with nil UUID to verify function presence without altering rows.
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
    const revQuery = await supabase
      .from("course_distribution_revisions")
      .select("id, revision_version, status")
      .limit(1);

    if (!revQuery.error) {
      scopeReadAuthorized = true;
      revisionRowExists = (revQuery.data ?? []).length > 0;
    }

    const nilUuid = "00000000-0000-0000-0000-000000000000";
    const readProbe = await supabase.rpc("read_course_distribution_revision", {
      target_revision: nilUuid,
    });
    // Expect P0002 (Unknown revision) or 42501 when the function + schema exist;
    // only PGRST202/42883/42P01 means the RPC or schema contract is missing.
    if (!isMissingFunctionOrSchemaError(readProbe.error)) {
      readRpcAvailable = true;
    }

    const appendProbe = await supabase.rpc(
      "append_course_distribution_correction",
      {
        target_revision: nilUuid,
        expected_revision_version: 0,
        target_row: 6,
        target_column: "I",
        prior_formula: null,
        prior_cached_value: null,
        next_effective_value: null,
        reason: "capability-probe",
      },
    );
    if (!isMissingFunctionOrSchemaError(appendProbe.error)) {
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
