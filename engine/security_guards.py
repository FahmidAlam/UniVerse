"""Zero-trust OOXML upload preflight, per-caller rate limiting, and concurrency guards."""

from __future__ import annotations

import io
import math
import os
import posixpath
import threading
import time
import zipfile
from collections import deque

from fastapi import HTTPException

# OOXML upload limits
MAX_XLSX_COMPRESSED_BYTES = 15 * 1024 * 1024       # 15 MiB
MAX_XLSX_UNCOMPRESSED_BYTES = 100 * 1024 * 1024    # 100 MiB
MAX_XLSX_COMPRESSION_RATIO = 100.0                 # Applied above RATIO_CHECK_MIN_UNCOMPRESSED_BYTES
RATIO_CHECK_MIN_UNCOMPRESSED_BYTES = 256 * 1024    # 256 KiB floor avoids false positives on tiny fixtures
MAX_XLSX_SHEETS = 100
MAX_XLSX_ENTRIES = 2000

_ZIP_MAGIC = b"PK\x03\x04"
_OLE2_MAGIC = b"\xd0\xcf\x11\xe0\xa1\xb1\x1a\xe1"

_FORBIDDEN_EXACT_FILENAMES = {
    "vbaproject.bin",
    "encryptedpackage",
    "encryptioninfo",
}

_FORBIDDEN_EMBEDDED_EXTENSIONS = {
    ".exe",
    ".dll",
    ".bat",
    ".cmd",
    ".ps1",
    ".vbs",
    ".vbe",
    ".js",
    ".jse",
    ".msi",
    ".scr",
    ".com",
    ".sh",
    ".jar",
    ".hta",
}


def _env_int(name: str, default: int, minimum: int = 1) -> int:
    raw = os.environ.get(name, "").strip()
    if not raw:
        return default
    try:
        return max(minimum, int(raw))
    except ValueError:
        return default


def _normalize_zip_member(name: str) -> str:
    return name.replace("\\", "/").strip()


def validate_xlsx_upload(
    filename: str | None,
    file_bytes: bytes,
    *,
    max_compressed_bytes: int = MAX_XLSX_COMPRESSED_BYTES,
    max_uncompressed_bytes: int = MAX_XLSX_UNCOMPRESSED_BYTES,
    max_compression_ratio: float = MAX_XLSX_COMPRESSION_RATIO,
    max_sheets: int = MAX_XLSX_SHEETS,
    max_entries: int = MAX_XLSX_ENTRIES,
) -> None:
    """Validate an untrusted `.xlsx` upload BEFORE any XML/openpyxl parser touches it.

    Raises:
        HTTPException(400): Non-`.xlsx`, malformed ZIP, encrypted/macro/executable payload,
            path traversal, or excessive worksheet count.
        HTTPException(413): Compressed size > 15 MiB, total uncompressed size > 100 MiB,
            or suspicious ZIP/XML bomb compression ratio.
    """
    clean_name = (filename or "").strip()
    if not clean_name or not clean_name.lower().endswith(".xlsx"):
        raise HTTPException(
            status_code=400,
            detail="Only standard .xlsx workbooks are accepted (macros and legacy .xls files are not supported).",
        )

    compressed_size = len(file_bytes)
    if compressed_size == 0:
        raise HTTPException(status_code=400, detail="Uploaded workbook is empty.")

    if compressed_size > max_compressed_bytes:
        limit_mb = max_compressed_bytes // (1024 * 1024)
        raise HTTPException(
            status_code=413,
            detail=f"Workbook exceeds the {limit_mb} MiB upload limit.",
        )

    if file_bytes.startswith(_OLE2_MAGIC):
        raise HTTPException(
            status_code=400,
            detail="Encrypted or legacy binary OLE2 workbooks are not supported. Upload an unencrypted .xlsx file.",
        )

    if not file_bytes.startswith(_ZIP_MAGIC):
        raise HTTPException(
            status_code=400,
            detail="File is not a valid .xlsx OOXML archive (missing ZIP signature).",
        )

    try:
        zf = zipfile.ZipFile(io.BytesIO(file_bytes), "r")
    except (zipfile.BadZipFile, OSError) as exc:
        raise HTTPException(
            status_code=400,
            detail="Uploaded .xlsx archive is corrupted or unreadable.",
        ) from exc

    with zf:
        infos = zf.infolist()
        if not infos:
            raise HTTPException(status_code=400, detail="Uploaded .xlsx archive contains no files.")

        if len(infos) > max_entries:
            raise HTTPException(
                status_code=413,
                detail=f"Workbook archive contains too many entries (limit {max_entries}).",
            )

        total_uncompressed = 0
        worksheet_count = 0
        has_workbook_xml = False

        for info in infos:
            member = _normalize_zip_member(info.filename)
            lower = member.lower()
            parts = [p for p in lower.split("/") if p]

            if member.startswith("/") or ".." in parts:
                raise HTTPException(
                    status_code=400,
                    detail="Workbook archive contains an unsafe entry path.",
                )

            # Check encryption flag bit 0 on ZIP entry
            if info.flag_bits & 0x1:
                raise HTTPException(
                    status_code=400,
                    detail="Password-protected or encrypted .xlsx archives are not supported.",
                )

            base_name = posixpath.basename(lower)
            if base_name in _FORBIDDEN_EXACT_FILENAMES or "vbaproject" in lower:
                if "encrypted" in base_name or "encryption" in base_name:
                    raise HTTPException(
                        status_code=400,
                        detail="Encrypted workbooks are not supported. Upload an unencrypted .xlsx file.",
                    )
                raise HTTPException(
                    status_code=400,
                    detail="Macro-enabled workbooks (vbaProject.bin) are rejected for security.",
                )

            if "/activex/" in f"/{lower}":
                raise HTTPException(
                    status_code=400,
                    detail="Workbooks containing ActiveX payloads are rejected for security.",
                )

            _, ext = posixpath.splitext(base_name)
            if ext in _FORBIDDEN_EMBEDDED_EXTENSIONS:
                raise HTTPException(
                    status_code=400,
                    detail=f"Workbook contains a forbidden embedded payload ({ext}).",
                )

            if lower.startswith("xl/embeddings/") and ext not in {"", ".xml", ".rels"}:
                raise HTTPException(
                    status_code=400,
                    detail="Workbooks with embedded binary objects are rejected for security.",
                )

            total_uncompressed += max(0, info.file_size)
            if total_uncompressed > max_uncompressed_bytes:
                limit_mb = max_uncompressed_bytes // (1024 * 1024)
                raise HTTPException(
                    status_code=413,
                    detail=f"Workbook uncompressed content exceeds the {limit_mb} MiB safety limit (possible XML/ZIP bomb).",
                )

            if info.file_size >= RATIO_CHECK_MIN_UNCOMPRESSED_BYTES:
                entry_comp = max(1, info.compress_size)
                if (info.file_size / entry_comp) > max_compression_ratio:
                    raise HTTPException(
                        status_code=413,
                        detail="Workbook compression ratio exceeds safety bounds (possible ZIP/XML bomb).",
                    )

            if lower == "xl/workbook.xml":
                has_workbook_xml = True
            elif lower.startswith("xl/worksheets/sheet") and lower.endswith(".xml"):
                worksheet_count += 1

        if total_uncompressed >= RATIO_CHECK_MIN_UNCOMPRESSED_BYTES:
            overall_ratio = total_uncompressed / max(1, compressed_size)
            if overall_ratio > max_compression_ratio:
                raise HTTPException(
                    status_code=413,
                    detail="Workbook overall compression ratio exceeds safety bounds (possible ZIP/XML bomb).",
                )

        if not has_workbook_xml:
            raise HTTPException(
                status_code=400,
                detail="Archive is missing xl/workbook.xml and is not a valid Excel .xlsx workbook.",
            )

        if worksheet_count > max_sheets:
            raise HTTPException(
                status_code=400,
                detail=f"Workbook exceeds the maximum supported worksheet limit ({max_sheets}).",
            )


class RateLimiter:
    """Thread-safe sliding-window per-caller rate limiter returning HTTP 429 + Retry-After."""

    def __init__(self, max_requests: int, window_seconds: float, label: str = "endpoint") -> None:
        self.max_requests = max(1, int(max_requests))
        self.window_seconds = max(1.0, float(window_seconds))
        self.label = label
        self._lock = threading.Lock()
        self._hits: dict[str, deque[float]] = {}

    def check(self, caller_key: str) -> None:
        now = time.monotonic()
        cutoff = now - self.window_seconds
        with self._lock:
            bucket = self._hits.setdefault(caller_key, deque())
            while bucket and bucket[0] <= cutoff:
                bucket.popleft()
            if len(bucket) >= self.max_requests:
                retry_after = max(1, math.ceil(self.window_seconds - (now - bucket[0])))
                raise HTTPException(
                    status_code=429,
                    detail=f"Rate limit exceeded for {self.label}. Please retry in {retry_after}s.",
                    headers={"Retry-After": str(retry_after)},
                )
            bucket.append(now)

    def reset(self) -> None:
        with self._lock:
            self._hits.clear()


class ConcurrencyGuard:
    """Thread-safe cap on concurrent heavy solver jobs (protects Render 512 MB RAM)."""

    def __init__(self, max_concurrent: int = 2) -> None:
        self.max_concurrent = max(1, int(max_concurrent))
        self._lock = threading.Lock()
        self._active = 0

    @property
    def active_count(self) -> int:
        with self._lock:
            return self._active

    def acquire_or_reject(self, retry_after_s: int = 15) -> None:
        with self._lock:
            if self._active >= self.max_concurrent:
                raise HTTPException(
                    status_code=429,
                    detail=(
                        f"Timetable engine is at maximum concurrent solve capacity "
                        f"({self.max_concurrent}). Please retry shortly."
                    ),
                    headers={"Retry-After": str(max(1, retry_after_s))},
                )
            self._active += 1

    def release(self) -> None:
        with self._lock:
            if self._active > 0:
                self._active -= 1

    def reset(self) -> None:
        with self._lock:
            self._active = 0


def build_default_guards() -> tuple[RateLimiter, RateLimiter, ConcurrencyGuard]:
    window_s = _env_int("RATE_LIMIT_WINDOW_S", 60)
    gen_limiter = RateLimiter(
        max_requests=_env_int("RATE_LIMIT_GENERATE_MAX", 10),
        window_seconds=window_s,
        label="timetable generation",
    )
    parse_limiter = RateLimiter(
        max_requests=_env_int("RATE_LIMIT_PARSE_MAX", 30),
        window_seconds=window_s,
        label="workbook parsing",
    )
    solve_concurrency = ConcurrencyGuard(
        max_concurrent=_env_int("MAX_CONCURRENT_SOLVES", 2),
    )
    return gen_limiter, parse_limiter, solve_concurrency
