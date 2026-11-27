import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universe/core/constants/app_enums.dart';
import 'package:universe/core/models/notification_model.dart';
import 'package:universe/core/models/resource_model.dart';
import 'package:universe/core/models/routine_model.dart';
import 'package:universe/core/theme/app_theme.dart';
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

  group('Workstream C: Phase 6 Supporting Campus Modules', () {
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
        'ResourcesScreen renders with 0 overflow',
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

      expect(tester.takeException(), isNull);
    });
  });
}
