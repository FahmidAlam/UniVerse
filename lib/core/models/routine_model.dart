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
  final String room;
  final String batch;
  final String section;
  final int semester;
  final bool isActive;

  const RoutineEntry({
    required this.id,
    required this.day,
    required this.timeStart,
    required this.timeEnd,
    required this.subject,
    required this.subjectCode,
    this.teacherName,
    this.teacherCode,
    required this.room,
    required this.batch,
    required this.section,
    required this.semester,
    this.isActive = true,
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
    };
  }

  factory RoutineEntry.fromMap(Map<String, dynamic> map) {
    return RoutineEntry(
      id: map['id'] as String,
      day: (map['day'] as String?) ?? '',
      timeStart: (map['time_start'] as String?) ?? '00:00',
      timeEnd: (map['time_end'] as String?) ?? '00:00',
      subject: (map['subject'] as String?) ?? '',
      subjectCode: (map['subject_code'] as String?) ?? '',
      teacherName: map['teacher_name'] as String?,
      teacherCode: map['teacher_code'] as String?,
      room: (map['room'] as String?) ?? '',
      batch: (map['batch'] as String?) ?? '',
      section: (map['section'] as String?) ?? '',
      semester: (map['semester'] as int?) ?? 0,
      isActive: (map['is_active'] as bool?) ?? true,
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

  String get teacherDisplay =>
      (teacherName != null && teacherName!.isNotEmpty)
          ? teacherName!
          : (teacherCode ?? 'TBA');

  ClassStatus statusOn(DateTime date, {required bool isToday}) {
    if (!isToday) return ClassStatus.upcoming;
    return AppDateUtils.getClassStatus(startOn(date), endOn(date));
  }
}
