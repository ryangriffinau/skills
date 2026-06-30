# Agent Flywheel — working cheat-sheet (human)

The day-to-day loop. A **core artifact layer** (Agent Mail + Beads) plus an optional **NTM swarm layer** for running many agents at once. **One-time install & config live in [`setup.md`](./setup.md)** — do that first on a new machine or repo.

> **Golden rule: one shared working tree, one branch, no git worktrees.** Agents coordinate by reserving files through Agent Mail; worktrees defeat that and are never used.

---

## 1. Mental model

| Layer | Tools | Role |
|---|---|---|
| **Core** | **Agent Mail**, **`br`** (beads), **`bv`** (viewer) | file-lease coordination · the task graph · graph-aware triage |
| **Multipliers** | **NTM** (tmux room), **DCG** (destructive guard), **UBS** (bug scan), **CASS** (session memory) | speed, safety, quality, recall |
| **Human layer** | **Linear** | where features originate + ship-status lives (a one-way projection of beads) |

The core loop runs with just Agent Mail + `br` + `bv` and a couple of agents; **NTM is the room you open to run several agents at once.**

**Watch progress with bare `bv`** — the interactive TUI of the whole graph. (`bv --robot-*` is JSON *for agents*, not for you; `br epic status` is a one-off text check.)

---

## 2. The workflow (6 stages) — and what NTM covers

| Stage | What happens | NTM? |
|---|---|---|
| 1 · **Plan** | brain-dump → sharpen → competing plans → synthesize → stress-test | only the optional parallel-draft step |
| 2 · **Encode** | turn the final plan into a Beads graph | no (CLI) |
| 3–5 · **Triage / Implement / Close** | claim → reserve → code → test → review → close, looping | **yes — the swarm** |
| 6 · **Ship** | commit → PR → merge → changelog → close Linear | partly |

### Stage 1 — Plan (highest-leverage; spend real effort here)
1. **Brain-dump → brief:** sharpen with **`/grill-me`** or **`/grill-with-docs`** (`/p-idea-wizard` if the feature isn't chosen yet). No template — it's conversational.
2. **Pull prior context:** `cass pack --robot "<topic>"` — reuse past decisions instead of re-deriving.
3. **Competing plans:** run **`/p-draft-plan`** in several strong models (GPT Pro, Opus, Gemini, Grok) — or in parallel agents via `ntm spawn <name> -t parallel-explore`.
4. **Synthesize:** **`/p-synthesize-plans`** → one hybrid plan.
5. **Stress-test:** **`/p-reality-check`** + **`/p-pre-mortem`**. Save it in-repo (`docs/specs/<x>/plan.md`).

### Stage 2 — Encode
**`/p-plan-to-beads`** → epics/tasks via `br`, with deps + self-contained comments. Verify: `bv` (the TUI), or `bv ready`.

### Stages 3–5 — the swarm
Each agent loops: `bv` → reserve files via Agent Mail → `cass pack` → implement + test → `ubs --staged --fail-on-warning` → **`/p-fresh-eyes-review`** → `br close` → **commit + push immediately** (§4). Launch + monitor in §3.

---

## 3. Launch & monitor the swarm

**Before you spawn:** ensure Codex *and* Claude are current + logged in. A stale Codex **self-updates on first launch** ("Please restart Codex"), drops every pane to the shell, and your `--init-prompt` then gets typed into zsh. Quick check: `echo ok | codex exec` returns text, and `claude` is logged in.

```bash
# Generate the full, profile-aware launch recipe.
bash <skill>/scripts/flywheel-kickoff.sh <name> --plan docs/specs/<x>/plan.md --cod 2 --cass "<area>"
```

Run the printed `ntm spawn ...` line with the Claude supervisor included from the start (`--cc=1`, or a cc-inclusive recipe such as `review-team` / `balanced`). The generator reads `.flywheel/profile` once and bakes in the repo mode, detected package manager, one-shared-tree rule, controller brief, and 0/N-ready recovery note.

Raw fallback form, useful for understanding or if the generator is unavailable:
```bash
# Paste as ONE line (blank lines between continuations drop the flags).
ntm spawn <name> --cod=2 --assign --strategy=dependency --cass-context "<area>" \
  --cc=1 \
  --init-prompt "Follow AGENTS.md. Run /p-deep-project-primer first. Plan: docs/specs/<x>/plan.md. Loop: bv → reserve files via Agent Mail → cass pack --robot \"<topic>\" → implement + test → ubs --staged --fail-on-warning → fresh-eyes review → br close → commit AND push immediately. Then claim the NEXT ready bead and repeat until bv is empty. ONE shared tree, NEVER worktrees. Commits: lowercase subject + valid scope; docs/specs needs frontmatter."
```

**⚠ Things that bite at launch — check every run:**
- **Agents `0/N ready` at spawn** (Codex/Claude boot slowly, or Codex just auto-updated → panes fell to the shell): ntm sends the init-prompt + assignment to **0 agents**. If a pane shows the shell after a Codex self-update, `ntm respawn <name> --type=cod --force` (or kill + re-spawn) first; then once the panes are in their agent TUI, re-feed: `ntm send <name> --cod "<kickoff>"` and `ntm coordinator assign <name>`.
- **Continuous assignment:** `--assign` is *one-shot*. With `[coordinator] auto_assign = true` (setup.md §A.3) the coordinator keeps feeding ready beads; otherwise it **stalls after the first wave**. Workers also self-claim via `br ready` if the kickoff says to — `Idle Agents: 0` usually means they're busy, not stuck.
- **Spawn the Claude supervisor from the start.** Reliable path: `ntm spawn <name> --cc=1 --cod=N ...` (or a cc-inclusive recipe such as `review-team` / `balanced`). This gives Claude its own fresh pane. `ntm controller <name>` retrofits Claude into an already-running session and is unreliable when pane 1 is a busy Codex worker; use it only as a last-resort manual recovery path.
- **The CC supervisor still needs attention:**
  - Confirm it's **logged in** — a spawned Claude often 401s (`Invalid authentication credentials · Please run /login`). Run `/login` in its pane.
  - It can **park at the "bypass permissions" welcome screen** — focus the pane and accept (don't Ctrl-C).
  - **Feed its coordinator brief with `tmux send-keys`, NOT `ntm send`.** `ntm send` / `--cc` pastes into a Claude pane as `[Image #1]` and is lost. Type it straight in: `tmux send-keys -t <name>:0.<pane> "<brief>"` then `tmux send-keys -t <name>:0.<pane> Enter` (a 2nd Enter may be needed to submit); `tmux list-panes -t <name>` shows pane indices. Or just click into the pane and type.
  - Brief it to **coordinate + review only** (don't claim beads) and to **approve workers' Agent Mail contact requests**.

**Monitor:**
```bash
bv                              # ← the bead progress dashboard (TUI)
ntm dashboard <name>            # agent liveness: token velocity, health, who's stalled
ntm attach <name>               # live panes
ntm coordinator status <name>   # idle agents, conflicts, digests
open http://127.0.0.1:8765/mail # agent messages + active file reservations
```
Steer: `ntm send <name> --cod "<correction>"`. DCG vetoes destructive commands; clear gated ones with `ntm approve`.

> Agents run fully autonomous (`--dangerously-*`). The guardrails are **DCG + Agent Mail leases + a feature branch (never `main`)** — that's what replaces worktree isolation. **Stash unrelated/dirty files before spawning** — a mixed tree makes agents hesitant to commit.

**Teardown (after the run):**
- **Stop the swarm:** `ntm kill <name> --force` (stops controller + workers; prompts without `--force`), then `ntm cleanup` (clears stale temp files). Don't leave a finished swarm running — idle Codex panes burn tokens, and stale locks + accumulated identities clutter the next run. `ntm list` shows what's still live.
- **Leases + identities are disposable** — file leases are advisory and expire when agents exit (no manual release); the whimsical agent identities accumulate harmlessly.
- **Get your local back to a clean `main`** once the PR has merged: stash any runtime stragglers (`.ntm/rate_limits.json`, etc.) with `git stash` (reversible), then `git checkout main && git pull`. The feature branch's commits are already in the squash-merge.

---

## 4. Shipping

- **Commit + push per bead, immediately.** Each agent commits its own small change and pushes the moment a bead closes (unpushed = invisible to other agents; piling up changes creates the "mixed tree" that stalls commits). The lease guard checks reservations on commit.
- **Ship bead follows `.flywheel/profile` mode:** `solo` commits and pushes to the working branch with no PR. `team` opens the PR (`gh pr create`) and sets it **ready**, so CI + the preview env run, then **merge when green** — directly for safe DX / non-prod / template changes, or with user approval otherwise. `gh pr merge <n> --auto --squash` merges the moment checks pass (or `--squash` once they're green). The agent should not block-poll CI; it opens ready, enables auto-merge when available, and lets CI/the human complete. Then **`/pr-closeout`**.
- **Verify:** **`/p-deploy-and-verify`**.
- **Close the loop:** `br changelog` → close the Linear issue. `ntm handoff create <name> --auto` for cross-session continuity.

Make shipping part of the swarm by encoding "open PR / deploy-verify / changelog" as final beads depending on the implementation beads.

---

## 5. No-worktrees enforcement

No built-in guard stops `git worktree add` (DCG allows it). Enforce by: **never** passing `--worktrees` to `ntm spawn`; the AGENTS.md flywheel-protocol line forbidding worktrees; and *(optional)* a custom DCG rule blocking `git worktree add`.

---

## 6. Prompt & skill map

| Step | Prompt / skill |
|---|---|
| Idea → brief | `/grill-me`, `/grill-with-docs`, `/p-idea-wizard` |
| Competing plans → merge | `/p-draft-plan` → `/p-synthesize-plans` |
| Stress-test | `/p-reality-check`, `/p-pre-mortem` |
| Plan → beads | `/p-plan-to-beads` |
| Onboard agents to a repo | `/p-deep-project-primer` |
| Launch swarm | `/p-agent-swarm-launcher`, `ntm spawn --cc=1 ...` (§3) |
| Per-bead quality | `ubs --staged --fail-on-warning`, `/p-fresh-eyes-review` |
| Ship | `/commit`, `/commit-whole-diff`, `/pr-closeout`, `/p-deploy-and-verify` |
