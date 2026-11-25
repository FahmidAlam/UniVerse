import 'dart:async' show Timer, unawaited;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthException, AuthChangeEvent;
import 'package:universe/core/constants/app_constants.dart';
import 'package:universe/core/services/push_service.dart';
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
  profileError,
  passwordRecovery,
}

class AuthController extends ChangeNotifier {
  AuthController({
    AuthService? authService,
    this.initializationDelay = const Duration(milliseconds: 1800),
    this.recoveryTimeout = const Duration(minutes: 10),
  }) : _authService = authService ?? AuthService();

  final Duration initializationDelay;
  final Duration recoveryTimeout;
  int _stateEpoch = 0;
  bool _disposed = false;
  Timer? _recoveryTimer;
  String? _recoveryUserId;
  bool _recoveryCompleted = false;
  bool _updatingRecovery = false;
  bool _resolvingInvitation = false;

  /// Called only with events emitted by the authenticated Supabase client.
  /// A route or URL flag alone never establishes recovery permission.
  void handleAuthEvent(AuthChangeEvent event, String? sessionUserId) {
    if (event == AuthChangeEvent.passwordRecovery) {
      if (sessionUserId == null ||
          sessionUserId != _authService.currentUser?.id) {
        return;
      }
      _stateEpoch++;
      _resolvingInvitation = false;
      _recoveryTimer?.cancel();
      _recoveryUserId = sessionUserId;
      _recoveryCompleted = false;
      _updatingRecovery = false;
      _errorMessage = null;
      _isLoading = false;
      _status = AuthStatus.passwordRecovery;
      _recoveryTimer = Timer(recoveryTimeout, () {
        unawaited(signOut().catchError((Object _) {}));
      });
      notifyListeners();
    } else if (event == AuthChangeEvent.signedOut ||
        (_resolvingInvitation && event == AuthChangeEvent.signedIn) ||
        (_recoveryUserId != null &&
            sessionUserId != null &&
            sessionUserId != _recoveryUserId)) {
      _stateEpoch++;
      _resolvingInvitation = false;
      _clearRecovery();
      _profile = null;
      _pendingEmail = null;
      clearPendingData();
      _status = AuthStatus.unauthenticated;
      _isLoading = false;
      notifyListeners();
    }
  }

  int beginInvitationCallback() {
    _stateEpoch++;
    _clearRecovery();
    _resolvingInvitation = true;
    _profile = null;
    _errorMessage = null;
    _isLoading = true;
    _status = AuthStatus.loading;
    notifyListeners();
    return _stateEpoch;
  }

  bool completeInvitationCallback(int epoch, String userId) {
    if (epoch != _stateEpoch ||
        !_resolvingInvitation ||
        userId != _authService.currentUser?.id) {
      return false;
    }
    handleAuthEvent(AuthChangeEvent.passwordRecovery, userId);
    return _status == AuthStatus.passwordRecovery;
  }

  void reportCallbackFailure({int? epoch}) {
    if (epoch != null && epoch != _stateEpoch) return;
    _resolvingInvitation = false;
    _stateEpoch++;
    _clearRecovery();
    _profile = null;
    _isLoading = false;
    _errorMessage =
        'The invitation link could not be verified. Request a new invitation or sign out and retry.';
    _status = AuthStatus.profileError;
    notifyListeners();
  }

  void _clearRecovery() {
    _recoveryTimer?.cancel();
    _recoveryTimer = null;
    _recoveryUserId = null;
    _recoveryCompleted = false;
    _updatingRecovery = false;
  }

  Future<AuthResult> updateRecoveryPassword(String password) async {
    final epoch = _stateEpoch;
    if (_status != AuthStatus.passwordRecovery ||
        _recoveryCompleted ||
        _updatingRecovery ||
        _recoveryUserId == null ||
        _recoveryUserId != _authService.currentUser?.id) {
      return AuthResult.failure(
          'Recovery session is missing or expired. Request a new reset email.');
    }
    _updatingRecovery = true;
    final AuthResult result;
    try {
      result = await _authService.updatePassword(password);
    } catch (_) {
      if (epoch != _stateEpoch) {
        return AuthResult.failure(
            'Recovery session expired. Request a new reset email.');
      }
      _updatingRecovery = false;
      _errorMessage = 'Password update failed. Please try again.';
      notifyListeners();
      return AuthResult.failure(_errorMessage!);
    }
    if (epoch != _stateEpoch ||
        _recoveryUserId != _authService.currentUser?.id) {
      return AuthResult.failure(
          'Recovery session expired. Request a new reset email.');
    }
    _updatingRecovery = false;
    _recoveryCompleted = result.success;
    _errorMessage = result.errorMessage;
    notifyListeners();
    return result;
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _stateEpoch++;
    _clearRecovery();
    super.dispose();
  }

  final AuthService _authService;

  AuthStatus _status = AuthStatus.initial;
  Map<String, dynamic>? _profile;
  String? _errorMessage;
  bool _isLoading = false;

  String? _pendingEmail;

  Map<String, dynamic>? _pendingStudentData;
  Map<String, dynamic>? _pendingFacultyData;

  int get operationEpoch => _stateEpoch;
  AuthStatus get status => _status;
  Map<String, dynamic>? get profile => _profile;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  String? get role => _profile?['role'] as String?;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  /// A Supabase session exists, whether or not a profile does yet.
  bool get hasSession => _authService.isLoggedIn;
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
    if (_status == AuthStatus.passwordRecovery || _resolvingInvitation) return;
    final epoch = ++_stateEpoch;
    _setLoading(true);
    _clearError();
    await Future<void>.delayed(initializationDelay);
    if (epoch != _stateEpoch) return;
    final user = _authService.currentUser;
    if (user == null) {
      _status = AuthStatus.unauthenticated;
      _setLoading(false);
      return;
    }
    if (user.emailConfirmedAt == null &&
        user.appMetadata['provider'] == 'email') {
      _pendingEmail = user.email;
      _status = AuthStatus.awaitingVerification;
      _setLoading(false);
      return;
    }
    try {
      final profile = await _authService.fetchProfile(user.id);
      if (epoch != _stateEpoch || user.id != _authService.currentUser?.id) {
        return;
      }
      if (profile != null) {
        _profile = profile;
        _status = AuthStatus.authenticated;
        _registerPushToken(user.id);
      } else {
        final result = await _authService.handlePostLogin();
        if (epoch != _stateEpoch || user.id != _authService.currentUser?.id) {
          return;
        }
        if (result.success) {
          _profile = result.profile;
          _status = result.profile == null
              ? AuthStatus.registering
              : AuthStatus.authenticated;
          if (result.profile != null) _registerPushToken(user.id);
        } else if (result.errorMessage == 'not_whitelisted') {
          _status = AuthStatus.notWhitelisted;
        } else {
          _errorMessage = result.errorMessage ??
              'Could not load your account. Please retry.';
          _status = AuthStatus.profileError;
        }
      }
    } catch (e) {
      if (epoch != _stateEpoch) return;
      _errorMessage = 'Could not load your account: $e';
      _status = AuthStatus.profileError;
    }
    if (epoch == _stateEpoch) _setLoading(false);
  }

  void _registerPushToken(String userId) {
    if (kIsWeb) return;
    try {
      unawaited(
          PushService.instance.registerToken(userId).catchError((Object _) {}));
    } catch (_) {}
  }

  // ===========================================================
  // GOOGLE OAUTH
  // ===========================================================

  Future<void> signInWithGoogle() async {
    final epoch = _stateEpoch;
    _setLoading(true);
    _clearError();
    final bool signedIn;
    try {
      signedIn = await _authService.signInWithGoogle();
    } catch (e) {
      if (epoch != _stateEpoch) return;
      _isLoading = false;
      _setError(
        'Google sign-in failed: ${e is AuthException ? e.message : e}',
      );
      return;
    }
    if (epoch != _stateEpoch) return;
    if (!signedIn) {
      _setLoading(false);
      return;
    }
    // Native sign-in creates the session inside the await above, while
    // isLoading is still true, so the signedIn listener in main.dart skips it.
    // Look the profile up here; handleOAuthCallback de-duplicates if both run.
    await handleOAuthCallback();
  }

  Future<void>? _postLoginInFlight;

  Future<void> handleOAuthCallback() {
    if (_status == AuthStatus.passwordRecovery || _resolvingInvitation) {
      return Future<void>.value();
    }
    return _postLoginInFlight ??= _resolvePostLogin().whenComplete(() {
      _postLoginInFlight = null;
    });
  }

  Future<void> _resolvePostLogin() async {
    final epoch = _stateEpoch;
    final userId = _authService.currentUser?.id;
    _setLoading(true);
    _clearError();

    if (_pendingStudentData != null || _pendingFacultyData != null) {
      final ok = await _completeFromPendingData();
      if (epoch != _stateEpoch || userId != _authService.currentUser?.id) {
        return;
      }
      // A refused teacher registration is final. Looking the profile up
      // afterwards would overwrite notWhitelisted with registering.
      if (ok || _status == AuthStatus.notWhitelisted) {
        _setLoading(false);
        return;
      }
    }

    final result = await _authService.handlePostLogin();
    if (epoch != _stateEpoch || userId != _authService.currentUser?.id) return;

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
      _errorMessage =
          result.errorMessage ?? 'Could not load your account. Please retry.';
      _status = AuthStatus.profileError;
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

    final epoch = _stateEpoch;
    final result = await _authService.signUpWithEmail(
      email: email,
      password: password,
    );

    if (epoch != _stateEpoch) return false;

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

    final epoch = _stateEpoch;
    final result = await _authService.signInWithEmail(
      email: email,
      password: password,
    );

    if (epoch != _stateEpoch) return false;

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
    final epoch = _stateEpoch;
    _setLoading(true);
    _clearError();

    final result = await _authService.sendPasswordResetEmail(email);
    if (epoch != _stateEpoch) return false;

    _setLoading(false);

    if (result.success) return true;
    _setError(result.errorMessage ?? 'Failed to send reset email.');
    return false;
  }

  Future<bool> resendVerificationEmail() async {
    final epoch = _stateEpoch;
    if (_pendingEmail == null) return false;
    _setLoading(true);

    final result = await _authService.resendVerificationEmail(_pendingEmail!);
    if (epoch != _stateEpoch) return false;

    _setLoading(false);

    if (result.success) return true;
    _setError(result.errorMessage ?? 'Failed to resend email.');
    return false;
  }

  Future<bool> verifyEmailCode(String code) async {
    final epoch = _stateEpoch;
    if (_pendingEmail == null) return false;
    _setLoading(true);
    _clearError();

    final result = await _authService.verifyEmailOtp(
      email: _pendingEmail!,
      token: code,
    );

    if (epoch != _stateEpoch) return false;

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
    final epoch = _stateEpoch;
    _setLoading(true);

    try {
      await _authService.authStateChanges.first
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      if (epoch != _stateEpoch) return false;
      _setLoading(false);
      _setError('Verification timed out. Please try again.');
      return false;
    }
    if (epoch != _stateEpoch) return false;
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

    final epoch = _stateEpoch;
    final result = await _authService.completeStudentRegistration(
      name: name,
      studentId: studentId,
      batch: batch,
      section: section,
    );

    if (epoch != _stateEpoch) return false;

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

    final epoch = _stateEpoch;
    final result = await _authService.completeFacultyRegistration(
      name: name,
      teacherCode: teacherCode,
      department: department,
      designation: designation,
    );

    if (epoch != _stateEpoch) return false;

    _setLoading(false);

    if (result.success) {
      _profile = result.profile;
      _status = AuthStatus.authenticated;
      clearPendingData();
      notifyListeners();
      return true;
    }
    if (result.errorMessage == 'not_whitelisted') {
      _status = AuthStatus.notWhitelisted;
      clearPendingData();
      notifyListeners();
      return false;
    }
    _setError(result.errorMessage ?? 'Registration failed.');
    return false;
  }

  bool _isSigningOut = false;

  /// True for the whole sign-out (push-token removal + Supabase call), which
  /// takes a noticeable moment; the app root shows an overlay meanwhile.
  bool get isSigningOut => _isSigningOut;

  Future<void> signOut() async {
    _stateEpoch++;
    _resolvingInvitation = false;
    _clearRecovery();
    _isSigningOut = true;
    _setLoading(true);
    try {
      await _authService.signOut();

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(AppConstants.prefUserRole);
    } finally {
      // Even if a step fails, never leave the overlay covering the app.
      _profile = null;
      _pendingEmail = null;
      clearPendingData();
      _status = AuthStatus.unauthenticated;
      _isSigningOut = false;
      _setLoading(false);
    }
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
