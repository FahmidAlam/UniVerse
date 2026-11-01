"""Schema-v1 canonical catalog. Labels never substitute for resource identities.

This additive contract is not yet connected to legacy ingestion or publication.
Academic progression is supplied explicitly; institutional rules are not inferred.
"""
from __future__ import annotations

from dataclasses import dataclass, fields
from datetime import date
import re
import types
from typing import get_args, get_origin, get_type_hints
from uuid import UUID

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
        if not isinstance(data, dict) or set(data) != names:
            raise ValueError(f'{cls.__name__}: missing or unknown fields')
        hints = get_type_hints(cls)
        return cls(**{name: _read(data[name], hints[name]) for name in names})

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
class PolicySnapshot(_Record):
    schema_version: int
    policy_revision_id: str
    scope_id: str
    term_id: str
    resource_revision: int
    teaching_dates: tuple[date, ...]

    def __post_init__(self):
        super().__post_init__()
        _dates(self.teaching_dates)
        if self.schema_version != 1 or self.resource_revision < 1:
            raise ValueError('Unsupported policy version/revision')


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

