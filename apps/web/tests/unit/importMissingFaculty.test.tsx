import { cleanup, fireEvent, render, screen, waitFor } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import * as facultyService from "@/features/admin/services/facultyService";
import { ImportMissingFacultyModal } from "@/features/routine/components/ImportMissingFacultyModal";
import {
  buildCourseDistributionXlsx,
  type CourseDistributionOfferingRow,
} from "@/features/routine/services/distributionXlsxBuilder";
import {
  diffScannedTeachersAgainstFaculty,
  scanTeachersFromDistributionRows,
  scanTeachersFromXlsxBytes,
} from "@/features/routine/services/workbookFacultyScanner";

const SAMPLE_ROWS: CourseDistributionOfferingRow[] = [
  {
    id: "1",
    batch: "66",
    section: "A",
    courseCode: "CSE-1101",
    courseTitle: "Programming",
    credit: 3,
    prerequisite: "",
    conductingDept: "CSE",
    students: 45,
    teacher: "sbs/tkn",
    totalClasses: 28,
    classDuration: 1.5,
    classesPerWeek: 2,
  },
  {
    id: "2",
    batch: "66",
    section: "B",
    courseCode: "EEE-1201",
    courseTitle: "Circuits",
    credit: 3,
    prerequisite: "",
    conductingDept: "EEE",
    students: 45,
    teacher: "MNM",
    totalClasses: 28,
    classDuration: 1.5,
    classesPerWeek: 2,
  },
  {
    id: "3",
    batch: "66",
    section: "C",
    courseCode: "GED-1116",
    courseTitle: "Management",
    credit: 3,
    prerequisite: "",
    conductingDept: "BuA",
    students: 45,
    teacher: "TBA",
    totalClasses: 28,
    classDuration: 1.5,
    classesPerWeek: 2,
  },
  {
    id: "4",
    batch: "66",
    section: "D",
    courseCode: "CSE-1103",
    courseTitle: "Discrete Math",
    credit: 3,
    prerequisite: "",
    conductingDept: "CSE",
    students: 45,
    teacher: "  ",
    totalClasses: 28,
    classDuration: 1.5,
    classesPerWeek: 2,
  },
];

afterEach(() => {
  cleanup();
  vi.restoreAllMocks();
});

describe("workbookFacultyScanner & ImportMissingFacultyModal", () => {
  it("scans Course Distribution .xlsx bytes, splits co-teachers, ignores TBA/blanks, and degrades safely on corrupt bytes", async () => {
    const xlsxBytes = buildCourseDistributionXlsx(SAMPLE_ROWS, {
      termLabel: "Fall 2026",
    });
    const fromXlsx = await scanTeachersFromXlsxBytes(xlsxBytes);
    const fromDraft = scanTeachersFromDistributionRows(SAMPLE_ROWS);

    expect(fromXlsx).toEqual([
      { acronym: "MNM", suggestedDept: "EEE", occurrenceCount: 1 },
      { acronym: "SBS", suggestedDept: "CSE", occurrenceCount: 1 },
      { acronym: "TKN", suggestedDept: "CSE", occurrenceCount: 1 },
    ]);
    expect(fromDraft).toEqual(fromXlsx);

    // Malformed / non-ZIP bytes must return [] without throwing
    const bad = await scanTeachersFromXlsxBytes(new Uint8Array([1, 2, 3, 4, 5]));
    expect(bad).toEqual([]);
  });

  it("diffs scanned teachers case-insensitively into missing, inactive, and matched", () => {
    const scanned = scanTeachersFromDistributionRows(SAMPLE_ROWS);
    const faculty: facultyService.TimetableFacultyRecord[] = [
      {
        id: "fac-1",
        acronym: "sbs",
        full_name: "Prof SBS",
        dept: "CSE",
        designation: "Professor",
        off_days: ["Friday", "Saturday"],
        is_active: true,
        courses: [],
      },
      {
        id: "fac-2",
        acronym: "MNM",
        full_name: "Prof MNM",
        dept: "EEE",
        designation: "Lecturer",
        off_days: ["Thursday", "Friday"],
        is_active: false,
        courses: [],
        employment_type: "permanent",
      },
    ];

    const diff = diffScannedTeachersAgainstFaculty(scanned, faculty);
    expect(diff.matched.map((t) => t.acronym)).toEqual(["SBS"]);
    expect(diff.inactive.map((t) => t.acronym)).toEqual(["MNM"]);
    expect(diff.inactive[0]?.existingId).toBe("fac-2");
    expect(diff.missing.map((t) => t.acronym)).toEqual(["TKN"]);
  });

  it("allows unchecking a typo, reactivates inactive rows without duplicate insert, and inserts missing rows", async () => {
    const bulkSpy = vi
      .spyOn(facultyService, "bulkSetFacultyActive")
      .mockResolvedValue(undefined);
    const createSpy = vi
      .spyOn(facultyService, "createFaculty")
      .mockResolvedValue({
        id: "new-1",
        acronym: "TKN",
        full_name: "TKN",
        dept: "CSE",
        designation: null,
        off_days: [],
        is_active: true,
        courses: [],
      });
    const onImported = vi.fn();
    const onOpenChange = vi.fn();

    render(
      <ImportMissingFacultyModal
        open={true}
        onOpenChange={onOpenChange}
        missing={[
          { acronym: "TKN", suggestedDept: "CSE", occurrenceCount: 4 },
          { acronym: "TYPO", suggestedDept: "CSE", occurrenceCount: 1 },
        ]}
        inactive={[
          {
            acronym: "MNM",
            suggestedDept: "EEE",
            occurrenceCount: 2,
            existingId: "fac-2",
            existingFullName: "Prof MNM",
            existingDept: "EEE",
            existingDesignation: "Lecturer",
            existingOffDays: ["Friday", "Saturday"],
            existingCourses: [],
            existingEmploymentType: "permanent",
            existingAllowThreeOffDays: false,
            existingIsSustAdjunct: false,
          },
        ]}
        isDevPreview={false}
        onImported={onImported}
      />,
    );

    // Uncheck the typo row before importing
    fireEvent.click(screen.getByLabelText("Select TYPO"));
    fireEvent.click(screen.getByTestId("confirm-import-faculty-btn"));

    await waitFor(() => {
      expect(onImported).toHaveBeenCalledWith({
        addedCount: 1,
        reactivatedCount: 1,
      });
    });

    expect(bulkSpy).toHaveBeenCalledWith(["fac-2"], true, false);
    expect(createSpy).toHaveBeenCalledTimes(1);
    expect(createSpy).toHaveBeenCalledWith(
      expect.objectContaining({
        acronym: "TKN",
        full_name: "TKN",
        dept: "CSE",
        is_active: true,
        off_days: [],
        courses: [],
        employment_type: "permanent",
      }),
      false,
    );
    expect(onOpenChange).toHaveBeenCalledWith(false);
  });

  it("disables import completely in Dev Preview mode", () => {
    render(
      <ImportMissingFacultyModal
        open={true}
        onOpenChange={() => {}}
        missing={[{ acronym: "TKN", suggestedDept: "CSE", occurrenceCount: 2 }]}
        inactive={[]}
        isDevPreview={true}
        onImported={() => {}}
      />,
    );
    const btn = screen.getByTestId(
      "confirm-import-faculty-btn",
    ) as HTMLButtonElement;
    expect(btn.disabled).toBe(true);

    const dialog = screen.getByRole("dialog");
    expect(dialog.className).toContain("fixed");
    expect(dialog.className).toContain("left-1/2");
    expect(dialog.className).toContain("top-1/2");
  });

  it("extracts teachers even when preceding cells are self-closing empty <c .../> tags", async () => {
    // Build a minimal stored (method 0) ZIP containing Course Distribution XML
    // where Col H (No. Of Students) is a self-closing <c r="H6" s="12"/> right before Col I (Teacher).
    const enc = new TextEncoder();
    const files: Array<{ name: string; data: Uint8Array }> = [
      {
        name: "xl/workbook.xml",
        data: enc.encode(
          `<workbook xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Course Distribution" sheetId="1" r:id="rId1"/></sheets></workbook>`,
        ),
      },
      {
        name: "xl/_rels/workbook.xml.rels",
        data: enc.encode(
          `<Relationships><Relationship Id="rId1" Target="worksheets/sheet1.xml"/></Relationships>`,
        ),
      },
      {
        name: "xl/sharedStrings.xml",
        data: enc.encode(
          `<sst><si><t>Batch</t></si><si><t>Course Code</t></si><si><t>Conducting Department</t></si><si><t>Teacher</t></si><si><t>SHI</t></si><si><t>MNM/KSA</t></si></sst>`,
        ),
      },
      {
        name: "xl/worksheets/sheet1.xml",
        data: enc.encode(
          `<worksheet><sheetData>` +
            `<row r="5"><c r="A5" t="s"><v>0</v></c><c r="C5" t="s"><v>1</v></c><c r="G5" t="s"><v>2</v></c><c r="I5" t="s"><v>3</v></c></row>` +
            `<row r="6"><c r="A6"><v>66</v></c><c r="F6" s="1"/><c r="G6" s="1"/><c r="H6" s="12"/><c r="I6" t="s"><v>4</v></c></row>` +
            `<row r="7"><c r="A7"><v>66</v></c><c r="H7" s="12"/><c r="I7" t="s"><v>5</v></c></row>` +
            `</sheetData></worksheet>`,
        ),
      },
    ];

    const localParts: Uint8Array[] = [];
    const cdParts: Uint8Array[] = [];
    let offset = 0;

    for (const f of files) {
      const nameBytes = enc.encode(f.name);
      const local = new Uint8Array(30 + nameBytes.length + f.data.length);
      const lv = new DataView(local.buffer);
      lv.setUint32(0, 0x04034b50, true);
      lv.setUint16(4, 20, true);
      lv.setUint16(8, 0, true);
      lv.setUint32(18, f.data.length, true);
      lv.setUint32(22, f.data.length, true);
      lv.setUint16(26, nameBytes.length, true);
      local.set(nameBytes, 30);
      local.set(f.data, 30 + nameBytes.length);
      localParts.push(local);

      const cd = new Uint8Array(46 + nameBytes.length);
      const cv = new DataView(cd.buffer);
      cv.setUint32(0, 0x02014b50, true);
      cv.setUint16(4, 20, true);
      cv.setUint16(6, 20, true);
      cv.setUint16(10, 0, true);
      cv.setUint32(20, f.data.length, true);
      cv.setUint32(24, f.data.length, true);
      cv.setUint16(28, nameBytes.length, true);
      cv.setUint32(42, offset, true);
      cd.set(nameBytes, 46);
      cdParts.push(cd);

      offset += local.length;
    }

    const cdStart = offset;
    const cdSize = cdParts.reduce((s, p) => s + p.length, 0);
    const eocd = new Uint8Array(22);
    const ev = new DataView(eocd.buffer);
    ev.setUint32(0, 0x06054b50, true);
    ev.setUint16(8, files.length, true);
    ev.setUint16(10, files.length, true);
    ev.setUint32(12, cdSize, true);
    ev.setUint32(16, cdStart, true);

    const totalLen = cdStart + cdSize + eocd.length;
    const zip = new Uint8Array(totalLen);
    let cursor = 0;
    for (const p of [...localParts, ...cdParts, eocd]) {
      zip.set(p, cursor);
      cursor += p.length;
    }

    const scanned = await scanTeachersFromXlsxBytes(zip);
    expect(scanned.map((s) => s.acronym)).toEqual(["KSA", "MNM", "SHI"]);

    const diff = diffScannedTeachersAgainstFaculty(scanned, [
      {
        id: "f1",
        acronym: "KSA",
        full_name: "KSA",
        dept: "CSE",
        designation: null,
        off_days: [],
        is_active: true,
        courses: [],
      },
    ]);
    expect(diff.missing.map((m) => m.acronym)).toEqual(["MNM", "SHI"]);
  });
});
