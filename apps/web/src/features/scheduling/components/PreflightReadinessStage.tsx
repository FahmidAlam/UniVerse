import {
  ArrowRight,
  ArrowsClockwise,
  CheckCircle,
  LockSimple,
  ShieldCheck,
  WarningCircle,
} from "@phosphor-icons/react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useEffect } from "react";
import { toast } from "sonner";
import { LedgerTableSkeleton } from "@/components/ui/AsyncStates";
import { Badge } from "@/components/ui/Badge";
import { Button } from "@/components/ui/Button";
import { fetchSectionPolicies } from "@/features/admin/services/batchesService";
import { fetchCatalogCourses } from "@/features/admin/services/coursesService";
import { fetchFaculty } from "@/features/admin/services/facultyService";
import { fetchRooms } from "@/features/admin/services/roomsService";
import { fetchTimetableSettings } from "@/features/admin/services/settingsService";
import {
  DEFAULT_POLICY_SNAPSHOT_FORM,
  fetchLatestValidationArtifact,
  readActivePolicySnapshot,
  saveValidationReportArtifact,
  validatePolicyReadiness,
  type PreflightValidationReport,
} from "@/features/scheduling/services/policySnapshotService";
import { useSchedulingWorkbenchStore } from "@/features/scheduling/store/schedulingWorkbenchStore";
import type {
  ArtifactFreshnessSummary,
  DistributionSourceRecord,
  GateStatusInfo,
  RevisionContext,
  WorkbenchMode,
  WorkbenchStageId,
} from "@/features/scheduling/types";

interface PreflightReadinessStageProps {
  mode: WorkbenchMode;
  gateC: GateStatusInfo;
  gateD?: GateStatusInfo;
  revision?: RevisionContext | null;
  liveRecords?: readonly DistributionSourceRecord[];
  liveFreshness?: ArtifactFreshnessSummary;
  onJumpToStage: (stage: WorkbenchStageId, row?: number) => void;
}

export function PreflightReadinessStage({
  mode,
  gateC,
  gateD,
  revision = null,
  liveRecords = [],
  liveFreshness,
  onJumpToStage,
}: PreflightReadinessStageProps) {
  const queryClient = useQueryClient();
  const {
    previewReadinessItems,
    previewArtifactFreshness,
    revalidatePreviewArtifacts,
    livePolicySnapshot,
    livePreflightReport,
    setLivePreflightResult,
  } = useSchedulingWorkbenchStore();

  const isLiveUnlocked = mode === "live" && gateC.unlocked;

  const artifactQuery = useQuery({
    queryKey: ["scheduling-validation-artifact", revision?.revisionId ?? null],
    enabled: isLiveUnlocked && Boolean(revision?.revisionId),
    queryFn: () => fetchLatestValidationArtifact(revision!.revisionId),
    retry: false,
  });

  useEffect(() => {
    if (!isLiveUnlocked || !artifactQuery.data) return;
    const payload = artifactQuery.data.payload;
    if (payload && typeof payload === "object" && "checks" in payload) {
      setLivePreflightResult({
        report: payload as PreflightValidationReport,
        artifact: artifactQuery.data,
      });
    }
  }, [artifactQuery.data, isLiveUnlocked, setLivePreflightResult]);

  const runPreflightMutation = useMutation({
    mutationFn: async () => {
      const [activeSnap, faculty, rooms, coursesRes, sectionsRes, settings] =
        await Promise.all([
          livePolicySnapshot
            ? Promise.resolve(livePolicySnapshot)
            : readActivePolicySnapshot({
                revisionId: revision?.revisionId ?? null,
                scopeId: revision?.scopeId || null,
              }),
          fetchFaculty(false),
          fetchRooms(false),
          fetchCatalogCourses(false),
          fetchSectionPolicies(false),
          fetchTimetableSettings(false),
        ]);

      const policyPayload = activeSnap
        ? {
            default_section_weekend: activeSnap.default_section_weekend,
            batch_max_off_day_spread: activeSnap.batch_max_off_day_spread,
            max_section_internal_gap: activeSnap.max_section_internal_gap,
            allow_sessional_across_break: activeSnap.allow_sessional_across_break,
            physics_lab_course_codes: activeSnap.physics_lab_course_codes,
            ...activeSnap.policy_payload,
          }
        : {
            default_section_weekend:
              DEFAULT_POLICY_SNAPSHOT_FORM.defaultSectionWeekend,
            batch_max_off_day_spread:
              DEFAULT_POLICY_SNAPSHOT_FORM.batchMaxOffDaySpread,
            max_section_internal_gap:
              DEFAULT_POLICY_SNAPSHOT_FORM.maxSectionInternalGap,
            allow_sessional_across_break:
              DEFAULT_POLICY_SNAPSHOT_FORM.allowSessionalAcrossBreak,
            physics_lab_course_codes:
              DEFAULT_POLICY_SNAPSHOT_FORM.physicsLabCourseCodes,
            ...DEFAULT_POLICY_SNAPSHOT_FORM.policyPayload,
          };

      const report = await validatePolicyReadiness({
        policy_snapshot: policyPayload,
        faculty: faculty as unknown as Array<Record<string, unknown>>,
        rooms: rooms as unknown as Array<Record<string, unknown>>,
        courses: coursesRes.courses as unknown as Array<Record<string, unknown>>,
        sections: sectionsRes.sections as unknown as Array<Record<string, unknown>>,
        settings: settings as unknown as Record<string, unknown>,
        offerings: liveRecords as unknown as Array<Record<string, unknown>>,
      });

      let savedArtifact = null;
      if (revision?.revisionId) {
        savedArtifact = await saveValidationReportArtifact({
          revisionId: revision.revisionId,
          policySnapshotId: activeSnap?.id ?? null,
          report,
        });
      }

      return { report, artifact: savedArtifact };
    },
    onSuccess: ({ report, artifact }) => {
      setLivePreflightResult({ report, artifact });
      void queryClient.invalidateQueries({
        queryKey: ["scheduling-validation-artifact"],
      });
      if (report.ok) {
        toast.success("Server preflight passed with 0 blockers");
      } else {
        toast.warning(
          `Preflight found ${report.blockers.length} blocker(s)`,
        );
      }
    },
    onError: (err) => {
      toast.error("Server preflight failed", {
        description:
          err instanceof Error ? err.message : "Could not reach preflight validator.",
      });
    },
  });

  if (mode === "live" && !gateC.unlocked) {
    return (
      <section
        data-testid="live-gate-c-readiness-locked"
        className="ledger-card flex max-w-[760px] flex-col gap-3 p-6"
      >
        <div className="flex flex-wrap items-center justify-between gap-2">
          <span className="font-mono-tabular text-[12px] font-medium text-[var(--accent-brand)]">
            Stage 3 · Gate C Required
          </span>
          <Badge tone="joint" mono>
            <LockSimple size={12} aria-hidden="true" />
            <span>Locked · Gate C</span>
          </Badge>
        </div>
        <h2 className="text-[17px] font-semibold text-[var(--ink-primary)]">
          Server Preflight Validation Awaits Stage 5A
        </h2>
        <p className="text-[13.5px] leading-[1.55] text-[var(--ink-secondary)]">
          {gateC.reason} Track 1 validation diagnostics remain active in{" "}
          <span className="font-semibold text-[var(--ink-primary)]">
            Routine Operations
          </span>
          .
        </p>
      </section>
    );
  }

  // ── Live Mode Gate C Unlocked ────────────────────────────────────────────
  if (isLiveUnlocked) {
    if (artifactQuery.isLoading) {
      return (
        <LedgerTableSkeleton
          rows={5}
          label="Loading persisted validation artifact"
        />
      );
    }

    const report = livePreflightReport;
    const isStale = liveFreshness?.validationReportStatus === "stale";
    const blockerCount = report?.blockers.length ?? 0;
    const warningCount = report?.warnings.length ?? 0;
    const isGo = Boolean(report?.ok && !isStale);

    return (
      <div className="space-y-4" data-testid="live-gate-c-readiness">
        {isStale && (
          <div
            role="alert"
            data-testid="live-preflight-stale-banner"
            className="flex flex-wrap items-center justify-between gap-3 rounded-[var(--r-card)] border border-[var(--border-subtle)] border-l-[3px] border-l-[var(--sem-joint-bar)] bg-[var(--bg-elevated)] p-4 text-[12.5px] text-[var(--ink-secondary)]"
          >
            <div className="flex items-start gap-2.5">
              <WarningCircle
                size={18}
                className="mt-0.5 shrink-0 text-[var(--sem-joint-bar)]"
                aria-hidden="true"
              />
              <div>
                <div className="font-semibold text-[var(--ink-primary)]">
                  Persisted validation artifact marked stale after correction or policy save
                </div>
                <p className="mt-0.5">
                  Re-run server preflight validation to bind a current report to the active revision and PolicySnapshot.
                </p>
              </div>
            </div>
            <Button
              variant="secondary"
              size="sm"
              disabled={runPreflightMutation.isPending}
              onClick={() => runPreflightMutation.mutate()}
            >
              <ArrowsClockwise size={14} aria-hidden="true" />
              <span>Re-run Server Preflight</span>
            </Button>
          </div>
        )}

        <section className="ledger-card flex flex-wrap items-center justify-between gap-4 p-5">
          <div className="space-y-1">
            <div className="flex flex-wrap items-center gap-2">
              <Badge tone={!report ? "neutral" : isGo ? "lab" : "conflict"} mono>
                {!report
                  ? "NOT VALIDATED"
                  : isGo
                    ? "READY TO SOLVE"
                    : `${blockerCount} BLOCKER(S)`}
              </Badge>
              {report && (
                <Badge tone={warningCount > 0 ? "joint" : "neutral"} mono>
                  {warningCount} Advisory
                </Badge>
              )}
              {report && (
                <Badge tone="neutral" mono>
                  D5 Break Cross:{" "}
                  {report.allow_sessional_across_break ? "Enabled" : "Disabled"}
                </Badge>
              )}
            </div>
            <h2 className="text-[16px] font-semibold text-[var(--ink-primary)]">
              Server-Authoritative Gate C Preflight Validation
            </h2>
            <p className="text-[12.5px] text-[var(--ink-secondary)]">
              Evaluates R1–R15 rules, R5 guest windows, R7 off-days, R10/R11 lab slots, and CD1 distribution completeness on FastAPI.
            </p>
          </div>

          <div className="flex flex-wrap items-center gap-2">
            <Button
              variant="primary"
              size="md"
              data-testid="run-server-preflight-btn"
              disabled={runPreflightMutation.isPending}
              onClick={() => runPreflightMutation.mutate()}
            >
              <ShieldCheck size={15} aria-hidden="true" />
              <span>
                {runPreflightMutation.isPending
                  ? "Validating..."
                  : "Run Server Preflight Validation"}
              </span>
            </Button>
            <Button
              variant="secondary"
              size="md"
              disabled={!gateD?.unlocked || !isGo}
              title={gateD?.reason ?? "Gate D solver pipeline locked in Stage 5A."}
              onClick={() => onJumpToStage("generate")}
            >
              <span>Proceed to Revision Solve (Gate D Locked)</span>
              <ArrowRight size={15} aria-hidden="true" />
            </Button>
          </div>
        </section>

        {report ? (
          <section className="ledger-card divide-y divide-[var(--border-subtle)] overflow-hidden">
            {report.checks.map((item) => {
              const isBlocker = item.status === "blocker";
              const isWarning = item.status === "warning";
              return (
                <div
                  key={item.id}
                  data-testid={`live-readiness-item-${item.id}`}
                  className="flex flex-wrap items-start justify-between gap-3 px-5 py-3.5"
                >
                  <div className="flex min-w-0 flex-1 items-start gap-3">
                    {isBlocker ? (
                      <WarningCircle
                        size={18}
                        className="mt-0.5 shrink-0 text-[var(--sem-conflict-bar)]"
                        aria-hidden="true"
                      />
                    ) : isWarning ? (
                      <WarningCircle
                        size={18}
                        className="mt-0.5 shrink-0 text-[var(--sem-joint-bar)]"
                        aria-hidden="true"
                      />
                    ) : (
                      <CheckCircle
                        size={18}
                        weight="fill"
                        className="mt-0.5 shrink-0 text-[var(--sem-lab-bar)]"
                        aria-hidden="true"
                      />
                    )}
                    <div className="min-w-0 space-y-1">
                      <div className="flex flex-wrap items-center gap-2">
                        <Badge tone="neutral" mono>
                          {item.rule_id}
                        </Badge>
                        <span className="font-mono-tabular text-[11px] font-semibold text-[var(--ink-muted)] uppercase">
                          {item.category}
                        </span>
                        {isBlocker ? (
                          <Badge tone="conflict" mono>
                            Blocker
                          </Badge>
                        ) : isWarning ? (
                          <Badge tone="joint" mono>
                            Advisory
                          </Badge>
                        ) : (
                          <span className="font-mono-tabular text-[11px] font-medium text-[var(--ink-muted)]">
                            Ready
                          </span>
                        )}
                      </div>
                      <div className="text-[13.5px] font-semibold text-[var(--ink-primary)]">
                        {item.title}
                      </div>
                      <p className="text-[12.5px] text-[var(--ink-secondary)]">
                        {item.description}
                      </p>
                      {item.affected_entities.length > 0 && (
                        <div className="flex flex-wrap gap-1.5 pt-0.5">
                          {item.affected_entities.map((ent) => (
                            <Badge key={ent} tone="neutral" mono>
                              {ent}
                            </Badge>
                          ))}
                        </div>
                      )}
                    </div>
                  </div>
                  <Button
                    variant="secondary"
                    size="sm"
                    onClick={() => onJumpToStage(item.target_stage, item.target_row)}
                  >
                    <span>
                      {item.target_row
                        ? `Inspect Row ${item.target_row}`
                        : "Inspect Stage"}
                    </span>
                    <ArrowRight size={13} aria-hidden="true" />
                  </Button>
                </div>
              );
            })}
          </section>
        ) : (
          <div className="ledger-card p-6 text-[13px] text-[var(--ink-secondary)]">
            No server validation report is persisted for this revision yet. Click{" "}
            <strong className="text-[var(--ink-primary)]">
              Run Server Preflight Validation
            </strong>{" "}
            above to evaluate live catalogs and save a <code className="font-mono-tabular rounded bg-[var(--bg-surface)] px-1 py-0.5 text-[12px] text-[var(--ink-primary)]">validation_report</code> artifact.
          </div>
        )}
      </div>
    );
  }

  // ── Design Preview Mode (existing unchanged local simulation) ────────────
  const criticalOpen = previewReadinessItems.filter(
    (i) => i.severity === "critical" && !i.isResolved,
  );
  const warningsOpen = previewReadinessItems.filter(
    (i) => i.severity === "warning" && !i.isResolved,
  );
  const isStale = previewArtifactFreshness.validationReportStatus === "stale";
  const isGoForSolve = criticalOpen.length === 0 && !isStale;

  return (
    <div className="space-y-4">
      {isStale && (
        <div
          role="alert"
          data-testid="preflight-stale-artifacts-banner"
          className="flex flex-wrap items-center justify-between gap-3 rounded-[var(--r-card)] border border-[var(--border-subtle)] border-l-[3px] border-l-[var(--sem-joint-bar)] bg-[var(--bg-elevated)] p-4 text-[12.5px] text-[var(--ink-secondary)]"
        >
          <div className="flex items-start gap-2.5">
            <WarningCircle
              size={18}
              className="mt-0.5 shrink-0 text-[var(--sem-joint-bar)]"
              aria-hidden="true"
            />
            <div>
              <div className="font-semibold text-[var(--ink-primary)]">
                Validation report marked stale after distribution/policy edits
              </div>
              <p className="mt-0.5">
                Re-run preflight verification so checks bind to the updated
                revision overlay and R1–R16 configuration.
              </p>
            </div>
          </div>
          <Button
            variant="secondary"
            size="sm"
            onClick={revalidatePreviewArtifacts}
          >
            <ArrowsClockwise size={14} aria-hidden="true" />
            <span>Re-run Preflight Validation</span>
          </Button>
        </div>
      )}

      {/* Overall Go/No-Go Header */}
      <section
        data-testid="preflight-status-card"
        className="ledger-card flex flex-wrap items-center justify-between gap-4 p-5"
      >
        <div className="space-y-1">
          <div className="flex items-center gap-2">
            <Badge tone={isGoForSolve ? "lab" : "conflict"} mono>
              {isGoForSolve ? "READY TO SOLVE" : `${criticalOpen.length} BLOCKER(S)`}
            </Badge>
            <Badge tone={warningsOpen.length > 0 ? "joint" : "neutral"} mono>
              {warningsOpen.length} Advisory
            </Badge>
          </div>
          <h2 className="text-[16px] font-semibold text-[var(--ink-primary)]">
            {isGoForSolve
              ? "All preflight readiness checks satisfied"
              : "Resolve critical distribution blockers before running CP-SAT"}
          </h2>
          <p className="text-[12.5px] text-[var(--ink-secondary)]">
            Verifies accepted revision rows, instructor completeness, R7
            off-days, R10/R11 lab windows, and R14 room pool capacity.
          </p>
        </div>

        <Button
          variant="primary"
          size="md"
          disabled={!isGoForSolve}
          onClick={() => onJumpToStage("generate")}
        >
          <span>Proceed to Revision Solve</span>
          <ArrowRight size={15} aria-hidden="true" />
        </Button>
      </section>

      {/* Checkpoints Ledger */}
      <section className="ledger-card divide-y divide-[var(--border-subtle)] overflow-hidden">
        {previewReadinessItems.map((item) => {
          const isBlocker = item.severity === "critical" && !item.isResolved;
          const isWarning = item.severity === "warning" && !item.isResolved;
          return (
            <div
              key={item.id}
              data-testid={`readiness-item-${item.id}`}
              className="flex flex-wrap items-start justify-between gap-3 px-5 py-3.5"
            >
              <div className="flex min-w-0 flex-1 items-start gap-3">
                {isBlocker ? (
                  <WarningCircle
                    size={18}
                    className="mt-0.5 shrink-0 text-[var(--sem-conflict-bar)]"
                    aria-hidden="true"
                  />
                ) : isWarning ? (
                  <WarningCircle
                    size={18}
                    className="mt-0.5 shrink-0 text-[var(--sem-joint-bar)]"
                    aria-hidden="true"
                  />
                ) : (
                  <CheckCircle
                    size={18}
                    weight="fill"
                    className="mt-0.5 shrink-0 text-[var(--sem-lab-bar)]"
                    aria-hidden="true"
                  />
                )}

                <div className="min-w-0 space-y-1">
                  <div className="flex flex-wrap items-center gap-2">
                    <span className="font-mono-tabular text-[11px] font-semibold text-[var(--ink-muted)] uppercase">
                      {item.category}
                    </span>
                    {isBlocker ? (
                      <Badge tone="conflict" mono>
                        Blocker
                      </Badge>
                    ) : isWarning ? (
                      <Badge tone="joint" mono>
                        Advisory
                      </Badge>
                    ) : (
                      <span className="font-mono-tabular text-[11px] font-medium text-[var(--ink-muted)]">
                        Ready
                      </span>
                    )}
                  </div>
                  <div className="text-[13.5px] font-semibold text-[var(--ink-primary)]">
                    {item.isResolved &&
                    item.id === "chk-teacher-pending" &&
                    item.title.startsWith("Unassigned")
                      ? "Lab Instructor Assigned on Row 19 (CSE-2202)"
                      : item.title}
                  </div>
                  <p className="text-[12.5px] text-[var(--ink-secondary)]">
                    {item.description}
                  </p>
                  <div className="flex flex-wrap gap-1.5 pt-0.5">
                    {item.affectedEntities.map((ent) => (
                      <Badge key={ent} tone="neutral" mono>
                        {ent}
                      </Badge>
                    ))}
                  </div>
                </div>
              </div>

              <Button
                variant="secondary"
                size="sm"
                onClick={() => onJumpToStage(item.targetStage, item.targetRow)}
              >
                <span>
                  {item.targetRow
                    ? `Inspect Row ${item.targetRow}`
                    : "Inspect Stage"}
                </span>
                <ArrowRight size={13} aria-hidden="true" />
              </Button>
            </div>
          );
        })}
      </section>
    </div>
  );
}
