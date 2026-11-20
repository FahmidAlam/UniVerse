import 'package:universe/features/find_teacher/screens/teacher_detail_screen.dart';
import 'package:universe/shared/widgets/weekly_schedule_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:universe/core/models/routine_model.dart';
import 'package:universe/features/admin/widgets/admin_schedule_slot.dart';
import 'package:universe/features/admin/screens/timetable_grid_screen.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  RoutineEntry row(String code) => RoutineEntry.fromMap({
        'day': 'Monday',
        'time_start': '11:50',
        'time_end': '12:50',
        'batch': '93',
        'section': 'B+C',
        'subject_code': code,
        'teacher_code': 'AAA',
        'teachers': ['AAA', 'BBB'],
        'room': 'PHY LAB'
      });
  testWidgets(
      'real grid shows shared teachers and never overwrites colliding rows',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: TimetableGridScreen(
            rows: [row('CSE-1001'), row('CSE-2001')],
            roomAliases: const {'PHY LAB': 'RAB-106'})));
    expect(find.text('CSE-1001'), findsWidgets);
    expect(find.text('CSE-2001'), findsOneWidget);
    final slots = tester
        .widgetList<AdminScheduleSlot>(find.byType(AdminScheduleSlot))
        .toList();
    expect(slots.length, 2);
    for (final slot in slots) {
      expect(slot.entry.teacherCodes, ['AAA', 'BBB']);
    }
    expect(
        find.descendant(
            of: find.byType(AdminScheduleSlot), matching: find.text('AAA')),
        findsNWidgets(2));
    expect(
        find.descendant(
            of: find.byType(AdminScheduleSlot), matching: find.text('BBB')),
        findsNWidgets(2));
    expect(find.text('2 overlapping entries'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'student B and secondary teacher filter retain the one shared meeting',
      (tester) async {
    await tester.pumpWidget(
        MaterialApp(home: TimetableGridScreen(rows: [row('CSE-1001')])));
    final student = tester.widget<DropdownButton<String>>(
        find.byType(DropdownButton<String>).at(0));
    student.onChanged!('93|B');
    await tester.pump();
    final faculty = tester.widget<DropdownButton<String>>(
        find.byType(DropdownButton<String>).at(1));
    faculty.onChanged!('BBB');
    await tester.pump();
    expect(find.text('CSE-1001'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
  testWidgets('faculty detail includes a meeting taught as a secondary teacher',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: TeacherDetailView(
            teacherCode: 'BBB',
            teacherName: 'Fixture secondary teacher',
            routineLoader: () async => [row('CSE-1001')])));
    await tester.pumpAndSettle();
    final schedule =
        tester.widget<WeeklyScheduleView>(find.byType(WeeklyScheduleView));
    expect(schedule.entries.single.subjectCode, 'CSE-1001');
    expect(tester.takeException(), isNull);
  });
}
