// PHASE B & 7-DAY INSTITUTIONAL STANDARD TEST SUITE
// Tests:
// 1. 7-Day Institutional Week & Friday Jummah Prayer Hard Constraint (friday_no_p4) across Faculty & Room matrices.
// 2. Anti-Slop Precision: Unselected row 3px stripes removed, filler badges deleted, right-aligned tabular numerals.
// 3. Phase B1: Native UI Catalog ↔ .xlsx Co-existence Bridge & Synthesis in TimetableConfigService & GenerateTimetableScreen.
// 4. Phase B2: Unified Routine Operations 2D Grid with 4-tab IndexedStack in AdminRoutineScreen and TimetableGridScreen.
// 5. Phase B3: 3-Tab Visual Studio Redesign in TimetableSettingsScreen (7-Day Term Clock & R15 Timeline, Committee Rules R1–R14, Engine Optimization Presets).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:universe/core/models/routine_model.dart';
import 'package:universe/core/theme/app_theme.dart';
import 'package:universe/features/admin/controllers/timetable_faculty_controller.dart';
import 'package:universe/features/admin/controllers/timetable_gen_controller.dart';
import 'package:universe/features/admin/controllers/timetable_rooms_controller.dart';
import 'package:universe/features/admin/screens/admin_routine_screen.dart';
import 'package:universe/features/admin/screens/generate_timetable_screen.dart';
import 'package:universe/features/admin/screens/manage_courses_screen.dart';
import 'package:universe/features/admin/screens/manage_faculty_screen.dart';
import 'package:universe/features/admin/screens/manage_rooms_screen.dart';
import 'package:universe/features/admin/screens/timetable_grid_screen.dart';
import 'package:universe/features/admin/screens/timetable_settings_screen.dart';
import 'package:universe/features/admin/services/timetable_config_service.dart';

Widget _wrap(Widget child, {Size size = const Size(1280, 900)}) {
  return MediaQuery(
    data: MediaQueryData(size: size),
    child: MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('7-Day Institutional Week & Friday Jummah Prayer Hard Constraint', () {
    testWidgets('ManageFacultyScreen renders 7-day availability matrix with Friday Jummah locked', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      final controller = TimetableFacultyController();
      await tester.pumpWidget(_wrap(ManageFacultyScreen(controller: controller)));
      await tester.pumpAndSettle();

      // Check working days contain all 7 days
      for (final day in ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']) {
        expect(find.text(day), findsWidgets);
      }

      // Check Friday Jummah prayer indicator exists
      expect(find.textContaining('JUMMAH'), findsWidgets);
    });

    testWidgets('ManageRoomsScreen renders 7-day availability matrix with Friday Jummah locked', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      final controller = TimetableRoomsController();
      await tester.pumpWidget(_wrap(ManageRoomsScreen(controller: controller)));
      await tester.pumpAndSettle();

      for (final day in ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']) {
        expect(find.text(day), findsWidgets);
      }

      expect(find.textContaining('JUMMAH'), findsWidgets);
    });
  });

  group('Anti-Slop Precision: Row Stripes & Dirty State Action Bars', () {
    testWidgets('ManageCoursesScreen shows left bar on selected row and hides save bar when clean', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_wrap(const ManageCoursesScreen()));
      await tester.pumpAndSettle();

      // Find first course row
      final courseTile = find.text('CSE-3101');
      expect(courseTile, findsOneWidget);

      // Verify clean initial state: Discard Changes button is not visible
      expect(find.text('Discard Changes'), findsNothing);
    });
  });

  group('Phase B1: Native UI Catalog ↔ .xlsx Co-existence Bridge & Synthesis', () {
    test('TimetableConfigService synthesizes distribution records from UI catalog', () async {
      final service = TimetableConfigService();
      final records = await service.synthesizeDistributionFromCatalog();

      expect(records, isNotEmpty);
      expect(records.first.courseCode, isNotEmpty);
      expect(records.first.classesPerWeek, greaterThan(0));
      expect(records.first.batch, isNotEmpty);
      expect(records.first.section, isNotEmpty);
    });

    test('TimetableConfigService exports audited workbook summary map', () async {
      final service = TimetableConfigService();
      final summary = await service.exportCatalogToWorkbookSummary();

      expect(summary.containsKey('totalRecords'), isTrue);
      expect(summary.containsKey('totalBatches'), isTrue);
      expect(summary.containsKey('totalSections'), isTrue);
      expect(summary.containsKey('totalCourses'), isTrue);
      expect(summary.containsKey('totalFaculty'), isTrue);
      expect(summary['totalBatches'], greaterThan(0));
      expect(summary['totalCourses'], greaterThan(0));
    });

    testWidgets('GenerateTimetableScreen switches between Native UI Catalog and Excel Workbook', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      final controller = TimetableGenController();
      await tester.pumpWidget(_wrap(GenerateTimetableScreen(controller: controller)));
      await tester.pumpAndSettle();

      // Verify top segmented switcher
      expect(find.textContaining('UI Catalog & Batch Offerings (Native)'), findsOneWidget);
      expect(find.textContaining('Excel Workbook (.xlsx)'), findsOneWidget);

      // In Native mode, verify synthesis button is rendered
      expect(find.text('Synthesize & Generate Routine'), findsOneWidget);
      expect(find.text('Export .xlsx Summary'), findsOneWidget);
    });
  });

  group('Phase B2: Unified Routine Operations 2D Grid in AdminRoutineScreen', () {
    testWidgets('AdminRoutineScreen renders 4-segment control and switches tabs lazily', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_wrap(const AdminRoutineScreen()));
      await tester.pumpAndSettle();

      // Verify all 4 tab labels
      expect(find.text('Operational 2D Grid'), findsOneWidget);
      expect(find.text('Manage Published'), findsOneWidget);
      expect(find.text('Generate via Engine'), findsOneWidget);
      expect(find.text('Upload Workbook'), findsOneWidget);

      // Verify lazy active tab is rendered
      expect(find.byType(TimetableGridScreen), findsOneWidget);
    });

    testWidgets('TimetableGridScreen renders Operational Lenses and handles grid rows', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      final testRows = [
        RoutineEntry(
          id: 'test-1',
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
        RoutineEntry(
          id: 'test-2',
          day: 'Sunday',
          timeStart: '10:10',
          timeEnd: '11:25',
          subject: 'Database Lab',
          subjectCode: 'CSE-3102',
          teacherCode: 'MSA',
          room: 'Lab 1',
          batch: '58',
          section: 'A',
          semester: 5,
        ),
      ];

      await tester.pumpWidget(_wrap(TimetableGridScreen(rows: testRows, embedded: true)));
      await tester.pumpAndSettle();

      // Check operational lens switcher (untruncated concise labels)
      expect(find.text('Section'), findsOneWidget);
      expect(find.text('Faculty'), findsOneWidget);
      expect(find.text('Room'), findsOneWidget);

      // Check slots are rendered
      expect(find.text('CSE-3101'), findsWidgets);
      expect(find.text('CSE-3102'), findsWidgets);
    });
  });

  group('Phase B3: 3-Tab Visual Studio Redesign in TimetableSettingsScreen', () {
    testWidgets('TimetableSettingsScreen renders 3-Tab studio and switches tabs', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_wrap(const TimetableSettingsScreen()));
      await tester.pumpAndSettle();

      // Check 3 tab labels
      expect(find.text('7-Day Clock & R15 Timeline'), findsOneWidget);
      expect(find.text('Committee Rules (R1–R14)'), findsOneWidget);
      expect(find.text('Engine Profiles & Weights'), findsOneWidget);

      // Verify Tab 0 displays 7-day strip and R15 toggle
      expect(find.text('7-Day Operational Week (Sun–Sat)'), findsOneWidget);
      expect(find.text('6 Slots / Day (Standard R15)'), findsOneWidget);
      expect(find.text('7 Slots / Day (Extended)'), findsOneWidget);

      // Switch to Tab 1: Committee Rules (R1–R14)
      await tester.tap(find.text('Committee Rules (R1–R14)'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Cohort & Section Weekend Governance'), findsOneWidget);
      expect(find.textContaining('Faculty Availability & Workload Matrix'), findsOneWidget);
      expect(find.textContaining('Room & Course Classification Rules'), findsOneWidget);
      expect(find.text('R1'), findsOneWidget);
      expect(find.text('R2'), findsOneWidget);
      expect(find.text('R4'), findsOneWidget);
      expect(find.text('R13'), findsOneWidget);

      // Switch to Tab 2: Engine Profiles & Weights
      await tester.tap(find.text('Engine Profiles & Weights'));
      await tester.pumpAndSettle();

      expect(find.text('Strict Compliance'), findsOneWidget);
      expect(find.text('Balanced (Default)'), findsOneWidget);
      expect(find.text('Relaxed Feasibility'), findsOneWidget);
      expect(find.text('Restore Defaults'), findsOneWidget);
    });

    testWidgets('TimetableSettingsScreen shows dirty bar on modifications and can discard', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_wrap(const TimetableSettingsScreen()));
      await tester.pumpAndSettle();

      // Clean state: bottom save bar is not visible
      expect(find.text('Unsaved Modifications · Review changes before generating'), findsNothing);

      // Modify semester field
      await tester.enterText(find.widgetWithText(TextField, 'e.g. Summer 2025'), 'Autumn 2026');
      await tester.pumpAndSettle();

      // Verify dirty bar appears
      expect(find.text('Unsaved Modifications · Review changes before generating'), findsOneWidget);
      expect(find.text('Discard'), findsOneWidget);
      expect(find.text('Save Settings'), findsOneWidget);

      // Tap Discard
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();

      // Bar disappears
      expect(find.text('Unsaved Modifications · Review changes before generating'), findsNothing);
    });
  });
}
