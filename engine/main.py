
from __future__ import annotations

from contextlib import asynccontextmanager
import gc
import json
import logging
import threading
import uuid
from threading import Thread

import anyio
from fastapi import Depends, FastAPI, File, Form, HTTPException, Request, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, Response

import auth
import distribution
import domain
import job_store
import parse_rendered
import preflight
import render
import security_guards
import solver

logger = logging.getLogger("universe.engine.main")


@asynccontextmanager
async def _lifespan(_app: FastAPI):
    # On container boot (including after a Render OOM restart), immediately sweep
    # any orphaned non-terminal jobs in Postgres in a background thread so health
    # checks stay instant and polling clients get a clear restart error.
    Thread(
        target=job_store.mark_orphaned_jobs_on_startup,
        name="solver-startup-orphan-sweep",
        daemon=True,
    ).start()
    yield


app = FastAPI(title="UniVerse Timetable Engine", version="2.0.0", lifespan=_lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=auth.get_allowed_origins(),
    allow_credentials=False,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type"],
)


@app.exception_handler(Exception)
async def unhandled_exception_handler(request: Request, exc: Exception) -> JSONResponse:
    """Guarantee structured JSON + CORS headers on unexpected 500s so browsers do not report bare Failed to fetch."""
    logger.exception("Unhandled engine error on %s %s", request.method, request.url.path)
    headers: dict[str, str] = {"Vary": "Origin"}
    origin = (request.headers.get("origin") or "").strip().rstrip("/")
    if origin and origin in auth.get_allowed_origins():
        headers["Access-Control-Allow-Origin"] = origin
    return JSONResponse(
        status_code=500,
        content={"detail": "Internal timetable engine error."},
        headers=headers,
    )

JOBS: dict[str, dict] = job_store._MEMORY_JOBS
GENERATE_RATE_LIMITER, PARSE_RATE_LIMITER, SOLVE_CONCURRENCY_GUARD = (
    security_guards.build_default_guards()
)


def _caller_rate_key(request: Request, caller: auth.VerifiedCaller | None) -> str:
    if caller is not None and caller.user_id:
        return f"user:{caller.user_id}"
    host = request.client.host if request.client else "unknown"
    return f"ip:{host}"


def normalize_generation_distribution(file_bytes: bytes, cfg: dict,
                                      source_contract: dict | None = None) -> dict:
    """Bind generation to an immutable source revision before solver input.

    Uploads currently create revision zero in memory. Persisted accepted
    revisions will use this same normalization boundary after Phase 2a storage
    integration, rather than introducing a second spreadsheet parser.
    """
    committee_policy = cfg.get("committee_policy")
    courses_catalog = cfg.get("courses_catalog") or None
    if source_contract is not None:
        return distribution.normalize_persisted_revision(
            file_bytes, source_contract,
            weeks_in_term=cfg['weeks_in_term'],
            fixed_sessions_per_week=cfg.get('fixed_sessions_per_week'),
            committee_policy=committee_policy,
            courses_catalog=courses_catalog)
    draft = distribution.DistributionDraft.create(file_bytes)
    return distribution.normalize(
        draft, weeks_in_term=cfg['weeks_in_term'],
        fixed_sessions_per_week=cfg.get('fixed_sessions_per_week'),
        committee_policy=committee_policy,
        courses_catalog=courses_catalog)


def _run_job(
    job_id: str,
    file_bytes: bytes,
    config_override: dict | None,
    time_limit_s: float,
    source_contract: dict | None = None,
    caller_token: str | None = None,
) -> None:
    job_store.mark_job_active(job_id)
    stop_heartbeat = threading.Event()

    def _heartbeat_loop() -> None:
        interval = job_store.get_heartbeat_interval_s()
        while not stop_heartbeat.wait(interval):
            job_store.touch_heartbeat(job_id, caller_token=caller_token)

    heartbeat_thread = Thread(
        target=_heartbeat_loop,
        name=f"solver-heartbeat-{job_id}",
        daemon=True,
    )
    heartbeat_thread.start()
    try:
        job_store.update_job(
            job_id,
            {"state": "ingesting", "progress": 0.08},
            caller_token=caller_token,
            force_remote=True,
        )
        # Config first: the parser needs `weeks_in_term` to turn each
        # offering's whole-term class count into weekly sessions.
        cfg = solver.load_config(override=config_override)
        dataset = normalize_generation_distribution(
            file_bytes, cfg, source_contract=source_contract)
        # Release raw uploaded workbook bytes before CP-SAT allocates search buffers.
        file_bytes = b""
        gc.collect()

        job_store.update_job(
            job_id,
            {"state": "solving", "progress": 0.2},
            caller_token=caller_token,
            force_remote=True,
        )

        def on_progress(value: float) -> None:
            job_store.update_job(
                job_id,
                {"progress": round(0.2 + (float(value) * 0.75), 2)},
                caller_token=caller_token,
                force_remote=False,
            )

        result = solver.solve(
            dataset,
            cfg,
            time_limit_s=time_limit_s,
            progress=solver._Progress(on_progress),
            return_outcomes=True,
        )

        outcome = result.get("outcome", "OPTIMAL")
        raw_status = result.get("raw_status", outcome)
        termination_reason = result.get("termination_reason", "")
        proven_infeasible = bool(result.get("proven_infeasible", False))
        conflicts = result.get("conflicts", [])
        soft_metrics = result.get("soft_metrics")

        if outcome not in ("OPTIMAL", "FEASIBLE"):
            report_payload = {
                "source_contract": dataset["source_contract"],
                "cohorts": dataset["cohorts"],
                "meta": dataset["meta"],
                "excluded": dataset["excluded"],
                "warnings": dataset["warnings"],
                "offerings": dataset["offerings"],
            }
            job_store.update_job(
                job_id,
                {
                    "state": "failed",
                    "structured_terminal": True,
                    "outcome": outcome,
                    "raw_status": raw_status,
                    "termination_reason": termination_reason,
                    "proven_infeasible": proven_infeasible,
                    "conflicts": conflicts,
                    "soft_metrics": soft_metrics,
                    "error": result.get("error") or f"Solver terminated with outcome {outcome}.",
                    "stats": result.get("stats") or {"status": raw_status},
                    "validation": result.get("validation"),
                    "source_contract": dataset["source_contract"],
                    "report": report_payload,
                    "progress": 1.0,
                },
                caller_token=caller_token,
                force_remote=True,
            )
            return

        result["validation"] = {
            **result["validation"],
            "source_contract": dataset["source_contract"],
        }

        job_store.update_job(
            job_id,
            {"state": "rendering", "progress": 0.97},
            caller_token=caller_token,
            force_remote=True,
        )
        xlsx_bytes = render.render_bytes(
            result["rows"], dataset["cohorts"], cfg,
            source_contract=dataset["source_contract"])
        storage_path = job_store.save_workbook(
            job_id,
            xlsx_bytes,
            caller_token=caller_token,
        )

        semester_label = (
            (config_override or {}).get("settings", {}).get("semester_label")
            if config_override
            else cfg.get("semester_label")
        )
        report_payload = {
            "source_contract": dataset["source_contract"],
            "cohorts": dataset["cohorts"],
            "meta": dataset["meta"],
            "excluded": dataset["excluded"],
            "warnings": dataset["warnings"],
            "offerings": dataset["offerings"],
        }
        done_patch: dict[str, object] = {
            "state": "done",
            "progress": 1.0,
            "outcome": outcome,
            "raw_status": raw_status,
            "termination_reason": termination_reason,
            "proven_infeasible": proven_infeasible,
            "conflicts": conflicts,
            "soft_metrics": soft_metrics,
            "rows": result["rows"],
            # Service / non-CSE classes are not drawn on the printed grid, but they
            # occupy real teachers and rooms and must be published so Room
            # Availability and Find Teacher tell the truth.
            "service_rows": result["service_rows"],
            "stats": result["stats"],
            "validation": result["validation"],
            "source_contract": dataset["source_contract"],
            "report": report_payload,
            "semester_label": semester_label,
        }
        if storage_path:
            done_patch["workbook_storage_path"] = storage_path
        job_store.update_job(
            job_id,
            done_patch,
            caller_token=caller_token,
            force_remote=True,
        )
    except Exception as e:  # noqa: BLE001 — surface any error to the client
        job_store.update_job(
            job_id,
            {
                "state": "failed",
                "error": str(e),
                "outcome": "INPUT_ERROR",
                "raw_status": "INPUT_ERROR",
                "termination_reason": "unexpected_exception",
                "proven_infeasible": False,
                "conflicts": [],
                "progress": 1.0,
            },
            caller_token=caller_token,
            force_remote=True,
        )
    finally:
        stop_heartbeat.set()
        job_store.mark_job_inactive(job_id)
        SOLVE_CONCURRENCY_GUARD.release()
        gc.collect()


@app.get("/")
def health() -> dict:
    return {
        "service": "universe-timetable-engine",
        "version": "2.0.0",
        "ok": True,
        "auth_mode": auth.get_auth_mode(),
    }


@app.post("/api/timetable/parse-rendered-workbook")
async def parse_rendered_workbook_endpoint(
    request: Request,
    file: UploadFile = File(...),
    config: str | None = Form(None),
    subject_titles: str | None = Form(None),
    _caller: auth.VerifiedCaller | None = Depends(auth.require_admin_caller),
) -> dict:
    """Phase 3B strictly non-mutating rendered-workbook parser & validator."""
    PARSE_RATE_LIMITER.check(_caller_rate_key(request, _caller))
    file_bytes = await file.read()
    security_guards.validate_xlsx_upload(file.filename, file_bytes)

    config_obj = None
    if config:
        try:
            config_obj = json.loads(config)
        except json.JSONDecodeError:
            raise HTTPException(status_code=400, detail="config is not valid JSON.")
        if not isinstance(config_obj, dict):
            raise HTTPException(status_code=400, detail="config must be a JSON object.")

    titles_obj = None
    if subject_titles:
        try:
            titles_obj = json.loads(subject_titles)
        except json.JSONDecodeError:
            raise HTTPException(status_code=400, detail="subject_titles is not valid JSON.")
        if not isinstance(titles_obj, dict):
            raise HTTPException(status_code=400, detail="subject_titles must be a JSON object.")

    try:
        return parse_rendered.parse_rendered_workbook(
            file_bytes,
            config=config_obj,
            subject_titles=titles_obj,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


def _parse_config_policy_snapshot(config_override: dict | None) -> domain.CommitteePolicySnapshot | None:
    if not config_override or "policy_snapshot" not in config_override:
        return None
    raw_snapshot = config_override.get("policy_snapshot")
    if raw_snapshot is None:
        return None
    if not isinstance(raw_snapshot, dict):
        raise HTTPException(status_code=400, detail="config.policy_snapshot must be a JSON object.")
    try:
        return domain.CommitteePolicySnapshot.from_dict(raw_snapshot)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=f"Invalid config.policy_snapshot: {exc}") from exc


@app.post("/api/timetable/validate-policy-readiness")
async def validate_policy_readiness_endpoint(
    request: Request,
    _caller: auth.VerifiedCaller | None = Depends(auth.require_admin_caller),
) -> dict:
    """Stage 5A (Gate C) strictly non-mutating server preflight validator."""
    PARSE_RATE_LIMITER.check(_caller_rate_key(request, _caller))
    try:
        body = await request.json()
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=400, detail="Request body must be valid JSON.") from exc
    if not isinstance(body, dict):
        raise HTTPException(status_code=400, detail="Request body must be a JSON object.")
    try:
        return preflight.validate_policy_readiness(body)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@app.post("/api/timetable/generate")
async def generate(
    request: Request,
    file: UploadFile = File(...),
    config: str | None = Form(None),
    source_contract: str | None = Form(None),
    time_limit_s: float = Form(60.0),
    scheduling_scope_id: str | None = Form(None),
    revision_id: str | None = Form(None),
    revision_version: int | None = Form(None),
    policy_snapshot_id: str | None = Form(None),
    _caller: auth.VerifiedCaller | None = Depends(auth.require_admin_caller),
) -> dict:
    GENERATE_RATE_LIMITER.check(_caller_rate_key(request, _caller))
    file_bytes = await file.read()
    security_guards.validate_xlsx_upload(file.filename, file_bytes)
    config_override = None
    if config:
        try:
            config_override = json.loads(config)
        except json.JSONDecodeError:
            raise HTTPException(status_code=400, detail="config is not valid JSON.")
    _parse_config_policy_snapshot(config_override)
    persisted_contract = None
    if source_contract:
        try:
            persisted_contract = json.loads(source_contract)
        except json.JSONDecodeError:
            raise HTTPException(status_code=400, detail="source_contract is not valid JSON.")
        if not isinstance(persisted_contract, dict):
            raise HTTPException(status_code=400, detail="source_contract must be a JSON object.")

    caller_token = auth._extract_bearer_token(request.headers.get("authorization"))
    semester_label = None
    if isinstance(config_override, dict):
        semester_label = (
            (config_override.get("settings") or {}).get("semester_label")
            if isinstance(config_override.get("settings"), dict)
            else config_override.get("semester_label")
        )
    if not semester_label and isinstance(persisted_contract, dict):
        semester_label = persisted_contract.get("semester_label")

    SOLVE_CONCURRENCY_GUARD.acquire_or_reject()
    job_id = uuid.uuid4().hex[:12]
    await anyio.to_thread.run_sync(
        lambda: job_store.create_job(
            job_id,
            scheduling_scope_id=scheduling_scope_id or None,
            revision_id=revision_id or None,
            revision_version=revision_version,
            policy_snapshot_id=policy_snapshot_id or None,
            semester_label=str(semester_label) if semester_label else None,
            created_by=_caller.user_id if _caller and _caller.user_id else None,
            caller_token=caller_token,
        )
    )
    try:
        Thread(
            target=_run_job,
            args=(job_id, file_bytes, config_override, time_limit_s, persisted_contract, caller_token),
            daemon=True,
        ).start()
    except Exception:
        SOLVE_CONCURRENCY_GUARD.release()
        job_store.delete_job(job_id)
        raise
    return {"job_id": job_id}


@app.get("/api/timetable/jobs")
def list_jobs(
    request: Request,
    revision_id: str | None = None,
    scheduling_scope_id: str | None = None,
    limit: int = 20,
    _caller: auth.VerifiedCaller | None = Depends(auth.require_admin_caller),
) -> dict:
    caller_token = auth._extract_bearer_token(request.headers.get("authorization"))
    return {
        "jobs": job_store.list_jobs(
            revision_id=revision_id,
            scheduling_scope_id=scheduling_scope_id,
            limit=limit,
            caller_token=caller_token,
        )
    }


@app.get("/api/timetable/status/{job_id}")
def status(
    job_id: str,
    request: Request,
    _caller: auth.VerifiedCaller | None = Depends(auth.require_admin_caller),
) -> dict:
    caller_token = auth._extract_bearer_token(request.headers.get("authorization"))
    job = job_store.get_job_status(job_id, caller_token=caller_token)
    if job is None:
        raise HTTPException(status_code=404, detail="Unknown job_id.")
    out = {
        "job_id": job_id,
        "state": job["state"],
        "progress": job.get("progress", 0.0),
        "scheduling_scope_id": job.get("scheduling_scope_id"),
        "revision_id": job.get("revision_id"),
        "revision_version": job.get("revision_version"),
        "policy_snapshot_id": job.get("policy_snapshot_id"),
        "workbook_storage_path": job.get("workbook_storage_path"),
        "created_at": job.get("created_at"),
        "updated_at": job.get("updated_at"),
    }
    if "outcome" in job:
        out["outcome"] = job.get("outcome")
        out["raw_status"] = job.get("raw_status")
        out["termination_reason"] = job.get("termination_reason")
        out["proven_infeasible"] = job.get("proven_infeasible", False)
        out["conflicts"] = job.get("conflicts", [])
    if job["state"] == "done":
        out["stats"] = job.get("stats")
        out["validation"] = job.get("validation")
        out["source_contract"] = job.get("source_contract")
        out["soft_metrics"] = job.get("soft_metrics")
    if job["state"] == "failed":
        out["error"] = job.get("error")
        if job.get("stats") is not None:
            out["stats"] = job.get("stats")
        if job.get("validation") is not None:
            out["validation"] = job.get("validation")
    return out


@app.get("/api/timetable/result/{job_id}")
def result(
    job_id: str,
    request: Request,
    _caller: auth.VerifiedCaller | None = Depends(auth.require_admin_caller),
) -> dict:
    caller_token = auth._extract_bearer_token(request.headers.get("authorization"))
    job = job_store.get_job(job_id, caller_token=caller_token)
    if job is None:
        raise HTTPException(status_code=404, detail="Unknown job_id.")
    if job["state"] != "done" and not job.get("structured_terminal"):
        raise HTTPException(status_code=409, detail=f"Job not finished (state={job['state']}).")
    return {
        "job_id": job_id,
        "outcome": job.get("outcome", "OPTIMAL"),
        "raw_status": job.get("raw_status", "OPTIMAL"),
        "termination_reason": job.get("termination_reason", "optimal"),
        "proven_infeasible": job.get("proven_infeasible", False),
        "conflicts": job.get("conflicts", []),
        "error": job.get("error"),
        "rows": job.get("rows", []),
        "service_rows": job.get("service_rows", []),
        "stats": job.get("stats") or {},
        "validation": job.get("validation") or {"ok": False},
        "soft_metrics": job.get("soft_metrics"),
        "source_contract": job.get("source_contract"),
        "scheduling_scope_id": job.get("scheduling_scope_id"),
        "revision_id": job.get("revision_id"),
        "revision_version": job.get("revision_version"),
        "policy_snapshot_id": job.get("policy_snapshot_id"),
        "workbook_storage_path": job.get("workbook_storage_path"),
        "created_at": job.get("created_at"),
        "updated_at": job.get("updated_at"),
        "report": job.get("report") or {
            "cohorts": [], "meta": {}, "excluded": [], "warnings": [], "offerings": []
        },
        "has_workbook": bool(job.get("file") is not None or job.get("workbook_storage_path")),
    }


@app.get("/api/timetable/download/{job_id}")
def download(
    job_id: str,
    request: Request,
    _caller: auth.VerifiedCaller | None = Depends(auth.require_admin_caller),
):
    caller_token = auth._extract_bearer_token(request.headers.get("authorization"))
    data, job = job_store.get_workbook(job_id, caller_token=caller_token)
    if job is None:
        raise HTTPException(status_code=404, detail="Unknown job_id.")
    if data is None:
        raise HTTPException(status_code=409, detail="No workbook for this job yet.")
    label = (job.get("semester_label") or "timetable").replace(" ", "_")
    return Response(
        content=data,
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={"Content-Disposition": f'attachment; filename="CSE_Routine_{label}.xlsx"'},
    )
