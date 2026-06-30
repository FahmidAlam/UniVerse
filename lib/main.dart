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

  AppTheme.setSystemUI();

  if (!kIsWeb) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await PushService.instance.init();
  }

  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );

  final authController = AuthController();

  final appRouter = AppRouter(authController: authController);

  if (!kIsWeb) {
    PushService.instance.onNotificationTap = (_) {
      appRouter.router.go(RouteNames.notifications);
    };
  }

  AuthService().authStateChanges.listen((event) async {
    if (event.event == AuthChangeEvent.signedIn) {
      if (authController.status != AuthStatus.authenticated &&
          !authController.isLoading) {
        await authController.handleOAuthCallback();
      }
      final userId = event.session?.user.id;
      if (!kIsWeb && userId != null) {
        unawaited(PushService.instance.registerToken(userId));
      }
    } else if (event.event == AuthChangeEvent.passwordRecovery) {
      appRouter.router.go(RouteNames.resetPassword);
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
