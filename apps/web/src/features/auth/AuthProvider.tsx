import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
  type ReactNode,
} from "react";
import type { User } from "@supabase/supabase-js";
import {
  adoptInviteSession,
  extractAndScrubInviteHash,
  isSupabaseConfigured,
  mapFriendlyAuthError,
  supabase,
} from "@/services/supabase";

export type AuthStatus =
  | "loading"
  | "unauthenticated"
  | "authenticated"
  | "passwordRecovery"
  | "accessDenied"
  | "error";

export type AccessDeniedReason = "non_admin_role" | "not_whitelisted";

export interface AdminProfile {
  id: string;
  email: string;
  role: string;
  name: string;
  department?: string | null;
  teacher_code?: string | null;
}

interface AuthContextValue {
  status: AuthStatus;
  profile: AdminProfile | null;
  isDevPreview: boolean;
  canUseDevPreview: boolean;
  deniedReason: AccessDeniedReason | null;
  deniedRole: string | null;
  authError: string | null;
  recoveryExpiresAt: number | null;
  signInWithEmail: (
    email: string,
    password: string,
  ) => Promise<{ ok: boolean; error?: string }>;
  signInWithGoogle: () => Promise<{ ok: boolean; error?: string }>;
  sendPasswordReset: (
    email: string,
  ) => Promise<{ ok: boolean; error?: string }>;
  updateRecoveryPassword: (
    password: string,
  ) => Promise<{ ok: boolean; error?: string }>;
  signOut: () => Promise<void>;
  enterDevPreview: () => void;
  exitDevPreview: () => void;
}

const RECOVERY_TTL_MS = 10 * 60 * 1000;
export const DEV_PREVIEW_STORAGE_KEY = "universe-web-dev-preview";

const DEV_PREVIEW_PROFILE: AdminProfile = {
  id: "dev-preview-admin",
  email: "committee.cse@lus.ac.bd",
  role: "admin",
  name: "KJH · Routine Committee Chair",
  department: "CSE",
  teacher_code: "KJH",
};

const AuthContext = createContext<AuthContextValue | null>(null);

function isNotWhitelistedError(err: unknown): boolean {
  if (!err || typeof err !== "object") return false;
  const rec = err as { hint?: string; code?: string; message?: string };
  return (
    rec.hint === "not_whitelisted" ||
    rec.code === "42501" ||
    (rec.message?.toLowerCase().includes("not_whitelisted") ?? false)
  );
}

function isDuplicateProfileError(err: unknown): boolean {
  if (!err || typeof err !== "object") return false;
  const rec = err as { code?: string; status?: number; message?: string };
  return (
    rec.code === "23505" ||
    rec.status === 409 ||
    (rec.message?.toLowerCase().includes("duplicate key") ?? false)
  );
}

function readInitialDevPreviewFlag(canUse: boolean): boolean {
  if (!canUse || typeof window === "undefined") return false;
  try {
    const params = new URLSearchParams(window.location.search);
    if (params.get("preview") === "admin") {
      window.sessionStorage.setItem(DEV_PREVIEW_STORAGE_KEY, "1");
      return true;
    }
    return window.sessionStorage.getItem(DEV_PREVIEW_STORAGE_KEY) === "1";
  } catch {
    return false;
  }
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const canUseDevPreview = import.meta.env.DEV && !isSupabaseConfigured;
  const initialPreview = readInitialDevPreviewFlag(canUseDevPreview);

  const initialStatus: AuthStatus = initialPreview
    ? "authenticated"
    : isSupabaseConfigured
      ? "loading"
      : "unauthenticated";

  const [status, setStatus] = useState<AuthStatus>(initialStatus);
  const statusRef = useRef<AuthStatus>(initialStatus);

  const updateStatus = useCallback((next: AuthStatus) => {
    statusRef.current = next;
    setStatus(next);
  }, []);

  const [isDevPreview, setIsDevPreview] = useState<boolean>(initialPreview);
  const [profile, setProfile] = useState<AdminProfile | null>(
    initialPreview ? DEV_PREVIEW_PROFILE : null,
  );
  const [deniedReason, setDeniedReason] = useState<AccessDeniedReason | null>(
    null,
  );
  const [deniedRole, setDeniedRole] = useState<string | null>(null);
  const [authError, setAuthError] = useState<string | null>(null);
  const [recoveryExpiresAt, setRecoveryExpiresAt] = useState<number | null>(
    null,
  );

  const recoveryTimerRef = useRef<number | null>(null);
  const inFlightGateRef = useRef<Map<string, Promise<void>>>(new Map());

  const clearRecoveryTimer = useCallback(() => {
    if (recoveryTimerRef.current) {
      window.clearTimeout(recoveryTimerRef.current);
      recoveryTimerRef.current = null;
    }
    setRecoveryExpiresAt(null);
  }, []);

  const startRecoveryWindow = useCallback(() => {
    clearRecoveryTimer();
    const expires = Date.now() + RECOVERY_TTL_MS;
    setRecoveryExpiresAt(expires);
    updateStatus("passwordRecovery");
    recoveryTimerRef.current = window.setTimeout(() => {
      void supabase?.auth.signOut();
      updateStatus("unauthenticated");
      setRecoveryExpiresAt(null);
      setAuthError(
        "Password setup window expired after 10 minutes. Request a new recovery link.",
      );
    }, RECOVERY_TTL_MS);
  }, [clearRecoveryTimer, updateStatus]);

  const resolveAdminGate = useCallback(
    (user: User): Promise<void> => {
      if (!supabase) {
        updateStatus("unauthenticated");
        return Promise.resolve();
      }

      const existing = inFlightGateRef.current.get(user.id);
      if (existing) return existing;

      const task = (async () => {
        setDeniedReason(null);
        setDeniedRole(null);
        setAuthError(null);

        try {
          const { data: existingProfile, error: profErr } = await supabase!
            .from("profiles")
            .select("id, email, role, name, department, teacher_code")
            .eq("id", user.id)
            .maybeSingle();

          if (profErr) throw profErr;

          if (existingProfile) {
            if (existingProfile.role === "admin") {
              setProfile(existingProfile as AdminProfile);
              updateStatus("authenticated");
              return;
            }
            setProfile(existingProfile as AdminProfile);
            setDeniedReason("non_admin_role");
            setDeniedRole(String(existingProfile.role ?? "member"));
            updateStatus("accessDenied");
            return;
          }

          const emailLower = (user.email ?? "").trim().toLowerCase();
          if (!emailLower) {
            setDeniedReason("not_whitelisted");
            updateStatus("accessDenied");
            return;
          }

          const { data: wlRow, error: wlErr } = await supabase!
            .from("whitelists")
            .select("email, role, name, department, teacher_code, designation")
            .ilike("email", emailLower)
            .eq("role", "admin")
            .maybeSingle();

          if (wlErr) throw wlErr;

          if (!wlRow) {
            setDeniedReason("not_whitelisted");
            updateStatus("accessDenied");
            return;
          }

          const fullName =
            (typeof wlRow.name === "string" && wlRow.name.trim()) ||
            (typeof user.user_metadata?.full_name === "string" &&
              user.user_metadata.full_name.trim()) ||
            emailLower.split("@")[0] ||
            "Administrator";

          const { data: inserted, error: insertErr } = await supabase!
            .from("profiles")
            .insert({
              id: user.id,
              email: emailLower,
              role: "admin",
              name: fullName,
              department: wlRow.department ?? "CSE",
              teacher_code: wlRow.teacher_code ?? null,
              designation: wlRow.designation ?? null,
              courses: [],
            })
            .select("id, email, role, name, department, teacher_code")
            .single();

          if (insertErr) {
            if (isNotWhitelistedError(insertErr)) {
              setDeniedReason("not_whitelisted");
              updateStatus("accessDenied");
              return;
            }
            if (isDuplicateProfileError(insertErr)) {
              const { data: recoveredProfile, error: recoveryErr } =
                await supabase!
                  .from("profiles")
                  .select("id, email, role, name, department, teacher_code")
                  .eq("id", user.id)
                  .maybeSingle();
              if (recoveryErr) throw recoveryErr;
              if (recoveredProfile) {
                if (recoveredProfile.role === "admin") {
                  setProfile(recoveredProfile as AdminProfile);
                  updateStatus("authenticated");
                  return;
                }
                setProfile(recoveredProfile as AdminProfile);
                setDeniedReason("non_admin_role");
                setDeniedRole(String(recoveredProfile.role ?? "member"));
                updateStatus("accessDenied");
                return;
              }
            }
            throw insertErr;
          }

          setProfile(inserted as AdminProfile);
          updateStatus("authenticated");
        } catch (err) {
          if (isNotWhitelistedError(err)) {
            setDeniedReason("not_whitelisted");
            updateStatus("accessDenied");
            return;
          }
          setAuthError(
            err instanceof Error
              ? err.message
              : "Unable to verify administrator authorization.",
          );
          updateStatus("error");
        }
      })().finally(() => {
        inFlightGateRef.current.delete(user.id);
      });

      inFlightGateRef.current.set(user.id, task);
      return task;
    },
    [updateStatus],
  );

  // Bootstrap invite-admin implicit hash bridge + PKCE session hydration
  useEffect(() => {
    if (!supabase || !isSupabaseConfigured) return;

    let cancelled = false;

    async function bootstrap() {
      try {
        const invite = extractAndScrubInviteHash();
        if (invite) {
          await adoptInviteSession(invite);
          if (!cancelled) startRecoveryWindow();
          return;
        }
      } catch (err) {
        if (!cancelled) {
          setAuthError(
            err instanceof Error ? err.message : "Invalid invitation callback.",
          );
          updateStatus("unauthenticated");
        }
        return;
      }

      const {
        data: { session },
        error,
      } = await supabase!.auth.getSession();

      if (cancelled || statusRef.current === "passwordRecovery") return;
      if (error || !session?.user) {
        updateStatus("unauthenticated");
        return;
      }

      await resolveAdminGate(session.user);
    }

    void bootstrap();

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((event, session) => {
      if (event === "PASSWORD_RECOVERY") {
        startRecoveryWindow();
        return;
      }
      if (event === "SIGNED_OUT" || !session?.user) {
        clearRecoveryTimer();
        setProfile(null);
        setDeniedReason(null);
        setDeniedRole(null);
        updateStatus("unauthenticated");
        return;
      }
      // Reads statusRef.current so stale closure values never override passwordRecovery state
      if (event === "SIGNED_IN" && statusRef.current !== "passwordRecovery") {
        void resolveAdminGate(session.user);
      }
    });

    return () => {
      cancelled = true;
      subscription.unsubscribe();
      clearRecoveryTimer();
    };
  }, [clearRecoveryTimer, resolveAdminGate, startRecoveryWindow, updateStatus]);

  const signInWithEmail = useCallback(
    async (email: string, password: string) => {
      if (!supabase || !isSupabaseConfigured) {
        return {
          ok: false,
          error: "Authentication service is not configured for this build.",
        };
      }

      const { data, error } = await supabase.auth.signInWithPassword({
        email: email.trim().toLowerCase(),
        password,
      });

      if (error || !data.user) {
        return {
          ok: false,
          error: mapFriendlyAuthError(error?.message ?? "Sign in failed."),
        };
      }

      if (!data.user.email_confirmed_at) {
        await supabase.auth.signOut();
        return {
          ok: false,
          error: "Please verify your email address before signing in.",
        };
      }

      await resolveAdminGate(data.user);
      return { ok: true };
    },
    [resolveAdminGate],
  );

  const signInWithGoogle = useCallback(async () => {
    if (!supabase || !isSupabaseConfigured) {
      return {
        ok: false,
        error: "Authentication service is not configured for this build.",
      };
    }

    const redirectTo = `${window.location.origin}/`;
    const { error } = await supabase.auth.signInWithOAuth({
      provider: "google",
      options: { redirectTo },
    });

    if (error) {
      return { ok: false, error: mapFriendlyAuthError(error.message) };
    }
    return { ok: true };
  }, []);

  const sendPasswordReset = useCallback(async (email: string) => {
    if (!supabase || !isSupabaseConfigured) {
      return {
        ok: false,
        error: "Authentication service is not configured for this build.",
      };
    }

    const { error } = await supabase.auth.resetPasswordForEmail(
      email.trim().toLowerCase(),
      { redirectTo: `${window.location.origin}/` },
    );

    if (error) {
      return { ok: false, error: mapFriendlyAuthError(error.message) };
    }
    return { ok: true };
  }, []);

  const updateRecoveryPassword = useCallback(
    async (password: string) => {
      if (!supabase || !isSupabaseConfigured) {
        return {
          ok: false,
          error: "Authentication service is not configured for this build.",
        };
      }
      if (password.length < 8) {
        return {
          ok: false,
          error: "Password must be at least 8 characters.",
        };
      }

      const { error } = await supabase.auth.updateUser({ password });
      if (error) {
        return { ok: false, error: mapFriendlyAuthError(error.message) };
      }

      clearRecoveryTimer();
      return { ok: true };
    },
    [clearRecoveryTimer],
  );

  const signOut = useCallback(async () => {
    clearRecoveryTimer();
    setIsDevPreview(false);
    try {
      window.sessionStorage.removeItem(DEV_PREVIEW_STORAGE_KEY);
    } catch {
      // ignore storage errors
    }
    if (supabase) {
      await supabase.auth.signOut();
    }
    setProfile(null);
    setDeniedReason(null);
    setDeniedRole(null);
    setAuthError(null);
    updateStatus("unauthenticated");
  }, [clearRecoveryTimer, updateStatus]);

  const enterDevPreview = useCallback(() => {
    if (!canUseDevPreview) return;
    try {
      window.sessionStorage.setItem(DEV_PREVIEW_STORAGE_KEY, "1");
    } catch {
      // ignore storage errors
    }
    setIsDevPreview(true);
    setProfile(DEV_PREVIEW_PROFILE);
    updateStatus("authenticated");
  }, [canUseDevPreview, updateStatus]);

  const exitDevPreview = useCallback(() => {
    void signOut();
  }, [signOut]);

  const value = useMemo<AuthContextValue>(
    () => ({
      status,
      profile,
      isDevPreview,
      canUseDevPreview,
      deniedReason,
      deniedRole,
      authError,
      recoveryExpiresAt,
      signInWithEmail,
      signInWithGoogle,
      sendPasswordReset,
      updateRecoveryPassword,
      signOut,
      enterDevPreview,
      exitDevPreview,
    }),
    [
      status,
      profile,
      isDevPreview,
      canUseDevPreview,
      deniedReason,
      deniedRole,
      authError,
      recoveryExpiresAt,
      signInWithEmail,
      signInWithGoogle,
      sendPasswordReset,
      updateRecoveryPassword,
      signOut,
      enterDevPreview,
      exitDevPreview,
    ],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth(): AuthContextValue {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth must be used within AuthProvider");
  return ctx;
}
