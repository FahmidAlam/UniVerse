import type {
  FacultyEmploymentType,
  TimetableFacultyRecord,
} from "@/features/admin/services/facultyService";
import type { CourseDistributionOfferingRow } from "@/features/routine/services/distributionXlsxBuilder";

export interface ScannedWorkbookTeacher {
  acronym: string;
  suggestedDept: string | null;
  occurrenceCount: number;
}

export interface InactiveWorkbookTeacher extends ScannedWorkbookTeacher {
  existingId: string;
  existingFullName: string | null;
  existingDept: string | null;
  existingDesignation: string | null;
  existingOffDays: string[];
  existingCourses: string[];
  existingEmploymentType: FacultyEmploymentType;
  existingAllowThreeOffDays: boolean;
  existingIsSustAdjunct: boolean;
}

export interface WorkbookFacultyDiff {
  missing: ScannedWorkbookTeacher[];
  inactive: InactiveWorkbookTeacher[];
  matched: ScannedWorkbookTeacher[];
}

const PLACEHOLDER_TOKENS = new Set([
  "TBA",
  "TBD",
  "N/A",
  "NA",
  "-",
  "--",
  "NONE",
  "NULL",
  "PENDING",
]);

export function normalizeTeacherAcronyms(raw: string): string[] {
  if (!raw || typeof raw !== "string") return [];
  const out: string[] = [];
  for (const part of raw.split(/[\/,]+/)) {
    const clean = part.trim().toUpperCase();
    if (!clean || PLACEHOLDER_TOKENS.has(clean)) continue;
    out.push(clean);
  }
  return out;
}

function aggregateTeachers(
  pairs: ReadonlyArray<{ teacherRaw: string; deptRaw?: string | null }>,
): ScannedWorkbookTeacher[] {
  const byAcronym = new Map<
    string,
    { count: number; deptCounts: Map<string, number> }
  >();

  for (const { teacherRaw, deptRaw } of pairs) {
    const tokens = normalizeTeacherAcronyms(teacherRaw);
    const cleanDept = deptRaw?.trim() ? deptRaw.trim() : null;
    for (const acro of tokens) {
      let entry = byAcronym.get(acro);
      if (!entry) {
        entry = { count: 0, deptCounts: new Map() };
        byAcronym.set(acro, entry);
      }
      entry.count += 1;
      if (cleanDept) {
        entry.deptCounts.set(cleanDept, (entry.deptCounts.get(cleanDept) ?? 0) + 1);
      }
    }
  }

  const result: ScannedWorkbookTeacher[] = [];
  for (const [acronym, entry] of byAcronym.entries()) {
    let bestDept: string | null = null;
    let bestCount = -1;
    for (const [dept, cnt] of entry.deptCounts.entries()) {
      if (cnt > bestCount) {
        bestCount = cnt;
        bestDept = dept;
      }
    }
    result.push({
      acronym,
      suggestedDept: bestDept,
      occurrenceCount: entry.count,
    });
  }

  return result.sort((a, b) => a.acronym.localeCompare(b.acronym));
}

export function scanTeachersFromDistributionRows(
  rows: readonly CourseDistributionOfferingRow[],
): ScannedWorkbookTeacher[] {
  return aggregateTeachers(
    rows.map((r) => ({
      teacherRaw: r.teacher ?? "",
      deptRaw: r.conductingDept ?? null,
    })),
  );
}

export function diffScannedTeachersAgainstFaculty(
  scanned: readonly ScannedWorkbookTeacher[],
  faculty: readonly TimetableFacultyRecord[],
): WorkbookFacultyDiff {
  const byAcronym = new Map<string, TimetableFacultyRecord>();
  for (const f of faculty) {
    const key = f.acronym.trim().toUpperCase();
    if (key) byAcronym.set(key, f);
  }

  const missing: ScannedWorkbookTeacher[] = [];
  const inactive: InactiveWorkbookTeacher[] = [];
  const matched: ScannedWorkbookTeacher[] = [];

  for (const item of scanned) {
    const existing = byAcronym.get(item.acronym.trim().toUpperCase());
    if (!existing) {
      missing.push(item);
    } else if (!existing.is_active) {
      inactive.push({
        ...item,
        existingId: existing.id,
        existingFullName: existing.full_name,
        existingDept: existing.dept,
        existingDesignation: existing.designation,
        existingOffDays: [...existing.off_days],
        existingCourses: [...existing.courses],
        existingEmploymentType: existing.employment_type ?? "permanent",
        existingAllowThreeOffDays: Boolean(existing.allow_three_off_days),
        existingIsSustAdjunct: Boolean(existing.is_sust_adjunct),
      });
    } else {
      matched.push(item);
    }
  }

  return { missing, inactive, matched };
}

// ── Lightweight Zero-Dependency OOXML (.xlsx) Reader ─────────────────────────

interface ZipEntry {
  name: string;
  compressionMethod: number;
  compressedData: Uint8Array;
}

function readZipEntries(bytes: Uint8Array): Map<string, ZipEntry> {
  const entries = new Map<string, ZipEntry>();
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  const decoder = new TextDecoder("utf-8");

  // Locate End of Central Directory (EOCD) signature 0x06054b50 from the tail
  let eocdOffset = -1;
  const minOffset = Math.max(0, bytes.byteLength - 65557);
  for (let i = bytes.byteLength - 22; i >= minOffset; i--) {
    if (view.getUint32(i, true) === 0x06054b50) {
      eocdOffset = i;
      break;
    }
  }
  if (eocdOffset < 0) return entries;

  const cdCount = view.getUint16(eocdOffset + 10, true);
  let cdOffset = view.getUint32(eocdOffset + 16, true);

  for (let i = 0; i < cdCount && cdOffset + 46 <= bytes.byteLength; i++) {
    if (view.getUint32(cdOffset, true) !== 0x02014b50) break;
    const compressionMethod = view.getUint16(cdOffset + 10, true);
    const compressedSize = view.getUint32(cdOffset + 20, true);
    const nameLen = view.getUint16(cdOffset + 28, true);
    const extraLen = view.getUint16(cdOffset + 30, true);
    const commentLen = view.getUint16(cdOffset + 32, true);
    const localHeaderOffset = view.getUint32(cdOffset + 42, true);

    const name = decoder.decode(
      bytes.subarray(cdOffset + 46, cdOffset + 46 + nameLen),
    );
    cdOffset += 46 + nameLen + extraLen + commentLen;

    if (localHeaderOffset + 30 > bytes.byteLength) continue;
    if (view.getUint32(localHeaderOffset, true) !== 0x04034b50) continue;
    const localNameLen = view.getUint16(localHeaderOffset + 26, true);
    const localExtraLen = view.getUint16(localHeaderOffset + 28, true);
    const dataStart = localHeaderOffset + 30 + localNameLen + localExtraLen;
    const dataEnd = dataStart + compressedSize;
    if (dataEnd > bytes.byteLength) continue;

    entries.set(name.replace(/\\/g, "/"), {
      name,
      compressionMethod,
      compressedData: bytes.subarray(dataStart, dataEnd),
    });
  }

  return entries;
}

async function readZipTextEntry(
  entries: Map<string, ZipEntry>,
  path: string,
): Promise<string | null> {
  const entry = entries.get(path);
  if (!entry) return null;
  if (entry.compressionMethod === 0) {
    return new TextDecoder("utf-8").decode(entry.compressedData);
  }
  if (entry.compressionMethod === 8 && typeof DecompressionStream !== "undefined") {
    const ds = new DecompressionStream("deflate-raw");
    const writer = ds.writable.getWriter();
    void writer.write(new Uint8Array(entry.compressedData));
    void writer.close();
    const out = await new Response(ds.readable).arrayBuffer();
    return new TextDecoder("utf-8").decode(out);
  }
  return null;
}

function decodeXmlEntities(raw: string): string {
  return raw
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'")
    .replace(/&#(\d+);/g, (_, dec) => String.fromCharCode(Number(dec)))
    .replace(/&#x([0-9a-fA-F]+);/g, (_, hex) =>
      String.fromCharCode(Number.parseInt(hex, 16)),
    );
}

function colLettersToIndex(letters: string): number {
  let idx = 0;
  for (let i = 0; i < letters.length; i++) {
    idx = idx * 26 + (letters.charCodeAt(i) - 64);
  }
  return idx - 1; // 0-based (A=0, G=6, I=8)
}

function parseSharedStrings(xml: string | null): string[] {
  if (!xml) return [];
  const strings: string[] = [];
  const siRe = /<si\b[^>]*>([\s\S]*?)<\/si>/g;
  const tRe = /<t\b[^>]*>([\s\S]*?)<\/t>/g;
  let m: RegExpExecArray | null;
  while ((m = siRe.exec(xml)) !== null) {
    const body = m[1] ?? "";
    let text = "";
    let tm: RegExpExecArray | null;
    tRe.lastIndex = 0;
    while ((tm = tRe.exec(body)) !== null) {
      text += decodeXmlEntities(tm[1] ?? "");
    }
    strings.push(text);
  }
  return strings;
}

function resolveCourseDistributionSheetPath(
  workbookXml: string | null,
  relsXml: string | null,
): string {
  if (!workbookXml || !relsXml) return "xl/worksheets/sheet1.xml";
  const rels = new Map<string, string>();
  const relRe = /<Relationship\b([^>]+)\/?>/g;
  let rm: RegExpExecArray | null;
  while ((rm = relRe.exec(relsXml)) !== null) {
    const attrs = rm[1] ?? "";
    const idMatch = /\bId="([^"]+)"/.exec(attrs);
    const targetMatch = /\bTarget="([^"]+)"/.exec(attrs);
    if (idMatch?.[1] && targetMatch?.[1]) {
      const target = targetMatch[1].replace(/^\/+/, "");
      rels.set(idMatch[1], target.startsWith("xl/") ? target : `xl/${target}`);
    }
  }

  const sheetRe = /<sheet\b([^>]+)\/?>/g;
  let sm: RegExpExecArray | null;
  while ((sm = sheetRe.exec(workbookXml)) !== null) {
    const attrs = sm[1] ?? "";
    const nameMatch = /\bname="([^"]+)"/.exec(attrs);
    const ridMatch = /\br:id="([^"]+)"/.exec(attrs);
    if (
      nameMatch?.[1]?.trim().toLowerCase() === "course distribution" &&
      ridMatch?.[1]
    ) {
      return rels.get(ridMatch[1]) ?? "xl/worksheets/sheet1.xml";
    }
  }
  return "xl/worksheets/sheet1.xml";
}

function parseWorksheetRows(
  sheetXml: string,
  sharedStrings: readonly string[],
): Map<number, Map<number, string>> {
  const rows = new Map<number, Map<number, string>>();
  const rowRe = /<row\b([^>]*)>([\s\S]*?)<\/row>/g;
  const cellRe = /<c\b([^>]*)>([\s\S]*?)<\/c>/g;

  let rm: RegExpExecArray | null;
  while ((rm = rowRe.exec(sheetXml)) !== null) {
    const rowAttrs = rm[1] ?? "";
    const rMatch = /\br="(\d+)"/.exec(rowAttrs);
    if (!rMatch?.[1]) continue;
    const rowNum = Number.parseInt(rMatch[1], 10);
    if (rowNum < 5) continue;

    const cells = new Map<number, string>();
    const rowBody = rm[2] ?? "";
    let cm: RegExpExecArray | null;
    cellRe.lastIndex = 0;
    while ((cm = cellRe.exec(rowBody)) !== null) {
      const cAttrs = cm[1] ?? "";
      const cBody = cm[2] ?? "";
      const refMatch = /\br="([A-Z]+)\d+"/.exec(cAttrs);
      if (!refMatch?.[1]) continue;
      const colIdx = colLettersToIndex(refMatch[1]);
      const typeMatch = /\bt="([^"]+)"/.exec(cAttrs);
      const cellType = typeMatch?.[1] ?? "";

      let val = "";
      if (cellType === "inlineStr") {
        const tRe = /<t\b[^>]*>([\s\S]*?)<\/t>/g;
        let tm: RegExpExecArray | null;
        while ((tm = tRe.exec(cBody)) !== null) {
          val += decodeXmlEntities(tm[1] ?? "");
        }
      } else {
        const vMatch = /<v\b[^>]*>([\s\S]*?)<\/v>/.exec(cBody);
        const rawV = vMatch?.[1] ?? "";
        if (cellType === "s") {
          const sIdx = Number.parseInt(rawV, 10);
          val = sharedStrings[sIdx] ?? "";
        } else {
          val = decodeXmlEntities(rawV);
        }
      }
      if (val.trim()) {
        cells.set(colIdx, val.trim());
      }
    }
    if (cells.size > 0) {
      rows.set(rowNum, cells);
    }
  }
  return rows;
}

export async function parseCourseDistributionXlsxRows(
  bytes: Uint8Array,
): Promise<Map<number, Map<number, string>> | null> {
  if (!bytes || bytes.byteLength < 22) return null;
  const entries = readZipEntries(bytes);
  if (entries.size === 0) return null;

  const [workbookXml, relsXml, sharedStringsXml] = await Promise.all([
    readZipTextEntry(entries, "xl/workbook.xml"),
    readZipTextEntry(entries, "xl/_rels/workbook.xml.rels"),
    readZipTextEntry(entries, "xl/sharedStrings.xml"),
  ]);

  const sheetPath = resolveCourseDistributionSheetPath(workbookXml, relsXml);
  const sheetXml = await readZipTextEntry(entries, sheetPath);
  if (!sheetXml) return null;

  const sharedStrings = parseSharedStrings(sharedStringsXml);
  return parseWorksheetRows(sheetXml, sharedStrings);
}

/**
 * Scan teacher acronyms from an uploaded Course Distribution `.xlsx` file.
 * Fails gracefully (returns `[]`) on malformed/unsupported files so it can
 * never block or crash `Run CP-SAT Solver`.
 */
export async function scanTeachersFromXlsxBytes(
  bytes: Uint8Array,
): Promise<ScannedWorkbookTeacher[]> {
  try {
    const rowMap = await parseCourseDistributionXlsxRows(bytes);
    if (!rowMap) return [];

    // Locate Teacher & Conducting Dept columns from header row 5 (fallback I=8, G=6)
    const headerRow = rowMap.get(5);
    let teacherCol = 8;
    let deptCol = 6;
    if (headerRow) {
      for (const [colIdx, label] of headerRow.entries()) {
        const lower = label.toLowerCase();
        if (lower.startsWith("teacher")) {
          teacherCol = colIdx;
        } else if (lower.startsWith("conducting")) {
          deptCol = colIdx;
        }
      }
    }

    const pairs: Array<{ teacherRaw: string; deptRaw: string | null }> = [];
    for (const [rowNum, cells] of rowMap.entries()) {
      if (rowNum < 6) continue;
      const teacherRaw = cells.get(teacherCol) ?? "";
      if (!teacherRaw) continue;
      const deptRaw = cells.get(deptCol) ?? null;
      pairs.push({ teacherRaw, deptRaw });
    }

    return aggregateTeachers(pairs);
  } catch {
    return [];
  }
}
