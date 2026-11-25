import { useCallback, useEffect, useState, type CSSProperties, type RefObject } from "react";

const RIGHT_EDGE_MASK: CSSProperties = {
  maskImage: "linear-gradient(to right, black calc(100% - 24px), transparent)",
  WebkitMaskImage:
    "linear-gradient(to right, black calc(100% - 24px), transparent)",
};

/**
 * Measures horizontal overflow on a scrollable table/matrix container and
 * returns a subtle right-edge fade mask style whenever clipped columns remain off-screen.
 */
export function useHorizontalScrollCue(
  containerRef: RefObject<HTMLElement | null>,
  deps: readonly unknown[] = [],
) {
  const [hasRightOverflow, setHasRightOverflow] = useState(false);

  const updateCue = useCallback(() => {
    const el = containerRef.current;
    if (!el) {
      setHasRightOverflow(false);
      return;
    }
    const remaining = el.scrollWidth - el.clientWidth - el.scrollLeft;
    setHasRightOverflow(remaining > 4);
  }, [containerRef]);

  useEffect(() => {
    updateCue();
    const el = containerRef.current;
    if (!el) return;

    let observer: ResizeObserver | null = null;
    if (typeof ResizeObserver === "function") {
      observer = new ResizeObserver(() => updateCue());
      observer.observe(el);
    }
    window.addEventListener("resize", updateCue);
    return () => {
      observer?.disconnect();
      window.removeEventListener("resize", updateCue);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [updateCue, ...deps]);

  return {
    hasRightOverflow,
    onScroll: updateCue,
    maskStyle: hasRightOverflow ? RIGHT_EDGE_MASK : undefined,
  };
}
