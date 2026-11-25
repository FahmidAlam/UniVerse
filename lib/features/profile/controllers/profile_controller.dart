import 'package:universe/core/models/profile_model.dart';
import 'package:universe/core/utils/safe_change_notifier.dart';
import 'package:universe/features/auth/controllers/auth_controller.dart';
import 'package:universe/features/profile/services/profile_service.dart';

class ProfileController extends SafeChangeNotifier {
  final ProfileService _service;
  final AuthController authController;

  ProfileController({
    required this.authController,
    ProfileService? service,
  }) : _service = service ?? ProfileService();

  Profile? _profile;
  bool _isLoading = false;
  String? _errorMessage;

  Profile? get profile => _profile;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    final map = authController.profile;
    if (map != null) {
      _profile = Profile.fromMap(map);
      notifyListeners();
    }

    final id = _profile?.id ?? map?['id'] as String?;
    if (id == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final fresh = await _service.fetchProfile(id);
      if (fresh != null) _profile = fresh;
    } catch (_) {
      _errorMessage = 'Could not refresh profile.';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> updateDisplayName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      _errorMessage = 'Display name cannot be empty.';
      notifyListeners();
      return false;
    }
    final id = _profile?.id;
    if (id == null) return false;
    if (trimmed == _profile?.displayName.trim()) {
      _errorMessage = null;
      return true;
    }
    _errorMessage = null;
    _isLoading = true;
    notifyListeners();
    try {
      final updated = await _service.updateProfile(
        userId: id,
        changes: {'name': trimmed},
      );
      if (updated != null) {
        _profile = updated;
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (_) {
      _errorMessage = 'Could not update display name.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() => authController.signOut();
}
