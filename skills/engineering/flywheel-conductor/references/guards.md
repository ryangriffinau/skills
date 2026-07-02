# Conductor guards — failure playbook

One section per guard: **Signal → Diagnosis → Fix → Evidence**. The compact index lives in
`SKILL.md`; this file is loaded when a guard fires. All guards were distilled from a real
conducted swarm (customer-template `architecture-transfer`, 2026-06-30 → 07-01, "the AT
session" below) — new guards arrive via the write-back loop (`assets/candidate-guard.md`)
and must carry the same four fields.

## G1 — no-controller-pane

**Signal:** Any instruction, doc, or habit suggesting `ntm controller <session>`; a pane named
`*__controller_claude_*` showing `ERR` / "Rate limit detected"; ntm banner "Run: ntm rotate".
**Diagnosis:** A Claude controller pane is a second Claude client on the same Anthropic
account as the conductor session — both contend for one rate limit and the pane loses.
ntm's recovery (`ntm rotate`) assumes a second account. Structural, not transient.
**Fix:** Never spawn a controller pane — the conductor **is** this session. If one exists:
`ntm kill` it or leave it dead; conduct from here. (A Codex controller pane works but is
redundant once this session conducts.)
**Evidence:** AT session — controller_claude ERR "Rate limit detected"; `ntm rotate
customer-template --pane=1` → "Browser authentication required: switch to your other account".

## G2 — config-valid

**Signal:** `ntm config show` (or any ntm output) prints `warning: config load failed …
unknown field(s)`; workers show `xhigh` effort when config says `high`; poll reports
`config_warning: true`.
**Diagnosis:** ntm config parsing is all-or-nothing: ONE unknown field rejects the ENTIRE
file and ntm silently falls back to built-in defaults — codex `xhigh` and the default
`projects_base`. Classic cause: `default_claude` placed under `[agents]` (it belongs under
`[models]`).
**Fix:** Fix the field placement; verify `ntm config show` prints no warning; then
`ntm kill <session> --force` and respawn — running agents never pick up config changes.
**Evidence:** AT session — three spawns at xhigh before the `[agents] default_claude` line
was found; documented in `ntm-flywheel-config` memory + setup.md §A.3 caveat.

## G3 — env-preflight

**Signal:** A bead blocks with "missing env var X in deployment"; `convex codegen` (or
similar) aborts naming a variable; workers block honestly and move on.
**Diagnosis:** Deployment-level env (Convex env, etc.) is not settable by anonymous worker
agents — and process-only env does not satisfy deployment validation. Self-generated
secrets (signing keys) don't need the user; platform keys do.
**Fix:** Conductor sets it: self-generated → `openssl rand -base64 32` then the platform's
`env set`; platform-issued → surface to the user, park only the affected chain, keep other
beads flowing. Then unblock the bead with a comment and nudge. Journal the **name only**.
Prevention: Step 1 env-preflight reads profile-declared required vars before spawning.
**Evidence:** AT session — A1 blocked twice (BETTER_AUTH_SECRET placeholder, then
RESEND_API_KEY); conductor `bunx convex env set` + unblock resumed the auth chain.

## G4 — one-shot-only

**Signal:** Worker "Working" grows past ~10 min with a background task on `dev`, `--watch`,
or a server; no new commits; pane transcript shows a long-running process.
**Diagnosis:** Watch/dev modes never exit — the agent's turn hangs forever. AGENTS.md
forbids agents starting persistent dev servers.
**Fix:** `Esc` the pane, re-prompt: one-shot equivalents only (`convex dev --once`, `bun
test` without watch, `bunx playwright test --reporter=line`); e2e uses Playwright
`webServer` + `reuseExistingServer: true` (boots and tears down within the run). Kill any
background process the worker started.
**Evidence:** AT session — all 3 workers hung 11m+ on watch commands; post-interrupt the
"no watch" rule held for the rest of the run. Endgame e2e bead resolved via webServer.

## G5 — exact-tooling

**Signal:** Worker transcript shows filesystem scanning (`find ~`, `grep -r $HOME`) hunting
for a tool/command; long turns with "searching for" phrasing.
**Diagnosis:** The agent knows a tool exists (Agent Mail, br) but not its interface, and
burns tokens spelunking instead of asking.
**Fix:** `Esc`, re-prompt with the exact interface: Agent Mail = MCP tools or
`http://127.0.0.1:8765`; beads = `br --db <path>`. Prevention: the worker kickoff includes
these interfaces verbatim.
**Evidence:** AT session — a worker spent ~19 min scanning `$HOME` for an Agent Mail
"list reservations" command while holding the critical-path bead (A3).

## G6 — assignment-gap

**Signal:** Post-spawn: `--assign` reports "assigned 0"; poll shows `ready > 0` with all
panes idle; no bead moves to in_progress within one check-in.
**Diagnosis:** ntm's assignment push is unreliable; `[coordinator] auto_assign` may not
feed either. The dependable mechanism is workers **self-claiming** via `br ready` — which
only happens if the kickoff loop says so and the workers act on it.
**Fix:** `ntm send <session> --cod "<claim nudge>"` naming the ready bead ids; verify a
claim lands within the next check-in; if a specific worker idles while others hold locks,
hand it a named non-conflicting bead (G9).
**Evidence:** AT session — hit twice: spawn assigned 0 (workers idle until nudged), and a
mid-run stall with 4 ready + 0 claiming.

## G7 — respawn-dead-panes

**Signal:** Poll pane `state: shell`; transcript tail is a zsh/bash prompt or
`zsh: parse error`; ntm dashboard shows the pane as a user shell.
**Diagnosis:** Codex exited cleanly (crash, self-update, or parse error typed into the
shell) — a *clean* exit evades `--auto-restart`, which only watches for crashes.
**Fix:** `ntm respawn <session> --panes=<N> --force`, then re-feed the kickoff via
`ntm send`/`tmux send-keys` (respawned panes lose their init-prompt). Verify it claims.
**Evidence:** AT session — pane 3 died to zsh three times; auto-restart never caught it;
manual respawn + re-prompt recovered each time.

## G8 — hang-vs-deep-work (the judgment call)

**Signal:** Poll shows `working_secs` beyond threshold (default 600s) with no new commits.
Triage emits a *candidate*, never a verdict — this is the conductor's call.
**Diagnosis:** Two look-alikes: (a) **deep work** — transcript shows file edits, test runs,
or an explicit lock-wait ("waiting on A3 reservations"); (b) **tangent** — scanning,
re-reading docs in circles, tool-hunting.
**Fix:** Read the pane tail. Deep work → leave it alone (interrupting loses context).
Lock-wait → check the lock holder is alive, else G9. Tangent → `Esc` + refocus with the
bead id and the exact next action. When genuinely unsure, wait one more check-in before
interrupting.
**Evidence:** AT session — 11m turns that were REAL work (P6 test authoring; V1.4 correctly
waiting on A3 file locks and releasing its own overlaps) vs the G5 tangent. Interrupting
the former would have cost 15 minutes of context.

## G9 — route-around-locks

**Signal:** Worker idle or blocked "waiting on reservations"; Agent Mail shows another
agent holding the files; ready beads exist in a different area.
**Diagnosis:** Healthy coordination (leases working) but poor scheduling — the idle worker
has nothing conflict-free in its default pick order.
**Fix:** Hand the idle worker a named bead that touches disjoint files (frontend vs
backend). NEVER force-release another agent's reservation for scheduling convenience.
**Evidence:** AT session — pane 3 idled while backend locks were held; conductor assigned
the frontend A5 bead explicitly; both streams completed in parallel.

## G10 — stale-bead-reconciliation

**Signal:** Bead status contradicts the tree: commits/files exist for an open bead, or a
closed bead's work is missing; often after resets, respawns, or conductor restarts.
**Diagnosis:** Interrupted workers (or conductor resets) desync the graph from reality.
The graph is the source of truth for *scheduling*, but the tree is the truth for *work*.
**Fix:** Instruct the claiming worker: verify the existing work (typecheck + tests), commit
with explicit paths, close the bead — never redo work that exists. Conductor includes this
rule in every re-kick prompt after any reset.
**Evidence:** AT session — V1.1 colocation was implemented, then its bead was reset during
the xhigh→high respawn; the next wave verified + committed + closed it instead of redoing.

## G11 — serial-chains

**Signal:** Two workers claim adjacent beads of a high-blast-radius chain (auth, schema
migration); or a chain bead is "ready" while its sibling is mid-flight in another pane.
**Diagnosis:** Chains that edit the same subsystem must be single-owner. Prompt-level
instructions ("run serially") are advisory; only graph dependencies enforce.
**Fix:** At encode time (Step 2) verify chain beads have explicit sequential deps
(`br dep add`); if a gap is found mid-run, add the dep immediately — the graph, not the
prompt, is the enforcement.
**Evidence:** AT session — A2/A3 both went ready after A1 until the verification pass added
`A3 → A2`; the serialized chain then landed cleanly (A1→A6 with zero conflicts).

## G12 — simple-commands

**Signal:** DCG blocks a conductor command citing a destructive pattern that isn't there
(e.g. `>` inside a sed replacement string read as a redirect).
**Diagnosis:** Clever one-liners trip guard heuristics. The guard is right to be paranoid;
the command was wrong to be clever.
**Fix:** Rewrite plainly: separate commands, temp files in the scratchpad, python3 heredocs
for text processing. Never work around the guard's intent.
**Evidence:** AT session — a sed with `>` in the replacement was blocked as
redirect-truncate; the plain rewrite passed immediately.

## G13 — conductor-survivability

**Signal:** Swarm alive but the conductor's reservation on `.flywheel/CONDUCTOR` is
expired; no fresh `checkin` lines in the journal; poll exit 3 after a machine/session
change; a fork/compaction notice in the conductor's own context.
**Diagnosis:** The conductor's wake-up timer dies silently on session fork, compaction, or
app restart — the swarm keeps working unconducted (blocked beads accumulate unnoticed).
**Fix:** Prevention is structural: journal + lease + **re-arm on entry** (Step 0). On any
skill (re)entry: read the journal, attempt the lease, re-arm the check-in. An adopting
session (either app, any teammate) claims the expired lease and continues from the journal.
**Evidence:** AT session — the user forked the session; the background timer died with no
completion record; the swarm ran unconducted (reached 86% on momentum, but the endgame
gate sat blocked until the next manual poll noticed).
