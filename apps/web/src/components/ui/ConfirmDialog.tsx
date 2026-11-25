import { WarningCircle, X } from "@phosphor-icons/react";
import { Button } from "@/components/ui/Button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogTitle,
} from "@/components/ui/Dialog";

interface ConfirmDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  title: string;
  description: string;
  confirmLabel?: string;
  cancelLabel?: string;
  tone?: "default" | "destructive";
  isPending?: boolean;
  onConfirm: () => void;
}

export function ConfirmDialog({
  open,
  onOpenChange,
  title,
  description,
  confirmLabel = "Confirm",
  cancelLabel = "Cancel",
  tone = "default",
  isPending = false,
  onConfirm,
}: ConfirmDialogProps) {
  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="fixed left-1/2 top-1/2 w-[calc(100%-32px)] max-w-[440px] -translate-x-1/2 -translate-y-1/2 p-5">
        <div className="flex items-start justify-between gap-3">
          <div className="flex items-start gap-2.5">
            {tone === "destructive" && (
              <WarningCircle
                size={20}
                className="mt-0.5 shrink-0 text-[var(--sem-conflict-ink)]"
                aria-hidden="true"
              />
            )}
            <DialogTitle className="text-[16px] font-semibold tracking-[-0.015em] text-[var(--ink-primary)]">
              {title}
            </DialogTitle>
          </div>
          <button
            type="button"
            onClick={() => onOpenChange(false)}
            aria-label="Close confirmation dialog"
            className="flex h-7 w-7 shrink-0 items-center justify-center rounded-[5px] text-[var(--ink-secondary)] hover:bg-[var(--surface-hover)] hover:text-[var(--ink-primary)]"
          >
            <X size={15} aria-hidden="true" />
          </button>
        </div>

        <DialogDescription className="mt-2 text-[13.5px] leading-[1.55] text-[var(--ink-secondary)]">
          {description}
        </DialogDescription>

        <div className="mt-5 flex flex-wrap justify-end gap-2">
          <Button
            variant="secondary"
            size="md"
            disabled={isPending}
            onClick={() => onOpenChange(false)}
          >
            {cancelLabel}
          </Button>
          <Button
            variant={tone === "destructive" ? "destructive" : "primary"}
            size="md"
            disabled={isPending}
            onClick={onConfirm}
          >
            {isPending ? "Processing..." : confirmLabel}
          </Button>
        </div>
      </DialogContent>
    </Dialog>
  );
}
