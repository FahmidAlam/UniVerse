import 'package:flutter_test/flutter_test.dart';
import 'package:universe/core/utils/clock_time.dart';

void main() {
  group('ClockTime.normalize', () {
    test('keeps values that already carry a 24-hour clock', () {
      expect(ClockTime.normalize('08:50'), '08:50:00');
      expect(ClockTime.normalize('13:10'), '13:10:00');
      expect(ClockTime.normalize('19:00'), '19:00:00');
      expect(ClockTime.normalize('16:55:00'), '16:55:00');
    });

    test('reads a bare afternoon hour as PM — the reported bug', () {
      // "1:50" out of the workbook used to reach Postgres as 01:50 (1:50 AM).
      expect(ClockTime.normalize('1:50'), '13:50:00');
      expect(ClockTime.normalize('2:55'), '14:55:00');
      expect(ClockTime.normalize('4:00'), '16:00:00');
      expect(ClockTime.normalize('5:05'), '17:05:00');
    });

    test('leaves bare morning hours alone', () {
      expect(ClockTime.normalize('9:00'), '09:00:00');
      expect(ClockTime.normalize('10:05'), '10:05:00');
      expect(ClockTime.normalize('11:10'), '11:10:00');
      expect(ClockTime.normalize('12:15'), '12:15:00');
    });

    test('honours an explicit meridiem over the heuristic', () {
      expect(ClockTime.normalize('1:50 PM'), '13:50:00');
      expect(ClockTime.normalize('9:00 AM'), '09:00:00');
      expect(ClockTime.normalize('12:00 AM'), '00:00:00');
      expect(ClockTime.normalize('12:00 PM'), '12:00:00');
      expect(ClockTime.normalize('7:30 a.m.'), '07:30:00');
    });

    test('handles Excel serial times and junk', () {
      expect(ClockTime.normalize('0.5'), '12:00:00');
      expect(ClockTime.normalize(''), isNull);
      expect(ClockTime.normalize('   '), isNull);
      expect(ClockTime.normalize('TBA'), isNull);
    });
  });

  group('ClockTime.repairSequence', () {
    test('pushes a backwards slot into the afternoon', () {
      // The real Leading University grid, as typed without any PM markers.
      final repaired = ClockTime.repairSequence([
        (start: '09:00:00', end: '10:05:00'),
        (start: '10:05:00', end: '11:10:00'),
        (start: '11:10:00', end: '12:15:00'),
        (start: '01:50:00', end: '02:55:00'), // lost its PM
        (start: '02:55:00', end: '04:00:00'), // lost its PM
        (start: '04:00:00', end: '05:05:00'), // lost its PM
      ]);

      expect(repaired.map((s) => s.start).toList(), [
        '09:00:00',
        '10:05:00',
        '11:10:00',
        '13:50:00',
        '14:55:00',
        '16:00:00',
      ]);
      expect(repaired.last.end, '17:05:00');
    });

    test('leaves an already-correct day untouched', () {
      final slots = [
        (start: '08:50:00', end: '10:05:00'),
        (start: '13:10:00', end: '14:25:00'),
        (start: '19:00:00', end: '20:20:00'),
      ];
      expect(ClockTime.repairSequence(slots), slots);
    });

    test('extends a slot whose end lands before its start', () {
      final repaired = ClockTime.repairSequence([
        (start: '16:00:00', end: '05:05:00'),
      ]);
      expect(repaired.single.end, '17:05:00');
    });

    test('passes unparseable entries through', () {
      final repaired = ClockTime.repairSequence([
        (start: 'TBA', end: 'TBA'),
      ]);
      expect(repaired.single.start, 'TBA');
    });
  });
}
