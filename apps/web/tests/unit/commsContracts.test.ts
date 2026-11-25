import { describe, expect, it } from "vitest";
import {
  formatBroadcastAudienceLabel,
  NOTIFICATION_TYPES,
  toBroadcastInsertPayload,
} from "@/features/admin/services/broadcastService";
import {
  buildResourceStoragePath,
  extractResourceStoragePath,
  RESOURCE_CATEGORIES,
  RESOURCE_SEMESTERS,
  toResourceInsertPayload,
} from "@/features/admin/services/resourcesService";

describe("Broadcast & Academic Resources SQL/Flutter parity contracts", () => {
  it("enforces the exact 6-value SQL check_notif_type enum and sent_by author column", () => {
    expect([...NOTIFICATION_TYPES]).toEqual([
      "university",
      "class_cancel",
      "room_change",
      "test_reminder",
      "assignment",
      "exam",
    ]);

    const payload = toBroadcastInsertPayload(
      {
        title: "Midterm Routine Update",
        body: "Check updated room assignments before Thursday.",
        type: "room_change",
        target_role: "all",
        target_batch: "  ",
        target_section: "",
      },
      "admin-uuid-123",
    );

    expect(payload).toEqual({
      title: "Midterm Routine Update",
      body: "Check updated room assignments before Thursday.",
      type: "room_change",
      sent_by: "admin-uuid-123",
      target_role: null,
      target_batch: null,
      target_section: null,
    });
    expect("created_by" in payload).toBe(false);

    const targeted = toBroadcastInsertPayload(
      {
        title: "Lab Rescheduled",
        body: "ACL-2 session moved to Tuesday P5.",
        type: "class_cancel",
        target_role: "student",
        target_batch: "60",
        target_section: " b ",
      },
      "admin-uuid-123",
    );
    expect(targeted.target_role).toBe("student");
    expect(targeted.target_batch).toBe("60");
    expect(targeted.target_section).toBe("B");
    expect(formatBroadcastAudienceLabel(targeted)).toBe(
      "Students · Batch 60 · Section B",
    );
  });

  it("matches Flutter ResourceService Storage path sanitization and Drive URL validation", () => {
    expect([...RESOURCE_CATEGORIES]).toEqual([
      "PYQ",
      "Notes",
      "Slides",
      "Assignments",
    ]);
    expect([...RESOURCE_SEMESTERS]).toEqual([1, 2, 3, 4, 5, 6, 7, 8]);

    expect(buildResourceStoragePath(4, "CSE 2101 (Final)!.pdf", 1700000000)).toBe(
      "4/1700000000_CSE_2101__Final__.pdf",
    );

    expect(
      extractResourceStoragePath(
        "https://proj.supabase.co/storage/v1/object/public/resources/4/1700000000_notes.pdf?download=1",
      ),
    ).toBe("4/1700000000_notes.pdf");

    expect(() =>
      toResourceInsertPayload(
        {
          title: "Missing File or Drive",
          category: "Notes",
          semester: 3,
          drive_link: "",
          file_url: "",
        },
        "admin-uuid",
      ),
    ).toThrow(/Upload a file or provide an external HTTPS Drive link/i);

    expect(() =>
      toResourceInsertPayload(
        {
          title: "Insecure Drive",
          category: "PYQ",
          semester: 3,
          drive_link: "http://example.com/file.pdf",
        },
        "admin-uuid",
      ),
    ).toThrow(/https:\/\//i);
  });
});
