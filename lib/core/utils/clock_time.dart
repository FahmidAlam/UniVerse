// ============================================================
// FILE: lib/core/utils/clock_time.dart
// PURPOSE: Turn the messy clock text that arrives from routine
// workbooks and `timetable_settings.periods` into a canonical
// Postgres `time` literal ("HH:MM:SS", 24-hour).
//
// WHY THIS EXISTS:
// Period boundaries reach us in whatever shape the department typed
// into Excel — "13:10", "1:50", "1:50 PM", "9:00 AM", "(1:50-2:55 PM)".
// A bare 12-hour value like "1:50" used to be written through to the
// `routines` table verbatim, where Postgres read it as 01:50 — 1:50 in
// the MORNING. Afternoon classes then rendered in the middle of the
// night across every routine screen.
//
// Two defences, because a single one is not enough:
//   1. `normalize()`  — a bare hour of 1–7 can only be afternoon/evening
//      on a campus that teaches roughly 08:00–21:00, so it gets +12h.
//   2. `repairSequence()` — a teaching day only ever moves forward. Once
//      the periods are in column order their starts must increase; a slot
//      that jumps backwards lost its PM marker upstream. This catches
//      damage `normalize()` cannot see from one value alone.
//
// Used by the workbook uploader AND by the config sent to the timetable
// engine, so both producers of `routines` rows agree on the clock.
// ============================================================

/// Latest bare hour that must be read as PM. Campus teaching runs from
/// ~08:00 to the 19:00–20:20 evening slot, so 1–7 without a meridiem is
/// always afternoon/evening; 8–12 is always morning.
const int _lastAfternoonHour = 7;

const int _minutesPerHalfDay = 12 * 60;
const int _minutesPerDay = 24 * 60;

abstract class ClockTime {
  /// Parses [value] and returns a canonical `HH:MM:SS` 24-hour literal.
  ///
  /// Returns `null` when [value] holds no recognisable clock time, so
  /// callers can decide whether to skip the row or keep the raw text.
  static String? normalize(String value) {
    final text = value.trim();
    if (text.isEmpty) return null;

    // Excel serial time — a fraction of a day (0.5 == 12:00).
    final serial = double.tryParse(text);
    if (serial != null && serial >= 0 && serial < 1) {
      return fromMinutes((serial * _minutesPerDay).round());
    }

    final match = RegExp(
      r'(\d{1,2})(?::(\d{1,2}))?(?::(\d{1,2}))?\s*(a\.?m\.?|p\.?m\.?)?',
      caseSensitive: false,
    ).firstMatch(text);
    if (match == null) return null;

    var hour = int.tryParse(match.group(1) ?? '');
    final minute = int.tryParse(match.group(2) ?? '') ?? 0;
    final second = int.tryParse(match.group(3) ?? '') ?? 0;
    if (hour == null || hour > 24 || minute > 59 || second > 59) return null;

    final meridiem = match.group(4)?.toLowerCase().replaceAll('.', '');
    if (meridiem == 'pm') {
      if (hour < 12) hour += 12;
    } else if (meridiem == 'am') {
      if (hour == 12) hour = 0;
    } else if (hour >= 1 && hour <= _lastAfternoonHour) {
      // Bare afternoon hour — the missing "PM" this whole file exists for.
      hour += 12;
    }
    if (hour >= 24) hour -= 24;

    return _format(hour, minute, second);
  }

  /// [normalize] but never fails — falls back to the original text so a
  /// value we cannot read is passed along rather than silently dropped.
  static String normalizeOr(String value) => normalize(value) ?? value.trim();

  /// Drops the seconds field: `"13:50:00"` -> `"13:50"`.
  ///
  /// The timetable engine's `render.py` unpacks period boundaries with
  /// `h, m = hhmm.split(":")`, so it accepts `HH:MM` and *only* `HH:MM` —
  /// handing it a third field raises "too many values to unpack". Postgres
  /// wants the full literal, so the two consumers get different shapes.
  static String toHm(String value) {
    final parts = value.split(':');
    return parts.length < 2 ? value : '${parts[0]}:${parts[1]}';
  }

  /// Minutes since midnight for an `HH:MM[:SS]` literal, or `null`.
  static int? toMinutes(String value) {
    final parts = value.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0].trim());
    final minute = int.tryParse(parts[1].trim());
    if (hour == null || minute == null) return null;
    return hour * 60 + minute;
  }

  /// Canonical literal for [totalMinutes] since midnight.
  static String fromMinutes(int totalMinutes) {
    final wrapped = totalMinutes % _minutesPerDay;
    return _format(wrapped ~/ 60, wrapped % 60, 0);
  }

  /// Repairs AM/PM damage across an ordered list of period boundaries.
  ///
  /// [slots] must already be in teaching order (period 1 first). Each entry
  /// is a `(start, end)` pair of canonical literals. A start earlier than the
  /// period before it, or an end at/before its own start, is pushed forward
  /// 12 hours — the only way those can happen on a real timetable is a lost
  /// PM marker. Values that cannot be parsed are passed through untouched.
  static List<({String start, String end})> repairSequence(
    List<({String start, String end})> slots,
  ) {
    final out = <({String start, String end})>[];
    var previousStart = -1;

    for (final slot in slots) {
      var start = toMinutes(slot.start);
      var end = toMinutes(slot.end);
      if (start == null || end == null) {
        out.add(slot);
        continue;
      }

      if (start < previousStart && start + _minutesPerHalfDay < _minutesPerDay) {
        start += _minutesPerHalfDay;
      }
      if (end <= start && end + _minutesPerHalfDay < _minutesPerDay) {
        end += _minutesPerHalfDay;
      }

      previousStart = start;
      out.add((start: fromMinutes(start), end: fromMinutes(end)));
    }

    return out;
  }

  static String _format(int h, int m, int s) =>
      '${_two(h)}:${_two(m)}:${_two(s)}';

  static String _two(int value) => value.toString().padLeft(2, '0');
}
