import {
  ArrowCounterClockwise,
  ArrowRight,
  CaretDown,
  ClipboardText,
  Copy,
  DownloadSimple,
  MagnifyingGlass,
  Plus,
  Sparkle,
  Trash,
  WarningCircle,
  X,
} from "@phosphor-icons/react";
import { useQuery } from "@tanstack/react-query";
import {
  flexRender,
  tableFeatures,
  useTable,
  type ColumnDef,
} from "@tanstack/react-table";
import { useVirtualizer } from "@tanstack/react-virtual";
import { useMemo, useRef, useState } from "react";
import { toast } from "sonner";
import { Badge } from "@/components/ui/Badge";
import { Button } from "@/components/ui/Button";
import {
  CommandCombobox,
  type ComboboxOption,
} from "@/components/ui/CommandCombobox";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogTitle,
} from "@/components/ui/Dialog";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/DropdownMenu";
import { useWorkspaceShortcuts } from "@/core/hooks/useWorkspaceShortcuts";
import {
  fetchFaculty,
  type TimetableFacultyRecord,
} from "@/features/admin/services/facultyService";
import { fetchTimetableSettings } from "@/features/admin/services/settingsService";
import { useAuth } from "@/features/auth/AuthProvider";
import {
  buildCourseDistributionFile,
  computeDistributionSessions,
  isLabCourseCode,
  parseDistributionPaste,
  splitTeacherTokens,
  type CourseDistributionOfferingRow,
} from "@/features/routine/services/distributionXlsxBuilder";
import { fetchRoutines } from "@/features/routine/services/routineService";
import { triggerBrowserDownload } from "@/features/routine/services/timetableEngineService";
import {
  mapPublishedRoutinesToDistribution,
  useDistributionDraftStore,
} from "@/features/routine/store/distributionDraftStore";
import { cn } from "@/lib/utils";

type DistributionFilter =
  | "all"
  | "unknown-faculty"
  | "tba"
  | "joint"
  | "co-taught"
  | "service";

const DIST_STUDIO_FEATURES = tableFeatures({});

function isServiceRow(row: CourseDistributionOfferingRow): boolean {
  const b = row.batch.trim().toUpperCase();
  const s = row.section.trim().toUpperCase();
  if (/^(GED|WD|WE)/.test(s)) return true;
  if (b && !/^\d+$/.test(b) && !/^(RETAKE|IMPROVEMENT)/i.test(b)) return true;
  return row.conductingDept.trim().toUpperCase() !== "CSE";
}

export function DistributionStudioTab({
  onGenerateFromSheet,
}: {
  onGenerateFromSheet: () => void;
}) {
  const { isDevPreview } = useAuth();
  const searchRef = useRef<HTMLInputElement>(null);
  const tableScrollRef = useRef<HTMLDivElement>(null);

  const {
    termLabel,
    weeksInTerm,
    rows,
    past,
    setTermLabel,
    setWeeksInTerm,
    addRow,
    duplicateRow,
    updateRow,
    deleteRows,
    bulkUpdateRows,
    appendRows,
    replaceRows,
    loadFall2026Sample,
    clearAllRows,
    undo,
  } = useDistributionDraftStore();

  const [search, setSearch] = useState("");
  const [filter, setFilter] = useState<DistributionFilter>("all");
  const [batchFilter, setBatchFilter] = useState<string>("all");
  const [selectedIds, setSelectedIds] = useState<Set<string>>(() => new Set());
  const [inspectedId, setInspectedId] = useState<string | null>(null);
  const [pasteOpen, setPasteOpen] = useState(false);
  const [pasteText, setPasteText] = useState("");
  const [bulkDept, setBulkDept] = useState("CSE");
  const [bulkTeacher, setBulkTeacher] = useState("");

  useWorkspaceShortcuts({
    searchInputRef: searchRef,
    onEscape: () => {
      if (pasteOpen) {
        setPasteOpen(false);
      } else if (inspectedId) {
        setInspectedId(null);
      }
    },
  });

  const facultyQuery = useQuery({
    queryKey: ["timetable-faculty", isDevPreview],
    queryFn: () => fetchFaculty(isDevPreview),
    staleTime: 60_000,
  });

  const settingsQuery = useQuery({
    queryKey: ["timetable-settings", isDevPreview],
    queryFn: () => fetchTimetableSettings(isDevPreview),
    staleTime: 60_000,
  });

  const activeRoutinesQuery = useQuery({
    queryKey: ["routines", "active", isDevPreview],
    queryFn: () => fetchRoutines(isDevPreview),
    staleTime: 60_000,
  });

  const effectiveWeeks =
    settingsQuery.data?.weeks_in_term ?? weeksInTerm ?? 14;

  const facultyByAcronym = useMemo(() => {
    const map = new Map<string, TimetableFacultyRecord>();
    for (const f of facultyQuery.data ?? []) {
      map.set(f.acronym.trim().toUpperCase(), f);
    }
    return map;
  }, [facultyQuery.data]);

  const hasFacultyDirectory = facultyByAcronym.size > 0;

  const facultyOptions = useMemo<ComboboxOption[]>(() => {
    return (facultyQuery.data ?? [])
      .filter((f) => f.is_active)
      .map((f) => ({
        value: f.acronym,
        label: f.acronym,
        subtitle: `${f.full_name ?? "Faculty"}${
          f.off_days.length > 0 ? ` · Off: ${f.off_days.join(", ")}` : ""
        }`,
      }));
  }, [facultyQuery.data]);

  const rowDiagnostics = useMemo(() => {
    const map = new Map<
      string,
      {
        tokens: string[];
        unknownTokens: string[];
        isTba: boolean;
        isJoint: boolean;
        isCoTaught: boolean;
        isService: boolean;
        isLab: boolean;
        ruleBadge: string;
      }
    >();
    for (const r of rows) {
      const tokens = splitTeacherTokens(r.teacher);
      const unknownTokens = hasFacultyDirectory
        ? tokens.filter((t) => !facultyByAcronym.has(t.toUpperCase()))
        : [];
      const isLab = isLabCourseCode(r.courseCode, r.courseTitle);
      const derived = computeDistributionSessions(
        r.credit,
        effectiveWeeks,
        isLab,
      );
      map.set(r.id, {
        tokens,
        unknownTokens,
        isTba: tokens.length === 0,
        isJoint: r.section.includes("+"),
        isCoTaught: tokens.length > 1,
        isService: isServiceRow(r),
        isLab,
        ruleBadge: derived.ruleBadge,
      });
    }
    return map;
  }, [rows, hasFacultyDirectory, facultyByAcronym, effectiveWeeks]);

  const filterCounts = useMemo(() => {
    let unknownFaculty = 0;
    let tba = 0;
    let joint = 0;
    let coTaught = 0;
    let service = 0;
    for (const r of rows) {
      const d = rowDiagnostics.get(r.id);
      if (!d) continue;
      if (d.unknownTokens.length > 0) unknownFaculty++;
      if (d.isTba) tba++;
      if (d.isJoint) joint++;
      if (d.isCoTaught) coTaught++;
      if (d.isService) service++;
    }
    return {
      all: rows.length,
      unknownFaculty,
      tba,
      joint,
      coTaught,
      service,
    };
  }, [rows, rowDiagnostics]);

  const batches = useMemo(() => {
    const set = new Set<string>();
    for (const r of rows) {
      if (r.batch.trim()) set.add(r.batch.trim());
    }
    return Array.from(set).sort((a, b) => {
      const na = Number(a);
      const nb = Number(b);
      if (Number.isFinite(na) && Number.isFinite(nb)) return nb - na;
      if (Number.isFinite(na)) return -1;
      if (Number.isFinite(nb)) return 1;
      return a.localeCompare(b);
    });
  }, [rows]);

  const filteredRows = useMemo(() => {
    const q = search.trim().toLowerCase();
    return rows.filter((r) => {
      if (batchFilter !== "all" && r.batch.trim() !== batchFilter) return false;
      const diag = rowDiagnostics.get(r.id);
      if (filter === "unknown-faculty" && (!diag || diag.unknownTokens.length === 0))
        return false;
      if (filter === "tba" && !diag?.isTba) return false;
      if (filter === "joint" && !diag?.isJoint) return false;
      if (filter === "co-taught" && !diag?.isCoTaught) return false;
      if (filter === "service" && !diag?.isService) return false;

      if (!q) return true;
      return (
        r.batch.toLowerCase().includes(q) ||
        r.section.toLowerCase().includes(q) ||
        r.courseCode.toLowerCase().includes(q) ||
        r.courseTitle.toLowerCase().includes(q) ||
        r.teacher.toLowerCase().includes(q) ||
        r.conductingDept.toLowerCase().includes(q)
      );
    });
  }, [rows, batchFilter, filter, search, rowDiagnostics]);

  const inspectedRow = useMemo(
    () => rows.find((r) => r.id === inspectedId) ?? null,
    [rows, inspectedId],
  );

  const toggleSelect = (id: string) => {
    setSelectedIds((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  };

  const toggleSelectAllVisible = () => {
    const visibleIds = filteredRows.map((r) => r.id);
    const allSelected =
      visibleIds.length > 0 && visibleIds.every((id) => selectedIds.has(id));
    if (allSelected) {
      setSelectedIds(new Set());
    } else {
      setSelectedIds(new Set(visibleIds));
    }
  };

  const handleExportXlsx = () => {
    if (rows.length === 0) {
      toast.error("Add at least one course offering before exporting.");
      return;
    }
    const safeTerm = termLabel.trim().replace(/[^A-Za-z0-9_-]+/g, "_") || "Draft";
    const file = buildCourseDistributionFile(
      rows,
      `Course_Distribution_${safeTerm}.xlsx`,
      { termLabel },
    );
    triggerBrowserDownload(file, file.name);
    toast.success(`Exported ${file.name} (${rows.length} offerings).`);
  };

  const handleSeedFromActive = () => {
    const live = activeRoutinesQuery.data ?? [];
    if (live.length === 0) {
      toast.error("No active published routine rows found to import.");
      return;
    }
    const mapped = mapPublishedRoutinesToDistribution(live, effectiveWeeks);
    replaceRows(mapped);
    setSelectedIds(new Set());
    toast.success(`Imported ${mapped.length} offerings from active routine.`);
  };

  const handleApplyPaste = (mode: "append" | "replace") => {
    const parsed = parseDistributionPaste(pasteText, effectiveWeeks);
    if (parsed.length === 0) {
      toast.error("No valid offering rows detected in pasted text.");
      return;
    }
    if (mode === "replace") {
      replaceRows(parsed);
    } else {
      appendRows(parsed);
    }
    setPasteText("");
    setPasteOpen(false);
    toast.success(
      `${mode === "replace" ? "Replaced sheet with" : "Added"} ${parsed.length} pasted offering(s).`,
    );
  };

  const columns = useMemo<
    ColumnDef<typeof DIST_STUDIO_FEATURES, CourseDistributionOfferingRow, unknown>[]
  >(
    () => [
      {
        id: "select",
        header: () => {
          const allChecked =
            filteredRows.length > 0 &&
            filteredRows.every((r) => selectedIds.has(r.id));
          return (
            <input
              type="checkbox"
              aria-label="Select all visible offerings"
              checked={allChecked}
              onChange={toggleSelectAllVisible}
              className="h-3.5 w-3.5 accent-[var(--accent-brand)]"
            />
          );
        },
        cell: ({ row }) => (
          <input
            type="checkbox"
            aria-label={`Select ${row.original.courseCode} ${row.original.batch}-${row.original.section}`}
            checked={selectedIds.has(row.original.id)}
            onChange={() => toggleSelect(row.original.id)}
            onClick={(e) => e.stopPropagation()}
            className="h-3.5 w-3.5 accent-[var(--accent-brand)]"
          />
        ),
      },
      {
        accessorKey: "batch",
        header: "A · Batch",
        cell: ({ row }) => (
          <input
            type="text"
            aria-label="Batch"
            value={row.original.batch}
            onChange={(e) =>
              updateRow(row.original.id, { batch: e.target.value })
            }
            onClick={(e) => e.stopPropagation()}
            className="w-[62px] rounded border border-transparent bg-transparent px-1.5 py-1 font-mono-tabular text-[12.5px] font-semibold text-[var(--ink-primary)] hover:border-[var(--border-subtle)] focus:border-[var(--accent-brand)] focus:bg-[var(--bg-elevated)] focus:outline-none"
          />
        ),
      },
      {
        accessorKey: "section",
        header: "B · Sec",
        cell: ({ row }) => (
          <input
            type="text"
            aria-label="Section"
            value={row.original.section}
            onChange={(e) =>
              updateRow(row.original.id, { section: e.target.value })
            }
            onClick={(e) => e.stopPropagation()}
            placeholder="A / F+G"
            className="w-[64px] rounded border border-transparent bg-transparent px-1.5 py-1 font-mono-tabular text-[12.5px] text-[var(--ink-primary)] hover:border-[var(--border-subtle)] focus:border-[var(--accent-brand)] focus:bg-[var(--bg-elevated)] focus:outline-none"
          />
        ),
      },
      {
        accessorKey: "courseCode",
        header: "C · Code",
        cell: ({ row }) => (
          <input
            type="text"
            aria-label="Course Code"
            value={row.original.courseCode}
            onChange={(e) =>
              updateRow(row.original.id, {
                courseCode: e.target.value.toUpperCase(),
              })
            }
            onClick={(e) => e.stopPropagation()}
            className="w-[96px] rounded border border-transparent bg-transparent px-1.5 py-1 font-mono-tabular text-[12.5px] font-medium text-[var(--ink-primary)] hover:border-[var(--border-subtle)] focus:border-[var(--accent-brand)] focus:bg-[var(--bg-elevated)] focus:outline-none"
          />
        ),
      },
      {
        accessorKey: "courseTitle",
        header: "D · Course Title",
        cell: ({ row }) => (
          <input
            type="text"
            aria-label="Course Title"
            value={row.original.courseTitle}
            onChange={(e) =>
              updateRow(row.original.id, { courseTitle: e.target.value })
            }
            onClick={(e) => e.stopPropagation()}
            className="w-full min-w-[120px] rounded border border-transparent bg-transparent px-1.5 py-1 text-[12.5px] text-[var(--ink-primary)] hover:border-[var(--border-subtle)] focus:border-[var(--accent-brand)] focus:bg-[var(--bg-elevated)] focus:outline-none"
          />
        ),
      },
      {
        accessorKey: "credit",
        header: "E · Cr",
        cell: ({ row }) => (
          <input
            type="number"
            step="0.25"
            min="0"
            aria-label="Credit"
            value={row.original.credit ?? ""}
            onChange={(e) => {
              const v = e.target.value;
              updateRow(row.original.id, {
                credit: v === "" ? null : Number(v),
              });
            }}
            onClick={(e) => e.stopPropagation()}
            className="w-[56px] rounded border border-transparent bg-transparent px-1.5 py-1 text-right font-mono-tabular text-[12.5px] text-[var(--ink-primary)] hover:border-[var(--border-subtle)] focus:border-[var(--accent-brand)] focus:bg-[var(--bg-elevated)] focus:outline-none"
          />
        ),
      },
      {
        accessorKey: "prerequisite",
        header: "F · Prereq",
        cell: ({ row }) => (
          <input
            type="text"
            aria-label="Prerequisite"
            value={row.original.prerequisite}
            onChange={(e) =>
              updateRow(row.original.id, { prerequisite: e.target.value })
            }
            onClick={(e) => e.stopPropagation()}
            placeholder="—"
            className="w-[82px] rounded border border-transparent bg-transparent px-1.5 py-1 font-mono-tabular text-[12px] text-[var(--ink-secondary)] hover:border-[var(--border-subtle)] focus:border-[var(--accent-brand)] focus:bg-[var(--bg-elevated)] focus:outline-none"
          />
        ),
      },
      {
        accessorKey: "conductingDept",
        header: "G · Dept",
        cell: ({ row }) => (
          <input
            type="text"
            aria-label="Conducting Dept"
            value={row.original.conductingDept}
            onChange={(e) =>
              updateRow(row.original.id, {
                conductingDept: e.target.value.toUpperCase(),
              })
            }
            onClick={(e) => e.stopPropagation()}
            className="w-[62px] rounded border border-transparent bg-transparent px-1.5 py-1 font-mono-tabular text-[12px] text-[var(--ink-secondary)] hover:border-[var(--border-subtle)] focus:border-[var(--accent-brand)] focus:bg-[var(--bg-elevated)] focus:outline-none"
          />
        ),
      },
      {
        accessorKey: "students",
        header: "H · Stud",
        cell: ({ row }) => (
          <input
            type="number"
            min="1"
            aria-label="No. of Students"
            value={row.original.students ?? ""}
            placeholder="—"
            onChange={(e) => {
              const v = e.target.value;
              updateRow(row.original.id, {
                students: v === "" ? null : Number.parseInt(v, 10),
              });
            }}
            onClick={(e) => e.stopPropagation()}
            className="w-[58px] rounded border border-transparent bg-transparent px-1.5 py-1 text-right font-mono-tabular text-[12.5px] text-[var(--ink-secondary)] hover:border-[var(--border-subtle)] focus:border-[var(--accent-brand)] focus:bg-[var(--bg-elevated)] focus:outline-none"
          />
        ),
      },
      {
        accessorKey: "teacher",
        header: "I · Teacher",
        cell: ({ row }) => {
          const diag = rowDiagnostics.get(row.original.id);
          const hasUnknown = (diag?.unknownTokens.length ?? 0) > 0;
          return (
            <div
              className="flex items-center gap-1"
              onClick={(e) => e.stopPropagation()}
            >
              <input
                type="text"
                aria-label="Teacher acronym"
                value={row.original.teacher}
                placeholder="TBA"
                onChange={(e) =>
                  updateRow(row.original.id, {
                    teacher: e.target.value.toUpperCase(),
                  })
                }
                className={cn(
                  "w-[86px] rounded border bg-transparent px-1.5 py-1 font-mono-tabular text-[12.5px] font-medium focus:bg-[var(--bg-elevated)] focus:outline-none",
                  hasUnknown
                    ? "border-[var(--sem-conflict-bar)] text-[var(--sem-conflict-ink)]"
                    : diag?.isTba
                      ? "border-[var(--sem-joint-border)] text-[var(--sem-joint-ink)]"
                      : "border-transparent text-[var(--ink-primary)] hover:border-[var(--border-subtle)] focus:border-[var(--accent-brand)]",
                )}
              />
              {hasUnknown && (
                <span
                  title={`Unknown acronym: ${diag!.unknownTokens.join(", ")}`}
                  className="text-[var(--sem-conflict-bar)]"
                >
                  <WarningCircle size={14} aria-hidden="true" />
                </span>
              )}
            </div>
          );
        },
      },
      {
        accessorKey: "totalClasses",
        header: "J · Cls",
        cell: ({ row }) => (
          <input
            type="number"
            min="1"
            aria-label="No. of Classes"
            value={row.original.totalClasses ?? ""}
            onChange={(e) => {
              const v = e.target.value;
              updateRow(row.original.id, {
                totalClasses: v === "" ? null : Number.parseInt(v, 10),
              });
            }}
            onClick={(e) => e.stopPropagation()}
            className="w-[54px] rounded border border-transparent bg-transparent px-1.5 py-1 text-right font-mono-tabular text-[12.5px] text-[var(--ink-primary)] hover:border-[var(--border-subtle)] focus:border-[var(--accent-brand)] focus:bg-[var(--bg-elevated)] focus:outline-none"
          />
        ),
      },
      {
        accessorKey: "classDuration",
        header: "K · Dur",
        cell: ({ row }) => (
          <input
            type="number"
            step="0.25"
            min="0.5"
            aria-label="Class Duration"
            value={row.original.classDuration ?? ""}
            onChange={(e) => {
              const v = e.target.value;
              updateRow(row.original.id, {
                classDuration: v === "" ? null : Number(v),
              });
            }}
            onClick={(e) => e.stopPropagation()}
            className="w-[52px] rounded border border-transparent bg-transparent px-1.5 py-1 text-right font-mono-tabular text-[12px] text-[var(--ink-secondary)] hover:border-[var(--border-subtle)] focus:border-[var(--accent-brand)] focus:bg-[var(--bg-elevated)] focus:outline-none"
          />
        ),
      },
      {
        accessorKey: "classesPerWeek",
        header: "L · /Wk",
        cell: ({ row }) => (
          <input
            type="number"
            min="1"
            aria-label="Classes Per Week"
            value={row.original.classesPerWeek ?? ""}
            onChange={(e) => {
              const v = e.target.value;
              updateRow(row.original.id, {
                classesPerWeek: v === "" ? null : Number.parseInt(v, 10),
              });
            }}
            onClick={(e) => e.stopPropagation()}
            className="w-[48px] rounded border border-transparent bg-transparent px-1.5 py-1 text-right font-mono-tabular text-[12.5px] font-semibold text-[var(--ink-primary)] hover:border-[var(--border-subtle)] focus:border-[var(--accent-brand)] focus:bg-[var(--bg-elevated)] focus:outline-none"
          />
        ),
      },
      {
        id: "actions",
        header: "",
        cell: ({ row }) => (
          <div
            className="row-reveal-action flex items-center justify-end gap-1"
            onClick={(e) => e.stopPropagation()}
          >
            <button
              type="button"
              aria-label={`Duplicate ${row.original.courseCode}`}
              onClick={() => duplicateRow(row.original.id)}
              className="rounded p-1 text-[var(--ink-muted)] hover:bg-[var(--surface-hover)] hover:text-[var(--ink-primary)]"
            >
              <Copy size={13} aria-hidden="true" />
            </button>
            <button
              type="button"
              aria-label={`Delete ${row.original.courseCode}`}
              onClick={() => deleteRows([row.original.id])}
              className="rounded p-1 text-[var(--ink-muted)] hover:bg-[var(--sem-conflict-bg)] hover:text-[var(--sem-conflict-ink)]"
            >
              <Trash size={13} aria-hidden="true" />
            </button>
          </div>
        ),
      },
    ],
    [filteredRows, selectedIds, rowDiagnostics, updateRow, duplicateRow, deleteRows],
  );

  const table = useTable<
    typeof DIST_STUDIO_FEATURES,
    CourseDistributionOfferingRow
  >({
    features: DIST_STUDIO_FEATURES,
    data: filteredRows,
    columns,
    getRowId: (r) => r.id,
  });

  const tableRows = table.getRowModel().rows;
  const rowVirtualizer = useVirtualizer({
    count: tableRows.length,
    getScrollElement: () => tableScrollRef.current,
    estimateSize: () => 40,
    overscan: 8,
  });

  const virtualItems = rowVirtualizer.getVirtualItems();
  const paddingTop = virtualItems.length > 0 ? virtualItems[0]!.start : 0;
  const paddingBottom =
    virtualItems.length > 0
      ? rowVirtualizer.getTotalSize() - virtualItems[virtualItems.length - 1]!.end
      : 0;

  return (
    <div className="space-y-4">
      {/* Honesty / Persistence Disclosure Banner */}
      <div
        data-testid="distribution-local-draft-banner"
        className="flex flex-wrap items-center justify-between gap-3 rounded-[var(--r-card)] border border-[var(--sem-joint-border)] bg-[var(--sem-joint-bg)] px-3.5 py-2.5 text-[12.5px] text-[var(--sem-joint-ink)]"
      >
        <div className="flex items-center gap-2">
          <Badge tone="joint" mono>
            Local Committee Draft
          </Badge>
          <span>
            Saved in this browser — export <code>.xlsx</code> or send directly
            to CP-SAT solver; database revision archiving unlocks with Track 2
            Gates A–B.
          </span>
        </div>
        <div className="flex items-center gap-2 text-[12px]">
          <label className="flex items-center gap-1.5">
            <span className="font-medium">Term:</span>
            <input
              type="text"
              aria-label="Term label"
              value={termLabel}
              onChange={(e) => setTermLabel(e.target.value)}
              className="h-[28px] w-[112px] rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-2 text-[12px] text-[var(--ink-primary)]"
            />
          </label>
          <label className="flex items-center gap-1.5">
            <span className="font-medium">Weeks:</span>
            <input
              type="number"
              min={1}
              max={26}
              aria-label="Weeks in term"
              value={weeksInTerm}
              onChange={(e) => setWeeksInTerm(Number(e.target.value))}
              className="h-[28px] w-[54px] rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-2 text-right font-mono-tabular text-[12px] text-[var(--ink-primary)]"
            />
          </label>
        </div>
      </div>

      {/* Connected 36px Toolbar */}
      <div className="ledger-card p-3">
        <div className="flex flex-wrap items-center justify-between gap-2.5">
          <div className="flex flex-wrap items-center gap-2">
            <div className="relative">
              <MagnifyingGlass
                size={14}
                aria-hidden="true"
                className="pointer-events-none absolute left-2.5 top-1/2 -translate-y-1/2 text-[var(--ink-muted)]"
              />
              <input
                ref={searchRef}
                type="search"
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                placeholder="Search code, batch, teacher ( / )"
                aria-label="Search distribution offerings"
                className="h-[36px] w-[220px] rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] pl-8 pr-3 text-[12.5px] text-[var(--ink-primary)] placeholder:text-[var(--ink-muted)] focus:border-[var(--accent-brand)] focus:outline-none"
              />
            </div>

            <select
              aria-label="Filter by batch"
              value={batchFilter}
              onChange={(e) => setBatchFilter(e.target.value)}
              className="h-[36px] rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-2.5 text-[12.5px] text-[var(--ink-primary)]"
            >
              <option value="all">All Batches ({batches.length})</option>
              {batches.map((b) => (
                <option key={b} value={b}>
                  Batch {b}
                </option>
              ))}
            </select>
          </div>

          <div className="flex flex-wrap items-center gap-2">
            <Button
              type="button"
              variant="secondary"
              size="sm"
              onClick={() => {
                const newId = addRow();
                setInspectedId(newId);
              }}
              data-testid="dist-add-offering-btn"
            >
              <Plus size={14} aria-hidden="true" />
              <span>Add Offering</span>
            </Button>

            <Button
              type="button"
              variant="secondary"
              size="sm"
              onClick={() => setPasteOpen(true)}
              data-testid="dist-paste-rows-btn"
            >
              <ClipboardText size={14} aria-hidden="true" />
              <span>Paste Rows</span>
            </Button>

            <DropdownMenu>
              <DropdownMenuTrigger asChild>
                <Button type="button" variant="secondary" size="sm">
                  <Sparkle size={14} aria-hidden="true" />
                  <span>Seed / Reset</span>
                  <CaretDown size={12} aria-hidden="true" />
                </Button>
              </DropdownMenuTrigger>
              <DropdownMenuContent align="end" className="w-[230px]">
                <DropdownMenuItem onSelect={handleSeedFromActive}>
                  Seed From Active Routine ({activeRoutinesQuery.data?.length ?? 0} slots)
                </DropdownMenuItem>
                <DropdownMenuItem
                  onSelect={() => {
                    loadFall2026Sample();
                    toast.success("Loaded Fall 2026 CSE sample distribution.");
                  }}
                >
                  Load Fall 2026 CSE Sample
                </DropdownMenuItem>
                <DropdownMenuItem
                  disabled={past.length === 0}
                  onSelect={undo}
                >
                  <ArrowCounterClockwise size={14} aria-hidden="true" />
                  <span>Undo Last Edit ({past.length})</span>
                </DropdownMenuItem>
                <DropdownMenuSeparator />
                <DropdownMenuItem
                  onSelect={() => {
                    clearAllRows();
                    setSelectedIds(new Set());
                    setInspectedId(null);
                  }}
                  className="text-[var(--sem-conflict-ink)]"
                >
                  Clear Sheet
                </DropdownMenuItem>
              </DropdownMenuContent>
            </DropdownMenu>

            <Button
              type="button"
              variant="secondary"
              size="sm"
              onClick={handleExportXlsx}
              data-testid="dist-export-xlsx-btn"
            >
              <DownloadSimple size={14} aria-hidden="true" />
              <span>Export .xlsx</span>
            </Button>

            <Button
              type="button"
              variant="primary"
              size="sm"
              className="!h-[36px]"
              disabled={rows.length === 0}
              onClick={onGenerateFromSheet}
              data-testid="dist-generate-cta"
            >
              <span>Generate Routine From Sheet</span>
              <ArrowRight size={14} aria-hidden="true" />
            </Button>
          </div>
        </div>

        {/* Upfront Filter Counts */}
        <div className="mt-2.5 flex flex-wrap items-center justify-between gap-2 border-t border-[var(--border-subtle)] pt-2.5">
          <div className="flex flex-wrap items-center gap-1.5">
            {(
              [
                ["all", `All (${filterCounts.all})`],
                ["unknown-faculty", `Unknown Faculty (${filterCounts.unknownFaculty})`],
                ["tba", `Pending TBA (${filterCounts.tba})`],
                ["joint", `Joint Cohorts (${filterCounts.joint})`],
                ["co-taught", `Co-Taught (${filterCounts.coTaught})`],
                ["service", `Service Dept (${filterCounts.service})`],
              ] as const
            ).map(([key, label]) => (
              <button
                key={key}
                type="button"
                onClick={() => setFilter(key)}
                className={cn(
                  "h-[28px] rounded-[var(--r-pill)] border px-2.5 font-mono-tabular text-[11.5px] font-medium transition-colors",
                  filter === key
                    ? "border-[var(--accent-brand)] bg-[var(--accent-brand-soft)] text-[var(--accent-brand)]"
                    : "border-[var(--border-subtle)] bg-[var(--bg-surface)] text-[var(--ink-secondary)] hover:bg-[var(--surface-hover)] hover:text-[var(--ink-primary)]",
                )}
              >
                {label}
              </button>
            ))}
          </div>
          <span className="font-mono-tabular text-[11.5px] text-[var(--ink-muted)]">
            Showing {filteredRows.length} of {rows.length} offerings
            {!hasFacultyDirectory && " · Faculty directory empty (acronym check skipped)"}
          </span>
        </div>
      </div>

      {/* Contextual Multi-Select Bulk Bar */}
      {selectedIds.size > 0 && (
        <div className="flex flex-wrap items-center justify-between gap-3 rounded-[var(--r-card)] border border-[var(--accent-brand-border)] bg-[var(--accent-brand-soft)] px-3.5 py-2 text-[12.5px]">
          <span className="font-mono-tabular font-semibold text-[var(--accent-brand)]">
            {selectedIds.size} offering(s) selected
          </span>
          <div className="flex flex-wrap items-center gap-2">
            <div className="flex items-center gap-1">
              <input
                type="text"
                value={bulkDept}
                onChange={(e) => setBulkDept(e.target.value.toUpperCase())}
                placeholder="Dept"
                className="h-[30px] w-[66px] rounded border border-[var(--border-control)] bg-[var(--bg-elevated)] px-2 font-mono-tabular text-[12px] text-[var(--ink-primary)]"
              />
              <Button
                type="button"
                variant="secondary"
                size="sm"
                className="!h-[30px]"
                onClick={() => {
                  bulkUpdateRows(Array.from(selectedIds), {
                    conductingDept: bulkDept,
                  });
                  toast.success(`Updated Dept to ${bulkDept}.`);
                }}
              >
                Set Dept
              </Button>
            </div>

            <div className="flex items-center gap-1">
              <input
                type="text"
                value={bulkTeacher}
                onChange={(e) => setBulkTeacher(e.target.value.toUpperCase())}
                placeholder="Teacher"
                className="h-[30px] w-[80px] rounded border border-[var(--border-control)] bg-[var(--bg-elevated)] px-2 font-mono-tabular text-[12px] text-[var(--ink-primary)]"
              />
              <Button
                type="button"
                variant="secondary"
                size="sm"
                className="!h-[30px]"
                onClick={() => {
                  bulkUpdateRows(Array.from(selectedIds), {
                    teacher: bulkTeacher,
                  });
                  toast.success(`Updated Teacher to ${bulkTeacher || "TBA"}.`);
                }}
              >
                Set Teacher
              </Button>
            </div>

            <Button
              type="button"
              variant="secondary"
              size="sm"
              className="!h-[30px]"
              onClick={() => {
                deleteRows(Array.from(selectedIds));
                setSelectedIds(new Set());
              }}
            >
              <Trash size={13} aria-hidden="true" />
              <span>Delete Selected</span>
            </Button>

            <button
              type="button"
              onClick={() => setSelectedIds(new Set())}
              className="text-[12px] text-[var(--ink-secondary)] underline"
            >
              Clear
            </button>
          </div>
        </div>
      )}

      {/* Main Split: Virtualized A-L Table + Optional Docked Row Inspector */}
      <div
        className={cn(
          "grid grid-cols-1 gap-4",
          inspectedRow && "min-[1100px]:grid-cols-[minmax(0,1fr)_340px]",
        )}
      >
        <div className="ledger-sheet overflow-hidden">
          <div
            ref={tableScrollRef}
            className="max-h-[560px] overflow-auto"
            data-testid="distribution-table-scroll"
          >
            <table className="w-full border-collapse text-left">
              <thead className="sticky top-0 z-10 border-b border-[var(--border-subtle)] bg-[var(--bg-raised)]">
                {table.getHeaderGroups().map((hg) => (
                  <tr key={hg.id}>
                    {hg.headers.map((header) => (
                      <th
                        key={header.id}
                        className="whitespace-nowrap px-1.5 py-2 font-mono-tabular text-[11px] font-semibold uppercase tracking-[0.04em] text-[var(--ink-secondary)]"
                      >
                        {flexRender(
                          header.column.columnDef.header,
                          header.getContext(),
                        )}
                      </th>
                    ))}
                  </tr>
                ))}
              </thead>
              <tbody>
                {paddingTop > 0 && (
                  <tr>
                    <td
                      colSpan={columns.length}
                      style={{ height: `${paddingTop}px` }}
                    />
                  </tr>
                )}
                {tableRows.length === 0 ? (
                  <tr>
                    <td
                      colSpan={columns.length}
                      className="px-4 py-12 text-center text-[13px] text-[var(--ink-muted)]"
                    >
                      No offerings match this filter. Clear filters or add an
                      offering row.
                    </td>
                  </tr>
                ) : (
                  virtualItems.map((vRow) => {
                    const row = tableRows[vRow.index]!;
                    const isInspected = inspectedId === row.original.id;
                    return (
                      <tr
                        key={row.id}
                        onClick={() => setInspectedId(row.original.id)}
                        className={cn(
                          "group cursor-pointer border-b border-[var(--border-subtle)] transition-colors",
                          isInspected
                            ? "bg-[var(--accent-brand-soft)]"
                            : "hover:bg-[var(--surface-hover)]",
                        )}
                      >
                        {row.getAllCells().map((cell) => (
                          <td
                            key={cell.id}
                            className="px-1.5 py-1 align-middle"
                          >
                            {flexRender(
                              cell.column.columnDef.cell,
                              cell.getContext(),
                            )}
                          </td>
                        ))}
                      </tr>
                    );
                  })
                )}
                {paddingBottom > 0 && (
                  <tr>
                    <td
                      colSpan={columns.length}
                      style={{ height: `${paddingBottom}px` }}
                    />
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </div>

        {/* Docked Offering Inspector */}
        {inspectedRow && (
          <aside
            aria-label="Offering inspector"
            className="ledger-sheet flex flex-col gap-3 p-4"
            data-testid="distribution-row-inspector"
          >
            <div className="flex items-start justify-between gap-2 border-b border-[var(--border-subtle)] pb-2.5">
              <div>
                <p className="font-mono-tabular text-[11px] font-semibold uppercase tracking-[0.06em] text-[var(--ink-muted)]">
                  Offering Inspector
                </p>
                <h3 className="mt-0.5 font-mono-tabular text-[15px] font-semibold text-[var(--ink-primary)]">
                  {inspectedRow.batch}-{inspectedRow.section || "—"} ·{" "}
                  {inspectedRow.courseCode || "NEW"}
                </h3>
              </div>
              <button
                type="button"
                aria-label="Close inspector"
                onClick={() => setInspectedId(null)}
                className="rounded p-1 text-[var(--ink-muted)] hover:bg-[var(--surface-hover)] hover:text-[var(--ink-primary)]"
              >
                <X size={15} aria-hidden="true" />
              </button>
            </div>

            {(() => {
              const diag = rowDiagnostics.get(inspectedRow.id);
              return (
                <>
                  <div className="flex flex-wrap gap-1.5">
                    <Badge tone={diag?.isLab ? "lab" : "theory"} mono>
                      {diag?.ruleBadge ?? "Theory"}
                    </Badge>
                    {diag?.isJoint && (
                      <Badge tone="joint" mono>
                        Joint Cohort
                      </Badge>
                    )}
                    {diag?.isCoTaught && (
                      <Badge tone="conflict" mono>
                        Co-Taught (F-22 Publish Guard)
                      </Badge>
                    )}
                    {diag?.isTba && (
                      <Badge tone="joint" mono>
                        Pending TBA Faculty
                      </Badge>
                    )}
                  </div>

                  {diag && diag.unknownTokens.length > 0 && (
                    <div className="rounded-[var(--r-control)] border border-[var(--sem-conflict-border)] bg-[var(--sem-conflict-bg)] px-2.5 py-2 text-[12px] text-[var(--sem-conflict-ink)]">
                      Unknown faculty acronym(s):{" "}
                      <strong className="font-mono-tabular">
                        {diag.unknownTokens.join(", ")}
                      </strong>{" "}
                      not found in <code>timetable_faculty</code>.
                    </div>
                  )}

                  {facultyOptions.length > 0 && (
                    <div className="space-y-1">
                      <label className="text-[12px] font-medium text-[var(--ink-secondary)]">
                        Assign Primary Faculty (Directory Picker)
                      </label>
                      <CommandCombobox
                        value={
                          splitTeacherTokens(inspectedRow.teacher)[0] ?? ""
                        }
                        onChange={(acronym) =>
                          updateRow(inspectedRow.id, { teacher: acronym })
                        }
                        options={facultyOptions}
                        placeholder="Select faculty acronym..."
                        searchPlaceholder="Search acronym or name..."
                        emptyLabel="No matching faculty."
                        allowCustom
                        normalizeValue={(raw) => raw.toUpperCase()}
                      />
                    </div>
                  )}

                  <div className="grid grid-cols-2 gap-2.5 text-[12.5px]">
                    <label className="space-y-1">
                      <span className="text-[11.5px] text-[var(--ink-secondary)]">
                        Batch (A)
                      </span>
                      <input
                        type="text"
                        value={inspectedRow.batch}
                        onChange={(e) =>
                          updateRow(inspectedRow.id, { batch: e.target.value })
                        }
                        className="h-[34px] w-full rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-2.5 font-mono-tabular text-[var(--ink-primary)]"
                      />
                    </label>
                    <label className="space-y-1">
                      <span className="text-[11.5px] text-[var(--ink-secondary)]">
                        Section (B)
                      </span>
                      <input
                        type="text"
                        value={inspectedRow.section}
                        onChange={(e) =>
                          updateRow(inspectedRow.id, {
                            section: e.target.value,
                          })
                        }
                        className="h-[34px] w-full rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-2.5 font-mono-tabular text-[var(--ink-primary)]"
                      />
                    </label>
                    <label className="space-y-1">
                      <span className="text-[11.5px] text-[var(--ink-secondary)]">
                        Course Code (C)
                      </span>
                      <input
                        type="text"
                        value={inspectedRow.courseCode}
                        onChange={(e) =>
                          updateRow(inspectedRow.id, {
                            courseCode: e.target.value.toUpperCase(),
                          })
                        }
                        className="h-[34px] w-full rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-2.5 font-mono-tabular text-[var(--ink-primary)]"
                      />
                    </label>
                    <label className="space-y-1">
                      <span className="text-[11.5px] text-[var(--ink-secondary)]">
                        Credit (E)
                      </span>
                      <input
                        type="number"
                        step="0.25"
                        value={inspectedRow.credit ?? ""}
                        onChange={(e) =>
                          updateRow(inspectedRow.id, {
                            credit:
                              e.target.value === ""
                                ? null
                                : Number(e.target.value),
                          })
                        }
                        className="h-[34px] w-full rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-2.5 font-mono-tabular text-[var(--ink-primary)]"
                      />
                    </label>
                    <label className="col-span-2 space-y-1">
                      <span className="text-[11.5px] text-[var(--ink-secondary)]">
                        Course Title (D)
                      </span>
                      <input
                        type="text"
                        value={inspectedRow.courseTitle}
                        onChange={(e) =>
                          updateRow(inspectedRow.id, {
                            courseTitle: e.target.value,
                          })
                        }
                        className="h-[34px] w-full rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-2.5 text-[var(--ink-primary)]"
                      />
                    </label>
                    <label className="space-y-1">
                      <span className="text-[11.5px] text-[var(--ink-secondary)]">
                        Total Classes (J)
                      </span>
                      <input
                        type="number"
                        value={inspectedRow.totalClasses ?? ""}
                        onChange={(e) =>
                          updateRow(inspectedRow.id, {
                            totalClasses:
                              e.target.value === ""
                                ? null
                                : Number.parseInt(e.target.value, 10),
                          })
                        }
                        className="h-[34px] w-full rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-2.5 font-mono-tabular text-[var(--ink-primary)]"
                      />
                    </label>
                    <label className="space-y-1">
                      <span className="text-[11.5px] text-[var(--ink-secondary)]">
                        Classes / Week (L)
                      </span>
                      <input
                        type="number"
                        value={inspectedRow.classesPerWeek ?? ""}
                        onChange={(e) =>
                          updateRow(inspectedRow.id, {
                            classesPerWeek:
                              e.target.value === ""
                                ? null
                                : Number.parseInt(e.target.value, 10),
                          })
                        }
                        className="h-[34px] w-full rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-2.5 font-mono-tabular text-[var(--ink-primary)]"
                      />
                    </label>
                  </div>
                </>
              );
            })()}
          </aside>
        )}
      </div>

      {/* Paste TSV / CSV Dialog */}
      <Dialog open={pasteOpen} onOpenChange={setPasteOpen}>
        <DialogContent className="fixed left-1/2 top-1/2 w-[calc(100vw-2rem)] max-w-[640px] -translate-x-1/2 -translate-y-1/2 p-5">
          <DialogTitle className="text-[16px] font-semibold text-[var(--ink-primary)]">
            Paste Rows From Excel or Google Sheets
          </DialogTitle>
          <DialogDescription className="mt-1 text-[12.5px] text-[var(--ink-secondary)]">
            Paste tab-separated (TSV) or CSV rows matching Columns A–L (Batch,
            Section, Course Code, Course Title, Credit, Prerequisite, Dept,
            Students, Teacher, No. of Classes, Duration, Class/Week).
          </DialogDescription>
          <textarea
            rows={8}
            value={pasteText}
            onChange={(e) => setPasteText(e.target.value)}
            placeholder={"69\tA\tCSE-1101\tStructured Programming\t3\t\tCSE\t45\tEBH\t28\t1.5\t2"}
            data-testid="dist-paste-textarea"
            className="mt-3 w-full rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] p-3 font-mono-tabular text-[12px] text-[var(--ink-primary)]"
          />
          <div className="mt-4 flex flex-wrap justify-end gap-2">
            <Button
              type="button"
              variant="secondary"
              size="sm"
              onClick={() => setPasteOpen(false)}
            >
              Cancel
            </Button>
            <Button
              type="button"
              variant="secondary"
              size="sm"
              onClick={() => handleApplyPaste("append")}
              data-testid="dist-paste-append-btn"
            >
              Append Rows
            </Button>
            <Button
              type="button"
              variant="primary"
              size="sm"
              className="!h-[36px]"
              onClick={() => handleApplyPaste("replace")}
              data-testid="dist-paste-replace-btn"
            >
              Replace Sheet
            </Button>
          </div>
        </DialogContent>
      </Dialog>
    </div>
  );
}
