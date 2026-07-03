---
name: flywheel-local-launcher
status: drafting
version: 0.3.0
tags: [agents, flywheel, orchestration, setup]
updated: 2026-07-01
description: Make a local repo ready for the Agent Flywheel and manage its projects_base symlink. Preflight-checks the flywheel stack (Agent Mail, beads, ntm, dcg, cass, ubs), links the repo into NTM's projects_base, runs per-repo init, and routes onboarding by first detecting an existing workflow system: Case A migration vs Case B greenfield setup.
---

# Flywheel local launcher

Prepares a single local repo for Jeffrey Emanuel's Agent Flywheel and maintains the flat
`projects_base` symlinks NTM needs. **Strictly local per-repo setup** — it does NOT launch
or drive swarms (that is the **flywheel-conductor** skill, which consumes this skill's
`flywheel-profile.sh` + `flywheel-kickoff.sh` output),
and it does NOT bootstrap a machine (remote/Linux machines use Emanuel's ACFS; macOS uses
the per-tool `install.sh` list — see `references/setup.md` §A.1).

## When to use
- Onboarding a new repo to the flywheel ("set up `<repo>` for the flywheel").
- A project needs to be symlinked into `projects_base` so `ntm spawn <name>` resolves.
- Verifying the stack is installed and the Agent Mail server is up before a swarm session.
- Setup only: to launch **and drive** a swarm, use `flywheel-conductor`.

## Onboarding a repo — "set it up for the flywheel and plan the work"

When asked to onboard/flywheel a repo, **detect any existing workflow/issue/task system FIRST**, then route to Case A or B. Do not skip the detection step.

**1. Detect an existing system** (before touching anything):
- Look for a homegrown orchestrator or task tracker: `.workhorse/`, `.backpocket/`, `.bp/`, `scripts/bp`, `*/orchestrator/tasks/*.json`, `.agents/skills/*` workflow skills, `docs/workflow/`, `docs/agents/`, or `AGENTS.md` sections wiring a custom "workflow" / "artifact" / "issue-tracker" system.
- Quick sweep: `grep -rilE 'orchestrat|workflow|task[-_.]?json|issue[-_.]?tracker|agent[-_.]?skills' AGENTS.md docs/ scripts/ 2>/dev/null` and read `AGENTS.md`.

**2. Route:**
- **Case A — an existing custom system IS present → MIGRATION.** `fw setup` → **audit** the existing system → `/p-draft-plan` the replacement (existing system → Agent Flywheel) → `/p-plan-to-beads` → **swarm** (archive the old system, rewrite `AGENTS.md` to the flywheel protocol, wire docs, verify) → ship. **Archive, never delete** (RULE 1). *(This is exactly the platform-monorepo `bp` and customer-template `.workhorse/.agents` migrations.)*
- **Case B — no existing system → GREENFIELD.** `fw setup` → add the flywheel-protocol `AGENTS.md` snippet (confirm first) → done, the repo is flywheel-ready. Then plan + swarm the repo's actual **feature** work (not a migration).

**3. Always human-confirmed:** which case it is (propose, confirm), and — for team repos — the Linear project mapping (1 beads epic ↔ 1 Linear project).

`fw setup` + `scripts/flywheel-kickoff.sh` make setup + launch near-one-command; the **planning** (`/p-*` pipeline) is the intellectual step this skill does not do.

## Commands

Run the bundled script `scripts/flywheel-link.sh` from inside the target repo:

| Command | Does |
|---|---|
| `preflight` | Verify stack installed (ntm, agent-mail, br, bv, dcg, cass, ubs, claude, codex) + Agent Mail server on `:8765` + `projects_base` set; report each gap with its fix |
| `link [path]` | Symlink a repo (default: cwd) into `projects_base` under its basename |
| `setup [path]` | `link` + `br init` (+ a starter **verification bead**) + `ntm init` + lease guard + `.flywheel/profile`, check AGENTS.md, then run `verify` |
| `verify [path]` | **Success test** — confirm the repo is linked into `projects_base` (so `ntm spawn` resolves it) AND holds a completable bead; the proof the flywheel is live here. (`ntm list` shows active *sessions*, not linked projects — a repo can be flywheel-ready with no running swarm.) |
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
- `references/cheatsheet.md` — the **day-to-day** human workflow: the loop (plan → encode → swarm → ship), how to watch a running swarm, and the pointer to `flywheel-conductor` for launching + driving.
- `references/branching-model.md` — branching with no worktrees: trunk-based one-tree coordination, features-as-beads, one-machine vs multiple-machine.

`setup.md` to get going, `cheatsheet.md` for the day-to-day. This skill itself only covers preflight + linking + per-repo init.
