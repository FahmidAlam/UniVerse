import {
  CaretDown,
  CaretUp,
  CaretUpDown,
  Check,
  Copy,
  X,
} from "@phosphor-icons/react";
import {
  createSortedRowModel,
  rowSelectionFeature,
  rowSortingFeature,
  sortFn_alphanumeric,
  sortFn_text,
  tableFeatures,
  useTable,
  type ColumnDef,
  type Row,
  type RowData,
  type RowSelectionState,
  type SortingState,
} from "@tanstack/react-table";
import { useVirtualizer } from "@tanstack/react-virtual";
import { AnimatePresence, motion, useReducedMotion } from "motion/react";
import { useMemo, useRef, useState, type ReactNode } from "react";
import { toast } from "sonner";
import { Button } from "@/components/ui/Button";
import { useHorizontalScrollCue } from "@/core/hooks/useHorizontalScrollCue";
import { cn } from "@/lib/utils";

const LEDGER_FEATURES = tableFeatures({
  rowSelectionFeature,
  rowSortingFeature,
  sortedRowModel: createSortedRowModel(),
  sortFns: {
    alphanumeric: sortFn_alphanumeric,
    text: sortFn_text,
  },
});

export interface DataLedgerColumn<T extends RowData> {
  id: string;
  header: string;
  accessor: (row: T) => string | number | boolean | null | undefined;
  cell: (row: T, context: { isInactive: boolean }) => ReactNode;
  sortable?: boolean;
  align?: "left" | "right";
  widthClass?: string;
}

export interface BulkActionItem {
  id: string;
  label: string;
  tone?: "secondary" | "destructive" | "pine";
  disabled?: boolean;
  onAction: (selectedIds: string[]) => void;
}

interface DataLedgerTableProps<T extends RowData> {
  data: readonly T[];
  columns: readonly DataLedgerColumn<T>[];
  getRowId: (row: T) => string;
  selectedRowId?: string | null;
  onRowClick?: (row: T) => void;
  isInactiveRow?: (row: T) => boolean;
  renderRowActions?: (row: T) => ReactNode;
  bulkActions?: readonly BulkActionItem[];
  virtualizeThreshold?: number;
  ariaLabel: string;
}

export function HoverCopyButton({
  value,
  label,
}: {
  value: string;
  label: string;
}) {
  const [copied, setCopied] = useState(false);

  return (
    <button
      type="button"
      aria-label={`Copy ${label}: ${value}`}
      onClick={(e) => {
        e.stopPropagation();
        if (navigator.clipboard?.writeText) {
          void navigator.clipboard.writeText(value);
        }
        setCopied(true);
        toast.success(`Copied ${value}`);
        window.setTimeout(() => setCopied(false), 1400);
      }}
      className="row-reveal-action inline-flex h-6 w-6 shrink-0 items-center justify-center rounded-[4px] border border-transparent text-[var(--ink-muted)] hover:border-[var(--border-subtle)] hover:bg-[var(--bg-elevated)] hover:text-[var(--ink-primary)]"
    >
      {copied ? (
        <Check size={13} className="text-[var(--accent-brand)]" aria-hidden="true" />
      ) : (
        <Copy size={13} aria-hidden="true" />
      )}
    </button>
  );
}

export function DataLedgerTable<T extends RowData>({
  data,
  columns,
  getRowId,
  selectedRowId,
  onRowClick,
  isInactiveRow,
  renderRowActions,
  bulkActions = [],
  virtualizeThreshold = 40,
  ariaLabel,
}: DataLedgerTableProps<T>) {
  const prefersReducedMotion = useReducedMotion() ?? false;
  const [sorting, setSorting] = useState<SortingState>([]);
  const [rowSelection, setRowSelection] = useState<RowSelectionState>({});
  const scrollParentRef = useRef<HTMLDivElement>(null);
  const {
    hasRightOverflow,
    onScroll: handleTableScroll,
    maskStyle: scrollMaskStyle,
  } = useHorizontalScrollCue(scrollParentRef, [data.length, columns.length]);

  const mutableData = useMemo(() => [...data], [data]);

  const tableColumns = useMemo<ColumnDef<typeof LEDGER_FEATURES, T, unknown>[]>(() => {
    const defs: ColumnDef<typeof LEDGER_FEATURES, T, unknown>[] = [];

    if (bulkActions.length > 0) {
      defs.push({
        id: "__select__",
        header: ({ table }) => (
          <input
            type="checkbox"
            aria-label="Select all visible rows"
            checked={table.getIsAllRowsSelected()}
            onChange={table.getToggleAllRowsSelectedHandler()}
            className="h-4 w-4 cursor-pointer accent-[var(--accent-brand)]"
          />
        ),
        cell: ({ row }) => (
          <input
            type="checkbox"
            aria-label={`Select row ${getRowId(row.original)}`}
            checked={row.getIsSelected()}
            onChange={row.getToggleSelectedHandler()}
            onClick={(e) => e.stopPropagation()}
            className="h-4 w-4 cursor-pointer accent-[var(--accent-brand)]"
          />
        ),
      });
    }

    for (const col of columns) {
      defs.push({
        id: col.id,
        accessorFn: (row) => col.accessor(row) ?? "",
        enableSorting: col.sortable ?? true,
        header: () => col.header,
        cell: ({ row }) => {
          const inactive = isInactiveRow ? isInactiveRow(row.original) : false;
          return col.cell(row.original, { isInactive: inactive });
        },
      });
    }

    if (renderRowActions) {
      defs.push({
        id: "__actions__",
        enableSorting: false,
        header: () => <span className="sr-only">Actions</span>,
        cell: ({ row }) => (
          <div
            className="row-reveal-action flex items-center justify-end gap-1"
            onClick={(e) => e.stopPropagation()}
          >
            {renderRowActions(row.original)}
          </div>
        ),
      });
    }

    return defs;
  }, [bulkActions.length, columns, getRowId, isInactiveRow, renderRowActions]);

  const table = useTable<
    typeof LEDGER_FEATURES,
    T,
    { sorting: SortingState; rowSelection: RowSelectionState }
  >(
    {
      features: LEDGER_FEATURES,
      data: mutableData,
      columns: tableColumns,
      getRowId,
      state: {
        sorting,
        rowSelection,
      },
      onSortingChange: setSorting,
      onRowSelectionChange: setRowSelection,
    },
    (state) => ({
      sorting: state.sorting,
      rowSelection: state.rowSelection,
    }),
  );

  const rows = table.getRowModel().rows;
  const shouldVirtualize = rows.length > virtualizeThreshold;

  const rowVirtualizer = useVirtualizer({
    count: shouldVirtualize ? rows.length : 0,
    getScrollElement: () => scrollParentRef.current,
    estimateSize: () => 52,
    overscan: 8,
  });

  const selectedIds = useMemo(
    () =>
      Object.entries(rowSelection)
        .filter(([, checked]) => Boolean(checked))
        .map(([id]) => id)
        .filter((id) => mutableData.some((item) => getRowId(item) === id)),
    [getRowId, mutableData, rowSelection],
  );

  const renderRow = (row: Row<typeof LEDGER_FEATURES, T>) => {
    const id = getRowId(row.original);
    const isActiveSelection = selectedRowId === id;
    const isInactive = isInactiveRow ? isInactiveRow(row.original) : false;

    return (
      <tr
        key={id}
        data-row-id={id}
        data-inactive={isInactive ? "true" : "false"}
        onClick={onRowClick ? () => onRowClick(row.original) : undefined}
        className={cn(
          "group transition-colors",
          onRowClick ? "cursor-pointer" : undefined,
          isActiveSelection
            ? "bg-[var(--accent-brand-soft)]/70"
            : "hover:bg-[var(--surface-hover)]",
          isInactive ? "text-[var(--ink-muted)]" : "text-[var(--ink-primary)]",
        )}
      >
        {row.getAllCells().map((cell) => {
          const colMeta = columns.find((c) => c.id === cell.column.id);
          return (
            <td
              key={cell.id}
              className={cn(
                "px-3.5 py-3 align-middle text-[13.5px]",
                cell.column.id === "__select__" ? "w-[40px] pr-1" : undefined,
                cell.column.id === "__actions__" ? "w-[1%] whitespace-nowrap" : undefined,
                colMeta?.align === "right" ? "text-right font-mono-tabular" : undefined,
                colMeta?.widthClass,
              )}
            >
              <table.FlexRender cell={cell} />
            </td>
          );
        })}
      </tr>
    );
  };

  return (
    <div className="flex flex-col gap-3">
      {/* Contextual Multi-Select Bulk Action Bar */}
      <AnimatePresence initial={false}>
        {selectedIds.length > 0 && bulkActions.length > 0 && (
          <motion.div
            role="region"
            aria-label="Bulk selection actions"
            data-testid="bulk-action-bar"
            initial={prefersReducedMotion ? false : { opacity: 0, y: -6 }}
            animate={{ opacity: 1, y: 0 }}
            exit={prefersReducedMotion ? undefined : { opacity: 0, y: -4 }}
            transition={{ duration: 0.16, ease: [0.16, 1, 0.3, 1] }}
            className="flex flex-wrap items-center justify-between gap-2.5 rounded-[var(--r-card)] border border-[var(--accent-brand-border)] bg-[var(--accent-brand-soft)] px-4 py-2.5"
          >
            <div className="flex items-center gap-2.5 text-[12.5px] font-semibold text-[var(--accent-brand)]">
              <span className="font-mono-tabular">{selectedIds.length} selected</span>
              <button
                type="button"
                onClick={() => setRowSelection({})}
                className="inline-flex items-center gap-1 rounded-[4px] px-1.5 py-0.5 text-[11.5px] font-medium text-[var(--ink-secondary)] hover:bg-[var(--bg-elevated)] hover:text-[var(--ink-primary)]"
              >
                <X size={12} aria-hidden="true" />
                <span>Clear</span>
              </button>
            </div>

            <div className="flex flex-wrap items-center gap-2">
              {bulkActions.map((act) => (
                <Button
                  key={act.id}
                  size="sm"
                  variant={act.tone ?? "secondary"}
                  disabled={act.disabled}
                  onClick={() => act.onAction(selectedIds)}
                >
                  {act.label}
                </Button>
              ))}
            </div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Ledger Data Table */}
      <div className="ledger-card overflow-hidden">
        <div
          ref={scrollParentRef}
          onScroll={handleTableScroll}
          data-scroll-cue-right={hasRightOverflow ? "true" : "false"}
          style={scrollMaskStyle}
          className={cn(
            "overflow-x-auto",
            shouldVirtualize ? "max-h-[560px] overflow-y-auto" : undefined,
          )}
        >
          <table aria-label={ariaLabel} className="w-full border-collapse text-left">
            <thead className="sticky top-0 z-10 border-b border-[var(--border-subtle)] bg-[var(--bg-canvas)]/95 backdrop-blur-xs">
              {table.getHeaderGroups().map((headerGroup) => (
                <tr key={headerGroup.id}>
                  {headerGroup.headers.map((header) => {
                    const colMeta = columns.find((c) => c.id === header.column.id);
                    const canSort = header.column.getCanSort();
                    const sorted = header.column.getIsSorted();
                    return (
                      <th
                        key={header.id}
                        scope="col"
                        className={cn(
                          "px-3.5 py-2.5 text-[11.5px] font-semibold tracking-[0.04em] text-[var(--ink-secondary)] uppercase whitespace-nowrap",
                          header.column.id === "__select__" ? "w-[40px] pr-1" : undefined,
                          colMeta?.align === "right" ? "text-right" : undefined,
                        )}
                      >
                        {header.isPlaceholder ? null : canSort ? (
                          <button
                            type="button"
                            onClick={header.column.getToggleSortingHandler()}
                            className={cn(
                              "inline-flex items-center gap-1 font-semibold uppercase hover:text-[var(--ink-primary)]",
                              colMeta?.align === "right" ? "ml-auto" : undefined,
                            )}
                          >
                            <table.FlexRender header={header} />
                            {sorted === "asc" ? (
                              <CaretUp size={12} aria-hidden="true" />
                            ) : sorted === "desc" ? (
                              <CaretDown size={12} aria-hidden="true" />
                            ) : (
                              <CaretUpDown
                                size={12}
                                className="opacity-55"
                                aria-hidden="true"
                              />
                            )}
                          </button>
                        ) : (
                          <table.FlexRender header={header} />
                        )}
                      </th>
                    );
                  })}
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
                    return row ? renderRow(row) : null;
                  })}
                  {rowVirtualizer.getVirtualItems().length > 0 && (
                    <tr aria-hidden="true">
                      <td
                        colSpan={tableColumns.length}
                        style={{
                          height: `${Math.max(
                            0,
                            rowVirtualizer.getTotalSize() -
                              (rowVirtualizer.getVirtualItems().at(-1)?.end ?? 0),
                          )}px`,
                        }}
                      />
                    </tr>
                  )}
                </>
              ) : (
                rows.map((row) => renderRow(row))
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
