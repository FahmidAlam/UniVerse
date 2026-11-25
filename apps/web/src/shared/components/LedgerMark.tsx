interface LedgerMarkProps {
  size?: number;
  className?: string;
}

/**
 * Geometric Archival Ledger emblem for UniVerse Web.
 * Clean static hairline grid with X-Azure Blue active cell mark.
 */
export function LedgerMark({ size = 28, className }: LedgerMarkProps) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 32 32"
      fill="none"
      aria-hidden="true"
      className={className}
    >
      <rect
        x="2"
        y="2"
        width="28"
        height="28"
        rx="6"
        fill="var(--action-primary)"
      />
      <rect
        x="6.5"
        y="6.5"
        width="19"
        height="19"
        rx="2.5"
        stroke="var(--action-primary-ink)"
        strokeWidth="1.3"
        strokeOpacity="0.88"
      />
      <line
        x1="6.5"
        y1="13"
        x2="25.5"
        y2="13"
        stroke="var(--action-primary-ink)"
        strokeWidth="1.15"
        strokeOpacity="0.45"
      />
      <line
        x1="13"
        y1="6.5"
        x2="13"
        y2="25.5"
        stroke="var(--action-primary-ink)"
        strokeWidth="1.15"
        strokeOpacity="0.45"
      />
      <rect
        x="15.25"
        y="15.25"
        width="7.75"
        height="7.75"
        rx="1.25"
        fill="var(--accent-brand)"
        stroke="var(--accent-brand-soft)"
        strokeWidth="1.1"
      />
    </svg>
  );
}
