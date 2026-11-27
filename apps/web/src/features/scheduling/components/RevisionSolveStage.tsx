import {
  ArrowRight,
  ArrowsClockwise,
  CheckCircle,
  CircleNotch,
  Cpu,
  FileXls,
  LockSimple,
  Play,
  WarningCircle,
} from "@phosphor-icons/react";
import { useQuery } from "@tanstack/react-query";
import { useEffect, useRef, useState } from "react";
import { toast } from "sonner";
import { Badge } from "@/components/ui/Badge";
import { Button } from "@/components/ui/Button";
import { SolverDiagnosticsPanel } from "@/features/routine/components/SolverDiagnosticsPanel";
import { fetchBaselineConfigAndBuild } from "@/features/routine/services/buildEngineConfig";
import {
  buildCourseDistributionFile,
  type CourseDistributionOfferingRow,
} from "@/features/routine/services/distributionXlsxBuilder";
import {
  downloadJobWorkbook,
  EngineJobError,
  extractOutcomeDiagnostics,
  fetchJobResult,
  fetchRecentSolverJobs,
  runResilientJobPolling,
  submitGenerationJob,
  type DurableSolverJobSummary,
} from "@/features/routine/services/timetableEngineService";
import { getEffectiveColumnValue } from "@/features/scheduling/services/courseDistributionService";
import { readActivePolicySnapshot } from "@/features/scheduling/services/policySnapshotService";
import { useSchedulingWorkbenchStore } from "@/features/scheduling/store/schedulingWorkbenchStore";
import type {
  DistributionSourceRecord,
  GateStatusInfo,
  RevisionContext,
  WorkbenchMode,
  WorkbenchStageId,
} from "@/features/scheduling/types";
import { cn } from "@/lib/utils";

const SOLVER_TIMELINE_NODES = [
  { step: "1", label: "Queued" },
  { step: "2", label: "Ingesting Revision" },
  { step: "3", label: "CP-SAT Solving" },
  { step: "4", label: "Rendering Matrix" },
] as const;

interface RevisionSolveStageProps {
  mode: WorkbenchMode;
  gateD: GateStatusInfo;
  revision?: RevisionContext | null;
  onJumpToStage: (stage: WorkbenchStageId, row?: number) => void;
}

function toOfferingRows(
  records: readonly DistributionSourceRecord[],
): CourseDistributionOfferingRow[] {
  return records.map((rec) => ({
    id: `row-${rec.row}`,
    batch: getEffectiveColumnValue(rec, "A"),
    section: getEffectiveColumnValue(rec, "B"),
    courseCode: getEffectiveColumnValue(rec, "C"),
    courseTitle: getEffectiveColumnValue(rec, "D"),
    credit: Number.parseFloat(getEffectiveColumnValue(rec, "E")) || rec.credit,
    prerequisite: getEffectiveColumnValue(rec, "F"),
    conductingDept: getEffectiveColumnValue(rec, "G"),
    students: Number.parseInt(getEffectiveColumnValue(rec, "H"), 10) || rec.studentCount,
    teacher: getEffectiveColumnValue(rec, "I"),
    totalClasses: Number.parseFloat(getEffectiveColumnValue(rec, "J")) || rec.classes,
    classDuration:
      Number.parseFloat(getEffectiveColumnValue(rec, "K")) || rec.durationMinutes,
    classesPerWeek:
      Number.parseFloat(getEffectiveColumnValue(rec, "L")) || rec.classesPerWeek,
  }));
}

function liveStepIndexOf(state: string | null, phase: string): number {
  if (phase === "done") return 4;
  switch (state) {
    case "queued":
      return 0;
    case "ingesting":
      return 1;
    case "solving":
      return 2;
    case "rendering":
      return 3;
    default:
      return phase === "submitting" ? 0 : -1;
  }
}

export function RevisionSolveStage({
  mode,
  gateD,
  revision = null,
  onJumpToStage,
}: RevisionSolveStageProps) {
  const {
    liveRecords,
    livePolicySnapshot,
    liveJobId,
    liveJobPhase,
    liveJobState,
    liveJobProgress,
    liveJobElapsedMs,
    liveSolverResult,
    liveSolverDiagnostics,
    liveSolverError,
    setLiveSolveSubmitting,
    setLiveSolvePolling,
    tickLiveSolveElapsed,
    setLiveSolveComplete,
    setLiveSolveFailed,
    previewRevision,
    previewSolverConfig,
    previewSolverResult,
    previewSolverStepIndex,
    updatePreviewSolverConfig,
    startPreviewSimulation,
    setPreviewSolverStep,
    completePreviewSimulation,
  } = useSchedulingWorkbenchStore();

  const [overrideWorkbookFile, setOverrideWorkbookFile] = useState<File | null>(null);
  const [timeLimitS, setTimeLimitS] = useState(120);
  const [recoveringJobId, setRecoveringJobId] = useState<string | null>(null);
  const pollAbortRef = useRef<AbortController | null>(null);
  const fileInputRef = useRef<HTMLInputElement | null>(null);

  const isLiveUnlocked = mode === "live" && gateD.unlocked;
  const isLiveBusy = liveJobPhase === "submitting" || liveJobPhase === "polling";

  useEffect(() => {
    if (!isLiveBusy) return;
    const timer = window.setInterval(() => tickLiveSolveElapsed(500), 500);
    return () => window.clearInterval(timer);
  }, [isLiveBusy, tickLiveSolveElapsed]);

  useEffect(() => () => pollAbortRef.current?.abort(), []);

  const baselineQuery = useQuery({
    queryKey: ["admin-engine-baseline-config", false],
    enabled: isLiveUnlocked,
    queryFn: () => fetchBaselineConfigAndBuild(false),
    retry: false,
  });

  const recentJobsQuery = useQuery({
    queryKey: [
      "scheduling-recent-solver-jobs",
      revision?.revisionId ?? null,
      revision?.scopeId ?? null,
    ],
    enabled: isLiveUnlocked,
    queryFn: () =>
      fetchRecentSolverJobs({
        revisionId: revision?.revisionId ?? null,
        schedulingScopeId: revision?.scopeId || null,
        limit: 8,
      }),
    retry: false,
  });

  if (mode === "live" && !gateD.unlocked) {
    return (
      <section
        data-testid="live-gate-d-solve-locked"
        className="ledger-card flex max-w-[760px] flex-col gap-3 p-6"
      >
        <div className="flex flex-wrap items-center justify-between gap-2">
          <span className="font-mono-tabular text-[12px] font-medium text-[var(--accent-brand)]">
            Stage 4 · Gate D Required
          </span>
          <Badge tone="joint" mono>
            <LockSimple size={12} aria-hidden="true" />
            <span>Locked · Gate D</span>
          </Badge>
        </div>
        <h2 className="text-[17px] font-semibold text-[var(--ink-primary)]">
          Revision-Bound Solver Pipeline Locked in Live Mode
        </h2>
        <p className="text-[13.5px] leading-[1.55] text-[var(--ink-secondary)]">
          {gateD.reason} Track 1 manual workbook CP-SAT generation remains
          operational in{" "}
          <span className="font-semibold text-[var(--ink-primary)]">
            Routine Operations
          </span>
          .
        </p>
      </section>
    );
  }

  if (isLiveUnlocked) {
    const canSynthesizeFromRevision = liveRecords.length > 0;
    const activeWorkbookReady = Boolean(overrideWorkbookFile || canSynthesizeFromRevision);
    const liveStepIdx = liveStepIndexOf(liveJobState, liveJobPhase);
    const liveSolvedOk = Boolean(
      liveSolverResult &&
        (liveSolverResult.outcome === "OPTIMAL" ||
          liveSolverResult.outcome === "FEASIBLE" ||
          liveSolverResult.validation.ok),
    );

    const handleRunLiveSolve = async () => {
      if (!activeWorkbookReady) {
        toast.error("Load a distribution revision or attach an .xlsx workbook first.");
        return;
      }
      pollAbortRef.current?.abort();
      const abort = new AbortController();
      pollAbortRef.current = abort;
      setLiveSolveSubmitting();

      try {
        const baseline =
          baselineQuery.data ?? (await fetchBaselineConfigAndBuild(false));
        const activeSnap =
          livePolicySnapshot ??
          (await readActivePolicySnapshot({
            revisionId: revision?.revisionId ?? null,
            scopeId: revision?.scopeId || null,
          }));
        const configPayload = {
          ...baseline.config,
          ...(activeSnap
            ? {
                policy_snapshot: {
                  ...activeSnap.policy_payload,
                  default_section_weekend: activeSnap.default_section_weekend,
                  batch_max_off_day_spread: activeSnap.batch_max_off_day_spread,
                  max_section_internal_gap: activeSnap.max_section_internal_gap,
                  allow_sessional_across_break:
                    activeSnap.allow_sessional_across_break,
                  physics_lab_course_codes: activeSnap.physics_lab_course_codes,
                },
              }
            : {}),
        };

        const workbookFile =
          overrideWorkbookFile ??
          buildCourseDistributionFile(
            toOfferingRows(liveRecords),
            `Revision_v${revision?.revisionVersion ?? 1}_Distribution.xlsx`,
            { termLabel: revision?.semester ?? undefined },
          );

        const sourceContractJson = revision
          ? JSON.stringify({
              source_sha256: revision.sourceHash,
              revision: revision.revisionVersion,
              revision_id: revision.revisionId,
              revision_version: revision.revisionVersion,
            })
          : undefined;

        const { job_id } = await submitGenerationJob({
          file: workbookFile,
          configJson: JSON.stringify(configPayload),
          timeLimitS,
          sourceContractJson,
          schedulingScopeId: revision?.scopeId || null,
          revisionId: revision?.revisionId ?? null,
          revisionVersion: revision?.revisionVersion ?? null,
          policySnapshotId: activeSnap?.id ?? null,
          signal: abort.signal,
        });

        setLiveSolvePolling({ jobId: job_id, state: "queued", progress: 0 });
        await runResilientJobPolling({
          jobId: job_id,
          signal: abort.signal,
          onStatus: (st) => {
            setLiveSolvePolling({
              jobId: job_id,
              state: st.state,
              progress: st.progress,
            });
          },
        });

        const res = await fetchJobResult(job_id, abort.signal);
        const diagnostics = extractOutcomeDiagnostics(res) ?? null;
        if (
          res.outcome &&
          res.outcome !== "OPTIMAL" &&
          res.outcome !== "FEASIBLE"
        ) {
          setLiveSolveFailed({
            jobId: job_id,
            error:
              res.error ||
              `Solver terminated with ${res.outcome} (${res.termination_reason ?? "policy"}).`,
            diagnostics,
          });
          toast.error(`Solver outcome: ${res.outcome}`);
          void recentJobsQuery.refetch();
          return;
        }

        const workbookBlob = res.has_workbook
          ? await downloadJobWorkbook(job_id, abort.signal).catch(() => null)
          : null;

        setLiveSolveComplete({
          jobId: job_id,
          result: res,
          diagnostics,
          revisionVersion: revision?.revisionVersion ?? null,
          workbookBlob,
        });
        toast.success(
          `Revision solve complete (${res.rows.length + res.service_rows.length} slots)`,
        );
        void recentJobsQuery.refetch();
      } catch (err) {
        const diagnostics =
          err instanceof EngineJobError ? (err.diagnostics ?? null) : null;
        const msg =
          err instanceof Error ? err.message : "Live CP-SAT solve failed.";
        setLiveSolveFailed({ error: msg, diagnostics });
        toast.error("Revision solve failed", { description: msg });
        void recentJobsQuery.refetch();
      }
    };

    const handleRecoverJob = async (job: DurableSolverJobSummary) => {
      setRecoveringJobId(job.job_id);
      try {
        if (job.state === "done" || job.outcome) {
          const res = await fetchJobResult(job.job_id);
          const diagnostics = extractOutcomeDiagnostics(res) ?? null;
          if (
            res.outcome &&
            res.outcome !== "OPTIMAL" &&
            res.outcome !== "FEASIBLE"
          ) {
            setLiveSolveFailed({
              jobId: job.job_id,
              error: res.error || `Solver outcome: ${res.outcome}`,
              diagnostics,
            });
          } else {
            const blob = res.has_workbook
              ? await downloadJobWorkbook(job.job_id).catch(() => null)
              : null;
            setLiveSolveComplete({
              jobId: job.job_id,
              result: res,
              diagnostics,
              revisionVersion:
                job.revision_version ?? revision?.revisionVersion ?? null,
              workbookBlob: blob,
            });
            toast.success(`Recovered durable job ${job.job_id}`);
          }
        } else {
          setLiveSolvePolling({
            jobId: job.job_id,
            state: (job.state as typeof liveJobState) ?? "solving",
            progress: job.progress,
          });
        }
      } catch (err) {
        toast.error("Could not recover solver job", {
          description: err instanceof Error ? err.message : "Fetch failed.",
        });
      } finally {
        setRecoveringJobId(null);
      }
    };

    return (
      <div className="space-y-4" data-testid="live-gate-d-solve-panel">
        {/* Bound Revision & Workbook Contract Header */}
        <section className="ledger-card flex flex-wrap items-center justify-between gap-3 p-4">
          <div className="flex items-start gap-3">
            <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-[var(--r-control)] border border-[var(--border-subtle)] bg-[var(--bg-surface)] text-[var(--accent-brand)]">
              <Cpu size={18} aria-hidden="true" />
            </div>
            <div>
              <div className="flex flex-wrap items-center gap-2">
                <span className="text-[14px] font-semibold text-[var(--ink-primary)]">
                  Gate D Revision-Bound CP-SAT Solver
                </span>
                <Badge tone="lab" mono>
                  Durable Jobs Active
                </Badge>
              </div>
              <div className="font-mono-tabular mt-0.5 text-[12px] text-[var(--ink-secondary)]">
                {revision
                  ? `Rev #${revision.revisionNumber} (v${revision.revisionVersion}) · ${liveRecords.length} ledger rows · hash ${revision.sourceHash.slice(0, 10)}`
                  : "No live accepted revision selected yet"}
              </div>
            </div>
          </div>

          <div className="flex flex-wrap items-center gap-2">
            <label className="flex items-center gap-1.5 rounded-[var(--r-control)] border border-[var(--border-subtle)] bg-[var(--bg-surface)] px-2.5 py-1.5 text-[12px]">
              <span className="text-[var(--ink-muted)]">Time Limit</span>
              <select
                value={timeLimitS}
                disabled={isLiveBusy}
                onChange={(e) => setTimeLimitS(Number(e.target.value))}
                className="font-mono-tabular bg-transparent font-semibold text-[var(--ink-primary)] outline-none"
              >
                <option value={60}>60s</option>
                <option value={120}>120s</option>
                <option value={180}>180s</option>
              </select>
            </label>
            <input
              ref={fileInputRef}
              type="file"
              accept=".xlsx"
              className="hidden"
              onChange={(e) => setOverrideWorkbookFile(e.target.files?.[0] ?? null)}
            />
            <Button
              type="button"
              variant="secondary"
              size="sm"
              disabled={isLiveBusy}
              onClick={() => fileInputRef.current?.click()}
            >
              <FileXls size={14} aria-hidden="true" />
              <span>
                {overrideWorkbookFile
                  ? overrideWorkbookFile.name
                  : "Override .xlsx"}
              </span>
            </Button>
            <Button
              type="button"
              variant="primary"
              size="md"
              data-testid="live-run-cpsat-btn"
              disabled={isLiveBusy || !activeWorkbookReady}
              onClick={() => void handleRunLiveSolve()}
            >
              {isLiveBusy ? (
                <CircleNotch size={15} className="animate-spin" aria-hidden="true" />
              ) : (
                <Play size={15} aria-hidden="true" />
              )}
              <span>
                {isLiveBusy
                  ? `${liveJobState ?? "running"} (${Math.round(liveJobProgress * 100)}%)`
                  : "Run Revision Solve"}
              </span>
            </Button>
          </div>
        </section>

        {/* Live 4-Node Execution Timeline */}
        {(liveJobPhase !== "idle" || liveSolverResult) && (
          <section className="ledger-card space-y-4 p-5">
            <div className="flex flex-wrap items-center justify-between gap-2">
              <div className="flex flex-wrap items-center gap-2">
                <h3 className="text-[14px] font-semibold text-[var(--ink-primary)]">
                  CP-SAT Execution Progress
                </h3>
                {liveJobId && (
                  <Badge tone="neutral" mono>
                    Job {liveJobId}
                  </Badge>
                )}
                {isLiveBusy && (
                  <span className="font-mono-tabular text-[11.5px] text-[var(--ink-muted)]">
                    {(liveJobElapsedMs / 1000).toFixed(1)}s elapsed
                  </span>
                )}
              </div>
              {liveSolvedOk && (
                <Button
                  type="button"
                  variant="secondary"
                  size="sm"
                  data-testid="live-proceed-review-btn"
                  onClick={() => onJumpToStage("review")}
                >
                  <span>Proceed to Review &amp; Diff</span>
                  <ArrowRight size={14} aria-hidden="true" />
                </Button>
              )}
            </div>

            <ol className="grid grid-cols-2 gap-2.5 sm:grid-cols-4">
              {SOLVER_TIMELINE_NODES.map((node, idx) => {
                const completed = liveStepIdx > idx;
                const current = isLiveBusy && liveStepIdx === idx;
                return (
                  <li
                    key={node.step}
                    className={cn(
                      "flex items-center gap-2 rounded-[var(--r-control)] border px-3 py-2 text-[12px]",
                      completed
                        ? "border-[var(--sem-lab-border)] bg-[var(--sem-lab-bg)] text-[var(--sem-lab-ink)]"
                        : current
                          ? "border-[var(--accent-brand)] bg-[var(--accent-brand-soft)] font-semibold text-[var(--accent-brand)]"
                          : "border-[var(--border-subtle)] bg-[var(--bg-surface)] text-[var(--ink-muted)]",
                    )}
                  >
                    {completed ? (
                      <CheckCircle size={15} weight="fill" aria-hidden="true" />
                    ) : current ? (
                      <CircleNotch size={15} className="animate-spin" aria-hidden="true" />
                    ) : (
                      <span className="font-mono-tabular flex h-4 w-4 items-center justify-center rounded-full border border-current text-[10px]">
                        {node.step}
                      </span>
                    )}
                    <span>{node.label}</span>
                  </li>
                );
              })}
            </ol>

            {liveSolverError && (
              <div
                role="alert"
                className="flex items-start gap-2 rounded-[var(--r-control)] border border-[var(--sem-conflict-border)] bg-[var(--sem-conflict-bg)] p-3 text-[12.5px] text-[var(--sem-conflict-ink)]"
              >
                <WarningCircle size={16} className="mt-0.5 shrink-0" aria-hidden="true" />
                <span>{liveSolverError}</span>
              </div>
            )}

            {liveSolverDiagnostics && (
              <SolverDiagnosticsPanel diagnostics={liveSolverDiagnostics} />
            )}
          </section>
        )}

        {/* Recent Durable Solver Jobs (`public.solver_jobs`) */}
        <section
          data-testid="durable-jobs-recovery-panel"
          className="ledger-card space-y-3 p-4"
        >
          <div className="flex flex-wrap items-center justify-between gap-2">
            <div>
              <h3 className="text-[13.5px] font-semibold text-[var(--ink-primary)]">
                Recent Durable Solver Jobs
              </h3>
              <p className="text-[12px] text-[var(--ink-secondary)]">
                Persisted in <code className="font-mono-tabular">public.solver_jobs</code> &amp; Storage — recover completed runs even after Render restarts.
              </p>
            </div>
            <Button
              type="button"
              variant="secondary"
              size="sm"
              disabled={recentJobsQuery.isFetching}
              onClick={() => void recentJobsQuery.refetch()}
            >
              <ArrowsClockwise
                size={13}
                className={recentJobsQuery.isFetching ? "animate-spin" : undefined}
                aria-hidden="true"
              />
              <span>Refresh Jobs</span>
            </Button>
          </div>

          {recentJobsQuery.isError ? (
            <p className="text-[12px] text-[var(--ink-muted)]">
              Unable to query recent engine jobs right now ({recentJobsQuery.error instanceof Error ? recentJobsQuery.error.message : "offline"}).
            </p>
          ) : (recentJobsQuery.data ?? []).length === 0 ? (
            <p className="text-[12px] text-[var(--ink-muted)]">
              No durable solver jobs recorded yet for this revision.
            </p>
          ) : (
            <div className="divide-y divide-[var(--border-subtle)] rounded-[var(--r-control)] border border-[var(--border-subtle)] bg-[var(--bg-surface)]">
              {(recentJobsQuery.data ?? []).map((job) => (
                <div
                  key={job.job_id}
                  className="flex flex-wrap items-center justify-between gap-2 px-3.5 py-2.5 text-[12px]"
                >
                  <div className="flex flex-wrap items-center gap-2">
                    <Badge tone={job.state === "done" ? "lab" : job.state === "failed" ? "conflict" : "joint"} mono>
                      {job.outcome ?? job.state}
                    </Badge>
                    <span className="font-mono-tabular font-semibold text-[var(--ink-primary)]">
                      {job.job_id}
                    </span>
                    {job.revision_version != null && (
                      <span className="font-mono-tabular text-[var(--ink-muted)]">
                        v{job.revision_version}
                      </span>
                    )}
                    {job.created_at && (
                      <span className="text-[var(--ink-muted)]">
                        {new Date(job.created_at).toLocaleString()}
                      </span>
                    )}
                  </div>
                  <Button
                    type="button"
                    variant="secondary"
                    size="sm"
                    disabled={recoveringJobId === job.job_id}
                    onClick={() => void handleRecoverJob(job)}
                  >
                    {recoveringJobId === job.job_id ? "Loading…" : "Recover Result"}
                  </Button>
                </div>
              ))}
            </div>
          )}
        </section>
      </div>
    );
  }

  const isRunning = previewSolverStepIndex >= 0 && previewSolverStepIndex < 4;

  const triggerSimulatedRun = (outcome: "optimal" | "infeasible") => {
    startPreviewSimulation();
    window.setTimeout(() => setPreviewSolverStep(1), 80);
    window.setTimeout(() => setPreviewSolverStep(2), 160);
    window.setTimeout(() => setPreviewSolverStep(3), 240);
    window.setTimeout(() => completePreviewSimulation(outcome), 320);
  };

  return (
    <div className="space-y-4">
      {/* Bound Source Contract Header */}
      <section className="ledger-card flex flex-wrap items-center justify-between gap-3 p-4">
        <div className="flex items-start gap-3">
          <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-[var(--r-control)] border border-[var(--border-subtle)] bg-[var(--bg-surface)] text-[var(--accent-brand)]">
            <Cpu size={18} aria-hidden="true" />
          </div>
          <div>
            <div className="text-[14px] font-semibold text-[var(--ink-primary)]">
              OR-Tools CP-SAT Binding Summary
            </div>
            <div className="font-mono-tabular mt-0.5 text-[12px] text-[var(--ink-secondary)]">
              Rev #{previewRevision.revisionNumber} (v{previewRevision.revisionVersion}) ·{" "}
              {previewRevision.totalRows} offerings · hash{" "}
              {previewRevision.sourceHash.slice(0, 10)}
            </div>
          </div>
        </div>
        <Badge tone="neutral" mono>
          {previewSolverConfig.engineProfile}
        </Badge>
      </section>

      {/* Tiered Objective Weights (Mirrors engine/solver.py soft objectives) */}
      <section className="ledger-card space-y-4 p-5">
        <div className="flex flex-wrap items-center justify-between gap-2">
          <div>
            <h2 className="text-[15px] font-semibold text-[var(--ink-primary)]">
              Tiered Soft-Objective Weights &amp; Budget
            </h2>
            <p className="text-[12.5px] text-[var(--ink-secondary)]">
              Hard constraints (R1–R7, R10–R13) are non-relaxable. Tune tiered
              preference penalties below.
            </p>
          </div>
          <span className="font-mono-tabular text-[12px] text-[var(--ink-muted)]">
            Budget: {previewSolverConfig.timeLimitSeconds}s
          </span>
        </div>

        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
          {(
            [
              {
                key: "cohortCompactnessWeight",
                label: "Tier 1 · Cohort Compactness (R3 / R9)",
              },
              {
                key: "facultyPreferenceWeight",
                label: "Tier 2 · Faculty Preferred Windows (R8)",
              },
              {
                key: "theorySpreadWeight",
                label: "Tier 3 · Theory Non-Adjacent Spread (R13)",
              },
              {
                key: "latePeriodAvoidanceWeight",
                label: "Tier 4 · Late Period Avoidance (R15)",
              },
            ] as const
          ).map((slider) => {
            const val = previewSolverConfig[slider.key];
            return (
              <label
                key={slider.key}
                className="flex flex-col gap-1.5 rounded-[var(--r-control)] border border-[var(--border-subtle)] bg-[var(--bg-surface)] px-3.5 py-2.5 text-[12.5px]"
              >
                <div className="flex items-center justify-between">
                  <span className="font-medium text-[var(--ink-primary)]">
                    {slider.label}
                  </span>
                  <span className="font-mono-tabular font-semibold text-[var(--accent-brand)]">
                    {val.toFixed(2)}
                  </span>
                </div>
                <input
                  type="range"
                  min={0}
                  max={1}
                  step={0.05}
                  value={val}
                  onChange={(e) =>
                    updatePreviewSolverConfig({
                      [slider.key]: Number.parseFloat(e.target.value),
                    })
                  }
                  className="accent-[var(--accent-brand)]"
                />
              </label>
            );
          })}
        </div>

        <div className="flex flex-wrap items-center justify-between gap-2 border-t border-[var(--border-subtle)] pt-3">
          <div className="flex flex-wrap items-center gap-2">
            <Button
              variant="primary"
              size="md"
              disabled={isRunning}
              data-testid="simulate-optimal-solve-btn"
              onClick={() => triggerSimulatedRun("optimal")}
            >
              {isRunning ? (
                <CircleNotch size={15} className="animate-spin" aria-hidden="true" />
              ) : (
                <Play size={15} aria-hidden="true" />
              )}
              <span>Simulate Optimal Solve</span>
            </Button>
            <Button
              variant="secondary"
              size="md"
              disabled={isRunning}
              data-testid="simulate-infeasible-solve-btn"
              onClick={() => triggerSimulatedRun("infeasible")}
            >
              <span>Simulate Infeasible Conflict</span>
            </Button>
          </div>

          {previewSolverResult?.outcome === "optimal" && (
            <Button
              variant="secondary"
              size="sm"
              onClick={() => onJumpToStage("review")}
            >
              <span>Review Candidate Schedule</span>
              <ArrowRight size={14} aria-hidden="true" />
            </Button>
          )}
        </div>
      </section>

      {/* Honest 4-Node Solver Timeline (No fabricated progress bar) */}
      <section className="ledger-card space-y-4 p-5">
        <div className="flex flex-wrap items-center justify-between gap-2">
          <h3 className="text-[14px] font-semibold text-[var(--ink-primary)]">
            4-Node CP-SAT Execution Timeline
          </h3>
          {previewSolverResult && (
            <Badge
              tone={
                previewSolverResult.outcome === "optimal" ? "lab" : "conflict"
              }
              mono
            >
              {previewSolverResult.outcomeLabel}
            </Badge>
          )}
        </div>

        <ol className="grid grid-cols-2 gap-2.5 sm:grid-cols-4">
          {SOLVER_TIMELINE_NODES.map((node, idx) => {
            const completed = previewSolverStepIndex > idx;
            const current = isRunning && previewSolverStepIndex === idx;
            return (
              <li
                key={node.step}
                className={cn(
                  "flex items-center gap-2 rounded-[var(--r-control)] border px-3 py-2 text-[12px]",
                  completed
                    ? "border-[var(--sem-lab-border)] bg-[var(--sem-lab-bg)] text-[var(--sem-lab-ink)]"
                    : current
                      ? "border-[var(--accent-brand)] bg-[var(--accent-brand-soft)] font-semibold text-[var(--accent-brand)]"
                      : "border-[var(--border-subtle)] bg-[var(--bg-surface)] text-[var(--ink-muted)]",
                )}
              >
                {completed ? (
                  <CheckCircle size={15} weight="fill" aria-hidden="true" />
                ) : current ? (
                  <CircleNotch size={15} className="animate-spin" aria-hidden="true" />
                ) : (
                  <span className="font-mono-tabular flex h-4 w-4 items-center justify-center rounded-full border border-current text-[10px]">
                    {node.step}
                  </span>
                )}
                <span>{node.label}</span>
              </li>
            );
          })}
        </ol>

        {previewSolverResult && (
          <div className="grid grid-cols-2 gap-2.5 sm:grid-cols-4">
            {Object.entries(previewSolverResult.diagnostics).map(([k, v]) => (
              <div
                key={k}
                className="rounded-[var(--r-control)] border border-[var(--border-subtle)] bg-[var(--bg-surface)] px-3 py-2"
              >
                <div className="text-[11px] text-[var(--ink-muted)]">{k}</div>
                <div className="font-mono-tabular mt-0.5 text-[13.5px] font-semibold text-[var(--ink-primary)]">
                  {v}
                </div>
              </div>
            ))}
          </div>
        )}

        {previewSolverResult &&
          previewSolverResult.conflictDiagnostics.length > 0 && (
            <div
              data-testid="solver-conflict-diagnostics"
              className="space-y-2 border-t border-[var(--border-subtle)] pt-3"
            >
              {previewSolverResult.conflictDiagnostics.map((diag) => (
                <div
                  key={diag.constraintId}
                  className="flex flex-wrap items-start justify-between gap-3 rounded-[var(--r-control)] border border-[var(--sem-conflict-border)] bg-[var(--sem-conflict-bg)] p-3.5 text-[12.5px] text-[var(--sem-conflict-ink)]"
                >
                  <div className="space-y-1">
                    <div className="flex items-center gap-2 font-semibold">
                      <WarningCircle size={15} aria-hidden="true" />
                      <span>
                        {diag.constraintId}: {diag.title}
                      </span>
                    </div>
                    <p>{diag.humanExplanation}</p>
                    <p className="text-[11.5px]">
                      Suggested action: {diag.suggestedAction}
                    </p>
                  </div>
                  <Button
                    variant="secondary"
                    size="sm"
                    onClick={() => onJumpToStage(diag.targetStage, diag.targetRow)}
                  >
                    <span>Fix Source</span>
                    <ArrowRight size={13} aria-hidden="true" />
                  </Button>
                </div>
              ))}
            </div>
          )}
      </section>
    </div>
  );
}
