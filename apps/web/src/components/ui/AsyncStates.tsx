import {
  ArrowsClockwise,
  Info,
  WarningCircle,
} from "@phosphor-icons/react";
import type { ReactNode } from "react";
import { Button } from "@/components/ui/Button";

export function LedgerTableSkeleton({
  rows = 6,
  label = "Loading records",
}: {
  rows?: number;
  label?: string;
}) {
  return (
    <div
      className="ledger-card overflow-hidden"
      aria-label={label}
      data-testid="ledger-loading-skeleton"
    >
      <div className="h-[42px] border-b border-[var(--border-subtle)] bg-[var(--bg-canvas)]/60 px-4" />
      <div className="divide-y divide-[var(--border-subtle)]">
        {Array.from({ length: rows }).map((_, i) => (
          <div key={i} className="flex items-center gap-4 px-4 py-3.5">
            <div className="h-4 w-4 animate-pulse rounded bg-[var(--surface-active)]" />
            <div className="h-4 w-28 animate-pulse rounded bg-[var(--surface-active)]" />
            <div className="h-4 flex-1 animate-pulse rounded bg-[var(--surface-hover)]" />
            <div className="h-4 w-20 animate-pulse rounded bg-[var(--surface-active)]" />
          </div>
        ))}
      </div>
    </div>
  );
}

export function LedgerEmptyState({
  icon,
  title,
  description,
  actionLabel,
  onAction,
}: {
  icon?: ReactNode;
  title: string;
  description: string;
  actionLabel?: string;
  onAction?: () => void;
}) {
  return (
    <div
      data-testid="ledger-empty-state"
      className="ledger-card flex flex-col items-start gap-3 p-6"
    >
      {icon && (
        <div className="flex h-10 w-10 items-center justify-center rounded-[var(--r-control)] border border-[var(--border-subtle)] bg-[var(--bg-surface)] text-[var(--accent-pine)]">
          {icon}
        </div>
      )}
      <div>
        <h2 className="text-[16px] font-semibold text-[var(--ink-primary)]">
          {title}
        </h2>
        <p className="mt-1 max-w-[58ch] text-[13.5px] leading-[1.55] text-[var(--ink-secondary)]">
          {description}
        </p>
      </div>
      {actionLabel && onAction && (
        <Button variant="primary" size="md" onClick={onAction}>
          {actionLabel}
        </Button>
      )}
    </div>
  );
}

export function LedgerFilterEmpty({
  message = "No records match the active search or filters.",
  onReset,
}: {
  message?: string;
  onReset: () => void;
}) {
  return (
    <div
      data-testid="ledger-filter-empty"
      className="ledger-card flex flex-wrap items-center justify-between gap-3 px-5 py-6 text-[13px] text-[var(--ink-secondary)]"
    >
      <span>{message}</span>
      <Button variant="secondary" size="sm" onClick={onReset}>
        Reset Filters
      </Button>
    </div>
  );
}

export function LedgerErrorRecovery({
  title = "Unable to load records",
  message,
  onRetry,
}: {
  title?: string;
  message: string;
  onRetry: () => void;
}) {
  return (
    <div
      role="alert"
      data-testid="ledger-error-recovery"
      className="ledger-card flex flex-col items-start gap-3 border-[var(--sem-conflict-border)] bg-[var(--sem-conflict-bg)] p-5 text-[var(--sem-conflict-ink)]"
    >
      <div className="flex items-center gap-2 text-[15.5px] font-semibold">
        <WarningCircle size={19} aria-hidden="true" />
        <span>{title}</span>
      </div>
      <p className="text-[13px] leading-[1.5]">{message}</p>
      <Button variant="secondary" size="sm" onClick={onRetry}>
        <ArrowsClockwise size={14} aria-hidden="true" />
        <span>Retry</span>
      </Button>
    </div>
  );
}

export function StagedFeatureNotice({
  title,
  description,
}: {
  title: string;
  description: string;
}) {
  return (
    <div
      data-testid="staged-feature-notice"
      className="flex items-start gap-2.5 rounded-[var(--r-control)] border border-[var(--border-subtle)] bg-[var(--bg-canvas)] px-3.5 py-3 text-[12.5px] text-[var(--ink-secondary)]"
    >
      <Info
        size={16}
        className="mt-0.5 shrink-0 text-[var(--ink-muted)]"
        aria-hidden="true"
      />
      <div>
        <div className="font-semibold text-[var(--ink-primary)]">{title}</div>
        <p className="mt-0.5 leading-[1.5]">{description}</p>
      </div>
    </div>
  );
}
