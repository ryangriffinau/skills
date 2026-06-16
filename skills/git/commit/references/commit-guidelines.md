# Commit Guidelines

Use this rubric when the user asks to commit only the work done in the current session.

## Primary Rules

- Current-session scope only
- Multiple atomic commits, not one omnibus commit
- Conventional Commit messages only
- Stage only explicit paths
- Check `git status` before every commit
- Re-check `git status` after every commit

## Instruction Hierarchy

Apply commit rules from most general to most specific:

1. User instruction in the current thread
2. `~/.codex/AGENTS.md`
3. Repo `AGENTS.md`
4. Repo docs such as `docs/RELEASING.md` or changelog notes
5. Local skill guidance

Lower layers cannot weaken a higher-layer atomic-commit rule.

## Scope Rules

- Commit only files changed in the current session
- Exclude pre-existing unrelated modified or untracked paths
- If unsure whether a path belongs to this session, stop and ask
- If the user wants the entire repo diff committed, use the whole-diff commit skill instead

## Helper Hierarchy

Preferred commit helper order:

1. Local repo `./scripts/committer`
2. Shared ai-config helper at `$AI_CONFIG_HOME/scripts/committer` or `committer` on `PATH`
3. Manual explicit git commands

Before using a shell helper, validate it with `bash -n`.

## Atomic Commit Heuristics

Split commits by:

- current-session ownership
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

- Did I miss a higher-priority commit rule?
- Did I accidentally include unrelated files?
- Did I accidentally include work from before this session?
- Should this diff be 2+ commits instead of 1?
- Does the message match the actual change?
- Did I use a validated helper, or a safe manual fallback?
