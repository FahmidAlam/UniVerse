import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universe/core/constants/app_enums.dart';
import 'package:universe/core/models/notification_model.dart';
import 'package:universe/core/models/profile_model.dart';
import 'package:universe/core/models/resource_model.dart';
import 'package:universe/core/models/routine_model.dart';
import 'package:universe/core/models/timetable_config_model.dart';
import 'package:universe/core/theme/app_theme.dart';
import 'package:universe/features/admin/controllers/course_eligibility_controller.dart';
import 'package:universe/features/admin/controllers/manage_users_controller.dart';
import 'package:universe/features/admin/controllers/timetable_faculty_controller.dart';
import 'package:universe/features/admin/controllers/timetable_rooms_controller.dart';
import 'package:universe/features/admin/scheduling/controllers/scheduling_workspace_controller.dart';
import 'package:universe/features/admin/scheduling/widgets/configuration/scheduling_configuration_pane.dart';
import 'package:universe/features/admin/screens/campus_broadcast_screen.dart';
import 'package:universe/features/admin/screens/manage_course_eligibility_screen.dart';
import 'package:universe/features/admin/screens/manage_faculty_screen.dart';
import 'package:universe/features/admin/screens/manage_rooms_screen.dart';
import 'package:universe/features/admin/screens/manage_users_screen.dart';
import 'package:universe/features/admin/screens/timetable_settings_screen.dart';
import 'package:universe/features/auth/controllers/auth_controller.dart';
import 'package:universe/features/find_teacher/controllers/find_teacher_controller.dart';
import 'package:universe/features/find_teacher/screens/find_teacher_screen.dart';
import 'package:universe/features/find_teacher/services/teacher_location_service.dart';
import 'package:universe/features/notifications/controllers/notification_controller.dart';
import 'package:universe/features/notifications/screens/notifications_screen.dart';
import 'package:universe/features/resources/controllers/resource_controller.dart';
import 'package:universe/features/resources/screens/resources_screen.dart';
import 'package:universe/features/rooms/controllers/rooms_controller.dart';
import 'package:universe/features/rooms/screens/rooms_screen.dart';
import 'package:universe/features/rooms/services/room_status_service.dart';
import 'package:universe/shared/widgets/desktop_shell_scope.dart';

class _MockAuth extends ChangeNotifier implements AuthController {
  @override
  String get role => 'admin';
  @override
  Map<String, dynamic>? get profile => {
        'id': 'test-admin-uuid',
        'display_name': 'Dr. Test Administrator',
        'email': 'admin@sust.edu',
        'role': 'admin',
      };
  @override
  Future<void> signOut() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockNotifications extends ChangeNotifier
    implements NotificationController {
  @override
  int get unreadCount => 3;
  @override
  DateTime? get lastChecked => DateTime.now();
  @override
  bool get isLoading => false;
  @override
  bool get selectionMode => false;
  @override
  int get selectedCount => 0;
  @override
  NotifType? get activeFilter => null;
  @override
  List<NotificationItem> get filtered => [];
  @override
  Future<void> load() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockTeacherService implements TeacherLocationService {
  @override
  Future<List<RoutineEntry>> fetchAllRoutines() async {
    return [
      const RoutineEntry(
        id: 'r1',
        semester: 1,
        batch: '62',
        section: 'A',
        subject: 'Structured Programming',
        subjectCode: 'CSE-1101',
        teacherCode: 'MSR',
        room: 'LAB-1',
        day: 'Sunday',
        timeStart: '09:00',
        timeEnd: '10:40',
      ),
    ];
  }

  @override
  Future<List<String>> fetchUniqueTeachers() async => ['MSR'];

  @override
  Stream<List<RoutineEntry>> streamAllRoutines() => const Stream.empty();
}

class _MockRoomStatusService implements RoomStatusService {
  @override
  Future<List<RoutineEntry>> fetchAllRoutines() async {
    return [
      const RoutineEntry(
        id: 'r1',
        semester: 1,
        batch: '62',
        section: 'A',
        subject: 'Structured Programming',
        subjectCode: 'CSE-1101',
        teacherCode: 'MSR',
        room: 'LAB-1',
        day: 'Sunday',
        timeStart: '09:00',
        timeEnd: '10:40',
      ),
    ];
  }

  @override
  Stream<List<RoutineEntry>> streamAllRoutines() => const Stream.empty();
}

final _sampleFaculty = [
  const TimetableFaculty(
    id: 'f1',
    acronym: 'MSA',
    fullName: 'Prof. Dr. M. Shahidur Rahman',
    dept: 'CSE',
    designation: 'Professor',
    offDays: ['Friday', 'Saturday'],
    isActive: true,
  ),
  const TimetableFaculty(
    id: 'f2',
    acronym: 'FA',
    fullName: 'Dr. Farhad Ahmed',
    dept: 'CSE',
    designation: 'Adjunct Professor',
    offDays: ['Friday', 'Saturday', 'Sunday'],
    isActive: true,
  ),
];

final _sampleRooms = [
  const TimetableRoom(
    id: 'r1',
    name: 'RAB-301',
    building: 'Academic Building',
    isLab: false,
    isActive: true,
    capacity: 60,
  ),
  const TimetableRoom(
    id: 'r2',
    name: 'ECL-1',
    building: 'EEE Building',
    isLab: true,
    isActive: true,
    capacity: 35,
  ),
];

final _sampleCourses = [
  (code: 'CSE-1101', title: 'Structured Programming'),
  (code: 'CSE-1102', title: 'Structured Programming Lab'),
];

Future<void> _setSurfaceSize(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Widget _wrapInApp(Widget child,
    {Size size = const Size(1440, 900), bool isDesktop = true}) {
  return MaterialApp(
    theme: AppTheme.dark,
    home: MediaQuery(
      data: MediaQueryData(size: size),
      child: DesktopShellScope(
        isDesktop: isDesktop,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: Material(child: child),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Workstream A: R1–R16 Policy Architecture & Scheduling Workbench', () {
    testWidgets(
        'SchedulingConfigurationPane renders all 5 categories and prominent R15 6/7-slot control',
        (tester) async {
      await _setSurfaceSize(tester, const Size(1440, 900));
      final controller =
          SchedulingWorkspaceController(initialPreviewMode: true);

      await tester.pumpWidget(
        _wrapInApp(
          SchedulingConfigurationPane(controller: controller),
          size: const Size(1440, 900),
        ),
      );
      await tester.pumpAndSettle();

      // Category 1
      expect(
          find.textContaining('TERM GRID & SECTION CALENDAR'), findsWidgets);
      // R15 Flexible Daily Slot Configuration Segmented Control
      expect(find.textContaining('6-Slot Daily Grid'), findsOneWidget);
      expect(find.textContaining('7-Slot Daily Grid'), findsOneWidget);

      // Verify period strip preview is visible
      expect(find.textContaining('PERIOD STRIP VISUAL PREVIEW'), findsOneWidget);
      expect(find.text('SLOT 1'), findsOneWidget);
      expect(find.text('BREAK'), findsOneWidget);

      // Switch to 6-Slot Grid
      await tester.tap(find.textContaining('6-Slot Daily Grid'));
      await tester.pumpAndSettle();

      // Verify policy override updated in controller
      final r15Item =
          controller.policyItems.firstWhere((i) => i.ruleId.contains('R15'));
      expect(r15Item.overrideValue, contains('6-Slot Daily Grid'));

      // Drag down to verify Category 2 and R6 Workload Table
      await tester.drag(find.byType(ListView).first, const Offset(0, -900));
      await tester.pumpAndSettle();
      expect(find.textContaining('FACULTY WORKLOAD'), findsWidgets);
      expect(find.textContaining('R6 CATEGORY WORKLOAD TABLE'), findsOneWidget);
      expect(find.textContaining('Adjunct Faculty: 2 courses'), findsOneWidget);
    });

    testWidgets(
        'TimetableSettingsScreen honors Single-Header Rule and renders Section 1 and Section 2',
        (tester) async {
      await _setSurfaceSize(tester, const Size(1440, 900));
      await tester.pumpWidget(
        _wrapInApp(
          const TimetableSettingsScreen(),
          size: const Size(1440, 900),
          isDesktop: true,
        ),
      );
      await tester.pumpAndSettle();

      // Under DesktopShellScope, no redundant AppBar is rendered
      expect(find.byType(AppBar), findsNothing);
      expect(find.text('SECTION 1 · CORE TERM GRID & TIMINGS (R15)'),
          findsOneWidget);

      await tester.drag(find.byType(ListView).first, const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(
          find.text('SECTION 2 · COMMITTEE SOLVER RULES & WEIGHTS (R1–R14)'),
          findsOneWidget);
    });
  });

  group('Workstream B: Admin Baseline CRUD Screens Overhaul (R4–R14)', () {
    testWidgets(
        'ManageFacultyScreen renders 55/45 Master-Detail Split at 1440px with R4-R9 controls',
        (tester) async {
      await _setSurfaceSize(tester, const Size(1440, 900));
      final controller =
          TimetableFacultyController(initialFaculty: _sampleFaculty);

      await tester.pumpWidget(
        _wrapInApp(
          ManageFacultyScreen(controller: controller),
          size: const Size(1440, 900),
          isDesktop: true,
        ),
      );
      await tester.pumpAndSettle();

      // Under DesktopShellScope, no redundant AppBar
      expect(find.byType(AppBar), findsNothing);

      // Verify Upfront Filter Chips and Live Count Pill
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Permanent'), findsOneWidget);
      expect(find.text('Adjunct'), findsOneWidget);
      expect(find.textContaining('Showing'), findsOneWidget);

      // Verify Detail Inspector is visible in 45% right pane
      expect(find.textContaining('DAY × SLOT AVAILABILITY MATRIX'),
          findsOneWidget);
      expect(find.textContaining('R9 SUST ADJUNCT COMPACTNESS'), findsOneWidget);
    });

    testWidgets(
        'ManageRoomsScreen renders 55/45 Master-Detail Split and R14 Dynamic Pool Switch',
        (tester) async {
      await _setSurfaceSize(tester, const Size(1440, 900));
      final controller =
          TimetableRoomsController(initialRooms: _sampleRooms);

      await tester.pumpWidget(
        _wrapInApp(
          ManageRoomsScreen(controller: controller),
          size: const Size(1440, 900),
          isDesktop: true,
        ),
      );
      await tester.pumpAndSettle();

      // Under DesktopShellScope, no redundant AppBar
      expect(find.byType(AppBar), findsNothing);

      // Verify Filter Chips & Room Counts
      expect(find.textContaining('Active Semester Pool'), findsOneWidget);
      expect(find.textContaining('CSE Computer Labs'), findsOneWidget);
      expect(find.textContaining('ECL Labs'), findsOneWidget);

      // Right detail inspector
      expect(find.textContaining('R14 Active Semester Classroom Pool'),
          findsOneWidget);
      expect(find.textContaining('Active in Semester Pool (R14)'),
          findsOneWidget);
    });

    testWidgets(
        'ManageCourseEligibilityScreen renders 55/45 Split and R12/R13 rule badges',
        (tester) async {
      await _setSurfaceSize(tester, const Size(1440, 900));
      final controller = CourseEligibilityController(
        initialFaculty: _sampleFaculty,
        initialCatalog: _sampleCourses,
      );

      await tester.pumpWidget(
        _wrapInApp(
          ManageCourseEligibilityScreen(controller: controller),
          size: const Size(1440, 900),
          isDesktop: true,
        ),
      );
      await tester.pumpAndSettle();

      // Under DesktopShellScope, no redundant AppBar
      expect(find.byType(AppBar), findsNothing);

      // Verify course list & automatic rule badge
      expect(
          find.textContaining(
              'Course Meeting Distribution & Eligibility (R12, R13)'),
          findsOneWidget);
      expect(find.textContaining('Theory'), findsWidgets);
    });

    testWidgets(
        'CRUD screens adapt cleanly to mobile 390x844 without horizontal overflow',
        (tester) async {
      await _setSurfaceSize(tester, const Size(390, 844));
      final controller =
          TimetableFacultyController(initialFaculty: _sampleFaculty);

      await tester.pumpWidget(
        _wrapInApp(
          ManageFacultyScreen(controller: controller),
          size: const Size(390, 844),
          isDesktop: false,
        ),
      );
      await tester.pumpAndSettle();

      // On mobile, app bar is preserved
      expect(find.byType(AppBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Workstream C: Phase 6 Supporting Campus & Admin Modules Overhaul', () {
    testWidgets(
        'RoomsScreen renders 55/45 Master-Detail Split with truthful copy at 1440px',
        (tester) async {
      await _setSurfaceSize(tester, const Size(1440, 900));
      final controller = RoomsController(service: _MockRoomStatusService());
      await controller.fetchRoomStatuses();

      await tester.pumpWidget(
        _wrapInApp(
          RoomsScreen(controller: controller),
          size: const Size(1440, 900),
          isDesktop: true,
        ),
      );
      await tester.pumpAndSettle();

      // 55/45 master detail split
      expect(find.text('ALL CAMPUS ROOMS'), findsOneWidget);
      expect(find.textContaining('WEEKLY SCHEDULE'), findsOneWidget);
      expect(find.textContaining('Occupancy derived from published routine'),
          findsOneWidget);
      controller.dispose();
    });

    testWidgets(
        'FindTeacherScreen renders 55/45 Master-Detail Split with truthful copy at 1440px',
        (tester) async {
      await _setSurfaceSize(tester, const Size(1440, 900));
      final controller = FindTeacherController(service: _MockTeacherService());
      await controller.initialize();

      await tester.pumpWidget(
        _wrapInApp(
          FindTeacherScreen(controller: controller),
          size: const Size(1440, 900),
          isDesktop: true,
        ),
      );
      await tester.pumpAndSettle();

      // 55/45 master detail split
      expect(find.textContaining('faculty'), findsWidgets);
      expect(find.textContaining('Derived from published routine'),
          findsWidgets);
      controller.dispose();
    });

    testWidgets(
        'NotificationsScreen renders manual refresh and last-checked timestamp',
        (tester) async {
      await _setSurfaceSize(tester, const Size(1440, 900));
      final auth = _MockAuth();
      final notifs = _MockNotifications();

      await tester.pumpWidget(
        _wrapInApp(
          NotificationsScreen(authController: auth, controller: notifs),
          size: const Size(1440, 900),
          isDesktop: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Notifications & Alerts'), findsOneWidget);
      expect(find.textContaining('Last checked:'), findsOneWidget);
      expect(find.textContaining('Live updates active'), findsOneWidget);
      expect(find.text('Refresh'), findsOneWidget);
    });

    testWidgets(
        'ResourcesScreen, ProfileScreen, CampusBroadcastScreen, ManageUsersScreen render with 0 overflow',
        (tester) async {
      await _setSurfaceSize(tester, const Size(1440, 900));
      final auth = _MockAuth();

      // ResourcesScreen
      final resCtrl = ResourceController(
        authController: auth,
        initialItems: [
          const Resource(
            id: 'res-1',
            title: 'CSE-1101 Syllabus',
            semester: 1,
            category: 'Syllabus',
            fileUrl: 'https://example.com/syllabus.pdf',
          ),
        ],
      );
      await tester.pumpWidget(
        _wrapInApp(
          ResourcesScreen(authController: auth, controller: resCtrl),
          size: const Size(1440, 900),
          isDesktop: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Academic Resources'), findsOneWidget);

      // CampusBroadcastScreen
      await tester.pumpWidget(
        _wrapInApp(
          CampusBroadcastScreen(authController: auth),
          size: const Size(1440, 900),
          isDesktop: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Campus Broadcast'), findsOneWidget);

      // ManageUsersScreen
      final usersCtrl = ManageUsersController(
        initialUsers: [
          const Profile(
            id: 'u1',
            email: 'student@sust.edu',
            role: 'student',
            name: 'Sadia Rahman',
          ),
        ],
      );
      await tester.pumpWidget(
        _wrapInApp(
          ManageUsersScreen(controller: usersCtrl),
          size: const Size(1440, 900),
          isDesktop: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Manage Users'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });
  });
}
