import { cleanup, fireEvent, render, screen, waitFor } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { CourseRoomPoolReviewModal } from "@/features/routine/components/CourseRoomPoolReviewModal";
import {
  classifyScannedCourses,
  scanCoursesFromDistributionRows,
  summarizeCourseRoomPools,
} from "@/features/routine/services/workbookCourseScanner";
import type { CourseDistributionOfferingRow } from "@/features/routine/services/distributionXlsxBuilder";

const { createCatalogCourseMock, updateCatalogCourseMock } = vi.hoisted(() => ({
  createCatalogCourseMock: vi.fn(),
  updateCatalogCourseMock: vi.fn(),
}));

vi.mock("@/features/admin/services/coursesService", async () => {
  const actual = await vi.importActual<
    typeof import("@/features/admin/services/coursesService")
  >("@/features/admin/services/coursesService");
  return {
    ...actual,
    createCatalogCourse: createCatalogCourseMock,
    updateCatalogCourse: updateCatalogCourseMock,
  };
});

function makeOfferingRow(
  overrides: Partial<CourseDistributionOfferingRow>,
): CourseDistributionOfferingRow {
  return {
    id: overrides.id ?? "row-1",
    batch: overrides.batch ?? "66",
    section: overrides.section ?? "A",
    courseCode: overrides.courseCode ?? "CSE-1101",
    courseTitle: overrides.courseTitle ?? "Structured Programming",
    credit: overrides.credit ?? 3.0,
    conductingDept: overrides.conductingDept ?? "CSE",
    students: overrides.students ?? 45,
    teacher: overrides.teacher ?? "FBM",
    noOfClasses: overrides.noOfClasses ?? 28,
    classDuration: overrides.classDuration ?? 1.5,
    classPerWeek: overrides.classPerWeek ?? 2,
    isService: overrides.isService ?? false,
  };
}

const FALL_2026_GED_ROWS: CourseDistributionOfferingRow[] = [
  makeOfferingRow({
    id: "r1",
    courseCode: "GED-3213",
    courseTitle: "Research Methodology",
    credit: 3.0,
    conductingDept: "",
  }),
  makeOfferingRow({
    id: "r2",
    courseCode: "GED-1116",
    courseTitle: "Introduction to Management",
    credit: 3.0,
    conductingDept: "GED",
  }),
  makeOfferingRow({
    id: "r3",
    courseCode: "GED-1262",
    courseTitle: "Computer Aided Engineering Drawing",
    credit: 1.0,
    conductingDept: "GED",
  }),
  makeOfferingRow({
    id: "r4",
    courseCode: "GED-1122",
    courseTitle: "Basic Computer Application",
    credit: 1.5,
    conductingDept: "",
  }),
  makeOfferingRow({
    id: "r5",
    courseCode: "GED-2222",
    courseTitle: "Computer Programming Sessional",
    credit: 1.5,
    conductingDept: "",
  }),
  makeOfferingRow({
    id: "r6",
    courseCode: "CSE-1101",
    courseTitle: "Structured Programming",
    credit: 3.0,
    conductingDept: "CSE",
  }),
];

describe("Course Room-Pool Preflight Scanner & Review Modal", () => {
  afterEach(() => {
    cleanup();
  });

  beforeEach(() => {
    createCatalogCourseMock.mockReset();
    updateCatalogCourseMock.mockReset();
    createCatalogCourseMock.mockResolvedValue({ id: "new-cat-1" });
    updateCatalogCourseMock.mockResolvedValue({ id: "upd-cat-1" });
  });

  it("matches Python Tier 2 + Tier 3 classification on all 5 real Fall 2026 GED-* cases", () => {
    const scanned = scanCoursesFromDistributionRows(FALL_2026_GED_ROWS);
    const classified = classifyScannedCourses(scanned, [
      {
        id: "cat-cse-1101",
        code: "CSE-1101",
        title: "Structured Programming",
        department_id: null,
        dept_code: "CSE",
        credit: 3.0,
        class_type: "theory",
        is_service: false,
        is_physics_lab: false,
        default_weekly_sessions: 2,
        is_active: true,
        notes: null,
        created_at: "2026-11-20T00:00:00Z",
        updated_at: "2026-11-20T00:00:00Z",
      },
    ]);

    const byCode = new Map(classified.map((c) => [c.code, c]));
    expect(byCode.get("GED-3213")?.roomPool).toBe("theory");
    expect(byCode.get("GED-1116")?.roomPool).toBe("theory");
    expect(byCode.get("GED-1262")?.roomPool).toBe("cse_lab");
    expect(byCode.get("GED-1122")?.roomPool).toBe("cse_lab");
    expect(byCode.get("GED-2222")?.roomPool).toBe("cse_lab");

    // Borderline / GED courses flagged for review; cataloged CSE-1101 is not
    expect(byCode.get("GED-1262")?.needsReview).toBe(true);
    expect(byCode.get("GED-1116")?.needsReview).toBe(true);
    expect(byCode.get("CSE-1101")?.needsReview).toBe(false);

    const summary = summarizeCourseRoomPools(classified);
    expect(summary.total).toBe(6);
    expect(summary.theory).toBe(3);
    expect(summary.cseLab).toBe(3);
    expect(summary.needsReviewCount).toBe(5);
  });

  it("filters borderline courses, applies inline override, and saves to catalog_courses", async () => {
    const scanned = scanCoursesFromDistributionRows(FALL_2026_GED_ROWS);
    const classified = classifyScannedCourses(scanned, []);
    const onSaved = vi.fn();
    const onOpenChange = vi.fn();

    render(
      <CourseRoomPoolReviewModal
        open={true}
        onOpenChange={onOpenChange}
        courses={classified}
        isDevPreview={false}
        onSaved={onSaved}
      />,
    );

    // Change GED-1122 from CSE Lab -> ECL Lab
    const select = screen.getByTestId("room-pool-select-GED-1122") as HTMLSelectElement;
    expect(select.value).toBe("cse_lab");
    fireEvent.change(select, { target: { value: "ecl_lab" } });
    expect(select.value).toBe("ecl_lab");

    // Switch to Overridden tab and verify GED-1122 appears
    fireEvent.click(screen.getByTestId("room-pool-tab-overridden"));
    expect(screen.getByTestId("room-pool-row-GED-1122")).toBeTruthy();

    // Save Overrides -> calls createCatalogCourse with [pool:ecl_lab]
    fireEvent.click(screen.getByTestId("save-room-pool-overrides-btn"));
    await waitFor(() => {
      expect(createCatalogCourseMock).toHaveBeenCalledTimes(1);
    });
    expect(createCatalogCourseMock).toHaveBeenCalledWith(
      expect.objectContaining({
        code: "GED-1122",
        class_type: "lab",
        is_physics_lab: false,
        notes: "[pool:ecl_lab]",
      }),
      false,
    );
    expect(onSaved).toHaveBeenCalledWith({ savedCount: 1 });
  });

  it("locks save controls in Dev Preview mode", () => {
    const scanned = scanCoursesFromDistributionRows(FALL_2026_GED_ROWS);
    const classified = classifyScannedCourses(scanned, []);

    render(
      <CourseRoomPoolReviewModal
        open={true}
        onOpenChange={() => {}}
        courses={classified}
        isDevPreview={true}
        onSaved={() => {}}
      />,
    );

    const saveBtn = screen.getByTestId(
      "save-room-pool-overrides-btn",
    ) as HTMLButtonElement;
    expect(saveBtn.disabled).toBe(true);
    expect(saveBtn.getAttribute("title")).toBe("Disabled in Dev Preview mode");
    expect(
      (screen.getByTestId("room-pool-select-GED-1122") as HTMLSelectElement)
        .disabled,
    ).toBe(true);
  });

  it("renders a viewport-centered visible dialog and dismisses on Escape", () => {
    const scanned = scanCoursesFromDistributionRows(FALL_2026_GED_ROWS);
    const classified = classifyScannedCourses(scanned, []);
    const onOpenChange = vi.fn();

    render(
      <CourseRoomPoolReviewModal
        open={true}
        onOpenChange={onOpenChange}
        courses={classified}
        isDevPreview={false}
        onSaved={() => {}}
      />,
    );

    const dialog = screen.getByRole("dialog");
    expect(dialog).toBeTruthy();
    expect(dialog.className).toContain("fixed");
    expect(dialog.className).toContain("left-1/2");
    expect(dialog.className).toContain("top-1/2");
    expect(dialog.className).toContain("-translate-x-1/2");
    expect(dialog.className).toContain("-translate-y-1/2");

    fireEvent.keyDown(dialog, { key: "Escape" });
    expect(onOpenChange).toHaveBeenCalledWith(false);
  });
});
