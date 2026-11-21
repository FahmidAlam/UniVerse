# UniVerse — Phase 0 Compatibility Matrix, Audit Addendum & SQL Diagnostic Packet

> **Document Role:** Phase 0 Readiness Addendum supporting [`WEB_ARCHITECTURE_DESIGN_BLUEPRINT.md`](WEB_ARCHITECTURE_DESIGN_BLUEPRINT.md), [`WEB_SOURCE_VERIFICATION_REPORT.md`](WEB_SOURCE_VERIFICATION_REPORT.md), and [`WEB_IMPLEMENTATION_ROADMAP.md`](WEB_IMPLEMENTATION_ROADMAP.md).
> **Verification Date:** 21 November 2026
> **Safety Status:** Strictly read-only inspection (`npm view` metadata lookup, local source reads, zero package installs, zero Supabase CLI calls, zero live database writes, zero secrets exposed).

---

## 1. Live npm Registry Compatibility Matrix (`npm view`)

Inspected live via `npm view <pkg> version dist-tags peerDependencies --json` against [`apps/web/package.json`](../../apps/web/package.json) and resolved versions in [`apps/web/package-lock.json`](../../apps/web/package-lock.json). **No packages were installed or updated in Phase 0.**

### 1.1 Currently Installed Core Packages (`apps/web/`)

| Package | `package.json` Spec | Lockfile / Latest (`npm view`) | React 19 Peer Compatibility | Notes |
|---|---|---|---|---|
| `react` / `react-dom` | `^19.1.0` | `19.3.1` (`latest`; `backport: 19.1.10`) | Baseline React 19 | Core target matches strategic direction (`React 19`). |
| `vite` | `^6.3.5` | `6.4.6` (`previous`; `latest: 8.3.8`) | N/A (`@types/node@^26.6.6` present) | Stay on Vite `6.4.x` initially; tighten range to `^6.4.0` if pairing with Vitest v5 (see §1.2). |
| `tailwindcss` / `@tailwindcss/vite` | `^4.1.8` | `4.3.5` (`latest`) | N/A (`vite: ^5.2.0 \|\| ^6 \|\| ^7 \|\| ^8`) | Matches Tailwind v4 + native OKLCH CSS token architecture. |
| `react-router-dom` | `^7.6.2` | `7.18.6` (`latest`) | `react: >=18`, `react-dom: >=18` | Compatible with React 19 (`React Router v7`). |
| `@tanstack/react-query` | `^5.80.7` | `5.108.2` (`latest`) | `react: ^18 \|\| ^19` | Compatible with React 19 (`TanStack Query v5`). |
| `@phosphor-icons/react` | `^2.1.7` | `2.1.10` (`latest`) | `react: >= 16.8`, `react-dom: >= 16.8` | Compatible; sole approved icon library (no Lucide). |
| `framer-motion` *(legacy)* | `^12.16.0` | `12.43.0` locked (`14.14.0` latest) | `react: ^18.0.0 \|\| ^19.0.0` | Overlapping with `motion` (`14.14.0`); consolidate to single package (`motion`) in Phase 1A (`apps/web/`). |
| `@radix-ui/react-switch` *(unused)* | `^1.2.5` | Unused in `apps/web/src/` | React 19 compatible | Remove or fold into unified `radix-ui` / `shadcn/ui` primitives during Phase 1A cleanup. |

### 1.2 Proposed Target Packages for Phase 1–4 Adoption

| Category | Candidate Package | Verified Version (`npm view`) | Verified React / Vite Peer Dependencies | Stability & Compatibility Assessment | Phase 0 Recommendation |
|---|---|---|---|---|---|
| **Animation** | `motion` | `14.14.0` (`latest`) | `react: ^18.0.0 \|\| ^19.0.0`, `react-dom: ^18.0.0 \|\| ^19.0.0` | Identical v14 release line and peer deps as `framer-motion@14.14.0`. | Adopt `motion` (`motion/react`) in Phase 1A and **remove `framer-motion`** so zero duplicate animation libraries exist. |
| **UI Primitives** | `shadcn` + `radix-ui` | `shadcn@4.23.0`, `radix-ui@1.8.1` | `radix-ui`: `react: ^16.8 \|\| ... \|\| ^19.0` | Unified `radix-ui` (or modular `@radix-ui/react-*`) supports React 19; `shadcn` defaults many component templates to `lucide-react`. | Adopt `shadcn/ui` patterns backed by `radix-ui` (or existing `@radix-ui/react-*`), explicitly mapping icons strictly to `@phosphor-icons/react` (zero Lucide). |
| **Searchable Inputs** | `cmdk` | `1.1.1` (`latest`) | `react: ^18 \|\| ^19`, `react-dom: ^18 \|\| ^19` | Stable v1 release explicitly declaring React 19 peers. | Safe to adopt in Phase 2 (`cmdk@^1.1.1`) for dense course/faculty/room comboboxes. |
| **Tables** | `@tanstack/react-table` | **`9.3.1`** (`latest`) vs. `8.21.3` (`8.x`) | v9: `react: >=18`; v8: `react: >=16.8` | `@tanstack/react-table` v9 IS published on the `latest` npm dist-tag (`9.3.1`, React 18/19 compatible). Note v9 changed table APIs vs. v8 (`8.21.3` LTS). | Adopt `9.3.1` matching strategic target in Phase 2/4B, auditing API migration against Phase 4 `CD1` requirements before locking; keep `8.21.3` as documented fallback only if breaking ecosystem gaps emerge. |
| **Virtualization** | `@tanstack/react-virtual` | `3.14.26` (`latest`) | `react: ^16.8..^19.0`, `react-dom: ^16.8..^19.0` | Stable v3 explicitly declaring React 19 peers. | Safe to pair with `@tanstack/react-table` in Phase 4B. |
| **Charts** | `recharts` + `react-is` | `recharts@3.11.0` (`latest`), `react-is@19.3.1` | `react: ^16.8..^19.0`, **`react-is: ^16.8..^19.0`**, `react-dom: ^16.0..^19.0` | Stable v3 supports React 19, **but declares a required `react-is` peer dependency matching React 19** (`react-is` is NOT currently in `apps/web/package.json`). | Adopt `recharts@^3.11.0` in Phase 2 **only alongside explicit `react-is@^19.3.1`** (and enforce explicit axes, flat bar tops, sibling-bar hover dimming). |
| **Forms & Validation** | `react-hook-form` + `zod` + `@hookform/resolvers` | `rhf@7.92.0`, `zod@4.6.7`, `resolvers@7.0.8` | `rhf`: `react: ^16.8..\|\| ^19`; `resolvers`: `zod: ^3.25.0 \|\| ^4.0.0`, `rhf: ^7.55.0` | Latest `@hookform/resolvers@7.0.8` natively supports Zod v4 (`4.6.7`) and `react-hook-form@7.92.0`. | Safe to adopt `react-hook-form@^7.92.0` + `zod@^4.6.7` + `@hookform/resolvers@^7.0.8` in Phase 1/2. |
| **Client State** | `zustand` | `5.1.0` (`latest`) | `react: >=18.0.0`, `@types/react: >=18.0.0`, `use-sync-external-store: >=1.2.0` | Stable v5 compatible with React 19 (note optional `immer` peer only if middleware used). | Safe to adopt `zustand@^5.1.0` in Phase 1/2. |
| **Unit / E2E Testing** | `vitest` + `@playwright/test` | `vitest@5.1.1` (`latest`) vs. `V4: 4.1.12`; `playwright@1.65.1` | `vitest@5.1.1`: `vite: ^6.4.0 \|\| ^7 \|\| ^8`, `@types/node: ^22 \|\| >=24`; `vitest@4.1.12`: `vite: ^6.0.0 \|\| ^7 \|\| ^8` | `apps/web/package.json` allows `vite@^6.3.5` (lockfile already resolves `6.4.6`) and `@types/node@^26.6.6`. Both `vitest@4.1.12` and `5.1.1` work with locked `vite@6.4.6`; updating `package.json` `vite` to `^6.4.6` avoids peer warning if choosing Vitest v5. | Prefer `vitest@^4.1.12` (zero range adjustment needed for `^6.3.5`) or bump `vite` floor to `^6.4.6` with `vitest@^5.1.1`, plus `@playwright/test@^1.65.1` in Phase 1A. |
| **Spreadsheet Parsing (`xlsx` / `exceljs`)** | *(Not recommended for Phase 1–3 default)* | `xlsx@0.18.5`, `exceljs@4.4.0` | Framework-agnostic | Client-side parsing of rendered `.xlsx` is **not required** under the provisional FastAPI parse endpoint preference (`F-24`). | Do **not** install client-side Excel libraries unless owner explicitly rejects the additive FastAPI parse endpoint in Phase 3B. |

---

## 2. Phase 0 Targeted Read-Only Codebase Audit Summary (`F-29` – `F-31`)

Full findings and file citations appear in [`WEB_SOURCE_VERIFICATION_REPORT.md`](WEB_SOURCE_VERIFICATION_REPORT.md) §14:

1. **`F-29` — `supabase/functions/send-push/` (`index.ts`, `audience.js`, `webhook_auth.js`):**
   - Uses `SUPABASE_SERVICE_ROLE_KEY` via `createClient(url, serviceKey)` (`index.ts:126-128`), which **bypasses RLS** when querying `profiles.select('id')` and `device_tokens` (`audience.js:3-22`) or deleting stale tokens (`index.ts:170`).
   - Protected by `protectWebhook` checking `x-webhook-secret == PUSH_WEBHOOK_SECRET`, while `index.ts:1-6` flags `"TEST-ONLY AUTHORIZATION CHANGE - NOT DEPLOYED"`.
   - **Implication:** Tightening `profiles_select` RLS in Phase 5B (`id = auth.uid() or public.is_admin()`) will **not** break `send-push`. Live deployment and DB webhook triggers remain `NOT VERIFIED`.
2. **`F-30` — Flutter Avatar Storage (`lib/features/profile/`, `lib/shared/widgets/`, `lib/features/auth/services/auth_service.dart`):**
   - Although `AppConstants.bucketAvatars = 'avatars'` is defined (`app_constants.dart:123`), **zero Dart code uploads or mutates files in the `avatars` bucket**.
   - Local avatar customization uses 8 Phosphor icon presets stored in `SharedPreferences` (`'avatar_preset_$userId'`), while `profiles.avatar_url` is copied only from Google OAuth `user.userMetadata?['avatar_url']` (`auth_service.dart:241,283,327`) and displayed via `CachedNetworkImage`.
   - **Implication:** Scoping `storage.objects` write policies by bucket in Phase 5B (eliminating `006_enable_rls_all_tables.sql:278-288` wildcard `using (true)` writes across `timetables`, `resources`, `avatars`) breaks **zero existing Flutter features**.
3. **`F-31` — iOS Baseline (`ios/Runner/Info.plist`, `AuthCallbackPolicy`, `AuthService`):**
   - `ios/Runner/Info.plist:50-63` sets `FlutterDeepLinkingEnabled = false` and registers `CFBundleURLSchemes`: **`io.supabase.universe`** and **`com.example.universe`**, matching `AuthCallbackPolicy` (`com.example.universe://login-callback/` and `com.example.universe://reset-callback/`).
   - **Unresolved Dependencies:** `Info.plist` lacks `GIDClientID` and a reversed `com.googleusercontent.apps.*` URL scheme, and `AuthService` omits an iOS Google OAuth `clientId`. Do **not** modify `ios/` in Phase 0; maintain callback/scheme compatibility across both Android and iOS continuously.

---

## 3. Owner-Ready Copy-Pasteable Read-Only SQL Diagnostic Packet

### 3.1 Execution Governance & Quarantine Rules

| Target Supabase Project | Safety Classification | Permitted Action Now | Notes |
|---|---|---|---|
| **Production (`yxqyrjyzxitrgkhgauli`)** | **READ-ONLY** | Read-only SQL inspection complete (§4). | No React Web dev writes, test CRUD, or migrations permitted. |
| **Staging (`oqwvxplteqtlrhktsplj`)** | **Quarantine Lifted → Owner-Approved Non-Prod Staging** | Owner audited via SQL Packet §3.2 (§4 confirmed `37` tables, `0` rows everywhere, zero `send-push` webhooks). | Approved exclusively as non-production staging target (requires Supabase Auth Redirect URLs & `AUTH_WEB_CALLBACK_URLS` check before Phase 1B live Auth tests). |

### 3.2 Read-Only SQL Script (Supabase Dashboard → SQL Editor)

> **Usage:** Copy the entire query below into **Supabase Dashboard → SQL Editor**, click **Run** separately on production (`yxqyrjyzxitrgkhgauli`) and (for read-only ownership/schema inspection only) on secondary (`oqwvxplteqtlrhktsplj`), and share each resulting JSON cell back.
> **Safety Guarantees:**
> - **100% Read-Only:** Contains zero `INSERT`, `UPDATE`, `DELETE`, `CREATE`, `ALTER`, `DROP`, or `GRANT` statements.
> - **Missing-Table Safe:** Uses `to_regclass(...)` guards and `pg_catalog` metadata so older/minimal schemas never throw `relation does not exist` errors.
> - **Zero Secret / PII Exposure:** Never queries `auth.users`, `device_tokens`, `whitelists` emails, `profiles` rows, webhook `tgargs`/secret headers, or storage object file paths/contents (`supabase/reconciliation/storage_realtime_inventory.sql` pattern extended cleanly).

```sql
-- READ-ONLY PHASE 0 DIAGNOSTIC PACKET
-- Safe for Supabase Dashboard -> SQL Editor (Production Read-Only & Quarantined Secondary Audit).
-- Returns ONE jsonb_pretty cell. Exposes zero secrets, tokens, webhook auth headers, emails, or user rows.

select jsonb_pretty(jsonb_build_object(

  -- 1. Database Identity & Environment Indicators
  'environment_identity', jsonb_build_object(
    'database_name', current_database(),
    'current_user', current_user,
    'session_user', session_user,
    'timezone', current_setting('TimeZone'),
    'postgres_version', version(),
    'search_path', current_setting('search_path'),
    'schemas_present', (
      select coalesce(jsonb_agg(schema_name order by schema_name), '[]'::jsonb)
      from information_schema.schemata
      where schema_name in ('public', 'auth', 'storage', 'realtime', 'supabase_migrations', 'supabase_functions', 'extensions', 'academic_private')
    ),
    'installed_extensions', (
      select coalesce(jsonb_agg(jsonb_build_object('name', extname, 'version', extversion) order by extname), '[]'::jsonb)
      from pg_extension
    )
  ),

  -- 2. Public & Target Table Existence + RLS Enablement
  'public_tables', (
    select coalesce(jsonb_agg(jsonb_build_object(
      'table', c.relname,
      'rls_enabled', c.relrowsecurity,
      'force_rls', c.relforcerowsecurity,
      'policy_count', (select count(*) from pg_policies p where p.schemaname = 'public' and p.tablename = c.relname),
      'est_rows', greatest(c.reltuples::bigint, 0)
    ) order by c.relname), '[]'::jsonb)
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind in ('r', 'p')
  ),

  -- 3. Expected Phase 1-4 & Catalog/Distribution Table Presence Matrix
  'expected_tables_presence', (
    select jsonb_object_agg(t.name, to_regclass('public.' || t.name) is not null)
    from (values
      ('profiles'), ('whitelists'), ('routines'), ('routine_versions'), ('timetable_runs'),
      ('timetable_rooms'), ('timetable_faculty'), ('timetable_settings'), ('timetable_course_eligibility'),
      ('timetable_courses'), ('notifications'), ('notification_reads'), ('cancellations'),
      ('resources'), ('device_tokens'), ('departments'), ('cohorts'), ('student_groups'),
      ('course_distribution_sources'), ('course_distribution_revisions'),
      ('course_distribution_corrections'), ('course_distribution_artifacts')
    ) as t(name)
  ),

  -- 4. Exact Column Inventory for Key Baseline, Catalog & Distribution Tables
  'key_table_columns', (
    select coalesce(jsonb_agg(jsonb_build_object(
      'table', table_name,
      'column', column_name,
      'data_type', udt_name,
      'nullable', is_nullable,
      'default', column_default
    ) order by table_name, ordinal_position), '[]'::jsonb)
    from information_schema.columns
    where table_schema = 'public'
      and table_name in (
        'profiles', 'whitelists', 'routines', 'routine_versions', 'timetable_runs',
        'timetable_rooms', 'timetable_faculty', 'timetable_settings', 'timetable_course_eligibility',
        'timetable_courses', 'notifications', 'cancellations', 'resources',
        'departments', 'cohorts', 'student_groups',
        'course_distribution_sources', 'course_distribution_revisions',
        'course_distribution_corrections', 'course_distribution_artifacts'
      )
  ),

  -- 5. Migration History (Safely checked via to_regclass; strips bulky SQL statement bodies)
  'migration_history', case
    when to_regclass('supabase_migrations.schema_migrations') is not null then (
      ((xpath('//data/text()', query_to_xml(
        'select coalesce(jsonb_agg(to_jsonb(m) - ''statements'' order by m.version), ''[]''::jsonb)::text as data from supabase_migrations.schema_migrations m',
        false, true, ''
      )))[1]::text)::jsonb
    )
    else jsonb_build_object('status', 'supabase_migrations.schema_migrations_not_present')
  end,

  -- 6. Safe Baseline Row Counts (Exact counts only where table exists; null if absent)
  'baseline_row_counts', jsonb_build_object(
    'profiles', case when to_regclass('public.profiles') is not null then ((xpath('//c/text()', query_to_xml('select count(*) as c from public.profiles', false, true, '')))[1]::text::bigint) end,
    'whitelists', case when to_regclass('public.whitelists') is not null then ((xpath('//c/text()', query_to_xml('select count(*) as c from public.whitelists', false, true, '')))[1]::text::bigint) end,
    'routines', case when to_regclass('public.routines') is not null then ((xpath('//c/text()', query_to_xml('select count(*) as c from public.routines', false, true, '')))[1]::text::bigint) end,
    'routine_versions', case when to_regclass('public.routine_versions') is not null then ((xpath('//c/text()', query_to_xml('select count(*) as c from public.routine_versions', false, true, '')))[1]::text::bigint) end,
    'timetable_runs', case when to_regclass('public.timetable_runs') is not null then ((xpath('//c/text()', query_to_xml('select count(*) as c from public.timetable_runs', false, true, '')))[1]::text::bigint) end,
    'timetable_rooms', case when to_regclass('public.timetable_rooms') is not null then ((xpath('//c/text()', query_to_xml('select count(*) as c from public.timetable_rooms', false, true, '')))[1]::text::bigint) end,
    'timetable_faculty', case when to_regclass('public.timetable_faculty') is not null then ((xpath('//c/text()', query_to_xml('select count(*) as c from public.timetable_faculty', false, true, '')))[1]::text::bigint) end,
    'timetable_settings', case when to_regclass('public.timetable_settings') is not null then ((xpath('//c/text()', query_to_xml('select count(*) as c from public.timetable_settings', false, true, '')))[1]::text::bigint) end,
    'timetable_course_eligibility', case when to_regclass('public.timetable_course_eligibility') is not null then ((xpath('//c/text()', query_to_xml('select count(*) as c from public.timetable_course_eligibility', false, true, '')))[1]::text::bigint) end,
    'course_distribution_sources', case when to_regclass('public.course_distribution_sources') is not null then ((xpath('//c/text()', query_to_xml('select count(*) as c from public.course_distribution_sources', false, true, '')))[1]::text::bigint) end,
    'course_distribution_revisions', case when to_regclass('public.course_distribution_revisions') is not null then ((xpath('//c/text()', query_to_xml('select count(*) as c from public.course_distribution_revisions', false, true, '')))[1]::text::bigint) end
  ),

  -- 7. RLS Policies & Effective Table Privileges on public
  'public_rls_policies', (
    select coalesce(jsonb_agg(jsonb_build_object(
      'table', tablename,
      'policy', policyname,
      'permissive', permissive,
      'cmd', cmd,
      'roles', roles,
      'using', qual,
      'check', with_check
    ) order by tablename, policyname), '[]'::jsonb)
    from pg_policies
    where schemaname = 'public'
  ),
  'public_role_grants', (
    select coalesce(jsonb_agg(jsonb_build_object(
      'table', table_name,
      'grantee', grantee,
      'privilege', privilege_type
    ) order by table_name, grantee, privilege_type), '[]'::jsonb)
    from information_schema.table_privileges
    where table_schema = 'public'
      and grantee in ('anon', 'authenticated', 'PUBLIC')
  ),

  -- 8. Key RPC & Security Helper Signatures (publish_routine, CD1 RPCs, role guards)
  'public_functions_and_rpcs', (
    select coalesce(jsonb_agg(jsonb_build_object(
      'name', p.proname,
      'args', pg_get_function_identity_arguments(p.oid),
      'returns', pg_get_function_result(p.oid),
      'security_definer', p.prosecdef,
      'config', p.proconfig
    ) order by p.proname), '[]'::jsonb)
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
  ),

  -- 9. Triggers & Webhook Presence (Function name only; omits action_statement/tgargs to avoid secret leakage)
  'public_triggers_no_secrets', (
    select coalesce(jsonb_agg(jsonb_build_object(
      'table', c.relname,
      'trigger', t.tgname,
      'enabled', t.tgenabled,
      'function_schema', fn_ns.nspname,
      'function_name', fn.proname
    ) order by c.relname, t.tgname), '[]'::jsonb)
    from pg_trigger t
    join pg_class c on c.oid = t.tgrelid
    join pg_namespace ns on ns.oid = c.relnamespace
    join pg_proc fn on fn.oid = t.tgfoid
    join pg_namespace fn_ns on fn_ns.oid = fn.pronamespace
    where ns.nspname = 'public' and not t.tgisinternal
  ),

  -- 10. Storage Buckets, Storage Privileges & storage.objects Policies (from storage_realtime_inventory.sql)
  'storage_buckets', (
    select coalesce(jsonb_agg(jsonb_build_object(
      'id', b.id,
      'name', b.name,
      'public', b.public,
      'file_size_limit', b.file_size_limit,
      'allowed_mime_types', b.allowed_mime_types
    ) order by b.id), '[]'::jsonb)
    from storage.buckets b
  ),
  'storage_policies', (
    select coalesce(jsonb_agg(jsonb_build_object(
      'table', tablename,
      'name', policyname,
      'permissive', permissive,
      'roles', roles,
      'cmd', cmd,
      'using', qual,
      'check', with_check
    ) order by tablename, policyname), '[]'::jsonb)
    from pg_policies
    where schemaname = 'storage' and tablename in ('buckets', 'objects')
  ),

  -- 11. Realtime Publication Membership & Replica Identity
  'realtime_publication', (
    select coalesce(jsonb_agg(jsonb_build_object(
      'name', pubname,
      'all_tables', puballtables,
      'insert', pubinsert,
      'update', pubupdate,
      'delete', pubdelete
    )), '[]'::jsonb)
    from pg_publication
    where pubname = 'supabase_realtime'
  ),
  'realtime_membership', (
    select coalesce(jsonb_agg(jsonb_build_object(
      'schema', schemaname,
      'table', tablename,
      'columns', attnames,
      'row_filter', rowfilter
    ) order by schemaname, tablename), '[]'::jsonb)
    from pg_publication_tables
    where pubname = 'supabase_realtime'
  ),
  'public_replica_identity', (
    select coalesce(jsonb_agg(jsonb_build_object(
      'table', c.relname,
      'identity', c.relreplident
    ) order by c.relname), '[]'::jsonb)
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind in ('r', 'p')
  )

)) as phase0_read_only_audit;
```

### 3.3 Check Classification & Owner Interpretation Guide

| Diagnostic Key | Production (`yxqyrjyzxitrgkhgauli`) Safe? | Quarantined Secondary (`oqwvxplteqtlrhktsplj`) Safe? | What Requires Owner Interpretation |
|---|---|---|---|
| `environment_identity` & `migration_history` | **Yes** (Read-only metadata) | **Yes** (Audit-only; first step to establish ownership & history) | Confirms whether `oqwvxplteqtlrhktsplj` actually contains UniVerse migrations (`001`–`016`, `20261022140809`, `20261106130000`) and belongs solely to UniVerse staging, or belongs to unrelated work (requiring a dedicated clean staging project). |
| `expected_tables_presence` & `key_table_columns` | **Yes** | **Yes** | Confirms whether `campus`/`features` on `timetable_rooms` and `home_department_id` on `timetable_faculty` exist in the target DB before Phase 2 binds forms (`F-18`), and whether `20261022140809` / `20261106130000` exist (`F-19`). |
| `baseline_row_counts` | **Yes** (`to_regclass`-guarded counts) | **Yes** | If `timetable_rooms`, `timetable_faculty`, `timetable_settings`, or `timetable_course_eligibility` equal `0` in production, Phase 2/3 pre-publish empty-config guards remain critical (`F-20`). |
| `public_rls_policies`, `public_role_grants`, `public_functions_and_rpcs` | **Yes** | **Yes** | Checks `profiles_select` (`F-13`/`F-17`), `timetable_course_eligibility` `read_all` (`to public` vs `to authenticated`), `publish_routine` arg types, and whether `proconfig` sets `search_path=''` on `SECURITY DEFINER` helpers. Also verifies `oqwvxplteqtlrhktsplj` isolation/access controls before lifting quarantine. |
| `public_triggers_no_secrets` | **Yes** | **Yes** | Shows whether a trigger calling `supabase_functions.http_request` exists on `notifications` (`send-push`, `F-29`) **without exposing `x-webhook-secret` header values**; owner must separately verify hosted Edge Function secrets (`PUSH_WEBHOOK_SECRET`, `AUTH_WEB_CALLBACK_URLS`) in Supabase Dashboard → Edge Functions. |
| `storage_buckets`, `storage_policies`, `realtime_*` | **Yes** | **Yes** | Confirms live buckets (`timetables`, `resources`, `avatars`, `assignments`), open `storage_auth_*` policies (`F-30`), and whether `supabase_realtime` includes only `cancellations` (`F-25`). |

---

## 4. Verified Hosted SQL Audit Results (21 November 2026)

Both projects were inspected read-only via the owner-executed SQL Editor packet (§3.2 plus compact secondary follow-up omitting column/grant bloat).

### 4.1 Environment Comparison Summary

| Dimension | Production (`yxqyrjyzxitrgkhgauli`) | Secondary Staging (`oqwvxplteqtlrhktsplj`) |
|---|---|---|
| **Governance Classification** | **READ-ONLY** during React Web dev | **Quarantine Lifted → Owner-Approved Non-Prod Staging** |
| **PostgreSQL / Timezone** | PostgreSQL 17.6 (`UTC`) | Postgres (`UTC`) |
| **Schemas Present** | `auth`, `extensions`, `public`, `realtime`, `storage`, `supabase_functions` | `academic_private`, `auth`, `extensions`, `public`, `realtime`, `storage` (`supabase_functions` absent) |
| **`public` Tables (RLS)** | `18` tables (all `rls_enabled: true`, `force_rls: false`) | `37` tables (all `rls_enabled: true`; includes `20261022140809` + `20261106130000`) |
| **Extended Columns (`rooms`/`faculty`/`routines`)** | Absent (`timetable_rooms` 8 cols, `timetable_faculty` 8 cols) | Present (`campus`, `features`, `home_department_id`, `scheduling_scope_id`, `revision_version`) |
| **Migration Table (`schema_migrations`)** | Absent (applied manually) | Absent (applied manually) |
| **Exact Baseline Row Counts** | `routines: 796`, `routine_versions: 6`, `timetable_runs: 23`, `timetable_rooms: 30`, `timetable_faculty: 76`, `timetable_settings: 1`, `profiles: 9`, `whitelists: 3`, **`timetable_course_eligibility: 0`** | **`0` across all 11 baseline & Track 2 tables** |
| **Outbound Push Webhook Trigger** | `notifications` → `send_push_on_notification` (`supabase_functions.http_request`, enabled) | **None** (all 26 triggers are internal `public` or `academic_private` guards) |
| **Track 2 RPCs** | Absent (`publish_routine` present with `search_path=public`, `security_definer=false`) | Present & signature-verified (`read_course_distribution_revision`, 8-param `append_course_distribution_correction`, `academic_catalog`, alias/mapping RPCs with `search_path=""`) |
| **`supabase_realtime` Publication** | `public.cancellations` only (`all_tables: false`) | `public.cancellations` only |
| **Storage Buckets & Policies** | `assignments`, `avatars`, `resources`, `timetables` (all `public: true`, `file_size_limit: null`); wildcard `storage_public_read` + `storage_auth_insert/update/delete` | Same 4 public buckets and same 4 wildcard `storage.objects` policies |

### 4.2 Audit Outcomes & Decisions Recorded (21 November 2026)

1. **Production Baseline (`F-20` Updated):** Contrary to historical local docs reporting `0` rows in production config tables, production `yxqyrjyzxitrgkhgauli` **does** hold active `timetable_rooms` (`30`), `timetable_faculty` (`76`), and `timetable_settings` (`1`), while **`timetable_course_eligibility` remains empty (`0` rows)** — confirming the pre-publish eligibility readiness warning remains necessary in Phases 1–3.
2. **Quarantine Lifted on `oqwvxplteqtlrhktsplj`:** Because secondary `oqwvxplteqtlrhktsplj` contains zero user/routine rows (`0` everywhere), zero outbound `supabase_functions` webhooks, and the verified UniVerse 37-table schema, the owner confirmed project ownership and approved `oqwvxplteqtlrhktsplj` as the **non-production staging target** while keeping `yxqyrjyzxitrgkhgauli` strictly read-only.
3. **RLS Security Items Flagged for Future Hardening (Phase 4A / 5B):**
   - Confirmed production/staging `profiles_select` (`using (true)`), `timetable_course_eligibility` `read_all` (`roles: ["public"]`, `anon` grants across baseline tables), `SECURITY DEFINER` helpers (`guard_profile_role`, `is_admin`, `my_role`, `register_device_token` using `search_path=public`), and wildcard `storage_auth_*` (`F-17`, `F-30`).
   - Flagged staging `course_distribution_{sources,revisions,corrections,artifacts}_read` policies declared on `roles: ["public"]` allowing reads when `scheduling_scope_id IS NULL` (mitigated for `anon` only by missing `anon` table grant; `authenticated` reads remain open for unscoped rows until tightened).
4. **Confirmed Phase 1A Accent Token:** Owner confirmed **Deep Botanical Pine** as the Phase 1A accent color alongside Charcoal Ink primary actions in `tokens.css`.
