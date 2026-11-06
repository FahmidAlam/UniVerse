# Role 1 — Web Platform & Admin Shell

## Scope

- Browser compatibility across `lib/main.dart`, `lib/core/platform/`, `lib/core/router/`, `lib/features/auth/`, `lib/features/admin/`, and `lib/features/routine/`.
- Responsive desktop/tablet/mobile admin shell (`AdminDesktopShell` and `AppShell`) preserving existing Flutter feature-first `ChangeNotifier` + `GoRouter` architecture.
- Browser file upload (`pickBytes`) and download (`saveBytes`) abstractions without direct `dart:io` leakage on web.
- Browser auth callback routing (`/auth-callback`, `/reset-password`) alongside native deep links (`com.example.universe://login-callback/` and `com.example.universe://reset-callback/`).

## Guardrails

- Do not introduce React/Next.js or replace `ChangeNotifier` / `GoRouter`.
- Keep non-admin web sessions out of admin routes (`NotWhitelistedScreen` / login redirect).
- Do not touch iOS configuration or builds.
- See [`docs/implementation/20-browser-admin-foundation.md`](../../../../docs/implementation/20-browser-admin-foundation.md) and [`docs/implementation/21-browser-admin-independent-review.md`](../../../../docs/implementation/21-browser-admin-independent-review.md) only when reviewing or closing Phase 1 runtime checks.
