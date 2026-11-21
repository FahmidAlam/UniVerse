import { CircleNotch } from "@phosphor-icons/react";
import { AnimatePresence, motion, useReducedMotion } from "motion/react";
import { Button } from "@/components/ui/Button";
import { cn } from "@/lib/utils";

interface StickyDirtyBarProps {
  isDirty: boolean;
  isSaving?: boolean;
  message?: string;
  saveLabel?: string;
  discardLabel?: string;
  docked?: boolean;
  onDiscard: () => void;
  onSave?: () => void;
  formId?: string;
  className?: string;
}

export function StickyDirtyBar({
  isDirty,
  isSaving = false,
  message = "Unsaved changes ready to review",
  saveLabel = "Save Changes",
  discardLabel = "Discard",
  docked = false,
  onDiscard,
  onSave,
  formId,
  className,
}: StickyDirtyBarProps) {
  const prefersReducedMotion = useReducedMotion() ?? false;

  return (
    <AnimatePresence initial={false}>
      {isDirty && (
        <motion.div
          role="region"
          aria-label="Unsaved changes"
          data-testid="sticky-dirty-bar"
          initial={prefersReducedMotion ? false : { opacity: 0, y: 8 }}
          animate={{ opacity: 1, y: 0 }}
          exit={prefersReducedMotion ? undefined : { opacity: 0, y: 6 }}
          transition={{ duration: 0.16, ease: [0.16, 1, 0.3, 1] }}
          className={cn(
            docked ? "mt-6" : "sticky bottom-3 z-20 mt-6",
            "flex flex-wrap items-center justify-between gap-3 rounded-[var(--r-card)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-4 py-2.5 shadow-[var(--shadow-popover)]",
            className,
          )}
        >
          <div className="flex items-center gap-2 text-[12.5px] font-medium text-[var(--ink-primary)]">
            <span
              className="h-2 w-2 shrink-0 rounded-full bg-[var(--sem-joint-bar)]"
              aria-hidden="true"
            />
            <span>{message}</span>
          </div>

          <div className="flex items-center gap-2">
            <Button
              variant="secondary"
              size="sm"
              disabled={isSaving}
              onClick={onDiscard}
            >
              {discardLabel}
            </Button>
            <Button
              variant="primary"
              size="sm"
              type={formId ? "submit" : "button"}
              form={formId}
              disabled={isSaving}
              onClick={formId ? undefined : onSave}
            >
              {isSaving && (
                <CircleNotch
                  size={14}
                  className="animate-spin"
                  aria-hidden="true"
                />
              )}
              <span>{saveLabel}</span>
            </Button>
          </div>
        </motion.div>
      )}
    </AnimatePresence>
  );
}
