import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universe/core/constants/app_constants.dart';
import 'package:universe/core/constants/app_enums.dart';
import 'package:universe/core/models/notification_model.dart';
import 'package:universe/core/models/routine_model.dart';
import 'package:universe/core/theme/app_theme.dart';
import 'package:universe/features/auth/controllers/auth_controller.dart';
import 'package:universe/features/auth/screens/admin_web_notice_screen.dart';
import 'package:universe/features/find_teacher/controllers/find_teacher_controller.dart';
import 'package:universe/features/find_teacher/services/teacher_location_service.dart';
import 'package:universe/features/profile/services/teacher_r8_preference_service.dart';

class _FakeAdminAuthController extends ChangeNotifier
    implements AuthController {
  @override
  String get role => 'admin';

  @override
  Map<String, dynamic>? get profile => {
        'id': 'admin-1',
        'email': 'committee@lus.ac.bd',
        'role': 'admin',
      };

  @override
  Future<void> signOut() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCoTeacherService implements TeacherLocationService {
  @override
  Future<List<RoutineEntry>> fetchAllRoutines() async {
    return [
      RoutineEntry.fromMap({
        'id': 'co-1',
        'day': 'Sunday',
        'time_start': '08:50:00',
        'time_end': '10:05:00',
        'subject': 'Compiler Sessional',
        'subject_code': 'CSE-3312',
        'teacher_code': 'AA',
        'teacher_codes': ['AA', 'BB'],
        'room': 'ACL-1',
        'batch': '58',
        'section': 'B+C',
        'semester': 6,
        'is_active': true,
      }),
    ];
  }

  @override
  Future<List<String>> fetchUniqueTeachers() async => ['AA', 'BB'];

  @override
  Stream<List<RoutineEntry>> streamAllRoutines() => const Stream.empty();
}

void main() {
  test('AppConstants defaults to 2027 Supabase publishable key format', () {
    expect(AppConstants.supabaseAnonKey, startsWith('sb_publishable_'));
  });

  test('NotificationItem.matchesAudience splits B+C joint sections', () {
    final jointNotif = NotificationItem(
      id: 'n-1',
      title: 'Class Cancelled',
      body: 'CSE-3101 cancelled',
      type: NotifType.classCancel,
      time: DateTime(2026, 11, 27),
      targetRole: 'student',
      targetBatch: '58',
      targetSection: 'B+C',
    );

    expect(
      jointNotif.matchesAudience(role: 'student', batch: '58', section: 'B'),
      isTrue,
    );
    expect(
      jointNotif.matchesAudience(role: 'student', batch: '58', section: 'C'),
      isTrue,
    );
    expect(
      jointNotif.matchesAudience(role: 'student', batch: '58', section: 'A'),
      isFalse,
    );
    expect(
      jointNotif.matchesAudience(role: 'student', batch: '59', section: 'B'),
      isFalse,
    );
  });

  test('RoutineEntry.fromMap reads teacher_codes and FindTeacherController indexes co-teachers', () async {
    final row = RoutineEntry.fromMap({
      'id': 'r-1',
      'day': 'Sunday',
      'time_start': '08:50:00',
      'time_end': '10:05:00',
      'subject': 'Compiler Lab',
      'subject_code': 'CSE-3312',
      'teacher_code': 'AA',
      'teacher_codes': ['AA', 'BB'],
      'room': 'ACL-1',
      'batch': '58',
      'section': 'B+C',
      'semester': 6,
      'is_active': true,
    });

    expect(row.teacherCodes, ['AA', 'BB']);
    expect(row.matchesTeacher('bb'), isTrue);
    expect(row.matchesTeacher('AA'), isTrue);
    expect(row.matchesTeacher('CC'), isFalse);

    final ctrl = FindTeacherController(service: _FakeCoTeacherService());
    await ctrl.initialize();
    final acronyms = ctrl.filteredTeachers.map((t) => t.code).toSet();
    expect(acronyms, containsAll(['AA', 'BB']));
    ctrl.dispose();
  });

  testWidgets('AdminWebNoticeScreen displays React Web console URL and Sign Out',
      (tester) async {
    final auth = _FakeAdminAuthController();
    addTearDown(auth.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: AdminWebNoticeScreen(authController: auth),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Admin Operations Moved to Web'), findsOneWidget);
    expect(find.text(AdminWebNoticeScreen.webConsoleUrl), findsOneWidget);
    expect(find.text('Sign Out'), findsOneWidget);
  });

  test('TeacherR8PreferenceService.isPermissionDenied detects 42501 RLS denial', () {
    expect(
      TeacherR8PreferenceService.isPermissionDenied(
        const PostgrestException(message: 'permission denied', code: '42501'),
      ),
      isTrue,
    );
    expect(
      TeacherR8PreferenceService.isPermissionDenied(
        const PostgrestException(message: 'other error', code: 'PGRST116'),
      ),
      isFalse,
    );
    expect(
      TeacherR8PreferenceService.isPermissionDenied(Exception('network')),
      isFalse,
    );
  });
}
