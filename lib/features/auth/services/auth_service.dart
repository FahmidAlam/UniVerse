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
      // No whitelist check here — students and teachers sign up freely.
      // Admin accounts are created directly by the department head
      // and only sign in, never self-register via this screen.
      final response = await _supabase.auth.signUp(
        email: email.trim().toLowerCase(),
        password: password,
        emailRedirectTo: 'com.example.universe_v1://login-callback/',
      );

      if (response.user == null) {
        return AuthResult.failure('Sign-up failed. Please try again.');
      }

      // No session = email confirmation required
      final needsVerification = response.session == null;
      if (needsVerification) {
        return AuthResult.needsVerification();
      }

      // Email confirmation disabled in Supabase dashboard → proceed
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

      // ── Step 1: Check if profile already exists ─────────────
      // Returning users skip all whitelist logic entirely.
      final existingProfile = await _supabase
          .from(AppConstants.tableProfiles)
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (existingProfile != null) {
        final role = existingProfile['role'] as String;
        return AuthResult(
            success: true, role: role, profile: existingProfile);
      }

      // ── Step 2: First login — check whitelist for admin gate ─
      // Whitelist is ONLY enforced for admin accounts.
      // Students and teachers can sign up freely.
      final whitelistRow = await _supabase
          .from(AppConstants.tableWhitelists)
          .select()
          .eq('email', email.toLowerCase())
          .maybeSingle();

      // ── Step 3: Determine role ────────────────────────────────
      // If whitelisted → use the role from whitelist (covers admin).
      // If NOT whitelisted → default to student.
      //   Teachers self-identify during registration via
      //   completeFacultyRegistration() which sets role explicitly.
      //   Admin without whitelist entry → blocked.
      String role;

      if (whitelistRow != null) {
        role = whitelistRow['role'] as String;
      } else {
        // Not in whitelist — allowed only as student or teacher.
        // Admin accounts MUST be whitelisted — block them here.
        // (Teachers arrive here via completeFacultyRegistration,
        //  which upserts the profile with role='teacher' before
        //  handlePostLogin is called, so existingProfile catches
        //  them above. This fallback is for Google OAuth students.)
        role = AppConstants.roleStudent;
      }

      // Extra safety: if somehow an admin is not whitelisted, block.
      if (role == AppConstants.roleAdmin && whitelistRow == null) {
        await signOut();
        return AuthResult.failure('not_whitelisted');
      }

      // ── Step 4: Create profile for first-time user ────────────
      final newProfile = {
        'id': user.id,
        'email': email,
        'role': role,
        'name': whitelistRow?['name'] ??
            user.userMetadata?['full_name'] ?? '',
        'avatar_url': user.userMetadata?['avatar_url'],
        'batch': whitelistRow?['batch'],
        'section': whitelistRow?['section'],
        'semester': whitelistRow?['semester'],
        'student_id': null,
        'teacher_code': whitelistRow?['teacher_code'],
        'designation': whitelistRow?['designation'],
        'department': whitelistRow?['department'],
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