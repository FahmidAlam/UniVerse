import { CaretUpDown, Check, MagnifyingGlass, Plus } from "@phosphor-icons/react";
import { Command } from "cmdk";
import { useEffect, useRef, useState } from "react";
import { cn } from "@/lib/utils";

export interface ComboboxOption {
  value: string;
  label: string;
  subtitle?: string;
}

interface CommandComboboxProps {
  id?: string;
  value: string;
  onChange: (value: string) => void;
  options: readonly ComboboxOption[];
  placeholder?: string;
  searchPlaceholder?: string;
  emptyLabel?: string;
  allowCustom?: boolean;
  normalizeValue?: (raw: string) => string;
  disabled?: boolean;
  "aria-invalid"?: boolean;
}

export function CommandCombobox({
  id,
  value,
  onChange,
  options,
  placeholder = "Select an option...",
  searchPlaceholder = "Type to filter...",
  emptyLabel = "No matching entries found.",
  allowCustom = false,
  normalizeValue,
  disabled = false,
  "aria-invalid": ariaInvalid,
}: CommandComboboxProps) {
  const [open, setOpen] = useState(false);
  const [search, setSearch] = useState("");
  const containerRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!open) return;
    const onPointerDown = (e: MouseEvent) => {
      if (!containerRef.current?.contains(e.target as Node)) {
        setOpen(false);
      }
    };
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key === "Escape") {
        setOpen(false);
      }
    };
    window.addEventListener("mousedown", onPointerDown);
    window.addEventListener("keydown", onKeyDown);
    return () => {
      window.removeEventListener("mousedown", onPointerDown);
      window.removeEventListener("keydown", onKeyDown);
    };
  }, [open]);

  const selected = options.find((opt) => opt.value === value);
  const formattedCustom = normalizeValue
    ? normalizeValue(search.trim())
    : search.trim();
  const hasExactMatch =
    formattedCustom.length > 0 &&
    options.some(
      (opt) => opt.value.toUpperCase() === formattedCustom.toUpperCase(),
    );

  return (
    <div ref={containerRef} className="relative">
      <button
        id={id}
        type="button"
        role="combobox"
        aria-expanded={open}
        aria-invalid={ariaInvalid}
        disabled={disabled}
        onClick={() => setOpen((v) => !v)}
        className={cn(
          "flex h-[40px] w-full items-center justify-between gap-2 rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-3 text-left text-[13.5px] transition-colors hover:bg-[var(--surface-hover)] disabled:cursor-not-allowed disabled:opacity-55",
          value ? "text-[var(--ink-primary)]" : "text-[var(--ink-muted)]",
        )}
      >
        <span className="truncate font-mono-tabular">
          {selected ? `${selected.value} — ${selected.label}` : value || placeholder}
        </span>
        <CaretUpDown
          size={15}
          className="shrink-0 text-[var(--ink-secondary)]"
          aria-hidden="true"
        />
      </button>

      {open && (
        <div className="ledger-popover absolute left-0 right-0 top-[calc(100%+4px)] z-40 overflow-hidden">
          <Command label={placeholder} shouldFilter>
            <div className="flex items-center gap-2 border-b border-[var(--border-subtle)] px-3 py-2">
              <MagnifyingGlass
                size={15}
                className="shrink-0 text-[var(--ink-muted)]"
                aria-hidden="true"
              />
              <Command.Input
                value={search}
                onValueChange={setSearch}
                placeholder={searchPlaceholder}
                autoFocus
                className="w-full bg-transparent text-[13px] text-[var(--ink-primary)] placeholder:text-[var(--ink-muted)] focus:outline-none"
              />
            </div>

            <Command.List className="max-h-[220px] overflow-y-auto p-1.5">
              <Command.Empty className="px-2.5 py-4 text-center text-[12.5px] text-[var(--ink-muted)]">
                {emptyLabel}
              </Command.Empty>

              {options.map((opt) => {
                const isSelected = opt.value === value;
                return (
                  <Command.Item
                    key={opt.value}
                    value={`${opt.value} ${opt.label} ${opt.subtitle ?? ""}`}
                    onSelect={() => {
                      onChange(opt.value);
                      setOpen(false);
                      setSearch("");
                    }}
                    className="flex cursor-pointer items-center justify-between gap-2 rounded-[5px] px-2.5 py-2 text-[12.5px] text-[var(--ink-primary)] aria-selected:bg-[var(--surface-hover)]"
                  >
                    <div className="min-w-0">
                      <span className="font-mono-tabular font-semibold">
                        {opt.value}
                      </span>
                      {opt.label !== opt.value && (
                        <span className="ml-2 text-[var(--ink-secondary)]">
                          {opt.label}
                        </span>
                      )}
                      {opt.subtitle && (
                        <span className="ml-2 text-[11px] text-[var(--ink-muted)]">
                          {opt.subtitle}
                        </span>
                      )}
                    </div>
                    {isSelected && (
                      <Check
                        size={14}
                        className="shrink-0 text-[var(--accent-brand)]"
                        aria-hidden="true"
                      />
                    )}
                  </Command.Item>
                );
              })}

              {allowCustom && formattedCustom.length > 0 && !hasExactMatch && (
                <Command.Item
                  value={`__custom__ ${formattedCustom}`}
                  onSelect={() => {
                    onChange(formattedCustom);
                    setOpen(false);
                    setSearch("");
                  }}
                  className="mt-1 flex cursor-pointer items-center gap-2 rounded-[5px] border-t border-[var(--border-subtle)] px-2.5 py-2 text-[12.5px] font-medium text-[var(--accent-brand)] aria-selected:bg-[var(--accent-brand-soft)]"
                >
                  <Plus size={14} aria-hidden="true" />
                  <span>
                    Use <span className="font-mono-tabular">{formattedCustom}</span>
                  </span>
                </Command.Item>
              )}
            </Command.List>
          </Command>
        </div>
      )}
    </div>
  );
}
