# flywheel-conductor — implementation plan

Plan of record (no fan-out synthesis; single-model draft, Fable 5 ultrathink, 2026-07-01).
Scope: build the new `flywheel-conductor` skill in this canonical repo **plus** the reconciliation edits to `flywheel-local-launcher`, its references, and `prompts/p-agent-swarm-launcher.md`. Plan only — implementation follows via `/p-plan-to-beads` in this repo's beads.

---

## 1. Goal and intent

Encode the **conductor pattern** proven empirically on the customer-template architecture-transfer swarm (2026-06-30 → 07-01, 86%+ driven, ~12 interventions): a human-owned agent session (Claude Code app or Codex app) acts as the swarm's coordinator — spawning codex workers via ntm, then looping *poll → triage → act → journal* until the epic ships. This replaces the in-tmux `ntm controller` Claude pane, which is **structurally broken on a single Anthropic account** (two Claude clients contend for one rate limit; recovery via `ntm rotate` demands a second account).

Design authorities, converged:
- **Pocock (`writing-great-skills`)** — predictability; leading words; information hierarchy (steps → in-skill reference → disclosed reference); split only at independent invocation moments; prune no-ops.
- **Emanuel (jeffreys-skills.md)** — one deep skill per expert workflow; "scan fast, go deep when needed"; runnable self-testing ("proof the workflow actually works"); guardrails inside the workflow; `assets/` for deterministic templates.

The converged rule that shaped every structural call below: **default to one deep skill with layered references; split only when a piece fires at a genuinely different invocation moment.** Setup (once per repo/machine) and conducting (every swarm run) are different moments → two skills. Everything else stays inside the conductor.

## 2. Division of labour (the load-bearing decision)

**Build-time vs run-time.** The launcher already owns build-time artifacts (from skills-bg7): stack preflight (`flywheel-link.sh`), per-repo profile resolution (`flywheel-profile.sh` → `.flywheel/profile` → `FLYWHEEL_*` vars), and spawn-recipe *generation* (`flywheel-kickoff.sh`). The conductor owns **run-time**: executing the recipe, driving the swarm, recovering from failures, journaling, and writing lessons back. The conductor **calls** the launcher's scripts; it never re-implements them.

Rejected alternatives:
- *Fold conduct into the launcher* — rejected: two invocation moments in one always-loaded description; the launcher's own SKILL.md declares "it does NOT launch swarms"; leading-word clarity dies.
- *One mega flywheel skill* — rejected for the same reason; Emanuel's depth lives in references, not in merged trigger surfaces.
- *Move `flywheel-kickoff.sh` into the conductor* — rejected (for now): it was just landed in the launcher (PR #2); churn without benefit. The recipe text has a single source (kickoff.sh); the conductor executes its output. Revisit only if kickoff grows run-time behavior.

**Terminology (must appear verbatim in SKILL.md):** **conductor** = the human-owned agent session running this skill · **controller** = the forbidden `ntm controller` cc pane · **coordinator** = ntm's assignment subsystem (`ntm coordinator`, `[coordinator] auto_assign`) which the conductor may drive. Three words, three referents, never interchanged.

## 3. Deliverable 1 — the skill

Location: `skills/engineering/flywheel-conductor/` (this repo; installed via `npx skills add` → `~/.agents/skills` → symlinked into `~/.claude/skills` and the Codex dir — cross-tool falls out of the install model).

```
skills/engineering/flywheel-conductor/
├── SKILL.md
├── references/
│   ├── guards.md          # full playbook: signal → diagnosis → fix, one section per guard
│   ├── check-in.md        # wake-up mechanics per tool + portable fallback
│   └── commands.md        # exact ntm/br/tmux cookbook for every conductor action
├── assets/
│   ├── worker-kickoff.md  # init-prompt template (fallback form; primary = /p-agent-swarm-launcher)
│   ├── journal.schema.json
│   └── candidate-guard.md # template for write-back lessons
├── scripts/
│   ├── conductor-poll.sh     # one-shot swarm snapshot → JSON (the tight loop)
│   ├── conductor-triage.sh   # poll JSON in → exceptions JSON out (script-first, LLM-escalate)
│   └── conductor-certify.sh  # live tiny-epic certification run
├── evals/
│   ├── fixtures/          # canned poll outputs (dead-pane, idle+ready, stuck-worker, all-clear…)
│   └── expected/          # expected triage exceptions per fixture
└── tests/
    ├── conductor-poll.test.sh
    └── conductor-triage.test.sh   # table-driven: fixtures → expected guard IDs
```

(`tests/` mirrors the launcher's existing shell-test convention; `evals/` holds the data. CONVENTIONS.md treats both as maturity evidence.)

### 3.1 SKILL.md — frontmatter + shape

```yaml
---
name: flywheel-conductor
status: drafting
version: 0.1.0
tags: [agents, flywheel, orchestration, swarm]
updated: <build date>
description: Drive a flywheel swarm as the conductor — this agent session coordinates
  codex workers (spawn, poll, triage, unblock, ship) instead of an in-tmux controller pane.
  Use when the user asks to launch/run/drive a swarm on a beads epic, when p-plan-to-beads
  has just encoded an epic ready to execute, or to check on / re-kick / adopt a running swarm.
---
```
Three trigger branches, one clause each (launch · post-encode · resume/adopt). Setup-only asks stay with the launcher — the description never mentions preflight/linking.

Body = **steps 0–6**, each with a checkable completion criterion; guard *index* inline (a 13-row table: `signal → guard name → reference pointer`); everything else disclosed. Target ≤ ~120 lines.

- **Step 0 — Enter / re-enter.** Read `.flywheel/runtime/journal.jsonl` if present. Take the **conductor lease**: an Agent Mail **file reservation** on sentinel path `.flywheel/CONDUCTOR` (exclusive, TTL ~15 min, reason = `conductor <session> <epic>`). Reservation **conflict** → another conductor is active: **report and STOP** (never dual-conduct). Granted (fresh, or after the prior lease expired) → adopt: re-arm the check-in and, if a swarm is live, continue at Step 4. If no journal and no `.flywheel/runtime/certified.json` → route to **certify** (§3.6) with user confirmation (it spawns real agents). *Criterion: reservation held; journal opened; check-in armed or consciously not.*
- **Step 1 — Preflight (delegated).** Run launcher `flywheel-link.sh preflight`; `ntm config show` parses with **no warning** (a broken config silently reverts codex to xhigh — G2); resolve profile via `flywheel-profile.sh`; **env-preflight**: for each profile-declared required deployment var, verify present (generate-and-set where the var is a self-generated secret; name-only in journal, never values). Clean tree; feature branch per profile. *Criterion: every check green or the gap surfaced to the user.*
- **Step 2 — Encode check.** Epic + beads exist (`br ready` non-empty) with reality-check + ship closers; critical path named. If not: stop and route to `/p-plan-to-beads`. *Criterion: ready ≥ 1, closers present.*
- **Step 3 — Spawn the muscle.** Execute the recipe from launcher `flywheel-kickoff.sh <session> --plan <spec> --cod <N>`. Init-prompt primary form: invoke `/p-agent-swarm-launcher` with epic/branch parameters (single source of the worker loop); fallback: `assets/worker-kickoff.md` text. **No `ntm controller` — the conductor is this session** (G1). Verify: N panes alive at profile effort (default `high`), claims appearing within one check-in (G6). *Criterion: workers claiming, not merely spawned.*
- **Step 4 — Conduct (the loop).** Arm the check-in (references/check-in.md). Each wake-up: run `conductor-triage.sh` (which runs `conductor-poll.sh` internally) → act **only on its exceptions** → append a `checkin` line + any `lesson` lines to the journal + **renew the lease reservation** → re-arm. **The conductor never does the triager's work** — no raw pane-reading or bead-listing outside the scripts; if triage output is insufficient, improve the script (that's a lesson), don't inline the analysis. Act-on-exception cookbook lives in references/commands.md; judgment calls (hang-vs-deep-work, G8) are the conductor's — that's the LLM's seat. *Criterion per wake-up: zero unhandled exceptions; journal appended. Loop exit: epic 100% closed, or a documented external block handed to the user.*
- **Step 5 — Endgame + teardown.** Reality-check and ship beads close through the normal loop (they're beads, not conductor steps). Then `ntm kill <session> --force` + `ntm cleanup`; final journal entry. *Criterion: no live session; PR link (or block) reported.*
- **Step 6 — Write-back (the flywheel's flywheel).** Diff `lessons[]` where `guard_matched: null` against the guard index. For each novel failure: instantiate `assets/candidate-guard.md`; if `cass` is available, `cass pack --robot "<signal>"` and attach prior-session hits as evidence (dedupe — if an existing guard already covers it, strengthen that guard instead); file a bead in **this canonical repo** (epic: flywheel-conductor-guards) or open the PR directly for one-liners. *Criterion: zero unmatched lessons.*

### 3.2 references/guards.md — the playbook (13 guards)

One section per guard: **Signal** (what triage/pane shows) → **Diagnosis** → **Fix** (exact commands) → **Evidence** (session/date pointer). Seeded entirely from the conducted session:

| # | Guard | Signal → fix (compressed) |
|---|---|---|
| G1 | no-controller-pane | Any urge/instruction to run `ntm controller` → don't; conductor is this session. A cc pane on the same account WILL rate-limit (`ntm rotate` demands a second account). |
| G2 | config-valid | `ntm config show` prints a load warning → one unknown field rejects the WHOLE config → built-in defaults (codex **xhigh**, wrong projects_base). Fix field placement (`default_claude` lives under `[models]`), kill+respawn to apply. |
| G3 | env-preflight | Bead blocks on missing deployment env (e.g. Convex `env set X`) → agents can't set it; conductor generates (self-generated secrets: `openssl rand -base64 32`) + sets + unblocks + comments the bead. Names in journal, never values. |
| G4 | one-shot-only | Worker "Working" ages with a background task on a watch/dev command → Esc, re-prompt: one-shot verify only (`convex dev --once`, `bun test` no watch); never a persistent dev server — Playwright `webServer` + `reuseExistingServer` for e2e. |
| G5 | exact-tooling | Worker greps `$HOME`/filesystem for tool docs → Esc, hand it the exact interface (Agent Mail = MCP tools or `:8765`; beads = `br --db <path>`). |
| G6 | assignment-gap | `--assign` reports 0 assigned / workers idle post-spawn → init-prompt self-claim loop is the real mechanism; nudge `ntm send --cod` with claim instruction; verify claims within one check-in. |
| G7 | respawn-dead-panes | Pane title alive but shows a shell prompt → clean codex exit evades `--auto-restart`; `ntm respawn <s> --panes=N --force`, re-feed prompt. |
| G8 | hang-vs-deep-work | Long turn: visible file edits/tests/lock-waits = deep work, leave it; scanning/searching loops = tangent, Esc + refocus with bead-specific instruction. The one judgment call scripts can't make. |
| G9 | route-around-locks | Worker idle because another agent holds file locks → assign a non-conflicting bead (frontend vs backend); never break a lease. |
| G10 | stale-bead-reconciliation | Bead status contradicts tree/commits (work exists but bead open, or vice versa) → instruct: verify, commit, close — before claiming new work. |
| G11 | serial-chains | High-blast-radius chains (auth) → keep single-owner serial via explicit bead deps; verify graph enforces it, don't trust prompts. |
| G12 | simple-commands | DCG blocks a clever one-liner (false positive, e.g. `>` inside sed) → rewrite plainly; conductor commands stay boring. |
| G13 | conductor-survivability | Session fork/compaction kills the check-in timer silently → journal + lease + re-arm-on-entry (Step 0) is the recovery; symptom: swarm alive, conductor reservation expired. |

### 3.3 scripts — contracts

**`conductor-poll.sh`** (bash + `br --json` + tmux + python3 for assembly; no jq dependency):
- Input: `--session <s> --db <path-to-beads.db> [--epic <id>]`
- Output (stdout, single JSON object): `{ts, session, epic, progress:{closed,total}, in_progress:[ids], ready:[ids], blocked:[{id}], panes:[{idx,title,state:working|idle|shell|error,working_secs}], last_commits:[{sha,subject}], config_warning:bool}`
- Exit codes: 0 ok · 3 session missing · 4 beads unreachable. Runtime target < 5s. Never mutates.

**`conductor-triage.sh`** — script-first, LLM-escalate:
- Input: poll JSON on stdin (or runs poll itself with the same flags).
- Deterministic rules (cover ~10 of 13 guards): pane `state==shell` → G7 · `ready>0 && all panes idle` → G6 · `config_warning` → G2 · `blocked>0` → G3 candidate · `working_secs > threshold && no new commits since last poll` → G8-candidate (ambiguous) · closed-bead/commit mismatch → G10 · session missing → G13.
- Ambiguous G8 candidates: with `--llm`, escalate via **`codex exec`** one-shot (proven non-interactive on this stack) feeding the pane capture + G8 rule; without `--llm` or if codex absent, emit `needs_conductor: true`. This is the cross-tool answer: the triager is a *script* both apps can run; the LLM step is an optional subprocess, not an app-specific subagent. (On Claude Code the conductor MAY use a read-only subagent instead — noted as an alternative in check-in.md, never required.)
- Output: `{all_clear:bool, exceptions:[{guard, pane?, bead?, evidence, recommended_action}]}`.

**`conductor-certify.sh`** — live self-test (§3.6). Creates a sandbox repo in `$TMPDIR`, links it, `br init`, creates a 3-bead env-free epic (docs-only edits), spawns `--cod=1`, drives via poll/triage until green, **injects one pane-kill** mid-run and asserts detection+respawn within one cycle, tears down, writes `.flywheel/runtime/certified.json` in the *target* repo. Flags: `--repo <dir>`; exit 0 = certified.

### 3.4 assets

- **`journal.schema.json`** — validates one JSONL **line**: `{type: checkin|lesson|certification, ts, ...}` — `checkin:{session, epic, exceptions, actions}` · `lesson:{signal, guard_matched|null, intervention, outcome, evidence}` · `certification:{eval_version}`. Journal path: **`.flywheel/runtime/journal.jsonl`** (append-only; crash-safe; no rewrite races). The **lease is NOT in the journal** — it is an Agent Mail reservation on `.flywheel/CONDUCTOR` (atomic, TTL, renewable, visible at :8765/mail beside worker reservations). Launcher `setup` ensures `.flywheel/runtime/` is gitignored (`profile` stays committed — same committed/ignored mix as `.beads/`). Secrets: key names only, never values.
- **State architecture (binding):** lease → Agent Mail reservation (ephemeral mutex) · journal + certification → `.flywheel/runtime/` gitignored (machine-local state) · config → `.flywheel/profile` committed (declarative, existing) · skill dir → schema/templates/scripts only, never written at runtime. **State stays in the repo; knowledge graduates to the skill** via the write-back loop (bead/PR), the only runtime→skill path.
- **`worker-kickoff.md`** — parameterized fallback init-prompt (epic, branch, db path, serial chains, one-shot rule, self-claim loop). Primary path stays `/p-agent-swarm-launcher <params>` so the worker loop has ONE source; the asset exists because slash-prompt resolution inside a codex pane is not guaranteed on every machine.
- **`candidate-guard.md`** — template: Signal / Diagnosis / Fix / Evidence (journal pointer + optional cass hits) / Proposed index row.

### 3.5 references/check-in.md

- **Claude Code (proven):** background `Bash` sleep timer → completion notification re-invokes the conductor; cadence 4.5–5 min while a swarm is live. Include the exact pattern used this session.
- **Portable fallback (any app):** bounded in-turn poll loop (`N` cycles of poll→triage→act with `sleep` between) + explicit hand-back with "re-invoke me in X min" — degraded but functional.
- **Codex app self-wake: TO-VERIFY** — marked honestly; verification is an eval task, not an assumption. Until verified, Codex conductors use the portable fallback.
- Lease renewal (Agent Mail reservation renew) rides on every wake-up; TTL default 15 min (3 missed check-ins) — an expired reservation is exactly what an adopting conductor claims.

### 3.6 --certify + auto-route

First conduct on a repo with no `certification` line in its journal (and no `.flywheel/runtime/certified.json`) → Step 0 routes to certify **after user confirmation** (it spawns a real codex worker = tokens). Certify = `conductor-certify.sh` (§3.3). Pass → record + proceed to real work. This is Emanuel's "proof the workflow actually works" *and* the new-repo/new-team-member driver's licence.

### 3.7 Conductor handoff — assessment verdict: INCLUDE (as lease + adopt, inside Step 0)

Honest assessment: journal + re-arm is ~90% of handoff. The remaining 10% is the **dual-conductor hazard**, and it is real — observed this session (the original session kept conducting while a forked session took over "elsewhere"; two conductors would have double-nudged workers and double-set env). The fix is small and rides on existing machinery: the **conductor lease as an Agent Mail file reservation** on `.flywheel/CONDUCTOR` (atomic first-wins, TTL, renewable, human-visible in the mail UI) plus Step 0's conflict-STOP rule and expired-lease adopt flow. No separate skill, no new file, no new mechanism. High impact ÷ near-zero cost → in.

## 4. Deliverable 2 — reconciliation edits (single source of truth)

All in this canonical repo; propagate via `npx skills update`.

1. **`skills/engineering/flywheel-local-launcher/SKILL.md`** — (a) replace "use the raw commands in references/cheatsheet.md §6 for that" with "drive the swarm with **flywheel-conductor**"; (b) add one routing line under *When to use*: setup → here; driving → conductor; (c) bump version, note kickoff.sh output is *consumed by* the conductor.
2. **`references/cheatsheet.md`** — §3 (launch & monitor) gutted to: golden rule + "drive with flywheel-conductor" pointer + teardown note; the CC-controller warning block and the inline spawn/init-prompt text are **deleted** (the warning's content lives on as G1; the spawn text's single source is kickoff.sh + conductor Step 3). §6 map: launch row → `flywheel-conductor`. §4 shipping / §5 no-worktrees stay.
3. **`references/setup.md`** — §A.3 config block gains the G2 lesson as a caveat: one unknown field rejects the whole config → silent xhigh; `default_claude` belongs under `[models]`; "verify `ntm config show` prints no warning". §D unchanged (high-not-xhigh already documented; now enforced by G2).
4. **`prompts/p-agent-swarm-launcher.md`** — hardened as the canonical **worker-side** loop (distinct audience from the conductor): parameterized epic/branch; continuous self-claim until `br ready` empty; reserve-before-edit with bead-id reason; one-shot verify only (no watch, no persistent dev server); exact Agent Mail interface (never scan the filesystem for tooling); block-and-move-on with a bead comment; commit explicit paths + push per bead; serial-chain respect.
5. **Repo indexes** — README skill table + CONVENTIONS example tree gain the conductor; both skills' `updated`/`version` bumped.

## 5. Build order (waves; independent units, minimal file overlap)

- **Wave 1 (parallel):** U1 `conductor-poll.sh` + test · U2 assets (schema + candidate-guard + worker-kickoff) · U3 `guards.md` · U4 `commands.md` · U5 hardened `p-agent-swarm-launcher.md`.
- **Wave 2 (after 1):** U6 `conductor-triage.sh` + fixtures/expected + test (needs U1 contract + U3 guard IDs) · U7 `SKILL.md` (needs all shapes) · U8 `check-in.md`.
- **Wave 3 (after 2):** U9 `conductor-certify.sh` (needs U1/U6 + launcher kickoff) · U10 launcher/cheatsheet/setup reconciliation (needs U7 to point at) · U11 README/CONVENTIONS + version bumps.
- **Wave 4 (validation):** U12 run tests + a live certify on a sandbox; U13 seed `lessons[]`/guards evidence from the customer-template session (~12 interventions are already written up in the session record + `ntm-flywheel-config` memory).

Acceptance for the whole build: `tests/*.test.sh` green · a live `--certify` passes on a sandbox repo incl. injected pane-kill recovery · `flywheel-conductor` invocable from Claude Code (proven) with Codex-side check-in explicitly marked to-verify · zero duplicated launch/monitor/kickoff text across the five flywheel artifacts (grep-checkable).

## 6. Assumptions + risks

- Machine has the full flywheel stack (per launcher preflight) and `python3`; `codex exec` works non-interactively (proven on this machine).
- Slash-prompts are bridged into codex panes (user's prompts system) — worker-kickoff asset is the fallback if not.
- ntm version provides `add/respawn/send/kill/cleanup` (proven) — HUD/F12 features are NOT assumed.
- Single-machine swarms; multi-machine conducting is out of scope (branching-model.md owns that discussion).
- Risk: guards.md sediment → mitigated by evidence pointers + write-back loop pruning discipline.
- Risk: triage thresholds (G8 `working_secs`) mis-tuned → start conservative (10 min), tune via lessons.
