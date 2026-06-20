---
name: stale-work-audit
status: drafting
version: 0.1.0
tags: [engineering, git, audit, cleanup]
updated: 2026-06-20
description: Audits old agent sessions, stale threads, branches, PRs, worktrees, deployments, and migrated repos against current evidence, then returns a concise grouped status summary without closing anything. Use when deciding whether prior work is complete, stale, superseded, active, in the wrong repo, or needs porting.
---

# Stale Work Audit

Use this skill to review old work and decide what, if anything, still needs attention.

## Core Rules

- Inventory first. Treat thread text as a clue, not truth.
- Stay read-only unless the user separately asks for an action.
- Always look for PRs. Equivalent or superseding PRs are strong staleness evidence.
- Resolve the authoritative repo before judging completion.
- Keep results concise: grouped status, strongest evidence, PRs, confidence, next action.
- Keep repo-specific workflow in the local profile, not in this skill.

## Modes

- `init`: create or update `.agents/stale-work-audit/profile.json` for the current repo.
- `audit`: inspect supplied thread/session context plus configured sources and report status.
- `report`: render a stored audit JSON file into concise Markdown.
- `eval`: run fixture cases when changing this skill.

## Workflow

1. Read local rules such as `AGENTS.md`, `CLAUDE.md`, and docs indexes before auditing.
2. Load `.agents/stale-work-audit/profile.json`; if missing, run init discovery first.
3. Extract candidate work items from the supplied thread, branch, PR, commit, URL, or summary.
4. Collect evidence through configured sources: Git, PRs, docs, deployments, issue/task trackers, and external thread sources.
5. Build the evidence graph before synthesizing.
6. Classify each item using [status-taxonomy.md](references/status-taxonomy.md).
7. Return the concise grouped summary. Include PR links/numbers where found.
8. Do not close, archive, resolve, merge, delete, or mutate any thread, PR, branch, issue, or deployment.

## Local Profile

Follow [profile.md](references/profile.md). The profile records repo-specific choices:

- canonical and deprecated repo hints
- long-lived branch names
- docs/context patterns, including agent instruction files
- PR, deployment, issue/task, and external-thread sources
- output verbosity defaults

## Scripts

```bash
node skills/engineering/stale-work-audit/scripts/audit-work.mjs \
  --repo /abs/repo \
  --profile /abs/repo/.agents/stale-work-audit/profile.json \
  --thread /tmp/thread.md \
  --out /tmp/stale-work-audit.json
```

```bash
node skills/engineering/stale-work-audit/scripts/render-report.mjs \
  --input /tmp/stale-work-audit.json \
  --format markdown
```

```bash
node skills/engineering/stale-work-audit/scripts/eval-stale-work.mjs
```

## Output Contract

Start with the highest-risk loose ends, then grouped results:

- `Done`
- `Done, deploy unverified`
- `Needs port`
- `Superseded`
- `Active`
- `Blocked`
- `Wrong repo / deprecated source`
- `Unknown`

Each item should include one line of reason, confidence, PRs if present, and the next user decision or action.
