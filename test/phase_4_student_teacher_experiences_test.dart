// PHASE 4: Comprehensive verification suite for StudentDashboardScreen, TeacherDashboardScreen,
// RoutineScreen, WeeklyScheduleView, and ManageClassesScreen across 390x844 and 1440x900 viewports.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:universe/core/constants/app_enums.dart';
import 'package:universe/core/models/notification_model.dart';
import 'package:universe/core/models/routine_model.dart';
import 'package:universe/core/router/route_names.dart';
import 'package:universe/core/theme/app_theme.dart';
import 'package:universe/features/auth/controllers/auth_controller.dart';
import 'package:universe/features/dashboard/controllers/student_dashboard_controller.dart';
import 'package:universe/features/dashboard/screens/student_dashboard_screen.dart';
import 'package:universe/features/notifications/controllers/notification_controller.dart';
import 'package:universe/features/routine/controllers/routine_controller.dart';
import 'package:universe/features/routine/screens/routine_screen.dart';
import 'package:universe/features/teacher/controllers/manage_classes_controller.dart';
import 'package:universe/features/teacher/controllers/teacher_dashboard_controller.dart';
import 'package:universe/features/teacher/screens/manage_classes_screen.dart';
import 'package:universe/features/teacher/screens/teacher_dashboard_screen.dart';
import 'package:universe/features/teacher/services/teacher_service.dart';
import 'package:universe/shared/widgets/live_class_card.dart';
import 'package:universe/shared/widgets/message_hero_card.dart';
import 'package:universe/shared/widgets/next_class_card.dart';
import 'package:universe/shared/widgets/u_weekly_load_bar_card.dart';
import 'package:universe/shared/widgets/weekly_schedule_view.dart';

class FakePhase4Auth extends ChangeNotifier implements AuthController {
  FakePhase4Auth({required this.role, required Map<String, dynamic> profileMap})
      : _profile = profileMap;

  @override
  final String role;
  final Map<String, dynamic> _profile;

  @override
  Map<String, dynamic>? get profile => _profile;

  @override
  Future<void> signOut() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakePhase4Notifications extends ChangeNotifier
    implements NotificationController {
  @override
  int get unreadCount => 2;

  @override
  List<NotificationItem> get items => [
        NotificationItem(
          id: 'n-1',
          title: 'Lab Room Updated',
          body: 'CSE-312 Sessional moved to Lab-3.',
          type: NotifType.roomChange,
          time: DateTime(2026, 11, 8, 9, 20),
          isRead: false,
        ),
        NotificationItem(
          id: 'n-2',
          title: 'Class Test 2 Reminder',
          body: 'Syllabus: Chapters 4 & 5.',
          type: NotifType.testReminder,
          time: DateTime(2026, 11, 8, 8, 30),
          isRead: true,
        ),
      ];

  @override
  Future<void> load() async {}

  @override
  void startRealtime() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

List<RoutineEntry> _sampleRoutineEntries() => const [
      RoutineEntry(
        id: 'sun-1',
        day: 'Sunday',
        timeStart: '09:00',
        timeEnd: '10:30',
        subject: 'Operating Systems',
        subjectCode: 'CSE-311',
        teacherName: 'Dr. Jamilur Rahman',
        teacherCode: 'JR',
        room: '302',
        batch: '58',
        section: 'B',
        semester: 6,
      ),
      RoutineEntry(
        id: 'sun-2',
        day: 'Sunday',
        timeStart: '11:30',
        timeEnd: '13:00',
        subject: 'Compiler Design Joint Lecture',
        subjectCode: 'CSE-313',
        teacherName: 'Dr. Jamilur Rahman',
        teacherCode: 'JR',
        coTeacherCodes: ['MK'],
        room: '404',
        batch: '58',
        section: 'B+C',
        semester: 6,
      ),
      RoutineEntry(
        id: 'mon-1',
        day: 'Monday',
        timeStart: '09:30',
        timeEnd: '12:00',
        subject: 'Operating Systems Sessional Lab',
        subjectCode: 'CSE-312',
        teacherName: 'Dr. Jamilur Rahman',
        teacherCode: 'JR',
        room: 'Lab-2',
        batch: '58',
        section: 'B',
        semester: 6,
      ),
    ];

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('Phase 4 Workstream A: StudentDashboardScreen', () {
    for (final size in [const Size(390, 844), const Size(1440, 900)]) {
      testWidgets(
          'renders Live, Next, and Done hero states and B+C joint section at $size without overflow',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final auth = FakePhase4Auth(
          role: 'student',
          profileMap: {
            'id': 'stu-1',
            'full_name': 'Arif Hossain',
            'email': 'arif@cse.edu',
            'role': 'student',
            'batch': '58',
            'section': 'B',
          },
        );
        final notifs = FakePhase4Notifications();
        addTearDown(auth.dispose);
        addTearDown(notifs.dispose);

        // 1. Live Class state (Sunday 09:30 -> sun-1 is live 09:00..10:30)
        // 8 Nov 2026 is a Sunday!
        var clockNow = DateTime(2026, 11, 8, 9, 30);
        final controller = StudentDashboardController(
          authController: auth,
          clock: () => clockNow,
          initialEntries: _sampleRoutineEntries(),
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark,
            home: MediaQuery(
              data: MediaQueryData(size: size, disableAnimations: true),
              child: StudentDashboardScreen(
                authController: auth,
                notificationController: notifs,
                controller: controller,
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(LiveClassCard), findsOneWidget);
        expect(find.textContaining('B+C'), findsWidgets);
        expect(find.text('Operating Systems'), findsWidgets);
        expect(find.text('Compiler Design Joint Lecture'), findsOneWidget);
        expect(tester.takeException(), isNull);

        // 2. Up Next state (Sunday 10:45 -> sun-1 done, sun-2 starts at 11:30)
        clockNow = DateTime(2026, 11, 8, 10, 45);
        controller.notifyListeners();
        await tester.pump();

        expect(find.byType(NextClassCard), findsOneWidget);
        expect(find.text('UP NEXT'), findsOneWidget);
        expect(tester.takeException(), isNull);

        // 3. Done for Today state (Sunday 15:00 -> all Sunday classes finished, previews Monday class)
        clockNow = DateTime(2026, 11, 8, 15, 0);
        controller.notifyListeners();
        await tester.pump();

        expect(find.byType(MessageHeroCard), findsOneWidget);
        expect(find.text("You're done for today"), findsOneWidget);
        expect(
          find.textContaining('Operating Systems Sessional Lab'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        expect(tester.binding.transientCallbackCount, 0);
      });
    }
  });

  group('Phase 4 Workstream B: TeacherDashboardScreen', () {
    for (final size in [const Size(390, 844), const Size(1440, 900)]) {
      testWidgets(
          'renders Teacher Code badge, teaching load summary, and navigates via Manage Occurrence at $size',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final auth = FakePhase4Auth(
          role: 'teacher',
          profileMap: {
            'id': 'tch-1',
            'full_name': 'Dr. Jamilur Rahman',
            'email': 'jr@cse.edu',
            'role': 'teacher',
            'teacher_code': 'JR',
            'department': 'CSE',
            'designation': 'Professor',
          },
        );
        final notifs = FakePhase4Notifications();
        addTearDown(auth.dispose);
        addTearDown(notifs.dispose);

        final clockNow = DateTime(2026, 11, 8, 9, 30);
        final controller = TeacherDashboardController(
          authController: auth,
          clock: () => clockNow,
          initialEntries: _sampleRoutineEntries(),
          initialCancelledKeys: const {'mon-1|2026-11-09'},
        );
        addTearDown(controller.dispose);

        final router = GoRouter(
          initialLocation: RouteNames.teacherDashboard,
          routes: [
            GoRoute(
              path: RouteNames.teacherDashboard,
              builder: (c, s) => MediaQuery(
                data: MediaQueryData(size: size, disableAnimations: true),
                child: TeacherDashboardScreen(
                  authController: auth,
                  notificationController: notifs,
                  controller: controller,
                ),
              ),
            ),
            GoRoute(
              path: RouteNames.manageClasses,
              builder: (c, s) => const Scaffold(
                body: Text('Manage Classes Destination'),
              ),
            ),
          ],
        );
        addTearDown(router.dispose);

        await tester.pumpWidget(
          MaterialApp.router(
            theme: AppTheme.dark,
            routerConfig: router,
          ),
        );
        await tester.pump();

        expect(find.text('Teacher Code: JR'), findsOneWidget);
        expect(find.byType(UWeeklyLoadBarCard), findsOneWidget);
        expect(find.textContaining('WEEKLY TEACHING LOAD'), findsOneWidget);
        expect(find.text('Manage Occurrence'), findsWidgets);
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('Manage Occurrence').first);
        await tester.pumpAndSettle();
        expect(find.text('Manage Classes Destination'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Phase 4 Workstream C: RoutineScreen & WeeklyScheduleView', () {
    testWidgets(
        'defaults to Day List at 390x844 with >=40m Break divider and Weekly Matrix at 1440x900 with cell detail inspection',
        (tester) async {
      final auth = FakePhase4Auth(
        role: 'student',
        profileMap: {
          'id': 'stu-1',
          'full_name': 'Arif Hossain',
          'email': 'arif@cse.edu',
          'role': 'student',
          'batch': '58',
          'section': 'B',
        },
      );
      addTearDown(auth.dispose);

      final clockNow = DateTime(2026, 11, 8, 9, 30); // Sunday
      final controller = RoutineController(
        authController: auth,
        clock: () => clockNow,
        initialEntries: _sampleRoutineEntries(),
        initialSelectedDay: 'Sun',
      );
      addTearDown(controller.dispose);

      // 1. Mobile 390x844: defaults to Day List and renders Break / Free Window divider (10:30 to 11:30 = 60m >= 40m)
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(390, 844),
              disableAnimations: true,
            ),
            child: RoutineScreen(
              authController: auth,
              controller: controller,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.textContaining('Batch 58 · Section B & Joint Sections'),
        findsOneWidget,
      );
      expect(find.textContaining('3 classes this week'), findsOneWidget);
      expect(find.byType(RoutineBreakDivider), findsOneWidget);
      expect(find.textContaining('Break:'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // 2. Desktop 1440x900: defaults to Weekly Matrix when usableWidth >= 860px
      tester.view.physicalSize = const Size(1440, 900);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(1440, 900),
              disableAnimations: true,
            ),
            child: RoutineScreen(
              authController: auth,
              controller: controller,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(WeeklyScheduleView), findsOneWidget);
      expect(find.text('DAY / SLOT'), findsOneWidget);
      expect(find.text('CSE-311'), findsOneWidget);
      expect(find.text('CSE-313'), findsOneWidget);

      // Tap a matrix cell to open the contextual detail modal
      await tester.tap(find.text('CSE-313'));
      await tester.pumpAndSettle();

      expect(find.text('JOINT / CO-TAUGHT SESSION'), findsOneWidget);
      expect(find.text('Room 404'), findsOneWidget);
      expect(
        find.textContaining('Combined / Joint Section'),
        findsOneWidget,
      );

      // Close modal and switch to Day List via USegmentedControl
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Day List'));
      await tester.pumpAndSettle();
      expect(find.byType(RoutineBreakDivider), findsOneWidget);
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    });
  });

  group('Phase 4 Workstream D: ManageClassesScreen & Two-Step Recovery', () {
    testWidgets(
        'renders docked inspector at 1440x900 and floating sheet at 390x844 with truthful partial-failure and undo recovery',
        (tester) async {
      final auth = FakePhase4Auth(
        role: 'teacher',
        profileMap: {
          'id': 'tch-1',
          'full_name': 'Dr. Jamilur Rahman',
          'email': 'jr@cse.edu',
          'role': 'teacher',
          'teacher_code': 'JR',
        },
      );
      addTearDown(auth.dispose);

      var simulatedOutcome =
          CancellationOutcome.partialSuccessNotificationFailed;
      var noticeSentCount = 0;

      final clockNow = DateTime(2026, 11, 8, 9, 0); // Sunday, Nov 8
      final controller = ManageClassesController(
        authController: auth,
        clock: () => clockNow,
        initialEntries: _sampleRoutineEntries(),
        initialSelectedDay: 'Sun',
        cancelClassHandler: (entry, date, reason) async => simulatedOutcome,
        undoCancelHandler: (entry, date) async => true,
        postNoticeHandler: (entry, type, title, body) async {
          noticeSentCount++;
          return true;
        },
      );
      addTearDown(controller.dispose);

      // 1. Desktop 1440x900: Master-Detail Split Workspace with docked right inspector
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(1440, 900),
              disableAnimations: true,
            ),
            child: ManageClassesScreen(
              authController: auth,
              controller: controller,
            ),
          ),
        ),
      );
      await tester.pump();

      // Verify interactive Date Stepper header & docked right inspector
      expect(find.textContaining('Sunday, Nov 8'), findsWidgets);
      expect(find.text('TODAY'), findsOneWidget);
      expect(
        find.textContaining(
          'Affects Nov 8 only · Recurring weekly routine remains unchanged',
        ),
        findsOneWidget,
      );
      expect(find.text('CANCEL THIS OCCURRENCE'), findsOneWidget);
      expect(find.text('POST A COHORT UPDATE'), findsOneWidget);

      // Trigger partial-success cancellation (cancellation saved, notification failed)
      await tester.tap(find.text('Cancel class'));
      await tester.pump();

      expect(controller.isCancelled(_sampleRoutineEntries().first), isTrue);
      expect(
        find.textContaining(
          'Class cancelled for Nov 8, but the cohort alert could not be sent. Your cancellation is saved.',
        ),
        findsWidgets,
      );
      expect(find.text('RESTORE CLASS OCCURRENCE'), findsOneWidget);

      // Undo cancellation and verify 1-tap 'Class Restored' Notice option
      await tester.tap(find.text('Undo cancellation'));
      await tester.pump();

      expect(controller.isCancelled(_sampleRoutineEntries().first), isFalse);
      expect(
        find.text("Send 'Class Restored' Notice to Cohort"),
        findsWidgets,
      );

      await tester.tap(
        find.text("Send 'Class Restored' Notice to Cohort").first,
      );
      await tester.pump();
      expect(noticeSentCount, 1);
      expect(tester.takeException(), isNull);

      // 2. Mobile 390x844: tapping a class opens the top-lit floating sheet
      simulatedOutcome = CancellationOutcome.fullSuccess;
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(390, 844),
              disableAnimations: true,
            ),
            child: ManageClassesScreen(
              authController: auth,
              controller: controller,
            ),
          ),
        ),
      );
      await tester.pump();

      // Docked inspector is not shown inline at 390px; tapping a class opens the sheet
      expect(find.text('POST A COHORT UPDATE'), findsNothing);
      await tester.tap(find.text('Operating Systems'));
      await tester.pumpAndSettle();

      expect(find.text('POST A COHORT UPDATE'), findsOneWidget);
      await tester.tap(find.text('Cancel class'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
          'Class occurrence cancelled for Nov 8 and cohort notification sent.',
        ),
        findsWidgets,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
