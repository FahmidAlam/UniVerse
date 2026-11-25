import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universe/features/auth/services/auth_service.dart';
import 'package:universe/core/theme/app_theme.dart';
import 'package:universe/features/auth/controllers/auth_controller.dart';
import 'package:universe/features/auth/screens/onboarding_screen.dart';
import 'package:universe/features/auth/screens/login_screen.dart';
import 'package:universe/features/auth/screens/role_selection_screen.dart';
import 'package:universe/features/auth/screens/student_register_screen.dart';
import 'package:universe/features/auth/screens/faculty_register_screen.dart';
import 'package:universe/features/auth/screens/verify_email_screen.dart';
import 'package:universe/features/auth/widgets/auth_responsive_shell.dart';
import 'package:universe/features/auth/widgets/password_requirements.dart';
import 'package:universe/features/auth/screens/email_signup_screen.dart';
import 'package:universe/features/auth/screens/reset_password_screen.dart';
import 'package:universe/features/auth/widgets/routine_convergence_showcase.dart';
import 'auth_recovery_remediation_test.dart' show FakeAuth;

class RefreshAuth extends Fake implements GoTrueClient {
  Session? session;
  Future<AuthResponse> Function()? refresh;
  int calls = 0;
  @override
  Session? get currentSession => session;
  @override
  User? get currentUser => session?.user;
  @override
  Future<AuthResponse> refreshSession([String? refreshToken]) async {
    calls++;
    return await refresh!();
  }
}

class RefreshClient extends Fake implements SupabaseClient {
  RefreshClient(this.auth);
  @override
  final GoTrueClient auth;
}

class SlowSignOutAuth extends FakeAuth {
  final signedOut = Completer<void>();
  int callbacks = 0;
  @override
  Future<void> signOut() => signedOut.future;
  @override
  Future<AuthResult> handlePostLogin() async {
    callbacks++;
    return super.handlePostLogin();
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<AuthController> mount(
      WidgetTester tester, Size size, Widget Function(AuthController) screen,
      {double scale = 1, double keyboard = 0, FakeAuth? service}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final auth = AuthController(authService: service ?? FakeAuth());
    addTearDown(auth.dispose);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark,
        home: MediaQuery(
            data: MediaQueryData(
                size: size,
                disableAnimations: true,
                textScaler: TextScaler.linear(scale),
                viewInsets: EdgeInsets.only(bottom: keyboard)),
            child: screen(auth))));
    await tester.pumpAndSettle();
    return auth;
  }

  for (final recovery in [false, true]) {
    testWidgets(
        '${recovery ? 'reset' : 'signup'} feedback follows actual password rules',
        (tester) async {
      await mount(
          tester,
          const Size(390, 844),
          (auth) => recovery
              ? ResetPasswordScreen(authController: auth)
              : EmailSignupScreen(authController: auth));
      final fields = find.byType(TextFormField);
      final password = fields.at(recovery ? 0 : 1);
      final confirmation = fields.at(recovery ? 1 : 2);
      await tester.enterText(password, 'aaaaaa');
      await tester.enterText(confirmation, 'aaaaaa');
      await tester.pumpAndSettle();
      final rules = tester
          .widget<PasswordRequirements>(find.byType(PasswordRequirements));
      expect(rules.password.length, 6);
      expect(rules.confirmation, rules.password);
      // A digit requirement would contradict the existing validator.
      expect(find.text('Contains letters and digits'), findsNothing);
      expect(tester.state<FormState>(find.byType(Form)).validate(), recovery);
      await tester.pump();
      expect(find.text('Minimum 6 characters'), findsNothing);
      expect(find.text('Passwords do not match'), findsNothing);
      await tester.enterText(confirmation, 'different');
      await tester.pumpAndSettle();
      expect(tester.state<FormState>(find.byType(Form)).validate(), isFalse);
      await tester.pumpAndSettle();
      expect(find.text('Passwords do not match'), findsOneWidget);
      expect(tester.binding.transientCallbackCount, 0);
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final size in [
    const Size(390, 844),
    const Size(900, 800),
    const Size(1440, 900)
  ]) {
    for (final skip in [false, true]) {
      testWidgets(
          'onboarding stages and ${skip ? 'Skip' : 'completion'} persist at $size',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final auth = AuthController(authService: FakeAuth());
        final router = GoRouter(initialLocation: '/onboarding', routes: [
          GoRoute(
              path: '/onboarding',
              builder: (_, state) => OnboardingScreen(authController: auth)),
          GoRoute(
              path: '/login',
              builder: (_, state) =>
                  const Scaffold(body: Text('Login destination'))),
        ]);
        await tester.pumpWidget(MaterialApp.router(
            theme: AppTheme.dark,
            routerConfig: router,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: child!)));
        await tester.pumpAndSettle();
        if (!skip) {
          for (var i = 0; i < 3; i++) {
            expect(
                find.text(RoutineConvergenceShowcase.titles[i]), findsWidgets);
            final button = find.text(i == 2 ? 'Get Started' : 'Next');
            await tester.ensureVisible(button);
            await tester.tap(button);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
        } else {
          await tester.tap(find.text('Skip'));
          await tester.pumpAndSettle();
        }
        expect(
            (await SharedPreferences.getInstance()).getBool('onboarding_done'),
            isTrue);
        expect(find.text('Login destination'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        router.dispose();
        auth.dispose();
      });
    }
  }

  testWidgets('ambient motion stops immediately when reduced motion is enabled',
      (tester) async {
    final theme = AppTheme.dark;
    Widget scene(bool reduced) => MaterialApp(
        theme: theme,
        home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduced),
            child: const Scaffold(
                body: SingleChildScrollView(
                    child: RoutineConvergenceShowcase()))));
    await tester.pumpWidget(scene(false));
    await tester.pump(const Duration(seconds: 3));
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    await tester.pumpWidget(scene(true));
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0);
    expect(find.text('UniVerse Orbit Engine'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('showcase interactive stages and reduced motion rest state',
      (tester) async {
    await mount(tester, const Size(900, 800),
        (_) => const Scaffold(body: RoutineConvergenceShowcase()));
    expect(find.text('UniVerse Orbit Engine'), findsOneWidget);
    expect(tester.binding.transientCallbackCount, 0);
    await tester.tap(find.text('02'));
    await tester.pumpAndSettle();
    expect(find.text('CSE-3101 · Room 302'), findsOneWidget);
    await tester.tap(find.text('03'));
    await tester.pumpAndSettle();
    expect(find.text('Semester course resources'), findsOneWidget);
    expect(tester.binding.transientCallbackCount, 0);
  });

  for (final size in [const Size(390, 844), const Size(1440, 900)]) {
    testWidgets('auth screens and input previews at $size', (tester) async {
      await mount(tester, size, (auth) => LoginScreen(authController: auth));
      expect(find.byType(AuthResponsiveShell), findsOneWidget);
      expect(tester.takeException(), isNull);
      await mount(
          tester, size, (auth) => RoleSelectionScreen(authController: auth));
      expect(find.text('01'), findsNothing);
      expect(find.textContaining('role intent'), findsOneWidget);
      expect(
          tester
              .widget<ElevatedButton>(
                  find.widgetWithText(ElevatedButton, 'Continue'))
              .onPressed,
          isNull);
      await tester.tap(find.text('Teacher'));
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<ElevatedButton>(
                  find.widgetWithText(ElevatedButton, 'Continue'))
              .onPressed,
          isNotNull);
      final adminRole = find.text('Admin');
      await tester.ensureVisible(adminRole);
      await tester.tap(adminRole);
      await tester.pumpAndSettle();
      final continueBtn = find.widgetWithText(ElevatedButton, 'Continue');
      await tester.ensureVisible(continueBtn);
      await tester.tap(continueBtn);
      await tester.pumpAndSettle();
      expect(find.text('Admin Access Required'), findsOneWidget);
      await tester.tap(find.text('Understood'));
      await tester.pumpAndSettle();
      expect(find.text('Admin Access Required'), findsNothing);
      expect(find.byType(AuthResponsiveShell), findsOneWidget);
      expect(tester.takeException(), isNull);
      await mount(
          tester, size, (auth) => StudentRegisterScreen(authController: auth));
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(2), '58');
      await tester.enterText(fields.at(3), 'B');
      await tester.pump();
      expect(find.textContaining('Routine Lens Preview · Batch 58 · Section B'),
          findsOneWidget);
      if (size.width >= 920) {
        expect(find.textContaining('LIVE LENS: Batch 58 \u00b7 Section B'),
            findsOneWidget);
        expect(find.byType(AppBar), findsNothing);
      }
      final form = tester.state<FormState>(find.byType(Form));
      expect(form.validate(), isFalse);
      await tester.pump();
      expect(find.text('Name is required'), findsOneWidget);
      expect(find.byType(AuthResponsiveShell), findsOneWidget);
      expect(tester.takeException(), isNull);
      await mount(
          tester, size, (auth) => FacultyRegisterScreen(authController: auth));
      await tester.enterText(find.byType(TextFormField).at(1), 'JR');
      await tester.pump();
      expect(find.textContaining('Teaching Lens Preview · JR'), findsOneWidget);
      expect(tester.state<FormState>(find.byType(Form)).validate(), isFalse);
      await tester.pump();
      expect(find.byType(AuthResponsiveShell), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final scale in [1.0, 1.3]) {
    testWidgets(
        'verification scrolls with keyboard and diagnoses failed refresh at scale $scale',
        (tester) async {
      final refresh = RefreshAuth()
        ..session = Session(
            accessToken: 'synthetic',
            tokenType: 'bearer',
            user: FakeAuth().user!);
      refresh.refresh =
          () async => throw const AuthException('Synthetic refresh failure');
      await mount(
          tester,
          const Size(390, 844),
          (auth) => VerifyEmailScreen(
              authController: auth, supabaseClient: RefreshClient(refresh)),
          scale: scale,
          keyboard: 300);
      expect(find.byType(AuthResponsiveShell), findsOneWidget);
      final check = find.text('Verified some other way? Check status');
      await tester.ensureVisible(check);
      await tester.tap(check);
      await tester.pumpAndSettle();
      expect(find.textContaining('We could not check verification right now'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 5));
      expect(
          find.textContaining('6–8 digit verification code'), findsOneWidget);
      expect(tester.binding.transientCallbackCount, 0);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('missing session guides code entry without attempting refresh',
      (tester) async {
    final refresh = RefreshAuth();
    await mount(
        tester,
        const Size(390, 844),
        (auth) => VerifyEmailScreen(
            authController: auth, supabaseClient: RefreshClient(refresh)));
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(find.textContaining('No active session yet'), findsOneWidget);
    expect(refresh.calls, 0);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'sign-out invalidates pending verification and polling does not overlap',
      (tester) async {
    final service = SlowSignOutAuth();
    final refresh = RefreshAuth()
      ..session = Session(
          accessToken: 'synthetic', tokenType: 'bearer', user: service.user!);
    final response = Completer<AuthResponse>();
    refresh.refresh = () => response.future;
    await mount(
        tester,
        const Size(390, 844),
        (auth) => VerifyEmailScreen(
            authController: auth, supabaseClient: RefreshClient(refresh)),
        service: service);
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 5));
    expect(refresh.calls, 1);
    await tester.tap(find.byType(IconButton).first, warnIfMissed: false);
    response.complete(AuthResponse(session: refresh.session));
    await tester.pump();
    expect(service.callbacks, 0);
    await tester.pumpWidget(const SizedBox());
    service.signedOut.complete();
    await tester.pump();
  });
  testWidgets('onboarding starts with the approved generation narrative',
      (tester) async {
    final auth = AuthController(authService: FakeAuth());
    await tester
        .pumpWidget(MaterialApp(home: OnboardingScreen(authController: auth)));
    expect(find.text('Intelligent Routine Generation'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    auth.dispose();
  });
}
