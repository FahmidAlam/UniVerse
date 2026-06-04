// ============================================================
// FILE: lib/features/notifications/controllers/notification_controller.dart
// PURPOSE: State between NotificationService and the screen.
// Holds the audience-filtered list, the active type filter,
// loading/error state, and the unread count for the nav badge.
// Plain ChangeNotifier — no Riverpod/Bloc/Provider.
// ============================================================

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universe_v1/core/constants/app_enums.dart';
import 'package:universe_v1/core/models/notification_model.dart';
import 'package:universe_v1/core/models/profile_model.dart';
import 'package:universe_v1/features/auth/controllers/auth_controller.dart';
import 'package:universe_v1/features/notifications/services/notification_service.dart';

class NotificationController extends ChangeNotifier {
  final NotificationService _service = NotificationService();
  final AuthController authController;

  NotificationController({required this.authController});

  // ─── State ────────────────────────────────────────────────
  List<NotificationItem> _items = [];
  bool _isLoading = false;
  String? _errorMessage;

  /// null == "All"
  NotifType? _activeFilter;

  RealtimeChannel? _channel;

  // ─── Getters ──────────────────────────────────────────────
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  NotifType? get activeFilter => _activeFilter;

  List<NotificationItem> get filtered {
    if (_activeFilter == null) return _items;
    return _items.where((n) => n.type == _activeFilter).toList();
  }

  int get unreadCount => _items.where((n) => !n.isRead).length;

  Profile? get _me {
    final map = authController.profile;
    return map == null ? null : Profile.fromMap(map);
  }

  // ─── Load ─────────────────────────────────────────────────
  Future<void> load() async {
    final me = _me;
    if (me == null) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _items = await _service.fetchNotifications(me);
    } catch (e) {
      _errorMessage = 'Could not load notifications.';
    }

    _isLoading = false;
    notifyListeners();
  }

  // ─── Realtime ─────────────────────────────────────────────
  void startRealtime() {
    _channel ??= _service.subscribeToInserts(load);
  }

  // ─── Filter ───────────────────────────────────────────────
  void setFilter(NotifType? type) {
    _activeFilter = type;
    notifyListeners();
  }

  // ─── Mark read (optimistic) ───────────────────────────────
  Future<void> markRead(String id) async {
    final me = _me;
    if (me == null) return;

    final i = _items.indexWhere((n) => n.id == id);
    if (i == -1 || _items[i].isRead) return;

    _items[i] = _items[i].copyWith(isRead: true);
    notifyListeners();

    try {
      await _service.markAsRead(userId: me.id, notificationId: id);
    } catch (_) {
      _items[i] = _items[i].copyWith(isRead: false); // rollback
      notifyListeners();
    }
  }

  Future<void> markAllRead() async {
    final me = _me;
    if (me == null) return;

    final unreadIds =
        _items.where((n) => !n.isRead).map((n) => n.id).toList();
    if (unreadIds.isEmpty) return;

    final previous = _items;
    _items = _items.map((n) => n.copyWith(isRead: true)).toList();
    notifyListeners();

    try {
      await _service.markAllAsRead(userId: me.id, notificationIds: unreadIds);
    } catch (_) {
      _items = previous; // rollback
      notifyListeners();
    }
  }

  @override
  void dispose() {
    final channel = _channel;
    if (channel != null) {
      _service.unsubscribe(channel);
      _channel = null;
    }
    super.dispose();
  }
}
