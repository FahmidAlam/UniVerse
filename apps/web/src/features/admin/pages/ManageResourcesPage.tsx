import { zodResolver } from "@hookform/resolvers/zod";
import {
  ArrowSquareOut,
  FileArrowUp,
  FolderSimple,
  MagnifyingGlass,
  Plus,
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
  HoverCopyButton,
  type DataLedgerColumn,
} from "@/components/ui/DataLedgerTable";
import { MasterDetailShell } from "@/components/ui/MasterDetailShell";
import { StickyDirtyBar } from "@/components/ui/StickyDirtyBar";
import { useWorkspaceShortcuts } from "@/core/hooks/useWorkspaceShortcuts";
import { createBroadcast } from "@/features/admin/services/broadcastService";
import {
  createResource,
  deleteResourceWithCleanup,
  fetchResources,
  RESOURCE_CATEGORIES,
  RESOURCE_SEMESTERS,
  uploadResourceFile,
  type ResourceCategory,
  type ResourceRecord,
} from "@/features/admin/services/resourcesService";
import { useAuth } from "@/features/auth/AuthProvider";
import { cn } from "@/lib/utils";

type CategoryFilter = "all" | ResourceCategory;

const resourceSchema = z.object({
  title: z
    .string()
    .trim()
    .min(2, "Enter a clear title for the material.")
    .max(140),
  category: z.enum(RESOURCE_CATEGORIES),
  semester: z
    .string()
    .refine(
      (v) => /^\d+$/.test(v) && Number.parseInt(v, 10) >= 1 && Number.parseInt(v, 10) <= 8,
      "Select a semester between 1 and 8.",
    ),
  subject_code: z.string().trim().max(32).optional(),
  drive_link: z
    .string()
    .trim()
    .refine(
      (v) => v === "" || /^https:\/\//i.test(v),
      "External Drive link must begin with https://",
    )
    .optional(),
  notify_students: z.boolean(),
});

type ResourceFormValues = z.infer<typeof resourceSchema>;

function categoryBadgeTone(
  cat: ResourceCategory,
): "pine" | "theory" | "lab" | "joint" {
  switch (cat) {
    case "PYQ":
      return "pine";
    case "Notes":
      return "theory";
    case "Slides":
      return "lab";
    case "Assignments":
      return "joint";
  }
}

export function ManageResourcesPage() {
  const { isDevPreview, profile } = useAuth();
  const queryClient = useQueryClient();
  const searchInputRef = useRef<HTMLInputElement>(null);

  const [search, setSearch] = useState("");
  const [catFilter, setCatFilter] = useState<CategoryFilter>("all");
  const [semesterFilter, setSemesterFilter] = useState<number | "all">("all");
  const [sheetOpen, setSheetOpen] = useState(false);
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  const [deleteTarget, setDeleteTarget] = useState<ResourceRecord | null>(null);

  const {
    data: resources = [],
    isLoading,
    isError,
    error,
    refetch,
  } = useQuery({
    queryKey: ["admin-academic-resources", isDevPreview],
    queryFn: () => fetchResources(isDevPreview),
    retry: false,
  });

  const form = useForm<ResourceFormValues>({
    resolver: zodResolver(resourceSchema),
    defaultValues: {
      title: "",
      category: "Notes",
      semester: "1",
      subject_code: "",
      drive_link: "",
      notify_students: false,
    },
  });

  const selectedSemester = form.watch("semester");

  useWorkspaceShortcuts({
    searchInputRef,
    onEscape: () => {
      if (sheetOpen && !deleteTarget) setSheetOpen(false);
    },
  });

  const createMutation = useMutation({
    mutationFn: async (values: ResourceFormValues) => {
      let uploadedFileUrl: string | null = null;
      const driveLink = values.drive_link?.trim() || null;

      const semNum = Number.parseInt(values.semester, 10);

      if (!selectedFile && !driveLink) {
        throw new Error("Attach a file upload or enter an HTTPS Drive link.");
      }

      if (selectedFile) {
        uploadedFileUrl = await uploadResourceFile(
          selectedFile,
          semNum,
          isDevPreview,
        );
      }

      const created = await createResource(
        {
          title: values.title,
          category: values.category,
          semester: semNum,
          subject_code: values.subject_code,
          drive_link: driveLink,
          file_url: uploadedFileUrl,
        },
        profile?.id ?? null,
        isDevPreview,
      );

      let notifyWarning: string | null = null;
      if (values.notify_students) {
        try {
          await createBroadcast(
            {
              title: `New ${values.category}: ${created.title}`,
              body: `Uploaded for Semester ${semNum}${
                created.subject_code ? ` (${created.subject_code})` : ""
              }. Check Academic Resources.`,
              type: "university",
              target_role: "student",
              target_batch: null,
              target_section: null,
            },
            profile?.id ?? null,
            isDevPreview,
          );
        } catch (err) {
          notifyWarning =
            err instanceof Error
              ? err.message
              : "Could not create announcement notification.";
        }
      }

      return { created, notifyWarning };
    },
    onSuccess: ({ created, notifyWarning }) => {
      void queryClient.invalidateQueries({
        queryKey: ["admin-academic-resources"],
      });
      void queryClient.invalidateQueries({
        queryKey: ["admin-broadcast-history"],
      });
      setSheetOpen(false);
      setSelectedFile(null);
      form.reset({
        title: "",
        category: "Notes",
        semester: "1",
        subject_code: "",
        drive_link: "",
        notify_students: false,
      });

      if (notifyWarning) {
        toast.warning(`Saved resource "${created.title}", but alert failed`, {
          description: notifyWarning,
        });
      } else {
        toast.success(`Published resource: ${created.title}`);
      }
    },
    onError: (err) => {
      toast.error("Could not publish resource", {
        description:
          err instanceof Error ? err.message : "Upload or insert failed.",
      });
    },
  });

  const deleteMutation = useMutation({
    mutationFn: (item: ResourceRecord) =>
      deleteResourceWithCleanup(item, isDevPreview),
    onSuccess: ({ storageWarning }, item) => {
      void queryClient.invalidateQueries({
        queryKey: ["admin-academic-resources"],
      });
      setDeleteTarget(null);
      if (storageWarning) {
        toast.warning(`Removed "${item.title}" with Storage note`, {
          description: storageWarning,
        });
      } else {
        toast.success(`Deleted resource: ${item.title}`);
      }
    },
    onError: (err) => {
      toast.error("Could not delete resource", {
        description:
          err instanceof Error ? err.message : "Database delete failed.",
      });
    },
  });

  const counts = useMemo(() => {
    const map: Record<string, number> = { all: resources.length };
    for (const c of RESOURCE_CATEGORIES) map[c] = 0;
    for (const r of resources) {
      map[r.category] = (map[r.category] ?? 0) + 1;
    }
    return map;
  }, [resources]);

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    return resources.filter((r) => {
      if (catFilter !== "all" && r.category !== catFilter) return false;
      if (semesterFilter !== "all" && r.semester !== semesterFilter) {
        return false;
      }
      if (!q) return true;
      return (
        r.title.toLowerCase().includes(q) ||
        (r.subject_code ?? "").toLowerCase().includes(q) ||
        r.category.toLowerCase().includes(q)
      );
    });
  }, [resources, catFilter, semesterFilter, search]);

  const columns = useMemo<DataLedgerColumn<ResourceRecord>[]>(
    () => [
      {
        id: "title",
        header: "Resource",
        accessor: (r) => r.title,
        cell: (r) => (
          <div className="min-w-0">
            <div className="truncate font-medium text-[var(--ink-primary)]">
              {r.title}
            </div>
            <div className="mt-0.5 flex flex-wrap items-center gap-2 text-[11.5px] text-[var(--ink-muted)]">
              <span className="font-mono-tabular">Sem {r.semester}</span>
              {r.subject_code && (
                <span className="inline-flex items-center gap-1 font-mono-tabular">
                  {r.subject_code}
                  <HoverCopyButton
                    value={r.subject_code}
                    label="course code"
                  />
                </span>
              )}
            </div>
          </div>
        ),
      },
      {
        id: "category",
        header: "Category",
        accessor: (r) => r.category,
        cell: (r) => (
          <Badge tone={categoryBadgeTone(r.category)} mono>
            {r.category}
          </Badge>
        ),
      },
      {
        id: "source",
        header: "Access",
        accessor: (r) => (r.file_url ? "Storage" : "Drive"),
        cell: (r) => {
          const href = r.file_url || r.drive_link;
          return href ? (
            <a
              href={href}
              target="_blank"
              rel="noreferrer"
              onClick={(e) => e.stopPropagation()}
              className="inline-flex items-center gap-1 text-[12.5px] font-medium text-[var(--accent-pine)] no-underline hover:underline"
            >
              <span>{r.file_url ? "File" : "Drive Link"}</span>
              <ArrowSquareOut size={13} aria-hidden="true" />
            </a>
          ) : (
            <span className="text-[var(--ink-muted)]">—</span>
          );
        },
      },
    ],
    [],
  );

  return (
    <div className="space-y-4">
      <header className="flex flex-wrap items-end justify-between gap-4 border-b border-[var(--border-subtle)] pb-4">
        <div>
          <h1 className="font-editorial text-[26px] font-semibold tracking-[-0.02em] text-[var(--ink-primary)]">
            Academic Resources
          </h1>
          <p className="mt-1 max-w-[66ch] text-[13.5px] leading-[1.55] text-[var(--ink-secondary)]">
            Publish official PYQs, notes, lecture slides, and assignments to
            student and teacher mobile feeds.
          </p>
        </div>

        <Button
          variant="primary"
          size="md"
          onClick={() => setSheetOpen(true)}
        >
          <Plus size={15} aria-hidden="true" />
          <span>Add Resource</span>
        </Button>
      </header>

      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="flex flex-wrap items-center gap-2">
          <div
            role="group"
            aria-label="Filter resources by category"
            className="flex flex-wrap items-center gap-1.5"
          >
            <button
              type="button"
              aria-pressed={catFilter === "all"}
              onClick={() => setCatFilter("all")}
              className={cn(
                "h-[36px] rounded-[var(--r-control)] border px-3 font-mono-tabular text-[12px]",
                catFilter === "all"
                  ? "border-[var(--accent-pine)] bg-[var(--accent-pine-soft)] font-semibold text-[var(--accent-pine)]"
                  : "border-[var(--border-control)] bg-[var(--bg-elevated)] text-[var(--ink-secondary)]",
              )}
            >
              All ({counts.all ?? 0})
            </button>
            {RESOURCE_CATEGORIES.map((cat) => (
              <button
                key={cat}
                type="button"
                aria-pressed={catFilter === cat}
                onClick={() => setCatFilter(cat)}
                className={cn(
                  "h-[36px] rounded-[var(--r-control)] border px-3 font-mono-tabular text-[12px]",
                  catFilter === cat
                    ? "border-[var(--accent-pine)] bg-[var(--accent-pine-soft)] font-semibold text-[var(--accent-pine)]"
                    : "border-[var(--border-control)] bg-[var(--bg-elevated)] text-[var(--ink-secondary)]",
                )}
              >
                {cat} ({counts[cat] ?? 0})
              </button>
            ))}
          </div>

          <select
            aria-label="Filter by semester"
            value={semesterFilter}
            onChange={(e) =>
              setSemesterFilter(
                e.target.value === "all" ? "all" : Number(e.target.value),
              )
            }
            className="font-mono-tabular h-[36px] rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-2.5 text-[12.5px]"
          >
            <option value="all">All Semesters</option>
            {RESOURCE_SEMESTERS.map((s) => (
              <option key={s} value={s}>
                Semester {s}
              </option>
            ))}
          </select>
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
            placeholder="Search title or course... (/)"
            aria-label="Search academic resources"
            className="h-[36px] w-full rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] pl-8 pr-3 text-[13px]"
          />
        </div>
      </div>

      <MasterDetailShell
        detailOpen={sheetOpen}
        onRequestClose={() => setSheetOpen(false)}
        detailTitle="Publish Academic Resource"
        detailSubtitle="Attach a file upload to bucket resources or link external Google Drive URL."
        master={
          isLoading ? (
            <LedgerTableSkeleton label="Loading academic resources" />
          ) : isError ? (
            <LedgerErrorRecovery
              title="Could not load academic resources"
              message={
                error instanceof Error ? error.message : "Supabase query failed."
              }
              onRetry={() => void refetch()}
            />
          ) : resources.length === 0 ? (
            <LedgerEmptyState
              icon={<FolderSimple size={20} aria-hidden="true" />}
              title="No academic resources uploaded yet"
              description="Share lecture notes, past-year question papers, slide decks, and assignments for mobile access."
              actionLabel="Add First Resource"
              onAction={() => setSheetOpen(true)}
            />
          ) : filtered.length === 0 ? (
            <LedgerFilterEmpty
              message="No resources match your active category, semester, or search."
              onReset={() => {
                setSearch("");
                setCatFilter("all");
                setSemesterFilter("all");
              }}
            />
          ) : (
            <DataLedgerTable
              data={filtered}
              columns={columns}
              getRowId={(r) => r.id}
              ariaLabel="Academic resources library"
              renderRowActions={(r) => (
                <button
                  type="button"
                  aria-label={`Delete resource ${r.title}`}
                  onClick={() => setDeleteTarget(r)}
                  className="flex h-7 w-7 items-center justify-center rounded-[5px] text-[var(--sem-conflict-ink)] hover:bg-[var(--sem-conflict-bg)]"
                >
                  <Trash size={14} aria-hidden="true" />
                </button>
              )}
            />
          )
        }
        detail={
          <form
            id="resource-upload-form"
            onSubmit={form.handleSubmit((vals) => createMutation.mutate(vals))}
            className="space-y-4"
            noValidate
          >
            <div>
              <label
                htmlFor="res-title"
                className="mb-1 block text-[12.5px] font-medium text-[var(--ink-primary)]"
              >
                Title
              </label>
              <input
                id="res-title"
                type="text"
                placeholder="e.g. Algorithms Midterm PYQ 2025"
                {...form.register("title")}
                className="h-[38px] w-full rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-3 text-[13.5px]"
              />
              {form.formState.errors.title && (
                <p className="mt-1 text-[12px] text-[var(--sem-conflict-ink)]">
                  {form.formState.errors.title.message}
                </p>
              )}
            </div>

            <div className="grid grid-cols-2 gap-3">
              <div>
                <label
                  htmlFor="res-category"
                  className="mb-1 block text-[12.5px] font-medium text-[var(--ink-primary)]"
                >
                  Category
                </label>
                <select
                  id="res-category"
                  {...form.register("category")}
                  className="h-[38px] w-full rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-3 text-[13px]"
                >
                  {RESOURCE_CATEGORIES.map((c) => (
                    <option key={c} value={c}>
                      {c}
                    </option>
                  ))}
                </select>
              </div>
              <div>
                <label
                  htmlFor="res-semester"
                  className="mb-1 block text-[12.5px] font-medium text-[var(--ink-primary)]"
                >
                  Semester
                </label>
                <select
                  id="res-semester"
                  {...form.register("semester")}
                  className="font-mono-tabular h-[38px] w-full rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-3 text-[13px]"
                >
                  {RESOURCE_SEMESTERS.map((s) => (
                    <option key={s} value={s}>
                      Semester {s}
                    </option>
                  ))}
                </select>
              </div>
            </div>

            <div>
              <label
                htmlFor="res-subject-code"
                className="mb-1 block text-[12.5px] font-medium text-[var(--ink-primary)]"
              >
                Course Code (optional)
              </label>
              <input
                id="res-subject-code"
                type="text"
                placeholder="e.g. CSE-2101"
                {...form.register("subject_code")}
                className="font-mono-tabular h-[38px] w-full rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-3 text-[13px] uppercase"
              />
            </div>

            <div>
              <label
                htmlFor="res-file"
                className="mb-1 block text-[12.5px] font-medium text-[var(--ink-primary)]"
              >
                Upload File (PDF, Slides, Document)
              </label>
              <label
                htmlFor="res-file"
                className="flex cursor-pointer items-center gap-2.5 rounded-[var(--r-control)] border border-dashed border-[var(--border-control)] bg-[var(--bg-canvas)]/60 px-3.5 py-2.5 text-[12.5px] text-[var(--ink-secondary)] hover:bg-[var(--surface-hover)]"
              >
                <FileArrowUp size={18} className="shrink-0 text-[var(--accent-pine)]" aria-hidden="true" />
                <span className="truncate">
                  {selectedFile ? selectedFile.name : "Choose file from computer..."}
                </span>
                <input
                  id="res-file"
                  type="file"
                  onChange={(e) => setSelectedFile(e.target.files?.[0] ?? null)}
                  className="sr-only"
                />
              </label>
            </div>

            <div>
              <label
                htmlFor="res-drive-link"
                className="mb-1 block text-[12.5px] font-medium text-[var(--ink-primary)]"
              >
                Or External HTTPS Drive Link
              </label>
              <input
                id="res-drive-link"
                type="url"
                placeholder="https://drive.google.com/..."
                {...form.register("drive_link")}
                className="font-mono-tabular h-[38px] w-full rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-3 text-[13px]"
              />
              {form.formState.errors.drive_link && (
                <p className="mt-1 text-[12px] text-[var(--sem-conflict-ink)]">
                  {form.formState.errors.drive_link.message}
                </p>
              )}
            </div>

            <label
              htmlFor="res-notify"
              className="flex cursor-pointer items-start gap-2.5 rounded-[var(--r-control)] border border-[var(--border-subtle)] bg-[var(--bg-canvas)]/55 px-3 py-2.5 text-[12.5px]"
            >
              <input
                id="res-notify"
                type="checkbox"
                {...form.register("notify_students")}
                className="mt-0.5 h-4 w-4 accent-[var(--accent-pine)]"
              />
              <span className="text-[var(--ink-primary)]">
                Notify students in Semester {selectedSemester} via Campus
                Broadcasts
              </span>
            </label>

            <StickyDirtyBar
              isDirty={
                form.formState.isDirty || selectedFile !== null || sheetOpen
              }
              isSaving={createMutation.isPending}
              message="Ready to publish academic resource"
              saveLabel="Publish Resource"
              formId="resource-upload-form"
              onDiscard={() => {
                setSheetOpen(false);
                setSelectedFile(null);
                form.reset();
              }}
            />
          </form>
        }
      />

      <ConfirmDialog
        open={deleteTarget !== null}
        onOpenChange={(open) => {
          if (!open) setDeleteTarget(null);
        }}
        title={`Delete "${deleteTarget?.title ?? ""}"?`}
        description="Removes the resource entry from public.resources and performs best-effort cleanup of uploaded bucket files."
        confirmLabel="Delete Resource"
        tone="destructive"
        isPending={deleteMutation.isPending}
        onConfirm={() => {
          if (deleteTarget) deleteMutation.mutate(deleteTarget);
        }}
      />
    </div>
  );
}
