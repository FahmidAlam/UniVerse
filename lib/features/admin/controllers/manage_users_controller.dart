import 'package:universe/core/models/profile_model.dart';
import 'package:universe/core/utils/safe_change_notifier.dart';
import 'package:universe/features/admin/services/admin_service.dart';

class ManageUsersController extends SafeChangeNotifier {
  final AdminService _service = AdminService();

  List<Profile> _all = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _roleFilter;
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
      await load();
      return true;
    } catch (_) {
      _errorMessage = 'Could not change the role.';
      notifyListeners();
      return false;
    }
  }
}
