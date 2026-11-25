import { ArrowRight, LockSimple, MagnifyingGlass } from "@phosphor-icons/react";
import { Command } from "cmdk";
import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import {
  CAPABILITY_GROUP_LABELS,
  CAPABILITY_REGISTRY,
  type CapabilityGroup,
} from "@/core/capabilities";
import { Dialog, DialogContent, DialogTitle } from "@/components/ui/Dialog";
import { Badge } from "@/components/ui/Badge";

const GROUP_ORDER: readonly CapabilityGroup[] = [
  "operations",
  "configuration",
  "directory",
];

interface CommandPaletteProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
}

export function CommandPalette({ open, onOpenChange }: CommandPaletteProps) {
  const navigate = useNavigate();
  const [query, setQuery] = useState("");

  useEffect(() => {
    const onKeyDown = (e: KeyboardEvent) => {
      if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === "k") {
        e.preventDefault();
        onOpenChange(!open);
      }
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, [onOpenChange, open]);

  useEffect(() => {
    if (!open) setQuery("");
  }, [open]);

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent
        aria-describedby={undefined}
        data-testid="command-palette-dialog"
        className="fixed left-1/2 top-[16%] w-[calc(100%-32px)] max-w-[540px] -translate-x-1/2 overflow-hidden p-0"
      >
        <DialogTitle className="sr-only">
          Quick Navigate Administrator Routes
        </DialogTitle>
        <Command label="Quick Navigate Administrator Routes" shouldFilter>
          <div className="flex items-center gap-2.5 border-b border-[var(--border-subtle)] px-3.5 py-2.5">
            <MagnifyingGlass
              size={16}
              className="shrink-0 text-[var(--ink-muted)]"
              aria-hidden="true"
            />
            <Command.Input
              value={query}
              onValueChange={setQuery}
              placeholder="Jump to rooms, faculty, eligibility, settings..."
              className="w-full bg-transparent text-[13.5px] text-[var(--ink-primary)] placeholder:text-[var(--ink-muted)] focus:outline-none"
            />
            <kbd className="rounded border border-[var(--border-subtle)] bg-[var(--bg-surface)] px-1.5 py-0.5 font-mono-tabular text-[10.5px] text-[var(--ink-muted)]">
              Esc
            </kbd>
          </div>

          <Command.List className="max-h-[340px] overflow-y-auto p-2">
            <Command.Empty className="px-3 py-6 text-center text-[13px] text-[var(--ink-muted)]">
              No matching console views found.
            </Command.Empty>

            {GROUP_ORDER.map((group) => {
              const items = CAPABILITY_REGISTRY.filter((c) => c.group === group);
              return (
                <Command.Group
                  key={group}
                  heading={CAPABILITY_GROUP_LABELS[group]}
                  className="[&_[cmdk-group-heading]]:px-2 [&_[cmdk-group-heading]]:py-1.5 [&_[cmdk-group-heading]]:text-[11px] [&_[cmdk-group-heading]]:font-semibold [&_[cmdk-group-heading]]:tracking-[0.04em] [&_[cmdk-group-heading]]:text-[var(--ink-muted)] [&_[cmdk-group-heading]]:uppercase"
                >
                  {items.map((cap) => (
                    <Command.Item
                      key={cap.id}
                      value={`${cap.label} ${cap.pageTitle} ${cap.path}`}
                      onSelect={() => {
                        onOpenChange(false);
                        navigate(cap.path);
                      }}
                      className="flex cursor-pointer items-center justify-between gap-3 rounded-[6px] px-2.5 py-2 text-[13px] text-[var(--ink-primary)] aria-selected:bg-[var(--surface-hover)]"
                    >
                      <div className="min-w-0">
                        <div className="font-medium">{cap.label}</div>
                        <div className="truncate text-[11.5px] text-[var(--ink-muted)]">
                          {cap.pageTitle}
                        </div>
                      </div>
                      <div className="flex shrink-0 items-center gap-2">
                        {cap.sidebarBadge && (
                          <Badge
                            tone={
                              cap.status === "fail-closed-gate"
                                ? "joint"
                                : "neutral"
                            }
                            mono
                            className="text-[10px]"
                          >
                            {cap.status === "fail-closed-gate" && (
                              <LockSimple size={11} aria-hidden="true" />
                            )}
                            <span>{cap.sidebarBadge}</span>
                          </Badge>
                        )}
                        <ArrowRight
                          size={14}
                          className="text-[var(--ink-muted)]"
                          aria-hidden="true"
                        />
                      </div>
                    </Command.Item>
                  ))}
                </Command.Group>
              );
            })}
          </Command.List>
        </Command>
      </DialogContent>
    </Dialog>
  );
}
