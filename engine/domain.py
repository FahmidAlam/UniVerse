"""Schema-v1 canonical catalog. Labels never substitute for resource identities.

This additive contract is not yet connected to legacy ingestion or publication.
Academic progression is supplied explicitly; institutional rules are not inferred.
"""
from __future__ import annotations

from dataclasses import MISSING, dataclass, fields
from datetime import date
import hashlib
import json
import re
import types
from typing import Any, get_args, get_origin, get_type_hints
from uuid import UUID

WEEK_DAYS = (
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
)
_WEEK_DAY_INDEX = {day: idx for idx, day in enumerate(WEEK_DAYS)}


def is_valid_consecutive_weekend(days: tuple[str, ...] | list[str]) -> bool:
    """True when `days` holds 2 distinct consecutive weekdays on the 7-day cycle."""
    if len(days) != 2:
        return False
    d1, d2 = str(days[0]).strip(), str(days[1]).strip()
    if d1 == d2 or d1 not in _WEEK_DAY_INDEX or d2 not in _WEEK_DAY_INDEX:
        return False
    diff = (_WEEK_DAY_INDEX[d2] - _WEEK_DAY_INDEX[d1] + 7) % 7
    return diff in (1, 6)

# Unicode White_Space plus BOM; explicit so Dart and Python accept identical labels.
_EDGE_WHITESPACE = '\u0009\u000a\u000b\u000c\u000d\u0020\u0085\u00a0\u1680\u2000\u2001\u2002\u2003\u2004\u2005\u2006\u2007\u2008\u2009\u200a\u2028\u2029\u202f\u205f\u3000\ufeff'


def _trim(value):
    return value.strip(_EDGE_WHITESPACE)


def _read(value, kind):
    if get_origin(kind) is types.UnionType:
        if value is None and type(None) in get_args(kind):
            return None
        return _read(value, next(t for t in get_args(kind) if t is not type(None)))
    if get_origin(kind) is tuple:
        if not isinstance(value, list):
            raise ValueError('Expected JSON array')
        return tuple(_read(v, get_args(kind)[0]) for v in value)
    if kind is date:
        if not isinstance(value, str) or not re.fullmatch(r'\d{4}-\d{2}-\d{2}', value):
            raise ValueError('Expected ISO calendar date')
        return date.fromisoformat(value)
    if isinstance(kind, type) and issubclass(kind, _Record):
        return kind.from_map(value)
    if type(value) is not kind:
        raise ValueError(f'Expected {kind.__name__}')
    return value


def _write(value):
    if isinstance(value, _Record):
        return value.to_map()
    if isinstance(value, tuple):
        return [_write(v) for v in value]
    if isinstance(value, date):
        return value.isoformat()
    return value


class _Record:
    @classmethod
    def from_map(cls, data):
        names = {f.name for f in fields(cls)}
        if not isinstance(data, dict) or not set(data) <= names:
            raise ValueError(f'{cls.__name__}: missing or unknown fields')
        missing_required = {
            f.name
            for f in fields(cls)
            if f.name not in data and f.default is MISSING and f.default_factory is MISSING
        }
        if missing_required:
            raise ValueError(f'{cls.__name__}: missing or unknown fields')
        hints = get_type_hints(cls)
        kwargs = {
            f.name: _read(data[f.name], hints[f.name])
            for f in fields(cls)
            if f.name in data
        }
        return cls(**kwargs)

    def to_map(self):
        return {f.name: _write(getattr(self, f.name)) for f in fields(self)}

    def __post_init__(self):
        # Check direct construction as well as JSON parsing; freeze nested lists.
        hints = get_type_hints(type(self))
        for f in fields(self):
            value = getattr(self, f.name)
            if _read(_write(value), hints[f.name]) != value:
                raise ValueError(f'Invalid {f.name}')
            if isinstance(value, str) and not _trim(value):
                raise ValueError(f'Empty {f.name}')
            if value is not None and (f.name == 'id' or (f.name.endswith('_id') and f.name != 'rule_id')):
                if not isinstance(value, str) or str(UUID(value)) != value:
                    raise ValueError(f'{f.name} must be a canonical UUID')
            if f.name.endswith('_ids'):
                if len(set(value)) != len(value) or any(str(UUID(v)) != v for v in value):
                    raise ValueError(f'Invalid or duplicate {f.name}')


@dataclass(frozen=True)
class Department(_Record):
    id: str
    code: str
    name: str
    is_active: bool


@dataclass(frozen=True)
class AcademicCalendar(_Record):
    id: str
    name: str
    timezone: str


@dataclass(frozen=True)
class AcademicYear(_Record):
    id: str
    calendar_id: str
    label: str


@dataclass(frozen=True)
class AcademicProgram(_Record):
    id: str
    department_id: str
    calendar_id: str
    code: str
    title: str
    is_active: bool


@dataclass(frozen=True)
class AcademicTerm(_Record):
    id: str
    academic_year_id: str
    sequence: int
    label: str
    start_date: date
    end_date: date

    def __post_init__(self):
        super().__post_init__()
        if self.sequence < 1 or self.start_date > self.end_date:
            raise ValueError('Invalid term sequence/date range')


@dataclass(frozen=True)
class Cohort(_Record):
    id: str
    program_id: str
    code: str
    admitted_on: date
    status: str
    graduated_on: date | None
    archived_on: date | None

    def __post_init__(self):
        super().__post_init__()
        if self.status not in ('active', 'graduated', 'archived'):
            raise ValueError('Unknown cohort lifecycle status')
        if (self.status == 'active' and self.graduated_on is not None
                or self.status == 'graduated' and self.graduated_on is None
                or (self.status == 'archived') != (self.archived_on is not None)):
            raise ValueError('Inconsistent cohort lifecycle dates')
        if any(d is not None and d < self.admitted_on for d in (self.graduated_on, self.archived_on)):
            raise ValueError('Lifecycle date precedes admission')
        if self.graduated_on and self.archived_on and self.archived_on < self.graduated_on:
            raise ValueError('Archive precedes graduation')


@dataclass(frozen=True)
class StudentGroup(_Record):
    id: str
    cohort_id: str
    code: str
    is_active: bool


@dataclass(frozen=True)
class CohortTerm(_Record):
    id: str
    cohort_id: str
    term_id: str
    study_stage: int

    def __post_init__(self):
        super().__post_init__()
        if self.study_stage < 1:
            raise ValueError('Study stage must be positive')


@dataclass(frozen=True)
class Faculty(_Record):
    id: str
    home_department_id: str | None
    display_name: str
    is_active: bool


@dataclass(frozen=True)
class Room(_Record):
    id: str
    name: str
    campus: str | None
    capacity: int | None
    features: tuple[str, ...]
    is_active: bool

    def __post_init__(self):
        super().__post_init__()
        if self.capacity is not None and self.capacity < 1:
            raise ValueError('Known room capacity must be positive')
        if any(not _trim(f) for f in self.features) or len(set(self.features)) != len(self.features):
            raise ValueError('Invalid room features')


@dataclass(frozen=True)
class SchedulingScope(_Record):
    id: str
    department_id: str
    program_id: str | None
    term_id: str


@dataclass(frozen=True)
class GroupAlias(_Record):
    id: str
    cohort_id: str
    label: str
    group_ids: tuple[str, ...]
    reviewed: bool

    def __post_init__(self):
        super().__post_init__()
        if not self.group_ids:
            raise ValueError('An alias needs explicit atomic group IDs')


def _unique(rows, key, label):
    keys = [key(r) for r in rows]
    if len(set(keys)) != len(keys):
        raise ValueError(f'Duplicate {label}')


def _label(value):
    return _trim(value).lower()


@dataclass(frozen=True)
class AcademicCatalog(_Record):
    departments: tuple[Department, ...]
    calendars: tuple[AcademicCalendar, ...]
    academic_years: tuple[AcademicYear, ...]
    programs: tuple[AcademicProgram, ...]
    terms: tuple[AcademicTerm, ...]
    cohorts: tuple[Cohort, ...]
    student_groups: tuple[StudentGroup, ...]
    cohort_terms: tuple[CohortTerm, ...]
    faculty: tuple[Faculty, ...]
    rooms: tuple[Room, ...]
    scopes: tuple[SchedulingScope, ...]
    group_aliases: tuple[GroupAlias, ...]
    schema_version: int = 1

    def __post_init__(self):
        # Nested records already validate their fields. Avoid recursively rebuilding
        # the entire catalog when checking the immutable collection boundary.
        if type(self.schema_version) is not int or self.schema_version != 1:
            raise ValueError('Unsupported catalog schema_version')
        hints = get_type_hints(type(self))
        for f in fields(self):
            if f.name != 'schema_version':
                rows = getattr(self, f.name)
                record_type = get_args(hints[f.name])[0]
                if type(rows) is not tuple or any(type(r) is not record_type for r in rows):
                    raise ValueError('Expected immutable typed catalog records')
                _unique(rows, lambda r: r.id, f.name + ' ID')
        indexes = {f.name: {r.id: r for r in getattr(self, f.name)}
                   for f in fields(self) if f.name != 'schema_version'}

        def ref(collection, identity):
            if identity not in indexes[collection]:
                raise ValueError(f'Unknown {collection} reference: {identity}')
            return indexes[collection][identity]

        for year in self.academic_years:
            ref('calendars', year.calendar_id)
        for program in self.programs:
            ref('departments', program.department_id)
            ref('calendars', program.calendar_id)
        for term in self.terms:
            ref('academic_years', term.academic_year_id)
        for cohort in self.cohorts:
            ref('programs', cohort.program_id)
        for group in self.student_groups:
            ref('cohorts', group.cohort_id)
        for row in self.cohort_terms:
            program = ref('programs', ref('cohorts', row.cohort_id).program_id)
            year = ref('academic_years', ref('terms', row.term_id).academic_year_id)
            if program.calendar_id != year.calendar_id:
                raise ValueError('Cohort term belongs to another calendar')
        for teacher in self.faculty:
            if teacher.home_department_id is not None:
                ref('departments', teacher.home_department_id)
        for scope in self.scopes:
            ref('departments', scope.department_id)
            year = ref('academic_years', ref('terms', scope.term_id).academic_year_id)
            if scope.program_id is not None:
                program = ref('programs', scope.program_id)
                if program.department_id != scope.department_id:
                    raise ValueError('Scope program belongs to another department')
                if program.calendar_id != year.calendar_id:
                    raise ValueError('Scope term belongs to another calendar')
        for alias in self.group_aliases:
            ref('cohorts', alias.cohort_id)
            if any(ref('student_groups', gid).cohort_id != alias.cohort_id for gid in alias.group_ids):
                raise ValueError('Group alias crosses cohort boundaries')
        for rows, key, label in (
            (self.departments, lambda r: _label(r.code), 'department code'),
            (self.programs, lambda r: (r.department_id, _label(r.code)), 'program code'),
            (self.academic_years, lambda r: (r.calendar_id, _label(r.label)), 'academic year'),
            (self.terms, lambda r: (r.academic_year_id, r.sequence), 'term sequence'),
            (self.cohorts, lambda r: (r.program_id, _label(r.code)), 'cohort code'),
            (self.student_groups, lambda r: (r.cohort_id, _label(r.code)), 'group code'),
            (self.cohort_terms, lambda r: (r.cohort_id, r.term_id), 'cohort term'),
            (self.scopes, lambda r: (r.department_id, r.program_id, r.term_id), 'scope'),
            (self.group_aliases, lambda r: (r.cohort_id, _label(r.label)), 'group alias'),
        ):
            _unique(rows, key, label)

    def resolve_group_alias(self, cohort_id, label):
        matches = [a for a in self.group_aliases if a.cohort_id == cohort_id and _label(a.label) == _label(label)]
        if len(matches) != 1:
            raise ValueError('Unknown or ambiguous group alias')
        alias = matches[0]
        if not alias.reviewed:
            raise ValueError('Group alias has not been reviewed')
        groups = {g.id: g for g in self.student_groups}
        return tuple(groups[gid] for gid in alias.group_ids)

# Engine exchange records. Policy approval and solving remain separate operations.
def _dates(values):
    if not values or len(set(values)) != len(values):
        raise ValueError('Expected nonempty distinct teaching dates')


@dataclass(frozen=True)
class SourceRef(_Record):
    file_hash: str
    sheet: str
    row: int
    column: str

    def __post_init__(self):
        super().__post_init__()
        if not re.fullmatch(r'[0-9a-f]{64}', self.file_hash) or self.row < 1:
            raise ValueError('Invalid source checksum or row')


@dataclass(frozen=True)
class TeacherAssignment(_Record):
    faculty_id: str
    assignment_kind: str
    effective_dates: tuple[date, ...]

    def __post_init__(self):
        super().__post_init__()
        _dates(self.effective_dates)
        if self.assignment_kind not in ('co_teaching', 'split'):
            raise ValueError('Unknown teacher assignment kind')


@dataclass(frozen=True)
class RoomCriteria(_Record):
    minimum_capacity: int | None
    required_features: tuple[str, ...]
    eligible_room_ids: tuple[str, ...]

    def __post_init__(self):
        super().__post_init__()
        if self.minimum_capacity is not None and self.minimum_capacity < 1:
            raise ValueError('Invalid minimum capacity')
        if any(not _trim(v) for v in self.required_features):
            raise ValueError('Empty room feature')


@dataclass(frozen=True)
class Offering(_Record):
    id: str
    course_id: str
    course_code: str
    title: str
    group_ids: tuple[str, ...]
    teacher_assignments: tuple[TeacherAssignment, ...]
    teacher_state: str
    meeting_count: int
    contact_minutes: int
    duration_minutes: int
    delivery_mode: str
    room_criteria: RoomCriteria
    source_refs: tuple[SourceRef, ...]
    is_service: bool

    def __post_init__(self):
        super().__post_init__()
        if not self.group_ids or not self.source_refs:
            raise ValueError('Offering needs groups and provenance')
        if self.teacher_state not in ('assigned', 'pending') or bool(self.teacher_assignments) != (self.teacher_state == 'assigned'):
            raise ValueError('Teacher state disagrees with assignments')
        if min(self.meeting_count, self.contact_minutes, self.duration_minutes) < 1:
            raise ValueError('Requirements must be positive')
        if self.delivery_mode not in ('in_person', 'online'):
            raise ValueError('Unknown delivery mode')


@dataclass(frozen=True)
class Assignment(_Record):
    id: str
    offering_id: str
    teaching_dates: tuple[date, ...]
    start_minute: int
    end_minute: int
    room_id: str | None
    faculty_ids: tuple[str, ...]
    group_ids: tuple[str, ...]
    pinned: bool

    def __post_init__(self):
        super().__post_init__()
        _dates(self.teaching_dates)
        if not 0 <= self.start_minute < self.end_minute <= 1440 or not self.group_ids:
            raise ValueError('Invalid assignment interval/groups')


@dataclass(frozen=True)
class ApprovedExclusion(_Record):
    offering_id: str
    reason: str
    approved_by: str
    source_refs: tuple[SourceRef, ...]


@dataclass(frozen=True)
class SlotWindow:
    day: str
    period_idx: int | None = None
    start: str | None = None
    end: str | None = None
    priority: int | None = None

    def __post_init__(self):
        clean_day = _trim(str(self.day))
        if clean_day not in _WEEK_DAY_INDEX:
            raise ValueError(f'Unknown weekday in SlotWindow: {self.day!r}')
        object.__setattr__(self, 'day', clean_day)
        if self.period_idx is not None:
            if isinstance(self.period_idx, bool) or not isinstance(self.period_idx, int) or self.period_idx < 1 or self.period_idx > 12:
                raise ValueError('SlotWindow.period_idx must be 1..12')
        if self.period_idx is None and (not self.start or not self.end):
            raise ValueError('SlotWindow needs period_idx or start/end bounds')

    @classmethod
    def from_dict(cls, data: Any) -> 'SlotWindow':
        if not isinstance(data, dict):
            raise ValueError('SlotWindow must be a JSON object')
        return cls(
            day=str(data.get('day') or ''),
            period_idx=data.get('period_idx'),
            start=str(data['start']).strip() if data.get('start') else None,
            end=str(data['end']).strip() if data.get('end') else None,
            priority=data.get('priority'),
        )

    def to_dict(self) -> dict[str, Any]:
        out: dict[str, Any] = {'day': self.day}
        if self.period_idx is not None:
            out['period_idx'] = self.period_idx
        if self.start is not None:
            out['start'] = self.start
        if self.end is not None:
            out['end'] = self.end
        if self.priority is not None:
            out['priority'] = self.priority
        return out


@dataclass(frozen=True)
class SectionWeekendOverride:
    batch: str
    section: str
    weekend_days: tuple[str, str]
    calendar_system: str = 'bi_semester'

    def __post_init__(self):
        if not _trim(self.batch) or not _trim(self.section):
            raise ValueError('SectionWeekendOverride requires batch and section')
        if not is_valid_consecutive_weekend(self.weekend_days):
            raise ValueError('SectionWeekendOverride requires 2 consecutive weekdays')
        if self.calendar_system not in ('trimester', 'bi_semester'):
            raise ValueError('Unknown calendar_system')

    @classmethod
    def from_dict(cls, data: Any) -> 'SectionWeekendOverride':
        if not isinstance(data, dict):
            raise ValueError('SectionWeekendOverride must be a JSON object')
        raw_days = data.get('weekend_days') or data.get('weekend_override_days') or ()
        if not isinstance(raw_days, (list, tuple)) or len(raw_days) != 2:
            raise ValueError('weekend_days must contain 2 weekdays')
        return cls(
            batch=str(data.get('batch') or '').strip(),
            section=str(data.get('section') or '').strip(),
            weekend_days=(str(raw_days[0]).strip(), str(raw_days[1]).strip()),
            calendar_system=str(data.get('calendar_system') or 'bi_semester').strip(),
        )

    def to_dict(self) -> dict[str, Any]:
        return {
            'batch': self.batch,
            'section': self.section,
            'weekend_days': list(self.weekend_days),
            'calendar_system': self.calendar_system,
        }


@dataclass(frozen=True)
class AdjunctDayBandPolicy:
    two_courses_max_days: int = 2
    three_courses_min_days: int = 3
    three_courses_max_days: int = 4
    four_plus_courses_min_days: int = 4
    four_plus_courses_max_days: int = 5

    def __post_init__(self):
        for val in (
            self.two_courses_max_days,
            self.three_courses_min_days,
            self.three_courses_max_days,
            self.four_plus_courses_min_days,
            self.four_plus_courses_max_days,
        ):
            if isinstance(val, bool) or not isinstance(val, int) or not 1 <= val <= 7:
                raise ValueError('Adjunct day-band values must be integers between 1 and 7')
        if self.three_courses_min_days > self.three_courses_max_days:
            raise ValueError('Invalid 3-course adjunct day band')
        if self.four_plus_courses_min_days > self.four_plus_courses_max_days:
            raise ValueError('Invalid 4+-course adjunct day band')

    @classmethod
    def from_dict(cls, data: Any) -> 'AdjunctDayBandPolicy':
        if not data:
            return cls()
        if not isinstance(data, dict):
            raise ValueError('adjunct_day_bands must be a JSON object')
        return cls(
            two_courses_max_days=int(data.get('two_courses_max_days', 2)),
            three_courses_min_days=int(data.get('three_courses_min_days', 3)),
            three_courses_max_days=int(data.get('three_courses_max_days', 4)),
            four_plus_courses_min_days=int(data.get('four_plus_courses_min_days', 4)),
            four_plus_courses_max_days=int(data.get('four_plus_courses_max_days', 5)),
        )

    def to_dict(self) -> dict[str, int]:
        return {
            'two_courses_max_days': self.two_courses_max_days,
            'three_courses_min_days': self.three_courses_min_days,
            'three_courses_max_days': self.three_courses_max_days,
            'four_plus_courses_min_days': self.four_plus_courses_min_days,
            'four_plus_courses_max_days': self.four_plus_courses_max_days,
        }


@dataclass(frozen=True)
class FacultyPolicyProfile:
    acronym: str
    employment_type: str = 'permanent'
    off_days: tuple[str, ...] = ()
    allow_three_off_days: bool = False
    is_sust_adjunct: bool = False
    external_blocked_slots: tuple[SlotWindow, ...] = ()
    available_slots: tuple[SlotWindow, ...] = ()
    preferred_slots: tuple[SlotWindow, ...] = ()
    is_active: bool = True
    dept: str | None = None

    def __post_init__(self):
        if not _trim(self.acronym):
            raise ValueError('FacultyPolicyProfile requires acronym')
        if self.employment_type not in ('permanent', 'adjunct', 'guest'):
            raise ValueError(f'Unknown employment_type: {self.employment_type!r}')

    @classmethod
    def from_dict(cls, data: Any) -> 'FacultyPolicyProfile':
        if not isinstance(data, dict):
            raise ValueError('Faculty item must be a JSON object')
        return cls(
            acronym=str(data.get('acronym') or '').strip().upper(),
            employment_type=str(data.get('employment_type') or 'permanent').strip().lower(),
            off_days=tuple(str(d).strip() for d in (data.get('off_days') or []) if str(d).strip()),
            allow_three_off_days=bool(data.get('allow_three_off_days', False)),
            is_sust_adjunct=bool(data.get('is_sust_adjunct', False)),
            external_blocked_slots=tuple(SlotWindow.from_dict(s) for s in (data.get('external_blocked_slots') or [])),
            available_slots=tuple(SlotWindow.from_dict(s) for s in (data.get('available_slots') or [])),
            preferred_slots=tuple(SlotWindow.from_dict(s) for s in (data.get('preferred_slots') or [])),
            is_active=bool(data.get('is_active', True)),
            dept=str(data['dept']).strip() if data.get('dept') else None,
        )


@dataclass(frozen=True)
class RoomPolicyProfile:
    name: str
    room_pool_role: str = 'general'
    is_lab: bool = False
    is_gallery: bool = False
    capacity: int | None = None
    available_slots: tuple[SlotWindow, ...] = ()
    is_active: bool = True
    dept: str | None = None

    def __post_init__(self):
        if not _trim(self.name):
            raise ValueError('RoomPolicyProfile requires name')
        if self.room_pool_role not in ('general', 'cse_lab', 'ecl_lab', 'physics_lab', 'gallery', 'other'):
            raise ValueError(f'Unknown room_pool_role: {self.room_pool_role!r}')

    @classmethod
    def from_dict(cls, data: Any) -> 'RoomPolicyProfile':
        if not isinstance(data, dict):
            raise ValueError('Room item must be a JSON object')
        cap = data.get('capacity')
        return cls(
            name=str(data.get('name') or '').strip(),
            room_pool_role=str(data.get('room_pool_role') or 'general').strip().lower(),
            is_lab=bool(data.get('is_lab', False)),
            is_gallery=bool(data.get('is_gallery', False)),
            capacity=int(cap) if cap is not None and cap != '' else None,
            available_slots=tuple(SlotWindow.from_dict(s) for s in (data.get('available_slots') or [])),
            is_active=bool(data.get('is_active', True)),
            dept=str(data['dept']).strip() if data.get('dept') else None,
        )


@dataclass(frozen=True)
class CoursePolicyProfile:
    code: str
    title: str
    credit: float = 3.0
    class_type: str = 'theory'
    is_service: bool = False
    is_physics_lab: bool = False
    default_weekly_sessions: int | None = None
    dept_code: str = 'CSE'
    is_active: bool = True

    def __post_init__(self):
        if not _trim(self.code) or not _trim(self.title):
            raise ValueError('CoursePolicyProfile requires code and title')
        if self.class_type not in ('theory', 'lab'):
            raise ValueError(f'Unknown class_type: {self.class_type!r}')

    @classmethod
    def from_dict(cls, data: Any) -> 'CoursePolicyProfile':
        if not isinstance(data, dict):
            raise ValueError('Course item must be a JSON object')
        dws = data.get('default_weekly_sessions')
        return cls(
            code=str(data.get('code') or '').strip().upper(),
            title=str(data.get('title') or '').strip(),
            credit=float(data.get('credit', 3.0)),
            class_type=str(data.get('class_type') or 'theory').strip().lower(),
            is_service=bool(data.get('is_service', False)),
            is_physics_lab=bool(data.get('is_physics_lab', False)),
            default_weekly_sessions=int(dws) if dws is not None else None,
            dept_code=str(data.get('dept_code') or 'CSE').strip(),
            is_active=bool(data.get('is_active', True)),
        )


@dataclass(frozen=True)
class CommitteePolicySnapshot:
    """Typed R1-R16 committee policy configuration (Gate C)."""
    schema_version: int = 1
    default_section_weekend: tuple[str, str] = ('Friday', 'Saturday')
    section_weekend_overrides: tuple[SectionWeekendOverride, ...] = ()
    batch_max_off_day_spread: int = 1
    max_section_internal_gap: int = 1
    adjunct_day_bands: AdjunctDayBandPolicy = AdjunctDayBandPolicy()
    faculty_preference_weight: int = 85
    sust_adjunct_single_half_day: bool = True
    sust_adjunct_max_gap: int = 2
    allow_sessional_across_break: bool = False
    physics_lab_course_codes: tuple[str, ...] = ()
    low_credit_cse_theory_consecutive: bool = True
    three_credit_theory_spread: bool = True
    active_room_pool: tuple[str, ...] = ()
    daily_slot_count: int = 7
    allow_online_slot: bool = False
    friday_no_p4: bool = True
    auto_resolve_undeclared_off_days: bool = True

    def __post_init__(self):
        if self.schema_version != 1:
            raise ValueError('Unsupported CommitteePolicySnapshot schema_version')
        if not is_valid_consecutive_weekend(self.default_section_weekend):
            raise ValueError('default_section_weekend must be 2 consecutive weekdays')
        if not 0 <= self.batch_max_off_day_spread <= 3:
            raise ValueError('batch_max_off_day_spread must be between 0 and 3')
        if not 0 <= self.max_section_internal_gap <= 3:
            raise ValueError('max_section_internal_gap must be between 0 and 3')
        if self.daily_slot_count not in (6, 7):
            raise ValueError('daily_slot_count must be 6 or 7')
        if not 0 <= self.sust_adjunct_max_gap <= 4:
            raise ValueError('sust_adjunct_max_gap must be between 0 and 4')

    @classmethod
    def from_dict(cls, data: Any) -> 'CommitteePolicySnapshot':
        if data is None:
            return cls()
        if not isinstance(data, dict):
            raise ValueError('CommitteePolicySnapshot must be a JSON object')
        merged: dict[str, Any] = {}
        nested = data.get('policy_payload')
        if isinstance(nested, dict):
            merged.update(nested)
        merged.update(data)

        raw_weekend = merged.get('default_section_weekend') or ('Friday', 'Saturday')
        if not isinstance(raw_weekend, (list, tuple)) or len(raw_weekend) != 2:
            raise ValueError('default_section_weekend must have 2 days')
        weekend = (str(raw_weekend[0]).strip(), str(raw_weekend[1]).strip())

        overrides = tuple(
            SectionWeekendOverride.from_dict(item)
            for item in (merged.get('section_weekend_overrides') or ())
        )
        physics_codes = tuple(sorted({
            str(code).strip().upper()
            for code in (merged.get('physics_lab_course_codes') or ())
            if str(code).strip()
        }))
        room_pool = tuple(sorted({
            str(name).strip().upper()
            for name in (merged.get('active_room_pool') or ())
            if str(name).strip()
        }))

        return cls(
            schema_version=int(merged.get('schema_version', 1)),
            default_section_weekend=weekend,
            section_weekend_overrides=overrides,
            batch_max_off_day_spread=int(merged.get('batch_max_off_day_spread', 1)),
            max_section_internal_gap=int(merged.get('max_section_internal_gap', 1)),
            adjunct_day_bands=AdjunctDayBandPolicy.from_dict(merged.get('adjunct_day_bands')),
            faculty_preference_weight=int(merged.get('faculty_preference_weight', 85)),
            sust_adjunct_single_half_day=bool(merged.get('sust_adjunct_single_half_day', True)),
            sust_adjunct_max_gap=int(merged.get('sust_adjunct_max_gap', 2)),
            allow_sessional_across_break=bool(merged.get('allow_sessional_across_break', False)),
            physics_lab_course_codes=physics_codes,
            low_credit_cse_theory_consecutive=bool(merged.get('low_credit_cse_theory_consecutive', True)),
            three_credit_theory_spread=bool(merged.get('three_credit_theory_spread', True)),
            active_room_pool=room_pool,
            daily_slot_count=int(merged.get('daily_slot_count', 7)),
            allow_online_slot=bool(merged.get('allow_online_slot', False)),
            friday_no_p4=bool(merged.get('friday_no_p4', True)),
            auto_resolve_undeclared_off_days=bool(merged.get('auto_resolve_undeclared_off_days', True)),
        )

    def to_dict(self) -> dict[str, Any]:
        return {
            'schema_version': self.schema_version,
            'default_section_weekend': list(self.default_section_weekend),
            'section_weekend_overrides': [o.to_dict() for o in self.section_weekend_overrides],
            'batch_max_off_day_spread': self.batch_max_off_day_spread,
            'max_section_internal_gap': self.max_section_internal_gap,
            'adjunct_day_bands': self.adjunct_day_bands.to_dict(),
            'faculty_preference_weight': self.faculty_preference_weight,
            'sust_adjunct_single_half_day': self.sust_adjunct_single_half_day,
            'sust_adjunct_max_gap': self.sust_adjunct_max_gap,
            'allow_sessional_across_break': self.allow_sessional_across_break,
            'physics_lab_course_codes': list(self.physics_lab_course_codes),
            'low_credit_cse_theory_consecutive': self.low_credit_cse_theory_consecutive,
            'three_credit_theory_spread': self.three_credit_theory_spread,
            'active_room_pool': list(self.active_room_pool),
            'daily_slot_count': self.daily_slot_count,
            'allow_online_slot': self.allow_online_slot,
            'friday_no_p4': self.friday_no_p4,
            'auto_resolve_undeclared_off_days': self.auto_resolve_undeclared_off_days,
        }

    def policy_hash(self) -> str:
        canonical = json.dumps(self.to_dict(), sort_keys=True, separators=(',', ':'))
        return hashlib.sha256(canonical.encode('utf-8')).hexdigest()


@dataclass(frozen=True)
class PolicySnapshot(_Record):
    schema_version: int
    policy_revision_id: str
    scope_id: str
    term_id: str
    resource_revision: int
    teaching_dates: tuple[date, ...]
    committee_policy: CommitteePolicySnapshot | None = None

    def __post_init__(self):
        _dates(self.teaching_dates)
        if self.schema_version != 1 or self.resource_revision < 1:
            raise ValueError('Unsupported policy version/revision')
        for name in ('policy_revision_id', 'scope_id', 'term_id'):
            value = getattr(self, name)
            if not isinstance(value, str) or str(UUID(value)) != value:
                raise ValueError(f'{name} must be a canonical UUID')

    def to_map(self):
        out = {
            'schema_version': self.schema_version,
            'policy_revision_id': self.policy_revision_id,
            'scope_id': self.scope_id,
            'term_id': self.term_id,
            'resource_revision': self.resource_revision,
            'teaching_dates': [_write(d) for d in self.teaching_dates],
        }
        if self.committee_policy is not None:
            out['committee_policy'] = self.committee_policy.to_dict()
        return out

    @classmethod
    def from_map(cls, data):
        if not isinstance(data, dict):
            raise ValueError('PolicySnapshot must be a JSON object')
        allowed = {'schema_version', 'policy_revision_id', 'scope_id', 'term_id', 'resource_revision', 'teaching_dates', 'committee_policy'}
        if not set(data) <= allowed:
            raise ValueError('PolicySnapshot: unknown fields')
        required = allowed - {'committee_policy'}
        if not required <= set(data):
            raise ValueError('PolicySnapshot: missing fields')
        cp = data.get('committee_policy')
        return cls(
            schema_version=_read(data['schema_version'], int),
            policy_revision_id=_read(data['policy_revision_id'], str),
            scope_id=_read(data['scope_id'], str),
            term_id=_read(data['term_id'], str),
            resource_revision=_read(data['resource_revision'], int),
            teaching_dates=_read(data['teaching_dates'], tuple[date, ...]),
            committee_policy=CommitteePolicySnapshot.from_dict(cp) if cp is not None else None,
        )

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> 'PolicySnapshot':
        return cls.from_map(data)

    def to_dict(self) -> dict[str, Any]:
        return self.to_map()

    def policy_hash(self) -> str:
        canonical = json.dumps(self.to_dict(), sort_keys=True, separators=(',', ':'))
        return hashlib.sha256(canonical.encode('utf-8')).hexdigest()


@dataclass(frozen=True)
class ValidationIssue(_Record):
    rule_id: str
    severity: str
    message: str
    offering_ids: tuple[str, ...]
    resource_ids: tuple[str, ...]
    source_refs: tuple[SourceRef, ...]

    def __post_init__(self):
        super().__post_init__()
        if self.severity not in ('error', 'warning'):
            raise ValueError('Unknown issue severity')


@dataclass(frozen=True)
class ValidationReport(_Record):
    schema_version: int
    input_revision_id: str
    policy_revision_id: str
    resource_revision: int
    issues: tuple[ValidationIssue, ...]

    def __post_init__(self):
        super().__post_init__()
        if self.schema_version != 1 or self.resource_revision < 1:
            raise ValueError('Unsupported report version/revision')

    @property
    def ok(self):
        return not any(issue.severity == 'error' for issue in self.issues)


@dataclass(frozen=True)
class NormalizedInput(_Record):
    schema_version: int
    input_revision_id: str
    scope_id: str
    term_id: str
    policy_revision_id: str
    resource_revision: int
    timezone: str
    teaching_dates: tuple[date, ...]
    offerings: tuple[Offering, ...]
    faculty: tuple[Faculty, ...]
    rooms: tuple[Room, ...]
    external_reservations: tuple[Assignment, ...]
    approved_exclusions: tuple[ApprovedExclusion, ...]

    def __post_init__(self):
        super().__post_init__()
        _dates(self.teaching_dates)
        if self.schema_version != 1 or self.resource_revision < 1:
            raise ValueError('Unsupported input version/revision')
        faculty = {v.id for v in self.faculty}
        rooms = {v.id for v in self.rooms}
        offerings = {v.id for v in self.offerings}
        for values in (self.faculty, self.rooms, self.offerings):
            if len({v.id for v in values}) != len(values):
                raise ValueError('Duplicate resource identity')
        for offering in self.offerings:
            if not set(offering.room_criteria.eligible_room_ids) <= rooms:
                raise ValueError('Unknown room identity')
            for teacher in offering.teacher_assignments:
                if teacher.faculty_id not in faculty or not set(teacher.effective_dates) <= set(self.teaching_dates):
                    raise ValueError('Unknown teacher identity or teaching date')
        for reservation in self.external_reservations:
            if (not set(reservation.faculty_ids) <= faculty or
                (reservation.room_id is not None and reservation.room_id not in rooms)):
                raise ValueError('Unknown external reservation resource')
        if any(v.offering_id not in offerings for v in self.approved_exclusions):
            raise ValueError('Unknown excluded offering')

