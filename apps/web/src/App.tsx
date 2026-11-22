import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { MotionConfig } from "motion/react";
import {
  BrowserRouter,
  Navigate,
  Outlet,
  Route,
  Routes,
  useLocation,
} from "react-router-dom";
import { Toaster } from "sonner";
import { TooltipProvider } from "@/components/ui/Tooltip";
import { CAPABILITY_REGISTRY } from "@/core/capabilities";
import { AdminShell } from "@/features/admin/AdminShell";
import { AdminDashboardPage } from "@/features/admin/pages/AdminDashboardPage";
import { AdminProfilePage } from "@/features/admin/pages/AdminProfilePage";
import { AdminRouteStubPage } from "@/features/admin/pages/AdminRouteStubPage";
import { CampusBroadcastPage } from "@/features/admin/pages/CampusBroadcastPage";
import { ManageCourseEligibilityPage } from "@/features/admin/pages/ManageCourseEligibilityPage";
import { ManageFacultyPage } from "@/features/admin/pages/ManageFacultyPage";
import { ManageResourcesPage } from "@/features/admin/pages/ManageResourcesPage";
import { ManageRoomsPage } from "@/features/admin/pages/ManageRoomsPage";
import { ManageUsersPage } from "@/features/admin/pages/ManageUsersPage";
import { StagedBatchesReferencePage } from "@/features/admin/pages/StagedBatchesReferencePage";
import { StagedCoursesReferencePage } from "@/features/admin/pages/StagedCoursesReferencePage";
import { TimetableSettingsPage } from "@/features/admin/pages/TimetableSettingsPage";
import { AdminRoutinePage } from "@/features/routine/pages/AdminRoutinePage";
import { TimetableGridPage } from "@/features/routine/pages/TimetableGridPage";
import { SchedulingWorkbenchPage } from "@/features/scheduling/pages/SchedulingWorkbenchPage";
import { AuthProvider, useAuth } from "@/features/auth/AuthProvider";
import { PublicAuthLayout } from "@/features/auth/PublicAuthLayout";
import { AccessRequiredPage } from "@/features/auth/pages/AccessRequiredPage";
import { ForgotPasswordPage } from "@/features/auth/pages/ForgotPasswordPage";
import { LandingPage } from "@/features/auth/pages/LandingPage";
import { LoginPage } from "@/features/auth/pages/LoginPage";
import { ResetPasswordPage } from "@/features/auth/pages/ResetPasswordPage";

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 30_000,
      refetchOnWindowFocus: true,
    },
  },
});

function AdminRouteGuard() {
  const { status } = useAuth();
  const location = useLocation();

  if (status === "loading") {
    return (
      <div className="flex min-h-dvh items-center justify-center bg-[var(--bg-surface)] text-[13px] text-[var(--ink-secondary)]">
        Verifying administrator session...
      </div>
    );
  }
  if (status === "passwordRecovery") {
    return <Navigate to="/reset-password" replace />;
  }
  if (status === "accessDenied") {
    return <Navigate to="/access-required" replace />;
  }
  if (status !== "authenticated") {
    return <Navigate to="/login" state={{ from: location }} replace />;
  }
  return <Outlet />;
}

function PublicRouteGuard() {
  const { status } = useAuth();
  const location = useLocation();

  if (status === "passwordRecovery" && location.pathname !== "/reset-password") {
    return <Navigate to="/reset-password" replace />;
  }
  if (status === "accessDenied" && location.pathname !== "/access-required") {
    return <Navigate to="/access-required" replace />;
  }
  if (
    status === "authenticated" &&
    (location.pathname === "/login" ||
      location.pathname === "/forgot-password" ||
      location.pathname === "/access-required")
  ) {
    return <Navigate to="/admin/dashboard" replace />;
  }
  return <PublicAuthLayout />;
}

const LIVE_CAPABILITY_PATHS = new Set([
  "/admin/dashboard",
  "/admin/routine",
  "/admin/timetable/grid",
  "/admin/scheduling",
  "/admin/timetable/courses",
  "/admin/timetable/batches",
  "/admin/timetable/rooms",
  "/admin/timetable/faculty",
  "/admin/timetable/course-eligibility",
  "/admin/timetable/settings",
  "/admin/users",
  "/admin/broadcast",
  "/admin/resources",
  "/admin/profile",
]);

const STUB_CAPABILITIES = CAPABILITY_REGISTRY.filter(
  (cap) => !LIVE_CAPABILITY_PATHS.has(cap.path),
);

export function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <MotionConfig reducedMotion="user">
        <TooltipProvider delayDuration={400} skipDelayDuration={0}>
          <AuthProvider>
            <BrowserRouter>
              <Routes>
                <Route element={<PublicRouteGuard />}>
                  <Route path="/" element={<LandingPage />} />
                  <Route path="/login" element={<LoginPage />} />
                  <Route
                    path="/forgot-password"
                    element={<ForgotPasswordPage />}
                  />
                  <Route
                    path="/reset-password"
                    element={<ResetPasswordPage />}
                  />
                  <Route
                    path="/access-required"
                    element={<AccessRequiredPage />}
                  />
                </Route>

                <Route element={<AdminRouteGuard />}>
                  <Route path="/admin" element={<AdminShell />}>
                    <Route
                      index
                      element={<Navigate to="/admin/dashboard" replace />}
                    />
                    <Route
                      path="dashboard"
                      element={<AdminDashboardPage />}
                    />
                    <Route
                      path="routine"
                      element={<AdminRoutinePage />}
                    />
                    <Route
                      path="timetable/grid"
                      element={<TimetableGridPage />}
                    />
                    <Route
                      path="scheduling"
                      element={<SchedulingWorkbenchPage />}
                    />
                    <Route
                      path="timetable/courses"
                      element={<StagedCoursesReferencePage />}
                    />
                    <Route
                      path="timetable/batches"
                      element={<StagedBatchesReferencePage />}
                    />
                    <Route
                      path="timetable/rooms"
                      element={<ManageRoomsPage />}
                    />
                    <Route
                      path="timetable/faculty"
                      element={<ManageFacultyPage />}
                    />
                    <Route
                      path="timetable/course-eligibility"
                      element={<ManageCourseEligibilityPage />}
                    />
                    <Route
                      path="timetable/settings"
                      element={<TimetableSettingsPage />}
                    />
                    <Route path="users" element={<ManageUsersPage />} />
                    <Route
                      path="broadcast"
                      element={<CampusBroadcastPage />}
                    />
                    <Route
                      path="resources"
                      element={<ManageResourcesPage />}
                    />
                    <Route path="profile" element={<AdminProfilePage />} />
                    {STUB_CAPABILITIES.map((cap) => {
                      const subPath = cap.path.replace(/^\/admin\//, "");
                      return (
                        <Route
                          key={cap.id}
                          path={subPath}
                          element={<AdminRouteStubPage capabilityId={cap.id} />}
                        />
                      );
                    })}
                  </Route>
                </Route>

                <Route path="*" element={<Navigate to="/" replace />} />
              </Routes>
            </BrowserRouter>
            <Toaster
              position="bottom-left"
              closeButton
              duration={3500}
              toastOptions={{
                style: {
                  background: "var(--bg-elevated)",
                  color: "var(--ink-primary)",
                  border: "1px solid var(--border-subtle)",
                  boxShadow: "var(--shadow-popover)",
                  fontFamily: "var(--font-sans)",
                },
              }}
            />
          </AuthProvider>
        </TooltipProvider>
      </MotionConfig>
    </QueryClientProvider>
  );
}
