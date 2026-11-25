# Role 1 — Web Platform, Cloudflare Cutover & Frozen Fallback

## Cross-Referenced Mandatory Skills

Load [`system-security-and-hardening`](../../system-security-and-hardening/SKILL.md) (PKCE/invite-bridge isolation, `_headers` CSP, `ALLOWED_ORIGINS`, secret/PII hygiene) and [`backend-evolution-and-resilience`](../../backend-evolution-and-resilience/SKILL.md) (4-layer compatibility, direct Supabase Storage downloads, bounded queries) alongside the React Web design/contract skills when modifying `apps/web/`.

## Scope

- **Standalone React Web (`apps/web/`):** React 19 + TypeScript + Vite Admin Operations Console (`/admin/*`), Public Institutional Entry (`/`), auth flows (`/login`, `/forgot-password`, `/reset-password`, `/access-required`), and `public/` assets (`_headers` CSP, `_redirects` SPA fallback, `theme-init.js` anti-FOUC Light/Dark/System bootstrap).
- **Cloudflare Pages Deployment (`docs/deployment/CLOUDFLARE_PAGES_AND_CUTOVER_RUNBOOK.md`):**
  - **Environment A (Live):** `https://universe-bfi.pages.dev`, bound to Staging Supabase (`oqwvxplteqtlrhktsplj`) + Render engine (`https://universe-timetable-engine.onrender.com`, `7ec652a`, `ENGINE_AUTH_MODE=optional`).
  - **Environment B (Stage 3 Production Cutover):** Gated on owner-executed Phase 4A-1 + Phase 5B SQL promotion on Production (`yxqyrjyzxitrgkhgauli`) and flipping `ENGINE_AUTH_MODE=enforced` + exact `ALLOWED_ORIGINS`.
- **Frozen Flutter Web Fallback (`web/`, `lib/features/admin/`):** Preserved strictly read-only until Environment B Cutover and Wave 2 **Phase 3B** (additive FastAPI rendered-workbook parse endpoint replacing Dart `RoutineWorkbookParser`) are verified in production.

## Role-Specific Guardrails

- Load [`react-web-academic-design-system`](../../react-web-academic-design-system/SKILL.md), [`react-web-motion-and-craft`](../../react-web-motion-and-craft/SKILL.md), and [`react-admin-backend-contracts`](../../react-admin-backend-contracts/SKILL.md) as appropriate before modifying `apps/web/`.
- Never implement new browser features in Flutter (`lib/features/admin/` or `web/`), and do **not** delete Flutter admin/web files or `RoutineWorkbookParser` until the owner explicitly authorizes post-cutover pruning.
- Continuously preserve Flutter Mobile (`lib/`) Android and iOS compatibility (`com.example.universe://login-callback/`, `com.example.universe://reset-callback/`, shared Supabase/FastAPI contracts).
