export type WorkbenchStageId =
  | "distribution"
  | "policy"
  | "readiness"
  | "generate"
  | "review";

export type WorkbenchMode = "live" | "preview";

export type GateKey = "gateA" | "gateB" | "gateC" | "gateD";

export interface GateStatusInfo {
  key: GateKey;
  code: "A" | "B" | "C" | "D";
  label: string;
  contractName: string;
  unlocked: boolean;
  reason: string;
}

export interface CatalogCapabilityState {
  coursesLive: boolean;
  batchesLive: boolean;
  facultyExtendedLive: boolean;
  roomsExtendedLive: boolean;
}

export interface SchedulingGateState {
  gateA: GateStatusInfo;
  gateB: GateStatusInfo;
  gateC: GateStatusInfo;
  gateD: GateStatusInfo;
  catalogs?: CatalogCapabilityState;
  probedAt: string;
}

export type DistributionColumn =
  | "A"
  | "B"
  | "C"
  | "D"
  | "E"
  | "F"
  | "G"
  | "H"
  | "I"
  | "J"
  | "K"
  | "L";

export type DistributionRecordStatus =
  | "verified"
  | "corrected"
  | "conflict"
  | "pendingTeacher";

export interface DistributionCorrection {
  id: string;
  row: number;
  column: DistributionColumn;
  originalValue: string;
  originalFormula?: string | null;
  originalCachedValue?: string | number | null;
  effectiveValue: string;
  reason: string;
  author: string;
  timestamp: string;
  revisionVersion: number;
}

export interface DistributionSourceRecord {
  row: number;
  batch: string; // Col A
  section: string; // Col B
  courseCode: string; // Col C
  courseTitle: string; // Col D
  credit: number; // Col E
  prerequisite: string | null; // Col F
  conductingDept: string; // Col G
  studentCount: number | null; // Col H
  teacher: string; // Col I
  classes: number; // Col J
  durationMinutes: number; // Col K
  classesPerWeek: number; // Col L
  formulaJ: string | null;
  formulaL: string | null;
  cachedJ: number | null;
  cachedL: number | null;
  corrections: readonly DistributionCorrection[];
  conflicts: readonly string[];
}

export interface RevisionContext {
  scopeId: string;
  revisionId: string;
  department: string;
  semester: string;
  revisionNumber: number;
  revisionVersion: number;
  status: "draft" | "accepted" | "superseded";
  sourceHash: string;
  sourceFileName: string;
  sheetName: string;
  acceptedAt: string;
  acceptedBy: string;
  isFresh: boolean;
  totalRows: number;
  correctionCount: number;
  conflictCount: number;
}

export type ArtifactStatus = "current" | "stale" | "missing";

export interface ArtifactFreshnessSummary {
  normalizedInputStatus: ArtifactStatus;
  validationReportStatus: ArtifactStatus;
  generationOutputStatus: ArtifactStatus;
  validatedAgainstVersion: number | null;
}

/** Exact 8-parameter payload matching `public.append_course_distribution_correction`. */
export interface AppendCorrectionRpcParams {
  target_revision: string;
  expected_revision_version: number;
  target_row: number;
  target_column: DistributionColumn;
  prior_formula: string | null;
  prior_cached_value: string | number | null;
  next_effective_value: string | number | null;
  reason: string;
}

/** Exact JSONB shape returned by `public.read_course_distribution_revision(target_revision)`. */
export interface ReadDistributionRevisionRpcResponse {
  source_id: string;
  revision_id: string;
  revision_number: number;
  revision_version: number;
  status: "draft" | "accepted" | "superseded";
  source_sha256: string;
  source_bytes_base64: string;
  sheet_name: string;
  corrections: Array<{
    source_row: number;
    source_column: DistributionColumn;
    original_formula: string | null;
    original_cached_value: string | number | null;
    effective_value: string | number | null;
  }>;
}

export type PolicyPillarId =
  | "calendar"
  | "faculty"
  | "facilities"
  | "distribution"
  | "governance";

export type PolicyValueType =
  | "slotGridSelector"
  | "weekendPairSelector"
  | "intStepper"
  | "timeWindowList"
  | "dayBandMatrix"
  | "booleanToggle"
  | "textRule";

export interface PolicyConfigItem {
  pillar: PolicyPillarId;
  category: string;
  ruleId: string;
  label: string;
  description: string;
  defaultValue: string;
  overrideValue: string;
  effectiveValue: string;
  isLocked: boolean;
  snapshotRequirement: string;
  valueType: PolicyValueType;
  typedPayload: Record<string, unknown>;
}

export type ReadinessSeverity = "critical" | "warning" | "info";

export interface ReadinessItem {
  id: string;
  category: string;
  title: string;
  description: string;
  severity: ReadinessSeverity;
  affectedEntities: readonly string[];
  targetStage: WorkbenchStageId;
  targetRow?: number;
  isResolved: boolean;
}

export interface SolverObjectiveConfig {
  timeLimitSeconds: number;
  cohortCompactnessWeight: number;
  facultyPreferenceWeight: number;
  theorySpreadWeight: number;
  latePeriodAvoidanceWeight: number;
  enableSessionalBreakCrossing: boolean;
  engineProfile: string;
}

export interface SolverConflictDiagnostic {
  constraintId: string;
  title: string;
  humanExplanation: string;
  affectedEntities: readonly string[];
  targetStage: WorkbenchStageId;
  targetRow?: number;
  suggestedAction: string;
}

export type SolverRunOutcome =
  | "idle"
  | "running"
  | "optimal"
  | "feasible"
  | "infeasible"
  | "unknown"
  | "time_limit_exhausted"
  | "input_error";

export interface SolverExecutionResult {
  outcome: SolverRunOutcome;
  outcomeLabel: string;
  hardViolations: number;
  softScorePercent: number;
  variablesExplored: number;
  elapsedSeconds: number;
  conflictDetails: readonly string[];
  conflictDiagnostics: readonly SolverConflictDiagnostic[];
  diagnostics: Record<string, string>;
}

export interface LiveCorrectionDraft {
  row: number;
  column: DistributionColumn;
  value: string;
  reason: string;
}
