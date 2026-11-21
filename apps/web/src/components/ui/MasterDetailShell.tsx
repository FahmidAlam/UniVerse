import { X } from "@phosphor-icons/react";
import { AnimatePresence, motion, useReducedMotion } from "motion/react";
import { useEffect, useState, type ReactNode } from "react";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogTitle,
} from "@/components/ui/Dialog";
import { cn } from "@/lib/utils";

interface MasterDetailShellProps {
  detailOpen: boolean;
  onRequestClose: () => void;
  detailTitle: string;
  detailSubtitle?: string;
  master: ReactNode;
  detail: ReactNode;
  className?: string;
}

export function MasterDetailShell({
  detailOpen,
  onRequestClose,
  detailTitle,
  detailSubtitle,
  master,
  detail,
  className,
}: MasterDetailShellProps) {
  const prefersReducedMotion = useReducedMotion() ?? false;
  const [isDesktop, setIsDesktop] = useState(() =>
    typeof window !== "undefined" && typeof window.matchMedia === "function"
      ? window.matchMedia("(min-width: 1024px)").matches
      : true,
  );

  useEffect(() => {
    if (typeof window === "undefined" || typeof window.matchMedia !== "function") {
      return;
    }
    const mql = window.matchMedia("(min-width: 1024px)");
    const onChange = (e: MediaQueryListEvent) => setIsDesktop(e.matches);
    setIsDesktop(mql.matches);
    mql.addEventListener("change", onChange);
    return () => mql.removeEventListener("change", onChange);
  }, []);

  const inspectorHeader = (
    <div className="flex items-start justify-between gap-3 border-b border-[var(--border-subtle)] px-5 py-4">
      <div className="min-w-0">
        <h2 className="truncate text-[16px] font-semibold tracking-[-0.015em] text-[var(--ink-primary)]">
          {detailTitle}
        </h2>
        {detailSubtitle && (
          <p className="mt-0.5 truncate text-[12px] text-[var(--ink-secondary)]">
            {detailSubtitle}
          </p>
        )}
      </div>
      <button
        type="button"
        onClick={onRequestClose}
        aria-label="Close detail inspector"
        data-testid="inspector-close-btn"
        className="flex h-8 w-8 shrink-0 items-center justify-center rounded-[var(--r-control)] border border-[var(--border-subtle)] bg-[var(--bg-surface)] text-[var(--ink-secondary)] hover:bg-[var(--surface-hover)] hover:text-[var(--ink-primary)]"
      >
        <X size={16} aria-hidden="true" />
      </button>
    </div>
  );

  return (
    <div
      className={cn(
        "grid grid-cols-1 items-start gap-5",
        detailOpen && isDesktop
          ? "lg:grid-cols-[minmax(0,1.22fr)_minmax(340px,460px)]"
          : "",
        className,
      )}
    >
      <div className="min-w-0">{master}</div>

      {/* Desktop 55/45 Docked Right Inspector */}
      {isDesktop && (
        <AnimatePresence initial={false}>
          {detailOpen && (
            <motion.aside
              aria-label={detailTitle}
              data-testid="master-detail-inspector"
              initial={prefersReducedMotion ? false : { opacity: 0, x: 16 }}
              animate={{ opacity: 1, x: 0 }}
              exit={
                prefersReducedMotion
                  ? undefined
                  : {
                      opacity: 0,
                      x: 12,
                      transition: { duration: 0.14, ease: [0.4, 0, 1, 1] },
                    }
              }
              transition={{ duration: 0.19, ease: [0.16, 1, 0.3, 1] }}
              className="ledger-sheet sticky top-[68px] flex max-h-[calc(100dvh-84px)] flex-col overflow-hidden"
            >
              {inspectorHeader}
              <div className="flex-1 overflow-y-auto px-5 py-4">{detail}</div>
            </motion.aside>
          )}
        </AnimatePresence>
      )}

      {/* Tablet / Mobile Slide-Over Radix Dialog (< 1024px) */}
      {!isDesktop && (
        <Dialog
          open={detailOpen}
          onOpenChange={(open) => {
            if (!open) onRequestClose();
          }}
        >
          <DialogContent
            aria-describedby={undefined}
            className="fixed inset-y-0 right-0 flex w-full max-w-[460px] flex-col rounded-none border-l border-[var(--border-subtle)] bg-[var(--bg-elevated)] p-0"
          >
            <DialogTitle className="sr-only">{detailTitle}</DialogTitle>
            {detailSubtitle && (
              <DialogDescription className="sr-only">
                {detailSubtitle}
              </DialogDescription>
            )}
            {inspectorHeader}
            <div className="flex-1 overflow-y-auto px-5 py-4">{detail}</div>
          </DialogContent>
        </Dialog>
      )}
    </div>
  );
}
