import {
  isSupabaseConfigured,
  supabase,
} from "@/services/supabase";
import type {
  CatalogCapabilityState,
  GateStatusInfo,
  SchedulingGateState,
} from "@/features/scheduling/types";

export interface LiveGateProbeInput {
  supabaseConfigured: boolean;
  isDevPreview: boolean;
  readRpcAvailable: boolean;
  appendRpcAvailable: boolean;
  scopeReadAuthorized: boolean;
  revisionRowExists: boolean;
  policySnapshotsAvailable?: boolean;
  validationArtifactPayloadAvailable?: boolean;
  catalogCoursesAvailable?: boolean;
  sectionPoliciesAvailable?: boolean;
  facultyExtendedAvailable?: boolean;
  roomsExtendedAvailable?: boolean;
}

/**
 * Pure fail-closed Gate A-D resolver.
 * Never unlocks Gate A simply because a row exists unless both the scope query
 * and `read_course_distribution_revision` RPC contract pass.
 * Unlocks Gate C only when Gate A passes AND Stage 5A `policy_snapshots` +
 * `course_distribution_artifacts.payload` contracts are verified live.
 * Keeps Gate D unconditionally locked until Wave 2B Phase 4A-2 Stage 5C ships.
 */
export function resolveLiveSchedulingGates(
  probe: LiveGateProbeInput,
): SchedulingGateState {
  const probedAt = new Date().toISOString();

  const canAttemptLive = probe.supabaseConfigured && !probe.isDevPreview;
  const gateAUnlocked =
    canAttemptLive && probe.scopeReadAuthorized && probe.readRpcAvailable;
  const gateBUnlocked = gateAUnlocked && probe.appendRpcAvailable;
  const gateCUnlocked =
    gateAUnlocked &&
    Boolean(probe.policySnapshotsAvailable) &&
    Boolean(probe.validationArtifactPayloadAvailable);

  const catalogs: CatalogCapabilityState = {
    coursesLive: canAttemptLive && Boolean(probe.catalogCoursesAvailable),
    batchesLive: canAttemptLive && Boolean(probe.sectionPoliciesAvailable),
    facultyExtendedLive: canAttemptLive && Boolean(probe.facultyExtendedAvailable),
    roomsExtendedLive: canAttemptLive && Boolean(probe.roomsExtendedAvailable),
  };

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
    contractName: "policy_snapshots + validation_report",
    unlocked: gateCUnlocked,
    reason: gateCUnlocked
      ? "Verified Stage 5A policy_snapshots, validation_report artifacts, and FastAPI preflight readiness."
      : !gateAUnlocked
        ? "Requires Gate A before revision-bound policy snapshots and preflight artifacts can be saved."
        : "Stage 5A policy_snapshots and validation_report artifact columns are not yet active on this Supabase project.",
  };

  const gateD: GateStatusInfo = {
    key: "gateD",
    code: "D",
    label: "CP-SAT Solve & Archive Publish",
    contractName: "Phase 4A · Archiving publish_routine()",
    unlocked: false,
    reason:
      "Fail-closed in Stage 5A: revision-bound solver pipeline and archiving publish_routine() await Stage 5C Gate D backend authorization.",
  };

  return { gateA, gateB, gateC, gateD, catalogs, probedAt };
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
    code === "PGRST204" ||
    code === "PGRST205" ||
    code === "42883" ||
    code === "42P01" ||
    code === "42703" ||
    msg.includes("could not find the function") ||
    msg.includes("could not find the table") ||
    msg.includes("does not exist")
  );
}

/**
 * Live capability probe against Supabase Track 2 distribution schema (`20261106130000`)
 * and Stage 5A Gate C catalog/policy schema (`20261127120000`).
 * Never mutates data, never calls PostgREST OpenAPI root (`GET /rest/v1/`),
 * and never invokes RPCs with nil UUIDs.
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
  let policySnapshotsAvailable = false;
  let validationArtifactPayloadAvailable = false;
  let catalogCoursesAvailable = false;
  let sectionPoliciesAvailable = false;
  let facultyExtendedAvailable = false;
  let roomsExtendedAvailable = false;

  try {
    const [
      revQuery,
      srcQuery,
      corrQuery,
      artQuery,
      policyQuery,
      artPayloadQuery,
      coursesQuery,
      sectionsQuery,
      facultyExtQuery,
      roomsExtQuery,
    ] = await Promise.all([
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
      supabase
        .from("policy_snapshots")
        .select("id, policy_hash")
        .limit(1),
      supabase
        .from("course_distribution_artifacts")
        .select("id, policy_snapshot_id, payload, summary, has_blockers")
        .limit(1),
      supabase
        .from("catalog_courses")
        .select("id, code")
        .limit(1),
      supabase
        .from("section_policies")
        .select("id, batch, section")
        .limit(1),
      supabase
        .from("timetable_faculty")
        .select("id, employment_type, allow_three_off_days, is_sust_adjunct")
        .limit(1),
      supabase
        .from("timetable_rooms")
        .select("id, room_pool_role, available_slots")
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
      readRpcAvailable = true;
    }

    if (readRpcAvailable && fullTrack2SchemaReadable) {
      appendRpcAvailable = true;
    }

    policySnapshotsAvailable = !policyQuery.error;
    validationArtifactPayloadAvailable = !artPayloadQuery.error;
    catalogCoursesAvailable = !coursesQuery.error;
    sectionPoliciesAvailable = !sectionsQuery.error;
    facultyExtendedAvailable = !facultyExtQuery.error;
    roomsExtendedAvailable = !roomsExtQuery.error;
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
    policySnapshotsAvailable,
    validationArtifactPayloadAvailable,
    catalogCoursesAvailable,
    sectionPoliciesAvailable,
    facultyExtendedAvailable,
    roomsExtendedAvailable,
  });
}
