import {
  ArrowLeft,
  ArrowsClockwise,
  CaretDown,
  CaretRight,
  Check,
  CircleNotch,
  ClockCounterClockwise,
  Copy,
  DownloadSimple,
  Eye,
  FileXls,
  GridFour,
  MagnifyingGlass,
  WarningCircle,
  X,
} from "@phosphor-icons/react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useMemo, useState } from "react";
import { toast } from "sonner";
import {
  LedgerEmptyState,
  LedgerErrorRecovery,
  LedgerFilterEmpty,
  LedgerTableSkeleton,
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
  DataLedgerTable,
  type DataLedgerColumn,
} from "@/components/ui/DataLedgerTable";
import { MasterDetailShell } from "@/components/ui/MasterDetailShell";
import { useAuth } from "@/features/auth/AuthProvider";
import { AcademicTimetableMatrix } from "@/features/routine/components/AcademicTimetableMatrix";
import {
  downloadArchiveWorkbook,
  downloadArchiveWorkbookBlob,
  extractStatsEntries,
  fetchRoutineArchive,
  parseValidationJsonb,
  restoreRoutineVersion,
  ROUTINE_ARCHIVE_QUERY_KEY,
  type ArchiveSource,
  type RoutineArchiveItem,
} from "@/features/routine/services/routineArchiveService";
import {
  buildDevPreviewParsedWorkbook,
  parseRenderedWorkbook,
} from "@/features/routine/services/timetableEngineService";
import { cn } from "@/lib/utils";

type ArchiveFilterTab = "all" | "version" | "run" | "storage-only";

function formatTimestamp(iso: string | null): string {
  if (!iso) return "—";
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) return iso;
  return new Intl.DateTimeFormat(undefined, {
    year: "numeric",
    month: "short",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
  }).format(date);
}

function formatFileSize(bytes: number | null): string {
  if (bytes === null || !Number.isFinite(bytes)) return "—";
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(2)} MB`;
}

function sourceBadgeProps(source: ArchiveSource): {
  label: string;
  tone: "theory" | "joint" | "lab" | "neutral";
} {
  switch (source) {
    case "engine":
      return { label: "engine", tone: "theory" };
    case "upload":
      return { label: "upload", tone: "joint" };
    case "manual":
      return { label: "manual", tone: "neutral" };
    case "rollback":
      return { label: "rollback", tone: "lab" };
    case "storage-only":
      return { label: "storage-only", tone: "neutral" };
  }
}

export function RoutineArchiveTab() {
  const { isDevPreview } = useAuth();
  const queryClient = useQueryClient();
  const [filterTab, setFilterTab] = useState<ArchiveFilterTab>("all");
  const [onlyWithXlsx, setOnlyWithXlsx] = useState(false);
  const [searchQuery, setSearchQuery] = useState("");
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [previewItem, setPreviewItem] = useState<RoutineArchiveItem | null>(null);
  const [restoreTarget, setRestoreTarget] = useState<RoutineArchiveItem | null>(null);
  const [restoreNote, setRestoreNote] = useState("");
  const [downloadingId, setDownloadingId] = useState<string | null>(null);
  const [copiedKey, setCopiedKey] = useState<string | null>(null);
  const [expandedDetailKeys, setExpandedDetailKeys] = useState<Record<string, boolean>>({});

  const archiveQuery = useQuery({
    queryKey: [...ROUTINE_ARCHIVE_QUERY_KEY, isDevPreview],
    queryFn: () => fetchRoutineArchive(isDevPreview),
    staleTime: 30_000,
  });

  const restoreMutation = useMutation({
    mutationFn: (target: RoutineArchiveItem) => {
      if (!target.versionId) {
        throw new Error("Only persisted published versions can be restored.");
      }
      return restoreRoutineVersion({
        versionId: target.versionId,
        notes: restoreNote,
        isDevPreview,
      });
    },
    onSuccess: (res, target) => {
      setRestoreTarget(null);
      setRestoreNote("");
      setSelectedId(`version:${res.versionId}`);
      void queryClient.invalidateQueries({ queryKey: ["admin-routines"] });
      void queryClient.invalidateQueries({
        queryKey: ["admin-routine-active-version"],
      });
      void queryClient.invalidateQueries({ queryKey: ROUTINE_ARCHIVE_QUERY_KEY });
      void queryClient.invalidateQueries({ queryKey: ["admin-dashboard-counts"] });
      toast.success(
        `Restored "${target.semesterLabel}" (${res.rowCount} active slots)`,
      );
    },
    onError: (err) => {
      toast.error("Version restore failed", {
        description: err instanceof Error ? err.message : "RPC failed.",
      });
    },
  });

  const archivePreviewQuery = useQuery({
    queryKey: [
      "archive-workbook-preview",
      previewItem?.id ?? null,
      previewItem?.objectKey ?? null,
      previewItem?.hasSnapshot ?? false,
      isDevPreview,
    ],
    enabled: Boolean(previewItem?.hasSnapshot || previewItem?.objectKey),
    staleTime: 10 * 60 * 1000,
    retry: false,
    queryFn: async () => {
      if (previewItem?.hasSnapshot && previewItem.snapshotRows?.length) {
        const regular = previewItem.snapshotRows.filter((r) => !r.is_service);
        const service = previewItem.snapshotRows.filter((r) => Boolean(r.is_service));
        return {
          rows: regular,
          service_rows: service,
          warnings: [],
          stats: {
            meetings: regular.length,
            service_meetings: service.length,
            total_meetings: regular.length + service.length,
            cohorts: 0,
            teachers: 0,
            days: 0,
            sheets_parsed: 0,
          },
          validation: { ok: true },
          detected_format: "snapshot",
          sheet_names: ["snapshot_rows"],
        };
      }
      if (!previewItem?.objectKey) {
        throw new Error("No workbook or snapshot attached to this archive record.");
      }
      if (isDevPreview) {
        return buildDevPreviewParsedWorkbook(previewItem.semesterLabel);
      }
      const { blob } = await downloadArchiveWorkbookBlob(
        previewItem.objectKey,
        false,
      );
      const file = new File(
        [blob],
        previewItem.fileName ?? "archive_routine.xlsx",
        {
          type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        },
      );
      return parseRenderedWorkbook(file);
    },
  });

  const dataset = archiveQuery.data;

  const filteredItems = useMemo(() => {
    const items = dataset?.items ?? [];
    const q = searchQuery.trim().toLowerCase();

    return items.filter((item) => {
      if (filterTab !== "all" && item.category !== filterTab) return false;
      if (onlyWithXlsx && !item.hasXlsx) return false;
      if (!q) return true;

      const haystack = [
        item.semesterLabel,
        item.source,
        item.actorName,
        item.fileName ?? "",
        item.objectKey ?? "",
        item.notes ?? "",
        item.id,
      ]
        .join(" ")
        .toLowerCase();
      return haystack.includes(q);
    });
  }, [dataset?.items, filterTab, onlyWithXlsx, searchQuery]);

  const selectedItem = useMemo(
    () => (dataset?.items ?? []).find((item) => item.id === selectedId) ?? null,
    [dataset?.items, selectedId],
  );

  const handleDownload = async (item: RoutineArchiveItem) => {
    if (!item.objectKey) return;
    setDownloadingId(item.id);
    try {
      await downloadArchiveWorkbook(
        item.objectKey,
        item.fileName ?? "routine.xlsx",
        isDevPreview,
      );
      toast.success(`Downloaded ${item.fileName ?? item.objectKey}`);
    } catch (err) {
      const msg = err instanceof Error ? err.message : "Workbook download failed.";
      toast.error("Download failed", { description: msg });
    } finally {
      setDownloadingId(null);
    }
  };

  const handleCopyPath = (value: string) => {
    if (navigator.clipboard?.writeText) {
      void navigator.clipboard.writeText(value);
    }
    setCopiedKey(value);
    toast.success(`Copied ${value}`);
    window.setTimeout(() => setCopiedKey((prev) => (prev === value ? null : prev)), 1400);
  };

  const columns = useMemo<DataLedgerColumn<RoutineArchiveItem>[]>(
    () => [
      {
        id: "semester",
        header: "Semester / Artifact",
        accessor: (row) => row.semesterLabel,
        cell: (row, { isInactive }) => (
          <div className="min-w-0 max-w-[280px]">
            <div className="flex flex-wrap items-center gap-2">
              <span
                className={cn(
                  "truncate font-medium",
                  isInactive
                    ? "text-[var(--ink-secondary)]"
                    : "text-[var(--ink-primary)]",
                )}
                title={row.semesterLabel}
              >
                {row.semesterLabel}
              </span>
              {row.isActive && (
                <Badge tone="pine" data-testid="archive-active-badge">
                  Active
                </Badge>
              )}
            </div>
            {row.fileName && row.fileName !== row.semesterLabel && (
              <div
                className="font-mono-tabular mt-0.5 truncate text-[11.5px] text-[var(--ink-muted)]"
                title={row.objectKey ?? row.fileName}
              >
                {row.fileName}
              </div>
            )}
          </div>
        ),
      },
      {
        id: "source",
        header: "Source",
        accessor: (row) => row.source,
        cell: (row) => {
          const badge = sourceBadgeProps(row.source);
          return (
            <Badge tone={badge.tone} mono>
              {badge.label}
            </Badge>
          );
        },
      },
      {
        id: "rows",
        header: "Slots",
        align: "right",
        accessor: (row) => row.rowCount ?? -1,
        cell: (row) => (
          <span className="font-mono-tabular text-[12.5px]">
            {row.rowCount !== null ? row.rowCount : "—"}
          </span>
        ),
      },
      {
        id: "validation",
        header: "Validation",
        accessor: (row) => {
          const parsed = parseValidationJsonb(row.validation);
          if (parsed.ok === false) return "issues";
          if (parsed.ok === true) return "ok";
          return "none";
        },
        cell: (row) => {
          const parsed = parseValidationJsonb(row.validation);
          if (parsed.ok === false) {
            return (
              <Badge tone="conflict" mono>
                {parsed.issueCount > 0 ? `${parsed.issueCount} issues` : "Flagged"}
              </Badge>
            );
          }
          if (parsed.ok === true) {
            return (
              <Badge tone="neutral" mono>
                Pass
              </Badge>
            );
          }
          return <span className="text-[12px] text-[var(--ink-muted)]">—</span>;
        },
      },
      {
        id: "actor",
        header: "Actor",
        accessor: (row) => row.actorName,
        cell: (row) => (
          <span className="block max-w-[160px] truncate text-[12.5px]">
            {row.actorName}
          </span>
        ),
      },
      {
        id: "timestamp",
        header: "Recorded",
        accessor: (row) => row.timestamp ?? "",
        cell: (row) => (
          <span className="font-mono-tabular whitespace-nowrap text-[12px]">
            {formatTimestamp(row.timestamp)}
          </span>
        ),
      },
    ],
    [],
  );

  const parsedValidation = useMemo(
    () => (selectedItem ? parseValidationJsonb(selectedItem.validation) : null),
    [selectedItem],
  );
  const statsEntries = useMemo(
    () => (selectedItem ? extractStatsEntries(selectedItem.stats) : []),
    [selectedItem],
  );

  const counts = dataset?.counts ?? {
    all: 0,
    versions: 0,
    runs: 0,
    storageOnly: 0,
    withXlsx: 0,
  };

  const filterPills: Array<{ id: ArchiveFilterTab; label: string; count: number }> = [
    { id: "all", label: "All", count: counts.all },
    { id: "version", label: "Published Versions", count: counts.versions },
    { id: "run", label: "Run History", count: counts.runs },
    { id: "storage-only", label: "Storage Only", count: counts.storageOnly },
  ];

  const hasActiveFilters =
    filterTab !== "all" || onlyWithXlsx || searchQuery.trim().length > 0;

  const masterContent = (
    <div className="space-y-3" data-testid="routine-archive-view">
      {dataset?.isPreviewFixture && (
        <div className="flex flex-wrap items-center justify-between gap-2 rounded-[var(--r-control)] border border-[var(--border-subtle)] bg-[var(--bg-elevated)] px-3.5 py-2 text-[12px] text-[var(--ink-secondary)]">
          <span>
            Showing illustrative archive fixtures in Dev Preview mode (zero network requests).
          </span>
          <Badge tone="neutral" mono>
            Preview Fixtures
          </Badge>
        </div>
      )}

      {/* Filter Pills + Quick Has .xlsx Toggle + Search + Refresh */}
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div
          role="group"
          aria-label="Filter archive records by category"
          className="flex flex-wrap items-center gap-1.5"
        >
          {filterPills.map((pill) => {
            const active = filterTab === pill.id;
            return (
              <button
                key={pill.id}
                type="button"
                aria-pressed={active}
                data-testid={`archive-filter-${pill.id}`}
                onClick={() => setFilterTab(pill.id)}
                className={cn(
                  "inline-flex h-8 items-center gap-1.5 rounded-[var(--r-control)] border px-2.5 text-[12.5px] transition-colors",
                  active
                    ? "border-[var(--border-strong)] bg-[var(--bg-raised)] font-semibold text-[var(--ink-primary)]"
                    : "border-[var(--border-subtle)] bg-[var(--bg-elevated)] font-medium text-[var(--ink-secondary)] hover:bg-[var(--surface-hover)] hover:text-[var(--ink-primary)]",
                )}
              >
                <span>{pill.label}</span>
                <span className="font-mono-tabular text-[11px] text-[var(--ink-muted)]">
                  {pill.count}
                </span>
              </button>
            );
          })}

          <button
            type="button"
            aria-pressed={onlyWithXlsx}
            data-testid="archive-filter-has-xlsx"
            onClick={() => setOnlyWithXlsx((prev) => !prev)}
            className={cn(
              "inline-flex h-8 items-center gap-1.5 rounded-[var(--r-control)] border px-2.5 text-[12.5px] transition-colors",
              onlyWithXlsx
                ? "border-[var(--accent-brand)] bg-[var(--accent-brand-soft)] font-semibold text-[var(--ink-primary)]"
                : "border-[var(--border-subtle)] bg-[var(--bg-elevated)] font-medium text-[var(--ink-secondary)] hover:bg-[var(--surface-hover)] hover:text-[var(--ink-primary)]",
            )}
          >
            <FileXls size={14} aria-hidden="true" />
            <span>Has .xlsx</span>
            <span className="font-mono-tabular text-[11px] text-[var(--ink-muted)]">
              {counts.withXlsx}
            </span>
          </button>
        </div>

        <div className="flex flex-wrap items-center gap-2">
          <div className="relative min-w-[200px] flex-1 sm:w-[240px] sm:flex-none">
            <MagnifyingGlass
              size={14}
              aria-hidden="true"
              className="pointer-events-none absolute top-1/2 left-2.5 -translate-y-1/2 text-[var(--ink-muted)]"
            />
            <input
              type="search"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              placeholder="Search semester, file, actor…"
              aria-label="Search routine archive"
              data-testid="archive-search-input"
              className="h-8 w-full rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] pr-2.5 pl-8 text-[12.5px] text-[var(--ink-primary)] placeholder:text-[var(--ink-muted)]"
            />
          </div>

          <Button
            variant="secondary"
            size="sm"
            onClick={() => void archiveQuery.refetch()}
            disabled={archiveQuery.isFetching}
          >
            <ArrowsClockwise
              size={14}
              aria-hidden="true"
              className={archiveQuery.isFetching ? "animate-spin" : undefined}
            />
            <span>Refresh</span>
          </Button>
        </div>
      </div>

      {/* Count summary */}
      {!archiveQuery.isLoading && !archiveQuery.isError && dataset && (
        <div className="font-mono-tabular text-[12px] text-[var(--ink-muted)]">
          Showing {filteredItems.length} of {counts.all} archive records
        </div>
      )}

      {/* Async states & DataLedgerTable */}
      {archiveQuery.isLoading ? (
        <LedgerTableSkeleton rows={6} label="Loading routine archive" />
      ) : archiveQuery.isError ? (
        <LedgerErrorRecovery
          title="Unable to load routine archive"
          message={
            archiveQuery.error instanceof Error
              ? archiveQuery.error.message
              : "An unexpected error occurred while reading archive metadata."
          }
          onRetry={() => void archiveQuery.refetch()}
        />
      ) : counts.all === 0 ? (
        <LedgerEmptyState
          icon={<ClockCounterClockwise size={20} aria-hidden="true" />}
          title="No archived routines yet"
          description="Published routine versions, solver run history, and stored .xlsx workbooks will appear here after the first routine publication."
        />
      ) : filteredItems.length === 0 ? (
        <LedgerFilterEmpty
          message="No archive records match your active category or search filter."
          onReset={() => {
            setFilterTab("all");
            setOnlyWithXlsx(false);
            setSearchQuery("");
          }}
        />
      ) : (
        <DataLedgerTable
          data={filteredItems}
          columns={columns}
          getRowId={(row) => row.id}
          selectedRowId={selectedId}
          onRowClick={(row) => {
            setSelectedId(row.id);
            setExpandedDetailKeys({});
          }}
          isInactiveRow={(row) => !row.isActive}
          ariaLabel="Published routines and timetable archive"
          renderRowActions={(row) => (
            <div className="flex items-center gap-1">
              {((row.hasXlsx && row.objectKey) || row.hasSnapshot) && (
                <button
                  type="button"
                  aria-label={`Preview ${row.semesterLabel} in 2D Grid`}
                  onClick={() => setPreviewItem(row)}
                  className="inline-flex h-7 items-center gap-1 rounded-[var(--r-control)] border border-[var(--border-subtle)] bg-[var(--bg-elevated)] px-2 text-[11.5px] font-medium text-[var(--ink-primary)] hover:bg-[var(--surface-hover)]"
                >
                  <GridFour size={13} aria-hidden="true" />
                  <span>2D Grid</span>
                </button>
              )}
              {row.hasXlsx && row.objectKey && (
                <button
                  type="button"
                  aria-label={`Download ${row.fileName ?? row.objectKey}`}
                  disabled={downloadingId === row.id}
                  onClick={() => void handleDownload(row)}
                  className="inline-flex h-7 items-center gap-1 rounded-[var(--r-control)] border border-[var(--border-subtle)] bg-[var(--bg-elevated)] px-2 text-[11.5px] font-medium text-[var(--ink-primary)] hover:bg-[var(--surface-hover)] disabled:opacity-50"
                >
                  <DownloadSimple size={13} aria-hidden="true" />
                  <span>.xlsx</span>
                </button>
              )}
              {row.category === "version" && row.canRestore && row.versionId && (
                <button
                  type="button"
                  data-testid={`archive-restore-btn-${row.versionId}`}
                  aria-label={`Restore Version ${row.semesterLabel}`}
                  onClick={() => {
                    setRestoreNote("");
                    setRestoreTarget(row);
                  }}
                  className="inline-flex h-7 items-center gap-1 rounded-[var(--r-control)] border border-[var(--border-subtle)] bg-[var(--bg-elevated)] px-2 text-[11.5px] font-medium text-[var(--accent-brand)] hover:bg-[var(--surface-hover)]"
                >
                  <ClockCounterClockwise size={13} aria-hidden="true" />
                  <span>Restore Version</span>
                </button>
              )}
              {(row.objectKey || row.fileName) && (
                <button
                  type="button"
                  aria-label={`Copy path ${row.objectKey ?? row.fileName}`}
                  onClick={() => handleCopyPath(row.objectKey ?? row.fileName ?? "")}
                  className="inline-flex h-7 w-7 items-center justify-center rounded-[var(--r-control)] border border-[var(--border-subtle)] bg-[var(--bg-elevated)] text-[var(--ink-secondary)] hover:bg-[var(--surface-hover)] hover:text-[var(--ink-primary)]"
                >
                  {copiedKey === (row.objectKey ?? row.fileName) ? (
                    <Check size={13} className="text-[var(--accent-brand)]" aria-hidden="true" />
                  ) : (
                    <Copy size={13} aria-hidden="true" />
                  )}
                </button>
              )}
              <button
                type="button"
                aria-label={`Inspect ${row.semesterLabel}`}
                onClick={() => {
                  setSelectedId(row.id);
                  setExpandedDetailKeys({});
                }}
                className="inline-flex h-7 items-center gap-1 rounded-[var(--r-control)] border border-[var(--border-subtle)] bg-[var(--bg-elevated)] px-2 text-[11.5px] font-medium text-[var(--ink-secondary)] hover:bg-[var(--surface-hover)] hover:text-[var(--ink-primary)]"
              >
                <Eye size={13} aria-hidden="true" />
                <span>Inspect</span>
              </button>
            </div>
          )}
        />
      )}

      {hasActiveFilters && filteredItems.length > 0 && (
        <div className="flex justify-end">
          <button
            type="button"
            onClick={() => {
              setFilterTab("all");
              setOnlyWithXlsx(false);
              setSearchQuery("");
            }}
            className="text-[12px] font-medium text-[var(--ink-secondary)] underline underline-offset-2 hover:text-[var(--ink-primary)]"
          >
            Clear active filters
          </button>
        </div>
      )}
    </div>
  );

  const detailContent = selectedItem ? (
    <div className="space-y-5" data-testid="archive-inspector-body">
      {/* Status & Working Actions */}
      <div className="flex flex-wrap items-center gap-2">
        {selectedItem.isActive && <Badge tone="pine">Active Version</Badge>}
        <Badge tone={sourceBadgeProps(selectedItem.source).tone} mono>
          {selectedItem.source}
        </Badge>
        <Badge tone="neutral" mono>
          {selectedItem.category === "version"
            ? "Published Version"
            : selectedItem.category === "run"
              ? "Run History"
              : "Storage Only"}
        </Badge>
      </div>

      <div className="flex flex-wrap items-center gap-2">
        {((selectedItem.hasXlsx && selectedItem.objectKey) ||
          selectedItem.hasSnapshot) && (
          <Button
            variant="primary"
            size="sm"
            data-testid="archive-preview-grid-btn"
            onClick={() => setPreviewItem(selectedItem)}
          >
            <GridFour size={14} aria-hidden="true" />
            <span>Preview in 2D Grid</span>
          </Button>
        )}
        {selectedItem.hasXlsx && selectedItem.objectKey && (
          <Button
            variant="secondary"
            size="sm"
            disabled={downloadingId === selectedItem.id}
            onClick={() => void handleDownload(selectedItem)}
          >
            <DownloadSimple size={14} aria-hidden="true" />
            <span>
              {downloadingId === selectedItem.id
                ? "Downloading…"
                : "Download .xlsx"}
            </span>
          </Button>
        )}
        {selectedItem.category === "version" &&
          selectedItem.canRestore &&
          selectedItem.versionId && (
            <Button
              variant="secondary"
              size="sm"
              data-testid="archive-inspector-restore-btn"
              onClick={() => {
                setRestoreNote("");
                setRestoreTarget(selectedItem);
              }}
            >
              <ClockCounterClockwise size={14} aria-hidden="true" />
              <span>Restore Version</span>
            </Button>
          )}
        {(selectedItem.objectKey || selectedItem.fileName) && (
          <Button
            variant="secondary"
            size="sm"
            onClick={() =>
              handleCopyPath(selectedItem.objectKey ?? selectedItem.fileName ?? "")
            }
          >
            <Copy size={14} aria-hidden="true" />
            <span>Copy Filename / Path</span>
          </Button>
        )}
      </div>

      {/* Metadata Ledger */}
      <section className="divide-y divide-[var(--border-subtle)] rounded-[var(--r-card)] border border-[var(--border-subtle)] bg-[var(--bg-surface)]">
        <div className="flex items-center justify-between gap-3 px-3.5 py-2.5 text-[12.5px]">
          <span className="text-[var(--ink-muted)]">Recorded</span>
          <span className="font-mono-tabular text-[var(--ink-primary)]">
            {formatTimestamp(selectedItem.timestamp)}
          </span>
        </div>
        <div className="flex items-center justify-between gap-3 px-3.5 py-2.5 text-[12.5px]">
          <span className="text-[var(--ink-muted)]">Actor</span>
          <span className="text-[var(--ink-primary)]">{selectedItem.actorName}</span>
        </div>
        <div className="flex items-center justify-between gap-3 px-3.5 py-2.5 text-[12.5px]">
          <span className="text-[var(--ink-muted)]">Published Slots</span>
          <span className="font-mono-tabular text-[var(--ink-primary)]">
            {selectedItem.rowCount !== null ? selectedItem.rowCount : "—"}
          </span>
        </div>
        {selectedItem.objectKey && (
          <div className="flex items-center justify-between gap-3 px-3.5 py-2.5 text-[12.5px]">
            <span className="text-[var(--ink-muted)]">Storage Object</span>
            <span
              className="font-mono-tabular max-w-[240px] truncate text-[var(--ink-primary)]"
              title={selectedItem.objectKey}
            >
              {selectedItem.objectKey}
            </span>
          </div>
        )}
        {selectedItem.fileSizeBytes !== null && (
          <div className="flex items-center justify-between gap-3 px-3.5 py-2.5 text-[12.5px]">
            <span className="text-[var(--ink-muted)]">Workbook Size</span>
            <span className="font-mono-tabular text-[var(--ink-primary)]">
              {formatFileSize(selectedItem.fileSizeBytes)}
            </span>
          </div>
        )}
        {selectedItem.notes && (
          <div className="px-3.5 py-2.5 text-[12.5px]">
            <div className="text-[var(--ink-muted)]">Notes</div>
            <p className="mt-1 text-[var(--ink-primary)]">{selectedItem.notes}</p>
          </div>
        )}
      </section>

      {/* Solver / Import Stats */}
      <section className="space-y-2">
        <h3 className="text-[13px] font-semibold text-[var(--ink-primary)]">
          Run Metrics
        </h3>
        {statsEntries.length === 0 ? (
          <p className="text-[12.5px] text-[var(--ink-muted)]">
            No structured stats recorded for this entry.
          </p>
        ) : (
          <div className="divide-y divide-[var(--border-subtle)] rounded-[var(--r-card)] border border-[var(--border-subtle)] bg-[var(--bg-surface)]">
            {statsEntries.map((entry) => (
              <div
                key={entry.key}
                className="flex items-center justify-between gap-3 px-3.5 py-2 text-[12.5px]"
              >
                <span className="text-[var(--ink-secondary)]">{entry.label}</span>
                <span className="font-mono-tabular font-medium text-[var(--ink-primary)]">
                  {entry.value}
                </span>
              </div>
            ))}
          </div>
        )}
      </section>

      {/* Heterogeneous Validation Inspector */}
      <section className="space-y-2">
        <div className="flex items-center justify-between gap-2">
          <h3 className="text-[13px] font-semibold text-[var(--ink-primary)]">
            Validation Report
          </h3>
          {parsedValidation && parsedValidation.variant !== "empty" && (
            <Badge tone="neutral" mono>
              {parsedValidation.variant}
            </Badge>
          )}
        </div>

        {!parsedValidation || parsedValidation.variant === "empty" ? (
          <p className="text-[12.5px] text-[var(--ink-muted)]">
            No validation payload recorded for this entry.
          </p>
        ) : (
          <div className="space-y-3">
            {parsedValidation.ok === false && (
              <div
                role="alert"
                className="flex items-start gap-2 rounded-[var(--r-control)] border border-[var(--sem-conflict-border)] bg-[var(--sem-conflict-bg)] px-3 py-2.5 text-[12.5px] text-[var(--sem-conflict-ink)]"
              >
                <WarningCircle size={16} className="mt-0.5 shrink-0" aria-hidden="true" />
                <div>
                  <span className="font-semibold">Validation flagged issues</span>
                  {parsedValidation.issueCount > 0 && (
                    <span>
                      {" "}
                      ({parsedValidation.issueCount} total violation
                      {parsedValidation.issueCount === 1 ? "" : "s"} detected).
                    </span>
                  )}
                </div>
              </div>
            )}

            {parsedValidation.metrics.length > 0 && (
              <div className="divide-y divide-[var(--border-subtle)] rounded-[var(--r-card)] border border-[var(--border-subtle)] bg-[var(--bg-surface)]">
                {parsedValidation.metrics.map((metric) => (
                  <div
                    key={metric.key}
                    className={cn(
                      "flex items-center justify-between gap-3 px-3.5 py-2 text-[12.5px]",
                      metric.isIssue
                        ? "bg-[var(--sem-conflict-bg)]/60 text-[var(--sem-conflict-ink)]"
                        : "",
                    )}
                  >
                    <span
                      className={
                        metric.isIssue
                          ? "font-medium text-[var(--sem-conflict-ink)]"
                          : "text-[var(--ink-secondary)]"
                      }
                    >
                      {metric.label}
                    </span>
                    <span className="font-mono-tabular font-medium">
                      {String(metric.value)}
                    </span>
                  </div>
                ))}
              </div>
            )}

            {parsedValidation.details.length > 0 && (
              <div className="space-y-1.5">
                {parsedValidation.details.map((group) => {
                  const isOpen = Boolean(expandedDetailKeys[group.key]);
                  return (
                    <div
                      key={group.key}
                      className="overflow-hidden rounded-[var(--r-control)] border border-[var(--border-subtle)] bg-[var(--bg-surface)]"
                    >
                      <button
                        type="button"
                        aria-expanded={isOpen}
                        onClick={() =>
                          setExpandedDetailKeys((prev) => ({
                            ...prev,
                            [group.key]: !prev[group.key],
                          }))
                        }
                        className="flex w-full items-center justify-between gap-2 px-3 py-2 text-left text-[12.5px] font-medium text-[var(--ink-primary)] hover:bg-[var(--surface-hover)]"
                      >
                        <span className="flex items-center gap-1.5">
                          {isOpen ? (
                            <CaretDown size={13} aria-hidden="true" />
                          ) : (
                            <CaretRight size={13} aria-hidden="true" />
                          )}
                          <span>{group.label}</span>
                        </span>
                        <span className="font-mono-tabular text-[11.5px] text-[var(--ink-muted)]">
                          {group.items.length}
                        </span>
                      </button>
                      {isOpen && (
                        <div className="divide-y divide-[var(--border-subtle)] border-t border-[var(--border-subtle)] bg-[var(--bg-elevated)] px-3 py-2 text-[12px]">
                          {group.items.map((entry, idx) => (
                            <pre
                              key={idx}
                              className="font-mono-tabular overflow-x-auto py-1.5 text-[11.5px] whitespace-pre-wrap text-[var(--ink-secondary)]"
                            >
                              {JSON.stringify(entry, null, 2)}
                            </pre>
                          ))}
                        </div>
                      )}
                    </div>
                  );
                })}
              </div>
            )}
          </div>
        )}
      </section>

      {/* Dynamic Gate D Disclosure / Rollback Policy Footer */}
      <footer className="border-t border-[var(--border-subtle)] pt-3 text-[11.5px] leading-[1.5] text-[var(--ink-muted)]">
        {dataset?.items.some((item) => item.canRestore)
          ? "1-click PostgreSQL snapshot restore is active via public.restore_routine_version(), preserving prior versions with non-destructive archival."
          : "1-click PostgreSQL version rollback unlocks in Gate D (Phase 4A-2)."}
      </footer>
    </div>
  ) : null;

  if (previewItem) {
    const previewRows = archivePreviewQuery.data
      ? [
          ...archivePreviewQuery.data.rows,
          ...archivePreviewQuery.data.service_rows,
        ]
      : [];

    return (
      <div className="space-y-4" data-testid="archive-grid-preview-panel">
        {/* Historical Archive Preview — Read-Only Banner */}
        <section
          role="status"
          data-testid="archive-grid-preview-banner"
          className="no-print ledger-card flex flex-wrap items-center justify-between gap-3 border-l-[3px] border-l-[var(--accent-brand)] px-4 py-3"
        >
          <div className="min-w-0 space-y-1">
            <div className="flex flex-wrap items-center gap-2">
              <Badge tone="theory" mono>
                Historical Archive Preview — Read-Only
              </Badge>
              {archivePreviewQuery.data && (
                <>
                  <span className="font-mono-tabular text-[12px] text-[var(--ink-secondary)]">
                    {previewRows.length} slots
                  </span>
                  {archivePreviewQuery.data.validation.ok ? (
                    <Badge tone="pine" mono>
                      Pass
                    </Badge>
                  ) : (
                    <Badge tone="conflict" mono>
                      Flagged
                    </Badge>
                  )}
                </>
              )}
            </div>
            <div className="flex flex-wrap items-baseline gap-2">
              <h2 className="text-[15px] font-semibold text-[var(--ink-primary)]">
                {previewItem.semesterLabel}
              </h2>
              {(previewItem.fileName || previewItem.objectKey) && (
                <span className="font-mono-tabular truncate text-[12px] text-[var(--ink-muted)]">
                  {previewItem.fileName ?? previewItem.objectKey}
                </span>
              )}
            </div>
          </div>

          <div className="flex flex-wrap items-center gap-2">
            <Button
              type="button"
              variant="secondary"
              size="sm"
              data-testid="archive-back-to-ledger-btn"
              onClick={() => setPreviewItem(null)}
            >
              <ArrowLeft size={14} aria-hidden="true" />
              <span>Back to Archive Ledger</span>
            </Button>
            {previewItem.objectKey && (
              <Button
                type="button"
                variant="primary"
                size="sm"
                data-testid="archive-preview-download-btn"
                disabled={downloadingId === previewItem.id}
                onClick={() => void handleDownload(previewItem)}
              >
                <DownloadSimple size={14} aria-hidden="true" />
                <span>
                  {downloadingId === previewItem.id
                    ? "Downloading…"
                    : "Download .xlsx"}
                </span>
              </Button>
            )}
          </div>
        </section>

        {archivePreviewQuery.isLoading ? (
          <div
            role="status"
            data-testid="archive-preview-loading"
            className="ledger-card flex items-center gap-3 p-6 text-[13px] text-[var(--ink-secondary)]"
          >
            <CircleNotch
              size={18}
              className="shrink-0 animate-spin text-[var(--accent-brand)]"
              aria-hidden="true"
            />
            <span>
              Streaming{" "}
              <code className="font-mono-tabular">
                {previewItem.fileName ?? previewItem.objectKey}
              </code>{" "}
              from Storage and parsing 2D grid… (Render cold-start may take
              30–50 seconds).
            </span>
          </div>
        ) : archivePreviewQuery.isError ? (
          <div className="space-y-3">
            <LedgerErrorRecovery
              title="Unable to render 2D archive preview"
              message={
                archivePreviewQuery.error instanceof Error
                  ? archivePreviewQuery.error.message
                  : "Failed to download or parse the archived workbook."
              }
              onRetry={() => void archivePreviewQuery.refetch()}
            />
            {previewItem.objectKey && (
              <div className="flex justify-end">
                <Button
                  type="button"
                  variant="secondary"
                  size="sm"
                  onClick={() => void handleDownload(previewItem)}
                >
                  <DownloadSimple size={14} aria-hidden="true" />
                  <span>Download .xlsx Directly Instead</span>
                </Button>
              </div>
            )}
          </div>
        ) : (
          <AcademicTimetableMatrix
            overrideRows={previewRows}
            overrideSourceLabel={previewItem.semesterLabel}
            hideCandidateBanner
          />
        )}
      </div>
    );
  }

  return (
    <>
      <MasterDetailShell
        detailOpen={Boolean(selectedItem)}
        onRequestClose={() => setSelectedId(null)}
        detailTitle={selectedItem?.semesterLabel ?? "Archive Record"}
        detailSubtitle={selectedItem?.fileName ?? selectedItem?.id}
        master={masterContent}
        detail={detailContent}
      />

      <Dialog
        open={Boolean(restoreTarget)}
        onOpenChange={(open) => {
          if (!open && !restoreMutation.isPending) {
            setRestoreTarget(null);
          }
        }}
      >
        <DialogContent className="fixed left-1/2 top-1/2 w-[calc(100%-32px)] max-w-[460px] -translate-x-1/2 -translate-y-1/2 p-5">
          <div className="flex items-start justify-between gap-3">
            <div>
              <DialogTitle className="text-[17px] font-semibold text-[var(--ink-primary)]">
                Restore Archived Routine Version
              </DialogTitle>
              <DialogDescription className="mt-1 text-[13px] text-[var(--ink-secondary)]">
                Non-destructively archives the current active routine and publishes a new{" "}
                <code className="font-mono-tabular">rollback</code> version from{" "}
                <span className="font-semibold text-[var(--ink-primary)]">
                  {restoreTarget?.semesterLabel}
                </span>
                .
              </DialogDescription>
            </div>
            <button
              type="button"
              aria-label="Close restore modal"
              disabled={restoreMutation.isPending}
              onClick={() => setRestoreTarget(null)}
              className="flex h-7 w-7 items-center justify-center rounded-[5px] text-[var(--ink-secondary)] hover:bg-[var(--surface-hover)]"
            >
              <X size={15} aria-hidden="true" />
            </button>
          </div>

          <div className="mt-4 space-y-3 text-[12.5px]">
            <div className="rounded-[var(--r-control)] border border-[var(--border-subtle)] bg-[var(--bg-surface)] px-3.5 py-2.5">
              <div className="flex items-center justify-between">
                <span className="text-[var(--ink-muted)]">Snapshot Slots</span>
                <span className="font-mono-tabular font-semibold text-[var(--ink-primary)]">
                  {restoreTarget?.rowCount ?? restoreTarget?.snapshotRows?.length ?? "—"}
                </span>
              </div>
              <div className="mt-1 flex items-center justify-between">
                <span className="text-[var(--ink-muted)]">Original Timestamp</span>
                <span className="font-mono-tabular text-[var(--ink-secondary)]">
                  {formatTimestamp(restoreTarget?.timestamp ?? null)}
                </span>
              </div>
            </div>

            <label className="block space-y-1">
              <span className="text-[12px] font-medium text-[var(--ink-primary)]">
                Audit Note (optional)
              </span>
              <input
                type="text"
                value={restoreNote}
                onChange={(e) => setRestoreNote(e.target.value)}
                placeholder="Reason for restoring this historical snapshot..."
                className="h-9 w-full rounded-[var(--r-control)] border border-[var(--border-subtle)] bg-[var(--bg-elevated)] px-3 text-[13px] text-[var(--ink-primary)] outline-none focus:border-[var(--accent-brand)]"
              />
            </label>
          </div>

          <div className="mt-5 flex justify-end gap-2">
            <Button
              type="button"
              variant="secondary"
              size="md"
              disabled={restoreMutation.isPending}
              onClick={() => setRestoreTarget(null)}
            >
              Cancel
            </Button>
            <Button
              type="button"
              variant="primary"
              size="md"
              data-testid="confirm-archive-restore-btn"
              disabled={restoreMutation.isPending || !restoreTarget?.versionId}
              onClick={() => restoreTarget && restoreMutation.mutate(restoreTarget)}
            >
              <ClockCounterClockwise size={15} aria-hidden="true" />
              <span>
                {restoreMutation.isPending
                  ? "Restoring…"
                  : "Confirm Version Restore"}
              </span>
            </Button>
          </div>
        </DialogContent>
      </Dialog>
    </>
  );
}

export default RoutineArchiveTab;
