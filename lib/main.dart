// ============================================================
// FILE: lib/main.dart
// PURPOSE: App entry point. Initializes Supabase, sets up
// the AuthController, wires GoRouter, and launches
// MaterialApp.router with AppTheme.dark.
// ============================================================

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universe_v1/core/constants/app_constants.dart';
import 'package:universe_v1/core/router/app_router.dart';
import 'package:universe_v1/core/router/route_names.dart';
import 'package:universe_v1/core/theme/app_theme.dart';
import 'package:universe_v1/features/auth/controllers/auth_controller.dart';
import 'package:universe_v1/features/auth/services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── System UI (status bar transparent, light icons) ───────
  AppTheme.setSystemUI();

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
    } else if (event.event == AuthChangeEvent.passwordRecovery) {
      // User tapped the reset link in their email.
      // Supabase establishes a session — navigate to reset screen.
      appRouter.router.go(RouteNames.resetPassword);
    } else if (event.event == AuthChangeEvent.signedOut) {
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