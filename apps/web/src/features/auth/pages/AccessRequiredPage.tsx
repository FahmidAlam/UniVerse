import { ShieldWarning, SignOut } from "@phosphor-icons/react";
import { useNavigate } from "react-router-dom";
import { useAuth } from "@/features/auth/AuthProvider";
import { MobileCompanionStrip } from "@/features/auth/components/MobileCompanionStrip";

export function AccessRequiredPage() {
  const navigate = useNavigate();
  const { deniedReason, deniedRole, profile, signOut } = useAuth();

  const isNonAdminRole = deniedReason === "non_admin_role";

  return (
    <div className="flex flex-col gap-5">
      <div className="flex items-start gap-3">
        <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-[var(--r-control)] border border-[var(--sem-conflict-border)] bg-[var(--sem-conflict-bg)] text-[var(--sem-conflict-ink)]">
          <ShieldWarning size={20} aria-hidden="true" />
        </div>
        <div>
          <h1 className="font-serif-editorial text-[22px] font-semibold leading-tight tracking-[-0.02em] text-[var(--ink-primary)]">
            {isNonAdminRole
              ? "Administrator Console Only"
              : "Committee Access Required"}
          </h1>
          <p className="mt-1.5 text-[13.5px] leading-[1.55] text-[var(--ink-secondary)]">
            {isNonAdminRole
              ? `Your signed-in account (${profile?.email ?? "verified user"}) is registered with a ${deniedRole ?? "member"} role. UniVerse Web is reserved for Department of CSE Routine Committee Administrators.`
              : "Your institutional email is not authorized for Routine Committee web console access. Contact the Department of CSE Routine Chair to request an administrator invitation."}
          </p>
        </div>
      </div>

      <MobileCompanionStrip compact />

      <button
        type="button"
        onClick={() => {
          void signOut().then(() => navigate("/login", { replace: true }));
        }}
        className="btn-secondary !h-[40px] w-full"
      >
        <SignOut size={16} aria-hidden="true" />
        <span>Sign out and switch account</span>
      </button>
    </div>
  );
}
