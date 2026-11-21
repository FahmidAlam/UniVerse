import { zodResolver } from "@hookform/resolvers/zod";
import {
  ArrowLeft,
  CheckCircle,
  CircleNotch,
  EnvelopeSimple,
  PaperPlaneTilt,
  WarningCircle,
} from "@phosphor-icons/react";
import { motion, useReducedMotion } from "motion/react";
import { useState } from "react";
import { useForm } from "react-hook-form";
import { Link } from "react-router-dom";
import { toast } from "sonner";
import { z } from "zod";
import { useAuth } from "@/features/auth/AuthProvider";

const forgotSchema = z.object({
  email: z
    .string()
    .trim()
    .min(1, "Enter your committee institutional email.")
    .email("Enter a valid institutional email address."),
});

type ForgotFormValues = z.infer<typeof forgotSchema>;

export function ForgotPasswordPage() {
  const prefersReducedMotion = useReducedMotion() ?? false;
  const { sendPasswordReset } = useAuth();

  const [sentEmail, setSentEmail] = useState<string | null>(null);
  const [serverError, setServerError] = useState<string | null>(null);
  const [shakeCount, setShakeCount] = useState(0);

  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<ForgotFormValues>({
    resolver: zodResolver(forgotSchema),
    defaultValues: { email: "" },
  });

  const onValidSubmit = async (values: ForgotFormValues) => {
    setServerError(null);
    const result = await sendPasswordReset(values.email);
    if (!result.ok) {
      const msg = result.error ?? "Unable to send recovery email.";
      setServerError(msg);
      setShakeCount((n) => n + 1);
      toast.error("Recovery email not sent", { description: msg });
      return;
    }
    setSentEmail(values.email.trim());
    toast.success("Password recovery link sent");
  };

  return (
    <motion.div
      key={`forgot-shake-${shakeCount}`}
      animate={
        shakeCount > 0 && !prefersReducedMotion
          ? { x: [0, -4, 4, -4, 3, 0] }
          : undefined
      }
      transition={{ duration: 0.24, ease: [0.16, 1, 0.3, 1] }}
      className="flex flex-col gap-5"
    >
      <div>
        <Link
          to="/login"
          className="mb-3 inline-flex items-center gap-1.5 text-[12.5px] font-medium text-[var(--ink-secondary)] no-underline hover:text-[var(--ink-primary)]"
        >
          <ArrowLeft size={14} aria-hidden="true" />
          <span>Back to Sign In</span>
        </Link>
        <h1 className="font-serif-editorial text-[24px] font-semibold leading-tight tracking-[-0.02em] text-[var(--ink-primary)]">
          Reset Admin Password
        </h1>
        <p className="mt-1.5 text-[13.5px] leading-[1.5] text-[var(--ink-secondary)]">
          Enter your approved Leading University{" "}
          <span className="acronym-sc">cse</span> email to receive a password
          recovery link.
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

      {sentEmail ? (
        <div
          role="status"
          className="flex flex-col gap-3 rounded-[var(--r-card)] border border-[var(--sem-lab-border)] bg-[var(--sem-lab-bg)] p-4 text-[13px] text-[var(--sem-lab-ink)]"
        >
          <div className="flex items-center gap-2 font-semibold">
            <CheckCircle size={18} aria-hidden="true" />
            <span>Recovery link sent</span>
          </div>
          <p className="text-[12.5px] leading-relaxed">
            If <span className="font-mono-tabular font-medium">{sentEmail}</span>{" "}
            belongs to an authorized administrator account, open the link in this
            browser within 10 minutes to choose a new password.
          </p>
          <Link to="/login" className="btn-secondary mt-1 w-full no-underline">
            Return to Sign In
          </Link>
        </div>
      ) : (
        <form
          onSubmit={handleSubmit(onValidSubmit, () => setShakeCount((n) => n + 1))}
          className="flex flex-col gap-4"
          noValidate
        >
          <div className="flex flex-col gap-1.5">
            <label
              htmlFor="reset-email"
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
                id="reset-email"
                type="email"
                autoComplete="email"
                placeholder="committee.cse@lus.ac.bd"
                aria-invalid={Boolean(errors.email)}
                {...register("email")}
                className="h-[40px] w-full rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] pl-9 pr-3 text-[13.5px] text-[var(--ink-primary)] placeholder:text-[var(--ink-muted)] focus:border-[var(--accent-pine)]"
              />
            </div>
            {errors.email && (
              <p className="text-[12px] font-medium text-[var(--sem-conflict-ink)]" role="alert">
                {errors.email.message}
              </p>
            )}
          </div>

          <button type="submit" disabled={isSubmitting} className="btn-primary w-full">
            {isSubmitting ? (
              <CircleNotch size={16} className="animate-spin" aria-hidden="true" />
            ) : (
              <PaperPlaneTilt size={16} aria-hidden="true" />
            )}
            <span>{isSubmitting ? "Sending link..." : "Send Recovery Link"}</span>
          </button>
        </form>
      )}
    </motion.div>
  );
}
