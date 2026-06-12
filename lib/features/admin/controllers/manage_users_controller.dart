// ============================================================
// FILE: lib/features/admin/controllers/manage_users_controller.dart
// PURPOSE: State for the Manage Users screen. Loads all profiles,
// filters by role + search query, and changes a user's role via
// AdminService. (Hard-deleting auth users needs a service-role
// Edge Function and is out of scope.)
// ============================================================

import 'package:universe_v1/core/models/profile_model.dart';
import 'package:universe_v1/core/utils/safe_change_notifier.dart';
import 'package:universe_v1/features/admin/services/admin_service.dart';

// SafeChangeNotifier: async loads may outlive the screen.
class ManageUsersController extends SafeChangeNotifier {
  final AdminService _service = AdminService();

  List<Profile> _all = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _roleFilter; // null = all roles
  String _query = '';

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get roleFilter => _roleFilter;

  List<Profile> get filtered {
    Iterable<Profile> list = _all;
    if (_roleFilter != null) {
      list = list.where((p) => p.role == _roleFilter);
    }
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((p) =>
          p.displayName.toLowerCase().contains(q) ||
          p.email.toLowerCase().contains(q) ||
          (p.identifier?.toLowerCase().contains(q) ?? false));
    }
    return list.toList();
  }

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _all = await _service.fetchAllProfiles();
    } catch (_) {
      _errorMessage = 'Could not load users.';
    }
    _isLoading = false;
    notifyListeners();
  }

  void setRoleFilter(String? role) {
    if (_roleFilter == role) return;
    _roleFilter = role;
    notifyListeners();
  }

  void setQuery(String q) {
    _query = q;
    notifyListeners();
  }

  Future<bool> changeRole(Profile p, String role) async {
    if (p.role == role) return true;
    try {
      await _service.updateUserRole(userId: p.id, role: role);
      await load(); // refresh with the persisted role
      return true;
    } catch (_) {
      _errorMessage = 'Could not change the role.';
      notifyListeners();
      return false;
    }
  }
}
