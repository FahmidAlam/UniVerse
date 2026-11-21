import { zodResolver } from "@hookform/resolvers/zod";
import {
  CheckCircle,
  Circle,
  CircleNotch,
  ClockCountdown,
  Eye,
  EyeSlash,
  LockKey,
  WarningCircle,
} from "@phosphor-icons/react";
import { motion, useReducedMotion } from "motion/react";
import { useEffect, useState } from "react";
import { useForm } from "react-hook-form";
import { useNavigate } from "react-router-dom";
import { toast } from "sonner";
import { z } from "zod";
import { useAuth } from "@/features/auth/AuthProvider";

const resetSchema = z
  .object({
    password: z
      .string()
      .min(8, "Password must be at least 8 characters.")
      .regex(/[A-Z]/, "Include at least one uppercase letter.")
      .regex(/[0-9]/, "Include at least one number."),
    confirm: z.string().min(1, "Re-enter your password."),
  })
  .refine((data) => data.password === data.confirm, {
    message: "Passwords do not match.",
    path: ["confirm"],
  });

type ResetFormValues = z.infer<typeof resetSchema>;

function formatRemaining(ms: number): string {
  const totalSec = Math.max(0, Math.floor(ms / 1000));
  const m = Math.floor(totalSec / 60);
  const s = totalSec % 60;
  return `${String(m).padStart(2, "0")}:${String(s).padStart(2, "0")}`;
}

export function ResetPasswordPage() {
  const navigate = useNavigate();
  const prefersReducedMotion = useReducedMotion() ?? false;
  const { recoveryExpiresAt, updateRecoveryPassword, signOut } = useAuth();

  const [showPassword, setShowPassword] = useState(false);
  const [showConfirm, setShowConfirm] = useState(false);
  const [updated, setUpdated] = useState(false);
  const [serverError, setServerError] = useState<string | null>(null);
  const [shakeCount, setShakeCount] = useState(0);
  const [now, setNow] = useState(() => Date.now());

  const {
    register,
    watch,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<ResetFormValues>({
    resolver: zodResolver(resetSchema),
    defaultValues: { password: "", confirm: "" },
    mode: "onChange",
  });

  const passwordVal = watch("password");
  const confirmVal = watch("confirm");

  useEffect(() => {
    if (!recoveryExpiresAt) return;
    const id = window.setInterval(() => setNow(Date.now()), 1000);
    return () => window.clearInterval(id);
  }, [recoveryExpiresAt]);

  const remainingMs = recoveryExpiresAt ? recoveryExpiresAt - now : 0;

  const requirements = [
    { label: "At least 8 characters", met: passwordVal.length >= 8 },
    { label: "Contains an uppercase letter (A–Z)", met: /[A-Z]/.test(passwordVal) },
    { label: "Contains a number (0–9)", met: /[0-9]/.test(passwordVal) },
    {
      label: "Matches confirm password",
      met: passwordVal.length > 0 && passwordVal === confirmVal,
    },
  ];

  const onValidSubmit = async (values: ResetFormValues) => {
    setServerError(null);
    const result = await updateRecoveryPassword(values.password);
    if (!result.ok) {
      const msg = result.error ?? "Failed to save new password.";
      setServerError(msg);
      setShakeCount((n) => n + 1);
      toast.error("Password update failed", { description: msg });
      return;
    }
    setUpdated(true);
    toast.success("Administrator password updated");
  };

  return (
    <motion.div
      key={`reset-shake-${shakeCount}`}
      animate={
        shakeCount > 0 && !prefersReducedMotion
          ? { x: [0, -4, 4, -4, 3, 0] }
          : undefined
      }
      transition={{ duration: 0.24, ease: [0.16, 1, 0.3, 1] }}
      className="flex flex-col gap-5"
    >
      <div>
        <div className="mb-2 inline-flex items-center gap-1.5 rounded-[var(--r-control)] border border-[var(--border-subtle)] bg-[var(--bg-surface)] px-2.5 py-1 font-mono-tabular text-[11.5px] text-[var(--ink-secondary)]">
          <ClockCountdown
            size={14}
            className="text-[var(--accent-pine)]"
            aria-hidden="true"
          />
          <span>
            Recovery window:{" "}
            {recoveryExpiresAt ? formatRemaining(remainingMs) : "10:00"}
          </span>
        </div>
        <h1 className="font-serif-editorial text-[24px] font-semibold leading-tight tracking-[-0.02em] text-[var(--ink-primary)]">
          Set New Password
        </h1>
        <p className="mt-1.5 text-[13.5px] leading-[1.5] text-[var(--ink-secondary)]">
          Choose a strong password to activate your administrator invitation or
          complete account recovery.
        </p>
      </div>

      {serverError && (
        <div
          role="alert"
          className="flex items-start gap-2 rounded-[var(--r-control)] border border-[var(--sem-conflict-border)] bg-[var(--sem-conflict-bg)] px-3.5 py-2.5 text-[12.5px] text-[var(--sem-conflict-ink)]"
        >
          <WarningCircle size={16} className="mt-0.5 shrink-0" aria-hidden="true" />
          <span>{serverError}</span>
        </div>
      )}

      {updated ? (
        <div className="flex flex-col gap-3 rounded-[var(--r-card)] border border-[var(--sem-lab-border)] bg-[var(--sem-lab-bg)] p-4 text-[13px] text-[var(--sem-lab-ink)]">
          <div className="flex items-center gap-2 font-semibold">
            <CheckCircle size={18} aria-hidden="true" />
            <span>Password updated</span>
          </div>
          <p className="text-[12.5px] leading-relaxed">
            Your new administrator password has been saved. Sign in to open the
            Routine Operations Console.
          </p>
          <button
            type="button"
            onClick={() => {
              void signOut().then(() => navigate("/login", { replace: true }));
            }}
            className="btn-primary mt-1 w-full"
          >
            Continue to Sign In
          </button>
        </div>
      ) : (
        <form
          onSubmit={handleSubmit(onValidSubmit, () => setShakeCount((n) => n + 1))}
          className="flex flex-col gap-4"
          noValidate
        >
          <div className="flex flex-col gap-1.5">
            <label
              htmlFor="new-password"
              className="text-[12.5px] font-semibold text-[var(--ink-primary)]"
            >
              New Password
            </label>
            <div className="relative flex items-center">
              <LockKey
                size={16}
                className="pointer-events-none absolute left-3 text-[var(--ink-muted)]"
                aria-hidden="true"
              />
              <input
                id="new-password"
                type={showPassword ? "text" : "password"}
                autoComplete="new-password"
                placeholder="At least 8 characters"
                aria-invalid={Boolean(errors.password)}
                {...register("password")}
                className="h-[40px] w-full rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] pl-9 pr-10 text-[13.5px] text-[var(--ink-primary)] placeholder:text-[var(--ink-muted)] focus:border-[var(--accent-pine)]"
              />
              <button
                type="button"
                onClick={() => setShowPassword((v) => !v)}
                aria-label={showPassword ? "Hide new password" : "Show new password"}
                className="absolute right-1.5 flex h-8 w-8 items-center justify-center rounded-[5px] text-[var(--ink-secondary)] hover:bg-[var(--surface-hover)] hover:text-[var(--ink-primary)]"
              >
                {showPassword ? (
                  <EyeSlash size={16} aria-hidden="true" />
                ) : (
                  <Eye size={16} aria-hidden="true" />
                )}
              </button>
            </div>
            {errors.password && (
              <p className="text-[12px] font-medium text-[var(--sem-conflict-ink)]" role="alert">
                {errors.password.message}
              </p>
            )}
          </div>

          <div className="flex flex-col gap-1.5">
            <label
              htmlFor="confirm-password"
              className="text-[12.5px] font-semibold text-[var(--ink-primary)]"
            >
              Confirm Password
            </label>
            <div className="relative flex items-center">
              <LockKey
                size={16}
                className="pointer-events-none absolute left-3 text-[var(--ink-muted)]"
                aria-hidden="true"
              />
              <input
                id="confirm-password"
                type={showConfirm ? "text" : "password"}
                autoComplete="new-password"
                placeholder="Re-enter password"
                aria-invalid={Boolean(errors.confirm)}
                {...register("confirm")}
                className="h-[40px] w-full rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] pl-9 pr-10 text-[13.5px] text-[var(--ink-primary)] placeholder:text-[var(--ink-muted)] focus:border-[var(--accent-pine)]"
              />
              <button
                type="button"
                onClick={() => setShowConfirm((v) => !v)}
                aria-label={showConfirm ? "Hide confirm password" : "Show confirm password"}
                className="absolute right-1.5 flex h-8 w-8 items-center justify-center rounded-[5px] text-[var(--ink-secondary)] hover:bg-[var(--surface-hover)] hover:text-[var(--ink-primary)]"
              >
                {showConfirm ? (
                  <EyeSlash size={16} aria-hidden="true" />
                ) : (
                  <Eye size={16} aria-hidden="true" />
                )}
              </button>
            </div>
            {errors.confirm && (
              <p className="text-[12px] font-medium text-[var(--sem-conflict-ink)]" role="alert">
                {errors.confirm.message}
              </p>
            )}
          </div>

          {/* Live 4-Item Inline Password Checklist */}
          <ul
            aria-label="Password strength requirements"
            data-testid="password-requirements-checklist"
            className="flex flex-col gap-1.5 rounded-[var(--r-control)] border border-[var(--border-subtle)] bg-[var(--bg-surface)] px-3.5 py-3 text-[12px]"
          >
            {requirements.map((item) => (
              <li
                key={item.label}
                data-met={item.met ? "true" : "false"}
                className="flex items-center gap-2"
                style={{
                  color: item.met
                    ? "var(--sem-lab-ink)"
                    : "var(--ink-muted)",
                }}
              >
                {item.met ? (
                  <CheckCircle size={15} className="shrink-0" aria-hidden="true" />
                ) : (
                  <Circle size={15} className="shrink-0" aria-hidden="true" />
                )}
                <span className={item.met ? "font-medium" : undefined}>
                  {item.label}
                </span>
              </li>
            ))}
          </ul>

          <button type="submit" disabled={isSubmitting} className="btn-primary w-full">
            {isSubmitting ? (
              <CircleNotch size={16} className="animate-spin" aria-hidden="true" />
            ) : (
              <span>Save Password</span>
            )}
          </button>
        </form>
      )}
    </motion.div>
  );
}
