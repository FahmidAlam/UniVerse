import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universe/core/constants/app_constants.dart';
import 'package:universe/core/services/push_service.dart';

class AuthResult {
  final bool success;
  final String? role;
  final Map<String, dynamic>? profile;
  final String? errorMessage;
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

  factory AuthResult.needsVerification() =>
      const AuthResult(success: false, emailNeedsVerification: true);
}

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  User? get currentUser => _supabase.auth.currentUser;
  bool get isLoggedIn => currentUser != null;

  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;


  Future<void> signInWithGoogle() async {
    await _supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'com.example.universe://login-callback/',
      authScreenLaunchMode: LaunchMode.externalApplication,
    );
  }


  Future<AuthResult> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email.trim().toLowerCase(),
        password: password,
        emailRedirectTo: 'com.example.universe://login-callback/',
      );

      if (response.user == null) {
        return AuthResult.failure('Sign-up failed. Please try again.');
      }

      final needsVerification = response.session == null;
      if (needsVerification) {
        return AuthResult.needsVerification();
      }

      return await handlePostLogin();
    } on AuthException catch (e) {
      return AuthResult.failure(_friendlyAuthError(e.message));
    } on PostgrestException catch (e) {
      return AuthResult.failure('Database error: ${e.message}');
    } catch (e) {
      return AuthResult.failure('Unexpected error: $e');
    }
  }

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

  Future<AuthResult> sendPasswordResetEmail(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(
        email.trim().toLowerCase(),
        redirectTo: 'com.example.universe://reset-callback/',
      );
      return const AuthResult(success: true);
    } on AuthException catch (e) {
      return AuthResult.failure(_friendlyAuthError(e.message));
    } catch (e) {
      return AuthResult.failure('Unexpected error: $e');
    }
  }

  Future<AuthResult> resendVerificationEmail(String email) async {
    try {
      await _supabase.auth.resend(
        type: OtpType.signup,
        email: email.trim().toLowerCase(),
        emailRedirectTo: 'com.example.universe://login-callback/',
      );
      return const AuthResult(success: true);
    } on AuthException catch (e) {
      return AuthResult.failure(_friendlyAuthError(e.message));
    } catch (e) {
      return AuthResult.failure('$e');
    }
  }

  Future<AuthResult> verifyEmailOtp({
    required String email,
    required String token,
  }) async {
    try {
      final response = await _supabase.auth.verifyOTP(
        type: OtpType.signup,
        email: email.trim().toLowerCase(),
        token: token.trim(),
      );

      if (response.session == null) {
        return AuthResult.failure('Invalid or expired code. Try resending.');
      }
      return const AuthResult(success: true);
    } on AuthException catch (e) {
      return AuthResult.failure(_friendlyAuthError(e.message));
    } catch (e) {
      return AuthResult.failure('Unexpected error: $e');
    }
  }

  Future<AuthResult> updatePassword(String newPassword) async {
    try {
      await _supabase.auth.updateUser(UserAttributes(password: newPassword));
      return const AuthResult(success: true);
    } on AuthException catch (e) {
      return AuthResult.failure(_friendlyAuthError(e.message));
    } catch (e) {
      return AuthResult.failure('$e');
    }
  }


  Future<AuthResult> handlePostLogin() async {
    try {
      final user = currentUser;
      if (user == null) return AuthResult.failure('No active session found.');

      final email = user.email;
      if (email == null) return AuthResult.failure('Could not read email.');

      final existingProfile = await _supabase
          .from(AppConstants.tableProfiles)
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (existingProfile != null) {
        final role = existingProfile['role'] as String;
        return AuthResult(success: true, role: role, profile: existingProfile);
      }

      final whitelistRow = await _supabase
          .from(AppConstants.tableWhitelists)
          .select()
          .eq('email', email.toLowerCase())
          .maybeSingle();

      if (whitelistRow == null) {
        return const AuthResult(success: true);
      }

      final role = whitelistRow['role'] as String;
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


  Future<AuthResult> completeStudentRegistration({
    required String name,
    required String studentId,
    required String batch,
    required String section,
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
        'avatar_url': user.userMetadata?['avatar_url'],
      });

      final profile = await _supabase
          .from(AppConstants.tableProfiles)
          .select()
          .eq('id', user.id)
          .single();

      return AuthResult(
        success: true,
        role: AppConstants.roleStudent,
        profile: profile,
      );
    } on PostgrestException catch (e) {
      return AuthResult.failure(e.message);
    } catch (e) {
      return AuthResult.failure('$e');
    }
  }

  Future<AuthResult> completeFacultyRegistration({
    required String name,
    required String teacherCode,
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
        'teacher_code': teacherCode,
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
        success: true,
        role: AppConstants.roleTeacher,
        profile: profile,
      );
    } on PostgrestException catch (e) {
      return AuthResult.failure(e.message);
    } catch (e) {
      return AuthResult.failure('$e');
    }
  }

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

  Future<void> signOut() async {
    if (!kIsWeb) await PushService.instance.unregisterToken();
    await _supabase.auth.signOut();
  }

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
    return raw;
  }
}
