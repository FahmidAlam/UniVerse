# Phase 7 local fixture renders

Captured and inspected on 9 November 2026. These are Flutter widget renders with injected controllers and fixture records, not authenticated browser or production evidence. Reduced motion is enabled. The desktop renders embed each route in `DesktopShellScope`; the surrounding admin sidebar is outside these captures.

| Screen | 390x844 | 1440x900 |
|---|---|---|
| Admin Registration | [Mobile](registration_390.png) | [Desktop](registration_1440.png) |
| Broadcast History | [Mobile](history_390.png) | [Desktop](history_1440.png) |
| Manage Resources | [Mobile](upload_390.png) | [Desktop](upload_1440.png) |
| Resource Library | [Mobile](library_390.png) | [Desktop](library_1440.png) |

Verified by widget assertions: four layouts at both sizes; local app bars absent in desktop scope; no reported layout overflow; mobile 1.3x text scaling; Escape closes broadcast and resource deletion overlays without executing deletion; resource filtering and clearing update real fixture match counts.

Visual findings: bounded forms and filter controls remain readable, cards use the existing tokens, and counts are placed before results. The long whitelist tab is ellipsized on mobile. The registration dropdown placeholder uses an inherited test-font surface that renders as blocks in the harness; production/browser typography is not accepted from this capture. No screen-reader, browser walkthrough or performance-profile acceptance is claimed.

See [closure report](../../../PHASE_7_FINAL_UI_UX_CLOSURE_REPORT.md) for repository-wide test limitations and backend boundaries.
