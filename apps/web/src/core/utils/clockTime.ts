/**
 * Canonical 24-hour clock normalization & teaching-sequence verification.
 * Exact parity with `lib/core/utils/clock_time.dart` and `engine/render.py` (`HH:MM`).
 */

const LAST_AFTERNOON_HOUR = 7;
const MINUTES_PER_HALF_DAY = 12 * 60;
const MINUTES_PER_DAY = 24 * 60;

function two(value: number): string {
  return String(value).padStart(2, "0");
}

function formatHms(h: number, m: number, s = 0): string {
  return `${two(h)}:${two(m)}:${two(s)}`;
}

export const ClockTime = {
  /**
   * Parses messy time strings ("13:10", "1:50", "1:50 PM", "9:00 AM", Excel fractional day)
   * into canonical `HH:MM:SS` 24-hour literals, or `null` if unrecognizable.
   */
  normalize(value: string): string | null {
    const text = value.trim();
    if (!text) return null;

    if (/^(?:0?\.\d+|0(?:\.0+)?)$/.test(text)) {
      const serial = Number.parseFloat(text);
      if (Number.isFinite(serial) && serial >= 0 && serial < 1) {
        return ClockTime.fromMinutes(Math.round(serial * MINUTES_PER_DAY));
      }
    }

    const match =
      /^(\d{1,2})(?::(\d{1,2}))?(?::(\d{1,2}))?\s*(a\.?m\.?|p\.?m\.?)?$/i.exec(
        text,
      );
    if (!match) return null;

    let hour = Number.parseInt(match[1] ?? "", 10);
    const minute = match[2] ? Number.parseInt(match[2], 10) : 0;
    const second = match[3] ? Number.parseInt(match[3], 10) : 0;

    if (
      !Number.isFinite(hour) ||
      !Number.isFinite(minute) ||
      !Number.isFinite(second) ||
      hour > 24 ||
      minute > 59 ||
      second > 59
    ) {
      return null;
    }

    const meridiem = match[4]?.toLowerCase().replace(/\./g, "") ?? "";
    const hasExplicitTwoDigitHms =
      (match[1]?.length ?? 0) === 2 && match[3] !== undefined;

    if (meridiem === "pm") {
      if (hour < 12) hour += 12;
    } else if (meridiem === "am") {
      if (hour === 12) hour = 0;
    } else if (
      hour >= 1 &&
      hour <= LAST_AFTERNOON_HOUR &&
      !hasExplicitTwoDigitHms
    ) {
      hour += 12;
    }

    if (hour >= 24) hour -= 24;
    return formatHms(hour, minute, second);
  },

  normalizeOr(value: string): string {
    return ClockTime.normalize(value) ?? value.trim();
  },

  /** Drops seconds field: `"13:50:00"` -> `"13:50"` (required by `engine/render.py`). */
  toHm(value: string): string {
    const normalized = ClockTime.normalize(value);
    const source = normalized ?? value.trim();
    const parts = source.split(":");
    if (parts.length < 2) return source;
    return `${two(Number.parseInt(parts[0]!, 10) || 0)}:${two(Number.parseInt(parts[1]!, 10) || 0)}`;
  },

  /** Converts into canonical Postgres `time` literal (`"HH:MM:SS"`). */
  toHms(value: string): string {
    return ClockTime.normalize(value) ?? value.trim();
  },

  toMinutes(value: string): number | null {
    const normalized = ClockTime.normalize(value) ?? value.trim();
    const parts = normalized.split(":");
    if (parts.length < 2) return null;
    const hour = Number.parseInt(parts[0] ?? "", 10);
    const minute = Number.parseInt(parts[1] ?? "", 10);
    if (!Number.isFinite(hour) || !Number.isFinite(minute)) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return hour * 60 + minute;
  },

  fromMinutes(totalMinutes: number): string {
    const wrapped =
      ((totalMinutes % MINUTES_PER_DAY) + MINUTES_PER_DAY) % MINUTES_PER_DAY;
    return formatHms(Math.floor(wrapped / 60), wrapped % 60, 0);
  },

  /**
   * Repairs missing PM markers across a teaching-order list of `(start, end)` slots.
   */
  repairSequence<T extends { start: string; end: string }>(slots: readonly T[]): T[] {
    let previousStart = -1;
    return slots.map((slot) => {
      let startMin = ClockTime.toMinutes(slot.start);
      let endMin = ClockTime.toMinutes(slot.end);
      if (startMin === null || endMin === null) return slot;

      if (startMin < previousStart && startMin + MINUTES_PER_HALF_DAY < MINUTES_PER_DAY) {
        startMin += MINUTES_PER_HALF_DAY;
      }
      if (endMin <= startMin && endMin + MINUTES_PER_HALF_DAY < MINUTES_PER_DAY) {
        endMin += MINUTES_PER_HALF_DAY;
      }

      previousStart = startMin;
      return {
        ...slot,
        start: ClockTime.toHm(ClockTime.fromMinutes(startMin)),
        end: ClockTime.toHm(ClockTime.fromMinutes(endMin)),
      };
    });
  },

  /**
   * Validates ordered teaching slots: all bounds valid `HH:MM`, `end > start`,
   * and each subsequent period starts at or after the previous period ends.
   */
  validateMonotonicPeriods(
    periods: ReadonlyArray<{ idx: number; start: string; end: string }>,
  ): string | null {
    let prevEnd = -1;
    for (let i = 0; i < periods.length; i++) {
      const p = periods[i]!;
      const normStart = ClockTime.normalize(p.start);
      const normEnd = ClockTime.normalize(p.end);
      if (!normStart || !normEnd) {
        return `Period ${p.idx} requires valid 24-hour HH:MM start and end times.`;
      }
      const startMin = ClockTime.toMinutes(normStart);
      const endMin = ClockTime.toMinutes(normEnd);
      if (startMin === null || endMin === null) {
        return `Period ${p.idx} contains an unreadable clock value.`;
      }
      if (endMin <= startMin) {
        return `Period ${p.idx} end time must be strictly after its start time.`;
      }
      if (startMin < prevEnd) {
        return `Period ${p.idx} cannot start before Period ${periods[i - 1]!.idx} ends.`;
      }
      prevEnd = endMin;
    }
    return null;
  },
};
