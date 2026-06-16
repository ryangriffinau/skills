---
name: pr-closeout
status: drafting
version: 0.3.0
tags: [git, github, cleanup]
updated: 2026-06-16
description: Audits open GitHub pull requests against active Codex sessions, worktrees, branches, and local task trackers, then recommends a closeout action for every PR. Use when the user asks to clean up PRs, find orphaned PRs, match PRs to sessions, reconcile open pull requests, or decide what to close, merge, leave open, or port between staging/main.
---

# PR Closeout

## Quick Start

Use this skill to turn a messy open-PR list into a tracked closeout plan. The required output is a recommendation for every open PR, not only the obvious stale ones.

Default posture:

- Inventory first; do not act from memory or screenshots alone.
- Prefer evidence over title matching.
- Do not close or merge unless the user has explicitly approved that action or the current request clearly delegates it.
- Keep user-owned/current-session work open by default.
- Treat older PRs as candidates for closeout, not automatic trash.

## Workflow

1. Load repo rules.
   - Read the repo `AGENTS.md` and required global agent rules.
   - Check whether the repo uses a nonstandard PR base, task tracker, or commit/merge policy.

2. Collect sources of truth.
   - Open PRs: number, title, author, base, head branch, draft state, mergeability, created/updated timestamps, changed files, body.
   - Codex sessions: active/recent thread titles, status, cwd, preview.
   - Local git state: worktrees, local/remote branches, current branch, dirty state.
   - Task/progress state: `.backpocket/orchestrator/tasks/*.json`, `docs/specs/**/PROGRESS.md`, or repo equivalent.
   - Optional: CI/check state and PR comments when deciding merge readiness.

3. Build an evidence map.
   - Match by exact branch first.
   - Then match by task id, spec path, changed files, PR body references, thread title, and worktree path.
   - Record uncertainty explicitly; do not collapse weak matches into confident matches.

4. Classify every PR.
   - `current-session`: directly tied to an active or recent live session.
   - `task-backed`: has task/spec/worktree evidence but no visible live session.
   - `owner-backlog`: owned by another person/account or an external workstream.
   - `stale-orphan`: no active session, no current task evidence, old or superseded.
   - `unknown`: insufficient evidence; requires owner/user decision.

5. Recommend one action for every PR.
   - `leave-open`: active work, intentionally parked, or user says not to touch.
   - `close-unmerged`: redundant, superseded, obsolete draft, or no longer useful.
   - `merge-to-base`: small, mergeable, relevant, and target base is correct.
   - `port-to-other-base`: relevant change belongs on another branch too, usually staging/main.
   - `rebase-or-recreate`: relevant but stale/conflicted/noisy.
   - `ask-owner`: another owner or business decision needed.
   - `do-not-touch`: user explicitly protected it.

6. Act only after authorization.
   - Restate the PR number, target action, and reason before mutating GitHub.
   - After closing/merging/creating a PR, re-read PR metadata and report the resulting state and SHA/URL.
   - Never delete branches as part of this skill unless the user explicitly authorizes branch deletion.

## Recommendation Heuristics

Use the rubric in [recommendation-rubric.md](recommendation-rubric.md) when the answer is not obvious.

Strong patterns:

- If the user says “leave open” or “do not touch,” mark `do-not-touch`.
- If a planning PR is old and the durable docs/workstream have moved on, recommend `close-unmerged`.
- If a workflow/docs PR may have been absorbed elsewhere, verify the exact essence on both intended bases before closing.
- If a cleanup PR only marks a completed task done, merge it only where the underlying work exists.
- If an in-progress product/spec PR has a live or recent session, recommend `leave-open`.
- If a PR is from another owner, recommend `ask-owner` unless the user clearly owns the decision.

## Output Format

Start with the global count and highest-risk loose ends.

Then provide a table with:

- PR number and title
- base/head
- owner
- evidence match
- recommendation
- confidence
- reason
- proposed next action

End with a tracked action list:

- `Protected / leave open`
- `Ready to close`
- `Ready to merge`
- `Needs port`
- `Needs owner decision`
- `Unknown`

If actions were taken, include a compact audit log with PR number, action, result, and merge SHA or close state.
