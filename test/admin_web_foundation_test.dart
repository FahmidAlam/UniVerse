import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;
import 'package:universe/core/constants/app_constants.dart';
import 'package:universe/core/models/routine_model.dart';
import 'package:universe/features/admin/services/timetable_engine_service.dart';
import 'package:universe/core/platform/file_downloader_io.dart';
import 'package:universe/core/router/app_shell.dart';
import 'package:universe/core/router/route_names.dart';
import 'package:universe/features/admin/screens/timetable_grid_screen.dart';
import 'package:universe/features/admin/widgets/admin_desktop_shell.dart';
import 'package:universe/features/auth/controllers/auth_controller.dart';
import 'package:universe/features/auth/services/auth_service.dart';
import 'package:universe/features/notifications/controllers/notification_controller.dart';
import 'package:universe/shared/widgets/app_bottom_nav.dart';

class _MockAuthController extends ChangeNotifier implements AuthController {
  @override
  AuthStatus status = AuthStatus.authenticated;

  @override
  String? role = AppConstants.roleAdmin;

  @override
  Map<String, dynamic>? profile = {
    'id': 'test-admin-id',
    'name': 'Test Admin',
    'email': 'admin@test.universe',
    'role': AppConstants.roleAdmin,
  };

  @override
  bool isLoading = false;

  @override
  bool hasSession = true;

  @override
  bool isAuthenticated = true;

  @override
  bool isSigningOut = false;

  @override
  String? errorMessage;

  @override
  String? pendingEmail;

  @override
  Map<String, dynamic>? pendingStudentData;

  @override
  Map<String, dynamic>? pendingFacultyData;

  @override
  Future<void> signOut() async {
    status = AuthStatus.unauthenticated;
    role = null;
    profile = null;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockNotificationController extends ChangeNotifier
    implements NotificationController {
  @override
  int unreadCount = 0;

  @override
  Future<void> load() async {}

  @override
  void startRealtime() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('engine report preserves immutable distribution source provenance', () {
    final hash = List.filled(64, 'a').join();
    final report = TimetableReport.fromMap({
      'source_contract': {
        'source_sha256': hash,
        'revision': 0,
        'invalidated_artifacts': <String>[],
      },
    });

    expect(report.sourceContract['source_sha256'], hash);
    expect(report.sourceContract['revision'], 0);
  });

  test('persisted distribution bundle separates source bytes from provenance',
      () {
    final bundle = PersistedDistributionRevision.fromMap({
      'source_id': '10000000-0000-4000-8000-000000000001',
      'revision_id': '20000000-0000-4000-8000-000000000001',
      'revision_number': 1,
      'revision_version': 2,
      'status': 'accepted',
      'source_sha256': List.filled(64, 'b').join(),
      'source_bytes_base64': base64Encode([1, 2, 3]),
      'corrections': const <Map<String, dynamic>>[],
    });

    expect(bundle.sourceBytes, Uint8List.fromList([1, 2, 3]));
    expect(bundle.sourceContract['revision_id'],
        '20000000-0000-4000-8000-000000000001');
    expect(bundle.sourceContract.containsKey('source_bytes_base64'), isFalse);
  });

  group('PlatformFileDownloader IO implementation', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('universe_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    test('downloadBytes writes bytes to directory', () async {
      final downloader = PlatformFileDownloader(
        temporaryDirectory: () async => tempDir,
        documentsDirectory: () async => tempDir,
        openFile: (_) async {},
      );
      final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final path = await downloader.downloadBytes(
        bytes: bytes,
        filename: 'test_file.xlsx',
        openAfterDownload: false,
      );

      expect(path, isNotNull);
      final file = File(path!);
      expect(await file.exists(), isTrue);
      expect(await file.readAsBytes(), bytes);
    });

    test('downloadString writes content to directory', () async {
      final downloader = PlatformFileDownloader(
        temporaryDirectory: () async => tempDir,
        documentsDirectory: () async => tempDir,
        openFile: (_) async {},
      );
      const content = '{"test": true}';
      final path = await downloader.downloadString(
        content: content,
        filename: 'test_draft.json',
      );

      expect(path, isNotNull);
      final file = File(path!);
      expect(await file.exists(), isTrue);
      expect(await file.readAsString(), content);
    });
  });

  group('AppShell responsive admin workbench', () {
    late _MockAuthController authController;
    late _MockNotificationController notifController;

    setUp(() {
      authController = _MockAuthController();
      notifController = _MockNotificationController();
    });

    Widget createRouterApp(Widget child,
        {String location = RouteNames.adminDashboard}) {
      final router = GoRouter(
        initialLocation: location,
        routes: [
          ShellRoute(
            builder: (context, state, child) => AppShell(
              authController: authController,
              notificationController: notifController,
              child: child,
            ),
            routes: [
              GoRoute(
                path: RouteNames.adminDashboard,
                builder: (context, state) => child,
              ),
              GoRoute(
                path: RouteNames.studentDashboard,
                builder: (context, state) => child,
              ),
            ],
          ),
        ],
      );

      return MaterialApp.router(routerConfig: router);
    }

    testWidgets(
      'renders AdminDesktopShell on desktop breakpoint (width >= 800) for admin',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          createRouterApp(const Text('Admin Dashboard Body')),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AdminDesktopShell), findsOneWidget);
        expect(find.text('ADMIN PORTAL'), findsOneWidget);
        expect(find.text('TIMETABLE ENGINE'), findsOneWidget);
        // PHASE 1: Live routine tools and preview workbench have distinct labels.
        expect(find.text('Manage Routine (Live)'), findsOneWidget);
        expect(find.text('Engine Connected'), findsNothing);
        expect(find.text('Engine Unavailable'), findsOneWidget);
        expect(find.text('Admin Dashboard Body'), findsOneWidget);
        expect(find.byType(AppBottomNav), findsNothing);
      },
    );

    testWidgets(
      'renders mobile AppBottomNav on narrow breakpoint (width < 800) for admin',
      (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          createRouterApp(const Text('Admin Mobile Body')),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AdminDesktopShell), findsNothing);
        expect(find.byType(AppBottomNav), findsOneWidget);
        expect(find.text('Admin Mobile Body'), findsOneWidget);
      },
    );

    testWidgets(
      'renders student desktop sidebar instead of mobile navigation',
      (tester) async {
        authController.role = AppConstants.roleStudent;
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          createRouterApp(
            const Text('Student Home Body'),
            location: RouteNames.studentDashboard,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AdminDesktopShell), findsNothing);
        // PHASE 1: Student desktop keeps its own persistent sidebar.
        expect(find.byType(AppBottomNav), findsNothing);
        expect(
            find.byKey(const ValueKey('role-desktop-sidebar')), findsOneWidget);
        expect(find.text('Student Home Body'), findsOneWidget);
      },
    );
  });

  group('TimetableGridScreen desktop inspection', () {
    testWidgets('shows helpful empty state with action when refreshed/empty',
        (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: TimetableGridScreen(rows: []),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No Timetable Preview Available'), findsOneWidget);
      expect(find.text('Open Routine Generator'), findsOneWidget);
    });

    testWidgets('renders grid cells with comfortable desktop spacing',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const row = RoutineEntry(
        id: '1',
        day: 'Sunday',
        timeStart: '09:00',
        timeEnd: '10:30',
        subject: 'Algorithms',
        subjectCode: 'CSE-1101',
        room: 'Lab-1',
        batch: '60',
        section: 'A',
        semester: 1,
        teacherCode: 'FA',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: TimetableGridScreen(rows: [row]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Batch·Sec'), findsOneWidget);
      expect(find.text('60-A'), findsOneWidget);
      expect(find.text('CSE-1101'), findsOneWidget);
      expect(find.text('FA'), findsOneWidget);
      expect(find.text('Lab-1'), findsOneWidget);
    });
  });

  group('Auth web and post-login provisioning safeguards', () {
    test('whitelist provisioning automatically assigns authenticated admin',
        () async {
      final fakeAuthService = _FakeWhitelistAuthService(
        user: User(
          id: 'whitelisted-admin-uid',
          appMetadata: const {'provider': 'email'},
          userMetadata: const {},
          aud: 'authenticated',
          createdAt: '2026-11-04T00:00:00Z',
          email: 'admin@sec.ac.bd',
          emailConfirmedAt: '2026-11-04T00:00:00Z',
        ),
        postLoginResult: const AuthResult(
          success: true,
          role: AppConstants.roleAdmin,
          profile: {
            'id': 'whitelisted-admin-uid',
            'email': 'admin@sec.ac.bd',
            'role': AppConstants.roleAdmin,
            'name': 'Committee Chair',
          },
        ),
      );

      final controller = AuthController(authService: fakeAuthService);
      await controller.initialize();

      expect(controller.status, AuthStatus.authenticated);
      expect(controller.role, AppConstants.roleAdmin);
      expect(controller.profile?['name'], 'Committee Chair');
    });
  });
}

class _FakeWhitelistAuthService implements AuthService {
  final User? _user;
  final AuthResult _postLoginResult;

  _FakeWhitelistAuthService({
    required User? user,
    required AuthResult postLoginResult,
  })  : _user = user,
        _postLoginResult = postLoginResult;

  @override
  bool get isLoggedIn => _user != null;

  @override
  User? get currentUser => _user;

  @override
  Future<Map<String, dynamic>?> fetchProfile(String userId) async {
    return null;
  }

  @override
  Future<AuthResult> handlePostLogin() async {
    return _postLoginResult;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
