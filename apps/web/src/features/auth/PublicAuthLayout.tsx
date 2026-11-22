import { ArrowLeft, CheckCircle, SignIn } from "@phosphor-icons/react";
import { AnimatePresence, motion, useReducedMotion } from "motion/react";
import { Link, Outlet, useLocation } from "react-router-dom";
import { MobileCompanionStrip } from "@/features/auth/components/MobileCompanionStrip";
import { LedgerMark } from "@/shared/components/LedgerMark";
import { ThemeSwitcher } from "@/shared/theme/ThemeSwitcher";

const ROUTE_ORDER: Record<string, number> = {
  "/": 0,
  "/login": 1,
  "/forgot-password": 2,
  "/reset-password": 3,
  "/access-required": 4,
};

export function PublicAuthLayout() {
  const location = useLocation();
  const prefersReducedMotion = useReducedMotion() ?? false;
  const isLanding = location.pathname === "/";
  const routeRank = ROUTE_ORDER[location.pathname] ?? 1;

  return (
    <div className="flex min-h-dvh flex-col bg-[var(--bg-surface)] text-[var(--ink-primary)]">
      {/* Compact Single-Row Top Masthead (56px mobile / 60px desktop, subtle archival paper grain on header strip) */}
      <header className="ledger-paper-grain sticky top-0 z-30 border-b border-[var(--border-subtle)] bg-[color-mix(in_oklab,var(--bg-surface)_94%,transparent)] backdrop-blur-sm">
        <div className="mx-auto flex h-[56px] max-w-[1280px] items-center justify-between gap-3 px-4 sm:h-[60px] sm:px-6 lg:px-8">
          <Link
            to="/"
            className="flex min-w-0 items-center gap-2.5 text-[var(--ink-primary)] no-underline"
          >
            <LedgerMark size={26} />
            <span className="font-serif-editorial text-[18px] font-semibold tracking-[-0.02em] whitespace-nowrap">
              UniVerse
            </span>
            <span className="hidden border-l border-[var(--border-subtle)] pl-2.5 text-[12px] text-[var(--ink-secondary)] sm:inline whitespace-nowrap">
              Leading University · CSE
            </span>
          </Link>

          <nav
            aria-label="Primary public navigation"
            className="flex shrink-0 items-center gap-3 sm:gap-4"
          >
            <ThemeSwitcher />
            {isLanding ? (
              <>
                <a
                  href="#specimen"
                  className="hidden text-[13px] font-medium text-[var(--ink-secondary)] no-underline hover:text-[var(--ink-primary)] md:inline-flex"
                >
                  Specimen
                </a>
                <a
                  href="#mobile-apps"
                  className="hidden text-[13px] font-medium text-[var(--ink-secondary)] no-underline hover:text-[var(--ink-primary)] md:inline-flex"
                >
                  Mobile Apps
                </a>
                <Link
                  to="/login"
                  className="btn-primary !h-[36px] !px-4 !text-[13px] no-underline"
                >
                  <SignIn size={15} aria-hidden="true" />
                  <span>Admin Sign In</span>
                </Link>
              </>
            ) : (
              <Link
                to="/"
                className="btn-secondary !h-[34px] !px-3 !text-[12.5px] no-underline"
              >
                <ArrowLeft size={14} aria-hidden="true" />
                <span>Back to Home</span>
              </Link>
            )}
          </nav>
        </div>
      </header>

      {/* Main Content */}
      <main className="flex flex-1 flex-col">
        {isLanding ? (
          <Outlet />
        ) : (
          <div className="mx-auto flex w-full max-w-[1160px] flex-1 items-start px-4 py-6 sm:px-6 lg:items-center lg:py-12">
            <div className="grid w-full grid-cols-1 items-start gap-6 lg:grid-cols-[minmax(0,1.17fr)_minmax(380px,1fr)] lg:gap-10">
              {/* Left 54% Archival Registrar Context Panel (Below form fold on <1024px) */}
              <section
                aria-label="Departmental administration context"
                className="ledger-paper-grain order-2 flex flex-col gap-5 rounded-[var(--r-sheet)] border border-[var(--border-subtle)] bg-[var(--bg-canvas)] p-6 sm:p-7 lg:order-1"
              >
                <div>
                  <h2 className="font-serif-editorial text-[26px] font-semibold leading-[1.18] tracking-[-0.02em] text-[var(--ink-primary)]">
                    Leading University Department of CSE
                  </h2>
                  <p className="mt-2.5 max-w-[50ch] text-[14.5px] leading-[1.6] text-[var(--ink-secondary)]">
                    Authorized committee administrators manage room inventory,
                    faculty off-day policies, course eligibility mappings, and
                    semester schedule publications from this console.
                  </p>
                </div>

                <ul className="divide-y divide-[var(--border-subtle)] border-t border-b border-[var(--border-subtle)] text-[13px] text-[var(--ink-secondary)]">
                  <li className="flex items-center gap-2.5 py-2.5">
                    <CheckCircle
                      size={16}
                      className="shrink-0 text-[var(--accent-brand)]"
                      aria-hidden="true"
                    />
                    <span>Departmental administrator account verification</span>
                  </li>
                  <li className="flex items-center gap-2.5 py-2.5">
                    <CheckCircle
                      size={16}
                      className="shrink-0 text-[var(--accent-brand)]"
                      aria-hidden="true"
                    />
                    <span>Room pool, faculty off-day, and prayer-window rule checks</span>
                  </li>
                  <li className="flex items-center gap-2.5 py-2.5">
                    <CheckCircle
                      size={16}
                      className="shrink-0 text-[var(--accent-brand)]"
                      aria-hidden="true"
                    />
                    <span>Coordinated routine release for student and teacher mobile apps</span>
                  </li>
                </ul>

                <MobileCompanionStrip compact />
              </section>

              {/* Right 46% Bounded Elevated Sheet (Renders ABOVE THE FOLD on mobile & tablet) */}
              <aside
                aria-label="Administrator authentication"
                className="ledger-sheet order-1 mx-auto w-full max-w-[440px] p-6 sm:p-7 lg:order-2"
              >
                <AnimatePresence mode="wait" initial={false}>
                  <motion.div
                    key={location.pathname}
                    initial={
                      prefersReducedMotion
                        ? false
                        : { opacity: 0, x: routeRank >= 2 ? 16 : -16 }
                    }
                    animate={{ opacity: 1, x: 0 }}
                    exit={
                      prefersReducedMotion
                        ? undefined
                        : {
                            opacity: 0,
                            x: routeRank >= 2 ? -14 : 14,
                            transition: { duration: 0.14, ease: [0.4, 0, 1, 1] },
                          }
                    }
                    transition={{ duration: 0.19, ease: [0.16, 1, 0.3, 1] }}
                  >
                    <Outlet />
                  </motion.div>
                </AnimatePresence>
              </aside>
            </div>
          </div>
        )}
      </main>
    </div>
  );
}
