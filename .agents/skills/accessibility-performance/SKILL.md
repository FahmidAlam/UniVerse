---
name: accessibility-performance
description: Review and implement accessible, inclusive, and performant UniVerse Flutter interfaces, especially browser layouts, data-heavy screens, forms, navigation, and custom controls.
---

# UniVerse Accessibility and UI Performance

## Accessibility baseline

- Ensure sufficient text and non-text contrast; verify actual color pairs rather than relying on visual impression.
- Never communicate status, validation, selection, or chart meaning by color alone. Add labels, icons, patterns, or text.
- Give controls meaningful semantic labels, roles, values, and hints where needed. Avoid redundant announcements.
- Support keyboard navigation, logical tab order, visible focus, Enter/Space activation, and Escape behavior for dismissible overlays.
- Keep focus visible and predictable when opening/closing dialogs, menus, routes, and side panels.
- Make touch targets comfortably usable and avoid tightly packed controls.
- Support text scaling and browser zoom without clipping, overlap, or loss of actions.
- Use headings and semantic grouping to support screen-reader navigation.
- Provide labels and understandable errors for form fields; do not rely on placeholder text as the only label.
- Announce important asynchronous status changes appropriately without flooding assistive technology.
- Respect reduced-motion settings and avoid flashing content.

## Flutter-specific checks

- Inspect Semantics widgets and semantic behavior of custom controls.
- Test FocusTraversalGroup/FocusNode behavior where custom focus management is used.
- Verify tooltip/label alternatives for icon-only controls.
- Ensure scrollable areas are keyboard reachable and preserve context.
- Test actual web semantics/keyboard behavior; widget tests alone do not prove browser accessibility.

## Performance principles

- Measure before optimizing. Record the screen, dataset size, browser/device, and observed symptom.
- Avoid rebuilding large subtrees for small local state changes; keep state scope narrow and keys stable.
- Use const widgets where practical and avoid expensive work in build methods.
- For large lists/tables, prefer lazy builders and avoid eager construction of every row/cell unless measured data size is small.
- Avoid unnecessary nested scroll views, repeated expensive formatting, unbounded image sizes, and excessive blur/shadow/opacity layers.
- Cache/reuse derived presentation data when appropriate, but keep cache invalidation correct.
- Debounce high-frequency search/filter input when it prevents unnecessary work without making the UI feel laggy.
- Keep animations lightweight and avoid continuous animations on large surfaces.
- Check initial web payload, image/font loading, route transitions, and runtime responsiveness separately.

## UniVerse priorities

- Dense timetable/admin grids need readable focus order, stable headers, understandable empty slots, and usable keyboard behavior.
- Stale connectivity or engine states must be visible and accurate; do not display a green/live indicator without a real check.
- Preserve important error details and recovery paths; don't optimize by removing useful feedback.

## Validation evidence

Separate:
- Static inspection/analyzer findings.
- Widget/unit tests.
- Browser keyboard and semantic checks.
- Screen-reader/manual assistive-technology checks.
- Lighthouse or equivalent measurements.
- Performance traces or measured profiling.

Do not claim WCAG compliance or accessibility certification from a checklist or automated score alone. State what was tested and what remains unverified.
