# flywheel-conductor — deletion manifest

Evidence for the approval gate `skills-fc-rework-tfx.6`. Produced by
`skills-fc-rework-tfx.5`. **This document deletes nothing.** No approval has been given and
no delete pass has run.

Every line count below was measured with `wc -l` against the working tree on 2026-08-03, not
copied from the plan.

**Correction to the plan.** `rework-PLAN.md` estimated "~1,700 lines". The measured total is
**1,446 lines across 24 files**. The plan's figure was an estimate written before the files
were counted; this manifest's figure is the real one.

| | Count |
|---|---|
| Files proposed for deletion | 24 |
| Lines proposed for deletion | 1,446 |
| Files in the skill today (tracked) | 26 |
| Files remaining after the cut | 2 (`SKILL.md`, `references/commands.md`) + 1 new (`SELF-TEST.md`) |

Disposition is `deleted` for every row. **No file is stubbed.** Nothing in this cut leaves a
placeholder, an empty file, or a commented-out shell behind.

---

## 1. Scripts — 493 lines, 3 files

| Path | Lines | What it does today | Why it goes | Source of truth after removal | Disposition |
|---|---:|---|---|---|---|
| `scripts/conductor-poll.sh` | 199 | One-shot swarm snapshot to JSON: tmux pane enumeration, `capture-pane` tail per pane, regex classification into working/idle/shell/error, `br` bead rollup, `ntm config show` warning check | The pane classification is a private contract with another program's redraw output. `:160` matches `Working \((\d+h)?(\d+m)?(\d+s)?` and `:170` matches a shell prompt as `[$%]\s*$` against Codex TUI chrome — both break silently on any Codex UI change | `ntm --robot-snapshot` (typed `sessions[].agents[]` with `state`, `last_output_age_sec`, `type`, `type_confidence`, `pending_mail`, schema `ntm:robot:snapshot:v1`) + `br ready --json`. Verified returning this shape on ntm 1.18.3 | deleted |
| `scripts/conductor-triage.sh` | 126 | Poll JSON in, exceptions JSON out. Deterministic rules for G2/G3/G6/G7, plus a G8 candidate path that shells out to `codex exec` under `--llm` to classify a pane tail | Its five rules map onto native ntm signals. The `--llm` path spawns a whole second agent to answer a question the conductor is sitting right there to answer — and the script already refused to render the G8 verdict itself | `ntm --robot-snapshot` (pane state), `ntm --robot-triage` (scored bead picks with reasons), `ntm work queue-dry` (idle-vs-dry). G8 judgment moves inline into the rewritten loop | deleted |
| `scripts/conductor-certify.sh` | 168 | Live certification: creates a `$TMPDIR` sandbox repo, links it into `projects_base`, creates a 3-bead epic, spawns a real codex worker, injects a pane-kill, asserts recovery, writes `certified.json` | Tests **ntm**, not the conductor — what it proves is that ntm can spawn a worker and recover a killed pane. Costs real tokens, up to 20 minutes, requires `--yes`, mutates `projects_base`, and leaks (see §6) | `SELF-TEST.md` (bead `skills-fc-rework-tfx.9`) — tool-contract assertions, zero tokens, no side effects | deleted |

## 2. Tests — 207 lines, 2 files

| Path | Lines | What it does today | Why it goes | Source of truth after removal | Disposition |
|---|---:|---|---|---|---|
| `tests/conductor-poll.test.sh` | 170 | Table-driven tests of `conductor-poll.sh` output shape | Tests a deleted script | n/a — the contract it protected is now ntm's, asserted by `SELF-TEST.md` | deleted |
| `tests/conductor-triage.test.sh` | 37 | Feeds `evals/fixtures/*` to `conductor-triage.sh`, diffs against `evals/expected/*` | Tests a deleted script | n/a — same | deleted |

## 3. Eval fixtures — 234 lines, 14 files

| Path | Lines | What it does today | Why it goes | Source of truth after removal | Disposition |
|---|---:|---|---|---|---|
| `evals/fixtures/` (7 JSON: all-clear 31, dead-pane 28, idle-ready 28, blocked-bead 27, config-warning 23, needs-restart 23, stuck-worker 23) | 183 | Canned `conductor-poll.sh` outputs, one per guard scenario | Inputs for a deleted script. They test our own regexes against our own captures — they could not, and never did, catch a real Codex UI change, which is the failure they existed to prevent | n/a | deleted |
| `evals/expected/` (7 JSON, matching names) | 51 | Expected triage exceptions per fixture | Same | n/a | deleted |

## 4. References — 385 lines, 2 files

| Path | Lines | What it does today | Why it goes | Source of truth after removal | Disposition |
|---|---:|---|---|---|---|
| `references/guards.md` | 337 | The 20-guard failure playbook: Signal → Diagnosis → Fix → Evidence per guard | 20 guards reduce to 4 inline rules; the rest relocate, are covered elsewhere, or fold into the loop. Per-guard disposition in §5 — **this is the row that needs the closest reading** | Split across §5's destinations | deleted |
| `references/check-in.md` | 48 | Wake-up mechanics: Claude Code background perl timer, a bounded in-turn fallback loop, and a "Codex app self-wake: TO VERIFY" note | Collapses to two lines in SKILL.md pointing at `ntm --robot-attention` / `--robot-wait`. The TO-VERIFY note has sat unverified since 2026-07 — carrying an open question as documentation is worse than deleting it | `ntm --robot-attention` / `--robot-wait` (attention contract v1.2.0), plus the harness's own scheduled wake-up | deleted |

## 5. Guard-by-guard disposition (all 20)

`references/guards.md` is the only row where content could be lost rather than moved. Every
guard is accounted for below.

### 5a. Retained — 5 guards become 4 inline rules in the rewritten SKILL.md

| Guard | Becomes | Why it must exist |
|---|---|---|
| G1 no-controller-pane + G15 no-subagent-fanout | **One Claude client** | One root cause: a second same-account Claude client contending for one rate limit. This is the reason the skill exists, and it is a real delta from jsm — ntm ships `--robot-controller-spawn` and the jsm stack assumes you may use it |
| G13 (lease half) | **Conductor lease** | Dual-conduct is observed, not theoretical. `vibing-with-ntm` is stateless per tick and has no equivalent |
| G13 (journal half) | **Journal + re-entry** | The only durable repo-local state surviving compaction/fork/handoff. `ntm --robot-events`/`--robot-replay` are session-scoped and windowed (`retention_period: 1h`) |
| G14 ship-bead-gating + G18 gate-human-beads | **Gate non-worker beads** | Both observed racing. Nothing in the jsm set gates on behalf of a human |

### 5b. Relocated — 5 guards, each with a landing bead

| Guard | Destination | Bead | Landed? |
|---|---|---|---|
| G3 env-preflight | `skills/engineering/flywheel-local-launcher/**` | `skills-fc-rework-tfx.2` | **not yet** |
| G3.5 codex-update-preflight | `skills/engineering/flywheel-local-launcher/**` | `skills-fc-rework-tfx.2` | **not yet** |
| G4 one-shot-only | `prompts/p-agent-swarm-launcher.md` | `skills-fc-rework-tfx.3` | **not yet** |
| G5 exact-tooling | `prompts/p-agent-swarm-launcher.md` | `skills-fc-rework-tfx.3` | **not yet** |
| G11 serial-chains | `prompts/p-plan-to-beads.md` | `skills-fc-rework-tfx.4` | **not yet** |

**None of the five relocations has landed at the time of writing.** The approval gate now
depends on all three relocation beads (dependency rewired in this bead, since Ryan ordered
the manifest first), so approval cannot fire until the destinations actually exist. Nothing
should be deleted from `guards.md` before this table reads "landed" on every row.

### 5c. Covered elsewhere — 2 guards, no relocation needed, verified

| Guard | Covered by | Verification |
|---|---|---|
| G12 simple-commands (DCG false positives) | the `dcg` skill | Confirmed installed at `~/.claude/skills/dcg`; this repo also ships `tools/dcg`. Nothing to move |
| G16 human-tasks-as-chat | `prompts/p-hitl.md` | Confirmed present in this repo and installed at `~/.claude/commands/p-hitl.md`. It states the rule better than G16 did, and is independently invocable |

### 5d. Folded into the rewritten loop — 4 guards, content preserved but not as sections

| Guard | Where its content goes | Residual risk |
|---|---|---|
| G6 assignment-gap | Loop line ("idle pane + ready work → hand it a named non-conflicting bead") + `ntm work queue-dry`. Its hard-won operational detail — `ntm send --cod` broadcasts type into an idle Codex TUI **without submitting**, so targeted send-keys + double-Enter is the only reliable channel — is explicitly retained in `references/commands.md` by bead `.10` | Low, provided `.10` keeps that reasoning and not just the command |
| G8 hang-vs-deep-work | Inline judgment in the loop, generalised by the Intervention Score Matrix | Low — it was always explicitly the call scripts cannot make |
| G9 route-around-locks | Loop line | **See §5e item 3** — the safety half needs an explicit home |
| G10 stale-bead-reconciliation | Partly `ntm work queue-dry` (`sync` state, stale in-progress) | **See §5e item 4** |

### 5e. No destination — 4 items Ryan should decide on

The plan claimed the non-relocated guards were safe to drop. Having read them line by line
against their destinations, **four are not cleanly safe**. Listing them rather than
smoothing over it:

1. **G17 evidence-integrity — no destination.** The rule: any live-system claim must record
   the exact command *and* the resolved deployment identity as evidence; use machine formats
   for counts, not human table output; if the evidence method is compromised the bead FAILS
   rather than publishing. Evidence: customer-kingfield 2026-07-05, a doc published "0 rows"
   for 8 tables after a stray deploy key silently redirected a "prod" read, and nearly drove
   a table-deletion approval. Not covered by `dcg` or `p-hitl`. The plan said it "belongs in
   the worker prompt / a review skill" but **no bead was created to put it there.**
2. **G19 whole-pr-sweep — no durable destination.** The rule: per-bead staged checks are
   local and miss risk accumulated across a long branch; the ship/reality-check bead must
   sweep the whole PR diff. Evidence: customer-kingfield 2026-07-07, PR126 had zero
   staged-warning commits but a whole-PR sweep found dozens of warning candidates. Its
   content *is* written into this epic's ship bead (`.12`), so this epic is protected — but
   for a **portable skill**, that means the rule survives only in one bead's text and is lost
   for every future swarm.
3. **G9's safety half — needs to be named, not implied.** "Never force-release another
   agent's reservation for scheduling convenience" is a safety rule, not a scheduling tip.
   "Hand the idle worker a different bead" is the scheduling half and folds fine; the
   no-force-release half must appear verbatim in the rewritten SKILL.md or it is gone.
4. **G10's done-definition — needs a home.** "A bead is done only after commit AND push of
   its explicit scope paths; closed beads with dirty scope paths must be reopened" is a
   *worker* instruction. `queue-dry` reports sync state but does not teach a worker what done
   means. Natural home is `prompts/p-agent-swarm-launcher.md`, alongside G4/G5.

**Recommendation:** add one more relocation bead covering items 1, 2 and 4 into
`prompts/p-agent-swarm-launcher.md` (G17, G19, G10's done-definition), and add item 3 to
bead `.8`'s acceptance criteria as a required verbatim line. That is a small amount of work
and it converts "probably fine" into "accounted for". **I have not created that bead** —
it changes the shape of an approved plan, so it is Ryan's call.

## 6. Assets — 127 lines, 3 files

| Path | Lines | What it does today | Why it goes | Source of truth after removal | Disposition |
|---|---:|---|---|---|---|
| `assets/journal.schema.json` | 68 | JSON Schema for one journal line (`checkin` / `lesson` / `certification`) | A 68-line schema validating a four-field append-only log, never invoked at runtime by anything in the skill | A three-line inline example in the rewritten SKILL.md | deleted |
| `assets/candidate-guard.md` | 24 | Template for Step 6 write-back: Signal / Diagnosis / Fix / Evidence / proposed index row | Deleted with Step 6. A formal guard-authoring pipeline maintaining a list that is about to be four items long is ceremony | Lessons become ordinary beads in this repo | deleted |
| `assets/worker-kickoff.md` | 35 | Fallback worker init-prompt for when slash-prompts are not bridged into codex panes | A duplicated worker loop that drifts from the prompt is worse than no fallback | `prompts/p-agent-swarm-launcher.md` is the single source; this repo now ships `p-install-agent-skill` for bridging | deleted |

## 7. The certify leak, for the record

Relevant to `skills-bhf`, which asks whether to patch this rather than delete it. Verified in
the current file:

- Line 64 links the sandbox into `projects_base`.
- Line 84 installs `trap cleanup EXIT`.
- **Twenty lines sit between them** (`br init`, epic creation, three bead creations). A
  failure anywhere in that window leaks the symlink with no cleanup path at all.
- `cleanup()` (lines 76–83) never removes the symlink or the sandbox even on success — it
  kills the tmux session and prints a comment asserting the temp dir is "OS-cleaned".

Six stale `fwcert*` symlinks accumulated in `projects_base`, exactly as `skills-bhf` reports.
If certify is kept as an approval exception, the fix must install the trap **before** the
link call; patching only the cleanup body leaves the twenty-line window open.

## 8. What survives

| Path | Lines now | After |
|---|---:|---|
| `SKILL.md` | 159 | rewritten, ~110 (bead `.8`) |
| `references/commands.md` | 169 | trimmed, ~90 (bead `.10`) |
| `SELF-TEST.md` | — | new, ~25 (bead `.9`) |

## 9. Approval status

**PENDING. No approval has been given.** The delete pass (`skills-fc-rework-tfx.7`) must not
run until the gate (`.6`) records Ryan's decision, and the gate cannot become ready until the
five relocations in §5b have actually landed.
