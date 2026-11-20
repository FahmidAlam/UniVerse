import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:universe/core/models/routine_model.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/core/theme/app_theme.dart';
import 'package:universe/features/admin/controllers/admin_dashboard_controller.dart';
import 'package:universe/features/admin/controllers/routine_admin_controller.dart';
import 'package:universe/features/admin/controllers/routine_upload_controller.dart';
import 'package:universe/features/admin/controllers/timetable_gen_controller.dart';
import 'package:universe/features/admin/scheduling/widgets/review/scheduling_review_pane.dart';
import 'package:universe/shared/utils/phosphor_compat.dart';
import 'package:universe/features/admin/screens/admin_dashboard_screen.dart';
import 'package:universe/features/admin/screens/admin_routine_screen.dart';
import 'package:universe/features/admin/screens/generate_timetable_screen.dart';
import 'package:universe/features/admin/screens/scheduling_workspace_screen.dart';
import 'package:universe/features/admin/screens/timetable_grid_screen.dart';
import 'package:universe/features/admin/screens/upload_routine_screen.dart';
import 'package:universe/features/admin/services/admin_service.dart';
import 'package:universe/features/admin/services/routine_workbook_parser.dart';
import 'package:universe/features/admin/widgets/admin_desktop_shell.dart';
import 'package:universe/features/auth/controllers/auth_controller.dart';
import 'package:universe/features/notifications/controllers/notification_controller.dart';

class _CaptureAuth extends ChangeNotifier implements AuthController {
  @override
  String get role => 'admin';
  @override
  Map<String, dynamic>? get profile => {
        'id': 'admin-uuid-1',
        'name': 'Prof. Sarah Jenkins',
        'email': 's.jenkins@university.edu',
        'role': 'admin',
      };
  @override
  Future<void> signOut() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CaptureNotifications extends ChangeNotifier
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

Widget _wrapRouter(
  Widget child, {
  required ThemeData theme,
  String initialLocation = '/admin/dashboard',
}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(path: '/admin/dashboard', builder: (context, state) => child),
      GoRoute(path: '/admin/scheduling', builder: (context, state) => child),
      GoRoute(path: '/admin/routine', builder: (context, state) => child),
      GoRoute(
          path: '/admin/timetable/grid', builder: (context, state) => child),
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
    theme: theme,
    routerConfig: router,
  );
}

final sampleEntries = <RoutineEntry>[
  const RoutineEntry(
    id: 'slot-1',
    day: 'Sunday',
    section: 'A',
    batch: '60',
    semester: 1,
    timeStart: '08:30',
    timeEnd: '09:20',
    subjectCode: 'CSE 1101',
    subject: 'Structured Programming',
    teacherCode: 'TUR',
    room: 'RAB-301',
  ),
  const RoutineEntry(
    id: 'slot-2',
    day: 'Sunday',
    section: 'B',
    batch: '59',
    semester: 3,
    timeStart: '09:20',
    timeEnd: '11:00',
    subjectCode: 'CSE 2103',
    subject: 'Data Structures Lab',
    teacherCode: 'KNU',
    room: 'SW-LAB',
  ),
  const RoutineEntry(
    id: 'slot-3',
    day: 'Monday',
    section: 'A',
    batch: '58',
    semester: 5,
    timeStart: '10:10',
    timeEnd: '11:00',
    subjectCode: 'CSE 3105',
    subject: 'Database Systems',
    teacherCode: 'COD',
    room: 'RAB-402',
  ),
  const RoutineEntry(
    id: 'slot-4',
    day: 'Monday',
    section: 'A+B',
    batch: '60',
    semester: 1,
    timeStart: '11:00',
    timeEnd: '11:50',
    subjectCode: 'MATH 1101',
    subject: 'Engineering Mathematics',
    teacherCode: 'LOV',
    room: 'AUD-01',
  ),
  const RoutineEntry(
    id: 'slot-5',
    day: 'Tuesday',
    section: 'A',
    batch: '57',
    semester: 7,
    timeStart: '13:00',
    timeEnd: '14:40',
    subjectCode: 'CSE 4101',
    subject: 'Artificial Intelligence',
    teacherCode: 'MIN',
    room: 'RAB-302',
  ),
];

const sampleParseResult = RoutineWorkbookParseResult(
  rows: [
    RoutineEntry(
      id: 'u-1',
      day: 'Sunday',
      section: 'A',
      batch: '60',
      semester: 1,
      timeStart: '08:30',
      timeEnd: '09:20',
      subjectCode: 'CSE 1101',
      subject: 'Structured Programming',
      teacherCode: 'TUR',
      room: 'RAB-301',
    ),
  ],
  sourceFormat: 'day_sheets',
  stats: {
    'meetings': 164,
    'cohorts': 8,
    'teachers': 26,
  },
  validation: {'ok': true},
  warnings: [],
);

void main() {
  testWidgets('Capture Phase 5 Visual Gallery Screenshots', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;

    final manifestData = await rootBundle.load('AssetManifest.bin');
    final manifest = Map<Object?, Object?>.from(
        const StandardMessageCodec().decodeMessage(manifestData) as Map);
    manifest['assets/Inter-Regular.ttf'] = [
      {'asset': 'assets/Inter-Regular.ttf'}
    ];
    manifest['google_fonts/Inter-Regular.ttf'] = [
      {'asset': 'google_fonts/Inter-Regular.ttf'}
    ];
    tester.binding.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
      final key = String.fromCharCodes(message!.buffer.asUint8List());
      if (key == 'AssetManifest.bin') {
        return const StandardMessageCodec().encodeMessage(manifest);
      }
      if (key.contains('Inter-Regular.ttf')) {
        return ByteData.sublistView(
            File('.dart_tool/phase35_inter.ttf').readAsBytesSync());
      }
      return null;
    });

    // Load CaptureSans & MaterialIcons
    final fontPath = '.dart_tool/phase35_inter.ttf';
    if (File(fontPath).existsSync()) {
      final fontBytes = File(fontPath).readAsBytesSync();
      final loader = FontLoader('CaptureSans')
        ..addFont(Future.value(ByteData.sublistView(fontBytes)));
      await loader.load();
      for (final family in ['Ahem', 'Roboto', 'Inter', 'monospace']) {
        final font = FontLoader(family)
          ..addFont(Future.value(ByteData.sublistView(fontBytes)));
        await font.load();
      }
    }

    const iconPath =
        'C:/src/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
    if (File(iconPath).existsSync()) {
      final iconBytes = File(iconPath).readAsBytesSync();
      final iconLoader = FontLoader('MaterialIcons')
        ..addFont(Future.value(ByteData.sublistView(iconBytes)));
      await iconLoader.load();
    }

    final baseTheme = AppTheme.dark;
    // Component themes resolve typography independently of TextTheme. Bind all
    // Material label surfaces to the loaded capture font to avoid Ahem blocks.
    final captureTheme = baseTheme.copyWith(
      textTheme: baseTheme.textTheme.apply(fontFamily: 'CaptureSans'),
      primaryTextTheme:
          baseTheme.primaryTextTheme.apply(fontFamily: 'CaptureSans'),
      appBarTheme: baseTheme.appBarTheme.copyWith(
        titleTextStyle:
            baseTheme.textTheme.titleLarge!.copyWith(fontFamily: 'CaptureSans'),
        toolbarTextStyle:
            baseTheme.textTheme.bodyMedium!.copyWith(fontFamily: 'CaptureSans'),
      ),
      filledButtonTheme: FilledButtonThemeData(
          style: baseTheme.filledButtonTheme.style!.copyWith(
              textStyle: WidgetStatePropertyAll(baseTheme.textTheme.labelLarge!
                  .copyWith(fontFamily: 'CaptureSans')))),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: baseTheme.outlinedButtonTheme.style!.copyWith(
              textStyle: WidgetStatePropertyAll(baseTheme.textTheme.labelLarge!
                  .copyWith(fontFamily: 'CaptureSans')))),
      textButtonTheme: TextButtonThemeData(
          style: baseTheme.textButtonTheme.style!.copyWith(
              textStyle: WidgetStatePropertyAll(baseTheme.textTheme.labelLarge!
                  .copyWith(fontFamily: 'CaptureSans')))),
      dialogTheme: baseTheme.dialogTheme.copyWith(
        titleTextStyle: AppTextStyles.h2.copyWith(fontFamily: 'CaptureSans'),
        contentTextStyle:
            AppTextStyles.body.copyWith(fontFamily: 'CaptureSans'),
      ),
    );

    final auth = _CaptureAuth();
    final notifications = _CaptureNotifications();
    addTearDown(() {
      auth.dispose();
      notifications.dispose();
    });

    final defaultCounts = const AdminCounts(
      students: 420,
      teachers: 32,
      admins: 4,
      routines: 186,
      broadcasts: 14,
      rooms: 18,
      courseEligibilities: 104,
    );

    Future<void> capture(String fileName, Widget widget, Size size,
        {String location = '/admin/dashboard',
        Future<void> Function()? interaction}) async {
      // ignore: avoid_print
      print('=== CAPTURING: $fileName ===');
      await tester.binding.setSurfaceSize(size);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;

      final key = GlobalKey();
      final wrapped = _wrapRouter(
        size.width >= 920
            ? AdminDesktopShell(
                authController: auth,
                notificationController: notifications,
                currentLocation: location,
                child: widget,
              )
            : widget,
        theme: captureTheme,
        initialLocation: location,
      );

      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: wrapped,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      if (interaction != null) {
        await interaction();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      }

      expect(tester.takeException(), isNull,
          reason: 'No layout/runtime exception in $fileName');
      await expectLater(
        find.byKey(key),
        matchesGoldenFile(
            '../docs/screenshots/phase_7/regression/$fileName.png'),
      );
    }

    // -------------------------------------------------------------
    // 1. Workstream A: Admin Dashboard & Command Center
    // -------------------------------------------------------------
    final dashController =
        AdminDashboardController(initialCounts: defaultCounts);
    addTearDown(dashController.dispose);

    // 01_admin_dashboard_desktop_1440
    await capture(
      '01_admin_dashboard_desktop_1440',
      AdminDashboardScreen(authController: auth, controller: dashController),
      const Size(1440, 900),
      location: '/admin/dashboard',
    );

    // 02_admin_dashboard_medium_1024
    await capture(
      '02_admin_dashboard_medium_1024',
      AdminDashboardScreen(authController: auth, controller: dashController),
      const Size(1024, 800),
      location: '/admin/dashboard',
    );

    // 03_admin_dashboard_mobile_390
    await capture(
      '03_admin_dashboard_mobile_390',
      AdminDashboardScreen(authController: auth, controller: dashController),
      const Size(390, 844),
      location: '/admin/dashboard',
    );

    // 04_admin_dashboard_setup_required_1280
    final zeroCounts = const AdminCounts(
      students: 24,
      teachers: 0,
      admins: 1,
      routines: 0,
      broadcasts: 0,
      rooms: 0,
      courseEligibilities: 0,
    );
    final zeroController = AdminDashboardController(initialCounts: zeroCounts);
    addTearDown(zeroController.dispose);

    await capture(
      '04_admin_dashboard_setup_required_1280',
      AdminDashboardScreen(authController: auth, controller: zeroController),
      const Size(1280, 800),
      location: '/admin/dashboard',
    );

    // -------------------------------------------------------------
    // 2. Workstream B: Scheduling Workbench (All 5 Panes & Viewports)
    // -------------------------------------------------------------

    // 05_scheduling_workbench_distribution_desktop_1440 (Expanded with docked 360px inspector)
    await capture(
      '05_scheduling_workbench_distribution_desktop_1440',
      SchedulingWorkspaceScreen(
        availabilityLoader: () async => DistributionAvailability.unavailable,
        initialPreviewMode: true,
        initialTabIndex: 0,
      ),
      const Size(1440, 900),
      location: '/admin/scheduling',
      interaction: () async {
        final toggle = find.byIcon(PhosphorIconsRegular.sidebarSimple);
        if (toggle.evaluate().isNotEmpty) {
          await tester.tap(toggle.first);
          await tester.pumpAndSettle();
        }
      },
    );

    // 06_scheduling_workbench_distribution_medium_1024 (1024px collision fix with full-width table)
    await capture(
      '06_scheduling_workbench_distribution_medium_1024',
      SchedulingWorkspaceScreen(
        availabilityLoader: () async => DistributionAvailability.unavailable,
        initialPreviewMode: true,
        initialTabIndex: 0,
      ),
      const Size(1024, 800),
      location: '/admin/scheduling',
    );

    // 07_scheduling_workbench_provenance_modal_1024 (Adaptive Modal Provenance Inspector)
    await capture(
      '07_scheduling_workbench_provenance_modal_1024',
      SchedulingWorkspaceScreen(
        availabilityLoader: () async => DistributionAvailability.unavailable,
        initialPreviewMode: true,
        initialTabIndex: 0,
      ),
      const Size(1024, 800),
      location: '/admin/scheduling',
      interaction: () async {
        final toggle = find.byIcon(PhosphorIconsRegular.sidebarSimple);
        if (toggle.evaluate().isNotEmpty) {
          await tester.tap(toggle.first);
          await tester.pumpAndSettle();
        }
      },
    );

    // 08_scheduling_workbench_distribution_mobile_390 (Compact mobile touch list)
    await capture(
      '08_scheduling_workbench_distribution_mobile_390',
      SchedulingWorkspaceScreen(
        availabilityLoader: () async => DistributionAvailability.unavailable,
        initialPreviewMode: true,
        initialTabIndex: 0,
      ),
      const Size(390, 844),
      location: '/admin/scheduling',
    );

    // 09_scheduling_workbench_configuration_desktop_1440 (Stage 2: R1-R15 Configuration)
    await capture(
      '09_scheduling_workbench_configuration_desktop_1440',
      SchedulingWorkspaceScreen(
        availabilityLoader: () async => DistributionAvailability.unavailable,
        initialPreviewMode: true,
        initialTabIndex: 1,
      ),
      const Size(1440, 900),
      location: '/admin/scheduling',
    );

    // 10_scheduling_workbench_readiness_desktop_1440 (Stage 3: Preflight Readiness)
    await capture(
      '10_scheduling_workbench_readiness_desktop_1440',
      SchedulingWorkspaceScreen(
        availabilityLoader: () async => DistributionAvailability.unavailable,
        initialPreviewMode: true,
        initialTabIndex: 2,
      ),
      const Size(1440, 900),
      location: '/admin/scheduling',
    );

    // 11_scheduling_workbench_generate_desktop_1440 (Stage 4: Solver Generate Parameters)
    await capture(
      '11_scheduling_workbench_generate_desktop_1440',
      SchedulingWorkspaceScreen(
        availabilityLoader: () async => DistributionAvailability.unavailable,
        initialPreviewMode: true,
        initialTabIndex: 3,
      ),
      const Size(1440, 900),
      location: '/admin/scheduling',
    );

    // 12_scheduling_workbench_review_publish_desktop_1440 (Stage 5: Review & Publish)
    await capture(
      '12_scheduling_workbench_review_publish_desktop_1440',
      SchedulingWorkspaceScreen(
        availabilityLoader: () async => DistributionAvailability.unavailable,
        initialPreviewMode: true,
        initialTabIndex: 4,
      ),
      const Size(1440, 900),
      location: '/admin/scheduling',
    );

    // 13_scheduling_workbench_publish_modal_slide_confirm_1024 (Slide-to-Confirm modal)
    await capture(
      '13_scheduling_workbench_publish_modal_slide_confirm_1024',
      SchedulingWorkspaceScreen(
        availabilityLoader: () async => DistributionAvailability.unavailable,
        initialPreviewMode: true,
        initialTabIndex: 4,
      ),
      const Size(1024, 800),
      location: '/admin/scheduling',
      interaction: () async {
        await tester.drag(
          find.byType(SchedulingReviewPane),
          const Offset(0, -1800),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Publish to Campus'));
        await tester.pumpAndSettle();
      },
    );

    // -------------------------------------------------------------
    // 3. Workstream C: Live Routine Operations
    // -------------------------------------------------------------
    final routineAdminController = RoutineAdminController(
      initialEntries: sampleEntries,
    );
    final genBaseCtrl = TimetableGenController();
    final uploadBaseCtrl = RoutineUploadController();
    addTearDown(() {
      routineAdminController.dispose();
      genBaseCtrl.dispose();
      uploadBaseCtrl.dispose();
    });

    // 14_routine_operations_manage_desktop_1440
    await capture(
      '14_routine_operations_manage_desktop_1440',
      AdminRoutineScreen(
        manageController: routineAdminController,
        generateController: genBaseCtrl,
        uploadController: uploadBaseCtrl,
        initialTabIndex: 0,
      ),
      const Size(1440, 900),
      location: '/admin/routine',
    );

    // 15_routine_operations_manage_mobile_390
    await capture(
      '15_routine_operations_manage_mobile_390',
      AdminRoutineScreen(
        manageController: routineAdminController,
        generateController: genBaseCtrl,
        uploadController: uploadBaseCtrl,
        initialTabIndex: 0,
      ),
      const Size(390, 844),
      location: '/admin/routine',
    );

    // 16_routine_operations_generate_timeline_desktop_1440 (4-Node Visual Timeline)
    final genController = TimetableGenController();
    addTearDown(genController.dispose);
    genController.seedPreviewState(
      phase: GenPhase.polling,
      fileName: 'Course Distribution Fall 2026.xlsx',
      progress: 0.68,
      activeJobState: 'solving',
    );

    await capture(
      '16_routine_operations_generate_timeline_desktop_1440',
      GenerateTimetableScreen(
        embedded: false,
        controller: genController,
      ),
      const Size(1440, 900),
      location: '/admin/routine?tab=generate',
    );

    // 17_routine_operations_generate_error_recovery_desktop_1440 (Service Recovery Paradox)
    final genErrorController = TimetableGenController();
    addTearDown(genErrorController.dispose);
    genErrorController.seedPreviewState(
      phase: GenPhase.error,
      errorMessage:
          'FastAPI engine connection timeout: OR-Tools solver reached time budget limit before finding feasible routine for CSE batch 60.',
    );

    await capture(
      '17_routine_operations_generate_error_recovery_desktop_1440',
      GenerateTimetableScreen(
        embedded: false,
        controller: genErrorController,
      ),
      const Size(1440, 900),
      location: '/admin/routine?tab=generate',
    );

    // 18_routine_operations_upload_pipeline_desktop_1440 (3-Step Post-Parse Pipeline)
    final uploadController = RoutineUploadController(
      initialPhase: RoutineUploadPhase.published,
      initialFileName: 'Rendered Routine Fall 2026.xlsx',
      initialResult: sampleParseResult,
      initialPublishedCount: 164,
    );
    addTearDown(uploadController.dispose);

    await capture(
      '18_routine_operations_upload_pipeline_desktop_1440',
      UploadRoutineScreen(
        embedded: false,
        controller: uploadController,
      ),
      const Size(1440, 900),
      location: '/admin/routine?tab=upload',
    );

    // 19_routine_operations_upload_secondary_warning_desktop_1440 (Service Recovery Paradox)
    final uploadWarnController = RoutineUploadController(
      initialPhase: RoutineUploadPhase.published,
      initialFileName: 'Rendered Routine Fall 2026.xlsx',
      initialResult: sampleParseResult,
      initialPublishedCount: 164,
      initialSecondaryWarning:
          'Routine published successfully to student and teacher portals, but the secondary audit history log could not be written to Supabase.',
    );
    addTearDown(uploadWarnController.dispose);

    await capture(
      '19_routine_operations_upload_secondary_warning_desktop_1440',
      UploadRoutineScreen(
        embedded: false,
        controller: uploadWarnController,
      ),
      const Size(1440, 900),
      location: '/admin/routine?tab=upload',
    );

    // 20_timetable_grid_desktop_1440 (Responsive filter bar & timetable matrix)
    await capture(
      '20_timetable_grid_desktop_1440',
      TimetableGridScreen(
        rows: sampleEntries,
      ),
      const Size(1440, 900),
      location: '/admin/timetable/grid',
    );
    await capture(
      '21_timetable_grid_mobile_390',
      TimetableGridScreen(rows: sampleEntries),
      const Size(390, 844),
      location: '/admin/timetable/grid',
    );
    await capture(
      '22_timetable_grid_medium_1024',
      TimetableGridScreen(rows: sampleEntries),
      const Size(1024, 800),
      location: '/admin/timetable/grid',
    );
  });
}
