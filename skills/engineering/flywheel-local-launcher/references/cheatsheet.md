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

```bash
# Paste as ONE line (blank lines between \ continuations drop the flags).
ntm spawn <name> --cod=2 --assign --strategy=dependency --cass-context "<area>" \
  --init-prompt "Follow AGENTS.md. Run /p-deep-project-primer first. Plan: docs/specs/<x>/plan.md. Loop: bv → reserve files via Agent Mail → cass pack --robot \"<topic>\" → implement + test → ubs --staged --fail-on-warning → fresh-eyes review → br close → commit AND push immediately. Then claim the NEXT ready bead and repeat until bv is empty. ONE shared tree, NEVER worktrees. Commits: lowercase subject + valid scope; docs/specs needs frontmatter."
ntm controller <name>     # adds a Claude coordinator/reviewer in pane 1
```

**⚠ Two things that bit us — check them every run:**
- **Continuous assignment:** `--assign` is *one-shot*. With `[coordinator] auto_assign = true` set (setup.md §A.3) the swarm keeps pulling ready beads; otherwise it **stalls after the first wave** — re-feed with `ntm send <name> "loop: claim the next ready bead with bv and repeat"`.
- **The CC controller actually running:** after `ntm controller <name>`, **go to pane 1 and confirm Claude started** — it often parks at Claude Code's *"bypass permissions"* welcome screen. Select **"Yes, I accept"** (don't Ctrl-C). If it's idle/erroring, it isn't reviewing. (The coordinator *service* handles assignment; the controller *agent* handles review — different jobs.)

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

**Tear down a finished run:** `ntm kill <name>` (stops the controller + workers), then `ntm cleanup` (clears stale temp files). Held file leases are advisory and expire when agents exit — no manual release. Don't leave a finished swarm running: idle Codex panes burn tokens and its stale locks + accumulated identities clutter the next run. `ntm list` shows what's still live.

---

## 4. Shipping

- **Commit + push per bead, immediately.** Each agent commits its own small change and pushes the moment a bead closes (unpushed = invisible to other agents; piling up changes creates the "mixed tree" that stalls commits). The lease guard checks reservations on commit.
- **PR + cleanup:** `gh pr create`, then **`/pr-closeout`**.
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
| Launch swarm | `/p-agent-swarm-launcher`, `ntm spawn` + `ntm controller` (§3) |
| Per-bead quality | `ubs --staged --fail-on-warning`, `/p-fresh-eyes-review` |
| Ship | `/commit`, `/commit-whole-diff`, `/pr-closeout`, `/p-deploy-and-verify` |
