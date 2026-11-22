import { cva, type VariantProps } from "class-variance-authority";
import type { ButtonHTMLAttributes } from "react";
import { cn } from "@/lib/utils";

export const buttonVariants = cva(
  "inline-flex items-center justify-center gap-2 whitespace-nowrap font-medium cursor-pointer disabled:opacity-55 disabled:cursor-not-allowed transition-[background-color,border-color,color,transform] duration-[var(--dur-in)] ease-[var(--ease-out)] active:scale-[0.97] motion-reduce:transition-none motion-reduce:active:scale-100 rounded-[var(--r-control)] select-none",
  {
    variants: {
      variant: {
        primary:
          "bg-[var(--action-primary)] text-[var(--action-primary-ink)] border border-[var(--action-primary)] font-semibold shadow-[inset_0_1px_0_oklch(1_0_0_/_0.14),0_1px_2px_oklch(0.205_0.012_75_/_0.12)] hover:bg-[var(--action-primary-hover)] hover:border-[var(--action-primary-hover)] active:bg-[var(--action-primary-active)]",
        secondary:
          "bg-[var(--bg-elevated)] text-[var(--ink-primary)] border border-[var(--border-control)] shadow-[var(--highlight-top)] hover:bg-[var(--surface-hover)] active:bg-[var(--surface-active)]",
        pine:
          "bg-[var(--accent-brand)] text-[var(--accent-brand-ink)] border border-[var(--accent-brand)] font-semibold hover:bg-[var(--accent-brand-hover)] hover:border-[var(--accent-brand-hover)]",
        ghost:
          "bg-transparent text-[var(--ink-secondary)] border border-transparent hover:bg-[var(--surface-hover)] hover:text-[var(--ink-primary)]",
        destructive:
          "bg-[var(--sem-conflict-bg)] text-[var(--sem-conflict-ink)] border border-[var(--sem-conflict-border)] font-semibold hover:bg-[color-mix(in_oklab,var(--sem-conflict-bg)_88%,var(--sem-conflict-bar))]",
      },
      size: {
        sm: "h-[32px] px-3 text-[12px]",
        md: "h-[36px] px-3.5 text-[13px]",
        lg: "h-[40px] px-5 text-[13.5px]",
        icon: "h-[36px] w-[36px] p-0",
      },
    },
    defaultVariants: {
      variant: "secondary",
      size: "md",
    },
  },
);

export interface ButtonProps
  extends ButtonHTMLAttributes<HTMLButtonElement>,
    VariantProps<typeof buttonVariants> {}

export function Button({
  className,
  variant,
  size,
  type = "button",
  ...props
}: ButtonProps) {
  return (
    <button
      type={type}
      className={cn(buttonVariants({ variant, size }), className)}
      {...props}
    />
  );
}
