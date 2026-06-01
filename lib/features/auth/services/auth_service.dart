// // ============================================================
// // FILE: lib/features/auth/services/auth_service.dart
// // PURPOSE: All raw Supabase auth operations live here.
// // AuthController calls this; screens call the controller.
// // This layer never touches Flutter UI.
// //
// // RESPONSIBILITIES:
// // - Google OAuth sign-in / sign-out
// // - Whitelist check (is this email registered by admin?)
// // - Profile creation (first login only)
// // - Profile fetch (every login)
// // - Session restore on app restart
// // ============================================================

// import 'package:supabase_flutter/supabase_flutter.dart';
// import 'package:universe_v1/core/constants/app_constants.dart';

// // ─── Data model returned after a successful auth check ────
// class AuthResult {
//   final bool success;
//   final String? role;         // 'student' | 'teacher' | 'admin'
//   final Map<String, dynamic>? profile;
//   final String? errorMessage;

//   const AuthResult({
//     required this.success,
//     this.role,
//     this.profile,
//     this.errorMessage,
//   });

//   factory AuthResult.failure(String message) =>
//       AuthResult(success: false, errorMessage: message);
// }

// class AuthService {
//   final SupabaseClient _supabase = Supabase.instance.client;

//   // ─── Current session user ─────────────────────────────────
//   User? get currentUser => _supabase.auth.currentUser;
//   bool get isLoggedIn   => currentUser != null;

//   // ─── Sign in with Google ──────────────────────────────────
//   // Opens the Google OAuth flow. On web this does a redirect;
//   // on mobile Supabase handles the deep link automatically.
//   Future<void> signInWithGoogle() async {
//     await _supabase.auth.signInWithOAuth(
//       OAuthProvider.google,
//       redirectTo: 'io.supabase.universe://login-callback/',
//       authScreenLaunchMode: LaunchMode.externalApplication,
//     );
//   }

//   // ─── Check whitelist + fetch/create profile ───────────────
//   // Called after the OAuth redirect completes and we have a
//   // confirmed session. Returns AuthResult with role or error.
//   Future<AuthResult> handlePostLogin() async {
//     try {
//       final user = currentUser;
//       if (user == null) {
//         return AuthResult.failure('No active session found.');
//       }

//       final email = user.email;
//       if (email == null) {
//         return AuthResult.failure('Could not read email from Google account.');
//       }

//       // 1. Check whitelist
//       final whitelistRow = await _supabase
//           .from(AppConstants.tableWhitelists)
//           .select()
//           .eq('email', email)
//           .maybeSingle();

//       if (whitelistRow == null) {
//         // Admin hasn't pre-registered this email
//         await signOut(); // Clear the session so they can't stay logged in
//         return AuthResult.failure('not_whitelisted');
//       }

//       final role = whitelistRow['role'] as String;

//       // 2. Check if profile already exists
//       final existingProfile = await _supabase
//           .from(AppConstants.tableProfiles)
//           .select()
//           .eq('id', user.id)
//           .maybeSingle();

//       if (existingProfile != null) {
//         // Returning user — just return existing profile
//         return AuthResult(
//           success: true,
//           role: role,
//           profile: existingProfile,
//         );
//       }

//       // 3. First login — create profile from whitelist data
//       final newProfile = {
//         'id': user.id,
//         'email': email,
//         'role': role,
//         'name': whitelistRow['name'] ?? user.userMetadata?['full_name'] ?? '',
//         'avatar_url': user.userMetadata?['avatar_url'],
//         'batch': whitelistRow['batch'],
//         'section': whitelistRow['section'],
//         'semester': whitelistRow['semester'],
//         'student_id': null, // set by student during register
//         'teacher_code': whitelistRow['teacher_code'],
//         'designation': whitelistRow['designation'],
//         'department': whitelistRow['department'],
//         'photo_url': user.userMetadata?['avatar_url'],
//         'courses': const [],
//       };

//       await _supabase
//           .from(AppConstants.tableProfiles)
//           .insert(newProfile);

//       return AuthResult(
//         success: true,
//         role: role,
//         profile: newProfile,
//       );
//     } on PostgrestException catch (e) {
//       return AuthResult.failure('Database error: ${e.message}');
//     } catch (e) {
//       return AuthResult.failure('Unexpected error: $e');
//     }
//   }

//   // ─── Complete registration (student) ─────────────────────
//   // Called from StudentRegisterScreen after user fills the form.
//   // Updates their profile with student-specific academic info.
//   Future<AuthResult> completeStudentRegistration({
//     required String name,
//     required String studentId,
//     required String batch,
//     required String section,
//     required int semester,
//   }) async {
//     try {
//       final user = currentUser;
//       if (user == null) return AuthResult.failure('Not signed in.');

//       await _supabase.from(AppConstants.tableProfiles).upsert({
//         'id': user.id,
//         'email': user.email,
//         'role': AppConstants.roleStudent,
//         'name': name,
//         'student_id': studentId,
//         'batch': batch,
//         'section': section,
//         'semester': semester,
//         'avatar_url': user.userMetadata?['avatar_url'],
//       });

//       final profile = await _supabase
//           .from(AppConstants.tableProfiles)
//           .select()
//           .eq('id', user.id)
//           .single();

//       return AuthResult(
//         success: true,
//         role: AppConstants.roleStudent,
//         profile: profile,
//       );
//     } on PostgrestException catch (e) {
//       return AuthResult.failure(e.message);
//     } catch (e) {
//       return AuthResult.failure('$e');
//     }
//   }

//   // ─── Complete registration (faculty) ─────────────────────
//   Future<AuthResult> completeFacultyRegistration({
//     required String name,
//     required String employeeId,
//     required String department,
//     required String designation,
//   }) async {
//     try {
//       final user = currentUser;
//       if (user == null) return AuthResult.failure('Not signed in.');

//       await _supabase.from(AppConstants.tableProfiles).upsert({
//         'id': user.id,
//         'email': user.email,
//         'role': AppConstants.roleTeacher,
//         'name': name,
//         'student_id': employeeId, // reusing field for employee ID
//         'department': department,
//         'designation': designation,
//         'avatar_url': user.userMetadata?['avatar_url'],
//       });

//       final profile = await _supabase
//           .from(AppConstants.tableProfiles)
//           .select()
//           .eq('id', user.id)
//           .single();

//       return AuthResult(
//         success: true,
//         role: AppConstants.roleTeacher,
//         profile: profile,
//       );
//     } on PostgrestException catch (e) {
//       return AuthResult.failure(e.message);
//     } catch (e) {
//       return AuthResult.failure('$e');
//     }
//   }

//   // ─── Fetch profile by user id ─────────────────────────────
//   Future<Map<String, dynamic>?> fetchProfile(String userId) async {
//     try {
//       return await _supabase
//           .from(AppConstants.tableProfiles)
//           .select()
//           .eq('id', userId)
//           .maybeSingle();
//     } catch (_) {
//       return null;
//     }
//   }

//   // ─── Sign out ─────────────────────────────────────────────
//   Future<void> signOut() async {
//     await _supabase.auth.signOut();
//   }

//   // ─── Auth state stream ────────────────────────────────────
//   // GoRouter listens to this to redirect after OAuth completes.
//   Stream<AuthState> get authStateChanges =>
//       _supabase.auth.onAuthStateChange;
// }
// ============================================================
// FILE: lib/features/auth/services/auth_service.dart
// PURPOSE: All raw Supabase auth operations.
// Supports BOTH Google OAuth AND email/password auth.
// AuthController calls this; screens never touch this directly.
// ============================================================

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universe_v1/core/constants/app_constants.dart';

// ─── Data model returned after every auth operation ───────
class AuthResult {
  final bool success;
  final String? role;
  final Map<String, dynamic>? profile;
  final String? errorMessage;
  // Extra flag for email/password flow
  final bool emailNeedsVerification;

  const AuthResult({
    required this.success,
    this.role,
    this.profile,
    this.errorMessage,
    this.emailNeedsVerification = false,
  });

  factory AuthResult.failure(String message) =>
      AuthResult(success: false, errorMessage: message);

  factory AuthResult.needsVerification() => const AuthResult(
        success: false,
        emailNeedsVerification: true,
      );
}

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ─── Current session ──────────────────────────────────────
  User? get currentUser => _supabase.auth.currentUser;
  bool get isLoggedIn   => currentUser != null;

  // ─── Auth state stream ────────────────────────────────────
  Stream<AuthState> get authStateChanges =>
      _supabase.auth.onAuthStateChange;

  // ===========================================================
  // GOOGLE OAUTH
  // ===========================================================

  Future<void> signInWithGoogle() async {
    await _supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'com.example.universe_v1://login-callback/',
      authScreenLaunchMode: LaunchMode.externalApplication,
    );
  }

  // ===========================================================
  // EMAIL / PASSWORD AUTH
  // ===========================================================

  // ─── Sign up with email + password ───────────────────────
  // Creates a Supabase auth user. Supabase automatically sends
  // a verification email. The user cannot log in until they
  // click the link in that email (controlled in Supabase dashboard).
  Future<AuthResult> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      // First check whitelist — only pre-registered emails allowed
      final whitelistRow = await _supabase
          .from(AppConstants.tableWhitelists)
          .select()
          .eq('email', email.trim().toLowerCase())
          .maybeSingle();

      if (whitelistRow == null) {
        return AuthResult.failure('not_whitelisted');
      }

      final response = await _supabase.auth.signUp(
        email: email.trim().toLowerCase(),
        password: password,
        emailRedirectTo: 'com.example.universe_v1://login-callback/',
      );

      if (response.user == null) {
        return AuthResult.failure('Sign-up failed. Please try again.');
      }

      // If email confirmation is required, user.identities will be
      // empty on the response — we tell the UI to show verify screen
      final needsVerification =
          response.session == null; // no session = email not confirmed yet

      if (needsVerification) {
        return AuthResult.needsVerification();
      }

      // Rare case: email confirmation disabled in Supabase →
      // session is immediately available, proceed to profile setup
      return await handlePostLogin();
    } on AuthException catch (e) {
      return AuthResult.failure(_friendlyAuthError(e.message));
    } on PostgrestException catch (e) {
      return AuthResult.failure('Database error: ${e.message}');
    } catch (e) {
      return AuthResult.failure('Unexpected error: $e');
    }
  }

  // ─── Sign in with email + password ────────────────────────
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );

      if (response.user == null) {
        return AuthResult.failure('Invalid email or password.');
      }

      // Check if email is verified
      final isVerified = response.user!.emailConfirmedAt != null;
      if (!isVerified) {
        await _supabase.auth.signOut();
        return AuthResult.needsVerification();
      }

      return await handlePostLogin();
    } on AuthException catch (e) {
      return AuthResult.failure(_friendlyAuthError(e.message));
    } catch (e) {
      return AuthResult.failure('Unexpected error: $e');
    }
  }

  // ─── Send password reset email ────────────────────────────
  Future<AuthResult> sendPasswordResetEmail(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(
        email.trim().toLowerCase(),
        redirectTo: 'com.example.universe_v1://reset-callback/',
      );
      return const AuthResult(success: true);
    } on AuthException catch (e) {
      return AuthResult.failure(_friendlyAuthError(e.message));
    } catch (e) {
      return AuthResult.failure('Unexpected error: $e');
    }
  }

  // ─── Resend verification email ────────────────────────────
  Future<AuthResult> resendVerificationEmail(String email) async {
    try {
      await _supabase.auth.resend(
        type: OtpType.signup,
        email: email.trim().toLowerCase(),
        emailRedirectTo: 'com.example.universe_v1://login-callback/',
      );
      return const AuthResult(success: true);
    } on AuthException catch (e) {
      return AuthResult.failure(_friendlyAuthError(e.message));
    } catch (e) {
      return AuthResult.failure('$e');
    }
  }

  // ─── Update password (from reset link) ───────────────────
  Future<AuthResult> updatePassword(String newPassword) async {
    try {
      await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      return const AuthResult(success: true);
    } on AuthException catch (e) {
      return AuthResult.failure(_friendlyAuthError(e.message));
    } catch (e) {
      return AuthResult.failure('$e');
    }
  }

  // ===========================================================
  // SHARED: POST-LOGIN PROFILE HANDLING
  // (Same logic for BOTH Google and email auth)
  // ===========================================================

  Future<AuthResult> handlePostLogin() async {
    try {
      final user = currentUser;
      if (user == null) return AuthResult.failure('No active session found.');

      final email = user.email;
      if (email == null) return AuthResult.failure('Could not read email.');

      // 1. Check whitelist
      final whitelistRow = await _supabase
          .from(AppConstants.tableWhitelists)
          .select()
          .eq('email', email.toLowerCase())
          .maybeSingle();

      if (whitelistRow == null) {
        await signOut();
        return AuthResult.failure('not_whitelisted');
      }

      final role = whitelistRow['role'] as String;

      // 2. Check if profile already exists
      final existingProfile = await _supabase
          .from(AppConstants.tableProfiles)
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (existingProfile != null) {
        return AuthResult(success: true, role: role, profile: existingProfile);
      }

      // 3. First login — create profile from whitelist data
      final newProfile = {
        'id': user.id,
        'email': email,
        'role': role,
        'name': whitelistRow['name'] ?? user.userMetadata?['full_name'] ?? '',
        'avatar_url': user.userMetadata?['avatar_url'],
        'batch': whitelistRow['batch'],
        'section': whitelistRow['section'],
        'semester': whitelistRow['semester'],
        'student_id': null,
        'teacher_code': whitelistRow['teacher_code'],
        'designation': whitelistRow['designation'],
        'department': whitelistRow['department'],
        'photo_url': user.userMetadata?['avatar_url'],
        'courses': const [],
      };

      await _supabase.from(AppConstants.tableProfiles).insert(newProfile);

      return AuthResult(success: true, role: role, profile: newProfile);
    } on PostgrestException catch (e) {
      return AuthResult.failure('Database error: ${e.message}');
    } catch (e) {
      return AuthResult.failure('Unexpected error: $e');
    }
  }

  // ===========================================================
  // PROFILE COMPLETION (after Google OAuth registration)
  // ===========================================================

  Future<AuthResult> completeStudentRegistration({
    required String name,
    required String studentId,
    required String batch,
    required String section,
    required int semester,
  }) async {
    try {
      final user = currentUser;
      if (user == null) return AuthResult.failure('Not signed in.');

      await _supabase.from(AppConstants.tableProfiles).upsert({
        'id': user.id,
        'email': user.email,
        'role': AppConstants.roleStudent,
        'name': name,
        'student_id': studentId,
        'batch': batch,
        'section': section,
        'semester': semester,
        'avatar_url': user.userMetadata?['avatar_url'],
      });

      final profile = await _supabase
          .from(AppConstants.tableProfiles)
          .select()
          .eq('id', user.id)
          .single();

      return AuthResult(
          success: true, role: AppConstants.roleStudent, profile: profile);
    } on PostgrestException catch (e) {
      return AuthResult.failure(e.message);
    } catch (e) {
      return AuthResult.failure('$e');
    }
  }

  Future<AuthResult> completeFacultyRegistration({
    required String name,
    required String employeeId,
    required String department,
    required String designation,
  }) async {
    try {
      final user = currentUser;
      if (user == null) return AuthResult.failure('Not signed in.');

      await _supabase.from(AppConstants.tableProfiles).upsert({
        'id': user.id,
        'email': user.email,
        'role': AppConstants.roleTeacher,
        'name': name,
        'student_id': employeeId,
        'department': department,
        'designation': designation,
        'avatar_url': user.userMetadata?['avatar_url'],
      });

      final profile = await _supabase
          .from(AppConstants.tableProfiles)
          .select()
          .eq('id', user.id)
          .single();

      return AuthResult(
          success: true, role: AppConstants.roleTeacher, profile: profile);
    } on PostgrestException catch (e) {
      return AuthResult.failure(e.message);
    } catch (e) {
      return AuthResult.failure('$e');
    }
  }

  // ─── Fetch profile ────────────────────────────────────────
  Future<Map<String, dynamic>?> fetchProfile(String userId) async {
    try {
      return await _supabase
          .from(AppConstants.tableProfiles)
          .select()
          .eq('id', userId)
          .maybeSingle();
    } catch (_) {
      return null;
    }
  }

  // ─── Sign out ─────────────────────────────────────────────
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  // ─── Human-readable error messages ───────────────────────
  // Supabase throws technical errors — we translate them.
  String _friendlyAuthError(String raw) {
    final msg = raw.toLowerCase();
    if (msg.contains('invalid login credentials') ||
        msg.contains('invalid email or password')) {
      return 'Incorrect email or password. Please try again.';
    }
    if (msg.contains('email not confirmed')) {
      return 'Please verify your email before signing in.';
    }
    if (msg.contains('user already registered')) {
      return 'An account with this email already exists. Try signing in.';
    }
    if (msg.contains('password should be at least')) {
      return 'Password must be at least 6 characters.';
    }
    if (msg.contains('rate limit')) {
      return 'Too many attempts. Please wait a few minutes and try again.';
    }
    if (msg.contains('network') || msg.contains('connection')) {
      return 'No internet connection. Please check your network.';
    }
    return raw; // fallback to raw if no match
  }
}