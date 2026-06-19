---
name: commit-whole-diff
status: drafting
version: 0.3.0
tags: [git, commits]
updated: 2026-06-16
description: Split the entire current git working tree diff into multiple atomic Conventional Commits when the user explicitly wants all outstanding changes committed, including work outside the current session.
---

# Commit Whole Diff

Commit the whole outstanding diff. Still atomic. Never omnibus.

## Do This First

- Read [references/commit-guidelines.md](references/commit-guidelines.md).
- Read the active instruction stack before committing:
  - your agent's global instruction file (e.g. `~/.codex/AGENTS.md` for Codex, or the equivalent for your agent)
  - repo `AGENTS.md`
  - release or changelog docs when relevant
- Run `git status --short` and inspect the full diff before deciding commit groups.

## Use This Only When

- the user explicitly says "whole diff"
- the user explicitly says "everything outstanding"
- the user explicitly says "commit all current changes"

If the user wants only the work from this session, use the `commit` skill instead.

## Commit Hierarchy

Always apply this order:

1. User instruction
2. Your agent's global instruction file (e.g. `~/.codex/AGENTS.md` for Codex, or the equivalent for your agent)
3. Repo `AGENTS.md`
4. Repo docs and release docs
5. This skill

If any higher layer says "multiple atomic commits", treat that as mandatory.

## Scope Rules

- Scope: the entire current working tree diff the user asked to commit
- Current-session boundaries do not limit this skill
- Still exclude files the user explicitly said not to include
- If destructive cleanup would be needed to make the diff commitable, stop and ask

## Helper Selection

Use the first valid option:

1. If your repo or environment provides a commit helper script (e.g. a project-local `scripts/committer`), validate it first with `bash -n <path>` and prefer it
2. Otherwise use manual explicit `git add -- <paths>` plus `git commit -m "<type>: <summary>" -- <paths>`

If a helper is missing or invalid, say so briefly and fall back to the manual git commands.

## Workflow

1. Inspect `git status --short`
2. Partition the full working tree into logical groups
3. Check each group for hidden mixed concerns
4. Pick a Conventional Commit type per group
5. Stage only that group's paths
6. Commit that group
7. Re-run `git status --short`
8. Repeat until the requested whole diff is committed or until user guidance is needed

## Grouping Rules

- One commit per coherent purpose
- Separate skills/config/scripts/docs/app code when they are independently reviewable
- Keep generated or lockfile changes with the change that required them
- Do not collapse unrelated untracked directories into one commit for convenience
- If a file spans multiple concerns, group by the dominant user-visible change

## Message Rules

- Use Conventional Commits only: `feat|fix|refactor|build|ci|chore|docs|style|perf|test`
- Keep the summary short and specific
- Do not add scope unless it improves clarity
- Prefer one-line messages

## Output Expectations

When the user asks to commit:

- Tell them the planned commit groups before committing if the split is non-trivial
- Call out helper choice if you could not use the preferred one
- Report the resulting commit SHAs and messages

## Fallback Notes

If no helper is available:

- Stage explicit paths only
- Use non-interactive `git commit -m ... -- <paths>`
- Re-check status after every commit
- Never use `git add .` or `git add -A`
