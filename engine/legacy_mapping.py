"""Read-only quarantine for source rows whose institutional mapping is unapproved.

This module never infers a term, study stage, identity, or combined-section alias.
Reviewed mappings are applied transactionally by apply_academic_mapping in SQL.
"""
from dataclasses import dataclass
from datetime import time
from copy import deepcopy


@dataclass(frozen=True)
class QuarantinedRow:
    fixture_row: int
    reasons: tuple[str, ...]


def quarantine_unapproved(rows):
    """Return detached evidence; leave every source row and identity untouched."""
    result = []
    seen = set()
    for row in deepcopy(rows):
        key = row['fixture_row']
        if type(key) is not int or key < 1 or key in seen:
            raise ValueError('Invalid or duplicate fixture row identity')
        seen.add(key)
        reasons = ['mapping_not_approved']
        try:
            start, end = time.fromisoformat(row['time_start']), time.fromisoformat(row['time_end'])
            if end <= start:
                reasons.append('invalid_same_day_interval')
        except (ValueError, TypeError):
            reasons.append('invalid_clock_time')
        if row.get('is_service'):
            reasons.append('service_scope_unresolved')
        if not row.get('teacher_code'):
            reasons.append('teacher_unresolved')
        result.append(QuarantinedRow(key, tuple(reasons)))
    return tuple(result)
