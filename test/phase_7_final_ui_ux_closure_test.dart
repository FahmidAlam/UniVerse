import 'package:universe/features/admin/screens/manage_faculty_screen.dart';
import 'package:universe/features/admin/screens/manage_rooms_screen.dart';
import 'package:universe/features/admin/controllers/timetable_faculty_controller.dart';
import 'package:universe/features/admin/controllers/timetable_rooms_controller.dart';
import 'dart:io';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universe/core/theme/app_theme.dart';
import 'package:universe/core/models/resource_model.dart';
import 'package:universe/core/models/notification_model.dart';
import 'package:universe/core/models/timetable_config_model.dart';
import 'package:universe/core/constants/app_enums.dart';
import 'package:universe/features/auth/controllers/auth_controller.dart';
import 'package:universe/features/admin/controllers/broadcast_controller.dart';
import 'package:universe/features/admin/controllers/resource_admin_controller.dart';
import 'package:universe/features/admin/controllers/whitelist_controller.dart';
import 'package:universe/features/admin/screens/admin_registration_screen.dart';
import 'package:universe/features/admin/screens/broadcast_history_screen.dart';
import 'package:universe/features/admin/screens/manage_resources_screen.dart';
import 'package:universe/features/admin/screens/resource_library_screen.dart';
import 'package:universe/features/admin/widgets/r15_slot_selector.dart';
import 'package:universe/shared/widgets/desktop_shell_scope.dart';
import 'package:universe/shared/widgets/u_app_bar.dart';

class _Auth extends ChangeNotifier implements AuthController {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Broadcast extends BroadcastController {
  _Broadcast(AuthController auth) : super(authController: auth);
  @override
  Future<void> loadRecent() async {}
  @override
  List<NotificationItem> get recent => [
        NotificationItem(
            id: 'fixture',
            title: 'Test announcement',
            body: 'Fixture broadcast for responsive verification',
            type: NotifType.university,
            time: DateTime(2026, 11, 9),
            targetRole: 'student')
      ];
}

class _Resources extends ResourceAdminController {
  @override
  Future<void> load() async {}
  @override
  List<Resource> get all => [
        const Resource(
            id: 'fixture',
            title: 'Fixture lecture notes',
            category: 'Notes',
            semester: 1)
      ];
}

class _Whitelist extends WhitelistController {
  @override
  Future<void> load() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final manifestData = await rootBundle.load('AssetManifest.bin');
    final manifest = Map<Object?, Object?>.from(
        const StandardMessageCodec().decodeMessage(manifestData) as Map);
    manifest['google_fonts/Inter-Regular.ttf'] = [
      {'asset': 'google_fonts/Inter-Regular.ttf'}
    ];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
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
    final iconBytes = File(
        'C:/src/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (iconBytes.existsSync()) {
      await (FontLoader('MaterialIcons')
            ..addFont(Future.value(
                ByteData.sublistView(iconBytes.readAsBytesSync()))))
          .load();
    }
    final bytes = File('.dart_tool/phase35_inter.ttf');
    if (bytes.existsSync()) {
      for (final family in [
        'Inter_100',
        'Inter_200',
        'Inter_300',
        'Inter_400',
        'Inter_500',
        'Inter_600',
        'Inter_700',
        'Inter_800',
        'Inter_900',
        'Inter_regular',
        'Inter_medium',
        'Inter_semiBold',
        'Inter_bold',
        'CaptureSans',
        'Inter',
        'Ahem',
        'Roboto',
        'monospace'
      ]) {
        await (FontLoader(family)
              ..addFont(
                  Future.value(ByteData.sublistView(bytes.readAsBytesSync()))))
            .load();
      }
    }
  });
  for (final width in [390.0, 1440.0]) {
    for (final scale in [1.0, if (width == 390) 1.3]) {
      for (final name in ['registration', 'history', 'upload', 'library']) {
        testWidgets(
            '$name at $width text $scale has one header and no overflow',
            (tester) async {
          tester.view.physicalSize = Size(width, width == 390 ? 844 : 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final auth = _Auth();
          final broadcasts = _Broadcast(auth);
          final resources = _Resources();
          final whitelist = _Whitelist();
          addTearDown(auth.dispose);
          addTearDown(broadcasts.dispose);
          addTearDown(resources.dispose);
          addTearDown(whitelist.dispose);
          final screen = switch (name) {
            'registration' => AdminRegistrationScreen(controller: whitelist),
            'history' => BroadcastHistoryScreen(
                authController: auth, controller: broadcasts),
            'upload' => ManageResourcesScreen(controller: resources),
            _ => ResourceLibraryScreen(controller: resources),
          };
          final boundaryKey = GlobalKey();
          await tester.pumpWidget(MaterialApp(
              theme: !File('.dart_tool/phase35_inter.ttf').existsSync()
                  ? ThemeData.dark()
                  : AppTheme.dark.copyWith(
                      textTheme: AppTheme.dark.textTheme
                          .apply(fontFamily: 'CaptureSans'),
                      primaryTextTheme: AppTheme.dark.primaryTextTheme
                          .apply(fontFamily: 'CaptureSans'),
                      appBarTheme: AppTheme.dark.appBarTheme.copyWith(
                          titleTextStyle: const TextStyle(
                              fontFamily: 'CaptureSans', fontSize: 20)),
                      textButtonTheme: TextButtonThemeData(
                          style: TextButton.styleFrom(
                              textStyle:
                                  const TextStyle(fontFamily: 'CaptureSans'))),
                    ),
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                      disableAnimations: true,
                      textScaler: TextScaler.linear(scale)),
                  child: child!),
              home: RepaintBoundary(
                  key: boundaryKey,
                  child: DesktopShellScope(
                      isDesktop: width >= 768, child: screen))));
          await tester.pumpAndSettle();
          expect(find.byType(UAppBar),
              width >= 768 ? findsNothing : findsOneWidget);
          expect(tester.takeException(), isNull);
          if (name == 'history') {
            await tester.tap(find.text('Test announcement'));
            await tester.pumpAndSettle();
            expect(find.text('Delete broadcast?'), findsOneWidget);
            await tester.sendKeyEvent(LogicalKeyboardKey.escape);
            await tester.pumpAndSettle();
            expect(find.text('Delete broadcast?'), findsNothing);
          }
          if (name == 'library') {
            expect(find.text('Showing 1 resources'), findsOneWidget);
            await tester.tap(find.text('PYQ'));
            await tester.pumpAndSettle();
            expect(find.text('Showing 0 resources'), findsOneWidget);
            await tester.tap(find.text('Clear filters'));
            await tester.pumpAndSettle();
            expect(find.text('Fixture lecture notes'), findsOneWidget);
            await tester.tap(find.byTooltip('Delete resource'));
            await tester.pumpAndSettle();
            await tester.sendKeyEvent(LogicalKeyboardKey.escape);
            await tester.pumpAndSettle();
            expect(find.text('Delete resource?'), findsNothing);
          }
          if (name == 'registration' || name == 'upload') {
            await tester.drag(find.byType(SingleChildScrollView).first,
                const Offset(0, -600));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            await tester.drag(find.byType(SingleChildScrollView).first,
                const Offset(0, 1000));
            await tester.pumpAndSettle();
          }
          if (scale == 1) {
            final boundary = boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
            await tester.runAsync(() async {
              final image = await boundary.toImage();
              final bytes =
                  await image.toByteData(format: ui.ImageByteFormat.png);
              final dir = Directory('docs/screenshots/phase_7');
              await dir.create(recursive: true);
              await File('${dir.path}/${name}_${width.toInt()}.png')
                  .writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
          await tester.pumpWidget(const SizedBox());
        });
      }
    }
    testWidgets('R15 configuration and preview toggle $width', (tester) async {
      int count = 0;
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: R15SlotSelector(
                  settingsLoader: () async => const TimetableSettings(
                      allowOnlinePeriods: true,
                      periods: [{}, {}, {}, {}, {}, {}, {}]),
                  onChanged: (value) => count = value))));
      await tester.pumpAndSettle();
      expect(count, 7);
      await tester.tap(find.text('6 Slots'));
      await tester.pumpAndSettle();
      expect(count, 6);
      await tester.tap(find.text('7 Slots'));
      await tester.pumpAndSettle();
      expect(count, 7);
    });
  }
  for (final faculty in [true, false]) {
    testWidgets(
        '${faculty ? "Faculty" : "Room"} inspector switches teaching rows for R15',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fc = TimetableFacultyController(initialFaculty: [
        const TimetableFaculty(
            id: 'fixture', acronym: 'TEST', fullName: 'Fixture Faculty')
      ]);
      final rc = TimetableRoomsController(initialRooms: [
        const TimetableRoom(id: 'fixture', name: 'ECL Lab', isLab: true)
      ]);
      addTearDown(fc.dispose);
      addTearDown(rc.dispose);
      await tester.pumpWidget(MaterialApp(
          theme: ThemeData.dark(),
          home: DesktopShellScope(
              isDesktop: true,
              child: faculty
                  ? ManageFacultyScreen(controller: fc)
                  : ManageRoomsScreen(controller: rc))));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('7 Slots'));
      await tester.tap(find.text('7 Slots'));
      await tester.pumpAndSettle();
      expect(find.text('P7'), findsOneWidget);
      expect(find.text('P4'), findsOneWidget);
      await tester.tap(find.text('6 Slots'));
      await tester.pumpAndSettle();
      expect(find.text('P7'), findsNothing);
      expect(find.text('P6'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
