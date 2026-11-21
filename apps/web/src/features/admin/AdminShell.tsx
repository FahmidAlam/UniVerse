import {
  BookOpen,
  Buildings,
  CalendarBlank,
  CaretDown,
  ChalkboardTeacher,
  Compass,
  FolderSimple,
  GridFour,
  List,
  MagnifyingGlass,
  Megaphone,
  Play,
  ShieldCheck,
  SignOut,
  SlidersHorizontal,
  Table,
  UserCircle,
  UserList,
  UsersFour,
  X,
} from "@phosphor-icons/react";
import { LayoutGroup, motion, useReducedMotion } from "motion/react";
import { useState, type ComponentType } from "react";
import { Link, NavLink, Outlet, useLocation, useNavigate } from "react-router-dom";
import { Badge } from "@/components/ui/Badge";
import {
  Dialog,
  DialogContent,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/Dialog";
import { CommandPalette } from "@/components/ui/CommandPalette";
import {
  Tooltip,
  TooltipContent,
  TooltipTrigger,
} from "@/components/ui/Tooltip";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/DropdownMenu";
import {
  CAPABILITY_GROUP_LABELS,
  getCapabilitiesByGroup,
  getCapabilityByPath,
  type CapabilityGroup,
  type CapabilityIconKey,
} from "@/core/capabilities";
import { useAuth } from "@/features/auth/AuthProvider";
import { cn } from "@/lib/utils";
import { EngineHealthBadge } from "@/shared/components/EngineHealthBadge";
import { LedgerMark } from "@/shared/components/LedgerMark";

const GROUP_ORDER: readonly CapabilityGroup[] = [
  "operations",
  "configuration",
  "directory",
];

const ICON_BY_KEY: Record<
  CapabilityIconKey,
  ComponentType<{ size?: number; "aria-hidden"?: boolean; className?: string }>
> = {
  dashboard: Compass,
  routine: CalendarBlank,
  matrix: GridFour,
  workbench: Table,
  courses: BookOpen,
  batches: UsersFour,
  rooms: Buildings,
  faculty: ChalkboardTeacher,
  eligibility: ShieldCheck,
  settings: SlidersHorizontal,
  broadcast: Megaphone,
  users: UserList,
  resources: FolderSimple,
  profile: UserCircle,
};

function initialsFrom(name: string): string {
  const parts = name
    .replace(/[^A-Za-z0-9 ]/g, " ")
    .trim()
    .split(/\s+/)
    .filter(Boolean);
  if (parts.length === 0) return "AD";
  if (parts.length === 1) return parts[0]!.slice(0, 2).toUpperCase();
  return `${parts[0]![0]}${parts[1]![0]}`.toUpperCase();
}

function SidebarContent({
  onNavigate,
  layoutGroupId,
}: {
  onNavigate?: () => void;
  layoutGroupId: string;
}) {
  const location = useLocation();
  const prefersReducedMotion = useReducedMotion() ?? false;

  return (
    <div className="flex h-full flex-col bg-[var(--bg-canvas)] px-2.5 py-3.5">
      <Link
        to="/admin/dashboard"
        onClick={onNavigate}
        className="flex items-center gap-2.5 border-b border-[var(--border-subtle)] px-1.5 pb-3 text-[var(--ink-primary)] no-underline"
      >
        <LedgerMark size={26} />
        <div className="min-w-0">
          <div className="font-serif-editorial text-[16px] font-semibold leading-tight tracking-[-0.015em]">
            UniVerse Admin
          </div>
          <div className="text-[11px] text-[var(--ink-secondary)]">
            Leading University · <span className="acronym-sc">cse</span>
          </div>
        </div>
      </Link>

      <LayoutGroup id={layoutGroupId}>
        <nav
          aria-label="Administrator navigation"
          className="mt-4 flex flex-1 flex-col gap-5 overflow-y-auto pr-0.5"
        >
          {GROUP_ORDER.map((group) => {
            const items = getCapabilitiesByGroup(group);
            return (
              <div key={group} className="flex flex-col gap-0.5">
                <div className="px-2 pb-1 text-[11px] font-semibold tracking-[0.04em] text-[var(--ink-muted)] uppercase">
                  {CAPABILITY_GROUP_LABELS[group]}
                </div>
                {items.map((cap) => {
                  const Icon = ICON_BY_KEY[cap.iconKey];
                  const isActive =
                    location.pathname === cap.path ||
                    (cap.path !== "/admin/dashboard" &&
                      location.pathname.startsWith(`${cap.path}/`));

                  const navLink = (
                    <NavLink
                      key={cap.id}
                      to={cap.path}
                      onClick={onNavigate}
                      className={cn(
                        "relative flex min-h-[36px] items-center justify-between gap-1.5 rounded-[var(--r-control)] px-2 text-[12.5px] no-underline transition-colors",
                        isActive
                          ? "border border-[var(--border-subtle)] bg-[var(--bg-elevated)] font-semibold text-[var(--ink-primary)] shadow-[var(--highlight-top)]"
                          : "border border-transparent font-medium text-[var(--ink-secondary)] hover:bg-[var(--surface-hover)] hover:text-[var(--ink-primary)]",
                      )}
                    >
                      {isActive && (
                        <motion.span
                          layoutId={`${layoutGroupId}-active-rail`}
                          transition={
                            prefersReducedMotion
                              ? { duration: 0 }
                              : { duration: 0.18, ease: [0.16, 1, 0.3, 1] }
                          }
                          className="absolute bottom-[7px] left-0 top-[7px] w-[3px] rounded-r-[3px] bg-[var(--accent-pine)]"
                          aria-hidden="true"
                        />
                      )}
                      <span className="flex min-w-0 items-center gap-2">
                        <Icon
                          size={18}
                          className={
                            isActive
                              ? "shrink-0 text-[var(--accent-pine)]"
                              : "shrink-0 text-[var(--ink-secondary)]"
                          }
                          aria-hidden={true}
                        />
                        <span className="truncate text-[12.5px]">{cap.label}</span>
                      </span>
                      {(cap.sidebarBadge === "LOCKED" ||
                        cap.sidebarBadge === "STAGED") && (
                        <Badge
                          tone={
                            cap.status === "fail-closed-gate"
                              ? "joint"
                              : "neutral"
                          }
                          mono
                          className="shrink-0 px-1.5 py-[1px] text-[10px]"
                        >
                          {cap.sidebarBadge}
                        </Badge>
                      )}
                    </NavLink>
                  );

                  if (cap.label !== cap.pageTitle && cap.id === "admin.scheduling") {
                    return (
                      <Tooltip key={cap.id}>
                        <TooltipTrigger asChild>{navLink}</TooltipTrigger>
                        <TooltipContent side="right">
                          {cap.pageTitle}
                        </TooltipContent>
                      </Tooltip>
                    );
                  }

                  return navLink;
                })}
              </div>
            );
          })}
        </nav>
      </LayoutGroup>
    </div>
  );
}

/**
 * Light-first UniVerse Academic Ledger Admin Shell.
 * Fixed left rail on >=1100px, single-row 52px header bar, single Account Popover.
 */
export function AdminShell() {
  const location = useLocation();
  const navigate = useNavigate();
  const { profile, isDevPreview, signOut } = useAuth();
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [paletteOpen, setPaletteOpen] = useState(false);

  const currentCap = getCapabilityByPath(location.pathname);
  const pageTitle = currentCap?.pageTitle ?? "Routine Command Center";

  return (
    <div
      className="flex min-h-dvh bg-[var(--bg-surface)] text-[var(--ink-primary)]"
      data-testid="admin-shell-academic-ledger"
    >
      {/* Desktop Left Navigation Rail (restored 240px light-first ledger rail) */}
      <aside className="hidden w-[240px] shrink-0 border-r border-[var(--border-subtle)] min-[1100px]:block">
        <div className="sticky top-0 h-dvh">
          <SidebarContent layoutGroupId="desktop-admin-nav" />
        </div>
      </aside>

      {/* Main Fluid Workspace */}
      <div className="flex min-w-0 flex-1 flex-col">
        {/* Single-Row 52px Top Instrument Bar */}
        <header className="sticky top-0 z-30 flex h-[52px] items-center justify-between gap-2 border-b border-[var(--border-subtle)] bg-[var(--bg-surface)] px-3.5 sm:px-6">
          <div className="flex min-w-0 items-center gap-2.5">
            <Dialog open={drawerOpen} onOpenChange={setDrawerOpen}>
              <DialogTrigger asChild>
                <button
                  type="button"
                  aria-label="Open navigation sidebar"
                  className="btn-secondary !h-[36px] !w-[44px] shrink-0 !px-0 min-[1100px]:hidden"
                >
                  <List size={18} aria-hidden="true" />
                </button>
              </DialogTrigger>
              <DialogContent className="fixed inset-y-0 left-0 w-[264px] rounded-none border-r border-[var(--border-subtle)] bg-[var(--bg-canvas)] p-0">
                <DialogTitle className="sr-only">
                  Administrator Navigation
                </DialogTitle>
                <button
                  type="button"
                  onClick={() => setDrawerOpen(false)}
                  aria-label="Close navigation sidebar"
                  className="btn-secondary absolute right-3 top-3 z-10 !h-[32px] !w-[32px] !px-0"
                >
                  <X size={15} aria-hidden="true" />
                </button>
                <SidebarContent
                  layoutGroupId="drawer-admin-nav"
                  onNavigate={() => setDrawerOpen(false)}
                />
              </DialogContent>
            </Dialog>

            <h1 className="truncate font-sans text-[15.5px] font-semibold leading-tight tracking-[-0.015em] text-[var(--ink-primary)] sm:text-[19px]">
              {pageTitle}
            </h1>
          </div>

          <div className="flex shrink-0 items-center gap-2">
            <button
              type="button"
              onClick={() => setPaletteOpen(true)}
              aria-label="Quick navigate (Ctrl+K)"
              data-testid="cmdk-trigger-btn"
              className="hidden h-[34px] items-center gap-2 rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-2.5 text-[12px] text-[var(--ink-secondary)] hover:bg-[var(--surface-hover)] hover:text-[var(--ink-primary)] md:inline-flex"
            >
              <MagnifyingGlass size={14} aria-hidden="true" />
              <span className="hidden lg:inline">Jump</span>
              <kbd className="rounded border border-[var(--border-subtle)] bg-[var(--bg-surface)] px-1 py-0.5 font-mono-tabular text-[10px] text-[var(--ink-muted)]">
                ⌘K
              </kbd>
            </button>

            <div className="hidden sm:block">
              <EngineHealthBadge />
            </div>

            <Link
              to="/admin/routine?tab=generate"
              className="btn-primary !h-[36px] !px-3.5 !text-[12.5px] no-underline"
            >
              <Play size={14} aria-hidden="true" />
              <span className="hidden sm:inline">Generate Routine</span>
              <span className="sm:hidden">Generate</span>
            </Link>

            {/* Single Account Popover */}
            <DropdownMenu>
              <DropdownMenuTrigger asChild>
                <button
                  type="button"
                  aria-label="Administrator account menu"
                  data-testid="admin-account-menu-btn"
                  className="inline-flex h-[36px] items-center gap-1.5 rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-2.5 text-[12px] font-semibold text-[var(--ink-primary)] hover:bg-[var(--surface-hover)]"
                >
                  <span className="font-mono-tabular">
                    {initialsFrom(profile?.name ?? "AD")}
                  </span>
                  <CaretDown
                    size={12}
                    aria-hidden="true"
                    className="text-[var(--ink-secondary)]"
                  />
                </button>
              </DropdownMenuTrigger>
              <DropdownMenuContent align="end">
                <div className="px-2.5 py-2">
                  <div className="flex items-center justify-between gap-2">
                    <span className="truncate font-semibold text-[var(--ink-primary)]">
                      {profile?.name ?? "Administrator"}
                    </span>
                    <Badge tone="pine" className="text-[10px]">
                      Admin
                    </Badge>
                  </div>
                  <div className="font-mono-tabular mt-0.5 truncate text-[11.5px] text-[var(--ink-muted)]">
                    {profile?.email ?? "committee.cse@lus.ac.bd"}
                  </div>
                </div>
                <DropdownMenuSeparator className="my-1 h-px bg-[var(--border-subtle)]" />
                <DropdownMenuItem onSelect={() => navigate("/admin/profile")}>
                  <UserCircle size={16} aria-hidden="true" />
                  <span>My Profile</span>
                </DropdownMenuItem>
                <DropdownMenuItem
                  onSelect={() => {
                    void signOut().then(() => navigate("/", { replace: true }));
                  }}
                  className="text-[var(--sem-conflict-ink)] data-[highlighted]:bg-[var(--sem-conflict-bg)]"
                >
                  <SignOut size={16} aria-hidden="true" />
                  <span>{isDevPreview ? "Exit Preview" : "Sign Out"}</span>
                </DropdownMenuItem>
              </DropdownMenuContent>
            </DropdownMenu>
          </div>
        </header>

        {/* Main Workspace Canvas */}
        <main className="mx-auto w-full min-w-0 max-w-[1220px] flex-1 p-4 sm:p-6">
          <Outlet />
        </main>
      </div>

      <CommandPalette open={paletteOpen} onOpenChange={setPaletteOpen} />
    </div>
  );
}
