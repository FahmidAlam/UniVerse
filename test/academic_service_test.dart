import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:universe/core/models/profile_model.dart';
import 'package:universe/core/models/routine_model.dart';
import 'package:universe/features/admin/services/academic_config_service.dart';

class FakeAcademicStore implements AcademicStore {
  final calls = <String>[];
  final writes = <Map<String, dynamic>>[];
  @override
  Future<Map<String, dynamic>> catalog() async => jsonDecode(
          File('test/fixtures/academic_catalog_v1.json').readAsStringSync())
      as Map<String, dynamic>;
  @override
  Future<void> save(String table, Map<String, dynamic> row) async {
    calls.add(table);
    writes.add(row);
  }

  @override
  Future<void> reviewAlias(String id) async {
    calls.add('review:$id');
  }

  @override
  Future<void> replaceAliasMembers(String id, List<String> members) async {
    calls.add('members:$id');
  }
}

void main() {
  test(
      'catalog service reads the atomic typed snapshot and writes canonical fields',
      () async {
    final store = FakeAcademicStore();
    final service = AcademicConfigService(store: store);
    final catalog = await service.fetchCatalog();
    await service.saveGroup(catalog.studentGroups.first);
    expect(store.calls, ['student_groups']);
    expect(store.writes.single, catalog.studentGroups.first.toMap());
    await service.reviewAlias(catalog.groupAliases.first.id);
    expect(store.calls.last, startsWith('review:'));
  });
  test('group membership edit uses the atomic RPC adapter', () async {
    final store = FakeAcademicStore();
    final service = AcademicConfigService(store: store);
    final catalog = await service.fetchCatalog();
    await service.replaceAliasMembers(
        catalog.groupAliases.first.id, catalog.groupAliases.first.groupIds);
    expect(store.calls, ['members:${catalog.groupAliases.first.id}']);
  });
  test(
      'legacy profile fields and role remain intact beside optional canonical links',
      () {
    final old = Profile.fromMap({
      'id': 'legacy-auth-id',
      'email': 'synthetic@example.invalid',
      'role': 'teacher',
      'department': 'Old label'
    });
    expect(old.departmentId, isNull);
    expect(old.role, 'teacher');
    final linked = Profile.fromMap({
      'id': old.id,
      'email': old.email,
      'role': old.role,
      'department': old.department,
      'department_id': 'canonical-dept',
      'program_id': 'canonical-program',
      'cohort_id': 'canonical-cohort',
      'student_group_id': 'canonical-group',
      'faculty_id': 'canonical-faculty'
    });
    expect(linked.id, old.id);
    expect(linked.department, old.department);
    expect(linked.facultyId, 'canonical-faculty');
    expect(linked.studentGroupId, 'canonical-group');
  });
  test(
      'old routine payload is unchanged, linked payload retains both representations',
      () {
    final row = {
      'id': 'legacy-row',
      'day': 'Sunday',
      'time_start': '09:00',
      'time_end': '10:00',
      'subject': 'Test',
      'subject_code': 'TEST',
      'room': 'Old room',
      'batch': '66',
      'section': 'B+C',
      'semester': 3
    };
    final old = RoutineEntry.fromMap(row);
    expect(old.toMap().containsKey('scheduling_scope_id'), isFalse);
    final linked = RoutineEntry.fromMap({
      ...row,
      'scheduling_scope_id': 'scope',
      'cohort_id': 'cohort',
      'student_group_id': null,
      'faculty_id': 'faculty',
      'room_id': 'room'
    });
    expect(linked.section, 'B+C');
    expect(linked.batch, '66');
    expect(linked.id, old.id);
    expect(linked.toMap()['scheduling_scope_id'], 'scope');
    expect(linked.roomId, 'room');
  });
}
