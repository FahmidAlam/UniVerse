import { ArrowLeft, LockSimple } from "@phosphor-icons/react";
import { Link } from "react-router-dom";
import { Badge } from "@/components/ui/Badge";
import { SUBFEATURE_CAPABILITIES } from "@/core/capabilities";

export function UploadRoutineGatedTab() {
  const capability = SUBFEATURE_CAPABILITIES.find(
    (item) => item.id === "track1.workbook-upload",
  );

  return (
    <section
      aria-label="Rendered routine upload capability gate"
      data-testid="upload-gated-card"
      className="ledger-card flex max-w-[760px] flex-col gap-4 p-6"
    >
      <div className="flex flex-wrap items-center justify-between gap-2">
        <span className="font-mono-tabular text-[12px] font-medium text-[var(--accent-pine)]">
          Track 1 · Sub-Phase 3B
        </span>
        <Badge tone="joint" mono>
          <LockSimple size={13} aria-hidden="true" />
          <span>{capability?.badgeLabel ?? "Gated · Phase 3B"}</span>
        </Badge>
      </div>

      <div>
        <h2 className="text-[18px] font-semibold tracking-[-0.015em] text-[var(--ink-primary)]">
          {capability?.label ?? "Rendered Routine Upload"}
        </h2>
        <p className="mt-1.5 text-[13.5px] leading-[1.55] text-[var(--ink-secondary)]">
          Uploading pre-rendered{" "}
          <code className="font-mono-tabular">.xlsx</code> routine workbooks for
          direct validation and publication awaits separate owner review and
          authorization of an additive, non-mutating FastAPI parse/validation
          endpoint in{" "}
          <code className="font-mono-tabular">engine/main.py</code>.
        </p>
      </div>

      <div className="rounded-[var(--r-control)] border border-[var(--border-subtle)] bg-[var(--bg-surface)] px-4 py-3 text-[12.5px] leading-[1.5] text-[var(--ink-secondary)]">
        <strong className="font-semibold text-[var(--ink-primary)]">
          Single-Source Parser Policy:{" "}
        </strong>
        React Web does not duplicate browser-side Excel XML heuristics.
        Rendered workbook parsing remains server-owned until shared Dart and
        Python fixture equivalence is verified and authorized.
      </div>

      <div className="flex flex-wrap items-center gap-2.5">
        <Link
          to="/admin/routine?tab=generate"
          className="btn-primary !h-[36px] !px-4 !text-[12.5px] no-underline"
        >
          <span>Use Course Distribution Solver</span>
        </Link>
        <Link
          to="/admin/routine?tab=grid"
          className="btn-secondary !h-[36px] no-underline"
        >
          <ArrowLeft size={15} aria-hidden="true" />
          <span>Inspect Active 2D Grid</span>
        </Link>
      </div>
    </section>
  );
}
