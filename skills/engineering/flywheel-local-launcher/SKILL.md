---
name: flywheel-local-launcher
status: drafting
version: 0.2.0
tags: [agents, flywheel, orchestration, setup]
updated: 2026-06-24
description: Make a local repo ready for the Agent Flywheel and manage its projects_base symlink. Preflight-checks the flywheel stack (Agent Mail, beads, ntm, dcg, cass, ubs), links the repo into NTM's projects_base, and runs per-repo init (beads, ntm hooks, Agent Mail lease guard). Use when onboarding or setting up a repo for multi-agent flywheel work, when a project needs symlinking into projects_base, or to verify the stack before launching a swarm.
---

# Flywheel local launcher

Prepares a single local repo for Jeffrey Emanuel's Agent Flywheel and maintains the flat
`projects_base` symlinks NTM needs. **Strictly local per-repo setup** — it does NOT launch
swarms or wrap `ntm spawn` (use the raw commands in `references/cheatsheet.md` §6 for that),
and it does NOT bootstrap a machine (remote/Linux machines use Emanuel's ACFS; macOS uses
the per-tool `install.sh` list — see `references/cheatsheet.md` §3).

## When to use
- Onboarding a new repo to the flywheel ("set up `<repo>` for the flywheel").
- A project needs to be symlinked into `projects_base` so `ntm spawn <name>` resolves.
- Verifying the stack is installed and the Agent Mail server is up before a swarm session.

## Commands

Run the bundled script `scripts/flywheel-link.sh` from inside the target repo:

| Command | Does |
|---|---|
| `preflight` | Verify stack installed (ntm, agent-mail, br, bv, dcg, cass, ubs, claude, codex) + Agent Mail server on `:8765` + `projects_base` set; report each gap with its fix |
| `link [path]` | Symlink a repo (default: cwd) into `projects_base` under its basename |
| `setup [path]` | `link` + `br init` + `ntm init` + `ntm guards install`, then check AGENTS.md |
| `list` | List projects currently linked into `projects_base` |

Typical onboarding, from inside the repo:
```bash
bash scripts/flywheel-link.sh preflight   # confirm prerequisites + fixes
bash scripts/flywheel-link.sh setup       # link + init this repo
```

## Rules
- **Never auto-edit AGENTS.md.** `setup` only *checks* for the no-worktree / flywheel protocol and prints a suggested snippet; adding it requires explicit user confirmation.
- **No git worktrees.** The flywheel uses one shared working tree; the suggested AGENTS.md snippet enforces this.
- **Local only.** If the stack is missing, point the user at ACFS (remote/Linux) or the install.sh list (macOS) — do not try to install the machine stack from here.
- Idempotent: re-running `link`/`setup` on an already-prepared repo is safe.

## Reference
- `references/setup.md` — **one-time** setup/config: install the stack, per-machine + per-repo setup, the projects/symlink model + one-path rule, and reasoning-effort defaults. Start here on a new machine or repo.
- `references/cheatsheet.md` — the **day-to-day** human workflow: the loop (plan → encode → swarm → ship) and the raw `ntm spawn` / `ntm controller` launch + monitor commands.
- `references/branching-model.md` — branching with no worktrees: trunk-based one-tree coordination, features-as-beads, one-machine vs multiple-machine.

`setup.md` to get going, `cheatsheet.md` for the day-to-day. This skill itself only covers preflight + linking + per-repo init.
