import { ArrowLeft, Eye, LockSimple, Wrench } from "@phosphor-icons/react";
import { Link } from "react-router-dom";
import { Badge } from "@/components/ui/Badge";
import {
  formatCapabilityStatusLabel,
  getCapabilityById,
} from "@/core/capabilities";

interface AdminRouteStubPageProps {
  capabilityId: string;
}

export function AdminRouteStubPage({ capabilityId }: AdminRouteStubPageProps) {
  const capability = getCapabilityById(capabilityId);

  if (!capability) {
    return null;
  }

  const badgeTone =
    capability.status === "fail-closed-gate"
      ? "joint"
      : capability.status === "staged-no-db"
        ? "neutral"
        : "pine";

  return (
    <div className="ledger-card flex max-w-[740px] flex-col gap-4 p-6">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <span className="font-mono-tabular text-[12px] font-medium text-[var(--accent-pine)]">
          {capability.plannedPhaseLabel}
        </span>
        <Badge tone={badgeTone} mono>
          {capability.status === "fail-closed-gate" ||
          capability.status === "staged-no-db" ? (
            <LockSimple size={13} aria-hidden="true" />
          ) : capability.status === "read-only" ? (
            <Eye size={13} aria-hidden="true" />
          ) : (
            <Wrench size={13} aria-hidden="true" />
          )}
          <span>{formatCapabilityStatusLabel(capability.status)}</span>
        </Badge>
      </div>

      <div>
        <h2 className="text-[18px] font-semibold tracking-[-0.015em] text-[var(--ink-primary)]">
          {capability.pageTitle}
        </h2>
        <p className="mt-1.5 text-[13.5px] leading-[1.55] text-[var(--ink-secondary)]">
          {capability.summary}
        </p>
      </div>

      <div className="rounded-[var(--r-control)] border border-[var(--border-subtle)] bg-[var(--bg-surface)] px-3.5 py-2.5 text-[12.5px] text-[var(--ink-secondary)]">
        <span className="font-semibold text-[var(--ink-primary)]">
          Governance state:{" "}
        </span>
        <span>{capability.governanceNote}</span>
      </div>

      <div>
        <Link
          to="/admin/dashboard"
          className="btn-secondary !h-[36px] no-underline"
        >
          <ArrowLeft size={15} aria-hidden="true" />
          <span>Return to Command Center</span>
        </Link>
      </div>
    </div>
  );
}
