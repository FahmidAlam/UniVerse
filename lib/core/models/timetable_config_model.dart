class TimetableRoom {
  final String id;
  final String name;
  final String? building;
  final bool isLab;
  final bool isGallery;
  final bool isActive;

  const TimetableRoom({
    required this.id,
    required this.name,
    this.building,
    this.isLab = false,
    this.isGallery = false,
    this.isActive = true,
  });

  factory TimetableRoom.fromMap(Map<String, dynamic> m) => TimetableRoom(
        id: m['id'] as String,
        name: (m['name'] as String?) ?? '',
        building: m['building'] as String?,
        isLab: (m['is_lab'] as bool?) ?? false,
        isGallery: (m['is_gallery'] as bool?) ?? false,
        isActive: (m['is_active'] as bool?) ?? true,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'building': building,
        'is_lab': isLab,
        'is_gallery': isGallery,
        'is_active': isActive,
      };

  String get kind => isLab ? 'Lab' : (isGallery ? 'Gallery' : 'Theory');
}

class TimetableFaculty {
  final String id;
  final String acronym;
  final String? fullName;
  final String? dept;
  final String? designation;
  final List<String> offDays;
  final bool isActive;

  const TimetableFaculty({
    required this.id,
    required this.acronym,
    this.fullName,
    this.dept,
    this.designation,
    this.offDays = const [],
    this.isActive = true,
  });

  factory TimetableFaculty.fromMap(Map<String, dynamic> m) => TimetableFaculty(
        id: m['id'] as String,
        acronym: (m['acronym'] as String?) ?? '',
        fullName: m['full_name'] as String?,
        dept: m['dept'] as String?,
        designation: m['designation'] as String?,
        offDays: ((m['off_days'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        isActive: (m['is_active'] as bool?) ?? true,
      );

  Map<String, dynamic> toMap() => {
        'acronym': acronym,
        'full_name': fullName,
        'dept': dept,
        'designation': designation,
        'off_days': offDays,
        'is_active': isActive,
      };

  String get displayName =>
      (fullName != null && fullName!.isNotEmpty) ? fullName! : acronym;

  TimetableFaculty copyWith({String? fullName, List<String>? offDays}) =>
      TimetableFaculty(
        id: id,
        acronym: acronym,
        fullName: fullName ?? this.fullName,
        dept: dept,
        designation: designation,
        offDays: offDays ?? this.offDays,
        isActive: isActive,
      );
}

/// Every university rule the timetable engine obeys.
///
/// These used to be constants inside `solver.py` — a 14-week term, a 7:00pm
/// period that could never be used, a Friday-only period block, one batch per
/// term. The university changes all of them (summer vs winter timings,
/// bi- vs tri-semester), so they live here and reach the engine as data.
/// Changing them must never require a code change or a new build.
class TimetableSettings {
  final String? semesterLabel;
  final List<dynamic> periods;

  /// Days taught. Empty = the engine's Sun–Sat default; keep in step with
  /// [AppConstants.weekDays].
  final List<String> workingDays;

  /// Teaching weeks in the term. Converts a course's whole-term class count
  /// into the number of weekly sessions the routine must contain.
  final int weeksInTerm;

  /// Periods unavailable on one specific day, e.g. `{'Friday': [4]}`.
  final Map<String, List<int>> blockedPeriods;

  /// Real periods that are held back unless [allowOnlinePeriods] is set —
  /// the department's 7:00pm "OL Class" slot.
  final List<int> onlinePeriods;
  final bool allowOnlinePeriods;

  /// Periods disabled on every day.
  final List<int> excludedPeriods;

  /// Batch → study semester. Empty falls back to counting down from the
  /// newest batch, which only holds with one intake per term.
  final Map<String, int> semesterMap;

  /// Legacy single-purpose flag, folded into [blockedPeriods] by the engine.
  final bool fridayNoP4;
  final String serviceScope;
  final Map<String, dynamic> weights;

  const TimetableSettings({
    this.semesterLabel,
    this.periods = const [],
    this.workingDays = const [],
    this.weeksInTerm = 14,
    this.blockedPeriods = const {},
    this.onlinePeriods = const [7],
    this.allowOnlinePeriods = false,
    this.excludedPeriods = const [],
    this.semesterMap = const {},
    this.fridayNoP4 = true,
    this.serviceScope = 'resource_only',
    this.weights = const {},
  });

  factory TimetableSettings.fromMap(Map<String, dynamic> m) => TimetableSettings(
        semesterLabel: m['semester_label'] as String?,
        periods: (m['periods'] as List?) ?? const [],
        workingDays: _stringList(m['working_days']),
        weeksInTerm: (m['weeks_in_term'] as num?)?.toInt() ?? 14,
        blockedPeriods: _intListMap(m['blocked_periods']),
        onlinePeriods: _intList(m['online_periods'], fallback: const [7]),
        allowOnlinePeriods: (m['allow_online_periods'] as bool?) ?? false,
        excludedPeriods: _intList(m['excluded_periods']),
        semesterMap: _intMap(m['semester_map']),
        fridayNoP4: (m['friday_no_p4'] as bool?) ?? true,
        serviceScope: (m['service_scope'] as String?) ?? 'resource_only',
        weights: (m['weights'] as Map?)?.cast<String, dynamic>() ?? const {},
      );

  Map<String, dynamic> toMap() => {
        'id': 1,
        'semester_label': semesterLabel,
        'periods': periods,
        'working_days': workingDays.isEmpty ? null : workingDays,
        'weeks_in_term': weeksInTerm,
        'blocked_periods': blockedPeriods,
        'online_periods': onlinePeriods,
        'allow_online_periods': allowOnlinePeriods,
        'excluded_periods': excludedPeriods,
        'semester_map': semesterMap,
        'friday_no_p4': fridayNoP4,
        'service_scope': serviceScope,
        'weights': weights,
      };

  int weight(String key, int fallback) {
    final v = weights[key];
    return v is num ? v.toInt() : fallback;
  }

  TimetableSettings copyWith({
    String? semesterLabel,
    List<dynamic>? periods,
    List<String>? workingDays,
    int? weeksInTerm,
    Map<String, List<int>>? blockedPeriods,
    List<int>? onlinePeriods,
    bool? allowOnlinePeriods,
    List<int>? excludedPeriods,
    Map<String, int>? semesterMap,
    bool? fridayNoP4,
    String? serviceScope,
    Map<String, dynamic>? weights,
  }) =>
      TimetableSettings(
        semesterLabel: semesterLabel ?? this.semesterLabel,
        periods: periods ?? this.periods,
        workingDays: workingDays ?? this.workingDays,
        weeksInTerm: weeksInTerm ?? this.weeksInTerm,
        blockedPeriods: blockedPeriods ?? this.blockedPeriods,
        onlinePeriods: onlinePeriods ?? this.onlinePeriods,
        allowOnlinePeriods: allowOnlinePeriods ?? this.allowOnlinePeriods,
        excludedPeriods: excludedPeriods ?? this.excludedPeriods,
        semesterMap: semesterMap ?? this.semesterMap,
        fridayNoP4: fridayNoP4 ?? this.fridayNoP4,
        serviceScope: serviceScope ?? this.serviceScope,
        weights: weights ?? this.weights,
      );

  /// Why this period list cannot be saved, or null when it is usable.
  ///
  /// The engine trusts these boundaries completely — it schedules into them and
  /// writes them straight into `routines` — so a typo here becomes a wrong
  /// class time for every student. Checked before the row reaches Postgres.
  static String? validatePeriods(List<dynamic> periods) {
    final maps = periods.whereType<Map>().toList();
    if (maps.isEmpty) return 'Add at least one class period.';

    final seen = <int>{};
    int? prevEnd;
    for (final p in maps) {
      final idx = (p['idx'] as num?)?.toInt();
      if (idx == null || idx < 1) return 'Every period needs a number.';
      if (!seen.add(idx)) return 'Period $idx appears more than once.';

      final start = _minutes(p['start']);
      final end = _minutes(p['end']);
      if (start == null || end == null) {
        return 'Period $idx has a time that cannot be read. Use HH:MM.';
      }
      if (end <= start) {
        return 'Period $idx ends before it starts.';
      }
      if (prevEnd != null && start < prevEnd) {
        return 'Period $idx starts before the previous one ends.';
      }
      prevEnd = end;
    }
    return null;
  }

  static int? _minutes(dynamic v) {
    final parts = v?.toString().split(':') ?? const [];
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null || h > 23 || m > 59) return null;
    return h * 60 + m;
  }

  static List<String> _stringList(dynamic v) => v is List
      ? [for (final e in v) e.toString()]
      : const [];

  static List<int> _intList(dynamic v, {List<int> fallback = const []}) {
    if (v is! List) return fallback;
    return [
      for (final e in v)
        if (e is num) e.toInt() else int.tryParse(e.toString()) ?? -1,
    ]..removeWhere((e) => e < 0);
  }

  static Map<String, List<int>> _intListMap(dynamic v) {
    if (v is! Map) return const {};
    return {
      for (final entry in v.entries)
        entry.key.toString(): _intList(entry.value),
    };
  }

  static Map<String, int> _intMap(dynamic v) {
    if (v is! Map) return const {};
    final out = <String, int>{};
    for (final entry in v.entries) {
      final n = entry.value is num
          ? (entry.value as num).toInt()
          : int.tryParse(entry.value.toString());
      if (n != null) out[entry.key.toString()] = n;
    }
    return out;
  }
}

/// One faculty member's relationship to one course.
///
/// This is a check on the **distribution**, not an instruction to the solver.
/// The workbook names the teacher for every offering and the engine's CP-SAT
/// model only chooses (day, period) — it never picks a teacher. So this cannot
/// stop the scheduler assigning the wrong person; it catches a distribution
/// row that gives a course to someone who is not qualified for it, before the
/// routine can be published.
///
/// [priority] orders the courses a teacher prefers (1 = most preferred). It is
/// stored for preference-ordering and reporting; nothing optimises against it
/// while teacher identity comes from the workbook.
class TimetableCourseEligibility {
  final String id;
  final String acronym;
  final String courseCode;
  final bool isEligible;
  final int? priority;

  const TimetableCourseEligibility({
    required this.id,
    required this.acronym,
    required this.courseCode,
    this.isEligible = true,
    this.priority,
  });

  factory TimetableCourseEligibility.fromMap(Map<String, dynamic> m) =>
      TimetableCourseEligibility(
        id: m['id'] as String,
        acronym: (m['acronym'] as String?) ?? '',
        courseCode: (m['course_code'] as String?) ?? '',
        isEligible: (m['is_eligible'] as bool?) ?? true,
        priority: (m['priority'] as num?)?.toInt(),
      );

  Map<String, dynamic> toMap() => {
        'acronym': acronym,
        'course_code': courseCode,
        'is_eligible': isEligible,
        'priority': priority,
      };

  TimetableCourseEligibility copyWith({bool? isEligible, int? priority}) =>
      TimetableCourseEligibility(
        id: id,
        acronym: acronym,
        courseCode: courseCode,
        isEligible: isEligible ?? this.isEligible,
        priority: priority ?? this.priority,
      );
}
