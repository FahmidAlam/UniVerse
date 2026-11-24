# Role 1 — Web Platform, Cloudflare Cutover & Frozen Fallback

## Scope

- **Standalone React Web (`apps/web/`):** React 19 + TypeScript + Vite Admin Operations Console (`/admin/*`), Public Institutional Entry (`/`), auth flows (`/login`, `/forgot-password`, `/reset-password`, `/access-required`), and `public/` assets (`_headers` CSP, `_redirects` SPA fallback, `theme-init.js` anti-FOUC Light/Dark/System bootstrap).
- **Cloudflare Pages Deployment (`docs/deployment/CLOUDFLARE_PAGES_AND_CUTOVER_RUNBOOK.md`):**
  - **Environment A (Committee Review):** Continuous preview bound to Staging Supabase (`oqwvxplteqtlrhktsplj`) + Render engine (`ENGINE_AUTH_MODE=optional`).
  - **Environment B (Production Cutover):** Gated on owner-executed Phase 4A-1 + Phase 5B SQL promotion on Production (`yxqyrjyzxitrgkhgauli`) and flipping `ENGINE_AUTH_MODE=enforced` + `ALLOWED_ORIGINS`.
- **Frozen Flutter Web Fallback (`web/`, `lib/features/admin/`):** Preserved strictly read-only until Environment B Cutover and Wave 2 **Phase 3B** (additive FastAPI rendered-workbook parse endpoint replacing Dart `RoutineWorkbookParser`) are verified in production.

## Guardrails

- Load [`react-web-academic-design-system`](../../react-web-academic-design-system/SKILL.md), [`react-web-motion-and-craft`](../../react-web-motion-and-craft/SKILL.md), and [`react-admin-backend-contracts`](../../react-admin-backend-contracts/SKILL.md) as appropriate before modifying `apps/web/`.
- Never implement new browser features in Flutter (`lib/features/admin/` or `web/`), and do **not** delete Flutter admin/web files or `RoutineWorkbookParser` until the owner explicitly authorizes post-cutover pruning.
- Continuously preserve Flutter Mobile (`lib/`) Android and iOS compatibility (`com.example.universe://login-callback/`, `com.example.universe://reset-callback/`, shared Supabase/FastAPI contracts).
- Enforce strict admin-only web access (`profile.role === 'admin'`), scrubbing `#type=invite` hash tokens immediately on bootstrap via `extractAndScrubInviteHash()`.
