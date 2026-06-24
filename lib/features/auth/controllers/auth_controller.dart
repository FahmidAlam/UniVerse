import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universe/core/constants/app_constants.dart';
import 'package:universe/features/auth/services/auth_service.dart';

enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  registering,
  notWhitelisted,
  awaitingVerification,
  error,
}

class AuthController extends ChangeNotifier {
  final AuthService _authService = AuthService();

  AuthStatus _status = AuthStatus.initial;
  Map<String, dynamic>? _profile;
  String? _errorMessage;
  bool _isLoading = false;

  String? _pendingEmail;

  Map<String, dynamic>? _pendingStudentData;
  Map<String, dynamic>? _pendingFacultyData;

  AuthStatus get status => _status;
  Map<String, dynamic>? get profile => _profile;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  String? get role => _profile?['role'] as String?;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  String? get pendingEmail => _pendingEmail;
  Map<String, dynamic>? get pendingStudentData => _pendingStudentData;
  Map<String, dynamic>? get pendingFacultyData => _pendingFacultyData;

  void storePendingStudentData({
    required String name,
    required String studentId,
    required String batch,
    required String section,
  }) {
    _pendingStudentData = {
      'name': name,
      'studentId': studentId,
      'batch': batch,
      'section': section,
    };
    _pendingFacultyData = null;
  }

  void storePendingFacultyData({
    required String name,
    required String teacherCode,
    required String department,
    required String designation,
  }) {
    _pendingFacultyData = {
      'name': name,
      'teacherCode': teacherCode,
      'department': department,
      'designation': designation,
    };
    _pendingStudentData = null;
  }

  void clearPendingData() {
    _pendingStudentData = null;
    _pendingFacultyData = null;
  }

  Future<void> initialize() async {
    _setLoading(true);
    await Future.delayed(const Duration(milliseconds: 1800));

    if (_authService.isLoggedIn) {
      final user = _authService.currentUser!;

      if (user.emailConfirmedAt == null &&
          user.appMetadata['provider'] == 'email') {
        _pendingEmail = user.email;
        _status = AuthStatus.awaitingVerification;
        _setLoading(false);
        return;
      }

      final profile = await _authService.fetchProfile(user.id);
      if (profile != null) {
        _profile = profile;
        _status = AuthStatus.authenticated;
      } else {
        _status = AuthStatus.registering;
      }
    } else {
      _status = AuthStatus.unauthenticated;
    }

    _setLoading(false);
  }


  Future<void> signInWithGoogle() async {
    _setLoading(true);
    _clearError();
    try {
      await _authService.signInWithGoogle();
    } catch (e) {
      _setError('Failed to open Google sign-in: $e');
    }
    _setLoading(false);
  }

  Future<void>? _postLoginInFlight;

  Future<void> handleOAuthCallback() {
    return _postLoginInFlight ??= _resolvePostLogin().whenComplete(() {
      _postLoginInFlight = null;
    });
  }

  Future<void> _resolvePostLogin() async {
    _setLoading(true);
    _clearError();

    if (_pendingStudentData != null || _pendingFacultyData != null) {
      final ok = await _completeFromPendingData();
      if (ok) {
        _setLoading(false);
        return;
      }
    }

    final result = await _authService.handlePostLogin();

    if (result.success) {
      if (result.profile != null) {
        _profile = result.profile;
        _status = AuthStatus.authenticated;
      } else {
        _status = AuthStatus.registering;
      }
    } else if (result.errorMessage == 'not_whitelisted') {
      _status = AuthStatus.notWhitelisted;
    } else {
      _setError(result.errorMessage ?? 'Sign-in failed.');
      _status = AuthStatus.unauthenticated;
    }

    _setLoading(false);
  }

  Future<bool> _completeFromPendingData() async {
    if (_pendingStudentData != null) {
      final d = _pendingStudentData!;
      return completeStudentRegistration(
        name: d['name'] as String,
        studentId: d['studentId'] as String,
        batch: d['batch'] as String,
        section: d['section'] as String,
      );
    }
    if (_pendingFacultyData != null) {
      final d = _pendingFacultyData!;
      return completeFacultyRegistration(
        name: d['name'] as String,
        teacherCode: d['teacherCode'] as String,
        department: d['department'] as String,
        designation: d['designation'] as String,
      );
    }
    return false;
  }


  Future<bool> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _clearError();

    final result = await _authService.signUpWithEmail(
      email: email,
      password: password,
    );

    _setLoading(false);

    if (result.emailNeedsVerification) {
      _pendingEmail = email;
      _status = AuthStatus.awaitingVerification;
      notifyListeners();
      return true;
    }

    if (result.success) {
      if (result.profile == null) {
        await handleOAuthCallback();
        return _status == AuthStatus.authenticated ||
            _status == AuthStatus.registering;
      }
      _profile = result.profile;
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    }

    if (result.errorMessage == 'not_whitelisted') {
      _status = AuthStatus.notWhitelisted;
      notifyListeners();
      return false;
    }

    _setError(result.errorMessage ?? 'Sign-up failed.');
    return false;
  }

  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _clearError();

    final result = await _authService.signInWithEmail(
      email: email,
      password: password,
    );

    _setLoading(false);

    if (result.emailNeedsVerification) {
      _pendingEmail = email;
      _status = AuthStatus.awaitingVerification;
      notifyListeners();
      return false;
    }

    if (result.success) {
      if (result.profile == null) {
        _status = AuthStatus.registering;
        notifyListeners();
        return true;
      }
      _profile = result.profile;
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    }

    if (result.errorMessage == 'not_whitelisted') {
      _status = AuthStatus.notWhitelisted;
      notifyListeners();
      return false;
    }

    _setError(result.errorMessage ?? 'Sign-in failed.');
    return false;
  }

  Future<bool> sendPasswordReset(String email) async {
    _setLoading(true);
    _clearError();

    final result = await _authService.sendPasswordResetEmail(email);

    _setLoading(false);

    if (result.success) return true;
    _setError(result.errorMessage ?? 'Failed to send reset email.');
    return false;
  }

  Future<bool> resendVerificationEmail() async {
    if (_pendingEmail == null) return false;
    _setLoading(true);

    final result = await _authService.resendVerificationEmail(_pendingEmail!);

    _setLoading(false);

    if (result.success) return true;
    _setError(result.errorMessage ?? 'Failed to resend email.');
    return false;
  }

  Future<bool> verifyEmailCode(String code) async {
    if (_pendingEmail == null) return false;
    _setLoading(true);
    _clearError();

    final result = await _authService.verifyEmailOtp(
      email: _pendingEmail!,
      token: code,
    );

    if (!result.success) {
      _setLoading(false);
      _setError(result.errorMessage ?? 'Invalid or expired code.');
      return false;
    }

    await handleOAuthCallback();

    return _status == AuthStatus.authenticated ||
        _status == AuthStatus.registering;
  }

  Future<bool> checkEmailVerified() async {
    _setLoading(true);

    await _authService.authStateChanges.first;
    final user = _authService.currentUser;

    if (user?.emailConfirmedAt != null) {
      await handleOAuthCallback();
      return _status == AuthStatus.authenticated ||
          _status == AuthStatus.registering;
    }

    _setLoading(false);
    return false;
  }


  Future<bool> completeStudentRegistration({
    required String name,
    required String studentId,
    required String batch,
    required String section,
  }) async {
    _setLoading(true);
    _clearError();

    final result = await _authService.completeStudentRegistration(
      name: name,
      studentId: studentId,
      batch: batch,
      section: section,
    );

    _setLoading(false);

    if (result.success) {
      _profile = result.profile;
      _status = AuthStatus.authenticated;
      clearPendingData();
      notifyListeners();
      return true;
    }
    _setError(result.errorMessage ?? 'Registration failed.');
    return false;
  }

  Future<bool> completeFacultyRegistration({
    required String name,
    required String teacherCode,
    required String department,
    required String designation,
  }) async {
    _setLoading(true);
    _clearError();

    final result = await _authService.completeFacultyRegistration(
      name: name,
      teacherCode: teacherCode,
      department: department,
      designation: designation,
    );

    _setLoading(false);

    if (result.success) {
      _profile = result.profile;
      _status = AuthStatus.authenticated;
      clearPendingData();
      notifyListeners();
      return true;
    }
    _setError(result.errorMessage ?? 'Registration failed.');
    return false;
  }


  Future<void> signOut() async {
    _setLoading(true);
    await _authService.signOut();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.prefUserRole);

    _profile = null;
    _pendingEmail = null;
    clearPendingData();
    _status = AuthStatus.unauthenticated;
    _setLoading(false);
  }

  Future<bool> hasSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConstants.prefOnboardingDone) ?? false;
  }

  Future<void> markOnboardingSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefOnboardingDone, true);
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    _status = AuthStatus.error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }
}
