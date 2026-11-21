import { act, cleanup, render, screen } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { AuthProvider, useAuth } from "@/features/auth/AuthProvider";
import {
  adoptInviteSession,
  extractAndScrubInviteHash,
  type ParsedInviteHash,
} from "@/services/supabase";

afterEach(cleanup);

describe("invite-admin hash bridge & adoptInviteSession hardening", () => {
  beforeEach(() => {
    window.history.replaceState(null, "", "/");
  });

  it("extracts valid invite hash tokens and scrubs hash from browser history", () => {
    window.history.replaceState(
      null,
      "",
      "/#access_token=acc123&refresh_token=ref456&expires_in=3600&token_type=bearer&type=invite",
    );

    const parsed = extractAndScrubInviteHash();
    expect(parsed).toEqual({
      accessToken: "acc123",
      refreshToken: "ref456",
      expiresIn: 3600,
      tokenType: "bearer",
    });
    expect(window.location.hash).toBe("");
  });

  it("rejects invite hash combined with query string parameters", () => {
    window.history.replaceState(
      null,
      "",
      "/?code=pkce_code#access_token=acc123&refresh_token=ref456&expires_in=3600&token_type=bearer&type=invite",
    );

    expect(() => extractAndScrubInviteHash()).toThrow(
      /query string parameters/i,
    );
    expect(window.location.hash).toBe("");
  });

  it("returns null for non-invite hash callbacks", () => {
    window.history.replaceState(null, "", "/#access_token=abc&type=recovery");
    expect(extractAndScrubInviteHash()).toBeNull();
  });

  it("rejects adoptInviteSession when query search params exist", async () => {
    const invite: ParsedInviteHash = {
      accessToken: "acc",
      refreshToken: "ref",
      expiresIn: 3600,
      tokenType: "bearer",
    };

    await expect(
      adoptInviteSession(invite, {
        search: "?code=123",
        supabaseUrl: "https://example.supabase.co",
        supabaseAnonKey: "anon",
        setSessionFn: async () => ({ error: null }),
      }),
    ).rejects.toThrow(/query string parameters/i);
  });

  it("rejects unconfirmed invited user (missing email_confirmed_at)", async () => {
    const fetchMock = vi.fn().mockResolvedValueOnce(
      new Response(
        JSON.stringify({
          id: "u-1",
          email: "admin@lus.ac.bd",
          invited_at: "2026-11-20T00:00:00Z",
          email_confirmed_at: null,
        }),
        { status: 200 },
      ),
    );

    await expect(
      adoptInviteSession(
        {
          accessToken: "acc",
          refreshToken: "ref",
          expiresIn: 3600,
          tokenType: "bearer",
        },
        {
          search: "",
          supabaseUrl: "https://example.supabase.co",
          supabaseAnonKey: "anon",
          fetchImpl: fetchMock as unknown as typeof fetch,
          setSessionFn: async () => ({ error: null }),
        },
      ),
    ).rejects.toThrow(/confirmed administrator invitation/i);
  });

  it("rejects session whose expires_at <= now + 60", async () => {
    const nowMs = 1_700_000_000_000;
    const nowSec = Math.floor(nowMs / 1000);
    const fetchMock = vi
      .fn()
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            id: "u-1",
            email: "admin@lus.ac.bd",
            invited_at: "2026-11-20T00:00:00Z",
            email_confirmed_at: "2026-11-20T00:01:00Z",
          }),
          { status: 200 },
        ),
      )
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            access_token: "fresh-acc",
            refresh_token: "fresh-ref",
            expires_at: nowSec + 45,
            user: { id: "u-1", email: "admin@lus.ac.bd" },
          }),
          { status: 200 },
        ),
      );

    await expect(
      adoptInviteSession(
        {
          accessToken: "acc",
          refreshToken: "ref",
          expiresIn: 3600,
          tokenType: "bearer",
        },
        {
          search: "",
          nowMs,
          supabaseUrl: "https://example.supabase.co",
          supabaseAnonKey: "anon",
          fetchImpl: fetchMock as unknown as typeof fetch,
          setSessionFn: async () => ({ error: null }),
        },
      ),
    ).rejects.toThrow(/expired or is too close to expiry/i);
  });

  it("adopts session when email is confirmed and expires_at > now + 60", async () => {
    const nowMs = 1_700_000_000_000;
    const nowSec = Math.floor(nowMs / 1000);
    const setSessionSpy = vi.fn().mockResolvedValue({ error: null });

    const fetchMock = vi
      .fn()
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            id: "u-1",
            email: "chair@lus.ac.bd",
            invited_at: "2026-11-20T00:00:00Z",
            email_confirmed_at: "2026-11-20T00:01:00Z",
          }),
          { status: 200 },
        ),
      )
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            access_token: "fresh-acc",
            refresh_token: "fresh-ref",
            expires_at: nowSec + 1800,
            user: { id: "u-1", email: "chair@lus.ac.bd" },
          }),
          { status: 200 },
        ),
      );

    const res = await adoptInviteSession(
      {
        accessToken: "acc",
        refreshToken: "ref",
        expiresIn: 3600,
        tokenType: "bearer",
      },
      {
        search: "",
        nowMs,
        supabaseUrl: "https://example.supabase.co",
        supabaseAnonKey: "anon",
        fetchImpl: fetchMock as unknown as typeof fetch,
        setSessionFn: setSessionSpy,
      },
    );

    expect(res).toEqual({ userId: "u-1", email: "chair@lus.ac.bd" });
    expect(setSessionSpy).toHaveBeenCalledWith({
      access_token: "fresh-acc",
      refresh_token: "fresh-ref",
    });
  });
});

describe("AuthProvider statusRef closure guard against SIGNED_IN during passwordRecovery", () => {
  it("preserves passwordRecovery when Supabase emits SIGNED_IN inside the same subscription", async () => {
    vi.resetModules();

    let authCallback:
      | ((event: string, session: { user: { id: string; email: string } } | null) => void)
      | null = null;
    const profileQuerySpy = vi.fn();

    vi.doMock("@/services/supabase", () => ({
      isSupabaseConfigured: true,
      extractAndScrubInviteHash: () => null,
      adoptInviteSession: vi.fn(),
      mapFriendlyAuthError: (m: string) => m,
      supabase: {
        auth: {
          getSession: vi.fn().mockResolvedValue({
            data: { session: null },
            error: null,
          }),
          onAuthStateChange: vi.fn((cb) => {
            authCallback = cb;
            return { data: { subscription: { unsubscribe: vi.fn() } } };
          }),
          signOut: vi.fn().mockResolvedValue({}),
        },
        from: (...args: unknown[]) => {
          profileQuerySpy(...args);
          return {
            select: () => ({
              eq: () => ({
                maybeSingle: async () => ({ data: null, error: null }),
              }),
            }),
          };
        },
      },
    }));

    const mod = await import("@/features/auth/AuthProvider");

    function Probe() {
      const { status } = mod.useAuth();
      return <span data-testid="auth-status">{status}</span>;
    }

    render(
      <mod.AuthProvider>
        <Probe />
      </mod.AuthProvider>,
    );

    await act(async () => {
      await Promise.resolve();
    });

    expect(authCallback).not.toBeNull();

    await act(async () => {
      authCallback?.("PASSWORD_RECOVERY", {
        user: { id: "u-rec", email: "chair@lus.ac.bd" },
      });
      // Immediately follow with SIGNED_IN inside same closure instance
      authCallback?.("SIGNED_IN", {
        user: { id: "u-rec", email: "chair@lus.ac.bd" },
      });
    });

    expect(screen.getByTestId("auth-status").textContent).toBe("passwordRecovery");
    expect(profileQuerySpy).not.toHaveBeenCalled();

    vi.doUnmock("@/services/supabase");
  });

  it("requires AuthProvider wrapper around useAuth", () => {
    function BrokenConsumer() {
      useAuth();
      return null;
    }
    expect(() => render(<BrokenConsumer />)).toThrow(
      /must be used within AuthProvider/i,
    );
  });
});
