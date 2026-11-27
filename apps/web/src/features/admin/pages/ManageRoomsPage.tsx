import { zodResolver } from "@hookform/resolvers/zod";
import {
  ArrowRight,
  Buildings,
  Desktop,
  Info,
  MagnifyingGlass,
  PencilSimple,
  Plus,
  Trash,
} from "@phosphor-icons/react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useMemo, useRef, useState } from "react";
import { Controller, useForm } from "react-hook-form";
import { Link } from "react-router-dom";
import { toast } from "sonner";
import { z } from "zod";
import {
  LedgerEmptyState,
  LedgerErrorRecovery,
  LedgerFilterEmpty,
  LedgerTableSkeleton,
  StagedFeatureNotice,
} from "@/components/ui/AsyncStates";
import { Badge } from "@/components/ui/Badge";
import { Button } from "@/components/ui/Button";
import { ConfirmDialog } from "@/components/ui/ConfirmDialog";
import {
  DataLedgerTable,
  HoverCopyButton,
  type BulkActionItem,
  type DataLedgerColumn,
} from "@/components/ui/DataLedgerTable";
import { MasterDetailShell } from "@/components/ui/MasterDetailShell";
import { StickyDirtyBar } from "@/components/ui/StickyDirtyBar";
import { Switch } from "@/components/ui/Switch";
import { useWorkspaceShortcuts } from "@/core/hooks/useWorkspaceShortcuts";
import {
  DaySlotMatrixPicker,
  type SlotMatrixEntry,
} from "@/features/admin/components/DaySlotMatrixPicker";
import { INSTITUTIONAL_DEPARTMENTS } from "@/features/admin/services/facultyService";
import {
  bulkSetRoomsActive,
  createRoom,
  deleteRooms,
  fetchRooms,
  inferRoomPoolRole,
  isRoomExtendedSchemaLive,
  ROOM_POOL_ROLE_LABELS,
  updateRoom,
  type RoomPoolRole,
  type TimetableRoomRecord,
} from "@/features/admin/services/roomsService";
import { useAuth } from "@/features/auth/AuthProvider";
import { cn } from "@/lib/utils";

type RoomFilter = "all" | "labs" | "gallery" | "active" | "inactive";

const slotEntrySchema = z.object({
  day: z.string(),
  period_idx: z.number().int().min(1).max(12),
});

const roomSchema = z.object({
  name: z
    .string()
    .trim()
    .min(1, "Enter a room identifier (e.g. RAB-302 or ACL-1).")
    .max(40, "Room identifier is too long."),
  building: z.string().trim().max(80).optional(),
  dept: z.string().trim().max(40).optional(),
  capacity: z
    .string()
    .trim()
    .refine(
      (v) =>
        v === "" ||
        (/^\d+$/.test(v) && Number.parseInt(v, 10) >= 1 && Number.parseInt(v, 10) <= 500),
      "Capacity must be between 1 and 500.",
    ),
  is_lab: z.boolean(),
  is_gallery: z.boolean(),
  is_active: z.boolean(),
  room_pool_role: z.enum([
    "general",
    "cse_lab",
    "ecl_lab",
    "physics_lab",
    "gallery",
    "other",
  ]),
  available_slots: z.array(slotEntrySchema),
});

type RoomFormValues = z.infer<typeof roomSchema>;

function toFormValues(room: TimetableRoomRecord | null): RoomFormValues {
  if (!room) {
    return {
      name: "",
      building: "",
      dept: "CSE",
      capacity: "",
      is_lab: false,
      is_gallery: false,
      is_active: true,
      room_pool_role: "general",
      available_slots: [],
    };
  }
  return {
    name: room.name,
    building: room.building ?? "",
    dept: room.dept ?? "",
    capacity: room.capacity !== null ? String(room.capacity) : "",
    is_lab: room.is_lab,
    is_gallery: room.is_gallery,
    is_active: room.is_active,
    room_pool_role: inferRoomPoolRole(room),
    available_slots: [...(room.available_slots ?? [])],
  };
}

export function ManageRoomsPage() {
  const { isDevPreview } = useAuth();
  const queryClient = useQueryClient();
  const searchInputRef = useRef<HTMLInputElement>(null);

  const [search, setSearch] = useState("");
  const [filter, setFilter] = useState<RoomFilter>("all");
  const [selectedId, setSelectedId] = useState<string | "new" | null>(null);
  const [pendingSelectId, setPendingSelectId] = useState<string | "new" | null | undefined>(
    undefined,
  );
  const [deleteIds, setDeleteIds] = useState<string[] | null>(null);

  const {
    data: rooms = [],
    isLoading,
    isError,
    error,
    refetch,
  } = useQuery({
    queryKey: ["admin-timetable-rooms", isDevPreview],
    queryFn: () => fetchRooms(isDevPreview),
    retry: false,
  });

  const extendedLiveQuery = useQuery({
    queryKey: ["admin-rooms-extended-live", isDevPreview],
    queryFn: () => isRoomExtendedSchemaLive(isDevPreview),
    retry: false,
  });
  const isExtendedLive = extendedLiveQuery.data ?? false;

  const selectedRoom = useMemo(
    () =>
      selectedId && selectedId !== "new"
        ? rooms.find((r) => r.id === selectedId) ?? null
        : null,
    [rooms, selectedId],
  );

  const form = useForm<RoomFormValues>({
    resolver: zodResolver(roomSchema),
    defaultValues: toFormValues(null),
  });

  const {
    register,
    control,
    watch,
    setValue,
    handleSubmit,
    reset,
    formState: { errors, isDirty },
  } = form;

  const watchedPoolRole = watch("room_pool_role");
  const watchedAvailableSlots = watch("available_slots");

  const openInspector = (target: string | "new" | null) => {
    if (isDirty && target !== selectedId) {
      setPendingSelectId(target);
      return;
    }
    setSelectedId(target);
    if (target === "new") {
      reset(toFormValues(null));
    } else if (target) {
      const rec = rooms.find((r) => r.id === target) ?? null;
      reset(toFormValues(rec));
    }
  };

  useWorkspaceShortcuts({
    searchInputRef,
    onEscape: () => {
      if (selectedId !== null && pendingSelectId === undefined && deleteIds === null) {
        openInspector(null);
      }
    },
  });

  const saveMutation = useMutation({
    mutationFn: async (values: RoomFormValues) => {
      const parsedCap =
        values.capacity.trim() !== ""
          ? Number.parseInt(values.capacity.trim(), 10)
          : null;
      const input = {
        name: values.name,
        building: values.building ?? null,
        dept: values.dept ?? null,
        capacity: parsedCap,
        is_lab: values.is_lab,
        is_gallery: values.is_gallery,
        is_active: values.is_active,
        room_pool_role: values.room_pool_role as RoomPoolRole,
        available_slots: values.available_slots as SlotMatrixEntry[],
      };
      if (selectedId === "new" || !selectedRoom) {
        return createRoom(input, isDevPreview);
      }
      return updateRoom(selectedRoom.id, input, isDevPreview);
    },
    onSuccess: (saved) => {
      void queryClient.invalidateQueries({ queryKey: ["admin-timetable-rooms"] });
      void queryClient.invalidateQueries({ queryKey: ["admin-dashboard-counts"] });
      setSelectedId(saved.id);
      reset(toFormValues(saved));
      toast.success(`Saved room ${saved.name}`);
    },
    onError: (err) => {
      toast.error("Could not save room", {
        description: err instanceof Error ? err.message : "Database write failed.",
      });
    },
  });

  const bulkStatusMutation = useMutation({
    mutationFn: ({ ids, isActive }: { ids: string[]; isActive: boolean }) =>
      bulkSetRoomsActive(ids, isActive, isDevPreview),
    onSuccess: (_, vars) => {
      void queryClient.invalidateQueries({ queryKey: ["admin-timetable-rooms"] });
      void queryClient.invalidateQueries({ queryKey: ["admin-dashboard-counts"] });
      toast.success(
        `${vars.ids.length} room${vars.ids.length > 1 ? "s" : ""} marked ${vars.isActive ? "active" : "inactive"}`,
      );
    },
    onError: (err) => {
      toast.error("Bulk update failed", {
        description: err instanceof Error ? err.message : "Update failed.",
      });
    },
  });

  const toggleRoomActiveMutation = useMutation({
    mutationFn: ({ id, isActive }: { id: string; isActive: boolean; name: string }) =>
      bulkSetRoomsActive([id], isActive, isDevPreview),
    onMutate: async ({ id, isActive }) => {
      const qKey = ["admin-timetable-rooms", isDevPreview];
      await queryClient.cancelQueries({ queryKey: qKey });
      const previous = queryClient.getQueryData<TimetableRoomRecord[]>(qKey);
      if (previous) {
        queryClient.setQueryData<TimetableRoomRecord[]>(
          qKey,
          previous.map((r) => (r.id === id ? { ...r, is_active: isActive } : r)),
        );
      }
      return { previous, qKey };
    },
    onError: (err, _vars, ctx) => {
      if (ctx?.previous) {
        queryClient.setQueryData(ctx.qKey, ctx.previous);
      }
      toast.error("Could not update room status", {
        description: err instanceof Error ? err.message : "Database write failed.",
      });
    },
    onSuccess: (_data, vars) => {
      void queryClient.invalidateQueries({ queryKey: ["admin-timetable-rooms"] });
      void queryClient.invalidateQueries({ queryKey: ["admin-dashboard-counts"] });
      toast.success(
        `${vars.name} marked ${vars.isActive ? "active" : "inactive"}`,
      );
    },
  });

  const deleteMutation = useMutation({
    mutationFn: (ids: string[]) => deleteRooms(ids, isDevPreview),
    onSuccess: (_, ids) => {
      void queryClient.invalidateQueries({ queryKey: ["admin-timetable-rooms"] });
      void queryClient.invalidateQueries({ queryKey: ["admin-dashboard-counts"] });
      if (selectedId && ids.includes(selectedId)) {
        setSelectedId(null);
        reset(toFormValues(null));
      }
      setDeleteIds(null);
      toast.success(`Removed ${ids.length} room${ids.length > 1 ? "s" : ""}`);
    },
    onError: (err) => {
      toast.error("Could not delete rooms", {
        description: err instanceof Error ? err.message : "Delete failed.",
      });
    },
  });

  const filterCounts = useMemo(() => {
    const labs = rooms.filter((r) => r.is_lab).length;
    const gallery = rooms.filter((r) => r.is_gallery).length;
    const active = rooms.filter((r) => r.is_active).length;
    const inactive = rooms.filter((r) => !r.is_active).length;
    return {
      all: rooms.length,
      labs,
      gallery,
      active,
      inactive,
    };
  }, [rooms]);

  const poolSummary = useMemo(() => {
    let theoryCount = 0;
    let theorySeats = 0;
    let labCount = 0;
    let labSeats = 0;
    let galleryCount = 0;
    let gallerySeats = 0;
    let inactiveCount = 0;

    for (const r of rooms) {
      const cap = r.capacity ?? 0;
      if (!r.is_active) inactiveCount += 1;
      if (r.is_lab) {
        labCount += 1;
        labSeats += cap;
      } else if (r.is_gallery) {
        galleryCount += 1;
        gallerySeats += cap;
      } else {
        theoryCount += 1;
        theorySeats += cap;
      }
    }
    return {
      theoryCount,
      theorySeats,
      labCount,
      labSeats,
      galleryCount,
      gallerySeats,
      inactiveCount,
    };
  }, [rooms]);

  const filteredRooms = useMemo(() => {
    const q = search.trim().toLowerCase();
    return rooms.filter((r) => {
      if (filter === "labs" && !r.is_lab) return false;
      if (filter === "gallery" && !r.is_gallery) return false;
      if (filter === "active" && !r.is_active) return false;
      if (filter === "inactive" && r.is_active) return false;
      if (!q) return true;
      return (
        r.name.toLowerCase().includes(q) ||
        (r.building?.toLowerCase().includes(q) ?? false) ||
        (r.dept?.toLowerCase().includes(q) ?? false)
      );
    });
  }, [filter, rooms, search]);

  const columns: DataLedgerColumn<TimetableRoomRecord>[] = [
    {
      id: "name",
      header: "Room",
      accessor: (r) => r.name,
      cell: (r) => (
        <div className="flex items-center gap-1.5">
          <span className="font-mono-tabular font-semibold whitespace-nowrap">
            {r.name}
          </span>
          <HoverCopyButton value={r.name} label="room code" />
        </div>
      ),
    },
    {
      id: "building",
      header: "Building",
      accessor: (r) => r.building ?? "",
      cell: (r) => (
        <span className="text-[var(--ink-secondary)]">
          {r.building ?? "—"}
        </span>
      ),
    },
    {
      id: "type",
      header: "Classification",
      accessor: (r) => (r.is_lab ? "Lab" : r.is_gallery ? "Gallery" : "Theory"),
      cell: (r) =>
        r.is_lab ? (
          <Badge tone="lab">
            <Desktop size={12} aria-hidden="true" />
            <span>Lab</span>
          </Badge>
        ) : r.is_gallery ? (
          <Badge tone="joint">Gallery</Badge>
        ) : (
          <Badge tone="theory">Theory</Badge>
        ),
    },
    {
      id: "dept",
      header: "Dept",
      accessor: (r) => r.dept ?? "",
      cell: (r) => (
        <span className="font-mono-tabular text-[12.5px]">
          {r.dept ?? "Shared"}
        </span>
      ),
    },
    {
      id: "capacity",
      header: "Capacity",
      align: "right",
      accessor: (r) => r.capacity ?? 0,
      cell: (r) => (
        <span className="font-mono-tabular">
          {r.capacity !== null ? r.capacity : "—"}
        </span>
      ),
    },
    {
      id: "is_active",
      header: "Pool Status",
      accessor: (r) => (r.is_active ? "Active" : "Inactive"),
      cell: (r) => (
        <div
          className="flex items-center gap-2"
          onClick={(e) => e.stopPropagation()}
        >
          <Switch
            checked={r.is_active}
            aria-label={`Toggle ${r.name} active`}
            disabled={toggleRoomActiveMutation.isPending}
            onCheckedChange={(checked) =>
              toggleRoomActiveMutation.mutate({
                id: r.id,
                name: r.name,
                isActive: checked,
              })
            }
          />
          <span
            className={cn(
              "font-mono-tabular text-[12px] font-medium",
              r.is_active
                ? "text-[var(--ink-primary)]"
                : "text-[var(--ink-muted)]",
            )}
          >
            {r.is_active ? "Active" : "Inactive"}
          </span>
        </div>
      ),
    },
  ];

  const bulkActions: BulkActionItem[] = [
    {
      id: "activate",
      label: "Activate",
      tone: "pine",
      disabled: bulkStatusMutation.isPending,
      onAction: (ids) => bulkStatusMutation.mutate({ ids, isActive: true }),
    },
    {
      id: "deactivate",
      label: "Deactivate",
      tone: "secondary",
      disabled: bulkStatusMutation.isPending,
      onAction: (ids) => bulkStatusMutation.mutate({ ids, isActive: false }),
    },
    {
      id: "delete",
      label: "Delete",
      tone: "destructive",
      disabled: deleteMutation.isPending,
      onAction: (ids) => setDeleteIds(ids),
    },
  ];

  return (
    <div className="flex flex-col gap-5">
      {isDevPreview && (
        <div
          role="status"
          className="flex items-center gap-2 rounded-[var(--r-card)] border border-[var(--accent-brand-border)] bg-[var(--accent-brand-soft)] px-4 py-2.5 text-[12.5px] text-[var(--accent-brand)]"
        >
          <Info size={16} className="shrink-0" aria-hidden="true" />
          <span>
            Illustrative preview — disconnected from live Supabase &amp; FastAPI
            backends. Edits remain local to this browser session.
          </span>
        </div>
      )}

      {/* Pool Capacity Summary Strip */}
      {rooms.length > 0 && (
        <div
          data-testid="rooms-capacity-strip"
          className="ledger-card flex flex-wrap items-center gap-x-5 gap-y-2 px-4 py-2.5 text-[12px]"
        >
          <span className="font-mono-tabular text-[var(--ink-primary)]">
            <strong>Theory:</strong> {poolSummary.theoryCount} rooms ·{" "}
            {poolSummary.theorySeats} seats
          </span>
          <span className="font-mono-tabular text-[var(--ink-primary)]">
            <strong>Labs:</strong> {poolSummary.labCount} rooms ·{" "}
            {poolSummary.labSeats} seats
          </span>
          <span className="font-mono-tabular text-[var(--ink-primary)]">
            <strong>Galleries:</strong> {poolSummary.galleryCount} rooms ·{" "}
            {poolSummary.gallerySeats} seats
          </span>
          <span className="font-mono-tabular text-[var(--ink-muted)]">
            Inactive: {poolSummary.inactiveCount}
          </span>
        </div>
      )}

      {/* Uniform 36px Toolbar */}
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="flex min-w-0 flex-1 flex-wrap items-center gap-2">
          <div className="relative flex w-full max-w-[280px] items-center">
            <MagnifyingGlass
              size={15}
              className="pointer-events-none absolute left-3 text-[var(--ink-muted)]"
              aria-hidden="true"
            />
            <input
              ref={searchInputRef}
              type="search"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Search rooms (press /)"
              aria-label="Search rooms"
              className="h-[36px] w-full rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] pl-9 pr-3 text-[13px] text-[var(--ink-primary)] placeholder:text-[var(--ink-muted)] focus:border-[var(--accent-brand)]"
            />
          </div>

          <div
            role="group"
            aria-label="Filter rooms"
            className="flex flex-wrap items-center gap-1.5"
          >
            {(
              [
                { key: "all", label: `All (${filterCounts.all})` },
                { key: "labs", label: `Labs (${filterCounts.labs})` },
                { key: "gallery", label: `Gallery (${filterCounts.gallery})` },
                { key: "active", label: `Active (${filterCounts.active})` },
                { key: "inactive", label: `Inactive (${filterCounts.inactive})` },
              ] as const
            ).map((opt) => {
              const active = filter === opt.key;
              return (
                <button
                  key={opt.key}
                  type="button"
                  aria-pressed={active}
                  onClick={() => setFilter(opt.key)}
                  className={cn(
                    "h-[36px] rounded-[var(--r-control)] border px-3 font-mono-tabular text-[12px] transition-colors whitespace-nowrap",
                    active
                      ? "border-[var(--accent-brand)] bg-[var(--accent-brand-soft)] font-semibold text-[var(--accent-brand)]"
                      : "border-[var(--border-subtle)] bg-[var(--bg-elevated)] text-[var(--ink-secondary)] hover:bg-[var(--surface-hover)] hover:text-[var(--ink-primary)]",
                  )}
                >
                  {opt.label}
                </button>
              );
            })}
          </div>
        </div>

        <Button
          variant="primary"
          size="md"
          onClick={() => openInspector("new")}
        >
          <Plus size={15} aria-hidden="true" />
          <span>Add Room</span>
        </Button>
      </div>

      {/* Main Master-Detail Workspace */}
      <MasterDetailShell
        detailOpen={selectedId !== null}
        onRequestClose={() => openInspector(null)}
        detailTitle={
          selectedId === "new"
            ? "Add Room or Lab"
            : selectedRoom
              ? `Edit ${selectedRoom.name}`
              : "Room Details"
        }
        detailSubtitle="Persisted baseline attributes (building, lab/gallery flags, capacity, status)"
        master={
          isLoading ? (
            <LedgerTableSkeleton label="Loading room pools" />
          ) : isError ? (
            <LedgerErrorRecovery
              title="Could not load room pools"
              message={
                error instanceof Error
                  ? error.message
                  : "Failed to read rooms from Supabase."
              }
              onRetry={() => void refetch()}
            />
          ) : rooms.length === 0 ? (
            <LedgerEmptyState
              icon={<Buildings size={20} aria-hidden="true" />}
              title="No rooms configured yet"
              description="Add lecture rooms, gallery halls, and computing labs with capacities and department tags before generating a semester routine."
              actionLabel="Add First Room"
              onAction={() => openInspector("new")}
            />
          ) : filteredRooms.length === 0 ? (
            <LedgerFilterEmpty
              onReset={() => {
                setSearch("");
                setFilter("all");
              }}
            />
          ) : (
            <DataLedgerTable
              ariaLabel="Campus rooms and labs"
              data={filteredRooms}
              columns={columns}
              getRowId={(r) => r.id}
              selectedRowId={selectedId}
              onRowClick={(r) => openInspector(r.id)}
              isInactiveRow={(r) => !r.is_active}
              bulkActions={bulkActions}
              renderRowActions={(r) => (
                <>
                  <button
                    type="button"
                    aria-label={`Edit ${r.name}`}
                    onClick={() => openInspector(r.id)}
                    className="inline-flex h-7 w-7 items-center justify-center rounded-[5px] text-[var(--ink-secondary)] hover:bg-[var(--surface-active)] hover:text-[var(--ink-primary)]"
                  >
                    <PencilSimple size={14} aria-hidden="true" />
                  </button>
                  <button
                    type="button"
                    aria-label={`Delete ${r.name}`}
                    onClick={() => setDeleteIds([r.id])}
                    className="inline-flex h-7 w-7 items-center justify-center rounded-[5px] text-[var(--sem-conflict-ink)] hover:bg-[var(--sem-conflict-bg)]"
                  >
                    <Trash size={14} aria-hidden="true" />
                  </button>
                </>
              )}
            />
          )
        }
        detail={
          <form
            id="room-inspector-form"
            onSubmit={handleSubmit((vals) => saveMutation.mutate(vals))}
            className="flex flex-col gap-4"
            noValidate
          >
            {selectedId && selectedId !== "new" && selectedRoom && (
              <div className="flex items-center justify-between gap-2 rounded-[var(--r-control)] border border-[var(--border-subtle)] bg-[var(--bg-canvas)] px-3 py-2">
                <span className="font-mono-tabular text-[12px] text-[var(--ink-secondary)]">
                  Inspect weekly placements
                </span>
                <Link
                  to={`/admin/timetable/grid?lens=room&entity=${encodeURIComponent(selectedRoom.name)}&from=rooms`}
                  data-testid="view-room-schedule-link"
                  className="inline-flex items-center gap-1 text-[12px] font-semibold text-[var(--accent-brand)] no-underline hover:underline"
                >
                  <span>View Room Schedule</span>
                  <ArrowRight size={13} aria-hidden="true" />
                </Link>
              </div>
            )}

            {saveMutation.isError && (
              <div
                role="alert"
                className="rounded-[var(--r-control)] border border-[var(--sem-conflict-border)] bg-[var(--sem-conflict-bg)] px-3 py-2.5 text-[12.5px] text-[var(--sem-conflict-ink)]"
              >
                {saveMutation.error instanceof Error
                  ? saveMutation.error.message
                  : "Save failed."}
              </div>
            )}

            <div className="flex flex-col gap-1.5">
              <label
                htmlFor="room-name"
                className="text-[12.5px] font-semibold text-[var(--ink-primary)]"
              >
                Room Code
              </label>
              <input
                id="room-name"
                type="text"
                placeholder="e.g. RAB-302 or ACL-1"
                aria-invalid={Boolean(errors.name)}
                {...register("name")}
                className="font-mono-tabular h-[40px] rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-3 text-[13.5px] text-[var(--ink-primary)] uppercase focus:border-[var(--accent-brand)]"
              />
              {errors.name && (
                <p className="text-[12px] font-medium text-[var(--sem-conflict-ink)]">
                  {errors.name.message}
                </p>
              )}
            </div>

            <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
              <div className="flex flex-col gap-1.5">
                <label
                  htmlFor="room-building"
                  className="text-[12.5px] font-semibold text-[var(--ink-primary)]"
                >
                  Building
                </label>
                <input
                  id="room-building"
                  type="text"
                  placeholder="e.g. RAB, RKB, Academic 2"
                  {...register("building")}
                  className="h-[40px] rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-3 text-[13.5px] text-[var(--ink-primary)] focus:border-[var(--accent-brand)]"
                />
              </div>

              <div className="flex flex-col gap-1.5">
                <label
                  htmlFor="room-capacity"
                  className="text-[12.5px] font-semibold text-[var(--ink-primary)]"
                >
                  Seat Capacity
                </label>
                <input
                  id="room-capacity"
                  type="number"
                  min={1}
                  max={500}
                  placeholder="45"
                  aria-invalid={Boolean(errors.capacity)}
                  {...register("capacity")}
                  className="font-mono-tabular h-[40px] rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-3 text-[13.5px] text-[var(--ink-primary)] focus:border-[var(--accent-brand)]"
                />
                {errors.capacity && (
                  <p className="text-[12px] font-medium text-[var(--sem-conflict-ink)]">
                    {errors.capacity.message}
                  </p>
                )}
              </div>
            </div>

            <div className="flex flex-col gap-1.5">
              <label
                htmlFor="room-dept"
                className="text-[12.5px] font-semibold text-[var(--ink-primary)]"
              >
                Home Department
              </label>
              <input
                id="room-dept"
                list="room-dept-suggestions"
                placeholder="CSE, EEE, or blank if shared"
                {...register("dept")}
                className="h-[40px] rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-3 text-[13.5px] text-[var(--ink-primary)] focus:border-[var(--accent-brand)]"
              />
              <datalist id="room-dept-suggestions">
                {INSTITUTIONAL_DEPARTMENTS.map((d) => (
                  <option key={d} value={d} />
                ))}
              </datalist>
            </div>

            <div className="divide-y divide-[var(--border-subtle)] rounded-[var(--r-control)] border border-[var(--border-subtle)] bg-[var(--bg-surface)] px-3.5">
              <label
                htmlFor="room-is-lab"
                className="flex cursor-pointer items-center justify-between gap-3 py-3 text-[13px]"
              >
                <div>
                  <div className="font-medium text-[var(--ink-primary)]">
                    Computing / Hardware Lab
                  </div>
                  <div className="text-[11.5px] text-[var(--ink-muted)]">
                    Reserve exclusively for sessional lab offerings
                  </div>
                </div>
                <Controller
                  name="is_lab"
                  control={control}
                  render={({ field }) => (
                    <Switch
                      id="room-is-lab"
                      checked={field.value}
                      onCheckedChange={field.onChange}
                    />
                  )}
                />
              </label>

              <label
                htmlFor="room-is-gallery"
                className="flex cursor-pointer items-center justify-between gap-3 py-3 text-[13px]"
              >
                <div>
                  <div className="font-medium text-[var(--ink-primary)]">
                    Gallery Classroom
                  </div>
                  <div className="text-[11.5px] text-[var(--ink-muted)]">
                    Large stepped lecture hall for combined theory cohorts
                  </div>
                </div>
                <Controller
                  name="is_gallery"
                  control={control}
                  render={({ field }) => (
                    <Switch
                      id="room-is-gallery"
                      checked={field.value}
                      onCheckedChange={field.onChange}
                    />
                  )}
                />
              </label>

              <label
                htmlFor="room-is-active"
                className="flex cursor-pointer items-center justify-between gap-3 py-3 text-[13px]"
              >
                <div>
                  <div className="font-medium text-[var(--ink-primary)]">
                    Active in Solver Pool
                  </div>
                  <div className="text-[11.5px] text-[var(--ink-muted)]">
                    Inactive rooms stay archived without deletion
                  </div>
                </div>
                <Controller
                  name="is_active"
                  control={control}
                  render={({ field }) => (
                    <Switch
                      id="room-is-active"
                      checked={field.value}
                      onCheckedChange={field.onChange}
                    />
                  )}
                />
              </label>
            </div>

            {isExtendedLive ? (
              <div className="flex flex-col gap-3">
                <div className="flex flex-col gap-1.5">
                  <label
                    htmlFor="room-pool-role"
                    className="text-[12.5px] font-semibold text-[var(--ink-primary)]"
                  >
                    Room Pool Role (R10 / R11 / R14)
                  </label>
                  <select
                    id="room-pool-role"
                    {...register("room_pool_role")}
                    className="h-[38px] rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-2.5 text-[12.5px] focus:border-[var(--accent-brand)]"
                  >
                    {(Object.entries(ROOM_POOL_ROLE_LABELS) as [RoomPoolRole, string][]).map(
                      ([role, label]) => (
                        <option key={role} value={role}>
                          {label}
                        </option>
                      ),
                    )}
                  </select>
                </div>

                {(watchedPoolRole === "ecl_lab" ||
                  watchedPoolRole === "physics_lab") && (
                  <div className="space-y-2">
                    <DaySlotMatrixPicker
                      testId="room-shared-lab-windows"
                      label={
                        watchedPoolRole === "ecl_lab"
                          ? "ECL Lab Approved EEE Windows (R10)"
                          : "Physics Lab Approved Windows (R11)"
                      }
                      description="Declare explicit slot windows available for CSE scheduling."
                      value={watchedAvailableSlots}
                      onChange={(next) =>
                        setValue("available_slots", next, { shouldDirty: true })
                      }
                      tone="lab"
                    />
                    {watchedAvailableSlots.length === 0 && (
                      <div
                        role="status"
                        className="rounded-[var(--r-control)] border border-[var(--sem-conflict-border)] bg-[var(--sem-conflict-bg)] px-3 py-2 text-[12px] text-[var(--sem-conflict-ink)]"
                      >
                        Blocker: {watchedPoolRole === "ecl_lab" ? "ECL" : "Physics"} lab
                        rooms require at least 1 declared slot window before solve.
                      </div>
                    )}
                  </div>
                )}
              </div>
            ) : (
              <StagedFeatureNotice
                title="Staged Policy Rules (R10/R11 Window Matrix & R14 Term Pools)"
                description="Declared lab availability matrices and term-specific room pool overrides remain staged pending Stage 5A database schema promotion and are omitted from room writes."
              />
            )}

            <StickyDirtyBar
              docked
              isDirty={isDirty}
              isSaving={saveMutation.isPending}
              formId="room-inspector-form"
              saveLabel={selectedId === "new" ? "Create Room" : "Save Room"}
              onDiscard={() => {
                if (selectedId === "new") {
                  setSelectedId(null);
                  reset(toFormValues(null));
                } else {
                  reset(toFormValues(selectedRoom));
                }
              }}
            />
          </form>
        }
      />

      {/* Dirty Discard Confirmation */}
      <ConfirmDialog
        open={pendingSelectId !== undefined}
        onOpenChange={(open) => {
          if (!open) setPendingSelectId(undefined);
        }}
        title="Discard unsaved room edits?"
        description="You have unsaved changes in the Room Inspector. Discard those edits before switching or closing?"
        confirmLabel="Discard Changes"
        tone="destructive"
        onConfirm={() => {
          const target = pendingSelectId ?? null;
          setPendingSelectId(undefined);
          setSelectedId(target);
          if (target === "new") {
            reset(toFormValues(null));
          } else if (target) {
            const rec = rooms.find((r) => r.id === target) ?? null;
            reset(toFormValues(rec));
          } else {
            reset(toFormValues(null));
          }
        }}
      />

      {/* Delete Confirmation */}
      <ConfirmDialog
        open={deleteIds !== null}
        onOpenChange={(open) => {
          if (!open) setDeleteIds(null);
        }}
        title={`Delete ${deleteIds?.length ?? 0} room${(deleteIds?.length ?? 0) === 1 ? "" : "s"}?`}
        description="This permanently deletes the selected room inventory row from the baseline configuration."
        confirmLabel="Delete"
        tone="destructive"
        isPending={deleteMutation.isPending}
        onConfirm={() => {
          if (deleteIds) deleteMutation.mutate(deleteIds);
        }}
      />
    </div>
  );
}
