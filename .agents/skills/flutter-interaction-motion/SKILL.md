---
name: flutter-interaction-motion
description: Design and implement purposeful Flutter interaction states, transitions, feedback, gestures, and motion for UniVerse without sacrificing speed, clarity, or accessibility.
---

# UniVerse Interaction and Motion

## Principle

Motion should explain a state change, preserve spatial context, provide feedback, or make an interaction feel responsive. It must never be required to understand content or complete a task.

## Interaction contract

For every interactive component, define:
- Idle/default state.
- Hover (web), focus, pressed, selected, disabled, loading, success, and error states as applicable.
- Keyboard and pointer behavior.
- Whether the action is immediate, reversible, destructive, or asynchronous.
- Feedback and recovery behavior.

Use familiar affordances. A visual control must behave as users expect; avoid clickable-looking decoration and invisible hit areas.

## Motion rules

- Prefer short, restrained transitions. Typical starting ranges: 120–200 ms for small state changes and dropdowns; 180–280 ms for larger panel/page transitions. Tune to context and platform; these are not laws.
- Use ease-out for entrances, ease-in for exits, and ease-in-out for state movement where it feels natural.
- Avoid bounce/elastic motion for routine academic workflows unless it communicates a meaningful physical interaction.
- Keep exits slightly faster than entrances when that improves perceived responsiveness.
- Use stagger sparingly and only for meaningful grouped content; do not delay access to controls while rows animate in.
- Avoid animating layout properties across large, dense tables when it causes expensive relayout or visual instability.
- Respect reduced-motion preferences when available and provide an equivalent non-motion state transition.
- Never use pulsing, shaking, flashing, or continuous motion as the only signal of status or urgency.

## Feedback and micro-interactions

- Buttons: clear hover/focus/pressed/disabled/loading feedback; prevent duplicate submission while pending.
- Forms: show validation close to the field and preserve entered values after recoverable errors.
- Async tasks: show honest progress or indeterminate loading; expose cancellation/retry when supported.
- Success: concise confirmation tied to the completed action; a subtle transition is optional, not mandatory.
- Menus/dialogs: open from a clear trigger, maintain focus, close predictably, and return focus to the trigger.
- Sticky actions: ensure they do not cover fields, table rows, browser controls, or keyboard focus.

## Flutter implementation

- Reuse existing animation utilities, duration tokens, and shared components where available.
- Prefer AnimatedSwitcher, AnimatedContainer, implicit animations, or explicit AnimationController only when appropriate to the interaction and performance profile.
- Dispose controllers/listeners correctly; avoid creating controllers repeatedly during build.
- Keep animation state separate from business state where possible.
- Do not animate authoritative data values in a way that could imply false intermediate values.
- Avoid adding packages for simple transitions already supported by Flutter.

## Review questions

- What information does this motion communicate?
- Would the interaction remain clear with animation disabled?
- Does it make the task faster or merely more theatrical?
- Does it delay input, create layout shift, distract, or increase CPU/GPU work?
- Does it work with keyboard, screen readers, and reduced-motion settings?
