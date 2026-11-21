import { DeviceMobile } from "@phosphor-icons/react";
import { cn } from "@/lib/utils";

interface MobileCompanionStripProps {
  compact?: boolean;
  className?: string;
}

/**
 * Calm institutional guidance card explaining the boundary between
 * UniVerse Web (Administrators) and the UniVerse Flutter Mobile app (Android & iOS).
 */
export function MobileCompanionStrip({
  compact = false,
  className,
}: MobileCompanionStripProps) {
  return (
    <section
      id="mobile-apps"
      aria-label="Mobile app guidance for students and teachers"
      className={cn(
        "rounded-[var(--r-card)] border border-[var(--border-subtle)] bg-[var(--bg-elevated)] text-[var(--ink-primary)] shadow-[var(--highlight-top)]",
        compact ? "p-3.5" : "p-5",
        className,
      )}
    >
      <div className="flex items-start gap-3">
        <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-[var(--r-control)] border border-[var(--accent-pine-border)] bg-[var(--accent-pine-soft)] text-[var(--accent-pine)]">
          <DeviceMobile size={18} aria-hidden="true" />
        </div>
        <div className="min-w-0 flex-1">
          <div className="flex flex-wrap items-center gap-2">
            <h2
              className={cn(
                "font-semibold tracking-[-0.015em] text-[var(--ink-primary)]",
                compact ? "text-[13.5px]" : "text-[15px]",
              )}
            >
              Students &amp; Teachers: Use UniVerse Mobile
            </h2>
            <span className="rounded-[4px] border border-[var(--border-subtle)] bg-[var(--bg-surface)] px-1.5 py-0.5 font-mono-tabular text-[10.5px] font-medium text-[var(--ink-secondary)]">
              Android &amp; iOS
            </span>
          </div>
          <p
            className={cn(
              "mt-1 text-[var(--ink-secondary)]",
              compact ? "text-[12.5px] leading-[1.45]" : "text-[13.5px] leading-[1.55]",
            )}
          >
            This browser console is reserved for Routine Committee Administrators.
            Students and faculty can view live published schedules, cancellation
            notices, teacher directories, and room availability in the UniVerse
            mobile application on Android and iOS.
          </p>
        </div>
      </div>
    </section>
  );
}
