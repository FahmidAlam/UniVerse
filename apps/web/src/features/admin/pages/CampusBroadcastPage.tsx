import { zodResolver } from "@hookform/resolvers/zod";
import {
  ArrowsClockwise,
  Bell,
  Info,
  MagnifyingGlass,
  PaperPlaneTilt,
  Trash,
} from "@phosphor-icons/react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useMemo, useRef, useState } from "react";
import { useForm } from "react-hook-form";
import { toast } from "sonner";
import { z } from "zod";
import {
  LedgerEmptyState,
  LedgerErrorRecovery,
  LedgerFilterEmpty,
  LedgerTableSkeleton,
} from "@/components/ui/AsyncStates";
import { Badge } from "@/components/ui/Badge";
import { Button } from "@/components/ui/Button";
import { ConfirmDialog } from "@/components/ui/ConfirmDialog";
import {
  DataLedgerTable,
  type BulkActionItem,
  type DataLedgerColumn,
} from "@/components/ui/DataLedgerTable";
import { useWorkspaceShortcuts } from "@/core/hooks/useWorkspaceShortcuts";
import {
  createBroadcast,
  deleteBroadcasts,
  fetchBroadcastHistory,
  formatBroadcastAudienceLabel,
  NOTIFICATION_TYPE_LABELS,
  NOTIFICATION_TYPES,
  type BroadcastRecord,
  type NotificationType,
} from "@/features/admin/services/broadcastService";
import { useAuth } from "@/features/auth/AuthProvider";
import { cn } from "@/lib/utils";

type BroadcastTab = "compose" | "history";
type TypeFilter = "all" | NotificationType;

const broadcastSchema = z.object({
  title: z
    .string()
    .trim()
    .min(3, "Enter a clear broadcast title (3+ characters).")
    .max(140, "Broadcast title cannot exceed 140 characters."),
  body: z
    .string()
    .trim()
    .min(5, "Enter the announcement message body.")
    .max(1000, "Announcement message cannot exceed 1000 characters."),
  type: z.enum(NOTIFICATION_TYPES),
  target_role: z.enum(["all", "student", "teacher", "admin"]),
  target_batch: z.string().trim().max(24).optional(),
  target_section: z.string().trim().max(12).optional(),
});

type BroadcastFormValues = z.infer<typeof broadcastSchema>;

function notifBadgeTone(
  type: NotificationType,
): "conflict" | "joint" | "lab" | "theory" | "neutral" | "pine" {
  switch (type) {
    case "class_cancel":
      return "conflict";
    case "room_change":
      return "joint";
    case "exam":
      return "pine";
    case "test_reminder":
      return "theory";
    case "assignment":
      return "lab";
    default:
      return "neutral";
  }
}

export function CampusBroadcastPage() {
  const { isDevPreview, profile } = useAuth();
  const queryClient = useQueryClient();
  const searchInputRef = useRef<HTMLInputElement>(null);

  const [activeTab, setActiveTab] = useState<BroadcastTab>("compose");
  const [search, setSearch] = useState("");
  const [typeFilter, setTypeFilter] = useState<TypeFilter>("all");
  const [pendingSendValues, setPendingSendValues] =
    useState<BroadcastFormValues | null>(null);
  const [deleteIds, setDeleteIds] = useState<string[] | null>(null);

  const form = useForm<BroadcastFormValues>({
    resolver: zodResolver(broadcastSchema),
    defaultValues: {
      title: "",
      body: "",
      type: "university",
      target_role: "all",
      target_batch: "",
      target_section: "",
    },
  });

  const {
    data: history = [],
    isLoading,
    isFetching,
    isError,
    error,
    dataUpdatedAt,
    refetch,
  } = useQuery({
    queryKey: ["admin-broadcast-history", isDevPreview],
    queryFn: () => fetchBroadcastHistory(isDevPreview),
    retry: false,
  });

  useWorkspaceShortcuts({
    searchInputRef,
    onEscape: () => {
      if (pendingSendValues) setPendingSendValues(null);
      if (deleteIds) setDeleteIds(null);
    },
  });

  const publishMutation = useMutation({
    mutationFn: (values: BroadcastFormValues) =>
      createBroadcast(
        {
          title: values.title,
          body: values.body,
          type: values.type,
          target_role: values.target_role,
          target_batch: values.target_batch,
          target_section: values.target_section,
        },
        profile?.id ?? null,
        isDevPreview,
      ),
    onSuccess: (created) => {
      void queryClient.invalidateQueries({
        queryKey: ["admin-broadcast-history"],
      });
      void queryClient.invalidateQueries({
        queryKey: ["admin-dashboard-counts"],
      });
      setPendingSendValues(null);
      form.reset({
        title: "",
        body: "",
        type: "university",
        target_role: "all",
        target_batch: "",
        target_section: "",
      });
      toast.success(`Published notice: ${created.title}`);
      setActiveTab("history");
    },
    onError: (err) => {
      setPendingSendValues(null);
      toast.error("Failed to send campus broadcast", {
        description:
          err instanceof Error ? err.message : "Database insert failed.",
      });
    },
  });

  const deleteMutation = useMutation({
    mutationFn: (ids: string[]) => deleteBroadcasts(ids, isDevPreview),
    onSuccess: (_d, ids) => {
      void queryClient.invalidateQueries({
        queryKey: ["admin-broadcast-history"],
      });
      void queryClient.invalidateQueries({
        queryKey: ["admin-dashboard-counts"],
      });
      setDeleteIds(null);
      toast.success(`Deleted ${ids.length} announcement(s)`);
    },
    onError: (err) => {
      toast.error("Could not remove broadcast", {
        description:
          err instanceof Error ? err.message : "Database delete failed.",
      });
    },
  });

  const typeCounts = useMemo(() => {
    const map: Record<string, number> = { all: history.length };
    for (const t of NOTIFICATION_TYPES) map[t] = 0;
    for (const row of history) {
      map[row.type] = (map[row.type] ?? 0) + 1;
    }
    return map;
  }, [history]);

  const filteredHistory = useMemo(() => {
    const q = search.trim().toLowerCase();
    return history.filter((row) => {
      if (typeFilter !== "all" && row.type !== typeFilter) return false;
      if (!q) return true;
      return (
        row.title.toLowerCase().includes(q) ||
        row.body.toLowerCase().includes(q) ||
        (row.target_batch ?? "").toLowerCase().includes(q)
      );
    });
  }, [history, typeFilter, search]);

  const columns = useMemo<DataLedgerColumn<BroadcastRecord>[]>(
    () => [
      {
        id: "title",
        header: "Announcement",
        accessor: (r) => r.title,
        cell: (r) => (
          <div className="min-w-0 max-w-[420px]">
            <div className="truncate font-medium text-[var(--ink-primary)]">
              {r.title}
            </div>
            <div className="truncate text-[12px] text-[var(--ink-muted)]">
              {r.body}
            </div>
          </div>
        ),
      },
      {
        id: "type",
        header: "Type",
        accessor: (r) => r.type,
        cell: (r) => (
          <Badge tone={notifBadgeTone(r.type)}>
            {NOTIFICATION_TYPE_LABELS[r.type] ?? r.type}
          </Badge>
        ),
      },
      {
        id: "audience",
        header: "Audience",
        accessor: (r) => formatBroadcastAudienceLabel(r),
        cell: (r) => (
          <span className="font-mono-tabular text-[12px] text-[var(--ink-secondary)]">
            {formatBroadcastAudienceLabel(r)}
          </span>
        ),
      },
      {
        id: "created_at",
        header: "Published",
        accessor: (r) => r.created_at,
        align: "right",
        cell: (r) => (
          <span className="font-mono-tabular text-[12px] text-[var(--ink-muted)]">
            {new Date(r.created_at).toLocaleDateString()}
          </span>
        ),
      },
    ],
    [],
  );

  const bulkActions = useMemo<BulkActionItem[]>(
    () => [
      {
        id: "delete",
        label: "Delete Selected",
        tone: "destructive",
        disabled: deleteMutation.isPending,
        onAction: (ids) => setDeleteIds(ids),
      },
    ],
    [deleteMutation.isPending],
  );

  const lastCheckedStr = dataUpdatedAt
    ? new Date(dataUpdatedAt).toLocaleTimeString()
    : "—";

  return (
    <div className="space-y-4">
      <header className="flex flex-wrap items-end justify-between gap-4 border-b border-[var(--border-subtle)] pb-4">
        <div>
          <h1 className="font-editorial text-[26px] font-semibold tracking-[-0.02em] text-[var(--ink-primary)]">
            Campus Broadcasts
          </h1>
          <p className="mt-1 max-w-[68ch] text-[13.5px] leading-[1.55] text-[var(--ink-secondary)]">
            Compose targeted notices to student cohorts or faculty and audit sent
            campus announcements.
          </p>
        </div>

        <div className="flex items-center gap-3">
          <span className="font-mono-tabular text-[12px] text-[var(--ink-muted)]">
            Last checked {lastCheckedStr}
          </span>
          <Button
            variant="secondary"
            size="sm"
            disabled={isFetching}
            onClick={() => void refetch()}
          >
            <ArrowsClockwise
              size={14}
              className={cn(isFetching && "animate-spin")}
              aria-hidden="true"
            />
            <span>Refresh</span>
          </Button>
        </div>
      </header>

      <div
        role="tablist"
        aria-label="Campus broadcast views"
        className="flex flex-wrap gap-1.5 border-b border-[var(--border-subtle)] pb-3"
      >
        <button
          type="button"
          role="tab"
          aria-selected={activeTab === "compose"}
          onClick={() => setActiveTab("compose")}
          className={cn(
            "inline-flex h-9 items-center gap-2 rounded-[var(--r-control)] border px-3 text-[13px] font-medium transition-colors",
            activeTab === "compose"
              ? "border-[var(--ink-primary)] bg-[var(--ink-primary)] text-[var(--bg-elevated)]"
              : "border-[var(--border-subtle)] bg-[var(--bg-elevated)] text-[var(--ink-secondary)] hover:bg-[var(--surface-hover)]",
          )}
        >
          <PaperPlaneTilt size={15} aria-hidden="true" />
          <span>Compose Broadcast</span>
        </button>
        <button
          type="button"
          role="tab"
          aria-selected={activeTab === "history"}
          onClick={() => setActiveTab("history")}
          className={cn(
            "inline-flex h-9 items-center gap-2 rounded-[var(--r-control)] border px-3 text-[13px] font-medium transition-colors",
            activeTab === "history"
              ? "border-[var(--ink-primary)] bg-[var(--ink-primary)] text-[var(--bg-elevated)]"
              : "border-[var(--border-subtle)] bg-[var(--bg-elevated)] text-[var(--ink-secondary)] hover:bg-[var(--surface-hover)]",
          )}
        >
          <Bell size={15} aria-hidden="true" />
          <span>Sent History ({history.length})</span>
        </button>
      </div>

      {activeTab === "compose" ? (
        <div className="grid gap-5 lg:grid-cols-[minmax(0,1.4fr)_minmax(280px,0.9fr)]">
          <form
            onSubmit={form.handleSubmit((vals) => setPendingSendValues(vals))}
            className="ledger-card space-y-4 p-5"
            noValidate
          >
            <div>
              <label
                htmlFor="bc-title"
                className="mb-1.5 block text-[12.5px] font-medium text-[var(--ink-primary)]"
              >
                Announcement Headline
              </label>
              <input
                id="bc-title"
                type="text"
                placeholder="e.g. CSE-3101 moved to RAB-302 today"
                {...form.register("title")}
                className="h-[40px] w-full rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-3 text-[13.5px]"
              />
              {form.formState.errors.title && (
                <p className="mt-1 text-[12px] text-[var(--sem-conflict-ink)]">
                  {form.formState.errors.title.message}
                </p>
              )}
            </div>

            <div className="grid gap-3 sm:grid-cols-2">
              <div>
                <label
                  htmlFor="bc-type"
                  className="mb-1.5 block text-[12.5px] font-medium text-[var(--ink-primary)]"
                >
                  Category
                </label>
                <select
                  id="bc-type"
                  {...form.register("type")}
                  className="h-[40px] w-full rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-3 text-[13.5px]"
                >
                  {NOTIFICATION_TYPES.map((t) => (
                    <option key={t} value={t}>
                      {NOTIFICATION_TYPE_LABELS[t]}
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label
                  htmlFor="bc-role"
                  className="mb-1.5 block text-[12.5px] font-medium text-[var(--ink-primary)]"
                >
                  Target Role
                </label>
                <select
                  id="bc-role"
                  {...form.register("target_role")}
                  className="h-[40px] w-full rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-3 text-[13.5px]"
                >
                  <option value="all">All Students &amp; Teachers</option>
                  <option value="student">Students Only</option>
                  <option value="teacher">Faculty Only</option>
                  <option value="admin">Administrators Only</option>
                </select>
              </div>
            </div>

            <div className="grid gap-3 sm:grid-cols-2">
              <div>
                <label
                  htmlFor="bc-batch"
                  className="mb-1.5 block text-[12.5px] font-medium text-[var(--ink-primary)]"
                >
                  Batch Scope (optional)
                </label>
                <input
                  id="bc-batch"
                  type="text"
                  placeholder="Blank = all batches (e.g. 60)"
                  {...form.register("target_batch")}
                  className="font-mono-tabular h-[40px] w-full rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-3 text-[13.5px]"
                />
              </div>

              <div>
                <label
                  htmlFor="bc-section"
                  className="mb-1.5 block text-[12.5px] font-medium text-[var(--ink-primary)]"
                >
                  Section Scope (optional)
                </label>
                <input
                  id="bc-section"
                  type="text"
                  placeholder="Blank = all sections (e.g. B)"
                  {...form.register("target_section")}
                  className="font-mono-tabular h-[40px] w-full rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-3 text-[13.5px] uppercase"
                />
              </div>
            </div>

            <div>
              <label
                htmlFor="bc-body"
                className="mb-1.5 block text-[12.5px] font-medium text-[var(--ink-primary)]"
              >
                Message Body
              </label>
              <textarea
                id="bc-body"
                rows={4}
                placeholder="Write concise instructions delivered to student and faculty mobile alerts..."
                {...form.register("body")}
                className="w-full rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] p-3 text-[13.5px]"
              />
              {form.formState.errors.body && (
                <p className="mt-1 text-[12px] text-[var(--sem-conflict-ink)]">
                  {form.formState.errors.body.message}
                </p>
              )}
            </div>

            <div className="flex justify-end">
              <Button
                type="submit"
                variant="primary"
                size="md"
                disabled={publishMutation.isPending}
              >
                <PaperPlaneTilt size={15} aria-hidden="true" />
                <span>Review &amp; Publish Notice</span>
              </Button>
            </div>
          </form>

          <aside className="space-y-3">
            <div className="ledger-card space-y-2.5 p-4 text-[12.5px] text-[var(--ink-secondary)]">
              <div className="flex items-center gap-2 font-semibold text-[var(--ink-primary)]">
                <Info size={16} className="shrink-0 text-[var(--accent-pine)]" aria-hidden="true" />
                <span>Mobile Audience Matching</span>
              </div>
              <p className="leading-[1.55]">
                Leaving Role on All, Batch blank, or Section blank transmits{" "}
                <code className="font-mono-tabular">null</code> filters so Flutter
                Android and iOS clients match every cohort cleanly.
              </p>
              <p className="leading-[1.55]">
                History refreshes on publish, window focus, and manual Refresh
                (broadcasts are not subscribed on realtime).
              </p>
            </div>
          </aside>
        </div>
      ) : (
        <div className="space-y-4">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <div
              role="group"
              aria-label="Filter announcements by type"
              className="flex flex-wrap items-center gap-1.5"
            >
              <button
                type="button"
                aria-pressed={typeFilter === "all"}
                onClick={() => setTypeFilter("all")}
                className={cn(
                  "inline-flex h-[36px] items-center gap-1.5 rounded-[var(--r-control)] border px-3 font-mono-tabular text-[12px]",
                  typeFilter === "all"
                    ? "border-[var(--accent-pine)] bg-[var(--accent-pine-soft)] font-semibold text-[var(--accent-pine)]"
                    : "border-[var(--border-control)] bg-[var(--bg-elevated)] text-[var(--ink-secondary)]",
                )}
              >
                <span>All ({typeCounts.all ?? 0})</span>
              </button>
              {NOTIFICATION_TYPES.map((t) => (
                <button
                  key={t}
                  type="button"
                  aria-pressed={typeFilter === t}
                  onClick={() => setTypeFilter(t)}
                  className={cn(
                    "inline-flex h-[36px] items-center gap-1.5 rounded-[var(--r-control)] border px-2.5 font-mono-tabular text-[12px]",
                    typeFilter === t
                      ? "border-[var(--accent-pine)] bg-[var(--accent-pine-soft)] font-semibold text-[var(--accent-pine)]"
                      : "border-[var(--border-control)] bg-[var(--bg-elevated)] text-[var(--ink-secondary)]",
                  )}
                >
                  <span>
                    {NOTIFICATION_TYPE_LABELS[t]} ({typeCounts[t] ?? 0})
                  </span>
                </button>
              ))}
            </div>

            <div className="relative w-full sm:w-[260px]">
              <MagnifyingGlass
                size={15}
                className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-[var(--ink-muted)]"
                aria-hidden="true"
              />
              <input
                ref={searchInputRef}
                type="search"
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                placeholder="Search history... (/)"
                aria-label="Search broadcast history"
                className="h-[36px] w-full rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] pl-8 pr-3 text-[13px]"
              />
            </div>
          </div>

          {isLoading ? (
            <LedgerTableSkeleton label="Loading broadcast history" />
          ) : isError ? (
            <LedgerErrorRecovery
              title="Could not load broadcast history"
              message={
                error instanceof Error ? error.message : "Supabase query failed."
              }
              onRetry={() => void refetch()}
            />
          ) : history.length === 0 ? (
            <LedgerEmptyState
              icon={<Bell size={20} aria-hidden="true" />}
              title="No campus announcements sent yet"
              description="Publish your first schedule change, classroom relocation, or institutional notice from Compose Broadcast."
              actionLabel="Compose Notice"
              onAction={() => setActiveTab("compose")}
            />
          ) : filteredHistory.length === 0 ? (
            <LedgerFilterEmpty
              message="No announcements match your active type filter or search."
              onReset={() => {
                setSearch("");
                setTypeFilter("all");
              }}
            />
          ) : (
            <DataLedgerTable
              data={filteredHistory}
              columns={columns}
              getRowId={(r) => r.id}
              bulkActions={bulkActions}
              ariaLabel="Sent broadcast announcements"
              renderRowActions={(r) => (
                <button
                  type="button"
                  aria-label={`Delete announcement ${r.title}`}
                  onClick={() => setDeleteIds([r.id])}
                  className="flex h-7 w-7 items-center justify-center rounded-[5px] text-[var(--sem-conflict-ink)] hover:bg-[var(--sem-conflict-bg)]"
                >
                  <Trash size={14} aria-hidden="true" />
                </button>
              )}
            />
          )}
        </div>
      )}

      {/* Pre-Send Audience Confirmation Dialog */}
      <ConfirmDialog
        open={pendingSendValues !== null}
        onOpenChange={(open) => {
          if (!open) setPendingSendValues(null);
        }}
        title="Publish campus broadcast?"
        description={
          pendingSendValues
            ? `Audience: ${formatBroadcastAudienceLabel({
                target_role:
                  pendingSendValues.target_role === "all"
                    ? null
                    : pendingSendValues.target_role,
                target_batch: pendingSendValues.target_batch?.trim() || null,
                target_section:
                  pendingSendValues.target_section?.trim().toUpperCase() || null,
              })}. Inserting this notice triggers mobile notification delivery for matching recipients.`
            : ""
        }
        confirmLabel="Publish Now"
        isPending={publishMutation.isPending}
        onConfirm={() => {
          if (pendingSendValues) publishMutation.mutate(pendingSendValues);
        }}
      />

      <ConfirmDialog
        open={deleteIds !== null}
        onOpenChange={(open) => {
          if (!open) setDeleteIds(null);
        }}
        title={`Delete ${deleteIds?.length ?? 0} announcement(s)?`}
        description="Removes the announcement record from campus history."
        confirmLabel="Delete Notices"
        tone="destructive"
        isPending={deleteMutation.isPending}
        onConfirm={() => {
          if (deleteIds) deleteMutation.mutate(deleteIds);
        }}
      />
    </div>
  );
}
