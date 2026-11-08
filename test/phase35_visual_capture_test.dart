import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:universe/features/auth/screens/splash_screen.dart';
// PHASE 3: Opt-in local rendered widget capture, synthetic auth only.
// flutter test test/phase35_visual_capture_test.dart --update-goldens --dart-define=PHASE35_CAPTURE=true
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universe/core/theme/app_theme.dart';
import 'package:universe/features/auth/controllers/auth_controller.dart';
import 'package:universe/features/auth/screens/onboarding_screen.dart';
import 'package:universe/features/auth/screens/login_screen.dart';
import 'package:universe/features/auth/screens/email_login_screen.dart';
import 'package:universe/features/auth/screens/email_signup_screen.dart';
import 'package:universe/features/auth/screens/role_selection_screen.dart';
import 'package:universe/features/auth/screens/student_register_screen.dart';
import 'package:universe/features/auth/screens/faculty_register_screen.dart';
import 'package:universe/features/auth/screens/verify_email_screen.dart';
import 'package:universe/features/auth/screens/forgot_password_screen.dart';
import 'package:universe/features/auth/screens/reset_password_screen.dart';
import 'package:universe/features/auth/screens/auth_error_screen.dart';
import 'package:universe/features/auth/screens/not_whitelisted_screen.dart';
import 'auth_recovery_remediation_test.dart' show FakeAuth;

class _SplashCaptureAuth extends AuthController {
  _SplashCaptureAuth() : super(authService: FakeAuth());
  @override
  Future<void> initialize() => Completer<void>().future;
}

void main() {
  const enabled = bool.fromEnvironment('PHASE35_CAPTURE');
  testWidgets('render Phase 3.5 inspection gallery with synthetic auth',
      (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final manifestData = await rootBundle.load('AssetManifest.bin');
    final manifest = Map<Object?, Object?>.from(
        const StandardMessageCodec().decodeMessage(manifestData) as Map);
    manifest['assets/Inter-Regular.ttf'] = [
      {'asset': 'assets/Inter-Regular.ttf'}
    ];
    tester.binding.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
      final key = String.fromCharCodes(message!.buffer.asUint8List());
      if (key == 'AssetManifest.bin') {
        return const StandardMessageCodec().encodeMessage(manifest);
      }
      if (key == 'assets/Inter-Regular.ttf') {
        return ByteData.sublistView(
            File('.dart_tool/phase35_inter.ttf').readAsBytesSync());
      }
      return null;
    });
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
        url: 'http://127.0.0.1:54321',
        anonKey: 'local-visual-fixture',
        authOptions: const FlutterAuthClientOptions(
            autoRefreshToken: false, detectSessionInUri: false));
    final loader = FontLoader('CaptureSans')
      ..addFont(Future.value(ByteData.sublistView(
          File('.dart_tool/phase35_inter.ttf').readAsBytesSync())));
    await loader.load();
    for (final family in ['Ahem', 'Roboto', 'Inter']) {
      final font = FontLoader(family)
        ..addFont(Future.value(ByteData.sublistView(
            File('.dart_tool/phase35_inter.ttf').readAsBytesSync())));
      await font.load();
    }
    final iconLoader = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(File(
              'C:/src/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf')
          .readAsBytesSync())));
    await iconLoader.load();
    final auth = AuthController(authService: FakeAuth());
    addTearDown(auth.dispose);
    final splashAuth = _SplashCaptureAuth();
    addTearDown(splashAuth.dispose);
    final scenes = <String, Widget Function()>{
      '00_splash': () => SplashScreen(authController: splashAuth),
      '01_onboarding_stage1': () => OnboardingScreen(authController: auth),
      '02_login': () => LoginScreen(authController: auth),
      '03_email_login': () => EmailLoginScreen(authController: auth),
      '04_email_signup': () => EmailSignupScreen(authController: auth),
      '05_role_selection': () => RoleSelectionScreen(authController: auth),
      '06_student_register': () => StudentRegisterScreen(authController: auth),
      '07_faculty_register': () => FacultyRegisterScreen(authController: auth),
      '08_verify_email': () => VerifyEmailScreen(authController: auth),
      '09_forgot_password': () => ForgotPasswordScreen(authController: auth),
      '10_reset_password': () => ResetPasswordScreen(authController: auth),
      '11_not_whitelisted': () => NotWhitelistedScreen(authController: auth),
      '12_auth_error': () => AuthErrorScreen(authController: auth),
    };
    final baseTheme = AppTheme.dark;
    ButtonStyle? fontStyle(ButtonStyle? style) => style?.copyWith(
        textStyle: WidgetStatePropertyAll(
            (style.textStyle?.resolve({}) ?? const TextStyle())
                .copyWith(fontFamily: 'CaptureSans')));
    final captureTheme = baseTheme.copyWith(
      textTheme: baseTheme.textTheme.apply(fontFamily: 'CaptureSans'),
      primaryTextTheme:
          baseTheme.primaryTextTheme.apply(fontFamily: 'CaptureSans'),
      elevatedButtonTheme: ElevatedButtonThemeData(
          style: fontStyle(baseTheme.elevatedButtonTheme.style)),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: fontStyle(baseTheme.outlinedButtonTheme.style)),
      textButtonTheme: TextButtonThemeData(
          style: fontStyle(baseTheme.textButtonTheme.style)),
      filledButtonTheme: FilledButtonThemeData(
          style: fontStyle(baseTheme.filledButtonTheme.style)),
    );
    final capture = GlobalKey();
    for (final size in [
      const Size(1440, 900),
      const Size(900, 800),
      const Size(920, 800),
      const Size(390, 844)
    ]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      final suffix = size.width == 1440
          ? 'desktop_1440'
          : size.width >= 900
              ? 'medium_${size.width.toInt()}'
              : 'mobile_390';
      for (final scene in scenes.entries) {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(MaterialApp(
            theme: captureTheme,
            builder: (context, child) => MediaQuery(
                data: MediaQueryData(size: size, disableAnimations: true),
                child: RepaintBoundary(
                    key: capture,
                    child: child ?? const SizedBox())),
            home: scene.value()));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '${scene.key} $suffix');
        Future<void> shot(String name) async => expectLater(
            find.byKey(capture),
            matchesGoldenFile(
                '../docs/screenshots/phase_3/${name}_$suffix.png'));
        await shot(scene.key);
        if (scene.key == '01_onboarding_stage1') {
          for (var stage = 2; stage <= 3; stage++) {
            final next = find.text('Next');
            await tester.ensureVisible(next);
            await tester.tap(next);
            await tester.pumpAndSettle();
            await shot('01_onboarding_stage$stage');
          }
        }
        if (scene.key == '05_role_selection') {
          final adminRole = find.text('Admin');
          await tester.ensureVisible(adminRole);
          await tester.tap(adminRole);
          await tester.pumpAndSettle();
          final continueBtn = find.widgetWithText(ElevatedButton, 'Continue');
          await tester.ensureVisible(continueBtn);
          await tester.tap(continueBtn);
          await tester.pumpAndSettle();
          await shot('05_role_selection_modal');
        }
        if (scene.key == '06_student_register') {
          await tester.enterText(find.byType(TextFormField).at(2), '58');
          await tester.enterText(find.byType(TextFormField).at(3), 'B');
          await tester.pumpAndSettle();
          await shot('06_student_register_lens_preview');
        }
        if (scene.key == '07_faculty_register') {
          await tester.enterText(find.byType(TextFormField).at(1), 'JR');
          await tester.pumpAndSettle();
          await shot('07_faculty_register_lens_preview');
        }
      }
    }
    await tester.pumpWidget(const SizedBox());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    await Supabase.instance.dispose();
  }, skip: !enabled);
}
