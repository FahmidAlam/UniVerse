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
  SidebarSimple,
  SignOut,
  SlidersHorizontal,
  Table,
  UserCircle,
  UserList,
  UsersFour,
  X,
} from "@phosphor-icons/react";
import { useQuery } from "@tanstack/react-query";
import { LayoutGroup, motion, useReducedMotion } from "motion/react";
import { useEffect, useState, type ComponentType } from "react";
import { Link, NavLink, Outlet, useLocation, useNavigate } from "react-router-dom";
import { toast } from "sonner";
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
import { fetchAdminDashboardCounts } from "@/features/admin/services/adminDashboardService";
import { useAuth } from "@/features/auth/AuthProvider";
import { cn } from "@/lib/utils";
import { EngineHealthBadge } from "@/shared/components/EngineHealthBadge";
import { LedgerMark } from "@/shared/components/LedgerMark";
import { ThemeSwitcher } from "@/shared/theme/ThemeSwitcher";

const SIDEBAR_STORAGE_KEY = "universe-sidebar-collapsed";

const GROUP_ORDER: readonly CapabilityGroup[] = [
  "operations",
  "configuration",
  "directory",
];

const NAV_TOOLTIP_BY_ID: Record<string, string> = {
  "admin.routine": "Manage published slots, inspect matrix, and run CP-SAT solver",
  "admin.routine-grid": "Full-screen 2D weekly timetable grid by section, faculty, or room",
  "admin.scheduling": "5-Stage Scheduling Workbench",
};

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

function readInitialCollapsed(): boolean {
  if (typeof window === "undefined") return false;
  try {
    return window.localStorage.getItem(SIDEBAR_STORAGE_KEY) === "true";
  } catch {
    return false;
  }
}

function SidebarContent({
  onNavigate,
  layoutGroupId,
  collapsed = false,
  onToggleCollapse,
  attentionCounts,
}: {
  onNavigate?: () => void;
  layoutGroupId: string;
  collapsed?: boolean;
  onToggleCollapse?: () => void;
  attentionCounts?: Record<string, number | undefined>;
}) {
  const location = useLocation();
  const prefersReducedMotion = useReducedMotion() ?? false;
  const activeCap = getCapabilityByPath(location.pathname);

  const [collapsedGroups, setCollapsedGroups] = useState<
    Record<CapabilityGroup, boolean>
  >({
    operations: false,
    configuration: false,
    directory: false,
  });

  // Automatically keep the active route's group expanded
  useEffect(() => {
    if (!activeCap) return;
    setCollapsedGroups((prev) =>
      prev[activeCap.group] ? { ...prev, [activeCap.group]: false } : prev,
    );
  }, [activeCap]);

  const toggleGroup = (group: CapabilityGroup) => {
    setCollapsedGroups((prev) => ({ ...prev, [group]: !prev[group] }));
  };

  return (
    <div
      className={cn(
        "flex h-full flex-col bg-[var(--bg-canvas)] py-3.5",
        collapsed ? "px-2" : "px-2.5",
      )}
    >
      <div
        className={cn(
          "flex items-center border-b border-[var(--border-subtle)] pb-3",
          collapsed ? "justify-center px-0" : "justify-between gap-1.5 px-1.5",
        )}
      >
        <Link
          to="/admin/dashboard"
          onClick={onNavigate}
          aria-label="UniVerse Admin Dashboard"
          className="flex min-w-0 items-center gap-2.5 text-[var(--ink-primary)] no-underline"
        >
          <LedgerMark size={26} />
          {!collapsed && (
            <div className="min-w-0">
              <div className="truncate font-serif-editorial text-[16px] font-semibold leading-tight tracking-[-0.015em]">
                UniVerse Admin
              </div>
              <div className="truncate text-[11px] text-[var(--ink-secondary)]">
                Leading University · <span className="acronym-sc">cse</span>
              </div>
            </div>
          )}
        </Link>

        {onToggleCollapse && !collapsed && (
          <Tooltip delayDuration={200}>
            <TooltipTrigger asChild>
              <button
                type="button"
                onClick={onToggleCollapse}
                data-testid="sidebar-collapse-toggle"
                aria-label="Collapse sidebar ([)"
                className="flex h-7 w-7 shrink-0 items-center justify-center rounded-[var(--r-control)] text-[var(--ink-secondary)] hover:bg-[var(--surface-hover)] hover:text-[var(--ink-primary)]"
              >
                <SidebarSimple size={16} aria-hidden="true" />
              </button>
            </TooltipTrigger>
            <TooltipContent side="right">
              Collapse sidebar ([)
            </TooltipContent>
          </Tooltip>
        )}
      </div>

      <LayoutGroup id={layoutGroupId}>
        <nav
          aria-label="Administrator navigation"
          className={cn(
            "mt-3.5 flex flex-1 flex-col overflow-y-auto pr-0.5",
            collapsed ? "gap-3" : "gap-4",
          )}
        >
          {GROUP_ORDER.map((group, groupIdx) => {
            const items = getCapabilitiesByGroup(group);
            const isGroupCollapsed = !collapsed && collapsedGroups[group];
            const firstStagedIdx =
              group === "configuration"
                ? items.findIndex((c) => c.status === "staged-no-db")
                : -1;

            return (
              <div key={group} className="flex flex-col gap-0.5">
                {collapsed ? (
                  groupIdx > 0 && (
                    <div
                      className="mx-auto my-1 h-px w-7 bg-[var(--border-subtle)]"
                      aria-hidden="true"
                    />
                  )
                ) : (
                  <button
                    type="button"
                    onClick={() => toggleGroup(group)}
                    aria-expanded={!isGroupCollapsed}
                    className="flex items-center justify-between rounded-[4px] px-2 py-1 text-left text-[11px] font-semibold tracking-[0.04em] text-[var(--ink-muted)] uppercase hover:bg-[var(--surface-hover)] hover:text-[var(--ink-secondary)]"
                  >
                    <span>{CAPABILITY_GROUP_LABELS[group]}</span>
                    <CaretDown
                      size={12}
                      aria-hidden="true"
                      className={cn(
                        !prefersReducedMotion &&
                          "transition-transform duration-[180ms] ease-[cubic-bezier(0.16,1,0.3,1)]",
                        isGroupCollapsed && "-rotate-90",
                      )}
                    />
                  </button>
                )}

                <div
                  className={cn(
                    "grid",
                    !prefersReducedMotion &&
                      "transition-[grid-template-rows] duration-[180ms] ease-[cubic-bezier(0.16,1,0.3,1)]",
                    isGroupCollapsed ? "grid-rows-[0fr]" : "grid-rows-[1fr]",
                  )}
                >
                  <div className="flex min-h-0 flex-col gap-0.5 overflow-hidden">
                    {items.map((cap, idx) => {
                      const Icon = ICON_BY_KEY[cap.iconKey];
                      const isActive =
                        location.pathname === cap.path ||
                        (cap.path !== "/admin/dashboard" &&
                          location.pathname.startsWith(`${cap.path}/`));
                      const zeroCount = attentionCounts?.[cap.id];
                      const needsAttention = zeroCount === 0;

                      const navLink = (
                        <NavLink
                          to={cap.path}
                          onClick={onNavigate}
                          aria-label={cap.label}
                          className={cn(
                            "relative flex items-center rounded-[var(--r-control)] text-[12.5px] no-underline transition-colors",
                            collapsed
                              ? "mx-auto h-[40px] w-[40px] justify-center px-0"
                              : "min-h-[36px] justify-between gap-1.5 px-2",
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
                              className="absolute bottom-[7px] left-0 top-[7px] w-[3px] rounded-r-[3px] bg-[var(--accent-brand)]"
                              aria-hidden="true"
                            />
                          )}
                          <span
                            className={cn(
                              "flex min-w-0 items-center",
                              collapsed ? "justify-center" : "gap-2",
                            )}
                          >
                            <Icon
                              size={collapsed ? 20 : 18}
                              className={
                                isActive
                                  ? "shrink-0 text-[var(--accent-brand)]"
                                  : "shrink-0 text-[var(--ink-muted)]"
                              }
                              aria-hidden={true}
                            />
                            {!collapsed && (
                              <span className="truncate text-[12.5px]">
                                {cap.label}
                              </span>
                            )}
                          </span>

                          {collapsed && needsAttention && (
                            <span
                              className="absolute right-1.5 top-1.5 h-1.5 w-1.5 rounded-full bg-[var(--sem-joint-bar)]"
                              aria-hidden="true"
                            />
                          )}

                          {!collapsed && needsAttention && (
                            <span
                              title="0 baseline rows configured"
                              className="font-mono-tabular inline-flex items-center gap-1 text-[11px] font-semibold text-[var(--sem-joint-ink)]"
                            >
                              <span
                                className="h-1.5 w-1.5 rounded-full bg-[var(--sem-joint-bar)]"
                                aria-hidden="true"
                              />
                              <span>0</span>
                            </span>
                          )}

                          {!collapsed &&
                            (cap.sidebarBadge === "LOCKED" ||
                              cap.sidebarBadge === "STAGED" ||
                              cap.sidebarBadge === "GATED") && (
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

                      const tooltipText = NAV_TOOLTIP_BY_ID[cap.id];
                      const wrappedLink =
                        collapsed || tooltipText ? (
                          <Tooltip key={cap.id} delayDuration={200}>
                            <TooltipTrigger asChild>{navLink}</TooltipTrigger>
                            <TooltipContent side="right">
                              <div className="flex items-center gap-1.5">
                                <span>
                                  {collapsed
                                    ? cap.label
                                    : tooltipText ?? cap.pageTitle}
                                </span>
                                {collapsed && cap.sidebarBadge && (
                                  <span className="font-mono-tabular text-[10px] opacity-80">
                                    · {cap.sidebarBadge}
                                  </span>
                                )}
                              </div>
                            </TooltipContent>
                          </Tooltip>
                        ) : (
                          <div key={cap.id}>{navLink}</div>
                        );

                      if (!collapsed && firstStagedIdx > 0 && idx === firstStagedIdx) {
                        return (
                          <div key={cap.id} className="mt-1 border-t border-[var(--border-subtle)] pt-1.5">
                            {wrappedLink}
                          </div>
                        );
                      }

                      return wrappedLink;
                    })}
                  </div>
                </div>
              </div>
            );
          })}
        </nav>
      </LayoutGroup>

      {onToggleCollapse && collapsed && (
        <div className="mt-2 border-t border-[var(--border-subtle)] pt-2.5">
          <Tooltip delayDuration={200}>
            <TooltipTrigger asChild>
              <button
                type="button"
                onClick={onToggleCollapse}
                data-testid="sidebar-collapse-toggle"
                aria-label="Expand sidebar ([)"
                className="mx-auto flex h-[40px] w-[40px] items-center justify-center rounded-[var(--r-control)] text-[var(--ink-secondary)] hover:bg-[var(--surface-hover)] hover:text-[var(--ink-primary)]"
              >
                <SidebarSimple size={20} aria-hidden="true" />
              </button>
            </TooltipTrigger>
            <TooltipContent side="right">Expand sidebar ([)</TooltipContent>
          </Tooltip>
        </div>
      )}
    </div>
  );
}

const COMPACT_MOBILE_TITLES: Record<string, string> = {
  "admin.routine-grid": "Routine Matrix",
  "admin.eligibility": "Course Eligibility",
  "admin.scheduling": "Workbench",
  "admin.settings": "Settings",
  "admin.routine": "Routine Console",
};

/**
 * Light-first UniVerse Academic Ledger Admin Shell.
 * Collapsible left rail (240px <-> 68px) on >=1100px, single-row 52px header bar, single Account Popover.
 */
export function AdminShell() {
  const location = useLocation();
  const navigate = useNavigate();
  const { profile, isDevPreview, signOut } = useAuth();
  const prefersReducedMotion = useReducedMotion() ?? false;
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [paletteOpen, setPaletteOpen] = useState(false);
  const [sidebarCollapsed, setSidebarCollapsed] = useState<boolean>(
    readInitialCollapsed,
  );

  const toggleSidebar = () => {
    setSidebarCollapsed((prev) => {
      const next = !prev;
      try {
        window.localStorage.setItem(SIDEBAR_STORAGE_KEY, String(next));
      } catch {
        // Ignore storage quota errors
      }
      return next;
    });
  };

  // Dismiss stale toasts when switching routes, ?tab=, or ?stage=
  useEffect(() => {
    toast.dismiss();
  }, [location.pathname, location.search]);

  // `[` shortcut toggles desktop sidebar collapse when not typing in an input
  useEffect(() => {
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key !== "[" || e.metaKey || e.ctrlKey || e.altKey) return;
      const target = e.target as HTMLElement | null;
      const tag = target?.tagName?.toLowerCase();
      if (
        tag === "input" ||
        tag === "textarea" ||
        tag === "select" ||
        target?.isContentEditable
      ) {
        return;
      }
      if (paletteOpen || drawerOpen) return;
      e.preventDefault();
      toggleSidebar();
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, [drawerOpen, paletteOpen]);

  const overviewQuery = useQuery({
    queryKey: ["admin-dashboard-counts", isDevPreview],
    queryFn: () => fetchAdminDashboardCounts(isDevPreview),
    staleTime: 60_000,
    retry: false,
  });

  const attentionCounts: Record<string, number | undefined> | undefined =
    overviewQuery.data
      ? {
          "admin.rooms": overviewQuery.data.timetableRooms,
          "admin.faculty": overviewQuery.data.timetableFaculty,
          "admin.course-eligibility":
            overviewQuery.data.timetableCourseEligibility,
        }
      : undefined;

  const currentCap = getCapabilityByPath(location.pathname);
  const pageTitle = currentCap?.pageTitle ?? "Routine Command Center";
  const mobilePageTitle =
    (currentCap ? COMPACT_MOBILE_TITLES[currentCap.id] : undefined) ??
    pageTitle;
  const pageOwnsRoutinePrimaryCta =
    location.pathname.startsWith("/admin/routine") ||
    location.pathname.startsWith("/admin/timetable/grid") ||
    location.pathname.startsWith("/admin/scheduling");
  const topbarSectionTitle =
    currentCap?.id === "admin.routine-grid"
      ? "Track 1 · Weekly Matrix"
      : currentCap?.id === "admin.routine"
        ? "Track 1 · Operational Console"
        : pageTitle;

  return (
    <div
      className="flex min-h-dvh bg-[var(--bg-surface)] text-[var(--ink-primary)]"
      data-testid="admin-shell-academic-ledger"
    >
      {/* Desktop Left Navigation Rail (240px expanded <-> 68px compact icon rail) */}
      <aside
        data-testid="desktop-admin-sidebar"
        data-collapsed={sidebarCollapsed ? "true" : "false"}
        className={cn(
          "hidden shrink-0 border-r border-[var(--border-subtle)] min-[1100px]:block",
          !prefersReducedMotion &&
            "transition-[width] duration-[180ms] ease-[cubic-bezier(0.16,1,0.3,1)]",
          sidebarCollapsed ? "w-[68px]" : "w-[240px]",
        )}
      >
        <div className="sticky top-0 h-dvh">
          <SidebarContent
            layoutGroupId="desktop-admin-nav"
            collapsed={sidebarCollapsed}
            onToggleCollapse={toggleSidebar}
            attentionCounts={attentionCounts}
          />
        </div>
      </aside>

      {/* Main Fluid Workspace */}
      <div className="flex min-w-0 flex-1 flex-col">
        {/* Single-Row 52px Top Instrument Bar (non-sticky so scrolled fullPage captures never slice page headings) */}
        <header
          data-admin-topbar="true"
          className="no-print relative z-20 flex h-[52px] shrink-0 items-center justify-between gap-2 border-b border-[var(--border-subtle)] bg-[var(--bg-surface)] px-3.5 sm:px-6"
        >
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

            <span className="truncate font-sans text-[15px] font-semibold leading-tight tracking-[-0.015em] text-[var(--ink-primary)] sm:hidden">
              {mobilePageTitle}
            </span>
            <span className="hidden truncate font-sans text-[17px] font-semibold leading-tight tracking-[-0.015em] text-[var(--ink-primary)] sm:inline">
              {topbarSectionTitle}
            </span>
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

            <ThemeSwitcher compact />

            {!pageOwnsRoutinePrimaryCta && (
              <Link
                to="/admin/routine?tab=generate"
                className="btn-primary !h-[36px] !px-3.5 !text-[12.5px] no-underline"
              >
                <Play size={14} aria-hidden="true" />
                <span className="hidden sm:inline">Generate Routine</span>
                <span className="sm:hidden">Generate</span>
              </Link>
            )}

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
        <main className="mx-auto w-full min-w-0 max-w-[1920px] flex-1 p-4 sm:p-6">
          <Outlet />
        </main>
      </div>

      <CommandPalette open={paletteOpen} onOpenChange={setPaletteOpen} />
    </div>
  );
}
