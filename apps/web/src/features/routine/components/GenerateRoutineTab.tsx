import {
  ArrowRight,
  ArrowsClockwise,
  CaretDown,
  CaretRight,
  CheckCircle,
  CircleNotch,
  DownloadSimple,
  FileCode,
  FileXls,
  GridFour,
  LockSimple,
  Play,
  UploadSimple,
  WarningCircle,
  X,
} from "@phosphor-icons/react";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useEffect, useMemo, useRef, useState } from "react";
import { Link } from "react-router-dom";
import { toast } from "sonner";
import { Badge } from "@/components/ui/Badge";
import { Button } from "@/components/ui/Button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogTitle,
} from "@/components/ui/Dialog";
import { useAuth } from "@/features/auth/AuthProvider";
import { fetchBaselineConfigAndBuild } from "@/features/routine/services/buildEngineConfig";
import {
  buildRoutineDraftPayload,
  parseGenerationProfile,
  verifyGenerationProfileSource,
} from "@/features/routine/services/generationProfile";
import { fetchRoutines } from "@/features/routine/services/routineService";
import {
  downloadJobWorkbook,
  EngineJobError,
  publishRoutinePipeline,
  retryRecordTimetableRun,
  runResilientJobPolling,
  submitGenerationJob,
  triggerBrowserDownload,
} from "@/features/routine/services/timetableEngineService";
import {
  assessBaselineConfigForPublish,
  blockingValidationErrorFor,
  extractRowTeacherCodes,
  findCoTeacherBlockers,
  inspectValidationCounters,
} from "@/features/routine/services/validationGate";
import { useRoutineOperationsStore } from "@/features/routine/store/routineOperationsStore";
import type { EngineJobState } from "@/features/routine/types";
import { cn } from "@/lib/utils";

const SOLVER_STAGES: readonly {
  state: EngineJobState;
  step: string;
  label: string;
}[] = [
  { state: "queued", step: "1", label: "Queued" },
  { state: "ingesting", step: "2", label: "Ingesting" },
  { state: "solving", step: "3", label: "CP-SAT Solving" },
  { state: "rendering", step: "4", label: "Rendering" },
];

function middleTruncateFilename(filename: string, maxLen = 36): string {
  if (filename.length <= maxLen) return filename;
  const dotIdx = filename.lastIndexOf(".");
  const ext = dotIdx > 0 ? filename.slice(dotIdx) : "";
  const stem = dotIdx > 0 ? filename.slice(0, dotIdx) : filename;
  const keepTail = Math.min(8, Math.max(4, Math.floor(stem.length * 0.25)));
  const keepHead = Math.max(8, maxLen - ext.length - keepTail - 3);
  return `${stem.slice(0, keepHead)}...${stem.slice(-keepTail)}${ext}`;
}

function formatElapsedMs(ms: number): string {
  const totalSec = Math.max(0, Math.floor(ms / 1000));
  const min = Math.floor(totalSec / 60);
  const sec = totalSec % 60;
  return `${String(min).padStart(2, "0")}:${String(sec).padStart(2, "0")}`;
}

function stageIndexOf(state: EngineJobState | null): number {
  if (!state) return -1;
  if (state === "done") return 4;
  return SOLVER_STAGES.findIndex((s) => s.state === state);
}

export function GenerateRoutineTab({
  onInspectInGrid,
}: {
  onInspectInGrid: () => void;
}) {
  const { isDevPreview, profile } = useAuth();
  const queryClient = useQueryClient();
  const xlsxInputRef = useRef<HTMLInputElement>(null);
  const profileInputRef = useRef<HTMLInputElement>(null);
  const pollAbortRef = useRef<AbortController | null>(null);

  const {
    selectedWorkbookName,
    selectedWorkbookSize,
    selectedWorkbookBytes,
    selectedWorkbookFile,
    loadedProfile,
    profileError,
    jobId,
    solverPhase,
    activeJobState,
    elapsedMs,
    isRateLimitedBackoff,
    errorKind,
    errorMessage,
    candidateResult,
    candidateWorkbookBlob,
    candidateConfigSnapshot,
    candidateSemesterLabel,
    runWasPrivatePreview,
    publishResult,
    setWorkbook,
    clearWorkbook,
    setLoadedProfile,
    setProfileError,
    startSubmitting,
    setPollingJob,
    updateJobProgress,
    setRateLimitedBackoff,
    tickElapsed,
    completeSolve,
    failSolve,
    setCandidateWorkbookBlob,
    setPublishResult,
  } = useRoutineOperationsStore();

  const [rehearsalOpen, setRehearsalOpen] = useState(false);
  const [validationExpanded, setValidationExpanded] = useState(false);
  const [isDraggingXlsx, setIsDraggingXlsx] = useState(false);
  const [isDownloadingXlsx, setIsDownloadingXlsx] = useState(false);
  const [publishModalOpen, setPublishModalOpen] = useState(false);
  const [publishNotes, setPublishNotes] = useState("");
  const [notifyUsers, setNotifyUsers] = useState(false);
  const [publishStep, setPublishStep] = useState<
    "idle" | "uploading" | "publishing" | "recording" | "done" | "error"
  >("idle");
  const [publishError, setPublishError] = useState<string | null>(null);
  const [retryingAudit, setRetryingAudit] = useState(false);

  const baselineQuery = useQuery({
    queryKey: ["admin-engine-baseline-config", isDevPreview],
    queryFn: () => fetchBaselineConfigAndBuild(isDevPreview),
    retry: false,
  });

  const liveRoutinesQuery = useQuery({
    queryKey: ["admin-routines", isDevPreview],
    queryFn: () => fetchRoutines(isDevPreview),
    retry: false,
  });

  const isBusy = solverPhase === "submitting" || solverPhase === "polling";

  useEffect(() => {
    if (!isBusy) return;
    const interval = window.setInterval(() => {
      tickElapsed();
    }, 500);
    return () => window.clearInterval(interval);
  }, [isBusy, tickElapsed]);

  const baselineAssessment = useMemo(
    () => assessBaselineConfigForPublish(baselineQuery.data?.baselineCounts),
    [baselineQuery.data?.baselineCounts],
  );

  const validationError = useMemo(
    () =>
      candidateResult
        ? blockingValidationErrorFor(candidateResult.validation)
        : null,
    [candidateResult],
  );

  const counterInspections = useMemo(
    () =>
      candidateResult
        ? inspectValidationCounters(candidateResult.validation)
        : [],
    [candidateResult],
  );

  const failingCounters = useMemo(
    () => counterInspections.filter((c) => c.count > 0),
    [counterInspections],
  );

  const coTeacherBlockers = useMemo(
    () =>
      candidateResult
        ? findCoTeacherBlockers(
            candidateResult.rows,
            candidateResult.service_rows,
          )
        : [],
    [candidateResult],
  );

  const canPublish = useMemo(() => {
    if (!candidateResult) return false;
    if (candidateResult.rows.length === 0) return false;
    if (runWasPrivatePreview || loadedProfile !== null) return false;
    if (validationError !== null) return false;
    if (coTeacherBlockers.length > 0) return false;
    if (!baselineAssessment.canPublish) return false;
    return true;
  }, [
    baselineAssessment.canPublish,
    candidateResult,
    coTeacherBlockers.length,
    loadedProfile,
    runWasPrivatePreview,
    validationError,
  ]);

  const handleWorkbookFile = async (file: File | undefined) => {
    if (!file) return;
    if (!/\.(xlsx|xls)$/i.test(file.name)) {
      toast.error("Upload a Course Distribution .xlsx workbook.");
      return;
    }
    const bytes = new Uint8Array(await file.arrayBuffer());
    setWorkbook(file, bytes);
    if (loadedProfile) {
      try {
        verifyGenerationProfileSource(loadedProfile, bytes);
        setProfileError(null);
      } catch (err) {
        setProfileError(
          err instanceof Error ? err.message : "Profile source mismatch.",
        );
      }
    }
  };

  const handleProfileFile = async (file: File | undefined) => {
    if (!file) return;
    try {
      const text = await file.text();
      const parsed = parseGenerationProfile(text);
      if (selectedWorkbookBytes) {
        verifyGenerationProfileSource(parsed, selectedWorkbookBytes);
      }
      setLoadedProfile(parsed, null);
      toast.message("Rehearsal profile loaded (private preview only)");
    } catch (err) {
      const msg =
        err instanceof Error ? err.message : "Invalid rehearsal profile JSON.";
      setLoadedProfile(null, msg);
      toast.error("Could not load rehearsal profile", { description: msg });
    }
  };

  const handleRunSolver = async () => {
    if (!selectedWorkbookFile || !selectedWorkbookBytes) {
      toast.error("Select a Course Distribution .xlsx file first.");
      return;
    }
    if (profileError) {
      toast.error(profileError);
      return;
    }

    pollAbortRef.current?.abort();
    const abortCtrl = new AbortController();
    pollAbortRef.current = abortCtrl;

    startSubmitting();

    try {
      let configObj: Record<string, unknown>;
      let semesterLabel: string | null = null;
      if (loadedProfile) {
        verifyGenerationProfileSource(loadedProfile, selectedWorkbookBytes);
        configObj = loadedProfile.config as unknown as Record<string, unknown>;
        const rawSettings = configObj.settings as
          | Record<string, unknown>
          | undefined;
        semesterLabel =
          typeof rawSettings?.semester_label === "string"
            ? rawSettings.semester_label
            : loadedProfile.label;
      } else {
        const assembled =
          baselineQuery.data ?? (await fetchBaselineConfigAndBuild(isDevPreview));
        configObj = assembled.config as unknown as Record<string, unknown>;
        semesterLabel = assembled.config.settings.semester_label;
      }

      const configJson = JSON.stringify(configObj);
      const { job_id } = await submitGenerationJob({
        file: selectedWorkbookFile,
        configJson,
        signal: abortCtrl.signal,
      });

      setPollingJob(job_id);

      const result = await runResilientJobPolling({
        jobId: job_id,
        signal: abortCtrl.signal,
        onBackoff: (active) => setRateLimitedBackoff(active),
        onStatus: (st) => updateJobProgress(st.state, st.progress),
      });

      completeSolve({
        result,
        configSnapshot: configObj,
        semesterLabel,
        wasPrivatePreview: loadedProfile !== null,
      });

      toast.success("CP-SAT routine generation completed");
    } catch (err) {
      const kind =
        err instanceof EngineJobError ? err.kind : ("network" as const);
      const msg =
        err instanceof Error
          ? err.message
          : "Timetable generation failed unexpectedly.";
      failSolve(kind, msg);
      toast.error("Solver run stopped", { description: msg });
    }
  };

  const handleDownloadWorkbook = async () => {
    if (!jobId) return;
    setIsDownloadingXlsx(true);
    try {
      const blob =
        candidateWorkbookBlob ?? (await downloadJobWorkbook(jobId));
      setCandidateWorkbookBlob(blob);
      const safe = (candidateSemesterLabel ?? "timetable")
        .trim()
        .replace(/\s+/g, "_");
      triggerBrowserDownload(blob, `CSE_Routine_${safe || "timetable"}.xlsx`);
      toast.success("Downloaded rendered .xlsx workbook");
    } catch (err) {
      toast.error("Workbook download failed", {
        description: err instanceof Error ? err.message : "Download failed.",
      });
    } finally {
      setIsDownloadingXlsx(false);
    }
  };

  const handleExportPrivateDraft = () => {
    if (!candidateResult) return;
    const payload = buildRoutineDraftPayload({
      rows: candidateResult.rows,
      serviceRows: candidateResult.service_rows,
      profile: loadedProfile,
      sourceContract: candidateResult.report.source_contract ?? candidateResult.source_contract,
      config: candidateConfigSnapshot,
      validation: candidateResult.validation,
    });
    triggerBrowserDownload(
      JSON.stringify(payload, null, 2),
      `routine_draft_${Date.now()}.json`,
    );
    toast.success("Exported private JSON routine draft");
  };

  const handleConfirmPublish = async () => {
    if (!candidateResult) return;
    setPublishError(null);
    setPublishStep("uploading");
    try {
      const outcome = await publishRoutinePipeline({
        jobId,
        result: candidateResult,
        workbookBlob: candidateWorkbookBlob,
        semesterLabel: candidateSemesterLabel,
        notes: publishNotes,
        notifyUsers,
        baselineCounts: baselineQuery.data?.baselineCounts ?? null,
        isPrivatePreview: runWasPrivatePreview || loadedProfile !== null,
        createdBy: profile?.id ?? null,
        isDevPreview,
        onStepChange: (step) => setPublishStep(step),
      });
      setPublishResult(outcome);
      setPublishStep("done");
      void queryClient.invalidateQueries({ queryKey: ["admin-routines"] });
      void queryClient.invalidateQueries({
        queryKey: ["admin-routine-active-version"],
      });
      void queryClient.invalidateQueries({
        queryKey: ["admin-dashboard-counts"],
      });
      if (outcome.secondaryAuditError) {
        toast.warning("Routine published with audit log warning", {
          description: outcome.secondaryAuditError,
        });
      } else {
        toast.success(`Published ${outcome.rowCount} slots to active routine`);
      }
      setPublishModalOpen(false);
    } catch (err) {
      setPublishStep("error");
      const msg =
        err instanceof Error ? err.message : "Routine publication failed.";
      setPublishError(msg);
      toast.error("Publication blocked or failed", { description: msg });
    }
  };

  const handleRetryAuditLog = async () => {
    if (!publishResult?.retryAuditParams) return;
    setRetryingAudit(true);
    try {
      await retryRecordTimetableRun(
        publishResult.retryAuditParams,
        isDevPreview,
      );
      setPublishResult({
        ...publishResult,
        secondaryAuditError: null,
        retryAuditParams: null,
      });
      toast.success("Audit log recorded in timetable_runs");
    } catch (err) {
      toast.error("Retry audit log failed", {
        description: err instanceof Error ? err.message : "Insert error.",
      });
    } finally {
      setRetryingAudit(false);
    }
  };

  const counts = baselineQuery.data?.baselineCounts;
  const activeStageIdx = stageIndexOf(activeJobState);

  return (
    <div className="space-y-4">
      {/* Section 1: Baseline Readiness Preflight Strip */}
      <section
        aria-label="Baseline configuration readiness"
        className="ledger-card space-y-3 p-4"
      >
        <div className="flex flex-wrap items-center justify-between gap-2">
          <div>
            <h2 className="text-[15px] font-semibold text-[var(--ink-primary)]">
              Baseline Solver Configuration Preflight
            </h2>
            <p className="text-[12.5px] text-[var(--ink-secondary)]">
              Live database configuration assembled into the solver payload
              before submission.
            </p>
          </div>
          <Button
            variant="secondary"
            size="sm"
            disabled={baselineQuery.isFetching}
            onClick={() => void baselineQuery.refetch()}
          >
            <ArrowsClockwise
              size={14}
              className={baselineQuery.isFetching ? "animate-spin" : undefined}
              aria-hidden="true"
            />
            <span>Refresh Baseline</span>
          </Button>
        </div>

        <div className="grid grid-cols-2 gap-2.5 sm:grid-cols-4">
          <Link
            to="/admin/timetable/rooms"
            className="flex flex-col gap-1 rounded-[var(--r-control)] border border-[var(--border-subtle)] bg-[var(--bg-surface)] px-3 py-2.5 no-underline hover:bg-[var(--surface-hover)]"
          >
            <span className="text-[11.5px] text-[var(--ink-secondary)]">
              Active Rooms
            </span>
            <span className="font-mono-tabular text-[16px] font-semibold text-[var(--ink-primary)]">
              {counts?.activeRooms ?? 0}
            </span>
          </Link>

          <Link
            to="/admin/timetable/faculty"
            className="flex flex-col gap-1 rounded-[var(--r-control)] border border-[var(--border-subtle)] bg-[var(--bg-surface)] px-3 py-2.5 no-underline hover:bg-[var(--surface-hover)]"
          >
            <span className="text-[11.5px] text-[var(--ink-secondary)]">
              Active Faculty
            </span>
            <span className="font-mono-tabular text-[16px] font-semibold text-[var(--ink-primary)]">
              {counts?.activeFaculty ?? 0}
            </span>
          </Link>

          <Link
            to="/admin/timetable/course-eligibility"
            className="flex flex-col gap-1 rounded-[var(--r-control)] border border-[var(--border-subtle)] bg-[var(--bg-surface)] px-3 py-2.5 no-underline hover:bg-[var(--surface-hover)]"
          >
            <span className="text-[11.5px] text-[var(--ink-secondary)]">
              Eligibility Rules
            </span>
            <span className="font-mono-tabular text-[16px] font-semibold text-[var(--ink-primary)]">
              {counts?.eligibility ?? 0}
            </span>
          </Link>

          <Link
            to="/admin/timetable/settings"
            className="flex flex-col gap-1 rounded-[var(--r-control)] border border-[var(--border-subtle)] bg-[var(--bg-surface)] px-3 py-2.5 no-underline hover:bg-[var(--surface-hover)]"
          >
            <span className="text-[11.5px] text-[var(--ink-secondary)]">
              Settings Row (id=1)
            </span>
            <span className="font-mono-tabular text-[14px] font-semibold text-[var(--ink-primary)]">
              {counts?.hasSettings ? "Configured" : "Missing"}
            </span>
          </Link>
        </div>

        {/* Empty-Config Pre-Publish Guard (F-20) */}
        {!baselineAssessment.canPublish && (
          <div
            role="alert"
            data-testid="empty-config-publish-guard"
            className="flex items-start gap-2.5 rounded-[var(--r-control)] border border-[var(--sem-conflict-border)] bg-[var(--sem-conflict-bg)] p-3 text-[12.5px] text-[var(--sem-conflict-ink)]"
          >
            <WarningCircle size={17} className="mt-0.5 shrink-0" aria-hidden="true" />
            <div>
              <div className="font-semibold">
                Publication blocked until baseline configuration is populated
              </div>
              <ul className="mt-1 list-disc pl-4">
                {baselineAssessment.blockingReasons.map((reason) => (
                  <li key={reason}>{reason}</li>
                ))}
              </ul>
            </div>
          </div>
        )}

        {baselineAssessment.warnings.map((w) => (
          <div
            key={w}
            className="flex items-start gap-2 rounded-[var(--r-control)] border border-[var(--sem-joint-border)] bg-[var(--sem-joint-bg)] px-3 py-2 text-[12px] text-[var(--sem-joint-ink)]"
          >
            <WarningCircle size={15} className="mt-0.5 shrink-0" aria-hidden="true" />
            <span>{w}</span>
          </div>
        ))}
      </section>

      {/* Section 2: Workbook Input & Optional Rehearsal Profile */}
      <section
        aria-label="Course distribution workbook and rehearsal profile"
        className="ledger-card space-y-4 p-5"
      >
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div>
            <h2 className="text-[16px] font-semibold text-[var(--ink-primary)]">
              Course Distribution Input
            </h2>
            <p className="mt-0.5 text-[12.5px] text-[var(--ink-secondary)]">
              Upload a Leading University{" "}
              <code className="font-mono-tabular">.xlsx</code> Course
              Distribution workbook to run the CP-SAT solver (180s budget).
            </p>
          </div>
          {loadedProfile && (
            <Badge tone="joint" mono>
              <LockSimple size={12} aria-hidden="true" />
              <span>PRIVATE PREVIEW ONLY · PUBLICATION BLOCKED</span>
            </Badge>
          )}
        </div>

        {/* Accessible Drag & Drop / File Picker */}
        <div
          onDragOver={(e) => {
            e.preventDefault();
            setIsDraggingXlsx(true);
          }}
          onDragLeave={() => setIsDraggingXlsx(false)}
          onDrop={(e) => {
            e.preventDefault();
            setIsDraggingXlsx(false);
            void handleWorkbookFile(e.dataTransfer.files?.[0]);
          }}
          className={cn(
            "flex flex-wrap items-center justify-between gap-3 rounded-[var(--r-control)] border border-dashed px-4 py-4 transition-colors",
            isDraggingXlsx
              ? "border-[var(--accent-pine)] bg-[var(--accent-pine-soft)]/60"
              : "border-[var(--border-control)] bg-[var(--bg-surface)]",
          )}
        >
          <input
            ref={xlsxInputRef}
            type="file"
            accept=".xlsx,.xls"
            aria-label="Select Course Distribution .xlsx file"
            data-testid="workbook-file-input"
            className="sr-only"
            onChange={(e) => void handleWorkbookFile(e.target.files?.[0])}
          />

          <div className="flex min-w-0 items-center gap-3">
            <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-[var(--r-control)] border border-[var(--border-subtle)] bg-[var(--bg-elevated)] text-[var(--accent-pine)]">
              <FileXls size={20} aria-hidden="true" />
            </div>
            <div className="min-w-0">
              {selectedWorkbookName ? (
                <>
                  <div
                    title={selectedWorkbookName}
                    className="font-mono-tabular text-[13.5px] font-semibold text-[var(--ink-primary)]"
                  >
                    {middleTruncateFilename(selectedWorkbookName)}
                  </div>
                  <div className="font-mono-tabular text-[11.5px] text-[var(--ink-muted)]">
                    {((selectedWorkbookSize ?? 0) / 1024).toFixed(1)} KB · Ready
                    for CP-SAT ingestion
                  </div>
                </>
              ) : (
                <>
                  <div className="text-[13.5px] font-medium text-[var(--ink-primary)]">
                    Drop a Course Distribution{" "}
                    <code className="font-mono-tabular">.xlsx</code> file here
                  </div>
                  <div className="text-[12px] text-[var(--ink-muted)]">
                    Must contain the{" "}
                    <code className="font-mono-tabular">
                      Course Distribution
                    </code>{" "}
                    worksheet.
                  </div>
                </>
              )}
            </div>
          </div>

          <div className="flex flex-wrap items-center gap-2">
            <Button
              type="button"
              variant="secondary"
              size="sm"
              disabled={isBusy}
              onClick={() => xlsxInputRef.current?.click()}
            >
              <UploadSimple size={14} aria-hidden="true" />
              <span>
                {selectedWorkbookName ? "Change Workbook" : "Browse .xlsx"}
              </span>
            </Button>
            {selectedWorkbookName && !isBusy && (
              <Button
                type="button"
                variant="ghost"
                size="sm"
                onClick={clearWorkbook}
                aria-label="Clear selected workbook"
              >
                <X size={14} aria-hidden="true" />
              </Button>
            )}
          </div>
        </div>

        {/* Collapsible Rehearsal Profile (Private Preview Only) */}
        <div className="rounded-[var(--r-control)] border border-[var(--border-subtle)] bg-[var(--bg-surface)]">
          <button
            type="button"
            aria-expanded={rehearsalOpen}
            onClick={() => setRehearsalOpen((v) => !v)}
            className="flex w-full items-center justify-between gap-2 px-3.5 py-2.5 text-left text-[12.5px] font-medium text-[var(--ink-primary)] hover:bg-[var(--surface-hover)]"
          >
            <span className="flex items-center gap-2">
              {rehearsalOpen ? (
                <CaretDown size={14} aria-hidden="true" />
              ) : (
                <CaretRight size={14} aria-hidden="true" />
              )}
              <span>Rehearsal Profile (Private Preview Only)</span>
              {loadedProfile && (
                <Badge tone="joint" mono>
                  {loadedProfile.label}
                </Badge>
              )}
            </span>
            <span className="text-[11.5px] text-[var(--ink-muted)]">
              Optional CRC32-verified JSON override
            </span>
          </button>

          {rehearsalOpen && (
            <div className="space-y-3 border-t border-[var(--border-subtle)] px-3.5 py-3 text-[12.5px]">
              <p className="text-[var(--ink-secondary)]">
                Attach a{" "}
                <code className="font-mono-tabular">
                  universe-generation-profile-v1
                </code>{" "}
                JSON file to test historical parameters. Verified via CRC32 and
                byte-length against the selected workbook; publication is
                strictly blocked while a rehearsal profile is active.
              </p>
              <input
                ref={profileInputRef}
                type="file"
                accept=".json,application/json"
                aria-label="Select Rehearsal Profile JSON file"
                data-testid="rehearsal-profile-input"
                className="sr-only"
                onChange={(e) => void handleProfileFile(e.target.files?.[0])}
              />
              <div className="flex flex-wrap items-center gap-2">
                <Button
                  type="button"
                  variant="secondary"
                  size="sm"
                  disabled={isBusy}
                  onClick={() => profileInputRef.current?.click()}
                >
                  <FileCode size={14} aria-hidden="true" />
                  <span>Load Profile JSON</span>
                </Button>
                {loadedProfile && (
                  <Button
                    type="button"
                    variant="ghost"
                    size="sm"
                    onClick={() => setLoadedProfile(null, null)}
                  >
                    Clear Profile
                  </Button>
                )}
              </div>
              {profileError && (
                <div
                  role="alert"
                  data-testid="rehearsal-profile-error"
                  className="rounded-[var(--r-control)] border border-[var(--sem-conflict-border)] bg-[var(--sem-conflict-bg)] px-3 py-2 text-[12px] text-[var(--sem-conflict-ink)]"
                >
                  {profileError}
                </div>
              )}
            </div>
          )}
        </div>

        <div className="flex flex-wrap items-center justify-between gap-3 pt-1">
          <div className="font-mono-tabular text-[12px] text-[var(--ink-muted)]">
            {loadedProfile
              ? `Using rehearsal profile "${loadedProfile.label}" (${loadedProfile.provenance})`
              : "Using live Supabase baseline rooms, faculty, eligibility & settings"}
          </div>
          <Button
            type="button"
            variant="primary"
            size="md"
            disabled={!selectedWorkbookFile || isBusy || Boolean(profileError)}
            onClick={() => void handleRunSolver()}
          >
            {isBusy ? (
              <CircleNotch
                size={16}
                className="animate-spin"
                aria-hidden="true"
              />
            ) : (
              <Play size={16} aria-hidden="true" />
            )}
            <span>{isBusy ? "Solver Running..." : "Run CP-SAT Solver"}</span>
          </Button>
        </div>
      </section>

      {/* Section 3: 4-Node Visual Solver Timeline & Service Recovery Card */}
      {solverPhase !== "idle" && (
        <section
          aria-label="CP-SAT solver execution timeline"
          data-testid="solver-timeline-panel"
          className="ledger-card space-y-4 p-5"
        >
          <div className="flex flex-wrap items-center justify-between gap-3">
            <div className="flex items-center gap-2.5">
              <h3 className="text-[15px] font-semibold text-[var(--ink-primary)]">
                Solver Execution Status
              </h3>
              {jobId && (
                <Badge tone="neutral" mono>
                  Job {jobId}
                </Badge>
              )}
              {isRateLimitedBackoff && (
                <Badge tone="joint" mono>
                  429 backoff (+4s)
                </Badge>
              )}
            </div>
            <div className="font-mono-tabular text-[13px] font-semibold text-[var(--ink-primary)]">
              Elapsed {formatElapsedMs(elapsedMs)}
            </div>
          </div>

          {/* Honest 4-Node Progression (Zero fabricated percentage bars) */}
          <ol className="grid grid-cols-2 gap-2.5 sm:grid-cols-4">
            {SOLVER_STAGES.map((stage, idx) => {
              const isCompleted =
                solverPhase === "done" ||
                (activeStageIdx > idx && solverPhase === "polling");
              const isCurrent =
                (solverPhase === "submitting" && idx === 0) ||
                (solverPhase === "polling" && activeStageIdx === idx);
              return (
                <li
                  key={stage.state}
                  data-state={
                    isCompleted
                      ? "completed"
                      : isCurrent
                        ? "active"
                        : "pending"
                  }
                  className={cn(
                    "flex items-center gap-2.5 rounded-[var(--r-control)] border px-3 py-2.5 text-[12.5px]",
                    isCompleted
                      ? "border-[var(--sem-lab-border)] bg-[var(--sem-lab-bg)] text-[var(--sem-lab-ink)]"
                      : isCurrent
                        ? "border-[var(--accent-pine)] bg-[var(--accent-pine-soft)] font-semibold text-[var(--accent-pine)]"
                        : "border-[var(--border-subtle)] bg-[var(--bg-surface)] text-[var(--ink-muted)]",
                  )}
                >
                  {isCompleted ? (
                    <CheckCircle
                      size={16}
                      weight="fill"
                      className="shrink-0"
                      aria-hidden="true"
                    />
                  ) : isCurrent ? (
                    <CircleNotch
                      size={16}
                      className="shrink-0 animate-spin"
                      aria-hidden="true"
                    />
                  ) : (
                    <span className="font-mono-tabular flex h-4 w-4 shrink-0 items-center justify-center rounded-full border border-current text-[10px]">
                      {stage.step}
                    </span>
                  )}
                  <span>{stage.label}</span>
                </li>
              );
            })}
          </ol>

          {/* Service Recovery Card on Error / Render 404 Restart */}
          {solverPhase === "error" && (
            <div
              role="alert"
              data-testid="solver-service-recovery-card"
              className="flex flex-wrap items-center justify-between gap-3 rounded-[var(--r-control)] border border-[var(--sem-conflict-border)] bg-[var(--sem-conflict-bg)] p-4 text-[13px] text-[var(--sem-conflict-ink)]"
            >
              <div className="space-y-1">
                <div className="flex items-center gap-2 font-semibold">
                  <WarningCircle size={17} aria-hidden="true" />
                  <span>
                    {errorKind === "engine-restart"
                      ? "Engine restarted mid-solve — re-submit workbook"
                      : "Timetable generation interrupted"}
                  </span>
                </div>
                <p className="text-[12.5px] leading-[1.45]">{errorMessage}</p>
              </div>
              <Button
                type="button"
                variant="secondary"
                size="sm"
                disabled={!selectedWorkbookFile}
                onClick={() => void handleRunSolver()}
              >
                <ArrowsClockwise size={14} aria-hidden="true" />
                <span>Retry Generation</span>
              </Button>
            </div>
          )}
        </section>
      )}

      {/* Section 4: Candidate Results, 20-Counter Validation Ledger & Guarded Publish Bar */}
      {candidateResult && (
        <section
          aria-label="Candidate timetable results and validation"
          data-testid="candidate-results-panel"
          className="ledger-card space-y-4 p-5"
        >
          <div className="flex flex-wrap items-center justify-between gap-3 border-b border-[var(--border-subtle)] pb-3">
            <div>
              <h3 className="text-[16px] font-semibold text-[var(--ink-primary)]">
                Candidate Schedule &amp; Validation Ledger
              </h3>
              <p className="mt-0.5 text-[12.5px] text-[var(--ink-secondary)]">
                Review solver metrics, 20-counter distribution validation, and
                storage guards before publishing.
              </p>
            </div>
            <Badge
              tone={validationError ? "conflict" : "lab"}
              mono
              data-testid="validation-verdict-badge"
            >
              {validationError ? "Blocked · Validation Failed" : "Passed (20/20)"}
            </Badge>
          </div>

          {/* Summary Stats */}
          <div className="grid grid-cols-2 gap-2.5 sm:grid-cols-4 lg:grid-cols-7">
            {[
              { label: "OR-Tools", value: candidateResult.stats.status },
              {
                label: "Solve Time",
                value: `${candidateResult.stats.solve_ms} ms`,
              },
              {
                label: "CSE Meetings",
                value: String(candidateResult.stats.meetings),
              },
              {
                label: "Service",
                value: String(candidateResult.stats.service_meetings),
              },
              {
                label: "Cohorts",
                value: String(candidateResult.stats.cohorts),
              },
              {
                label: "Teachers",
                value: String(candidateResult.stats.teachers),
              },
              {
                label: "Lab Adjacent",
                value: `${candidateResult.stats.lab_theory_adjacent}/${candidateResult.stats.lab_theory_pairs}`,
              },
            ].map((stat) => (
              <div
                key={stat.label}
                className="rounded-[var(--r-control)] border border-[var(--border-subtle)] bg-[var(--bg-surface)] px-3 py-2"
              >
                <div className="text-[11px] text-[var(--ink-muted)]">
                  {stat.label}
                </div>
                <div className="font-mono-tabular mt-0.5 text-[14px] font-semibold text-[var(--ink-primary)]">
                  {stat.value}
                </div>
              </div>
            ))}
          </div>

          {/* Co-Teacher Storage Guard Banner (F-22) */}
          {coTeacherBlockers.length > 0 && (
            <div
              role="alert"
              data-testid="coteacher-storage-guard-banner"
              className="flex items-start gap-2.5 rounded-[var(--r-control)] border border-[var(--sem-conflict-border)] bg-[var(--sem-conflict-bg)] p-3.5 text-[12.5px] text-[var(--sem-conflict-ink)]"
            >
              <WarningCircle
                size={17}
                className="mt-0.5 shrink-0"
                aria-hidden="true"
              />
              <div>
                <div className="font-semibold">
                  Shared faculty guard: {coTeacherBlockers.length} slot(s)
                  cannot publish to scalar storage
                </div>
                <p className="mt-0.5 leading-[1.45]">
                  Live database routines store only one scalar teacher acronym
                  per slot. Export this candidate as a private JSON draft or
                  download the rendered{" "}
                  <code className="font-mono-tabular">.xlsx</code> instead.
                  Affected:{" "}
                  {coTeacherBlockers
                    .slice(0, 3)
                    .map(
                      (r) =>
                        `${r.subject_code} (${extractRowTeacherCodes(r).join(" / ")})`,
                    )
                    .join(", ")}
                  .
                </p>
              </div>
            </div>
          )}

          {/* Validation Diagnostic Banner + Expandable 20-Counter Ledger */}
          {validationError && (
            <div
              role="alert"
              data-testid="validation-blocker-banner"
              className="rounded-[var(--r-control)] border border-[var(--sem-conflict-border)] bg-[var(--sem-conflict-bg)] p-3.5 text-[12.5px] text-[var(--sem-conflict-ink)]"
            >
              <div className="font-semibold">Publication blocked</div>
              <p className="mt-0.5 leading-[1.45]">{validationError}</p>
            </div>
          )}

          <div className="rounded-[var(--r-control)] border border-[var(--border-subtle)] bg-[var(--bg-surface)]">
            <button
              type="button"
              aria-expanded={validationExpanded}
              onClick={() => setValidationExpanded((v) => !v)}
              className="flex w-full items-center justify-between gap-2 px-3.5 py-2.5 text-left text-[12.5px] font-medium text-[var(--ink-primary)] hover:bg-[var(--surface-hover)]"
            >
              <span className="flex items-center gap-2">
                {validationExpanded ? (
                  <CaretDown size={14} aria-hidden="true" />
                ) : (
                  <CaretRight size={14} aria-hidden="true" />
                )}
                <span>20-Counter Validation Diagnostic Ledger</span>
              </span>
              <span className="font-mono-tabular text-[11.5px] text-[var(--ink-muted)]">
                {failingCounters.length} failing / 20 checks
              </span>
            </button>

            {validationExpanded && (
              <div className="divide-y divide-[var(--border-subtle)] border-t border-[var(--border-subtle)]">
                {counterInspections.map((item) => (
                  <div key={item.key} className="px-3.5 py-2 text-[12px]">
                    <div className="flex items-center justify-between gap-2">
                      <span className="font-medium text-[var(--ink-primary)]">
                        {item.label}{" "}
                        <code className="font-mono-tabular text-[11px] text-[var(--ink-muted)]">
                          ({item.key})
                        </code>
                      </span>
                      <Badge
                        tone={item.count > 0 ? "conflict" : "lab"}
                        mono
                      >
                        {item.count}
                      </Badge>
                    </div>
                    {item.count > 0 && item.details.length > 0 && (
                      <div className="font-mono-tabular mt-1.5 space-y-1 rounded bg-[var(--bg-elevated)] p-2 text-[11px] text-[var(--ink-secondary)]">
                        {item.details.slice(0, 5).map((detail, idx) => (
                          <div key={idx}>{JSON.stringify(detail)}</div>
                        ))}
                      </div>
                    )}
                  </div>
                ))}
              </div>
            )}
          </div>

          {/* Publish Outcome + Service Recovery Retry Audit Log */}
          {publishResult?.published && (
            <div
              role="status"
              data-testid="publish-outcome-banner"
              className={cn(
                "flex flex-wrap items-center justify-between gap-3 rounded-[var(--r-control)] border p-3.5 text-[12.5px]",
                publishResult.secondaryAuditError
                  ? "border-[var(--sem-joint-border)] bg-[var(--sem-joint-bg)] text-[var(--sem-joint-ink)]"
                  : "border-[var(--sem-lab-border)] bg-[var(--sem-lab-bg)] text-[var(--sem-lab-ink)]",
              )}
            >
              <div>
                <div className="font-semibold">
                  Routine is live ({publishResult.rowCount} slots published)
                </div>
                {publishResult.secondaryAuditError && (
                  <p className="mt-0.5">
                    Audit log write failed: {publishResult.secondaryAuditError}
                  </p>
                )}
              </div>
              {publishResult.retryAuditParams && (
                <Button
                  type="button"
                  variant="secondary"
                  size="sm"
                  disabled={retryingAudit}
                  onClick={() => void handleRetryAuditLog()}
                >
                  <ArrowsClockwise
                    size={14}
                    className={retryingAudit ? "animate-spin" : undefined}
                    aria-hidden="true"
                  />
                  <span>Retry Audit Log</span>
                </Button>
              )}
            </div>
          )}

          {/* Candidate Action Bar */}
          <div className="flex flex-wrap items-center justify-between gap-2.5 border-t border-[var(--border-subtle)] pt-3">
            <div className="flex flex-wrap items-center gap-2">
              <Button
                type="button"
                variant="secondary"
                size="sm"
                onClick={onInspectInGrid}
              >
                <GridFour size={15} aria-hidden="true" />
                <span>Inspect in 2D Grid</span>
              </Button>
              <Button
                type="button"
                variant="secondary"
                size="sm"
                disabled={!candidateResult.has_workbook || isDownloadingXlsx}
                onClick={() => void handleDownloadWorkbook()}
              >
                <DownloadSimple size={15} aria-hidden="true" />
                <span>
                  {isDownloadingXlsx ? "Downloading..." : "Download .xlsx"}
                </span>
              </Button>
              <Button
                type="button"
                variant="secondary"
                size="sm"
                onClick={handleExportPrivateDraft}
              >
                <FileCode size={15} aria-hidden="true" />
                <span>Export Private JSON Draft</span>
              </Button>
            </div>

            <Button
              type="button"
              variant="primary"
              size="md"
              disabled={!canPublish}
              onClick={() => {
                setPublishError(null);
                setPublishStep("idle");
                setPublishModalOpen(true);
              }}
            >
              <span>Publish to Active Routine</span>
              <ArrowRight size={15} aria-hidden="true" />
            </Button>
          </div>
        </section>
      )}

      {/* Blocking 3-Step Guarded Publication Confirmation Modal (F-21) */}
      <Dialog
        open={publishModalOpen}
        onOpenChange={(open) => {
          if (
            publishStep === "uploading" ||
            publishStep === "publishing" ||
            publishStep === "recording"
          ) {
            return;
          }
          setPublishModalOpen(open);
        }}
      >
        <DialogContent className="fixed left-1/2 top-1/2 w-[calc(100%-32px)] max-w-[520px] -translate-x-1/2 -translate-y-1/2 p-5">
          <div className="flex items-start justify-between gap-3">
            <div>
              <DialogTitle className="text-[17px] font-semibold text-[var(--ink-primary)]">
                Confirm Atomic Routine Publication
              </DialogTitle>
              <DialogDescription className="mt-1 text-[13px] text-[var(--ink-secondary)]">
                3-step pipeline: upload rendered workbook, replace active
                routine transactionally, and record run history.
              </DialogDescription>
            </div>
            <button
              type="button"
              aria-label="Close publish confirmation"
              onClick={() => setPublishModalOpen(false)}
              className="flex h-7 w-7 items-center justify-center rounded-[5px] text-[var(--ink-secondary)] hover:bg-[var(--surface-hover)]"
            >
              <X size={15} aria-hidden="true" />
            </button>
          </div>

          <div className="mt-4 space-y-3.5 text-[13px]">
            {/* Explicit F-21 Wipe Disclosure */}
            <div
              role="alert"
              className="rounded-[var(--r-control)] border border-[var(--sem-conflict-border)] bg-[var(--sem-conflict-bg)] p-3 text-[12.5px] text-[var(--sem-conflict-ink)]"
            >
              <strong>Permanent Table Replacement (F-21):</strong>{" "}
              <code className="font-mono-tabular">publish_routine()</code>{" "}
              atomically wipes all prior{" "}
              <code className="font-mono-tabular">public.routines</code> rows
              and activates this schedule for students and faculty.
            </div>

            <div className="grid grid-cols-2 gap-3 rounded-[var(--r-control)] border border-[var(--border-subtle)] bg-[var(--bg-surface)] p-3">
              <div>
                <div className="text-[11.5px] text-[var(--ink-muted)]">
                  Current Active Slots
                </div>
                <div className="font-mono-tabular text-[16px] font-semibold text-[var(--ink-primary)]">
                  {(liveRoutinesQuery.data ?? []).length}
                </div>
              </div>
              <div>
                <div className="text-[11.5px] text-[var(--ink-muted)]">
                  Incoming Slots (CSE + Service)
                </div>
                <div className="font-mono-tabular text-[16px] font-semibold text-[var(--accent-pine)]">
                  {(candidateResult?.rows.length ?? 0) +
                    (candidateResult?.service_rows.length ?? 0)}
                </div>
              </div>
            </div>

            <div>
              <label
                htmlFor="publish-notes"
                className="mb-1 block text-[12px] font-medium text-[var(--ink-primary)]"
              >
                Publication Notes (optional)
              </label>
              <input
                id="publish-notes"
                type="text"
                value={publishNotes}
                onChange={(e) => setPublishNotes(e.target.value)}
                placeholder="e.g. Approved by Routine Committee v1"
                className="h-9 w-full rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-3 text-[13px] text-[var(--ink-primary)] focus:border-[var(--ink-primary)] focus:outline-none"
              />
            </div>

            <label className="flex cursor-pointer items-center gap-2 text-[12.5px] text-[var(--ink-primary)]">
              <input
                type="checkbox"
                checked={notifyUsers}
                onChange={(e) => setNotifyUsers(e.target.checked)}
                className="h-4 w-4 accent-[var(--accent-pine)]"
              />
              <span>Notify students &amp; teachers via campus broadcast</span>
            </label>

            {/* Live 3-Step Indicators */}
            {publishStep !== "idle" && (
              <ol className="space-y-1.5 rounded-[var(--r-control)] border border-[var(--border-subtle)] bg-[var(--bg-surface)] p-3 text-[12px]">
                {[
                  { id: "uploading", label: "1. Upload .xlsx to timetables bucket" },
                  { id: "publishing", label: "2. Atomic publish_routine() RPC" },
                  { id: "recording", label: "3. Record timetable_runs & broadcast" },
                ].map((s) => (
                  <li key={s.id} className="flex items-center justify-between">
                    <span>{s.label}</span>
                    <span className="font-mono-tabular text-[11px] uppercase">
                      {publishStep === s.id ? "Running..." : publishStep === "done" ? "Done" : "Queued"}
                    </span>
                  </li>
                ))}
              </ol>
            )}

            {publishError && (
              <div
                role="alert"
                className="rounded-[var(--r-control)] border border-[var(--sem-conflict-border)] bg-[var(--sem-conflict-bg)] px-3 py-2 text-[12px] text-[var(--sem-conflict-ink)]"
              >
                {publishError}
              </div>
            )}
          </div>

          <div className="mt-5 flex flex-wrap justify-end gap-2">
            <Button
              type="button"
              variant="secondary"
              size="md"
              disabled={
                publishStep === "uploading" ||
                publishStep === "publishing" ||
                publishStep === "recording"
              }
              onClick={() => setPublishModalOpen(false)}
            >
              Cancel
            </Button>
            <Button
              type="button"
              variant="primary"
              size="md"
              disabled={
                publishStep === "uploading" ||
                publishStep === "publishing" ||
                publishStep === "recording"
              }
              onClick={() => void handleConfirmPublish()}
            >
              <span>
                {publishStep === "uploading" ||
                publishStep === "publishing" ||
                publishStep === "recording"
                  ? "Publishing..."
                  : "Publish Now"}
              </span>
            </Button>
          </div>
        </DialogContent>
      </Dialog>
    </div>
  );
}
