export interface ParsedOAuthError {
  error: string;
  errorCode: string | null;
  errorDescription: string | null;
}

export interface ParsedPkceCode {
  code: string;
  flowId: string | null;
}

export interface PkceExchangeOutcome {
  data: {
    session: {
      user: {
        id: string;
        email?: string | null;
        email_confirmed_at?: string | null;
        app_metadata?: Record<string, unknown>;
        user_metadata?: Record<string, unknown>;
      };
    } | null;
    redirectType?: string | null;
  };
  error: { message: string } | null;
}

let activePkceExchange: Promise<PkceExchangeOutcome> | null = null;

export function getInFlightPkceExchange(): Promise<PkceExchangeOutcome> | null {
  return activePkceExchange;
}

export function resetInFlightPkceExchangeForTest(): void {
  activePkceExchange = null;
}

function scrubUrlAuthParams(
  keysToDelete: readonly string[],
  scrubHash = false,
): void {
  if (typeof window === "undefined") return;
  const url = new URL(window.location.href);
  for (const key of keysToDelete) {
    url.searchParams.delete(key);
  }
  const searchStr = url.searchParams.toString();
  const nextSearch = searchStr ? `?${searchStr}` : "";
  const nextHash = scrubHash ? "" : window.location.hash;
  window.history.replaceState(
    window.history.state,
    "",
    `${url.pathname}${nextSearch}${nextHash}`,
  );
}

/**
 * Parses OAuth / GoTrue error callback parameters from either `?error=...`
 * or `#error=...`, scrubs auth callback params from browser history, and
 * returns a normalized error payload for display on `/login`.
 */
export function extractAndScrubOAuthError(): ParsedOAuthError | null {
  if (typeof window === "undefined") return null;

  const searchParams = new URLSearchParams(window.location.search);
  const rawHash = window.location.hash;
  const hashParams =
    rawHash && rawHash.startsWith("#")
      ? new URLSearchParams(rawHash.slice(1))
      : null;

  // Never interfere with a valid implicit invite token hash
  if (hashParams?.get("type") === "invite" && hashParams.get("access_token")) {
    return null;
  }

  const searchErr = searchParams.get("error")?.trim() ?? "";
  const searchErrCode = searchParams.get("error_code")?.trim() ?? "";
  const searchErrDesc = searchParams.get("error_description")?.trim() ?? "";

  const hashErr = hashParams?.get("error")?.trim() ?? "";
  const hashErrCode = hashParams?.get("error_code")?.trim() ?? "";
  const hashErrDesc = hashParams?.get("error_description")?.trim() ?? "";

  const hasSearchErr = Boolean(searchErr || searchErrCode || searchErrDesc);
  const hasHashErr = Boolean(hashErr || hashErrCode || hashErrDesc);

  if (!hasSearchErr && !hasHashErr) {
    return null;
  }

  scrubUrlAuthParams(
    ["error", "error_code", "error_description", "state", "code", "sb_flow_id"],
    hasHashErr,
  );

  const error = searchErr || hashErr || "oauth_error";
  const errorCode = searchErrCode || hashErrCode || null;
  const rawDesc = searchErrDesc || hashErrDesc || null;
  return {
    error,
    errorCode,
    errorDescription: rawDesc ? rawDesc.replace(/\+/g, " ") : null,
  };
}

/**
 * Extracts `?code=...` (and optional `sb_flow_id`) from a PKCE OAuth / recovery
 * redirect on any route and scrubs auth parameters cleanly via `replaceState`.
 */
export function extractAndScrubPkceCode(): ParsedPkceCode | null {
  if (typeof window === "undefined") return null;
  const searchParams = new URLSearchParams(window.location.search);
  const code = searchParams.get("code")?.trim() ?? "";
  if (!code) return null;

  const flowId = searchParams.get("sb_flow_id")?.trim() || null;
  scrubUrlAuthParams(["code", "state", "sb_flow_id"], false);
  return { code, flowId };
}

/**
 * Deduplicates `exchangeCodeForSession` across React 19 StrictMode double-mounts
 * so the single-use PKCE authorization code is exchanged at most once.
 */
export function exchangePkceCodeOnce(
  code: string,
  flowId: string | null,
  exchangeFn: (
    authCode: string,
    options?: { flowId?: string },
  ) => Promise<PkceExchangeOutcome>,
): Promise<PkceExchangeOutcome> {
  if (activePkceExchange) {
    return activePkceExchange;
  }

  const entry = exchangeFn(code, flowId ? { flowId } : undefined).finally(
    () => {
      if (activePkceExchange === entry) {
        activePkceExchange = null;
      }
    },
  );
  activePkceExchange = entry;
  return entry;
}
