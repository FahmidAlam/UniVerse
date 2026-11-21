import * as SwitchPrimitive from "@radix-ui/react-switch";
import type { ComponentPropsWithoutRef } from "react";
import { cn } from "@/lib/utils";

export function Switch({
  className,
  ...props
}: ComponentPropsWithoutRef<typeof SwitchPrimitive.Root>) {
  return (
    <SwitchPrimitive.Root
      className={cn(
        "peer inline-flex h-[22px] w-[38px] shrink-0 cursor-pointer items-center rounded-full border border-[var(--border-control)] bg-[var(--bg-canvas)] p-[2px] transition-colors duration-[var(--dur-in)] ease-[var(--ease-out)] data-[state=checked]:border-[var(--accent-pine)] data-[state=checked]:bg-[var(--accent-pine)] disabled:cursor-not-allowed disabled:opacity-50 motion-reduce:transition-none",
        className,
      )}
      {...props}
    >
      <SwitchPrimitive.Thumb
        className={cn(
          "pointer-events-none block h-[16px] w-[16px] rounded-full bg-[var(--bg-elevated)] shadow-xs ring-0 transition-transform duration-[var(--dur-in)] ease-[var(--ease-out)] data-[state=checked]:translate-x-[16px] data-[state=unchecked]:translate-x-0 motion-reduce:transition-none",
        )}
      />
    </SwitchPrimitive.Root>
  );
}
