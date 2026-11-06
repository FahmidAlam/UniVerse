import 'dart:async';
import 'package:flutter/material.dart';
import 'package:universe/features/auth/screens/reset_password_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universe/core/router/app_router.dart';
import 'package:universe/core/router/route_names.dart';
import 'package:universe/features/auth/controllers/auth_controller.dart';
import 'package:universe/features/auth/services/auth_service.dart';

class FakeAuth extends Fake implements AuthService {
  User? user = User(
      id: 'admin-1',
      appMetadata: {'provider': 'email'},
      userMetadata: {},
      aud: 'authenticated',
      createdAt: '',
      email: 'a@example.test',
      emailConfirmedAt: '2026-11-05');
  Future<Map<String, dynamic>?> Function()? read;
  AuthResult result = const AuthResult(success: true);
  AuthResult updateResult = const AuthResult(success: true);
  int updates = 0;
  Future<bool>? googleResult;
  @override
  Future<bool> signInWithGoogle() async =>
      googleResult == null ? false : await googleResult!;
  @override
  User? get currentUser => user;
  @override
  bool get isLoggedIn => user != null;
  @override
  Future<Map<String, dynamic>?> fetchProfile(String id) async =>
      read == null ? {'id': id, 'role': 'admin'} : await read!();
  @override
  Future<AuthResult> handlePostLogin() async => result;
  @override
  Future<AuthResult> updatePassword(String password) async {
    updates++;
    return updateResult;
  }

  @override
  Future<void> signOut() async {
    user = null;
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  AuthController controller(FakeAuth service,
          {Duration timeout = const Duration(minutes: 10)}) =>
      AuthController(
          authService: service,
          initializationDelay: Duration.zero,
          recoveryTimeout: timeout);
  testWidgets(
      'password screen submits through the trusted controller and displays success',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = FakeAuth();
    final auth = controller(service);
    auth.handleAuthEvent(AuthChangeEvent.passwordRecovery, service.user!.id);
    await tester.pumpWidget(
        MaterialApp(home: ResetPasswordScreen(authController: auth)));
    await tester.enterText(find.byType(TextFormField).at(0), 'Safe-password8!');
    await tester.enterText(find.byType(TextFormField).at(1), 'Safe-password8!');
    await tester.tap(find.text('Update password'));
    await tester.pumpAndSettle();
    auth.dispose();
    expect(service.updates, 1);
    expect(find.textContaining('Your password has been changed successfully.'),
        findsOneWidget);
  });
  test(
      'a newer signedIn session cancels pending invitation and resolves its own profile',
      () async {
    final service = FakeAuth();
    final auth = controller(service);
    addTearDown(auth.dispose);
    final callbackEpoch = auth.beginInvitationCallback();
    service.user = User(
        id: 'newer-user',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: '');
    service.result = const AuthResult(
        success: true, profile: {'id': 'newer-user', 'role': 'admin'});
    auth.handleAuthEvent(AuthChangeEvent.signedIn, 'newer-user');
    expect(auth.operationEpoch, greaterThan(callbackEpoch));
    expect(auth.isLoading, isFalse);
    expect(
        auth.completeInvitationCallback(callbackEpoch, 'newer-user'), isFalse);
    await auth.handleOAuthCallback();
    expect(auth.status, AuthStatus.authenticated);
    expect(auth.profile?['id'], 'newer-user');
  });
  test(
      'cancelled invitation cannot reactivate recovery after signout or override newer error state',
      () async {
    final service = FakeAuth();
    final user = service.user;
    final auth = controller(service);
    addTearDown(auth.dispose);
    final epoch = auth.beginInvitationCallback();
    await auth.initialize();
    expect(auth.status, AuthStatus.loading);
    await auth.signOut();
    service.user = user; // a delayed transport completion
    expect(auth.completeInvitationCallback(epoch, user!.id), isFalse);
    auth.reportCallbackFailure(epoch: epoch);
    expect(auth.status, AuthStatus.unauthenticated);
  });
  test('delayed native Google failure cannot overwrite trusted recovery',
      () async {
    final service = FakeAuth();
    final pending = Completer<bool>();
    service.googleResult = pending.future;
    final auth = controller(service);
    addTearDown(auth.dispose);
    final login = auth.signInWithGoogle();
    auth.handleAuthEvent(AuthChangeEvent.passwordRecovery, service.user!.id);
    pending.completeError(const AuthException('cancelled'));
    await login;
    expect(auth.status, AuthStatus.passwordRecovery);
    expect(auth.errorMessage, isNull);
  });
  test('trusted recovery survives initialization and confines navigation',
      () async {
    final service = FakeAuth();
    final auth = controller(service);
    addTearDown(auth.dispose);
    auth.handleAuthEvent(AuthChangeEvent.passwordRecovery, service.user!.id);
    await auth.initialize();
    expect(auth.status, AuthStatus.passwordRecovery);
    expect(
        AppRouter.redirectFor(auth.status, RouteNames.resetPassword, 'admin'),
        isNull);
    expect(
        AppRouter.redirectFor(auth.status, RouteNames.adminDashboard, 'admin'),
        RouteNames.resetPassword);
    expect(
        AppRouter.redirectFor(
            AuthStatus.authenticated, RouteNames.resetPassword, 'admin'),
        RouteNames.adminDashboard);
    expect(
        AppRouter.redirectFor(
            AuthStatus.unauthenticated, RouteNames.resetPassword, null),
        RouteNames.login);
  });
  test(
      'recovery after initialized profile and signedOut event clear permission',
      () async {
    final service = FakeAuth();
    final auth = controller(service);
    addTearDown(auth.dispose);
    await auth.initialize();
    expect(auth.status, AuthStatus.authenticated);
    auth.handleAuthEvent(AuthChangeEvent.passwordRecovery, service.user!.id);
    expect(auth.status, AuthStatus.passwordRecovery);
    auth.handleAuthEvent(AuthChangeEvent.signedOut, null);
    expect(auth.status, AuthStatus.unauthenticated);
    expect(auth.profile, isNull);
    expect((await auth.updateRecoveryPassword('password')).success, isFalse);
  });
  test('signedIn for a different authenticated identity clears recovery',
      () async {
    final service = FakeAuth();
    final auth = controller(service);
    addTearDown(auth.dispose);
    auth.handleAuthEvent(AuthChangeEvent.passwordRecovery, service.user!.id);
    auth.handleAuthEvent(AuthChangeEvent.signedIn, 'different-user');
    expect(auth.status, AuthStatus.unauthenticated);
    expect((await auth.updateRecoveryPassword('password')).success, isFalse);
  });
  test('recovery during profile read wins over delayed initialization',
      () async {
    final service = FakeAuth();
    final pending = Completer<Map<String, dynamic>?>();
    service.read = () => pending.future;
    final auth = controller(service);
    addTearDown(auth.dispose);
    final init = auth.initialize();
    await Future<void>.delayed(Duration.zero);
    auth.handleAuthEvent(AuthChangeEvent.passwordRecovery, service.user!.id);
    pending.complete({'role': 'admin'});
    await init;
    expect(auth.status, AuthStatus.passwordRecovery);
    expect(auth.isLoading, isFalse);
  });
  test('signout invalidates delayed initialization and recovery session',
      () async {
    final service = FakeAuth();
    final pending = Completer<Map<String, dynamic>?>();
    service.read = () => pending.future;
    final auth = controller(service);
    addTearDown(auth.dispose);
    final init = auth.initialize();
    await Future<void>.delayed(Duration.zero);
    await auth.signOut();
    pending.complete({'role': 'admin'});
    await init;
    expect(auth.status, AuthStatus.unauthenticated);
    expect(auth.profile, isNull);
    expect(
        (await auth.updateRecoveryPassword('safe-password')).success, isFalse);
  });
  test('untrusted/mismatched recovery events cannot unlock password update',
      () async {
    final service = FakeAuth();
    final auth = controller(service);
    addTearDown(auth.dispose);
    auth.handleAuthEvent(AuthChangeEvent.passwordRecovery, 'other-user');
    expect(
        (await auth.updateRecoveryPassword('safe-password')).success, isFalse);
    expect(service.updates, 0);
  });
  test('failure permits retry, completion consumes password update permission',
      () async {
    final service = FakeAuth();
    final auth = controller(service);
    addTearDown(auth.dispose);
    auth.handleAuthEvent(AuthChangeEvent.passwordRecovery, service.user!.id);
    service.updateResult = AuthResult.failure('Temporary update failure');
    expect(
        (await auth.updateRecoveryPassword('safe-password')).success, isFalse);
    expect(auth.status, AuthStatus.passwordRecovery);
    expect(auth.errorMessage, contains('Temporary'));
    service.updateResult = const AuthResult(success: true);
    expect(
        (await auth.updateRecoveryPassword('safe-password')).success, isTrue);
    expect(
        (await auth.updateRecoveryPassword('again-password')).success, isFalse);
    await auth.signOut();
    expect(auth.status, AuthStatus.unauthenticated);
  });
  test('recovery expires and a different session invalidates it', () async {
    final service = FakeAuth();
    final auth = controller(service, timeout: const Duration(milliseconds: 5));
    addTearDown(auth.dispose);
    auth.handleAuthEvent(AuthChangeEvent.passwordRecovery, service.user!.id);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(auth.status, AuthStatus.unauthenticated);
    expect((await auth.updateRecoveryPassword('password')).success, isFalse);
  });
  test('profile read failure stays retryable and retry restores real profile',
      () async {
    final service = FakeAuth();
    service.read = () async => throw Exception('offline');
    final auth = controller(service);
    addTearDown(auth.dispose);
    await auth.initialize();
    expect(auth.status, AuthStatus.profileError);
    expect(auth.errorMessage, contains('offline'));
    service.read = null;
    await auth.initialize();
    expect(auth.status, AuthStatus.authenticated);
  });
  for (final error in [
    'Database denied insert',
    'Could not read email.',
    'Temporary network failure'
  ]) {
    test('provisioning failure remains error: $error', () async {
      final service = FakeAuth();
      service.read = () async => null;
      service.result = AuthResult.failure(error);
      final auth = controller(service);
      addTearDown(auth.dispose);
      await auth.initialize();
      expect(auth.status, AuthStatus.profileError);
      expect(auth.errorMessage, error);
    });
  }
  test(
      'missing profile permits registration only after successful lookup; whitelist denial stays denied',
      () async {
    final service = FakeAuth();
    service.read = () async => null;
    final auth = controller(service);
    addTearDown(auth.dispose);
    await auth.initialize();
    expect(auth.status, AuthStatus.registering);
    service.result = AuthResult.failure('not_whitelisted');
    await auth.initialize();
    expect(auth.status, AuthStatus.notWhitelisted);
  });
}
