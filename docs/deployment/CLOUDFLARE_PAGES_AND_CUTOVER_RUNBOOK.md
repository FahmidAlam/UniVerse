# UniVerse — Cloudflare Pages & Dual-Environment Cutover Runbook

> **Scope:** Deployment and environment configuration for standalone React Web (`apps/web/`) on Cloudflare Pages, coordinated with Render FastAPI (`engine/`) and Supabase Auth / Edge Functions (`invite-admin`).
> **Governance:** Zero Supabase CLI is used or required. All Supabase database & Auth settings are managed via **Supabase Dashboard**.

---

## 1. Build & Static Asset Contract (`apps/web/`)

Cloudflare Pages deploys directly from `apps/web/dist/` with:
- **Root directory:** `apps/web`
- **Build command:** `npm run build`
- **Output directory:** `dist`
- **Node.js version:** `22` (set `NODE_VERSION=22` in Cloudflare Pages environment variables)

Static files automatically copied from `apps/web/public/` into `apps/web/dist/`:
- `_redirects`: `/* /index.html 200` (SPA client-side routing fallback for `/login`, `/admin/dashboard`, `/admin/routine`, etc.)
- `_headers`: Security headers (`X-Frame-Options: DENY`, `X-Content-Type-Options: nosniff`, `Referrer-Policy`, `Permissions-Policy`, `Strict-Transport-Security`, strict `Content-Security-Policy` with zero `'unsafe-inline'` scripts via `/theme-init.js`), plus `immutable` caching for `/assets/*` and `no-cache` for `/index.html`.
- `theme-init.js`: External pre-paint Light/Dark/System theme initializer.

---

## 2. Environment A — Continuous Committee Review (Immediate / Staging)

Use this dedicated persistent Cloudflare Pages project (e.g., `universe-admin-review.pages.dev`) for committee UAT against **Staging Supabase (`oqwvxplteqtlrhktsplj`)**.

### 2.1 Cloudflare Pages Environment Variables (Environment A)
Set under **Cloudflare Pages → Settings → Environment variables** (Production & Preview):

| Variable | Value |
|---|---|
| `NODE_VERSION` | `22` |
| `VITE_SUPABASE_URL` | `https://oqwvxplteqtlrhktsplj.supabase.co` |
| `VITE_SUPABASE_ANON_KEY` | `<staging_supabase_anon_key>` *(from Staging Dashboard → Settings → API)* |
| `VITE_TIMETABLE_BASE_URL` | `https://universe-timetable-engine.onrender.com` |
| `VITE_ENABLE_SCHEDULING_PREVIEW_ROUTE` | `false` |

### 2.2 Staging Supabase Auth Redirect URLs (`oqwvxplteqtlrhktsplj`)
In **Supabase Dashboard (`oqwvxplteqtlrhktsplj`) → Authentication → URL Configuration → Redirect URLs**, add exact trailing-slash root URLs (no wildcards — React sends `${window.location.origin}/` for Google OAuth, password recovery, and `invite-admin`):
- `https://<review-domain>.pages.dev/`
- `http://localhost:5173/`

*(Optional secondary entries: `https://<review-domain>.pages.dev/login`, `https://<review-domain>.pages.dev/reset-password`, `http://localhost:5173/login`, `http://localhost:5173/reset-password`.)*

If `invite-admin` Edge Function is deployed to staging, set Edge Function secret `AUTH_WEB_CALLBACK_URLS` to the comma-separated exact root callback URLs:
- `https://<review-domain>.pages.dev/,http://localhost:5173/`

### 2.3 Render FastAPI Environment Variables (`universe-timetable-engine`)
Set under **Render → `universe-timetable-engine` → Environment**:

| Variable | Value | Notes |
|---|---|---|
| `ALLOWED_ORIGINS` | `https://<review-domain>.pages.dev,http://localhost:5173,http://127.0.0.1:5173` | Comma-separated exact origins (no trailing slash). Add production origin when Environment B cuts over. |
| `ENGINE_AUTH_MODE` | `optional` *(during dual-client rollout)* → `enforced` *(after Stage 2 dual-client verification)* | Controls whether `/api/timetable/*` requires valid admin JWT (`401`/`403` when `enforced`). |
| `SUPABASE_URL` | `https://oqwvxplteqtlrhktsplj.supabase.co` *(or prod URL at cutover)* | Required when `ENGINE_AUTH_MODE=enforced`. |
| `SUPABASE_SERVICE_ROLE_KEY` | `<target_service_role_key>` *(marked secret)* | Used server-side only by `engine/auth.py` to verify `public.profiles.role == 'admin'`. Never expose in `apps/web/` or `lib/`. |
| `SUPABASE_ANON_KEY` | `<target_anon_key>` | Used server-side to call `${SUPABASE_URL}/auth/v1/user` if needed. |

> **Shared Render Service Warning:** While a single shared Render service (`universe-timetable-engine`) serves both Staging Review (`oqwvxplteqtlrhktsplj`) and Production Flutter (`yxqyrjyzxitrgkhgauli`), Render **must stay in `ENGINE_AUTH_MODE=optional`** (with strict `ALLOWED_ORIGINS` active) until either a dedicated staging Render service is created or Environment B cuts over to Production with `ENGINE_AUTH_MODE=enforced`. Setting `ENGINE_AUTH_MODE=enforced` against Staging `SUPABASE_URL` on a shared Render instance would reject Production Flutter admin JWTs.

---

## 3. Environment B — Production Cutover (GATED Until Stages 2–4 Complete)

> **GATE:** Do **NOT** deploy Environment B or mutate Production Supabase (`yxqyrjyzxitrgkhgauli`) until:
> 1. Stage 2 (`ENGINE_AUTH_MODE=enforced` + dual-client Flutter & React Web headers) is verified on Staging.
> 2. Stage 3 (`20261122160000_phase_5b_rls_and_storage_hardening.sql`) passes all negative/positive tests on Staging.
> 3. Explicit Owner Sign-Off is recorded for Production Cutover.

### 3.1 Cloudflare Pages Environment Variables (Environment B)
Create a separate Production Cloudflare Pages project (e.g., `universe-admin.pages.dev` or custom domain):

| Variable | Value |
|---|---|
| `NODE_VERSION` | `22` |
| `VITE_SUPABASE_URL` | `https://yxqyrjyzxitrgkhgauli.supabase.co` |
| `VITE_SUPABASE_ANON_KEY` | `<production_supabase_anon_key>` |
| `VITE_TIMETABLE_BASE_URL` | `https://universe-timetable-engine.onrender.com` |
| `VITE_ENABLE_SCHEDULING_PREVIEW_ROUTE` | `false` |

### 3.2 Production Supabase, Google OAuth & `invite-admin` Checklist
1. **Production Supabase (`yxqyrjyzxitrgkhgauli`) → Authentication → URL Configuration:**
   - Add exact trailing-slash root URL: `https://<prod-domain>/` *(optional secondary entries: `https://<prod-domain>/login`, `https://<prod-domain>/reset-password`)*.
2. **Google Cloud Console → OAuth 2.0 Client:**
   - Verify authorized JavaScript origins include `https://<prod-domain>` (and Supabase callback `https://yxqyrjyzxitrgkhgauli.supabase.co/auth/v1/callback` remains intact).
3. **`invite-admin` Edge Function (`AUTH_WEB_CALLBACK_URLS`):**
   - Set exact production root callback: `https://<prod-domain>/`.
4. **Render FastAPI (`universe-timetable-engine`):**
   - Update `ALLOWED_ORIGINS` to include `https://<prod-domain>`.
   - Point `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` to `yxqyrjyzxitrgkhgauli` and ensure `ENGINE_AUTH_MODE=enforced`.

### 3.3 Post-Cutover Smoke Verification
1. Hard-refresh `/`, `/login`, `/admin/dashboard`, and `/admin/routine` → all return HTTP `200` with `_headers` CSP active and zero console errors.
2. Verify unauthenticated `POST /api/timetable/generate` returns `401` and student JWT returns `403`.
3. Verify Admin PKCE Google OAuth, `invite-admin`, `EngineHealthBadge` (`GET /` → `200`), and Flutter Android student/teacher routine reads remain green.
