import 'dart:async' show unawaited;

import 'package:app_links/app_links.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universe/core/constants/app_constants.dart';
import 'package:universe/core/platform/auth_callback_cleanup.dart';
import 'package:universe/core/router/app_router.dart';
import 'package:universe/core/router/route_names.dart';
import 'package:universe/core/services/push_service.dart';
import 'package:universe/core/theme/app_theme.dart';
import 'package:universe/features/auth/controllers/auth_controller.dart';
import 'package:universe/features/auth/services/auth_service.dart';
import 'package:universe/features/auth/services/invitation_callback_bridge.dart';
import 'package:universe/features/auth/services/invitation_callback_coordinator.dart';
import 'package:universe/firebase_options.dart';
import 'package:universe/shared/widgets/u_blocking_overlay.dart';

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

  final invitations = InvitationCallbackCoordinator(
    operationEpoch: () => authController.operationEpoch,
    consume: InvitationCallbackBridge.current(
        operationEpoch: () => authController.operationEpoch).consume,
    onStart: authController.beginInvitationCallback,
    onVerified: (session, epoch) async {
      if (!authController.completeInvitationCallback(epoch, session.user.id)) {
        // A sign-out or newer auth event cancelled this callback while remote
        // verification ran. Revoke its newly established local session.
        await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
      }
    },
    onFailure: (epoch) => authController.reportCallbackFailure(epoch: epoch),
  );
  if (kIsWeb) {
    final callbackUri = Uri.base;
    clearInvitationLocation(callbackUri);
    await invitations.handle(callbackUri);
  } else {
    // Public app_links API, shared with the SDK. Ordinary PKCE links continue
    // through Supabase's own listener; only implicit invitations are consumed.
    final links = AppLinks();
    links.uriLinkStream.listen((uri) => unawaited(invitations.handle(uri)));
    try {
      final initialLink = await links.getInitialLink();
      if (initialLink != null) await invitations.handle(initialLink);
    } catch (_) {
      // Link retrieval failures do not claim a verified invitation/session.
    }
  }

  final appRouter = AppRouter(authController: authController);

  if (!kIsWeb) {
    PushService.instance.onNotificationTap = (_) {
      appRouter.router.go(RouteNames.notifications);
    };
  }

  AuthService().authStateChanges.listen((event) async {
    authController.handleAuthEvent(event.event, event.session?.user.id);
    if (event.event == AuthChangeEvent.signedIn) {
      if (authController.status != AuthStatus.profileError &&
          authController.status != AuthStatus.passwordRecovery &&
          authController.status != AuthStatus.authenticated &&
          !authController.isLoading) {
        await authController.handleOAuthCallback();
      }
      final userId = event.session?.user.id;
      if (!kIsWeb && userId != null) {
        unawaited(PushService.instance.registerToken(userId));
      }
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
      // One overlay for every sign-out button in the app.
      builder: (context, child) => ListenableBuilder(
        listenable: router.authController,
        builder: (context, _) => Stack(
          children: [
            child!,
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: router.authController.isSigningOut
                  ? const UBlockingOverlay(message: 'Signing out…')
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
