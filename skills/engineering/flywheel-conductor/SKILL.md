---
name: flywheel-conductor
status: drafting
version: 0.1.0
tags: [agents, flywheel, orchestration, swarm]
updated: 2026-07-01
description: Drive a flywheel swarm as the conductor — this agent session coordinates codex workers (spawn, poll, triage, unblock, ship) instead of an in-tmux controller pane. Use when the user asks to launch/run/drive a swarm on a beads epic, when p-plan-to-beads has just encoded an epic ready to execute, or to check on / re-kick / adopt a running swarm.
---

# Flywheel conductor

You are the **conductor**: the human-owned agent session that drives a flywheel swarm.
Codex workers in ntm panes are the muscle; you coordinate — spawn, poll, triage, unblock,
ship. You never play an instrument yourself: workers implement beads, scripts observe the
swarm, and you act only on exceptions.

**Terminology — never interchanged:** **conductor** = this session · **controller** = the
forbidden `ntm controller` cc pane (a second same-account Claude client that rate-limits
itself; guard G1) · **coordinator** = ntm's assignment subsystem, which you may drive.

Setup/onboarding belongs to `flywheel-local-launcher`; this skill assumes the repo is
flywheel-ready and consumes the launcher's scripts (`flywheel-link.sh`,
`flywheel-profile.sh`, `flywheel-kickoff.sh`). Exact commands for every action:
[references/commands.md](references/commands.md).

**State (binding):** lease = an Agent Mail file reservation on `.flywheel/CONDUCTOR` ·
journal + certification = `.flywheel/runtime/` (gitignored, append-only JSONL per
[assets/journal.schema.json](assets/journal.schema.json)) · config = `.flywheel/profile`
(committed) · this skill's install dir is never written at runtime. State stays in the
repo; knowledge graduates to the skill (Step 6).

**Quota boundary:** never fan out local same-account model subagents for review, sweeps,
or other parallel grunt work unless the operator explicitly opts in. Encode that work as
beads and let Codex workers execute it (G15).

## Steps

**0 — Enter / re-enter.** Read `.flywheel/runtime/journal.jsonl` if present. Register this
conductor in Agent Mail first and keep the returned `registration_token`; take the conductor
lease with that identity (reservation on `.flywheel/CONDUCTOR`, TTL ~15 min, reason
`conductor <session> <epic>`). Conflict → another conductor is active: report and **stop**.
Granted → if a swarm is live, re-arm the check-in and jump to Step 4 (this is how a fork,
compaction, or teammate adopts an orphaned swarm — G13). If the repo has no
`.flywheel/runtime/certified.json`, route to **certify** (below) with user confirmation.
*Done when: lease held; journal open; check-in armed or consciously not.*

**1 — Preflight (delegated).** Launcher `flywheel-link.sh preflight` green, including the
Codex auth/currency probe that catches interactive self-update prompts before spawning
(G3.5); `ntm config show` prints **no warning** (G2); resolve `.flywheel/profile`;
env-preflight every profile-declared deployment var (generate-and-set self-generated
secrets — names only in the journal; G3); clean tree on the profile's feature branch.
*Done when: every check green or the gap surfaced.*

**2 — Encode check.** The epic exists with ready beads and reality-check + ship closers;
serial chains are enforced by graph deps, not prompts (G11); critical path named. If not:
stop and route to `/p-plan-to-beads`. *Done when: `br ready` ≥ 1 and closers present.*

**3 — Spawn the muscle.** Execute the launcher's `flywheel-kickoff.sh` recipe. Workers'
init-prompt: `/p-agent-swarm-launcher <epic> <branch>` (fallback text:
[assets/worker-kickoff.md](assets/worker-kickoff.md)). **Never `ntm controller`** (G1).
*Done when: panes show the profile effort (default `high`) and a bead is claimed within
one check-in (G6) — spawned ≠ working.*

**4 — Conduct (the loop).** Arm the check-in ([references/check-in.md](references/check-in.md)).
Each wake-up: `conductor-poll.sh | conductor-triage.sh` → act **only on exceptions** (act
cookbook: commands.md; the G8 deep-work-vs-tangent judgment is yours — read the pane tail)
→ append a `checkin` line + any `lesson` lines → renew the lease → re-arm. Never do the
triager's work: no raw pane-reading or bead-listing outside the scripts except a flagged
G8 call; if triage told you too little, improving the script is the lesson. *Done per
wake-up: zero unhandled exceptions, journal appended. Loop exits when: epic 100% closed,
or a documented external block is handed to the user.*

**5 — Endgame + teardown.** Reality-check and ship close as beads through the normal loop.
Before the conductor performs any claimable ship-bead work, gate that bead from workers or
confirm no live worker can claim it; otherwise let a worker own ship and only verify (G14).
Then `ntm kill` + `ntm cleanup`, release the lease, final journal line. *Done when: no
live session; PR link (or the exact block) reported.*

**6 — Write-back.** For every journal `lesson` with `guard_matched: null`: instantiate
[assets/candidate-guard.md](assets/candidate-guard.md) (if `cass` is available, attach
`cass pack --robot "<signal>"` hits; if an existing guard already covers it, strengthen
that guard instead) and file a bead/PR in `ryangriffinau/skills`. *Done when: zero
unmatched lessons.*

## Guard index

Full playbook — signal, diagnosis, fix, evidence: [references/guards.md](references/guards.md).

| Signal | Guard |
|---|---|
| Urge to run `ntm controller`; controller pane ERR/rate-limit | G1 no-controller-pane |
| ntm prints `config load failed`; workers at xhigh | G2 config-valid |
| Bead blocked on a missing deployment env var | G3 env-preflight |
| Codex reports an interactive update before spawn | G3.5 codex-update-preflight |
| Worker hung on a watch/dev command | G4 one-shot-only |
| Worker scanning the filesystem for tooling | G5 exact-tooling |
| Ready beads, zero claims, idle panes | G6 assignment-gap |
| Pane dropped to a shell prompt | G7 respawn-dead-panes |
| Long turn, no commits — deep work or tangent? | G8 hang-vs-deep-work |
| Worker idle while others hold file locks | G9 route-around-locks |
| Bead status contradicts the tree | G10 stale-bead-reconciliation |
| Two workers inside one high-blast-radius chain | G11 serial-chains |
| DCG blocks a clever one-liner | G12 simple-commands |
| Swarm alive, conductor lease expired | G13 conductor-survivability |
| Conductor and worker both touch the ship bead | G14 ship-bead-gating |
| Urge to fan out local model subagents for grunt work | G15 no-subagent-fanout |
| Handing a human a bead id to read/act on | G16 human-tasks-as-chat |
| Prod-fact claim contradicts the dashboard; caveated evidence doc | G17 evidence-integrity |
| Worker claims a human/conductor bead in the readiness gap | G18 gate-human-beads-before-workers |
| Per-bead staged checks pass but the full PR still has warnings | G19 whole-pr-sweep |

## Certify

`scripts/conductor-certify.sh --repo <dir>` — the runnable proof this workflow works here:
sandbox repo → 3-bead env-free epic → one codex worker driven to green → an injected
pane-kill must be detected and respawned within one check-in → writes
`.flywheel/runtime/certified.json`. Auto-routed on first conduct of an uncertified repo
(Step 0); spawns real agents, so confirm with the user first.
