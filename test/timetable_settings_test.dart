// The university's scheduling rules travel from Postgres -> TimetableSettings
// -> buildEngineConfig() -> the Python solver. If a value is lost or mistyped
// on the way, the engine silently falls back to a hard-coded default and the
// generated routine stops matching what the admin configured — which is the
// class of bug this whole layer exists to remove.

import 'package:flutter_test/flutter_test.dart';
import 'package:universe/core/models/timetable_config_model.dart';

void main() {
  group('TimetableSettings.fromMap', () {
    test('reads every scheduling rule out of a full row', () {
      final s = TimetableSettings.fromMap({
        'semester_label': 'Winter 2026',
        'periods': [
          {'idx': 1, 'start': '09:30', 'end': '10:45', 'col': 'D'},
        ],
        'working_days': ['Sunday', 'Monday', 'Tuesday'],
        'weeks_in_term': 12,
        'blocked_periods': {'Friday': [4], 'Saturday': [1, 2]},
        'online_periods': [7],
        'allow_online_periods': true,
        'excluded_periods': [6],
        'semester_map': {'66': 1, '65': 2},
        'friday_no_p4': false,
        'service_scope': 'resource_only',
        'weights': {'different_days': 8},
      });

      expect(s.semesterLabel, 'Winter 2026');
      expect(s.workingDays, ['Sunday', 'Monday', 'Tuesday']);
      expect(s.weeksInTerm, 12);
      expect(s.blockedPeriods, {
        'Friday': [4],
        'Saturday': [1, 2],
      });
      expect(s.onlinePeriods, [7]);
      expect(s.allowOnlinePeriods, isTrue);
      expect(s.excludedPeriods, [6]);
      expect(s.semesterMap, {'66': 1, '65': 2});
      expect(s.fridayNoP4, isFalse);
      expect(s.weight('different_days', 0), 8);
    });

    test('falls back to today\'s behaviour on a pre-migration row', () {
      final s = TimetableSettings.fromMap({
        'semester_label': 'Summer 2025',
        'periods': const [],
        'friday_no_p4': true,
      });

      expect(s.weeksInTerm, 14);
      expect(s.onlinePeriods, [7], reason: 'the 7pm slot stays held back');
      expect(s.allowOnlinePeriods, isFalse);
      expect(s.workingDays, isEmpty, reason: 'engine keeps its Sun-Sat default');
      expect(s.blockedPeriods, isEmpty);
      expect(s.semesterMap, isEmpty);
    });

    test('survives jsonb numbers arriving as strings or doubles', () {
      final s = TimetableSettings.fromMap({
        'weeks_in_term': 13.0,
        'online_periods': ['7'],
        'excluded_periods': [6.0, 'nonsense'],
        'blocked_periods': {'Friday': ['4']},
        'semester_map': {'66': '1'},
      });

      expect(s.weeksInTerm, 13);
      expect(s.onlinePeriods, [7]);
      expect(s.excludedPeriods, [6], reason: 'unparseable entries are dropped');
      expect(s.blockedPeriods, {
        'Friday': [4],
      });
      expect(s.semesterMap, {'66': 1});
    });

    test('ignores a wrong-typed column instead of throwing', () {
      final s = TimetableSettings.fromMap({
        'working_days': 'Sunday',
        'blocked_periods': 'Friday',
        'semester_map': 42,
      });

      expect(s.workingDays, isEmpty);
      expect(s.blockedPeriods, isEmpty);
      expect(s.semesterMap, isEmpty);
    });
  });

  test('toMap round-trips every rule back to Postgres', () {
    const original = TimetableSettings(
      semesterLabel: 'Winter 2026',
      periods: [
        {'idx': 1, 'start': '09:30', 'end': '10:45'},
      ],
      workingDays: ['Sunday', 'Monday'],
      weeksInTerm: 12,
      blockedPeriods: {
        'Friday': [4],
      },
      onlinePeriods: [7],
      allowOnlinePeriods: true,
      excludedPeriods: [6],
      semesterMap: {'66': 1},
      fridayNoP4: false,
      weights: {'compactness': 3},
    );

    final back = TimetableSettings.fromMap(original.toMap());

    expect(back.semesterLabel, original.semesterLabel);
    expect(back.workingDays, original.workingDays);
    expect(back.weeksInTerm, original.weeksInTerm);
    expect(back.blockedPeriods, original.blockedPeriods);
    expect(back.onlinePeriods, original.onlinePeriods);
    expect(back.allowOnlinePeriods, original.allowOnlinePeriods);
    expect(back.excludedPeriods, original.excludedPeriods);
    expect(back.semesterMap, original.semesterMap);
    expect(back.fridayNoP4, original.fridayNoP4);
    expect(back.periods, original.periods);
  });

  test('toMap sends null working_days rather than an empty array', () {
    // An empty array would tell the engine there are no teaching days at all.
    expect(const TimetableSettings().toMap()['working_days'], isNull);
  });

  test('copyWith can now change the period list', () {
    // It could not before, which is part of why the admin UI never edited it.
    const s = TimetableSettings(periods: [
      {'idx': 1}
    ]);
    final winter = s.copyWith(periods: const [
      {'idx': 1, 'start': '09:30'},
      {'idx': 2, 'start': '10:45'},
    ]);
    expect(winter.periods, hasLength(2));
    expect(s.periods, hasLength(1), reason: 'the original is untouched');
  });
}
