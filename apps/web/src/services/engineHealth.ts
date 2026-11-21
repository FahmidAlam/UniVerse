export interface EngineHealthSnapshot {
  status: "online" | "cold-start" | "unavailable";
  service: string | null;
  version: string | null;
  latencyMs: number | null;
  checkedAt: string;
  baseUrl: string;
  detail: string;
}

const DEFAULT_ENGINE_URL = "https://universe-timetable-engine.onrender.com";

export function getEngineBaseUrl(): string {
  const envUrl = import.meta.env.VITE_TIMETABLE_BASE_URL?.trim();
  const raw = envUrl && envUrl.length > 0 ? envUrl : DEFAULT_ENGINE_URL;
  return raw.replace(/\/+$/, "");
}

/**
 * Polls the Python FastAPI CP-SAT engine root endpoint (`GET /` — NOT `/health`).
 * Exact contract: 200 OK `{ service: "universe-timetable-engine", version: "2.0.0", ok: true }`, 5s timeout.
 */
export async function checkEngineHealth(): Promise<EngineHealthSnapshot> {
  const baseUrl = getEngineBaseUrl();
  const started = performance.now();
  const checkedAt = new Date().toISOString();

  const controller = new AbortController();
  const timeoutId = window.setTimeout(() => controller.abort(), 5000);

  try {
    const res = await fetch(`${baseUrl}/`, {
      method: "GET",
      signal: controller.signal,
      headers: { Accept: "application/json" },
    });

    const latencyMs = Math.round(performance.now() - started);

    if (!res.ok) {
      return {
        status: res.status === 502 || res.status === 503 ? "cold-start" : "unavailable",
        service: null,
        version: null,
        latencyMs,
        checkedAt,
        baseUrl,
        detail: `HTTP ${res.status} from engine root`,
      };
    }

    const body = (await res.json()) as {
      ok?: unknown;
      service?: unknown;
      version?: unknown;
    };

    if (body.ok === true && body.service === "universe-timetable-engine") {
      return {
        status: "online",
        service: String(body.service),
        version: typeof body.version === "string" ? body.version : "2.0.0",
        latencyMs,
        checkedAt,
        baseUrl,
        detail: "CP-SAT engine ready",
      };
    }

    return {
      status: "unavailable",
      service: typeof body.service === "string" ? body.service : null,
      version: null,
      latencyMs,
      checkedAt,
      baseUrl,
      detail: "Unexpected root payload",
    };
  } catch (err) {
    const latencyMs = Math.round(performance.now() - started);
    const isAbort = err instanceof DOMException && err.name === "AbortError";
    return {
      status: isAbort ? "cold-start" : "unavailable",
      service: null,
      version: null,
      latencyMs,
      checkedAt,
      baseUrl,
      detail: isAbort
        ? "Timed out after 5s (Render free-tier spin-up)"
        : "Engine unreachable from browser",
    };
  } finally {
    window.clearTimeout(timeoutId);
  }
}
