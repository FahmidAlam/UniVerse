import { createClient, type SupabaseClient } from "@supabase/supabase-js";

const SUPABASE_URL = import.meta.env.VITE_SUPABASE_URL?.trim() ?? "";
const SUPABASE_ANON_KEY = import.meta.env.VITE_SUPABASE_ANON_KEY?.trim() ?? "";

export const isSupabaseConfigured =
  SUPABASE_URL.length > 0 && SUPABASE_ANON_KEY.length > 0;

export const supabase: SupabaseClient | null = isSupabaseConfigured
  ? createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      auth: {
        flowType: "pkce",
        detectSessionInUrl: true,
        autoRefreshToken: true,
        persistSession: true,
      },
    })
  : null;

export interface ParsedInviteHash {
  accessToken: string;
  refreshToken: string;
  expiresIn: number;
  tokenType: string;
}

export interface AdoptInviteDeps {
  supabaseUrl?: string;
  supabaseAnonKey?: string;
  search?: string;
  nowMs?: number;
  fetchImpl?: typeof fetch;
  setSessionFn?: (tokens: {
    access_token: string;
    refresh_token: string;
  }) => Promise<{ error: { message: string } | null }>;
}

/**
 * Detects and immediately scrubs server-side `invite-admin` implicit hash tokens
 * (`#access_token=...&refresh_token=...&expires_in=...&token_type=bearer&type=invite`)
 * BEFORE router redirects settle so credentials never linger in browser history.
 */
export function extractAndScrubInviteHash(): ParsedInviteHash | null {
  if (typeof window === "undefined") return null;
  const rawHash = window.location.hash;
  if (!rawHash || !rawHash.startsWith("#")) return null;

  const params = new URLSearchParams(rawHash.slice(1));
  if (params.get("type") !== "invite") return null;

  const accessToken = params.get("access_token")?.trim() ?? "";
  const refreshToken = params.get("refresh_token")?.trim() ?? "";
  const tokenType = params.get("token_type")?.trim().toLowerCase() ?? "";
  const expiresIn = Number.parseInt(params.get("expires_in") ?? "0", 10);

  // Immediately scrub hash credentials while keeping pathname/search intact for URL validation
  window.history.replaceState(
    null,
    "",
    `${window.location.pathname}${window.location.search}`,
  );

  if (window.location.search.length > 0) {
    throw new Error("Invitation links cannot contain query string parameters.");
  }

  if (
    !accessToken ||
    !refreshToken ||
    tokenType !== "bearer" ||
    !Number.isFinite(expiresIn) ||
    expiresIn <= 0
  ) {
    throw new Error("Invitation link is incomplete or malformed.");
  }

  return { accessToken, refreshToken, expiresIn, tokenType };
}

/**
 * Verifies an implicit invite token against GoTrue `/auth/v1/user`
 * (requiring `id`, `invited_at`, and confirmed email), exchanges the refresh token,
 * verifies `expires_at > now + 60`, and adopts the session into the PKCE client.
 */
export async function adoptInviteSession(
  invite: ParsedInviteHash,
  deps?: AdoptInviteDeps,
): Promise<{ userId: string; email: string | null }> {
  const search =
    deps?.search ??
    (typeof window !== "undefined" ? window.location.search : "");
  if (search.length > 0) {
    throw new Error("Invitation links cannot contain query string parameters.");
  }

  const baseUrl = deps?.supabaseUrl ?? SUPABASE_URL;
  const anonKey = deps?.supabaseAnonKey ?? SUPABASE_ANON_KEY;
  const fetchFn = deps?.fetchImpl ?? fetch;
  const setSessionFn =
    deps?.setSessionFn ??
    (supabase ? (tokens) => supabase!.auth.setSession(tokens) : undefined);

  if (!baseUrl || !anonKey || !setSessionFn) {
    throw new Error("Authentication service is not configured.");
  }

  // 1. Verify invited user directly against GoTrue
  const userResp = await fetchFn(`${baseUrl}/auth/v1/user`, {
    method: "GET",
    headers: {
      apikey: anonKey,
      Authorization: `Bearer ${invite.accessToken}`,
    },
  });

  if (!userResp.ok) {
    throw new Error("Invitation token could not be verified or has expired.");
  }

  const verifiedUser = (await userResp.json()) as {
    id?: string;
    email?: string | null;
    invited_at?: string | null;
    email_confirmed_at?: string | null;
  };

  if (
    !verifiedUser.id ||
    !verifiedUser.invited_at ||
    !verifiedUser.email_confirmed_at
  ) {
    throw new Error(
      "This callback does not belong to a confirmed administrator invitation.",
    );
  }

  // 2. Exchange refresh token for a fresh session
  const tokenResp = await fetchFn(
    `${baseUrl}/auth/v1/token?grant_type=refresh_token`,
    {
      method: "POST",
      headers: {
        apikey: anonKey,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ refresh_token: invite.refreshToken }),
    },
  );

  if (!tokenResp.ok) {
    throw new Error("Failed to establish invitation recovery session.");
  }

  const sessionData = (await tokenResp.json()) as {
    access_token?: string;
    refresh_token?: string;
    expires_at?: number;
    expires_in?: number;
    user?: { id?: string; email?: string | null };
  };

  if (
    !sessionData.access_token ||
    !sessionData.refresh_token ||
    sessionData.user?.id !== verifiedUser.id
  ) {
    throw new Error("Invitation session user mismatch.");
  }

  const nowSeconds = Math.floor((deps?.nowMs ?? Date.now()) / 1000);
  const expiresAt =
    typeof sessionData.expires_at === "number"
      ? sessionData.expires_at
      : typeof sessionData.expires_in === "number"
        ? nowSeconds + sessionData.expires_in
        : 0;

  if (!Number.isFinite(expiresAt) || expiresAt <= nowSeconds + 60) {
    throw new Error(
      "Invitation session has expired or is too close to expiry. Request a fresh link.",
    );
  }

  // 3. Adopt verified session into primary Supabase client
  const { error } = await setSessionFn({
    access_token: sessionData.access_token,
    refresh_token: sessionData.refresh_token,
  });

  if (error) {
    throw new Error(error.message);
  }

  return {
    userId: verifiedUser.id,
    email: verifiedUser.email ?? sessionData.user?.email ?? null,
  };
}

export function mapFriendlyAuthError(rawMessage: string): string {
  const m = rawMessage.toLowerCase();
  if (
    m.includes("invalid login credentials") ||
    m.includes("invalid email or password")
  ) {
    return "Incorrect email or password. Please verify your credentials and try again.";
  }
  if (m.includes("email not confirmed")) {
    return "Please verify your email address before signing in.";
  }
  if (m.includes("password should be at least")) {
    return "Password does not meet minimum length requirements.";
  }
  if (m.includes("rate limit")) {
    return "Too many sign-in attempts. Wait a few minutes before retrying.";
  }
  if (m.includes("network") || m.includes("fetch") || m.includes("connection")) {
    return "Unable to reach authentication service. Check your connection and try again.";
  }
  return rawMessage || "Sign-in failed. Please try again.";
}
