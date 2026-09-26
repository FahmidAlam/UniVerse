import 'dart:async' show Completer;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthException, PostgrestException;
import 'package:universe/core/router/app_router.dart';
import 'package:universe/core/router/route_names.dart';
import 'package:universe/features/auth/controllers/auth_controller.dart';
import 'package:universe/features/auth/screens/student_register_screen.dart';
import 'package:universe/features/auth/services/auth_service.dart';

/// "Continue with Google" created the Supabase user and then did nothing.
///
/// Native Google Sign-In finishes the session *inside*
/// `AuthService.signInWithGoogle`, while the controller is still loading, and
/// the `signedIn` listener in `main.dart` ignores events that arrive while
/// loading. So no one looked the profile up. Even when something did, a new
/// user was left on /login, and the register screens recursed forever.
void main() {
  group('AuthController.signInWithGoogle', () {
    test('resolves the profile itself once the session exists', () async {
      final service = _FakeAuthService(
        postLogin: const AuthResult(
          success: true,
          role: 'student',
          profile: {'role': 'student'},
        ),
      );
      final controller = AuthController(authService: service);

      await controller.signInWithGoogle();

      expect(service.postLoginCalls, 1);
      expect(controller.status, AuthStatus.authenticated);
      expect(controller.role, 'student');
      expect(controller.isLoading, isFalse);
    });

    test('a new Google account with no profile goes to registration',
        () async {
      final controller = AuthController(authService: _FakeAuthService());

      await controller.signInWithGoogle();

      expect(controller.status, AuthStatus.registering);
      expect(controller.isLoading, isFalse);
    });

    test('dismissing the account chooser is not an error', () async {
      final service = _FakeAuthService(signIn: () async => false);
      final controller = AuthController(authService: service);

      await controller.signInWithGoogle();

      expect(service.postLoginCalls, 0);
      expect(controller.errorMessage, isNull);
      expect(controller.isLoading, isFalse);
    });

    test('a failed sign-in is reported and stops loading', () async {
      final controller = AuthController(
        authService: _FakeAuthService(
          signIn: () async =>
              throw const AuthException('Unacceptable audience in id_token'),
        ),
      );

      await controller.signInWithGoogle();

      expect(controller.status, AuthStatus.error);
      expect(controller.errorMessage, contains('Unacceptable audience'));
      expect(controller.isLoading, isFalse);
    });
  });

  group('AuthController.signOut', () {
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
    });

    test('isSigningOut covers the whole sign-out, then clears', () async {
      final gate = Completer<void>();
      final controller = AuthController(
        authService: _FakeAuthService(signOut: () => gate.future),
      );

      final done = controller.signOut();
      expect(controller.isSigningOut, isTrue);

      gate.complete();
      await done;
      expect(controller.isSigningOut, isFalse);
      expect(controller.status, AuthStatus.unauthenticated);
    });

    test('a failed sign-out does not leave the overlay up', () async {
      final controller = AuthController(
        authService: _FakeAuthService(
          signOut: () async => throw Exception('offline'),
        ),
      );

      await expectLater(controller.signOut(), throwsException);
      expect(controller.isSigningOut, isFalse);
      expect(controller.isLoading, isFalse);
    });
  });

  /// Anyone could register as a teacher. Migration 016's trigger now refuses
  /// a teacher role without a whitelist entry, with hint `not_whitelisted`.
  group('teacher whitelist gate', () {
    test('the database refusal is recognised by its hint', () {
      expect(
        AuthService.isNotWhitelistedError(PostgrestException(
          message: 'The teacher role needs to be added by the department '
              'admin.',
          code: '42501',
          hint: 'not_whitelisted',
        )),
        isTrue,
      );
      expect(
        AuthService.isNotWhitelistedError(PostgrestException(
          message: 'new row violates row-level security policy',
          code: '42501',
        )),
        isFalse,
      );
    });

    test('a refused teacher registration shows the not-whitelisted screen',
        () async {
      final controller = AuthController(
        authService: _FakeAuthService(
          faculty: AuthResult.failure('not_whitelisted'),
        ),
      );

      final ok = await controller.completeFacultyRegistration(
        name: 'Test Teacher',
        teacherCode: 'TT',
        department: 'CSE',
        designation: 'Lecturer',
      );

      expect(ok, isFalse);
      expect(controller.status, AuthStatus.notWhitelisted);
      expect(controller.errorMessage, isNull);
      expect(controller.isLoading, isFalse);
    });

    test('a refused email sign-up is not overwritten by the profile lookup',
        () async {
      final service = _FakeAuthService(
        faculty: AuthResult.failure('not_whitelisted'),
      );
      final controller = AuthController(authService: service)
        ..storePendingFacultyData(
          name: 'Test Teacher',
          teacherCode: 'TT',
          department: 'CSE',
          designation: 'Lecturer',
        );

      await controller.handleOAuthCallback();

      expect(controller.status, AuthStatus.notWhitelisted);
      expect(service.postLoginCalls, 0);
    });
  });

  group('AppRouter.redirectFor', () {
    test('a signed-in user with no profile is sent on to registration', () {
      for (final page in [
        RouteNames.splash,
        RouteNames.onboarding,
        RouteNames.login,
        RouteNames.emailLogin,
      ]) {
        expect(
          AppRouter.redirectFor(AuthStatus.registering, page, null),
          RouteNames.roleSelection,
          reason: page,
        );
      }
    });

    test('a signed-in user with no profile can finish registering', () {
      for (final page in [
        RouteNames.roleSelection,
        RouteNames.studentRegister,
        RouteNames.facultyRegister,
      ]) {
        expect(
          AppRouter.redirectFor(AuthStatus.registering, page, null),
          isNull,
          reason: page,
        );
      }
    });

    test('a signed-out user still reaches login and account creation', () {
      expect(
        AppRouter.redirectFor(AuthStatus.unauthenticated, RouteNames.login, null),
        isNull,
      );
      expect(
        AppRouter.redirectFor(
            AuthStatus.unauthenticated, RouteNames.roleSelection, null),
        isNull,
      );
    });

    test('a user with a profile lands on their own dashboard', () {
      expect(
        AppRouter.redirectFor(
            AuthStatus.authenticated, RouteNames.login, 'teacher'),
        RouteNames.teacherDashboard,
      );
    });

    test('a refused teacher is held on the not-whitelisted screen', () {
      expect(
        AppRouter.redirectFor(
            AuthStatus.notWhitelisted, RouteNames.facultyRegister, null),
        RouteNames.notWhitelisted,
      );
    });
  });

  group('StudentRegisterScreen', () {
    Future<_FakeAuthController> pumpFilledForm(
      WidgetTester tester, {
      required bool signedIn,
    }) async {
      // The test font's glyphs are far wider than Inter's; give buttons room.
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final auth = _FakeAuthController(signedIn: signedIn);
      await tester.pumpWidget(
        MaterialApp(home: StudentRegisterScreen(authController: auth)),
      );
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Test Student');
      await tester.enterText(fields.at(1), '0182320012101999');
      await tester.enterText(fields.at(2), '62');
      await tester.enterText(fields.at(3), 'G');
      return auth;
    }

    testWidgets('a signed-in user finishes without a second Google sign-in',
        (tester) async {
      final auth = await pumpFilledForm(tester, signedIn: true);

      expect(find.text('Register with Google'), findsNothing);
      await tester.tap(find.text('Finish registration'));
      await tester.pump();

      expect(auth.completions, 1);
      expect(auth.googleSignIns, 0);
    });

    testWidgets('Google sign-in from this screen completes exactly once',
        (tester) async {
      final auth = await pumpFilledForm(tester, signedIn: false);

      await tester.tap(find.text('Register with Google'));
      await tester.pump();

      expect(auth.googleSignIns, 1);
      expect(auth.completions, 1);
    });

    testWidgets('an unrelated controller update does not create a profile',
        (tester) async {
      final auth = await pumpFilledForm(tester, signedIn: true);

      auth.emit(AuthStatus.registering);
      await tester.pump();

      expect(auth.completions, 0);
    });
  });
}

class _FakeAuthService implements AuthService {
  _FakeAuthService({
    Future<bool> Function()? signIn,
    Future<void> Function()? signOut,
    this.postLogin = const AuthResult(success: true),
    this.faculty = const AuthResult(success: true),
  })  : _signIn = signIn ?? (() async => true),
        _signOut = signOut ?? (() async {});

  final Future<bool> Function() _signIn;
  final Future<void> Function() _signOut;

  @override
  Future<void> signOut() => _signOut();
  final AuthResult postLogin;
  final AuthResult faculty;
  int postLoginCalls = 0;

  @override
  Future<bool> signInWithGoogle() => _signIn();

  @override
  Future<AuthResult> handlePostLogin() async {
    postLoginCalls++;
    return postLogin;
  }

  @override
  Future<AuthResult> completeFacultyRegistration({
    required String name,
    required String teacherCode,
    required String department,
    required String designation,
  }) async =>
      faculty;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAuthController extends ChangeNotifier implements AuthController {
  _FakeAuthController({required bool signedIn})
      : _signedIn = signedIn,
        _status =
            signedIn ? AuthStatus.registering : AuthStatus.unauthenticated;

  bool _signedIn;
  AuthStatus _status;
  int completions = 0;
  int googleSignIns = 0;

  @override
  AuthStatus get status => _status;

  @override
  bool get isLoading => false;

  @override
  bool get hasSession => _signedIn;

  @override
  String? get errorMessage => null;

  void emit(AuthStatus status) {
    _status = status;
    notifyListeners();
  }

  @override
  Future<void> signInWithGoogle() async {
    googleSignIns++;
    // Where the real controller ends for a new account: a session, no
    // profile, and a notification.
    _signedIn = true;
    _status = AuthStatus.registering;
    notifyListeners();
  }

  @override
  Future<bool> completeStudentRegistration({
    required String name,
    required String studentId,
    required String batch,
    required String section,
  }) async {
    completions++;
    // Bail out instead of overflowing the stack if the guard ever regresses.
    if (completions > 5) return false;
    // The real controller notifies (via _setLoading) before its first await.
    notifyListeners();
    await Future<void>.value();
    _status = AuthStatus.authenticated;
    notifyListeners();
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
