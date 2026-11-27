"""Durable Postgres (`public.solver_jobs`) + Storage (`timetables`) job store.

Falls back transparently to an in-memory dictionary (`_MEMORY_JOBS`) when
Supabase credentials are not configured (unit tests, offline local CLI runs)
or when a caller only needs ephemeral in-process state, while keeping Render
free-tier restarts and browser refreshes recoverable whenever Supabase REST +
Storage are reachable.
"""

from __future__ import annotations

import logging
import os
import threading
import time
from datetime import datetime, timezone
from typing import Any

import httpx

import auth

logger = logging.getLogger("universe.engine.job_store")

_MEMORY_LOCK = threading.Lock()
_MEMORY_JOBS: dict[str, dict[str, Any]] = {}
_LOCAL_ACTIVE_JOBS: set[str] = set()

_NON_TERMINAL_STATES = {"queued", "ingesting", "solving", "rendering"}
_MAX_MEMORY_JOBS = 12

SOLVER_JOB_COLUMNS = (
    "job_id,scheduling_scope_id,revision_id,revision_version,policy_snapshot_id,"
    "semester_label,state,progress,outcome,raw_status,termination_reason,"
    "proven_infeasible,conflicts,stats,validation,report,rows,service_rows,"
    "source_contract,workbook_storage_path,error,created_by,created_at,updated_at"
)

SOLVER_JOB_STATUS_COLUMNS = (
    "job_id,scheduling_scope_id,revision_id,revision_version,policy_snapshot_id,"
    "semester_label,state,progress,outcome,raw_status,termination_reason,"
    "proven_infeasible,conflicts,stats,validation,source_contract,"
    "workbook_storage_path,error,created_by,created_at,updated_at"
)

SOLVER_JOB_SUMMARY_COLUMNS = (
    "job_id,scheduling_scope_id,revision_id,revision_version,policy_snapshot_id,"
    "semester_label,state,progress,outcome,raw_status,termination_reason,"
    "proven_infeasible,workbook_storage_path,error,stats,created_by,created_at,updated_at"
)

_WORKBOOK_BUCKET = "timetables"
_PROGRESS_PATCH_MIN_DELTA = 0.12
_ORPHAN_ERROR_MESSAGE = (
    "Engine restarted mid-solve (likely memory or timeout limit). Please retry generation."
)


def get_heartbeat_interval_s() -> float:
    raw = os.environ.get("SOLVER_HEARTBEAT_INTERVAL_S", "15.0").strip()
    try:
        return max(1.0, float(raw))
    except ValueError:
        return 15.0


def get_stale_job_timeout_s() -> float:
    raw = os.environ.get("STALE_JOB_TIMEOUT_S", "45.0").strip()
    try:
        return max(5.0, float(raw))
    except ValueError:
        return 45.0


def mark_job_active(job_id: str) -> None:
    with _MEMORY_LOCK:
        _LOCAL_ACTIVE_JOBS.add(job_id)


def mark_job_inactive(job_id: str) -> None:
    with _MEMORY_LOCK:
        _LOCAL_ACTIVE_JOBS.discard(job_id)


def is_job_locally_active(job_id: str) -> bool:
    with _MEMORY_LOCK:
        return job_id in _LOCAL_ACTIVE_JOBS


def _parse_iso_timestamp(value: Any) -> datetime | None:
    if not value or not isinstance(value, str):
        return None
    normalized = value.strip()
    if not normalized:
        return None
    if normalized.endswith("Z"):
        normalized = f"{normalized[:-1]}+00:00"
    try:
        dt = datetime.fromisoformat(normalized)
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        return dt
    except ValueError:
        return None


def _evict_old_memory_jobs() -> None:
    """Keep in-process job cache bounded to protect 512 MB containers."""
    if len(_MEMORY_JOBS) <= _MAX_MEMORY_JOBS:
        return
    removable = [
        (str(job.get("updated_at") or job.get("created_at") or ""), jid)
        for jid, job in _MEMORY_JOBS.items()
        if jid not in _LOCAL_ACTIVE_JOBS and job.get("state") not in _NON_TERMINAL_STATES
    ]
    removable.sort()
    overflow = len(_MEMORY_JOBS) - _MAX_MEMORY_JOBS
    for _, jid in removable[:overflow]:
        _MEMORY_JOBS.pop(jid, None)


def _maybe_mark_orphaned_job(
    job: dict[str, Any],
    *,
    caller_token: str | None = None,
) -> dict[str, Any]:
    """Detect a non-terminal job whose worker process died (e.g. Render OOM restart)."""
    job_id = str(job.get("job_id") or "")
    if not job_id or job.get("state") not in _NON_TERMINAL_STATES:
        return job
    if is_job_locally_active(job_id):
        return job
    ts = _parse_iso_timestamp(job.get("updated_at")) or _parse_iso_timestamp(job.get("created_at"))
    if ts is None:
        return job
    age_s = (datetime.now(timezone.utc) - ts).total_seconds()
    if age_s < get_stale_job_timeout_s():
        return job

    logger.warning(
        "Detected orphaned solver job %s (state=%s, stale %.1fs) — marking failed.",
        job_id,
        job.get("state"),
        age_s,
    )
    now = _now_iso()
    orphan_patch: dict[str, Any] = {
        "state": "failed",
        "progress": 1.0,
        "outcome": "UNKNOWN",
        "raw_status": "ENGINE_RESTARTED",
        "termination_reason": "engine_restarted",
        "proven_infeasible": False,
        "error": _ORPHAN_ERROR_MESSAGE,
        "updated_at": now,
    }
    updated = {**job, **orphan_patch}
    with _MEMORY_LOCK:
        if job_id in _MEMORY_JOBS:
            _MEMORY_JOBS[job_id].update(orphan_patch)
    _postgrest_patch(job_id, _serialize_db_patch(orphan_patch), caller_token=caller_token)
    return updated


def mark_orphaned_jobs_on_startup() -> int:
    """Immediately transition any leftover non-terminal Postgres jobs on fresh process boot.

    Safe on single-worker Render deployments: a freshly booted process has no
    in-flight solver threads from before the restart, so any pre-existing
    queued/ingesting/solving/rendering row is guaranteed orphaned by a crash or OOM.
    """
    ctx = _remote_context(caller_token=None)
    if ctx is None:
        return 0
    supabase_url, headers = ctx
    try:
        with _http_client() as client:
            resp = client.get(
                f"{supabase_url}/rest/v1/solver_jobs",
                params={
                    "select": "job_id,state",
                    "state": "in.(queued,ingesting,solving,rendering)",
                    "limit": "50",
                },
                headers=headers,
            )
            if resp.status_code != 200:
                return 0
            rows = resp.json()
            if not isinstance(rows, list):
                return 0
    except Exception as exc:  # noqa: BLE001
        logger.warning("Startup orphan sweep query failed: %s", exc)
        return 0

    marked = 0
    now = _now_iso()
    orphan_patch: dict[str, Any] = {
        "state": "failed",
        "progress": 1.0,
        "outcome": "UNKNOWN",
        "raw_status": "ENGINE_RESTARTED",
        "termination_reason": "engine_restarted",
        "proven_infeasible": False,
        "error": _ORPHAN_ERROR_MESSAGE,
        "updated_at": now,
    }
    serialized = _serialize_db_patch(orphan_patch)
    for row in rows:
        jid = str(row.get("job_id") or "")
        if not jid or is_job_locally_active(jid):
            continue
        if _postgrest_patch(jid, serialized, caller_token=None):
            marked += 1
    if marked:
        logger.warning("Startup orphan sweep marked %d interrupted job(s) failed.", marked)
    return marked


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _http_client() -> httpx.Client:
    timeout = float(os.environ.get("JOB_STORE_TIMEOUT_S", "15.0") or 15.0)
    return httpx.Client(timeout=timeout)


def _remote_context(caller_token: str | None = None) -> tuple[str, dict[str, str]] | None:
    creds = auth._supabase_credentials()
    if creds is None:
        return None
    supabase_url, api_key, service_key = creds
    if not service_key and not caller_token:
        return None
    headers = auth._build_profile_headers(
        api_key=api_key,
        service_key=service_key,
        caller_token=caller_token or "",
    )
    return supabase_url, headers


def is_durable_enabled(caller_token: str | None = None) -> bool:
    return _remote_context(caller_token=caller_token) is not None


def clear_memory_jobs() -> None:
    """Test helper to simulate a process restart losing volatile memory."""
    with _MEMORY_LOCK:
        _MEMORY_JOBS.clear()
        _LOCAL_ACTIVE_JOBS.clear()


def _serialize_db_patch(patch: dict[str, Any]) -> dict[str, Any]:
    allowed = {
        "job_id",
        "scheduling_scope_id",
        "revision_id",
        "revision_version",
        "policy_snapshot_id",
        "semester_label",
        "state",
        "progress",
        "outcome",
        "raw_status",
        "termination_reason",
        "proven_infeasible",
        "conflicts",
        "stats",
        "validation",
        "report",
        "rows",
        "service_rows",
        "source_contract",
        "workbook_storage_path",
        "error",
        "created_by",
        "updated_at",
    }
    payload: dict[str, Any] = {}
    for key, value in patch.items():
        if key in allowed:
            payload[key] = value
    # Preserve `soft_metrics` inside `report` without requiring an extra column.
    if "soft_metrics" in patch and patch["soft_metrics"] is not None:
        report_obj = dict(payload.get("report") or {})
        report_obj["_soft_metrics"] = patch["soft_metrics"]
        payload["report"] = report_obj
    return payload


def _hydrate_job_row(row: dict[str, Any]) -> dict[str, Any]:
    report = dict(row.get("report") or {}) if isinstance(row.get("report"), dict) else None
    soft_metrics = None
    if report is not None and "_soft_metrics" in report:
        soft_metrics = report.pop("_soft_metrics")
    elif isinstance(row.get("validation"), dict):
        soft_metrics = row["validation"].get("soft_metrics")

    job: dict[str, Any] = {
        "job_id": row["job_id"],
        "state": row.get("state", "queued"),
        "progress": float(row.get("progress") or 0.0),
        "scheduling_scope_id": row.get("scheduling_scope_id"),
        "revision_id": row.get("revision_id"),
        "revision_version": row.get("revision_version"),
        "policy_snapshot_id": row.get("policy_snapshot_id"),
        "semester_label": row.get("semester_label"),
        "outcome": row.get("outcome"),
        "raw_status": row.get("raw_status"),
        "termination_reason": row.get("termination_reason"),
        "proven_infeasible": bool(row.get("proven_infeasible", False)),
        "conflicts": row.get("conflicts") or [],
        "stats": row.get("stats"),
        "validation": row.get("validation"),
        "soft_metrics": soft_metrics,
        "report": report,
        "rows": row.get("rows"),
        "service_rows": row.get("service_rows"),
        "source_contract": row.get("source_contract"),
        "workbook_storage_path": row.get("workbook_storage_path"),
        "error": row.get("error"),
        "created_by": row.get("created_by"),
        "created_at": row.get("created_at"),
        "updated_at": row.get("updated_at"),
    }
    if job["state"] == "failed" and job.get("outcome"):
        job["structured_terminal"] = True
    return {k: v for k, v in job.items() if v is not None or k in {"state", "progress", "proven_infeasible", "conflicts"}}


def _postgrest_upsert(
    row_payload: dict[str, Any],
    *,
    caller_token: str | None = None,
) -> bool:
    ctx = _remote_context(caller_token=caller_token)
    if ctx is None:
        return False
    supabase_url, base_headers = ctx
    headers = {
        **base_headers,
        "Content-Type": "application/json",
        "Prefer": "resolution=merge-duplicates,return=minimal",
    }
    try:
        with _http_client() as client:
            resp = client.post(
                f"{supabase_url}/rest/v1/solver_jobs",
                params={"on_conflict": "job_id"},
                headers=headers,
                json=row_payload,
            )
            if resp.status_code not in (200, 201, 204):
                logger.warning(
                    "solver_jobs upsert failed (%s): %s",
                    resp.status_code,
                    resp.text[:240],
                )
                return False
            return True
    except Exception as exc:  # noqa: BLE001 — degrade safely to memory cache
        logger.warning("solver_jobs upsert exception: %s", exc)
        return False


def _postgrest_patch(
    job_id: str,
    patch_payload: dict[str, Any],
    *,
    caller_token: str | None = None,
) -> bool:
    ctx = _remote_context(caller_token=caller_token)
    if ctx is None or not patch_payload:
        return False
    supabase_url, base_headers = ctx
    headers = {
        **base_headers,
        "Content-Type": "application/json",
        "Prefer": "return=minimal",
    }
    try:
        with _http_client() as client:
            resp = client.patch(
                f"{supabase_url}/rest/v1/solver_jobs",
                params={"job_id": f"eq.{job_id}"},
                headers=headers,
                json=patch_payload,
            )
            if resp.status_code not in (200, 204):
                logger.warning(
                    "solver_jobs patch failed (%s): %s",
                    resp.status_code,
                    resp.text[:240],
                )
                return False
            return True
    except Exception as exc:  # noqa: BLE001
        logger.warning("solver_jobs patch exception: %s", exc)
        return False


def create_job(
    job_id: str,
    *,
    scheduling_scope_id: str | None = None,
    revision_id: str | None = None,
    revision_version: int | None = None,
    policy_snapshot_id: str | None = None,
    semester_label: str | None = None,
    created_by: str | None = None,
    caller_token: str | None = None,
) -> dict[str, Any]:
    now = _now_iso()
    record: dict[str, Any] = {
        "job_id": job_id,
        "state": "queued",
        "progress": 0.0,
        "proven_infeasible": False,
        "conflicts": [],
        "created_at": now,
        "updated_at": now,
        "_last_persisted_progress": 0.0,
    }
    if scheduling_scope_id:
        record["scheduling_scope_id"] = scheduling_scope_id
    if revision_id:
        record["revision_id"] = revision_id
    if revision_version is not None:
        record["revision_version"] = int(revision_version)
    if policy_snapshot_id:
        record["policy_snapshot_id"] = policy_snapshot_id
    if semester_label:
        record["semester_label"] = semester_label
    if created_by:
        record["created_by"] = created_by

    with _MEMORY_LOCK:
        _MEMORY_JOBS[job_id] = record
        _evict_old_memory_jobs()

    db_payload = _serialize_db_patch(record)
    _postgrest_upsert(db_payload, caller_token=caller_token)
    return record


def touch_heartbeat(
    job_id: str,
    *,
    caller_token: str | None = None,
) -> None:
    """Refresh updated_at in memory and Postgres while a long solve is running."""
    now = _now_iso()
    with _MEMORY_LOCK:
        existing = _MEMORY_JOBS.get(job_id)
        if existing is None or existing.get("state") not in _NON_TERMINAL_STATES:
            return
        existing["updated_at"] = now
    _postgrest_patch(job_id, {"updated_at": now}, caller_token=caller_token)


def update_job(
    job_id: str,
    patch: dict[str, Any],
    *,
    caller_token: str | None = None,
    force_remote: bool = True,
) -> None:
    should_persist = force_remote
    with _MEMORY_LOCK:
        existing = _MEMORY_JOBS.setdefault(
            job_id,
            {"job_id": job_id, "state": "queued", "progress": 0.0},
        )
        prev_state = existing.get("state")
        prev_persisted = float(existing.get("_last_persisted_progress") or 0.0)
        existing.update(patch)
        existing["updated_at"] = _now_iso()
        new_state = existing.get("state")
        new_progress = float(existing.get("progress") or 0.0)
        if not should_persist:
            should_persist = (
                new_state != prev_state
                or abs(new_progress - prev_persisted) >= _PROGRESS_PATCH_MIN_DELTA
            )
        if should_persist:
            existing["_last_persisted_progress"] = new_progress
        soft_metrics_snapshot = (
            patch.get("soft_metrics")
            if "soft_metrics" in patch
            else existing.get("soft_metrics")
        )
        report_snapshot = (
            patch.get("report") if "report" in patch else existing.get("report")
        )

    if not should_persist:
        return

    db_patch_input = dict(patch)
    if "soft_metrics" in db_patch_input and "report" not in db_patch_input and report_snapshot is not None:
        db_patch_input["report"] = report_snapshot
    if "report" in db_patch_input and "soft_metrics" not in db_patch_input and soft_metrics_snapshot is not None:
        db_patch_input["soft_metrics"] = soft_metrics_snapshot

    db_payload = _serialize_db_patch(db_patch_input)
    _postgrest_patch(job_id, db_payload, caller_token=caller_token)


def save_workbook(
    job_id: str,
    xlsx_bytes: bytes,
    *,
    caller_token: str | None = None,
) -> str | None:
    storage_path = f"solver_jobs/{job_id}.xlsx"
    with _MEMORY_LOCK:
        existing = _MEMORY_JOBS.setdefault(job_id, {"job_id": job_id})
        existing["file"] = xlsx_bytes

    ctx = _remote_context(caller_token=caller_token)
    if ctx is None:
        return None
    supabase_url, base_headers = ctx
    headers = {
        **base_headers,
        "Content-Type": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        "x-upsert": "true",
    }
    try:
        with _http_client() as client:
            resp = client.post(
                f"{supabase_url}/storage/v1/object/{_WORKBOOK_BUCKET}/{storage_path}",
                headers=headers,
                content=xlsx_bytes,
            )
            if resp.status_code not in (200, 201):
                logger.warning(
                    "Storage workbook upload failed (%s): %s",
                    resp.status_code,
                    resp.text[:240],
                )
                return None
    except Exception as exc:  # noqa: BLE001
        logger.warning("Storage workbook upload exception: %s", exc)
        return None

    with _MEMORY_LOCK:
        _MEMORY_JOBS[job_id]["workbook_storage_path"] = storage_path
        # Once durably stored in Supabase Storage, drop raw bytes from RAM to keep RSS low.
        _MEMORY_JOBS[job_id].pop("file", None)
    return storage_path


def get_job_status(
    job_id: str,
    *,
    caller_token: str | None = None,
) -> dict[str, Any] | None:
    """Lightweight status lookup (never selects multi-MB rows/report JSONB blobs)."""
    with _MEMORY_LOCK:
        cached = _MEMORY_JOBS.get(job_id)
        if cached is not None:
            snapshot = dict(cached)
        else:
            snapshot = None

    if snapshot is not None:
        return _maybe_mark_orphaned_job(snapshot, caller_token=caller_token)

    ctx = _remote_context(caller_token=caller_token)
    if ctx is None:
        return None
    supabase_url, headers = ctx
    try:
        with _http_client() as client:
            resp = client.get(
                f"{supabase_url}/rest/v1/solver_jobs",
                params={"job_id": f"eq.{job_id}", "select": SOLVER_JOB_STATUS_COLUMNS, "limit": "1"},
                headers=headers,
            )
            if resp.status_code != 200:
                return None
            rows = resp.json()
            if not isinstance(rows, list) or not rows:
                return None
            hydrated = _hydrate_job_row(rows[0])
            return _maybe_mark_orphaned_job(hydrated, caller_token=caller_token)
    except Exception as exc:  # noqa: BLE001
        logger.warning("solver_jobs status get failed: %s", exc)
        return None


def get_job(
    job_id: str,
    *,
    caller_token: str | None = None,
) -> dict[str, Any] | None:
    with _MEMORY_LOCK:
        cached = _MEMORY_JOBS.get(job_id)
        if cached is not None:
            snapshot = dict(cached)
        else:
            snapshot = None

    if snapshot is not None:
        return _maybe_mark_orphaned_job(snapshot, caller_token=caller_token)

    ctx = _remote_context(caller_token=caller_token)
    if ctx is None:
        return None
    supabase_url, headers = ctx
    try:
        with _http_client() as client:
            resp = client.get(
                f"{supabase_url}/rest/v1/solver_jobs",
                params={"job_id": f"eq.{job_id}", "select": SOLVER_JOB_COLUMNS, "limit": "1"},
                headers=headers,
            )
            if resp.status_code != 200:
                return None
            rows = resp.json()
            if not isinstance(rows, list) or not rows:
                return None
            hydrated = _hydrate_job_row(rows[0])
            checked = _maybe_mark_orphaned_job(hydrated, caller_token=caller_token)
            with _MEMORY_LOCK:
                _MEMORY_JOBS[job_id] = checked
                _evict_old_memory_jobs()
            return dict(checked)
    except Exception as exc:  # noqa: BLE001
        logger.warning("solver_jobs get failed: %s", exc)
        return None


def get_workbook(
    job_id: str,
    *,
    caller_token: str | None = None,
) -> tuple[bytes | None, dict[str, Any] | None]:
    job = get_job(job_id, caller_token=caller_token)
    if job is None:
        return None, None

    cached_bytes = job.get("file")
    if isinstance(cached_bytes, (bytes, bytearray)):
        return bytes(cached_bytes), job

    storage_path = job.get("workbook_storage_path")
    if not storage_path:
        return None, job

    ctx = _remote_context(caller_token=caller_token)
    if ctx is None:
        return None, job
    supabase_url, headers = ctx
    try:
        with _http_client() as client:
            resp = client.get(
                f"{supabase_url}/storage/v1/object/{_WORKBOOK_BUCKET}/{storage_path}",
                headers=headers,
            )
            if resp.status_code != 200:
                logger.warning(
                    "Storage workbook download failed (%s) for %s",
                    resp.status_code,
                    storage_path,
                )
                return None, job
            data = resp.content
            with _MEMORY_LOCK:
                if job_id in _MEMORY_JOBS:
                    _MEMORY_JOBS[job_id]["file"] = data
            return data, job
    except Exception as exc:  # noqa: BLE001
        logger.warning("Storage workbook download exception: %s", exc)
        return None, job


def list_jobs(
    *,
    revision_id: str | None = None,
    scheduling_scope_id: str | None = None,
    limit: int = 20,
    caller_token: str | None = None,
) -> list[dict[str, Any]]:
    bounded_limit = max(1, min(int(limit or 20), 100))
    ctx = _remote_context(caller_token=caller_token)
    if ctx is not None:
        supabase_url, headers = ctx
        params: dict[str, str] = {
            "select": SOLVER_JOB_SUMMARY_COLUMNS,
            "order": "created_at.desc",
            "limit": str(bounded_limit),
        }
        if revision_id:
            params["revision_id"] = f"eq.{revision_id}"
        if scheduling_scope_id:
            params["scheduling_scope_id"] = f"eq.{scheduling_scope_id}"
        try:
            with _http_client() as client:
                resp = client.get(
                    f"{supabase_url}/rest/v1/solver_jobs",
                    params=params,
                    headers=headers,
                )
                if resp.status_code == 200:
                    raw_rows = resp.json()
                    if isinstance(raw_rows, list):
                        return [_to_summary(row) for row in raw_rows]
        except Exception as exc:  # noqa: BLE001
            logger.warning("solver_jobs list failed: %s", exc)

    with _MEMORY_LOCK:
        items = list(_MEMORY_JOBS.values())
    if revision_id:
        items = [j for j in items if j.get("revision_id") == revision_id]
    if scheduling_scope_id:
        items = [j for j in items if j.get("scheduling_scope_id") == scheduling_scope_id]
    items.sort(key=lambda j: str(j.get("created_at") or ""), reverse=True)
    return [_to_summary(item) for item in items[:bounded_limit]]


def _to_summary(row: dict[str, Any]) -> dict[str, Any]:
    return {
        "job_id": row.get("job_id"),
        "state": row.get("state", "queued"),
        "progress": float(row.get("progress") or 0.0),
        "outcome": row.get("outcome"),
        "raw_status": row.get("raw_status"),
        "termination_reason": row.get("termination_reason"),
        "proven_infeasible": bool(row.get("proven_infeasible", False)),
        "scheduling_scope_id": row.get("scheduling_scope_id"),
        "revision_id": row.get("revision_id"),
        "revision_version": row.get("revision_version"),
        "policy_snapshot_id": row.get("policy_snapshot_id"),
        "semester_label": row.get("semester_label"),
        "workbook_storage_path": row.get("workbook_storage_path"),
        "has_workbook": bool(row.get("file") is not None or row.get("workbook_storage_path")),
        "error": row.get("error"),
        "stats": row.get("stats"),
        "created_by": row.get("created_by"),
        "created_at": row.get("created_at"),
        "updated_at": row.get("updated_at"),
    }


def delete_job(job_id: str) -> None:
    """Drop an in-memory entry when thread creation fails before launch."""
    with _MEMORY_LOCK:
        _MEMORY_JOBS.pop(job_id, None)
