import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universe/core/constants/app_constants.dart';
import 'package:universe/core/constants/app_enums.dart';
import 'package:universe/core/models/notification_model.dart';
import 'package:universe/core/models/profile_model.dart';

class NotificationService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<NotificationItem>> fetchNotifications(Profile me) async {
    final rows = await _supabase
        .from(AppConstants.tableNotifications)
        .select()
        .order('created_at', ascending: false);

    final readRows = await _supabase
        .from(AppConstants.tableNotificationReads)
        .select('notification_id')
        .eq('user_id', me.id);

    final readIds = (readRows as List)
        .map((r) => r['notification_id'] as String)
        .toSet();

    return (rows as List)
        .map((r) {
          final map = r as Map<String, dynamic>;
          return NotificationItem.fromMap(
            map,
            isRead: readIds.contains(map['id']),
          );
        })
        .where((n) => n.matchesAudience(
              role: me.role,
              batch: me.batch,
              section: me.section,
            ))
        .toList();
  }

  Future<void> markAsRead({
    required String userId,
    required String notificationId,
  }) async {
    await _supabase.from(AppConstants.tableNotificationReads).upsert(
      {'user_id': userId, 'notification_id': notificationId},
      onConflict: 'user_id,notification_id',
    );
  }

  Future<void> markAllAsRead({
    required String userId,
    required List<String> notificationIds,
  }) async {
    if (notificationIds.isEmpty) return;
    final rows = notificationIds
        .map((id) => {'user_id': userId, 'notification_id': id})
        .toList();
    await _supabase.from(AppConstants.tableNotificationReads).upsert(
          rows,
          onConflict: 'user_id,notification_id',
        );
  }

  Future<void> createBroadcast({
    required NotifType type,
    required String title,
    required String body,
    String? sentBy,
    String? targetRole,
    String? targetBatch,
    String? targetSection,
  }) async {
    await _supabase.from(AppConstants.tableNotifications).insert({
      'type': type.dbValue,
      'title': title,
      'body': body,
      'sent_by': sentBy ?? _supabase.auth.currentUser?.id,
      'target_role': targetRole,
      'target_batch': targetBatch,
      'target_section': targetSection,
    });
  }

  Future<List<NotificationItem>> fetchAllForAdmin() async {
    final rows = await _supabase
        .from(AppConstants.tableNotifications)
        .select()
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => NotificationItem.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> deleteBroadcast(String id) async {
    await _supabase
        .from(AppConstants.tableNotifications)
        .delete()
        .eq('id', id);
  }

  RealtimeChannel subscribeToInserts(void Function() onInsert) {
    return _supabase
        .channel('public:notifications')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: AppConstants.tableNotifications,
          callback: (_) => onInsert(),
        )
        .subscribe();
  }

  Future<void> unsubscribe(RealtimeChannel channel) async {
    await _supabase.removeChannel(channel);
  }
}
