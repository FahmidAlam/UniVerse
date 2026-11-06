---
name: universe-ux-principles
description: Apply product-level UX reasoning to UniVerse screens and workflows. Use when designing, reviewing, simplifying, or changing user journeys, forms, navigation, information hierarchy, defaults, feedback, or decision points.
---

# UniVerse UX Principles

## Purpose

Make UniVerse feel clear, trustworthy, efficient, and predictable for students, teachers, and administrators. Optimize for successful completion of real university tasks—not visual novelty, engagement for its own sake, or e-commerce conversion patterns.

## Before making a design decision

1. Identify the user role, task, context, frequency, and consequence of an error.
2. Map the current journey: entry point, required decisions, inputs, system feedback, success state, recovery path, and exit.
3. Inspect the current implementation and its navigation/state/data contracts. Do not assume a proposed interaction is supported by the backend.
4. Identify the single most important next action and make it visually and behaviorally clear.
5. Remove unnecessary decisions, repeated information, avoidable navigation, and fields that can be safely inferred.
6. Preserve user control: explain consequential actions, allow correction before submission, and provide a recoverable path where possible.

## Core principles

- **Clarity before cleverness:** use familiar labels and explicit actions. Avoid ambiguous icon-only controls for important tasks.
- **Hierarchy follows the task:** organize information by what users need to decide or do next, not by the database schema or component hierarchy.
- **Progressive disclosure:** show essential information first; reveal advanced options when they become relevant. Do not hide critical warnings or constraints.
- **Good defaults:** preselect only when the default is safe, reversible, contextually justified, and visible. Never silently choose a consequential academic value.
- **Honest progress:** show actual completion or processing progress. Never start at an arbitrary percentage or imply work is complete when it is not.
- **Useful feedback:** every meaningful action should produce a clear pending, success, empty, warning, or error state. Explain what happened and what the user can do next.
- **Error prevention and recovery:** validate near the point of entry, preserve user input after recoverable errors, explain how to fix problems, and confirm destructive or irreversible actions.
- **Consistency without rigidity:** reuse established patterns unless evidence shows they are confusing or unsuitable for the task.
- **Respect attention:** avoid unnecessary prompts, forced tours, fake urgency, engagement loops, and repeated confirmations.

## Psychology: ethical use only

Use cognitive and behavioral principles to reduce effort, not manipulate users:

- Smart defaults: reduce repetitive choices when the default is safe and transparent.
- Goal-gradient/progress feedback: communicate real milestones and remaining steps; do not fabricate an initial completion percentage.
- IKEA effect/personalization: offer useful, optional configuration when it improves ownership or fit; do not add setup work to manufacture attachment.
- Reciprocity: provide useful information without coercing sign-up or disclosure.
- Loss aversion: communicate real consequences neutrally; never manufacture fear or hide equivalent alternatives.
- Contrast: use comparison to explain meaningful differences, not to manipulate perceived value.

## UniVerse-specific UX checks

- Student-facing: timetable readability, fast access to current/relevant information, clear course/section context, useful empty states, and understandable schedule conflicts.
- Teacher-facing: low-friction access to relevant teaching information; avoid admin-only complexity.
- Admin-facing: support dense data work with filters, search, batch actions, clear validation, source traceability, and explicit draft/review/publish states.
- Academic correctness outranks convenience. Never hide unresolved data, silently normalize uncertain source values, or present a draft as published/authoritative.
- Distinguish loading, no data, no results, unavailable service, stale data, and permission denial. These states are not interchangeable.

## Required workflow for material UX changes

For a new screen, material interaction change, or workflow redesign:
1. Inspect the existing screen, routes, shared widgets, theme, role permissions, and relevant requirements.
2. Produce a compact design brief: user/task, proposed hierarchy, interaction sequence, responsive behavior, edge states, and trade-offs.
3. Ask the user to approve material design choices before implementation. Offer a small number of grounded alternatives, not an open-ended questionnaire.
4. Record the approved design contract in the relevant project document.
5. Implement in a bounded scope and verify the whole user journey.

Small defect fixes that preserve an already-approved behavior do not need a new design approval round.

## Do not

- Copy e-commerce conversion tactics into academic workflows without a genuine user benefit.
- Add steps, personalization, defaults, or notifications just to increase engagement.
- Use fake scarcity, dark patterns, deceptive labels, arbitrary progress, or hidden opt-outs.
- Design only the happy path; include loading, empty, error, stale, denied, and recovery states.
- Claim usability improvements without testing the relevant task with realistic data and viewport sizes.

## Deliverable for a UX review

Report: user/task; strongest parts; highest-friction points ranked by impact; evidence or uncertainty; proposed changes; affected states/roles; and acceptance checks. Separate observed defects from hypotheses.
