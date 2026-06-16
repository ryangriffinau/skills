---
name: goal-plan
status: drafting
version: 0.3.0
tags: [planning, goals, agents]
updated: 2026-06-16
description: Create crisp, verifiable goal prompts and execution plans for long-running Codex work after investigating available context first. Use when the user asks to set, shape, prepare, refine, or plan a goal, mentions /goal or goal mode, asks for acceptance criteria, or wants an agent goal that can run for hours or days.
---

# Goal Plan

Use this skill to turn a fuzzy ambition into a goal the agent can actually finish. The output should be a clear goal statement plus enough operating guidance for execution, measurement, progress tracking, and final review.

For UI or visual goals, also apply [UI_VISUAL_ACCEPTANCE.md](UI_VISUAL_ACCEPTANCE.md).

## Core Rule

Do not ask the user anything until you have done pre-investigation.

Before questions, inspect all available local context that could answer them: repo docs, existing plans/specs, code, tests, config, current git state, issue tracker context, linked artifacts the user provided, and relevant existing skills. If a question can be answered by investigation, answer it yourself.

Ask the user only when an answer cannot be discovered, materially changes the goal, or requires permission, credentials, budget, production access, destructive action, or a product judgment. Ask one question at a time and include your recommended answer.

The most important output is closed acceptance criteria. Before setting or handing off a goal, resolve every known branch that could change what "done" means. Do not leave alternatives like "maybe include X", "depending on Y", or "probably good enough" inside the goal. Either decide the branch from evidence, ask the user to decide it, or mark the goal blocked until it is resolved.

## Workflow

1. Investigate first
   - Identify the actual desired outcome, not just the requested activity.
   - Find existing constraints, owner docs, related specs/issues, test commands, deployment surfaces, and known risks.
   - Check whether the environment needed for the goal is realistic or only a local approximation.
   - Note what is measurable now and what measurement tooling may need to be created.

2. Resolve goal shape
   - State the smallest useful finish line.
   - Prefer concrete numbers, parity checks, pass/fail criteria, or named artifacts.
   - Define what does not count as success, especially shortcuts that could game the metric.
   - Walk the acceptance-criteria decision tree until no open branches remain.
   - Record resolved constraints: scope boundaries, target surfaces, quality bar, exclusions, allowed shortcuts, forbidden shortcuts, and required evidence.
   - For visual goals, avoid pure "pixel perfect" criteria unless visual diff tooling and non-visual requirements are also defined.
   - For UI goals, close the specific visual acceptance branches in [UI_VISUAL_ACCEPTANCE.md](UI_VISUAL_ACCEPTANCE.md).

3. Build the goal packet
   - Goal: one concise sentence suitable for `/goal`.
   - Acceptance criteria: objective checks that decide completion.
   - Starting context: files, docs, routes, systems, commands, and suspected hotspots to inspect first.
   - Measurement plan: how progress will be measured, including smoke checks, full checks, benchmarks, evals, screenshots, logs, or artifacts.
   - Environment plan: the most realistic available environment, required access, fallback branches, and any local/prod differences.
   - Progress tracking: meaningful checkpoints, commits/PRs/status artifacts, or external updates if requested.
   - Receipt: what evidence must be saved at the end, such as metrics, logs, screenshots, result files, links, or a summary doc.
   - Skeptical review: final audit angles and cleanup checks before calling the goal complete.
   - Resolved branches: key decisions that clarify scope and acceptance criteria, with the source of each decision.

4. Question loop, if needed
   - Ask the highest-leverage unresolved question first.
   - Provide your recommended answer and explain the tradeoff briefly.
   - After the user answers, update the goal packet rather than restarting.
   - Continue until the goal is executable, verifiable, and free of open acceptance-criteria branches.

5. Set or hand off the goal
   - If the user explicitly asked you to set the goal and a goal tool is available, create it only after the packet is coherent.
   - Otherwise provide the exact `/goal` text and the supporting execution plan.

## Goal Quality Checklist

- The goal has a finish line the agent can test.
- Every known branch that changes acceptance criteria has been resolved.
- Outcome constraints are explicit: in scope, out of scope, quality bar, evidence required, and unacceptable shortcuts.
- UI or visual goals have explicit target screens, states, responsive sizes, design constraints, behavior checks, and screenshot/browser evidence.
- The plan starts from investigated evidence, not user interrogation.
- The agent has a realistic environment or a clearly documented fallback.
- Progress is measurable before the long run begins.
- Smoke mode and full mode are separated when a job may be expensive or slow.
- The plan includes a durable receipt, not only terminal output.
- The final step includes skeptical review and cleanup of failed attempts.
- The goal avoids incentives to pass by reducing scope, weakening tests, hiding failures, or faking visuals.

## Example Output Shape

```md
Goal:
Reduce production-like build plus deploy preview time by 30% without disabling existing build paths or weakening tests.

Acceptance criteria:
- Baseline and final timings are captured from the same deploy-preview path.
- Final median time across 3 runs is at least 30% lower than baseline.
- Existing typecheck, build, and relevant tests still pass.
- No build paths, tests, telemetry, or validation are removed to hit the metric.

Starting context:
- Inspect docs/tooling/deploy.md, CI config, build scripts, and recent deploy logs first.

Measurement plan:
- Capture a baseline receipt, make one tracer change at a time, run smoke checks locally, then remeasure in the preview environment.

Receipt:
- Save baseline/final timings, commands, deploy links, changed files, and residual risks in the handoff summary.

Skeptical review:
- Review for hidden scope reduction, cache-only wins, flaky timing, and cleanup of failed experiments.
```
