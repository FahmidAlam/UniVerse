import { describe, expect, it } from "vitest";
import {
  CAPABILITY_REGISTRY,
  SUBFEATURE_CAPABILITIES,
  formatCapabilityStatusLabel,
  getCapabilitiesByGroup,
  getCapabilityById,
  getCapabilityByPath,
} from "@/core/capabilities";

describe("Centralized CapabilityRegistry contract", () => {
  it("contains all 14 admin routes with unique IDs and paths", () => {
    expect(CAPABILITY_REGISTRY).toHaveLength(14);
    const ids = new Set(CAPABILITY_REGISTRY.map((c) => c.id));
    const paths = new Set(CAPABILITY_REGISTRY.map((c) => c.path));
    expect(ids.size).toBe(14);
    expect(paths.size).toBe(14);
  });

  it("marks Courses and Batches strictly as staged-no-db with STAGED badges", () => {
    const courses = getCapabilityById("admin.courses");
    const batches = getCapabilityById("admin.batches");
    expect(courses?.status).toBe("staged-no-db");
    expect(courses?.sidebarBadge).toBe("STAGED");
    expect(batches?.status).toBe("staged-no-db");
    expect(batches?.sidebarBadge).toBe("STAGED");
  });

  it("marks Scheduling Workbench & Track 1 upload as fail-closed-gate", () => {
    const workbench = getCapabilityByPath("/admin/scheduling");
    expect(workbench?.status).toBe("fail-closed-gate");
    expect(workbench?.sidebarBadge).toBe("GATED");

    const upload = SUBFEATURE_CAPABILITIES.find(
      (s) => s.id === "track1.workbook-upload",
    );
    expect(upload?.status).toBe("fail-closed-gate");
    expect(upload?.label).toBe("Rendered Routine Upload");
    expect(upload?.badgeLabel).toBe("Gated · Phase 3B");
  });

  it("marks Routine Matrix as read-only without READ-ONLY sidebar pill and marks Profile live-persisted", () => {
    const grid = getCapabilityById("admin.routine-grid");
    expect(grid?.status).toBe("read-only");
    expect(grid?.sidebarBadge).toBeUndefined();
    expect(getCapabilityById("admin.profile")?.status).toBe("live-persisted");
  });

  it("keeps Dashboard active as live-persisted in Phase 1A and splits groups evenly", () => {
    const dash = getCapabilityByPath("/admin/dashboard");
    expect(dash?.status).toBe("live-persisted");
    expect(dash?.implementedInPhase1A).toBe(true);

    expect(getCapabilitiesByGroup("operations")).toHaveLength(4);
    expect(getCapabilitiesByGroup("configuration")).toHaveLength(6);
    expect(getCapabilitiesByGroup("directory")).toHaveLength(4);
    expect(formatCapabilityStatusLabel("fail-closed-gate")).toContain("Gates A–D");
  });
});
