import { describe, expect, it } from "vitest";
import {
  buildCourseDistributionFile,
  buildCourseDistributionXlsx,
  CANONICAL_DISTRIBUTION_HEADERS,
  computeDistributionSessions,
  isLabCourseCode,
  parseDistributionPaste,
  splitTeacherTokens,
} from "@/features/routine/services/distributionXlsxBuilder";
import {
  createFall2026SampleRows,
  mapPublishedRoutinesToDistribution,
} from "@/features/routine/store/distributionDraftStore";
import type { RoutineRow } from "@/features/routine/types";

function findZipEntryText(zipBytes: Uint8Array, entryName: string): string | null {
  const decoder = new TextDecoder("utf-8");
  const view = new DataView(zipBytes.buffer, zipBytes.byteOffset, zipBytes.byteLength);
  let offset = 0;

  while (offset + 30 <= zipBytes.length) {
    const sig = view.getUint32(offset, true);
    if (sig !== 0x04034b50) break;
    const nameLen = view.getUint16(offset + 26, true);
    const extraLen = view.getUint16(offset + 28, true);
    const dataSize = view.getUint32(offset + 22, true);
    const nameStart = offset + 30;
    const name = decoder.decode(zipBytes.slice(nameStart, nameStart + nameLen));
    const dataStart = nameStart + nameLen + extraLen;
    if (name === entryName) {
      return decoder.decode(zipBytes.slice(dataStart, dataStart + dataSize));
    }
    offset = dataStart + dataSize;
  }
  return null;
}

describe("OOXML Course Distribution .xlsx Synthesizer & Paste Parser", () => {
  it("synthesizes a valid PK-zip OOXML workbook with Course Distribution sheet and Row 5 A-L headers", () => {
    const sample = createFall2026SampleRows(14);
    const rows = [
      ...sample.slice(0, 2),
      {
        id: "xml-escape-test",
        batch: "67",
        section: "F+G",
        courseCode: "CSE-2101",
        courseTitle: "Algorithms & Data <Structures>",
        credit: 3,
        prerequisite: "CSE-1101",
        conductingDept: "CSE",
        students: null, // Must be omitted, never written as 0
        teacher: "MFR / FK",
        totalClasses: 28,
        classDuration: 1.5,
        classesPerWeek: 2,
      },
    ];

    const bytes = buildCourseDistributionXlsx(rows, { termLabel: "Fall 2026" });

    // PK\x03\x04 local file header signature
    expect(bytes[0]).toBe(0x50);
    expect(bytes[1]).toBe(0x4b);
    expect(bytes[2]).toBe(0x03);
    expect(bytes[3]).toBe(0x04);

    const contentTypes = findZipEntryText(bytes, "[Content_Types].xml");
    const workbookXml = findZipEntryText(bytes, "xl/workbook.xml");
    const sheetXml = findZipEntryText(bytes, "xl/worksheets/sheet1.xml");

    expect(contentTypes).toContain("spreadsheetml.worksheet+xml");
    expect(workbookXml).toContain('name="Course Distribution"');
    expect(sheetXml).not.toBeNull();

    for (const header of CANONICAL_DISTRIBUTION_HEADERS) {
      expect(sheetXml).toContain(header);
    }

    // XML escaping verified
    expect(sheetXml).toContain("Algorithms &amp; Data &lt;Structures&gt;");
    // Blank No. of Students on row 8 (6 + 2) must be omitted, never <c r="H8"><v>0</v></c>
    expect(sheetXml).not.toContain('<c r="H8">');

    const file = buildCourseDistributionFile(rows, "Test_Dist.xlsx");
    expect(file.name).toBe("Test_Dist.xlsx");
    expect(file.type).toBe(
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    );
    expect(file.size).toBe(bytes.byteLength);
  });

  it("parses Excel/Sheets TSV & CSV paste rows and skips header row", () => {
    const tsv = [
      "Batch\tSection\tCourse Code\tCourse Title\tCredit\tPrerequisite\tConducting Dept\tNo. of Students\tTeacher\tNo. of Classes\tClass Duration\tClass/Week",
      "69\tA\tCSE-1101\tStructured Programming\t3\t\tCSE\t45\tEBH\t28\t1.5\t2",
      "67\tF+G\tCSE-2102\tData Structures Sessional\t1.5\t\tCSE\t\tMFR / FK",
    ].join("\n");

    const parsed = parseDistributionPaste(tsv, 14);
    expect(parsed).toHaveLength(2);
    expect(parsed[0]!.batch).toBe("69");
    expect(parsed[0]!.teacher).toBe("EBH");
    expect(parsed[1]!.section).toBe("F+G");
    expect(parsed[1]!.students).toBeNull();
    expect(parsed[1]!.totalClasses).toBe(28);
    expect(parsed[1]!.classesPerWeek).toBe(2);
  });

  it("computes R12/R13 sessions, lab detection, teacher tokens, and active routine mapping", () => {
    expect(isLabCourseCode("CSE-1102")).toBe(true);
    expect(isLabCourseCode("CSE-1101")).toBe(false);
    expect(computeDistributionSessions(1.5, 14, true).classesPerWeek).toBe(2);
    expect(computeDistributionSessions(3, 14, true).classesPerWeek).toBe(3);
    expect(splitTeacherTokens("MFR / FK")).toEqual(["MFR", "FK"]);

    const routineRows: RoutineRow[] = [
      {
        id: "r1",
        day: "Sunday",
        time_start: "08:50:00",
        time_end: "10:05:00",
        subject: "Structured Programming",
        subject_code: "CSE-1101",
        teacher_name: "Dr. EBH",
        teacher_code: "EBH",
        room: "G2",
        batch: "69",
        section: "A",
        semester: 1,
        is_active: true,
        is_service: false,
      },
      {
        id: "r2",
        day: "Tuesday",
        time_start: "08:50:00",
        time_end: "10:05:00",
        subject: "Structured Programming",
        subject_code: "CSE-1101",
        teacher_name: "Dr. EBH",
        teacher_code: "EBH",
        room: "G2",
        batch: "69",
        section: "A",
        semester: 1,
        is_active: true,
        is_service: false,
      },
    ];

    const mapped = mapPublishedRoutinesToDistribution(routineRows, 14);
    expect(mapped).toHaveLength(1);
    expect(mapped[0]!.classesPerWeek).toBe(2);
    expect(mapped[0]!.totalClasses).toBe(28);
    expect(mapped[0]!.teacher).toBe("EBH");
  });
});
