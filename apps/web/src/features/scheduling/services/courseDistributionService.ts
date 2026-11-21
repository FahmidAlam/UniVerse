import { isSupabaseConfigured, supabase } from "@/services/supabase";
import type {
  AppendCorrectionRpcParams,
  ArtifactFreshnessSummary,
  DistributionColumn,
  DistributionCorrection,
  DistributionSourceRecord,
  ReadDistributionRevisionRpcResponse,
  RevisionContext,
} from "@/features/scheduling/types";

/**
 * Raised when `append_course_distribution_correction` returns PostgreSQL `SQLSTATE 40001`
 * ("Stale course distribution revision") due to optimistic concurrency mismatch on `revision_version`.
 */
export class StaleRevisionError extends Error {
  readonly code = "40001";
  readonly expectedRevisionVersion: number;

  constructor(message: string, expectedRevisionVersion: number) {
    super(message);
    this.name = "StaleRevisionError";
    this.expectedRevisionVersion = expectedRevisionVersion;
  }
}

export function isStaleRevisionError(err: unknown): boolean {
  if (err instanceof StaleRevisionError) return true;
  if (typeof err !== "object" || err === null) return false;
  const candidate = err as { code?: unknown; message?: unknown };
  const code = String(candidate.code ?? "");
  const message = String(candidate.message ?? "").toLowerCase();
  return (
    code === "40001" || message.includes("stale course distribution revision")
  );
}

interface JoinedScopeRevisionRow {
  id: string;
  source_id: string;
  revision_number: number;
  revision_version: number;
  status: "draft" | "accepted" | "superseded";
  created_at: string;
  course_distribution_sources: {
    id: string;
    scheduling_scope_id: string;
    source_hash: string;
    sheet_name: string;
    uploaded_at: string;
    scheduling_scopes?: {
      id: string;
      departments?: { code?: string; name?: string } | null;
      academic_terms?: {
        label?: string;
        sequence?: number;
        academic_years?: { label?: string } | null;
      } | null;
    } | null;
  } | null;
}

/**
 * Queries scoped revisions strictly using authoritative SQL column names from
 * `20261106130000_course_distribution_contract.sql`:
 * - `course_distribution_revisions.revision_version`
 * - `course_distribution_sources.scheduling_scope_id`
 */
export async function fetchScopedRevisions(): Promise<RevisionContext[]> {
  if (!isSupabaseConfigured || !supabase) {
    return [];
  }

  const { data, error } = await supabase
    .from("course_distribution_revisions")
    .select(
      `
      id,
      source_id,
      revision_number,
      revision_version,
      status,
      created_at,
      course_distribution_sources (
        id,
        scheduling_scope_id,
        source_hash,
        sheet_name,
        uploaded_at,
        scheduling_scopes (
          id,
          departments ( code, name ),
          academic_terms ( label, sequence, academic_years ( label ) )
        )
      )
      `,
    )
    .order("revision_number", { ascending: false });

  if (error) {
    throw new Error(error.message);
  }

  const rows = (data ?? []) as unknown as JoinedScopeRevisionRow[];
  return rows.map((row) => {
    const src = row.course_distribution_sources;
    const deptName =
      src?.scheduling_scopes?.departments?.name ??
      src?.scheduling_scopes?.departments?.code ??
      "Computer Science & Engineering";
    const termLabel = src?.scheduling_scopes?.academic_terms?.label;
    const yearLabel = src?.scheduling_scopes?.academic_terms?.academic_years?.label;
    const termName = termLabel
      ? yearLabel
        ? `${termLabel} · ${yearLabel}`
        : termLabel
      : "Active Term";

    return {
      scopeId: src?.scheduling_scope_id ?? "",
      revisionId: row.id,
      department: deptName,
      semester: termName,
      revisionNumber: row.revision_number,
      revisionVersion: row.revision_version,
      status: row.status,
      sourceHash: src?.source_hash ?? "",
      sourceFileName: `${src?.sheet_name ?? "Course Distribution"} (Rev #${row.revision_number})`,
      sheetName: src?.sheet_name ?? "Course Distribution",
      acceptedAt: row.created_at,
      acceptedBy: "Committee Scope Registry",
      isFresh: true,
      totalRows: 0,
      correctionCount: 0,
      conflictCount: 0,
    };
  });
}

/**
 * Reads the complete revision payload (`read_course_distribution_revision(target_revision)`).
 */
export async function readCourseDistributionRevision(
  targetRevisionId: string,
): Promise<ReadDistributionRevisionRpcResponse> {
  if (!isSupabaseConfigured || !supabase) {
    throw new Error(
      "Supabase is not configured in this isolated runtime; live revision read is unavailable.",
    );
  }

  const { data, error } = await supabase.rpc(
    "read_course_distribution_revision",
    {
      target_revision: targetRevisionId,
    },
  );

  if (error) {
    throw new Error(error.message);
  }
  return data as ReadDistributionRevisionRpcResponse;
}

/**
 * Queries `course_distribution_artifacts` freshness for a revision.
 */
export async function fetchRevisionArtifactsFreshness(
  revisionId: string,
  revisionVersion: number,
): Promise<ArtifactFreshnessSummary> {
  if (!isSupabaseConfigured || !supabase) {
    return {
      normalizedInputStatus: "missing",
      validationReportStatus: "missing",
      generationOutputStatus: "missing",
      validatedAgainstVersion: null,
    };
  }

  const { data, error } = await supabase
    .from("course_distribution_artifacts")
    .select("artifact_kind, status")
    .eq("revision_id", revisionId);

  if (error) {
    throw new Error(error.message);
  }

  const map = new Map<string, "current" | "stale">();
  for (const row of data ?? []) {
    if (
      typeof row.artifact_kind === "string" &&
      (row.status === "current" || row.status === "stale")
    ) {
      map.set(row.artifact_kind, row.status);
    }
  }

  return {
    normalizedInputStatus: map.get("normalized_input") ?? "missing",
    validationReportStatus: map.get("validation_report") ?? "missing",
    generationOutputStatus: map.get("generation_output") ?? "missing",
    validatedAgainstVersion: revisionVersion,
  };
}

/**
 * Calls the exact 8-parameter PostgreSQL RPC:
 * `append_course_distribution_correction(
 *    target_revision, expected_revision_version, target_row, target_column,
 *    prior_formula, prior_cached_value, next_effective_value, reason
 * )`
 * Throws `StaleRevisionError` when PostgreSQL raises `SQLSTATE 40001`.
 */
export async function appendCourseDistributionCorrection(
  params: AppendCorrectionRpcParams,
  client: Pick<NonNullable<typeof supabase>, "rpc"> | null = supabase,
): Promise<string> {
  if (!client) {
    throw new Error(
      "Live audited corrections require an authenticated Supabase session.",
    );
  }

  const rpcPayload: AppendCorrectionRpcParams = {
    target_revision: params.target_revision,
    expected_revision_version: params.expected_revision_version,
    target_row: params.target_row,
    target_column: params.target_column,
    prior_formula: params.prior_formula,
    prior_cached_value: params.prior_cached_value,
    next_effective_value: params.next_effective_value,
    reason: params.reason.trim(),
  };

  const { data, error } = await client.rpc(
    "append_course_distribution_correction",
    rpcPayload,
  );

  if (error) {
    if (isStaleRevisionError(error)) {
      throw new StaleRevisionError(
        error.message || "Stale course distribution revision.",
        params.expected_revision_version,
      );
    }
    throw new Error(error.message);
  }

  return String(data);
}

export function getOriginalColumnValue(
  record: DistributionSourceRecord,
  column: DistributionColumn,
): string {
  switch (column) {
    case "A":
      return record.batch;
    case "B":
      return record.section;
    case "C":
      return record.courseCode;
    case "D":
      return record.courseTitle;
    case "E":
      return String(record.credit);
    case "F":
      return record.prerequisite ?? "None";
    case "G":
      return record.conductingDept;
    case "H":
      return record.studentCount !== null ? String(record.studentCount) : "TBA";
    case "I":
      return record.teacher;
    case "J":
      return String(record.classes);
    case "K":
      return `${record.durationMinutes} min`;
    case "L":
      return String(record.classesPerWeek);
  }
}

export function getEffectiveColumnValue(
  record: DistributionSourceRecord,
  column: DistributionColumn,
): string {
  const latest = [...record.corrections]
    .reverse()
    .find((c) => c.column === column);
  if (latest) return latest.effectiveValue;
  return getOriginalColumnValue(record, column);
}

export function isTeacherPending(teacherValue: string): boolean {
  const normalized = teacherValue.trim().toLowerCase();
  return (
    normalized.length === 0 ||
    normalized.includes("pending") ||
    normalized === "tba"
  );
}

export function deriveRecordStatus(
  record: DistributionSourceRecord,
): "verified" | "corrected" | "conflict" | "pendingTeacher" {
  const effectiveTeacher = getEffectiveColumnValue(record, "I");
  const activeConflicts = record.conflicts.filter((msg) => {
    if (
      msg.toLowerCase().includes("missing teacher") &&
      !isTeacherPending(effectiveTeacher)
    ) {
      return false;
    }
    return true;
  });
  if (activeConflicts.length > 0) return "conflict";
  if (isTeacherPending(effectiveTeacher)) return "pendingTeacher";
  if (record.corrections.length > 0) return "corrected";
  return "verified";
}

export function hasFormulaCachedDiscrepancy(
  record: DistributionSourceRecord,
): { column: "J" | "L"; formula: string; cached: number; expected: number } | null {
  if (record.formulaL && record.cachedL !== null) {
    const expectedWeekly = Math.max(1, Math.round(record.classes / 14));
    if (record.cachedL !== expectedWeekly) {
      return {
        column: "L",
        formula: record.formulaL,
        cached: record.cachedL,
        expected: expectedWeekly,
      };
    }
  }
  if (record.formulaJ && record.cachedJ !== null && record.cachedJ !== record.classes) {
    return {
      column: "J",
      formula: record.formulaJ,
      cached: record.cachedJ,
      expected: record.classes,
    };
  }
  return null;
}

export function applyCorrectionToRecords(
  records: readonly DistributionSourceRecord[],
  correction: DistributionCorrection,
): DistributionSourceRecord[] {
  return records.map((rec) => {
    if (rec.row !== correction.row) return rec;
    const withoutSameCol = rec.corrections.filter(
      (c) => c.column !== correction.column,
    );
    const nextTeacher =
      correction.column === "I" ? correction.effectiveValue : rec.teacher;
    const nextConflicts =
      correction.column === "I" && !isTeacherPending(nextTeacher)
        ? rec.conflicts.filter((m) => !m.toLowerCase().includes("missing teacher"))
        : rec.conflicts;

    return {
      ...rec,
      teacher: nextTeacher,
      conductingDept:
        correction.column === "G"
          ? correction.effectiveValue
          : rec.conductingDept,
      classes:
        correction.column === "J"
          ? Number.parseInt(correction.effectiveValue, 10) || rec.classes
          : rec.classes,
      classesPerWeek:
        correction.column === "L"
          ? Number.parseInt(correction.effectiveValue, 10) || rec.classesPerWeek
          : rec.classesPerWeek,
      corrections: [...withoutSameCol, correction],
      conflicts: nextConflicts,
    };
  });
}
