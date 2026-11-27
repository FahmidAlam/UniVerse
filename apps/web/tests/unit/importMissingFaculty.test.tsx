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
  });
});
