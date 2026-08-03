# flywheel-conductor — simplification + jsm-lessons rework

Plan of record for `skills-bwv`. Planning only; no implementation in this document.
Supersedes `plan.md` (the 2026-07-01 build plan) and `sustain-mode-PLAN.md` for everything
they specify about scripts, guards, evals, and sustain mode.

**Verdict up front:** the conductor is ~2,000 lines and 14 eval fixtures implementing a
swarm observer that `ntm` now ships natively, plus a 20-guard playbook whose majority
belongs to other skills. The rework deletes ~85% of it and keeps the four things that are
actually conductor-specific. Target end state: **3 files, ~250 lines**, down from 12 files
+ 14 fixtures, ~1,993 lines.

---

## 1. Why this skill still exists (the constraint that shapes every cut)

`skills-2da` settled it: teammates without a jeffreys-skills.md subscription cannot use the
jsm skill set and still need to drive a swarm. This skill is the **honest fallback**, and
its SKILL.md preflight now says so out loud.

That gives one hard design constraint, which is also the precise reading of "adopt the
better shape rather than reinventing it":

> **Adopt jsm's shape and its native tool calls. Never take a jsm skill as a dependency.**

The distinction is load-bearing and verifiable: the *tools* are free and installed
independently of any subscription (`ntm` → `/opt/homebrew/bin/ntm` 1.18.3, `br`, `bv`,
`ubs`), while the *skills* that wrap them (`vibing-with-ntm`, `beads-bv`, `rch`, …) are the
paid layer. So the conductor may call `ntm --robot-snapshot` freely; it may not say "see
/vibing-with-ntm". Everywhere the current skill hand-rolls an observer, the fix is to call
the free tool — not to copy the paid skill's prose.

Corollary, already observed on this machine: **skill installed ≠ tool present** (the `rch`
skill is installed; the `rch` binary is not). The conductor must therefore probe
`ntm --robot-capabilities` rather than assume a verb exists.

---

## 2. What ntm already does that the conductor re-implements

Verified against ntm 1.18.3 on this machine, not assumed:

| Conductor artifact | Native replacement | Evidence |
|---|---|---|
| `conductor-poll.sh` pane classification (199 lines of regex over `capture-pane` tails) | `ntm --robot-snapshot` → typed `agents[]` with `state`, `last_output_age_sec`, `type`, `type_confidence`, `pending_mail`, under schema `ntm:robot:snapshot:v1` | ran it; returns the full shape |
| `conductor-poll.sh` bead rollup | `ntm --robot-beads-list`, `br ready --json` | native |
| `conductor-triage.sh` "what next" scoring | `ntm --robot-triage` → scored `top_picks[]` with `reasons[]` and `unblocks` | ran it; scored `skills-v18` at 0.27 with 4 reasons |
| Step 4 loop-exit ("epic 100% closed") | `ntm work queue-dry` → `safe_to_stand_down` + quiescence reasons + sync state | ran it; returned `unsafe_to_stand_down / quiescence.ready_work` |
| `references/check-in.md` perl sleep timer | `ntm --robot-attention` / `--robot-wait` (cursor + attention contract v1.2.0) | present in `--robot-capabilities` |
| G7 respawn recipes | `ntm --robot-smart-restart`, `--robot-health-restart-stuck` | present |
| Sustain-mode wall parser (whole subsystem) | `ntm --robot-quota-status` (typed: `providers`, `has_warning`, `has_critical`), `--robot-health-oauth` | ran it; correct shape, `caut_available:false` here — see §5 |
| Submit-verification ("confirm `Working`") | `ntm --robot-is-working=<session>` | present |

The pane-state regexes are the sharpest case. `conductor-poll.sh:160` matches
`Working \((\d+h)?(\d+m)?(\d+s)?` and `:170` matches a shell prompt as `[$%]\s*$` against
Codex TUI chrome. That is a private contract with another program's redraw output — it
breaks silently on any Codex UI change, and it is exactly what ntm computes internally and
publishes with a confidence score and a versioned schema.

---

## 3. What gets DELETED

Named explicitly, per the bead's acceptance criteria. ~1,700 lines and 14 fixtures.

### 3.1 Scripts and their test apparatus — delete outright

| Path | Lines | Why |
|---|---|---|
| `scripts/conductor-poll.sh` | 199 | Superseded by `--robot-snapshot` + `br ready --json`. Its only unique output was the regex pane state, which is the part most likely to be wrong. |
| `scripts/conductor-triage.sh` | 126 | Its five deterministic rules map 1:1 onto native signals (G2→config check, G3→blocked beads, G6→queue-dry, G7→`--robot-activity`, G8→judgment, which it already refused to decide). Its `--llm` path shells out to `codex exec` to classify a pane tail — an entire second agent invocation to answer a question the conductor is sitting right there to answer. |
| `tests/conductor-poll.test.sh` | 170 | Tests a deleted script. |
| `tests/conductor-triage.test.sh` | 37 | Tests a deleted script. |
| `evals/fixtures/*.json` + `evals/expected/*.json` | 14 files | Canned poll outputs for a deleted script. They test our regex against our own captures — they never caught a real Codex UI change, and could not. |
| `scripts/conductor-certify.sh` | 168 | See §4 — this is the `skills-bhf` decision. |

### 3.2 The guard playbook — 20 guards down to 4

`references/guards.md` (337 lines) is **deleted as a file**. Four rules survive and move
inline into SKILL.md; the rest are deleted or relocated. Every retained rule carries its
reason, per the acceptance criteria.

**RETAINED — genuinely conductor-specific, nothing else covers them:**

| Rule | Reason it must exist |
|---|---|
| **One Claude client** (was G1 + G15) | The founding constraint and the reason this skill exists at all. A `ntm controller` cc pane and conductor-side Agent-tool fan-out are the *same* bug: a second same-account Claude client contending for one rate limit. ntm actively offers `--robot-controller-spawn`, and jsm's stack assumes you may use it — so this is a real delta from jsm, not a restatement. Evidence is strong on both halves (AT session controller ERR; kingfield burned ~90% of quota on 8 local subagents). Merged into one rule because they have one root cause. |
| **Conductor lease** (was G13) | Dual-conduct is a real observed hazard (a forked session kept conducting while its successor took over), and `vibing-with-ntm` has no equivalent — it is stateless per tick. This plus the journal is the conductor's only genuine differentiator. Cost is near zero: one Agent Mail reservation on `.flywheel/CONDUCTOR`. |
| **Gate non-worker beads** (was G14 + G18) | Ship beads and human-gated beads are ordinary claimable work to a swarm the instant their blocker closes. Both were observed racing (duplicate ship PRs; H2/MIRROR-2 surfacing into `br ready`). Merged: one rule, "anything a human or the conductor owns is gated at encode time or the moment it becomes ready." Nothing in the jsm set gates on behalf of a human. |
| **Journal + re-entry** (was the Step 0 half of G13) | The one piece of durable repo-local state that survives compaction, fork, and handoff. `ntm --robot-events`/`--robot-replay` are session-scoped and windowed (`retention_period: 1h`); the journal is the repo's own record. |

**DELETED — covered better elsewhere, and the pointer is free:**

| Guard | Disposition |
|---|---|
| G12 simple-commands (DCG false positives) | Delete. The `dcg` skill is installed and owns this; this repo also ships `tools/dcg`. |
| G16 human-tasks-as-chat | Delete. `prompts/p-hitl.md` in this repo is exactly this rule, better stated and independently invocable. |
| G4 one-shot-only, G5 exact-tooling | Delete from the conductor. These are **worker** behaviours; their real home is `prompts/p-agent-swarm-launcher.md`, which the workers actually read. A conductor-side guard fires only after a worker has already hung for 10 minutes. |
| G6 assignment-gap, G9 route-around-locks | Delete as named guards. Both reduce to "idle pane + ready work → hand it a named non-conflicting bead", which is one line of the loop, not two playbook sections. |
| G8 hang-vs-deep-work | Delete as a guard; **keep the judgment inline in the loop**, where it belongs. It was always explicitly "the one call scripts can't make" — writing 14 lines of playbook about a judgment call does not make the call. |
| G17 evidence-integrity, G19 whole-pr-sweep | Delete from the conductor. These are verification rules for the reality-check/ship beads and the worker prompt. They landed here only because the conductor was where kingfield's lessons happened to be written down — that is sediment, not design. |
| G11 serial-chains | Delete from the conductor; the rule ("chains are enforced by graph deps, not prompts") is an **encode-time** rule belonging to `p-plan-to-beads`. Keep one line in the conductor's encode check. |
| G10 stale-bead-reconciliation | Delete the section; keep one line in the loop. `ntm work queue-dry` already reports `sync` state and stale in-progress. |
| G3 env-preflight, G3.5 codex-update-preflight | Delete from the conductor and **relocate to `flywheel-local-launcher`**, which already owns `flywheel-link.sh preflight` and is where both checks actually run. The conductor's Step 1 already just delegates to it. |
| G2 config-valid | **Verify before deciding.** The claim is that one unknown field silently rejects the whole ntm config and reverts codex to `xhigh`. I could not reproduce it — the config on this machine is clean and `ntm config show` printed no warning. If ntm ≥1.18 now fails loudly, delete the guard; if the footgun is live, it survives as one line in the preflight, not a playbook section. **This is the plan's one open question, and it is a five-minute experiment, not a discussion.** |

### 3.3 Assets — delete three of three

| Path | Why |
|---|---|
| `assets/journal.schema.json` | A JSON Schema for a four-field append-only log. Replace with a three-line example inline in SKILL.md. The schema was never validated against anything at runtime. |
| `assets/candidate-guard.md` | Template for Step 6 write-back — deleted with Step 6 (below). |
| `assets/worker-kickoff.md` | Fallback init-prompt for when slash-prompts aren't bridged into codex panes. `prompts/p-agent-swarm-launcher.md` is the single source, and this repo now ships `p-install-agent-skill` for bridging. A duplicated worker loop that drifts from the prompt is worse than no fallback. |

### 3.4 Steps and modes

- **Step 6 (write-back) — deleted**, with `assets/candidate-guard.md`. A formal
  guard-authoring pipeline that files beads about itself, maintaining a list that is about
  to be four items long, is ceremony. Lessons become ordinary beads in this repo like every
  other improvement.
- **`references/check-in.md` — deleted** (48 lines). The perl sleep timer and the
  "bounded in-turn loop" fallback collapse to two lines in SKILL.md pointing at
  `--robot-attention` / `--robot-wait`, with the harness's own scheduled wake-up as the
  Claude Code form. Its "Codex app self-wake: TO VERIFY" note has sat unverified since
  2026-07; delete the note with the file rather than carry an open question as documentation.
- **Sustain mode — the specified implementation is deleted before it is built.** See §5.

### 3.5 Repo docs

`README.md:62` claims flywheel-conductor "has moved to `deprecated/` pending a complete
rework." There is no `deprecated/` directory, the skill is live at
`skills/engineering/flywheel-conductor/`, and `skills-bhf` explicitly reverses the
deprecation. Delete that line and restore the skill's row in the skills table.

---

## 4. `conductor-certify.sh` — the skills-bhf decision

`skills-bhf` is blocked on this plan and asks three questions before anyone patches the
trap. Answering them in order:

**Is the fix high-value?** The leak is real and worse than the bead describes. `certify`
links its sandbox into `projects_base` at line 64 and installs `trap cleanup EXIT` at line
84 — so any failure in the twenty lines between them (`br init`, epic creation, three bead
creations) leaks the symlink with *no* cleanup path at all. And `cleanup()` never removes
the symlink or the sandbox even on the success path; it only kills the tmux session and
prints a comment claiming the temp dir is "OS-cleaned". Six stale `fwcert*` symlinks
accumulated, exactly as reported.

**Is it the simplest fix available?** No — because the simplest fix is to delete the script.

**Does it align with the real jsm process?** No, and this is decisive. The jsm skills prove
their contract with `SELF-TEST.md`: ~10 lines of copy-pasteable assertions that the tools
they depend on actually answer (`bv --robot-plan | jq -e '.plan.tracks | type == "array"'`).
Cost: zero tokens, two seconds, no side effects. `conductor-certify.sh` spends real tokens,
spawns a real codex worker, runs up to 20 minutes, requires `--yes`, mutates
`projects_base`, and what it actually proves is that **ntm can spawn a worker and recover a
killed pane** — it tests ntm, not the conductor.

**Decision: delete `conductor-certify.sh` and replace it with `SELF-TEST.md`** in the jsm
shape — assert that `ntm --robot-capabilities` lists the verbs the skill calls, that
`--robot-snapshot` parses, that `br ready --json` answers, and that an Agent Mail
reservation can be taken and released. That is the contract the conductor actually depends
on, and it is checkable in seconds by a teammate who has never run a swarm.

**Conditional fallback (must be carried, not dropped):** if this plan is rejected and
certify is retained, the trap fix is required *and* the current patch shape is insufficient
— the trap must be installed **before** the `flywheel-link.sh link` call, and `cleanup()`
must remove both the projects_base symlink and the sandbox dir on pass and fail. Patching
only the trap body, as `skills-bhf` currently reads, leaves the 20-line unguarded window
open.

---

## 5. Sustain mode — delete the subsystem, keep the human contract

`sustain-mode-PLAN.md` (with its two drafts) specifies: a wall-phrase parser with a
greppable phrase list, a typed `usage_reset` record with local-time resolution and
past-time ambiguity handling, retry caps, a new `references/sustain-mode.md`, a new `"mode"`
journal line type, and a test-fixture suite including must-not-fire cases.

Almost all of that is a bespoke re-implementation of `ntm --robot-quota-status` (typed:
`providers`, `has_warning`, `has_critical`, `total_cost_today_usd`) and
`--robot-health-oauth`, plus `--robot-is-working` for the submit-verification the draft
specifies by hand. `vibing-with-ntm` reaches the same conclusion from the other side: its
"rate-limit mirage" pathology card says pane text mentioning a reset time is *the
unreliable source* and to probe provider state instead.

**Delete:** the parser, the phrase list, the typed record spec, the fixtures, the separate
reference file, and the new journal line type.

**Keep — because ntm genuinely does not have it:** the human contract Ryan specified, which
is a consent protocol, not a mechanism. Ask once per session before the first unattended
wait; approval persists for the session; a decline is not re-asked; emit a one-line status
on arm, wake, and verify. That is roughly six lines in SKILL.md.

**Honest caveat:** `--robot-quota-status` returned an empty `providers` map with
`caut_available: false` on this machine, so the typed source is not universally populated.
The fallback is a pane-text grep — *one grep*, in the loop, explicitly labelled a fallback.
It does not get a fixture suite, because a fallback that needs a fixture suite is a
subsystem wearing a disguise.

---

## 6. What gets ADOPTED from the jsm shape

Shape, not dependency. Each of these replaces something longer.

1. **Decision-tree-first layout.** `vibing-with-ntm` opens with "if you are tending a swarm
   right now, jump here; everything else is context." The conductor's numbered Steps 0–6
   force a teammate mid-incident to read a build sequence. Adopt: a short decision tree at
   the top, setup below it.
2. **The Intervention Score Matrix** — `Score = (Evidence × Impact × Reversibility) /
   BlastRadius`, act only at ≥ 2.0. This is the single highest-value adoption: it is a
   *generalisation* of the guard playbook. Sixteen named guards were sixteen worked examples
   of one scoring rule. Keeping the rule and deleting the examples is the whole
   simplification thesis in one line.
3. **Grounding table** — where truth lives (pane snapshot, work graph, mail, git, snapshot
   deltas), and the rule that when a source and an agent's self-report disagree, the
   artifact wins. Replaces the conductor's scattered "verify within one check-in" clauses.
4. **An explicit "delivered" definition** — every pane is progressing, explicitly blocked
   with a handoff, or standing down by policy; "idle and you don't know why" is not a
   terminal state. The conductor currently has per-step completion criteria but no
   session-level one.
5. **Convergence triple-check + queue-dry stand-down** — ready queue empty AND no in-flight
   work AND no expected upstream signals, backed by `ntm work queue-dry`'s
   `safe_to_stand_down`. Replaces "loop exits when the epic is 100% closed", and encodes
   the standing rule that a dry queue means stop, not manufacture work.
6. **`SELF-TEST.md` over `evals/` + `tests/`** — §4.

Deliberately **not** adopted: `vibing-with-ntm` is 863 lines. Its length is affordable for a
subscription skill that is the operator's primary reference. This one is a fallback for a
teammate who does not have that skill — its value is being short enough to read in full
before their first swarm.

---

## 7. End state

```
skills/engineering/flywheel-conductor/
├── SKILL.md            ~110 lines  preflight (jsm) → decision tree → 4 rules → loop → endgame
├── SELF-TEST.md         ~25 lines  tool-contract assertions, zero side effects
└── references/
    └── commands.md      ~90 lines  conductor-specific cookbook only (lease, journal,
                                    targeted re-prompt, teardown); everything ntm answers
                                    natively becomes a --robot-* call in SKILL.md
```

| | Before | After |
|---|---|---|
| Files | 12 + 14 fixtures | 3 |
| Lines | ~1,993 | ~250 |
| Shell scripts | 3 (493 lines) | 0 |
| Guards | 20 | 4 rules |
| Token cost to verify | one live codex worker, ≤20 min | zero |

Version target `0.4.0`, `status: drafting` retained — the rework invalidates the existing
evidence base, so it re-earns maturity through use, not through this document.

## 8. Sequencing

1. **Verify G2** (§3.2) — the one open question; five-minute experiment with a deliberately
   broken ntm config field. Gates whether the preflight keeps a config-validity line.
2. **Delete pass** — scripts, tests, evals, guards.md, check-in.md, assets. One commit,
   nothing else changes; the skill is briefly broken by design and that is visible.
3. **Rewrite SKILL.md** against the native `--robot-*` calls and the §6 shape.
4. **Write SELF-TEST.md**; run it; it must pass on a machine with no jsm subscription.
5. **Trim `references/commands.md`** to what SKILL.md still points at.
6. **Relocate** G3/G3.5 to `flywheel-local-launcher`; G4/G5 to `p-agent-swarm-launcher`;
   G11's encode rule to `p-plan-to-beads`. Each is a separate small PR-sized change and
   must land, not be dropped on the floor — this is the step most likely to be skipped.
7. **Fix `README.md:62`** and restore the skills-table row.
8. **Close `skills-bhf`** with §4's verdict: certify deleted, leak resolved by deletion.

## 9. Risks

- **Deleting evidence with the guards.** guards.md carries real dated incidents. Mitigation:
  step 6 relocates the rules that still have an owner; the incidents themselves are in
  session history and `cass`, not uniquely in this file.
- **`--robot-*` surface drift.** Trading our regexes for ntm's schema trades a private
  contract for a published one — better, but not free. Mitigation: `SELF-TEST.md` asserts
  `--robot-capabilities` lists what we call, so drift fails loudly and cheaply.
- **ntm absent or older than 1.18.** The conductor's preflight must degrade honestly: if
  `--robot-capabilities` lacks a verb, say so and hand back, rather than silently falling
  back to tmux scraping. Do not resurrect the deleted regexes as a fallback path.
- **Relocation gets skipped** (step 6), leaving G3/G4/G5/G11 deleted but not rehomed. This
  is the plan's most likely real failure. Mitigation: each relocation is its own bead with
  the destination file in its acceptance criteria, and the delete-pass bead depends on them.
