// // ============================================================
// // FILE: lib/features/auth/controllers/auth_controller.dart
// // PURPOSE: Sits between AuthService and the UI screens.
// // Holds loading state, error state, and the current
// // user profile. Screens call controller methods and
// // react to state changes via setState or ValueNotifier.
// //
// // PATTERN: Simple ChangeNotifier — no Riverpod, no Bloc.
// // Screens call controller.signInWithGoogle() and rebuild
// // when notifyListeners() fires.
// // ============================================================

// import 'package:flutter/material.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:universe_v1/core/constants/app_constants.dart';
// import 'package:universe_v1/features/auth/services/auth_service.dart';

// enum AuthStatus {
//   initial,       // App just launched
//   loading,       // Async operation in progress
//   authenticated, // Logged in, profile loaded
//   unauthenticated, // Not logged in
//   notWhitelisted,  // Logged in with Google but not pre-registered
//   error,           // Something went wrong
// }

// class AuthController extends ChangeNotifier {
//   final AuthService _authService = AuthService();

//   AuthStatus _status = AuthStatus.initial;
//   Map<String, dynamic>? _profile;
//   String? _errorMessage;
//   bool _isLoading = false;

//   // ─── Getters ──────────────────────────────────────────────
//   AuthStatus get status        => _status;
//   Map<String, dynamic>? get profile => _profile;
//   String? get errorMessage     => _errorMessage;
//   bool get isLoading           => _isLoading;
//   String? get role             => _profile?['role'] as String?;
//   bool get isAuthenticated     => _status == AuthStatus.authenticated;

//   // ─── Initialize (called from main / splash) ───────────────
//   // Checks if there's already a valid Supabase session.
//   Future<void> initialize() async {
//     _setLoading(true);

//     // Small delay to let splash logo animate
//     await Future.delayed(const Duration(milliseconds: 1800));

//     if (_authService.isLoggedIn) {
//       final profile = await _authService.fetchProfile(
//         _authService.currentUser!.id,
//       );

//       if (profile != null) {
//         _profile = profile;
//         _status = AuthStatus.authenticated;
//       } else {
//         // Session exists but no profile — send to login
//         _status = AuthStatus.unauthenticated;
//       }
//     } else {
//       _status = AuthStatus.unauthenticated;
//     }

//     _setLoading(false);
//   }

//   // ─── Sign in with Google ──────────────────────────────────
//   // Step 1 of 2: opens Google OAuth. The actual result comes
//   // via handleOAuthCallback() after the deep link fires.
//   Future<void> signInWithGoogle() async {
//     _setLoading(true);
//     _clearError();

//     try {
//       await _authService.signInWithGoogle();
//       // GoRouter listens to auth state changes and will call
//       // handleOAuthCallback once the session is established.
//     } catch (e) {
//       _setError('Failed to open Google sign-in: $e');
//     }

//     _setLoading(false);
//   }

//   // ─── Handle OAuth callback ────────────────────────────────
//   // Step 2 of 2: called by GoRouter redirect when auth state
//   // changes to "signed in". Checks whitelist and loads profile.
//   Future<void> handleOAuthCallback() async {
//     _setLoading(true);
//     _clearError();

//     final result = await _authService.handlePostLogin();

//     if (result.success) {
//       _profile = result.profile;
//       _status = AuthStatus.authenticated;
//     } else if (result.errorMessage == 'not_whitelisted') {
//       _status = AuthStatus.notWhitelisted;
//     } else {
//       _setError(result.errorMessage ?? 'Sign-in failed.');
//       _status = AuthStatus.unauthenticated;
//     }

//     _setLoading(false);
//   }

//   // ─── Complete student registration ────────────────────────
//   Future<bool> completeStudentRegistration({
//     required String name,
//     required String studentId,
//     required String batch,
//     required String section,
//     required int semester,
//   }) async {
//     _setLoading(true);
//     _clearError();

//     final result = await _authService.completeStudentRegistration(
//       name: name,
//       studentId: studentId,
//       batch: batch,
//       section: section,
//       semester: semester,
//     );

//     _setLoading(false);

//     if (result.success) {
//       _profile = result.profile;
//       _status = AuthStatus.authenticated;
//       notifyListeners();
//       return true;
//     } else {
//       _setError(result.errorMessage ?? 'Registration failed.');
//       return false;
//     }
//   }

//   // ─── Complete faculty registration ────────────────────────
//   Future<bool> completeFacultyRegistration({
//     required String name,
//     required String employeeId,
//     required String department,
//     required String designation,
//   }) async {
//     _setLoading(true);
//     _clearError();

//     final result = await _authService.completeFacultyRegistration(
//       name: name,
//       employeeId: employeeId,
//       department: department,
//       designation: designation,
//     );

//     _setLoading(false);

//     if (result.success) {
//       _profile = result.profile;
//       _status = AuthStatus.authenticated;
//       notifyListeners();
//       return true;
//     } else {
//       _setError(result.errorMessage ?? 'Registration failed.');
//       return false;
//     }
//   }

//   // ─── Sign out ─────────────────────────────────────────────
//   Future<void> signOut() async {
//     _setLoading(true);
//     await _authService.signOut();

//     // Clear onboarding flag so it shows again on next login
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.remove(AppConstants.prefUserRole);

//     _profile = null;
//     _status = AuthStatus.unauthenticated;
//     _setLoading(false);
//   }

//   // ─── Onboarding helpers ───────────────────────────────────
//   Future<bool> hasSeenOnboarding() async {
//     final prefs = await SharedPreferences.getInstance();
//     return prefs.getBool(AppConstants.prefOnboardingDone) ?? false;
//   }

//   Future<void> markOnboardingSeen() async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setBool(AppConstants.prefOnboardingDone, true);
//   }

//   // ─── Private helpers ──────────────────────────────────────
//   void _setLoading(bool value) {
//     _isLoading = value;
//     notifyListeners();
//   }

//   void _setError(String message) {
//     _errorMessage = message;
//     _status = AuthStatus.error;
//     notifyListeners();
//   }

//   void _clearError() {
//     _errorMessage = null;
//   }
// }
// // ============================================================
// // FILE: lib/features/auth/controllers/auth_controller.dart
// // PURPOSE: State manager for all auth flows.
// // Handles both Google OAuth and email/password.
// // Screens listen via ListenableBuilder / addListener.
// // ============================================================

// import 'package:flutter/material.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:universe_v1/core/constants/app_constants.dart';
// import 'package:universe_v1/features/auth/services/auth_service.dart';

// enum AuthStatus {
//   initial,           // App just launched, checking session
//   loading,           // Async operation in progress
//   authenticated,     // Logged in with a loaded profile
//   unauthenticated,   // Not logged in
//   registering,      // Signed in via registration flow, awaiting profile completion
//   notWhitelisted,    // Signed in but email not in whitelist
//   awaitingVerification, // Signed up, email not yet confirmed
//   error,             // Something went wrong
// }

// class AuthController extends ChangeNotifier {
//   final AuthService _authService = AuthService();

//   AuthStatus _status = AuthStatus.initial;
//   Map<String, dynamic>? _profile;
//   String? _errorMessage;
//   bool _isLoading = false;

//   // Stored temporarily so VerifyEmailScreen can resend
//   String? _pendingEmail;

//   // Used during role-specific registration flows.
//   String? _pendingRole;

//   // ─── Getters ──────────────────────────────────────────────
//   AuthStatus get status              => _status;
//   Map<String, dynamic>? get profile  => _profile;
//   String? get errorMessage           => _errorMessage;
//   bool get isLoading                 => _isLoading;
//   String? get role                   => _profile?['role'] as String?;
//   bool get isAuthenticated           => _status == AuthStatus.authenticated;
//   String? get pendingEmail           => _pendingEmail;

//   // ─── Initialize ───────────────────────────────────────────
//   Future<void> initialize() async {
//     _setLoading(true);
//     await Future.delayed(const Duration(milliseconds: 1800));

//     if (_authService.isLoggedIn) {
//       final user = _authService.currentUser!;

//       // Email user who hasn't verified yet
//       if (user.emailConfirmedAt == null &&
//           user.appMetadata['provider'] == 'email') {
//         _pendingEmail = user.email;
//         _status = AuthStatus.awaitingVerification;
//         _setLoading(false);
//         return;
//       }

//       final profile = await _authService.fetchProfile(user.id);
//       if (profile != null) {
//         _profile = profile;
//         _status = AuthStatus.authenticated;
//       } else {
//         _status = AuthStatus.unauthenticated;
//       }
//     } else {
//       _status = AuthStatus.unauthenticated;
//     }

//     _setLoading(false);
//   }

//   // ===========================================================
//   // GOOGLE OAUTH
//   // ===========================================================

//   Future<void> signInWithGoogle() async {
//     _setLoading(true);
//     _clearError();
//     try {
//       await _authService.signInWithGoogle();
//     } catch (e) {
//       _setError('Failed to open Google sign-in: $e');
//     }
//     _setLoading(false);
//   }

//   Future<void> handleOAuthCallback() async {
//     _setLoading(true);
//     _clearError();

//     final result = await _authService.handlePostLogin(
//       pendingRole: _pendingRole,
//     );

//     _pendingRole = null;

//     if (result.success) {
//       if (result.profile != null) {
//         _profile = result.profile;
//         _status = AuthStatus.authenticated;
//       } else {
//         _status = AuthStatus.registering;
//       }
//     } else if (result.errorMessage == 'not_whitelisted') {
//       _status = AuthStatus.notWhitelisted;
//     } else {
//       _setError(result.errorMessage ?? 'Sign-in failed.');
//       _status = AuthStatus.unauthenticated;
//     }

//     _setLoading(false);
//   }

//   // ===========================================================
//   // EMAIL / PASSWORD
//   // ===========================================================

//   // ─── Sign up ──────────────────────────────────────────────
//   // Returns true if verification email was sent (normal case).
//   // Returns false on error (sets errorMessage).
//   void setPendingRole(String role) {
//     _pendingRole = role;
//   }

//   Future<bool> signUpWithEmail({
//     required String email,
//     required String password,
//   }) async {
//     _setLoading(true);
//     _clearError();

//     final result = await _authService.signUpWithEmail(
//       email: email,
//       password: password,
//     );

//     _setLoading(false);

//     if (result.emailNeedsVerification) {
//       _pendingEmail = email;
//       _status = AuthStatus.awaitingVerification;
//       notifyListeners();
//       return true; // tells UI to navigate to verify screen
//     }

//     if (result.success) {
//       _profile = result.profile;
//       _status = AuthStatus.authenticated;
//       notifyListeners();
//       return true;
//     }

//     if (result.errorMessage == 'not_whitelisted') {
//       _status = AuthStatus.notWhitelisted;
//       notifyListeners();
//       return false;
//     }

//     _setError(result.errorMessage ?? 'Sign-up failed.');
//     return false;
//   }

//   // ─── Sign in ──────────────────────────────────────────────
//   Future<bool> signInWithEmail({
//     required String email,
//     required String password,
//   }) async {
//     _setLoading(true);
//     _clearError();

//     final result = await _authService.signInWithEmail(
//       email: email,
//       password: password,
//     );

//     _setLoading(false);

//     if (result.emailNeedsVerification) {
//       _pendingEmail = email;
//       _status = AuthStatus.awaitingVerification;
//       notifyListeners();
//       return false;
//     }

//     if (result.success) {
//       _profile = result.profile;
//       _status = AuthStatus.authenticated;
//       notifyListeners();
//       return true;
//     }

//     if (result.errorMessage == 'not_whitelisted') {
//       _status = AuthStatus.notWhitelisted;
//       notifyListeners();
//       return false;
//     }

//     _setError(result.errorMessage ?? 'Sign-in failed.');
//     return false;
//   }

//   // ─── Forgot password ──────────────────────────────────────
//   // Returns true if email was sent successfully.
//   Future<bool> sendPasswordReset(String email) async {
//     _setLoading(true);
//     _clearError();

//     final result = await _authService.sendPasswordResetEmail(email);

//     _setLoading(false);

//     if (result.success) return true;

//     _setError(result.errorMessage ?? 'Failed to send reset email.');
//     return false;
//   }

//   // ─── Resend verification email ────────────────────────────
//   Future<bool> resendVerificationEmail() async {
//     if (_pendingEmail == null) return false;
//     _setLoading(true);

//     final result =
//         await _authService.resendVerificationEmail(_pendingEmail!);

//     _setLoading(false);

//     if (result.success) return true;
//     _setError(result.errorMessage ?? 'Failed to resend email.');
//     return false;
//   }

//   // ─── Check if email is now verified (user tapped the link) ─
//   Future<bool> checkEmailVerified() async {
//     _setLoading(true);

//     // Refresh session — Supabase will update emailConfirmedAt if verified
//     await _authService.authStateChanges.first;
//     final user = _authService.currentUser;

//     if (user?.emailConfirmedAt != null) {
//       final result = await _authService.handlePostLogin();
//       if (result.success) {
//         _profile = result.profile;
//         _status = AuthStatus.authenticated;
//         _setLoading(false);
//         return true;
//       }
//     }

//     _setLoading(false);
//     return false;
//   }

//   // ===========================================================
//   // PROFILE COMPLETION (after Google OAuth registration)
//   // ===========================================================

//   Future<bool> completeStudentRegistration({
//     required String name,
//     required String studentId,
//     required String batch,
//     required String section,
//     required int semester,
//   }) async {
//     _setLoading(true);
//     _clearError();

//     final result = await _authService.completeStudentRegistration(
//       name: name,
//       studentId: studentId,
//       batch: batch,
//       section: section,
//       semester: semester,
//     );

//     _setLoading(false);

//     if (result.success) {
//       _profile = result.profile;
//       _status = AuthStatus.authenticated;
//       notifyListeners();
//       return true;
//     }
//     _setError(result.errorMessage ?? 'Registration failed.');
//     return false;
//   }

//   Future<bool> completeFacultyRegistration({
//     required String name,
//     required String employeeId,
//     required String department,
//     required String designation,
//   }) async {
//     _setLoading(true);
//     _clearError();

//     final result = await _authService.completeFacultyRegistration(
//       name: name,
//       employeeId: employeeId,
//       department: department,
//       designation: designation,
//     );

//     _setLoading(false);

//     if (result.success) {
//       _profile = result.profile;
//       _status = AuthStatus.authenticated;
//       notifyListeners();
//       return true;
//     }
//     _setError(result.errorMessage ?? 'Registration failed.');
//     return false;
//   }

//   // ===========================================================
//   // SIGN OUT & ONBOARDING
//   // ===========================================================

//   Future<void> signOut() async {
//     _setLoading(true);
//     await _authService.signOut();

//     final prefs = await SharedPreferences.getInstance();
//     await prefs.remove(AppConstants.prefUserRole);

//     _profile = null;
//     _pendingEmail = null;
//     _pendingRole = null;
//     _status = AuthStatus.unauthenticated;
//     _setLoading(false);
//   }

//   Future<bool> hasSeenOnboarding() async {
//     final prefs = await SharedPreferences.getInstance();
//     return prefs.getBool(AppConstants.prefOnboardingDone) ?? false;
//   }

//   Future<void> markOnboardingSeen() async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setBool(AppConstants.prefOnboardingDone, true);
//   }

//   // ─── Private helpers ──────────────────────────────────────
//   void _setLoading(bool value) {
//     _isLoading = value;
//     notifyListeners();
//   }

//   void _setError(String message) {
//     _errorMessage = message;
//     _status = AuthStatus.error;
//     notifyListeners();
//   }

//   void _clearError() {
//     _errorMessage = null;
//   }
// }
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universe_v1/core/constants/app_constants.dart';
import 'package:universe_v1/features/auth/services/auth_service.dart';

enum AuthStatus {
  initial,              // App just launched, checking session
  loading,              // Async operation in progress
  authenticated,        // Logged in with a loaded profile
  unauthenticated,      // Not logged in
  registering,          // OAuth done, no profile yet — register screens complete it
  notWhitelisted,       // Admin account not in whitelist
  awaitingVerification, // Signed up, email not yet confirmed
  error,                // Something went wrong
}

class AuthController extends ChangeNotifier {
  final AuthService _authService = AuthService();

  AuthStatus _status = AuthStatus.initial;
  Map<String, dynamic>? _profile;
  String? _errorMessage;
  bool _isLoading = false;

  // Stored temporarily so VerifyEmailScreen can resend
  String? _pendingEmail;

  // Stored so EmailSignupScreen can complete registration after
  // email is verified. Set by student/faculty register screens.
  Map<String, dynamic>? _pendingStudentData;
  Map<String, dynamic>? _pendingFacultyData;

  // ─── Getters ──────────────────────────────────────────────
  AuthStatus get status             => _status;
  Map<String, dynamic>? get profile => _profile;
  String? get errorMessage          => _errorMessage;
  bool get isLoading                => _isLoading;
  String? get role                  => _profile?['role'] as String?;
  bool get isAuthenticated          => _status == AuthStatus.authenticated;
  String? get pendingEmail          => _pendingEmail;
  Map<String, dynamic>? get pendingStudentData => _pendingStudentData;
  Map<String, dynamic>? get pendingFacultyData => _pendingFacultyData;

  // ─── Store pending registration data ──────────────────────
  // Called by register screens BEFORE navigating to email signup.
  // EmailSignupScreen reads these after verification completes.
  void storePendingStudentData({
    required String name,
    required String studentId,
    required String batch,
    required String section,
    required int semester,
  }) {
    _pendingStudentData = {
      'name': name,
      'studentId': studentId,
      'batch': batch,
      'section': section,
      'semester': semester,
    };
    _pendingFacultyData = null;
  }

  void storePendingFacultyData({
    required String name,
    required String employeeId,
    required String department,
    required String designation,
  }) {
    _pendingFacultyData = {
      'name': name,
      'employeeId': employeeId,
      'department': department,
      'designation': designation,
    };
    _pendingStudentData = null;
  }

  void clearPendingData() {
    _pendingStudentData = null;
    _pendingFacultyData = null;
  }

  // ─── Initialize ───────────────────────────────────────────
  Future<void> initialize() async {
    _setLoading(true);
    await Future.delayed(const Duration(milliseconds: 1800));

    if (_authService.isLoggedIn) {
      final user = _authService.currentUser!;

      // Email user who hasn't verified yet
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
        _status = AuthStatus.unauthenticated;
      }
    } else {
      _status = AuthStatus.unauthenticated;
    }

    _setLoading(false);
  }

  // ===========================================================
  // GOOGLE OAUTH
  // ===========================================================

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

  // Called by main.dart auth stream when OAuth callback fires.
  Future<void> handleOAuthCallback() async {
    _setLoading(true);
    _clearError();

    final result = await _authService.handlePostLogin();

    if (result.success) {
      if (result.profile != null) {
        _profile = result.profile;
        _status = AuthStatus.authenticated;
      } else {
        // Session active but no profile yet — register screen completes it
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

  // ===========================================================
  // EMAIL / PASSWORD
  // ===========================================================

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

  // ─── Forgot password ──────────────────────────────────────
  Future<bool> sendPasswordReset(String email) async {
    _setLoading(true);
    _clearError();

    final result = await _authService.sendPasswordResetEmail(email);

    _setLoading(false);

    if (result.success) return true;
    _setError(result.errorMessage ?? 'Failed to send reset email.');
    return false;
  }

  // ─── Resend verification email ────────────────────────────
  Future<bool> resendVerificationEmail() async {
    if (_pendingEmail == null) return false;
    _setLoading(true);

    final result = await _authService.resendVerificationEmail(_pendingEmail!);

    _setLoading(false);

    if (result.success) return true;
    _setError(result.errorMessage ?? 'Failed to resend email.');
    return false;
  }

  // ─── Check email verified (manual check button) ───────────
  Future<bool> checkEmailVerified() async {
    _setLoading(true);

    await _authService.authStateChanges.first;
    final user = _authService.currentUser;

    if (user?.emailConfirmedAt != null) {
      final result = await _authService.handlePostLogin();
      if (result.success) {
        _profile = result.profile;
        _status = AuthStatus.authenticated;
        clearPendingData();
        _setLoading(false);
        return true;
      }
    }

    _setLoading(false);
    return false;
  }

  // ===========================================================
  // PROFILE COMPLETION (after Google OAuth or email verification)
  // ===========================================================

  Future<bool> completeStudentRegistration({
    required String name,
    required String studentId,
    required String batch,
    required String section,
    required int semester,
  }) async {
    _setLoading(true);
    _clearError();

    final result = await _authService.completeStudentRegistration(
      name: name,
      studentId: studentId,
      batch: batch,
      section: section,
      semester: semester,
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
    required String employeeId,
    required String department,
    required String designation,
  }) async {
    _setLoading(true);
    _clearError();

    final result = await _authService.completeFacultyRegistration(
      name: name,
      employeeId: employeeId,
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

  // ===========================================================
  // SIGN OUT & ONBOARDING
  // ===========================================================

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

  // ─── Private helpers ──────────────────────────────────────
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