import fs from "node:fs";
import path from "node:path";
import { afterEach, describe, expect, it, vi } from "vitest";
import { toOwnProfileUpdatePayload } from "@/features/admin/services/profileService";
import {
  buildInviteAdminPayload,
  updateProfileRole,
} from "@/features/admin/services/usersService";

describe("Users directory, invite-admin Edge Function & Profile F-30 contracts", () => {
  afterEach(() => {
    vi.doUnmock("@/services/supabase");
  });

  it("hard-blocks administrator self-demotion", async () => {
    await expect(
      updateProfileRole("admin-self-1", "teacher", "admin-self-1", true),
    ).rejects.toThrow(/Self-demotion is blocked/i);
  });

  it("builds exact invite-admin payload with root origin redirect_to", () => {
    expect(
      buildInviteAdminPayload(
        "  Chair.CSE@lus.ac.bd ",
        " Dr. Chair ",
        "https://universe.pages.dev/",
      ),
    ).toEqual({
      email: "chair.cse@lus.ac.bd",
      name: "Dr. Chair",
      redirect_to: "https://universe.pages.dev/",
    });
  });

  it("surfaces 400/403/404 Edge Function invite-admin errors honestly without faking success", async () => {
    for (const [status, serverMsg, expectedPattern] of [
      [400, "Invitation callback is not approved.", /Invitation callback is not approved\./i],
      [403, "Only admins can invite admins.", /Only admins can invite admins\./i],
      [404, "", /not deployed \(HTTP 404\)/i],
    ] as const) {
      vi.resetModules();
      vi.doMock("@/services/supabase", () => ({
        isSupabaseConfigured: true,
        supabase: {
          functions: {
            invoke: async () => ({
              data: null,
              error: {
                context: new Response(
                  serverMsg ? JSON.stringify({ error: serverMsg }) : "",
                  { status },
                ),
              },
            }),
          },
        },
      }));

      const mod = await import("@/features/admin/services/usersService");
      await expect(
        mod.invokeInviteAdmin(
          { email: "newadmin@lus.ac.bd", name: "New Admin" },
          false,
        ),
      ).rejects.toThrow(expectedPattern);
    }
  });

  it("keeps AdminProfilePage strictly free of avatars storage uploads (F-30)", () => {
    const profilePageText = fs.readFileSync(
      path.resolve(
        __dirname,
        "../../src/features/admin/pages/AdminProfilePage.tsx",
      ),
      "utf8",
    );
    const profileServiceText = fs.readFileSync(
      path.resolve(
        __dirname,
        "../../src/features/admin/services/profileService.ts",
      ),
      "utf8",
    );

    expect(profilePageText).not.toContain('type="file"');
    expect(profileServiceText).not.toContain("avatars");

    const sanitized = toOwnProfileUpdatePayload({
      name: "  Prof. Rahman ",
      department: "CSE",
      designation: "Professor",
      teacher_code: "mhr",
    });
    expect(sanitized).toEqual({
      name: "Prof. Rahman",
      department: "CSE",
      designation: "Professor",
      teacher_code: "MHR",
    });
    expect("role" in sanitized).toBe(false);
    expect("avatar_url" in sanitized).toBe(false);
  });
});
