import 'package:flutter_test/flutter_test.dart';
import 'package:universe/features/admin/controllers/timetable_gen_controller.dart';

/// The publish gate must agree with the engine's own verdict.
///
/// It used to check eight of the engine's failure counters. The engine reports
/// fifteen, so a routine it had already marked `ok: false` — an unplaced room,
/// a class on a teacher's day off, a lab in a lecture room — was still
/// publishable from the app.
void main() {
  Map<String, dynamic> clean([Map<String, dynamic> overrides = const {}]) => {
        'ok': true,
        'missing_courses': 0,
        'under_scheduled': 0,
        'over_scheduled': 0,
        'unexpected_courses': 0,
        'teacher_clashes': 0,
        'cohort_clashes': 0,
        'room_clashes': 0,
        'same_day_sessions': 0,
        'ineligible_assignments': 0,
        'dayoff_violations': 0,
        'blocked_period_violations': 0,
        'lab_room_violations': 0,
        'unplaced_rooms': 0,
        'lab_theory_violations': 0,
        'invalid_time_slots': 0,
        'invalid_days': 0,
        ...overrides,
      };

  test('a clean routine is publishable', () {
    expect(blockingValidationErrorFor(clean()), isNull);
  });

  test('no validation at all does not block', () {
    expect(blockingValidationErrorFor(null), isNull);
  });

  // Each of these used to be invisible to the gate.
  for (final key in [
    'same_day_sessions',
    'ineligible_assignments',
    'dayoff_violations',
    'blocked_period_violations',
    'lab_room_violations',
    'unplaced_rooms',
    'lab_theory_violations',
    'invalid_days',
  ]) {
    test('$key blocks publishing', () {
      final msg =
          blockingValidationErrorFor(clean({key: 2, 'ok': false}));
      expect(msg, isNotNull, reason: '$key must block');
      expect(msg, contains('2'));
    });
  }

  // The checks that always worked must keep working.
  for (final key in [
    'missing_courses',
    'under_scheduled',
    'over_scheduled',
    'unexpected_courses',
    'teacher_clashes',
    'cohort_clashes',
    'room_clashes',
    'invalid_time_slots',
  ]) {
    test('$key still blocks publishing', () {
      expect(blockingValidationErrorFor(clean({key: 1, 'ok': false})),
          isNotNull);
    });
  }

  test('an engine verdict of not-ok blocks even when no counter is named', () {
    // Forward compatibility: the engine grows a new check the app has not
    // learned about yet. Refuse rather than publish what it rejected.
    final msg = blockingValidationErrorFor(clean({'ok': false}));
    expect(msg, isNotNull);
    expect(msg, contains('invalid'));
  });

  test('every failing check is named in one message', () {
    final msg = blockingValidationErrorFor(clean({
      'ok': false,
      'missing_courses': 3,
      'same_day_sessions': 1,
      'unplaced_rooms': 2,
    }))!;
    expect(msg, contains('3 course(s) from the distribution are missing'));
    expect(msg, contains('1 course(s) scheduled twice on the same day'));
    expect(msg, contains('2 class(es) with no room assigned'));
  });

  test('a missing counter is treated as zero, not as a failure', () {
    expect(blockingValidationErrorFor({'ok': true}), isNull);
  });
}
