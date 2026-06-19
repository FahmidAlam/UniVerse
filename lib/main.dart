// ============================================================
// FILE: lib/main.dart
// PURPOSE: App entry point. Initializes Supabase, sets up
// the AuthController, wires GoRouter, and launches
// MaterialApp.router with AppTheme.dark.
// ============================================================

import 'dart:async' show unawaited;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universe/core/constants/app_constants.dart';
import 'package:universe/core/router/app_router.dart';
import 'package:universe/core/router/route_names.dart';
import 'package:universe/core/services/push_service.dart';
import 'package:universe/core/theme/app_theme.dart';
import 'package:universe/features/auth/controllers/auth_controller.dart';
import 'package:universe/features/auth/services/auth_service.dart';
import 'package:universe/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── System UI (status bar transparent, light icons) ───────
  AppTheme.setSystemUI();

  // ── Firebase + push notifications ─────────────────────────
  // Mobile only. firebase_options has no web config (Android-only app),
  // so calling this on web throws UnsupportedError and kills startup.
  if (!kIsWeb) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await PushService.instance.init();
  }

  // ── Supabase initialization ───────────────────────────────
  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce, // PKCE = secure for mobile
    ),
  );

  // ── Auth controller ───────────────────────────────────────
  final authController = AuthController();

  // ── Router ────────────────────────────────────────────────
  final appRouter = AppRouter(authController: authController);

  // Tapping a push opens the notifications feed.
  // Accessing PushService.instance constructs FirebaseMessaging.instance,
  // which throws on web (Firebase isn't initialized there) — so mobile only.
  if (!kIsWeb) {
    PushService.instance.onNotificationTap = (_) {
      appRouter.router.go(RouteNames.notifications);
    };
  }

  // ── Listen for OAuth deep link callbacks ──────────────────
  // When Google OAuth completes and redirects back to the app,
  // Supabase fires an onAuthStateChange event. We hook into
  // it here to call handleOAuthCallback on the controller.
  AuthService().authStateChanges.listen((event) async {
    if (event.event == AuthChangeEvent.signedIn) {
      // Resolve the session only when no controller-driven flow is
      // already doing it: email sign-in and OTP verification call
      // handlePostLogin themselves (isLoading is true while they run),
      // and double-resolving races the router into wrong redirects.
      // The OAuth deep link is the case this listener exists for.
      if (authController.status != AuthStatus.authenticated &&
          !authController.isLoading) {
        await authController.handleOAuthCallback();
      }
      // Save this device's FCM token so the user can receive pushes.
      // Fire-and-forget: token persistence must never block navigation,
      // and registerToken catches its own errors.
      final userId = event.session?.user.id;
      if (!kIsWeb && userId != null) {
        unawaited(PushService.instance.registerToken(userId));
      }
    } else if (event.event == AuthChangeEvent.passwordRecovery) {
      // User tapped the reset link in their email.
      // Supabase establishes a session — navigate to reset screen.
      appRouter.router.go(RouteNames.resetPassword);
    }
    // signedOut: token cleanup happens in AuthService.signOut() BEFORE
    // the session drops — deleting here would run as anon and silently
    // leave a stale row behind.
  });

  runApp(UniVerseApp(router: appRouter));
}

class UniVerseApp extends StatelessWidget {
  final AppRouter router;

  const UniVerseApp({super.key, required this.router});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: router.router,
    );
  }
}
