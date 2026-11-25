// PHASE A: Comprehensive test suite for Admin Core Catalog & Entity CRUD Overhaul
// (Courses, Batches & Sections, Faculty, and Rooms)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:universe/core/models/admin_catalog_models.dart';
import 'package:universe/core/models/timetable_config_model.dart';
import 'package:universe/core/theme/app_theme.dart';
import 'package:universe/features/admin/controllers/batches_controller.dart';
import 'package:universe/features/admin/controllers/courses_controller.dart';
import 'package:universe/features/admin/controllers/timetable_faculty_controller.dart';
import 'package:universe/features/admin/controllers/timetable_rooms_controller.dart';
import 'package:universe/features/admin/screens/manage_batches_screen.dart';
import 'package:universe/features/admin/screens/manage_courses_screen.dart';
import 'package:universe/features/admin/screens/manage_faculty_screen.dart';
import 'package:universe/features/admin/screens/manage_rooms_screen.dart';
import 'package:universe/features/admin/services/timetable_config_service.dart';
import 'package:universe/core/models/routine_model.dart';
import 'package:universe/features/auth/controllers/auth_controller.dart';
import 'package:universe/features/dashboard/controllers/student_dashboard_controller.dart';
import 'package:universe/features/teacher/controllers/teacher_dashboard_controller.dart';

class FakeAuth extends ChangeNotifier implements AuthController {
  FakeAuth({required this.role, required Map<String, dynamic> profileMap})
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

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('Phase A — CatalogCourse Model & R12/R13 Rules', () {
    test('Rule R12: Sessional course meeting derivation and badges', () {
      const lab15 = CatalogCourse(
        id: 'c1',
        code: 'CSE-3102',
        title: 'Database Lab',
        credits: 1.5,
        courseType: 'sessional',
        category: 'CSE',
      );
      expect(lab15.defaultWeeklyMeetings, 2);
      expect(lab15.isR13SingleDayBlock, isFalse);
      expect(lab15.r12OrR13BadgeLabel, 'R12 · 2 Lab Slots/Wk');

      const lab20 = CatalogCourse(
        id: 'c2',
        code: 'CSE-4102',
        title: 'Advanced AI Lab',
        credits: 2.0,
        courseType: 'sessional',
        category: 'CSE',
      );
      expect(lab20.defaultWeeklyMeetings, 3);
      expect(lab20.r12OrR13BadgeLabel, 'R12 · 3 Lab Slots/Wk (2 Consec Pref)');
    });

    test('Rule R13: 1-2 Cr CSE Theory single-day block derivation and badge', () {
      const cseTheory2 = CatalogCourse(
        id: 'c3',
        code: 'CSE-2101',
        title: 'Digital Logic Design',
        credits: 2.0,
        courseType: 'theory',
        category: 'CSE',
      );
      expect(cseTheory2.defaultWeeklyMeetings, 2);
      expect(cseTheory2.isR13SingleDayBlock, isTrue);
      expect(cseTheory2.r12OrR13BadgeLabel, 'R13 · 1-Day 2-Slot Block');

      const cseTheory3 = CatalogCourse(
        id: 'c4',
        code: 'CSE-3101',
        title: 'Database Systems',
        credits: 3.0,
        courseType: 'theory',
        category: 'CSE',
      );
      expect(cseTheory3.defaultWeeklyMeetings, 3);
      expect(cseTheory3.isR13SingleDayBlock, isFalse);
      expect(cseTheory3.r12OrR13BadgeLabel, 'Standard 3x/Wk');

      const gedTheory2 = CatalogCourse(
        id: 'c5',
        code: 'GED-1101',
        title: 'Bangladesh Studies',
        credits: 2.0,
        courseType: 'theory',
        category: 'GED',
      );
      expect(gedTheory2.defaultWeeklyMeetings, 2);
      // Only CSE theory qualifies for R13 single-day block
      expect(gedTheory2.isR13SingleDayBlock, isFalse);
    });

    test('CatalogCourse JSON serialization round-trip', () {
      const course = CatalogCourse(
        id: 'course-test',
        code: 'CSE-3101',
        title: 'Database Systems',
        credits: 3.0,
        courseType: 'theory',
        category: 'CSE',
        companionCourseCode: 'CSE-3102',
        prerequisiteCodes: ['CSE-2101'],
        preferredRoomClassification: RoomClassification.lectureGallery,
        isRetake: false,
        isActive: true,
      );

      final map = course.toMap();
      final restored = CatalogCourse.fromMap(map);
      expect(restored.code, 'CSE-3101');
      expect(restored.companionCourseCode, 'CSE-3102');
      expect(restored.prerequisiteCodes, ['CSE-2101']);
      expect(restored.preferredRoomClassification, RoomClassification.lectureGallery);
    });
  });

  group('Phase A — CohortBatch & Offering Models & R1/R2 Rules', () {
    test('Rule R1: Consecutive weekend validation for sections across all 7 days', () {
      const allSevenPairs = [
        ['Sunday', 'Monday'],
        ['Monday', 'Tuesday'],
        ['Tuesday', 'Wednesday'],
        ['Wednesday', 'Thursday'],
        ['Thursday', 'Friday'],
        ['Friday', 'Saturday'],
        ['Saturday', 'Sunday'],
      ];

      for (var i = 0; i < allSevenPairs.length; i++) {
        final pair = allSevenPairs[i];
        final batch = CohortBatch(
          id: 'b-$i',
          batchName: 'Batch $i',
          semesterLabel: '1st Semester',
          sections: ['A'],
          sectionWeekends: {'A': pair},
        );
        expect(batch.satisfiesR1ConsecutiveWeekend('A'), isTrue,
            reason: '${pair.join("+")} must be a valid consecutive weekend in 7-day cycle');
      }

      const batchWithSplitWeekends = CohortBatch(
        id: 'b-split',
        batchName: 'Batch Split',
        semesterLabel: '3rd Semester',
        sections: ['A'],
        sectionWeekends: {
          'A': ['Friday', 'Sunday'], // Non-consecutive split
        },
      );
      expect(batchWithSplitWeekends.satisfiesR1ConsecutiveWeekend('A'), isFalse);
      expect(batchWithSplitWeekends.satisfiesAllR1Weekends, isFalse);
    });

    test('Rule R2: Days-off parity across sections within batch', () {
      const balancedBatch = CohortBatch(
        id: 'b1',
        batchName: 'Batch 58',
        semesterLabel: '5th Semester',
        sections: ['A', 'B', 'C'],
        sectionWeeklyDaysOffCount: {'A': 2, 'B': 2, 'C': 3}, // max variance = 1
      );
      expect(balancedBatch.daysOffVariance, 1);
      expect(balancedBatch.satisfiesR2Parity, isTrue);

      const unbalancedBatch = CohortBatch(
        id: 'b2',
        batchName: 'Batch 59',
        semesterLabel: '4th Semester',
        sections: ['A', 'B'],
        sectionWeeklyDaysOffCount: {'A': 1, 'B': 3}, // max variance = 2
      );
      expect(unbalancedBatch.daysOffVariance, 2);
      expect(unbalancedBatch.satisfiesR2Parity, isFalse);
    });

    test('CohortBatch offerings and total credits offered calculation', () {
      const batch = CohortBatch(
        id: 'b1',
        batchName: 'Batch 58',
        semesterLabel: '5th Semester',
        sections: ['A', 'B'],
        combinedSections: ['A+B'],
        offerings: [
          BatchCourseOffering(
            courseCode: 'CSE-3101',
            targetSection: 'A',
            credits: 3.0,
            primaryTeacherAcronym: 'MSR',
          ),
          BatchCourseOffering(
            courseCode: 'CSE-3102',
            targetSection: 'A',
            credits: 1.5,
            primaryTeacherAcronym: 'RH',
          ),
          BatchCourseOffering(
            courseCode: 'GED-1101',
            targetSection: 'A+B', // Joint Section
            credits: 2.0,
            primaryTeacherAcronym: 'TI',
          ),
        ],
      );

      expect(batch.totalCreditsOffered, 6.5);
      expect(batch.combinedSections, ['A+B']);
    });
  });

  group('Phase A — TimetableRoom Extensions & Classifications', () {
    test('Room classifications and exclusive lab bindings (R11)', () {
      const physicsLab = TimetableRoom(
        id: 'r-phy',
        name: 'Physics Lab 1',
        capacity: 40,
        isActive: true,
        inActiveSemesterPool: true,
        classification: RoomClassification.physicsLab,
        boundCourseCodes: ['PHY-1102'],
      );

      expect(physicsLab.roomClassification, RoomClassification.physicsLab);
      expect(physicsLab.boundCourseCodes, ['PHY-1102']);
      expect(physicsLab.inActiveSemesterPool, isTrue);

      const classroom = TimetableRoom(
        id: 'r-302',
        name: 'Room 302',
        capacity: 65,
        isActive: true,
      );
      // Unspecified classification defaults to generalClassroom
      expect(classroom.roomClassification, RoomClassification.generalClassroom);
      expect(classroom.inActiveSemesterPool, isTrue);
    });
  });

  group('Phase A — TimetableFaculty Extensions & Rules R4-R9', () {
    test('Faculty employment types and R7 off-day violation checks', () {
      const permanentValid = TimetableFaculty(
        id: 'f1',
        acronym: 'MSR',
        fullName: 'Prof. Dr. M. S. Rahman',
        dept: 'CSE',
        designation: 'Professor',
        employmentType: 'permanent',
        offDays: ['Friday', 'Saturday'], // 2 days: valid
      );
      expect(permanentValid.isPermanent, isTrue);
      expect(permanentValid.isAdjunct, isFalse);
      expect(permanentValid.isR7Violation, isFalse);

      const permanentViolation = TimetableFaculty(
        id: 'f2',
        acronym: 'XX',
        fullName: 'Test Faculty',
        dept: 'CSE',
        designation: 'Lecturer',
        employmentType: 'permanent',
        offDays: ['Friday'], // 1 day: violation of R7 (needs 2-3)
      );
      expect(permanentViolation.isR7Violation, isTrue);

      const adjunctTeacher = TimetableFaculty(
        id: 'f3',
        acronym: 'SUST1',
        fullName: 'Dr. Adjunct',
        dept: 'CSE',
        designation: 'Adjunct Professor',
        employmentType: 'adjunct',
        isSustAdjunctExplicit: true,
        sustCompactnessMode: 'Before Break',
        offDays: ['Sunday', 'Monday', 'Tuesday'],
      );
      expect(adjunctTeacher.isAdjunct, isTrue);
      expect(adjunctTeacher.isSustAdjunct, isTrue);
      expect(adjunctTeacher.sustCompactnessMode, 'Before Break');
      // Adjuncts are not flagged as R7 violations for having 3 off days
      expect(adjunctTeacher.isR7Violation, isFalse);
    });
  });

  group('Phase A — Service & Controllers In-Memory Flow', () {
    late TimetableConfigService service;
    late CoursesController coursesController;
    late BatchesController batchesController;
    late TimetableFacultyController facultyController;
    late TimetableRoomsController roomsController;

    setUp(() {
      service = TimetableConfigService();
      coursesController = CoursesController(service: service);
      batchesController = BatchesController(service: service);
      facultyController = TimetableFacultyController(service: service);
      roomsController = TimetableRoomsController(service: service);
    });

    test('CoursesController loads, filters, and performs reciprocal companion linking', () async {
      await coursesController.load();
      expect(coursesController.allCourses.isNotEmpty, isTrue);

      // Search
      coursesController.setQuery('Database');
      expect(coursesController.filteredCourses.any((c) => c.code.contains('CSE-3101')), isTrue);
      coursesController.setQuery('');

      // Filter by category
      coursesController.setCategoryFilter('GED');
      expect(coursesController.filteredCourses.every((c) => c.category == 'GED'), isTrue);
      coursesController.setCategoryFilter('All');

      // Save course with reciprocal companion update
      const newTheory = CatalogCourse(
        id: 'test-theory',
        code: 'CSE-5501',
        title: 'Quantum Computing Theory',
        credits: 3.0,
        courseType: 'theory',
        category: 'CSE',
        companionCourseCode: 'CSE-5502',
      );
      const newLab = CatalogCourse(
        id: 'test-lab',
        code: 'CSE-5502',
        title: 'Quantum Computing Lab',
        credits: 1.5,
        courseType: 'sessional',
        category: 'CSE',
      );

      await coursesController.saveCourse(newTheory);
      await coursesController.saveCourse(newLab);

      // Now save theory linking to lab: service should link reciprocally
      await coursesController.saveCourse(newTheory.copyWith(companionCourseCode: 'CSE-5502'));
      final updatedLab = coursesController.allCourses.firstWhere((c) => c.code == 'CSE-5502');
      expect(updatedLab.companionCourseCode, 'CSE-5501');

      // Delete course
      await coursesController.deleteCourse('test-theory');
      expect(coursesController.allCourses.any((c) => c.id == 'test-theory'), isFalse);
    });

    test('BatchesController creates batch, adds joint sections, and calculates R1/R2', () async {
      await batchesController.load();
      expect(batchesController.allBatches.isNotEmpty, isTrue);

      final newBatch = CohortBatch(
        id: 'batch-test',
        batchName: 'Batch 62',
        semesterLabel: '1st Semester',
        sections: const ['A', 'B', 'C'],
        combinedSections: const ['B+C'],
        sectionWeekends: const {
          'A': ['Friday', 'Saturday'],
          'B': ['Friday', 'Saturday'],
          'C': ['Friday', 'Saturday'],
        },
        sectionWeeklyDaysOffCount: const {'A': 2, 'B': 2, 'C': 2},
      );

      await batchesController.saveBatch(newBatch);
      expect(batchesController.allBatches.any((b) => b.id == 'batch-test'), isTrue);

      final saved = batchesController.allBatches.firstWhere((b) => b.id == 'batch-test');
      expect(saved.combinedSections, ['B+C']);
      expect(saved.satisfiesR2Parity, isTrue);

      await batchesController.deleteBatch('batch-test');
      expect(batchesController.allBatches.any((b) => b.id == 'batch-test'), isFalse);
    });

    test('TimetableFacultyController and TimetableRoomsController save & delete', () async {
      await facultyController.load();
      expect(facultyController.allFaculty.isNotEmpty, isTrue);

      const testFaculty = TimetableFaculty(
        id: 'fac-new',
        acronym: 'TEST',
        fullName: 'Test Faculty Member',
        dept: 'CSE',
        designation: 'Lecturer',
        employmentType: 'permanent',
        offDays: ['Friday', 'Saturday'],
      );

      await facultyController.saveFaculty(testFaculty);
      expect(facultyController.allFaculty.any((f) => f.id == 'fac-new'), isTrue);

      await facultyController.deleteFaculty('fac-new');
      expect(facultyController.allFaculty.any((f) => f.id == 'fac-new'), isFalse);

      await roomsController.load();
      expect(roomsController.rooms.isNotEmpty, isTrue);

      const testRoom = TimetableRoom(
        id: 'room-new',
        name: 'Lab 501',
        capacity: 45,
        isActive: true,
        classification: RoomClassification.cseComputerLab,
      );

      await roomsController.saveRoom(testRoom);
      expect(roomsController.rooms.any((r) => r.id == 'room-new'), isTrue);

      await roomsController.delete('room-new');
      expect(roomsController.rooms.any((r) => r.id == 'room-new'), isFalse);
    });
  });

  group('Phase A — Screen Responsive Rendering & Overflows', () {
    testWidgets('ManageCoursesScreen renders at 1440x900 (55/45 split) without overflow',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      final service = TimetableConfigService();
      final controller = CoursesController(service: service);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: ManageCoursesScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Course Catalog'), findsOneWidget);
      expect(find.text('Search Courses'), findsOneWidget);
      expect(find.byType(ListView), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ManageCoursesScreen renders at 390x844 mobile without overflow',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      final service = TimetableConfigService();
      final controller = CoursesController(service: service);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: ManageCoursesScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Course Catalog'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ManageBatchesScreen renders at 1440x900 with Joint Sections without overflow',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      final service = TimetableConfigService();
      final controller = BatchesController(service: service);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: ManageBatchesScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Batches & Sections'), findsOneWidget);
      expect(find.textContaining('Sections (3 Active)'), findsOneWidget);
      expect(find.textContaining('Combined / Joint Sections'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ManageBatchesScreen renders at 390x844 mobile without overflow',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      final service = TimetableConfigService();
      final controller = BatchesController(service: service);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: ManageBatchesScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Batches & Sections'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ManageFacultyScreen renders at 1440x900 with R4-R9 matrix without overflow',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      final service = TimetableConfigService();
      final controller = TimetableFacultyController(service: service);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: ManageFacultyScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Faculty'), findsOneWidget);
      expect(find.text('CORE IDENTITY'), findsOneWidget);
      expect(find.text('CATEGORY & CROSS-DEPT FLAGS (R4–R9)'), findsOneWidget);
      // Friday Jummah Prayer Window (friday_no_p4) hard block
      expect(find.text('JUMMAH'), findsWidgets);
      // Full 7-day week headers present
      expect(find.text('Fri'), findsWidgets);
      expect(find.text('Sat'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ManageFacultyScreen renders at 390x844 mobile without overflow',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      final service = TimetableConfigService();
      final controller = TimetableFacultyController(service: service);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: ManageFacultyScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Faculty'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ManageRoomsScreen renders at 1440x900 with R10/R11 matrix without overflow',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      final service = TimetableConfigService();
      final controller = TimetableRoomsController(service: service);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: ManageRoomsScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Room Pools'), findsOneWidget);
      expect(find.text('ROOM CLASSIFICATION & RULES R10/R11/R14'), findsOneWidget);
      // Friday Jummah Prayer Window (friday_no_p4) hard block
      expect(find.text('JUMMAH'), findsWidgets);
      // 7-day week headers
      expect(find.text('Fri'), findsWidgets);
      expect(find.text('Sat'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ManageRoomsScreen renders at 390x844 mobile without overflow',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      final service = TimetableConfigService();
      final controller = TimetableRoomsController(service: service);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: ManageRoomsScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Room Pools'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Phase A — 7-Day Week & Dynamic Weekend Dashboard Controllers', () {
    test('StudentDashboardController resolves dynamic off-day and 7-day upcoming class', () async {
      final sunday = DateTime(2026, 11, 8, 9, 0); // Sunday
      final controller = StudentDashboardController(
        authController: FakeAuth(role: 'student', profileMap: {'id': 's1', 'batch': '58', 'section': 'A'}),
        clock: () => sunday,
        routineLoader: (_, __) async => [
          RoutineEntry.fromMap({
            'id': 'r1',
            'day': 'Monday',
            'time_start': '10:00',
            'time_end': '10:50',
            'batch': '58',
            'section': 'A',
            'subject': 'CSE-3101',
            'subject_code': 'CSE-3101',
            'subject_name': 'Database Systems',
            'teacher_code': 'MSR',
            'room': '302',
          }),
          RoutineEntry.fromMap({
            'id': 'r2',
            'day': 'Saturday',
            'time_start': '09:00',
            'time_end': '10:40',
            'batch': '58',
            'section': 'A',
            'subject': 'CSE-3102',
            'subject_code': 'CSE-3102',
            'subject_name': 'Database Lab',
            'teacher_code': 'MSR',
            'room': 'LAB-1',
          }),
        ],
      );

      await controller.load();
      // Sunday has no classes -> dynamic section off-day
      expect(controller.todaysClasses, isEmpty);
      expect(controller.isWeekendToday, isTrue);
      expect(controller.isClassDayToday, isFalse);

      // Finds next upcoming class across 7 days (Monday)
      final upcoming = controller.nextUpcomingClass;
      expect(upcoming, isNotNull);
      expect(upcoming!.dayName, 'Monday');
      expect(upcoming.daysAhead, 1);
      expect(upcoming.entry.subject, 'CSE-3101');
    });

    test('TeacherDashboardController resolves dynamic off-day and 7-day upcoming session', () async {
      final friday = DateTime(2026, 11, 13, 10, 0); // Friday
      final controller = TeacherDashboardController(
        authController: FakeAuth(role: 'teacher', profileMap: {'id': 't1', 'teacher_code': 'MSR'}),
        clock: () => friday,
        routineLoader: (_) async => [
          RoutineEntry.fromMap({
            'id': 'r3',
            'day': 'Saturday',
            'time_start': '09:00',
            'time_end': '10:40',
            'batch': '58',
            'section': 'A',
            'subject': 'CSE-3102',
            'subject_code': 'CSE-3102',
            'subject_name': 'Database Lab',
            'teacher_code': 'MSR',
            'room': 'LAB-1',
          }),
        ],
      );

      await controller.load();
      // Friday has no classes for this teacher -> dynamic off-day
      expect(controller.todaysClasses, isEmpty);
      expect(controller.isWeekendToday, isTrue);

      // Finds Saturday teaching session
      final upcoming = controller.nextUpcomingClass;
      expect(upcoming, isNotNull);
      expect(upcoming!.dayName, 'Saturday');
      expect(upcoming.daysAhead, 1);
    });
  });
}
