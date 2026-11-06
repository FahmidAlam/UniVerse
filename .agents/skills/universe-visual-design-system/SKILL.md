---
name: universe-visual-design-system
description: Design and refine UniVerse's visual language, hierarchy, spacing, typography, color, iconography, and component consistency while safely governing the existing Flutter theme system.
---

# UniVerse Visual Design System

## Objective

Create a recognizable, polished, calm, high-quality academic product. UniVerse's established dark foundation and orange accent are the current identity; refine them where evidence supports it, but do not casually replace or fork the theme.

## Inspect before styling

- Find the actual ThemeData/ColorScheme, semantic color tokens, typography, spacing conventions, component themes, and shared widgets in the repository.
- Identify light/dark support, theme modes, responsive variants, and any existing exceptions.
- Inspect real screens before proposing global changes. Do not infer exact token values from screenshots when source values can be inspected.
- Reuse existing components and semantic tokens. Do not introduce hard-coded one-off colors, font sizes, radii, or shadows when a suitable token exists.

## Visual hierarchy and composition

- Establish a clear primary, secondary, and tertiary level for content and actions.
- Align content to a consistent grid; use consistent page gutters, section spacing, and baselines.
- Group related information by proximity and meaningful whitespace before adding borders or cards.
- Use typography to communicate hierarchy: readable body size, restrained weights, consistent line height, and appropriate line lengths.
- Make important headings and primary actions distinct without making every element compete for attention.
- Keep icon size, stroke/weight, alignment, and visual semantics consistent. Ensure icon contrast on every surface.
- Use imagery only when it communicates useful context; use consistent crop, aspect ratio, and quality.

## Theme modification safety protocol

A theme is a shared contract, not a collection of local decoration.

Before changing it:
1. Map where theme tokens and component themes are defined and consumed.
2. Identify the exact problem and representative screens affected.
3. Prefer a small semantic-token correction over broad palette replacement.
4. Check foreground/background pairs, interaction states, disabled states, surfaces, borders, and charts/status colors.
5. Assess impact on existing student, teacher, and admin flows and both web/mobile layouts.
6. Present material global changes for user approval before implementation.

When implementing an approved theme change:
- Centralize values in the existing theme/token layer.
- Preserve public interfaces and existing theme extension contracts unless a separately approved refactor is necessary.
- Avoid parallel palettes and scattered constants.
- Update component themes consistently; do not fix one screen by creating a conflicting local theme.
- Capture before/after screenshots of representative screens and run relevant tests/analyzer.
- Report changed tokens, impacted components, verified screens, and any unverified surfaces.

## Anti-slop: avoid patterns, not categories

Do not add a visual trend because it is popular or AI tools generate it easily. In particular, scrutinize:

- Gratuitous gradients, glass effects, glow, blur, noise, dithering, ASCII art, sparkle icons, pixel loaders, liquid effects, marquees, decorative flowcharts, or animated logos.
- Repeated pill/tag/badge treatments, excessive italics, all-caps eyebrow labels, tiny metadata, overly tight letter spacing, and gratuitous serif/display fonts.
- Cards nested inside cards, border around every container, excessive dividers, too many shades/opacities, unnecessary shadows, and repetitive three-card feature sections.
- Overly detailed UI, verbose helper text, redundant headings, decorative numbering, code-like breadcrumbs, and periods or punctuation conventions applied mechanically to titles.
- Inconsistent icon packs, arbitrary corner radii, one-off font families, unexplained gradients, and visually noisy status colors.

These are warning signs, not absolute bans. A pill can be the clearest status indicator; a divider can clarify a dense table; a gradient can establish meaningful brand depth. Keep a pattern only when it has a specific purpose and survives a simpler alternative comparison.

## Use restraint deliberately

- Prefer a small number of strong surfaces over layers of containers.
- Use color to encode meaning and action, not as decoration on every element.
- Keep accent color scarce enough to retain importance.
- Use status colors consistently and never rely on color alone.
- Prefer clear typography and whitespace over visual tricks.
- Use distinctive brand moments selectively; product-wide consistency matters more than novelty per screen.

## Review checklist

- Is the most important content visible and scannable first?
- Is the visual hierarchy understandable in a quick glance?
- Are alignments, gutters, spacing, typography, and icons consistent?
- Does every decoration have a purpose?
- Are contrast and states sufficient?
- Does the screen still look like UniVerse?
- Is the theme change centralized and safe across roles, platforms, and components?
