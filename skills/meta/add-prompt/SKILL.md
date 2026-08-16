---
name: add-prompt
status: drafting
version: 0.4.0
tags: [meta, prompts, tooling]
updated: 2026-08-08
description: >
  Create a new reusable slash-command prompt (the /p-* commands) for Claude Code, Codex, and
  similar clients. Use when the user wants to add or save a prompt, make a "/p-" command, turn
  an instruction into a slash command, or grow their prompt library. Captures user-provided
  prompt bodies verbatim, writes the markdown, uses a p- prefix by convention, and bridges the
  prompts directory so it surfaces in each tool.
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
- **The canonical dir may be a git checkout.** In the author's layout it is: `~/.agents/prompts` → `<skills-repo>/prompts` in `ryangriffinau/skills`. Writing the file makes the command work locally *and nowhere else* — until it is committed and landed on `main` it is an untracked file that no other machine, agent, or fresh clone will ever see. Creating a prompt is not done until it is on remote `main`.

## Steps

1. **Settle the spec** (ask only if unclear): a short kebab **name**, a punchy one-line **description** for the dropdown, the **body**, and whether it takes args (`$ARGUMENTS` for the whole tail, `$1 $2 …` positional). By convention this library prefixes the filename with `p-`; keep or drop that to taste. If the user already provided the prompt body, treat it as final source text, not draft material to rewrite.
2. **Pick scope:** global (visible everywhere, **default**) or project (one repo). Remember global-only clients won't see project-scope prompts. Global means the canonical prompts dir — in the author's layout, the `ryangriffinau/skills` repo — so the prompt ships with the library instead of living on one machine.
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
5. **Write the real body** into the file (replacing any scaffolded TODO). If the user supplied prompt text, paste that body verbatim: preserve wording, order, line breaks, emphasis, punctuation, and placeholders. Do not tighten, restructure, rename concepts, add missing sections, add `$ARGUMENTS`, or otherwise "improve" the body unless the user explicitly asks for that edit. Only add the required prompt frontmatter around it.
6. **Verify:** confirm the file resolves through the client's command dir (for the author's layout, `~/.claude/commands` and `~/.codex/prompts`), then tell the user to type `/<name>` (or `/p-<name>` with the prefix).
7. **Update the prompt index if this repo maintains one:** add the prompt to `README.md` or the relevant index. Default new prompts to refining (`🟡`) unless the user explicitly says they are battle-tested (`🟢`) or another maturity applies.
8. **Land it on remote `main` — not optional.** Commit the prompt file *and* its index row, then get that commit onto `origin/main`. Report the pushed commit SHA; "created the file" is not a completion claim.
   - Commit **only** the prompt and index row. The canonical dir is a shared checkout: other prompts, `.beads/`, and spec drafts are frequently dirty and belong to someone else's work. Use `git commit -- <paths>`, never `git add -A`.
   - The checkout is usually parked on an unrelated feature branch that is many commits ahead of `main`. Do **not** push that branch to `main`, and do not `git checkout` (it will collide with in-flight local edits). Build the commit directly on `origin/main` with a temp index and push it:
     ```bash
     export GIT_INDEX_FILE="$(mktemp -u)"; git read-tree origin/main
     git update-index --add --cacheinfo 100644,"$(git hash-object -w prompts/p-<name>.md)",prompts/p-<name>.md
     git update-index --add --cacheinfo 100644,"$(git hash-object -w <edited-README>)",README.md
     C=$(git commit-tree "$(git write-tree)" -p origin/main -m "feat(prompts): add p-<name>")
     git push origin "$C:refs/heads/main"
     ```
     Base the README edit on `git show origin/main:README.md`, not the working copy — the branch's README may carry rows that aren't on `main` yet.
   - If the push is rejected (branch protection or a race), fetch and rebuild on the new `origin/main`, or open a PR from a branch cut at `origin/main` and merge it. Never force-push.
9. **Optional suggestions:** after the prompt is added verbatim and verified, you may offer concise, clearly separate suggestions for accretive improvements. Do not apply them unless the user asks.

## Rules

- Only `.md` files belong in the prompts/command folders — each becomes a command. Keep docs and scripts elsewhere.
- The prompt body is user-owned. When a user provides the prompt text, store it verbatim on first creation. Smart suggestions belong in the response after creation, not silently inside the saved prompt.
- Never delete files; renaming is fine (e.g. to re-prefix).
- If a prompt doesn't show up, the most common cause is a missing or broken directory symlink — recreate the bridge for that client's command dir (the author's helper: `~/.agents/bin/prompts-bridge`, add `--project` inside a repo).
- If you maintain an index/reference of your prompts, keep it as a regular file outside the command dirs so it isn't mistaken for a command.
