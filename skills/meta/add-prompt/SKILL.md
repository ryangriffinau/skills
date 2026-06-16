---
name: add-prompt
status: drafting
version: 0.3.0
tags: [meta, prompts, tooling]
updated: 2026-06-16
description: >
  Create a new reusable slash-command prompt (the /p-* commands) for Claude Code and Codex.
  Use when the user wants to add or save a prompt, make a "/p-" command, turn an instruction
  into a slash command, or grow their prompt library. Writes the markdown, forces the p-
  prefix, and ensures the symlink bridges so it appears in both tools.
---

# add-prompt

Turn a reusable instruction into a `/p-<name>` slash command available in Claude Code
and Codex.

## When to use

"Add a prompt that …", "save this as a prompt", "make a /p- command for …", "turn this
into a slash command", "add to my prompt library".

## How the prompt system works

- Canonical files live in `~/.agents/prompts/*.md` (global) or `<repo>/.agents/prompts/*.md` (project).
- They surface via **directory** symlinks: `~/.claude/commands` and `~/.codex/prompts` both point at `~/.agents/prompts`; a per-repo `<repo>/.claude/commands` points at `<repo>/.agents/prompts`.
- Because the directory is symlinked, a new `.md` file needs no symlink of its own — but the bridge symlinks must exist. `~/.agents/bin/prompts-bridge` (idempotent) guarantees them.
- **Naming:** every prompt filename starts with `p-`, so `/p-` filters to all prompts. `new-prompt` adds the prefix automatically.
- **Codex is global-only:** project-scope prompts work in Claude Code (+ Cursor) but not Codex. Make it global if Codex needs it.

## Steps

1. **Settle the spec** (ask only if unclear): a short kebab **name** (no need to add `p-`), a punchy one-line **description** for the dropdown, the **body**, and whether it takes args (`$ARGUMENTS` for the whole tail, `$1 $2 …` positional).
2. **Pick scope:** global (default) or project (`--project`).
3. **Scaffold + ensure bridges in one step:**
   ```bash
   ~/.agents/bin/new-prompt <name> -d "<description>"            # global → both tools
   ~/.agents/bin/new-prompt <name> --project -d "<description>"  # this repo → Claude/Cursor
   ```
   `new-prompt` calls `prompts-bridge` itself, so the symlinks are always in place.
4. **Write the real body** into the created file, replacing the scaffolded TODO. Keep it fluff-free; lead with the instruction, then any framing.
5. **Verify:** confirm the file resolves through `~/.claude/commands` (and `~/.codex/prompts` for global), then tell the user to type `/p-<name>`.

## Rules

- Only `.md` files belong in the prompts folders — each becomes a command. Keep docs/scripts outside (e.g. `~/.agents/PROMPTS.md`, `~/.agents/bin/`).
- Never delete files; renaming is fine (e.g. to re-prefix).
- If links ever look broken, run `~/.agents/bin/prompts-bridge` (add `--project` inside a repo) to repair.
- Full reference: `~/.agents/PROMPTS.md`.
