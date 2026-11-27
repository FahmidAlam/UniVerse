
from __future__ import annotations

import json
import uuid
from threading import Thread

from fastapi import Depends, FastAPI, File, Form, HTTPException, Request, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response

import auth
import distribution
import domain
import parse_rendered
import preflight
import render
import security_guards
import solver

app = FastAPI(title="UniVerse Timetable Engine", version="2.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=auth.get_allowed_origins(),
    allow_credentials=False,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type"],
)

JOBS: dict[str, dict] = {}
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
    if source_contract is not None:
        return distribution.normalize_persisted_revision(
            file_bytes, source_contract,
            weeks_in_term=cfg['weeks_in_term'],
            fixed_sessions_per_week=cfg.get('fixed_sessions_per_week'))
    draft = distribution.DistributionDraft.create(file_bytes)
    return distribution.normalize(
        draft, weeks_in_term=cfg['weeks_in_term'],
        fixed_sessions_per_week=cfg.get('fixed_sessions_per_week'))


def _run_job(job_id: str, file_bytes: bytes, config_override: dict | None,
             time_limit_s: float, source_contract: dict | None = None) -> None:
    job = JOBS[job_id]
    try:
        job["state"] = "ingesting"
        job["progress"] = 0.08
        # Config first: the parser needs `weeks_in_term` to turn each
        # offering's whole-term class count into weekly sessions.
        cfg = solver.load_config(override=config_override)
        dataset = normalize_generation_distribution(
            file_bytes, cfg, source_contract=source_contract)

        job["state"] = "solving"
        job["progress"] = 0.2

        def on_progress(value: float) -> None:
            job["progress"] = round(0.2 + (float(value) * 0.75), 2)

        result = solver.solve(dataset, cfg, time_limit_s=time_limit_s,
                              progress=solver._Progress(on_progress))
        result["validation"] = {
            **result["validation"],
            "source_contract": dataset["source_contract"],
        }

        job["state"] = "rendering"
        job["progress"] = 0.97
        job["file"] = render.render_bytes(
            result["rows"], dataset["cohorts"], cfg,
            source_contract=dataset["source_contract"])

        job["rows"] = result["rows"]
        # Service / non-CSE classes are not drawn on the printed grid, but they
        # occupy real teachers and rooms and must be published so Room
        # Availability and Find Teacher tell the truth.
        job["service_rows"] = result["service_rows"]
        job["stats"] = result["stats"]
        job["validation"] = result["validation"]
        job["source_contract"] = dataset["source_contract"]
        job["report"] = {
            "source_contract": dataset["source_contract"],
            "cohorts": dataset["cohorts"],
            "meta": dataset["meta"],
            "excluded": dataset["excluded"],
            "warnings": dataset["warnings"],
            "offerings": dataset["offerings"],
        }
        job["semester_label"] = (config_override or {}).get(
            "settings", {}).get("semester_label") if config_override else cfg.get("semester_label")
        job["progress"] = 1.0
        job["state"] = "done"
    except Exception as e:  # noqa: BLE001 — surface any error to the client
        job["state"] = "failed"
        job["error"] = str(e)
        job["progress"] = 1.0
    finally:
        SOLVE_CONCURRENCY_GUARD.release()


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

    SOLVE_CONCURRENCY_GUARD.acquire_or_reject()
    job_id = uuid.uuid4().hex[:12]
    JOBS[job_id] = {"state": "queued", "progress": 0.0}
    try:
        Thread(target=_run_job,
               args=(job_id, file_bytes, config_override, time_limit_s, persisted_contract),
               daemon=True).start()
    except Exception:
        SOLVE_CONCURRENCY_GUARD.release()
        JOBS.pop(job_id, None)
        raise
    return {"job_id": job_id}


@app.get("/api/timetable/status/{job_id}")
def status(
    job_id: str,
    _caller: auth.VerifiedCaller | None = Depends(auth.require_admin_caller),
) -> dict:
    job = JOBS.get(job_id)
    if job is None:
        raise HTTPException(status_code=404, detail="Unknown job_id.")
    out = {"job_id": job_id, "state": job["state"], "progress": job.get("progress", 0.0)}
    if job["state"] == "done":
        out["stats"] = job.get("stats")
        out["validation"] = job.get("validation")
        out["source_contract"] = job.get("source_contract")
    if job["state"] == "failed":
        out["error"] = job.get("error")
    return out


@app.get("/api/timetable/result/{job_id}")
def result(
    job_id: str,
    _caller: auth.VerifiedCaller | None = Depends(auth.require_admin_caller),
) -> dict:
    job = JOBS.get(job_id)
    if job is None:
        raise HTTPException(status_code=404, detail="Unknown job_id.")
    if job["state"] != "done":
        raise HTTPException(status_code=409, detail=f"Job not finished (state={job['state']}).")
    return {
        "job_id": job_id,
        "rows": job["rows"],
        "service_rows": job.get("service_rows", []),
        "stats": job["stats"],
        "validation": job["validation"],
        "source_contract": job["source_contract"],
        "report": job["report"],
        "has_workbook": job.get("file") is not None,
    }


@app.get("/api/timetable/download/{job_id}")
def download(
    job_id: str,
    _caller: auth.VerifiedCaller | None = Depends(auth.require_admin_caller),
):
    job = JOBS.get(job_id)
    if job is None:
        raise HTTPException(status_code=404, detail="Unknown job_id.")
    data = job.get("file")
    if data is None:
        raise HTTPException(status_code=409, detail="No workbook for this job yet.")
    label = (job.get("semester_label") or "timetable").replace(" ", "_")
    return Response(
        content=data,
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={"Content-Disposition": f'attachment; filename="CSE_Routine_{label}.xlsx"'},
    )
