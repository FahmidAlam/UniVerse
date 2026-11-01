"""Room identity keys and explicitly supplied per-run usage policy.

No historical room-purpose or semester rule is a permanent default.
"""
from __future__ import annotations

import re


def room_key(label: str, aliases: dict | None = None) -> str:
    def normalize(value: object) -> str:
        return ' '.join(str(value).upper().split())
    key = normalize(label)
    mapping = {normalize(k): normalize(v) for k, v in (aliases or {}).items()}
    seen = set()
    while key in mapping and mapping[key] != key:
        if key in seen:
            raise ValueError('Cyclic room aliases')
        seen.add(key)
        key = mapping[key]
    return key


def is_ecl_room(label: str, aliases: dict | None = None) -> bool:
    """True if the room's canonical physical identity is an ECL laboratory."""
    key = room_key(label, aliases)
    return bool(re.match(r"^ECL([-_ \d]|$)", key))


def is_eee_course(code: str, dept: str | None = None) -> bool:
    """True if the course is an EEE-related course."""
    clean_code = str(code).strip().upper()
    clean_dept = str(dept).strip().upper() if dept else ""
    return clean_code.startswith("EEE") or clean_dept == "EEE"


def is_cse_course(code: str, dept: str | None = None) -> bool:
    """True if the course is a CSE course."""
    clean_code = str(code).strip().upper()
    clean_dept = str(dept).strip().upper() if dept else ""
    return clean_code.startswith("CSE") or clean_dept == "CSE"
