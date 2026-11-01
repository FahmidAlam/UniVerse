// Additive schema-v1 catalog; not yet wired into legacy services or publishing.
// Canonical UUIDs identify resources; labels and aliases never manufacture IDs.

abstract class AcademicRecord {
  String get id;
  Map<String, dynamic> toMap();
}

class Department implements AcademicRecord {
  @override
  final String id;
  final String code;
  final String name;
  final bool isActive;
  Department._({
    required this.id,
    required this.code,
    required this.name,
    required this.isActive,
  });
  factory Department.fromMap(Map<String, dynamic> m) {
    _fields(m, const ['id', 'code', 'name', 'is_active']);
    return Department._(
      id: _id(m, 'id'),
      code: _text(m, 'code'),
      name: _text(m, 'name'),
      isActive: _boolean(m, 'is_active'),
    );
  }
  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'code': code,
        'name': name,
        'is_active': isActive,
      };
}

class AcademicCalendar implements AcademicRecord {
  @override
  final String id;
  final String name;
  final String timezone;
  AcademicCalendar._({
    required this.id,
    required this.name,
    required this.timezone,
  });
  factory AcademicCalendar.fromMap(Map<String, dynamic> m) {
    _fields(m, const ['id', 'name', 'timezone']);
    return AcademicCalendar._(
      id: _id(m, 'id'),
      name: _text(m, 'name'),
      timezone: _text(m, 'timezone'),
    );
  }
  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'timezone': timezone,
      };
}

class AcademicYear implements AcademicRecord {
  @override
  final String id;
  final String calendarId;
  final String label;
  AcademicYear._({
    required this.id,
    required this.calendarId,
    required this.label,
  });
  factory AcademicYear.fromMap(Map<String, dynamic> m) {
    _fields(m, const ['id', 'calendar_id', 'label']);
    return AcademicYear._(
      id: _id(m, 'id'),
      calendarId: _id(m, 'calendar_id'),
      label: _text(m, 'label'),
    );
  }
  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'calendar_id': calendarId,
        'label': label,
      };
}

class AcademicProgram implements AcademicRecord {
  @override
  final String id;
  final String departmentId;
  final String calendarId;
  final String code;
  final String title;
  final bool isActive;
  AcademicProgram._({
    required this.id,
    required this.departmentId,
    required this.calendarId,
    required this.code,
    required this.title,
    required this.isActive,
  });
  factory AcademicProgram.fromMap(Map<String, dynamic> m) {
    _fields(m, const [
      'id',
      'department_id',
      'calendar_id',
      'code',
      'title',
      'is_active'
    ]);
    return AcademicProgram._(
      id: _id(m, 'id'),
      departmentId: _id(m, 'department_id'),
      calendarId: _id(m, 'calendar_id'),
      code: _text(m, 'code'),
      title: _text(m, 'title'),
      isActive: _boolean(m, 'is_active'),
    );
  }
  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'department_id': departmentId,
        'calendar_id': calendarId,
        'code': code,
        'title': title,
        'is_active': isActive,
      };
}

class AcademicTerm implements AcademicRecord {
  @override
  final String id;
  final String academicYearId;
  final int sequence;
  final String label;
  final DateTime startDate;
  final DateTime endDate;
  AcademicTerm._({
    required this.id,
    required this.academicYearId,
    required this.sequence,
    required this.label,
    required this.startDate,
    required this.endDate,
  }) {
    if (sequence < 1 || startDate.isAfter(endDate)) {
      throw const FormatException('Invalid term sequence/date range');
    }
  }
  factory AcademicTerm.fromMap(Map<String, dynamic> m) {
    _fields(m, const [
      'id',
      'academic_year_id',
      'sequence',
      'label',
      'start_date',
      'end_date'
    ]);
    return AcademicTerm._(
      id: _id(m, 'id'),
      academicYearId: _id(m, 'academic_year_id'),
      sequence: _integer(m, 'sequence'),
      label: _text(m, 'label'),
      startDate: _date(m, 'start_date'),
      endDate: _date(m, 'end_date'),
    );
  }
  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'academic_year_id': academicYearId,
        'sequence': sequence,
        'label': label,
        'start_date': _day(startDate),
        'end_date': _day(endDate),
      };
}

class Cohort implements AcademicRecord {
  @override
  final String id;
  final String programId;
  final String code;
  final DateTime admittedOn;
  final String status;
  final DateTime? graduatedOn;
  final DateTime? archivedOn;
  Cohort._({
    required this.id,
    required this.programId,
    required this.code,
    required this.admittedOn,
    required this.status,
    required this.graduatedOn,
    required this.archivedOn,
  }) {
    if (!const {'active', 'graduated', 'archived'}.contains(status) ||
        (status == 'active' && graduatedOn != null) ||
        (status == 'graduated' && graduatedOn == null) ||
        ((status == 'archived') != (archivedOn != null)) ||
        (graduatedOn != null && graduatedOn!.isBefore(admittedOn)) ||
        (archivedOn != null && archivedOn!.isBefore(admittedOn)) ||
        (graduatedOn != null &&
            archivedOn != null &&
            archivedOn!.isBefore(graduatedOn!))) {
      throw const FormatException('Inconsistent cohort lifecycle dates');
    }
  }
  factory Cohort.fromMap(Map<String, dynamic> m) {
    _fields(m, const [
      'id',
      'program_id',
      'code',
      'admitted_on',
      'status',
      'graduated_on',
      'archived_on'
    ]);
    return Cohort._(
      id: _id(m, 'id'),
      programId: _id(m, 'program_id'),
      code: _text(m, 'code'),
      admittedOn: _date(m, 'admitted_on'),
      status: _text(m, 'status'),
      graduatedOn: m['graduated_on'] == null ? null : _date(m, 'graduated_on'),
      archivedOn: m['archived_on'] == null ? null : _date(m, 'archived_on'),
    );
  }
  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'program_id': programId,
        'code': code,
        'admitted_on': _day(admittedOn),
        'status': status,
        'graduated_on': graduatedOn == null ? null : _day(graduatedOn!),
        'archived_on': archivedOn == null ? null : _day(archivedOn!),
      };
}

class StudentGroup implements AcademicRecord {
  @override
  final String id;
  final String cohortId;
  final String code;
  final bool isActive;
  StudentGroup._({
    required this.id,
    required this.cohortId,
    required this.code,
    required this.isActive,
  });
  factory StudentGroup.fromMap(Map<String, dynamic> m) {
    _fields(m, const ['id', 'cohort_id', 'code', 'is_active']);
    return StudentGroup._(
      id: _id(m, 'id'),
      cohortId: _id(m, 'cohort_id'),
      code: _text(m, 'code'),
      isActive: _boolean(m, 'is_active'),
    );
  }
  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'cohort_id': cohortId,
        'code': code,
        'is_active': isActive,
      };
}

class CohortTerm implements AcademicRecord {
  @override
  final String id;
  final String cohortId;
  final String termId;
  final int studyStage;
  CohortTerm._({
    required this.id,
    required this.cohortId,
    required this.termId,
    required this.studyStage,
  }) {
    if (studyStage < 1) {
      throw const FormatException('Study stage must be positive');
    }
  }
  factory CohortTerm.fromMap(Map<String, dynamic> m) {
    _fields(m, const ['id', 'cohort_id', 'term_id', 'study_stage']);
    return CohortTerm._(
      id: _id(m, 'id'),
      cohortId: _id(m, 'cohort_id'),
      termId: _id(m, 'term_id'),
      studyStage: _integer(m, 'study_stage'),
    );
  }
  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'cohort_id': cohortId,
        'term_id': termId,
        'study_stage': studyStage,
      };
}

class Faculty implements AcademicRecord {
  @override
  final String id;
  final String? homeDepartmentId;
  final String displayName;
  final bool isActive;
  Faculty._({
    required this.id,
    required this.homeDepartmentId,
    required this.displayName,
    required this.isActive,
  });
  factory Faculty.fromMap(Map<String, dynamic> m) {
    _fields(m, const ['id', 'home_department_id', 'display_name', 'is_active']);
    return Faculty._(
      id: _id(m, 'id'),
      homeDepartmentId:
          m['home_department_id'] == null ? null : _id(m, 'home_department_id'),
      displayName: _text(m, 'display_name'),
      isActive: _boolean(m, 'is_active'),
    );
  }
  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'home_department_id': homeDepartmentId,
        'display_name': displayName,
        'is_active': isActive,
      };
}

class Room implements AcademicRecord {
  @override
  final String id;
  final String name;
  final String? campus;
  final int? capacity;
  final List<String> features;
  final bool isActive;
  Room._({
    required this.id,
    required this.name,
    required this.campus,
    required this.capacity,
    required List<String> features,
    required this.isActive,
  }) : features = List.unmodifiable(features) {
    if ((capacity != null && capacity! < 1) ||
        features.toSet().length != features.length) {
      throw const FormatException('Invalid room capacity/features');
    }
  }
  factory Room.fromMap(Map<String, dynamic> m) {
    _fields(
        m, const ['id', 'name', 'campus', 'capacity', 'features', 'is_active']);
    return Room._(
      id: _id(m, 'id'),
      name: _text(m, 'name'),
      campus: m['campus'] == null ? null : _text(m, 'campus'),
      capacity: m['capacity'] == null ? null : _integer(m, 'capacity'),
      features: _strings(m, 'features', ids: false),
      isActive: _boolean(m, 'is_active'),
    );
  }
  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'campus': campus,
        'capacity': capacity,
        'features': List<String>.of(features),
        'is_active': isActive,
      };
}

class SchedulingScope implements AcademicRecord {
  @override
  final String id;
  final String departmentId;
  final String? programId;
  final String termId;
  SchedulingScope._({
    required this.id,
    required this.departmentId,
    required this.programId,
    required this.termId,
  });
  factory SchedulingScope.fromMap(Map<String, dynamic> m) {
    _fields(m, const ['id', 'department_id', 'program_id', 'term_id']);
    return SchedulingScope._(
      id: _id(m, 'id'),
      departmentId: _id(m, 'department_id'),
      programId: m['program_id'] == null ? null : _id(m, 'program_id'),
      termId: _id(m, 'term_id'),
    );
  }
  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'department_id': departmentId,
        'program_id': programId,
        'term_id': termId,
      };
}

class GroupAlias implements AcademicRecord {
  @override
  final String id;
  final String cohortId;
  final String label;
  final List<String> groupIds;
  final bool reviewed;
  GroupAlias._({
    required this.id,
    required this.cohortId,
    required this.label,
    required List<String> groupIds,
    required this.reviewed,
  }) : groupIds = List.unmodifiable(groupIds) {
    if (groupIds.isEmpty || groupIds.toSet().length != groupIds.length) {
      throw const FormatException('Invalid atomic group IDs');
    }
  }
  factory GroupAlias.fromMap(Map<String, dynamic> m) {
    _fields(m, const ['id', 'cohort_id', 'label', 'group_ids', 'reviewed']);
    return GroupAlias._(
      id: _id(m, 'id'),
      cohortId: _id(m, 'cohort_id'),
      label: _text(m, 'label'),
      groupIds: _strings(m, 'group_ids', ids: true),
      reviewed: _boolean(m, 'reviewed'),
    );
  }
  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'cohort_id': cohortId,
        'label': label,
        'group_ids': List<String>.of(groupIds),
        'reviewed': reviewed,
      };
}

class AcademicCatalog {
  int get schemaVersion => 1;
  final List<Department> departments;
  final List<AcademicCalendar> calendars;
  final List<AcademicYear> academicYears;
  final List<AcademicProgram> programs;
  final List<AcademicTerm> terms;
  final List<Cohort> cohorts;
  final List<StudentGroup> studentGroups;
  final List<CohortTerm> cohortTerms;
  final List<Faculty> faculty;
  final List<Room> rooms;
  final List<SchedulingScope> scopes;
  final List<GroupAlias> groupAliases;
  AcademicCatalog._({
    required List<Department> departments,
    required List<AcademicCalendar> calendars,
    required List<AcademicYear> academicYears,
    required List<AcademicProgram> programs,
    required List<AcademicTerm> terms,
    required List<Cohort> cohorts,
    required List<StudentGroup> studentGroups,
    required List<CohortTerm> cohortTerms,
    required List<Faculty> faculty,
    required List<Room> rooms,
    required List<SchedulingScope> scopes,
    required List<GroupAlias> groupAliases,
  })  : departments = List.unmodifiable(departments),
        calendars = List.unmodifiable(calendars),
        academicYears = List.unmodifiable(academicYears),
        programs = List.unmodifiable(programs),
        terms = List.unmodifiable(terms),
        cohorts = List.unmodifiable(cohorts),
        studentGroups = List.unmodifiable(studentGroups),
        cohortTerms = List.unmodifiable(cohortTerms),
        faculty = List.unmodifiable(faculty),
        rooms = List.unmodifiable(rooms),
        scopes = List.unmodifiable(scopes),
        groupAliases = List.unmodifiable(groupAliases) {
    _validate();
  }
  factory AcademicCatalog.fromMap(Map<String, dynamic> m) {
    _fields(m, const [
      'schema_version',
      'departments',
      'calendars',
      'academic_years',
      'programs',
      'terms',
      'cohorts',
      'student_groups',
      'cohort_terms',
      'faculty',
      'rooms',
      'scopes',
      'group_aliases'
    ]);
    if (_integer(m, 'schema_version') != 1) {
      throw const FormatException('Unsupported catalog schema_version');
    }
    return AcademicCatalog._(
      departments: _rows(m, 'departments', Department.fromMap),
      calendars: _rows(m, 'calendars', AcademicCalendar.fromMap),
      academicYears: _rows(m, 'academic_years', AcademicYear.fromMap),
      programs: _rows(m, 'programs', AcademicProgram.fromMap),
      terms: _rows(m, 'terms', AcademicTerm.fromMap),
      cohorts: _rows(m, 'cohorts', Cohort.fromMap),
      studentGroups: _rows(m, 'student_groups', StudentGroup.fromMap),
      cohortTerms: _rows(m, 'cohort_terms', CohortTerm.fromMap),
      faculty: _rows(m, 'faculty', Faculty.fromMap),
      rooms: _rows(m, 'rooms', Room.fromMap),
      scopes: _rows(m, 'scopes', SchedulingScope.fromMap),
      groupAliases: _rows(m, 'group_aliases', GroupAlias.fromMap),
    );
  }
  Map<String, dynamic> toMap() => {
        'schema_version': schemaVersion,
        'departments': departments.map((r) => r.toMap()).toList(),
        'calendars': calendars.map((r) => r.toMap()).toList(),
        'academic_years': academicYears.map((r) => r.toMap()).toList(),
        'programs': programs.map((r) => r.toMap()).toList(),
        'terms': terms.map((r) => r.toMap()).toList(),
        'cohorts': cohorts.map((r) => r.toMap()).toList(),
        'student_groups': studentGroups.map((r) => r.toMap()).toList(),
        'cohort_terms': cohortTerms.map((r) => r.toMap()).toList(),
        'faculty': faculty.map((r) => r.toMap()).toList(),
        'rooms': rooms.map((r) => r.toMap()).toList(),
        'scopes': scopes.map((r) => r.toMap()).toList(),
        'group_aliases': groupAliases.map((r) => r.toMap()).toList(),
      };
  void _validate() {
    final departmentsById = _index(departments);
    final calendarsById = _index(calendars);
    final academicYearsById = _index(academicYears);
    final programsById = _index(programs);
    final termsById = _index(terms);
    final cohortsById = _index(cohorts);
    final studentGroupsById = _index(studentGroups);
    _index(cohortTerms);
    _index(faculty);
    _index(rooms);
    _index(scopes);
    _index(groupAliases);
    for (final year in academicYears) {
      _ref(calendarsById, year.calendarId);
    }
    for (final program in programs) {
      _ref(departmentsById, program.departmentId);
      _ref(calendarsById, program.calendarId);
    }
    for (final term in terms) {
      _ref(academicYearsById, term.academicYearId);
    }
    for (final cohort in cohorts) {
      _ref(programsById, cohort.programId);
    }
    for (final group in studentGroups) {
      _ref(cohortsById, group.cohortId);
    }
    for (final row in cohortTerms) {
      final program =
          _ref(programsById, _ref(cohortsById, row.cohortId).programId);
      final year =
          _ref(academicYearsById, _ref(termsById, row.termId).academicYearId);
      if (program.calendarId != year.calendarId) {
        throw const FormatException('Cohort term belongs to another calendar');
      }
    }
    for (final teacher in faculty) {
      if (teacher.homeDepartmentId != null) {
        _ref(departmentsById, teacher.homeDepartmentId!);
      }
    }
    for (final scope in scopes) {
      _ref(departmentsById, scope.departmentId);
      final year =
          _ref(academicYearsById, _ref(termsById, scope.termId).academicYearId);
      if (scope.programId != null) {
        final program = _ref(programsById, scope.programId!);
        if (program.departmentId != scope.departmentId ||
            program.calendarId != year.calendarId) {
          throw const FormatException(
              'Scope program department/calendar mismatch');
        }
      }
    }
    for (final alias in groupAliases) {
      _ref(cohortsById, alias.cohortId);
      if (alias.groupIds.any(
          (id) => _ref(studentGroupsById, id).cohortId != alias.cohortId)) {
        throw const FormatException('Group alias crosses cohort boundaries');
      }
    }
    _unique(departments, (r) => _label(r.code), 'department code');
    _unique(programs, (r) => (r.departmentId, _label(r.code)), 'program code');
    _unique(
        academicYears, (r) => (r.calendarId, _label(r.label)), 'academic year');
    _unique(terms, (r) => (r.academicYearId, r.sequence), 'term sequence');
    _unique(cohorts, (r) => (r.programId, _label(r.code)), 'cohort code');
    _unique(studentGroups, (r) => (r.cohortId, _label(r.code)), 'group code');
    _unique(cohortTerms, (r) => (r.cohortId, r.termId), 'cohort term');
    _unique(scopes, (r) => (r.departmentId, r.programId, r.termId), 'scope');
    _unique(groupAliases, (r) => (r.cohortId, _label(r.label)), 'group alias');
  }

  List<StudentGroup> resolveGroupAlias(String cohortId, String label) {
    final matches = groupAliases
        .where(
            (a) => a.cohortId == cohortId && _label(a.label) == _label(label))
        .toList();
    if (matches.length != 1) {
      throw const FormatException('Unknown or ambiguous group alias');
    }
    final alias = matches.single;
    if (!alias.reviewed) {
      throw const FormatException('Group alias has not been reviewed');
    }
    final groups = _index(studentGroups);
    return List.unmodifiable(alias.groupIds.map((id) => groups[id]!));
  }
}

void _fields(Map<String, dynamic> m, List<String> names) {
  if (m.length != names.length || !names.every(m.containsKey)) {
    throw const FormatException('Missing or unknown catalog fields');
  }
}

String _text(Map<String, dynamic> m, String key) {
  final value = m[key];
  if (value is! String || _trim(value).isEmpty) {
    throw FormatException('Expected nonempty text: $key');
  }
  return value;
}

String _id(Map<String, dynamic> m, String key) {
  final value = _text(m, key);
  if (value.length != 36 ||
      !RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')
          .hasMatch(value)) {
    throw FormatException('Expected canonical UUID: $key');
  }
  return value;
}

int _integer(Map<String, dynamic> m, String key) {
  final value = m[key];
  if (value is! int) throw FormatException('Expected integer: $key');
  return value;
}

bool _boolean(Map<String, dynamic> m, String key) {
  final value = m[key];
  if (value is! bool) throw FormatException('Expected boolean: $key');
  return value;
}

DateTime _date(Map<String, dynamic> m, String key) {
  final value = _text(m, key);
  if (!RegExp(r'^[0-9]{4}-[0-9]{2}-[0-9]{2}$').hasMatch(value) ||
      value.length != 10) {
    throw FormatException('Expected ISO calendar date: $key');
  }
  final parts = value.split('-').map(int.parse).toList();
  final result = DateTime.utc(parts[0], parts[1], parts[2]);
  if (parts[0] < 1 ||
      result.year != parts[0] ||
      result.month != parts[1] ||
      result.day != parts[2]) {
    throw FormatException('Invalid calendar date: $key');
  }
  return result;
}

String _day(DateTime value) => value.toIso8601String().substring(0, 10);
// Unicode White_Space plus BOM, kept identical to engine/domain.py.
const _edgeWhitespace =
    '\u0009\u000a\u000b\u000c\u000d\u0020\u0085\u00a0\u1680\u2000\u2001\u2002\u2003\u2004\u2005\u2006\u2007\u2008\u2009\u200a\u2028\u2029\u202f\u205f\u3000\ufeff';

String _trim(String value) {
  var start = 0;
  var end = value.length;
  while (start < end && _edgeWhitespace.contains(value[start])) {
    start++;
  }
  while (end > start && _edgeWhitespace.contains(value[end - 1])) {
    end--;
  }
  return value.substring(start, end);
}

String _label(String value) => _trim(value).toLowerCase();

List<String> _strings(Map<String, dynamic> m, String key, {bool ids = false}) {
  final value = m[key];
  if (value is! List) throw FormatException('Expected array: $key');
  return value
      .map((v) =>
          ids ? _id({'value': v}, 'value') : _text({'value': v}, 'value'))
      .toList();
}

List<T> _rows<T>(Map<String, dynamic> m, String key,
    T Function(Map<String, dynamic>) parse) {
  final value = m[key];
  if (value is! List) throw FormatException('Expected array: $key');
  return value.map((row) {
    if (row is! Map || row.keys.any((k) => k is! String)) {
      throw FormatException('Expected object in $key');
    }
    return parse(Map<String, dynamic>.from(row));
  }).toList();
}

void _unique<T>(List<T> rows, Object Function(T) key, String label) {
  final keys = rows.map(key).toSet();
  if (keys.length != rows.length) throw FormatException('Duplicate $label');
}

Map<String, T> _index<T extends AcademicRecord>(List<T> rows) {
  _unique(rows, (r) => r.id, 'record ID');
  return {for (final row in rows) row.id: row};
}

T _ref<T extends Object>(Map<String, T> index, String id) {
  if (!index.containsKey(id)) {
    throw FormatException('Unknown catalog reference: $id');
  }
  return index[id]!;
}
