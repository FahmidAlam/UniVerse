# Full Read-Only Supabase Audit & Drift Report (2026-11-27)

- **Production Project:** `yxqyrjyzxitrgkhgauli`
- **Staging Project:** `oqwvxplteqtlrhktsplj`
- **Audit Mode:** 100% Read-Only (`SELECT` / catalog queries, `list_edge_functions`, `get_edge_function`, `get_publishable_keys`, `get_advisors`, local repo inspection). Zero mutations performed.
- **Secret Handling:** Zero API keys, JWTs, webhook secret values, service account JSON, or user PII/emails are included.

---

## 1. Master Drift Matrix Table

| Area | Item | Repo Target | Production (`yxqyrjyzxitrgkhgauli`) | Staging (`oqwvxplteqtlrhktsplj`) | Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Schema (Audit 1)** | `public` & `academic_private` tables | 41 `public` tables (Layers 1–3 + Stage 5A/5C) | 41 `public` tables `[VERIFIED: Live MCP]` | 41 `public` tables `[VERIFIED: Live MCP]` | **CURRENT** |
| **Schema (Audit 1)** | Stage 5A Gate C tables & extended columns | `catalog_courses`, `section_policies`, `policy_snapshots`, `timetable_faculty` (+6 cols), `timetable_rooms` (+2 cols), `course_distribution_artifacts` (+6 cols) | Present & identical `[VERIFIED: Live MCP]` | Present & identical `[VERIFIED: Live MCP]` | **CURRENT** |
| **Schema (Audit 1)** | Stage 5C Gate D tables, columns & indexes | `solver_jobs`, `routines.teacher_codes` + GIN idx, `routine_versions` (+7 cols, `'rollback'` CHECK, scoped active uniq idx) | Present & identical `[VERIFIED: Live MCP]` | Present & identical `[VERIFIED: Live MCP]` | **CURRENT** |
| **Schema (Audit 1)** | Legacy tables (`timetable_courses`, `assignments`, `submissions`, `documents`) | Retained for Flutter Mobile compat (`AppConstants`) | Present with RLS enabled `[VERIFIED: Live MCP]` | Present with RLS enabled `[VERIFIED: Live MCP]` | **CURRENT** |
| **RPCs (Audit 2)** | `publish_routine` | Single 12-arg `SECURITY DEFINER`, `search_path=''`, `teacher_codes[]`, archiving | 12-arg `SECURITY DEFINER`, `search_path=""`, no old overload `[VERIFIED: Live MCP]` | 12-arg `SECURITY DEFINER`, `search_path=""`, no old overload `[VERIFIED: Live MCP]` | **CURRENT** |
| **RPCs (Audit 2)** | `restore_routine_version` & Gate C/B RPCs | `restore_routine_version`, `read_active_policy_snapshot`, `save_policy_snapshot`, `save_validation_report_artifact`, `append_course_distribution_correction`, `read_course_distribution_revision` | All present, `SECURITY DEFINER`, `search_path=""`, `authenticated` only `[VERIFIED: Live MCP]` | All present, `SECURITY DEFINER`, `search_path=""`, `authenticated` only `[VERIFIED: Live MCP]` | **CURRENT** |
| **RPCs (Audit 2)** | `guard_profile_role()` | Trigger fn, `SECURITY DEFINER`, `search_path=''`, no `anon`/`PUBLIC` grant | `search_path=""`, **granted to `PUBLIC` & `anon`** `[VERIFIED: Live MCP]` | `search_path=""`, **granted to `anon`** `[VERIFIED: Live MCP]` | **DRIFT** |
| **RPCs (Audit 2)** | `match_documents()` & `calculate_is_late()` | `search_path=''`, no `anon`/`PUBLIC` grant on `match_documents` | `search_path` **NULL**, **granted to `PUBLIC` & `anon`** `[VERIFIED: Live MCP]` | `search_path` **NULL**, **granted to `anon`** `[VERIFIED: Live MCP]` | **DRIFT** |
| **RLS (Audit 3)** | RLS enabled on all `public` tables | `rowsecurity = true` on all 41 tables | 41/41 enabled `[VERIFIED: Live MCP]` | 41/41 enabled `[VERIFIED: Live MCP]` | **CURRENT** |
| **RLS (Audit 3)** | `profiles_select` & mobile compat policies | `id = auth.uid() OR is_admin()`; mobile read/write preserved | Enforced & identical `[VERIFIED: Live MCP]` | Enforced & identical `[VERIFIED: Live MCP]` | **CURRENT** |
| **RLS (Audit 3)** | Legacy `anon` table grants & `TO public` policies | Least privilege (`authenticated` only) | 13 legacy tables have `anon` grants; `device_tokens`, `notification_reads`, `timetable_course_eligibility` have `TO public` policies `[VERIFIED: Live MCP]` | Same 13 tables + 3 policy sets `[VERIFIED: Live MCP]` | **DRIFT** |
| **Storage (Audit 4)** | `storage.objects` policies | 13 scoped Phase 5B policies, 0 wildcards | 13/13 scoped policies, 0 wildcards `[VERIFIED: Live MCP]` | 13/13 scoped policies, 0 wildcards `[VERIFIED: Live MCP]` | **CURRENT** |
| **Storage (Audit 4)** | `storage.buckets` size & MIME limits | Size & MIME limits on all 4 buckets | `avatars`, `resources`, `timetables` set; **`assignments` `allowed_mime_types: null`** `[VERIFIED: Live MCP]` | **All 4 buckets have `null` size & MIME limits** `[VERIFIED: Live MCP]` | **DRIFT** |
| **Edge Fn (Audit 5)** | `send-push` | Multi-file (`index.ts`, `webhook_auth.js`, `audience.js`), `verify_jwt: false`, `x-webhook-secret` + `B+C` split | **v3 single-file `index.ts`** (`verify_jwt: false`), **no `protectWebhook`**, **no `B+C` split** `[VERIFIED: Live MCP]` | **MISSING** (`send-push-auth-test` & `send-push-audience-test` only) `[VERIFIED: Live MCP]` | **OUTDATED / MISSING** |
| **Edge Fn (Audit 5)** | `invite-admin` | Multi-file (`index.ts`, `callback_policy.js`, `handler.js`), `verify_jwt: true`, `AUTH_WEB_CALLBACK_URLS` | **v3 single-file `index.ts`** (`verify_jwt: true`), hardcoded `com.example.universe_v1://reset-callback/` `[VERIFIED: Live MCP]` | **MISSING** (`invite-admin-auth-test` only, `verify_jwt: false`) `[VERIFIED: Live MCP]` | **OUTDATED / MISSING** |
| **Edge Fn (Audit 5)** | Stale test slugs | None in Prod; clean Staging | None `[VERIFIED: Live MCP]` | 3 stale test slugs (`send-push-auth-test`, `send-push-audience-test`, `invite-admin-auth-test`) `[VERIFIED: Live MCP]` | **DRIFT** |
| **Webhooks (Audit 6)** | `send_push_on_notification` trigger | Sends `x-webhook-secret`, no legacy `eyJ...` Bearer JWT | Enabled (`O`), **missing `x-webhook-secret`**, sends **legacy `Authorization: Bearer eyJ...`** `[VERIFIED: Live MCP]` | Absent (intentional Staging isolation) `[VERIFIED: Live MCP]` | **OUTDATED (P0)** |
| **Realtime & Ext (Audit 6)** | `supabase_realtime` & extensions | Only `public.cancellations`; `pgcrypto`, `vector`, `pg_net` (Prod) | `cancellations` only; `pg_net 0.20.0`, `vector 0.8.0` (`public`) `[VERIFIED: Live MCP]` | `cancellations` only; `pgtap 1.3.3`, `vector 0.8.2` (`public`) `[VERIFIED: Live MCP]` | **CURRENT** |
| **Advisors (Audit 7)** | Security & Performance Advisors | Zero `WARN`s where avoidable | 5 Security `WARN` types; 2 Perf `WARN` types (`auth_rls_initplan` 26, `multiple_permissive_policies` 29) `[VERIFIED: Live MCP]` | Identical Security & Perf `WARN`s `[VERIFIED: Live MCP]` | **DRIFT** |
| **Keys (Audit 7)** | 2027 `sb_publishable_` + legacy JWT | `sb_publishable_` active; legacy JWT kept until APK ships | Both active (`disabled: false`) `[VERIFIED: Live MCP]` | Both active (`disabled: false`) `[VERIFIED: Live MCP]` | **CURRENT** |
| **Data (Audit 8)** | Catalogs, snapshots, jobs, routines | Clean Prod data; no leftover Staging test rows | 796 active routines (0 empty `teacher_codes`), 54 `catalog_courses`, 66 `section_policies`, 0 `policy_snapshots`, 0 `solver_jobs` `[VERIFIED: Live MCP]` | 4 active routines, 1 `policy_snapshots`, **1 leftover test `solver_jobs` (`5826a8fa394b`)** `[VERIFIED: Live MCP]` | **DRIFT** |

---

## 2. Every Old or Broken Item Grouped by Priority

### P0 — Security & Breaking Risks
1. **Production `send-push` Edge Function is unauthenticated & outdated (v3 single-file `index.ts`)** `[VERIFIED: Live MCP]`
   - Missing `webhook_auth.js` (`protectWebhook` requiring `x-webhook-secret`) — currently anyone who knows the URL can POST a forged `record` payload because `verify_jwt` is `false`.
   - Missing `audience.js` (`B+C` joint-section split), so broadcasts targeting combined sections like `B+C` match zero profiles.
2. **Production `send_push_on_notification` DB Webhook lacks `x-webhook-secret` & embeds a legacy `eyJ...` JWT** `[VERIFIED: Live MCP]`
   - Deploying the repo's `send-push` *without* simultaneously updating this trigger to send `x-webhook-secret` (and setting `PUSH_WEBHOOK_SECRET` in Edge Function Secrets) will break all live push notifications with `401`/`503`.
   - The embedded `Authorization: Bearer eyJ...` header will also break when legacy JWT keys are retired in 2027.
3. **Production `invite-admin` Edge Function is outdated (v3 single-file `index.ts`)** `[VERIFIED: Live MCP]`
   - Missing `callback_policy.js` and `handler.js`.
   - Does not read `AUTH_WEB_CALLBACK_URLS`, so React Web admin invitations cannot redirect to `https://universe-admin-exi.pages.dev/` or `http://localhost:5173/`.
   - Hardcodes `redirectTo: 'com.example.universe_v1://reset-callback/'` (contains `_v1` mismatch vs. repo `com.example.universe://reset-callback/`).
4. **Security Advisor `WARN`s on both Production and Staging:** `[VERIFIED: Live MCP]`
   - `anon_security_definer_function_executable` (1): `public.guard_profile_role()` is `SECURITY DEFINER` and callable by `anon` / `PUBLIC`.
   - `function_search_path_mutable` (2): `public.match_documents(vector, integer)` and `public.calculate_is_late()` have `search_path` unset (`NULL`), and `match_documents` is callable by `anon` / `PUBLIC`.
   - `auth_leaked_password_protection` (1): Disabled in Supabase Auth on both projects.

### P1 — Missing Stage 5C / Gate D Schema & RPC Promotions
- **None.** `[VERIFIED: Live MCP]`
  All Stage 5A (`20261127120000`) and Stage 5C (`20261127180000`) tables, columns, indexes, CHECK constraints, and RPCs (`publish_routine` 12-arg archiving `SECURITY DEFINER`, `restore_routine_version`, `solver_jobs`, `routines.teacher_codes` + GIN index) are **already promoted and identical** on both Production and Staging.

### P2 — Staging Parity & Data Hygiene
1. **Staging Edge Functions missing canonical slugs + 3 stale test slugs:** `[VERIFIED: Live MCP]`
   - `send-push` and `invite-admin` are not deployed on Staging; only `send-push-auth-test`, `send-push-audience-test`, and `invite-admin-auth-test` exist.
2. **Storage Bucket Limits Drift:** `[VERIFIED: Live MCP]`
   - **Staging:** All 4 buckets (`assignments`, `avatars`, `resources`, `timetables`) have `file_size_limit: null` and `allowed_mime_types: null`.
   - **Production:** `assignments` bucket has `allowed_mime_types: null`.
3. **Staging Data Hygiene:** `[VERIFIED: Live MCP]`
   - 1 leftover synthetic test row in `public.solver_jobs` (`job_id = '5826a8fa394b'`, `state = 'done'`, `outcome = 'OPTIMAL'`).
4. **Production `routine_versions.snapshot_rows`:** `[VERIFIED: Live MCP]`
   - The active `routine_versions` row on Production has `snapshot_rows IS NULL` (`with_snapshot_rows = 0` of 6). Safe for future publishes/rollbacks (the RPC backfills outgoing active rows dynamically), but older historical versions without `snapshot_rows` cannot be rolled back unless their `routines` rows still exist.

### P3 — Performance Advisors & 2027 Key / Cleanup Items
1. **Legacy `anon` Table Grants & `TO public` RLS Policies (Prod & Staging):** `[VERIFIED: Live MCP]`
   - 13 legacy tables still have `anon` table privileges (mitigated by `authenticated` RLS policies, except `device_tokens`, `notification_reads`, and `timetable_course_eligibility` `admin_write` which use `TO public`).
2. **Performance Advisor `WARN`s (Prod & Staging):** `[VERIFIED: Live MCP]`
   - `auth_rls_initplan` (26): Legacy policies calling `auth.uid()` / `auth.jwt()` without `(select auth.uid())`.
   - `multiple_permissive_policies` (29): Tables with both a `FOR SELECT` policy and a `FOR ALL` admin write policy for `authenticated`.
   - `extension_in_public` (1): `vector` extension in `public` schema (`0.8.0` Prod, `0.8.2` Staging).
   - `unindexed_foreign_keys` (30 `INFO`) and `unused_index` (33 Prod / 36 Staging `INFO`).
3. **2027 Key Readiness:** `[VERIFIED: Live MCP]`
   - `sb_publishable_...` keys are active on both projects and wired into `lib/core/constants/app_constants.dart`, `engine/auth.py`, and `.github/workflows/supabase_keep_alive.yml`. Keep legacy JWT keys enabled until a new Flutter APK ships and `send_push_on_notification` drops its legacy JWT header.

---

## 3. Single Ordered "Fix-All" Action Plan

1. **Dashboard — Edge Function Secrets (Owner, 60s):**
   - On **Production** (`yxqyrjyzxitrgkhgauli`) and **Staging** (`oqwvxplteqtlrhktsplj`), set:
     - `PUSH_WEBHOOK_SECRET` (high-entropy random string, e.g. 32+ bytes hex).
     - `AUTH_WEB_CALLBACK_URLS`:
       - Prod: `https://universe-admin-exi.pages.dev/` (plus `http://localhost:5173/` if local testing against Prod is needed).
       - Staging: `https://universe-bfi.pages.dev/,http://localhost:5173/`
     - Confirm `FCM_SERVICE_ACCOUNT` is set on Production.
2. **Deploy Multi-File Edge Functions (Antigravity via `deploy_edge_function` once authorized, or Owner):**
   - Deploy `send-push` (`verify_jwt: false`) with `index.ts`, `webhook_auth.js`, `audience.js` to **Staging** first, then **Production**.
   - Deploy `invite-admin` (`verify_jwt: true`) with `index.ts`, `callback_policy.js`, `handler.js` to **Staging** first, then **Production**.
   - Delete stale test slugs on Staging (`send-push-auth-test`, `send-push-audience-test`, `invite-admin-auth-test`).
3. **Dashboard — Update Production DB Webhook `send_push_on_notification` (Owner):**
   - Immediately after `send-push` is deployed on Production, edit `notifications` → `send_push_on_notification` in **Database → Webhooks**:
     - Add header `x-webhook-secret: <exact PUSH_WEBHOOK_SECRET>`.
     - Remove the legacy `Authorization: Bearer eyJ...` header.
4. **SQL Editor — Security & Storage Hygiene Patch (Antigravity can draft/run once authorized, Staging → Prod):**
   - Lock down `guard_profile_role()`, `calculate_is_late()`, and `match_documents()`:
     - `ALTER FUNCTION public.calculate_is_late() SET search_path = '';`
     - `ALTER FUNCTION public.match_documents(vector, integer) SET search_path = '';`
     - `REVOKE ALL ON FUNCTION public.guard_profile_role() FROM PUBLIC, anon, authenticated;`
     - `REVOKE ALL ON FUNCTION public.calculate_is_late() FROM PUBLIC, anon, authenticated;`
     - `REVOKE ALL ON FUNCTION public.match_documents(vector, integer) FROM PUBLIC, anon;` (keep `authenticated`).
   - Sync `storage.buckets` limits on **Staging** (`assignments`, `avatars`, `resources`, `timetables`) to match Production, and add `allowed_mime_types` to `assignments` on both if desired.
   - Delete synthetic test row `solver_jobs` `job_id = '5826a8fa394b'` on **Staging**.
   - *(Optional P3)*: Wrap `auth.uid()`/`auth.jwt()` in `(select ...)` on legacy RLS policies and revoke unused `anon` table grants.
5. **Dashboard — Auth Hardening (Owner, 30s):**
   - Enable **Leaked Password Protection** (HaveIBeenPwned) under **Authentication → Providers / Password Security** on both Production and Staging.
6. **Verification Probes (Antigravity, Read-Only):**
   - Re-run `get_advisors` (`security`) on both projects to confirm `anon_security_definer_function_executable`, `function_search_path_mutable`, and `auth_leaked_password_protection` are cleared.
   - Verify `send-push` rejects unauthenticated requests (`401`) and accepts `x-webhook-secret`, and verify `invite-admin` accepts `AUTH_WEB_CALLBACK_URLS`.

---

## 4. 60-Second `[UNVERIFIED: Dashboard-Only]` Owner Checklist

MCP/SQL cannot inspect these Dashboard-only settings; please verify manually on **both** `yxqyrjyzxitrgkhgauli` (Prod) and `oqwvxplteqtlrhktsplj` (Staging):

- [ ] **Edge Functions → Secrets:**
  - `PUSH_WEBHOOK_SECRET` present and high-entropy? `[UNVERIFIED: Dashboard-Only]`
  - `FCM_SERVICE_ACCOUNT` present on Production (valid Firebase service account JSON)? `[UNVERIFIED: Dashboard-Only]`
  - `AUTH_WEB_CALLBACK_URLS` exact match including trailing slashes (`https://universe-admin-exi.pages.dev/`, `https://universe-bfi.pages.dev/`, `http://localhost:5173/`)? `[UNVERIFIED: Dashboard-Only]`
- [ ] **Authentication → URL Configuration:**
  - **Site URL** set to `https://universe-admin-exi.pages.dev/` (Prod) / `https://universe-bfi.pages.dev/` (Staging)? `[UNVERIFIED: Dashboard-Only]`
  - **Redirect URLs** include `https://universe-admin-exi.pages.dev/`, `https://universe-bfi.pages.dev/`, `http://localhost:5173/`, `com.example.universe://login-callback/`, and `com.example.universe://reset-callback/`? `[UNVERIFIED: Dashboard-Only]`
- [ ] **Authentication → Password Security:**
  - **Leaked Password Protection** toggled ON? `[VERIFIED: Live MCP — currently OFF]`
- [ ] **Project Settings → API Keys:**
  - Legacy `anon` / `service_role` JWT keys kept **enabled** until a new Flutter APK ships? `[VERIFIED: Live MCP — currently enabled]`
