import {
  ArrowsClockwise,
  CaretDown,
  CaretRight,
  CheckCircle,
  CircleNotch,
  FileXls,
  UploadSimple,
  WarningCircle,
  X,
} from "@phosphor-icons/react";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useMemo, useRef, useState } from "react";
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
import { AcademicTimetableMatrix } from "@/features/routine/components/AcademicTimetableMatrix";
import { fetchBaselineConfigAndBuild } from "@/features/routine/services/buildEngineConfig";
import { isRoutineTeacherCodesLive } from "@/features/routine/services/routineService";
import {
  buildDevPreviewParsedWorkbook,
  EngineJobError,
  MAX_WORKBOOK_UPLOAD_BYTES,
  parseRenderedWorkbook,
  publishRoutinePipeline,
  retryRecordTimetableRun,
} from "@/features/routine/services/timetableEngineService";
import {
  assessBaselineConfigForPublish,
  blockingValidationErrorFor,
  extractRowTeacherCodes,
  findCoTeacherBlockers,
} from "@/features/routine/services/validationGate";
import type {
  ParsedRenderedWorkbookResponse,
  PublishPipelineResult,
} from "@/features/routine/types";
import { cn } from "@/lib/utils";

function formatFileSize(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(2)} MB`;
}

function inferSemesterLabelFromFile(filename: string): string {
  const stem = filename.replace(/\.xlsx$/i, "").replace(/[_-]+/g, " ").trim();
  return stem || "Uploaded Routine";
}

export function UploadRoutineTab() {
  const { isDevPreview, profile } = useAuth();
  const queryClient = useQueryClient();
  const fileInputRef = useRef<HTMLInputElement>(null);

  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  const [fileError, setFileError] = useState<string | null>(null);
  const [isDragging, setIsDragging] = useState(false);
  const [semesterLabel, setSemesterLabel] = useState("");
  const [notes, setNotes] = useState("");
  const [isParsing, setIsParsing] = useState(false);
  const [parseError, setParseError] = useState<string | null>(null);
  const [parsedResult, setParsedResult] =
    useState<ParsedRenderedWorkbookResponse | null>(null);
  const [warningsOpen, setWarningsOpen] = useState(false);
  const [confirmEmptyBaseline, setConfirmEmptyBaseline] = useState(false);

  const [publishModalOpen, setPublishModalOpen] = useState(false);
  const [notifyUsers, setNotifyUsers] = useState(false);
  const [publishStep, setPublishStep] = useState<
    "idle" | "uploading" | "publishing" | "recording" | "done" | "error"
  >("idle");
  const [publishError, setPublishError] = useState<string | null>(null);
  const [publishOutcome, setPublishOutcome] =
    useState<PublishPipelineResult | null>(null);
  const [retryingAudit, setRetryingAudit] = useState(false);

  const baselineQuery = useQuery({
    queryKey: ["admin-engine-baseline-config", isDevPreview],
    queryFn: () => fetchBaselineConfigAndBuild(isDevPreview),
    retry: false,
  });

  const coTeacherLiveQuery = useQuery({
    queryKey: ["routine-teacher-codes-live", isDevPreview],
    queryFn: () => isRoutineTeacherCodesLive(isDevPreview),
    staleTime: 60_000,
    retry: false,
  });
  const coTeacherStorageLive = coTeacherLiveQuery.data ?? false;

  const baselineAssessment = useMemo(
    () => assessBaselineConfigForPublish(baselineQuery.data?.baselineCounts),
    [baselineQuery.data?.baselineCounts],
  );

  const allParsedRows = useMemo(
    () =>
      parsedResult
        ? [...parsedResult.rows, ...parsedResult.service_rows]
        : [],
    [parsedResult],
  );

  const validationBlocker = useMemo(
    () =>
      parsedResult
        ? blockingValidationErrorFor(parsedResult.validation)
        : null,
    [parsedResult],
  );

  const coTeacherBlockers = useMemo(
    () =>
      parsedResult
        ? findCoTeacherBlockers(parsedResult.rows, parsedResult.service_rows, {
            coTeacherStorageLive,
          })
        : [],
    [coTeacherStorageLive, parsedResult],
  );

  const canPublish = useMemo(() => {
    if (!parsedResult || !selectedFile) return false;
    if (allParsedRows.length === 0) return false;
    if (validationBlocker !== null) return false;
    if (coTeacherBlockers.length > 0) return false;
    if (!baselineAssessment.canPublish && !confirmEmptyBaseline) return false;
    return true;
  }, [
    allParsedRows.length,
    baselineAssessment.canPublish,
    coTeacherBlockers.length,
    confirmEmptyBaseline,
    parsedResult,
    selectedFile,
    validationBlocker,
  ]);

  const handleSelectFile = (file: File | undefined) => {
    if (!file) return;
    setParseError(null);
    setPublishOutcome(null);
    setPublishError(null);
    setParsedResult(null);

    if (!file.name.toLowerCase().endsWith(".xlsx")) {
      setSelectedFile(null);
      setFileError(
        "Only standard .xlsx routine workbooks are accepted (macros and legacy .xls files are rejected).",
      );
      toast.error("Unsupported file format", {
        description: "Select a standard .xlsx workbook.",
      });
      return;
    }

    if (file.size > MAX_WORKBOOK_UPLOAD_BYTES) {
      setSelectedFile(null);
      setFileError(
        `Workbook is ${formatFileSize(file.size)} — maximum supported upload size is 15 MB.`,
      );
      toast.error("File exceeds 15 MB limit");
      return;
    }

    setFileError(null);
    setSelectedFile(file);
    if (!semesterLabel.trim()) {
      const defaultLabel =
        baselineQuery.data?.config.settings.semester_label?.trim() ||
        inferSemesterLabelFromFile(file.name);
      setSemesterLabel(defaultLabel);
    }
  };

  const handleClearFile = () => {
    setSelectedFile(null);
    setFileError(null);
    setParseError(null);
    setParsedResult(null);
    setPublishOutcome(null);
    if (fileInputRef.current) {
      fileInputRef.current.value = "";
    }
  };

  const handleParseWorkbook = async () => {
    if (!selectedFile) {
      toast.error("Select a rendered .xlsx routine workbook first.");
      return;
    }

    setIsParsing(true);
    setParseError(null);
    setPublishOutcome(null);
    setPublishError(null);

    try {
      let parsed: ParsedRenderedWorkbookResponse;
      if (isDevPreview) {
        parsed = await buildDevPreviewParsedWorkbook(selectedFile.name);
      } else {
        const assembled =
          baselineQuery.data ??
          (await fetchBaselineConfigAndBuild(false).catch(() => null));
        parsed = await parseRenderedWorkbook(selectedFile, {
          config: assembled?.config,
        });
      }
      setParsedResult(parsed);
      setWarningsOpen(parsed.warnings.length > 0 && parsed.warnings.length <= 5);
      toast.success(
        `Parsed ${parsed.rows.length + parsed.service_rows.length} routine slots (${parsed.detected_format})`,
      );
    } catch (err) {
      const msg =
        err instanceof EngineJobError
          ? err.message
          : err instanceof Error
            ? err.message
            : "Failed to parse workbook.";
      setParseError(msg);
      toast.error("Workbook parsing failed", { description: msg });
    } finally {
      setIsParsing(false);
    }
  };

  const handleConfirmPublish = async () => {
    if (!parsedResult || !selectedFile) return;
    setPublishError(null);
    setPublishStep("uploading");

    try {
      const resolvedLabel =
        semesterLabel.trim() || inferSemesterLabelFromFile(selectedFile.name);
      const outcome = await publishRoutinePipeline({
        jobId: null,
        result: {
          rows: parsedResult.rows,
          service_rows: parsedResult.service_rows,
          stats: parsedResult.stats,
          validation: parsedResult.validation,
        },
        workbookBlob: selectedFile,
        semesterLabel: resolvedLabel,
        notes,
        notifyUsers,
        baselineCounts: baselineQuery.data?.baselineCounts ?? null,
        isPrivatePreview: false,
        createdBy: profile?.id ?? null,
        isDevPreview,
        source: "upload",
        allowEmptyBaselineConfirm: confirmEmptyBaseline,
        allowCoTeachers: coTeacherStorageLive,
        onStepChange: (step) => setPublishStep(step),
      });

      setPublishOutcome(outcome);
      setPublishStep("done");
      setPublishModalOpen(false);

      void queryClient.invalidateQueries({ queryKey: ["admin-routines"] });
      void queryClient.invalidateQueries({
        queryKey: ["admin-routine-active-version"],
      });
      void queryClient.invalidateQueries({
        queryKey: ["admin-routine-archive"],
      });
      void queryClient.invalidateQueries({
        queryKey: ["admin-dashboard-counts"],
      });

      if (outcome.secondaryAuditError) {
        toast.warning("Routine published with audit log warning", {
          description: outcome.secondaryAuditError,
        });
      } else {
        toast.success(`Published ${outcome.rowCount} uploaded slots`);
      }
    } catch (err) {
      setPublishStep("error");
      const msg =
        err instanceof Error ? err.message : "Routine publication failed.";
      setPublishError(msg);
      toast.error("Publication blocked or failed", { description: msg });
    }
  };

  const handleRetryAuditLog = async () => {
    if (!publishOutcome?.retryAuditParams) return;
    setRetryingAudit(true);
    try {
      await retryRecordTimetableRun(
        publishOutcome.retryAuditParams,
        isDevPreview,
      );
      setPublishOutcome({
        ...publishOutcome,
        secondaryAuditError: null,
        retryAuditParams: null,
      });
      void queryClient.invalidateQueries({
        queryKey: ["admin-routine-archive"],
      });
      toast.success("Audit log recorded in timetable run history");
    } catch (err) {
      toast.error("Retry audit log failed", {
        description: err instanceof Error ? err.message : "Insert error.",
      });
    } finally {
      setRetryingAudit(false);
    }
  };

  return (
    <div className="space-y-4" data-testid="upload-routine-view">
      {/* Section 1: Upload & Metadata Form */}
      <section
        aria-label="Upload rendered routine workbook"
        className="ledger-card space-y-4 p-5"
      >
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div>
            <h2 className="text-[16px] font-semibold text-[var(--ink-primary)]">
              Upload Rendered Routine Workbook
            </h2>
            <p className="mt-0.5 max-w-[70ch] text-[12.5px] leading-[1.5] text-[var(--ink-secondary)]">
              Upload a Leading University 7-day rendered{" "}
              <code className="font-mono-tabular">.xlsx</code> routine or
              tabular routine sheet (max 15 MB). The FastAPI Phase 3B parser
              validates clocks, aliases, and clashes read-only before anything
              is published.
            </p>
          </div>
          {isDevPreview && (
            <Badge tone="neutral" mono>
              Preview Fixtures
            </Badge>
          )}
        </div>

        {/* Drag & Drop File Zone */}
        <div
          onDragOver={(e) => {
            e.preventDefault();
            setIsDragging(true);
          }}
          onDragLeave={() => setIsDragging(false)}
          onDrop={(e) => {
            e.preventDefault();
            setIsDragging(false);
            handleSelectFile(e.dataTransfer.files?.[0]);
          }}
          className={cn(
            "flex flex-wrap items-center justify-between gap-3 rounded-[var(--r-control)] border border-dashed px-4 py-4 transition-colors",
            isDragging
              ? "border-[var(--accent-brand)] bg-[var(--accent-brand-soft)]/60"
              : "border-[var(--border-control)] bg-[var(--bg-surface)]",
          )}
        >
          <input
            ref={fileInputRef}
            type="file"
            accept=".xlsx"
            aria-label="Select rendered routine .xlsx workbook"
            data-testid="upload-routine-file-input"
            className="sr-only"
            onChange={(e) => handleSelectFile(e.target.files?.[0])}
          />

          <div className="flex min-w-0 items-center gap-3">
            <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-[var(--r-control)] border border-[var(--border-subtle)] bg-[var(--bg-elevated)] text-[var(--accent-brand)]">
              <FileXls size={20} aria-hidden="true" />
            </div>
            <div className="min-w-0">
              {selectedFile ? (
                <>
                  <div
                    title={selectedFile.name}
                    className="font-mono-tabular truncate text-[13.5px] font-semibold text-[var(--ink-primary)]"
                  >
                    {selectedFile.name}
                  </div>
                  <div className="font-mono-tabular text-[11.5px] text-[var(--ink-muted)]">
                    {formatFileSize(selectedFile.size)} · Ready for non-mutating
                    server validation
                  </div>
                </>
              ) : (
                <>
                  <div className="text-[13.5px] font-medium text-[var(--ink-primary)]">
                    Drop a rendered routine{" "}
                    <code className="font-mono-tabular">.xlsx</code> file here
                  </div>
                  <div className="text-[12px] text-[var(--ink-muted)]">
                    Supports Sunday–Saturday rendered day sheets and tabular
                    routine workbooks (≤ 15 MB).
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
              disabled={isParsing}
              onClick={() => fileInputRef.current?.click()}
            >
              <UploadSimple size={14} aria-hidden="true" />
              <span>{selectedFile ? "Change .xlsx" : "Browse .xlsx"}</span>
            </Button>
            {selectedFile && !isParsing && (
              <Button
                type="button"
                variant="ghost"
                size="sm"
                aria-label="Clear selected workbook"
                onClick={handleClearFile}
              >
                <X size={14} aria-hidden="true" />
              </Button>
            )}
          </div>
        </div>

        {fileError && (
          <div
            role="alert"
            data-testid="upload-file-error"
            className="flex items-start gap-2 rounded-[var(--r-control)] border border-[var(--sem-conflict-border)] bg-[var(--sem-conflict-bg)] px-3.5 py-2.5 text-[12.5px] text-[var(--sem-conflict-ink)]"
          >
            <WarningCircle size={16} className="mt-0.5 shrink-0" aria-hidden="true" />
            <span>{fileError}</span>
          </div>
        )}

        {/* Semester Label & Optional Notes */}
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
          <div className="space-y-1">
            <label
              htmlFor="upload-semester-label"
              className="block text-[12px] font-medium text-[var(--ink-secondary)]"
            >
              Semester Label
            </label>
            <input
              id="upload-semester-label"
              type="text"
              value={semesterLabel}
              onChange={(e) => setSemesterLabel(e.target.value)}
              placeholder="e.g. Spring 2026 · Final Committee Routine"
              className="h-9 w-full rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-surface)] px-3 text-[13px] text-[var(--ink-primary)] placeholder:text-[var(--ink-muted)]"
            />
          </div>
          <div className="space-y-1">
            <label
              htmlFor="upload-notes"
              className="block text-[12px] font-medium text-[var(--ink-secondary)]"
            >
              Publication Notes (Optional)
            </label>
            <input
              id="upload-notes"
              type="text"
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
              placeholder="Committee approval note or revision summary"
              className="h-9 w-full rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-surface)] px-3 text-[13px] text-[var(--ink-primary)] placeholder:text-[var(--ink-muted)]"
            />
          </div>
        </div>

        <div className="flex flex-wrap items-center justify-between gap-3 border-t border-[var(--border-subtle)] pt-3">
          <span className="text-[12px] text-[var(--ink-muted)]">
            Parsing never writes to the database or replaces the live routine.
          </span>
          <Button
            type="button"
            variant={parsedResult ? "secondary" : "primary"}
            size="sm"
            data-testid="parse-workbook-btn"
            disabled={!selectedFile || isParsing}
            onClick={() => void handleParseWorkbook()}
          >
            {isParsing ? (
              <CircleNotch size={15} className="animate-spin" aria-hidden="true" />
            ) : (
              <ArrowsClockwise size={15} aria-hidden="true" />
            )}
            <span>
              {isParsing
                ? "Parsing Workbook…"
                : parsedResult
                  ? "Re-Parse Workbook"
                  : "Parse & Validate Workbook"}
            </span>
          </Button>
        </div>

        {isParsing && (
          <div
            role="status"
            data-testid="upload-parsing-status"
            className="flex items-center gap-2.5 rounded-[var(--r-control)] border border-[var(--border-subtle)] bg-[var(--bg-surface)] px-3.5 py-2.5 text-[12.5px] text-[var(--ink-secondary)]"
          >
            <CircleNotch
              size={16}
              className="shrink-0 animate-spin text-[var(--accent-brand)]"
              aria-hidden="true"
            />
            <span>
              Running server-side OOXML preflight and clash validation… (Render
              cold-start may take 30–50 seconds on the first request).
            </span>
          </div>
        )}

        {parseError && (
          <div
            role="alert"
            data-testid="upload-error-recovery"
            className="flex flex-wrap items-center justify-between gap-3 rounded-[var(--r-control)] border border-[var(--sem-conflict-border)] bg-[var(--sem-conflict-bg)] px-3.5 py-3 text-[12.5px] text-[var(--sem-conflict-ink)]"
          >
            <div className="flex items-start gap-2">
              <WarningCircle
                size={16}
                className="mt-0.5 shrink-0"
                aria-hidden="true"
              />
              <span>{parseError}</span>
            </div>
            <Button
              type="button"
              variant="secondary"
              size="sm"
              onClick={() => void handleParseWorkbook()}
            >
              Retry Parse
            </Button>
          </div>
        )}
      </section>

      {/* Publish Outcome Banner */}
      {publishOutcome && (
        <section
          role="status"
          data-testid="upload-publish-outcome"
          className="ledger-card space-y-2 border-l-[3px] border-l-[var(--sem-pine-bar)] p-4"
        >
          <div className="flex flex-wrap items-center justify-between gap-2">
            <div className="flex items-center gap-2 text-[13.5px] font-semibold text-[var(--ink-primary)]">
              <CheckCircle
                size={17}
                className="text-[var(--sem-pine-bar)]"
                aria-hidden="true"
              />
              <span>
                Uploaded routine is live ({publishOutcome.rowCount} slots
                published)
              </span>
            </div>
            {publishOutcome.filePath && (
              <span className="font-mono-tabular text-[11.5px] text-[var(--ink-muted)]">
                {publishOutcome.filePath}
              </span>
            )}
          </div>
          {publishOutcome.secondaryAuditError && (
            <div className="flex flex-wrap items-center justify-between gap-2 rounded-[var(--r-control)] border border-[var(--sem-joint-border)] bg-[var(--sem-joint-bg)] px-3 py-2 text-[12px] text-[var(--sem-joint-ink)]">
              <span>
                Routine published, but audit run log failed:{" "}
                {publishOutcome.secondaryAuditError}
              </span>
              {publishOutcome.retryAuditParams && (
                <Button
                  type="button"
                  variant="secondary"
                  size="sm"
                  disabled={retryingAudit}
                  onClick={() => void handleRetryAuditLog()}
                >
                  {retryingAudit ? "Retrying…" : "Retry Audit Log"}
                </Button>
              )}
            </div>
          )}
        </section>
      )}

      {/* Section 2: Parsed Summary, Guards, Warnings & Embedded 2D Matrix */}
      {parsedResult && (
        <>
          <section
            aria-label="Parsed workbook summary and validation gate"
            data-testid="upload-parsed-summary"
            className="ledger-card space-y-4 p-5"
          >
            <div className="flex flex-wrap items-center justify-between gap-3">
              <div className="flex flex-wrap items-center gap-2">
                <h3 className="text-[15px] font-semibold text-[var(--ink-primary)]">
                  Parsed Workbook Verification
                </h3>
                <Badge tone="neutral" mono>
                  {parsedResult.detected_format}
                </Badge>
                {parsedResult.validation.ok ? (
                  <Badge tone="pine" mono data-testid="upload-validation-badge">
                    Pass
                  </Badge>
                ) : (
                  <Badge
                    tone="conflict"
                    mono
                    data-testid="upload-validation-badge"
                  >
                    Blocking Issues
                  </Badge>
                )}
              </div>

              <Button
                type="button"
                variant="primary"
                size="sm"
                data-testid="upload-publish-btn"
                disabled={!canPublish}
                onClick={() => {
                  setPublishError(null);
                  setPublishStep("idle");
                  setPublishModalOpen(true);
                }}
              >
                <span>Publish Parsed Routine</span>
              </Button>
            </div>

            {/* Summary Metric Strip */}
            <div className="grid grid-cols-2 gap-2.5 sm:grid-cols-5">
              <div className="rounded-[var(--r-control)] border border-[var(--border-subtle)] bg-[var(--bg-surface)] px-3 py-2.5">
                <div className="text-[11px] text-[var(--ink-muted)]">
                  CSE Rows
                </div>
                <div className="font-mono-tabular mt-0.5 text-[16px] font-semibold text-[var(--ink-primary)]">
                  {parsedResult.rows.length}
                </div>
              </div>
              <div className="rounded-[var(--r-control)] border border-[var(--border-subtle)] bg-[var(--bg-surface)] px-3 py-2.5">
                <div className="text-[11px] text-[var(--ink-muted)]">
                  Service Rows
                </div>
                <div className="font-mono-tabular mt-0.5 text-[16px] font-semibold text-[var(--ink-primary)]">
                  {parsedResult.service_rows.length}
                </div>
              </div>
              <div className="rounded-[var(--r-control)] border border-[var(--border-subtle)] bg-[var(--bg-surface)] px-3 py-2.5">
                <div className="text-[11px] text-[var(--ink-muted)]">
                  Cohorts
                </div>
                <div className="font-mono-tabular mt-0.5 text-[16px] font-semibold text-[var(--ink-primary)]">
                  {parsedResult.stats.cohorts}
                </div>
              </div>
              <div className="rounded-[var(--r-control)] border border-[var(--border-subtle)] bg-[var(--bg-surface)] px-3 py-2.5">
                <div className="text-[11px] text-[var(--ink-muted)]">
                  Teachers
                </div>
                <div className="font-mono-tabular mt-0.5 text-[16px] font-semibold text-[var(--ink-primary)]">
                  {parsedResult.stats.teachers}
                </div>
              </div>
              <div className="rounded-[var(--r-control)] border border-[var(--border-subtle)] bg-[var(--bg-surface)] px-3 py-2.5">
                <div className="text-[11px] text-[var(--ink-muted)]">
                  Sheets Read
                </div>
                <div className="font-mono-tabular mt-0.5 text-[16px] font-semibold text-[var(--ink-primary)]">
                  {parsedResult.sheet_names.length}
                </div>
              </div>
            </div>

            {/* Blocking Validation Error */}
            {validationBlocker && (
              <div
                role="alert"
                data-testid="upload-validation-blocker"
                className="flex items-start gap-2.5 rounded-[var(--r-control)] border border-[var(--sem-conflict-border)] bg-[var(--sem-conflict-bg)] p-3 text-[12.5px] text-[var(--sem-conflict-ink)]"
              >
                <WarningCircle
                  size={16}
                  className="mt-0.5 shrink-0"
                  aria-hidden="true"
                />
                <span>{validationBlocker}</span>
              </div>
            )}

            {/* Co-Teacher Blocker (scalar teacher_code storage guard) */}
            {coTeacherBlockers.length > 0 && (
              <div
                role="alert"
                data-testid="upload-coteacher-blocker"
                className="flex items-start gap-2.5 rounded-[var(--r-control)] border border-[var(--sem-conflict-border)] bg-[var(--sem-conflict-bg)] p-3 text-[12.5px] text-[var(--sem-conflict-ink)]"
              >
                <WarningCircle
                  size={16}
                  className="mt-0.5 shrink-0"
                  aria-hidden="true"
                />
                <div>
                  <div className="font-semibold">
                    Publication blocked: {coTeacherBlockers.length} co-taught
                    slot(s) detected
                  </div>
                  <p className="mt-0.5">
                    Current hosted storage retains a single teacher per slot (
                    {coTeacherBlockers
                      .slice(0, 3)
                      .map(
                        (r) =>
                          `${r.subject_code} (${extractRowTeacherCodes(r).join("/")})`,
                      )
                      .join(", ")}
                    ).
                  </p>
                </div>
              </div>
            )}

            {/* Empty-Baseline Explicit Confirmation Gate */}
            {!baselineAssessment.canPublish && (
              <div
                role="alert"
                className="space-y-2 rounded-[var(--r-control)] border border-[var(--sem-joint-border)] bg-[var(--sem-joint-bg)] p-3 text-[12.5px] text-[var(--sem-joint-ink)]"
              >
                <div className="font-semibold">
                  Baseline configuration tables are currently empty
                </div>
                <ul className="list-disc pl-4">
                  {baselineAssessment.blockingReasons.map((reason) => (
                    <li key={reason}>{reason}</li>
                  ))}
                </ul>
                <label className="flex cursor-pointer items-center gap-2 pt-1 font-medium text-[var(--ink-primary)]">
                  <input
                    type="checkbox"
                    checked={confirmEmptyBaseline}
                    onChange={(e) => setConfirmEmptyBaseline(e.target.checked)}
                    data-testid="upload-empty-baseline-confirm"
                  />
                  <span>
                    I confirm this pre-rendered workbook has been verified
                    offline and should be published despite empty baseline
                    configuration.
                  </span>
                </label>
              </div>
            )}

            {/* Collapsible Warnings List */}
            {parsedResult.warnings.length > 0 && (
              <div className="overflow-hidden rounded-[var(--r-control)] border border-[var(--border-subtle)] bg-[var(--bg-surface)]">
                <button
                  type="button"
                  aria-expanded={warningsOpen}
                  data-testid="upload-warnings-toggle"
                  onClick={() => setWarningsOpen((prev) => !prev)}
                  className="flex w-full items-center justify-between gap-2 px-3.5 py-2.5 text-left text-[12.5px] font-medium text-[var(--ink-primary)] hover:bg-[var(--surface-hover)]"
                >
                  <span className="flex items-center gap-1.5">
                    {warningsOpen ? (
                      <CaretDown size={14} aria-hidden="true" />
                    ) : (
                      <CaretRight size={14} aria-hidden="true" />
                    )}
                    <span>Parser Warnings</span>
                  </span>
                  <Badge tone="joint" mono>
                    {parsedResult.warnings.length}
                  </Badge>
                </button>
                {warningsOpen && (
                  <ul className="divide-y divide-[var(--border-subtle)] border-t border-[var(--border-subtle)] px-3.5 py-2 text-[12px] text-[var(--ink-secondary)]">
                    {parsedResult.warnings.map((w, i) => (
                      <li key={i} className="py-1.5">
                        {w}
                      </li>
                    ))}
                  </ul>
                )}
              </div>
            )}
          </section>

          {/* Embedded 2D Academic Timetable Matrix Preview */}
          <section
            aria-label="Parsed workbook 2D timetable preview"
            data-testid="upload-2d-preview"
            className="space-y-3"
          >
            <div className="flex flex-wrap items-center justify-between gap-2 rounded-[var(--r-card)] border border-[var(--border-subtle)] border-l-[3px] border-l-[var(--accent-brand)] bg-[var(--bg-elevated)] px-4 py-2.5 text-[12.5px] text-[var(--ink-secondary)]">
              <span>
                <strong className="font-semibold text-[var(--ink-primary)]">
                  Pre-Publish 2D Inspection — Read-Only:
                </strong>{" "}
                Switch between Section, Faculty, and Room lenses below before
                publishing to Production.
              </span>
              <span className="font-mono-tabular text-[11.5px] text-[var(--ink-muted)]">
                {allParsedRows.length} total slots
              </span>
            </div>

            <AcademicTimetableMatrix
              overrideRows={allParsedRows}
              overrideSourceLabel={
                semesterLabel.trim() || selectedFile?.name || "Uploaded Routine"
              }
              hideCandidateBanner
              coTeacherStorageLive={coTeacherStorageLive}
            />
          </section>
        </>
      )}

      {/* Atomic 3-Step Publication Confirmation Dialog */}
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
        <DialogContent>
          <DialogTitle>Confirm Atomic Routine Publication</DialogTitle>
          <DialogDescription>
            This uploads{" "}
            <strong className="font-mono-tabular text-[var(--ink-primary)]">
              {selectedFile?.name}
            </strong>{" "}
            to the timetables archive and atomically replaces the active campus
            routine with{" "}
            <strong className="font-mono-tabular text-[var(--ink-primary)]">
              {allParsedRows.length}
            </strong>{" "}
            verified slots under{" "}
            <strong className="text-[var(--ink-primary)]">
              {semesterLabel.trim() || "Uploaded Routine"}
            </strong>
            .
          </DialogDescription>

          <div className="mt-4 space-y-3">
            <label className="flex cursor-pointer items-center gap-2 text-[13px] text-[var(--ink-primary)]">
              <input
                type="checkbox"
                checked={notifyUsers}
                onChange={(e) => setNotifyUsers(e.target.checked)}
                disabled={
                  publishStep === "uploading" ||
                  publishStep === "publishing" ||
                  publishStep === "recording"
                }
              />
              <span>Broadcast campus notification after publication</span>
            </label>

            {publishError && (
              <div
                role="alert"
                className="rounded-[var(--r-control)] border border-[var(--sem-conflict-border)] bg-[var(--sem-conflict-bg)] p-3 text-[12.5px] text-[var(--sem-conflict-ink)]"
              >
                {publishError}
              </div>
            )}

            <div className="flex justify-end gap-2 pt-2">
              <Button
                type="button"
                variant="secondary"
                size="sm"
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
                size="sm"
                data-testid="upload-confirm-publish-btn"
                disabled={
                  publishStep === "uploading" ||
                  publishStep === "publishing" ||
                  publishStep === "recording"
                }
                onClick={() => void handleConfirmPublish()}
              >
                {publishStep === "uploading"
                  ? "1/3 Uploading .xlsx…"
                  : publishStep === "publishing"
                    ? "2/3 Publishing Slots…"
                    : publishStep === "recording"
                      ? "3/3 Recording Audit…"
                      : "Publish Now"}
              </Button>
            </div>
          </div>
        </DialogContent>
      </Dialog>
    </div>
  );
}

export default UploadRoutineTab;
