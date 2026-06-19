# Whole-Diff Commit Guidelines

Use this rubric when the user explicitly wants the entire current working tree diff committed.

## Primary Rules

- Whole working tree scope, only when explicitly requested
- Multiple atomic commits, not one omnibus commit
- Conventional Commit messages only
- Stage only explicit paths
- Check `git status` before every commit
- Re-check `git status` after every commit

## Instruction Hierarchy

Apply commit rules from most general to most specific:

1. User instruction in the current thread
2. Your agent's global instruction file (e.g. `~/.codex/AGENTS.md` for Codex, or the equivalent for your agent)
3. Repo `AGENTS.md`
4. Repo docs such as `docs/RELEASING.md` or changelog notes
5. Local skill guidance

Lower layers cannot weaken a higher-layer atomic-commit rule.

## Scope Rules

- Use only when the user explicitly wants the full outstanding diff committed
- Do not narrow scope back to current-session files
- Exclude any path the user explicitly said to leave out
- If the user did not clearly ask for the whole diff, use the session-only commit skill instead

## Helper Hierarchy

Preferred commit helper order:

1. If your repo or environment provides a commit helper script (e.g. a project-local `scripts/committer`), prefer it
2. Otherwise use manual explicit git commands

Before using any shell helper, validate it with `bash -n`. The manual git commands are always a safe fallback.

## Atomic Commit Heuristics

Split commits by:

- distinct user-visible behavior
- separate infra or tooling changes
- docs vs code
- shared config vs repo-local code
- unrelated untracked additions

Do not split so far that a commit stops building conceptually, but do not merge changes that would be easier to review separately.

## Safe Manual Fallback

When no helper is usable:

1. identify one commit group
2. `git add -- <explicit paths>`
3. `git commit -m "<type>: <summary>" -- <explicit paths>`
4. `git status --short`
5. repeat

## Review Checklist

- Did I verify the user asked for the whole diff?
- Did I accidentally collapse unrelated changes into one commit?
- Should this diff be 2+ commits instead of 1?
- Does the message match the actual change?
- Did I use a validated helper, or a safe manual fallback?
