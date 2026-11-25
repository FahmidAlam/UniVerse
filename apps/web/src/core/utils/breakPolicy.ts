import { ClockTime } from "@/core/utils/clockTime";
import {
  ONLINE_SLOT_IDX,
  type PeriodDefinition,
} from "@/features/admin/services/settingsService";

export interface MiddayBreakInfo {
  afterPeriodIdx: number | null;
  start: string;
  end: string;
  durationMinutes: number;
}

const MIN_MIDDAY_BREAK_MINUTES = 15;
const DEFAULT_BREAK_MINUTES = 25;
const DEFAULT_TRANSITION_MINUTES = 5;

/**
 * Resolves the midday break position and clock window from `periods`.
 * Detects the primary clock gap (`next.start - prev.end >= 15 min`) among regular
 * on-campus periods (`idx < ONLINE_SLOT_IDX`). Returns `afterPeriodIdx: null`
 * when no >= 15 min gap exists (representing "No Break").
 */
export function resolveMiddayBreak(
  periods: readonly PeriodDefinition[],
): MiddayBreakInfo {
  const regular = periods
    .filter((p) => p.idx < ONLINE_SLOT_IDX)
    .slice()
    .sort((a, b) => a.idx - b.idx);

  if (regular.length < 2) {
    return { afterPeriodIdx: null, start: "", end: "", durationMinutes: 0 };
  }

  let best: MiddayBreakInfo | null = null;
  for (let i = 0; i < regular.length - 1; i += 1) {
    const prev = regular[i]!;
    const next = regular[i + 1]!;
    const prevEnd = ClockTime.toMinutes(prev.end);
    const nextStart = ClockTime.toMinutes(next.start);
    if (prevEnd === null || nextStart === null) continue;
    const gap = nextStart - prevEnd;
    if (gap >= MIN_MIDDAY_BREAK_MINUTES) {
      if (!best || gap > best.durationMinutes) {
        best = {
          afterPeriodIdx: prev.idx,
          start: ClockTime.toHm(prev.end),
          end: ClockTime.toHm(next.start),
          durationMinutes: gap,
        };
      }
    }
  }

  return best ?? { afterPeriodIdx: null, start: "", end: "", durationMinutes: 0 };
}

/**
 * Returns the period index immediately following the midday break (for border/divider
 * placement before that column), or `null` when No Break is active.
 */
export function resolveBreakBeforePeriodIdx(
  periods: readonly PeriodDefinition[],
): number | null {
  const info = resolveMiddayBreak(periods);
  if (info.afterPeriodIdx === null) return null;
  const regular = periods
    .filter((p) => p.idx < ONLINE_SLOT_IDX)
    .slice()
    .sort((a, b) => a.idx - b.idx);
  const idx = regular.findIndex((p) => p.idx === info.afterPeriodIdx);
  if (idx === -1 || idx + 1 >= regular.length) return null;
  return regular[idx + 1]!.idx;
}

/**
 * Recomputes regular on-campus period start/end clocks so the midday break sits
 * immediately after `afterPeriodIdx` (or removes the break when `null`),
 * preserving each period's duration, `idx`, and `col` for `engine/render.py`.
 */
export function applyMiddayBreakToPeriods(
  periods: readonly PeriodDefinition[],
  afterPeriodIdx: number | null,
  breakDurationMinutes = DEFAULT_BREAK_MINUTES,
  transitionMinutes = DEFAULT_TRANSITION_MINUTES,
): PeriodDefinition[] {
  const regular = periods
    .filter((p) => p.idx < ONLINE_SLOT_IDX)
    .slice()
    .sort((a, b) => a.idx - b.idx);
  const online = periods
    .filter((p) => p.idx >= ONLINE_SLOT_IDX)
    .slice()
    .sort((a, b) => a.idx - b.idx);

  if (regular.length === 0) return [...periods];

  const safeBreakMin = Math.max(
    MIN_MIDDAY_BREAK_MINUTES,
    Math.min(120, Math.round(breakDurationMinutes) || DEFAULT_BREAK_MINUTES),
  );
  const safeTransitionMin = Math.max(1, Math.min(14, transitionMinutes));

  const updatedRegular: PeriodDefinition[] = [];
  for (let i = 0; i < regular.length; i += 1) {
    const p = regular[i]!;
    const origStart = ClockTime.toMinutes(p.start);
    const origEnd = ClockTime.toMinutes(p.end);
    const duration =
      origStart !== null && origEnd !== null && origEnd > origStart
        ? origEnd - origStart
        : 75;

    let startMin: number;
    if (i === 0) {
      startMin = origStart ?? 8 * 60 + 50;
    } else {
      const prev = updatedRegular[i - 1]!;
      const prevEnd = ClockTime.toMinutes(prev.end)!;
      const gap =
        afterPeriodIdx !== null && prev.idx === afterPeriodIdx
          ? safeBreakMin
          : safeTransitionMin;
      startMin = prevEnd + gap;
    }

    const endMin = startMin + duration;
    const startStr = ClockTime.toHm(ClockTime.fromMinutes(startMin));
    const endStr = ClockTime.toHm(ClockTime.fromMinutes(endMin));
    updatedRegular.push({
      ...p,
      start: startStr,
      end: endStr,
      label: `${startStr}-${endStr}`,
    });
  }

  return [...updatedRegular, ...online];
}
