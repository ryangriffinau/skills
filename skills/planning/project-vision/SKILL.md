---
name: project-vision
status: battle-tested
version: 1.0.0
tags: [planning, vision, alignment]
updated: 2026-06-16
description: Creates and applies root VISION.md files for projects using a lightweight init grill and explicit read/update rules. Use when creating, installing, reviewing, applying, or explicitly updating project vision docs, or when the user mentions VISION.md, vision init, project direction, or auto-injected vision context.
---

# Project Vision

Use this skill to create or apply a compact root `VISION.md`.

## Core Rules

- `VISION.md` owns long-lived project direction.
- Do not put agent autonomy gates in `VISION.md`; put those in repo agent docs.
- Do not use `VISION.md` for roadmap items, sprint plans, implementation status, setup steps, changelogs, or duplicated agent rules.
- Do not update an existing `VISION.md` unless the user explicitly requests a vision update.
- If requested work contradicts `VISION.md`, raise the contradiction and ask whether the vision or work direction should win.

## Modes

- `init`: read local docs, run the lightweight vision grill, then create root `VISION.md`.
- `apply`: read `VISION.md` before substantial planning, product, architecture, UX, or agent workflow work.
- `review`: evaluate whether an existing `VISION.md` is crisp, stable, and correctly placed.
- `update`: only when the user explicitly requests a vision update.

## Installation

1. Follow [WORKFLOW.md](WORKFLOW.md) for init, apply, review, or update mode.
2. Use [REFERENCE.md](REFERENCE.md) for the template, grill prompts, and quality checks.
3. Add one repo-agent instruction to `AGENTS.md`: agents should read `VISION.md` before substantial product, architecture, agent workflow, or planning work, and must not update it unless explicitly requested.
4. If the repo has a docs index, link `VISION.md` as operating context.
5. Keep repo-specific supporting docs under `docs/**`; keep portable workflows under `.agents/**`.

## Quality Bar

- One screen to skim; under 80 lines.
- Specific enough to reject tempting wrong work.
- Stable enough to survive several releases.
- Written as durable constraints and tradeoffs, not aspiration.
- No duplicated backlog, architecture inventory, or procedural rules.
- Includes a real target human, a problem, a solution bet, and at least one durable advantage or constraint.

## Evaluation

Use `evals/evals.json` as regression cases when changing this skill.
