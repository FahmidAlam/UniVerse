import { useEffect, type RefObject } from "react";

interface UseWorkspaceShortcutsOptions {
  searchInputRef?: RefObject<HTMLInputElement | null>;
  onEscape?: () => void;
  enabled?: boolean;
}

function isEditableElement(target: EventTarget | null): boolean {
  if (!(target instanceof HTMLElement)) return false;
  const tag = target.tagName;
  return (
    tag === "INPUT" ||
    tag === "TEXTAREA" ||
    tag === "SELECT" ||
    target.isContentEditable
  );
}

/**
 * Registers `/` to focus the active filter search input and `Escape` for
 * contextual inspector/drawer dismissal without adding external shortcut deps.
 */
export function useWorkspaceShortcuts({
  searchInputRef,
  onEscape,
  enabled = true,
}: UseWorkspaceShortcutsOptions): void {
  useEffect(() => {
    if (!enabled) return;

    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === "/" && !e.metaKey && !e.ctrlKey && !e.altKey) {
        if (isEditableElement(e.target)) return;
        if (searchInputRef?.current) {
          e.preventDefault();
          searchInputRef.current.focus();
          searchInputRef.current.select();
        }
        return;
      }

      if (e.key === "Escape" && onEscape) {
        onEscape();
      }
    };

    window.addEventListener("keydown", handleKeyDown);
    return () => window.removeEventListener("keydown", handleKeyDown);
  }, [enabled, onEscape, searchInputRef]);
}
