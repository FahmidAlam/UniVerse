import type { CatalogCourseRecord } from "@/features/admin/services/coursesService";
import type { CourseDistributionOfferingRow } from "@/features/routine/services/distributionXlsxBuilder";
import {
  findCourseDistributionHeaderRow,
  parseCourseDistributionXlsxRows,
} from "@/features/routine/services/workbookFacultyScanner";

export type CourseRoomPool = "theory" | "cse_lab" | "ecl_lab" | "physics_lab";

export const COURSE_ROOM_POOL_LABELS: Record<CourseRoomPool, string> = {
  theory: "Theory Room",
  cse_lab: "CSE Lab",
  ecl_lab: "ECL Lab",
  physics_lab: "Physics Lab",
};

export interface ScannedWorkbookCourse {
  code: string;
  title: string;
  credit: number | null;
  conductingDept: string | null;
  sectionCount: number;
}

export interface ClassifiedWorkbookCourse extends ScannedWorkbookCourse {
  /** Resolved room pool that the CP-SAT solver will use. */
  roomPool: CourseRoomPool;
  /** Heuristic-only room pool (before catalog override), used for reset & diffing. */
  heuristicPool: CourseRoomPool;
  /** True when the resolved pool comes from an explicit catalog_courses entry. */
  isCatalogOverridden: boolean;
  /** Existing catalog_courses row if present. */
  catalogRecord: CatalogCourseRecord | null;
  /** Human-readable explanation of why this pool was chosen. */
  autoDetectedReason: string;
  /** True for borderline / GED / uncataloged review-worthy courses. */
  needsReview: boolean;
  /** Short reason why this course is flagged for review, if any. */
  reviewReason: string | null;
}

export interface CourseRoomPoolSummary {
  total: number;
  theory: number;
  cseLab: number;
  eclLab: number;
  physicsLab: number;
  needsReviewCount: number;
  overriddenCount: number;
}

const LAB_TITLE_RE =
  /\b(lab|laboratory|sessional|practical|workshop|drawing|cad|simulation)\b/i;

const ROOM_POOL_TAG_RE =
  /\[pool:(theory|cse_lab|ecl_lab|physics_lab)\]/i;

const VALID_POOLS = new Set<CourseRoomPool>([
  "theory",
  "cse_lab",
  "ecl_lab",
  "physics_lab",
]);

export function parseRoomPoolOverride(
  value: string | null | undefined,
): CourseRoomPool | null {
  if (!value) return null;
  const raw = value.trim().toLowerCase();
  if (VALID_POOLS.has(raw as CourseRoomPool)) {
    return raw as CourseRoomPool;
  }
  const m = ROOM_POOL_TAG_RE.exec(raw);
  if (m?.[1]) {
    return m[1].toLowerCase() as CourseRoomPool;
  }
  return null;
}

export function encodeRoomPoolOverrideNote(
  existingNotes: string | null | undefined,
  pool: CourseRoomPool | null,
): string | null {
  const stripped = (existingNotes ?? "")
    .replace(/\s*\[pool:(?:theory|cse_lab|ecl_lab|physics_lab)\]\s*/gi, " ")
    .trim();
  if (!pool) return stripped || null;
  return stripped ? `${stripped} [pool:${pool}]` : `[pool:${pool}]`;
}

function lastDigitOfCode(code: string): number | null {
  const m = /(\d+)\s*$/.exec(code || "");
  if (!m?.[1]) return null;
  return Number.parseInt(m[1][m[1].length - 1]!, 10);
}

function isEeeCourse(code: string, dept: string | null): boolean {
  const cleanCode = code.trim().toUpperCase();
  if (cleanCode.startsWith("PHY")) return false;
  const cleanDept = (dept ?? "").trim().toUpperCase();
  return cleanCode.startsWith("EEE") || cleanDept === "EEE";
}

function isPhysicsCourse(code: string): boolean {
  return code.trim().toUpperCase().startsWith("PHY");
}

function inferIsLabDynamic(
  code: string,
  title: string,
  credit: number | null,
): { isLab: boolean; reason: string } {
  const hasLabKeyword = LAB_TITLE_RE.test(title || "");
  if (hasLabKeyword) {
    return { isLab: true, reason: "Lab keyword in title" };
  }
  const ld = lastDigitOfCode(code);
  const isEven = ld !== null && ld % 2 === 0;
  if (isEven && (credit === null || credit <= 2.0)) {
    const crText = credit !== null ? `${credit} cr` : "no credit";
    return { isLab: true, reason: `Even digit + ${crText}` };
  }
  if (isEven && credit !== null && credit > 2.0) {
    return { isLab: false, reason: `${credit} cr theory` };
  }
  return { isLab: false, reason: "Odd digit theory" };
}

function routeLabPool(
  code: string,
  dept: string | null,
  isPhysicsLabFlag: boolean,
  physicsLabCourseCodes: ReadonlySet<string>,
): { pool: CourseRoomPool; label: string } {
  const cleanCode = code.trim().toUpperCase();
  if (
    isPhysicsLabFlag ||
    physicsLabCourseCodes.has(cleanCode) ||
    isPhysicsCourse(cleanCode)
  ) {
    return { pool: "physics_lab", label: "Physics Lab" };
  }
  if (isEeeCourse(cleanCode, dept)) {
    return { pool: "ecl_lab", label: "ECL Lab" };
  }
  return { pool: "cse_lab", label: "CSE Lab" };
}

/**
 * Mirror engine/ingest.py + engine/room_policy.py Tier 1 → Tier 2 → Tier 3
 * classification so admins see the exact room pool the CP-SAT solver will use.
 */
export function classifyScannedCourses(
  scanned: readonly ScannedWorkbookCourse[],
  catalogCourses: readonly CatalogCourseRecord[],
  physicsLabCourseCodes: readonly string[] = [],
): ClassifiedWorkbookCourse[] {
  const catalogByCode = new Map<string, CatalogCourseRecord>();
  for (const c of catalogCourses) {
    if (!c.is_active) continue;
    const key = c.code.trim().toUpperCase();
    if (key) catalogByCode.set(key, c);
  }

  const physicsSet = new Set(
    physicsLabCourseCodes.map((c) => c.trim().toUpperCase()).filter(Boolean),
  );

  return scanned.map((course) => {
    const code = course.code.trim().toUpperCase();
    const cat = catalogByCode.get(code) ?? null;
    const effectiveCredit = course.credit ?? cat?.credit ?? null;
    const effectiveDept = course.conductingDept ?? cat?.dept_code ?? null;

    // Tier 2 + Tier 3 heuristic baseline
    const heur = inferIsLabDynamic(code, course.title, effectiveCredit);
    let heuristicPool: CourseRoomPool = "theory";
    let heuristicReason = `${heur.reason} → Theory Room`;
    if (heur.isLab) {
      const routed = routeLabPool(code, effectiveDept, false, physicsSet);
      heuristicPool = routed.pool;
      heuristicReason = `${heur.reason} → ${routed.label}`;
    }

    // Tier 1 explicit catalog override
    let roomPool: CourseRoomPool = heuristicPool;
    let autoDetectedReason = heuristicReason;
    let isCatalogOverridden = false;

    if (cat) {
      const explicitPool = parseRoomPoolOverride(cat.notes);
      if (explicitPool) {
        roomPool = explicitPool;
        isCatalogOverridden = true;
        autoDetectedReason = `Catalog override → ${COURSE_ROOM_POOL_LABELS[explicitPool]}`;
      } else if (cat.is_physics_lab) {
        roomPool = "physics_lab";
        isCatalogOverridden = true;
        autoDetectedReason = "Catalog override → Physics Lab";
      } else if (cat.class_type === "theory") {
        roomPool = "theory";
        isCatalogOverridden = heuristicPool !== "theory";
        autoDetectedReason = isCatalogOverridden
          ? "Catalog override → Theory Room"
          : heuristicReason;
      } else if (cat.class_type === "lab") {
        const routed = routeLabPool(code, effectiveDept, false, physicsSet);
        roomPool = routed.pool;
        isCatalogOverridden = heuristicPool !== routed.pool;
        autoDetectedReason = isCatalogOverridden
          ? `Catalog override → ${routed.label}`
          : heuristicReason;
      }
    }

    // Borderline / review-worthy flagging
    const isGed = code.startsWith("GED");
    const ld = lastDigitOfCode(code);
    const isEvenThreePlus =
      ld !== null && ld % 2 === 0 && effectiveCredit !== null && effectiveCredit >= 3.0;

    let reviewReason: string | null = null;
    if (isGed && roomPool !== "theory") {
      reviewReason = "GED course classified as lab";
    } else if (isEvenThreePlus && roomPool === "theory") {
      reviewReason = "Even-digit 3+ cr classified as theory";
    } else if (isGed) {
      reviewReason = "GED course";
    } else if (!cat) {
      reviewReason = "Not yet in course catalog";
    }

    return {
      ...course,
      code,
      credit: effectiveCredit,
      conductingDept: effectiveDept,
      roomPool,
      heuristicPool,
      isCatalogOverridden,
      catalogRecord: cat,
      autoDetectedReason,
      needsReview: reviewReason !== null,
      reviewReason,
    };
  });
}

export function summarizeCourseRoomPools(
  courses: readonly ClassifiedWorkbookCourse[],
): CourseRoomPoolSummary {
  let theory = 0;
  let cseLab = 0;
  let eclLab = 0;
  let physicsLab = 0;
  let needsReviewCount = 0;
  let overriddenCount = 0;

  for (const c of courses) {
    if (c.roomPool === "theory") theory += 1;
    else if (c.roomPool === "cse_lab") cseLab += 1;
    else if (c.roomPool === "ecl_lab") eclLab += 1;
    else if (c.roomPool === "physics_lab") physicsLab += 1;
    if (c.needsReview) needsReviewCount += 1;
    if (c.isCatalogOverridden) overriddenCount += 1;
  }

  return {
    total: courses.length,
    theory,
    cseLab,
    eclLab,
    physicsLab,
    needsReviewCount,
    overriddenCount,
  };
}

function aggregateCourses(
  items: ReadonlyArray<{
    code: string;
    title: string;
    credit: number | null;
    conductingDept: string | null;
    cohortKey: string;
  }>,
): ScannedWorkbookCourse[] {
  const byCode = new Map<
    string,
    {
      code: string;
      title: string;
      credit: number | null;
      deptCounts: Map<string, number>;
      cohorts: Set<string>;
    }
  >();

  for (const item of items) {
    const code = item.code.trim().toUpperCase();
    if (!code) continue;
    let entry = byCode.get(code);
    if (!entry) {
      entry = {
        code,
        title: item.title.trim() || code,
        credit: item.credit,
        deptCounts: new Map(),
        cohorts: new Set(),
      };
      byCode.set(code, entry);
    } else {
      if (entry.title === code && item.title.trim()) {
        entry.title = item.title.trim();
      }
      if (entry.credit === null && item.credit !== null) {
        entry.credit = item.credit;
      }
    }
    const cleanDept = item.conductingDept?.trim().toUpperCase() || null;
    if (cleanDept) {
      entry.deptCounts.set(cleanDept, (entry.deptCounts.get(cleanDept) ?? 0) + 1);
    }
    entry.cohorts.add(item.cohortKey);
  }

  const out: ScannedWorkbookCourse[] = [];
  for (const entry of byCode.values()) {
    let bestDept: string | null = null;
    let bestCount = -1;
    for (const [dept, cnt] of entry.deptCounts.entries()) {
      if (cnt > bestCount) {
        bestCount = cnt;
        bestDept = dept;
      }
    }
    out.push({
      code: entry.code,
      title: entry.title,
      credit: entry.credit,
      conductingDept: bestDept,
      sectionCount: entry.cohorts.size,
    });
  }

  return out.sort((a, b) => a.code.localeCompare(b.code));
}

export function scanCoursesFromDistributionRows(
  rows: readonly CourseDistributionOfferingRow[],
): ScannedWorkbookCourse[] {
  return aggregateCourses(
    rows
      .filter((r) => Boolean(r.courseCode?.trim()) && Boolean(r.batch?.trim()))
      .map((r, idx) => ({
        code: r.courseCode,
        title: r.courseTitle || r.courseCode,
        credit:
          typeof r.credit === "number" && Number.isFinite(r.credit)
            ? r.credit
            : null,
        conductingDept: r.conductingDept ?? null,
        cohortKey: `${r.batch.trim()}-${(r.section ?? "").trim() || idx}`,
      })),
  );
}

/**
 * Scan unique courses from an uploaded Course Distribution `.xlsx` file.
 * Fails gracefully (returns `[]`) on malformed/unsupported files so it can
 * never block or crash `Run CP-SAT Solver`.
 */
export async function scanCoursesFromXlsxBytes(
  bytes: Uint8Array,
): Promise<ScannedWorkbookCourse[]> {
  try {
    const rowMap = await parseCourseDistributionXlsxRows(bytes);
    if (!rowMap) return [];

    const headerRowNum = findCourseDistributionHeaderRow(rowMap);
    const headerRow = rowMap.get(headerRowNum);
    let batchCol = 0;
    let sectionCol = 1;
    let codeCol = 2;
    let titleCol = 3;
    let creditCol = 4;
    let deptCol = 6;

    if (headerRow) {
      for (const [colIdx, label] of headerRow.entries()) {
        const lower = label.toLowerCase();
        if (lower.startsWith("batch")) batchCol = colIdx;
        else if (lower.startsWith("section")) sectionCol = colIdx;
        else if (lower.startsWith("course code")) codeCol = colIdx;
        else if (lower.startsWith("course title")) titleCol = colIdx;
        else if (lower.startsWith("credit")) creditCol = colIdx;
        else if (lower.startsWith("conducting")) deptCol = colIdx;
      }
    }

    const items: Array<{
      code: string;
      title: string;
      credit: number | null;
      conductingDept: string | null;
      cohortKey: string;
    }> = [];

    for (const [rowNum, cells] of rowMap.entries()) {
      if (rowNum <= headerRowNum) continue;
      const code = cells.get(codeCol)?.trim() ?? "";
      const batch = cells.get(batchCol)?.trim() ?? "";
      if (!code || !batch) continue;
      const section = cells.get(sectionCol)?.trim() ?? "";
      const title = cells.get(titleCol)?.trim() || code;
      const rawCredit = cells.get(creditCol)?.trim() ?? "";
      const parsedCredit = rawCredit ? Number.parseFloat(rawCredit) : Number.NaN;
      const credit = Number.isFinite(parsedCredit) ? parsedCredit : null;
      const conductingDept = cells.get(deptCol)?.trim() || null;

      items.push({
        code,
        title,
        credit,
        conductingDept,
        cohortKey: `${batch}-${section}`,
      });
    }

    return aggregateCourses(items);
  } catch {
    return [];
  }
}
