import { cva, type VariantProps } from "class-variance-authority";
import type { HTMLAttributes } from "react";
import { cn } from "@/lib/utils";

export const badgeVariants = cva(
  "inline-flex items-center gap-1.5 rounded-[5px] border px-2 py-0.5 text-[11px] font-medium leading-[1.3] whitespace-nowrap",
  {
    variants: {
      tone: {
        neutral:
          "border-[var(--border-subtle)] bg-[var(--sem-neutral-bg)] text-[var(--sem-neutral-ink)]",
        pine:
          "border-[var(--accent-pine-border)] bg-[var(--accent-pine-soft)] text-[var(--accent-pine)] font-semibold",
        theory:
          "border-[var(--sem-theory-border)] bg-[var(--sem-theory-bg)] text-[var(--sem-theory-ink)]",
        lab:
          "border-[var(--sem-lab-border)] bg-[var(--sem-lab-bg)] text-[var(--sem-lab-ink)]",
        joint:
          "border-[var(--sem-joint-border)] bg-[var(--sem-joint-bg)] text-[var(--sem-joint-ink)]",
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

export interface BadgeProps
  extends HTMLAttributes<HTMLSpanElement>,
    VariantProps<typeof badgeVariants> {}

export function Badge({ className, tone, mono, ...props }: BadgeProps) {
  return (
    <span className={cn(badgeVariants({ tone, mono }), className)} {...props} />
  );
}
