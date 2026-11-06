---
name: visual-ui-qa
description: Conduct evidence-based visual and usability reviews of UniVerse Flutter screens using screenshots, live browser inspection, responsive viewport checks, interaction walkthroughs, and regression comparisons.
---

# UniVerse Visual UI/UX QA

## Objective

Catch visual inconsistency, usability friction, responsive defects, and regressions before accepting UI work. Review the actual rendered product—not only code or design mockups.

## Start with evidence and scope

1. Identify the target role, screen, route, workflow, expected behavior, and approved design contract.
2. Inspect Git status/diff and preserve unrelated work before any test or implementation task.
3. Locate available screenshots, browser build, test scripts, and existing golden/widget tests.
4. If no current screenshots or runnable UI are available, say evidence is insufficient and request the exact screen/viewport evidence. Never invent defects or praise.
5. Distinguish observed defects, inferred risks, and speculative improvements.

## Review dimensions

### Visual quality
- Hierarchy, alignment, spacing rhythm, typography, contrast, icon consistency, color restraint, component consistency, content density, and whitespace.
- Look for accidental card nesting, redundant borders/dividers, decorative elements, inconsistent radii, arbitrary shades, overuse of pills/badges, and unnecessary helper text.
- Check real content, long labels, localization-like text expansion, large numbers, and empty slots—not only ideal mock content.

### Usability
- Can the user identify the current location, purpose, next action, and outcome?
- Are controls discoverable and predictable?
- Are errors actionable and recoverable?
- Are loading, empty, no-results, stale, denied, and failure states clearly distinguished?
- Are important actions close to the content they affect without being duplicated everywhere?

### Responsive behavior
- Inspect desktop, compact desktop, tablet, and mobile. Suggested test widths: 1440, 1280, 1024, 768, and 390 px, plus intermediate widths.
- Check overflow, clipped text, collapsed navigation, table strategy, dialog bounds, sticky controls, keyboard visibility, and browser zoom.
- Desktop is primary; mobile remains a first-class usable adaptation.

### Interaction and accessibility
- Test keyboard tab order, visible focus, Escape, browser back/forward, form validation, disabled/loading states, pointer hover, dialogs, and menu behavior.
- Check semantics and meaningful labels for critical controls.
- Verify reduced-motion behavior where motion is used.

### Performance
- Look for slow initial render, jank, excessive rebuilds, large eager grids, expensive effects, and unnecessary network/image work.
- Measure before recommending performance refactors.

## Screenshot comparison protocol

- Capture the same route, viewport, browser zoom, data fixture, and UI state before/after.
- Compare hierarchy, spacing, alignment, text wrapping, clipping, state visibility, and responsive composition.
- Use representative realistic data and include at least one edge case.
- Do not compare screenshots captured at different widths or different states as if they were a valid regression pair.

## Severity ranking

- **Critical:** user cannot complete a core task, data/action meaning is unsafe, or access/academic correctness is misrepresented.
- **High:** major workflow friction, inaccessible core action, responsive breakage, hidden important information, or serious visual defect.
- **Medium:** repeated inconsistency, confusing hierarchy, avoidable extra steps, minor overflow, or weak feedback.
- **Low:** cosmetic polish with little effect on comprehension or task completion.

Rank no more than the highest-impact findings first. Avoid long wish lists.

## Required report

- Scope and evidence reviewed (routes, screenshots, viewport sizes, browser, test type).
- Strong elements worth preserving.
- Findings ranked by severity, each with location, observed evidence, user impact, and recommended correction.
- Separate confirmed defects from hypotheses and unverified areas.
- 1–3 next actions with concrete acceptance criteria.
- Files/tests changed or run, if implementation was explicitly authorized.

Do not change code during a review-only task. Do not claim screenshots were inspected unless they were actually available and viewed.
