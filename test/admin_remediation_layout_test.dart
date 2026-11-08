import 'package:go_router/go_router.dart';
import 'package:universe/core/constants/app_constants.dart';
import 'package:universe/core/router/app_shell.dart';
import 'package:universe/core/router/route_names.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/features/admin/widgets/admin_desktop_shell.dart';
import 'package:universe/features/auth/controllers/auth_controller.dart';
import 'package:universe/features/notifications/controllers/notification_controller.dart';
import 'package:flutter/material.dart';
import 'package:universe/features/admin/widgets/admin_card_grid.dart';
import 'package:universe/shared/widgets/stat_card.dart';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:universe/features/admin/services/engine_connectivity_service.dart';

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
  testWidgets('query navigation selects only the exact live routine subitem',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final auth = _MockAuthController();
    final notifications = _MockNotificationController();
    final router = GoRouter(
        initialLocation: '${RouteNames.routineManagement}?tab=generate',
        routes: [
          ShellRoute(
              builder: (context, state, child) => AppShell(
                  authController: auth,
                  notificationController: notifications,
                  child: child),
              routes: [
                GoRoute(
                    path: RouteNames.routineManagement,
                    builder: (_, state) =>
                        Text('tab:${state.uri.queryParameters['tab']}')),
              ])
        ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    void expectSelected(String text) {
      final material = tester.widget<Material>(find
          .ancestor(of: find.text(text), matching: find.byType(Material))
          .first);
      expect(material.color, AppColors.primarySoft);
    }

    expectSelected('\u2022 Generate Timetable');
    // PHASE 1: The Manage link must not remain selected on Generate or Upload.
    expect(
        tester
            .widget<Semantics>(
                find.byKey(const ValueKey('admin-nav:/admin/routine')))
            .properties
            .selected,
        isFalse);
    await tester.tap(find.text('\u2022 Upload Routine'));
    await tester.pumpAndSettle();
    expectSelected('\u2022 Upload Routine');
    // PHASE 1: The Manage link must not remain selected on Generate or Upload.
    expect(
        tester
            .widget<Semantics>(
                find.byKey(const ValueKey('admin-nav:/admin/routine')))
            .properties
            .selected,
        isFalse);
    router.go('${RouteNames.routineManagement}?tab=generate');
    await tester.pumpAndSettle();
    expectSelected('\u2022 Generate Timetable');
    expect(tester.takeException(), isNull);
    final shell =
        tester.widget<AdminDesktopShell>(find.byType(AdminDesktopShell));
    expect(shell.currentLocation, contains('tab=generate'));
  });

  for (final width in [360.0, 550.0, 774.0, 1030.0, 1280.0]) {
    testWidgets('stat cards respect available width $width and text scaling',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(MaterialApp(
          home: MediaQuery(
              data: const MediaQueryData(
                  size: Size(1280, 1000), textScaler: TextScaler.linear(1.5)),
              child: Scaffold(
                  body: Align(
                      alignment: Alignment.topLeft,
                      child: SizedBox(
                          width: width,
                          child: AdminCardGrid(
                              children: List.generate(
                                  4,
                                  (_) => const StatCard(
                                      number: '123456',
                                      label: 'Routine Slots',
                                      icon: Icons.calendar_month)))))))));
      expect(tester.takeException(), isNull);
      final grid = tester.widget<GridView>(find.byType(GridView));
      final delegate =
          grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, lessThanOrEqualTo(width < 700 ? 2 : 4));
      expect(delegate.mainAxisExtent, greaterThanOrEqualTo(180));
    });
  }

  for (final width in [800.0, 1000.0, 1280.0]) {
    for (final scale in [1.0, 1.5]) {
      testWidgets('desktop content remains bounded at $width with scale $scale',
          (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        final service = EngineConnectivityService(
            client: MockClient((_) async => http.Response('offline', 503)));
        await tester.pumpWidget(MaterialApp(
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!),
            home: AdminDesktopShell(
                authController: _MockAuthController(),
                notificationController: _MockNotificationController(),
                currentLocation: RouteNames.adminDashboard,
                connectivityService: service,
                child: SingleChildScrollView(
                    child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: AdminCardGrid(
                            children: List.generate(
                                4,
                                (_) => const StatCard(
                                    number: '123456',
                                    label: 'Routine Slots',
                                    icon: Icons.calendar_month))))))));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('engine badge reports pending response and failed retry honestly',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final response = Completer<http.Response>();
    var requests = 0;
    final service = EngineConnectivityService(client: MockClient((_) {
      requests++;
      if (requests == 1) return response.future;
      return Future.value(http.Response('offline', 503));
    }));
    await tester.pumpWidget(MaterialApp(
        home: AdminDesktopShell(
            authController: _MockAuthController(),
            notificationController: _MockNotificationController(),
            currentLocation: RouteNames.adminDashboard,
            connectivityService: service,
            child: const Text('content'))));
    expect(find.text('Checking engine...'), findsOneWidget);
    expect(find.text('Engine Connected'), findsNothing);
    response.complete(http.Response(
        '{"ok":true,"service":"universe-timetable-engine"}', 200));
    await tester.pumpAndSettle();
    expect(find.text('Engine Connected'), findsOneWidget);
    await tester.tap(find.text('Engine Connected'));
    await tester.pumpAndSettle();
    expect(find.text('Engine Unavailable'), findsOneWidget);
    expect(requests, 2);
  });

  test('health requires the engine identity and ok response', () async {
    final service = EngineConnectivityService(
        client: MockClient((request) async {
          expect(request.url.toString(), 'http://localhost:8000/');
          return http.Response(
              '{"ok":true,"service":"universe-timetable-engine"}', 200);
        }),
        baseUrl: 'http://localhost:8000');
    expect(await service.check(), EngineConnectivity.connected);
  });
  test('unreachable engine is unavailable', () async {
    final service = EngineConnectivityService(
        client: MockClient((_) async => throw http.ClientException('offline')));
    expect(await service.check(), EngineConnectivity.unavailable);
  });
  test('malformed health is unknown', () async {
    final service = EngineConnectivityService(
        client: MockClient((_) async => http.Response('not json', 200)));
    expect(await service.check(), EngineConnectivity.unknown);
  });
  test('bounded check ends even when transport never completes', () async {
    final service = EngineConnectivityService(
        client: MockClient((_) => Completer<http.Response>().future),
        timeout: const Duration(milliseconds: 5));
    expect(await service.check(), EngineConnectivity.unavailable);
  });
}
