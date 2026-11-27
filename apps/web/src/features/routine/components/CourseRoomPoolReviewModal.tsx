import {
  ArrowCounterClockwise,
  CheckCircle,
  MagnifyingGlass,
  SlidersHorizontal,
  WarningCircle,
  X,
} from "@phosphor-icons/react";
import { useEffect, useMemo, useState } from "react";
import { Badge } from "@/components/ui/Badge";
import { Button } from "@/components/ui/Button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogTitle,
} from "@/components/ui/Dialog";
import {
  createCatalogCourse,
  updateCatalogCourse,
} from "@/features/admin/services/coursesService";
import {
  COURSE_ROOM_POOL_LABELS,
  encodeRoomPoolOverrideNote,
  type ClassifiedWorkbookCourse,
  type CourseRoomPool,
} from "@/features/routine/services/workbookCourseScanner";
import { cn } from "@/lib/utils";

type FilterTab = "review" | "all" | "overridden";

export interface CourseRoomPoolReviewModalProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  courses: readonly ClassifiedWorkbookCourse[];
  isDevPreview: boolean;
  onSaved: (summary: { savedCount: number }) => void;
}

const POOL_OPTIONS: readonly { value: CourseRoomPool; label: string }[] = [
  { value: "theory", label: COURSE_ROOM_POOL_LABELS.theory },
  { value: "cse_lab", label: COURSE_ROOM_POOL_LABELS.cse_lab },
  { value: "ecl_lab", label: COURSE_ROOM_POOL_LABELS.ecl_lab },
  { value: "physics_lab", label: COURSE_ROOM_POOL_LABELS.physics_lab },
];

export function CourseRoomPoolReviewModal({
  open,
  onOpenChange,
  courses,
  isDevPreview,
  onSaved,
}: CourseRoomPoolReviewModalProps) {
  const [activeTab, setActiveTab] = useState<FilterTab>("review");
  const [search, setSearch] = useState("");
  const [draftPools, setDraftPools] = useState<Record<string, CourseRoomPool>>(
    {},
  );
  const [isSaving, setIsSaving] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);

  useEffect(() => {
    if (open) {
      setDraftPools({});
      setSaveError(null);
      setSearch("");
      const hasReviewItems = courses.some((c) => c.needsReview);
      setActiveTab(hasReviewItems ? "review" : "all");
    }
  }, [open, courses]);

  const effectivePoolOf = (course: ClassifiedWorkbookCourse): CourseRoomPool =>
    draftPools[course.code] ?? course.roomPool;

  const isRowModified = (course: ClassifiedWorkbookCourse): boolean =>
    draftPools[course.code] !== undefined &&
    draftPools[course.code] !== course.roomPool;

  const modifiedCourses = useMemo(
    () => courses.filter((c) => isRowModified(c)),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [courses, draftPools],
  );

  const reviewCount = useMemo(
    () => courses.filter((c) => c.needsReview).length,
    [courses],
  );

  const overriddenCount = useMemo(
    () =>
      courses.filter(
        (c) =>
          isRowModified(c) ||
          (draftPools[c.code] === undefined && c.isCatalogOverridden),
      ).length,
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [courses, draftPools],
  );

  const filteredCourses = useMemo(() => {
    const q = search.trim().toLowerCase();
    return courses.filter((c) => {
      if (activeTab === "review" && !c.needsReview) return false;
      if (activeTab === "overridden") {
        const overridden =
          isRowModified(c) ||
          (draftPools[c.code] === undefined && c.isCatalogOverridden);
        if (!overridden) return false;
      }
      if (!q) return true;
      return (
        c.code.toLowerCase().includes(q) ||
        c.title.toLowerCase().includes(q) ||
        (c.conductingDept ?? "").toLowerCase().includes(q) ||
        c.autoDetectedReason.toLowerCase().includes(q)
      );
    });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [courses, activeTab, search, draftPools]);

  const handlePoolChange = (
    course: ClassifiedWorkbookCourse,
    nextPool: CourseRoomPool,
  ) => {
    setDraftPools((prev) => {
      const next = { ...prev };
      if (nextPool === course.roomPool) {
        delete next[course.code];
      } else {
        next[course.code] = nextPool;
      }
      return next;
    });
  };

  const handleResetRow = (course: ClassifiedWorkbookCourse) => {
    setDraftPools((prev) => {
      const next = { ...prev };
      if (prev[course.code] !== undefined) {
        delete next[course.code];
      } else if (course.roomPool !== course.heuristicPool) {
        next[course.code] = course.heuristicPool;
      }
      return next;
    });
  };

  const handleSave = async () => {
    if (isDevPreview || modifiedCourses.length === 0 || isSaving) return;
    setIsSaving(true);
    setSaveError(null);

    let savedCount = 0;
    const errors: string[] = [];

    try {
      for (const course of modifiedCourses) {
        const nextPool = effectivePoolOf(course);
        const classType = nextPool === "theory" ? "theory" : "lab";
        const isPhysicsLab = nextPool === "physics_lab";
        const existing = course.catalogRecord;
        const notes = encodeRoomPoolOverrideNote(
          existing?.notes ?? null,
          nextPool,
        );

        const payload = {
          code: course.code,
          title: existing?.title || course.title || course.code,
          dept_code: existing?.dept_code || course.conductingDept || "CSE",
          credit:
            existing?.credit ??
            (course.credit && course.credit > 0 ? course.credit : 3.0),
          class_type: classType as "theory" | "lab",
          is_service: existing?.is_service ?? false,
          is_physics_lab: isPhysicsLab,
          default_weekly_sessions: existing?.default_weekly_sessions ?? null,
          is_active: true,
          notes,
        };

        try {
          if (existing) {
            await updateCatalogCourse(existing.id, payload, false);
          } else {
            await createCatalogCourse(payload, false);
          }
          savedCount += 1;
        } catch (err) {
          errors.push(
            `${course.code}: ${err instanceof Error ? err.message : "Save failed."}`,
          );
        }
      }

      if (savedCount > 0) {
        onSaved({ savedCount });
      }
      if (errors.length > 0) {
        setSaveError(errors.join(" "));
      } else {
        onOpenChange(false);
      }
    } finally {
      setIsSaving(false);
    }
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent
        className="max-w-4xl p-0 overflow-hidden"
        data-testid="course-room-pool-review-modal"
      >
        {/* Header */}
        <div className="flex items-start justify-between gap-3 border-b border-[var(--border-subtle)] bg-[var(--bg-subtle)] px-5 py-4">
          <div className="min-w-0 space-y-1">
            <div className="flex items-center gap-2">
              <SlidersHorizontal
                size={17}
                className="text-[var(--brand-accent)]"
                aria-hidden="true"
              />
              <DialogTitle className="text-[16px] font-semibold text-[var(--ink-primary)]">
                Course Room-Pool Preflight Review
              </DialogTitle>
            </div>
            <DialogDescription className="text-[12.5px] text-[var(--ink-secondary)]">
              Inspect auto-classified courses and override any room pool (Theory
              Room, CSE Lab, ECL Lab, or Physics Lab) before running CP-SAT.
              Saved overrides persist in the Course Catalog for future semesters.
            </DialogDescription>
          </div>
          <Button
            type="button"
            variant="ghost"
            size="sm"
            aria-label="Close room-pool review modal"
            onClick={() => onOpenChange(false)}
          >
            <X size={16} />
          </Button>
        </div>

        {/* Filter Tabs & Search */}
        <div className="flex flex-wrap items-center justify-between gap-3 border-b border-[var(--border-subtle)] bg-[var(--bg-surface)] px-5 py-3">
          <div
            role="tablist"
            aria-label="Course room-pool filters"
            className="flex flex-wrap items-center gap-1.5"
          >
            {(
              [
                {
                  id: "review" as const,
                  label: `Needs Review / GED (${reviewCount})`,
                },
                {
                  id: "all" as const,
                  label: `All Courses (${courses.length})`,
                },
                {
                  id: "overridden" as const,
                  label: `Overridden (${overriddenCount})`,
                },
              ] as const
            ).map((tab) => (
              <button
                key={tab.id}
                type="button"
                role="tab"
                aria-selected={activeTab === tab.id}
                data-testid={`room-pool-tab-${tab.id}`}
                onClick={() => setActiveTab(tab.id)}
                className={cn(
                  "rounded-[var(--r-control)] px-2.5 py-1.5 text-[12px] font-medium transition-colors",
                  activeTab === tab.id
                    ? "bg-[var(--bg-elevated)] text-[var(--ink-primary)] shadow-[var(--shadow-xs)] border border-[var(--border-default)]"
                    : "text-[var(--ink-secondary)] hover:bg-[var(--bg-subtle)] hover:text-[var(--ink-primary)] border border-transparent",
                )}
              >
                {tab.label}
              </button>
            ))}
          </div>

          <div className="relative w-full sm:w-64">
            <MagnifyingGlass
              size={14}
              className="pointer-events-none absolute left-2.5 top-1/2 -translate-y-1/2 text-[var(--ink-muted)]"
              aria-hidden="true"
            />
            <input
              type="search"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Filter code, title, dept…"
              aria-label="Filter courses"
              data-testid="room-pool-search-input"
              className="h-8 w-full rounded-[var(--r-control)] border border-[var(--border-default)] bg-[var(--bg-canvas)] pl-8 pr-2.5 text-[12.5px] text-[var(--ink-primary)] placeholder:text-[var(--ink-muted)] focus:border-[var(--brand-accent)] focus:outline-none"
            />
          </div>
        </div>

        {/* Table */}
        <div className="max-h-[54vh] overflow-y-auto bg-[var(--bg-surface)]">
          {filteredCourses.length === 0 ? (
            <div className="flex flex-col items-center justify-center gap-1.5 px-6 py-10 text-center text-[13px] text-[var(--ink-muted)]">
              <CheckCircle size={20} className="text-[var(--sem-pass-ink)]" />
              <span>No courses match this filter.</span>
            </div>
          ) : (
            <table className="w-full border-collapse text-left text-[12.5px]">
              <thead className="sticky top-0 z-10 border-b border-[var(--border-subtle)] bg-[var(--bg-subtle)] text-[11px] font-semibold uppercase tracking-[0.04em] text-[var(--ink-muted)]">
                <tr>
                  <th className="px-4 py-2.5">Course Code</th>
                  <th className="px-3 py-2.5">Title &amp; Credits</th>
                  <th className="px-3 py-2.5">Dept</th>
                  <th className="px-3 py-2.5">Auto-Detected Reason</th>
                  <th className="px-4 py-2.5 text-right">Room Pool</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-[var(--border-subtle)]">
                {filteredCourses.map((course) => {
                  const currentPool = effectivePoolOf(course);
                  const modified = isRowModified(course);
                  const canReset =
                    modified || currentPool !== course.heuristicPool;
                  return (
                    <tr
                      key={course.code}
                      data-testid={`room-pool-row-${course.code}`}
                      className={cn(
                        "transition-colors hover:bg-[var(--bg-subtle)]/60",
                        modified && "bg-[var(--sem-joint-bg)]/40",
                      )}
                    >
                      <td className="whitespace-nowrap px-4 py-2.5 align-middle font-mono text-[12px] font-semibold text-[var(--ink-primary)]">
                        <div className="flex items-center gap-1.5">
                          <span>{course.code}</span>
                          {course.sectionCount > 1 && (
                            <span className="text-[10.5px] font-normal text-[var(--ink-muted)]">
                              ({course.sectionCount} sec)
                            </span>
                          )}
                        </div>
                      </td>
                      <td className="px-3 py-2.5 align-middle">
                        <div className="font-medium text-[var(--ink-primary)]">
                          {course.title}
                        </div>
                        <div className="font-mono text-[11px] text-[var(--ink-muted)]">
                          {course.credit !== null
                            ? `${course.credit} cr`
                            : "Credit unspecified"}
                        </div>
                      </td>
                      <td className="whitespace-nowrap px-3 py-2.5 align-middle font-mono text-[11.5px] text-[var(--ink-secondary)]">
                        {course.conductingDept ?? "—"}
                      </td>
                      <td className="px-3 py-2.5 align-middle text-[12px] text-[var(--ink-secondary)]">
                        <div>{course.autoDetectedReason}</div>
                        {course.reviewReason && (
                          <div className="mt-0.5 text-[11px] text-[var(--sem-joint-ink)]">
                            {course.reviewReason}
                          </div>
                        )}
                      </td>
                      <td className="whitespace-nowrap px-4 py-2.5 align-middle text-right">
                        <div className="inline-flex items-center justify-end gap-2">
                          {(modified || course.isCatalogOverridden) && (
                            <Badge tone="joint" className="text-[10.5px]">
                              Overridden
                            </Badge>
                          )}
                          <select
                            aria-label={`Room pool for ${course.code}`}
                            data-testid={`room-pool-select-${course.code}`}
                            value={currentPool}
                            disabled={isDevPreview || isSaving}
                            onChange={(e) =>
                              handlePoolChange(
                                course,
                                e.target.value as CourseRoomPool,
                              )
                            }
                            className="h-8 rounded-[var(--r-control)] border border-[var(--border-default)] bg-[var(--bg-canvas)] px-2 text-[12px] font-medium text-[var(--ink-primary)] focus:border-[var(--brand-accent)] focus:outline-none disabled:cursor-not-allowed disabled:opacity-60"
                          >
                            {POOL_OPTIONS.map((opt) => (
                              <option key={opt.value} value={opt.value}>
                                {opt.label}
                              </option>
                            ))}
                          </select>
                          {canReset && (
                            <button
                              type="button"
                              disabled={isDevPreview || isSaving}
                              data-testid={`room-pool-reset-${course.code}`}
                              onClick={() => handleResetRow(course)}
                              title="Reset to auto-detected room pool"
                              className="inline-flex items-center gap-1 rounded-[var(--r-control)] border border-[var(--border-subtle)] px-2 py-1 text-[11px] font-medium text-[var(--ink-secondary)] hover:bg-[var(--bg-subtle)] hover:text-[var(--ink-primary)] disabled:cursor-not-allowed disabled:opacity-50"
                            >
                              <ArrowCounterClockwise size={12} />
                              <span>Reset</span>
                            </button>
                          )}
                        </div>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          )}
        </div>

        {/* Footer */}
        <div className="flex flex-wrap items-center justify-between gap-3 border-t border-[var(--border-subtle)] bg-[var(--bg-subtle)] px-5 py-3.5">
          <div className="min-w-0 text-[12px] text-[var(--ink-secondary)]">
            {saveError ? (
              <span className="inline-flex items-center gap-1.5 text-[var(--sem-fail-ink)]">
                <WarningCircle size={15} aria-hidden="true" />
                <span>{saveError}</span>
              </span>
            ) : isDevPreview ? (
              <span>
                Dev Preview mode: room-pool inspection is enabled, saving
                overrides is disabled.
              </span>
            ) : modifiedCourses.length > 0 ? (
              <span>
                <strong className="font-semibold text-[var(--ink-primary)]">
                  {modifiedCourses.length}
                </strong>{" "}
                unsaved override{modifiedCourses.length === 1 ? "" : "s"} ready
                to persist to Course Catalog.
              </span>
            ) : (
              <span>No unsaved changes.</span>
            )}
          </div>
          <div className="flex items-center gap-2">
            <Button
              type="button"
              variant="ghost"
              size="sm"
              onClick={() => onOpenChange(false)}
              disabled={isSaving}
            >
              Close
            </Button>
            <Button
              type="button"
              variant="primary"
              size="sm"
              data-testid="save-room-pool-overrides-btn"
              disabled={isDevPreview || modifiedCourses.length === 0 || isSaving}
              title={
                isDevPreview
                  ? "Disabled in Dev Preview mode"
                  : modifiedCourses.length === 0
                    ? "Change at least one course room pool to save"
                    : "Save room-pool overrides to Course Catalog"
              }
              onClick={() => void handleSave()}
            >
              {isSaving
                ? "Saving..."
                : `Save Overrides${modifiedCourses.length > 0 ? ` (${modifiedCourses.length})` : ""}`}
            </Button>
          </div>
        </div>
      </DialogContent>
    </Dialog>
  );
}
