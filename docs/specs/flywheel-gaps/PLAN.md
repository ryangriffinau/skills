# Flywheel gap-closure — kingfield run write-back

> Source: `customer-kingfield/docs/specs/flywheel-verification/gap-analysis.md` (19 items,
> 2026-07-03) — the first full third-party-repo flywheel run. This plan is the conductor
> Step 6 write-back for it, shaped by three disciplines: **codebase-design** (deepen
> interfaces; hide implementation detail), **coding-standards** (parse boundary input,
> typed failure channels, real-seam tests), **writing-great-skills** (steps end on
> checkable completion criteria; reference at the right hierarchy tier; no new skill
> without a distinct leading word).

## 0. Reconciliation — gaps already closed before this plan

| Gap | Status |
|---|---|
| #2 `.flywheel/runtime/` gitignore in setup | ✅ fixed (PR #5/#6 era) — kingfield ran a **stale install**, which is itself gap V8 |
| #19 lightweight verify | ✅ mostly — `flywheel-link.sh verify` (PR #6/#7) is the light path; V8 documents routing (verify vs certify) |
| #16 `ntm respawn` → bare shell | ✅ guard G7 + kickoff already steer kill+fresh-spawn; certify now *proves* it (keep; one doc line in V5) |
| #14-adjacent G15 (plan-anticipation) | 📋 open bead `skills-yb0` — **merged into V5** |
| npx deletion bug | 📋 open bead `skills-4bq` — **merged into V8** |

Everything else is open and covered below.

## 1. Design stances (why the fixes take these shapes)

- **Deepen, don't patch (codebase-design).** #10's bug is a *shallow interface leaking an
  implementation detail*: child-detection depends on the dotted-id string shape. The fix
  deepens the module — same CLI surface, child-detection reads beads' **real
  `parent-child` dependency metadata** (verified present: 51 entries in a live
  `issues.jsonl`), dotted-prefix demoted to fallback.
- **The launcher's `setup` is the front door; it must own repo-integration.** A setup that
  leaves the repo's own linter red (#1), lets tools mutate tracked files mid-swarm (#5),
  or leaves the old workflow's entrypoints live (#6) has not completed setup. Completion
  criterion for `setup` becomes: *the next swarm run makes zero unexpected tracked-file
  changes and CI stays green on a no-op PR*.
- **Race windows close at encode time, not react time (Emmanuel).** #14 + G15: reactive
  gating loses to a worker's `br ready` loop. Conductor-owned beads get their hold
  **written into the graph at encode** (p-plan-to-beads), before any worker exists.
- **Exact interfaces beat discovery (G5).** #7/#8/#13: agents burn tokens or fail silently
  when flags/ordering are guessable-but-wrong. The cure is *in-skill reference* — exact
  per-subcommand flag tables and step ordering — at the right hierarchy tier
  (commands.md / cheatsheet, not SKILL.md bloat).
- **No new skills.** Every change lands inside `flywheel-local-launcher`,
  `flywheel-conductor`, or the prompts — no distinct leading word justifies a split
  (writing-great-skills granularity test). One new *script* (V2) joins the launcher's
  existing script family.

## 2. Units (disjoint file ownership)

| Unit | Gaps | Owns | Deps |
|---|---|---|---|
| **V1 Projection reads real parent metadata** | **#10 (P1, top risk)** | `scripts/beads-linear-sync`, `tests/beads-linear-sync.test.sh` | — |
| **V2 `beads-linear-map` helper** | #11, #12 | new `scripts/beads-linear-map`, `tests/beads-linear-map.test.sh`, setup.md §projection | — |
| **V3 `setup` absorbs repo-integration** | #1 (P1), #3, #4, #5 | `scripts/flywheel-link.sh`, `tests/flywheel-link.test.sh` | — |
| **V4 Case A decommission checklist** | #6 (P1) | launcher `SKILL.md` (Onboarding §), cheatsheet §2 | — |
| **V5 Conductor ordering + encode-time gating** | #13 (P1), #14 (P1)+G15+`skills-yb0`, #15, #17b, #18 | conductor `SKILL.md`, `references/commands.md`, `references/guards.md`, `assets/worker-kickoff.md`, `prompts/p-agent-swarm-launcher.md`, `prompts/p-plan-to-beads.md` (gating clause) | — |
| **V6 Exact `br` reference + resolver path** | #7, #8, #9 | launcher `references/cheatsheet.md` (flag table), `prompts/p-plan-to-beads.md` (path) — *coordinate with V5's p-plan-to-beads edit (serial dep)* | V5 |
| **V7 DCG upstream report** | #17a | draft GitHub issue (post only with user approval) | — |
| **V8 Install-staleness defense** | `skills-4bq`, meta-cause of #2/#19 reappearing | `scripts/flywheel-link.sh` preflight (staleness probe), setup.md §Updating | V3 |
| **V9 Broad reality-check** | closer | — | all |
| **V10 Ship** (team: PR ready → merge green → refresh installs — via the V8-documented reliable path) | closer | — | V9 |

### V1 — child-detection by metadata (the run's top risk)
Parse each JSONL line's `dependencies` array for `"type":"parent-child"` entries to build
the epic→children set; keep dotted-prefix as fallback **only when an epic yields zero
metadata children**, and log which mode ran (typed failure channel: `parent-metadata` vs
`dotted-fallback` vs `no-children`). Interface unchanged (`--repo/--all/--dry-run`).
**Tests at the real seam:** fixture JSONL with (a) `--parent` dotted children, (b)
dependency-linked children with non-dotted ids, (c) both, (d) neither → asserts counts +
mode line. *Acceptance: case (b) — which today posts "no children" — computes correctly.*

### V2 — `beads-linear-map <epic> [--create "Name" --team "Team"]`
One deep helper hiding the whole mapping ritual: resolves `LINEAR_API_KEY` via
`flywheel-env`, `projectCreate` via GraphQL when `--create` (else takes an existing
`--project-id`), appends `epic<TAB>project-id` to `.flywheel/projects.tsv` with a real
tab, idempotent (re-run = no dup line), fail-open messaging consistent with the sync.
Documents the API-key path (the Linear MCP needs interactive OAuth — unavailable
headless, #11). *Acceptance: fresh repo → one command → valid tsv line + project visible
via the sync's auth probe.*

### V3 — `setup` repo-integration (completion = quiet tree)
- **Linter ignores (#1):** detect `biome.json[c]` / `.eslintrc*` / `.prettierignore` /
  `ruff.toml`; print the exact ignore lines for `.beads/`, `.ntm/`, and append them where
  a safe append-target exists (`.prettierignore`-style files); never rewrite structured
  configs (biome/eslint) — print-and-instruct instead. Loud warning either way.
- **Gitignore (#3/#4):** add `.bv/` and `.ntm/` alongside the existing
  `.flywheel/runtime/` block (team repos: `.ntm/config.toml` embeds machine-local paths).
- **AGENTS.md injection (#5):** after `br init`, invoke the injection deliberately (run
  `bv --robot-triage >/dev/null` once or `br`'s doc-inject if exposed), then tell the user
  to commit it as part of setup — so it can never appear mid-swarm on a tracked file.
*Acceptance (the new setup completion criterion): after setup on a lint-enforcing fixture
repo, `git status` shows only intended files and the repo's own linter passes.*

### V4 — Case A decommission checklist (docs)
The Onboarding section's Case A gains an explicit **retire-the-old-system** step with an
exhaustive completion criterion: enumerate `package.json` scripts, CI workflow files,
tooling scripts, and docs entrypoints of the old system → archive/remove each (RULE 1:
archive) → *"grep finds zero live invocations of the old system outside `archive/`"* (#6).

### V5 — conductor ordering + encode-time gating
- **Step 0 (#13):** `register_agent` **before** the lease reservation — exact order + the
  registration_token requirement in commands.md (evidence: this session hit the same).
- **Encode-time gating (#14 + G15 + `skills-yb0`):** p-plan-to-beads gains a rule — beads
  the conductor will drive (cross-repo, live-projection, ship when workers may live) are
  encoded **with a dep on a conductor HOLD bead at creation**. New guard **G15
  plan-vs-graph-fence-coherence** in guards.md: graph fences must be paired with the
  worker-kickoff line "work ONLY `br ready`; never anticipate units from the plan doc"
  (line lands in worker-kickoff.md + p-agent-swarm-launcher).
- **#15:** commands.md note — `--assign`/coordinator "assigned 0" is normal; self-claim is
  the dependable mechanism; verify a claim within one check-in (G6 already covers the fix).
- **#17b:** journal-writing rule — never embed command-like strings in journal/log lines
  (DCG substring-matches quoted payloads).
- **#18:** worker kickoff passes the ntm pane identity into Agent Mail `register_agent`
  (`name=<ntm pane identity>`), one name per worker.

### V6 — exact `br` reference + resolver path
Cheatsheet gains the per-subcommand flag table: `create -d/--description` · `update
--description` (NOT `-d`) · `close -r/--reason` (NOT `-m`); never combine `--force` with a
status change; check exit codes — no `>/dev/null` in gating loops (#7/#8).
p-plan-to-beads resolver path (#9): try repo-local
`skills/engineering/flywheel-local-launcher/scripts/flywheel-profile.sh`, else
`~/.claude/skills/flywheel-local-launcher/scripts/flywheel-profile.sh`, else solo default.

### V7 — DCG upstream report (#17a)
Draft the issue for `Dicklesworthstone/destructive_command_guard`: substring-matching
inside quoted payloads (a JSON journal line containing `git checkout --` text blocked a
`printf >> journal`); repro + suggestion (parse the command, don't scan args). **Post only
after user approval** (outward-facing).

### V8 — install-staleness defense (`skills-4bq`)
The meta-gap: kingfield ran a stale setup, so "fixed" gaps re-bit. (a) `preflight` gains a
staleness probe: when the canonical repo exists locally, compare installed SKILL.md
`version:` vs repo — warn "installed launcher vX < repo vY; refresh". (b) setup.md
§Updating documents the reliable refresh (npx update; on '✗ Failed' — its file-deletion
bug — the direct-copy fallback) and the verify-vs-certify routing (#19): `verify` =
seconds, per-repo readiness; `certify` = minutes, real-agent proof, first conduct only.

## 3. Sequencing

Parallel roots: V1, V2, V3, V4, V5, V7 · V6←V5 (shared p-plan-to-beads file) · V8←V3
(shared flywheel-link.sh) · V9←all · V10←V9. Worker-able: V1, V2, V3, V6, V8 (script+test
units). Conductor-inline: V4, V5 (skill-of-the-conductor edits), V7 (user approval), V9,
V10. **Per G15: conductor-inline units get their HOLD dep at encode time.**

## 4. Acceptance (whole plan)

1. Fixture-proven: dependency-linked (non-dotted) children project correctly (V1).
2. One command maps an epic to a new Linear project with a valid tsv line (V2).
3. Setup on a biome-fixture repo → linter green + quiet tree + AGENTS.md injection done
   at setup, not mid-swarm (V3).
4. kingfield's five P1s each map to a landed change or a documented upstream report.
5. All launcher/conductor test suites green; docs coherent; installs refreshed via the
   V8-documented path; `skills-yb0` + `skills-4bq` closed as folded-in.
