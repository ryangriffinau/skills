# Flywheel Reconciliation + Env Wizard — Implementation Plan

> Everything remaining after the **flywheel-conductor** build reshaped the ground: a
> human-run **`flywheel-env` CLI** (authored via `/wizard`; the skill ships only the output
> script), the **hardened + live-verified `beads-linear-sync`**, **profile adoption** in
> customer-template and platform-monorepo, and **conductor-aware cleanup/docs/bead hygiene**.
> Repo: `ryangriffinau/skills` (flywheel-local-launcher skill + prompts + specs).

## 0. Sequencing contract (binding)

- **Gate:** all units except U0/U11 run on a **fresh branch off `main` cut AFTER the
  conductor epic ships**. Status at encode time: `skills-flywheel-conductor-nme.12`
  (reality-check) is **closed**; `.13` (ship) is open — so **executing `.13` (PR → merge →
  `npx skills update`) is the kickoff action of this workstream** and lifts the gate.
  Nothing else touches that branch. Branch name: `feat/flywheel-env-reconciliation`.
- **U0 (pre-epic hygiene) runs immediately** — it only touches session/bead state, never
  the conductor branch's files. (Already done as of planning: the projector + its test were
  restored on the conductor branch so its in-flight reality-check stays uncontaminated; the
  authorized deletion re-applies in U4 on the new branch.)
- The `beads-linear-sync` script currently sits **untracked** in the working tree (user-WIP,
  deliberately unstaged by the conductor work). It must survive the branch switch untouched
  (untracked files carry across checkout) and lands **tracked** in U3.
- **Conductor-awareness is a review criterion for every unit**: nothing may re-introduce a
  controller pane (G1), break `ntm config` validity (G2), bypass env-preflight (G3), hang on
  interactive prompts in agent contexts (G4-adjacent), or put projection inside the worker
  loop.

## 1. Goal & intent

Two user-facing capabilities and one debt-clearing sweep:

1. **`flywheel-env`** — the one way humans give the flywheel tooling secrets/config input
   (first key: `LINEAR_API_KEY`). Local-vs-global placement with informed override, masked
   display, strict precedence, non-interactive `get`/`check` for tooling (launcher scripts
   *and* conductor Step 1 / G3 env-preflight).
2. **`beads-linear-sync`** — project-level Beads→Linear projection, hardened (health,
   idempotency, env sourcing) and **live-verified** against the real `w7o` Linear project
   (key now available in `customer-template/.env`).
3. **Reconciliation** — profile adoption in both target repos, authorized deletion of the
   deprecated per-bead projector, stale-doc fixes, bead-graph hygiene, docs.

Non-goals: no changes to the conductor skill's loop/guards (only additive docs in its
`commands.md`); no Linear *project-state* mutation (updates only — completing/archiving a
Linear project stays human/MCP); no new runtime dependencies (bash + coreutils + curl +
existing stack only).

## 2. Architecture

```
                      HUMAN (interactive, TTY)                    TOOLING (non-interactive)
                      flywheel-env set/list                       flywheel-env get/check
                              │                                            │
                              ▼                                            ▼
         ┌─────────────────────────────────────────────────────────────────────┐
         │                     ENV RESOLUTION (one precedence)                  │
         │  process env  >  repo .flywheel/env.local  >  repo .env (read-only)  │
         │              >  global ~/.flywheel/env                               │
         └─────────────────────────────────────────────────────────────────────┘
                    ▲                          ▲                        ▲
        beads-linear-sync             conductor Step 1 (G3        flywheel-link.sh
        (LINEAR_API_KEY)              env-preflight: check         setup (gitignore
                                      profile-declared vars)       scaffolding)
```

- **Global store:** `~/.flywheel/env` — flat `KEY=value`, `chmod 600`, created by the CLI.
  *(Chosen over `~/.config/flywheel/env` for name-symmetry with the repo-level `.flywheel/`
  — same directory name, different scope; one thing to teach.)*
- **Project store:** `.flywheel/env.local` — flywheel-owned, gitignored, `chmod 600`.
  **The CLI never writes the project's `.env`** (project-owned; conventions vary; AGENTS.md
  forbids agents editing it) but **reads** it so keys users already keep there — like
  customer-template's `LINEAR_API_KEY` — just work.
- **Parse, never source** (same rule as `flywheel-profile.sh`): read specific
  `^(export )?KEY=` lines only; repo file content is data, not code.
- **Where projection runs (locked):** conductor **Step 5 endgame** and the **ship bead**
  (`mode=team` + `FLYWHEEL_PROJECTION_APP=linear`), plus ad-hoc human runs. **Never inside
  the worker loop** — workers neither hold the key nor own the roadmap view.

## 3. Contracts

### 3.1 `flywheel-env` (skill asset `scripts/flywheel-env`; authored via `/wizard`)

```
flywheel-env set [KEY] [--repo DIR]       # interactive; TTY REQUIRED (exit 3 + hint if none)
flywheel-env get KEY [--repo DIR]         # non-interactive; value to stdout, exit 1 if unresolved
flywheel-env check KEY... [--repo DIR]    # non-interactive; per-key source or MISSING; exit 1 if any missing
flywheel-env list [--repo DIR]            # masked table: KEY, source (process/project/env/global), …last4
```

Behavioral requirements (the `/wizard` session refines UX *within* these):
- `set` with an existing **global** value: show masked value → offer **[r]eplace global /
  [p]roject-level override / [a]bort**. No global: offer **[g]lobal / [p]roject**.
  (Deliberately mirrors the skill-install local/global UX.)
- Known-key registry inside the script (name → description, consumer, recommended scope);
  first entry `LINEAR_API_KEY` (consumer: beads-linear-sync; **recommended: project** —
  Linear API keys are commonly team-scoped, and the user runs two keys for two teams
  (Workhorse Delivery vs BackPocket), so each repo carries the key for *its* team; global
  is only a fallback for single-team users). Unknown keys are allowed (free-form) with a
  generic prompt.
- `check` with no explicit keys reads the repo profile's declared list (§3.2) — this is the
  conductor G3 preflight hook.
- Values are never echoed unmasked; never logged; never journaled (names only — G3 rule).
- Writes `chmod 600` files; ensures `.flywheel/env.local` is gitignored (appends the entry
  with confirmation if missing).
- **The `/wizard` process is authoring-only**: the live skill references nothing from the
  wizard session except the landed `scripts/flywheel-env` + its tests.

### 3.2 Profile addition (one field): `FLYWHEEL_ENV_REQUIRED`

Comma-separated env-var **names** a repo's flywheel work needs (e.g.
`FLYWHEEL_ENV_REQUIRED=LINEAR_API_KEY`). Resolver (`flywheel-profile.sh`) parses + emits it
(default empty); `flywheel-link.sh` scaffold writes a commented example. Consumed by
`flywheel-env check` (and therefore conductor Step 1). *Verify at implementation whether the
conductor already settled a field name for profile-declared vars — if so, adopt that name
instead of introducing a second.*

### 3.3 `beads-linear-sync` hardening (continuing `skills-bg7.14`)

Fixes on the existing untracked script, then land tracked + tested:
1. **Env sourcing:** resolve `LINEAR_API_KEY` via `flywheel-env get LINEAR_API_KEY --repo
   "$repo"` (falls back to process env if the CLI is absent — the script must still run
   standalone). Missing key → dry-run + fail-open message (unchanged behavior).
2. **Health derived, not hardcoded:** `atRisk` iff any mapped epic child has
   `"status":"blocked"`; else `onTrack`. (Beads has no richer health signal; documented.)
3. **Idempotency, escape-proof:** marker stays `[beads:<epic>] N/M` (no JSON-escapable
   chars, so `grep -F` on the raw response is reliable *by construction*); read
   `projectUpdates(first: 25)`, find the **latest update containing `[beads:<epic>]`**, skip
   only if its `N/M` equals current. Distinguish failure classes: curl/network error vs
   GraphQL `"errors"` in body — both log-and-continue (fail-open), with distinct messages.
4. **`--all` (portfolio sweep):** iterate the `projects_base` symlinks; for each repo whose
   profile sets `FLYWHEEL_PROJECTION_APP=linear`, run the same idempotent per-repo sync —
   resolving `LINEAR_API_KEY` **per repo** (so each repo authenticates with its own team's
   key); skip non-projection repos silently; per-repo errors log and continue; one summary
   line per repo. **Scheduling:** event triggers (ship bead + conductor Step 5 + manual)
   are the default and require no daemon; an **optional** machine-level `launchd` timer
   (documented one-liner in setup.md, e.g. hourly) may run `--all` in the background —
   time-based and fully decoupled from any orchestrator; idempotency makes most runs no-ops.
   Caveat documented: the sweep projects the *local checkout's* beads state.
5. **Read-only auth probe in `--dry-run`:** when a key resolves, issue one `viewer` +
   project-read query and print "key valid (user …) ✓ project reachable ✓" alongside the
   would-post summary. No writes ever occur in dry-run — this replaces the rejected
   `--verify` write-test (see §8).
6. **Live verification protocol** (the part that was impossible without a key — key now in
   `customer-template/.env`): from customer-template after U5 adoption —
   `--dry-run` (compute + auth probe) → real apply (update visible via GraphQL read-back
   **and** in the Linear UI) → immediate re-run (must print "unchanged, no new update" —
   idempotency proven) → close a test-irrelevant delta if available (optional third run
   after the swarm closes another bead). Record outputs in the bead close reason.

### 3.4 Adoption artifacts

- **customer-template** (`skills-bg7.13`): `.flywheel/profile` (`FLYWHEEL_MODE=team`,
  `FLYWHEEL_PRECOMMIT=light`, `FLYWHEEL_PREPUSH=full`, `FLYWHEEL_PROJECTION_APP=linear`,
  `FLYWHEEL_ENV_REQUIRED=LINEAR_API_KEY`) + `.flywheel/projects.tsv`
  (`customer-template-architecture-transfer-w7o<TAB>c538d7a2-a7bd-4474-a4d9-8d024d4478de`)
  + `.gitignore` entries (`.flywheel/env.local`, `.flywheel/runtime/`). **Its swarm session
  is LIVE**: reserve the exact paths via Agent Mail before editing; files are disjoint from
  swarm work; branch off its default branch → team PR flow.
- **platform-monorepo** (`skills-bg7.12`): `.flywheel/profile` (`team`; **no projection**
  — Linear project decision for its active work is deferred; leave the commented example)
  + same gitignore entries. Team PR to `main`. **User-sequenced FOLLOW-ON: runs after this
  epic fully ships** (`bg7.12` gains a dep on this epic's ship bead; not a unit here).

### 3.5 Machine-tool adoption (Emanuel stack additions)

- **`post_compact_reminder`** — registers a `SessionStart` hook (matcher `"compact"`) in
  `~/.claude/settings.json`; after compaction it injects a mandatory "re-read AGENTS.md +
  confirm key rules" reminder. Automates the compaction rule our AGENTS.md files state
  manually; directly supports conductor Step 0 re-entry / G13 (the conductor is a
  long-lived Claude session that WILL compact mid-swarm). Claude-Code-only. Install (own
  installer, per policy): `curl -fsSL https://github.com/Dicklesworthstone/post_compact_reminder/raw/refs/heads/main/install-post-compact-reminder.sh | bash`
- **`caam` (coding_agent_account_manager)** — sub-100ms auth-profile switching for Claude
  Code/Codex/Gemini (`caam backup/activate/pick/status`; `caam run <tool> --` with
  automatic rate-limit failover). This is the concrete mechanism behind G1's "recovery
  demands a second account" and general rate-limit resilience for the conductor session.
  Install via **install.sh, not the brew tap** (Gatekeeper policy):
  `curl -fsSL "https://raw.githubusercontent.com/Dicklesworthstone/coding_agent_account_manager/main/install.sh?$(date +%s)" | bash`
  Then `caam backup claude <current-account>` immediately; adding a second account is a
  **manual user step** (interactive `/login`).

## 4. Work decomposition (units → beads; disjoint file ownership)

| Unit | Owns (files) | Deps | Summary |
|---|---|---|---|
| **U0 Pre-epic hygiene** | session/bead state only | — (runs now) | `ntm kill fwcert* --force` + `ntm cleanup`; close `skills-ogi` epic (children all closed); close `skills-bg7.12/.13/.14` as "continued in <new epic>" at encode time |
| **U1 `flywheel-env` CLI** | `scripts/flywheel-env`, `tests/flywheel-env.test.sh` | gate | author via **`/wizard`**; land per §3.1 |
| **U2 Profile field** | `scripts/flywheel-profile.sh`, `scripts/flywheel-link.sh`, their tests | gate | `FLYWHEEL_ENV_REQUIRED` per §3.2 |
| **U3 Sync hardening** | `scripts/beads-linear-sync`, `tests/beads-linear-sync.test.sh` | U1 | §3.3 items 1–3; lands the script tracked |
| **U4 Authorized deletion + stale refs** | `scripts/beads-linear-projector`, `tests/beads-linear-projector.test.sh` (delete — user-authorized), `docs/specs/flywheel-profile/PLAN.md` (ref update) | gate | the ONLY deletion; everything else archive-not-delete (RULE 1) |
| **U5 Adopt: customer-template** | customer-template `.flywheel/*`, `.gitignore` (other repo) | U2 | §3.4; Agent-Mail reserve (live swarm); team PR |
| **U6 Live-verify sync** | none (runs U3's script) | U3, U5 | §3.3 item 4 against real `w7o`; closes the bg7.14 thread |
| **U11 Machine tools: post_compact_reminder + caam** | machine state only (installs + `caam backup` of current auth; docs land via U8) | — (gate-free) | §3.5; second caam account = manual user step |
| **U8 Docs + ENV-MISSING convention** | `references/setup.md`, `references/cheatsheet.md`, conductor `references/commands.md` (additive entry only), launcher `SKILL.md` frontmatter, `prompts/p-agent-swarm-launcher.md` (one line) | U1–U3 | env-CLI section (incl. optional launchd line); sync triggers (ship §4 + conductor endgame); SKILL.md description gains Case A/B detection mention; setup.md §A + cheatsheet gain the §3.5 tool entries (post_compact_reminder → conductor compaction resilience; caam → G1 second-account recovery); worker kickoff gains: *"blocked on a missing env var → mark the bead blocked with a comment containing `ENV-MISSING: <NAME>`"* (bead comments are the structured channel conductor triage already reads — replaces the rejected mail-subject protocol, §8) |
| **U9 Broad reality-check** | — | U1–U8 | tests green (`tests/*.test.sh`), shell `bash -n`, repo-wide stale-ref sweep (projector, wizard-session residue, `[linear]`, controller-pane advice), fresh-eyes on the whole diff, `/p-reality-check` the outcome |
| **U10 Ship** | — | U9 | mode-aware ship (skills repo: open PR ready → merge when green — direct, non-prod) → `npx skills update` + verify `~/.agents` + `~/.claude` symlinks resolve to the new assets |

DAG: gate(=conductor `.13` merged, the kickoff action) → {U1, U2, U4}; U3←U1; U5←U2;
U6←U3+U5; U8←U1–U3; U9←U1–U6,U8,U11; U10←U9; U11 gate-free (runs anytime). **Follow-on
after U10:** platform adoption `skills-bg7.12` (user-sequenced; gains a dep on U10).
Parallel width after the gate: U1, U2, U4, U11 (disjoint ownership).

## 5. Edge cases & failure modes

- `flywheel-env set` in a non-TTY context (an agent runs it): **exit 3 immediately** with
  "human-interactive; agents use `flywheel-env get/check`" — no hang (G4-adjacent).
- Key present only in project `.env` (customer-template today): `get` resolves it
  (read-only path), `check` passes, `set` still never writes that file.
- Same key global + project: project wins; `list` shows both with the winner marked.
- No HOME-store, no repo stores, not in process env: `get` exit 1 with a one-line
  "set it with: flywheel-env set KEY" hint (consumed verbatim by sync's fail-open message).
- Sync: Linear 401/403 (bad key) vs network-down vs GraphQL errors — distinct log lines,
  all fail-open exit 0.
- Sync marker collision with a human-written update containing `[beads:...]`: latest-match
  rule tolerates it (worst case: one extra update, never a wrong skip of a real change).
- Profile lists `FLYWHEEL_ENV_REQUIRED` names that aren't in the registry: `check` still
  resolves/report them (registry is help-text, not a gate).
- customer-template PR races its live swarm: reservation held; if the swarm's ship bead
  merges first, rebase — files are disjoint by construction.

## 6. Security & correctness

- Secrets: `chmod 600` stores; masked display (`…last4`); never in journal/beads/commits;
  never `source`d; DCG-friendly plain commands only (G12) in all scripts.
- The env CLI is the *only* writer of flywheel env stores; agents are read-only consumers.
- Projection remains fail-open and outside the worker loop; conductor consumes `check`, not
  `set`.
- RULE-1 ledger for this plan: the **only** deletions are `beads-linear-projector` + its
  test, per the user's written authorization ("Just delete the deprecated
  beads-linear-projector", 2026-07-01); executed in U4 on the new branch; recoverable from
  git history.

## 7. Acceptance criteria (per unit)

- **U1:** all four subcommands behave per §3.1 on a fixture repo; TTY guard verified;
  precedence matrix (process/project-local/.env/global) covered by tests; masked output
  only; gitignore ensured. Wizard-session artifacts: none in the repo beyond the script+tests.
- **U2:** resolver emits `FLYWHEEL_ENV_REQUIRED` (default empty); scaffold writes the
  commented example; existing profile tests still green.
- **U3:** health derives from blocked-children; re-run idempotency logic reads `first: 25`
  + latest-marker; env via `flywheel-env get` with process-env fallback; fixture tests for
  compute, gating, and both failure classes.
- **U4:** projector + test gone from the new branch; `grep -r beads-linear-projector` hits
  only git history/this plan's ledger + the updated flywheel-profile PLAN.md note.
- **U5/U7:** both repos' profiles resolve via `flywheel-profile.sh`; PRs opened via team
  flow (customer-template with an Agent-Mail reservation while its swarm runs); merged green.
- **U6:** live Linear update visible on project `c538d7a2-…` with correct `N/M`; immediate
  re-run posts nothing; evidence in the bead close.
- **U8:** setup.md documents the CLI (stores, precedence, masked list, agents-never-set);
  cheatsheet §4 + conductor commands.md name the two sync trigger points; SKILL.md
  description mentions detect-existing-system/Case A/B.
- **U9/U10:** per the standard closers; `npx skills update` pulls the new assets and both
  symlink roots resolve.

## 8. Rejected alternatives

- **Global store in `~/.config/flywheel/`** — rejected for name-symmetry with repo
  `.flywheel/` (one name to teach). Revisit only if XDG compliance becomes a real need.
- **Writing the project's `.env`** — rejected: project-owned file, AGENTS.md forbids agent
  edits, project env conventions vary; we read it, never write it.
- **`jq`/python for the Linear response parsing** — rejected: the escape-proof marker makes
  `grep -F` reliable by construction; zero new dependencies (G12-style plainness).
- **Projection inside the worker loop / per-close hook** — rejected: workers don't hold the
  key; duplicates conductor Step 5; couples the core loop to a human-view concern.
- **Deriving Linear health from velocity/dates** — rejected: beads carries no such signal;
  blocked-children → `atRisk` is the only honest derivation.
- **A new `fw env` verb on flywheel-link.sh** — rejected: `fw` stays `link/setup/list`;
  the env CLI is its own single-purpose script (same pattern as kickoff/profile/sync).
- **Standardized Agent-Mail subjects (`ENV-REQUEST: KEY`)** — rejected after adversarial
  review: LLM workers won't reliably hold an exact-string convention (paraphrase → the
  triage grep silently matches nothing → false "no env requests" confidence — a convention
  that fails silently is worse than none); it adds a third channel when the structured one
  (blocked beads, which triage already reads — G3 evidence) exists; and no latency win
  since the conductor acts at check-ins anyway. Adopted instead: the `ENV-MISSING: <NAME>`
  bead-comment line in the worker kickoff (U8).
- **`--verify` write-test flag** — rejected: it write-tests in production (posts a real
  status update into the real project feed the team reads — test noise in the exact
  surface the mirror exists to keep trustworthy), and after U6's one-time acceptance it
  proves nothing but key validity. Adopted instead: the read-only auth probe in `--dry-run`
  (§3.3.5).
- **A cross-repo portfolio dashboard** — deferred: checked Dicklesworthstone's repos — the
  closest is `frankenterm` (fleet *terminal* hypervisor: pane capture + JSON API), which is
  a different layer; `bv` is per-repo. At 2–3 repos, `bv` + `ntm list` suffices; revisit at
  ~5+ repos (and evaluate frankenterm then).

## 9. Assumptions (check at implementation)

- Conductor build is complete (`.12` closed — verified 2026-07-02); `.13` (ship) executes
  as this workstream's kickoff action.
- The conductor did **not** already define a profile field for declared env vars (else adopt
  its name in U2 instead of `FLYWHEEL_ENV_REQUIRED`).
- `LINEAR_API_KEY` in `customer-template/.env` is a valid personal key with access to the
  Workhorse workspace project `c538d7a2-a7bd-4474-a4d9-8d024d4478de`.
- The customer-template swarm's branch doesn't already add `.flywheel/profile` (re-check at
  U5; if it does, reconcile instead of scaffold).
- `bv`/`br` remain the tracker; new epic + closers encoded via `/p-plan-to-beads` after this
  plan is approved.
