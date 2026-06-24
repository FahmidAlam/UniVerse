
from __future__ import annotations

import json
import uuid
from threading import Thread

from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response

import ingest
import render
import solver

app = FastAPI(title="UniVerse Timetable Engine", version="2.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

JOBS: dict[str, dict] = {}


def _run_job(job_id: str, file_bytes: bytes, config_override: dict | None,
             time_limit_s: float) -> None:
    job = JOBS[job_id]
    try:
        job["state"] = "ingesting"
        job["progress"] = 0.08
        dataset = ingest.ingest_bytes(file_bytes)
        cfg = solver.load_config(override=config_override)

        job["state"] = "solving"
        job["progress"] = 0.2

        def on_progress(value: float) -> None:
            job["progress"] = round(0.2 + (float(value) * 0.75), 2)

        result = solver.solve(dataset, cfg, time_limit_s=time_limit_s,
                              progress=solver._Progress(on_progress))

        job["state"] = "rendering"
        job["progress"] = 0.97
        job["file"] = render.render_bytes(result["rows"], dataset["cohorts"], cfg)

        job["rows"] = result["rows"]
        job["stats"] = result["stats"]
        job["validation"] = result["validation"]
        job["report"] = {
            "cohorts": dataset["cohorts"],
            "meta": dataset["meta"],
            "excluded": dataset["excluded"],
            "warnings": dataset["warnings"],
        }
        job["semester_label"] = (config_override or {}).get(
            "settings", {}).get("semester_label") if config_override else cfg.get("semester_label")
        job["progress"] = 1.0
        job["state"] = "done"
    except Exception as e:  # noqa: BLE001 — surface any error to the client
        job["state"] = "failed"
        job["error"] = str(e)
        job["progress"] = 1.0


@app.get("/")
def health() -> dict:
    return {"service": "universe-timetable-engine", "version": "2.0.0", "ok": True}


@app.post("/api/timetable/generate")
async def generate(
    file: UploadFile = File(...),
    config: str | None = Form(None),
    time_limit_s: float = Form(60.0),
) -> dict:
    if not file.filename or not file.filename.lower().endswith((".xlsx", ".xls")):
        raise HTTPException(status_code=400, detail="Upload a .xlsx distribution file.")
    file_bytes = await file.read()
    config_override = None
    if config:
        try:
            config_override = json.loads(config)
        except json.JSONDecodeError:
            raise HTTPException(status_code=400, detail="config is not valid JSON.")

    job_id = uuid.uuid4().hex[:12]
    JOBS[job_id] = {"state": "queued", "progress": 0.0}
    Thread(target=_run_job,
           args=(job_id, file_bytes, config_override, time_limit_s),
           daemon=True).start()
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
        "report": job["report"],
        "has_workbook": job.get("file") is not None,
    }


@app.get("/api/timetable/download/{job_id}")
def download(job_id: str):
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
