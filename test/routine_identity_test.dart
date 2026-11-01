import 'package:flutter_test/flutter_test.dart';
import 'package:universe/core/models/routine_model.dart';
import 'package:universe/core/utils/room_identity.dart';

void main() {
  Map<String, dynamic> row() => {
        'id': 'draft-1',
        'day': 'Monday',
        'time_start': '11:50',
        'time_end': '12:50',
        'subject': 'Shared course',
        'subject_code': 'CSE-1001',
        'teacher_code': 'AAA',
        'teachers': ['AAA', 'BBB'],
        'room': 'PHY LAB',
        'batch': '93',
        'section': 'B+C',
        'semester': 1
      };
  test(
      'shared teachers survive draft persistence and both readers match one meeting',
      () {
    final entry = RoutineEntry.fromMap(row());
    final restored = RoutineEntry.fromMap(entry.toDraftMap());
    expect(restored.teacherCodes, ['AAA', 'BBB']);
    expect(restored.matchesTeacher('BBB'), isTrue);
    expect(restored.matchesStudent('93', 'B'), isTrue);
    expect(restored.matchesStudent('93', 'C'), isTrue);
    expect(restored.matchesStudent('93', 'D'), isFalse);
    expect(restored.teacherDisplay, contains('BBB'));
    expect(restored.requiresSharedTeacherStorage, isTrue);
  });
  test(
      'confirmed physical alias normalizes current room views without guessing RKB',
      () {
    expect(
        RoomIdentity.currentKey('phy lab'), RoomIdentity.currentKey('RAB-106'));
    expect(RoomIdentity.currentKey('RAB-106'),
        isNot(RoomIdentity.currentKey('RKB-106')));
  });
}
