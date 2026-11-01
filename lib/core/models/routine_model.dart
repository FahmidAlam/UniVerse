import 'package:universe/core/constants/app_enums.dart';
import 'package:universe/core/utils/date_utils.dart';

class RoutineEntry {
  final String id;
  final String day;
  final String timeStart;
  final String timeEnd;
  final String subject;
  final String subjectCode;
  final String? teacherName;
  final String? teacherCode;
  final List<String> coTeacherCodes;
  final String room;
  final String batch;
  final String section;
  final int semester;
  final bool isActive;

  /// Service / non-CSE classes (GED, or a course this department teaches to
  /// another). They are not part of any CSE cohort's routine, but they hold
  /// real teacher and room time, so Room Availability and Find Teacher need
  /// them. They used to be generated and then never published.
  final bool isService;

  /// Additive canonical links; legacy labels and auth IDs stay authoritative until reviewed mapping.
  final String? schedulingScopeId;
  final String? cohortId;
  final String? studentGroupId;
  final String? facultyId;
  final String? roomId;

  const RoutineEntry({
    required this.id,
    this.schedulingScopeId,
    this.cohortId,
    this.studentGroupId,
    this.facultyId,
    this.roomId,
    required this.day,
    required this.timeStart,
    required this.timeEnd,
    required this.subject,
    required this.subjectCode,
    this.teacherName,
    this.teacherCode,
    this.coTeacherCodes = const [],
    required this.room,
    required this.batch,
    required this.section,
    required this.semester,
    this.isActive = true,
    this.isService = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'day': day,
      'time_start': timeStart,
      'time_end': timeEnd,
      'subject': subject,
      'subject_code': subjectCode,
      'teacher_name': teacherName,
      'teacher_code': teacherCode,
      'room': room,
      'batch': batch,
      'section': section,
      'semester': semester,
      'is_active': isActive,
      'is_service': isService,
      if (schedulingScopeId != null) 'scheduling_scope_id': schedulingScopeId,
      if (cohortId != null) 'cohort_id': cohortId,
      if (studentGroupId != null) 'student_group_id': studentGroupId,
      if (facultyId != null) 'faculty_id': facultyId,
      if (roomId != null) 'room_id': roomId,
    };
  }

  /// Private draft persistence retains identities the legacy hosted RPC cannot.
  Map<String, dynamic> toDraftMap() =>
      {'id': id, ...toMap(), 'teachers': teacherCodes};
  List<String> get teacherCodes => {
        if (teacherCode != null && teacherCode!.trim().isNotEmpty)
          teacherCode!.trim(),
        ...coTeacherCodes
            .where((c) => c.trim().isNotEmpty)
            .map((c) => c.trim()),
      }.toList(growable: false);
  bool get requiresSharedTeacherStorage =>
      teacherCodes.any((c) => c != teacherCode);
  bool matchesTeacher(String code) => teacherCodes.contains(code);
  bool matchesStudent(String requestedBatch, String requestedSection) =>
      batch == requestedBatch &&
      (section == requestedSection ||
          section.split('+').map((s) => s.trim()).contains(requestedSection));

  factory RoutineEntry.fromMap(Map<String, dynamic> map) {
    return RoutineEntry(
      schedulingScopeId: map['scheduling_scope_id'] as String?,
      cohortId: map['cohort_id'] as String?,
      studentGroupId: map['student_group_id'] as String?,
      facultyId: map['faculty_id'] as String?,
      roomId: map['room_id'] as String?,
      // Engine rows arrive with a synthetic id ("gen-12"); DB rows with a uuid.
      id: (map['id'] ?? '').toString(),
      day: (map['day'] as String?) ?? '',
      timeStart: (map['time_start'] as String?) ?? '00:00',
      timeEnd: (map['time_end'] as String?) ?? '00:00',
      subject: (map['subject'] as String?) ?? '',
      subjectCode: (map['subject_code'] as String?) ?? '',
      teacherName: map['teacher_name'] as String?,
      teacherCode: map['teacher_code'] as String?,
      coTeacherCodes:
          ((map['teachers'] ?? map['teacher_codes']) as List? ?? const [])
              .map((c) => c.toString())
              .toList(growable: false),
      room: (map['room'] as String?) ?? '',
      batch: (map['batch'] as String?) ?? '',
      section: (map['section'] as String?) ?? '',
      semester: (map['semester'] as int?) ?? 0,
      isActive: (map['is_active'] as bool?) ?? true,
      isService: (map['is_service'] as bool?) ?? false,
    );
  }

  static (int, int) _hm(String t) {
    final parts = t.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    return (h, m);
  }

  DateTime startOn(DateTime date) {
    final (h, m) = _hm(timeStart);
    return DateTime(date.year, date.month, date.day, h, m);
  }

  DateTime endOn(DateTime date) {
    final (h, m) = _hm(timeEnd);
    return DateTime(date.year, date.month, date.day, h, m);
  }

  static String _to12h(String t) {
    final (h, m) = _hm(t);
    final period = h >= 12 ? 'PM' : 'AM';
    var hour = h % 12;
    if (hour == 0) hour = 12;
    final mm = m.toString().padLeft(2, '0');
    return '$hour:$mm $period';
  }

  String get timeLabel => '${_to12h(timeStart)} – ${_to12h(timeEnd)}';

  String get startLabel => _to12h(timeStart);
  String get endLabel => _to12h(timeEnd);

  String get teacherDisplay => teacherCodes.length > 1
      ? teacherCodes.join(' / ')
      : (teacherName != null && teacherName!.isNotEmpty)
          ? teacherName!
          : (teacherCode ?? 'Faculty pending');

  ClassStatus statusOn(DateTime date, {required bool isToday}) {
    if (!isToday) return ClassStatus.upcoming;
    return AppDateUtils.getClassStatus(startOn(date), endOn(date));
  }
}
