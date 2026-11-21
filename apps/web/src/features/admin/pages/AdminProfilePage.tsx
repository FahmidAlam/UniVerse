import { zodResolver } from "@hookform/resolvers/zod";
import {
  Key,
  SignOut,
  UserCircle,
} from "@phosphor-icons/react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useEffect } from "react";
import { useForm } from "react-hook-form";
import { useNavigate } from "react-router-dom";
import { toast } from "sonner";
import { z } from "zod";
import {
  LedgerErrorRecovery,
  LedgerTableSkeleton,
} from "@/components/ui/AsyncStates";
import { Badge } from "@/components/ui/Badge";
import { Button } from "@/components/ui/Button";
import { StickyDirtyBar } from "@/components/ui/StickyDirtyBar";
import {
  FACULTY_DESIGNATIONS,
  INSTITUTIONAL_DEPARTMENTS,
} from "@/features/admin/services/facultyService";
import {
  fetchOwnProfile,
  requestOwnPasswordReset,
  updateOwnProfile,
} from "@/features/admin/services/profileService";
import { useAuth } from "@/features/auth/AuthProvider";

const profileSchema = z.object({
  name: z
    .string()
    .trim()
    .min(2, "Display name must be at least 2 characters.")
    .max(120),
  department: z.string().trim().max(40).optional(),
  designation: z.string().trim().max(60).optional(),
  teacher_code: z.string().trim().max(24).optional(),
});

type ProfileFormValues = z.infer<typeof profileSchema>;

function getInitials(name: string | null | undefined, email: string): string {
  const src = (name && name.trim()) || email;
  const parts = src
    .replace(/[^A-Za-z0-9 ]/g, " ")
    .trim()
    .split(/\s+/)
    .filter(Boolean);
  if (parts.length === 0) return "AD";
  if (parts.length === 1) return parts[0]!.slice(0, 2).toUpperCase();
  return `${parts[0]![0]}${parts[1]![0]}`.toUpperCase();
}

export function AdminProfilePage() {
  const { isDevPreview, profile: authProfile, signOut } = useAuth();
  const navigate = useNavigate();
  const queryClient = useQueryClient();

  const {
    data: record,
    isLoading,
    isError,
    error,
    refetch,
  } = useQuery({
    queryKey: ["admin-own-profile", authProfile?.id ?? "preview", isDevPreview],
    queryFn: () => fetchOwnProfile(authProfile?.id ?? null, isDevPreview),
    retry: false,
  });

  const form = useForm<ProfileFormValues>({
    resolver: zodResolver(profileSchema),
    defaultValues: {
      name: "",
      department: "CSE",
      designation: "",
      teacher_code: "",
    },
  });

  useEffect(() => {
    if (record) {
      form.reset({
        name: record.name ?? "",
        department: record.department ?? "CSE",
        designation: record.designation ?? "",
        teacher_code: record.teacher_code ?? "",
      });
    }
  }, [record, form]);

  const saveMutation = useMutation({
    mutationFn: (values: ProfileFormValues) =>
      updateOwnProfile(
        authProfile?.id ?? null,
        {
          name: values.name,
          department: values.department,
          designation: values.designation,
          teacher_code: values.teacher_code,
        },
        isDevPreview,
      ),
    onSuccess: (updated) => {
      void queryClient.invalidateQueries({ queryKey: ["admin-own-profile"] });
      void queryClient.invalidateQueries({
        queryKey: ["admin-users-directory"],
      });
      form.reset({
        name: updated.name ?? "",
        department: updated.department ?? "",
        designation: updated.designation ?? "",
        teacher_code: updated.teacher_code ?? "",
      });
      toast.success("Updated administrator profile");
    },
    onError: (err) => {
      toast.error("Could not update profile", {
        description:
          err instanceof Error ? err.message : "Database update failed.",
      });
    },
  });

  const resetPwdMutation = useMutation({
    mutationFn: () => {
      const origin =
        typeof window !== "undefined" ? window.location.origin : "http://localhost";
      return requestOwnPasswordReset(
        record?.email ?? authProfile?.email ?? "",
        origin,
        isDevPreview,
      );
    },
    onSuccess: () => {
      toast.success("Password recovery email requested", {
        description:
          "Check your institutional inbox for the recovery link.",
      });
    },
    onError: (err) => {
      toast.error("Could not send password recovery link", {
        description:
          err instanceof Error ? err.message : "Auth service failed.",
      });
    },
  });

  return (
    <div className="space-y-4">
      <header className="border-b border-[var(--border-subtle)] pb-4">
        <h1 className="font-editorial text-[26px] font-semibold tracking-[-0.02em] text-[var(--ink-primary)]">
          Administrator Profile
        </h1>
        <p className="mt-1 max-w-[66ch] text-[13.5px] leading-[1.55] text-[var(--ink-secondary)]">
          Inspect your institutional role credentials and update permitted
          departmental contact details.
        </p>
      </header>

      {isLoading || !record ? (
        <LedgerTableSkeleton rows={4} label="Loading administrator profile" />
      ) : isError ? (
        <LedgerErrorRecovery
          title="Could not load administrator profile"
          message={
            error instanceof Error ? error.message : "Supabase query failed."
          }
          onRetry={() => void refetch()}
        />
      ) : (
        <div className="grid gap-5 lg:grid-cols-[minmax(280px,0.85fr)_minmax(0,1.4fr)]">
          {/* Read-Only Institutional Identity Card */}
          <aside className="ledger-card space-y-4 p-5">
            <div className="flex items-center gap-3.5">
              {record.avatar_url ? (
                <img
                  src={record.avatar_url}
                  alt={record.name ?? record.email}
                  className="h-14 w-14 rounded-full border border-[var(--border-subtle)] object-cover"
                />
              ) : (
                <div className="flex h-14 w-14 shrink-0 items-center justify-center rounded-full border border-[var(--border-control)] bg-[var(--bg-canvas)] font-mono-tabular text-[18px] font-semibold text-[var(--ink-primary)]">
                  {getInitials(record.name, record.email)}
                </div>
              )}
              <div className="min-w-0">
                <div className="truncate text-[16px] font-semibold text-[var(--ink-primary)]">
                  {record.name || "Administrator"}
                </div>
                <div className="font-mono-tabular truncate text-[12px] text-[var(--ink-muted)]">
                  {record.email}
                </div>
              </div>
            </div>

            <div className="divide-y divide-[var(--border-subtle)] border-t border-[var(--border-subtle)] text-[13px]">
              <div className="flex items-center justify-between py-2.5">
                <span className="text-[var(--ink-secondary)]">Access Role</span>
                <Badge tone="pine" mono>
                  {record.role.toUpperCase()}
                </Badge>
              </div>
              <div className="flex items-center justify-between py-2.5">
                <span className="text-[var(--ink-secondary)]">Member Since</span>
                <span className="font-mono-tabular text-[var(--ink-primary)]">
                  {new Date(record.created_at).toLocaleDateString()}
                </span>
              </div>
            </div>

            <div className="flex flex-col gap-2 border-t border-[var(--border-subtle)] pt-3">
              <Button
                variant="secondary"
                size="md"
                disabled={resetPwdMutation.isPending || !record.email}
                onClick={() => resetPwdMutation.mutate()}
              >
                <Key size={15} aria-hidden="true" />
                <span>
                  {resetPwdMutation.isPending
                    ? "Sending Reset Email..."
                    : "Reset Password"}
                </span>
              </Button>
              <Button
                variant="ghost"
                size="md"
                onClick={() => {
                  void signOut().then(() => navigate("/", { replace: true }));
                }}
                className="justify-center text-[var(--sem-conflict-ink)] hover:bg-[var(--sem-conflict-bg)]"
              >
                <SignOut size={15} aria-hidden="true" />
                <span>{isDevPreview ? "Exit Preview" : "Sign Out"}</span>
              </Button>
            </div>
          </aside>

          {/* Editable Personal Metadata Form (Strictly excludes avatar upload F-30) */}
          <form
            id="own-profile-form"
            onSubmit={form.handleSubmit((vals) => saveMutation.mutate(vals))}
            className="ledger-card space-y-4 p-5"
            noValidate
          >
            <div className="flex items-center gap-2 border-b border-[var(--border-subtle)] pb-3 text-[15px] font-semibold text-[var(--ink-primary)]">
              <UserCircle size={18} aria-hidden="true" />
              <span>Departmental Profile Details</span>
            </div>

            <div>
              <label
                htmlFor="prof-name"
                className="mb-1.5 block text-[12.5px] font-medium text-[var(--ink-primary)]"
              >
                Full Name
              </label>
              <input
                id="prof-name"
                type="text"
                {...form.register("name")}
                className="h-[40px] w-full rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-3 text-[13.5px]"
              />
              {form.formState.errors.name && (
                <p className="mt-1 text-[12px] text-[var(--sem-conflict-ink)]">
                  {form.formState.errors.name.message}
                </p>
              )}
            </div>

            <div className="grid gap-3 sm:grid-cols-2">
              <div>
                <label
                  htmlFor="prof-dept"
                  className="mb-1.5 block text-[12.5px] font-medium text-[var(--ink-primary)]"
                >
                  Department
                </label>
                <input
                  id="prof-dept"
                  list="prof-dept-list"
                  {...form.register("department")}
                  className="h-[40px] w-full rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-3 text-[13.5px]"
                />
                <datalist id="prof-dept-list">
                  {INSTITUTIONAL_DEPARTMENTS.map((d) => (
                    <option key={d} value={d} />
                  ))}
                </datalist>
              </div>

              <div>
                <label
                  htmlFor="prof-code"
                  className="mb-1.5 block text-[12.5px] font-medium text-[var(--ink-primary)]"
                >
                  Committee / Teacher Code
                </label>
                <input
                  id="prof-code"
                  type="text"
                  {...form.register("teacher_code")}
                  className="font-mono-tabular h-[40px] w-full rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-3 text-[13.5px] uppercase"
                />
              </div>
            </div>

            <div>
              <label
                htmlFor="prof-designation"
                className="mb-1.5 block text-[12.5px] font-medium text-[var(--ink-primary)]"
              >
                Designation
              </label>
              <input
                id="prof-designation"
                list="prof-designation-list"
                {...form.register("designation")}
                className="h-[40px] w-full rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-3 text-[13.5px]"
              />
              <datalist id="prof-designation-list">
                {FACULTY_DESIGNATIONS.map((d) => (
                  <option key={d} value={d} />
                ))}
              </datalist>
            </div>

            <StickyDirtyBar
              docked
              isDirty={form.formState.isDirty}
              isSaving={saveMutation.isPending}
              message="Unsaved profile edits"
              saveLabel="Save Profile"
              formId="own-profile-form"
              onDiscard={() => {
                form.reset({
                  name: record.name ?? "",
                  department: record.department ?? "",
                  designation: record.designation ?? "",
                  teacher_code: record.teacher_code ?? "",
                });
              }}
            />
          </form>
        </div>
      )}
    </div>
  );
}
