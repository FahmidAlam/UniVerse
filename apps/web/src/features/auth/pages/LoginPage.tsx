import { zodResolver } from "@hookform/resolvers/zod";
import {
  CircleNotch,
  EnvelopeSimple,
  Eye,
  EyeSlash,
  LockKey,
  SignIn,
  WarningCircle,
} from "@phosphor-icons/react";
import { motion, useReducedMotion } from "motion/react";
import { useState } from "react";
import { useForm } from "react-hook-form";
import { Link } from "react-router-dom";
import { toast } from "sonner";
import { z } from "zod";
import { useAuth } from "@/features/auth/AuthProvider";

const loginSchema = z.object({
  email: z
    .string()
    .trim()
    .min(1, "Enter your committee institutional email.")
    .email("Enter a valid institutional email address."),
  password: z
    .string()
    .min(6, "Password must be at least 6 characters."),
});

type LoginFormValues = z.infer<typeof loginSchema>;

function GoogleMarkSvg() {
  return (
    <svg width="16" height="16" viewBox="0 0 24 24" aria-hidden="true">
      <path
        fill="#4285F4"
        d="M23.745 12.27c0-.7-.06-1.4-.19-2.07H12v4.51h6.6c-.29 1.52-1.14 2.82-2.4 3.68v3.05h3.88c2.27-2.09 3.665-5.17 3.665-9.17Z"
      />
      <path
        fill="#34A853"
        d="M12 24c3.24 0 5.95-1.08 7.93-2.91l-3.88-3.05c-1.08.72-2.45 1.16-4.05 1.16-3.12 0-5.77-2.11-6.72-4.96H1.29v3.14C3.26 21.3 7.31 24 12 24Z"
      />
      <path
        fill="#FBBC05"
        d="M5.28 14.24c-.24-.72-.38-1.49-.38-2.24s.14-1.52.38-2.24V6.62H1.29C.47 8.24 0 10.06 0 12s.47 3.76 1.29 5.38l3.99-3.14Z"
      />
      <path
        fill="#EA4335"
        d="M12 4.75c1.77 0 3.35.61 4.6 1.8l3.42-3.42C17.95 1.19 15.24 0 12 0 7.31 0 3.26 2.7 1.29 6.62l3.99 3.14c.95-2.85 3.6-4.96 6.72-4.96Z"
      />
    </svg>
  );
}

export function LoginPage() {
  const prefersReducedMotion = useReducedMotion() ?? false;
  const { signInWithEmail, signInWithGoogle, authError } = useAuth();

  const [showPassword, setShowPassword] = useState(false);
  const [serverError, setServerError] = useState<string | null>(authError);
  const [shakeCount, setShakeCount] = useState(0);

  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<LoginFormValues>({
    resolver: zodResolver(loginSchema),
    defaultValues: { email: "", password: "" },
  });

  const onValidSubmit = async (values: LoginFormValues) => {
    setServerError(null);
    const result = await signInWithEmail(values.email, values.password);
    if (!result.ok) {
      const msg = result.error ?? "Unable to sign in. Please try again.";
      setServerError(msg);
      setShakeCount((n) => n + 1);
      toast.error("Sign-in could not be completed", { description: msg });
    }
  };

  const onInvalidSubmit = () => {
    setShakeCount((n) => n + 1);
  };

  async function handleGoogle() {
    setServerError(null);
    const result = await signInWithGoogle();
    if (!result.ok) {
      const msg = result.error ?? "Google sign-in could not be started.";
      setServerError(msg);
      setShakeCount((n) => n + 1);
      toast.error("Google sign-in unavailable", { description: msg });
    }
  }

  return (
    <motion.div
      key={`login-shake-${shakeCount}`}
      animate={
        shakeCount > 0 && !prefersReducedMotion
          ? { x: [0, -4, 4, -4, 3, 0] }
          : undefined
      }
      transition={{ duration: 0.24, ease: [0.16, 1, 0.3, 1] }}
      className="flex flex-col gap-5"
    >
      <div>
        <h1 className="font-serif-editorial text-[24px] font-semibold leading-tight tracking-[-0.02em] text-[var(--ink-primary)]">
          Administrator Sign In
        </h1>
        <p className="mt-1.5 text-[13.5px] leading-[1.5] text-[var(--ink-secondary)]">
          Sign in with an approved Leading University{" "}
          <span className="acronym-sc">cse</span> Routine Committee account.
        </p>
      </div>

      {serverError && (
        <div
          role="alert"
          data-testid="login-error-alert"
          className="flex items-start gap-2.5 rounded-[var(--r-control)] border border-[var(--sem-conflict-border)] bg-[var(--sem-conflict-bg)] px-3.5 py-3 text-[12.5px] text-[var(--sem-conflict-ink)]"
        >
          <WarningCircle size={17} className="mt-0.5 shrink-0" aria-hidden="true" />
          <div className="min-w-0 flex-1">
            <p className="font-semibold">Unable to complete sign-in</p>
            <p className="mt-0.5">{serverError}</p>
            <Link
              to="/forgot-password"
              className="mt-1.5 inline-block text-[12px] font-semibold text-[var(--sem-conflict-ink)] underline underline-offset-2"
            >
              Reset password or request recovery link
            </Link>
          </div>
        </div>
      )}

      <button
        type="button"
        disabled={isSubmitting}
        onClick={() => void handleGoogle()}
        className="btn-secondary !h-[40px] w-full"
      >
        <GoogleMarkSvg />
        <span>Continue with Google</span>
      </button>

      <div className="flex items-center gap-3 text-[12px] text-[var(--ink-muted)]">
        <span className="h-px flex-1 bg-[var(--border-subtle)]" />
        <span>or use committee email</span>
        <span className="h-px flex-1 bg-[var(--border-subtle)]" />
      </div>

      <form
        onSubmit={handleSubmit(onValidSubmit, onInvalidSubmit)}
        className="flex flex-col gap-4"
        noValidate
      >
        <div className="flex flex-col gap-1.5">
          <label
            htmlFor="admin-email"
            className="text-[12.5px] font-semibold text-[var(--ink-primary)]"
          >
            Institutional Email
          </label>
          <div className="relative flex items-center">
            <EnvelopeSimple
              size={16}
              className="pointer-events-none absolute left-3 text-[var(--ink-muted)]"
              aria-hidden="true"
            />
            <input
              id="admin-email"
              type="email"
              autoComplete="email"
              placeholder="committee.cse@lus.ac.bd"
              aria-invalid={Boolean(errors.email)}
              {...register("email")}
              className="h-[40px] w-full rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] pl-9 pr-3 text-[13.5px] text-[var(--ink-primary)] placeholder:text-[var(--ink-muted)] focus:border-[var(--accent-brand)]"
            />
          </div>
          {errors.email && (
            <p className="text-[12px] font-medium text-[var(--sem-conflict-ink)]" role="alert">
              {errors.email.message}
            </p>
          )}
        </div>

        <div className="flex flex-col gap-1.5">
          <div className="flex items-center justify-between gap-2">
            <label
              htmlFor="admin-password"
              className="text-[12.5px] font-semibold text-[var(--ink-primary)]"
            >
              Password
            </label>
            <Link
              to="/forgot-password"
              className="text-[12px] font-medium text-[var(--accent-brand)] underline-offset-[3px] hover:underline"
            >
              Forgot password?
            </Link>
          </div>
          <div className="relative flex items-center">
            <LockKey
              size={16}
              className="pointer-events-none absolute left-3 text-[var(--ink-muted)]"
              aria-hidden="true"
            />
            <input
              id="admin-password"
              type={showPassword ? "text" : "password"}
              autoComplete="current-password"
              placeholder="Minimum 6 characters"
              aria-invalid={Boolean(errors.password)}
              {...register("password")}
              className="h-[40px] w-full rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] pl-9 pr-10 text-[13.5px] text-[var(--ink-primary)] placeholder:text-[var(--ink-muted)] focus:border-[var(--accent-brand)]"
            />
            <button
              type="button"
              onClick={() => setShowPassword((v) => !v)}
              aria-label={showPassword ? "Hide password" : "Show password"}
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

        <button
          type="submit"
          disabled={isSubmitting}
          className="btn-primary mt-1 w-full"
        >
          {isSubmitting ? (
            <CircleNotch size={16} className="animate-spin" aria-hidden="true" />
          ) : (
            <SignIn size={16} aria-hidden="true" />
          )}
          <span>
            {isSubmitting ? "Signing in..." : "Sign In to Operations Console"}
          </span>
        </button>
      </form>
    </motion.div>
  );
}
