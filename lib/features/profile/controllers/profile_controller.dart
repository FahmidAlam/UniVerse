// ============================================================
// FILE: lib/features/profile/controllers/profile_controller.dart
// PURPOSE: State between ProfileService and the profile screen.
// Reads the in-memory profile from AuthController for an instant
// first paint, then refreshes from the DB. Sign-out delegates to
// AuthController so the GoRouter redirect fires correctly.
// ============================================================

import 'package:universe/core/models/profile_model.dart';
import 'package:universe/core/utils/safe_change_notifier.dart';
import 'package:universe/features/auth/controllers/auth_controller.dart';
import 'package:universe/features/profile/services/profile_service.dart';

class ProfileController extends SafeChangeNotifier {
  final ProfileService _service = ProfileService();
  final AuthController authController;

  ProfileController({required this.authController});

  Profile? _profile;
  bool _isLoading = false;
  String? _errorMessage;

  Profile? get profile => _profile;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    // Instant first paint from the profile auth already holds.
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

  Future<void> signOut() => authController.signOut();
}
