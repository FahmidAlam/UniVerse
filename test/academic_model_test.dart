import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:universe/core/models/academic_model.dart';

Map<String, dynamic> fixture() => jsonDecode(
      File('test/fixtures/academic_catalog_v1.json').readAsStringSync(),
    ) as Map<String, dynamic>;

void main() {
  test('shared edge whitespace rejects BOM-only codes and alias collisions',
      () {
    final blank = fixture();
    blank['departments'][0]['code'] = '\uFEFF';
    expect(() => AcademicCatalog.fromMap(blank), throwsFormatException);
    final input = fixture();
    input['group_aliases'].add({
      ...input['group_aliases'][0] as Map,
      'id': '00000000-0000-0000-0000-000000000099',
      'label': '\uFEFFB+C',
    });
    expect(() => AcademicCatalog.fromMap(input), throwsFormatException);
  });
  test('shared schema-v1 catalog round trips without inferred identities', () {
    final input = fixture();
    final catalog = AcademicCatalog.fromMap(input);
    expect(catalog.toMap(), input);
    expect(catalog.rooms.first.capacity, isNull);
    expect(catalog.cohorts[0].code, catalog.cohorts[1].code);
    final groups = catalog.studentGroups
        .where((g) =>
            g.code == 'A' &&
            catalog.cohorts.take(2).any((c) => c.id == g.cohortId))
        .toList();
    expect(groups.length, 2);
    expect(groups[0].id, isNot(groups[1].id));
  });

  test('B+C has two reviewed members and is scoped to its cohort', () {
    final catalog = AcademicCatalog.fromMap(fixture());
    expect(
        catalog
            .resolveGroupAlias(catalog.cohorts.first.id, 'B+C')
            .map((g) => g.code)
            .toSet(),
        {'B', 'C'});
    expect(() => catalog.resolveGroupAlias(catalog.cohorts[1].id, 'B+C'),
        throwsFormatException);
    expect(() => catalog.resolveGroupAlias(catalog.cohorts.first.id, 'C+B'),
        throwsFormatException);
    final input = fixture();
    input['group_aliases'][0]['reviewed'] = false;
    final unresolved = AcademicCatalog.fromMap(input);
    expect(
        () => unresolved.resolveGroupAlias(unresolved.cohorts.first.id, 'B+C'),
        throwsFormatException);
  });

  test('calendar progression is explicit and accepts a fourth yearly term', () {
    final catalog = AcademicCatalog.fromMap(fixture());
    expect(catalog.cohortTerms.map((t) => t.studyStage), [3, 5, 1]);
    expect(catalog.terms[1].sequence, 4);
    final input = fixture();
    input['cohort_terms'][0]['term_id'] = input['terms'][1]['id'];
    expect(() => AcademicCatalog.fromMap(input), throwsFormatException);
  });

  test('archive preserves sections and new intake can own a single section',
      () {
    final input = fixture();
    final oldId = input['student_groups'][0]['id'];
    input['cohorts'][0].addAll({
      'status': 'archived',
      'graduated_on': '2026-06-30',
      'archived_on': '2026-07-01',
    });
    final catalog = AcademicCatalog.fromMap(input);
    expect(catalog.studentGroups.first.id, oldId);
    expect(
        catalog.studentGroups
            .where((g) => g.cohortId == catalog.cohorts[2].id)
            .length,
        1);
  });

  test('duplicate nullable scope and ambiguous aliases reject', () {
    for (final key in ['scopes', 'group_aliases']) {
      final input = fixture();
      final rows = input[key] as List;
      rows.add(
          {...rows.last as Map, 'id': '00000000-0000-0000-0000-000000000099'});
      expect(() => AcademicCatalog.fromMap(input), throwsFormatException);
    }
  });

  test('wrong versions, bad dates, capacities and cross-scope links reject',
      () {
    for (final change in <void Function(Map<String, dynamic>)>[
      (d) => d['schema_version'] = 2,
      (d) => d['schema_version'] = true,
      (d) => d['extra'] = 'unknown',
      (d) => d['terms'][0]['start_date'] = '2026-02-30',
      (d) => d['terms'][0]['end_date'] = '2025-01-01',
      (d) => d['rooms'][0]['capacity'] = 0,
      (d) => d['cohort_terms'][0]['study_stage'] = true,
      (d) => d['scopes'][0]['department_id'] = d['departments'][1]['id'],
      (d) => d['group_aliases'][0]['group_ids']
          .add(d['student_groups'].last['id']),
    ]) {
      final input = fixture();
      change(input);
      expect(() => AcademicCatalog.fromMap(input), throwsFormatException);
    }
  });

  test('catalog and alias members cannot mutate through input or output', () {
    final input = fixture();
    final catalog = AcademicCatalog.fromMap(input);
    input['rooms'][0]['features'].add('changed');
    expect(catalog.rooms.first.features, isEmpty);
    expect(() => catalog.studentGroups.clear(), throwsUnsupportedError);
    expect(() => catalog.groupAliases.first.groupIds.clear(),
        throwsUnsupportedError);
    catalog.toMap()['group_aliases'][0]['group_ids'].clear();
    expect(catalog.groupAliases.first.groupIds.length, 2);
  });
}
