# UI And Visual Acceptance

Use this reference when a goal changes UI, visual design, interaction design, layout, screenshots, canvas, charts, emails, documents, or any other rendered surface. The purpose is to close visual acceptance criteria before long-running work begins.

## Investigate Before Questions

Inspect available context first:

- Current routes, components, screenshots, design docs, tokens, CSS, Storybook, examples, and neighboring screens.
- Existing component library, design system, brand constraints, accessibility patterns, and responsive breakpoints.
- Realistic data states: empty, loading, error, dense, long text, permissions, and edge cases.
- Existing verification tools: browser automation, visual diffs, screenshot tests, accessibility checks, component tests, or manual screenshot conventions.

Ask the user only for decisions that cannot be discovered and that change what "done" means.

## Close These Branches

Resolve each branch before setting or handing off the goal:

- Target surfaces: exact routes, components, emails, documents, canvases, or embeds in scope.
- Target states: default, empty, loading, error, success, disabled, hover/focus, modal/open, dense data, and long-content states.
- Responsive targets: exact viewport sizes and device classes to verify.
- Source of truth: design file, screenshot, existing screen, design-system doc, brand guide, written intent, or user-approved variant.
- Fidelity bar: exact match, design-system-consistent, inspired-by, or functional polish.
- Interaction behavior: clicks, keyboard, forms, navigation, focus, validation, animations, and persistence.
- Accessibility bar: semantic controls, focus states, keyboard path, contrast, reduced motion, labels, and screen-reader expectations.
- Data realism: whether fake data is acceptable, which data shapes must be represented, and what cannot be hard-coded.
- Forbidden shortcuts: cropped screenshots as UI, hiding overflow, weakening tests, removing states, disabling responsiveness, or faking data paths.
- Evidence: screenshots, videos, DOM snapshots, browser console status, visual diff output, test results, or rendered artifact links.

## Acceptance Criteria Pattern

Prefer observable user-facing criteria over implementation details, borrowing the TDD rule: test behavior through public interfaces, not internal structure.

Good UI acceptance:

- A user can complete the primary action on the target route with keyboard and pointer.
- The layout renders without overlap or clipped text at the named viewport sizes.
- The screen uses the existing design tokens and component patterns documented in the project.
- The empty, loading, error, and dense-data states are visible and verified.
- Browser console has no new runtime errors during the checked flow.

Weak UI acceptance:

- The component uses a specific internal class name.
- The DOM tree exactly matches a proposed implementation.
- It looks "modern", "clean", "better", or "pixel perfect" without evidence.
- It passes only because content, states, tests, or responsiveness were reduced.

## Visual Fidelity Rules

Use visual references carefully:

- If exact visual match is required, define the comparison tool, tolerance, viewport sizes, fonts/assets, and acceptable drift.
- If exact match is not required, translate the reference into explicit constraints: structure, hierarchy, density, color roles, typography, spacing, motion, and component behavior.
- For screenshots or videos, identify which elements are requirements and which are inspiration.
- Do not let decorative assets dominate the goal unless the asset itself is the deliverable.
- For charts, maps, canvas, 3D, or generated images, require pixel evidence that the rendered output is nonblank, correctly framed, and representative of expected data.

## Avoid Getting Stuck

Visual goals can pull an agent away from the actual outcome. Add constraints that keep the run moving:

- Prefer feature checklists, design-system adherence, user-flow checks, and rendered screenshots over open-ended "make it match this image" goals.
- Treat images as context unless the user explicitly says exact reproduction is required.
- Name which visual details are not worth chasing, such as tiny icon differences, decorative illustration exactness, stock-image similarity, or one-off shadows.
- Set a fallback for hard-to-recreate assets: use existing product assets, approved icon libraries, generated bitmap assets, or a simple faithful placeholder, depending on the goal.
- Define when to stop iterating visually: after the acceptance checks pass and screenshots show no material layout, hierarchy, brand, or interaction defects.
- If visual diff tooling is required but absent, first create or select the simplest useful comparison method; do not spend the whole goal improving the diff tool unless that is the goal.
- If a reference causes conflict with the product's design system, resolve that branch before implementation instead of oscillating between both.

## Real Context Rule

UI should be judged in the environment where users will see it:

- Prefer verifying on the existing route with real layout chrome, auth state, navigation, and data density.
- If prototyping variants, mount them in the closest real page with a switcher rather than judging isolated mockups when possible.
- If a standalone prototype is unavoidable, state that it is a lower-confidence visual environment and name what must be rechecked after integration.

## Goal Packet Additions

For UI goals, add these fields to the goal packet:

```md
UI acceptance:
- Target surfaces:
- Target states:
- Viewports:
- Design source of truth:
- Fidelity bar:
- Non-goals / stop rules:
- Interaction checks:
- Accessibility checks:
- Forbidden shortcuts:
- Evidence required:

Resolved visual branches:
- [Decision] because [source/evidence].
```
