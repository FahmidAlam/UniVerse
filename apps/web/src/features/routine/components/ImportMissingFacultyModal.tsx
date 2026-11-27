import { CheckSquare, UserPlus, WarningCircle, X } from "@phosphor-icons/react";
import { useEffect, useState } from "react";
import { Badge } from "@/components/ui/Badge";
import { Button } from "@/components/ui/Button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogTitle,
} from "@/components/ui/Dialog";
import {
  bulkSetFacultyActive,
  createFaculty,
  type FacultyEmploymentType,
} from "@/features/admin/services/facultyService";
import type {
  InactiveWorkbookTeacher,
  ScannedWorkbookTeacher,
} from "@/features/routine/services/workbookFacultyScanner";

interface EditableImportRow {
  key: string;
  kind: "missing" | "inactive";
  existingId?: string;
  selected: boolean;
  acronym: string;
  fullName: string;
  dept: string;
  employmentType: FacultyEmploymentType;
  occurrenceCount: number;
}

export interface ImportMissingFacultyModalProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  missing: readonly ScannedWorkbookTeacher[];
  inactive: readonly InactiveWorkbookTeacher[];
  isDevPreview: boolean;
  onImported: (summary: { addedCount: number; reactivatedCount: number }) => void;
}

function buildInitialRows(
  missing: readonly ScannedWorkbookTeacher[],
  inactive: readonly InactiveWorkbookTeacher[],
): EditableImportRow[] {
  const rows: EditableImportRow[] = [];
  for (const item of inactive) {
    rows.push({
      key: `inactive:${item.existingId}`,
      kind: "inactive",
      existingId: item.existingId,
      selected: true,
      acronym: item.acronym,
      fullName: item.existingFullName ?? item.acronym,
      dept: item.existingDept ?? item.suggestedDept ?? "CSE",
      employmentType: item.existingEmploymentType ?? "permanent",
      occurrenceCount: item.occurrenceCount,
    });
  }
  for (const item of missing) {
    rows.push({
      key: `missing:${item.acronym}`,
      kind: "missing",
      selected: true,
      acronym: item.acronym,
      fullName: "",
      dept: item.suggestedDept ?? "CSE",
      employmentType: "permanent",
      occurrenceCount: item.occurrenceCount,
    });
  }
  return rows;
}

export function ImportMissingFacultyModal({
  open,
  onOpenChange,
  missing,
  inactive,
  isDevPreview,
  onImported,
}: ImportMissingFacultyModalProps) {
  const [rows, setRows] = useState<EditableImportRow[]>([]);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [submitError, setSubmitError] = useState<string | null>(null);

  useEffect(() => {
    if (open) {
      setRows(buildInitialRows(missing, inactive));
      setSubmitError(null);
    }
  }, [open, missing, inactive]);

  const selectedRows = rows.filter((r) => r.selected);
  const selectedCount = selectedRows.length;

  const updateRow = (key: string, patch: Partial<EditableImportRow>) => {
    setRows((prev) =>
      prev.map((row) => (row.key === key ? { ...row, ...patch } : row)),
    );
  };

  const handleImport = async () => {
    if (isDevPreview || selectedCount === 0 || isSubmitting) return;
    setSubmitError(null);
    setIsSubmitting(true);

    let addedCount = 0;
    let reactivatedCount = 0;
    const errors: string[] = [];

    try {
      const inactiveIds = selectedRows
        .filter((r) => r.kind === "inactive" && r.existingId)
        .map((r) => r.existingId!);

      if (inactiveIds.length > 0) {
        try {
          await bulkSetFacultyActive(inactiveIds, true, false);
          reactivatedCount = inactiveIds.length;
        } catch (err) {
          errors.push(
            `Reactivating inactive faculty failed: ${
              err instanceof Error ? err.message : "Update error."
            }`,
          );
        }
      }

      const missingToInsert = selectedRows.filter((r) => r.kind === "missing");
      for (const row of missingToInsert) {
        const cleanAcronym = row.acronym.trim().toUpperCase();
        if (!cleanAcronym) {
          errors.push("Skipped a row with an empty acronym.");
          continue;
        }
        try {
          await createFaculty(
            {
              acronym: cleanAcronym,
              full_name: row.fullName.trim() || cleanAcronym,
              dept: row.dept.trim() || "CSE",
              designation: null,
              off_days: [],
              is_active: true,
              courses: [],
              employment_type: row.employmentType,
              allow_three_off_days: false,
              is_sust_adjunct: false,
              external_blocked_slots: [],
              available_slots: [],
              preferred_slots: [],
            },
            false,
          );
          addedCount += 1;
        } catch (err) {
          errors.push(
            `${cleanAcronym}: ${err instanceof Error ? err.message : "Insert failed."}`,
          );
        }
      }

      if (errors.length > 0) {
        setSubmitError(errors.join(" "));
        if (addedCount > 0 || reactivatedCount > 0) {
          onImported({ addedCount, reactivatedCount });
        }
        return;
      }

      onImported({ addedCount, reactivatedCount });
      onOpenChange(false);
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <Dialog
      open={open}
      onOpenChange={(next) => {
        if (isSubmitting) return;
        onOpenChange(next);
      }}
    >
      <DialogContent
        data-testid="import-missing-faculty-modal"
        className="fixed left-1/2 top-1/2 flex max-h-[85vh] w-[calc(100%-32px)] max-w-[780px] -translate-x-1/2 -translate-y-1/2 flex-col p-5"
      >
        <div className="flex items-start justify-between gap-3">
          <div>
            <DialogTitle className="text-[17px] font-semibold text-[var(--ink-primary)]">
              Review &amp; Import Missing Faculty
            </DialogTitle>
            <DialogDescription className="mt-1 text-[13px] text-[var(--ink-secondary)]">
              Uncheck any spreadsheet typos before importing. Inactive faculty are
              reactivated in place (preserving off-days); missing acronyms are
              added to <code className="font-mono-tabular">timetable_faculty</code>.
            </DialogDescription>
          </div>
          <button
            type="button"
            aria-label="Close import faculty modal"
            disabled={isSubmitting}
            onClick={() => onOpenChange(false)}
            className="flex h-7 w-7 items-center justify-center rounded-[5px] text-[var(--ink-secondary)] hover:bg-[var(--surface-hover)]"
          >
            <X size={15} aria-hidden="true" />
          </button>
        </div>

        {submitError && (
          <div
            role="alert"
            data-testid="import-faculty-error-alert"
            className="mt-3 flex items-start gap-2 rounded-[var(--r-control)] border border-[var(--sem-conflict-border)] bg-[var(--sem-conflict-bg)] px-3 py-2 text-[12.5px] text-[var(--sem-conflict-ink)]"
          >
            <WarningCircle size={16} className="mt-0.5 shrink-0" aria-hidden="true" />
            <span>{submitError}</span>
          </div>
        )}

        <div className="mt-4 min-h-0 flex-1 overflow-y-auto rounded-[var(--r-control)] border border-[var(--border-subtle)] bg-[var(--bg-surface)]">
          <table className="w-full border-collapse text-left text-[12.5px]">
            <thead className="sticky top-0 z-10 border-b border-[var(--border-subtle)] bg-[var(--bg-elevated)] text-[11.5px] font-semibold text-[var(--ink-secondary)]">
              <tr>
                <th className="w-10 px-3 py-2.5">
                  <CheckSquare size={14} aria-hidden="true" />
                </th>
                <th className="px-3 py-2.5">Acronym</th>
                <th className="px-3 py-2.5">Full Name</th>
                <th className="w-28 px-3 py-2.5">Dept</th>
                <th className="w-36 px-3 py-2.5">Category</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-[var(--border-subtle)]">
              {rows.map((row) => (
                <tr
                  key={row.key}
                  data-testid={`import-faculty-row-${row.acronym}`}
                  className={row.selected ? "" : "opacity-55"}
                >
                  <td className="px-3 py-2.5 align-top">
                    <input
                      type="checkbox"
                      aria-label={`Select ${row.acronym}`}
                      checked={row.selected}
                      disabled={isSubmitting}
                      onChange={(e) =>
                        updateRow(row.key, { selected: e.target.checked })
                      }
                      className="mt-1 h-4 w-4 accent-[var(--accent-brand)]"
                    />
                  </td>
                  <td className="px-3 py-2.5 align-top">
                    <div className="flex flex-col gap-1">
                      {row.kind === "missing" ? (
                        <input
                          type="text"
                          aria-label={`Acronym for ${row.acronym}`}
                          value={row.acronym}
                          disabled={isSubmitting || !row.selected}
                          onChange={(e) =>
                            updateRow(row.key, {
                              acronym: e.target.value.toUpperCase(),
                            })
                          }
                          className="font-mono-tabular h-8 w-24 rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-2 text-[12.5px] font-semibold text-[var(--ink-primary)] focus:border-[var(--ink-primary)] focus:outline-none"
                        />
                      ) : (
                        <span className="font-mono-tabular text-[13px] font-semibold text-[var(--ink-primary)]">
                          {row.acronym}
                        </span>
                      )}
                      <div className="flex flex-wrap items-center gap-1.5">
                        <Badge
                          tone={row.kind === "inactive" ? "joint" : "conflict"}
                          mono
                        >
                          {row.kind === "inactive" ? "Inactive in DB" : "Missing"}
                        </Badge>
                        <span className="font-mono-tabular text-[11px] text-[var(--ink-muted)]">
                          {row.occurrenceCount}{" "}
                          {row.occurrenceCount === 1 ? "class" : "classes"}
                        </span>
                      </div>
                    </div>
                  </td>
                  <td className="px-3 py-2.5 align-top">
                    <input
                      type="text"
                      aria-label={`Full name for ${row.acronym}`}
                      value={row.fullName}
                      placeholder={row.acronym}
                      disabled={
                        isSubmitting || !row.selected || row.kind === "inactive"
                      }
                      onChange={(e) =>
                        updateRow(row.key, { fullName: e.target.value })
                      }
                      className="h-8 w-full rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-2.5 text-[12.5px] text-[var(--ink-primary)] placeholder:text-[var(--ink-muted)] focus:border-[var(--ink-primary)] focus:outline-none disabled:opacity-60"
                    />
                  </td>
                  <td className="px-3 py-2.5 align-top">
                    <input
                      type="text"
                      aria-label={`Department for ${row.acronym}`}
                      value={row.dept}
                      disabled={
                        isSubmitting || !row.selected || row.kind === "inactive"
                      }
                      onChange={(e) =>
                        updateRow(row.key, { dept: e.target.value })
                      }
                      className="h-8 w-full rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-2 text-[12.5px] text-[var(--ink-primary)] focus:border-[var(--ink-primary)] focus:outline-none disabled:opacity-60"
                    />
                  </td>
                  <td className="px-3 py-2.5 align-top">
                    <div className="space-y-1">
                      <select
                        aria-label={`Category for ${row.acronym}`}
                        value={row.employmentType}
                        disabled={
                          isSubmitting || !row.selected || row.kind === "inactive"
                        }
                        onChange={(e) =>
                          updateRow(row.key, {
                            employmentType: e.target.value as FacultyEmploymentType,
                          })
                        }
                        className="h-8 w-full rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-2 text-[12.5px] text-[var(--ink-primary)] focus:border-[var(--ink-primary)] focus:outline-none disabled:opacity-60"
                      >
                        <option value="permanent">Permanent</option>
                        <option value="adjunct">Adjunct</option>
                        <option value="guest">Guest</option>
                      </select>
                      {row.employmentType === "guest" && (
                        <p className="text-[11px] leading-[1.35] text-[var(--sem-joint-ink)]">
                          Guest (R5) requires declared available slots in Faculty.
                        </p>
                      )}
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        <div className="mt-4 flex flex-wrap items-center justify-between gap-2">
          <span className="text-[12px] text-[var(--ink-muted)]">
            {isDevPreview
              ? "Disabled in Dev Preview mode."
              : `${selectedCount} of ${rows.length} selected`}
          </span>
          <div className="flex items-center gap-2">
            <Button
              type="button"
              variant="secondary"
              size="md"
              disabled={isSubmitting}
              onClick={() => onOpenChange(false)}
            >
              Cancel
            </Button>
            <Button
              type="button"
              variant="primary"
              size="md"
              data-testid="confirm-import-faculty-btn"
              disabled={isDevPreview || selectedCount === 0 || isSubmitting}
              onClick={() => void handleImport()}
            >
              <UserPlus size={15} aria-hidden="true" />
              <span>
                {isSubmitting
                  ? "Importing..."
                  : `Import Selected (${selectedCount})`}
              </span>
            </Button>
          </div>
        </div>
      </DialogContent>
    </Dialog>
  );
}
