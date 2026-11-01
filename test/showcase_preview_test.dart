import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:universe/core/models/routine_model.dart';
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
    await tester.pumpWidget(MaterialApp(
        home: TimetableGridScreen(
            rows: [row('CSE-1001'), row('CSE-2001')],
            roomAliases: const {'PHY LAB': 'RAB-106'})));
    expect(find.text('CSE-1001'), findsOneWidget);
    expect(find.text('CSE-2001'), findsOneWidget);
    expect(find.text('AAA / BBB'), findsNWidgets(2));
    expect(find.text('2 overlapping entries'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'student B and secondary teacher filter retain the one shared meeting',
      (tester) async {
    await tester.pumpWidget(
        MaterialApp(home: TimetableGridScreen(rows: [row('CSE-1001')])));
    final student = tester.widget<DropdownButtonFormField<String>>(
        find.byType(DropdownButtonFormField<String>).at(0));
    student.onChanged!('93|B');
    await tester.pump();
    final faculty = tester.widget<DropdownButtonFormField<String>>(
        find.byType(DropdownButtonFormField<String>).at(1));
    faculty.onChanged!('BBB');
    await tester.pump();
    expect(find.text('CSE-1001'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
