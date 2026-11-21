import {
  ArrowsClockwise,
  CheckCircle,
  Eye,
  GitBranch,
  LockSimple,
  MagnifyingGlass,
  PencilSimple,
  WarningCircle,
  X,
} from "@phosphor-icons/react";
import {
  createSortedRowModel,
  rowSortingFeature,
  sortFn_alphanumeric,
  sortFn_text,
  tableFeatures,
  useTable,
  type ColumnDef,
  type SortingState,
} from "@tanstack/react-table";
import { useVirtualizer } from "@tanstack/react-virtual";
import { AnimatePresence, motion, useReducedMotion } from "motion/react";
import { useEffect, useMemo, useRef, useState } from "react";
import { toast } from "sonner";
import {
  LedgerEmptyState,
  LedgerFilterEmpty,
} from "@/components/ui/AsyncStates";
import { Badge } from "@/components/ui/Badge";
import { Button } from "@/components/ui/Button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogTitle,
} from "@/components/ui/Dialog";
import {
  Tooltip,
  TooltipContent,
  TooltipTrigger,
} from "@/components/ui/Tooltip";
import { useHorizontalScrollCue } from "@/core/hooks/useHorizontalScrollCue";
import { useWorkspaceShortcuts } from "@/core/hooks/useWorkspaceShortcuts";
import {
  appendCourseDistributionCorrection,
  deriveRecordStatus,
  getEffectiveColumnValue,
  getOriginalColumnValue,
  hasFormulaCachedDiscrepancy,
  isStaleRevisionError,
} from "@/features/scheduling/services/courseDistributionService";
import { useSchedulingWorkbenchStore } from "@/features/scheduling/store/schedulingWorkbenchStore";
import type {
  DistributionColumn,
  DistributionRecordStatus,
  DistributionSourceRecord,
  GateStatusInfo,
  RevisionContext,
  WorkbenchMode,
} from "@/features/scheduling/types";
import { cn } from "@/lib/utils";

const DIST_FEATURES = tableFeatures({
  rowSortingFeature,
  sortedRowModel: createSortedRowModel(),
  sortFns: {
    alphanumeric: sortFn_alphanumeric,
    text: sortFn_text,
  },
});

type StatusFilter = "all" | DistributionRecordStatus;

const EDITABLE_COLUMN_OPTIONS: readonly {
  col: DistributionColumn;
  label: string;
}[] = [
  { col: "I", label: "Col I · Teacher" },
  { col: "G", label: "Col G · Conducting Dept" },
  { col: "H", label: "Col H · Enrollment" },
  { col: "J", label: "Col J · Total Classes" },
  { col: "K", label: "Col K · Duration (min)" },
  { col: "L", label: "Col L · Classes / Week" },
];

interface DistributionLedgerStageProps {
  mode: WorkbenchMode;
  gateA: GateStatusInfo;
  gateB: GateStatusInfo;
  revision: RevisionContext | null;
  records: readonly DistributionSourceRecord[];
  revisionsList: readonly RevisionContext[];
  selectedRevisionId: string | null;
  onSelectRevision: (id: string) => void;
  onReloadLiveRevision: () => Promise<void>;
  onSwitchToPreview: () => void;
  highlightRow?: number | null;
}

export function DistributionLedgerStage({
  mode,
  gateA,
  gateB,
  revision,
  records,
  revisionsList,
  selectedRevisionId,
  onSelectRevision,
  onReloadLiveRevision,
  onSwitchToPreview,
  highlightRow,
}: DistributionLedgerStageProps) {
  const isPreview = mode === "preview";
  const prefersReducedMotion = useReducedMotion() ?? false;
  const searchInputRef = useRef<HTMLInputElement>(null);
  const tableScrollRef = useRef<HTMLDivElement>(null);

  const {
    selectedRowNumber,
    setSelectedRowNumber,
    savePreviewCorrection,
    liveCorrectionDraft,
    liveConcurrencyError,
    setLiveCorrectionDraft,
    setLiveConcurrencyError,
  } = useSchedulingWorkbenchStore();

  const [searchQuery, setSearchQuery] = useState("");
  const [batchFilter, setBatchFilter] = useState("ALL");
  const [statusFilter, setStatusFilter] = useState<StatusFilter>("all");
  const [sorting, setSorting] = useState<SortingState>([]);

  // Inline audited correction form state
  const [isEditing, setIsEditing] = useState(false);
  const [targetColumn, setTargetColumn] = useState<DistributionColumn>("I");
  const [editValue, setEditValue] = useState("");
  const [editReason, setEditReason] = useState("");
  const [formError, setFormError] = useState<string | null>(null);
  const [isSavingCorrection, setIsSavingCorrection] = useState(false);

  const [isExpandedDesktop, setIsExpandedDesktop] = useState(() =>
    typeof window !== "undefined" && typeof window.matchMedia === "function"
      ? window.matchMedia("(min-width: 1100px)").matches
      : true,
  );

  useEffect(() => {
    if (typeof window === "undefined" || typeof window.matchMedia !== "function") {
      return;
    }
    const mql = window.matchMedia("(min-width: 1100px)");
    const onChange = (e: MediaQueryListEvent) => setIsExpandedDesktop(e.matches);
    setIsExpandedDesktop(mql.matches);
    mql.addEventListener("change", onChange);
    return () => mql.removeEventListener("change", onChange);
  }, []);

  useEffect(() => {
    if (highlightRow && records.some((r) => r.row === highlightRow)) {
      setSelectedRowNumber(highlightRow);
    }
  }, [highlightRow, records, setSelectedRowNumber]);

  useWorkspaceShortcuts({
    searchInputRef,
    onEscape: () => {
      if (isEditing) {
        setIsEditing(false);
        return;
      }
      if (selectedRowNumber !== null) {
        setSelectedRowNumber(null);
      }
    },
  });

  const batches = useMemo(
    () => Array.from(new Set(records.map((r) => r.batch))).sort(),
    [records],
  );

  const statusCounts = useMemo(() => {
    const counts = {
      all: records.length,
      conflict: 0,
      pendingTeacher: 0,
      corrected: 0,
      verified: 0,
    };
    for (const r of records) {
      counts[deriveRecordStatus(r)] += 1;
    }
    return counts;
  }, [records]);

  const filteredRecords = useMemo(() => {
    const q = searchQuery.trim().toLowerCase();
    return records.filter((rec) => {
      if (batchFilter !== "ALL" && rec.batch !== batchFilter) return false;
      if (statusFilter !== "all" && deriveRecordStatus(rec) !== statusFilter) {
        return false;
      }
      if (!q) return true;
      const teacher = getEffectiveColumnValue(rec, "I").toLowerCase();
      const dept = getEffectiveColumnValue(rec, "G").toLowerCase();
      return (
        rec.courseCode.toLowerCase().includes(q) ||
        rec.courseTitle.toLowerCase().includes(q) ||
        rec.batch.toLowerCase().includes(q) ||
        rec.section.toLowerCase().includes(q) ||
        teacher.includes(q) ||
        dept.includes(q) ||
        String(rec.row).includes(q)
      );
    });
  }, [batchFilter, records, searchQuery, statusFilter]);

  const selectedRecord = useMemo(
    () => records.find((r) => r.row === selectedRowNumber) ?? null,
    [records, selectedRowNumber],
  );

  // Restore preserved draft when reopening a conflicted row after SQLSTATE 40001
  useEffect(() => {
    if (
      !isPreview &&
      liveCorrectionDraft &&
      selectedRecord &&
      liveCorrectionDraft.row === selectedRecord.row
    ) {
      setIsEditing(true);
      setTargetColumn(liveCorrectionDraft.column);
      setEditValue(liveCorrectionDraft.value);
      setEditReason(liveCorrectionDraft.reason);
    }
  }, [isPreview, liveCorrectionDraft, selectedRecord]);

  const mutableRecords = useMemo(() => [...filteredRecords], [filteredRecords]);

  const tableColumns = useMemo<ColumnDef<typeof DIST_FEATURES, DistributionSourceRecord, unknown>[]>(
    () => [
      {
        id: "row",
        accessorFn: (r) => r.row,
        header: () => "Row",
        cell: ({ row }) => (
          <span className="font-mono-tabular text-[12px] text-[var(--ink-muted)]">
            {row.original.row}
          </span>
        ),
      },
      {
        id: "batch",
        accessorFn: (r) => r.batch,
        header: () => "Batch",
        cell: ({ row }) => (
          <span className="font-mono-tabular font-semibold">
            {row.original.batch}
          </span>
        ),
      },
      {
        id: "section",
        accessorFn: (r) => r.section,
        header: () => "Sec",
        cell: ({ row }) => (
          <Badge tone={row.original.section.includes("+") ? "joint" : "neutral"} mono>
            {row.original.section}
          </Badge>
        ),
      },
      {
        id: "code",
        accessorFn: (r) => r.courseCode,
        header: () => "Course",
        cell: ({ row }) => (
          <span className="font-mono-tabular font-semibold text-[var(--ink-primary)] whitespace-nowrap">
            {row.original.courseCode}
          </span>
        ),
      },
      {
        id: "title",
        accessorFn: (r) => r.courseTitle,
        header: () => "Title",
        cell: ({ row }) => (
          <span
            title={row.original.courseTitle}
            className="block max-w-[200px] truncate text-[12.5px] text-[var(--ink-secondary)]"
          >
            {row.original.courseTitle}
          </span>
        ),
      },
      {
        id: "credit",
        accessorFn: (r) => r.credit,
        header: () => "Cr",
        cell: ({ row }) => (
          <span className="font-mono-tabular text-[var(--ink-primary)]">
            {row.original.credit.toFixed(1)}
          </span>
        ),
      },
      {
        id: "prereq",
        accessorFn: (r) => r.prerequisite ?? "None",
        header: () => "Prereq",
        cell: ({ row }) => (
          <span className="font-mono-tabular text-[11.5px] text-[var(--ink-muted)] whitespace-nowrap">
            {row.original.prerequisite ?? "None"}
          </span>
        ),
      },
      {
        id: "dept",
        accessorFn: (r) => getEffectiveColumnValue(r, "G"),
        header: () => "Dept",
        cell: ({ row }) => {
          const val = getEffectiveColumnValue(row.original, "G");
          const corrected = row.original.corrections.some((c) => c.column === "G");
          return (
            <span
              className={cn(
                "font-mono-tabular whitespace-nowrap",
                corrected ? "font-semibold text-[var(--sem-joint-ink)]" : "",
              )}
            >
              {val}
            </span>
          );
        },
      },
      {
        id: "students",
        accessorFn: (r) => Number(getEffectiveColumnValue(r, "H")) || 0,
        header: () => "Enr",
        cell: ({ row }) => (
          <span className="font-mono-tabular text-[var(--ink-secondary)]">
            {getEffectiveColumnValue(row.original, "H")}
          </span>
        ),
      },
      {
        id: "teacher",
        accessorFn: (r) => getEffectiveColumnValue(r, "I"),
        header: () => "Teacher",
        cell: ({ row }) => {
          const val = getEffectiveColumnValue(row.original, "I");
          const pending = val.toLowerCase().includes("pending") || val === "TBA";
          const corrected = row.original.corrections.some((c) => c.column === "I");
          return (
            <span
              className={cn(
                "font-mono-tabular whitespace-nowrap",
                pending
                  ? "font-semibold text-[var(--sem-conflict-ink)]"
                  : corrected
                    ? "font-semibold text-[var(--sem-joint-ink)]"
                    : "text-[var(--ink-primary)]",
              )}
            >
              {pending ? "Pending" : val}
            </span>
          );
        },
      },
      {
        id: "classes",
        accessorFn: (r) => Number(getEffectiveColumnValue(r, "J")) || r.classes,
        header: () => "Cls (J)",
        cell: ({ row }) => {
          const rec = row.original;
          const val = getEffectiveColumnValue(rec, "J");
          if (!rec.formulaJ) {
            return <span className="font-mono-tabular">{val}</span>;
          }
          return (
            <Tooltip>
              <TooltipTrigger asChild>
                <span className="slot-override-corner font-mono-tabular inline-block rounded px-1.5 py-0.5 text-[var(--ink-primary)]">
                  {val}
                </span>
              </TooltipTrigger>
              <TooltipContent>
                Formula {rec.formulaJ} · Cached {rec.cachedJ ?? "—"}
              </TooltipContent>
            </Tooltip>
          );
        },
      },
      {
        id: "duration",
        accessorFn: (r) => r.durationMinutes,
        header: () => "Dur (K)",
        cell: ({ row }) => (
          <span className="font-mono-tabular whitespace-nowrap text-[var(--ink-muted)]">
            {row.original.durationMinutes}m
          </span>
        ),
      },
      {
        id: "weekly",
        accessorFn: (r) => Number(getEffectiveColumnValue(r, "L")) || r.classesPerWeek,
        header: () => "/Wk (L)",
        cell: ({ row }) => {
          const rec = row.original;
          const val = getEffectiveColumnValue(rec, "L");
          const discrepancy = hasFormulaCachedDiscrepancy(rec);
          const hasOverride = rec.corrections.some((c) => c.column === "L");
          if (!rec.formulaL) {
            return <span className="font-mono-tabular">{val}</span>;
          }
          return (
            <Tooltip>
              <TooltipTrigger asChild>
                <span
                  className={cn(
                    "slot-override-corner font-mono-tabular inline-block rounded px-1.5 py-0.5",
                    discrepancy && !hasOverride
                      ? "bg-[var(--sem-joint-bg)] font-semibold text-[var(--sem-joint-ink)]"
                      : "text-[var(--ink-primary)]",
                  )}
                >
                  {val}
                </span>
              </TooltipTrigger>
              <TooltipContent>
                Formula {rec.formulaL} · Cached Excel value:{" "}
                {rec.cachedL ?? "—"}
                {hasOverride ? ` · Overridden to ${val}` : ""}
              </TooltipContent>
            </Tooltip>
          );
        },
      },
      {
        id: "status",
        accessorFn: (r) => deriveRecordStatus(r),
        header: () => "Status",
        cell: ({ row }) => {
          const st = deriveRecordStatus(row.original);
          if (st === "conflict") {
            return (
              <Badge tone="conflict" mono>
                Conflict
              </Badge>
            );
          }
          if (st === "pendingTeacher") {
            return (
              <Badge tone="conflict" mono>
                Pending
              </Badge>
            );
          }
          if (st === "corrected") {
            return (
              <Badge tone="joint" mono>
                Overlay
              </Badge>
            );
          }
          return (
            <Badge tone="lab" mono>
              Verified
            </Badge>
          );
        },
      },
    ],
    [],
  );

  const table = useTable<
    typeof DIST_FEATURES,
    DistributionSourceRecord,
    { sorting: SortingState }
  >(
    {
      features: DIST_FEATURES,
      data: mutableRecords,
      columns: tableColumns,
      getRowId: (r) => String(r.row),
      state: { sorting },
      onSortingChange: setSorting,
    },
    (s) => ({ sorting: s.sorting }),
  );

  const rows = table.getRowModel().rows;
  const shouldVirtualize = rows.length > 20;

  const rowVirtualizer = useVirtualizer({
    count: shouldVirtualize ? rows.length : 0,
    getScrollElement: () => tableScrollRef.current,
    estimateSize: () => 48,
    overscan: 6,
  });

  const {
    hasRightOverflow,
    onScroll: handleTableScroll,
    maskStyle: scrollMaskStyle,
  } = useHorizontalScrollCue(tableScrollRef, [rows.length]);

  const startCorrectionEdit = (
    record: DistributionSourceRecord,
    col: DistributionColumn = "I",
  ) => {
    setTargetColumn(col);
    setEditValue(getEffectiveColumnValue(record, col));
    setEditReason("");
    setFormError(null);
    setIsEditing(true);
  };

  const handleSubmitCorrection = async (record: DistributionSourceRecord) => {
    const val = editValue.trim();
    const reason = editReason.trim();
    if (!val) {
      setFormError("Provide a non-empty effective cell value.");
      return;
    }
    if (!reason) {
      setFormError("Audit reason is mandatory for every cell overlay.");
      return;
    }

    if (isPreview) {
      savePreviewCorrection({
        row: record.row,
        column: targetColumn,
        effectiveValue: val,
        reason,
      });
      setIsEditing(false);
      setFormError(null);
      toast.success(
        `Simulated overlay applied to Row ${record.row} Col ${targetColumn}`,
      );
      return;
    }

    if (!gateB.unlocked || !revision) {
      setFormError("Gate B is locked; live corrections are disabled.");
      return;
    }

    setIsSavingCorrection(true);
    setFormError(null);
    setLiveConcurrencyError(null);

    const draftSnapshot = {
      row: record.row,
      column: targetColumn,
      value: val,
      reason,
    };

    try {
      await appendCourseDistributionCorrection({
        target_revision: revision.revisionId,
        expected_revision_version: revision.revisionVersion,
        target_row: record.row,
        target_column: targetColumn,
        prior_formula:
          targetColumn === "J"
            ? record.formulaJ
            : targetColumn === "L"
              ? record.formulaL
              : null,
        prior_cached_value:
          targetColumn === "J"
            ? record.cachedJ
            : targetColumn === "L"
              ? record.cachedL
              : getOriginalColumnValue(record, targetColumn),
        next_effective_value: val,
        reason,
      });

      setLiveCorrectionDraft(null);
      setIsEditing(false);
      toast.success(
        `Appended audited correction to Row ${record.row} Col ${targetColumn}`,
      );
      await onReloadLiveRevision();
    } catch (err) {
      if (isStaleRevisionError(err)) {
        // Preserve unsaved draft, reload latest revision_version, and show explicit 40001 banner
        setLiveCorrectionDraft(draftSnapshot);
        setLiveConcurrencyError(
          `Revision v${revision.revisionVersion} changed concurrently (SQLSTATE 40001). Reloaded latest revision while preserving your unsaved edit draft on Row ${record.row} Col ${targetColumn}.`,
        );
        await onReloadLiveRevision();
      } else {
        setFormError(
          err instanceof Error ? err.message : "Failed to save correction.",
        );
      }
    } finally {
      setIsSavingCorrection(false);
    }
  };

  // Strict fail-closed Live Mode Gate A card
  if (!isPreview && !gateA.unlocked) {
    return (
      <section
        data-testid="live-gate-a-locked"
        className="ledger-card flex max-w-[760px] flex-col gap-4 p-6"
      >
        <div className="flex flex-wrap items-center justify-between gap-2">
          <span className="font-mono-tabular text-[12px] font-medium text-[var(--accent-pine)]">
            Track 2 · Gate A Fail-Closed Boundary
          </span>
          <Badge tone="joint" mono>
            <LockSimple size={13} aria-hidden="true" />
            <span>Locked · Gates A–D</span>
          </Badge>
        </div>

        <div>
          <h2 className="text-[18px] font-semibold tracking-[-0.015em] text-[var(--ink-primary)]">
            5-Stage Scheduling Workbench
          </h2>
          <p className="mt-1.5 text-[13.5px] leading-[1.55] text-[var(--ink-secondary)]">
            {gateA.reason} Live workbench persistence stays fail-closed until
            Track 2 distribution read and correction contracts verify cleanly.
          </p>
        </div>

        <div className="rounded-[var(--r-control)] border border-[var(--border-subtle)] bg-[var(--bg-surface)] px-4 py-3 text-[12.5px] leading-[1.5] text-[var(--ink-secondary)]">
          <strong className="font-semibold text-[var(--ink-primary)]">
            Committee Review Option:{" "}
          </strong>
          Switch to isolated <strong>Design Preview</strong> to inspect the
          reconciled 23-offering Course Distribution ledger, 16 policy pillars,
          and preflight workflows without touching Supabase.
        </div>

        <div className="flex flex-wrap items-center gap-2.5">
          <Button variant="primary" size="md" onClick={onSwitchToPreview}>
            <Eye size={15} aria-hidden="true" />
            <span>Open Design Preview</span>
          </Button>
        </div>
      </section>
    );
  }

  const renderInspectorBody = () => {
    if (!selectedRecord) return null;
    const status = deriveRecordStatus(selectedRecord);
    const colDiscrepancy = hasFormulaCachedDiscrepancy(selectedRecord);
    const canEditOverlays = isPreview || gateB.unlocked;

    return (
      <div className="space-y-4 text-[13px]">
        {/* 1. Evidence (Original A-L) + 2. Effective Value */}
        <section className="space-y-2">
          <div className="text-[11px] font-semibold tracking-[0.04em] text-[var(--ink-muted)] uppercase">
            1–2. Evidence &amp; Effective Overlays (Cols A–L)
          </div>
          <div className="divide-y divide-[var(--border-subtle)] rounded-[var(--r-control)] border border-[var(--border-subtle)] bg-[var(--bg-surface)]">
            {(
              [
                ["A", "Batch"],
                ["B", "Section"],
                ["C", "Code"],
                ["D", "Course Title"],
                ["E", "Credit"],
                ["F", "Prerequisite"],
                ["G", "Conducting Dept"],
                ["H", "Enrolled Students"],
                ["I", "Teacher"],
                ["J", "Total Classes"],
                ["K", "Slot Duration"],
                ["L", "Classes / Week"],
              ] as const
            ).map(([col, label]) => {
              const orig = getOriginalColumnValue(selectedRecord, col);
              const eff = getEffectiveColumnValue(selectedRecord, col);
              const changed = orig !== eff;
              return (
                <div
                  key={col}
                  className="flex items-start justify-between gap-2 px-3 py-1.5 text-[12px]"
                >
                  <span className="text-[var(--ink-secondary)]">
                    <span className="font-mono-tabular font-semibold text-[var(--ink-muted)]">
                      {col}
                    </span>{" "}
                    · {label}
                  </span>
                  <div className="text-right">
                    {changed ? (
                      <div className="space-y-0.5">
                        <div className="font-mono-tabular text-[11px] text-[var(--ink-muted)] line-through">
                          {orig}
                        </div>
                        <div className="font-mono-tabular font-semibold text-[var(--sem-joint-ink)]">
                          {eff}
                        </div>
                      </div>
                    ) : (
                      <span className="font-mono-tabular font-medium text-[var(--ink-primary)]">
                        {eff}
                      </span>
                    )}
                  </div>
                </div>
              );
            })}
          </div>
        </section>

        {/* 3. Formula & Cached Values (Columns J & L) */}
        <section className="space-y-2">
          <div className="text-[11px] font-semibold tracking-[0.04em] text-[var(--ink-muted)] uppercase">
            3. Formula &amp; Cached Value Contract (J &amp; L)
          </div>
          <div className="rounded-[var(--r-control)] border border-[var(--border-subtle)] bg-[var(--bg-surface)] p-3 text-[12px]">
            <div className="grid grid-cols-2 gap-2">
              <div>
                <div className="text-[11px] text-[var(--ink-muted)]">
                  Column J (Total Classes)
                </div>
                <div className="font-mono-tabular font-semibold text-[var(--ink-primary)]">
                  {selectedRecord.formulaJ ?? "Scalar"}
                </div>
                <div className="font-mono-tabular text-[11px] text-[var(--ink-secondary)]">
                  Cached: {selectedRecord.cachedJ ?? "—"}
                </div>
              </div>
              <div>
                <div className="text-[11px] text-[var(--ink-muted)]">
                  Column L (Classes / Week)
                </div>
                <div className="font-mono-tabular font-semibold text-[var(--ink-primary)]">
                  {selectedRecord.formulaL ?? "Scalar"}
                </div>
                <div className="font-mono-tabular text-[11px] text-[var(--ink-secondary)]">
                  Cached: {selectedRecord.cachedL ?? "—"}
                </div>
              </div>
            </div>
            {colDiscrepancy && (
              <div className="mt-2 rounded border border-[var(--sem-joint-border)] bg-[var(--sem-joint-bg)] px-2.5 py-1.5 text-[11.5px] text-[var(--sem-joint-ink)]">
                Cached Excel value ({colDiscrepancy.cached}) on Col{" "}
                {colDiscrepancy.column} diverges from formula{" "}
                <code className="font-mono-tabular">{colDiscrepancy.formula}</code>{" "}
                (expected {colDiscrepancy.expected}).
              </div>
            )}
          </div>
        </section>

        {/* 4. Impact Preview */}
        <section className="space-y-2">
          <div className="text-[11px] font-semibold tracking-[0.04em] text-[var(--ink-muted)] uppercase">
            4. Deterministic Scheduling Implication
          </div>
          {selectedRecord.conflicts.length > 0 ? (
            <div className="space-y-1.5">
              {selectedRecord.conflicts.map((msg) => (
                <div
                  key={msg}
                  className="flex items-start gap-2 rounded-[var(--r-control)] border border-[var(--sem-conflict-border)] bg-[var(--sem-conflict-bg)] p-2.5 text-[12px] text-[var(--sem-conflict-ink)]"
                >
                  <WarningCircle
                    size={15}
                    className="mt-0.5 shrink-0"
                    aria-hidden="true"
                  />
                  <span>{msg}</span>
                </div>
              ))}
            </div>
          ) : (
            <div className="flex items-center gap-2 rounded-[var(--r-control)] border border-[var(--sem-lab-border)] bg-[var(--sem-lab-bg)] p-2.5 text-[12px] text-[var(--sem-lab-ink)]">
              <CheckCircle size={15} weight="fill" aria-hidden="true" />
              <span>
                Status: {status === "corrected" ? "Audited overlay ready" : "Verified"} — eligible for solver ingestion.
              </span>
            </div>
          )}
        </section>

        {/* 5. Audit Trail & Audited Correction Form */}
        <section className="space-y-2.5 border-t border-[var(--border-subtle)] pt-3">
          <div className="flex items-center justify-between gap-2">
            <div className="text-[11px] font-semibold tracking-[0.04em] text-[var(--ink-muted)] uppercase">
              5. Audit Trail ({selectedRecord.corrections.length})
            </div>
            {canEditOverlays && !isEditing && (
              <Button
                variant="secondary"
                size="sm"
                data-testid="open-correction-form-btn"
                onClick={() => startCorrectionEdit(selectedRecord, "I")}
              >
                <PencilSimple size={13} aria-hidden="true" />
                <span>Append Overlay</span>
              </Button>
            )}
          </div>

          {!canEditOverlays && (
            <div className="rounded-[var(--r-control)] border border-[var(--sem-joint-border)] bg-[var(--sem-joint-bg)] px-3 py-2 text-[12px] text-[var(--sem-joint-ink)]">
              Gate B locked: audited cell corrections require{" "}
              <code className="font-mono-tabular">
                append_course_distribution_correction
              </code>
              .
            </div>
          )}

          {selectedRecord.corrections.length === 0 ? (
            <p className="text-[12px] text-[var(--ink-muted)]">
              No cell overlays appended to Row {selectedRecord.row}.
            </p>
          ) : (
            <div className="space-y-2">
              {selectedRecord.corrections.map((c) => (
                <div
                  key={c.id}
                  className="rounded-[var(--r-control)] border border-[var(--border-subtle)] bg-[var(--bg-surface)] p-2.5 text-[12px]"
                >
                  <div className="flex items-center justify-between gap-2">
                    <Badge tone="joint" mono>
                      Col {c.column} · v{c.revisionVersion}
                    </Badge>
                    <span className="text-[11px] text-[var(--ink-muted)]">
                      {c.author}
                    </span>
                  </div>
                  <div className="font-mono-tabular mt-1.5 text-[12px]">
                    <span className="text-[var(--ink-muted)] line-through">
                      {c.originalValue}
                    </span>{" "}
                    <span aria-hidden="true">-&gt;</span>{" "}
                    <span className="font-semibold text-[var(--ink-primary)]">
                      {c.effectiveValue}
                    </span>
                  </div>
                  <p className="mt-1 text-[11.5px] text-[var(--ink-secondary)]">
                    {c.reason}
                  </p>
                </div>
              ))}
            </div>
          )}

          {isEditing && canEditOverlays && (
            <form
              data-testid="distribution-correction-form"
              onSubmit={(e) => {
                e.preventDefault();
                void handleSubmitCorrection(selectedRecord);
              }}
              className="space-y-2.5 rounded-[var(--r-control)] border border-[var(--border-strong)] bg-[var(--bg-surface)] p-3"
            >
              <div className="text-[12px] font-semibold text-[var(--ink-primary)]">
                Append Audited Correction
              </div>

              <div>
                <label
                  htmlFor="correction-column-select"
                  className="mb-1 block text-[11.5px] font-medium text-[var(--ink-secondary)]"
                >
                  Target Cell Column
                </label>
                <select
                  id="correction-column-select"
                  value={targetColumn}
                  onChange={(e) => {
                    const col = e.target.value as DistributionColumn;
                    setTargetColumn(col);
                    setEditValue(getEffectiveColumnValue(selectedRecord, col));
                  }}
                  className="h-8 w-full rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-2 text-[12.5px] text-[var(--ink-primary)]"
                >
                  {EDITABLE_COLUMN_OPTIONS.map((opt) => (
                    <option key={opt.col} value={opt.col}>
                      {opt.label}
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label
                  htmlFor="correction-effective-input"
                  className="mb-1 block text-[11.5px] font-medium text-[var(--ink-secondary)]"
                >
                  Effective Value
                </label>
                <input
                  id="correction-effective-input"
                  type="text"
                  value={editValue}
                  onChange={(e) => setEditValue(e.target.value)}
                  className="font-mono-tabular h-8 w-full rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-2.5 text-[12.5px] text-[var(--ink-primary)]"
                />
              </div>

              <div>
                <label
                  htmlFor="correction-reason-input"
                  className="mb-1 block text-[11.5px] font-medium text-[var(--ink-secondary)]"
                >
                  Committee Reason (Mandatory)
                </label>
                <textarea
                  id="correction-reason-input"
                  rows={2}
                  value={editReason}
                  onChange={(e) => setEditReason(e.target.value)}
                  placeholder="Document committee decision or spreadsheet reconciliation..."
                  className="w-full rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] p-2 text-[12px] text-[var(--ink-primary)]"
                />
              </div>

              {formError && (
                <div
                  role="alert"
                  className="rounded border border-[var(--sem-conflict-border)] bg-[var(--sem-conflict-bg)] px-2.5 py-1.5 text-[11.5px] text-[var(--sem-conflict-ink)]"
                >
                  {formError}
                </div>
              )}

              <div className="flex justify-end gap-2">
                <Button
                  type="button"
                  variant="ghost"
                  size="sm"
                  onClick={() => {
                    setIsEditing(false);
                    setLiveCorrectionDraft(null);
                  }}
                >
                  Cancel
                </Button>
                <Button
                  type="submit"
                  variant="primary"
                  size="sm"
                  disabled={isSavingCorrection}
                >
                  {isSavingCorrection ? "Appending..." : "Save Overlay"}
                </Button>
              </div>
            </form>
          )}
        </section>
      </div>
    );
  };

  return (
    <div className="space-y-4">
      {/* SQLSTATE 40001 Optimistic Concurrency Recovery Banner */}
      {!isPreview && liveConcurrencyError && (
        <div
          role="alert"
          data-testid="stale-revision-conflict-banner"
          className="flex flex-wrap items-start justify-between gap-3 rounded-[var(--r-card)] border border-[var(--sem-conflict-border)] bg-[var(--sem-conflict-bg)] p-4 text-[12.5px] text-[var(--sem-conflict-ink)]"
        >
          <div className="flex items-start gap-2.5">
            <WarningCircle
              size={18}
              className="mt-0.5 shrink-0"
              aria-hidden="true"
            />
            <div>
              <div className="font-semibold">
                Stale Revision Conflict Detected (40001)
              </div>
              <p className="mt-0.5 leading-[1.45]">{liveConcurrencyError}</p>
            </div>
          </div>
          <Button
            variant="secondary"
            size="sm"
            onClick={() => setLiveConcurrencyError(null)}
          >
            Dismiss
          </Button>
        </div>
      )}

      {/* Filter Toolbar & Live Scope Switcher */}
      <div className="ledger-card space-y-3 p-4">
        <div className="flex flex-wrap items-center justify-between gap-2.5">
          <div
            role="tablist"
            aria-label="Filter distribution offerings by verification status"
            className="flex flex-wrap items-center gap-1.5"
          >
            {(
              [
                { key: "all", label: `All (${statusCounts.all})` },
                { key: "conflict", label: `Conflicts (${statusCounts.conflict})` },
                {
                  key: "pendingTeacher",
                  label: `Pending (${statusCounts.pendingTeacher})`,
                },
                {
                  key: "corrected",
                  label: `Overlays (${statusCounts.corrected})`,
                },
                {
                  key: "verified",
                  label: `Verified (${statusCounts.verified})`,
                },
              ] as const
            ).map((opt) => {
              const active = statusFilter === opt.key;
              return (
                <button
                  key={opt.key}
                  type="button"
                  role="tab"
                  aria-selected={active}
                  onClick={() => setStatusFilter(opt.key)}
                  className={cn(
                    "font-mono-tabular h-[32px] rounded-[6px] border px-2.5 text-[12px] whitespace-nowrap transition-colors",
                    active
                      ? "border-[var(--action-primary)] bg-[var(--action-primary)] font-semibold text-[var(--action-primary-ink)]"
                      : "border-[var(--border-subtle)] bg-[var(--bg-surface)] text-[var(--ink-secondary)] hover:bg-[var(--surface-hover)]",
                  )}
                >
                  {opt.label}
                </button>
              );
            })}
          </div>

          {!isPreview && revisionsList.length > 0 && (
            <div className="flex items-center gap-2">
              <GitBranch
                size={14}
                className="text-[var(--ink-muted)]"
                aria-hidden="true"
              />
              <select
                aria-label="Select distribution revision"
                value={selectedRevisionId ?? ""}
                onChange={(e) => onSelectRevision(e.target.value)}
                className="font-mono-tabular h-[34px] rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-2.5 text-[12px] text-[var(--ink-primary)]"
              >
                {revisionsList.map((rev) => (
                  <option key={rev.revisionId} value={rev.revisionId}>
                    Rev #{rev.revisionNumber} (v{rev.revisionVersion}) ·{" "}
                    {rev.semester}
                  </option>
                ))}
              </select>
              <Button
                variant="secondary"
                size="sm"
                onClick={() => void onReloadLiveRevision()}
              >
                <ArrowsClockwise size={13} aria-hidden="true" />
                <span>Sync</span>
              </Button>
            </div>
          )}
        </div>

        <div className="flex flex-wrap items-center gap-2.5">
          <div className="relative min-w-[230px] flex-1">
            <MagnifyingGlass
              size={15}
              className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-[var(--ink-muted)]"
              aria-hidden="true"
            />
            <input
              ref={searchInputRef}
              type="search"
              aria-label="Search distribution rows"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              placeholder="Search course, teacher, batch (/)"
              className="h-[36px] w-full rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] pl-9 pr-3 text-[13px] text-[var(--ink-primary)] placeholder:text-[var(--ink-muted)] focus:border-[var(--ink-primary)] focus:outline-none"
            />
          </div>

          <select
            aria-label="Filter by batch"
            value={batchFilter}
            onChange={(e) => setBatchFilter(e.target.value)}
            className="font-mono-tabular h-[36px] rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-2.5 text-[12.5px] text-[var(--ink-primary)]"
          >
            <option value="ALL">All Batches</option>
            {batches.map((b) => (
              <option key={b} value={b}>
                Batch {b}
              </option>
            ))}
          </select>

          <span className="font-mono-tabular ml-auto text-[12px] text-[var(--ink-muted)]">
            Showing {filteredRecords.length} of {records.length} offerings
          </span>
        </div>
      </div>

      {/* Master Table / Mobile Stack + Closable 380px Provenance Inspector */}
      <div
        className={cn(
          "grid grid-cols-1 items-start gap-5",
          selectedRecord && isExpandedDesktop
            ? "min-[1100px]:grid-cols-[minmax(0,1fr)_380px]"
            : "",
        )}
      >
        <div className="min-w-0">
          {records.length === 0 ? (
            <LedgerEmptyState
              icon={<GitBranch size={20} aria-hidden="true" />}
              title="No source rows found for this revision"
              description="Accepted Course Distribution rows will populate here once uploaded and verified."
            />
          ) : filteredRecords.length === 0 ? (
            <LedgerFilterEmpty
              message="No offerings match the active batch, status, or search filters."
              onReset={() => {
                setSearchQuery("");
                setBatchFilter("ALL");
                setStatusFilter("all");
              }}
            />
          ) : (
            <>
              {/* Mobile Card List (< 768px) */}
              <div
                data-testid="distribution-mobile-list"
                className="ledger-card divide-y divide-[var(--border-subtle)] overflow-hidden md:hidden"
              >
                {filteredRecords.map((rec) => {
                  const st = deriveRecordStatus(rec);
                  return (
                    <button
                      key={rec.row}
                      type="button"
                      onClick={() => setSelectedRowNumber(rec.row)}
                      className="flex w-full flex-col gap-1.5 px-4 py-3 text-left transition-colors hover:bg-[var(--surface-hover)]"
                    >
                      <div className="flex items-center justify-between gap-2">
                        <span className="font-mono-tabular text-[12.5px] font-semibold text-[var(--ink-primary)]">
                          Row {rec.row} · {rec.courseCode}
                        </span>
                        <Badge
                          tone={
                            st === "conflict" || st === "pendingTeacher"
                              ? "conflict"
                              : st === "corrected"
                                ? "joint"
                                : "lab"
                          }
                          mono
                        >
                          {st === "conflict"
                            ? "Conflict"
                            : st === "pendingTeacher"
                              ? "Pending"
                              : st === "corrected"
                                ? "Overlay"
                                : "Verified"}
                        </Badge>
                      </div>
                      <div className="truncate text-[12.5px] text-[var(--ink-secondary)]">
                        {rec.courseTitle}
                      </div>
                      <div className="font-mono-tabular flex items-center justify-between gap-2 text-[11.5px] text-[var(--ink-muted)]">
                        <span>
                          Batch {rec.batch}-{rec.section} ·{" "}
                          {getEffectiveColumnValue(rec, "I")}
                        </span>
                        <span>
                          {getEffectiveColumnValue(rec, "L")}/wk ·{" "}
                          {rec.durationMinutes}m
                        </span>
                      </div>
                    </button>
                  );
                })}
              </div>

              {/* Desktop / Tablet 12-Column Table (>= 768px) */}
              <div className="ledger-card hidden overflow-hidden md:block">
                <div
                  ref={tableScrollRef}
                  onScroll={handleTableScroll}
                  data-scroll-cue-right={hasRightOverflow ? "true" : "false"}
                  style={scrollMaskStyle}
                  className={cn(
                    "overflow-x-auto",
                    shouldVirtualize && "max-h-[580px] overflow-y-auto",
                  )}
                >
                  <table
                    aria-label="Course Distribution Workbook Ledger"
                    className="w-full border-collapse text-left"
                  >
                    <thead className="sticky top-0 z-10 border-b border-[var(--border-subtle)] bg-[var(--bg-canvas)]">
                      {table.getHeaderGroups().map((hg) => (
                        <tr key={hg.id}>
                          {hg.headers.map((header) => (
                            <th
                              key={header.id}
                              scope="col"
                              className="px-3 py-2.5 text-[11px] font-semibold tracking-[0.04em] text-[var(--ink-secondary)] uppercase whitespace-nowrap"
                            >
                              <button
                                type="button"
                                onClick={header.column.getToggleSortingHandler()}
                                className="inline-flex items-center gap-1 uppercase hover:text-[var(--ink-primary)]"
                              >
                                <table.FlexRender header={header} />
                              </button>
                            </th>
                          ))}
                        </tr>
                      ))}
                    </thead>
                    <tbody className="divide-y divide-[var(--border-subtle)] bg-[var(--bg-elevated)]">
                      {shouldVirtualize ? (
                        <>
                          {rowVirtualizer.getVirtualItems().length > 0 &&
                            rowVirtualizer.getVirtualItems()[0]!.start > 0 && (
                              <tr aria-hidden="true">
                                <td
                                  colSpan={tableColumns.length}
                                  style={{
                                    height: `${rowVirtualizer.getVirtualItems()[0]!.start}px`,
                                  }}
                                />
                              </tr>
                            )}
                          {rowVirtualizer.getVirtualItems().map((vRow) => {
                            const row = rows[vRow.index];
                            if (!row) return null;
                            const isSel = selectedRowNumber === row.original.row;
                            return (
                              <tr
                                key={row.id}
                                data-testid={`distribution-row-${row.original.row}`}
                                onClick={() =>
                                  setSelectedRowNumber(row.original.row)
                                }
                                className={cn(
                                  "cursor-pointer transition-colors hover:bg-[var(--surface-hover)]",
                                  isSel && "bg-[var(--accent-pine-soft)]/55",
                                )}
                              >
                                {row.getAllCells().map((cell) => (
                                  <td
                                    key={cell.id}
                                    className="px-3 py-2.5 text-[12.5px]"
                                  >
                                    <table.FlexRender cell={cell} />
                                  </td>
                                ))}
                              </tr>
                            );
                          })}
                          {rowVirtualizer.getVirtualItems().length > 0 && (
                            <tr aria-hidden="true">
                              <td
                                colSpan={tableColumns.length}
                                style={{
                                  height: `${Math.max(
                                    0,
                                    rowVirtualizer.getTotalSize() -
                                      (rowVirtualizer.getVirtualItems().at(-1)
                                        ?.end ?? 0),
                                  )}px`,
                                }}
                              />
                            </tr>
                          )}
                        </>
                      ) : (
                        rows.map((row) => {
                          const isSel = selectedRowNumber === row.original.row;
                          return (
                            <tr
                              key={row.id}
                              data-testid={`distribution-row-${row.original.row}`}
                              onClick={() =>
                                setSelectedRowNumber(row.original.row)
                              }
                              className={cn(
                                "cursor-pointer transition-colors hover:bg-[var(--surface-hover)]",
                                isSel && "bg-[var(--accent-pine-soft)]/55",
                              )}
                            >
                              {row.getAllCells().map((cell) => (
                                <td
                                  key={cell.id}
                                  className="px-3 py-2.5 text-[12.5px]"
                                >
                                  <table.FlexRender cell={cell} />
                                </td>
                              ))}
                            </tr>
                          );
                        })
                      )}
                    </tbody>
                  </table>
                </div>
              </div>
            </>
          )}
        </div>

        {/* Closable 380px Docked Provenance Inspector (>= 1100px) */}
        {isExpandedDesktop && (
          <AnimatePresence initial={false}>
            {selectedRecord && (
              <motion.aside
                aria-label={`Row ${selectedRecord.row} Provenance`}
                data-testid="distribution-docked-inspector"
                initial={prefersReducedMotion ? false : { opacity: 0, x: 14 }}
                animate={{ opacity: 1, x: 0 }}
                exit={
                  prefersReducedMotion
                    ? undefined
                    : {
                        opacity: 0,
                        x: 10,
                        transition: { duration: 0.14, ease: [0.4, 0, 1, 1] },
                      }
                }
                transition={{ duration: 0.19, ease: [0.16, 1, 0.3, 1] }}
                className="ledger-sheet sticky top-4 flex max-h-[calc(100dvh-32px)] flex-col overflow-hidden"
              >
                <div className="flex items-start justify-between gap-3 border-b border-[var(--border-subtle)] px-4 py-3.5">
                  <div className="min-w-0">
                    <h2 className="truncate text-[15px] font-semibold text-[var(--ink-primary)]">
                      {selectedRecord.courseCode} · Row {selectedRecord.row}
                    </h2>
                    <p className="font-mono-tabular mt-0.5 truncate text-[11.5px] text-[var(--ink-secondary)]">
                      Batch {selectedRecord.batch}-{selectedRecord.section} ·{" "}
                      {selectedRecord.credit.toFixed(1)} Cr
                    </p>
                  </div>
                  <button
                    type="button"
                    data-testid="distribution-inspector-close"
                    aria-label="Close distribution inspector"
                    onClick={() => setSelectedRowNumber(null)}
                    className="flex h-8 w-8 shrink-0 items-center justify-center rounded-[var(--r-control)] border border-[var(--border-subtle)] bg-[var(--bg-surface)] text-[var(--ink-secondary)] hover:bg-[var(--surface-hover)] hover:text-[var(--ink-primary)]"
                  >
                    <X size={16} aria-hidden="true" />
                  </button>
                </div>
                <div className="flex-1 overflow-y-auto px-4 py-4">
                  {renderInspectorBody()}
                </div>
              </motion.aside>
            )}
          </AnimatePresence>
        )}

        {/* Tablet / Mobile Drawer (< 1100px) */}
        {!isExpandedDesktop && (
          <Dialog
            open={selectedRecord !== null}
            onOpenChange={(open) => {
              if (!open) setSelectedRowNumber(null);
            }}
          >
            <DialogContent
              aria-describedby={undefined}
              className="fixed inset-y-0 right-0 flex w-full max-w-[420px] flex-col rounded-none border-l border-[var(--border-subtle)] bg-[var(--bg-elevated)] p-0"
            >
              <DialogTitle className="sr-only">
                {selectedRecord
                  ? `${selectedRecord.courseCode} Row ${selectedRecord.row}`
                  : "Provenance Inspector"}
              </DialogTitle>
              <DialogDescription className="sr-only">
                Distribution provenance and audited overlay controls
              </DialogDescription>
              {selectedRecord && (
                <>
                  <div className="flex items-start justify-between gap-3 border-b border-[var(--border-subtle)] px-4 py-3.5">
                    <div className="min-w-0">
                      <h2 className="truncate text-[15px] font-semibold text-[var(--ink-primary)]">
                        {selectedRecord.courseCode} · Row {selectedRecord.row}
                      </h2>
                      <p className="font-mono-tabular mt-0.5 truncate text-[11.5px] text-[var(--ink-secondary)]">
                        Batch {selectedRecord.batch}-{selectedRecord.section}
                      </p>
                    </div>
                    <button
                      type="button"
                      data-testid="distribution-inspector-close"
                      aria-label="Close distribution inspector"
                      onClick={() => setSelectedRowNumber(null)}
                      className="flex h-8 w-8 shrink-0 items-center justify-center rounded-[var(--r-control)] border border-[var(--border-subtle)] bg-[var(--bg-surface)] text-[var(--ink-secondary)] hover:bg-[var(--surface-hover)] hover:text-[var(--ink-primary)]"
                    >
                      <X size={16} aria-hidden="true" />
                    </button>
                  </div>
                  <div className="flex-1 overflow-y-auto px-4 py-4">
                    {renderInspectorBody()}
                  </div>
                </>
              )}
            </DialogContent>
          </Dialog>
        )}
      </div>
    </div>
  );
}
