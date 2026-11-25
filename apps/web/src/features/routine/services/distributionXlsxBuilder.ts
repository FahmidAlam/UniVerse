import { crc32 } from "@/features/routine/services/generationProfile";

export interface CourseDistributionOfferingRow {
  id: string;
  batch: string;
  section: string;
  courseCode: string;
  courseTitle: string;
  credit: number | null;
  prerequisite: string;
  conductingDept: string;
  students: number | null;
  teacher: string;
  totalClasses: number | null;
  classDuration: number | null;
  classesPerWeek: number | null;
}

export interface DistributionWorkbookMeta {
  termLabel?: string;
  departmentName?: string;
  institutionName?: string;
}

export const DISTRIBUTION_SHEET_NAME = "Course Distribution";

export const CANONICAL_DISTRIBUTION_HEADERS = [
  "Batch",
  "Section",
  "Course Code",
  "Course Title",
  "Credit",
  "Prerequisite",
  "Conducting Dept",
  "No. of Students",
  "Teacher",
  "No. of Classes",
  "Class Duration",
  "Class/Week",
] as const;

export function isLabCourseCode(code: string, title = ""): boolean {
  const trimmed = code.trim();
  const m = /(\d+)\s*$/.exec(trimmed);
  if (m) {
    const lastDigit = Number.parseInt(m[1]!.slice(-1), 10);
    if (Number.isFinite(lastDigit) && lastDigit % 2 === 0) return true;
  }
  const lower = title.toLowerCase();
  return lower.includes("sessional") || lower.includes("lab");
}

export function computeDistributionSessions(
  credit: number | null,
  weeksInTerm: number,
  isLab: boolean,
): {
  totalClasses: number;
  classesPerWeek: number;
  ruleBadge: string;
} {
  const safeWeeks = Math.max(1, Math.round(weeksInTerm || 14));
  const cr = credit ?? 3;
  let classesPerWeek = 2;
  let ruleBadge = "3 Cr Theory · 2/wk";

  if (isLab) {
    if (cr >= 3) {
      classesPerWeek = 3;
      ruleBadge = "Sessional · 3/wk";
    } else if (cr <= 1) {
      classesPerWeek = 1;
      ruleBadge = "Sessional · 1/wk";
    } else {
      classesPerWeek = 2;
      ruleBadge = "Sessional · 2/wk";
    }
  } else if (cr <= 2) {
    classesPerWeek = cr <= 1 ? 1 : 2;
    ruleBadge = "1–2 Cr Theory · 1-Day 2-Slot Block";
  }

  return {
    totalClasses: classesPerWeek * safeWeeks,
    classesPerWeek,
    ruleBadge,
  };
}

export function splitTeacherTokens(teacherRaw: string): string[] {
  return teacherRaw
    .split(/[\/,&+]+/)
    .map((t) => t.trim())
    .filter(Boolean);
}

function parseOptionalNumber(raw: string | undefined): number | null {
  if (!raw) return null;
  const trimmed = raw.trim();
  if (!trimmed) return null;
  const n = Number(trimmed);
  return Number.isFinite(n) ? n : null;
}

function splitCsvLine(line: string): string[] {
  const cells: string[] = [];
  let current = "";
  let inQuotes = false;
  for (let i = 0; i < line.length; i++) {
    const ch = line[i]!;
    if (ch === '"') {
      if (inQuotes && line[i + 1] === '"') {
        current += '"';
        i++;
      } else {
        inQuotes = !inQuotes;
      }
    } else if (ch === "," && !inQuotes) {
      cells.push(current.trim());
      current = "";
    } else {
      current += ch;
    }
  }
  cells.push(current.trim());
  return cells;
}

export function parseDistributionPaste(
  text: string,
  weeksInTerm = 14,
): CourseDistributionOfferingRow[] {
  const lines = text
    .split(/\r?\n/)
    .map((l) => l.trimEnd())
    .filter((l) => l.trim().length > 0);
  if (lines.length === 0) return [];

  const useTabs = lines.some((l) => l.includes("\t"));
  const rows: CourseDistributionOfferingRow[] = [];

  for (let idx = 0; idx < lines.length; idx++) {
    const line = lines[idx]!;
    const cols = useTabs ? line.split("\t").map((c) => c.trim()) : splitCsvLine(line);
    const first = (cols[0] ?? "").toLowerCase();
    const third = (cols[2] ?? "").toLowerCase();
    if (idx === 0 && (first === "batch" || third.startsWith("course code"))) {
      continue;
    }

    const batch = cols[0] ?? "";
    const section = cols[1] ?? "";
    const courseCode = cols[2] ?? "";
    const courseTitle = cols[3] ?? "";
    if (!batch && !courseCode) continue;

    const credit = parseOptionalNumber(cols[4]);
    const isLab = isLabCourseCode(courseCode, courseTitle);
    const derived = computeDistributionSessions(credit, weeksInTerm, isLab);

    const parsedTotal = parseOptionalNumber(cols[9]);
    const parsedDuration = parseOptionalNumber(cols[10]);
    const parsedPerWeek = parseOptionalNumber(cols[11]);

    rows.push({
      id: `paste-${Date.now()}-${idx}-${Math.random().toString(36).slice(2, 7)}`,
      batch,
      section,
      courseCode,
      courseTitle: courseTitle || courseCode,
      credit,
      prerequisite: cols[5] ?? "",
      conductingDept: cols[6] || "CSE",
      students: parseOptionalNumber(cols[7]),
      teacher: cols[8] ?? "",
      totalClasses: parsedTotal ?? derived.totalClasses,
      classDuration: parsedDuration ?? 1.5,
      classesPerWeek: parsedPerWeek ?? derived.classesPerWeek,
    });
  }

  return rows;
}

function escapeXml(value: string): string {
  // Strip XML 1.0 illegal control characters
  const cleaned = value.replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F]/g, "");
  return cleaned
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&apos;");
}

function colLetters(colIndexZeroBased: number): string {
  let n = colIndexZeroBased + 1;
  let out = "";
  while (n > 0) {
    const rem = (n - 1) % 26;
    out = String.fromCharCode(65 + rem) + out;
    n = Math.floor((n - 1) / 26);
  }
  return out;
}

function xmlStringCell(ref: string, value: string): string {
  return `<c r="${ref}" t="inlineStr"><is><t xml:space="preserve">${escapeXml(value)}</t></is></c>`;
}

function xmlNumberCell(ref: string, value: number): string {
  return `<c r="${ref}"><v>${value}</v></c>`;
}

function buildWorksheetXml(
  rows: readonly CourseDistributionOfferingRow[],
  meta: DistributionWorkbookMeta,
): string {
  const institution = meta.institutionName?.trim() || "LEADING UNIVERSITY";
  const department =
    meta.departmentName?.trim() || "Department of Computer Science & Engineering";
  const term = meta.termLabel?.trim() || "Fall 2026";

  const xmlRows: string[] = [];
  xmlRows.push(`<row r="1">${xmlStringCell("A1", institution)}</row>`);
  xmlRows.push(`<row r="2">${xmlStringCell("A2", department)}</row>`);
  xmlRows.push(
    `<row r="3">${xmlStringCell("A3", `List of Offered Courses for ${term}`)}</row>`,
  );

  const headerCells = CANONICAL_DISTRIBUTION_HEADERS.map((header, idx) =>
    xmlStringCell(`${colLetters(idx)}5`, header),
  ).join("");
  xmlRows.push(`<row r="5">${headerCells}</row>`);

  let excelRow = 6;
  for (const row of rows) {
    const batch = row.batch.trim();
    const code = row.courseCode.trim();
    if (!batch && !code) continue;

    const cells: string[] = [];
    const batchNumeric = /^\d+$/.test(batch) ? Number.parseInt(batch, 10) : null;
    if (batch) {
      cells.push(
        batchNumeric !== null
          ? xmlNumberCell(`A${excelRow}`, batchNumeric)
          : xmlStringCell(`A${excelRow}`, batch),
      );
    }
    if (row.section.trim()) {
      cells.push(xmlStringCell(`B${excelRow}`, row.section.trim()));
    }
    if (code) {
      cells.push(xmlStringCell(`C${excelRow}`, code));
    }
    if (row.courseTitle.trim()) {
      cells.push(xmlStringCell(`D${excelRow}`, row.courseTitle.trim()));
    }
    if (row.credit !== null && Number.isFinite(row.credit)) {
      cells.push(xmlNumberCell(`E${excelRow}`, row.credit));
    }
    if (row.prerequisite.trim()) {
      cells.push(xmlStringCell(`F${excelRow}`, row.prerequisite.trim()));
    }
    if (row.conductingDept.trim()) {
      cells.push(xmlStringCell(`G${excelRow}`, row.conductingDept.trim()));
    }
    // Omit blank/unknown No. of Students rather than writing 0
    if (row.students !== null && Number.isFinite(row.students) && row.students > 0) {
      cells.push(xmlNumberCell(`H${excelRow}`, Math.round(row.students)));
    }
    if (row.teacher.trim()) {
      cells.push(xmlStringCell(`I${excelRow}`, row.teacher.trim()));
    }
    if (row.totalClasses !== null && Number.isFinite(row.totalClasses)) {
      cells.push(xmlNumberCell(`J${excelRow}`, Math.round(row.totalClasses)));
    }
    if (row.classDuration !== null && Number.isFinite(row.classDuration)) {
      cells.push(xmlNumberCell(`K${excelRow}`, row.classDuration));
    }
    if (row.classesPerWeek !== null && Number.isFinite(row.classesPerWeek)) {
      cells.push(xmlNumberCell(`L${excelRow}`, Math.round(row.classesPerWeek)));
    }

    if (cells.length > 0) {
      xmlRows.push(`<row r="${excelRow}">${cells.join("")}</row>`);
      excelRow++;
    }
  }

  return [
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
    '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">',
    `<sheetData>${xmlRows.join("")}</sheetData>`,
    "</worksheet>",
  ].join("");
}

interface ZipEntryInput {
  name: string;
  data: Uint8Array;
}

function buildStoreZip(entries: readonly ZipEntryInput[]): Uint8Array {
  const encoder = new TextEncoder();
  const localParts: Uint8Array[] = [];
  const centralParts: Uint8Array[] = [];
  let offset = 0;

  for (const entry of entries) {
    const nameBytes = encoder.encode(entry.name);
    const data = entry.data;
    const checksum = crc32(data);

    // Local file header (30 bytes + filename)
    const localHeader = new Uint8Array(30 + nameBytes.length);
    const lv = new DataView(localHeader.buffer);
    lv.setUint32(0, 0x04034b50, true); // Local file header signature
    lv.setUint16(4, 20, true); // Version needed to extract (2.0)
    lv.setUint16(6, 0x0800, true); // UTF-8 filename flag
    lv.setUint16(8, 0, true); // Compression method 0 (STORE)
    lv.setUint16(10, 0, true); // Mod time
    lv.setUint16(12, 0x5421, true); // Mod date
    lv.setUint32(14, checksum, true);
    lv.setUint32(18, data.length, true); // Compressed size
    lv.setUint32(22, data.length, true); // Uncompressed size
    lv.setUint16(26, nameBytes.length, true);
    lv.setUint16(28, 0, true); // Extra field length
    localHeader.set(nameBytes, 30);

    localParts.push(localHeader, data);

    // Central directory header (46 bytes + filename)
    const centralHeader = new Uint8Array(46 + nameBytes.length);
    const cv = new DataView(centralHeader.buffer);
    cv.setUint32(0, 0x02014b50, true); // Central directory signature
    cv.setUint16(4, 20, true); // Version made by
    cv.setUint16(6, 20, true); // Version needed
    cv.setUint16(8, 0x0800, true); // UTF-8 flag
    cv.setUint16(10, 0, true); // Compression method 0 (STORE)
    cv.setUint16(12, 0, true);
    cv.setUint16(14, 0x5421, true);
    cv.setUint32(16, checksum, true);
    cv.setUint32(20, data.length, true);
    cv.setUint32(24, data.length, true);
    cv.setUint16(28, nameBytes.length, true);
    cv.setUint16(30, 0, true);
    cv.setUint16(32, 0, true);
    cv.setUint16(34, 0, true);
    cv.setUint16(36, 0, true);
    cv.setUint32(38, 0, true);
    cv.setUint32(42, offset, true);
    centralHeader.set(nameBytes, 46);

    centralParts.push(centralHeader);
    offset += localHeader.length + data.length;
  }

  const centralSize = centralParts.reduce((acc, part) => acc + part.length, 0);
  const eocd = new Uint8Array(22);
  const ev = new DataView(eocd.buffer);
  ev.setUint32(0, 0x06054b50, true); // End of central directory signature
  ev.setUint16(4, 0, true);
  ev.setUint16(6, 0, true);
  ev.setUint16(8, entries.length, true);
  ev.setUint16(10, entries.length, true);
  ev.setUint32(12, centralSize, true);
  ev.setUint32(16, offset, true);
  ev.setUint16(20, 0, true);

  const totalSize = offset + centralSize + eocd.length;
  const archive = new Uint8Array(totalSize);
  let cursor = 0;
  for (const part of localParts) {
    archive.set(part, cursor);
    cursor += part.length;
  }
  for (const part of centralParts) {
    archive.set(part, cursor);
    cursor += part.length;
  }
  archive.set(eocd, cursor);
  return archive;
}

export function buildCourseDistributionXlsx(
  rows: readonly CourseDistributionOfferingRow[],
  meta: DistributionWorkbookMeta = {},
): Uint8Array {
  const encoder = new TextEncoder();

  const contentTypesXml = [
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
    '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">',
    '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>',
    '<Default Extension="xml" ContentType="application/xml"/>',
    '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>',
    '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>',
    "</Types>",
  ].join("");

  const rootRelsXml = [
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">',
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>',
    "</Relationships>",
  ].join("");

  const workbookXml = [
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
    '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">',
    "<sheets>",
    `<sheet name="${escapeXml(DISTRIBUTION_SHEET_NAME)}" sheetId="1" r:id="rId1"/>`,
    "</sheets>",
    "</workbook>",
  ].join("");

  const workbookRelsXml = [
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">',
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>',
    "</Relationships>",
  ].join("");

  const sheet1Xml = buildWorksheetXml(rows, meta);

  return buildStoreZip([
    { name: "[Content_Types].xml", data: encoder.encode(contentTypesXml) },
    { name: "_rels/.rels", data: encoder.encode(rootRelsXml) },
    { name: "xl/workbook.xml", data: encoder.encode(workbookXml) },
    { name: "xl/_rels/workbook.xml.rels", data: encoder.encode(workbookRelsXml) },
    { name: "xl/worksheets/sheet1.xml", data: encoder.encode(sheet1Xml) },
  ]);
}

export function buildCourseDistributionFile(
  rows: readonly CourseDistributionOfferingRow[],
  filename = "Course_Distribution_Draft.xlsx",
  meta: DistributionWorkbookMeta = {},
): File {
  const bytes = buildCourseDistributionXlsx(rows, meta);
  const copy = new Uint8Array(bytes.byteLength);
  copy.set(bytes);
  return new File([copy.buffer], filename, {
    type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
  });
}
