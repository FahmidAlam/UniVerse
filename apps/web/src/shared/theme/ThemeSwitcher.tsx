import { Check, Desktop, Moon, Sun } from "@phosphor-icons/react";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/DropdownMenu";
import { Tooltip, TooltipContent, TooltipTrigger } from "@/components/ui/Tooltip";
import { cn } from "@/lib/utils";
import { useTheme, type ThemePreference } from "@/shared/theme/ThemeProvider";

const OPTIONS: readonly {
  value: ThemePreference;
  label: string;
  Icon: typeof Sun;
}[] = [
  { value: "light", label: "Light", Icon: Sun },
  { value: "dark", label: "Dark", Icon: Moon },
  { value: "system", label: "System", Icon: Desktop },
];

export function ThemeSwitcher({
  compact = false,
  className,
}: {
  compact?: boolean;
  className?: string;
}) {
  const { preference, resolvedTheme, setPreference } = useTheme();
  const ActiveIcon =
    preference === "system"
      ? Desktop
      : resolvedTheme === "dark"
        ? Moon
        : Sun;

  return (
    <DropdownMenu>
      <Tooltip>
        <TooltipTrigger asChild>
          <DropdownMenuTrigger asChild>
            <button
              type="button"
              data-testid="theme-switcher-trigger"
              aria-label={`Theme: ${preference} (${resolvedTheme} active)`}
              className={cn(
                "inline-flex h-[34px] items-center justify-center gap-1.5 rounded-[var(--r-control)] border border-[var(--border-subtle)] bg-[var(--bg-elevated)] px-2.5 text-[12.5px] font-medium text-[var(--ink-secondary)] transition-colors hover:bg-[var(--surface-hover)] hover:text-[var(--ink-primary)]",
                compact && "w-[34px] px-0",
                className,
              )}
            >
              <ActiveIcon size={15} aria-hidden="true" />
              {!compact && (
                <span className="hidden capitalize sm:inline">{preference}</span>
              )}
            </button>
          </DropdownMenuTrigger>
        </TooltipTrigger>
        <TooltipContent side="bottom">
          Appearance: {preference} ({resolvedTheme})
        </TooltipContent>
      </Tooltip>

      <DropdownMenuContent
        align="end"
        onCloseAutoFocus={(e) => e.preventDefault()}
        className="w-[156px]"
      >
        {OPTIONS.map(({ value, label, Icon }) => {
          const selected = preference === value;
          return (
            <DropdownMenuItem
              key={value}
              data-testid={`theme-option-${value}`}
              onSelect={() => setPreference(value)}
              className="flex items-center justify-between gap-2"
            >
              <span className="flex items-center gap-2">
                <Icon size={14} aria-hidden="true" />
                <span>{label}</span>
              </span>
              {selected && (
                <Check
                  size={13}
                  className="text-[var(--accent-brand)]"
                  aria-hidden="true"
                />
              )}
            </DropdownMenuItem>
          );
        })}
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
