// ============================================================
// FILE: lib/main.dart
// PURPOSE: App entry point. Initializes Supabase, sets up
// the AuthController, wires GoRouter, and launches
// MaterialApp.router with AppTheme.dark.
// ============================================================

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universe_v1/core/constants/app_constants.dart';
import 'package:universe_v1/core/router/app_router.dart';
import 'package:universe_v1/core/router/route_names.dart';
import 'package:universe_v1/core/services/push_service.dart';
import 'package:universe_v1/core/theme/app_theme.dart';
import 'package:universe_v1/features/auth/controllers/auth_controller.dart';
import 'package:universe_v1/features/auth/services/auth_service.dart';
import 'package:universe_v1/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── System UI (status bar transparent, light icons) ───────
  AppTheme.setSystemUI();

  // ── Firebase + push notifications ─────────────────────────
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await PushService.instance.init();

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
  PushService.instance.onNotificationTap = (_) {
    appRouter.router.go(RouteNames.notifications);
  };

  // ── Listen for OAuth deep link callbacks ──────────────────
  // When Google OAuth completes and redirects back to the app,
  // Supabase fires an onAuthStateChange event. We hook into
  // it here to call handleOAuthCallback on the controller.
  AuthService().authStateChanges.listen((event) async {
    if (event.event == AuthChangeEvent.signedIn) {
      // Only handle if not already authenticated (avoids
      // double-calling on app restore with existing session)
      if (authController.status != AuthStatus.authenticated) {
        await authController.handleOAuthCallback();
      }
      // Save this device's FCM token so the user can receive pushes.
      final userId = event.session?.user.id;
      if (userId != null) {
        await PushService.instance.registerToken(userId);
      }
    } else if (event.event == AuthChangeEvent.passwordRecovery) {
      // User tapped the reset link in their email.
      // Supabase establishes a session — navigate to reset screen.
      appRouter.router.go(RouteNames.resetPassword);
    } else if (event.event == AuthChangeEvent.signedOut) {
      // Stop pushes to this device for the signed-out user.
      await PushService.instance.unregisterToken();
      // GoRouter refresh will handle redirect to login
    }
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

