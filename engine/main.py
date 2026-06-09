# ============================================================
# FILE: engine/main.py
# PURPOSE: FastAPI wrapper around the OR-Tools timetable solver.
#   Async job model so the Flutter client can show a live progress
#   bar while CP-SAT runs:
#     POST /api/timetable/generate        -> { job_id }
#     GET  /api/timetable/status/{job_id} -> { state, progress, ... }
#     GET  /api/timetable/result/{job_id} -> { rows, stats, validation }
#   Job state is in-memory (a dict) — fine for the demo; no DB.
#
# RUN (from the engine/ directory):
#   pip install -r requirements.txt
#   uvicorn main:app --reload --port 8000
#
# Android emulator reaches this host at http://10.0.2.2:8000
# ============================================================

from __future__ import annotations

import uuid
from threading import Thread

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

import solver

app = FastAPI(title="UniVerse Timetable Engine", version="1.0.0")

# Permissive CORS — the Flutter app calls this directly during the demo.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# job_id -> { state, progress, rows, stats, validation, error }
JOBS: dict[str, dict] = {}


class GenerateRequest(BaseModel):
    # Optional inline dataset override; falls back to fixtures/offerings.json.
    dataset: dict | None = None
    time_limit_s: float = 20.0


def _run_job(job_id: str, dataset: dict | None, time_limit_s: float) -> None:
    job = JOBS[job_id]
    try:
        job["state"] = "solving"
        job["progress"] = 0.15

        def on_progress(value: float) -> None:
            job["progress"] = round(float(value), 2)

        ds = solver.load_dataset(override=dataset)
        result = solver.solve(ds, time_limit_s=time_limit_s,
                              progress=solver._Progress(on_progress))

        job["rows"] = result["rows"]
        job["stats"] = result["stats"]
        job["validation"] = result["validation"]
        job["progress"] = 1.0
        job["state"] = "done"
    except Exception as e:  # noqa: BLE001 — surface any solver/data error to the client
        job["state"] = "failed"
        job["error"] = str(e)
        job["progress"] = 1.0


@app.get("/")
def health() -> dict:
    return {"service": "universe-timetable-engine", "ok": True}


@app.post("/api/timetable/generate")
def generate(req: GenerateRequest | None = None) -> dict:
    req = req or GenerateRequest()
    job_id = uuid.uuid4().hex[:12]
    JOBS[job_id] = {"state": "queued", "progress": 0.0}
    # Solve off the request thread so /status stays responsive.
    Thread(target=_run_job, args=(job_id, req.dataset, req.time_limit_s), daemon=True).start()
    return {"job_id": job_id}


@app.get("/api/timetable/status/{job_id}")
def status(job_id: str) -> dict:
    job = JOBS.get(job_id)
    if job is None:
        raise HTTPException(status_code=404, detail="Unknown job_id.")
    out = {"job_id": job_id, "state": job["state"], "progress": job.get("progress", 0.0)}
    if job["state"] == "done":
        out["stats"] = job.get("stats")
        out["validation"] = job.get("validation")
    if job["state"] == "failed":
        out["error"] = job.get("error")
    return out


@app.get("/api/timetable/result/{job_id}")
def result(job_id: str) -> dict:
    job = JOBS.get(job_id)
    if job is None:
        raise HTTPException(status_code=404, detail="Unknown job_id.")
    if job["state"] != "done":
        raise HTTPException(status_code=409, detail=f"Job not finished (state={job['state']}).")
    return {
        "job_id": job_id,
        "rows": job["rows"],
        "stats": job["stats"],
        "validation": job["validation"],
    }
