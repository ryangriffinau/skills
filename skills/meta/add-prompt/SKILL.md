---
name: add-prompt
status: drafting
version: 0.3.0
tags: [meta, prompts, tooling]
updated: 2026-06-16
description: >
  Create a new reusable slash-command prompt (the /p-* commands) for Claude Code, Codex, and
  similar clients. Use when the user wants to add or save a prompt, make a "/p-" command, turn
  an instruction into a slash command, or grow their prompt library. Writes the markdown, uses
  a p- prefix by convention, and bridges the prompts directory so it surfaces in each tool.
---

# add-prompt

Turn a reusable instruction into a `/p-<name>` slash command available in Claude Code,
Codex, and similar clients.

## When to use

"Add a prompt that …", "save this as a prompt", "make a /p- command for …", "turn this
into a slash command", "add to my prompt library".

## How the prompt system works

- A prompt is just a markdown file. Each `.md` file in a tool's command/prompt directory becomes one slash command.
- Most clients read prompts from a known directory — e.g. Claude Code from `~/.claude/commands` (global) or `<repo>/.claude/commands` (project), Codex from `~/.codex/prompts`. Check your client's docs for the exact path.
- If you want to keep prompts in **one canonical directory** and share them across tools, point each tool's command dir at that directory with a one-time **directory** symlink. For example, the author keeps prompts in `~/.agents/prompts` and symlinks `~/.claude/commands` and `~/.codex/prompts` to it (and a per-repo `<repo>/.claude/commands` → `<repo>/.agents/prompts` for project scope). Pick whatever canonical location suits you — this is just one layout.
- Because the *directory* is symlinked, a new `.md` file needs no symlink of its own; only the one-time directory bridge has to exist.
- **Naming convention:** this library prefixes every prompt filename with `p-` so typing `/p-` filters the menu to all prompts. Keep it, change it to your own prefix, or drop it — it is a convenience, not a requirement.
- **Scope:** some clients (e.g. Codex) only read global-scope prompts. If a prompt must appear in such a client, create it in the global directory rather than a project one.

## Steps

1. **Settle the spec** (ask only if unclear): a short kebab **name**, a punchy one-line **description** for the dropdown, the **body**, and whether it takes args (`$ARGUMENTS` for the whole tail, `$1 $2 …` positional). By convention this library prefixes the filename with `p-`; keep or drop that to taste.
2. **Pick scope:** global (visible everywhere, default) or project (one repo). Remember global-only clients won't see project-scope prompts.
3. **Create the file** (primary, tool-agnostic path): write `<name>.md` (e.g. `p-<name>.md` if you keep the prefix) into your prompts directory:
   - Global: your canonical global dir (e.g. `~/.agents/prompts/` or directly `~/.claude/commands/`).
   - Project: the repo's prompt dir (e.g. `<repo>/.agents/prompts/` or `<repo>/.claude/commands/`).
   Then, **only if** your client reads from a different directory than where you wrote the file, create the one-time directory symlink so the client picks it up (e.g. `ln -s ~/.agents/prompts ~/.codex/prompts`). If you write straight into each client's command dir, no symlink is needed.
4. **Optional helper (author's fast-path):** if you have the author's helper scripts installed, they do steps 2–3 in one command and ensure the bridges:
   ```bash
   ~/.agents/bin/new-prompt <name> -d "<description>"            # global → all bridged tools
   ~/.agents/bin/new-prompt <name> --project -d "<description>"  # this repo → Claude/Cursor
   ```
   `new-prompt` adds the `p-` prefix and calls `prompts-bridge` (idempotent) to guarantee the directory symlinks. This is optional — the manual path above works without these scripts.
5. **Write the real body** into the file (replacing any scaffolded TODO). Keep it fluff-free; lead with the instruction, then any framing.
6. **Verify:** confirm the file resolves through the client's command dir (for the author's layout, `~/.claude/commands` and `~/.codex/prompts`), then tell the user to type `/<name>` (or `/p-<name>` with the prefix).

## Rules

- Only `.md` files belong in the prompts/command folders — each becomes a command. Keep docs and scripts elsewhere.
- Never delete files; renaming is fine (e.g. to re-prefix).
- If a prompt doesn't show up, the most common cause is a missing or broken directory symlink — recreate the bridge for that client's command dir (the author's helper: `~/.agents/bin/prompts-bridge`, add `--project` inside a repo).
- If you maintain an index/reference of your prompts, keep it as a regular file outside the command dirs so it isn't mistaken for a command.
