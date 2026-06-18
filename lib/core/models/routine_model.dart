// ============================================================
// FILE: lib/core/models/routine_model.dart
// PURPOSE: Typed view of a row in the `routines` table.
// Carries the teacher as text (teacher_name/teacher_code), matching
// generated_timetable, so the same row serves the student view
// (filtered by batch+section) and the teacher view (by teacher_code).
// Pure Dart — no Supabase imports.
// ============================================================

import 'package:universe_v1/core/constants/app_enums.dart';
import 'package:universe_v1/core/utils/date_utils.dart';

class RoutineEntry {
  final String id;
  final String day; // full name, e.g. "Sunday"
  final String timeStart; // "HH:MM" / "HH:MM:SS"
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

  /// Column map for INSERT/UPDATE from the admin Routine Manager.
  /// Excludes `id` (Postgres generates it) and `created_at`.
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

  // ─── Time helpers ─────────────────────────────────────────
  static (int, int) _hm(String t) {
    final parts = t.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    return (h, m);
  }

  /// Builds a DateTime for this slot on a given calendar date.
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

  /// e.g. "9:30 AM – 10:50 AM"
  String get timeLabel => '${_to12h(timeStart)} – ${_to12h(timeEnd)}';

  /// Just the start/end, e.g. "9:30 AM" — for compact dashboard stats.
  String get startLabel => _to12h(timeStart);
  String get endLabel => _to12h(timeEnd);

  String get teacherDisplay =>
      (teacherName != null && teacherName!.isNotEmpty)
          ? teacherName!
          : (teacherCode ?? 'TBA');

  /// Live/next/done only make sense for the current day; otherwise
  /// the class is just an upcoming entry in the weekly grid.
  ClassStatus statusOn(DateTime date, {required bool isToday}) {
    if (!isToday) return ClassStatus.upcoming;
    return AppDateUtils.getClassStatus(startOn(date), endOn(date));
  }
}
