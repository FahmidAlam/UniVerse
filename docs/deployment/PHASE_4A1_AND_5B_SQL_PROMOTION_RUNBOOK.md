# UniVerse — Phase 4A-1 & Phase 5B SQL Promotion Runbook

> **Governance:** ZERO Supabase CLI is used or required. Every SQL script in this runbook is executed directly in **Supabase Dashboard → SQL Editor**.
> **Production Protection:** Production (`yxqyrjyzxitrgkhgauli`) is **GATED** behind explicit owner sign-off after Staging (`oqwvxplteqtlrhktsplj`) and the persistent Cloudflare Pages Review URL pass verification.

---

## 1. Pre-Flight Backup & Row-Count Check (Target Project)

Before running any migration in **Supabase Dashboard → SQL Editor**, capture a baseline row-count snapshot and confirm table counts:

```sql
select jsonb_pretty(jsonb_build_object(
  'db', current_database(),
  'table_count', (
    select count(*) from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind in ('r', 'p')
  ),
  'counts', jsonb_build_object(
    'profiles', (select count(*) from public.profiles),
    'whitelists', (select count(*) from public.whitelists),
    'routines', (select count(*) from public.routines),
    'timetable_rooms', (select count(*) from public.timetable_rooms),
    'timetable_faculty', (select count(*) from public.timetable_faculty),
    'timetable_settings', (select count(*) from public.timetable_settings),
    'timetable_course_eligibility', (select count(*) from public.timetable_course_eligibility)
  )
));
```

---

## 2. Staging Execution (`oqwvxplteqtlrhktsplj`)

`oqwvxplteqtlrhktsplj` already contains `20261022140809_academic_catalog.sql` and `20261106130000_course_distribution_contract.sql` (`37` tables).

1. **Apply Phase 5B RLS & Storage Hardening:**
   - Open `oqwvxplteqtlrhktsplj` → **SQL Editor**.
   - Paste and run [`supabase/migrations/20261122160000_phase_5b_rls_and_storage_hardening.sql`](../../supabase/migrations/20261122160000_phase_5b_rls_and_storage_hardening.sql).
2. **Run Negative & Positive Verification Assertions:**
   - Paste and run [`supabase/tests/phase_5b_rls_hardening_verification.sql`](../../supabase/tests/phase_5b_rls_hardening_verification.sql).
   - Confirm `NOTICE: PASS: All Phase 5B negative & positive RLS/Storage assertions succeeded.` (wrapped in `BEGIN ... ROLLBACK`, leaving zero test rows).
3. **Rollback Reference (if needed):**
   - [`supabase/reconciliation/rollback_phase_5b_rls_and_storage.sql`](../../supabase/reconciliation/rollback_phase_5b_rls_and_storage.sql).

---

## 3. Production Execution (`yxqyrjyzxitrgkhgauli` — GATED)

> **GATE:** Execute **ONLY** after:
> 1. Staging (`oqwvxplteqtlrhktsplj`) passes Phase 5B verification + live Cloudflare Pages Review URL smoke checks.
> 2. Render FastAPI `ENGINE_AUTH_MODE=enforced` is verified with both Flutter and React Web clients.
> 3. Explicit Owner Sign-Off is obtained.

Run in exact order in **Production (`yxqyrjyzxitrgkhgauli`) → SQL Editor**:

1. **Step A — Academic Catalog (Track 2 Foundation):**
   - Run [`supabase/migrations/20261022140809_academic_catalog.sql`](../../supabase/migrations/20261022140809_academic_catalog.sql).
2. **Step B — Course Distribution Contract (Gates A–B):**
   - Run [`supabase/migrations/20261106130000_course_distribution_contract.sql`](../../supabase/migrations/20261106130000_course_distribution_contract.sql).
3. **Step C — Phase 5B RLS & Storage Hardening:**
   - Run [`supabase/migrations/20261122160000_phase_5b_rls_and_storage_hardening.sql`](../../supabase/migrations/20261122160000_phase_5b_rls_and_storage_hardening.sql).
4. **Step D — Post-Promotion Verification:**
   - Run [`supabase/tests/phase_5b_rls_hardening_verification.sql`](../../supabase/tests/phase_5b_rls_hardening_verification.sql) (`ROLLBACK`-safe).
   - Verify policy inventory and `search_path` hardening:
     ```sql
     select proname, prosecdef, proconfig
     from pg_proc p
     join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public'
       and proname in ('my_role', 'is_admin', 'guard_profile_role', 'register_device_token');
     ```
   - Verify no `storage_auth_*` wildcard policies remain on `storage.objects`:
     ```sql
     select policyname, cmd
     from pg_policies
     where schemaname = 'storage' and tablename = 'objects'
     order by policyname;
     ```

---

## 4. Explicit Wave 2 (Phase 4A-2) Scope Boundary

The following items are **NOT** part of Phase 4A-1 / Phase 5 and remain scheduled for **Wave 2 (Phase 4A-2)**:
- Persistent database tables/RPCs for Catalog Courses, Batches/Sections, and `PolicySnapshot` (**Gate C**).
- R1–R16 committee solver math extensions in `engine/solver.py` and Excel rendering changes in `engine/render.py`.
- Durable database-backed solver job storage replacing in-memory `JOBS` in `engine/main.py` (**Gate D**).
- Multi-teacher / co-teacher `public.routines` storage (`teacher_codes`) and snapshot-recoverable `publish_routine()` (**Gate D**).
- Additive FastAPI `.xlsx` parse/validation endpoint for `?tab=upload` (**Phase 3B**).
