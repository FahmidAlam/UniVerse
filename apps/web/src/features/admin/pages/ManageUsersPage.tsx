import { zodResolver } from "@hookform/resolvers/zod";
import {
  EnvelopeSimple,
  MagnifyingGlass,
  PencilSimple,
  Plus,
  ShieldWarning,
  Trash,
  UserPlus,
  UsersThree,
  WarningCircle,
} from "@phosphor-icons/react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useMemo, useRef, useState } from "react";
import { useForm } from "react-hook-form";
import { toast } from "sonner";
import { z } from "zod";
import {
  LedgerEmptyState,
  LedgerErrorRecovery,
  LedgerFilterEmpty,
  LedgerTableSkeleton,
} from "@/components/ui/AsyncStates";
import { Badge } from "@/components/ui/Badge";
import { Button } from "@/components/ui/Button";
import { ConfirmDialog } from "@/components/ui/ConfirmDialog";
import {
  DataLedgerTable,
  HoverCopyButton,
  type BulkActionItem,
  type DataLedgerColumn,
} from "@/components/ui/DataLedgerTable";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogTitle,
} from "@/components/ui/Dialog";
import { MasterDetailShell } from "@/components/ui/MasterDetailShell";
import { StickyDirtyBar } from "@/components/ui/StickyDirtyBar";
import { useWorkspaceShortcuts } from "@/core/hooks/useWorkspaceShortcuts";
import {
  FACULTY_DESIGNATIONS,
  INSTITUTIONAL_DEPARTMENTS,
} from "@/features/admin/services/facultyService";
import {
  deleteWhitelistEntries,
  fetchDirectoryProfiles,
  fetchWhitelistEntries,
  invokeInviteAdmin,
  updateProfileRole,
  upsertWhitelistEntry,
  type DirectoryProfileRecord,
  type UserRole,
  type WhitelistRecord,
} from "@/features/admin/services/usersService";
import { useAuth } from "@/features/auth/AuthProvider";
import { cn } from "@/lib/utils";

type UsersTab = "directory" | "whitelists";
type RoleFilter = "all" | "admin" | "teacher" | "student";

const whitelistSchema = z.object({
  email: z.string().trim().email("Enter a valid institutional email address."),
  role: z.enum(["student", "teacher", "admin"]),
  name: z.string().trim().max(120).optional(),
  teacher_code: z.string().trim().max(24).optional(),
  department: z.string().trim().max(40).optional(),
  designation: z.string().trim().max(60).optional(),
  batch: z.string().trim().max(20).optional(),
  section: z.string().trim().max(12).optional(),
  semester: z
    .string()
    .trim()
    .refine(
      (v) =>
        v === "" ||
        (/^\d+$/.test(v) && Number.parseInt(v, 10) >= 1 && Number.parseInt(v, 10) <= 12),
      "Semester must be between 1 and 12.",
    ),
});

type WhitelistFormValues = z.infer<typeof whitelistSchema>;

const inviteAdminSchema = z.object({
  email: z.string().trim().email("Enter the administrator's institutional email."),
  name: z.string().trim().min(2, "Enter the administrator's full name.").max(120),
});

type InviteAdminFormValues = z.infer<typeof inviteAdminSchema>;

function toWhitelistForm(entry: WhitelistRecord | null): WhitelistFormValues {
  if (!entry) {
    return {
      email: "",
      role: "teacher",
      name: "",
      teacher_code: "",
      department: "CSE",
      designation: "Lecturer",
      batch: "",
      section: "",
      semester: "",
    };
  }
  return {
    email: entry.email,
    role: entry.role,
    name: entry.name ?? "",
    teacher_code: entry.teacher_code ?? "",
    department: entry.department ?? "",
    designation: entry.designation ?? "",
    batch: entry.batch ?? "",
    section: entry.section ?? "",
    semester: entry.semester !== null ? String(entry.semester) : "",
  };
}

function roleBadgeTone(role: UserRole): "pine" | "theory" | "neutral" {
  if (role === "admin") return "pine";
  if (role === "teacher") return "theory";
  return "neutral";
}

export function ManageUsersPage() {
  const { isDevPreview, profile: ownProfile } = useAuth();
  const queryClient = useQueryClient();
  const searchInputRef = useRef<HTMLInputElement>(null);

  const [tab, setTab] = useState<UsersTab>("directory");
  const [search, setSearch] = useState("");
  const [roleFilter, setRoleFilter] = useState<RoleFilter>("all");

  // Directory inspector state
  const [selectedProfileId, setSelectedProfileId] = useState<string | null>(null);
  const [pendingRoleEdit, setPendingRoleEdit] = useState<{
    profile: DirectoryProfileRecord;
    nextRole: UserRole;
  } | null>(null);

  // Whitelist inspector state
  const [selectedWhitelistEmail, setSelectedWhitelistEmail] = useState<
    string | "new" | null
  >(null);
  const [deleteWhitelistTarget, setDeleteWhitelistTarget] = useState<
    string[] | null
  >(null);

  // Invite Admin modal
  const [inviteOpen, setInviteOpen] = useState(false);

  const {
    data: profiles = [],
    isLoading: profilesLoading,
    isError: profilesError,
    error: profilesErrObj,
    refetch: refetchProfiles,
  } = useQuery({
    queryKey: ["admin-users-directory", isDevPreview],
    queryFn: () => fetchDirectoryProfiles(isDevPreview),
    retry: false,
  });

  const {
    data: whitelists = [],
    isLoading: whitelistsLoading,
    isError: whitelistsError,
    error: whitelistsErrObj,
    refetch: refetchWhitelists,
  } = useQuery({
    queryKey: ["admin-users-whitelists", isDevPreview],
    queryFn: () => fetchWhitelistEntries(isDevPreview),
    retry: false,
  });

  const selectedProfile = useMemo(
    () =>
      selectedProfileId
        ? profiles.find((p) => p.id === selectedProfileId) ?? null
        : null,
    [profiles, selectedProfileId],
  );

  const selectedWhitelist = useMemo(
    () =>
      selectedWhitelistEmail && selectedWhitelistEmail !== "new"
        ? whitelists.find((w) => w.email === selectedWhitelistEmail) ?? null
        : null,
    [whitelists, selectedWhitelistEmail],
  );

  const wlForm = useForm<WhitelistFormValues>({
    resolver: zodResolver(whitelistSchema),
    defaultValues: toWhitelistForm(null),
  });

  const inviteForm = useForm<InviteAdminFormValues>({
    resolver: zodResolver(inviteAdminSchema),
    defaultValues: { email: "", name: "" },
  });

  const openWhitelistInspector = (target: string | "new" | null) => {
    setSelectedWhitelistEmail(target);
    if (target === "new") {
      wlForm.reset(toWhitelistForm(null));
    } else if (target) {
      const rec = whitelists.find((w) => w.email === target) ?? null;
      wlForm.reset(toWhitelistForm(rec));
    }
  };

  useWorkspaceShortcuts({
    searchInputRef,
    onEscape: () => {
      if (tab === "directory" && selectedProfileId && !pendingRoleEdit) {
        setSelectedProfileId(null);
      } else if (
        tab === "whitelists" &&
        selectedWhitelistEmail !== null &&
        !deleteWhitelistTarget
      ) {
        openWhitelistInspector(null);
      }
    },
  });

  const roleMutation = useMutation({
    mutationFn: ({ targetId, nextRole }: { targetId: string; nextRole: UserRole }) =>
      updateProfileRole(
        targetId,
        nextRole,
        ownProfile?.id ?? null,
        isDevPreview,
      ),
    onSuccess: (updated) => {
      void queryClient.invalidateQueries({
        queryKey: ["admin-users-directory"],
      });
      void queryClient.invalidateQueries({
        queryKey: ["admin-dashboard-counts"],
      });
      setPendingRoleEdit(null);
      toast.success(`Updated role for ${updated.email} to ${updated.role}`);
    },
    onError: (err) => {
      setPendingRoleEdit(null);
      toast.error("Role update rejected", {
        description:
          err instanceof Error ? err.message : "Database update failed.",
      });
    },
  });

  const saveWhitelistMutation = useMutation({
    mutationFn: (values: WhitelistFormValues) =>
      upsertWhitelistEntry(
        {
          email: values.email,
          role: values.role,
          name: values.name,
          teacher_code: values.teacher_code,
          department: values.department,
          designation: values.designation,
          batch: values.batch,
          section: values.section,
          semester:
            values.semester.trim() !== ""
              ? Number.parseInt(values.semester.trim(), 10)
              : null,
        },
        isDevPreview,
      ),
    onSuccess: (saved) => {
      void queryClient.invalidateQueries({
        queryKey: ["admin-users-whitelists"],
      });
      setSelectedWhitelistEmail(saved.email);
      wlForm.reset(toWhitelistForm(saved));
      toast.success(`Saved whitelist entry for ${saved.email}`);
    },
    onError: (err) => {
      toast.error("Could not save whitelist entry", {
        description:
          err instanceof Error ? err.message : "Database write failed.",
      });
    },
  });

  const deleteWhitelistMutation = useMutation({
    mutationFn: (emails: string[]) =>
      deleteWhitelistEntries(emails, isDevPreview),
    onSuccess: (_data, emails) => {
      void queryClient.invalidateQueries({
        queryKey: ["admin-users-whitelists"],
      });
      if (
        selectedWhitelistEmail &&
        emails.includes(selectedWhitelistEmail)
      ) {
        setSelectedWhitelistEmail(null);
        wlForm.reset(toWhitelistForm(null));
      }
      setDeleteWhitelistTarget(null);
      toast.success(`Removed ${emails.length} whitelist entry(ies)`);
    },
    onError: (err) => {
      toast.error("Could not remove whitelist entry", {
        description:
          err instanceof Error ? err.message : "Database delete failed.",
      });
    },
  });

  const inviteAdminMutation = useMutation({
    mutationFn: (values: InviteAdminFormValues) =>
      invokeInviteAdmin(values, isDevPreview),
    onSuccess: (res) => {
      void queryClient.invalidateQueries({
        queryKey: ["admin-users-whitelists"],
      });
      setInviteOpen(false);
      inviteForm.reset({ email: "", name: "" });
      toast.success(`Invitation sent to ${res.invitedEmail}`, {
        description: `Callback locked to ${res.redirectTo}`,
      });
    },
    onError: (err) => {
      toast.error("Administrator invitation failed", {
        description:
          err instanceof Error
            ? err.message
            : "Could not reach invite-admin Edge Function.",
      });
    },
  });

  const dirCounts = useMemo(
    () => ({
      all: profiles.length,
      admin: profiles.filter((p) => p.role === "admin").length,
      teacher: profiles.filter((p) => p.role === "teacher").length,
      student: profiles.filter((p) => p.role === "student").length,
    }),
    [profiles],
  );

  const wlCounts = useMemo(
    () => ({
      all: whitelists.length,
      admin: whitelists.filter((w) => w.role === "admin").length,
      teacher: whitelists.filter((w) => w.role === "teacher").length,
      student: whitelists.filter((w) => w.role === "student").length,
    }),
    [whitelists],
  );

  const filteredProfiles = useMemo(() => {
    const q = search.trim().toLowerCase();
    return profiles.filter((p) => {
      if (roleFilter !== "all" && p.role !== roleFilter) return false;
      if (!q) return true;
      return (
        p.email.toLowerCase().includes(q) ||
        (p.name ?? "").toLowerCase().includes(q) ||
        (p.student_id ?? "").toLowerCase().includes(q) ||
        (p.teacher_code ?? "").toLowerCase().includes(q)
      );
    });
  }, [profiles, roleFilter, search]);

  const filteredWhitelists = useMemo(() => {
    const q = search.trim().toLowerCase();
    return whitelists.filter((w) => {
      if (roleFilter !== "all" && w.role !== roleFilter) return false;
      if (!q) return true;
      return (
        w.email.toLowerCase().includes(q) ||
        (w.name ?? "").toLowerCase().includes(q) ||
        (w.teacher_code ?? "").toLowerCase().includes(q) ||
        (w.department ?? "").toLowerCase().includes(q)
      );
    });
  }, [whitelists, roleFilter, search]);

  const directoryColumns = useMemo<DataLedgerColumn<DirectoryProfileRecord>[]>(
    () => [
      {
        id: "name",
        header: "Account",
        accessor: (p) => p.name ?? p.email,
        cell: (p) => (
          <div className="min-w-0">
            <div className="truncate font-medium text-[var(--ink-primary)]">
              {p.name?.trim() || "Unnamed Account"}
            </div>
            <div className="flex items-center gap-1 text-[12px] text-[var(--ink-muted)]">
              <span className="font-mono-tabular truncate">{p.email}</span>
              <HoverCopyButton value={p.email} label="email" />
            </div>
          </div>
        ),
      },
      {
        id: "role",
        header: "Role",
        accessor: (p) => p.role,
        cell: (p) => (
          <Badge tone={roleBadgeTone(p.role)} mono>
            {p.role.toUpperCase()}
          </Badge>
        ),
      },
      {
        id: "identifier",
        header: "Code / ID",
        accessor: (p) => p.teacher_code ?? p.student_id ?? "",
        cell: (p) => {
          const code = p.teacher_code || p.student_id;
          return code ? (
            <div className="flex items-center gap-1">
              <span className="font-mono-tabular text-[12.5px]">{code}</span>
              <HoverCopyButton value={code} label="institutional identifier" />
            </div>
          ) : (
            <span className="text-[var(--ink-muted)]">—</span>
          );
        },
      },
      {
        id: "cohort",
        header: "Dept / Batch",
        accessor: (p) => p.department ?? p.batch ?? "",
        cell: (p) => (
          <span className="font-mono-tabular text-[12.5px] text-[var(--ink-secondary)]">
            {[p.department, p.batch ? `Batch ${p.batch}` : null, p.section]
              .filter(Boolean)
              .join(" · ") || "—"}
          </span>
        ),
      },
    ],
    [],
  );

  const whitelistColumns = useMemo<DataLedgerColumn<WhitelistRecord>[]>(
    () => [
      {
        id: "email",
        header: "Whitelisted Email",
        accessor: (w) => w.email,
        cell: (w) => (
          <div className="min-w-0">
            <div className="flex items-center gap-1">
              <span className="font-mono-tabular font-medium text-[var(--ink-primary)]">
                {w.email}
              </span>
              <HoverCopyButton value={w.email} label="whitelist email" />
            </div>
            {w.name && (
              <div className="truncate text-[11.5px] text-[var(--ink-muted)]">
                {w.name}
              </div>
            )}
          </div>
        ),
      },
      {
        id: "role",
        header: "Granted Role",
        accessor: (w) => w.role,
        cell: (w) => (
          <Badge tone={roleBadgeTone(w.role)} mono>
            {w.role.toUpperCase()}
          </Badge>
        ),
      },
      {
        id: "code",
        header: "Teacher Code",
        accessor: (w) => w.teacher_code ?? "",
        cell: (w) => (
          <span className="font-mono-tabular text-[12.5px]">
            {w.teacher_code || "—"}
          </span>
        ),
      },
      {
        id: "dept",
        header: "Dept",
        accessor: (w) => w.department ?? "",
        cell: (w) => (
          <span className="font-mono-tabular text-[12.5px] text-[var(--ink-secondary)]">
            {w.department || "—"}
          </span>
        ),
      },
    ],
    [],
  );

  const whitelistBulkActions = useMemo<BulkActionItem[]>(
    () => [
      {
        id: "delete",
        label: "Remove Selected",
        tone: "destructive",
        disabled: deleteWhitelistMutation.isPending,
        onAction: (emails) => setDeleteWhitelistTarget(emails),
      },
    ],
    [deleteWhitelistMutation.isPending],
  );

  const activeCounts = tab === "directory" ? dirCounts : wlCounts;
  const roleChips: Array<{ id: RoleFilter; label: string; count: number }> = [
    { id: "all", label: "All", count: activeCounts.all },
    { id: "admin", label: "Admins", count: activeCounts.admin },
    { id: "teacher", label: "Teachers", count: activeCounts.teacher },
    { id: "student", label: "Students", count: activeCounts.student },
  ];

  const isOwnSelectedProfile =
    Boolean(selectedProfile) && selectedProfile?.id === ownProfile?.id;

  return (
    <div className="space-y-4">
      <header className="flex flex-wrap items-end justify-between gap-4 border-b border-[var(--border-subtle)] pb-4">
        <div>
          <h1 className="font-editorial text-[26px] font-semibold tracking-[-0.02em] text-[var(--ink-primary)]">
            Authorized Users &amp; Invites
          </h1>
          <p className="mt-1 max-w-[68ch] text-[13.5px] leading-[1.55] text-[var(--ink-secondary)]">
            Inspect active institutional accounts, manage pre-approved role
            whitelists, and send server-verified administrator invitations.
          </p>
        </div>

        <div className="flex flex-wrap items-center gap-2">
          <Button
            variant="primary"
            size="md"
            onClick={() => {
              inviteAdminMutation.reset();
              setInviteOpen(true);
            }}
          >
            <UserPlus size={15} aria-hidden="true" />
            <span>Invite Administrator</span>
          </Button>
          {tab === "whitelists" && (
            <Button
              variant="secondary"
              size="md"
              onClick={() => openWhitelistInspector("new")}
            >
              <Plus size={15} aria-hidden="true" />
              <span>Add Whitelist Entry</span>
            </Button>
          )}
        </div>
      </header>

      <div
        role="tablist"
        aria-label="User governance sections"
        className="flex flex-wrap gap-1.5 border-b border-[var(--border-subtle)] pb-3"
      >
        <button
          type="button"
          role="tab"
          aria-selected={tab === "directory"}
          onClick={() => setTab("directory")}
          className={cn(
            "inline-flex h-9 items-center gap-2 rounded-[var(--r-control)] border px-3 text-[13px] font-medium transition-colors",
            tab === "directory"
              ? "border-[var(--ink-primary)] bg-[var(--ink-primary)] text-[var(--bg-elevated)]"
              : "border-[var(--border-subtle)] bg-[var(--bg-elevated)] text-[var(--ink-secondary)] hover:bg-[var(--surface-hover)] hover:text-[var(--ink-primary)]",
          )}
        >
          <UsersThree size={15} aria-hidden="true" />
          <span>Directory ({dirCounts.all})</span>
        </button>
        <button
          type="button"
          role="tab"
          aria-selected={tab === "whitelists"}
          onClick={() => setTab("whitelists")}
          className={cn(
            "inline-flex h-9 items-center gap-2 rounded-[var(--r-control)] border px-3 text-[13px] font-medium transition-colors",
            tab === "whitelists"
              ? "border-[var(--ink-primary)] bg-[var(--ink-primary)] text-[var(--bg-elevated)]"
              : "border-[var(--border-subtle)] bg-[var(--bg-elevated)] text-[var(--ink-secondary)] hover:bg-[var(--surface-hover)] hover:text-[var(--ink-primary)]",
          )}
        >
          <EnvelopeSimple size={15} aria-hidden="true" />
          <span>Whitelists &amp; Invites ({wlCounts.all})</span>
        </button>
      </div>

      <div className="flex flex-wrap items-center justify-between gap-3">
        <div
          role="group"
          aria-label="Filter by role"
          className="flex flex-wrap items-center gap-1.5"
        >
          {roleChips.map((chip) => {
            const active = roleFilter === chip.id;
            return (
              <button
                key={chip.id}
                type="button"
                aria-pressed={active}
                onClick={() => setRoleFilter(chip.id)}
                className={cn(
                  "inline-flex h-[36px] items-center gap-1.5 rounded-[var(--r-control)] border px-3 font-mono-tabular text-[12px] transition-colors",
                  active
                    ? "border-[var(--accent-pine)] bg-[var(--accent-pine-soft)] font-semibold text-[var(--accent-pine)]"
                    : "border-[var(--border-control)] bg-[var(--bg-elevated)] text-[var(--ink-secondary)] hover:bg-[var(--surface-hover)]",
                )}
              >
                <span>{chip.label}</span>
                <span>({chip.count})</span>
              </button>
            );
          })}
        </div>

        <div className="relative w-full sm:w-[270px]">
          <MagnifyingGlass
            size={15}
            className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-[var(--ink-muted)]"
            aria-hidden="true"
          />
          <input
            ref={searchInputRef}
            type="search"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search name, email, ID... (/)"
            aria-label="Search users and whitelists"
            className="h-[36px] w-full rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] pl-8 pr-3 text-[13px] text-[var(--ink-primary)] placeholder:text-[var(--ink-muted)] focus:border-[var(--accent-pine)] focus:outline-none"
          />
        </div>
      </div>

      {tab === "directory" ? (
        <MasterDetailShell
          detailOpen={selectedProfile !== null}
          onRequestClose={() => setSelectedProfileId(null)}
          detailTitle={selectedProfile?.name || selectedProfile?.email || "Account"}
          detailSubtitle={selectedProfile?.email ?? ""}
          master={
            profilesLoading ? (
              <LedgerTableSkeleton label="Loading user directory" />
            ) : profilesError ? (
              <LedgerErrorRecovery
                title="Could not load user directory"
                message={
                  profilesErrObj instanceof Error
                    ? profilesErrObj.message
                    : "Supabase query failed."
                }
                onRetry={() => void refetchProfiles()}
              />
            ) : profiles.length === 0 ? (
              <LedgerEmptyState
                icon={<UsersThree size={20} aria-hidden="true" />}
                title="No registered user profiles yet"
                description="Invited administrators and onboarding faculty or student accounts appear here after their first sign-in."
              />
            ) : filteredProfiles.length === 0 ? (
              <LedgerFilterEmpty
                message="No user accounts match the active role filter or search."
                onReset={() => {
                  setSearch("");
                  setRoleFilter("all");
                }}
              />
            ) : (
              <DataLedgerTable
                data={filteredProfiles}
                columns={directoryColumns}
                getRowId={(p) => p.id}
                selectedRowId={selectedProfileId}
                onRowClick={(p) => setSelectedProfileId(p.id)}
                ariaLabel="Directory accounts ledger"
                renderRowActions={(p) => (
                  <button
                    type="button"
                    aria-label={`Inspect ${p.email}`}
                    onClick={() => setSelectedProfileId(p.id)}
                    className="flex h-7 w-7 items-center justify-center rounded-[5px] text-[var(--ink-secondary)] hover:bg-[var(--surface-hover)] hover:text-[var(--ink-primary)]"
                  >
                    <PencilSimple size={14} aria-hidden="true" />
                  </button>
                )}
              />
            )
          }
          detail={
            selectedProfile && (
              <div className="space-y-4">
                <div className="rounded-[var(--r-control)] border border-[var(--border-subtle)] bg-[var(--bg-canvas)]/60 p-3.5 text-[12.5px] space-y-1.5">
                  <div className="flex items-center justify-between gap-2">
                    <span className="text-[var(--ink-muted)]">Current Role</span>
                    <Badge tone={roleBadgeTone(selectedProfile.role)} mono>
                      {selectedProfile.role.toUpperCase()}
                    </Badge>
                  </div>
                  <div className="flex items-center justify-between gap-2">
                    <span className="text-[var(--ink-muted)]">Department</span>
                    <span className="font-mono-tabular text-[var(--ink-primary)]">
                      {selectedProfile.department ?? "—"}
                    </span>
                  </div>
                  <div className="flex items-center justify-between gap-2">
                    <span className="text-[var(--ink-muted)]">
                      Institutional Code / ID
                    </span>
                    <span className="font-mono-tabular text-[var(--ink-primary)]">
                      {selectedProfile.teacher_code ||
                        selectedProfile.student_id ||
                        "—"}
                    </span>
                  </div>
                </div>

                <div className="space-y-2">
                  <div className="text-[12.5px] font-semibold text-[var(--ink-primary)]">
                    Assign Account Role
                  </div>
                  {isOwnSelectedProfile && (
                    <div
                      role="status"
                      data-testid="self-demotion-guard-notice"
                      className="flex items-start gap-2 rounded-[var(--r-control)] border border-[var(--sem-joint-border)] bg-[var(--sem-joint-bg)] px-3 py-2 text-[12px] text-[var(--sem-joint-ink)]"
                    >
                      <ShieldWarning
                        size={15}
                        className="mt-0.5 shrink-0"
                        aria-hidden="true"
                      />
                      <span>
                        Self-demotion is disabled: you cannot downgrade your own
                        signed-in administrator role.
                      </span>
                    </div>
                  )}

                  <div className="grid grid-cols-3 gap-2">
                    {(["student", "teacher", "admin"] as const).map((role) => {
                      const active = selectedProfile.role === role;
                      const blockedSelf =
                        isOwnSelectedProfile && role !== "admin";
                      return (
                        <Button
                          key={role}
                          variant={active ? "primary" : "secondary"}
                          size="sm"
                          disabled={
                            active || blockedSelf || roleMutation.isPending
                          }
                          onClick={() => {
                            if (role === "admin") {
                              setPendingRoleEdit({
                                profile: selectedProfile,
                                nextRole: role,
                              });
                            } else {
                              roleMutation.mutate({
                                targetId: selectedProfile.id,
                                nextRole: role,
                              });
                            }
                          }}
                        >
                          {role.charAt(0).toUpperCase() + role.slice(1)}
                        </Button>
                      );
                    })}
                  </div>
                </div>
              </div>
            )
          }
        />
      ) : (
        <MasterDetailShell
          detailOpen={selectedWhitelistEmail !== null}
          onRequestClose={() => openWhitelistInspector(null)}
          detailTitle={
            selectedWhitelistEmail === "new"
              ? "Add Whitelist Entry"
              : selectedWhitelist?.email ?? "Whitelist Entry"
          }
          detailSubtitle="Pre-approved email & role mapping before first sign-in."
          master={
            whitelistsLoading ? (
              <LedgerTableSkeleton label="Loading whitelists" />
            ) : whitelistsError ? (
              <LedgerErrorRecovery
                title="Could not load whitelist entries"
                message={
                  whitelistsErrObj instanceof Error
                    ? whitelistsErrObj.message
                    : "Supabase query failed."
                }
                onRetry={() => void refetchWhitelists()}
              />
            ) : whitelists.length === 0 ? (
              <LedgerEmptyState
                icon={<EnvelopeSimple size={20} aria-hidden="true" />}
                title="No pre-approved whitelist entries yet"
                description="Add institutional faculty or administrator emails here before onboarding them into UniVerse."
                actionLabel="Add First Entry"
                onAction={() => openWhitelistInspector("new")}
              />
            ) : filteredWhitelists.length === 0 ? (
              <LedgerFilterEmpty
                message="No whitelist entries match your search or role filter."
                onReset={() => {
                  setSearch("");
                  setRoleFilter("all");
                }}
              />
            ) : (
              <DataLedgerTable
                data={filteredWhitelists}
                columns={whitelistColumns}
                getRowId={(w) => w.email}
                selectedRowId={selectedWhitelistEmail}
                onRowClick={(w) => openWhitelistInspector(w.email)}
                bulkActions={whitelistBulkActions}
                ariaLabel="Whitelisted institutional emails"
                renderRowActions={(w) => (
                  <>
                    <button
                      type="button"
                      aria-label={`Edit whitelist ${w.email}`}
                      onClick={(e) => {
                        e.stopPropagation();
                        openWhitelistInspector(w.email);
                      }}
                      className="flex h-7 w-7 items-center justify-center rounded-[5px] text-[var(--ink-secondary)] hover:bg-[var(--surface-hover)] hover:text-[var(--ink-primary)]"
                    >
                      <PencilSimple size={14} aria-hidden="true" />
                    </button>
                    <button
                      type="button"
                      aria-label={`Delete whitelist ${w.email}`}
                      onClick={(e) => {
                        e.stopPropagation();
                        setDeleteWhitelistTarget([w.email]);
                      }}
                      className="flex h-7 w-7 items-center justify-center rounded-[5px] text-[var(--sem-conflict-ink)] hover:bg-[var(--sem-conflict-bg)]"
                    >
                      <Trash size={14} aria-hidden="true" />
                    </button>
                  </>
                )}
              />
            )
          }
          detail={
            <form
              id="whitelist-inspector-form"
              onSubmit={wlForm.handleSubmit((vals) =>
                saveWhitelistMutation.mutate(vals),
              )}
              className="space-y-3.5"
              noValidate
            >
              <div>
                <label
                  htmlFor="wl-email"
                  className="mb-1 block text-[12.5px] font-medium text-[var(--ink-primary)]"
                >
                  Institutional Email
                </label>
                <input
                  id="wl-email"
                  type="email"
                  readOnly={selectedWhitelistEmail !== "new"}
                  placeholder="faculty@lus.ac.bd"
                  {...wlForm.register("email")}
                  className={cn(
                    "font-mono-tabular h-[38px] w-full rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-3 text-[13px]",
                    selectedWhitelistEmail !== "new" &&
                      "bg-[var(--bg-canvas)] text-[var(--ink-secondary)]",
                  )}
                />
                {wlForm.formState.errors.email && (
                  <p className="mt-1 text-[12px] text-[var(--sem-conflict-ink)]">
                    {wlForm.formState.errors.email.message}
                  </p>
                )}
              </div>

              <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
                <div>
                  <label
                    htmlFor="wl-role"
                    className="mb-1 block text-[12.5px] font-medium text-[var(--ink-primary)]"
                  >
                    Role
                  </label>
                  <select
                    id="wl-role"
                    {...wlForm.register("role")}
                    className="h-[38px] w-full rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-3 text-[13px]"
                  >
                    <option value="teacher">Teacher</option>
                    <option value="admin">Admin</option>
                    <option value="student">Student</option>
                  </select>
                </div>
                <div>
                  <label
                    htmlFor="wl-teacher-code"
                    className="mb-1 block text-[12.5px] font-medium text-[var(--ink-primary)]"
                  >
                    Teacher Code (optional)
                  </label>
                  <input
                    id="wl-teacher-code"
                    type="text"
                    placeholder="e.g. MHK"
                    {...wlForm.register("teacher_code")}
                    className="font-mono-tabular h-[38px] w-full rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-3 text-[13px] uppercase"
                  />
                </div>
              </div>

              <div>
                <label
                  htmlFor="wl-name"
                  className="mb-1 block text-[12.5px] font-medium text-[var(--ink-primary)]"
                >
                  Full Name (optional)
                </label>
                <input
                  id="wl-name"
                  type="text"
                  placeholder="Instructor or administrator name"
                  {...wlForm.register("name")}
                  className="h-[38px] w-full rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-3 text-[13px]"
                />
              </div>

              <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
                <div>
                  <label
                    htmlFor="wl-dept"
                    className="mb-1 block text-[12.5px] font-medium text-[var(--ink-primary)]"
                  >
                    Department
                  </label>
                  <input
                    id="wl-dept"
                    list="wl-dept-options"
                    {...wlForm.register("department")}
                    className="h-[38px] w-full rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-3 text-[13px]"
                  />
                  <datalist id="wl-dept-options">
                    {INSTITUTIONAL_DEPARTMENTS.map((d) => (
                      <option key={d} value={d} />
                    ))}
                  </datalist>
                </div>
                <div>
                  <label
                    htmlFor="wl-designation"
                    className="mb-1 block text-[12.5px] font-medium text-[var(--ink-primary)]"
                  >
                    Designation
                  </label>
                  <input
                    id="wl-designation"
                    list="wl-desig-options"
                    {...wlForm.register("designation")}
                    className="h-[38px] w-full rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-3 text-[13px]"
                  />
                  <datalist id="wl-desig-options">
                    {FACULTY_DESIGNATIONS.map((d) => (
                      <option key={d} value={d} />
                    ))}
                  </datalist>
                </div>
              </div>

              <div className="grid grid-cols-3 gap-2">
                <div>
                  <label
                    htmlFor="wl-batch"
                    className="mb-1 block text-[11.5px] font-medium text-[var(--ink-secondary)]"
                  >
                    Batch
                  </label>
                  <input
                    id="wl-batch"
                    type="text"
                    placeholder="60"
                    {...wlForm.register("batch")}
                    className="font-mono-tabular h-[36px] w-full rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-2.5 text-[12.5px]"
                  />
                </div>
                <div>
                  <label
                    htmlFor="wl-section"
                    className="mb-1 block text-[11.5px] font-medium text-[var(--ink-secondary)]"
                  >
                    Section
                  </label>
                  <input
                    id="wl-section"
                    type="text"
                    placeholder="A"
                    {...wlForm.register("section")}
                    className="font-mono-tabular h-[36px] w-full rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-2.5 text-[12.5px] uppercase"
                  />
                </div>
                <div>
                  <label
                    htmlFor="wl-semester"
                    className="mb-1 block text-[11.5px] font-medium text-[var(--ink-secondary)]"
                  >
                    Semester
                  </label>
                  <input
                    id="wl-semester"
                    type="text"
                    inputMode="numeric"
                    placeholder="1–12"
                    {...wlForm.register("semester")}
                    className="font-mono-tabular h-[36px] w-full rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-2.5 text-[12.5px]"
                  />
                </div>
              </div>

              {selectedWhitelist && (
                <div className="border-t border-[var(--border-subtle)] pt-2">
                  <Button
                    variant="ghost"
                    size="sm"
                    onClick={() =>
                      setDeleteWhitelistTarget([selectedWhitelist.email])
                    }
                    className="text-[var(--sem-conflict-ink)] hover:bg-[var(--sem-conflict-bg)]"
                  >
                    <Trash size={14} aria-hidden="true" />
                    <span>Remove Entry</span>
                  </Button>
                </div>
              )}

              <StickyDirtyBar
                isDirty={
                  wlForm.formState.isDirty || selectedWhitelistEmail === "new"
                }
                isSaving={saveWhitelistMutation.isPending}
                formId="whitelist-inspector-form"
                saveLabel={
                  selectedWhitelistEmail === "new"
                    ? "Save Entry"
                    : "Save Changes"
                }
                onDiscard={() => {
                  if (selectedWhitelistEmail === "new") {
                    openWhitelistInspector(null);
                  } else {
                    wlForm.reset(toWhitelistForm(selectedWhitelist));
                  }
                }}
              />
            </form>
          }
        />
      )}

      {/* Invite Administrator Modal */}
      <Dialog open={inviteOpen} onOpenChange={setInviteOpen}>
        <DialogContent className="fixed left-1/2 top-1/2 w-[calc(100%-32px)] max-w-[460px] -translate-x-1/2 -translate-y-1/2 p-5">
          <DialogTitle className="text-[17px] font-semibold text-[var(--ink-primary)]">
            Invite Administrator
          </DialogTitle>
          <DialogDescription className="mt-1 text-[13px] leading-[1.5] text-[var(--ink-secondary)]">
            Issues a server-verified administrator invite email via Edge Function{" "}
            <code className="font-mono-tabular">invite-admin</code> anchored to
            this web origin.
          </DialogDescription>

          <form
            onSubmit={inviteForm.handleSubmit((vals) =>
              inviteAdminMutation.mutate(vals),
            )}
            className="mt-4 space-y-3.5"
            noValidate
          >
            {inviteAdminMutation.isError && (
              <div
                role="alert"
                data-testid="invite-admin-error-alert"
                className="flex items-start gap-2 rounded-[var(--r-control)] border border-[var(--sem-conflict-border)] bg-[var(--sem-conflict-bg)] px-3 py-2.5 text-[12.5px] text-[var(--sem-conflict-ink)]"
              >
                <WarningCircle
                  size={16}
                  className="mt-0.5 shrink-0"
                  aria-hidden="true"
                />
                <span>
                  {inviteAdminMutation.error instanceof Error
                    ? inviteAdminMutation.error.message
                    : "Invitation request failed."}
                </span>
              </div>
            )}

            <div>
              <label
                htmlFor="invite-admin-name"
                className="mb-1 block text-[12.5px] font-medium text-[var(--ink-primary)]"
              >
                Full Name
              </label>
              <input
                id="invite-admin-name"
                type="text"
                placeholder="e.g. Dr. Farhana Rahman"
                {...inviteForm.register("name")}
                className="h-[38px] w-full rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-3 text-[13.5px]"
              />
              {inviteForm.formState.errors.name && (
                <p className="mt-1 text-[12px] text-[var(--sem-conflict-ink)]">
                  {inviteForm.formState.errors.name.message}
                </p>
              )}
            </div>

            <div>
              <label
                htmlFor="invite-admin-email"
                className="mb-1 block text-[12.5px] font-medium text-[var(--ink-primary)]"
              >
                Institutional Email
              </label>
              <input
                id="invite-admin-email"
                type="email"
                placeholder="committee@lus.ac.bd"
                {...inviteForm.register("email")}
                className="font-mono-tabular h-[38px] w-full rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-3 text-[13.5px]"
              />
              {inviteForm.formState.errors.email && (
                <p className="mt-1 text-[12px] text-[var(--sem-conflict-ink)]">
                  {inviteForm.formState.errors.email.message}
                </p>
              )}
            </div>

            <div className="flex justify-end gap-2 pt-2">
              <Button
                variant="secondary"
                size="md"
                onClick={() => setInviteOpen(false)}
                disabled={inviteAdminMutation.isPending}
              >
                Cancel
              </Button>
              <Button
                type="submit"
                variant="primary"
                size="md"
                disabled={inviteAdminMutation.isPending}
              >
                {inviteAdminMutation.isPending
                  ? "Sending Invite..."
                  : "Send Admin Invite"}
              </Button>
            </div>
          </form>
        </DialogContent>
      </Dialog>

      {/* Role Escalation Confirm Dialog */}
      <ConfirmDialog
        open={pendingRoleEdit !== null}
        onOpenChange={(open) => {
          if (!open) setPendingRoleEdit(null);
        }}
        title="Grant administrator privileges?"
        description={`Promoting ${pendingRoleEdit?.profile.email ?? ""} to Administrator grants full routine configuration, whitelist, and resource control.`}
        confirmLabel="Confirm Admin Promotion"
        tone="destructive"
        isPending={roleMutation.isPending}
        onConfirm={() => {
          if (pendingRoleEdit) {
            roleMutation.mutate({
              targetId: pendingRoleEdit.profile.id,
              nextRole: pendingRoleEdit.nextRole,
            });
          }
        }}
      />

      {/* Whitelist Delete Confirm Dialog */}
      <ConfirmDialog
        open={deleteWhitelistTarget !== null}
        onOpenChange={(open) => {
          if (!open) setDeleteWhitelistTarget(null);
        }}
        title={`Remove ${deleteWhitelistTarget?.length ?? 0} whitelist entry(ies)?`}
        description="Removed emails will no longer auto-provision on first sign-in."
        confirmLabel="Remove Entries"
        tone="destructive"
        isPending={deleteWhitelistMutation.isPending}
        onConfirm={() => {
          if (deleteWhitelistTarget) {
            deleteWhitelistMutation.mutate(deleteWhitelistTarget);
          }
        }}
      />
    </div>
  );
}
