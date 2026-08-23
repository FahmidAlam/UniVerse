import 'package:universe/core/constants/app_enums.dart';

class NotificationItem {
  final String id;
  final String title;
  final String body;
  final NotifType type;
  final DateTime time;

  final String? targetRole;
  final String? targetBatch;
  final String? targetSection;

  final bool isRead;

  const NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.time,
    this.targetRole,
    this.targetBatch,
    this.targetSection,
    this.isRead = false,
  });

  factory NotificationItem.fromMap(
    Map<String, dynamic> map, {
    bool isRead = false,
  }) {
    return NotificationItem(
      id: map['id'] as String,
      title: (map['title'] as String?) ?? '',
      body: (map['body'] as String?) ?? '',
      type: NotifType.fromString((map['type'] as String?) ?? ''),
      time: map['created_at'] != null
          ? (DateTime.tryParse(map['created_at'].toString())?.toLocal() ??
              DateTime.now())
          : DateTime.now(),
      targetRole: map['target_role'] as String?,
      targetBatch: map['target_batch'] as String?,
      targetSection: map['target_section'] as String?,
      isRead: isRead,
    );
  }

  NotificationItem copyWith({bool? isRead}) {
    return NotificationItem(
      id: id,
      title: title,
      body: body,
      type: type,
      time: time,
      targetRole: targetRole,
      targetBatch: targetBatch,
      targetSection: targetSection,
      isRead: isRead ?? this.isRead,
    );
  }

  bool matchesAudience({
    required String role,
    String? batch,
    String? section,
  }) {
    if (targetRole != null && targetRole != role) return false;
    if (targetBatch != null && targetBatch != batch) return false;
    if (targetSection != null && targetSection != section) return false;
    return true;
  }
}
