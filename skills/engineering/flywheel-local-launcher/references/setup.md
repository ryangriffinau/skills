# Flywheel setup & config (one-time)

Everything you do **once** — per machine, per repo, and the config defaults. Day-to-day workflow is in `cheatsheet.md`; this file is deliberately separate so the cheat-sheet stays uncluttered.

> Remote/Linux machines can use Emanuel's one-command **ACFS** bootstrap instead of §A. macOS uses the per-tool `install.sh` list below (ACFS is Ubuntu-only).

## A. Per-machine (once)

### 1. Install the stack
Each tool via its **own `install.sh`** (canonical, checksum-verified, and dodges the Apple-Silicon Gatekeeper quarantine that kills un-notarized brew-tap binaries):
```bash
curl -fsSL "https://raw.githubusercontent.com/Dicklesworthstone/ntm/main/install.sh?$(date +%s)"                         | bash -s -- --easy-mode      # NTM (tmux orchestrator)
curl -fsSL "https://raw.githubusercontent.com/Dicklesworthstone/mcp_agent_mail/main/scripts/install.sh?$(date +%s)"      | bash -s -- --yes            # Agent Mail (+ beads br/bv)
curl -fsSL "https://raw.githubusercontent.com/Dicklesworthstone/destructive_command_guard/main/install.sh?$(date +%s)"   | bash -s -- --easy-mode      # DCG
curl -fsSL "https://raw.githubusercontent.com/Dicklesworthstone/coding_agent_session_search/main/install.sh?$(date +%s)" | bash -s -- --easy-mode --verify  # CASS
curl -fsSL "https://raw.githubusercontent.com/Dicklesworthstone/ultimate_bug_scanner/main/install.sh?$(date +%s)"        | bash -s -- --easy-mode      # UBS
brew install fzf            # mainstream → brew is fine
```

**Install policy for *any* future tool:** Homebrew is the default for mainstream tools — `brew info <name>` shows `homebrew/core (bottled)` → use brew. The only carve-out: indie tools whose canonical channel is their own `install.sh` or a third-party `user/tap` (the whole Dicklesworthstone stack) → use `install.sh`. Never install one tool through two managers.

### 2. Start + wire Agent Mail
```bash
am          # one server per machine on http://127.0.0.1:8765 — leave it running (a dedicated pane/tmux window)
```
The installer auto-wires Claude Code. For **Codex** (so it also works from the GUI) add a literal bearer header to `~/.codex/config.toml`:
```toml
[mcp_servers.mcp_agent_mail]
url = "http://127.0.0.1:8765/api/"
http_headers = { Authorization = "Bearer <token from ~/.local/share/mcp_agent_mail/.env>" }
```

### 3. NTM config (`~/.config/ntm/config.toml`)
```toml
projects_base = "/Users/<you>/Code/github"   # see §C

[agents]
# default Codex reasoning effort = high (see §D)
codex = "{{if .SystemPromptFile}}CODEX_SYSTEM_PROMPT=\"$(cat {{shellQuote .SystemPromptFile}})\" {{end}}codex --dangerously-bypass-approvals-and-sandbox -m {{shellQuote (.Model | default \"gpt-5.5\")}} -c model_reasoning_effort=high -c model_reasoning_summary_format=experimental --search"

[coordinator]
auto_assign = true   # keep feeding ready beads to idle agents (without this the swarm stalls after the first wave)
```
Set `projects_base` with `ntm config set projects-base ~/Code/github`.

### 4. Learn `bv` (do this — the tutorial is excellent)
`bv` is your **work dashboard**. **Humans run bare `bv`** (an interactive TUI of the whole bead graph) — *not* `bv --robot-*`, which is JSON/TOON for *agents*. Run `bv` once and walk its built-in tutorial; thereafter it's how you watch progress instead of re-typing `br epic status`.

### 5. Build the CASS index + verify
```bash
cass index    # once — builds the GLOBAL session index (all projects) so agents' `cass pack` works
ntm deps      # expect tmux, Claude, Codex, Agent Mail, br/bv, dcg, cass, ubs all ✓
```

## B. Per-repo (once each)

```bash
cd ~/Code/github/<flat-name>     # the projects_base path (NOT the real nested path — see §C)
bash <skill>/scripts/flywheel-link.sh setup
#   link into projects_base · br init (.beads/) · ntm init (.ntm/ + hooks) · lease guard (§ below) · AGENTS.md check
```
`setup` also checks `AGENTS.md` for the flywheel protocol and prints a snippet if missing (it never auto-edits). The protocol must define: one shared tree / **no git worktrees**, the bead loop, the tool blurbs, and **commit + push immediately after each bead**.

### Guards + husky (the common case)
`ntm guards install` wants to **own** the pre-commit hook (it writes `.husky/_/pre-commit`) and **fails on any repo that already uses husky** — which is most of them:
```
Error: pre-commit hook already exists at .husky/_/pre-commit (use --force to overwrite)
```
Do **not** `--force` — that clobbers husky's runner and your lint-staged / typecheck / test steps. Instead **chain** the portable lease guard from the existing hook, which is what `setup` now does automatically when it sees `.husky/pre-commit`:
1. copies `scripts/file-reservation-guard.sh` (bundled with this skill) into the repo at `scripts/ci/file-reservation-guard.sh`;
2. prepends one line — `scripts/ci/file-reservation-guard.sh` — to the existing `.husky/pre-commit` (after any shebang).

Now the Agent Mail lease guard runs **alongside** the repo's own checks. The guard is repo-agnostic (machine-wide Agent Mail + `git rev-parse`). One-off bypass: `AGENT_MAIL_BYPASS=1 git commit …`; advisory mode: `AGENT_MAIL_GUARD_MODE=warn`. Non-husky repos fall back to plain `ntm guards install`.

### Flywheel Profile

`setup` also scaffolds an optional `.flywheel/profile`: a flat, shell-looking config file that describes repo-specific flywheel behavior. It is parsed by the skill scripts, not sourced. No secrets belong in it.

The profile tooling is bash-native. It adds no Python, TOML, or `jq` prerequisite.

Absence is valid and means Emmanuel defaults:

| Field | Values | Default when absent |
|---|---|---|
| `FLYWHEEL_MODE` | `solo`, `team` | `solo` |
| `FLYWHEEL_WORKTREES` | `false` | `false` |
| `FLYWHEEL_PRECOMMIT` | `light`, `heavy` | `light` |
| `FLYWHEEL_PREPUSH` | `full`, `none` | `full` |
| `FLYWHEEL_PROJECTION_APP` | empty, `linear` | empty |

Package manager is detected, not stored: `package.json` `packageManager` wins; otherwise lockfiles are checked in this order: `pnpm-lock.yaml`, `bun.lockb`, `package-lock.json`, `yarn.lock`; otherwise `none`.

`setup` is idempotent:
- if `.flywheel/profile` already exists, it prints the resolved summary and does not overwrite it;
- otherwise it writes a scaffold profile with `FLYWHEEL_MODE=team` only when the repo has a remote and `.github/workflows/`; `solo` otherwise;
- `FLYWHEEL_PRECOMMIT=heavy` only when `.husky/pre-commit` mentions `typecheck`, `build`, or `test`; if so, setup prints a warning suggesting fast pre-commit and heavier pre-push/CI gates;
- `FLYWHEEL_PROJECTION_APP=` is left empty, with comments showing how to opt into Linear.

Example solo repo:
```sh
FLYWHEEL_MODE=solo
FLYWHEEL_WORKTREES=false
FLYWHEEL_PRECOMMIT=light
FLYWHEEL_PREPUSH=full
FLYWHEEL_PROJECTION_APP=
```

Example team repo with Linear projection:
```sh
FLYWHEEL_MODE=team
FLYWHEEL_WORKTREES=false
FLYWHEEL_PRECOMMIT=light
FLYWHEEL_PREPUSH=full
FLYWHEEL_PROJECTION_APP=linear
```

When `FLYWHEEL_PROJECTION_APP=linear`, add `.flywheel/projects.tsv` — the manual epic→Linear-project map (create/choose the Linear project yourself, paste its id, commit it):
```text
customer-template-architecture-transfer-w7o	c538d7a2-a7bd-4474-a4d9-8d024d4478de
```
Then **apply the projection** with the runnable, idempotent `scripts/beads-linear-sync --repo .` — export a `LINEAR_API_KEY` (a Linear *personal* key from Settings → API; any team member can make one, no Claude/MCP session needed). It posts a Linear project **status update** carrying the epic's beads progress **only when the % changed** (safe to re-run or put on a hook), and it **never mirrors child beads to Linear issues** — Linear stays a project-level roadmap view. Fail-open: a missing key or an API error logs and continues.

## C. The projects model + the one-path rule

NTM resolves a session to **`projects_base/<flat-name>`** (one level deep, flat name), and that path is **also the Agent Mail project key**. Real repos are nested (`Code/github/<org>/<repo>`), so each is exposed as a **flat symlink** directly under `projects_base`.

> **One-path rule (important):** Agent Mail keys projects by the **exact cwd path** with *no symlink canonicalization*. So always operate on a repo via its **`projects_base` symlink path** — for `setup`, `spawn`, `attach`, everything. Mixing the real nested path (e.g. running `setup` there) with the symlink path (`spawn`) registers the repo under **two different project keys** → duplicate "projects" and split coordination. The skill's `setup` runs the inits via the linked path to enforce this.

```bash
bash <skill>/scripts/flywheel-link.sh list     # see linked projects
# manual link: ln -s /abs/real/path  ~/Code/github/<flat-name>
```

## D. Reasoning effort: default `high`

We default Codex to **`high`** (§A.3), not `xhigh`. Rationale: `high` is far cheaper and avoids the over-reasoning / needless-patching loops `xhigh` tends to fall into on normal web/app work. **Opt into `xhigh` only** for genuinely hard, high-stakes work (large systems, tricky concurrency/algorithms) — per-spawn via the model spec, or a temporary config change. Emanuel runs `xhigh` because his work is heavy systems code; that's his context, not the default here.
