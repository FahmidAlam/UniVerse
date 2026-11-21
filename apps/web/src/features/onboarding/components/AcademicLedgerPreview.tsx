import {
  ArrowsCounterClockwise,
  CheckCircle,
  Info,
  ListBullets,
  Table,
  WarningCircle,
} from "@phosphor-icons/react";
import { motion } from "motion/react";
import { useMemo } from "react";
import { Badge } from "@/components/ui/Badge";
import { Switch } from "@/components/ui/Switch";
import {
  Tooltip,
  TooltipContent,
  TooltipTrigger,
} from "@/components/ui/Tooltip";
import {
  buildSandboxSlots,
  PERIODS_ALL,
  SANDBOX_DAYS,
  type SandboxLens,
  type ScheduleCategory,
} from "@/features/onboarding/data/routineFixtures";
import {
  useSpecimenStore,
  type SpecimenViewMode,
} from "@/features/onboarding/store/specimenStore";
import { cn } from "@/lib/utils";

const LENS_OPTIONS: readonly { value: SandboxLens; label: string }[] = [
  { value: "section", label: "Section" },
  { value: "faculty", label: "Faculty" },
  { value: "room", label: "Room" },
];

const VIEW_OPTIONS: readonly {
  value: SpecimenViewMode;
  label: string;
  Icon: typeof Table;
}[] = [
  { value: "matrix", label: "Matrix", Icon: Table },
  { value: "list", label: "List", Icon: ListBullets },
];

function categoryClass(category: ScheduleCategory): string {
  switch (category) {
    case "theory":
      return "slot-theory";
    case "lab":
      return "slot-lab";
    case "joint":
      return "slot-joint";
    case "block":
      return "slot-conflict";
  }
}

export function AcademicLedgerPreview({ compact = false }: { compact?: boolean }) {
  const {
    config,
    viewMode,
    toggleJummah,
    toggleR7,
    setSlots,
    setLens,
    setViewMode,
    resetSpecimen,
  } = useSpecimenStore();

  const periods = useMemo(
    () => PERIODS_ALL.slice(0, config.slots),
    [config.slots],
  );
  const slots = useMemo(() => buildSandboxSlots(config), [config]);

  const slotMap = useMemo(() => {
    const map = new Map<string, (typeof slots)[number]>();
    for (const s of slots) {
      map.set(`${s.day}-${s.period}`, s);
    }
    return map;
  }, [slots]);

  const hasConflict = !config.r7Enforced || !config.jummah;
  const lensTarget =
    config.lens === "section"
      ? "Batch 58 B+C"
      : config.lens === "faculty"
        ? "Faculty EBH"
        : "Lab ACL-1";

  const statusText = !config.r7Enforced
    ? "R7 violation highlighted: EBH scheduled on Thursday off-day."
    : !config.jummah
      ? "Friday P4 Jummah window unlocked: CSE-3202 overlaps prayer window."
      : "Sample rules clean: 0 overlaps across active days.";

  const isDefault =
    config.jummah &&
    config.r7Enforced &&
    config.slots === 6 &&
    config.lens === "section" &&
    viewMode === "matrix";

  return (
    <section
      aria-label="Illustrative timetable rule preview"
      className="ledger-sheet overflow-hidden"
    >
      {/* Permanent Honest Preview Disclosure Bar */}
      <div className="flex flex-wrap items-center justify-between gap-2 border-b border-[var(--border-subtle)] bg-[var(--bg-canvas)] px-4 py-2.5 text-[12px] text-[var(--ink-secondary)]">
        <div className="flex items-center gap-2">
          <Info
            size={15}
            className="shrink-0 text-[var(--accent-pine)]"
            aria-hidden="true"
          />
          <span className="font-medium text-[var(--ink-primary)]">
            Illustrative sample schedule — interactive preview only, not a live CP-SAT solver run.
          </span>
        </div>
        {!isDefault && (
          <button
            type="button"
            onClick={resetSpecimen}
            className="inline-flex h-[26px] items-center gap-1 rounded-[5px] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-2 text-[11.5px] font-medium text-[var(--ink-primary)] hover:bg-[var(--surface-hover)]"
          >
            <ArrowsCounterClockwise size={12} aria-hidden="true" />
            <span>Reset</span>
          </button>
        )}
      </div>

      {/* User-Controlled Rule Toggles & Lens Bar (Zero Auto-Loops) */}
      <div className="flex flex-col gap-3 border-b border-[var(--border-subtle)] bg-[var(--bg-surface)] px-4 py-3">
        <div className="flex flex-wrap items-center justify-between gap-2.5">
          {/* Lens Segmented Control */}
          <div
            role="group"
            aria-label="Schedule viewing lens"
            className="inline-flex h-[36px] items-center rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] p-0.5"
          >
            {LENS_OPTIONS.map((item) => {
              const active = config.lens === item.value;
              return (
                <button
                  key={item.value}
                  type="button"
                  aria-pressed={active}
                  onClick={() => setLens(item.value)}
                  className={cn(
                    "relative h-[30px] rounded-[5px] px-3 text-[12.5px] whitespace-nowrap transition-colors",
                    active
                      ? "font-semibold text-[var(--action-primary-ink)]"
                      : "font-medium text-[var(--ink-secondary)] hover:text-[var(--ink-primary)]",
                  )}
                >
                  {active && (
                    <motion.span
                      layoutId="specimen-lens-pill"
                      transition={{ duration: 0.18, ease: [0.16, 1, 0.3, 1] }}
                      className="absolute inset-0 rounded-[5px] bg-[var(--action-primary)]"
                      aria-hidden="true"
                    />
                  )}
                  <span className="reserved-bold relative z-10" data-label={item.label}>
                    {item.label}
                  </span>
                </button>
              );
            })}
          </div>

          <div className="flex flex-wrap items-center gap-2">
            {/* R15 6 vs 7 Slot Control */}
            <div
              role="group"
              aria-label="Daily period grid count"
              className="inline-flex h-[36px] items-center rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] p-0.5"
            >
              {([6, 7] as const).map((slotCount) => {
                const active = config.slots === slotCount;
                const label = slotCount === 6 ? "6-Slot" : "7-Slot + P7";
                return (
                  <button
                    key={slotCount}
                    type="button"
                    aria-pressed={active}
                    onClick={() => setSlots(slotCount)}
                    className={cn(
                      "relative h-[30px] rounded-[5px] px-2.5 text-[12px] whitespace-nowrap transition-colors",
                      active
                        ? "font-semibold text-[var(--accent-pine-ink)]"
                        : "font-medium text-[var(--ink-secondary)] hover:text-[var(--ink-primary)]",
                    )}
                  >
                    {active && (
                      <motion.span
                        layoutId="specimen-slots-pill"
                        transition={{ duration: 0.18, ease: [0.16, 1, 0.3, 1] }}
                        className="absolute inset-0 rounded-[5px] bg-[var(--accent-pine)]"
                        aria-hidden="true"
                      />
                    )}
                    <span className="relative z-10">{label}</span>
                  </button>
                );
              })}
            </div>

            {/* Matrix / List View Switch */}
            <div
              role="group"
              aria-label="Preview layout format"
              className="inline-flex h-[36px] items-center rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] p-0.5"
            >
              {VIEW_OPTIONS.map(({ value, label, Icon }) => {
                const active = viewMode === value;
                return (
                  <button
                    key={value}
                    type="button"
                    aria-pressed={active}
                    onClick={() => setViewMode(value)}
                    className={cn(
                      "relative inline-flex h-[30px] items-center gap-1.5 rounded-[5px] px-2.5 text-[12px] whitespace-nowrap transition-colors",
                      active
                        ? "font-semibold text-[var(--ink-primary)]"
                        : "font-medium text-[var(--ink-secondary)] hover:text-[var(--ink-primary)]",
                    )}
                  >
                    {active && (
                      <motion.span
                        layoutId="specimen-view-pill"
                        transition={{ duration: 0.18, ease: [0.16, 1, 0.3, 1] }}
                        className="absolute inset-0 rounded-[5px] bg-[var(--surface-active)]"
                        aria-hidden="true"
                      />
                    )}
                    <Icon size={14} className="relative z-10" aria-hidden="true" />
                    <span className="relative z-10">{label}</span>
                  </button>
                );
              })}
            </div>
          </div>
        </div>

        {/* Rule Switches + Status Line */}
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div className="flex flex-wrap items-center gap-x-5 gap-y-2">
            <label
              htmlFor="specimen-jummah-switch"
              className="inline-flex min-h-[32px] cursor-pointer items-center gap-2 text-[12.5px] font-medium text-[var(--ink-primary)]"
            >
              <Switch
                id="specimen-jummah-switch"
                checked={config.jummah}
                onCheckedChange={toggleJummah}
              />
              <span className="whitespace-nowrap">Friday P4 Jummah Lock</span>
            </label>

            <label
              htmlFor="specimen-r7-switch"
              className="inline-flex min-h-[32px] cursor-pointer items-center gap-2 text-[12.5px] font-medium text-[var(--ink-primary)]"
            >
              <Switch
                id="specimen-r7-switch"
                checked={config.r7Enforced}
                onCheckedChange={toggleR7}
              />
              <span className="whitespace-nowrap">R7 Faculty Off-Day (EBH)</span>
            </label>
          </div>

          <div className="flex flex-wrap items-center gap-2">
            <Badge tone="neutral" mono>
              {lensTarget}
            </Badge>
            <Badge tone={hasConflict ? "conflict" : "lab"}>
              {hasConflict ? (
                <WarningCircle size={13} aria-hidden="true" />
              ) : (
                <CheckCircle size={13} aria-hidden="true" />
              )}
              <span>{hasConflict ? "Rule conflict" : "Rules satisfied"}</span>
            </Badge>
          </div>
        </div>

        <p className="text-[12px] text-[var(--ink-secondary)]">{statusText}</p>
      </div>

      {/* Main Preview Content */}
      <div className="bg-[var(--bg-elevated)] p-3 sm:p-4">
        {viewMode === "matrix" ? (
          <div className="overflow-x-auto pb-1">
            <table className="w-full min-w-[540px] border-collapse text-left">
              <thead>
                <tr className="border-b border-[var(--border-subtle)]">
                  <th
                    scope="col"
                    className="w-[42px] py-2 pr-1.5 text-[11px] font-semibold tracking-[0.04em] text-[var(--ink-muted)] uppercase"
                  >
                    Day
                  </th>
                  {periods.map((period) => (
                    <th
                      key={period.idx}
                      scope="col"
                      className={cn(
                        "border-l border-[var(--border-subtle)] px-1.5 py-2 align-bottom",
                        compact ? "min-w-[76px]" : "min-w-[82px]",
                      )}
                    >
                      <div className="font-mono-tabular text-[11px] font-semibold tracking-[0.03em] text-[var(--ink-primary)]">
                        {period.code}
                      </div>
                      <div className="font-mono-tabular text-[10.5px] font-normal text-[var(--ink-muted)]">
                        {period.time}
                      </div>
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody className="divide-y divide-[var(--border-subtle)]">
                {SANDBOX_DAYS.map((day) => (
                  <tr key={day} className="align-top">
                    <th
                      scope="row"
                      className="py-2.5 pr-2 font-mono-tabular text-[12px] font-medium text-[var(--ink-secondary)]"
                    >
                      {day}
                    </th>
                    {periods.map((period) => {
                      const slot = slotMap.get(`${day}-${period.idx}`);
                      return (
                        <td
                          key={`${day}-${period.idx}`}
                          className="border-l border-[var(--border-subtle)] p-1.5"
                        >
                          {slot ? (
                            slot.overrideNote ? (
                              <Tooltip>
                                <TooltipTrigger asChild>
                                  <button
                                    type="button"
                                    aria-label={`${slot.code} ${slot.actorOrGroup} ${slot.room}: ${slot.overrideNote}`}
                                    className={cn(
                                      "slot-override-corner flex w-full flex-col gap-0.5 rounded-[5px] px-2 py-1.5 text-left transition-opacity focus-visible:outline-2",
                                      categoryClass(slot.category),
                                    )}
                                  >
                                    <span className="font-mono-tabular text-[11.5px] font-semibold leading-tight whitespace-nowrap">
                                      {slot.code}
                                    </span>
                                    <span className="text-[11px] leading-tight">
                                      {slot.actorOrGroup}{" "}
                                      <span className="font-mono-tabular whitespace-nowrap">
                                        {slot.room}
                                      </span>
                                    </span>
                                  </button>
                                </TooltipTrigger>
                                <TooltipContent>{slot.overrideNote}</TooltipContent>
                              </Tooltip>
                            ) : (
                              <div
                                className={cn(
                                  "flex flex-col gap-0.5 rounded-[5px] px-2 py-1.5",
                                  categoryClass(slot.category),
                                )}
                              >
                                <span className="font-mono-tabular text-[11.5px] font-semibold leading-tight whitespace-nowrap">
                                  {slot.code}
                                </span>
                                <span className="text-[11px] leading-tight">
                                  {slot.actorOrGroup}{" "}
                                  <span className="font-mono-tabular whitespace-nowrap">
                                    {slot.room}
                                  </span>
                                </span>
                              </div>
                            )
                          ) : (
                            <div
                              className="h-[42px] rounded-[4px] border border-dashed border-[var(--border-subtle)]/70"
                              aria-hidden="true"
                            />
                          )}
                        </td>
                      );
                    })}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <div className="divide-y divide-[var(--border-subtle)] border-t border-b border-[var(--border-subtle)]">
            {slots.map((slot) => {
              const pInfo = PERIODS_ALL.find((p) => p.idx === slot.period);
              return (
                <div
                  key={slot.id}
                  className="grid grid-cols-[54px_76px_minmax(0,1fr)_auto] items-center gap-3 px-2 py-2.5 text-[13px]"
                >
                  <span className="font-mono-tabular text-[12px] font-medium text-[var(--ink-secondary)]">
                    {slot.day}
                  </span>
                  <span className="font-mono-tabular text-[12px] text-[var(--ink-muted)] whitespace-nowrap">
                    {pInfo?.code} · {pInfo?.time}
                  </span>
                  <div className="flex min-w-0 flex-wrap items-center gap-2">
                    <span className="font-mono-tabular font-semibold text-[var(--ink-primary)] whitespace-nowrap">
                      {slot.code}
                    </span>
                    <span className="text-[12.5px] text-[var(--ink-secondary)]">
                      {slot.actorOrGroup}
                    </span>
                  </div>
                  <div className="flex items-center gap-2">
                    <Badge
                      tone={
                        slot.category === "block"
                          ? "conflict"
                          : slot.category === "joint"
                            ? "joint"
                            : slot.category
                      }
                      mono
                    >
                      {slot.room}
                    </Badge>
                  </div>
                </div>
              );
            })}
          </div>
        )}

        {/* Restrained Legend Bar */}
        <div className="mt-3 flex flex-wrap items-center justify-between gap-2 border-t border-[var(--border-subtle)] pt-3 text-[11.5px] text-[var(--ink-secondary)]">
          <div className="flex flex-wrap items-center gap-x-4 gap-y-1.5">
            <span className="inline-flex items-center gap-1.5">
              <span
                className="h-2.5 w-2.5 rounded-[2px] bg-[var(--sem-theory-bar)]"
                aria-hidden="true"
              />
              Theory
            </span>
            <span className="inline-flex items-center gap-1.5">
              <span
                className="h-2.5 w-2.5 rounded-[2px] bg-[var(--sem-lab-bar)]"
                aria-hidden="true"
              />
              Lab / Sessional
            </span>
            <span className="inline-flex items-center gap-1.5">
              <span
                className="h-2.5 w-2.5 rounded-[2px] bg-[var(--sem-joint-bar)]"
                aria-hidden="true"
              />
              Joint B+C
            </span>
            <span className="inline-flex items-center gap-1.5">
              <span
                className="h-2.5 w-2.5 rounded-[2px] bg-[var(--sem-conflict-bar)]"
                aria-hidden="true"
              />
              Hard Block / Rule Alert
            </span>
          </div>
          <span className="font-mono-tabular text-[11px] text-[var(--ink-muted)]">
            Hover or focus corner-marked slots for rule overrides
          </span>
        </div>
      </div>
    </section>
  );
}
