"""Server-authoritative Stage 5A (Gate C) preflight policy & catalog validator.

Strictly non-mutating: inspects `policy_snapshot`, `faculty`, `rooms`, `courses`,
`sections`, `settings`, and optional `offerings` / `distribution_rows`, returning
a deterministic `ValidationReport`-aligned dictionary with structured blockers,
warnings, checks, summary counts, and rule coverage.
"""

from __future__ import annotations

from typing import Any

import domain
import room_policy


def _norm_str(value: Any, default: str = "") -> str:
    if value is None:
        return default
    return str(value).strip()


def _is_pending_teacher(value: Any) -> bool:
    clean = _norm_str(value).lower()
    return not clean or "pending" in clean or clean == "tba" or clean == "faculty-pending"


def _make_check(
    *,
    check_id: str,
    rule_id: str,
    category: str,
    status: str,  # 'passed' | 'warning' | 'blocker'
    title: str,
    description: str,
    target_stage: str = "policy",
    target_row: int | None = None,
    affected_entities: list[str] | None = None,
) -> dict[str, Any]:
    item: dict[str, Any] = {
        "id": check_id,
        "rule_id": rule_id,
        "category": category,
        "status": status,
        "severity": "critical" if status == "blocker" else ("warning" if status == "warning" else "info"),
        "title": title,
        "description": description,
        "target_stage": target_stage,
        "affected_entities": affected_entities or [],
    }
    if target_row is not None:
        item["target_row"] = target_row
    return item


def _periods_overlap_or_invalid(periods: list[dict[str, Any]]) -> list[str]:
    def to_min(clock: Any) -> float | None:
        raw = _norm_str(clock)
        parts = raw.split(":")
        if len(parts) not in (2, 3):
            return None
        try:
            h, m = int(parts[0]), int(parts[1])
            s = int(parts[2]) if len(parts) == 3 else 0
        except ValueError:
            return None
        if not (0 <= h <= 24 and 0 <= m <= 59 and 0 <= s <= 59) or (h == 24 and (m or s)):
            return None
        return h * 60 + m + s / 60.0

    errors: list[str] = []
    spans: list[tuple[float, float, Any]] = []
    seen_idx: set[Any] = set()
    for p in periods:
        if not isinstance(p, dict):
            errors.append("Period entry must be an object.")
            continue
        idx = p.get("idx")
        if idx in seen_idx:
            errors.append(f"Duplicate period idx {idx}.")
        seen_idx.add(idx)
        start = to_min(p.get("start"))
        end = to_min(p.get("end"))
        if start is None or end is None or end <= start:
            errors.append(f"Period {idx or '?'} has invalid or non-forward clock bounds.")
        else:
            spans.append((start, end, idx))

    spans.sort(key=lambda x: x[0])
    for prev, curr in zip(spans, spans[1:]):
        if curr[0] < prev[1]:
            errors.append(f"Period {prev[2]} overlaps with Period {curr[2]}.")
    return errors


def validate_policy_readiness(payload: dict[str, Any]) -> dict[str, Any]:
    """Validate Stage 5A policy snapshot + catalog readiness deterministically."""
    if not isinstance(payload, dict):
        raise ValueError("Request body must be a JSON object.")

    raw_policy = payload.get("policy_snapshot")
    policy = domain.CommitteePolicySnapshot.from_dict(
        raw_policy if isinstance(raw_policy, dict) else {}
    )

    raw_faculty = payload.get("faculty") or payload.get("teachers") or []
    raw_rooms = payload.get("rooms") or []
    raw_courses = payload.get("courses") or []
    raw_sections = payload.get("sections") or []
    raw_settings = payload.get("settings") or {}
    raw_offerings = payload.get("offerings") or payload.get("distribution_rows") or []

    if not isinstance(raw_faculty, list) or not isinstance(raw_rooms, list):
        raise ValueError("faculty and rooms must be lists.")
    if not isinstance(raw_courses, list) or not isinstance(raw_sections, list):
        raise ValueError("courses and sections must be lists.")

    faculty_list = [domain.FacultyPolicyProfile.from_dict(f) for f in raw_faculty]
    rooms_list = [domain.RoomPolicyProfile.from_dict(r) for r in raw_rooms]
    courses_list = [domain.CoursePolicyProfile.from_dict(c) for c in raw_courses]

    checks: list[dict[str, Any]] = []
    blockers: list[dict[str, Any]] = []
    warnings: list[dict[str, Any]] = []

    def record(item: dict[str, Any]) -> None:
        checks.append(item)
        if item["status"] == "blocker":
            blockers.append(item)
        elif item["status"] == "warning":
            warnings.append(item)

    # ── R1 / R2: Consecutive weekends & section overrides ──────────────────
    invalid_section_weekends: list[str] = []
    override_count = 0
    for sec in raw_sections:
        if not isinstance(sec, dict) or not sec.get("is_active", True):
            continue
        override = sec.get("weekend_override_days")
        if override is not None:
            override_count += 1
            if not isinstance(override, list) or not domain.is_valid_consecutive_weekend(override):
                label = f"Batch {_norm_str(sec.get('batch'))}-{_norm_str(sec.get('section'))}"
                invalid_section_weekends.append(label)

    if invalid_section_weekends:
        record(_make_check(
            check_id="r1-section-weekends",
            rule_id="R1",
            category="Section Calendar (R1/R2)",
            status="blocker",
            title="Invalid Non-Consecutive Section Weekend Override",
            description="Every section weekend override must declare exactly 2 consecutive weekdays.",
            affected_entities=invalid_section_weekends,
        ))
    else:
        record(_make_check(
            check_id="r1-section-weekends",
            rule_id="R1",
            category="Section Calendar (R1/R2)",
            status="passed",
            title="Consecutive 2-Day Section Weekends Verified",
            description=(
                f"Default weekend {' + '.join(policy.default_section_weekend)} with "
                f"{override_count} valid section override(s) and max ±{policy.batch_max_off_day_spread} batch spread (R2)."
            ),
            affected_entities=[f"Default: {'/'.join(policy.default_section_weekend)}"],
        ))

    # ── R4 / R5 / R6 / R7 / R9: Faculty policies ───────────────────────────
    active_faculty = [f for f in faculty_list if f.is_active]
    guest_missing_slots = [
        f.acronym for f in active_faculty
        if f.employment_type == "guest" and len(f.available_slots) == 0
    ]
    if guest_missing_slots:
        record(_make_check(
            check_id="r5-guest-availability",
            rule_id="R5",
            category="Guest Availability (R5)",
            status="blocker",
            title="Guest Faculty Missing Declared Available Slots",
            description="Guest/external faculty have zero implicit availability; declare explicit available_slots before solving.",
            affected_entities=guest_missing_slots,
        ))
    else:
        guest_count = sum(1 for f in active_faculty if f.employment_type == "guest")
        record(_make_check(
            check_id="r5-guest-availability",
            rule_id="R5",
            category="Guest Availability (R5)",
            status="passed",
            title="Guest Faculty Availability Windows Verified",
            description=f"{guest_count} active guest instructor(s) carry explicit available_slots whitelists.",
        ))

    r7_offenders: list[str] = []
    for f in active_faculty:
        if f.employment_type != "permanent":
            continue
        off_count = len(f.off_days)
        if off_count < 2 or off_count > 3 or (off_count == 3 and not f.allow_three_off_days):
            r7_offenders.append(f"{f.acronym} ({off_count} off-days)")

    if r7_offenders:
        record(_make_check(
            check_id="r7-permanent-offdays",
            rule_id="R7",
            category="Permanent Faculty Off-Days (R7/D3)",
            status="blocker",
            title="Permanent Faculty Off-Day Authorization Required",
            description="Permanent faculty require exactly 2 off-days unless allow_three_off_days is explicitly authorized for 3 off-days.",
            affected_entities=r7_offenders,
        ))
    else:
        perm_count = sum(1 for f in active_faculty if f.employment_type == "permanent")
        record(_make_check(
            check_id="r7-permanent-offdays",
            rule_id="R7",
            category="Permanent Faculty Off-Days (R7/D3)",
            status="passed",
            title="Permanent Faculty Off-Day Bounds Satisfied",
            description=f"All {perm_count} active permanent faculty satisfy R7/D3 2-vs-3 off-day authorization.",
        ))

    # R4 external block overlap advisory
    r4_overlaps: list[str] = []
    for f in active_faculty:
        off_set = set(f.off_days)
        if any(slot.day in off_set for slot in f.external_blocked_slots):
            r4_overlaps.append(f.acronym)
    if r4_overlaps:
        record(_make_check(
            check_id="r4-external-overlap",
            rule_id="R4",
            category="CSE External Blocks (R4)",
            status="warning",
            title="External Block Declared on Faculty Off-Day",
            description="Some CSE external_blocked_slots fall on days already marked as weekly off-days.",
            affected_entities=r4_overlaps,
        ))

    adjunct_count = sum(1 for f in active_faculty if f.employment_type == "adjunct")
    sust_count = sum(1 for f in active_faculty if f.is_sust_adjunct)
    record(_make_check(
        check_id="r6-r9-adjunct-bands",
        rule_id="R6",
        category="Adjunct & SUST Compactness (R6/R9)",
        status="passed",
        title="Adjunct Workload Bands & SUST Tagging Recorded",
        description=(
            f"{adjunct_count} adjunct(s) ({sust_count} SUST-tagged) configured under distinct-course bands "
            f"(2->{policy.adjunct_day_bands.two_courses_max_days}d, "
            f"3->{policy.adjunct_day_bands.three_courses_min_days}-{policy.adjunct_day_bands.three_courses_max_days}d, "
            f"4+->{policy.adjunct_day_bands.four_plus_courses_min_days}-{policy.adjunct_day_bands.four_plus_courses_max_days}d)."
        ),
    ))

    # ── R10 / R11: Shared ECL & Physics Lab Windows ────────────────────────
    active_rooms = [r for r in rooms_list if r.is_active]
    ecl_rooms = [
        r for r in active_rooms
        if r.room_pool_role == "ecl_lab" or (r.room_pool_role == "general" and room_policy.is_ecl_room(r.name))
    ]
    ecl_missing = [r.name for r in ecl_rooms if len(r.available_slots) == 0]
    if ecl_missing:
        record(_make_check(
            check_id="r10-ecl-windows",
            rule_id="R10",
            category="Shared ECL Labs (R10)",
            status="blocker",
            title="ECL Lab Rooms Missing Approved EEE Slot Windows",
            description="Every active ECL lab room must declare explicit available_slots released by EEE.",
            affected_entities=ecl_missing,
        ))
    else:
        record(_make_check(
            check_id="r10-ecl-windows",
            rule_id="R10",
            category="Shared ECL Labs (R10)",
            status="passed",
            title="ECL Lab Availability Windows Verified",
            description=f"{len(ecl_rooms)} active ECL lab(s) checked for declared EEE windows.",
        ))

    physics_rooms = [r for r in active_rooms if r.room_pool_role == "physics_lab"]
    physics_missing_slots = [r.name for r in physics_rooms if len(r.available_slots) == 0]
    declared_physics_codes = sorted(
        set(policy.physics_lab_course_codes)
        | {c.code for c in courses_list if c.is_active and c.is_physics_lab}
    )

    if physics_missing_slots:
        record(_make_check(
            check_id="r11-physics-lab-windows",
            rule_id="R11",
            category="Physics Lab Exclusivity (R11)",
            status="blocker",
            title="Physics Lab Room Missing Available Windows",
            description="Active physics_lab rooms require declared available_slots before scheduling.",
            affected_entities=physics_missing_slots,
        ))
    elif declared_physics_codes and not physics_rooms:
        record(_make_check(
            check_id="r11-physics-lab-room",
            rule_id="R11",
            category="Physics Lab Exclusivity (R11)",
            status="blocker",
            title="Physics Lab Course Codes Have No Active Physics Lab Room",
            description="Declare at least one active room with role physics_lab for bound Physics lab courses.",
            affected_entities=declared_physics_codes,
        ))
    else:
        record(_make_check(
            check_id="r11-physics-lab",
            rule_id="R11",
            category="Physics Lab Exclusivity (R11)",
            status="passed",
            title="Physics Lab Course Binding Ready",
            description=f"{len(declared_physics_codes)} Physics lab course code(s) matched against {len(physics_rooms)} active Physics lab room(s).",
            affected_entities=declared_physics_codes,
        ))

    # ── R12 / R13: D5 Sessional break permission & credit-session mismatches ─
    record(_make_check(
        check_id="r12-d5-break-crossing",
        rule_id="R12",
        category="Sessional Break Policy (R12/D5)",
        status="passed",
        title=(
            "2-Credit Sessional Break Crossing: ENABLED"
            if policy.allow_sessional_across_break
            else "2-Credit Sessional Break Crossing: DISABLED (Committee Default)"
        ),
        description=(
            "Explicit admin authorization enabled: 2-credit sessionals may span the midday break."
            if policy.allow_sessional_across_break
            else "Committee default enforced (D5): sessional lab pairs will not span the midday break."
        ),
    ))

    credit_mismatches: list[str] = []
    for c in courses_list:
        if not c.is_active or c.default_weekly_sessions is None:
            continue
        if c.class_type == "lab":
            if c.credit in (1.0, 1.5) and c.default_weekly_sessions != 2:
                credit_mismatches.append(f"{c.code} ({c.credit}cr lab={c.default_weekly_sessions})")
            elif c.credit == 2.0 and c.default_weekly_sessions != 3:
                credit_mismatches.append(f"{c.code} ({c.credit}cr lab={c.default_weekly_sessions})")
        elif c.class_type == "theory" and not c.is_service and c.credit in (1.0, 1.5, 2.0):
            if c.default_weekly_sessions != 2:
                credit_mismatches.append(f"{c.code} ({c.credit}cr CSE theory={c.default_weekly_sessions})")

    if credit_mismatches:
        record(_make_check(
            check_id="r12-r13-credit-sessions",
            rule_id="R13",
            category="Credit & Meeting Patterns (R12/R13)",
            status="warning",
            title="Course Weekly Sessions Differ From Credit Policy",
            description="Review courses whose default_weekly_sessions differs from R12/R13 (1/1.5cr lab->2, 2cr lab->3, 1-2cr CSE theory->2).",
            affected_entities=credit_mismatches,
        ))

    # ── R14: Room pool & non-digit classroom names ─────────────────────────
    if not active_rooms or not active_faculty:
        missing_parts = []
        if not active_rooms:
            missing_parts.append("active rooms")
        if not active_faculty:
            missing_parts.append("active faculty")
        record(_make_check(
            check_id="r14-baseline-pools",
            rule_id="R14",
            category="Resource Pools (R14)",
            status="blocker",
            title="Empty Active Resource Pool",
            description=f"Missing {' and '.join(missing_parts)} required for timetable generation.",
            affected_entities=missing_parts,
        ))
    else:
        non_digit_general = [
            r.name for r in active_rooms
            if not r.is_lab and not r.is_gallery and r.room_pool_role == "general" and not any(ch.isdigit() for ch in r.name)
        ]
        if non_digit_general:
            record(_make_check(
                check_id="r14-nondigit-rooms",
                rule_id="R14",
                category="Resource Pools (R14)",
                status="warning",
                title="Non-Digit General Room Names Detected",
                description="Legacy solver ignores non-gallery general rooms without digits unless assigned an explicit role.",
                affected_entities=non_digit_general,
            ))
        else:
            record(_make_check(
                check_id="r14-baseline-pools",
                rule_id="R14",
                category="Resource Pools (R14)",
                status="passed",
                title="Active Room & Faculty Pools Ready",
                description=f"{len(active_rooms)} active room(s) and {len(active_faculty)} active faculty available.",
            ))

    # ── R15: Daily period grid integrity ───────────────────────────────────
    raw_periods = raw_settings.get("periods") if isinstance(raw_settings, dict) else None
    if isinstance(raw_periods, list) and raw_periods:
        period_errors = _periods_overlap_or_invalid(raw_periods)
        if period_errors:
            record(_make_check(
                check_id="r15-period-grid",
                rule_id="R15",
                category="Daily Period Grid (R15)",
                status="blocker",
                title="Invalid or Overlapping Daily Period Grid",
                description=" ".join(period_errors),
            ))
        else:
            record(_make_check(
                check_id="r15-period-grid",
                rule_id="R15",
                category="Daily Period Grid (R15)",
                status="passed",
                title=f"{policy.daily_slot_count}-Slot Daily Grid Verified",
                description=(
                    f"{len(raw_periods)} configured period(s); online slot "
                    f"{'enabled' if policy.allow_online_slot else 'disabled'}."
                ),
            ))

    if not policy.friday_no_p4:
        record(_make_check(
            check_id="r15-friday-jummah",
            rule_id="R15",
            category="Friday Jummah Guard",
            status="warning",
            title="Friday Period 4 Jummah Hard Block Disabled",
            description="Committee baseline expects Friday Period 4 to remain blocked for Jummah prayer.",
        ))

    # ── CD1: Distribution rows / pending teachers / un-cached formulas ─────
    if isinstance(raw_offerings, list) and raw_offerings:
        pending_rows: list[str] = []
        uncached_rows: list[str] = []
        first_pending_row: int | None = None
        first_uncached_row: int | None = None
        for idx, row in enumerate(raw_offerings):
            if not isinstance(row, dict):
                continue
            row_num = row.get("row") if isinstance(row.get("row"), int) else None
            code = _norm_str(row.get("courseCode") or row.get("course_code") or f"Row {row_num or idx + 1}")
            teacher = row.get("teacher")
            if teacher is None and isinstance(row.get("teachers"), list):
                teacher = ", ".join(str(t) for t in row["teachers"])
            if _is_pending_teacher(teacher):
                pending_rows.append(f"{code} (Row {row_num or idx + 1})")
                if first_pending_row is None and row_num is not None:
                    first_pending_row = row_num
            if (row.get("formulaJ") and row.get("cachedJ") is None) or (
                row.get("formulaL") and row.get("cachedL") is None
            ):
                uncached_rows.append(f"{code} (Row {row_num or idx + 1})")
                if first_uncached_row is None and row_num is not None:
                    first_uncached_row = row_num

        if pending_rows:
            record(_make_check(
                check_id="cd1-pending-teachers",
                rule_id="CD1",
                category="Course Distribution (CD1)",
                status="blocker",
                title="Pending or Blank Instructor Assignments",
                description=f"{len(pending_rows)} distribution row(s) still require an assigned instructor.",
                target_stage="distribution",
                target_row=first_pending_row,
                affected_entities=pending_rows[:12],
            ))
        if uncached_rows:
            record(_make_check(
                check_id="cd1-uncached-formulas",
                rule_id="CD1",
                category="Course Distribution (CD1)",
                status="blocker",
                title="Un-Cached Spreadsheet Formula Cells (Cols J/L)",
                description="Apply explicit numeric corrections in Stage 1 for cells with formulas lacking cached values.",
                target_stage="distribution",
                target_row=first_uncached_row,
                affected_entities=uncached_rows[:12],
            ))
        if not pending_rows and not uncached_rows:
            record(_make_check(
                check_id="cd1-distribution-complete",
                rule_id="CD1",
                category="Course Distribution (CD1)",
                status="passed",
                title="Course Distribution Instructors & Formulas Verified",
                description=f"All {len(raw_offerings)} distribution row(s) have assigned instructors and cached counts.",
                target_stage="distribution",
            ))

    ok = len(blockers) == 0
    return {
        "ok": ok,
        "policy_hash": policy.policy_hash(),
        "allow_sessional_across_break": policy.allow_sessional_across_break,
        "checks": checks,
        "blockers": blockers,
        "warnings": warnings,
        "summary": {
            "blocker_count": len(blockers),
            "warning_count": len(warnings),
            "passed_count": sum(1 for c in checks if c["status"] == "passed"),
            "active_faculty_count": len(active_faculty),
            "active_room_count": len(active_rooms),
            "active_course_count": sum(1 for c in courses_list if c.is_active),
            "active_section_count": sum(
                1 for s in raw_sections if isinstance(s, dict) and s.get("is_active", True)
            ),
            "allow_sessional_across_break": policy.allow_sessional_across_break,
        },
        "rule_coverage": sorted({c["rule_id"] for c in checks}),
    }
