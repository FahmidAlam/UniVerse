import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:universe/core/models/routine_model.dart';
import 'package:universe/core/theme/app_theme.dart';
import 'package:universe/features/admin/controllers/admin_dashboard_controller.dart';
import 'package:universe/features/admin/controllers/routine_admin_controller.dart';
import 'package:universe/features/admin/controllers/routine_upload_controller.dart';
import 'package:universe/features/admin/controllers/timetable_gen_controller.dart';
import 'package:universe/features/admin/scheduling/widgets/distribution/distribution_record_inspector.dart';
import 'package:universe/features/admin/scheduling/widgets/distribution/distribution_table_desktop.dart';
import 'package:universe/features/admin/scheduling/widgets/generate/scheduling_generate_pane.dart';
import 'package:universe/features/admin/scheduling/widgets/review/scheduling_review_pane.dart';
import 'package:universe/features/admin/screens/admin_dashboard_screen.dart';
import 'package:universe/features/admin/screens/admin_routine_screen.dart';
import 'package:universe/features/admin/screens/generate_timetable_screen.dart';
import 'package:universe/features/admin/screens/routine_management_screen.dart';
import 'package:universe/features/admin/screens/scheduling_workspace_screen.dart';
import 'package:universe/features/admin/screens/timetable_grid_screen.dart';
import 'package:universe/features/admin/screens/upload_routine_screen.dart';
import 'package:universe/features/admin/services/admin_service.dart';
import 'package:universe/features/admin/services/routine_workbook_parser.dart';
import 'package:universe/features/admin/widgets/admin_desktop_shell.dart';
import 'package:universe/features/auth/controllers/auth_controller.dart';
import 'package:universe/features/notifications/controllers/notification_controller.dart';
import 'package:universe/shared/widgets/u_segmented_control.dart';

class _TestAuth extends ChangeNotifier implements AuthController {
  @override
  String get role => 'admin';
  @override
  Map<String, dynamic>? get profile => null;
  @override
  Future<void> signOut() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestNotifications extends ChangeNotifier
    implements NotificationController {
  @override
  int get unreadCount => 2;
  @override
  Future<void> load() async {}
  @override
  void startRealtime() {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _wrapRouter(
  Widget child, {
  String initialLocation = '/admin/dashboard',
}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/admin/dashboard',
        builder: (context, state) => child,
      ),
      GoRoute(
        path: '/admin/scheduling',
        builder: (context, state) => child,
      ),
      GoRoute(
        path: '/admin/routine',
        builder: (context, state) => child,
      ),
      GoRoute(
        path: '/admin/timetable/grid',
        builder: (context, state) => child,
      ),
      GoRoute(
        path: '/admin/timetable/rooms',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Rooms Target'))),
      ),
      GoRoute(
        path: '/admin/timetable/faculty',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Faculty Target'))),
      ),
      GoRoute(
        path: '/admin/timetable/course-eligibility',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Eligibility Target'))),
      ),
      GoRoute(
        path: '/admin/timetable/settings',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Settings Target'))),
      ),
      GoRoute(
        path: '/admin/broadcast',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Broadcast Target'))),
      ),
      GoRoute(
        path: '/admin/users',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Users Target'))),
      ),
      GoRoute(
        path: '/admin/registration',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Registration Target'))),
      ),
      GoRoute(
        path: '/admin/resources',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Resources Target'))),
      ),
    ],
  );
  return MaterialApp.router(
    theme: AppTheme.dark,
    routerConfig: router,
  );
}

Future<void> _setSurfaceSize(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void _assertNoException(WidgetTester tester) {
  final e = tester.takeException();
  expect(e, isNull);
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    FlutterError.onError = (FlutterErrorDetails details) {
      // ignore: avoid_print
      print('=== CAUGHT FLUTTER ERROR ===\n${details.toString()}');
      FlutterError.presentError(details);
    };
  });

  group('Workstream A: AdminDashboardScreen Command Center & Readiness', () {
    testWidgets(
      'Renders 4-stage readiness checklist, labeled load breakdown, and dual-track launchpad across 390px, 1024px, and 1440px without overflow',
      (tester) async {
        final auth = _TestAuth();
        final notifications = _TestNotifications();
        final controller = AdminDashboardController(
          initialCounts: const AdminCounts(
            students: 380,
            teachers: 26,
            admins: 4,
            routines: 164,
            broadcasts: 12,
            rooms: 14,
            courseEligibilities: 92,
          ),
        );
        addTearDown(() {
          controller.dispose();
          auth.dispose();
          notifications.dispose();
        });

        for (final size in const [
          Size(390, 844),
          Size(1024, 800),
          Size(1440, 900),
        ]) {
          await _setSurfaceSize(tester, size);
          final dashboard = AdminDashboardScreen(
            authController: auth,
            controller: controller,
          );
          await tester.pumpWidget(
            _wrapRouter(
              size.width >= 920
                  ? AdminDesktopShell(
                      authController: auth,
                      notificationController: notifications,
                      currentLocation: '/admin/dashboard',
                      child: dashboard,
                    )
                  : dashboard,
            ),
          );
          await tester.pumpAndSettle();

          _assertNoException(tester);
          expect(
            find.text('ROUTINE LIFECYCLE READINESS CHECKLIST'),
            findsOneWidget,
          );
          expect(find.text('01 · Room Pools'), findsOneWidget);
          expect(find.text('02 · Faculty & Off-Days'), findsOneWidget);
          expect(
              find.text('03 · Course Eligibility & Time Grid'), findsOneWidget);
          expect(find.text('04 · Active Routine & Engine'), findsOneWidget);
          expect(find.text('DUAL-TRACK SCHEDULING LAUNCHPAD'), findsOneWidget);
          expect(find.text('LIVE PIPELINE'), findsOneWidget);
          expect(find.text('DESIGN PREVIEW'), findsOneWidget);

          if (size.width < 880) {
            await tester.drag(
                find.byType(ListView).first, const Offset(0, -450));
            await tester.pumpAndSettle();
            _assertNoException(tester);
          }
          expect(
            find.text('DEPARTMENTAL SCHEDULE & RESOURCE LOAD BREAKDOWN'),
            findsOneWidget,
          );
        }
      },
    );

    testWidgets(
      'Highlights Setup Required badge when rooms or routine slots are zero',
      (tester) async {
        final zeroController = AdminDashboardController(
          initialCounts: const AdminCounts(
            students: 12,
            teachers: 0,
            admins: 1,
            routines: 0,
            broadcasts: 0,
            rooms: 0,
            courseEligibilities: 0,
          ),
        );
        addTearDown(zeroController.dispose);

        await _setSurfaceSize(tester, const Size(1280, 800));
        await tester.pumpWidget(
          _wrapRouter(AdminDashboardScreen(controller: zeroController)),
        );
        await tester.pumpAndSettle();

        expect(find.text('0 / 4 STAGES READY'), findsOneWidget);
        expect(find.text('Setup Required'), findsNWidgets(2));
        expect(find.text('Default Grid'), findsOneWidget);
        expect(find.text('Unpublished'), findsOneWidget);
      },
    );
  });

  group(
      'Workstream B: SchedulingWorkspaceScreen 1024px Fix, 390px Ergonomics & Signaling',
      () {
    testWidgets(
      'Fixes 1024px sidebar width collision: uses full-width table + adaptive modal inspector at 1024px inside AdminDesktopShell, and docks inspector at 1440px',
      (tester) async {
        final auth = _TestAuth();
        final notifications = _TestNotifications();
        addTearDown(() {
          auth.dispose();
          notifications.dispose();
        });

        // At 1024x800 inside AdminDesktopShell (252px sidebar -> ~772px usable width):
        // DistributionTableDesktop is visible, but permanent docked inspector is NOT shown.
        await _setSurfaceSize(tester, const Size(1024, 800));
        await tester.pumpWidget(
          _wrapRouter(
            AdminDesktopShell(
              authController: auth,
              notificationController: notifications,
              currentLocation: '/admin/scheduling',
              child: SchedulingWorkspaceScreen(
                availabilityLoader: () async =>
                    DistributionAvailability.unavailable,
                initialPreviewMode: true,
              ),
            ),
            initialLocation: '/admin/scheduling',
          ),
        );
        await tester.pumpAndSettle();

        _assertNoException(tester);
        expect(find.byType(DistributionTableDesktop), findsOneWidget);
        expect(find.byType(DistributionRecordInspector), findsNothing);
        expect(find.text('Showing 23 of 23 offerings'), findsOneWidget);

        // Tapping the Inspector toggle opens the adaptive modal sheet cleanly
        await tester.tap(find.byTooltip('Open Record Inspector'));
        await tester.pumpAndSettle();
        expect(find.byType(DistributionRecordInspector), findsOneWidget);

        // Close modal
        Navigator.of(tester.element(find.byType(DistributionRecordInspector)))
            .pop();
        await tester.pumpAndSettle();

        // At 1440x900 inside AdminDesktopShell (~1188px usable width >= 1020px):
        // Both DistributionTableDesktop AND docked DistributionRecordInspector render side-by-side.
        await _setSurfaceSize(tester, const Size(1440, 900));
        await tester.pumpAndSettle();

        _assertNoException(tester);
        // Toggle docked inspector side-by-side in expanded desktop view
        await tester.tap(find.byTooltip('Show Record Inspector'));
        await tester.pumpAndSettle();

        _assertNoException(tester);
        expect(find.byType(DistributionTableDesktop), findsOneWidget);
        expect(find.byType(DistributionRecordInspector), findsOneWidget);
      },
    );

    testWidgets(
      'All 5 panes render with zero RenderFlex overflow at 390x844 and enforce Default-Gray signaling + Slide-to-Confirm publish control',
      (tester) async {
        await _setSurfaceSize(tester, const Size(390, 844));
        await tester.pumpWidget(
          _wrapRouter(
            SchedulingWorkspaceScreen(
              availabilityLoader: () async =>
                  DistributionAvailability.unavailable,
              initialPreviewMode: true,
            ),
            initialLocation: '/admin/scheduling',
          ),
        );
        await tester.pumpAndSettle();
        _assertNoException(tester);
        expect(
          find.text('SIMULATED PREVIEW · NO DATABASE WRITES'),
          findsOneWidget,
        );

        // Stage 2: Configuration (Default-Gray vs Override-Active signaling)
        await tester.tap(find.text('Configuration'));
        await tester.pumpAndSettle();
        _assertNoException(tester);
        expect(find.text('DEFAULT BASELINE'), findsWidgets);

        // Stage 3: Readiness
        await tester.tap(find.text('Readiness'));
        await tester.pumpAndSettle();
        _assertNoException(tester);
        expect(find.text('PREFLIGHT BLOCKED (NO-GO)'), findsOneWidget);

        // Stage 4: Generate
        final tabController =
            tester.widget<TabBar>(find.byType(TabBar)).controller!;
        tabController.animateTo(3);
        await tester.pumpAndSettle();
        _assertNoException(tester);
        await tester.scrollUntilVisible(
          find.text('Run CP-SAT Solver'),
          200,
          scrollable: find.descendant(
            of: find.byType(SchedulingGeneratePane),
            matching: find.byType(Scrollable),
          ),
        );
        await tester.pumpAndSettle();
        _assertNoException(tester);
        expect(find.text('Run CP-SAT Solver'), findsWidgets);
        expect(find.text('SIMULATED PREVIEW · NO ENGINE CALL'), findsOneWidget);

        // Stage 5: Review & Publish
        tabController.animateTo(4);
        await tester.pumpAndSettle();
        _assertNoException(tester);
        expect(find.byType(USegmentedControl<int>), findsOneWidget);

        // Scroll to Atomic Publication Gate and open Publish dialog
        await tester.drag(
          find.byType(SchedulingReviewPane),
          const Offset(0, -1800),
        );
        await tester.pumpAndSettle();
        _assertNoException(tester);
        await tester.tap(find.text('Publish to Campus'));
        await tester.pumpAndSettle();
        _assertNoException(tester);
        expect(
          find.textContaining('Slide to Publish Routine'),
          findsOneWidget,
        );
      },
    );
  });

  group('Workstream C: Routine Operations (Manage, Generate, Upload & Grid)',
      () {
    final sampleEntries = <RoutineEntry>[
      const RoutineEntry(
        id: 'slot-1',
        day: 'Sunday',
        section: 'A',
        batch: '61',
        semester: 5,
        timeStart: '09:00',
        timeEnd: '10:15',
        subjectCode: 'CSE-3101',
        subject: 'Operating Systems',
        teacherCode: 'MRA',
        room: 'CR-302',
      ),
      const RoutineEntry(
        id: 'slot-2',
        day: 'Monday',
        section: 'B',
        batch: '62',
        semester: 3,
        timeStart: '10:15',
        timeEnd: '11:30',
        subjectCode: 'CSE-2201',
        subject: 'Algorithms',
        teacherCode: 'TKN',
        room: 'CR-304',
      ),
    ];

    testWidgets(
      'AdminRoutineScreen uses USegmentedControl while preserving IndexedStack and upfront slot counts',
      (tester) async {
        final auth = _TestAuth();
        final notifications = _TestNotifications();
        final manageCtrl =
            RoutineAdminController(initialEntries: sampleEntries);
        final genCtrl = TimetableGenController();
        final uploadCtrl = RoutineUploadController();
        addTearDown(() {
          manageCtrl.dispose();
          genCtrl.dispose();
          uploadCtrl.dispose();
          auth.dispose();
          notifications.dispose();
        });

        await _setSurfaceSize(tester, const Size(1280, 800));
        await tester.pumpWidget(
          _wrapRouter(
            AdminDesktopShell(
              authController: auth,
              notificationController: notifications,
              currentLocation: '/admin/routine',
              child: AdminRoutineScreen(
                manageController: manageCtrl,
                generateController: genCtrl,
                uploadController: uploadCtrl,
              ),
            ),
            initialLocation: '/admin/routine',
          ),
        );
        await tester.pumpAndSettle();

        _assertNoException(tester);
        expect(find.byType(USegmentedControl<int>), findsOneWidget);
        expect(find.text('Showing 2 of 2 published slots'), findsOneWidget);

        // Switch to Generate tab via USegmentedControl
        await tester.tap(find.text('Generate via Engine'));
        await tester.pumpAndSettle();
        expect(
          find.text('STAGE 1 · INPUT SOURCE & BASELINE READINESS'),
          findsOneWidget,
        );

        // Switch to Upload tab via USegmentedControl
        await tester.tap(find.text('Upload Workbook'));
        await tester.pumpAndSettle();
        expect(find.text('Choose routine workbook'), findsOneWidget);
      },
    );

    testWidgets(
      'GenerateTimetableScreen renders 4-Node Visual Timeline during polling and Service Recovery Card on error',
      (tester) async {
        final genCtrl = TimetableGenController();
        addTearDown(genCtrl.dispose);

        genCtrl.seedPreviewState(
          phase: GenPhase.polling,
          fileName: 'Course Distribution Spring 2026.xlsx',
          progress: 0.65,
          activeJobState: 'solving',
        );

        await _setSurfaceSize(tester, const Size(1024, 800));
        await tester.pumpWidget(
          _wrapRouter(
            GenerateTimetableScreen(
              embedded: true,
              controller: genCtrl,
            ),
          ),
        );
        await tester.pump();

        _assertNoException(tester);
        expect(
          find.text('STAGE 2 · SOLVER EXECUTION TIMELINE'),
          findsOneWidget,
        );
        expect(find.text('1. Queued'), findsOneWidget);
        expect(find.text('2. Ingesting & Validating'), findsOneWidget);
        expect(
          find.text('3. CP-SAT Session & Room Placement'),
          findsOneWidget,
        );
        expect(find.text('4. Rendering Timetable'), findsOneWidget);
        expect(find.text('65%'), findsOneWidget);

        // Transition to error state and verify Service Recovery Paradox card
        genCtrl.seedPreviewState(
          phase: GenPhase.error,
          errorMessage: 'Engine timeout while waking up worker.',
        );
        await tester.pumpAndSettle();

        expect(find.text('Generation could not complete'), findsOneWidget);
        expect(
          find.textContaining(
            'Input preserved: "Course Distribution Spring 2026.xlsx" remains loaded in memory',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'UploadRoutineScreen renders 3-Step Post-Parse Pipeline and Service Recovery Paradox notice when secondary log warns',
      (tester) async {
        const parseResult = RoutineWorkbookParseResult(
          rows: [
            RoutineEntry(
              id: 'u-1',
              day: 'Sunday',
              section: 'A',
              batch: '61',
              semester: 5,
              timeStart: '09:00',
              timeEnd: '10:15',
              subjectCode: 'CSE-3101',
              subject: 'Operating Systems',
              teacherCode: 'MRA',
              room: 'CR-302',
            ),
          ],
          sourceFormat: 'day_sheets',
          stats: {
            'meetings': 1,
            'cohorts': 1,
            'teachers': 1,
          },
          validation: {'ok': true},
          warnings: [],
        );

        final uploadCtrl = RoutineUploadController(
          initialPhase: RoutineUploadPhase.published,
          initialFileName: 'Rendered Routine Spring 2026.xlsx',
          initialResult: parseResult,
          initialPublishedCount: 1,
          initialSecondaryWarning:
              'Routine is live across all cohorts, but run-history log could not be recorded.',
        );
        addTearDown(uploadCtrl.dispose);

        await _setSurfaceSize(tester, const Size(1024, 800));
        await tester.pumpWidget(
          _wrapRouter(
            UploadRoutineScreen(
              embedded: true,
              controller: uploadCtrl,
            ),
          ),
        );
        await tester.pumpAndSettle();

        _assertNoException(tester);
        expect(find.text('Published to the app'), findsOneWidget);
        expect(
          find.text('Routine is live · Secondary log notice'),
          findsOneWidget,
        );
        expect(find.text('POST-PARSE PUBLICATION PIPELINE'), findsOneWidget);
        expect(find.text('1. Storage Archive'), findsOneWidget);
        expect(find.text('2. Atomic publish_routine RPC'), findsOneWidget);
        expect(find.text('3. Run History & Notification'), findsOneWidget);
      },
    );

    testWidgets(
      'RoutineManagementScreen opens adaptive Add Entry modal and TimetableGridScreen renders cleanly at 390px and 1280px',
      (tester) async {
        final manageCtrl =
            RoutineAdminController(initialEntries: sampleEntries);
        addTearDown(manageCtrl.dispose);

        await _setSurfaceSize(tester, const Size(390, 844));
        await tester.pumpWidget(
          _wrapRouter(
            RoutineManagementScreen(
              embedded: false,
              controller: manageCtrl,
            ),
          ),
        );
        await tester.pumpAndSettle();
        _assertNoException(tester);
        expect(find.text('Showing 2 of 2 published slots'), findsOneWidget);

        // TimetableGridScreen populated state at 390px
        await tester.pumpWidget(
          _wrapRouter(
            TimetableGridScreen(rows: sampleEntries),
            initialLocation: '/admin/timetable/grid',
          ),
        );
        await tester.pumpAndSettle();
        _assertNoException(tester);
        expect(find.text('Showing 2 of 2 slots'), findsOneWidget);
        await tester.tap(find.text(sampleEntries.first.subjectCode).first);
        await tester.pumpAndSettle();
        expect(find.text('Copy Slot Summary'), findsOneWidget);
        _assertNoException(tester);
        Navigator.of(tester.element(find.text('Copy Slot Summary'))).pop();
        await tester.pumpAndSettle();
        await _setSurfaceSize(tester, const Size(1280, 900));
        await tester.pumpAndSettle();
        expect(
            find.text('Slot Provenance & Resource Inspector'), findsOneWidget);
        expect(find.text('Copy Slot Summary'), findsOneWidget);
        _assertNoException(tester);
      },
    );
  });
}
