import { ACADEMIC_WEEK_DAYS } from "@/features/admin/services/facultyService";
import { cn } from "@/lib/utils";

export interface SlotMatrixEntry {
  day: string;
  period_idx: number;
}

interface DaySlotMatrixPickerProps {
  label: string;
  description?: string;
  value: readonly SlotMatrixEntry[];
  onChange: (next: SlotMatrixEntry[]) => void;
  periodCount?: 6 | 7;
  tone?: "brand" | "joint" | "lab";
  testId?: string;
}

export function DaySlotMatrixPicker({
  label,
  description,
  value,
  onChange,
  periodCount = 7,
  tone = "brand",
  testId,
}: DaySlotMatrixPickerProps) {
  const periods = Array.from({ length: periodCount }, (_, idx) => idx + 1);
  const selectedKeys = new Set(value.map((v) => `${v.day}|${v.period_idx}`));

  const toggleSlot = (day: string, periodIdx: number) => {
    if (day === "Friday" && periodIdx === 4) return;
    const key = `${day}|${periodIdx}`;
    if (selectedKeys.has(key)) {
      onChange(
        value.filter((v) => !(v.day === day && v.period_idx === periodIdx)),
      );
    } else {
      onChange([...value, { day, period_idx: periodIdx }]);
    }
  };

  const activeClass =
    tone === "joint"
      ? "border-[var(--sem-joint-border)] bg-[var(--sem-joint-bg)] font-semibold text-[var(--sem-joint-ink)]"
      : tone === "lab"
        ? "border-[var(--sem-lab-border)] bg-[var(--sem-lab-bg)] font-semibold text-[var(--sem-lab-ink)]"
        : "border-[var(--accent-brand)] bg-[var(--accent-brand-soft)] font-semibold text-[var(--accent-brand)]";

  return (
    <div
      data-testid={testId}
      className="flex flex-col gap-2 rounded-[var(--r-control)] border border-[var(--border-subtle)] bg-[var(--bg-surface)] p-3"
    >
      <div className="flex flex-wrap items-center justify-between gap-2">
        <div>
          <div className="text-[12.5px] font-semibold text-[var(--ink-primary)]">
            {label}
          </div>
          {description && (
            <div className="text-[11.5px] text-[var(--ink-muted)]">
              {description}
            </div>
          )}
        </div>
        <div className="flex items-center gap-2">
          <span className="font-mono-tabular text-[11px] text-[var(--ink-muted)]">
            {value.length} slot{value.length === 1 ? "" : "s"}
          </span>
          {value.length > 0 && (
            <button
              type="button"
              onClick={() => onChange([])}
              className="rounded px-1.5 py-0.5 text-[11px] font-medium text-[var(--ink-secondary)] hover:bg-[var(--surface-hover)] hover:text-[var(--ink-primary)]"
            >
              Clear
            </button>
          )}
        </div>
      </div>

      <div className="overflow-x-auto">
        <table className="w-full border-collapse text-center">
          <thead>
            <tr>
              <th className="py-1 pr-2 text-left font-mono-tabular text-[10px] font-semibold text-[var(--ink-muted)] uppercase">
                Day
              </th>
              {periods.map((p) => (
                <th
                  key={p}
                  className="px-0.5 py-1 font-mono-tabular text-[10px] font-semibold text-[var(--ink-muted)]"
                >
                  P{p}
                </th>
              ))}
            </tr>
          </thead>
          <tbody className="divide-y divide-[var(--border-subtle)]">
            {ACADEMIC_WEEK_DAYS.map((day) => (
              <tr key={day}>
                <td className="py-1 pr-2 text-left font-mono-tabular text-[11px] font-medium text-[var(--ink-secondary)]">
                  {day.slice(0, 3)}
                </td>
                {periods.map((p) => {
                  const isJummah = day === "Friday" && p === 4;
                  const active = selectedKeys.has(`${day}|${p}`);
                  return (
                    <td key={p} className="p-0.5">
                      <button
                        type="button"
                        disabled={isJummah}
                        aria-pressed={active}
                        aria-label={`${day} Period ${p}${isJummah ? " Jummah blocked" : ""}`}
                        onClick={() => toggleSlot(day, p)}
                        className={cn(
                          "font-mono-tabular h-[26px] w-full min-w-[28px] rounded-[4px] border text-[10.5px] transition-colors",
                          isJummah
                            ? "cursor-not-allowed border-dashed border-[var(--border-subtle)] bg-[var(--bg-canvas)] text-[var(--ink-muted)] opacity-55"
                            : active
                              ? activeClass
                              : "border-[var(--border-subtle)] bg-[var(--bg-elevated)] text-[var(--ink-muted)] hover:border-[var(--border-strong)] hover:text-[var(--ink-primary)]",
                        )}
                      >
                        {isJummah ? "JUM" : active ? "✓" : "·"}
                      </button>
                    </td>
                  );
                })}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
