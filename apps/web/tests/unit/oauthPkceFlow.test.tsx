import { StrictMode } from "react";
import { act, cleanup, fireEvent, render, screen, waitFor } from "@testing-library/react";
import { MemoryRouter, Navigate, Route, Routes } from "react-router-dom";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { resetInFlightPkceExchangeForTest } from "@/features/auth/oauthCallbackHelpers";

const mockState = {
  signInWithOAuth: vi.fn(),
  exchangeCodeForSession: vi.fn(),
  getSession: vi.fn(),
  onAuthStateChange: vi.fn(),
  signOut: vi.fn(),
  adoptInviteSession: vi.fn(),
  profileData: null as Record<string, unknown> | null,
};

vi.mock("@/services/supabase", () => ({
  isSupabaseConfigured: true,
  extractAndScrubInviteHash: () => {
    const rawHash = window.location.hash;
    if (!rawHash || !rawHash.startsWith("#")) return null;
    const params = new URLSearchParams(rawHash.slice(1));
    if (params.get("type") !== "invite") return null;
    window.history.replaceState(
      null,
      "",
      `${window.location.pathname}${window.location.search}`,
    );
    return {
      accessToken: params.get("access_token") ?? "",
      refreshToken: params.get("refresh_token") ?? "",
      expiresIn: Number.parseInt(params.get("expires_in") ?? "0", 10),
      tokenType: params.get("token_type") ?? "",
    };
  },
  adoptInviteSession: (...args: unknown[]) =>
    mockState.adoptInviteSession(...args),
  mapFriendlyAuthError: (raw: string) => {
    const m = raw.toLowerCase();
    if (m.includes("access_denied") || m.includes("user cancelled")) {
      return "Google sign-in was cancelled or denied. Choose an approved committee account to continue.";
    }
    return raw;
  },
  supabase: {
    auth: {
      signInWithOAuth: (...args: unknown[]) =>
        mockState.signInWithOAuth(...args),
      exchangeCodeForSession: (...args: unknown[]) =>
        mockState.exchangeCodeForSession(...args),
      getSession: (...args: unknown[]) => mockState.getSession(...args),
      onAuthStateChange: (...args: unknown[]) =>
        mockState.onAuthStateChange(...args),
      signOut: (...args: unknown[]) => mockState.signOut(...args),
    },
    from: () => ({
      select: () => ({
        eq: () => ({
          maybeSingle: async () => ({
            data: mockState.profileData,
            error: null,
          }),
        }),
      }),
    }),
  },
}));

import { AuthProvider, useAuth } from "@/features/auth/AuthProvider";
import { LoginPage } from "@/features/auth/pages/LoginPage";

beforeEach(() => {
  resetInFlightPkceExchangeForTest();
  window.history.replaceState(null, "", "/");
  mockState.profileData = null;
  mockState.signInWithOAuth.mockReset().mockResolvedValue({ error: null });
  mockState.exchangeCodeForSession.mockReset();
  mockState.getSession
    .mockReset()
    .mockResolvedValue({ data: { session: null }, error: null });
  mockState.onAuthStateChange.mockReset().mockImplementation(() => ({
    data: { subscription: { unsubscribe: vi.fn() } },
  }));
  mockState.signOut.mockReset().mockResolvedValue({});
  mockState.adoptInviteSession.mockReset();
});

afterEach(() => {
  cleanup();
  resetInFlightPkceExchangeForTest();
  window.history.replaceState(null, "", "/");
});

describe("Google OAuth PKCE flow, StrictMode deduplication & error surfacing", () => {
  it("signInWithGoogle passes exact origin redirectTo and prompt=select_account", async () => {
    let triggerGoogle: (() => Promise<{ ok: boolean; error?: string }>) | null =
      null;
    function Probe() {
      const { signInWithGoogle } = useAuth();
      triggerGoogle = signInWithGoogle;
      return null;
    }

    render(
      <AuthProvider>
        <Probe />
      </AuthProvider>,
    );

    await act(async () => {
      await triggerGoogle?.();
    });

    expect(mockState.signInWithOAuth).toHaveBeenCalledTimes(1);
    expect(mockState.signInWithOAuth).toHaveBeenCalledWith({
      provider: "google",
      options: {
        redirectTo: `${window.location.origin}/`,
        queryParams: { prompt: "select_account" },
      },
    });
  });

  it("exchanges ?code= exactly once under React StrictMode, scrubs URL, and routes whitelisted admin to /admin/dashboard", async () => {
    window.history.replaceState(
      null,
      "",
      "/?code=pkce-admin-code&state=oauth-state-1",
    );

    mockState.profileData = {
      id: "u-google-admin",
      email: "chair@lus.ac.bd",
      role: "admin",
      name: "Committee Chair",
      department: "CSE",
      teacher_code: "KJH",
    };

    mockState.exchangeCodeForSession.mockResolvedValue({
      data: {
        session: {
          user: {
            id: "u-google-admin",
            email: "chair@lus.ac.bd",
            email_confirmed_at: "2026-11-27T00:00:00Z",
            app_metadata: { provider: "google" },
          },
        },
        redirectType: null,
      },
      error: null,
    });

    function Harness() {
      const { status, isCompletingOAuth } = useAuth();
      if (isCompletingOAuth) return <div>completing</div>;
      if (status === "authenticated") {
        return <Navigate to="/admin/dashboard" replace />;
      }
      return <div>landing:{status}</div>;
    }

    render(
      <StrictMode>
        <AuthProvider>
          <MemoryRouter initialEntries={["/"]}>
            <Routes>
              <Route path="/" element={<Harness />} />
              <Route
                path="/admin/dashboard"
                element={<div data-testid="admin-dest">Dashboard</div>}
              />
            </Routes>
          </MemoryRouter>
        </AuthProvider>
      </StrictMode>,
    );

    await waitFor(() => {
      expect(screen.getByTestId("admin-dest").textContent).toBe("Dashboard");
    });

    expect(mockState.exchangeCodeForSession).toHaveBeenCalledTimes(1);
    expect(mockState.exchangeCodeForSession).toHaveBeenCalledWith(
      "pkce-admin-code",
      undefined,
    );
    expect(window.location.search).toBe("");
  });

  it("routes non-admin Google user after ?code= exchange to /access-required without loops", async () => {
    window.history.replaceState(null, "", "/?code=pkce-student-code");

    mockState.profileData = {
      id: "u-google-student",
      email: "student@lus.ac.bd",
      role: "student",
      name: "Student Account",
      department: "CSE",
      teacher_code: null,
    };

    mockState.exchangeCodeForSession.mockResolvedValue({
      data: {
        session: {
          user: {
            id: "u-google-student",
            email: "student@lus.ac.bd",
            email_confirmed_at: "2026-11-27T00:00:00Z",
            app_metadata: { provider: "google" },
          },
        },
        redirectType: null,
      },
      error: null,
    });

    function Guard() {
      const { status, isCompletingOAuth, deniedReason } = useAuth();
      if (isCompletingOAuth) return <div>completing</div>;
      if (status === "accessDenied") {
        return <Navigate to="/access-required" replace />;
      }
      return (
        <div>
          {status}:{deniedReason ?? "none"}
        </div>
      );
    }

    function AccessRequiredView() {
      const { deniedReason, deniedRole } = useAuth();
      return (
        <div data-testid="access-dest">
          {deniedReason}:{deniedRole}
        </div>
      );
    }

    render(
      <AuthProvider>
        <MemoryRouter initialEntries={["/"]}>
          <Routes>
            <Route path="/" element={<Guard />} />
            <Route path="/access-required" element={<AccessRequiredView />} />
          </Routes>
        </MemoryRouter>
      </AuthProvider>,
    );

    await waitFor(() => {
      expect(screen.getByTestId("access-dest").textContent).toBe(
        "non_admin_role:student",
      );
    });
    expect(mockState.exchangeCodeForSession).toHaveBeenCalledTimes(1);
    expect(window.location.search).toBe("");
  });

  it("surfaces ?error=access_denied and #error= callbacks on /login and scrubs error params from URL", async () => {
    function RootRedirect() {
      const { hasPendingAuthError, status } = useAuth();
      if (hasPendingAuthError && status === "unauthenticated") {
        return <Navigate to="/login" replace />;
      }
      return <div>landing</div>;
    }

    for (const badUrl of [
      "/?error=access_denied&error_description=User+cancelled+login&state=xyz",
      "/#error=server_error&error_description=Provider+rejected+request",
    ]) {
      window.history.replaceState(null, "", badUrl);

      render(
        <AuthProvider>
          <MemoryRouter initialEntries={["/"]}>
            <Routes>
              <Route path="/" element={<RootRedirect />} />
              <Route path="/login" element={<LoginPage />} />
              <Route path="/forgot-password" element={<div>forgot</div>} />
            </Routes>
          </MemoryRouter>
        </AuthProvider>,
      );

      await waitFor(() => {
        expect(screen.getByTestId("login-error-alert")).toBeTruthy();
      });
      expect(window.location.search).toBe("");
      expect(window.location.hash).toBe("");
      cleanup();
    }
  });

  it("routes implicit #access_token=...&type=invite cleanly to /reset-password without PKCE collision", async () => {
    window.history.replaceState(
      null,
      "",
      "/#access_token=inv-acc&refresh_token=inv-ref&expires_in=3600&token_type=bearer&type=invite",
    );

    mockState.adoptInviteSession.mockResolvedValue({
      userId: "u-inv",
      email: "newadmin@lus.ac.bd",
    });

    function Guard() {
      const { status } = useAuth();
      if (status === "passwordRecovery") {
        return <Navigate to="/reset-password" replace />;
      }
      return <div>{status}</div>;
    }

    render(
      <AuthProvider>
        <MemoryRouter initialEntries={["/"]}>
          <Routes>
            <Route path="/" element={<Guard />} />
            <Route
              path="/reset-password"
              element={<div data-testid="reset-dest">Reset Password</div>}
            />
          </Routes>
        </MemoryRouter>
      </AuthProvider>,
    );

    await waitFor(() => {
      expect(screen.getByTestId("reset-dest").textContent).toBe(
        "Reset Password",
      );
    });
    expect(mockState.adoptInviteSession).toHaveBeenCalledTimes(1);
    expect(window.location.hash).toBe("");
  });

  it("preserves email and password inputs when validation errors trigger form shake", async () => {
    render(
      <AuthProvider>
        <MemoryRouter initialEntries={["/login"]}>
          <Routes>
            <Route path="/login" element={<LoginPage />} />
            <Route path="/forgot-password" element={<div>forgot</div>} />
          </Routes>
        </MemoryRouter>
      </AuthProvider>,
    );

    const emailInput = screen.getByLabelText(/Email/i) as HTMLInputElement;
    const passwordInput = screen.getByLabelText(/^Password$/i) as HTMLInputElement;

    fireEvent.change(emailInput, { target: { value: "committee@lus.ac.bd" } });
    fireEvent.change(passwordInput, { target: { value: "12" } });
    fireEvent.submit(emailInput.closest("form")!);

    await waitFor(() => {
      expect(screen.getByText(/at least 6 characters/i)).toBeTruthy();
    });
    expect((screen.getByLabelText(/Email/i) as HTMLInputElement).value).toBe(
      "committee@lus.ac.bd",
    );
    expect((screen.getByLabelText(/^Password$/i) as HTMLInputElement).value).toBe("12");
  });
});
