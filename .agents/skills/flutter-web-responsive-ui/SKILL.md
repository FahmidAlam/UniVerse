---
name: flutter-web-responsive-ui
description: Build and review responsive UniVerse Flutter interfaces with desktop web as the primary target and tablet/mobile as deliberate adaptive layouts. Use for screens, navigation, forms, tables, dashboards, and layout defects.
---

# Flutter Web-First Responsive UI

## Product target

Design for desktop browser use first, then adapt intentionally for tablet and mobile. Do not simply stretch a phone layout across a wide viewport. Preserve the existing Flutter app, feature-first organization, GoRouter, controllers/services, role behavior, and shared theme.

## Inspect before implementation

- Inspect the target screen, route, parent shell, reusable widgets, state/controller contract, and existing responsive breakpoints.
- Identify the primary task and realistic data density.
- Check the current layout at wide desktop, compact desktop, tablet, and phone widths.
- Confirm browser support and platform-specific APIs before introducing dependencies or platform branches.
- Preserve current behavior and navigation unless the approved design explicitly changes them.

## Layout strategy

- Use adaptive composition: sidebar/navigation rail on wider screens where appropriate; compact navigation patterns on narrow screens.
- Use bounded content widths and consistent page gutters; avoid full-width text lines and excessively stretched forms.
- Use responsive grids and flexible constraints rather than fixed pixel layouts wherever possible.
- Set sensible minimum widths for complex data tables and provide an intentional narrow-screen alternative (horizontal scroll, stacked detail, or focused record view) rather than crushing columns.
- Keep primary actions visible and logically grouped; on narrow screens, place them near the related content and consider a reachable sticky action area only when it does not obscure content.
- Preserve readable text and touch target sizes at every width.
- Avoid both extremes: desktop UI that is wastefully sparse and mobile UI crammed into a desktop canvas.

## Data-heavy admin experiences

- Optimize scanning: stable column alignment, clear headers, readable row density, sorting/filtering where task-relevant, and consistent empty/loading/error states.
- Preserve table context when users inspect or edit a record. Side panels or dialogs must have clear focus, close behavior, and responsive fallback.
- Consider sticky headers/columns only when they solve a real navigation problem and remain usable on smaller screens.
- Do not hide validation, warnings, source values, or important academic context merely to fit the viewport.
- Use lazy rendering/virtualization only when supported by the chosen Flutter widgets and justified by measured scale; avoid premature complexity.

## Breakpoint verification

Use project-established breakpoints where they exist. Do not add a second competing breakpoint system. At minimum verify representative widths around:

- Wide desktop: 1440 px
- Standard laptop: 1280 px
- Compact desktop: 1024 px
- Tablet: 768 px
- Phone: 390 px

These are test viewports, not mandatory hard-coded breakpoint values. Check intermediate widths and browser zoom as well.

## Flutter implementation guidance

- Prefer LayoutBuilder/MediaQuery constraints and existing adaptive components over device-name checks.
- Avoid unnecessary IntrinsicHeight/IntrinsicWidth in large repeated layouts.
- Prevent overflow, unbounded constraints, accidental nested scrolling, and keyboard-hidden controls.
- Respect browser back/forward, direct route entry, refresh behavior, URL semantics, and focus restoration where relevant.
- Keep file handling, downloads, dialogs, and platform integrations browser-compatible; do not assume native filesystem APIs exist on web.
- Use semantics and keyboard support for custom interactive widgets.

## Responsive acceptance

For each changed screen, verify:
1. No unintended horizontal/vertical overflow.
2. Primary task remains obvious and completable.
3. Navigation and back behavior work.
4. Tables/forms remain usable and preserve important information.
5. Dialogs, menus, tooltips, and sticky controls fit the viewport.
6. Keyboard, browser zoom, and focus behavior remain usable.
7. Empty, loading, error, success, disabled, and permission states adapt correctly.
8. The UI remains recognizably UniVerse at each width.

Report exact tested widths and browsers. Do not call a screen responsive because it merely compiles or renders once.
