import { SignIn } from "@phosphor-icons/react";
import { Link } from "react-router-dom";
import { MobileCompanionStrip } from "@/features/auth/components/MobileCompanionStrip";
import { AcademicLedgerPreview } from "@/features/onboarding/components/AcademicLedgerPreview";

const GOVERNANCE_ROWS = [
  {
    tick: "01",
    title: "Room & Lab Pools",
    detail: "Verify RAB, RKB, ACL, and shared ECL lab allocations before solving.",
  },
  {
    tick: "02",
    title: "Faculty Off-Day Bounds",
    detail: "Protect permanent weekly off-days and adjunct distinct course limits.",
  },
  {
    tick: "03",
    title: "Prayer Window & Joint Cohorts",
    detail: "Reserve Friday P4 windows and align combined theory or lab sections.",
  },
] as const;

export function LandingPage() {
  return (
    <div className="w-full">
      {/* Archival Header Band with subtle grain strictly on public hero */}
      <div className="ledger-paper-grain border-b border-[var(--border-subtle)] bg-[var(--bg-canvas)]/55">
        <div className="mx-auto max-w-[1280px] px-4 py-8 sm:px-6 lg:px-8 lg:py-12">
          <div className="grid grid-cols-1 items-start gap-8 lg:grid-cols-[minmax(0,0.82fr)_minmax(0,1.48fr)] lg:gap-7 xl:grid-cols-[minmax(0,0.92fr)_minmax(0,1.38fr)] xl:gap-10">
            {/* Editorial Copy Column */}
            <div className="flex flex-col gap-5">
              <div className="flex items-center gap-2 font-mono-tabular text-[11.5px] font-medium tracking-[0.04em] text-[var(--ink-muted)] uppercase">
                <span>01</span>
                <span className="h-px w-5 bg-[var(--border-subtle)]" aria-hidden="true" />
                <span>Leading University CSE</span>
              </div>

              <h1 className="font-serif-editorial text-[clamp(2rem,3.6vw,2.75rem)] font-semibold leading-[1.10] tracking-[-0.025em] text-[var(--ink-primary)]">
                Academic routine administration for Leading University CSE
              </h1>

              <p className="max-w-[54ch] text-[16px] leading-[1.60] text-[var(--ink-secondary)]">
                Prepare departmental course distributions, verify room pools and
                faculty off-day policies, and release conflict-checked class
                routines from a dedicated desktop console.
              </p>

              <div className="flex flex-wrap items-center gap-3 pt-1">
                <Link to="/login" className="btn-primary no-underline">
                  <SignIn size={16} aria-hidden="true" />
                  <span>Open Admin Console</span>
                </Link>
                <a href="#mobile-apps" className="btn-secondary !h-[40px] no-underline">
                  Student &amp; Teacher Mobile Apps
                </a>
              </div>

              <dl className="mt-2 divide-y divide-[var(--border-subtle)] border-t border-b border-[var(--border-subtle)]">
                {GOVERNANCE_ROWS.map((item) => (
                  <div
                    key={item.tick}
                    className="grid grid-cols-[28px_minmax(0,1fr)] gap-2 py-2.5 text-[13px]"
                  >
                    <dt className="font-mono-tabular text-[11.5px] font-medium text-[var(--ink-muted)]">
                      {item.tick}
                    </dt>
                    <dd className="m-0">
                      <span className="font-semibold text-[var(--ink-primary)]">
                        {item.title}:{" "}
                      </span>
                      <span className="text-[var(--ink-secondary)]">
                        {item.detail}
                      </span>
                    </dd>
                  </div>
                ))}
              </dl>
            </div>

            {/* Interactive 2D Specimen Preview */}
            <div id="specimen" className="min-w-0">
              <AcademicLedgerPreview />
            </div>
          </div>
        </div>
      </div>

      {/* Dedicated Android & iOS Mobile Companion Strip */}
      <div className="mx-auto max-w-[1280px] px-4 py-8 sm:px-6 lg:px-8">
        <MobileCompanionStrip />
      </div>
    </div>
  );
}
