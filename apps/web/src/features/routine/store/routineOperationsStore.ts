import { create } from "zustand";
import type { GenerationProfileV1 } from "@/features/routine/services/generationProfile";
import type { EngineErrorKind } from "@/features/routine/services/timetableEngineService";
import type {
  EngineConfigPayload,
  EngineJobState,
  EngineResultResponse,
  PublishPipelineResult,
  RoutineDataSource,
  RoutineMatrixLens,
  RoutineMatrixViewMode,
} from "@/features/routine/types";

const SESSION_JOB_KEY = "universe-active-solver-job";

function persistSessionJobId(jobId: string | null): void {
  if (typeof window === "undefined") return;
  try {
    if (jobId) {
      window.sessionStorage.setItem(SESSION_JOB_KEY, jobId);
    } else {
      window.sessionStorage.removeItem(SESSION_JOB_KEY);
    }
  } catch {
    // Ignore storage quota errors
  }
}

export function getInitialMatrixViewMode(): RoutineMatrixViewMode {
  if (typeof window !== "undefined" && typeof window.matchMedia === "function") {
    return window.matchMedia("(max-width: 767px)").matches ? "list" : "matrix";
  }
  return "matrix";
}

export type SolverRunPhase = "idle" | "submitting" | "polling" | "done" | "error";

interface RoutineOperationsState {
  // Workbook & optional rehearsal profile
  generateInputMode: "sheet" | "upload";
  selectedWorkbookName: string | null;
  selectedWorkbookSize: number | null;
  selectedWorkbookBytes: Uint8Array | null;
  selectedWorkbookFile: File | null;
  loadedProfile: GenerationProfileV1 | null;
  profileError: string | null;

  // Active solver job & polling state (persisted across tab switches & /admin/timetable/grid)
  jobId: string | null;
  solverPhase: SolverRunPhase;
  activeJobState: EngineJobState | null;
  progress: number;
  startedAtMs: number | null;
  elapsedMs: number;
  isRateLimitedBackoff: boolean;
  errorKind: EngineErrorKind | "validation" | null;
  errorMessage: string | null;

  // Candidate results
  candidateResult: EngineResultResponse | null;
  candidateWorkbookBlob: Blob | null;
  candidateConfigSnapshot: EngineConfigPayload | Record<string, unknown> | null;
  candidateSemesterLabel: string | null;
  runWasPrivatePreview: boolean;
  publishResult: PublishPipelineResult | null;

  // Shared 2D Matrix view preferences
  lens: RoutineMatrixLens;
  viewMode: RoutineMatrixViewMode;
  viewModeManuallyChosen: boolean;
  selectedDay: string | null; // null = auto (Sunday if > 120 rows, else All Days)
  activeSource: RoutineDataSource;
  includeServiceCourses: boolean;

  // Actions
  setGenerateInputMode: (mode: "sheet" | "upload") => void;
  setWorkbook: (file: File, bytes: Uint8Array) => void;
  clearWorkbook: () => void;
  setLoadedProfile: (profile: GenerationProfileV1 | null, error: string | null) => void;
  setProfileError: (error: string | null) => void;
  startSubmitting: () => void;
  setPollingJob: (jobId: string) => void;
  updateJobProgress: (state: EngineJobState, progress: number) => void;
  setRateLimitedBackoff: (active: boolean) => void;
  tickElapsed: () => void;
  completeSolve: (params: {
    result: EngineResultResponse;
    configSnapshot: EngineConfigPayload | Record<string, unknown>;
    semesterLabel: string | null;
    wasPrivatePreview: boolean;
  }) => void;
  failSolve: (kind: EngineErrorKind | "validation", message: string) => void;
  setCandidateWorkbookBlob: (blob: Blob | null) => void;
  setPublishResult: (res: PublishPipelineResult | null) => void;
  resetSolveState: () => void;

  // Matrix actions
  setLens: (lens: RoutineMatrixLens) => void;
  setViewMode: (mode: RoutineMatrixViewMode, manual?: boolean) => void;
  setSelectedDay: (day: string | null) => void;
  setActiveSource: (source: RoutineDataSource) => void;
  setIncludeServiceCourses: (include: boolean) => void;
}

export const useRoutineOperationsStore = create<RoutineOperationsState>((set, get) => ({
  generateInputMode: "upload",
  selectedWorkbookName: null,
  selectedWorkbookSize: null,
  selectedWorkbookBytes: null,
  selectedWorkbookFile: null,
  loadedProfile: null,
  profileError: null,

  jobId: null,
  solverPhase: "idle",
  activeJobState: null,
  progress: 0,
  startedAtMs: null,
  elapsedMs: 0,
  isRateLimitedBackoff: false,
  errorKind: null,
  errorMessage: null,

  candidateResult: null,
  candidateWorkbookBlob: null,
  candidateConfigSnapshot: null,
  candidateSemesterLabel: null,
  runWasPrivatePreview: false,
  publishResult: null,

  lens: "section",
  viewMode: getInitialMatrixViewMode(),
  viewModeManuallyChosen: false,
  selectedDay: null,
  activeSource: "live",
  includeServiceCourses: true,

  setGenerateInputMode: (mode) => set({ generateInputMode: mode }),

  setWorkbook: (file, bytes) =>
    set({
      selectedWorkbookName: file.name,
      selectedWorkbookSize: file.size,
      selectedWorkbookBytes: bytes,
      selectedWorkbookFile: file,
      solverPhase: "idle",
      activeJobState: null,
      progress: 0,
      errorKind: null,
      errorMessage: null,
      candidateResult: null,
      candidateWorkbookBlob: null,
      publishResult: null,
      activeSource: "live",
    }),

  clearWorkbook: () => {
    persistSessionJobId(null);
    set({
      selectedWorkbookName: null,
      selectedWorkbookSize: null,
      selectedWorkbookBytes: null,
      selectedWorkbookFile: null,
      jobId: null,
      solverPhase: "idle",
      activeJobState: null,
      progress: 0,
      startedAtMs: null,
      elapsedMs: 0,
      errorKind: null,
      errorMessage: null,
      candidateResult: null,
      candidateWorkbookBlob: null,
      publishResult: null,
      activeSource: "live",
    });
  },

  setLoadedProfile: (profile, error) =>
    set({
      loadedProfile: profile,
      profileError: error,
      candidateResult: null,
      candidateWorkbookBlob: null,
      publishResult: null,
      solverPhase: "idle",
      errorKind: null,
      errorMessage: null,
    }),

  setProfileError: (error) => set({ profileError: error }),

  startSubmitting: () => {
    persistSessionJobId(null);
    set({
      jobId: null,
      solverPhase: "submitting",
      activeJobState: "queued",
      progress: 0,
      startedAtMs: Date.now(),
      elapsedMs: 0,
      isRateLimitedBackoff: false,
      errorKind: null,
      errorMessage: null,
      candidateResult: null,
      candidateWorkbookBlob: null,
      publishResult: null,
    });
  },

  setPollingJob: (jobId) => {
    persistSessionJobId(jobId);
    set({
      jobId,
      solverPhase: "polling",
      activeJobState: "queued",
    });
  },

  updateJobProgress: (state, progress) =>
    set({
      activeJobState: state,
      progress,
    }),

  setRateLimitedBackoff: (active) => set({ isRateLimitedBackoff: active }),

  tickElapsed: () => {
    const started = get().startedAtMs;
    if (started !== null) {
      set({ elapsedMs: Date.now() - started });
    }
  },

  completeSolve: ({ result, configSnapshot, semesterLabel, wasPrivatePreview }) => {
    persistSessionJobId(null);
    const started = get().startedAtMs;
    set({
      solverPhase: "done",
      activeJobState: "done",
      progress: 1,
      isRateLimitedBackoff: false,
      elapsedMs: started !== null ? Date.now() - started : get().elapsedMs,
      candidateResult: result,
      candidateConfigSnapshot: configSnapshot,
      candidateSemesterLabel: semesterLabel,
      runWasPrivatePreview: wasPrivatePreview,
    });
  },

  failSolve: (kind, message) => {
    persistSessionJobId(null);
    const started = get().startedAtMs;
    set({
      solverPhase: "error",
      errorKind: kind,
      errorMessage: message,
      isRateLimitedBackoff: false,
      elapsedMs: started !== null ? Date.now() - started : get().elapsedMs,
    });
  },

  setCandidateWorkbookBlob: (blob) => set({ candidateWorkbookBlob: blob }),

  setPublishResult: (res) => set({ publishResult: res }),

  resetSolveState: () => {
    persistSessionJobId(null);
    set({
      jobId: null,
      solverPhase: "idle",
      activeJobState: null,
      progress: 0,
      startedAtMs: null,
      elapsedMs: 0,
      isRateLimitedBackoff: false,
      errorKind: null,
      errorMessage: null,
    });
  },

  setLens: (lens) => set({ lens }),
  setViewMode: (viewMode, manual = true) =>
    set({
      viewMode,
      viewModeManuallyChosen: manual ? true : get().viewModeManuallyChosen,
    }),
  setSelectedDay: (selectedDay) => set({ selectedDay }),
  setActiveSource: (activeSource) => set({ activeSource }),
  setIncludeServiceCourses: (includeServiceCourses) =>
    set({ includeServiceCourses }),
}));
