// ============================================================
// FILE: lib/features/notifications/controllers/notification_controller.dart
// PURPOSE: State between NotificationService and the screen.
// Holds the audience-filtered list, the active type filter,
// loading/error state, and the unread count for the nav badge.
// Plain ChangeNotifier — no Riverpod/Bloc/Provider.
// ============================================================

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universe_v1/core/constants/app_enums.dart';
import 'package:universe_v1/core/models/notification_model.dart';
import 'package:universe_v1/core/models/profile_model.dart';
import 'package:universe_v1/core/utils/safe_change_notifier.dart';
import 'package:universe_v1/features/auth/controllers/auth_controller.dart';
import 'package:universe_v1/features/notifications/services/notification_service.dart';

class NotificationController extends SafeChangeNotifier {
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

  // Per-user, locally-dismissed notification ids. These hide items from
  // THIS user's feed only — the broadcast rows in the DB are never touched
  // (they're shared across everyone). Persisted via SharedPreferences.
  Set<String> _dismissedIds = <String>{};
  String? _dismissedUserId;

  // Multi-select state for the dismiss UI.
  bool _selectionMode = false;
  final Set<String> _selectedIds = <String>{};

  // ─── Getters ──────────────────────────────────────────────
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  NotifType? get activeFilter => _activeFilter;

  /// Items the user hasn't locally dismissed.
  List<NotificationItem> get _visible =>
      _items.where((n) => !_dismissedIds.contains(n.id)).toList();

  List<NotificationItem> get filtered {
    final base = _visible;
    if (_activeFilter == null) return base;
    return base.where((n) => n.type == _activeFilter).toList();
  }

  int get unreadCount => _visible.where((n) => !n.isRead).length;

  /// Latest items regardless of the active filter — for dashboard previews.
  List<NotificationItem> get items => List.unmodifiable(_visible);

  // ─── Selection (multi-select dismiss) ─────────────────────
  bool get selectionMode => _selectionMode;
  int get selectedCount => _selectedIds.length;
  bool isSelected(String id) => _selectedIds.contains(id);

  /// Enter selection mode with nothing selected (app-bar entry point).
  void enterSelection() {
    _selectionMode = true;
    _selectedIds.clear();
    notifyListeners();
  }

  /// Enter selection mode and select [id] (long-press entry point).
  void selectFromLongPress(String id) {
    _selectionMode = true;
    _selectedIds.add(id);
    notifyListeners();
  }

  void toggleSelected(String id) {
    if (_selectedIds.contains(id)) {
      _selectedIds.remove(id);
    } else {
      _selectedIds.add(id);
    }
    if (_selectedIds.isEmpty) _selectionMode = false;
    notifyListeners();
  }

  void exitSelection() {
    _selectionMode = false;
    _selectedIds.clear();
    notifyListeners();
  }

  /// Hide the selected notifications for THIS user only — the DB rows are
  /// kept (they're shared broadcasts). Persisted so they stay hidden.
  Future<void> dismissSelected() async {
    if (_selectedIds.isEmpty) return;
    _dismissedIds.addAll(_selectedIds);
    _selectedIds.clear();
    _selectionMode = false;
    notifyListeners();
    await _saveDismissed();
  }

  Profile? get _me {
    final map = authController.profile;
    return map == null ? null : Profile.fromMap(map);
  }

  // ─── Load ─────────────────────────────────────────────────
  Future<void> load() async {
    final me = _me;
    if (me == null) return;

    // Load this user's locally-dismissed ids once (or when the user swaps).
    if (_dismissedUserId != me.id) {
      _dismissedUserId = me.id;
      await _loadDismissed(me.id);
    }

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

  Future<void> _loadDismissed(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    _dismissedIds =
        (prefs.getStringList('dismissed_notifs_$userId') ?? <String>[]).toSet();
  }

  Future<void> _saveDismissed() async {
    final uid = _dismissedUserId;
    if (uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('dismissed_notifs_$uid', _dismissedIds.toList());
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
        _visible.where((n) => !n.isRead).map((n) => n.id).toList();
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
