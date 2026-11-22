import { ArrowRight } from "@phosphor-icons/react";
import { Link } from "react-router-dom";
import { AcademicTimetableMatrix } from "@/features/routine/components/AcademicTimetableMatrix";

export function TimetableGridPage() {
  return (
    <div className="space-y-4">
      <header className="no-print flex flex-wrap items-end justify-between gap-4 border-b border-[var(--border-subtle)] pb-4">
        <div>
          <h1 className="font-editorial text-[24px] font-semibold tracking-[-0.02em] text-[var(--ink-primary)]">
            Operational Routine Matrix
          </h1>
          <p className="mt-1 max-w-[68ch] text-[13.5px] leading-[1.55] text-[var(--ink-secondary)]">
            Full-canvas 2D schedule inspection across Section, Faculty, and
            Room lenses with midday break boundaries and Friday Jummah
            protections.
          </p>
        </div>

        <div className="flex flex-wrap items-center gap-2">
          <Link
            to="/admin/routine?tab=manage"
            className="btn-secondary !h-[36px] no-underline"
          >
            <span>Manage Published</span>
          </Link>
          <Link
            to="/admin/routine?tab=generate"
            className="btn-primary !h-[36px] !px-3.5 !text-[12.5px] no-underline"
          >
            <span>Generate Routine</span>
            <ArrowRight size={14} aria-hidden="true" />
          </Link>
        </div>
      </header>

      <AcademicTimetableMatrix />
    </div>
  );
}
