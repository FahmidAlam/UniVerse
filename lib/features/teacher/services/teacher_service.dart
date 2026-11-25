import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universe/core/constants/app_constants.dart';
import 'package:universe/core/constants/app_enums.dart';
import 'package:universe/core/models/routine_model.dart';
import 'package:universe/core/utils/date_utils.dart';
import 'package:universe/features/notifications/services/notification_service.dart';

// PHASE 4: Explicit outcome for two-step class cancellation + cohort notification broadcast.
enum CancellationOutcome {
  fullSuccess,
  partialSuccessNotificationFailed,
  failed,
}

class TeacherService {
  SupabaseClient get _supabase => Supabase.instance.client;
  NotificationService? _notificationsInstance;
  NotificationService get _notifications =>
      _notificationsInstance ??= NotificationService();

  static String dateKey(DateTime d) => AppDateUtils.dateKey(d);

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

  // PHASE 4: Separates cancellation persistence from broadcast notification failure ("Service Recovery Paradox").
  Future<CancellationOutcome> cancelClassWithOutcome({
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
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }

    try {
      await _notifications.createBroadcast(
        type: NotifType.classCancel,
        title: 'Class Cancelled: ${entry.subject}',
        body: _cancelBody(entry, trimmed),
        sentBy: userId,
        targetRole: AppConstants.roleStudent,
        targetBatch: entry.batch,
        targetSection: entry.section,
      );
      return CancellationOutcome.fullSuccess;
    } catch (_) {
      return CancellationOutcome.partialSuccessNotificationFailed;
    }
  }

  Future<void> cancelClass({
    required RoutineEntry entry,
    required DateTime date,
    required String reason,
    required String userId,
  }) async {
    await cancelClassWithOutcome(
      entry: entry,
      date: date,
      reason: reason,
      userId: userId,
    );
  }

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
