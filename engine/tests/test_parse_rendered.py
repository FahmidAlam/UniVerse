"""Phase 3B rendered-workbook parser parity & security guard tests.

Mirrors test/routine_workbook_parser_test.dart plus negative security tests
(401, 403, 400 non-xlsx/corrupt/macro/encrypted, 413 oversized/ZIP-bomb, 429 rate-limit).
"""

from __future__ import annotations

import io
import json
import sys
import xml.sax.saxutils as saxutils
import zipfile
from pathlib import Path

import pytest
from fastapi import HTTPException
from fastapi.testclient import TestClient

ENGINE_DIR = Path(__file__).resolve().parents[1]
if str(ENGINE_DIR) not in sys.path:
    sys.path.insert(0, str(ENGINE_DIR))

import auth  # noqa: E402
import main  # noqa: E402
import parse_rendered  # noqa: E402
import security_guards  # noqa: E402


# ---------------------------------------------------------------------------
# Synthetic OOXML fixture builders (mirroring test/routine_workbook_parser_test.dart)
# ---------------------------------------------------------------------------


def _text(ref: str, value: str) -> str:
    return f'<c r="{ref}" t="inlineStr"><is><t>{saxutils.escape(value)}</t></is></c>'


def _workbook(
    sheet: str,
    rows: str,
    *,
    shared_header: str | None = None,
    extra_files: dict[str, bytes] | None = None,
) -> bytes:
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        shared_ct = (
            '<Override PartName="/xl/sharedStrings.xml" '
            'ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/>'
            if shared_header is not None
            else ""
        )
        zf.writestr(
            "[Content_Types].xml",
            f'<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
            f'<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
            f'<Default Extension="xml" ContentType="application/xml"/>'
            f'<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
            f'<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
            f'<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
            f"{shared_ct}</Types>",
        )
        zf.writestr(
            "_rels/.rels",
            '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
            '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
            "</Relationships>",
        )
        zf.writestr(
            "xl/workbook.xml",
            f'<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
            f'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
            f'<sheets><sheet name="{saxutils.escape(sheet)}" sheetId="1" r:id="rId1"/></sheets></workbook>',
        )
        shared_rel = (
            '<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings" Target="sharedStrings.xml"/>'
            if shared_header is not None
            else ""
        )
        zf.writestr(
            "xl/_rels/workbook.xml.rels",
            '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
            '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>'
            '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
            f"{shared_rel}</Relationships>",
        )
        zf.writestr(
            "xl/styles.xml",
            '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
            '<fonts count="1"><font/></fonts><fills count="1"><fill><patternFill patternType="none"/></fill></fills>'
            '<borders count="1"><border/></borders><cellStyleXfs count="1"><xf/></cellStyleXfs>'
            '<cellXfs count="2"><xf numFmtId="0"/><xf numFmtId="18" applyNumberFormat="1"/></cellXfs></styleSheet>',
        )
        if shared_header is not None:
            zf.writestr(
                "xl/sharedStrings.xml",
                f'<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="1" uniqueCount="1">'
                f"<si><t>{saxutils.escape(shared_header)}</t></si></sst>",
            )
        zf.writestr(
            "xl/worksheets/sheet1.xml",
            f'<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>{rows}</sheetData></worksheet>',
        )
        for path, data in (extra_files or {}).items():
            zf.writestr(path, data)
    return buf.getvalue()


def _day(
    header: str | None,
    *,
    sheet: str = "Sunday",
    shared: bool = False,
    teacher: str = "SYN",
    col: str = "D",
    extra_rows: str = "",
) -> bytes:
    header_cell = (
        ""
        if header is None
        else (f'<c r="{col}2" t="s"><v>0</v></c>' if shared else _text(f"{col}2", header))
    )
    rows = (
        f'<row r="2">{_text("B2", "Batch")}{_text("C2", "Section")}{header_cell}</row>'
        f'<row r="3">{_text("B3", "66")}{_text("C3", "B+C")}'
        f'{_text(f"{col}3", f"CSE-1101 {teacher} ROOM-1")}</row>'
        f"{extra_rows}"
    )
    return _workbook(sheet, rows, shared_header=header if shared else None)


def _tabular(start: str, end: str, *, numeric: bool = False) -> bytes:
    headers = ["Day", "Batch", "Section", "Course Code", "Teacher", "Room", "Start", "End", "Semester"]
    values = ["Sunday", "66", "B+C", "CSE-1101", "SYN", "ROOM-1"]
    h_xml = "".join(_text(f"{chr(65 + i)}1", h) for i, h in enumerate(headers))
    v_xml = "".join(_text(f"{chr(65 + i)}2", v) for i, v in enumerate(values))
    s_cell = f'<c r="G2" s="1"><v>{start}</v></c>' if numeric else _text("G2", start)
    e_cell = f'<c r="H2" s="1"><v>{end}</v></c>' if numeric else _text("H2", end)
    return _workbook(
        "Assignments",
        f'<row r="1">{h_xml}</row><row r="2">{v_xml}{s_cell}{e_cell}{_text("I2", "3")}</row>',
    )


def _pair(
    first_group: str,
    second_group: str,
    *,
    second_start: str = "09:30",
    second_end: str = "10:30",
    second_teacher: str = "SYN",
    second_room: str = "ROOM-1",
    first_room: str = "ROOM-1",
) -> bytes:
    headers = ["Day", "Batch", "Section", "Course Code", "Teacher", "Room", "Start", "End"]
    values = [
        ["Sunday", "66", first_group, "CSE-1101", "SYN", first_room, "09:00", "10:00"],
        ["Sunday", "66", second_group, "CSE-1201", second_teacher, second_room, second_start, second_end],
    ]
    h_xml = "".join(_text(f"{chr(65 + i)}1", h) for i, h in enumerate(headers))
    r_xml = "".join(
        f'<row r="{r + 2}">'
        + "".join(_text(f"{chr(65 + c)}{r + 2}", val) for c, val in enumerate(row))
        + "</row>"
        for r, row in enumerate(values)
    )
    return _workbook("Assignments", f'<row r="1">{h_xml}</row>{r_xml}')


@pytest.fixture(autouse=True)
def _reset_state(monkeypatch: pytest.MonkeyPatch):
    auth.set_token_verifier(None)
    auth.clear_verification_cache()
    main.GENERATE_RATE_LIMITER.reset()
    main.PARSE_RATE_LIMITER.reset()
    main.SOLVE_CONCURRENCY_GUARD.reset()
    monkeypatch.delenv("ENGINE_AUTH_MODE", raising=False)
    yield
    auth.set_token_verifier(None)
    auth.clear_verification_cache()
    main.GENERATE_RATE_LIMITER.reset()
    main.PARSE_RATE_LIMITER.reset()
    main.SOLVE_CONCURRENCY_GUARD.reset()


# ---------------------------------------------------------------------------
# 1. Dart RoutineWorkbookParser Parity Tests
# ---------------------------------------------------------------------------


def test_explicit_faculty_name_without_acronym_detects_clash():
    rows_xml = (
        f'<row r="1">{_text("A1", "Day")}{_text("B1", "Batch")}{_text("C1", "Section")}'
        f'{_text("D1", "Course Code")}{_text("E1", "Teacher Name")}{_text("F1", "Room")}'
        f'{_text("G1", "Start")}{_text("H1", "End")}</row>'
        f'<row r="2">{_text("A2", "Sunday")}{_text("B2", "66")}{_text("C2", "A")}'
        f'{_text("D2", "CSE-1101")}{_text("E2", "Same Person")}{_text("F2", "ROOM-2")}'
        f'{_text("G2", "09:00")}{_text("H2", "10:00")}</row>'
        f'<row r="3">{_text("A3", "Sunday")}{_text("B3", "66")}{_text("C3", "B")}'
        f'{_text("D3", "CSE-1201")}{_text("E3", "Same Person")}{_text("F3", "ROOM-3")}'
        f'{_text("G3", "09:00")}{_text("H3", "10:00")}</row>'
    )
    result = parse_rendered.parse_rendered_workbook(_workbook("Assignments", rows_xml))
    assert len(result["rows"]) == 2
    assert result["rows"][0]["teacher_code"] is None
    assert result["validation"]["teacher_clashes"] == 1
    assert result["validation"]["pending_faculty_assignments"] == 0
    assert result["validation"]["unresolved_faculty_names"] == 2
    assert result["validation"]["ok"] is False


def test_blank_faculty_retains_retake_row_and_marks_pending():
    rows_xml = (
        f'<row r="1">{_text("A1", "Day")}{_text("B1", "Batch")}{_text("C1", "Section")}'
        f'{_text("D1", "Course Code")}{_text("E1", "Teacher")}{_text("F1", "Room")}'
        f'{_text("G1", "Start")}{_text("H1", "End")}</row>'
        f'<row r="2">{_text("A2", "Sunday")}{_text("B2", "Retake")}{_text("C2", "A")}'
        f'{_text("D2", "CSE-1101")}{_text("F2", "ROOM-1")}{_text("G2", "09:00")}{_text("H2", "10:00")}</row>'
    )
    result = parse_rendered.parse_rendered_workbook(_workbook("Assignments", rows_xml))
    assert len(result["rows"]) == 1
    assert result["rows"][0]["teacher_code"] is None
    assert result["rows"][0]["room"] == "ROOM-1"
    assert result["validation"]["pending_faculty_assignments"] == 1
    assert result["validation"]["ok"] is True


def test_reversed_clocks_and_pending_marker_parity():
    rev = parse_rendered.parse_rendered_workbook(_day("11:10-12:15AM"))
    assert len(rev["rows"]) == 1
    assert rev["rows"][0]["time_start"] == "11:10:00"
    assert rev["rows"][0]["time_end"] == "00:15:00"
    assert rev["validation"]["invalid_time_slots"] == 1
    assert rev["validation"]["ok"] is False

    pending = parse_rendered.parse_rendered_workbook(_day("09:00-10:00AM", teacher="FACULTY-PENDING"))
    assert pending["rows"][0]["teacher_code"] is None
    assert pending["rows"][0]["teacher_state"] == "pending"
    assert pending["validation"]["pending_faculty_assignments"] == 1
    assert pending["validation"]["ok"] is True


def test_room_aliases_footer_unavailable_rooms_and_cycle_guard():
    # Config alias collides RAB-106 with phy lab
    data = _pair("A", "B", first_room="RAB-106", second_room="phy lab", second_teacher="OTHER")
    res = parse_rendered.parse_rendered_workbook(data, config={"room_aliases": {"PHY LAB": "RAB-106"}})
    assert res["validation"]["room_clashes"] == 1
    assert res["validation"]["ok"] is False

    # Room Alias: footer on day sheet also resolves aliases
    footer_wb = _day(
        "09:00-10:00AM",
        extra_rows=(
            f'<row r="4">{_text("B4", "65")}{_text("C4", "A")}'
            f'{_text("D4", "CSE-2101 OTHER PHY LAB")}</row>'
            f'<row r="6">{_text("B6", "Room Alias: PHY LAB = ROOM-1")}</row>'
        ),
    )
    footer_res = parse_rendered.parse_rendered_workbook(footer_wb)
    assert footer_res["validation"]["room_clashes"] == 1

    # Cyclic aliases never crash (graceful warning fallback)
    cyc = parse_rendered.parse_rendered_workbook(
        data,
        config={"room_aliases": {"A": "B", "B": "A", "PHY LAB": "A"}},
    )
    assert any("cyclic" in w.lower() for w in cyc["warnings"])

    # Unavailable room flagged
    fac_wb = _pair("A", "B", first_room="RAB-104", second_room="ROOM-2", second_teacher="OTHER")
    assert parse_rendered.parse_rendered_workbook(fac_wb)["validation"]["ok"] is True
    unavail = parse_rendered.parse_rendered_workbook(
        fac_wb, config={"unavailable_rooms": ["rab-104"]}
    )
    assert unavail["validation"]["unavailable_room_assignments"] == 1
    assert unavail["validation"]["ok"] is False

    # TBA rooms never collide with each other
    tba_wb = _pair("A", "B", first_room="TBA", second_room="TBA", second_teacher="OTHER")
    assert parse_rendered.parse_rendered_workbook(tba_wb)["validation"]["room_clashes"] == 0


def test_overlaps_joint_sections_and_adjacent_intervals():
    overlap = parse_rendered.parse_rendered_workbook(_pair("A", "B"))["validation"]
    assert overlap["teacher_clashes"] == 1
    assert overlap["room_clashes"] == 1
    assert overlap["ok"] is False

    joint = parse_rendered.parse_rendered_workbook(
        _pair("B+C", "C", second_teacher="OTHER", second_room="ROOM-2")
    )["validation"]
    assert joint["cohort_clashes"] == 1
    assert joint["ok"] is False

    adjacent = parse_rendered.parse_rendered_workbook(
        _pair("A", "A", second_start="10:00", second_end="11:00")
    )["validation"]
    assert adjacent["ok"] is True


@pytest.mark.parametrize(
    ("wb_bytes", "exp_start", "exp_end"),
    [
        (_day("11:10-12:15PM", shared=True), "11:10:00", "12:15:00"),
        (_day("11:10-12:15 PM"), "11:10:00", "12:15:00"),
        (_tabular("11:10 AM", "12:15 PM"), "11:10:00", "12:15:00"),
        (_day("9:10-10:15PM"), "21:10:00", "22:15:00"),
        (_day("12:10-1:15 AM"), "00:10:00", "01:15:00"),
        (_day("(9:10-10:15 PM)"), "21:10:00", "22:15:00"),
        (_day("(12:10-1:15 AM)"), "00:10:00", "01:15:00"),
        (_day("11:10-12:15 p.m."), "11:10:00", "12:15:00"),
        (_tabular("0.25", "7:00 AM"), "06:00:00", "07:00:00"),
        (_tabular("06:10:00", "7:15 AM"), "06:10:00", "07:15:00"),
        (_tabular("0.5", "0.5520833333333334", numeric=True), "12:00:00", "13:15:00"),
        (_tabular("13:10:00", "14:25:00"), "13:10:00", "14:25:00"),
        (_tabular("06:10:00", "07:15:00"), "06:10:00", "07:15:00"),
    ],
)
def test_source_preserving_workbook_clocks_match_dart(wb_bytes: bytes, exp_start: str, exp_end: str):
    row = parse_rendered.parse_rendered_workbook(wb_bytes)["rows"][0]
    assert row["time_start"] == exp_start
    assert row["time_end"] == exp_end


def test_afternoon_sequence_repair_and_conflicting_grid_warning():
    # Missing PM marker in config periods gets repaired forward
    repaired = parse_rendered.clock_repair_sequence([
        ("08:50:00", "10:05:00"),
        ("11:20:00", "12:35:00"),
        ("01:10:00", "02:25:00"),
    ])
    assert repaired[2] == ("13:10:00", "14:25:00")

    winter = {"settings": {"periods": [{"idx": 1, "col": "D", "start": "09:00", "end": "10:05"}]}}
    res = parse_rendered.parse_rendered_workbook(_day("08:30-09:45AM"), config=winter)
    assert res["rows"][0]["time_start"] == "08:30:00"
    assert res["rows"][0]["time_end"] == "09:45:00"
    assert any("09:00:00-10:05:00" in w and "workbook time retained" in w for w in res["warnings"])


def test_service_rows_subject_titles_and_friday_p4_jummah():
    # Non-CSE batch goes to service_rows; subject_titles enriches title
    rows_xml = (
        f'<row r="1">{_text("A1", "Day")}{_text("B1", "Batch")}{_text("C1", "Section")}'
        f'{_text("D1", "Course Code")}{_text("E1", "Teacher")}{_text("F1", "Room")}'
        f'{_text("G1", "Start")}{_text("H1", "End")}</row>'
        f'<row r="2">{_text("A2", "Sunday")}{_text("B2", "66")}{_text("C2", "A")}'
        f'{_text("D2", "CSE-1101")}{_text("E2", "EBH")}{_text("F2", "RAB-302")}'
        f'{_text("G2", "08:50")}{_text("H2", "10:05")}</row>'
        f'<row r="3">{_text("A3", "Sunday")}{_text("B3", "BBA")}{_text("C3", "A")}'
        f'{_text("D3", "CSE-1199")}{_text("E3", "MSR")}{_text("F3", "RAB-305")}'
        f'{_text("G3", "08:50")}{_text("H3", "10:05")}</row>'
    )
    res = parse_rendered.parse_rendered_workbook(
        _workbook("Assignments", rows_xml),
        subject_titles={"CSE-1101": "Structured Programming"},
    )
    assert len(res["rows"]) == 1
    assert res["rows"][0]["subject"] == "Structured Programming"
    assert len(res["service_rows"]) == 1
    assert res["service_rows"][0]["is_service"] is True
    assert res["service_rows"][0]["batch"] == "BBA"

    # Friday P4 Jummah check
    fri_wb = _day("1:10-2:25PM", sheet="Friday", col="H")
    fri_res = parse_rendered.parse_rendered_workbook(fri_wb)
    assert fri_res["validation"]["blocked_period_violations"] == 1
    assert fri_res["validation"]["ok"] is False


# ---------------------------------------------------------------------------
# 2. FastAPI Endpoint & Security Guard Negative Tests (401/403/400/413/429)
# ---------------------------------------------------------------------------


def test_parse_endpoint_enforces_401_and_403_and_allows_admin(monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setenv("ENGINE_AUTH_MODE", "enforced")

    def fake_verifier(token: str) -> auth.VerifiedCaller:
        if token == "admin-jwt":
            return auth.VerifiedCaller(user_id="admin-1", role="admin")
        if token == "student-jwt":
            return auth.VerifiedCaller(user_id="student-1", role="student")
        raise HTTPException(status_code=401, detail="Invalid token.")

    auth.set_token_verifier(fake_verifier)
    client = TestClient(main.app)
    valid_bytes = _day("08:50-10:05AM")

    # 401 unauthenticated
    r401 = client.post(
        "/api/timetable/parse-rendered-workbook",
        files={"file": ("routine.xlsx", valid_bytes, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")},
    )
    assert r401.status_code == 401

    # 403 non-admin
    r403 = client.post(
        "/api/timetable/parse-rendered-workbook",
        headers={"Authorization": "Bearer student-jwt"},
        files={"file": ("routine.xlsx", valid_bytes, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")},
    )
    assert r403.status_code == 403

    # 200 admin with subject_titles & config
    r200 = client.post(
        "/api/timetable/parse-rendered-workbook",
        headers={"Authorization": "Bearer admin-jwt"},
        files={"file": ("routine.xlsx", valid_bytes, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")},
        data={"subject_titles": json.dumps({"CSE-1101": "Intro to CS"})},
    )
    assert r200.status_code == 200
    body = r200.json()
    assert body["detected_format"] == "UniVerse day sheets"
    assert body["sheet_names"] == ["Sunday"]
    assert body["rows"][0]["subject"] == "Intro to CS"
    assert body["validation"]["ok"] is True
    assert main.JOBS == {}  # Strictly non-mutating


def test_security_guards_reject_malformed_macro_encrypted_oversized_and_zip_bomb():
    client = TestClient(main.app)
    mime = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"

    # Non-.xlsx filename -> 400
    r_ext = client.post(
        "/api/timetable/parse-rendered-workbook",
        files={"file": ("routine.xlsm", _day("08:50-10:05AM"), mime)},
    )
    assert r_ext.status_code == 400

    # Bad magic bytes / corrupt -> 400
    r_corrupt = client.post(
        "/api/timetable/parse-rendered-workbook",
        files={"file": ("routine.xlsx", b"not-a-zip-file", mime)},
    )
    assert r_corrupt.status_code == 400

    # Macro-bearing xl/vbaProject.bin -> 400
    macro_bytes = _workbook(
        "Sunday",
        f'<row r="2">{_text("B2", "Batch")}</row>',
        extra_files={"xl/vbaProject.bin": b"fake-macro-binary"},
    )
    r_macro = client.post(
        "/api/timetable/parse-rendered-workbook",
        files={"file": ("macro.xlsx", macro_bytes, mime)},
    )
    assert r_macro.status_code == 400
    assert "macro" in r_macro.json()["detail"].lower()

    # Encrypted OLE2 header -> 400
    r_ole2 = client.post(
        "/api/timetable/parse-rendered-workbook",
        files={"file": ("encrypted.xlsx", b"\xd0\xcf\x11\xe0\xa1\xb1\x1a\xe1" + b"\x00" * 64, mime)},
    )
    assert r_ole2.status_code == 400

    # Oversized compressed upload (> 15 MiB) -> 413
    with pytest.raises(HTTPException) as exc_big:
        security_guards.validate_xlsx_upload(
            "huge.xlsx", b"PK\x03\x04" + b"\x00" * 2048, max_compressed_bytes=1024
        )
    assert exc_big.value.status_code == 413

    # ZIP/XML bomb (high compression ratio) -> 413
    bomb_bytes = _workbook(
        "Sunday",
        f'<row r="2">{_text("B2", "Batch")}</row>',
        extra_files={"xl/worksheets/sheet2.xml": b"A" * (600 * 1024)},
    )
    r_bomb = client.post(
        "/api/timetable/parse-rendered-workbook",
        files={"file": ("bomb.xlsx", bomb_bytes, mime)},
    )
    assert r_bomb.status_code == 413


def test_parse_endpoint_rate_limiter_returns_429_with_retry_after(monkeypatch: pytest.MonkeyPatch):
    tight_limiter = security_guards.RateLimiter(max_requests=2, window_seconds=60, label="parse")
    monkeypatch.setattr(main, "PARSE_RATE_LIMITER", tight_limiter)

    client = TestClient(main.app)
    valid_bytes = _day("08:50-10:05AM")
    mime = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"

    assert client.post("/api/timetable/parse-rendered-workbook", files={"file": ("r.xlsx", valid_bytes, mime)}).status_code == 200
    assert client.post("/api/timetable/parse-rendered-workbook", files={"file": ("r.xlsx", valid_bytes, mime)}).status_code == 200

    r429 = client.post("/api/timetable/parse-rendered-workbook", files={"file": ("r.xlsx", valid_bytes, mime)})
    assert r429.status_code == 429
    assert "retry-after" in {k.lower() for k in r429.headers.keys()}
    assert int(r429.headers["Retry-After"]) >= 1
