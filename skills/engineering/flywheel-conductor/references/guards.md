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

## G3.5 — codex-update-preflight

**Signal:** Fresh Codex panes drop to a bare shell immediately after launch; transcript
shows an interactive self-update prompt such as "Update available" / "Update now"; a probe
before spawn reports Codex is present but needs update handling.
**Diagnosis:** Codex self-update is interactive and process-replacing. If it fires inside
new worker panes, the update can complete and exit both panes cleanly. `ntm respawn` then
recreates shells, not Codex workers, so the swarm starts at 0/N ready.
**Fix:** Step 1 must run `flywheel-link.sh preflight` before any `ntm spawn`. If the Codex
probe reports an update prompt, update/restart Codex from the conductor shell first, then
rerun preflight and only spawn after the probe is clean. If this was missed and panes are
already shells, use G7 recovery: kill the session and freshly spawn after updating.
**Evidence:** Skills dogfood 2026-07-02 — fresh ntm spawn hit Codex
`0.142.4 -> 0.142.5` interactive update; both panes exited to shells and recovery required
`ntm kill` plus a fresh spawn on the updated binary.

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
shell) — a *clean* exit evades `--auto-restart`, which only watches for crashes. `ntm
respawn` uses `tmux respawn-pane -k`: it leaves a bare shell and does **not** relaunch
Codex, so sending the kickoff prompt just types into that shell.
**Fix:** Reliable recovery is session-level: `ntm kill <session> --force`, then fresh
`ntm spawn <session> --cod=<N> --init-prompt "<same kickoff>"`. This costs all live
workers in the session, but the shared tree + beads graph make it safe: workers resume
from `br ready`. After restart, apply G10 to any bead left `in_progress` by the killed
worker before assigning new work.
**Evidence:** Skills certify 2026-07-02 — `ntm respawn` fired repeatedly and never
relaunched Codex; kill + fresh spawn relaunched cleanly and resumed from beads.

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

## G14 — ship-bead-gating

**Signal:** A ship/release bead is ready while workers are still live; both a worker and
the conductor claim or perform ship actions on the same branch; duplicate PRs or merge
attempts appear.
**Diagnosis:** The ship bead is ordinary ready work to workers, but it is also the
conductor's natural endgame concern. Without a graph or session gate, both can race and
perform release actions against the same branch.
**Fix:** Before the conductor does any claimable ship-bead work, make ownership explicit:
either add a conductor-held blocker/hold dependency so workers cannot claim it, or verify
the swarm is stopped/no live worker can claim it. If a worker already owns ship, do not race
it — let the worker finish and the conductor only verifies the result.
**Evidence:** Skills conductor dogfood 2026-07-02 — after reality-check closed, the ship
bead unblocked and a live worker opened/merged a PR while the conductor opened/merged a
parallel PR for the same branch; benign only because the second PR carried beads state.

## G15 — no-subagent-fanout (conductor never spawns local model subagents for grunt work)

**Signal:** The conductor uses the Agent/Task tool to fan out local same-account model
subagents for parallelizable grunt work (review angles, code sweeps, doc audits); the
operator's model quota drains at N× the normal rate.
**Diagnosis:** G1 forbids the controller pane for same-account rate-limit reasons, but the
same failure re-enters through conductor-side Agent-tool fan-out. Grunt work belongs on the
codex workers, not on the conductor's own account.
**Fix:** Encode the work as beads and let codex workers execute it. Local subagents require
explicit operator opt-in. If a fan-out was already started, bank any partial results into a
shared repo artifact (a findings file the beads then consume) before switching to beads.
**Evidence:** customer-kingfield 2026-07-05 — a conductor ran 8 local review subagents and
burned ~90% of the operator's quota in minutes after the operator had explicitly directed
grunt work to beads+codex.

## G16 — human-tasks-as-chat (never hand a human a bead to read)

**Signal:** A human-gated bead is surfaced to the operator as a bead id to open/interrogate;
the operator says they will not read beads.
**Diagnosis:** Beads are AI-facing tracking artifacts. Humans act on a proactive, self-
contained explanation, not on bead prose. "Beads are for AI, not human review" (operator).
**Fix:** Render every human task as a chat walkthrough: what, why, exact steps, decision
options, and worked examples where judgment is required. The bead only tracks state; the
chat message is the interface.
**Evidence:** customer-kingfield 2026-07-05 — labeling + approval tasks pointed at bead ids
stalled until re-presented as chat walkthroughs with examples.

## G17 — evidence-integrity (live-system claims carry their proof; compromised evidence fails loud)

**Signal:** A bead or doc asserts production facts (row counts, "0 rows", deployment state)
that contradict the dashboard; or an analysis doc ships a headline table while its own fine
print admits the method was compromised.
**Diagnosis:** Hidden env can silently redirect a "prod" read (e.g. `CONVEX_DEPLOY_KEY`
overrides the Convex CLI `--prod` flag; the CLI table format truncates large-document
tables). Hedged prose does not stop a wrong headline from being consumed by a human-approval
gate.
**Fix:** Any live-system claim records the exact command **and** the resolved deployment
identity as evidence (e.g. `bunx convex dashboard --prod --no-open` URL); use machine formats
for counts (`--format jsonl`), not human table output. If the evidence method is compromised,
the bead FAILS (blocked with a note) rather than publishing. Human-approval beads must never
consume a document whose evidence section carries unresolved caveats. Conductor spot-checks
any all-zero / surprising prod claim against the dashboard before a human gate consumes it.
**Evidence:** customer-kingfield 2026-07-05 — a classification doc published "0 rows" for 8
tables (read a non-prod deployment via a stray deploy key; table format also truncated 549→36)
and nearly drove a table-deletion approval.

## G18 — gate-human-beads-before-workers (close the readiness race)

**Signal:** A worker claims a human-gated or conductor-owned bead in the gap between its
blocker closing and the conductor gating it.
**Diagnosis:** A human bead entering the ready frontier is ordinary claimable work to the
swarm until it is gated.
**Fix:** Gate human/conductor beads (status in_progress + assignee = the human) at encode
time, or the instant a dependency close makes them ready. Every check-in, scan for newly-ready
human-labeled beads and gate them before the next worker claim.
**Evidence:** customer-kingfield 2026-07-05 — H2 (labeling) and MIRROR-2 (approval) surfaced
into `br ready` on a blocker close and had to be gated reactively before a worker grabbed them.

## 2026-07 strengthenings to existing guards (customer-kingfield dogfood)

- **G3 (env-preflight):** also unset/validate `CONVEX_DEPLOY_KEY` for prod-read beads (it
  silently overrides `--prod`); reconcile provisioned secret NAMES against the names worker
  code reads (e.g. `BRAINTRUST_SERVICE_OWNER_KEY` vs the code's `BRAINTRUST_API_KEY`); beads
  that assert prod facts state the exact env var names and record the deployment URL.
- **G6 (assignment-gap):** `ntm send --cod` broadcasts frequently type into an idle codex TUI
  pane WITHOUT submitting (text sits at the prompt). The dependable channel for idle panes is a
  targeted `tmux send-keys` + wait + double-Enter (the cookbook re-prompt). After any broadcast,
  verify a claim within one check-in; if none, re-prompt targeted.
- **G10 (stale-bead-reconciliation):** (a) a bead is DONE only after commit AND push of its
  explicit scope paths — spot-check `git status` on every close; flag closed-bead-with-dirty-
  scope-paths. (b) beads readiness recompute is intermittent on last-blocker close; flag any
  open/blocked bead whose blocking deps are all closed as a stale-status auto-open candidate.

## Encoding-side lessons (belong to plan-to-beads, noted here for cross-reference)

- Data/pipeline bead acceptance must state the PRODUCTION-scale output (row counts, non-null
  field requirements, consumer-contract shape), not just the smoke-test artifact — else a
  worker satisfies "5-row sample uploads" literally and leaves the real deliverable missing.
- Retirement/refactor beads under a no-delete rule must produce a deletion-approval MANIFEST
  (path, size, reason) rather than silent stub files; a standing DELETE-STUBS bead executes
  after human approval; every human gate / ship bead presents the deleted-and-stubbed file
  manifest.
