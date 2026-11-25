import { create } from "zustand";
import {
  PREVIEW_ARTIFACT_FRESHNESS,
  PREVIEW_CANDIDATE_ROWS,
  PREVIEW_DISTRIBUTION_RECORDS,
  PREVIEW_INFEASIBLE_RESULT,
  PREVIEW_POLICY_ITEMS,
  PREVIEW_READINESS_ITEMS,
  PREVIEW_REVISION_CONTEXT,
  PREVIEW_SOLVED_RESULT,
} from "@/features/scheduling/data/schedulingPreviewFixtures";
import {
  applyCorrectionToRecords,
  getEffectiveColumnValue,
  isTeacherPending,
} from "@/features/scheduling/services/courseDistributionService";
import { ALL_GATES_LOCKED_STATE } from "@/features/scheduling/services/schedulingCapabilities";
import type {
  ArtifactFreshnessSummary,
  DistributionColumn,
  DistributionCorrection,
  DistributionSourceRecord,
  LiveCorrectionDraft,
  PolicyConfigItem,
  ReadinessItem,
  RevisionContext,
  SchedulingGateState,
  SolverExecutionResult,
  SolverObjectiveConfig,
  WorkbenchMode,
} from "@/features/scheduling/types";

const DEFAULT_SOLVER_CONFIG: SolverObjectiveConfig = {
  timeLimitSeconds: 60,
  cohortCompactnessWeight: 0.85,
  facultyPreferenceWeight: 0.75,
  theorySpreadWeight: 0.9,
  latePeriodAvoidanceWeight: 0.6,
  enableSessionalBreakCrossing: false,
  engineProfile: "OR-Tools CP-SAT v9.8 · Academic Balance",
};

function recomputePreviewContextAndReadiness(
  records: readonly DistributionSourceRecord[],
  prevContext: RevisionContext,
  prevReadiness: readonly ReadinessItem[],
  nextVersion: number,
): { revision: RevisionContext; readiness: ReadinessItem[] } {
  const totalCorrections = records.reduce(
    (sum, r) => sum + r.corrections.length,
    0,
  );
  const totalConflicts = records.reduce(
    (sum, r) => sum + r.conflicts.length,
    0,
  );
  const row19 = records.find((r) => r.row === 19);
  const row19Pending = row19
    ? isTeacherPending(getEffectiveColumnValue(row19, "I"))
    : true;

  const readiness = prevReadiness.map((item) => {
    if (item.id === "chk-dist-accepted") {
      return {
        ...item,
        description: `Revision #${prevContext.revisionNumber} (v${nextVersion}) verified with ${records.length} CSE & service offerings and ${totalCorrections} audited overlays.`,
      };
    }
    if (item.id === "chk-teacher-pending") {
      return {
        ...item,
        isResolved: !row19Pending,
        title: row19Pending
          ? "Unassigned Lab Instructor on Row 19 (CSE-2202)"
          : "Lab Instructor Assigned on Row 19 (CSE-2202)",
        description: row19Pending
          ? 'Course CSE-2202 Section A has "Pending teacher declaration". Designate a lab instructor in Stage 1 before solving.'
          : `Course CSE-2202 Section A assigned to "${getEffectiveColumnValue(row19!, "I")}".`,
      };
    }
    return item;
  });

  return {
    revision: {
      ...prevContext,
      revisionVersion: nextVersion,
      totalRows: records.length,
      correctionCount: totalCorrections,
      conflictCount: totalConflicts,
    },
    readiness,
  };
}

interface SchedulingWorkbenchState {
  mode: WorkbenchMode;
  selectedRowNumber: number | null;
  liveGates: SchedulingGateState;

  // Live backend state (Gates A/B)
  liveRevisions: RevisionContext[];
  liveSelectedRevisionId: string | null;
  liveRecords: DistributionSourceRecord[];
  liveArtifactFreshness: ArtifactFreshnessSummary;
  liveCorrectionDraft: LiveCorrectionDraft | null;
  liveConcurrencyError: string | null;

  // Isolated Design Preview state (zero DB writes)
  previewRevision: RevisionContext;
  previewRecords: DistributionSourceRecord[];
  previewArtifactFreshness: ArtifactFreshnessSummary;
  previewPolicyItems: PolicyConfigItem[];
  previewReadinessItems: ReadinessItem[];
  previewSolverConfig: SolverObjectiveConfig;
  previewSolverResult: SolverExecutionResult | null;
  previewSolverStepIndex: number; // -1 idle, 0..3 running, 4 done
  previewSimulatedPublishedAt: string | null;

  // Actions
  setMode: (mode: WorkbenchMode) => void;
  setSelectedRowNumber: (row: number | null) => void;
  setLiveGates: (gates: SchedulingGateState) => void;
  setLiveRevisions: (revs: RevisionContext[]) => void;
  setLiveSelectedRevisionId: (id: string | null) => void;
  setLiveLoadedData: (params: {
    revision: RevisionContext;
    records: DistributionSourceRecord[];
    freshness: ArtifactFreshnessSummary;
  }) => void;
  setLiveCorrectionDraft: (draft: LiveCorrectionDraft | null) => void;
  setLiveConcurrencyError: (msg: string | null) => void;

  // Design Preview mutations (memory-only)
  savePreviewCorrection: (params: {
    row: number;
    column: DistributionColumn;
    effectiveValue: string;
    reason: string;
  }) => void;
  applyPreviewPolicyOverride: (params: {
    ruleId: string;
    overrideValue: string;
    effectiveValue: string;
    typedPayload?: Record<string, unknown>;
  }) => void;
  resetPreviewPolicyOverride: (ruleId?: string) => void;
  revalidatePreviewArtifacts: () => void;
  updatePreviewSolverConfig: (patch: Partial<SolverObjectiveConfig>) => void;
  startPreviewSimulation: () => void;
  setPreviewSolverStep: (stepIndex: number) => void;
  completePreviewSimulation: (outcome: "optimal" | "infeasible") => void;
  simulatePreviewPublish: () => void;
  getPreviewCandidateRowCount: () => number;
  resetWorkbench: () => void;
}

export const useSchedulingWorkbenchStore = create<SchedulingWorkbenchState>(
  (set) => ({
    mode: "live",
    selectedRowNumber: null,
    liveGates: ALL_GATES_LOCKED_STATE,

    liveRevisions: [],
    liveSelectedRevisionId: null,
    liveRecords: [],
    liveArtifactFreshness: {
      normalizedInputStatus: "missing",
      validationReportStatus: "missing",
      generationOutputStatus: "missing",
      validatedAgainstVersion: null,
    },
    liveCorrectionDraft: null,
    liveConcurrencyError: null,

    previewRevision: PREVIEW_REVISION_CONTEXT,
    previewRecords: [...PREVIEW_DISTRIBUTION_RECORDS],
    previewArtifactFreshness: { ...PREVIEW_ARTIFACT_FRESHNESS },
    previewPolicyItems: PREVIEW_POLICY_ITEMS.map((item) => ({
      ...item,
      typedPayload: { ...item.typedPayload },
    })),
    previewReadinessItems: [...PREVIEW_READINESS_ITEMS],
    previewSolverConfig: { ...DEFAULT_SOLVER_CONFIG },
    previewSolverResult: PREVIEW_SOLVED_RESULT,
    previewSolverStepIndex: 4,
    previewSimulatedPublishedAt: null,

    setMode: (mode) =>
      set({
        mode,
        selectedRowNumber: null,
      }),

    setSelectedRowNumber: (row) => set({ selectedRowNumber: row }),

    setLiveGates: (liveGates) => set({ liveGates }),

    setLiveRevisions: (liveRevisions) =>
      set((s) => ({
        liveRevisions,
        liveSelectedRevisionId:
          s.liveSelectedRevisionId ?? liveRevisions[0]?.revisionId ?? null,
      })),

    setLiveSelectedRevisionId: (liveSelectedRevisionId) =>
      set({ liveSelectedRevisionId, selectedRowNumber: null }),

    setLiveLoadedData: ({ revision, records, freshness }) =>
      set((state) => {
        const exists = state.liveRevisions.some(
          (r) => r.revisionId === revision.revisionId,
        );
        return {
          liveRevisions: exists
            ? state.liveRevisions.map((r) =>
                r.revisionId === revision.revisionId ? revision : r,
              )
            : [revision, ...state.liveRevisions],
          liveRecords: records,
          liveArtifactFreshness: freshness,
        };
      }),

    setLiveCorrectionDraft: (liveCorrectionDraft) =>
      set({ liveCorrectionDraft }),

    setLiveConcurrencyError: (liveConcurrencyError) =>
      set({ liveConcurrencyError }),

    savePreviewCorrection: ({ row, column, effectiveValue, reason }) =>
      set((state) => {
        const target = state.previewRecords.find((r) => r.row === row);
        if (!target) return state;

        const nextVersion = state.previewRevision.revisionVersion + 1;
        const origVal = getEffectiveColumnValue(target, column);
        const newCorrection: DistributionCorrection = {
          id: `preview-corr-${row}-${column}-${nextVersion}`,
          row,
          column,
          originalValue: origVal,
          originalFormula:
            column === "J"
              ? target.formulaJ
              : column === "L"
                ? target.formulaL
                : null,
          originalCachedValue:
            column === "J"
              ? target.cachedJ
              : column === "L"
                ? target.cachedL
                : null,
          effectiveValue: effectiveValue.trim(),
          reason: reason.trim(),
          author: "Committee Lead (Simulated Preview)",
          timestamp: new Date().toISOString(),
          revisionVersion: nextVersion,
        };

        const nextRecords = applyCorrectionToRecords(
          state.previewRecords,
          newCorrection,
        );
        const { revision, readiness } = recomputePreviewContextAndReadiness(
          nextRecords,
          state.previewRevision,
          state.previewReadinessItems,
          nextVersion,
        );

        return {
          previewRecords: nextRecords,
          previewRevision: { ...revision, isFresh: false },
          previewReadinessItems: readiness,
          previewArtifactFreshness: {
            normalizedInputStatus: "current",
            validationReportStatus: "stale",
            generationOutputStatus: "stale",
            validatedAgainstVersion:
              state.previewArtifactFreshness.validatedAgainstVersion,
          },
          previewSimulatedPublishedAt: null,
        };
      }),

    applyPreviewPolicyOverride: ({
      ruleId,
      overrideValue,
      effectiveValue,
      typedPayload,
    }) =>
      set((state) => {
        const nextItems = state.previewPolicyItems.map((item) =>
          item.ruleId === ruleId
            ? {
                ...item,
                overrideValue,
                effectiveValue,
                typedPayload: typedPayload ?? item.typedPayload,
              }
            : item,
        );
        return {
          previewPolicyItems: nextItems,
          previewRevision: { ...state.previewRevision, isFresh: false },
          previewArtifactFreshness: {
            ...state.previewArtifactFreshness,
            validationReportStatus: "stale",
            generationOutputStatus: "stale",
          },
          previewSimulatedPublishedAt: null,
        };
      }),

    resetPreviewPolicyOverride: (ruleId) =>
      set((state) => {
        const defaultsMap = new Map(
          PREVIEW_POLICY_ITEMS.map((i) => [i.ruleId, i]),
        );
        const nextItems = state.previewPolicyItems.map((item) => {
          if (ruleId && item.ruleId !== ruleId) return item;
          const base = defaultsMap.get(item.ruleId);
          return base
            ? { ...base, typedPayload: { ...base.typedPayload } }
            : item;
        });
        return {
          previewPolicyItems: nextItems,
          previewArtifactFreshness: {
            ...state.previewArtifactFreshness,
            validationReportStatus: "stale",
            generationOutputStatus: "stale",
          },
        };
      }),

    revalidatePreviewArtifacts: () =>
      set((state) => ({
        previewRevision: { ...state.previewRevision, isFresh: true },
        previewArtifactFreshness: {
          ...state.previewArtifactFreshness,
          normalizedInputStatus: "current",
          validationReportStatus: "current",
          validatedAgainstVersion: state.previewRevision.revisionVersion,
        },
      })),

    updatePreviewSolverConfig: (patch) =>
      set((state) => ({
        previewSolverConfig: { ...state.previewSolverConfig, ...patch },
      })),

    startPreviewSimulation: () =>
      set({
        previewSolverStepIndex: 0,
        previewSimulatedPublishedAt: null,
      }),

    setPreviewSolverStep: (previewSolverStepIndex) =>
      set({ previewSolverStepIndex }),

    completePreviewSimulation: (outcome) =>
      set((state) => ({
        previewSolverStepIndex: 4,
        previewSolverResult:
          outcome === "optimal"
            ? PREVIEW_SOLVED_RESULT
            : PREVIEW_INFEASIBLE_RESULT,
        previewRevision: {
          ...state.previewRevision,
          isFresh: outcome === "optimal",
        },
        previewArtifactFreshness: {
          normalizedInputStatus: "current",
          validationReportStatus: "current",
          generationOutputStatus: outcome === "optimal" ? "current" : "stale",
          validatedAgainstVersion: state.previewRevision.revisionVersion,
        },
      })),

    simulatePreviewPublish: () =>
      set({
        previewSimulatedPublishedAt: new Date().toISOString(),
      }),

    getPreviewCandidateRowCount: () => PREVIEW_CANDIDATE_ROWS.length,

    resetWorkbench: () =>
      set({
        mode: "live",
        selectedRowNumber: null,
        liveGates: ALL_GATES_LOCKED_STATE,
        liveRevisions: [],
        liveSelectedRevisionId: null,
        liveRecords: [],
        liveCorrectionDraft: null,
        liveConcurrencyError: null,
        previewRevision: PREVIEW_REVISION_CONTEXT,
        previewRecords: [...PREVIEW_DISTRIBUTION_RECORDS],
        previewArtifactFreshness: { ...PREVIEW_ARTIFACT_FRESHNESS },
        previewPolicyItems: PREVIEW_POLICY_ITEMS.map((item) => ({
          ...item,
          typedPayload: { ...item.typedPayload },
        })),
        previewReadinessItems: [...PREVIEW_READINESS_ITEMS],
        previewSolverConfig: { ...DEFAULT_SOLVER_CONFIG },
        previewSolverResult: PREVIEW_SOLVED_RESULT,
        previewSolverStepIndex: 4,
        previewSimulatedPublishedAt: null,
      }),
  }),
);
