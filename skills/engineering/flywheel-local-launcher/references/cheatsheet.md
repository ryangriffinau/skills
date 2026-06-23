# Agent Flywheel — Working Cheat-Sheet

A local adaptation of Jeffrey Emanuel's Agent Flywheel: a **core artifact loop** (Agent Mail + Beads) plus an optional **NTM swarm layer** for running many coding agents at once. Human issue/feature system-of-record is **Linear**; Beads is the agents' execution graph.

> Golden rule: **one shared working tree, one branch, no git worktrees.** Agents coordinate by reserving files through Agent Mail — worktrees defeat that and are never used.

---

## 1. Mental model

| Layer | Tools | Role |
|---|---|---|
| **Core (mandatory)** | **Agent Mail**, **`br`** (beads), **`bv`** (beads-viewer) | Coordination (file leases + messaging), the task graph, and graph-aware triage |
| **Multipliers** | **NTM** (multi-agent tmux room), **DCG** (destructive-command guard), **UBS** (bug scanner), **CASS** (cross-agent session memory) | Speed, safety, quality, recall |
| **Human layer** | **Linear** | Where features/issues originate and ship-status lives |

You can run the entire core loop with just Agent Mail + `br` + `bv` and a couple of agents. NTM is the *room* you open when you want several agents running and watchable at once.

---

## 2. Install policy (how to add any tool, going forward)

```
1. Author offers an official install.sh (curl … | sh)?  → use it for standalone CLI tools.
     (canonical + tested; on Apple Silicon it avoids the Gatekeeper quarantine that
      silently kills un-notarized binaries installed via a third-party brew tap)
2. Else it's a language package (npm / pip / cargo / go)? → use that manager.
3. Considering Homebrew? run:  brew info <name>
      • "<name>: stable … (bottled)" from homebrew/core  → DEFAULT, use brew  (jq, fzf, ripgrep, gh…)
      • install shown as "brew install USER/tap/<name>"   → third-party tap → prefer the author's install.sh
4. Raw binary download → only to pin a version / last resort; you own PATH + updates.
```

**Homebrew remains the correct default for mainstream tools** — keep using it. The only carve-out is indie tools whose canonical channel is their own `install.sh` / a third-party tap (e.g. the whole Dicklesworthstone flywheel stack). `brew info <name>` is the objective test: `homebrew/core` → brew; `user/tap` → install.sh. Never install one tool through two managers.

---

## 3. Per-machine setup (one-time)

The flywheel stack, each via its own `install.sh`:

```bash
# NTM (multi-agent tmux orchestrator)
curl -fsSL "https://raw.githubusercontent.com/Dicklesworthstone/ntm/main/install.sh?$(date +%s)" | bash -s -- --easy-mode
# Agent Mail (coordination server; also installs Beads = br/bv)
curl -fsSL "https://raw.githubusercontent.com/Dicklesworthstone/mcp_agent_mail/main/scripts/install.sh?$(date +%s)" | bash -s -- --yes
# DCG (destructive-command guard; wires into each agent's pre-tool hook)
curl -fsSL "https://raw.githubusercontent.com/Dicklesworthstone/destructive_command_guard/main/install.sh?$(date +%s)" | bash -s -- --easy-mode
# CASS (cross-agent session search / memory)
curl -fsSL "https://raw.githubusercontent.com/Dicklesworthstone/coding_agent_session_search/main/install.sh?$(date +%s)" | bash -s -- --easy-mode --verify
# UBS (bug scanner; wires pre-commit + agent guardrails)
curl -fsSL "https://raw.githubusercontent.com/Dicklesworthstone/ultimate_bug_scanner/main/install.sh?$(date +%s)" | bash -s -- --easy-mode
# fzf (NTM command-palette fuzzy search) — mainstream, so brew is fine
brew install fzf
```

Then:
- Start the Agent Mail server: `am` (one server per machine, `http://127.0.0.1:8765`; leave it running).
- Register Agent Mail's MCP with each agent (the installer auto-wires Claude Code; for Codex use a literal bearer header in `~/.codex/config.toml` so it also works from the GUI):
  ```toml
  [mcp_servers.mcp_agent_mail]
  url = "http://127.0.0.1:8765/api/"
  http_headers = { Authorization = "Bearer <token-from-~/.local/share/mcp_agent_mail/.env>" }
  ```
- Verify the whole stack: `ntm deps` (expect tmux, Claude, Codex, Agent Mail, br/bv, dcg all ✓).
- Set the projects base: `ntm config set projects-base ~/Code/github` (see §9).

---

## 4. Per-repo setup (one-time, every project)

Every repo you run the flywheel in needs three things. The **flywheel-local-launcher** skill (`setup`) does all of them (and links it into `projects_base` — see §9):

```bash
cd <repo> && bash <skill>/scripts/flywheel-link.sh setup   # = symlink into projects_base, then:
#   br init             → creates .beads/  (the git-committed task graph)
#   ntm init            → project-local .ntm + git hooks (beads sync, UBS check)
#   ntm guards install  → Agent Mail pre-commit lease guard (blocks commits onto reserved files)
#   AGENTS.md check     → suggests the no-worktree protocol if missing (never auto-adds)
```

Check the guard later with `ntm guards status`.

---

## 5. The workflow (6 stages) — and exactly what NTM covers

| Stage | What happens | Runs as | NTM? |
|---|---|---|---|
| 1 · **Plan** | brain-dump → sharpen → competing plans → synthesize → stress-test | you, interactive | only the optional *parallel-draft* step |
| 2 · **Encode** | turn the final plan into a Beads graph | one agent / CLI | no |
| 3 · **Triage** | pick the next ready bead | `bv` / NTM | yes (swarm) |
| 4 · **Implement** | claim → reserve → code → test → review | swarm | **yes** |
| 5 · **Close** | close bead, graph reshapes, loop | swarm | **yes** |
| 6 · **Ship** | commit → PR → merge → changelog → close Linear | swarm + you | partly |

So **NTM owns stages 3–6** (the swarm) plus the *optional* parallel-drafting sub-step of stage 1. Stage 1 (mostly) and stage 2 are done by you / a single agent at the CLI.

### Stage 1 — Plan (highest-leverage; spend real effort here)
1. **Front-end (conversational, no template):** brain-dump the idea, then sharpen it into a crisp brief with **`/grill-me`** or **`/grill-with-docs`**. (`/p-idea-wizard` if you don't even have the feature picked yet.)
2. **Pull prior context:** `cass search "<topic>"` or `cass pack --robot "<topic>"` — reuse past decisions/solutions instead of re-deriving.
3. **Competing plans:** run **`/p-draft-plan <brief>`** independently in several strong models (GPT Pro, Claude Opus, Gemini Deep Think, Grok Heavy) — *or* in parallel agents: `ntm spawn <proj> -t parallel-explore --prompt "<brief + draft-plan instruction>"`.
4. **Synthesize:** paste the competing plans into **`/p-synthesize-plans`** (in your strongest model) → one hybrid plan.
5. **Stress-test:** **`/p-reality-check`** + **`/p-pre-mortem`** (or `/p-premortem-planner`). Save the final plan in-repo, e.g. `docs/specs/<x>/plan.md`.

### Stage 2 — Encode
- **`/p-plan-to-beads <final plan>`** (Claude Code / Opus) → creates epics/tasks/subtasks **only via `br`**, with dependencies and self-contained comments.
- Verify: `bv ready` (shows unblocked work), `br graph` (visualize the DAG).

### Stages 3–5 — Triage / Implement / Close (the swarm)
- Launch the swarm per §6. Each agent loops: `bv` (next ready bead) → reserve files via Agent Mail → `cass pack --robot "<bead topic>"` → implement + test → `ubs --fail-on-warning .` → **`/p-fresh-eyes-review`** → `br close`. Closing reshapes the graph; the next agent gets a better map.

### Stage 6 — Ship (see §7)

---

## 6. Launch & monitor the swarm

```bash
# 1) launch the generalist Codex swarm with the flywheel kickoff prompt
ntm spawn <name> --cod=2 --assign --strategy=dependency \
  --cass-context "<area>" \
  --init-prompt "Follow AGENTS.md. Run /p-deep-project-primer first. The plan is at docs/specs/<x>/plan.md. Before each bead run: cass pack --robot \"<topic>\". Loop: pick a ready bead with bv; reserve files via Agent Mail before editing; implement + test; run ubs --fail-on-warning . and a fresh-eyes review; br close. One shared tree on the current branch — NEVER create git worktrees."

# 2) attach a Claude controller to coordinate + monitor the Codex workers
ntm controller <name>
```
`ntm controller` launches a **Claude agent in pane 1** that coordinates the Codex workers, watches for conflicts, and enforces quality — the "Claude monitoring the Codex swarm" pattern.

**Monitor:**
```bash
ntm dashboard <name>              # token velocity, health, who's active/stalled
ntm attach <name>                 # live agent panes
ntm coordinator status <name>     # conflicts + digests; `ntm coordinator enable auto-assign`
ntm conflicts <name>              # file-collision view
ntm git status <name>             # branches + Agent Mail locks + pending changes
open http://127.0.0.1:8765/mail   # the agents' messages + active file reservations
```
Steer: `ntm send <name> --all "<correction>"` (or `--cod`). DCG silently vetoes destructive commands from any agent; clear anything gated with `ntm approve`.

> Agents are launched fully autonomous (`--dangerously-*`). The guardrails are **DCG + Agent Mail leases + working on a feature branch (never main)** — that is what replaces worktree isolation.

---

## 7. Shipping (agent-capable)

Shipping can be handled by the swarm, a final "ship" bead, or you — it's not magic, just steps:

```bash
ntm git status <name>        # confirm locks released, see pending changes
ntm git sync <name>          # pull + push
```
- **Commit:** agents commit per closed bead (the lease guard checks reservations). For a manual pass use **`/commit`** (session-scoped) or **`/commit-whole-diff`** (split the whole diff into atomic commits).
- **PR + cleanup:** open the PR (`gh pr create`), then **`/pr-closeout`** to reconcile PRs against sessions/beads.
- **Verify:** **`/p-deploy-and-verify`** (deploy + check desktop & mobile).
- **Changelog + close the loop:** `br changelog` (from closed beads) → close the Linear issue.
- **Continuity:** `ntm handoff create <name> --auto` → compact YAML of goal/now/blockers for the next session.

To make shipping part of the swarm, encode it as the final bead(s) in stage 2 ("open PR, run deploy-verify, generate changelog") with dependencies on the implementation beads.

---

## 8. No-worktrees enforcement

There is **no built-in guard** that stops an agent creating a worktree (DCG allows `git worktree add` by default). Enforce it by:
1. **Never** passing `--worktrees` to `ntm spawn` (the default is the shared tree).
2. An explicit line in the repo's **AGENTS.md**: *"Work in the single shared tree on the current branch. Never create or use git worktrees; coordinate via Agent Mail file reservations."* (The §6 kickoff prompt also says this.)
3. *(Optional, hard enforcement)* add a custom **DCG rule** to block `git worktree add`.

---

## 9. Adding a new project

NTM resolves `projects_base/<session-name>` one level deep with a flat name, and that name is the Agent Mail project key. Real repos are nested (`Code/github/<org>/<repo>`), so each is exposed as a **flat symlink** directly under `projects_base` (`~/Code/github`). The **flywheel-local-launcher** skill manages this:

```bash
cd <repo> && bash <skill>/scripts/flywheel-link.sh setup   # link + br/ntm/guards init
bash <skill>/scripts/flywheel-link.sh list                 # see everything linked
# then launch per §6:  ntm spawn <name> --cod=2 --assign … ; ntm controller <name>
```
Manual equivalent: `ln -s /abs/path/to/repo ~/Code/github/<flat-name>`.

---

## 10. Prompt & skill map

| Flywheel step | Prompt / skill |
|---|---|
| Shape a raw idea into a brief | `/grill-me`, `/grill-with-docs`, `/p-idea-wizard` |
| Draft competing plans (fan to N models) | `/p-draft-plan` |
| Merge competing plans | `/p-synthesize-plans` |
| Stress-test the plan | `/p-reality-check`, `/p-pre-mortem`, `/p-premortem-planner` |
| Plan → Beads graph | `/p-plan-to-beads` |
| Onboard agents to a repo | `/p-deep-project-primer` |
| Launch coordinated swarm work | `/p-agent-swarm-launcher`, `ntm spawn` + `ntm controller` (see §6) |
| Per-bead quality before close | `ubs --fail-on-warning .`, `/p-fresh-eyes-review` |
| Ship | `/commit`, `/commit-whole-diff`, `/pr-closeout`, `/p-deploy-and-verify` |
