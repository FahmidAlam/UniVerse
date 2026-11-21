import { ArrowsClockwise, CircleNotch } from "@phosphor-icons/react";
import { useQuery } from "@tanstack/react-query";
import {
  Tooltip,
  TooltipContent,
  TooltipTrigger,
} from "@/components/ui/Tooltip";
import { checkEngineHealth } from "@/services/engineHealth";

export function EngineHealthBadge() {
  const { data, isFetching, refetch } = useQuery({
    queryKey: ["engine-health-root"],
    queryFn: checkEngineHealth,
    refetchOnWindowFocus: true,
    refetchInterval: 60_000,
    retry: false,
  });

  const status = data?.status ?? "cold-start";
  const dotColor =
    status === "online"
      ? "var(--sem-lab-bar)"
      : status === "cold-start"
        ? "var(--sem-joint-bar)"
        : "var(--sem-conflict-bar)";

  const label =
    isFetching && !data
      ? "Checking engine..."
      : status === "online"
        ? `Engine v${data?.version ?? "2.0.0"} · ${data?.latencyMs ?? 0} ms`
        : status === "cold-start"
          ? "Engine waking"
          : "Engine offline";

  return (
    <Tooltip>
      <TooltipTrigger asChild>
        <button
          type="button"
          onClick={() => void refetch()}
          className="inline-flex h-[34px] items-center gap-2 rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-2.5 text-[12px] text-[var(--ink-secondary)] transition-colors hover:bg-[var(--surface-hover)] hover:text-[var(--ink-primary)]"
        >
          {isFetching ? (
            <CircleNotch
              size={14}
              className="animate-spin text-[var(--accent-pine)]"
              aria-hidden="true"
            />
          ) : (
            <span
              className="h-2 w-2 rounded-full"
              style={{ backgroundColor: dotColor }}
              aria-hidden="true"
            />
          )}
          <span className="font-mono-tabular whitespace-nowrap">{label}</span>
          <ArrowsClockwise
            size={13}
            aria-hidden="true"
            className="text-[var(--ink-muted)]"
          />
        </button>
      </TooltipTrigger>
      <TooltipContent>
        <div className="font-semibold text-[var(--ink-primary)]">
          {data?.detail ?? "Checking scheduling service availability"}
        </div>
        <div className="mt-1 text-[11.5px] text-[var(--ink-secondary)]">
          Click to re-check connection. Hosted instances may wake briefly after
          idle periods.
        </div>
      </TooltipContent>
    </Tooltip>
  );
}
