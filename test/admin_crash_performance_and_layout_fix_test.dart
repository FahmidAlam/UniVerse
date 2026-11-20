import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:universe/core/models/routine_model.dart';
import 'package:universe/core/theme/app_theme.dart';
import 'package:universe/features/admin/controllers/batches_controller.dart';
import 'package:universe/features/admin/controllers/courses_controller.dart';
import 'package:universe/features/admin/controllers/course_eligibility_controller.dart';
import 'package:universe/features/admin/controllers/timetable_faculty_controller.dart';
import 'package:universe/features/admin/controllers/timetable_rooms_controller.dart';
import 'package:universe/features/admin/screens/manage_batches_screen.dart';
import 'package:universe/features/admin/screens/manage_courses_screen.dart';
import 'package:universe/features/admin/screens/manage_course_eligibility_screen.dart';
import 'package:universe/features/admin/screens/manage_faculty_screen.dart';
import 'package:universe/features/admin/screens/manage_rooms_screen.dart';
import 'package:universe/features/admin/screens/timetable_grid_screen.dart';
import 'package:universe/features/admin/services/timetable_config_service.dart';
import 'package:universe/shared/widgets/desktop_shell_scope.dart';

Widget _wrap(Widget child, {Size size = const Size(1440, 900)}) {
  return MediaQuery(
    data: MediaQueryData(size: size),
    child: MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: DesktopShellScope(
          isDesktop: true,
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('Admin Crash, Performance and Layout Remediation Suite', () {
    testWidgets(
        'Test 1: ManageRoomsScreen row switching does not crash with LateInitializationError',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      final service = TimetableConfigService();
      final controller = TimetableRoomsController(service: service);

      await tester.pumpWidget(_wrap(ManageRoomsScreen(controller: controller)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Add Room'), findsOneWidget);

      // Tap Room 302
      final room302 = find.text('Room 302');
      if (room302.evaluate().isNotEmpty) {
        await tester.tap(room302.first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }

      // Tap Room 301
      final room301 = find.text('Room 301');
      if (room301.evaluate().isNotEmpty) {
        await tester.tap(room301.first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }

      // Tap CSE Lab 1
      final cseLab1 = find.text('CSE Lab 1');
      if (cseLab1.evaluate().isNotEmpty) {
        await tester.tap(cseLab1.first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets(
        'Test 2: ManageBatchesScreen, ManageCoursesScreen, ManageFacultyScreen row switching succeeds without error',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      final service = TimetableConfigService();

      // ManageBatchesScreen row switching
      final batchesCtrl = BatchesController(service: service);
      await tester.pumpWidget(_wrap(ManageBatchesScreen(controller: batchesCtrl)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final batch59 = find.text('Batch 59');
      if (batch59.evaluate().isNotEmpty) {
        await tester.tap(batch59.first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }

      final batch58 = find.text('Batch 58');
      if (batch58.evaluate().isNotEmpty) {
        await tester.tap(batch58.first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }

      // ManageCoursesScreen row switching
      final coursesCtrl = CoursesController(service: service);
      await tester.pumpWidget(_wrap(ManageCoursesScreen(controller: coursesCtrl)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final cse1102 = find.text('CSE-1102');
      if (cse1102.evaluate().isNotEmpty) {
        await tester.tap(cse1102.first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }

      final cse1101 = find.text('CSE-1101');
      if (cse1101.evaluate().isNotEmpty) {
        await tester.tap(cse1101.first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }

      // ManageFacultyScreen row switching
      final facultyCtrl = TimetableFacultyController(service: service);
      await tester.pumpWidget(_wrap(ManageFacultyScreen(controller: facultyCtrl)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final mna = find.text('MNA');
      if (mna.evaluate().isNotEmpty) {
        await tester.tap(mna.first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }

      final msa = find.text('MSA');
      if (msa.evaluate().isNotEmpty) {
        await tester.tap(msa.first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets(
        'Test 3: ManageCourseEligibilityScreen & Shell Route Switching without _dependents.isEmpty crash',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      final service = TimetableConfigService();

      int currentRouteIndex = 0;
      Widget buildRoute(int idx) {
        switch (idx) {
          case 0:
            return ManageRoomsScreen(
              controller: TimetableRoomsController(service: service),
            );
          case 1:
            return ManageCourseEligibilityScreen(
              controller: CourseEligibilityController(service: service),
            );
          case 2:
            return ManageBatchesScreen(
              controller: BatchesController(service: service),
            );
          case 3:
            return const TimetableGridScreen(
              rows: [],
              embedded: true,
            );
          default:
            return const SizedBox();
        }
      }

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return _wrap(
              Column(
                children: [
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        currentRouteIndex = (currentRouteIndex + 1) % 4;
                      });
                    },
                    child: const Text('Next Route'),
                  ),
                  Expanded(child: buildRoute(currentRouteIndex)),
                ],
              ),
            );
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Route 0 -> Route 1 (Course Eligibility)
      await tester.tap(find.text('Next Route'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Course Eligibility'), findsWidgets);

      // Route 1 -> Route 2 (Batches)
      await tester.tap(find.text('Next Route'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Route 2 -> Route 3 (Grid)
      await tester.tap(find.text('Next Route'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Route 3 -> Route 0 (Rooms)
      await tester.tap(find.text('Next Route'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Test 4: No double "+ +" button text across admin screens and unclipped lens labels',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      final service = TimetableConfigService();

      // Check ManageRoomsScreen
      await tester.pumpWidget(_wrap(ManageRoomsScreen(
        controller: TimetableRoomsController(service: service),
      )));
      await tester.pumpAndSettle();
      expect(find.textContaining('+ +'), findsNothing);
      expect(find.text('Add Room'), findsOneWidget);

      // Check ManageBatchesScreen
      await tester.pumpWidget(_wrap(ManageBatchesScreen(
        controller: BatchesController(service: service),
      )));
      await tester.pumpAndSettle();
      expect(find.textContaining('+ +'), findsNothing);
      expect(find.text('New Batch'), findsOneWidget);

      // Check ManageCoursesScreen
      await tester.pumpWidget(_wrap(ManageCoursesScreen(
        controller: CoursesController(service: service),
      )));
      await tester.pumpAndSettle();
      expect(find.textContaining('+ +'), findsNothing);
      expect(find.text('New Course'), findsOneWidget);

      // Check ManageFacultyScreen
      await tester.pumpWidget(_wrap(ManageFacultyScreen(
        controller: TimetableFacultyController(service: service),
      )));
      await tester.pumpAndSettle();
      expect(find.textContaining('+ +'), findsNothing);
      expect(find.text('Add Faculty'), findsOneWidget);

      // Check TimetableGridScreen
      await tester.pumpWidget(_wrap(const TimetableGridScreen(
        rows: [],
        embedded: true,
      )));
      await tester.pumpAndSettle();
      expect(find.textContaining('+ +'), findsNothing);

      // Check full Operational Lens labels without ellipsis truncation
      expect(find.text('Section'), findsOneWidget);
      expect(find.text('Faculty'), findsOneWidget);
      expect(find.text('Room'), findsOneWidget);
    });

    testWidgets(
        'Test 5: TimetableGridScreen has full-width default canvas and closable inspector',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));

      final testRows = [
        RoutineEntry(
          id: 'slot-sample-1',
          day: 'Sunday',
          timeStart: '08:50',
          timeEnd: '10:05',
          subject: 'Database Systems',
          subjectCode: 'CSE-3101',
          teacherCode: 'MSA',
          room: '302',
          batch: '58',
          section: 'A',
          semester: 5,
        ),
      ];

      await tester.pumpWidget(_wrap(TimetableGridScreen(
        rows: testRows,
        embedded: true,
      )));
      await tester.pumpAndSettle();

      // By default, inspector is NOT open -> 100% full-width grid
      expect(find.text('Slot Provenance & Resource Inspector'), findsNothing);

      // Tap scheduled slot cell
      final slotFinder = find.text('CSE-3101');
      expect(slotFinder, findsWidgets);
      await tester.tap(slotFinder.first);
      await tester.pumpAndSettle();

      // Inspector is now open
      expect(find.text('Slot Provenance & Resource Inspector'), findsOneWidget);

      // Tap close [X] button
      final closeButton = find.byTooltip('Close Inspector');
      expect(closeButton, findsOneWidget);
      await tester.tap(closeButton);
      await tester.pumpAndSettle();

      // Inspector is closed -> 100% full-width grid restored
      expect(find.text('Slot Provenance & Resource Inspector'), findsNothing);
    });
  });
}
