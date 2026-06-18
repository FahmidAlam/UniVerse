// ============================================================
// FILE: lib/features/teacher/services/teacher_service.dart
// PURPOSE: The ONLY Supabase layer for teacher class actions.
// Cancels a specific class occurrence (writes a `cancellations`
// row — see migration 007) AND fans the alert out to the cohort
// via NotificationService. Also posts room-change / notice /
// test-reminder broadcasts. Controllers call this; screens never
// touch Supabase.
// ============================================================

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universe_v1/core/constants/app_constants.dart';
import 'package:universe_v1/core/constants/app_enums.dart';
import 'package:universe_v1/core/models/routine_model.dart';
import 'package:universe_v1/features/notifications/services/notification_service.dart';

class TeacherService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final NotificationService _notifications = NotificationService();

  /// ISO date (yyyy-mm-dd) — the `class_date` column's format.
  static String dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Keys ("routineId|yyyy-mm-dd") for upcoming cancellations among the
  /// given routine rows, so the screen can badge cancelled occurrences.
  Future<Set<String>> fetchUpcomingCancellationKeys(
    List<String> routineIds,
  ) async {
    if (routineIds.isEmpty) return <String>{};
    final rows = await _supabase
        .from(AppConstants.tableCancellations)
        .select('routine_id, class_date')
        .inFilter('routine_id', routineIds)
        .gte('class_date', dateKey(DateTime.now()));
    return (rows as List)
        .map((r) => '${r['routine_id']}|${r['class_date']}')
        .toSet();
  }

  /// Cancel one occurrence: persist the cancellation row AND broadcast a
  /// class_cancel alert to the cohort (students get it live via Realtime).
  Future<void> cancelClass({
    required RoutineEntry entry,
    required DateTime date,
    required String reason,
    required String userId,
  }) async {
    final trimmed = reason.trim();

    try {
      await _supabase.from(AppConstants.tableCancellations).insert({
        'routine_id': entry.id,
        'class_date': dateKey(date),
        'reason': trimmed.isEmpty ? null : trimmed,
        'batch': entry.batch,
        'section': entry.section,
        'subject': entry.subject,
        'day': entry.day,
        'time_start': entry.timeStart,
        'cancelled_by': userId,
      });

      await _notifications.createBroadcast(
        type: NotifType.classCancel,
        title: 'Class Cancelled: ${entry.subject}',
        body: _cancelBody(entry, trimmed),
        sentBy: userId,
        targetRole: AppConstants.roleStudent,
        targetBatch: entry.batch,
        targetSection: entry.section,
      );
    } on PostgrestException catch (e) {
      // Surface the real DB / RLS reason instead of a generic failure.
      throw Exception(e.message);
    }
  }

  /// Remove a cancellation (teacher's own occurrence). The broadcast
  /// already sent cannot be recalled — the student feed keeps history.
  Future<void> undoCancel({
    required String routineId,
    required DateTime date,
    required String userId,
  }) async {
    await _supabase
        .from(AppConstants.tableCancellations)
        .delete()
        .eq('routine_id', routineId)
        .eq('class_date', dateKey(date))
        .eq('cancelled_by', userId);
  }

  /// Post a room-change / notice / test-reminder to the class's cohort.
  Future<void> postNotice({
    required NotifType type,
    required String title,
    required String body,
    required RoutineEntry entry,
    required String userId,
  }) async {
    await _notifications.createBroadcast(
      type: type,
      title: title.trim(),
      body: body.trim(),
      sentBy: userId,
      targetRole: AppConstants.roleStudent,
      targetBatch: entry.batch,
      targetSection: entry.section,
    );
  }

  String _cancelBody(RoutineEntry entry, String reason) {
    final base =
        '${entry.subject} (${entry.timeLabel}) on ${entry.day} is cancelled.';
    return reason.isEmpty ? base : '$base Reason: $reason';
  }
}
