// ============================================================
// FILE: lib/features/admin/controllers/broadcast_controller.dart
// PURPOSE: State for the admin Campus Broadcast composer. Holds the
// chosen type + audience, sends via NotificationService (which the
// student Alerts feed picks up live over Realtime), and keeps a
// recent-broadcasts list for review/delete.
// ============================================================

import 'package:universe/core/constants/app_enums.dart';
import 'package:universe/core/models/notification_model.dart';
import 'package:universe/core/utils/safe_change_notifier.dart';
import 'package:universe/features/auth/controllers/auth_controller.dart';
import 'package:universe/features/notifications/services/notification_service.dart';

// SafeChangeNotifier: async sends/loads may outlive the screen.
class BroadcastController extends SafeChangeNotifier {
  final NotificationService _service = NotificationService();
  final AuthController authController;

  BroadcastController({required this.authController});

  NotifType _type = NotifType.university;
  String? _targetRole; // null = everyone
  bool _isSending = false;
  bool _isLoadingRecent = false;
  String? _errorMessage;
  List<NotificationItem> _recent = [];

  NotifType get type => _type;
  String? get targetRole => _targetRole;
  bool get isSending => _isSending;
  bool get isLoadingRecent => _isLoadingRecent;
  String? get errorMessage => _errorMessage;
  List<NotificationItem> get recent => _recent;

  void setType(NotifType t) {
    if (_type == t) return;
    _type = t;
    notifyListeners();
  }

  void setTargetRole(String? role) {
    if (_targetRole == role) return;
    _targetRole = role;
    notifyListeners();
  }

  Future<void> loadRecent() async {
    _isLoadingRecent = true;
    notifyListeners();
    try {
      _recent = await _service.fetchAllForAdmin();
    } catch (_) {
      _errorMessage = 'Could not load recent broadcasts.';
    }
    _isLoadingRecent = false;
    notifyListeners();
  }

  Future<bool> submit({
    required String title,
    required String body,
    String? targetBatch,
    String? targetSection,
  }) async {
    _isSending = true;
    _errorMessage = null;
    notifyListeners();

    var ok = false;
    try {
      String? clean(String? v) =>
          (v != null && v.trim().isNotEmpty) ? v.trim() : null;

      await _service.createBroadcast(
        type: _type,
        title: title.trim(),
        body: body.trim(),
        sentBy: authController.profile?['id'] as String?,
        targetRole: _targetRole,
        targetBatch: clean(targetBatch),
        targetSection: clean(targetSection),
      );
      await loadRecent(); // pull the new row into the list
      ok = true;
    } catch (_) {
      _errorMessage = 'Failed to send broadcast. Please try again.';
    }

    _isSending = false;
    notifyListeners();
    return ok;
  }

  Future<void> deleteBroadcast(String id) async {
    try {
      await _service.deleteBroadcast(id);
      _recent.removeWhere((n) => n.id == id);
      notifyListeners();
    } catch (_) {
      _errorMessage = 'Could not delete broadcast.';
      notifyListeners();
    }
  }
}
