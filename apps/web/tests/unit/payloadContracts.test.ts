import { describe, expect, it } from "vitest";
import { toEligibilityWritePayload } from "@/features/admin/services/eligibilityService";
import {
  FACULTY_SELECT_COLUMNS,
  toFacultyWritePayload,
} from "@/features/admin/services/facultyService";
import {
  ROOM_SELECT_COLUMNS,
  toRoomWritePayload,
} from "@/features/admin/services/roomsService";

describe("Phase 2A PostgreSQL baseline payload contracts", () => {
  it("emits strictly the 8 guaranteed baseline columns in room select and 7 writable columns in payload", () => {
    expect(ROOM_SELECT_COLUMNS.split(",").map((s) => s.trim())).toEqual([
      "id",
      "name",
      "building",
      "is_lab",
      "is_gallery",
      "capacity",
      "is_active",
      "dept",
    ]);

    const dirtyInput = {
      name: "  rab-302 ",
      building: " RAB ",
      is_lab: false,
      is_gallery: true,
      capacity: 120.7,
      is_active: true,
      dept: " CSE ",
      campus: "Tilagor",
      features: ["projector"],
      classification: "Gallery",
      declared_window_matrix: {},
    };

    const payload = toRoomWritePayload(dirtyInput);
    expect(Object.keys(payload).sort()).toEqual([
      "building",
      "capacity",
      "dept",
      "is_active",
      "is_gallery",
      "is_lab",
      "name",
    ]);
    expect(payload).toEqual({
      name: "RAB-302",
      building: "RAB",
      is_lab: false,
      is_gallery: true,
      capacity: 120,
      is_active: true,
      dept: "CSE",
    });
    expect("campus" in payload).toBe(false);
    expect("features" in payload).toBe(false);
    expect("classification" in payload).toBe(false);
    expect("declared_window_matrix" in payload).toBe(false);
  });

  it("emits strictly the 8 guaranteed baseline columns in faculty select and 7 writable columns in payload", () => {
    expect(FACULTY_SELECT_COLUMNS.split(",").map((s) => s.trim())).toEqual([
      "id",
      "acronym",
      "full_name",
      "dept",
      "designation",
      "off_days",
      "is_active",
      "courses",
    ]);

    const dirtyInput = {
      acronym: " mhk ",
      full_name: " Mahbub Hasan ",
      dept: "CSE",
      designation: "Lecturer",
      off_days: ["Friday", "BogusDay", "Tuesday", "Friday"],
      is_active: true,
      courses: [" cse-2101 ", "CSE-2101", ""],
      home_department_id: "dept-1",
      employment_type: "Permanent",
      slot_matrix: {},
    };

    const payload = toFacultyWritePayload(dirtyInput);
    expect(Object.keys(payload).sort()).toEqual([
      "acronym",
      "courses",
      "dept",
      "designation",
      "full_name",
      "is_active",
      "off_days",
    ]);
    expect(payload).toEqual({
      acronym: "MHK",
      full_name: "Mahbub Hasan",
      dept: "CSE",
      designation: "Lecturer",
      off_days: ["Tuesday", "Friday"],
      is_active: true,
      courses: ["CSE-2101"],
    });
    expect("home_department_id" in payload).toBe(false);
    expect("employment_type" in payload).toBe(false);
    expect("slot_matrix" in payload).toBe(false);
  });

  it("normalizes course eligibility payloads cleanly", () => {
    expect(
      toEligibilityWritePayload({
        acronym: " mhk ",
        course_code: " cse-2101 ",
        is_eligible: true,
        priority: 2.9,
      }),
    ).toEqual({
      acronym: "MHK",
      course_code: "CSE-2101",
      is_eligible: true,
      priority: 2,
    });

    expect(
      toEligibilityWritePayload({
        acronym: "abc",
        course_code: "cse-1101",
        is_eligible: false,
        priority: 0,
      }).priority,
    ).toBeNull();
  });
});
