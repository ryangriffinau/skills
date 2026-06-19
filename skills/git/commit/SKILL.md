---
name: commit
status: drafting
version: 0.3.0
tags: [git, commits]
updated: 2026-06-16
description: Create Conventional Commit git commits for only the work completed in the current session. Use when the user asks to commit your changes, but not the repo's whole outstanding diff, and you need to keep unrelated pre-existing work out of the commit.
---

# Commit

Commit only current-session work. Never pull unrelated pre-existing changes into the commit.

## Do This First

- Read [references/commit-guidelines.md](references/commit-guidelines.md).
- Read the active instruction stack before committing:
  - your agent's global instruction file (e.g. `~/.codex/AGENTS.md` for Codex, or the equivalent for your agent)
  - repo `AGENTS.md`
  - release or changelog docs when relevant
- Run `git status --short` and inspect the full diff before deciding commit groups.
- Identify which paths were edited, created, or intentionally updated in the current session.

## Commit Hierarchy

Always apply this order:

1. User instruction
2. Your agent's global instruction file (e.g. `~/.codex/AGENTS.md` for Codex, or the equivalent for your agent)
3. Repo `AGENTS.md`
4. Repo docs and release docs
5. This skill

If any higher layer says "multiple atomic commits", treat that as mandatory.

## Scope Rules

- Default scope: only files changed in the current session
- Do not commit pre-existing modified or untracked files you did not work on in this session
- Include outside-session files only if the user explicitly says to include them
- If session ownership is unclear after checking the thread and diff, stop and ask

## Helper Selection

Use the first valid option:

1. If your repo or environment provides a commit helper script (e.g. a project-local `scripts/committer`), validate it first with `bash -n <path>` and prefer it
2. Otherwise use manual explicit `git add -- <paths>` plus `git commit -m "<type>: <summary>" -- <paths>`

If a helper is missing or invalid, say so briefly and fall back to the manual git commands.

## Workflow

1. Inspect `git status --short`
2. Mark the current-session paths you own
3. Exclude all unrelated pre-existing paths
4. Split owned paths into logical groups by purpose and risk
5. Check each group for unrelated files
6. Pick a Conventional Commit type per group
7. Stage only that group's paths
8. Commit that group
9. Re-run `git status --short`
10. Repeat until your current-session groups are committed or until user guidance is needed

## Grouping Rules

- One commit per coherent purpose
- Session-owned files only
- Separate skills/config/scripts/docs/app code when they are independently reviewable
- Keep generated or lockfile changes with the change that required them
- Do not mix unrelated untracked directories into an existing change just because they are present
- If a file spans multiple concerns, group by the dominant user-visible change

## Message Rules

- Use Conventional Commits only: `feat|fix|refactor|build|ci|chore|docs|style|perf|test`
- Keep the summary short and specific
- Do not add scope unless it improves clarity
- Prefer one-line messages

## Output Expectations

When the user asks to commit:

- Tell them the planned commit groups before committing if the split is non-trivial
- Call out which repo changes were intentionally left out because they predated this session
- Call out helper choice if you could not use the preferred one
- Report the resulting commit SHAs and messages

## Fallback Notes

If no helper is available:

- Stage explicit paths only
- Use non-interactive `git commit -m ... -- <paths>`
- Re-check status after every commit
- Never use `git add .` or `git add -A`
