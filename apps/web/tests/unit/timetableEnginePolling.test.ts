import { afterEach, describe, expect, it, vi } from "vitest";
import {
  EngineJobError,
  runResilientJobPolling,
  submitGenerationJob,
} from "@/features/routine/services/timetableEngineService";
import type { EngineResultResponse } from "@/features/routine/types";

const SAMPLE_RESULT: EngineResultResponse = {
  job_id: "job-abc123",
  rows: [
    {
      id: "gen-0",
      day: "Sunday",
      period: 1,
      time_start: "08:50",
      time_end: "10:05",
      subject: "Database Systems",
      subject_code: "CSE-3101",
      teacher_name: "Md. Ebrahim Hossain",
      teacher_code: "EBH",
      room: "RAB-302",
      batch: "58",
      section: "B+C",
      semester: 6,
      is_active: true,
      is_service: false,
      teachers: ["EBH"],
    },
  ],
  service_rows: [
    {
      id: "gen-1",
      day: "Sunday",
      period: 2,
      time_start: "10:10",
      time_end: "11:25",
      subject: "Physics",
      subject_code: "PHY-1101",
      teacher_name: "Md. Rashidul Hasan",
      teacher_code: "MRH",
      room: "RAB-106",
      batch: "61",
      section: "A",
      semester: 1,
      is_active: true,
      is_service: true,
      teachers: ["MRH"],
    },
  ],
  stats: {
    status: "OPTIMAL",
    solve_ms: 1200,
    meetings: 1,
    service_meetings: 1,
    offerings: 2,
    cohorts: 2,
    teachers: 2,
    objective: 10,
    lab_theory_pairs: 0,
    lab_theory_adjacent: 0,
  },
  validation: { ok: true },
  source_contract: {
    source_sha256: "abc",
    revision: 0,
    invalidated_artifacts: [],
  },
  report: {
    source_contract: {
      source_sha256: "abc",
      revision: 0,
      invalidated_artifacts: [],
    },
    cohorts: ["58-B+C", "61-A"],
    meta: {},
    excluded: [],
    warnings: [],
    offerings: [],
  },
  has_workbook: true,
};

afterEach(() => {
  vi.restoreAllMocks();
  vi.doUnmock("@/services/supabase");
});

describe("Timetable Engine HTTP Polling & 3-Step Guarded Publication Pipeline", () => {
  it("submits multipart/form-data to POST /api/timetable/generate without Authorization headers", async () => {
    const fetchSpy = vi.fn().mockResolvedValue(
      new Response(JSON.stringify({ job_id: "job-abc123" }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      }),
    );
    vi.stubGlobal("fetch", fetchSpy);

    const file = new Blob(["xlsx-bytes"], {
      type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    });
    const res = await submitGenerationJob({
      file,
      configJson: JSON.stringify({ rooms: [] }),
    });

    expect(res.job_id).toBe("job-abc123");
    const [url, init] = fetchSpy.mock.calls[0]!;
    expect(url).toContain("/api/timetable/generate");
    expect((init as RequestInit).method).toBe("POST");
    expect((init as RequestInit).headers).toBeUndefined();
    const body = (init as RequestInit).body as FormData;
    expect(body.get("time_limit_s")).toBe("180");
    expect(body.get("config")).toBe('{"rooms":[]}');
  });

  it("backs off +4000ms on 429 without incrementing consecutive error counter, and fails on 5th consecutive non-429 error", async () => {
    const sleepCalls: number[] = [];
    const sleepFn = async (ms: number) => {
      sleepCalls.push(ms);
    };

    // 6 consecutive 429s must NOT trip the 5-error limit, then done succeeds
    let callNum = 0;
    const fetch429 = vi.fn().mockImplementation(async (url: string) => {
      if (url.includes("/result/")) {
        return new Response(JSON.stringify(SAMPLE_RESULT), { status: 200 });
      }
      callNum += 1;
      if (callNum <= 6) {
        return new Response("Too Many Requests", { status: 429 });
      }
      return new Response(
        JSON.stringify({ job_id: "job-abc123", state: "done", progress: 1 }),
        { status: 200 },
      );
    });
    vi.stubGlobal("fetch", fetch429);

    const result = await runResilientJobPolling({
      jobId: "job-abc123",
      sleepFn,
      pollIntervalMs: 2000,
      backoffMs: 4000,
    });
    expect(result.rows).toHaveLength(1);
    expect(sleepCalls.filter((ms) => ms === 4000)).toHaveLength(6);

    // 5 consecutive 500 errors -> throws on 5th
    const fetch500 = vi
      .fn()
      .mockImplementation(async () => new Response("Server Error", { status: 500 }));
    vi.stubGlobal("fetch", fetch500);

    await expect(
      runResilientJobPolling({
        jobId: "job-abc123",
        sleepFn,
        pollIntervalMs: 10,
      }),
    ).rejects.toThrow(/500/);
    expect(fetch500).toHaveBeenCalledTimes(5);
  });

  it("classifies 404 Unknown job_id immediately as EngineJobError('engine-restart')", async () => {
    const fetch404 = vi.fn().mockResolvedValue(
      new Response(JSON.stringify({ detail: "Unknown job_id." }), {
        status: 404,
      }),
    );
    vi.stubGlobal("fetch", fetch404);

    let caught: unknown;
    try {
      await runResilientJobPolling({
        jobId: "lost-job",
        sleepFn: async () => {},
      });
    } catch (err) {
      caught = err;
    }

    expect(caught).toBeInstanceOf(EngineJobError);
    expect((caught as EngineJobError).kind).toBe("engine-restart");
    expect(fetch404).toHaveBeenCalledTimes(1);
  });

  it("executes 3-step publication pipeline and recovers gracefully when Step 3 audit insert fails", async () => {
    vi.resetModules();

    const uploadSpy = vi.fn().mockResolvedValue({ error: null });
    const rpcSpy = vi.fn().mockResolvedValue({
      data: { version_id: "ver-99", row_count: 2 },
      error: null,
    });
    const insertRunSpy = vi.fn().mockResolvedValue({
      error: { message: "timetable_runs RLS permission denied" },
    });

    vi.doMock("@/services/supabase", () => ({
      isSupabaseConfigured: true,
      supabase: {
        storage: {
          from: (bucket: string) => {
            expect(bucket).toBe("timetables");
            return { upload: uploadSpy };
          },
        },
        rpc: rpcSpy,
        from: (table: string) => {
          expect(table).toBe("timetable_runs");
          return { insert: insertRunSpy };
        },
      },
    }));

    const mod = await import(
      "@/features/routine/services/timetableEngineService"
    );

    const outcome = await mod.publishRoutinePipeline({
      jobId: "job-abc123",
      result: SAMPLE_RESULT,
      workbookBlob: new Blob(["xlsx"]),
      semesterLabel: "Spring 2026",
      notes: "Approved by committee",
      notifyUsers: false,
      baselineCounts: {
        rooms: 30,
        activeRooms: 28,
        faculty: 40,
        activeFaculty: 38,
        eligibility: 120,
        hasSettings: true,
      },
      isPrivatePreview: false,
      createdBy: "admin-1",
      isDevPreview: false,
    });

    expect(uploadSpy).toHaveBeenCalledTimes(1);
    expect(uploadSpy.mock.calls[0]?.[0]).toMatch(
      /^CSE_Routine_Spring_2026_\d+\.xlsx$/,
    );

    expect(rpcSpy).toHaveBeenCalledWith("publish_routine", {
      p_rows: expect.arrayContaining([
        expect.objectContaining({
          subject_code: "CSE-3101",
          time_start: "08:50:00",
          time_end: "10:05:00",
          is_service: false,
        }),
        expect.objectContaining({
          subject_code: "PHY-1101",
          time_start: "10:10:00",
          time_end: "11:25:00",
          is_service: true,
        }),
      ]),
      p_semester_label: "Spring 2026",
      p_source: "engine",
      p_stats: SAMPLE_RESULT.stats,
      p_validation: SAMPLE_RESULT.validation,
      p_notes: "Approved by committee",
    });

    // Service Recovery Paradox: Step 2 succeeded, Step 3 failed -> returns published: true + retryAuditParams
    expect(outcome.published).toBe(true);
    expect(outcome.versionId).toBe("ver-99");
    expect(outcome.rowCount).toBe(2);
    expect(outcome.secondaryAuditError).toContain("timetable_runs");
    expect(outcome.retryAuditParams).not.toBeNull();
  });

  it("attaches Authorization Bearer token when Supabase session exists and fails fast on 401/403", async () => {
    vi.resetModules();

    vi.doMock("@/services/supabase", () => ({
      isSupabaseConfigured: true,
      supabase: {
        auth: {
          getSession: vi.fn().mockResolvedValue({
            data: { session: { access_token: "web-admin-jwt-xyz" } },
          }),
        },
      },
    }));

    const recorded: Array<{ url: string; headers: HeadersInit | undefined }> = [];
    const fetchSpy = vi.fn().mockImplementation(async (url: string, init?: RequestInit) => {
      recorded.push({ url, headers: init?.headers });
      if (url.includes("/generate")) {
        return new Response(JSON.stringify({ job_id: "job-auth-1" }), { status: 200 });
      }
      if (url.includes("/status/")) {
        return new Response(
          JSON.stringify({ job_id: "job-auth-1", state: "done", progress: 1 }),
          { status: 200 },
        );
      }
      if (url.includes("/result/")) {
        return new Response(JSON.stringify(SAMPLE_RESULT), { status: 200 });
      }
      if (url.includes("/download/")) {
        return new Response(new Uint8Array([0x50, 0x4b]), { status: 200 });
      }
      return new Response("Not found", { status: 404 });
    });
    vi.stubGlobal("fetch", fetchSpy);

    const mod = await import(
      "@/features/routine/services/timetableEngineService"
    );

    await mod.submitGenerationJob({
      file: new Blob(["xlsx"]),
      configJson: "{}",
    });
    await mod.runResilientJobPolling({
      jobId: "job-auth-1",
      sleepFn: async () => {},
    });
    await mod.downloadJobWorkbook("job-auth-1");

    expect(recorded).toHaveLength(4);
    for (const call of recorded) {
      expect(call.headers).toEqual(
        expect.objectContaining({ Authorization: "Bearer web-admin-jwt-xyz" }),
      );
    }

    // 403 Forbidden during polling must fail fast on 1st attempt (not retry 5 times)
    const fetch403 = vi.fn().mockResolvedValue(
      new Response(JSON.stringify({ detail: "Admin role required." }), {
        status: 403,
      }),
    );
    vi.stubGlobal("fetch", fetch403);

    let caught: unknown;
    try {
      await mod.runResilientJobPolling({
        jobId: "job-auth-1",
        sleepFn: async () => {},
      });
    } catch (err) {
      caught = err;
    }
    expect(caught).toBeInstanceOf(mod.EngineJobError);
    expect((caught as EngineJobError).kind).toBe("auth");
    expect((caught as EngineJobError).status).toBe(403);
    expect(fetch403).toHaveBeenCalledTimes(1);
  });

  it("recovers from transient Failed to fetch & 502/503 blips with exponential backoff and emits reconnecting state", async () => {
    const sleepCalls: number[] = [];
    const reconnectEvents: Array<{ active: boolean; attempt: number; maxAttempts: number }> = [];
    let attempt = 0;

    const flakyFetch = vi.fn().mockImplementation(async (url: string) => {
      if (url.includes("/result/")) {
        return new Response(JSON.stringify(SAMPLE_RESULT), { status: 200 });
      }
      attempt += 1;
      if (attempt === 1 || attempt === 2) {
        throw new TypeError("Failed to fetch");
      }
      if (attempt === 3) {
        return new Response("Bad Gateway", { status: 502 });
      }
      if (attempt === 4) {
        return new Response("Service Unavailable", { status: 503 });
      }
      return new Response(
        JSON.stringify({ job_id: "job-abc123", state: "done", progress: 1 }),
        { status: 200 },
      );
    });
    vi.stubGlobal("fetch", flakyFetch);

    const res = await runResilientJobPolling({
      jobId: "job-abc123",
      sleepFn: async (ms) => {
        sleepCalls.push(ms);
      },
      transientBackoffScheduleMs: [100, 200, 300, 400, 500],
      onReconnecting: (info) =>
        reconnectEvents.push({
          active: info.active,
          attempt: info.attempt,
          maxAttempts: info.maxAttempts,
        }),
    });

    expect(res.rows).toHaveLength(1);
    expect(sleepCalls).toEqual([100, 200, 300, 400]);
    expect(reconnectEvents[0]).toEqual({ active: true, attempt: 1, maxAttempts: 5 });
    expect(reconnectEvents[reconnectEvents.length - 1]).toEqual({
      active: false,
      attempt: 0,
      maxAttempts: 5,
    });
  });

  it("replaces raw 'Failed to fetch' with actionable diagnostic copy when transient retries exhaust", async () => {
    const deadFetch = vi.fn().mockRejectedValue(new TypeError("Failed to fetch"));
    vi.stubGlobal("fetch", deadFetch);

    let caught: unknown;
    try {
      await runResilientJobPolling({
        jobId: "c47b731e9166",
        sleepFn: async () => {},
        transientBackoffScheduleMs: [10, 20, 30],
      });
    } catch (err) {
      caught = err;
    }

    expect(caught).toBeInstanceOf(EngineJobError);
    const err = caught as EngineJobError;
    expect(err.kind).toBe("network");
    expect(err.message).not.toMatch(/^failed to fetch$/i);
    expect(err.message).toContain("c47b731e9166");
    expect(err.message).toMatch(/Check Job Status/i);
    expect(deadFetch).toHaveBeenCalledTimes(4);
  });

  it("classifies engine_restarted terminal status as EngineJobError('engine-restart')", async () => {
    const restartedFetch = vi.fn().mockResolvedValue(
      new Response(
        JSON.stringify({
          job_id: "c47b731e9166",
          state: "failed",
          progress: 1,
          outcome: "UNKNOWN",
          raw_status: "ENGINE_RESTARTED",
          termination_reason: "engine_restarted",
          error: "Engine restarted mid-solve (likely memory or timeout limit). Please retry generation.",
        }),
        { status: 200 },
      ),
    );
    vi.stubGlobal("fetch", restartedFetch);

    let caught: unknown;
    try {
      await runResilientJobPolling({
        jobId: "c47b731e9166",
        sleepFn: async () => {},
      });
    } catch (err) {
      caught = err;
    }

    expect(caught).toBeInstanceOf(EngineJobError);
    expect((caught as EngineJobError).kind).toBe("engine-restart");
    expect((caught as EngineJobError).message).toMatch(/restarted mid-solve/i);
  });

  it("proactively refreshes an expiring Supabase access token during long polling", async () => {
    vi.resetModules();

    const refreshSession = vi.fn().mockResolvedValue({
      data: { session: { access_token: "refreshed-admin-jwt" } },
    });
    vi.doMock("@/services/supabase", () => ({
      isSupabaseConfigured: true,
      supabase: {
        auth: {
          getSession: vi.fn().mockResolvedValue({
            data: {
              session: {
                access_token: "expiring-admin-jwt",
                expires_at: Math.floor(Date.now() / 1000) + 15,
              },
            },
          }),
          refreshSession,
        },
      },
    }));

    const seenAuth: string[] = [];
    vi.stubGlobal(
      "fetch",
      vi.fn().mockImplementation(async (url: string, init?: RequestInit) => {
        const hdrs = init?.headers as Record<string, string> | undefined;
        if (hdrs?.Authorization) seenAuth.push(hdrs.Authorization);
        if (url.includes("/result/")) {
          return new Response(JSON.stringify(SAMPLE_RESULT), { status: 200 });
        }
        return new Response(
          JSON.stringify({ job_id: "job-refresh-1", state: "done", progress: 1 }),
          { status: 200 },
        );
      }),
    );

    const mod = await import("@/features/routine/services/timetableEngineService");
    await mod.runResilientJobPolling({
      jobId: "job-refresh-1",
      sleepFn: async () => {},
    });

    expect(refreshSession).toHaveBeenCalled();
    expect(seenAuth.every((h) => h === "Bearer refreshed-admin-jwt")).toBe(true);
  });
});
