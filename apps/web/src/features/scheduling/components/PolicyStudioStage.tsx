import {
  ArrowCounterClockwise,
  ArrowRight,
  CheckCircle,
  FloppyDisk,
  LockSimple,
  ShieldCheck,
  SlidersHorizontal,
} from "@phosphor-icons/react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useEffect, useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { toast } from "sonner";
import { LedgerTableSkeleton } from "@/components/ui/AsyncStates";
import { Badge } from "@/components/ui/Badge";
import { Button } from "@/components/ui/Button";
import { Switch } from "@/components/ui/Switch";
import {
  CONSECUTIVE_WEEKEND_PAIRS,
  fetchSectionPolicies,
} from "@/features/admin/services/batchesService";
import { fetchCatalogCourses } from "@/features/admin/services/coursesService";
import {
  DEFAULT_POLICY_SNAPSHOT_FORM,
  readActivePolicySnapshot,
  savePolicySnapshot,
  type PolicySnapshotRecord,
  type SavePolicySnapshotInput,
} from "@/features/scheduling/services/policySnapshotService";
import { useSchedulingWorkbenchStore } from "@/features/scheduling/store/schedulingWorkbenchStore";
import type {
  GateStatusInfo,
  PolicyConfigItem,
  PolicyPillarId,
  RevisionContext,
  WorkbenchMode,
  WorkbenchStageId,
} from "@/features/scheduling/types";
import { cn } from "@/lib/utils";

const PILLARS: readonly {
  id: PolicyPillarId;
  title: string;
  subtitle: string;
}[] = [
  {
    id: "calendar",
    title: "1. Term Grid & Section Calendar (R1–R3, R15)",
    subtitle: "6- vs 7-slot daily grid, 7-day staggered weekends, and gap bounds.",
  },
  {
    id: "faculty",
    title: "2. Faculty Workload, Categories & Compactness (R4–R9)",
    subtitle: "Permanent off-day bounds, adjunct scaling, and blackout windows.",
  },
  {
    id: "facilities",
    title: "3. Shared Labs & Dynamic Classroom Pools (R10, R11, R14)",
    subtitle: "EEE-shared ECL windows, Physics exclusivity, and capacity matching.",
  },
  {
    id: "distribution",
    title: "4. Credit-Based Course Distribution Rules (R12, R13)",
    subtitle: "Sessional break boundaries and 3-credit non-adjacent day spacing.",
  },
  {
    id: "governance",
    title: "5. UI Governance & Impact Warnings (R16)",
    subtitle: "Revision hash snapshot integrity and impact guardrails.",
  },
];

function hasActiveOverride(item: PolicyConfigItem): boolean {
  const ov = item.overrideValue.trim();
  if (!ov) return false;
  if (ov.toLowerCase().startsWith("none")) return false;
  return ov !== item.defaultValue.trim();
}

function toDraftFromSnapshot(
  snap: PolicySnapshotRecord | null,
  revision: RevisionContext | null,
): SavePolicySnapshotInput {
  if (!snap) {
    return {
      ...DEFAULT_POLICY_SNAPSHOT_FORM,
      revisionId: revision?.revisionId ?? null,
      scopeId: revision?.scopeId || null,
      policyPayload: {
        ...DEFAULT_POLICY_SNAPSHOT_FORM.policyPayload,
        adjunct_day_bands: {
          ...DEFAULT_POLICY_SNAPSHOT_FORM.policyPayload.adjunct_day_bands,
        },
      },
    };
  }
  return {
    revisionId: revision?.revisionId ?? snap.revision_id ?? null,
    scopeId: revision?.scopeId || snap.scheduling_scope_id || null,
    label: snap.label,
    defaultSectionWeekend: [...snap.default_section_weekend],
    batchMaxOffDaySpread: snap.batch_max_off_day_spread,
    maxSectionInternalGap: snap.max_section_internal_gap,
    allowSessionalAcrossBreak: snap.allow_sessional_across_break,
    physicsLabCourseCodes: [...snap.physics_lab_course_codes],
    policyPayload: structuredClone(snap.policy_payload),
  };
}

function countLiveOverrides(draft: SavePolicySnapshotInput): number {
  const base = DEFAULT_POLICY_SNAPSHOT_FORM;
  let count = 0;
  if (
    draft.defaultSectionWeekend.join("|") !==
    base.defaultSectionWeekend.join("|")
  ) {
    count += 1;
  }
  if (draft.batchMaxOffDaySpread !== base.batchMaxOffDaySpread) count += 1;
  if (draft.maxSectionInternalGap !== base.maxSectionInternalGap) count += 1;
  if (draft.allowSessionalAcrossBreak !== base.allowSessionalAcrossBreak) {
    count += 1;
  }
  if (draft.physicsLabCourseCodes.length > 0) count += 1;
  if (draft.policyPayload.daily_slot_count !== base.policyPayload.daily_slot_count) {
    count += 1;
  }
  if (draft.policyPayload.allow_online_slot !== base.policyPayload.allow_online_slot) {
    count += 1;
  }
  if (draft.policyPayload.friday_no_p4 !== base.policyPayload.friday_no_p4) {
    count += 1;
  }
  if (
    draft.policyPayload.auto_resolve_undeclared_off_days !==
    base.policyPayload.auto_resolve_undeclared_off_days
  ) {
    count += 1;
  }
  if (
    draft.policyPayload.faculty_preference_weight !==
    base.policyPayload.faculty_preference_weight
  ) {
    count += 1;
  }
  return count;
}

export function PolicyStudioStage({
  mode,
  gateC,
  revision = null,
  onJumpToStage,
}: {
  mode: WorkbenchMode;
  gateC: GateStatusInfo;
  revision?: RevisionContext | null;
  onJumpToStage?: (stage: WorkbenchStageId, row?: number) => void;
}) {
  const queryClient = useQueryClient();
  const {
    previewPolicyItems,
    applyPreviewPolicyOverride,
    resetPreviewPolicyOverride,
    setLivePolicySnapshot,
    markLiveValidationStale,
  } = useSchedulingWorkbenchStore();

  const isLiveUnlocked = mode === "live" && gateC.unlocked;

  const snapshotQuery = useQuery({
    queryKey: [
      "scheduling-active-policy-snapshot",
      revision?.revisionId ?? null,
      revision?.scopeId ?? null,
    ],
    enabled: isLiveUnlocked,
    queryFn: () =>
      readActivePolicySnapshot({
        revisionId: revision?.revisionId ?? null,
        scopeId: revision?.scopeId || null,
      }),
    retry: false,
  });

  const sectionsQuery = useQuery({
    queryKey: ["admin-section-policies", false],
    enabled: isLiveUnlocked,
    queryFn: () => fetchSectionPolicies(false),
    retry: false,
  });

  const coursesQuery = useQuery({
    queryKey: ["admin-catalog-courses", false],
    enabled: isLiveUnlocked,
    queryFn: () => fetchCatalogCourses(false),
    retry: false,
  });

  const [draft, setDraft] = useState<SavePolicySnapshotInput>(() =>
    toDraftFromSnapshot(null, revision),
  );
  const [physicsInput, setPhysicsInput] = useState("");
  const [isDirty, setIsDirty] = useState(false);

  useEffect(() => {
    if (!isLiveUnlocked) return;
    if (snapshotQuery.data !== undefined) {
      setLivePolicySnapshot(snapshotQuery.data);
      setDraft(toDraftFromSnapshot(snapshotQuery.data, revision));
      setIsDirty(false);
    }
  }, [isLiveUnlocked, revision, setLivePolicySnapshot, snapshotQuery.data]);

  const saveMutation = useMutation({
    mutationFn: (input: SavePolicySnapshotInput) => savePolicySnapshot(input),
    onSuccess: (saved) => {
      setLivePolicySnapshot(saved);
      markLiveValidationStale();
      setDraft(toDraftFromSnapshot(saved, revision));
      setIsDirty(false);
      void queryClient.invalidateQueries({
        queryKey: ["scheduling-active-policy-snapshot"],
      });
      toast.success(`Saved PolicySnapshot v${saved.version}`, {
        description: `SHA-256 ${saved.policy_hash.slice(0, 12)}… · validation artifact marked stale.`,
      });
    },
    onError: (err) => {
      toast.error("Could not save policy snapshot", {
        description: err instanceof Error ? err.message : "RPC save_policy_snapshot failed.",
      });
    },
  });

  const liveOverrideCount = useMemo(() => countLiveOverrides(draft), [draft]);
  const sectionOverrideCount = useMemo(
    () =>
      (sectionsQuery.data?.sections ?? []).filter((s) =>
        Boolean(s.weekend_override_days),
      ).length,
    [sectionsQuery.data?.sections],
  );
  const labCourseSuggestions = useMemo(
    () =>
      (coursesQuery.data?.courses ?? [])
        .filter((c) => c.class_type === "lab" && c.is_active)
        .map((c) => c.code),
    [coursesQuery.data?.courses],
  );

  if (mode === "live" && !gateC.unlocked) {
    return (
      <section
        data-testid="live-gate-c-policy-locked"
        className="ledger-card flex max-w-[760px] flex-col gap-3 p-6"
      >
        <div className="flex flex-wrap items-center justify-between gap-2">
          <span className="font-mono-tabular text-[12px] font-medium text-[var(--accent-brand)]">
            Stage 2 · Gate C Required
          </span>
          <Badge tone="joint" mono>
            <LockSimple size={12} aria-hidden="true" />
            <span>Locked · Gate C</span>
          </Badge>
        </div>
        <h2 className="text-[17px] font-semibold text-[var(--ink-primary)]">
          Revision-Bound Policy Studio Locked in Live Mode
        </h2>
        <p className="text-[13.5px] leading-[1.55] text-[var(--ink-secondary)]">
          {gateC.reason} Track 1 baseline settings remain active on{" "}
          <span className="font-semibold text-[var(--ink-primary)]">
            Timetable Settings
          </span>
          . Switch to Design Preview above to inspect the R1–R16 3-step policy
          override studio.
        </p>
      </section>
    );
  }

  // ── Live Mode Gate C Unlocked ────────────────────────────────────────────
  if (isLiveUnlocked) {
    if (snapshotQuery.isLoading) {
      return (
        <LedgerTableSkeleton
          rows={5}
          label="Loading active PolicySnapshot from Supabase"
        />
      );
    }

    const activeSnap = snapshotQuery.data;
    const weekendPairKey = draft.defaultSectionWeekend.join("|");

    const addPhysicsCode = (raw: string) => {
      const cleaned = raw.trim().toUpperCase();
      if (!cleaned) return;
      if (!draft.physicsLabCourseCodes.includes(cleaned)) {
        setDraft((prev) => ({
          ...prev,
          physicsLabCourseCodes: [...prev.physicsLabCourseCodes, cleaned].sort(),
        }));
        setIsDirty(true);
      }
      setPhysicsInput("");
    };

    return (
      <div className="space-y-4" data-testid="live-gate-c-policy-studio">
        {/* Provenance & Override Bar */}
        <div
          className={cn(
            "ledger-card flex flex-wrap items-center justify-between gap-3 p-4",
            liveOverrideCount > 0 && "border-l-[3px] border-l-[var(--sem-joint-bar)]",
          )}
        >
          <div className="flex items-start gap-2.5">
            <ShieldCheck
              size={18}
              className="mt-0.5 shrink-0 text-[var(--accent-brand)]"
              aria-hidden="true"
            />
            <div>
              <div className="flex flex-wrap items-center gap-2">
                <span className="text-[14px] font-semibold text-[var(--ink-primary)]">
                  Persisted Committee PolicySnapshot (R1–R16)
                </span>
                {activeSnap ? (
                  <Badge tone="neutral" mono data-testid="policy-snapshot-provenance">
                    v{activeSnap.version} · {activeSnap.policy_hash.slice(0, 10)}
                  </Badge>
                ) : (
                  <Badge tone="joint" mono>
                    Unsaved Baseline
                  </Badge>
                )}
              </div>
              <p className="mt-0.5 text-[12.5px] text-[var(--ink-secondary)]">
                {revision
                  ? `Bound to Revision #${revision.revisionNumber} (v${revision.revisionVersion}). Saving a snapshot automatically marks prior validation reports stale.`
                  : "Global committee baseline. Select a revision in Stage 1 to bind validation artifacts."}
              </p>
            </div>
          </div>

          <div className="flex flex-wrap items-center gap-2">
            <Badge tone={liveOverrideCount > 0 ? "joint" : "neutral"} mono>
              {liveOverrideCount} Non-Default Override(s)
            </Badge>
            <Button
              variant="secondary"
              size="sm"
              data-testid="live-reset-policy-baseline-btn"
              onClick={() => {
                setDraft(toDraftFromSnapshot(null, revision));
                setIsDirty(true);
              }}
            >
              <ArrowCounterClockwise size={13} aria-hidden="true" />
              <span>Reset to Committee Baseline</span>
            </Button>
            <Button
              variant="primary"
              size="sm"
              data-testid="save-policy-snapshot-btn"
              disabled={saveMutation.isPending}
              onClick={() => saveMutation.mutate(draft)}
            >
              <FloppyDisk size={14} aria-hidden="true" />
              <span>
                {saveMutation.isPending
                  ? "Saving..."
                  : isDirty || !activeSnap
                    ? "Save Policy Snapshot"
                    : "Save New Version"}
              </span>
            </Button>
          </div>
        </div>

        {/* Pillar 1: R15, R1, R2, R3 */}
        <section className="ledger-card space-y-4 p-5">
          <div className="flex flex-wrap items-center justify-between gap-2 border-b border-[var(--border-subtle)] pb-3">
            <div>
              <h2 className="text-[14.5px] font-semibold text-[var(--ink-primary)]">
                1. Term Grid &amp; Section Calendar (R1–R3, R15)
              </h2>
              <p className="text-[12px] text-[var(--ink-secondary)]">
                Configure 6- vs 7-slot daily grid, default consecutive 2-day weekend, and batch parity bounds.
              </p>
            </div>
            <Link
              to="/admin/timetable/batches"
              className="font-mono-tabular inline-flex items-center gap-1 text-[12px] font-semibold text-[var(--accent-brand)] no-underline hover:underline"
            >
              <span>{sectionOverrideCount} Section Override(s)</span>
              <ArrowRight size={12} aria-hidden="true" />
            </Link>
          </div>

          <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
            <div className="space-y-1.5">
              <span className="text-[12.5px] font-semibold text-[var(--ink-primary)]">
                R15 Daily Regular Slots
              </span>
              <div className="flex flex-wrap items-center gap-2">
                <div
                  role="group"
                  aria-label="R15 daily slot count"
                  className="inline-flex h-[34px] rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-surface)] p-0.5"
                >
                  {([6, 7] as const).map((slots) => {
                    const active = draft.policyPayload.daily_slot_count === slots;
                    return (
                      <button
                        key={slots}
                        type="button"
                        aria-pressed={active}
                        onClick={() => {
                          setDraft((p) => ({
                            ...p,
                            policyPayload: {
                              ...p.policyPayload,
                              daily_slot_count: slots,
                            },
                          }));
                          setIsDirty(true);
                        }}
                        className={cn(
                          "font-mono-tabular rounded-[5px] px-3 text-[12px] transition-colors",
                          active
                            ? "bg-[var(--bg-raised)] font-semibold text-[var(--ink-primary)]"
                            : "text-[var(--ink-secondary)] hover:text-[var(--ink-primary)]",
                        )}
                      >
                        {slots}-Slot Grid
                      </button>
                    );
                  })}
                </div>

                <label
                  className={cn(
                    "inline-flex h-[34px] cursor-pointer items-center gap-2 rounded-[var(--r-control)] border px-3 text-[12px]",
                    draft.policyPayload.allow_online_slot
                      ? "border-[var(--sem-joint-border)] bg-[var(--sem-joint-bg)] text-[var(--sem-joint-ink)]"
                      : "border-[var(--border-subtle)] bg-[var(--bg-surface)] text-[var(--ink-muted)]",
                  )}
                >
                  <input
                    type="checkbox"
                    checked={draft.policyPayload.allow_online_slot}
                    onChange={(e) => {
                      setDraft((p) => ({
                        ...p,
                        policyPayload: {
                          ...p.policyPayload,
                          allow_online_slot: e.target.checked,
                        },
                      }));
                      setIsDirty(true);
                    }}
                    className="h-3.5 w-3.5 accent-[var(--accent-brand)]"
                  />
                  <span>Online Slot (P8)</span>
                </label>
              </div>
            </div>

            <div className="space-y-1.5">
              <label
                htmlFor="live-default-weekend"
                className="text-[12.5px] font-semibold text-[var(--ink-primary)]"
              >
                R1 Default Consecutive Section Weekend
              </label>
              <select
                id="live-default-weekend"
                value={weekendPairKey}
                onChange={(e) => {
                  const [d1, d2] = e.target.value.split("|");
                  if (d1 && d2) {
                    setDraft((p) => ({
                      ...p,
                      defaultSectionWeekend: [d1, d2],
                    }));
                    setIsDirty(true);
                  }
                }}
                className="font-mono-tabular h-[36px] w-full rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-2.5 text-[12.5px]"
              >
                {CONSECUTIVE_WEEKEND_PAIRS.map((pair) => {
                  const key = `${pair[0]}|${pair[1]}`;
                  return (
                    <option key={key} value={key}>
                      {pair[0]} + {pair[1]}
                    </option>
                  );
                })}
              </select>
            </div>

            <div className="space-y-1.5">
              <label
                htmlFor="live-r2-spread"
                className="text-[12.5px] font-semibold text-[var(--ink-primary)]"
              >
                R2 Batch Max Off-Day Spread (0–3)
              </label>
              <input
                id="live-r2-spread"
                type="number"
                min={0}
                max={3}
                value={draft.batchMaxOffDaySpread}
                onChange={(e) => {
                  const val = Math.max(0, Math.min(3, Number(e.target.value) || 0));
                  setDraft((p) => ({ ...p, batchMaxOffDaySpread: val }));
                  setIsDirty(true);
                }}
                className="font-mono-tabular h-[36px] w-28 rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-3 text-[13px]"
              />
            </div>

            <div className="space-y-1.5">
              <label
                htmlFor="live-r3-gap"
                className="text-[12.5px] font-semibold text-[var(--ink-primary)]"
              >
                R3 Max Consecutive Section Gap (0–3 slots)
              </label>
              <input
                id="live-r3-gap"
                type="number"
                min={0}
                max={3}
                value={draft.maxSectionInternalGap}
                onChange={(e) => {
                  const val = Math.max(0, Math.min(3, Number(e.target.value) || 0));
                  setDraft((p) => ({ ...p, maxSectionInternalGap: val }));
                  setIsDirty(true);
                }}
                className="font-mono-tabular h-[36px] w-28 rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-3 text-[13px]"
              />
            </div>
          </div>
        </section>

        {/* Pillar 2 & 3: Faculty Weights, R11 Physics Lab Codes & R12/D5 Break Crossing */}
        <section className="ledger-card space-y-4 p-5">
          <div className="border-b border-[var(--border-subtle)] pb-3">
            <h2 className="text-[14.5px] font-semibold text-[var(--ink-primary)]">
              2. Faculty Weights, R11 Physics Lab &amp; R12/D5 Sessional Break Permission
            </h2>
            <p className="text-[12px] text-[var(--ink-secondary)]">
              D5 requires explicit admin authorization for 2-credit sessionals to span the midday break (defaults to disabled).
            </p>
          </div>

          <div
            className={cn(
              "flex flex-wrap items-center justify-between gap-3 rounded-[var(--r-control)] border p-3.5 transition-colors",
              draft.policyPayload.auto_resolve_undeclared_off_days
                ? "border-[var(--sem-lab-border)] bg-[var(--sem-lab-bg)]/35"
                : "border-[var(--sem-joint-border)] bg-[var(--sem-joint-bg)]/35",
            )}
          >
            <div>
              <div className="flex items-center gap-2">
                <Badge
                  tone={
                    draft.policyPayload.auto_resolve_undeclared_off_days
                      ? "lab"
                      : "joint"
                  }
                  mono
                >
                  Hybrid R7 / R6
                </Badge>
                <span className="text-[13px] font-semibold text-[var(--ink-primary)]">
                  Auto-Resolve Undeclared Faculty Off-Days (Hybrid R7/R6)
                </span>
              </div>
              <p className="mt-0.5 text-[12px] text-[var(--ink-secondary)]">
                {draft.policyPayload.auto_resolve_undeclared_off_days
                  ? "Hybrid Default (ON): Permanent faculty with 0 or 1 declared off-days have remaining off-day(s) resolved by CP-SAT to 2; explicit declarations & unauthorized 3-day limits stay enforced."
                  : "Strict Explicit Mode (OFF): Every assigned permanent faculty must pre-declare 2 (or authorized 3) off-days before solving."}
              </p>
            </div>
            <Switch
              id="live-auto-resolve-off-days"
              data-testid="auto-resolve-off-days-switch"
              checked={draft.policyPayload.auto_resolve_undeclared_off_days}
              onCheckedChange={(checked) => {
                setDraft((p) => ({
                  ...p,
                  policyPayload: {
                    ...p.policyPayload,
                    auto_resolve_undeclared_off_days: checked,
                  },
                }));
                setIsDirty(true);
              }}
            />
          </div>

          <div
            className={cn(
              "flex flex-wrap items-center justify-between gap-3 rounded-[var(--r-control)] border p-3.5 transition-colors",
              draft.allowSessionalAcrossBreak
                ? "border-[var(--sem-joint-border)] bg-[var(--sem-joint-bg)]/35"
                : "border-[var(--border-subtle)] bg-[var(--bg-surface)]",
            )}
          >
            <div>
              <div className="flex items-center gap-2">
                <Badge
                  tone={draft.allowSessionalAcrossBreak ? "joint" : "neutral"}
                  mono
                >
                  R12 / D5
                </Badge>
                <span className="text-[13px] font-semibold text-[var(--ink-primary)]">
                  Allow 2-Credit Sessional Labs Across Midday Break
                </span>
              </div>
              <p className="mt-0.5 text-[12px] text-[var(--ink-secondary)]">
                {draft.allowSessionalAcrossBreak
                  ? "Explicitly enabled: consecutive 2-credit lab pairs may span the break."
                  : "Disabled (Committee Default): sessional pairs never span the midday break."}
              </p>
            </div>
            <Switch
              id="live-allow-sessional-across-break"
              data-testid="allow-sessional-across-break-switch"
              checked={draft.allowSessionalAcrossBreak}
              onCheckedChange={(checked) => {
                setDraft((p) => ({ ...p, allowSessionalAcrossBreak: checked }));
                setIsDirty(true);
              }}
            />
          </div>

          <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
            <div className="space-y-2">
              <label
                htmlFor="live-physics-lab-input"
                className="text-[12.5px] font-semibold text-[var(--ink-primary)]"
              >
                R11 Bound Physics Lab Course Codes
              </label>
              <div className="flex gap-2">
                <input
                  id="live-physics-lab-input"
                  list="live-physics-lab-suggestions"
                  value={physicsInput}
                  onChange={(e) => setPhysicsInput(e.target.value)}
                  onKeyDown={(e) => {
                    if (e.key === "Enter") {
                      e.preventDefault();
                      addPhysicsCode(physicsInput);
                    }
                  }}
                  placeholder="e.g. PHY-1104"
                  className="font-mono-tabular h-[36px] flex-1 rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-3 text-[12.5px] uppercase"
                />
                <datalist id="live-physics-lab-suggestions">
                  {labCourseSuggestions.map((code) => (
                    <option key={code} value={code} />
                  ))}
                </datalist>
                <Button
                  type="button"
                  variant="secondary"
                  size="sm"
                  onClick={() => addPhysicsCode(physicsInput)}
                >
                  Add
                </Button>
              </div>
              {draft.physicsLabCourseCodes.length > 0 && (
                <div className="flex flex-wrap gap-1.5">
                  {draft.physicsLabCourseCodes.map((code) => (
                    <span
                      key={code}
                      className="inline-flex items-center gap-1 rounded-[5px] border border-[var(--border-subtle)] bg-[var(--bg-surface)] px-2 py-0.5 font-mono-tabular text-[12px]"
                    >
                      <span>{code}</span>
                      <button
                        type="button"
                        aria-label={`Remove ${code}`}
                        onClick={() => {
                          setDraft((p) => ({
                            ...p,
                            physicsLabCourseCodes: p.physicsLabCourseCodes.filter(
                              (c) => c !== code,
                            ),
                          }));
                          setIsDirty(true);
                        }}
                        className="text-[var(--ink-muted)] hover:text-[var(--sem-conflict-ink)]"
                      >
                        ×
                      </button>
                    </span>
                  ))}
                </div>
              )}
            </div>

            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-1.5">
                <label
                  htmlFor="live-r8-pref-weight"
                  className="text-[12.5px] font-semibold text-[var(--ink-primary)]"
                >
                  R8 Faculty Preference Weight
                </label>
                <input
                  id="live-r8-pref-weight"
                  type="number"
                  min={0}
                  max={200}
                  value={draft.policyPayload.faculty_preference_weight}
                  onChange={(e) => {
                    const v = Math.max(0, Math.min(200, Number(e.target.value) || 0));
                    setDraft((p) => ({
                      ...p,
                      policyPayload: {
                        ...p.policyPayload,
                        faculty_preference_weight: v,
                      },
                    }));
                    setIsDirty(true);
                  }}
                  className="font-mono-tabular h-[36px] w-full rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-3 text-[13px]"
                />
              </div>

              <div className="space-y-1.5">
                <label
                  htmlFor="live-r9-max-gap"
                  className="text-[12.5px] font-semibold text-[var(--ink-primary)]"
                >
                  R9 SUST Max Gap (slots)
                </label>
                <input
                  id="live-r9-max-gap"
                  type="number"
                  min={0}
                  max={4}
                  value={draft.policyPayload.sust_adjunct_max_gap}
                  onChange={(e) => {
                    const v = Math.max(0, Math.min(4, Number(e.target.value) || 0));
                    setDraft((p) => ({
                      ...p,
                      policyPayload: {
                        ...p.policyPayload,
                        sust_adjunct_max_gap: v,
                      },
                    }));
                    setIsDirty(true);
                  }}
                  className="font-mono-tabular h-[36px] w-full rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-3 text-[13px]"
                />
              </div>
            </div>
          </div>

          {onJumpToStage && (
            <div className="flex justify-end border-t border-[var(--border-subtle)] pt-3">
              <Button
                variant="secondary"
                size="sm"
                onClick={() => onJumpToStage("readiness")}
              >
                <span>Proceed to Server Preflight Validation</span>
                <ArrowRight size={13} aria-hidden="true" />
              </Button>
            </div>
          )}
        </section>
      </div>
    );
  }

  // ── Design Preview Mode (existing unchanged local simulation) ────────────
  const r15Item = previewPolicyItems.find((p) => p.ruleId === "R15");
  const r15Slots =
    Number(r15Item?.typedPayload.slot_count ?? 7) === 6 ? 6 : 7;
  const r15Online = Boolean(r15Item?.typedPayload.allow_online_slot);
  const activeOverrideCount = previewPolicyItems.filter(hasActiveOverride).length;

  return (
    <div className="space-y-4">
      <div className="ledger-card flex flex-wrap items-center justify-between gap-3 p-4">
        <div className="flex items-start gap-2.5">
          <ShieldCheck
            size={18}
            className="mt-0.5 shrink-0 text-[var(--accent-brand)]"
            aria-hidden="true"
          />
          <div>
            <div className="text-[14px] font-semibold text-[var(--ink-primary)]">
              Committee Policy Studio (R1–R16 · 5 Pillars)
            </div>
            <p className="text-[12.5px] text-[var(--ink-secondary)]">
              Baseline rules remain quiet neutral until overridden. Any change
              marks the preflight report stale and requires revalidation.
            </p>
          </div>
        </div>
        <div className="flex items-center gap-2">
          <Badge tone={activeOverrideCount > 0 ? "joint" : "neutral"} mono>
            {activeOverrideCount} Active Overrides
          </Badge>
          {activeOverrideCount > 0 && (
            <Button
              variant="secondary"
              size="sm"
              data-testid="reset-all-policies-btn"
              onClick={() => resetPreviewPolicyOverride()}
            >
              <ArrowCounterClockwise size={13} aria-hidden="true" />
              <span>Reset All to Baseline</span>
            </Button>
          )}
        </div>
      </div>

      {/* Prominent Interactive R15 6/7-Slot Grid Editor */}
      {r15Item && (
        <section
          data-testid="r15-slot-grid-control"
          className="ledger-card space-y-3 p-5"
        >
          <div className="flex flex-wrap items-center justify-between gap-3">
            <div>
              <div className="flex items-center gap-2">
                <Badge tone="pine" mono>
                  R15
                </Badge>
                <h2 className="text-[15px] font-semibold text-[var(--ink-primary)]">
                  Daily Period Dimension &amp; Visual Break Strip
                </h2>
              </div>
              <p className="mt-1 text-[12.5px] text-[var(--ink-secondary)]">
                Switch between 6-slot and 7-slot regular daily on-campus grids.
              </p>
            </div>

            <div className="flex flex-wrap items-center gap-2">
              <div
                role="group"
                aria-label="R15 daily slot count"
                className="inline-flex h-[34px] rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] p-0.5"
              >
                {[6, 7].map((slots) => {
                  const active = r15Slots === slots;
                  return (
                    <button
                      key={slots}
                      type="button"
                      data-testid={`r15-select-${slots}`}
                      aria-pressed={active}
                      onClick={() =>
                        applyPreviewPolicyOverride({
                          ruleId: "R15",
                          overrideValue:
                            slots === 6 ? "6 daily slots (compact day)" : "None",
                          effectiveValue: `${slots} slots (Period 4 Midday Break)`,
                          typedPayload: {
                            ...r15Item.typedPayload,
                            slot_count: slots,
                          },
                        })
                      }
                      className={cn(
                        "font-mono-tabular h-[28px] rounded-[5px] border px-3 text-[12px] transition-colors",
                        active
                          ? "border-[var(--border-strong)] bg-[var(--bg-raised)] font-semibold text-[var(--ink-primary)]"
                          : "border-transparent text-[var(--ink-secondary)] hover:text-[var(--ink-primary)]",
                      )}
                    >
                      {slots}-Slot Grid
                    </button>
                  );
                })}
              </div>

              {/* Checkbox Off = Gray discipline */}
              <label
                className={cn(
                  "inline-flex h-[34px] cursor-pointer items-center gap-2 rounded-[var(--r-control)] border px-3 text-[12px] font-medium transition-colors",
                  r15Online
                    ? "border-[var(--sem-joint-border)] bg-[var(--sem-joint-bg)] text-[var(--sem-joint-ink)]"
                    : "border-[var(--border-subtle)] bg-[var(--bg-surface)] text-[var(--ink-muted)]",
                )}
              >
                <input
                  type="checkbox"
                  checked={r15Online}
                  onChange={(e) =>
                    applyPreviewPolicyOverride({
                      ruleId: "R15",
                      overrideValue: e.target.checked
                        ? `${r15Slots} daily + Online evening slot`
                        : r15Slots === 6
                          ? "6 daily slots (compact day)"
                          : "None",
                      effectiveValue: `${r15Slots} on-campus slots${e.target.checked ? " + Online P8" : ""}`,
                      typedPayload: {
                        ...r15Item.typedPayload,
                        allow_online_slot: e.target.checked,
                      },
                    })
                  }
                  className="h-3.5 w-3.5 accent-[var(--accent-brand)]"
                />
                <span>Enable Online Slot</span>
              </label>
            </div>
          </div>

          <div
            aria-label="R15 period strip preview"
            className="grid grid-cols-3 gap-1.5 sm:grid-cols-8"
          >
            {[1, 2, 3, 4, 5, 6, 7].map((idx) => {
              const hidden = r15Slots === 6 && idx === 7;
              const isBreak = idx === 4;
              return (
                <div
                  key={idx}
                  className={cn(
                    "font-mono-tabular rounded-[6px] border px-2.5 py-2 text-center text-[11.5px]",
                    hidden
                      ? "border-dashed border-[var(--border-subtle)] bg-[var(--bg-surface)] text-[var(--ink-muted)] opacity-55"
                      : isBreak
                        ? "border-[var(--sem-joint-border)] bg-[var(--sem-joint-bg)] font-semibold text-[var(--sem-joint-ink)]"
                        : "border-[var(--border-subtle)] bg-[var(--bg-surface)] text-[var(--ink-primary)]",
                  )}
                >
                  <div>P{idx}</div>
                  <div className="text-[10px] text-[var(--ink-muted)]">
                    {hidden ? "Omitted" : isBreak ? "Break/Jummah" : "On-Campus"}
                  </div>
                </div>
              );
            })}
            <div
              className={cn(
                "font-mono-tabular rounded-[6px] border px-2.5 py-2 text-center text-[11.5px]",
                r15Online
                  ? "border-[var(--sem-joint-border)] bg-[var(--sem-joint-bg)] font-semibold text-[var(--sem-joint-ink)]"
                  : "border-[var(--border-subtle)] bg-[var(--bg-surface)] text-[var(--ink-muted)]",
              )}
            >
              <div>P8</div>
              <div className="text-[10px]">
                {r15Online ? "Online Slot" : "Inactive"}
              </div>
            </div>
          </div>
        </section>
      )}

      {/* 5 Committee Pillars */}
      <div className="space-y-4">
        {PILLARS.map((pillar) => {
          const items = previewPolicyItems.filter((i) => i.pillar === pillar.id);
          return (
            <section
              key={pillar.id}
              aria-label={pillar.title}
              className="ledger-card overflow-hidden"
            >
              <div className="border-b border-[var(--border-subtle)] bg-[var(--bg-canvas)]/55 px-5 py-3">
                <h3 className="text-[14px] font-semibold text-[var(--ink-primary)]">
                  {pillar.title}
                </h3>
                <p className="text-[12px] text-[var(--ink-secondary)]">
                  {pillar.subtitle}
                </p>
              </div>
              <div className="divide-y divide-[var(--border-subtle)]">
                {items.map((item) => {
                  const overridden = hasActiveOverride(item);
                  return (
                    <div
                      key={item.ruleId}
                      data-testid={`policy-row-${item.ruleId.replace(/[^A-Za-z0-9]/g, "-")}`}
                      className={cn(
                        "flex flex-col gap-2 px-5 py-3.5 transition-colors",
                        overridden ? "bg-[var(--sem-joint-bg)]/35" : "bg-[var(--bg-elevated)]",
                      )}
                    >
                      <div className="flex flex-wrap items-center justify-between gap-2">
                        <div className="flex flex-wrap items-center gap-2">
                          <Badge tone={overridden ? "joint" : "neutral"} mono>
                            {item.ruleId}
                          </Badge>
                          <span className="text-[13.5px] font-semibold text-[var(--ink-primary)]">
                            {item.label}
                          </span>
                        </div>
                        <div className="flex items-center gap-2">
                          {overridden ? (
                            <Badge tone="joint" mono>
                              <SlidersHorizontal size={11} aria-hidden="true" />
                              <span>Override Active</span>
                            </Badge>
                          ) : (
                            <span className="font-mono-tabular inline-flex items-center gap-1 text-[11px] font-medium text-[var(--ink-muted)]">
                              <CheckCircle size={12} aria-hidden="true" />
                              <span>Baseline</span>
                            </span>
                          )}
                          {overridden && (
                            <button
                              type="button"
                              onClick={() => resetPreviewPolicyOverride(item.ruleId)}
                              className="inline-flex items-center gap-1 rounded px-2 py-0.5 text-[11px] font-medium text-[var(--ink-secondary)] hover:bg-[var(--surface-hover)] hover:text-[var(--ink-primary)]"
                            >
                              <ArrowCounterClockwise size={11} aria-hidden="true" />
                              <span>Reset</span>
                            </button>
                          )}
                        </div>
                      </div>

                      <p className="text-[12.5px] text-[var(--ink-secondary)]">
                        {item.description}
                      </p>

                      {/* 3-Step Policy Resolution Chain: Default -> Override -> Effective */}
                      <div className="grid grid-cols-1 gap-2 rounded-[var(--r-control)] border border-[var(--border-subtle)] bg-[var(--bg-surface)] px-3 py-2 text-[12px] sm:grid-cols-3">
                        <div>
                          <div className="text-[10.5px] text-[var(--ink-muted)] uppercase">
                            1. Committee Default
                          </div>
                          <div className="mt-0.5 text-[var(--ink-secondary)]">
                            {item.defaultValue}
                          </div>
                        </div>
                        <div>
                          <div className="text-[10.5px] text-[var(--ink-muted)] uppercase">
                            2. Revision Override
                          </div>
                          <div
                            className={cn(
                              "mt-0.5",
                              overridden
                                ? "font-semibold text-[var(--sem-joint-ink)]"
                                : "text-[var(--ink-muted)]",
                            )}
                          >
                            {item.overrideValue}
                          </div>
                        </div>
                        <div>
                          <div className="text-[10.5px] text-[var(--ink-muted)] uppercase">
                            3. Effective Policy
                          </div>
                          <div className="mt-0.5 font-medium text-[var(--ink-primary)]">
                            {item.effectiveValue}
                          </div>
                        </div>
                      </div>
                    </div>
                  );
                })}
              </div>
            </section>
          );
        })}
      </div>
    </div>
  );
}
