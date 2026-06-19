// ============================================================
// FILE: lib/features/notifications/services/notification_service.dart
// PURPOSE: The ONLY layer that touches Supabase for notifications.
// Resolves per-user read-state against notification_reads and
// exposes a Realtime subscription for new broadcasts.
// NotificationController calls this; screens never touch it.
// ============================================================

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universe/core/constants/app_constants.dart';
import 'package:universe/core/constants/app_enums.dart';
import 'package:universe/core/models/notification_model.dart';
import 'package:universe/core/models/profile_model.dart';

class NotificationService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ─── Fetch notifications for a given user ──────────────────
  // Pulls all broadcasts + this user's read-marks, merges them,
  // then filters down to the audience this user belongs to.
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

  // ─── Mark a single notification read for this user ─────────
  Future<void> markAsRead({
    required String userId,
    required String notificationId,
  }) async {
    await _supabase.from(AppConstants.tableNotificationReads).upsert(
      {'user_id': userId, 'notification_id': notificationId},
      onConflict: 'user_id,notification_id',
    );
  }

  // ─── Mark many notifications read in one round-trip ────────
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

  // ─── Admin: create a broadcast ─────────────────────────────
  // Inserting a row is what the student devices pick up live via the
  // Realtime subscription below. `sentBy` records the admin (audit;
  // column is nullable). Null target fields = broadcast to everyone.
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
      // RLS requires sent_by = auth.uid(); default to the caller's session
      // so system events (resource upload, routine publish) can omit it.
      'sent_by': sentBy ?? _supabase.auth.currentUser?.id,
      'target_role': targetRole,
      'target_batch': targetBatch,
      'target_section': targetSection,
    });
  }

  // ─── Admin: every broadcast, unfiltered by audience ────────
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

  // ─── Realtime: fire `onInsert` when a new broadcast lands ──
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
