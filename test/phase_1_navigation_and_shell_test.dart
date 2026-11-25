// PHASE 1: Verify role navigation with isolated controllers and no hosted services.
import 'dart:async';
import 'package:universe/core/models/routine_model.dart';
import 'package:universe/shared/widgets/weekly_schedule_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:universe/core/router/app_shell.dart';
import 'package:universe/core/router/app_router.dart';
import 'package:universe/core/theme/app_theme.dart';
import 'package:universe/features/rooms/controllers/rooms_controller.dart';
import 'package:universe/features/rooms/screens/room_detail_screen.dart';
import 'package:universe/features/rooms/screens/rooms_screen.dart';
import 'package:universe/features/find_teacher/controllers/find_teacher_controller.dart';
import 'package:universe/features/find_teacher/screens/find_teacher_screen.dart';
import 'package:universe/features/find_teacher/screens/teacher_detail_screen.dart';
import 'package:universe/features/admin/widgets/admin_desktop_shell.dart';
import 'package:universe/shared/widgets/shell_back_scope.dart';
import 'package:universe/core/router/route_names.dart';
import 'package:universe/features/auth/controllers/auth_controller.dart';
import 'package:universe/features/notifications/controllers/notification_controller.dart';
import 'package:universe/shared/widgets/app_bottom_nav.dart';
import 'package:universe/shared/widgets/explore_fab_menu.dart';
import 'package:universe/shared/widgets/u_app_bar.dart';

class TestAuth extends ChangeNotifier implements AuthController {
  TestAuth(this.role);
  @override
  final String role;
  @override
  Map<String, dynamic>? get profile => null;
  @override
  Future<void> signOut() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestNotifications extends ChangeNotifier
    implements NotificationController {
  @override
  int get unreadCount => 3;
  @override
  Future<void> load() async {}
  @override
  void startRealtime() {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeRoomsController extends ChangeNotifier implements RoomsController {
  @override
  bool get disposed => false;
  @override
  bool get isLoading => false;
  @override
  String? get error => null;
  @override
  List<RoomStatus> get roomStatuses => [
        RoomStatus(
          room: '302',
          isOccupied: true,
          currentTeacher: 'Dr. Rahman',
          currentSubject: 'Operating Systems',
          currentClass: '58 - A',
          remainingTime: '28 min',
          timeStart: '09:00',
          timeEnd: '10:30',
        ),
        RoomStatus(
          room: '401',
          isOccupied: false,
          nextTeacher: 'Prof. Karim',
          nextSubject: 'Algorithms',
          nextTime: '11:00',
        ),
        RoomStatus(
          room: 'Lab-2',
          isOccupied: false,
        ),
      ];
  @override
  Future<void> refresh() async {}
  @override
  Future<void> fetchRoomStatuses() async {}
  @override
  void subscribeToRealTimeUpdates() {}
}

class FakeFindTeacherController extends ChangeNotifier
    implements FindTeacherController {
  @override
  bool get disposed => false;
  String _query = '';
  final List<TeacherInfo> _all = [
    TeacherInfo(
      code: 'JR',
      name: 'Dr. Jamilur Rahman',
      status: 'In Class',
      currentRoom: '302',
      currentSubject: 'Compiler Design',
      currentClass: '58 - B',
      remainingTime: '24 min',
    ),
    TeacherInfo(
      code: 'MK',
      name: 'Prof. Mahbub Karim',
      status: 'Free',
      nextRoom: '404',
      nextSubject: 'Computer Networks',
      nextTime: '11:30',
    ),
    TeacherInfo(
      code: 'SA',
      name: 'Dr. Sadia Akter',
      status: 'No Class Today',
    ),
  ];

  @override
  bool get isLoading => false;
  @override
  String? get error => null;
  @override
  String get searchQuery => _query;
  @override
  List<TeacherInfo> get filteredTeachers => _query.isEmpty
      ? _all
      : _all
          .where((t) =>
              t.name.toLowerCase().contains(_query) ||
              t.code.toLowerCase().contains(_query))
          .toList();
  @override
  void search(String query) {
    _query = query.toLowerCase();
    notifyListeners();
  }

  @override
  Future<void> initialize() async {}
  @override
  Future<void> refresh() async {}
  @override
  void subscribeToRealTimeUpdates() {}
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  // PHASE 1: URL encoding and active-state rules are independent of backend data.
  test('Campus descendants and secondary admin tools select the correct tab',
      () {
    for (final role in ['student', 'teacher']) {
      final campus = AppBottomNav.destinationsFor(role)
          .indexWhere((d) => d.label == 'Campus');
      for (final route in [
        '/rooms',
        '/rooms/detail?room=302',
        '/find-teacher',
        '/find-teacher/detail?code=TEST'
      ]) {
        expect(AppBottomNav.selectedIndexFor(role, route), campus);
      }
    }
    expect(AppBottomNav.selectedIndexFor('admin', '/admin/users'), 4);
    expect(AppBottomNav.selectedIndexFor('admin', '/find-teacher'), 4);
    final room = Uri.parse(RouteNames.roomDetailLocation('Lab A&B/302'));
    expect(room.queryParameters['room'], 'Lab A&B/302');
    final teacher = TeacherDetailArgs.resolve(
        null,
        Uri.parse(RouteNames.teacherDetailLocation(
            code: 'A&B',
            name: 'Test Faculty',
            dept: 'CSE',
            desig: 'Lecturer')));
    expect(teacher.code, 'A&B');
    expect(teacher.name, 'Test Faculty');
    expect(teacher.dept, 'CSE');
    expect(teacher.desig, 'Lecturer');
    expect(
        TeacherDetailArgs.resolve(
                'wrong type', Uri.parse('/find-teacher/detail?code=TEST'))
            .name,
        'TEST');
  });

  for (final location in [
    '/rooms/detail?room=302',
    '/find-teacher/detail?code=TEST&name=Test',
    '/rooms/detail',
    '/find-teacher/detail?code=%20'
  ]) {
    testWidgets('URL-only detail resolves $location without extra',
        (tester) async {
      final router = GoRouter(initialLocation: location, routes: [
        ...AppRouter.campusRoutes()
            .where((route) => route.path.endsWith('/detail')),
        GoRoute(
            path: RouteNames.rooms,
            builder: (c, s) => const Scaffold(body: Text('Rooms directory'))),
        GoRoute(
            path: RouteNames.findTeacher,
            builder: (c, s) => const Scaffold(body: Text('Faculty directory'))),
      ]);
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      if (location.startsWith('/rooms')) {
        expect(
            tester.widget<RoomDetailScreen>(find.byType(RoomDetailScreen)).room,
            location.contains('302') ? '302' : '');
      } else {
        final screen = tester
            .widget<TeacherDetailScreen>(find.byType(TeacherDetailScreen));
        expect(screen.teacherCode, location.contains('TEST') ? 'TEST' : '');
        if (location.contains('TEST')) expect(screen.teacherName, 'Test');
      }
      if (!location.contains('302') && !location.contains('TEST')) {
        expect(find.textContaining('selected'), findsOneWidget);
        expect(find.textContaining('Back to'), findsOneWidget);
        await tester.tap(find.textContaining('Back to'));
        await tester.pumpAndSettle();
        expect(
            find.text(location.startsWith('/rooms')
                ? 'Rooms directory'
                : 'Faculty directory'),
            findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final tab in [null, 'manage', 'generate', 'upload', 'invalid']) {
    testWidgets('admin sidebar selects exact routine tab $tab', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final location = '/admin/routine${tab == null ? '' : '?tab=$tab'}';
      final auth = TestAuth('admin');
      final notifications = TestNotifications();
      addTearDown(auth.dispose);
      addTearDown(notifications.dispose);
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.dark,
          home: AdminDesktopShell(
              authController: auth,
              notificationController: notifications,
              currentLocation: location,
              child: const Scaffold(
                  appBar: UAppBar(title: 'Routine'),
                  body: Text('Routine body')))));
      await tester.pumpAndSettle();
      final expected = tab == 'generate' || tab == 'upload' ? tab : 'manage';
      for (final candidate in ['manage', 'generate', 'upload']) {
        final route = candidate == 'manage'
            ? '/admin/routine'
            : '/admin/routine?tab=$candidate';
        expect(
            tester
                .widget<Semantics>(find.byKey(ValueKey('admin-nav:$route')))
                .properties
                .selected,
            candidate == expected);
      }
      expect(find.text('Scheduling Workbench · Preview'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  // PHASE 1: Query-only navigation reloads data and ignores obsolete in-flight reads.
  for (final faculty in [false, true]) {
    testWidgets(
        '${faculty ? 'faculty' : 'room'} query changes reload retained detail state',
        (tester) async {
      final requests = <Completer<List<RoutineEntry>>>[];
      Future<List<RoutineEntry>> load() {
        final request = Completer<List<RoutineEntry>>();
        requests.add(request);
        return request.future;
      }

      RoutineEntry entry(String identity) => RoutineEntry(
          id: identity,
          day: 'Sunday',
          timeStart: '09:00',
          timeEnd: '10:30',
          subject: 'Subject $identity',
          subjectCode: 'COURSE',
          room: identity,
          batch: '2024',
          section: 'A',
          semester: 1,
          teacherCode: identity);
      final path = faculty ? '/find-teacher/detail' : '/rooms/detail';
      final parameter = faculty ? 'code' : 'room';
      final router = GoRouter(initialLocation: '$path?$parameter=302', routes: [
        GoRoute(
            path: path,
            builder: (context, state) {
              final identity = state.uri.queryParameters[parameter] ?? '';
              return faculty
                  ? TeacherDetailScreen(
                      teacherCode: identity,
                      teacherName: identity,
                      routineLoader: load)
                  : RoomDetailScreen(room: identity, routineLoader: load);
            })
      ]);
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump();
      expect(requests.length, 1);
      requests[0].complete([entry('302')]);
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<WeeklyScheduleView>(find.byType(WeeklyScheduleView))
              .entries
              .single
              .subject,
          'Subject 302');
      final retainedState = tester
          .state(find.byType(faculty ? TeacherDetailView : RoomDetailView));
      router.go('$path?$parameter=303');
      await tester.pump();
      expect(requests.length, 2);
      expect(
          tester
              .state(find.byType(faculty ? TeacherDetailView : RoomDetailView)),
          same(retainedState));
      expect(find.byType(WeeklyScheduleView), findsNothing);
      router.go('$path?$parameter=304');
      await tester.pump();
      expect(requests.length, 3);
      requests[2].complete([entry('304')]);
      await tester.pumpAndSettle();
      requests[1].complete([entry('303')]);
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<WeeklyScheduleView>(find.byType(WeeklyScheduleView))
              .entries
              .single
              .subject,
          'Subject 304');
      router.go(path);
      await tester.pumpAndSettle();
      expect(find.textContaining('selected'), findsOneWidget);
      expect(requests.length, 3);
      router.go('$path?$parameter=305');
      await tester.pump();
      expect(requests.length, 4);
      requests[3].complete([entry('305')]);
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<WeeklyScheduleView>(find.byType(WeeklyScheduleView))
              .entries
              .single
              .subject,
          'Subject 305');
      expect(tester.takeException(), isNull);
    });
  }

  // PHASE 1: Workbench selection stays separate from all live routine tabs.
  testWidgets(
      'admin preview workbench is the sole selected routine destination',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final auth = TestAuth('admin');
    final notifications = TestNotifications();
    addTearDown(auth.dispose);
    addTearDown(notifications.dispose);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark,
        home: AdminDesktopShell(
            authController: auth,
            notificationController: notifications,
            currentLocation: '/admin/scheduling',
            child: const Text('Workbench body'))));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<Semantics>(
                find.byKey(const ValueKey('admin-nav:/admin/scheduling')))
            .properties
            .selected,
        isTrue);
    expect(
        tester
            .widget<Semantics>(
                find.byKey(const ValueKey('admin-nav:/admin/routine')))
            .properties
            .selected,
        isFalse);
    expect(tester.takeException(), isNull);
  });

  test('existing role and recovery guards still protect admin destinations',
      () {
    for (final role in ['student', 'teacher']) {
      for (final path in [
        '/admin/routine',
        '/admin/scheduling',
        '/admin/users'
      ]) {
        expect(AppRouter.redirectFor(AuthStatus.authenticated, path, role),
            role == 'student' ? '/student/dashboard' : '/teacher/dashboard');
      }
    }
    expect(
        AppRouter.redirectFor(AuthStatus.passwordRecovery, '/rooms', 'student'),
        '/reset-password');
    expect(
        AppRouter.redirectFor(
            AuthStatus.unauthenticated, '/rooms/detail', null),
        '/login');
  });

  // PHASE 1 RECONCILE: Release-mode preview access is admin-only; debug may disclose it publicly.
  test('release preview guard requires an authenticated administrator', () {
    expect(
        AppRouter.redirectFor(AuthStatus.unauthenticated,
            RouteNames.schedulingWorkspacePreview, null,
            enableUnauthenticatedSchedulingPreview: false),
        RouteNames.login);
    expect(
        AppRouter.redirectFor(AuthStatus.authenticated,
            RouteNames.schedulingWorkspacePreview, 'student',
            enableUnauthenticatedSchedulingPreview: false),
        RouteNames.studentDashboard);
    expect(
        AppRouter.redirectFor(AuthStatus.authenticated,
            RouteNames.schedulingWorkspacePreview, 'admin',
            enableUnauthenticatedSchedulingPreview: false),
        isNull);
  });

  // PHASE 1: The More directory uses existing routes and dismisses before navigation.
  testWidgets('mobile admin More opens tools and navigates to Users',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final auth = TestAuth('admin');
    final notifications = TestNotifications();
    addTearDown(auth.dispose);
    addTearDown(notifications.dispose);
    final router = GoRouter(initialLocation: '/admin/dashboard', routes: [
      ShellRoute(
        builder: (c, s, child) => AppShell(
            authController: auth,
            notificationController: notifications,
            child: child),
        routes: [
          for (final path in ['/admin/dashboard', '/admin/users', '/profile'])
            GoRoute(
                path: path,
                builder: (c, s) => Scaffold(
                    appBar: const UAppBar(
                        title: 'Admin page', showBackButton: false),
                    body: Text(s.uri.path)))
        ],
      )
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    expect(find.text('Admin tools'), findsOneWidget);
    expect(find.text('Registration'), findsOneWidget);
    await tester.tap(find.text('Users'));
    await tester.pumpAndSettle();
    expect(find.text('/admin/users'), findsOneWidget);
    expect(find.text('Admin tools'), findsNothing);
    await tester.tap(find.byTooltip('Profile / Account'));
    await tester.pumpAndSettle();
    expect(find.text('/profile'), findsOneWidget);
    expect(find.byType(AppBottomNav), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // PHASE 1: Retain local-state back priority, then home, then the two-second exit policy.
  testWidgets(
      'mobile back unwinds local state before home and double-back exit',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final auth = TestAuth('student');
    final notifications = TestNotifications();
    final localState = ValueNotifier(true);
    addTearDown(auth.dispose);
    addTearDown(notifications.dispose);
    addTearDown(localState.dispose);
    var exitCount = 0;
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemNavigator.pop') exitCount++;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    final router = GoRouter(initialLocation: '/student/resources', routes: [
      ShellRoute(
        builder: (c, s, child) => AppShell(
            authController: auth,
            notificationController: notifications,
            child: child),
        routes: [
          GoRoute(
              path: '/student/dashboard',
              builder: (c, s) => const Scaffold(body: Text('Today body'))),
          GoRoute(
              path: '/student/resources',
              builder: (c, s) => ValueListenableBuilder<bool>(
                  valueListenable: localState,
                  builder: (context, active, _) => ShellBackScope(
                      onBack: active ? () => localState.value = false : null,
                      child: const Scaffold(body: Text('Resource folder'))))),
        ],
      )
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(localState.value, isFalse);
    expect(find.text('Resource folder'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Today body'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('Press back again to exit'), findsOneWidget);
    expect(exitCount, 0);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(exitCount, 1);
  });

  for (final role in ['student', 'teacher', 'admin']) {
    test('$role has the approved five mobile destinations', () {
      expect(
          AppBottomNav.destinationsFor(role).map((d) => d.label),
          role == 'student'
              ? ['Today', 'Routine', 'Campus', 'Resources', 'Alerts']
              : role == 'teacher'
                  ? ['Today', 'Teaching', 'Campus', 'Class Tools', 'Alerts']
                  : [
                      'Overview',
                      'Routine Operations',
                      'Scheduling Workbench · Preview',
                      'Broadcast',
                      'More'
                    ]);
    });
    for (final width in [390.0, 1024.0, 1280.0, 1440.0]) {
      testWidgets('$role shell at $width retains one navigation surface',
          (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final auth = TestAuth(role);
        final notifications = TestNotifications();
        addTearDown(auth.dispose);
        addTearDown(notifications.dispose);
        final home = role == 'admin'
            ? RouteNames.adminDashboard
            : role == 'teacher'
                ? RouteNames.teacherDashboard
                : RouteNames.studentDashboard;
        final router = GoRouter(initialLocation: home, routes: [
          ShellRoute(
            builder: (context, state, child) => AppShell(
                authController: auth,
                notificationController: notifications,
                child: child),
            routes: [
              GoRoute(
                  path: home,
                  builder: (context, state) => const Scaffold(
                      appBar: UAppBar(title: 'Page', showBackButton: false),
                      body: Text('Page body')))
            ],
          )
        ]);
        addTearDown(router.dispose);
        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();
        expect(find.byType(AppBottomNav),
            width < 768 ? findsOneWidget : findsNothing);
        expect(find.byType(ExploreFabMenu), findsNothing);
        expect(find.byTooltip('Profile / Account'), findsOneWidget);
        expect(find.text('Page body'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final (size, textScale) in [
    (const Size(390, 844), 1.0),
    (const Size(390, 844), 1.3),
    (const Size(1440, 900), 1.0)
  ]) {
    testWidgets(
        'RoomsScreen and FindTeacherScreen render cleanly at $size text $textScale without overflow',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final roomsCtrl = FakeRoomsController();
      final teacherCtrl = FakeFindTeacherController();
      addTearDown(roomsCtrl.dispose);
      addTearDown(teacherCtrl.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: MediaQuery(
            data: MediaQueryData(
                size: size,
                disableAnimations: true,
                textScaler: TextScaler.linear(textScale)),
            child: RoomsScreen(controller: roomsCtrl),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Showing 3 rooms'), findsOneWidget);
      expect(find.text('302'), findsOneWidget);
      expect(find.byType(ListView), findsWidgets);
      expect(find.byType(VerticalDivider),
          size.width >= 900 ? findsOneWidget : findsNothing);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: MediaQuery(
            data: MediaQueryData(
                size: size,
                disableAnimations: true,
                textScaler: TextScaler.linear(textScale)),
            child: FindTeacherScreen(controller: teacherCtrl),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Showing 3 faculty'), findsOneWidget);
      expect(find.text('Dr. Jamilur Rahman'), findsOneWidget);
      expect(find.byType(ListView), findsWidgets);
      expect(find.byType(VerticalDivider),
          size.width >= 900 ? findsOneWidget : findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
