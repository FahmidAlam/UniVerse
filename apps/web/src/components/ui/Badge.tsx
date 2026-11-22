import { cva, type VariantProps } from "class-variance-authority";
import type { HTMLAttributes } from "react";
import { cn } from "@/lib/utils";

export const badgeVariants = cva(
  "inline-flex items-center gap-1.5 rounded-[var(--r-pill)] border px-2.5 py-0.5 text-[11px] font-medium leading-[1.3] whitespace-nowrap",
  {
    variants: {
      tone: {
        neutral:
          "border-[var(--border-strong)] bg-[var(--bg-raised)] text-[var(--ink-secondary)]",
        pine:
          "border-[var(--border-strong)] bg-[var(--bg-raised)] text-[var(--ink-primary)]",
        theory:
          "border-[var(--border-strong)] bg-[var(--bg-raised)] text-[var(--ink-primary)]",
        lab:
          "border-[var(--border-strong)] bg-[var(--bg-raised)] text-[var(--ink-primary)]",
        joint:
          "border-[var(--border-strong)] bg-[var(--bg-raised)] text-[var(--ink-primary)]",
        conflict:
          "border-[var(--sem-conflict-border)] bg-[var(--sem-conflict-bg)] text-[var(--sem-conflict-ink)]",
      },
      mono: {
        true: "font-mono-tabular",
        false: "",
      },
    },
    defaultVariants: {
      tone: "neutral",
      mono: false,
    },
  },
);

const DOT_TONE_CLASS: Record<
  NonNullable<VariantProps<typeof badgeVariants>["tone"]>,
  string | null
> = {
  neutral: null,
  pine: "bg-[var(--accent-brand)]",
  theory: "bg-[var(--sem-theory-bar)]",
  lab: "bg-[var(--sem-lab-bar)]",
  joint: "bg-[var(--sem-joint-bar)]",
  conflict: "bg-[var(--sem-conflict-bar)]",
};

export interface BadgeProps
  extends HTMLAttributes<HTMLSpanElement>,
    VariantProps<typeof badgeVariants> {
  dot?: boolean;
}

export function Badge({
  className,
  tone = "neutral",
  mono,
  dot,
  children,
  ...props
}: BadgeProps) {
  const dotColor = tone ? DOT_TONE_CLASS[tone] : null;
  const showDot = (dot ?? Boolean(dotColor)) && dotColor !== null;

  return (
    <span className={cn(badgeVariants({ tone, mono }), className)} {...props}>
      {showDot && (
        <span
          aria-hidden="true"
          className={cn("h-1.5 w-1.5 shrink-0 rounded-full", dotColor)}
        />
      )}
      {children}
    </span>
  );
}
