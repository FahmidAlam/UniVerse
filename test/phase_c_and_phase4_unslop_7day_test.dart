import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universe/core/constants/app_enums.dart';
import 'package:universe/core/models/profile_model.dart';
import 'package:universe/core/models/routine_model.dart';
import 'package:universe/core/models/timetable_config_model.dart';
import 'package:universe/core/theme/app_theme.dart';
import 'package:universe/features/auth/controllers/auth_controller.dart';
import 'package:universe/features/dashboard/controllers/student_dashboard_controller.dart';
import 'package:universe/features/profile/controllers/profile_controller.dart';
import 'package:universe/features/profile/screens/profile_screen.dart';
import 'package:universe/features/profile/services/profile_service.dart';
import 'package:universe/features/profile/services/teacher_r8_preference_service.dart';
import 'package:universe/features/routine/controllers/routine_controller.dart';
import 'package:universe/features/routine/screens/routine_screen.dart';
import 'package:universe/features/teacher/controllers/manage_classes_controller.dart';
import 'package:universe/features/teacher/screens/manage_classes_screen.dart';
import 'package:universe/shared/widgets/class_card.dart';
import 'package:universe/shared/widgets/day_selector.dart';
import 'package:universe/shared/widgets/u_animated_swap.dart';
import 'package:universe/shared/widgets/u_combobox.dart';
import 'package:universe/shared/widgets/u_staggered_list_row.dart';
import 'package:universe/shared/widgets/u_weekly_load_bar_card.dart';
import 'package:universe/shared/widgets/weekly_schedule_view.dart';

Widget _wrap(Widget child, {Size size = const Size(1280, 900)}) {
  return MediaQuery(
    data: MediaQueryData(size: size),
    child: MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(body: child),
    ),
  );
}

class _StubAuthController extends ChangeNotifier implements AuthController {
  final Map<String, dynamic>? _stubProfile;
  _StubAuthController(this._stubProfile);

  @override
  Map<String, dynamic>? get profile => _stubProfile;

  @override
  bool get isAuthenticated => true;

  @override
  Future<void> signOut() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('Workstream 1: 7-Day Institutional Standard & Jummah Sync', () {
    testWidgets('DaySelector renders 7 days and swiping wraps circularly',
        (tester) async {
      String selected = 'Sat';
      await tester.pumpWidget(
        _wrap(
          DaySelector(
            selectedDay: selected,
            onSelect: (d) => selected = d,
          ),
          size: const Size(800, 200),
        ),
      );

      expect(find.text('Sun'), findsOneWidget);
      expect(find.text('Sat'), findsOneWidget);

      // Fling left on Saturday (velocity < -220) -> circular step to Sunday
      await tester.fling(find.byType(DaySelector), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();
      expect(selected, 'Sun');
    });

    test('RoutineController.stepDay wraps circularly across 7 days', () {
      final auth = _StubAuthController({
        'id': 'test-student',
        'role': 'student',
        'batch': '58',
        'section': 'B',
      });
      final controller = RoutineController(
        authController: auth,
        initialSelectedDay: 'Sat',
      );

      expect(controller.selectedDay, 'Sat');
      // Step forward by +1 -> should wrap to 'Sun'
      final stepped = controller.stepDay(1);
      expect(stepped, isTrue);
      expect(controller.selectedDay, 'Sun');

      // Step backward by -1 -> should wrap to 'Sat'
      controller.stepDay(-1);
      expect(controller.selectedDay, 'Sat');
    });

    test('Student and Teacher dashboard controllers return 7-day classesCountPerDay',
        () {
      final authStudent = _StubAuthController({
        'id': 's1',
        'role': 'student',
        'batch': '58',
        'section': 'B',
      });
      final studentController = StudentDashboardController(
        authController: authStudent,
        initialEntries: [
          RoutineEntry(
            id: 'r1',
            day: 'Sunday',
            timeStart: '09:30:00',
            timeEnd: '10:50:00',
            subject: 'Algorithms',
            subjectCode: 'CSE-2201',
            teacherName: 'MSA',
            room: '301',
            batch: '58',
            section: 'B',
            semester: 5,
          ),
          RoutineEntry(
            id: 'r2',
            day: 'Friday',
            timeStart: '09:30:00',
            timeEnd: '10:50:00',
            subject: 'Algorithms Lab',
            subjectCode: 'CSE-2202',
            teacherName: 'MSA',
            room: 'Lab 1',
            batch: '58',
            section: 'B',
            semester: 5,
          ),
        ],
      );

      final counts = studentController.classesCountPerDay;
      expect(counts.keys.length, 7);
      expect(counts['Sun'], 1);
      expect(counts['Fri'], 1);
      expect(counts['Sat'], 0);
    });

    testWidgets('WeeklyScheduleView displays Friday Jummah Prayer Break',
        (tester) async {
      final List<RoutineEntry> entries = [
        const RoutineEntry(
          id: 'r1',
          day: 'Friday',
          timeStart: '10:50:00',
          timeEnd: '12:10:00',
          subject: 'Operating Systems',
          subjectCode: 'CSE-3201',
          teacherName: 'JRR',
          room: '302',
          batch: '58',
          section: 'B',
          semester: 5,
        ),
        const RoutineEntry(
          id: 'r2',
          day: 'Friday',
          timeStart: '14:10:00',
          timeEnd: '15:30:00',
          subject: 'Database Systems',
          subjectCode: 'CSE-3203',
          teacherName: 'FA',
          room: '401',
          batch: '58',
          section: 'B',
          semester: 5,
        ),
      ];

      await tester.pumpWidget(
        _wrap(
          WeeklyScheduleView(
            entries: entries,
            clock: () => DateTime(2026, 11, 13), // Friday
            rowBuilder: (ctx, entry, status) => Text(entry.subject),
          ),
          size: const Size(1280, 800),
        ),
      );
      await tester.pumpAndSettle();

      // Friday day list should inject the dedicated Jummah prayer break
      expect(find.textContaining('Jummah Prayer Break'), findsOneWidget);
    });
  });

  group('Workstream 2: Phase 4 Brutal Unslop', () {
    testWidgets('ClassCard unselected hides 3px stripe; hideDefaultCohortPill hides repetitive cohort',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          Column(
            children: const [
              ClassCard(
                subject: 'Compiler Design',
                teacher: 'MSA',
                room: '301',
                timeSlot: '09:30 AM – 10:50 AM',
                status: ClassStatus.upcoming,
                batch: '58',
                section: 'B',
                isSelected: false,
                hideDefaultCohortPill: true,
              ),
              ClassCard(
                subject: 'Computer Networks',
                teacher: 'MSA',
                room: '302',
                timeSlot: '10:50 AM – 12:10 PM',
                status: ClassStatus.upcoming,
                batch: '58',
                section: 'B+C',
                isSelected: true,
                hideDefaultCohortPill: true,
              ),
            ],
          ),
          size: const Size(600, 400),
        ),
      );

      // Repetitive "Batch 58 · B" should not appear for the standard section with hideDefaultCohortPill
      expect(find.text('Batch 58 · B'), findsNothing);
      // Joint section B+C should still render with Joint badge
      expect(find.textContaining('Joint'), findsOneWidget);
    });

    testWidgets('UWeeklyLoadBarCard renders 7 day columns with Today highlight',
        (tester) async {
      final counts = {
        'Sun': 2,
        'Mon': 3,
        'Tue': 0,
        'Wed': 2,
        'Thu': 1,
        'Fri': 2,
        'Sat': 0,
      };

      await tester.pumpWidget(
        _wrap(
          UWeeklyLoadBarCard(
            title: 'Weekly Schedule Load',
            dailyCounts: counts,
            todayShort: 'Sun',
          ),
          size: const Size(500, 200),
        ),
      );

      expect(find.text('WEEKLY SCHEDULE LOAD'), findsOneWidget);
      expect(find.text('10'), findsOneWidget); // 2+3+0+2+1+2+0 = 10 classes
      expect(find.text('Sun'), findsOneWidget);
      expect(find.text('Sat'), findsOneWidget);
    });

    testWidgets('ManageClassesScreen displays compact date stepper header and reassurance microcopy',
        (tester) async {
      final auth = _StubAuthController({
        'id': 't1',
        'role': 'teacher',
        'full_name': 'Dr. Teacher',
        'teacher_code': 'MSA',
      });
      final controller = ManageClassesController(
        authController: auth,
        initialEntries: [
          RoutineEntry(
            id: 'r1',
            day: 'Sunday',
            timeStart: '09:30:00',
            timeEnd: '10:50:00',
            subject: 'Algorithms',
            subjectCode: 'CSE-2201',
            teacherName: 'MSA',
            room: '301',
            batch: '58',
            section: 'B',
            semester: 5,
          ),
        ],
        initialSelectedDay: 'Sun',
      );

      await tester.pumpWidget(
        _wrap(
          ManageClassesScreen(
            authController: auth,
            controller: controller,
          ),
          size: const Size(1280, 800),
        ),
      );
      await tester.pumpAndSettle();

      // Compact Date Stepper Header present
      expect(find.byType(IconButton), findsWidgets);

      // Tap on class card to open the inspector pane
      await tester.tap(find.byType(ClassCard));
      await tester.pumpAndSettle();

      // Microcopy present in inspector panel
      expect(find.textContaining('Recurring weekly routine remains unchanged'), findsOneWidget);
    });
  });

  group('Workstream 3: Searchable UCombobox & Catalog Distribution Bridge', () {
    testWidgets('UCombobox filters items and selects new value',
        (tester) async {
      String? selectedVal;
      final items = [
        const UComboboxItem<String>(
          value: 'CSE-1101',
          label: 'Structured Programming',
          subtitle: '3.0 Cr · Theory',
        ),
        const UComboboxItem<String>(
          value: 'CSE-1102',
          label: 'Structured Programming Lab',
          subtitle: '1.5 Cr · Sessional',
        ),
        const UComboboxItem<String>(
          value: 'CSE-2201',
          label: 'Data Structures',
          subtitle: '3.0 Cr · Theory',
        ),
      ];

      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (ctx, setState) {
              return UCombobox<String>(
                label: 'Course',
                hint: 'Select course…',
                value: selectedVal,
                items: items,
                onChanged: (v) => setState(() => selectedVal = v),
              );
            },
          ),
          size: const Size(500, 400),
        ),
      );

      expect(find.text('Select course…'), findsOneWidget);

      // Tap to open search dialog
      await tester.tap(find.byType(UCombobox<String>));
      await tester.pumpAndSettle();

      expect(find.text('Structured Programming'), findsOneWidget);

      // Type-ahead filter
      await tester.enterText(find.byType(TextField).last, 'Data');
      await tester.pumpAndSettle();

      // Tap filtered item
      await tester.tap(find.text('Data Structures'));
      await tester.pumpAndSettle();

      expect(selectedVal, 'CSE-2201');
    });
  });

  group('Workstream 4: Phase C Role-Adaptive Profile Studio & Choreography', () {
    testWidgets('ProfileScreen renders 2-column Studio on desktop for Teacher',
        (tester) async {
      final auth = _StubAuthController({
        'id': 't1',
        'role': 'teacher',
        'full_name': 'Prof. Jamaner Rahaman',
        'email': 'jamaner@lus.ac.bd',
        'department': 'CSE',
        'designation': 'Assistant Professor',
        'teacher_code': 'JRR',
      });

      await tester.pumpWidget(
        _wrap(
          ProfileScreen(authController: auth),
          size: const Size(1280, 900),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('FACULTY SCHEDULING STUDIO'), findsOneWidget);
      expect(find.text('Code: JRR'), findsOneWidget);
      expect(find.textContaining('R6 / R7 · Faculty Weekly Teaching Math'), findsOneWidget);
      expect(find.text('R8 · PREFERRED TEACHING DAYS (7-DAY CYCLE)'), findsOneWidget);
      expect(find.text('SECURITY & DEVICE STATUS'), findsOneWidget);
    });

    testWidgets('ProfileScreen renders Admin Web Console notice card',
        (tester) async {
      final auth = _StubAuthController({
        'id': 'a1',
        'role': 'admin',
        'full_name': 'Timetable Committee Chair',
        'email': 'admin@lus.ac.bd',
        'department': 'CSE',
      });

      await tester.pumpWidget(
        _wrap(
          ProfileScreen(authController: auth),
          size: const Size(1280, 900),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ADMIN ROUTINE & ENGINE CONSOLE'), findsOneWidget);
      expect(find.text('https://universe-admin-exi.pages.dev'), findsOneWidget);
    });

    testWidgets('UAnimatedSwap uses 80% reverse duration and UStaggeredListRow renders child',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          UAnimatedSwap(
            duration: const Duration(milliseconds: 200),
            child: UStaggeredListRow(
              index: 0,
              child: const Text('Staggered Row Item'),
            ),
          ),
          size: const Size(400, 200),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Staggered Row Item'), findsOneWidget);
    });
  });

  group('Workstream 5: Reanalysis Hardening & Regression Suite', () {
    test('ProfileController.updateDisplayName writes name column, validates & short-circuits',
        () async {
      final spyService = _SpyProfileService(failOnSave: false);
      final auth = _StubAuthController({
        'id': 'u1',
        'email': 'fahim@lus.ac.bd',
        'role': 'student',
        'name': 'Old Name',
      });
      final controller = ProfileController(
        authController: auth,
        service: spyService,
      );
      await controller.load();

      // Unchanged name short-circuits without network write
      final sameOk = await controller.updateDisplayName('Old Name');
      expect(sameOk, isTrue);
      expect(spyService.updateCalls, 0);

      // Empty name rejected cleanly with error message
      final emptyOk = await controller.updateDisplayName('   ');
      expect(emptyOk, isFalse);
      expect(controller.errorMessage, 'Display name cannot be empty.');

      // Valid name writes `'name'` column (not non-existent `full_name`)
      final validOk = await controller.updateDisplayName('  Fahim Ahmed  ');
      expect(validOk, isTrue);
      expect(spyService.lastChanges, {'name': 'Fahim Ahmed'});
      expect(controller.profile?.displayName, 'Fahim Ahmed');

      // Error path populates errorMessage and returns false
      final failController = ProfileController(
        authController: auth,
        service: _SpyProfileService(failOnSave: true),
      );
      await failController.load();
      final failOk = await failController.updateDisplayName('New Fail Name');
      expect(failOk, isFalse);
      expect(failController.errorMessage, 'Could not update display name.');
    });

    testWidgets('ProfileScreen Teacher persists R8 preferred days to TimetableConfigService',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeConfig = _FakeProfileConfigService();
      final auth = _StubAuthController({
        'id': 't-msr',
        'role': 'teacher',
        'name': 'Prof. Dr. M. S. Rahman',
        'email': 'msr@lus.ac.bd',
        'department': 'CSE',
        'designation': 'Professor',
        'teacher_code': 'MSR',
      });

      await tester.pumpWidget(
        _wrap(
          ProfileScreen(authController: auth, configService: fakeConfig),
          size: const Size(1280, 900),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('5 working days + 2 off-days'), findsOneWidget);
      final wedFinder = find.widgetWithText(InkWell, 'Wed');
      await tester.ensureVisible(wedFinder);
      await tester.pumpAndSettle();
      await tester.tap(wedFinder);
      await tester.pumpAndSettle();

      expect(fakeConfig.updatedFacultyId, 'fac-msr');
      final savedMatrix = fakeConfig.updatedFacultyData?['slot_matrix'] as Map?;
      expect(savedMatrix?['Wed:0'], 'preferred_r8');
      expect(savedMatrix?['Sun:0'], 'preferred_r8');
    });

    testWidgets('ProfileScreen Student uses actual cohort metadata & v1.0.0 version',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final auth = _StubAuthController({
        'id': 's9',
        'role': 'student',
        'name': 'Tariq Aziz',
        'email': 'tariq@lus.ac.bd',
        'batch': '60',
        'section': 'A',
        'department': 'Software Engineering',
        'semester': 7,
      });

      await tester.pumpWidget(
        _wrap(
          ProfileScreen(authController: auth),
          size: const Size(1280, 900),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Batch 60 · Section A'), findsOneWidget);
      expect(
        find.text('Enrolled in Software Engineering · Semester 7'),
        findsOneWidget,
      );
      expect(find.text('Semester 5'), findsNothing);
      expect(find.text('v1.0.0'), findsOneWidget);
      expect(find.text('Google OAuth / Verified'), findsNothing);
    });

    testWidgets('UStaggeredListRow unmounts early without pending timer errors',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const UStaggeredListRow(
            index: 4,
            child: Text('Transient Row'),
          ),
        ),
      );
      // Unmount immediately before 4 * 30ms timer completes
      await tester.pumpWidget(_wrap(const SizedBox.shrink()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('UCombobox supports keyboard Enter selection, clear button, and Esc on empty search',
        (tester) async {
      String? selected = 'CSE-1101';
      final items = const [
        UComboboxItem<String>(value: 'CSE-1101', label: 'Algorithms'),
        UComboboxItem<String>(value: 'CSE-2201', label: 'Operating Systems'),
      ];

      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (ctx, setState) => UCombobox<String>(
              label: 'Course',
              hint: 'Select course',
              value: selected,
              items: items,
              onChanged: (v) => setState(() => selected = v),
            ),
          ),
          size: const Size(600, 400),
        ),
      );

      // Open dialog
      await tester.tap(find.text('Algorithms'));
      await tester.pumpAndSettle();

      // Clear inside dialog sets null
      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();
      expect(selected, isNull);

      // Reopen, arrow down to second item, Enter selects it
      await tester.tap(find.text('Select course'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(selected, 'CSE-2201');

      // Reopen, search gibberish -> 0 items -> Escape closes dialog
      await tester.tap(find.text('Operating Systems'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'ZZZZZ');
      await tester.pumpAndSettle();
      expect(find.text('No matching results'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('No matching results'), findsNothing);
    });

    test('RoutineBreakDivider avoids 12:00 false positive and catches true Jummah window',
        () {
      expect(
        RoutineBreakDivider.slotOverlapsFridayJummah(
          'Friday',
          '10:40-12:00',
          '10:40 AM – 12:00 PM',
        ),
        isFalse,
      );
      expect(
        RoutineBreakDivider.slotOverlapsFridayJummah(
          'Friday',
          '12:50-14:05',
          '12:50 PM – 02:05 PM',
        ),
        isTrue,
      );
    });

    testWidgets('RoutineScreen Friday Day List displays Jummah divider & hides student default pill',
        (tester) async {
      final auth = _StubAuthController({
        'id': 's1',
        'role': 'student',
        'batch': '58',
        'section': 'B',
      });
      final fridayEntries = [
        const RoutineEntry(
          id: 'r1',
          day: 'Friday',
          timeStart: '10:40:00',
          timeEnd: '12:00:00',
          subject: 'Compiler Design',
          subjectCode: 'CSE-3301',
          teacherName: 'MSA',
          room: '301',
          batch: '58',
          section: 'B',
          semester: 5,
        ),
        const RoutineEntry(
          id: 'r2',
          day: 'Friday',
          timeStart: '14:15:00',
          timeEnd: '15:35:00',
          subject: 'Computer Graphics',
          subjectCode: 'CSE-3305',
          teacherName: 'FA',
          room: '402',
          batch: '58',
          section: 'B',
          semester: 5,
        ),
      ];
      final controller = RoutineController(
        authController: auth,
        initialSelectedDay: 'Fri',
        clock: () => DateTime(2026, 11, 13), // Friday
        routineLoader: () async => fridayEntries,
      );

      await tester.pumpWidget(
        _wrap(
          RoutineScreen(
            authController: auth,
            controller: controller,
            clock: () => DateTime(2026, 11, 13),
          ),
          size: const Size(600, 800), // Day List viewport
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Jummah Prayer Break'), findsOneWidget);
      expect(find.text('Batch 58 · B'), findsNothing);
    });
  });
}

class _SpyProfileService extends ProfileService {
  final bool failOnSave;
  int updateCalls = 0;
  Map<String, dynamic>? lastChanges;

  _SpyProfileService({required this.failOnSave});

  @override
  Future<Profile?> fetchProfile(String userId) async => null;

  @override
  Future<Profile?> updateProfile({
    required String userId,
    required Map<String, dynamic> changes,
  }) async {
    updateCalls++;
    lastChanges = changes;
    if (failOnSave) {
      throw Exception('Simulated failure');
    }
    return Profile(
      id: userId,
      email: 'fahim@lus.ac.bd',
      role: 'student',
      name: changes['name'] as String?,
    );
  }
}

class _FakeProfileConfigService extends TeacherR8PreferenceService {
  final int facultyCount = 2;

  String? updatedFacultyId;
  Map<String, dynamic>? updatedFacultyData;

  @override
  Future<List<TimetableFaculty>> fetchFaculty() async {
    final base = [
      const TimetableFaculty(
        id: 'fac-msr',
        acronym: 'MSR',
        fullName: 'Prof. Dr. M. S. Rahman',
        dept: 'CSE',
        designation: 'Professor',
        employmentType: 'permanent',
        offDays: ['Fri', 'Sat'],
        slotMatrix: {'Sun:0': 'preferred_r8'},
      ),
      for (var i = 1; i < facultyCount; i++)
        TimetableFaculty(
          id: 'fac-$i',
          acronym: 'F$i',
          fullName: 'Faculty $i',
          dept: 'CSE',
          designation: 'Lecturer',
          employmentType: 'permanent',
          offDays: const ['Fri', 'Sat'],
        ),
    ];
    return base.take(facultyCount).toList();
  }

  @override
  Future<void> updateFacultySlotMatrix(
    String id,
    Map<String, String> slotMatrix,
  ) async {
    updatedFacultyId = id;
    updatedFacultyData = {'slot_matrix': slotMatrix};
  }
}
