---
summary: "Design + implementation plan for the weekly engineering-practices review system (engineering-review skill + docs/reviews home), tailored to the platform monorepo."
status: proposed
read_when:
  - "Building, extending, or operating the weekly engineering review."
  - "Picking up an unfinished unit of the engineering-review workstream."
---

# Weekly Engineering-Practices Review — Design & Implementation Plan

> **Self-contained.** This plan assumes no other context. It describes a system that produces a **weekly, longitudinal, graded scorecard** of a codebase's engineering practices — modelled on a worked example (the "reg-scorecard end-to-end review": a 37-agent, multi-lens review that grades areas A–F, attaches file:line findings with fix contracts, re-statuses prior findings, and shows week-over-week trend arrows). The first target is the BackPocket `platform-monorepo`; the engine is a portable skill reusable on any repo.
>
> **How to use this plan:** Units `U1`–`U14` are independently executable and touch disjoint file sets so a swarm can run them in parallel. Each unit lists scope, exact files, steps, dependencies, acceptance criteria, and edge cases. Read §1–§8 for intent/architecture/contracts, then execute units per the dependency graph in §10. Sequencing/milestones in §15.

---

## 1. Goal & intent

**Goal.** A repeatable process the maintainer runs (and a scheduled agent runs weekly) that outputs:

1. A **trend scorecard** — fixed lenses (Security, Architecture, Type safety, Testing, Performance, Observability, Sprawl, DRY/SoC, Design tokens, Accessibility, Dependencies, CI/CD, Docs, Tenancy, Live-site), each graded **A–F±**, with a **Direction arrow (↑ → ↓)** vs. the prior week.
2. **Per-lens companion findings** — each finding cites `path:line`, with *Current state → Why it matters → Fix contract → Migration sequence → Blast radius*.
3. A **longitudinal registry** so trends are computed, never recalled.
4. A **self-contained HTML report** for at-a-glance scanning.
5. A **roadmap** sequencing the work that raises the lowest grades.

**Why it exists.** Code review (per-PR) catches diffs; nothing was tracking *whole-codebase engineering practices over time*. The maintainer wants a defensible, longitudinal signal — "are we getting better or worse, and where" — that drives a roadmap.

**Design north star (non-negotiables).**
- **Grade against the repo's own declared standards first** (`AGENTS.md`, `docs/adr/**`, `VISION.md`). Measured violations of a stated rule are the strongest, least-arguable grades.
- **Measured spine + adversarial verification.** Counts ground grades; an independent verifier kills plausible-but-wrong findings.
- **Honesty over momentum.** A worsened number points the arrow down even if the narrative is positive. Distinguish *measured* from *judged*. Provisional runs are labelled provisional.
- **Read-only on product code.** The review writes only review artifacts. Acting on findings is a separate, downstream workstream (§14b).

**Anti-goals.** Not a per-PR linter (that's `code-review`). Not a one-off audit (longitudinal is the point). Not a vanity dashboard (grades must be defensible by the cited findings).

---

## 2. Current status — completed vs. remaining

### 2a. COMPLETED this session (scaffold + corrected quick baseline)

**Portable skill** (`~/Code/github/ryangriffinau/skills/skills/engineering/engineering-review/`):
- `SKILL.md` — modes (`init`/`baseline`/`quick`/`full`/`report`), core rules, workflow, references.
- `references/lens-catalog.md` — 15 lenses, each with inspect/signals/grade-anchors + tailoring guidance.
- `references/grading-and-trends.md` — A–F± rubric, overall-grade derivation rules, registry schema, trend mechanic, honesty rules.
- `references/report-format.md` — SUMMARY/companion structure, HTML, redaction policy, the `full`-mode multi-agent methodology (incl. a Workflow pipeline sketch).
- `scripts/collect-metrics.sh` — portable quantitative collector emitting JSON. **Hardened during fresh-eyes:** robust LOC/over-cap pass (xargs-batch-safe), `as` excludes namespace imports, non-null `!` conservative pattern, multiline empty-catch. Syntax-clean, reproducible.
- Added to the canonical repo `README.md` skills table (status `drafting` 0.1.0).

**Repo config + home** (`platform-monorepo`):
- `.agents/engineering-review/profile.json` — 15 lenses with weights + per-lens repo notes, `redaction: "split"`, tracker config, size cap 500.
- `docs/reviews/README.md` — the review home (how it runs, lenses, grades, redaction, runs table).
- `docs/reviews/REGISTRY.md` + `docs/reviews/scorecard.json` — the longitudinal registry (machine + human), seeded with the W26 row.
- `docs/reviews/schedule.md` — the weekly-cron definition (NOT yet created as a live routine).
- `docs/reviews/_scratch/{.gitkeep,README.md}` — gitignored scratch home for unredacted detail.
- `docs/reviews/2026-W26/SUMMARY.md` + `report-2026-W26.html` — the **quick baseline** (provisional; corrected after fresh-eyes).
- `.gitignore` — ignores `docs/reviews/_scratch/**` except its README/.gitkeep.
- `docs/README.md` — index entry for the review home.
- Memory: `engineering-review-process.md` recorded.

**W26 baseline result (provisional, corrected).** Overall **B−**. Theme: *engineering culture grades A; guardrails grade C.* Strong docs/ADR discipline; healthy Convex indexing (`withIndex` 257 vs `.collect()` 23); the named "handle-both-formats" antipattern at **0**. Held by **unenforced stated rules** — ~380 type escape hatches (107 `any` / ~167 `as` / ~99 non-null `!` vs a zero-tolerance rule), 389 arbitrary-hex utilities clustered in `apps/outreach/components/demo-site-preview-*`, 80 files over the 500-LOC cap — plus an **untriaged dependency-advisory backlog** (`pnpm audit`: 13 critical / 138 high, likely dev/transitive-inflated) and **no detected frontend error tracking**. Tenancy / accessibility / live-site **deferred** to the first `full` run.

> **Important caveat for executors:** the W26 grades are single-pass and **not adversarially verified**. Treat them as a starting hypothesis the first `full` run must confirm or correct.

### 2b. NOT yet done (the rest of this plan)

- The skill is **not committed / pushed / installed** — `/engineering-review` does not yet resolve, and the cloud cron cannot invoke it.
- No **HTML generator** or **registry-append** automation — both W26 artifacts were hand-authored; this does not scale.
- No **profile JSON schema** / validation.
- The **`full` multi-agent run** (fan-out → adversarial verify → re-status → synthesize) is documented but **not implemented** as a runnable Workflow + schemas + prompt templates.
- The **three deferred lenses** (tenancy, accessibility, live-site) have no analysis tooling wired (squirrelscan/`audit-website`, axe/Playwright, Convex tenancy scan, `convex-performance-audit`).
- No **redaction-enforcement** check or **private-issue filing** integration.
- No **scheduled cloud routine** created.
- No **eval fixtures / tests** for the scripts.
- The first authoritative **`full` run (W27)** — the system's real acceptance test — has not happened.

---

## 3. Architecture & key design decisions

### 3.1 Component map

```
┌─────────────────────────── PORTABLE (canonical skills repo) ───────────────────────────┐
│ engineering-review skill                                                                  │
│   SKILL.md  (entrypoint, modes, workflow)                                                 │
│   references/  lens-catalog · grading-and-trends · report-format · prompts/ (U7)          │
│   scripts/  collect-metrics.sh · render-report.mjs (U3) · registry-append.mjs (U4)        │
│             · full-review.workflow.template.js (U6) · profile.schema.json (U2)            │
│   evals/  fixtures + cases (U12)                                                          │
└──────────────────────────────────────────────────────────────────────────────────────────┘
                                   │ installed via `npx skills add` → ~/.agents/skills (symlinked to ~/.claude/skills)
                                   ▼
┌─────────────────────────── PER-REPO (platform-monorepo) ───────────────────────────────┐
│ .agents/engineering-review/profile.json   (lenses, weights, redaction, tracker, paths)   │
│ docs/reviews/                                                                             │
│   README.md · REGISTRY.md · scorecard.json   ← tracked registry (trend source of truth)   │
│   schedule.md                                ← cron definition                            │
│   <YYYY>-W<NN>/ SUMMARY.md · NN-<lens>.md · report-<...>.html   ← per-run tracked output   │
│   _scratch/ <YYYY>-W<NN>/ …                  ← gitignored unredacted detail               │
└──────────────────────────────────────────────────────────────────────────────────────────┘
                                   │ scheduled cloud agent (U11) invokes the skill weekly
                                   ▼
        PR `docs(reviews): engineering review <week>` + scorecard posted to channel
        + security/tenancy detail filed to private issues (U10)
```

### 3.2 Key decisions (with rationale and rejected alternatives)

- **D0 — Two layers: a Deterministic Core that is load-bearing on its own, and an optional LLM Review Layer.** *(Framing decision — added after a pre-mortem/reality-check pass; it reorders priorities below.)*
  - **Deterministic Core** = `collect-metrics.sh` (reproducible counts) + the **Ratchet Engine** (U15, blocking-for-net-new CI gates) + **diff attribution** (U16's count deltas) + the registry's measured metrics & ratchet floors. Properties: **100% reproducible, cheap, zero LLM, zero weekly human attention, CI-load-bearing.** It delivers standalone value — "engineering practices can only ratchet toward the stated standard" — even if nothing else ships.
  - **LLM Review Layer** = graded lenses (U6/U7), adversarial verification (U8), the narrative SUMMARY + companions, the deferred judgment lenses (U9). Properties: **richer and more insightful, but costly, noisy, and attention-hungry.** It is an *enhancement* layered on the Core, never a dependency of it.
  *Why:* the three most probable failure modes (weekly-`full` cost attrition, trust collapse from noisy LLM grades, and never-shipped) all stem from making the expensive/noisy LLM layer the load-bearing thing. Anchoring value on the Core means a lapse in the LLM layer degrades richness, not value; the trend that matters most (ratchet floors, measured counts) is the one that's reproducible. *Rejected:* one monolithic "full review" as the unit of value (couples all value to the most fragile, most expensive component — the modal way this class of system dies). **Consequence:** the Core is the MVP (see M0 in §15); the LLM layer's grades must pass a reproducibility gate (§7) before their *trends* are trusted.

- **D1 — Portable skill + per-repo profile** (not a repo-local script, not a standalone CLI).
  *Why:* reuse across repos (the maintainer reviews multiple projects and keeps a canonical skills repo that other repos install from); repo specifics live in a profile so the engine stays generic. *Rejected:* hard-coding into the monorepo (not reusable, violates the canonical-skills convention); a bespoke CLI binary (heavier to build/distribute; the skill + Workflow tool already provide orchestration and are how the maintainer's other tooling works).

- **D2 — Grade against the repo's own declared standards first.**
  *Why:* a rule the repo states about itself (no `any`/`as`, 500-LOC cap, design-token policy, Zod-boundary, handle-both ban) is an objective anchor; measured violations are indisputable and avoid generic-best-practice bikeshedding. *Rejected:* a fixed external rubric only (less defensible, poorer repo-fit) — though the lens catalog still supplies stack-agnostic anchors for repos with thin self-declared rules.

- **D3 — Measured spine + adversarial verification.**
  *Why:* counts (LOC, escape hatches, index ratios, advisory totals) ground grades in reproducible numbers; an independent verifier re-checking each finding against its `path:line` kills plausible-but-wrong findings — the single biggest quality lever (and the failure mode of one-shot LLM "audits"). *Rejected:* single-shot LLM opinion (unreliable, no falsification); pure-metrics scorecard (misses architecture/judgment lenses that aren't countable).

- **D4 — Longitudinal registry is the single source of truth for trends.**
  *Why:* arrows must be computed by diffing the prior recorded grades, never recalled from memory; a machine file (`scorecard.json`) drives computation, a human file (`REGISTRY.md`) drives reading. *Rejected:* re-deriving a baseline each run (drift, no real trend); storing trends inside each week's SUMMARY only (no queryable history).

- **D5 — Redaction split** (tracked-redacted + gitignored scratch + private issues).
  *Why:* the repo handles multi-business customer data; committing vuln class + `file:line` + repro to git history is itself a risk. The scorecard's *trend signal* is shareable; the *exploit detail* is not. *Rejected:* single fully-tracked report (leaks detail into history); fully-private review (loses the shareable longitudinal signal and the in-repo roadmap).

- **D6 — `quick` vs `full` modes.**
  *Why:* weekly cost control without abandoning rigor — `full` is the authoritative, verifier-backed floor; `quick` is an explicitly-provisional cheap pass for an off-week or a fast pulse. *Rejected:* only-`full` (too costly to run truly weekly at scale); only-`quick` (never authoritative, grades unverified). The honesty rule (label provisional) prevents `quick` from masquerading as `full`.

- **D7 — `full` mode uses the Workflow orchestration tool (parallel fan-out).**
  *Why:* one agent per lens in parallel + one adversarial verifier per finding, with deterministic control flow (pipeline/parallel, schema-validated structured output, retries). *Rejected:* one mega-agent (context limits, no parallelism, can't isolate verification); ad-hoc sequential `Agent` calls (slower, no structured pipeline, easy to lose findings).

- **D8 — Weekly cadence via a scheduled cloud agent.**
  *Why:* the artifact is inherently weekly/longitudinal and should run unattended; a cloud routine produces a PR + posts the scorecard. *Rejected:* a CI gate on every PR (wrong granularity — that's code-review's job, and a whole-repo review per PR is wasteful); manual-only (won't happen reliably). Manual invocation remains available for ad-hoc runs.

- **D9 — Reuse existing skills as lens adapters, don't reinvent.**
  *Why:* `audit-website` (squirrelscan) for live-site, `convex-performance-audit` for Convex perf, `security-review`/`code-review ultra` for deep dives, `review-council` for the architectural verdict. *Rejected:* building bespoke scanners for domains already covered by installed skills.

### 3.3 Assumptions (state explicitly; verify before relying)

- **A1.** `ripgrep` (`rg`) is available wherever `collect-metrics.sh` runs; `jq` is available for audit parsing (script degrades to 0s without it). *Verify in the cloud-agent env (U11).*
- **A2.** The canonical skills repo is private-or-public but reachable by `npx skills add ryangriffinau/skills`; the skill must be **pushed** before install (U1). *Currently uncommitted.*
- **A3.** The cloud-agent environment can run the skill, has `gh` auth for PRs, and tracker credentials for private issues. *Verify (U11/U10).*
- **A4.** `pnpm audit` totals over-count (dev/transitive/unreachable); the Dependencies lens must **triage**, not quote raw totals as production exposure.
- **A5.** Several large files under `packages/sanity-cms/.../generate-website/customers/*` are data-heavy generated-style content; the Sprawl lens must separate generated data from hand-authored god-files.
- **A6.** Convex is the primary backend (`packages/backend-website` shared, `packages/backend`); `apps/platform` is mid Prisma/Supabase→Convex migration (dual-stack expected, grade *coherence* not just end-state).
- **A7.** The maintainer's branch/PR policy: target/merge against `main` (not `staging`) for this repo.

---

## 4. Data model & contracts

All inter-component contracts are JSON or a fixed markdown structure. Schemas are the integration boundary — agents and scripts depend only on these, never on each other's internals.

### 4.1 `profile.json` (per repo) — owned by U2 schema

```jsonc
{
  "repo": "string",                       // repo name
  "reviewHome": "docs/reviews",           // tracked output root
  "scratchDir": "docs/reviews/_scratch",  // gitignored unredacted root
  "redaction": "split" | "none",
  "sizeCap": 500,                          // LOC cap to grade Sprawl against
  "standardsDocs": ["AGENTS.md", "..."],  // read these to derive stated rules
  "excludeGlobs": ["**/_generated/**", "..."], // metric-collection excludes (stack-tuned)
  "tracker": {
    "primary": "string",                  // e.g. backpocket-orchestrator
    "privateSecurity": "string",          // e.g. github-issue:label=security
    "note": "string"
  },
  "lenses": [
    { "key": "string", "enabled": true, "weight": 1.0, "redacted": false, "note": "string" }
  ]
}
```

### 4.2 Metrics JSON — owned by `collect-metrics.sh` (U5)

Stable keys (consumers read by key): `src_files, total_loc, size_cap, files_over_cap, any_count, as_count, ts_ignore, lint_disable, non_null, arbitrary_hex, handle_both, todo_fixme, console_calls, empty_catch, test_files, convex_fns, withindex, collect, audit_critical, audit_high, audit_moderate, audit_low, open_prs, ci_workflows`. All numeric; `open_prs` may be JSON `null`. New keys are additive only (never rename/remove — the registry stores historical metrics by key).

### 4.3 Lens-agent output — `FINDINGS` schema (U7)

```jsonc
{
  "lens": "string",
  "proposedGrade": "A|A-|B+|B|B-|C+|C|C-|D+|D|D-|F",
  "gradeRationale": "string",
  "findings": [
    {
      "id": "string",          // e.g. TYPE-1 (stable within a run)
      "severity": "P0|P1|P2|P3|Nit",
      "title": "string",
      "file": "string",        // path relative to repo root
      "line": 0,               // integer; 0 if file-level
      "evidence": "string",    // short code excerpt or measured count
      "why": "string",
      "fix": "string",         // the contract
      "migration": ["string"], // ordered steps
      "blastRadius": "string",
      "redacted": false        // true → route to scratch + private issue, not tracked SUMMARY
    }
  ]
}
```

### 4.4 Verifier output — `VERDICT` schema (U8)

```jsonc
{ "findingId": "string", "real": true, "severityAdjust": "none|up|down", "note": "string", "confidence": "low|med|high" }
```

### 4.5 Registry — `scorecard.json` (U4 appends)

```jsonc
{
  "repo": "string",
  "lenses": ["security","tenancy","architecture","type-safety","testing","performance",
             "observability","sprawl","dry-soc","design-tokens","accessibility",
             "dependencies","ci-cd","docs","live-site"],   // STABLE order; change = note in SUMMARY
  "runs": [
    {
      "id": "2026-W27", "date": "YYYY-MM-DD", "mode": "full|quick-baseline|quick",
      "verified": true,
      "commit": "string",                        // head SHA at run time — diff-aware range source (U16)
      "deep_lens": "string",                     // which lens got the whole-repo deep pass this week (U16)
      "overall": "B", "overall_cap_reason": "string",
      "grades": { "<lens>": "A-|...|null" },     // null = not assessed
      "not_assessed": ["string"],
      "metrics": { /* §4.2 keys, plus ratchet floors: "<rule>_floor" e.g. "arbitrary_hex_floor": 389 (U15) */ },
      "p0_count": 0,
      "notes": "string"
    }
  ]
}
```

### 4.6 Run directory contract (tracked)

`<reviewHome>/<id>/`:
- `SUMMARY.md` — sections in fixed order: Header · Architectural verdict · Headline scorecard (table with Direction col) · What was closed since `<prev>` · Roadmap · ADR-worthy decisions · Bottom line.
- `NN-<lens>.md` — one per graded lens with findings; finding sections per §4.3 prose shape.
- `report-<id>.html` — self-contained (U3 generates).

### 4.7 Trend function contract (pure, U3/U4 share)

`arrow(prevGrade, curGrade) → "↑" | "→" | "↓" | "(new)"`. Grade→ordinal: map `F=0 … A=12` with `±` as ±0.33 offsets; `↑` if `cur>prev`, `↓` if `<`, `→` if equal, `(new)` if `prev` is null/absent. Lens retired ⇒ omit row, note in SUMMARY.

---

## 5. End-to-end workflows

### 5.1 `init` (once per repo) — U13
Read `standardsDocs`; create/validate `profile.json`; create `docs/reviews/{README,REGISTRY,scorecard.json,schedule}.md|json` and `_scratch/`; add `.gitignore` rule; add the docs-index entry. *(Done for platform-monorepo; the unit is to generalize it into the skill's `init` mode.)*

### 5.2 `quick` (single-pass, provisional)
Run `collect-metrics.sh` → map; read prior registry row; for each lens, the runner reviews from metrics + targeted reads and records 1–3 findings + a provisional grade; compute trends; `registry-append` (U4); `render-report` (U3); write SUMMARY (labelled provisional). No fan-out, no verifier.

### 5.3 `full` (authoritative) — the core, U6/U7/U8
1. **Map.** `collect-metrics.sh`; load prior registry row + prior findings.
2. **Fan out lenses** (Workflow `pipeline`/`parallel`): one agent per enabled lens, fed metrics + stated rules + lens prompt (U7) → `FINDINGS`.
3. **Adversarially verify** (per finding, in parallel): verifier re-checks against `file:line` → `VERDICT`; drop `real:false`; apply `severityAdjust`. Security/tenancy findings get **perspective-diverse** verifiers (correctness/reachability/repro), majority vote.
4. **Re-status prior findings.** One pass marking each Addressed/Partial/Open/Worsened with current evidence.
5. **Synthesize.** Verifier-adjusted grades; trends from registry; write SUMMARY + companions; `render-report`; `registry-append`; apply redaction (U10): redacted findings → scratch + private issues, tracked rows trend-level only.
6. **Gate.** Run the redaction-leak check (U10) before declaring done.

### 5.4 `report` (re-render) — U3
Read an existing run's data + the registry → regenerate `report-<id>.html`. No analysis.

### 5.5 `scheduled` (weekly) — U11
Cloud routine (Mon 08:00) → `full` → open PR `docs(reviews): engineering review <id>` → post scorecard + Overall trend to channel → file private issues. On failure: notify loudly, do **not** write a partial green-looking run.

---

## 6. Lens catalog (tailored to platform-monorepo)

Graded each run (profile owns weights/notes). Stack-agnostic definitions + signals + grade anchors live in the skill's `references/lens-catalog.md`; repo-specific notes in `profile.json`. Summary of repo tailoring:

| Lens | Repo-specific signal focus |
|---|---|
| Security | Convex/better-auth surface, secrets, input validation at boundaries; dep exposure via Dependencies |
| Tenancy | account/business scoping **code-enforced vs operational**; watch `multi-business-customer-accounts` spec |
| Architecture | package boundaries; Prisma/Supabase→Convex migration *coherence*; service-layer adoption |
| Type safety | `any`/`as`/non-null `!` vs AGENTS.md zero-tolerance; Zod-boundary integrity |
| Testing | vitest + convex-test + Playwright staging e2e; **coverage-gate PLACEMENT (PR vs post-merge)**; skip-on-empty suites |
| Performance | `.withIndex` vs `.collect()`, pagination, N+1 (use `convex-performance-audit`) |
| Observability | FE error tracking (none found), path-scoped `console.*`, request-id continuity |
| Sprawl | files >500 LOC; **separate generated sanity-cms data from hand-authored god-files**; CI enforcement |
| DRY/SoC | "handle-both-formats" ban (0 today), duplication, logic-in-handlers |
| Design tokens | arbitrary-hex utilities (389, clustered in customer-facing `demo-site-preview-*`) |
| Accessibility | WCAG AA contrast, focus-trap, axe tests on platform + customer sites |
| Dependencies | `pnpm audit` triaged runtime-vs-dev; `minimumReleaseAge` maturity policy (strength) |
| CI/CD | 5 workflows, `verify:ci`/`verify:prepush`, `vercel-cicd-cost-control`; open-PR backlog (28) |
| Docs | owner-doc/ADR lifecycle/PROGRESS.md hygiene (strong) |
| Live-site | squirrelscan on `apps/www` + a managed customer site |

---

## 7. Grading & trend mechanics

A–F± per lens, anchored to the lens's evidence and the repo's stated standard (§3.2 D2). Overall = weighted central tendency with two binding rules: **(i) any D/F or unresolved P0 caps the Overall** (state the cap); **(ii) adding a lens that surfaces a real gap may drop the Overall even when everything else improved** (say so). Trends via §4.7. Full rubric in `references/grading-and-trends.md`. *Honesty rules are normative, not advisory.*

### 7.1 Grade reproducibility (gating, per D0)

LLM letter-grades are only allowed to drive **trend arrows** once they are proven stable on identical input — otherwise the trend is noise (pre-mortem #2). Rules:

- **Anchor grades to the deterministic spine.** Each lens grade is a function of *measured* inputs — metric counts, ratchet floors, and the *count* of verified findings by severity — with LLM judgment confined to a **bounded ±1 band** adjustment and to *finding discovery*, **not** free-form scoring. A grade move must trace to a changed measured input or a newly verified/closed finding, never to "the model felt different this week."
- **Same-commit reproducibility check.** Running a `full` review twice on the **same commit** must produce **identical grades and arrows** (the measured spine is deterministic; the bounded LLM band must not flip a letter). This is a gating acceptance test (U12 fixture-level, U14 real-run-level). If a grade flips on identical input, the rubric is too LLM-weighted — tighten the anchor.
- **Until reproducibility passes, the measured metrics + ratchet floors are the authoritative trend; letter-grades are advisory** and labelled as such in the SUMMARY. This is the D0 fallback: the Core's trend is always trustworthy even when the Layer's grades aren't yet.

---

## 8. Redaction model

`redaction: "split"`: tracked files carry the trend scorecard + engineering narrative; security/tenancy/data-access detail (vuln class, `file:line`, repro) goes to `_scratch/<id>/` (gitignored) and to private issues (`tracker.privateSecurity`), referenced from the tracked SUMMARY as "(detail in private issues)". The **registry is always tracked** (trend history is durable; the scratch dir is never where history lives). U10 adds an automated leak check.

---

## 9. Work decomposition (units U1–U14)

Each unit is independently executable; **Files** lists the disjoint set it owns. Do not edit another unit's files. `(P)` = parallelizable immediately; deps noted.

### U1 — Publish & install the skill `(P)`
**Files (canonical repo only):** the `engineering-review/` skill dir (already written) + `skills-lock.json` (CLI-managed) on the consuming side.
**Steps:** (1) commit the skill to `ryangriffinau/skills` on a branch, PR, merge. (2) `npx skills add ryangriffinau/skills --skill engineering-review`; confirm it lands in `~/.agents/skills/engineering-review` and is symlinked to `~/.claude/skills`. (3) Verify `/engineering-review` resolves in Claude Code and Codex (description triggers, modes documented).
**Deps:** none. **Blocks:** U11 (cron needs installed skill), U14 (uses installed skill; can also run from local path).
**Acceptance:** `/engineering-review` is invocable; `collect-metrics.sh` runs from the installed path; `skills check` shows it pinned.
**Edges:** repo private → ensure the install method has access; if not published yet, document a local-path fallback for U14.

### U2 — Profile schema + validator `(P)`
**Files:** `references/profile.schema.json` (new), `scripts/validate-profile.mjs` (new), one line in `SKILL.md` pointing to it.
**Steps:** author a JSON Schema for §4.1; a tiny Node validator (no deps or ajv) that the `init`/`full` modes call; emit actionable errors (unknown lens key, weight not numeric, redaction enum).
**Deps:** none. **Acceptance:** validator passes the platform-monorepo profile; fails a deliberately-broken fixture with a clear message.
**Edges:** unknown lens keys vs the stable lens list — warn, don't hard-fail (forward-compat).

### U3 — HTML report generator `(P)`
**Files:** `scripts/render-report.mjs` (new), `references/report.css` (extract the inline CSS), `references/report.template.html` (optional).
**Steps:** pure function `render(registry, runId) → htmlString`. Inputs: `scorecard.json` + the run's grades/notes (from a small `run.json` the synthesizer writes, or parsed from SUMMARY front-data). Output: the self-contained HTML (header health-grade, scorecard table with colored pills + **Direction arrows from §4.7**, key-metric cards, **metric sparklines across runs** once ≥2 runs exist). Light/dark via `prefers-color-scheme`.
**Deps:** §4.7 trend fn (share with U4). **Acceptance:** regenerates a W26-equivalent HTML byte-stable from inputs; tag-balanced; renders in a browser; arrows correct on a 2-run fixture.
**Edges:** 1 run → no arrows/sparklines (don't crash); `null` grades render as "—" grey pill.

### U4 — Registry-append automation `(P)`
**Files:** `scripts/registry-append.mjs` (new).
**Steps:** `append(scorecardPath, registryMdPath, runObject)` — idempotent (keyed by `run.id`; re-run replaces same id, never duplicates), validates against §4.5, recomputes the REGISTRY.md tables (overall, per-lens, key-metrics) and the README "Runs" table. Atomic write (temp + rename).
**Deps:** §4.7 (for any rendered deltas). **Acceptance:** appending W27 to the W26 registry yields valid JSON, correct 2-row tables, no dup; re-running is a no-op diff.
**Edges:** lens-set change between runs → write the new `lenses` array + emit a warning to include in SUMMARY; never silently misalign columns.

### U5 — Harden `collect-metrics.sh` + structured contract `(P)`
**Files:** `scripts/collect-metrics.sh` (exists), `references/metrics-schema.json` (new).
**Steps:** (1) switch file enumeration to `rg --files0 | xargs -0` to survive spaces/newlines in paths. (2) make `excludeGlobs` profile-driven (read from an env var or arg) instead of hard-coded. (3) add a `--budget-seconds` guard for very large repos (skip the most expensive counts, flag `partial:true`). (4) emit `tool_availability` (`rg/jq/gh/pnpm` present?) so consumers know which zeros are "absent" vs "real 0". (5) document each heuristic's known imprecision inline. (6) write `references/metrics-schema.json` matching §4.2.
**Deps:** none. **Acceptance:** runs on (a) this repo, (b) a no-TS repo (all zeros, no crash), (c) a path-with-spaces fixture; output validates against the schema; `set -u` clean.
**Edges:** `pnpm audit` offline → `audit_*` = 0 + `tool_availability.pnpm_audit:false`; consumers must not read 0 as "clean".

### U6 — `full`-mode Workflow orchestration `(P after U7/U8 schemas exist)`
**Files:** `references/full-review.workflow.template.js` (new) + a `## full mode` expansion in `SKILL.md`.
**Steps:** author the canonical Workflow script template implementing §5.3: `pipeline(LENSES, reviewStage, verifyStage)` with `phase('Review')`/`phase('Verify')`, `FINDINGS`/`VERDICT` schemas (U7), drop/adjust logic, then a re-status `parallel` over prior findings, then synthesis calls to U3/U4. **Default fleet (§16.4):** one agent per enabled lens (≤15) + verifier-per-finding — single verifier for non-sensitive lenses, **3-verifier majority** for security/tenancy — capped at ≤60 verifier agents/run; if a run token target is set, scale verifier depth within it (`budget.total ? scaled : default`), else use the fixed default. Higher `effort` on security/tenancy lens + verifier agents. The template is **adapted, not run standalone** (Workflow tool executes it).
**Deps:** U7 (prompts/schemas), U8 (verifier). **Acceptance:** a dry-run on 2–3 lenses produces verified findings + a grade per lens + an appended registry row; unverified findings are dropped; wall-clock ≈ slowest lens-chain (pipeline, not barrier).
**Edges:** agent returns malformed JSON → schema retry; agent dies → `.filter(Boolean)`; 0 findings for a lens → still emit a grade + "no findings" companion note.

### U7 — Lens prompt templates + schemas `(P)`
**Files:** `references/prompts/<lens>.md` (15 files, disjoint), `references/schemas.md` (FINDINGS/VERDICT).
**Steps:** one prompt per lens: inputs (metrics map, the lens's stated-rule excerpt, target globs), instructions (cite `path:line`, propose a fix contract, mark `redacted` for security/tenancy), output = `FINDINGS`. Encode the lens-catalog anchors so grades are consistent.
**Deps:** none (schemas referenced by U6/U8). **Acceptance:** running one lens prompt by hand on this repo yields ≥1 well-formed, file:line-cited finding matching the schema.
**Edges:** lens not applicable (e.g. live-site on a library) → return empty findings + grade `null` + reason.

### U8 — Adversarial verifier + re-status logic `(P)`
**Files:** `references/prompts/_verifier.md`, `references/prompts/_restatus.md`.
**Steps:** verifier prompt (re-read the cited `file:line`; default to `real:false` when not reproducible; perspective-diverse variants for security/tenancy; output `VERDICT`); re-status prompt (given a prior finding + current code, classify Addressed/Partial/Open/Worsened with evidence).
**Deps:** schemas (U7). **Acceptance:** on a seeded fake finding (wrong line), verifier returns `real:false`; on a real one, `real:true` with the confirming excerpt.
**Edges:** verifier can't open file (moved/renamed) → `real:false, note:"path not found"`, surfaced as "stale finding."

### U9 — Deferred-lens tooling adapters `(P, 3 sub-units)`
**Files:** `references/adapters/{tenancy,accessibility,live-site,performance}.md` (4 disjoint), plus optional `scripts/` helpers.
**Steps:**
- **U9a Tenancy:** a Convex-scoping analysis recipe — enumerate queries/mutations, flag those touching tenant-scoped tables without an account/business predicate; classify code-enforced vs operational. Output feeds the tenancy lens (redacted).
- **U9b Accessibility:** wire `vitest-axe`/Playwright-axe run on platform + a representative customer site; capture contrast/focus/landmark failures.
- **U9c Live-site:** invoke the `audit-website` (squirrelscan) skill against deployed `apps/www` + one managed customer site; map results to the live-site lens anchors.
- **U9d Performance:** invoke `convex-performance-audit` for N+1/index/pagination depth beyond the `.collect()`/`.withIndex()` ratio.
**Deps:** U1 (skills installed). **Acceptance:** each adapter produces lens findings on this repo in the FINDINGS schema; tenancy findings are marked `redacted`.
**Edges:** live-site requires a deployed URL + network; if unavailable, grade `null` + reason (don't fabricate).

### U10 — Redaction enforcement + private-issue filing `(P)`
**Files:** `scripts/redaction-check.mjs` (new), `references/issue-filing.md` (the tracker contract).
**Steps:** (1) `redaction-check`: scan tracked run files; FAIL if a `redacted`-lens row or any committed file contains a `path:line` token within a redacted lens section, or if a security/tenancy companion exists in the tracked dir. (2) **Audience-routed filing** (per §16.2): set each finding's `audience` (default by severity/type — security/tenancy *decisions* + `P0/P1` → `human`; mechanical `P2/P3/Nit` → `agent`); `agent` findings → BackPocket orchestrator tasks (`.backpocket/orchestrator`), `human` findings → Linear issues. Idempotent by a stable finding key (no dupes on re-run). The tracked SUMMARY references the routed item ("(detail in private issues)" for redacted ones) and records the audience split.
**Deps:** schemas (U7), tracker creds (A3), Linear + orchestrator access. **Acceptance:** a deliberately-leaked file:line in a tracked security section fails the check; filing creates one orchestrator task per `agent` finding and one Linear issue per `human` finding, no dupes on re-run.
**Edges:** a tracker offline → write detail to scratch, mark items "PENDING FILE," fail the run loudly rather than dropping detail; ambiguous audience → default to `human`/Linear (safer to route to a person than to auto-queue an agent).

### U11 — Scheduled cloud routine `(needs U1)`
**Files:** finalize `docs/reviews/schedule.md`; the routine is created via the scheduling capability (no repo file beyond the definition).
**Steps:** create the weekly routine (Mon 08:00 Australia/Brisbane, mode `full` per §16.5) running the §5.5 prompt. **Preflight (§16.1):** check `rg` / `gh` auth / tracker creds / installed skill; on a missing essential, fail loudly with the exact remediation (and try the local skill path before aborting); on a missing non-essential (e.g. `pnpm audit` offline), continue and mark that signal "not run." Resolve the **Slack "3 dev" channel id** (Slack connector) and post Overall + Direction + scorecard table + PR link there. Set failure notification.
**Deps:** U1, U10. **Acceptance:** a manual trigger produces a W-PR + a scorecard posted to the dev channel; a forced missing-tool case fails with remediation and writes no partial run; a double-fire is safe (idempotent append, U4).
**Edges:** skill missing in cloud env → local-path fallback, else abort with the install command; channel unresolved → post nothing but still open the PR and surface the channel-id gap.

### U12 — Eval fixtures + script tests `(P)`
**Files:** `evals/fixtures/mini-repo/**` (tiny synthetic TS repo with known violations), `evals/cases.md`, `evals/run.sh`.
**Steps:** a fixture with *known* counts (e.g. exactly 3 `any`, 2 real `as`, 1 `import * as`, 1 file >cap, 1 non-null `!`, 1 prose `!`); assert `collect-metrics.sh` returns the exact expected numbers (regression-guards the very over-count bugs fixed in fresh-eyes); assert `render-report`/`registry-append`/`redaction-check` on golden inputs. **Ratchet determinism (U15, the operator's explicit concern):** assert `ratchet generate` on the fixture is **byte-identical across two runs** (empty diff) and matches a checked-in golden allowlist; assert `ratchet check` is green on baseline, **red** when a seeded net-new violation is added (both in a new file and as count+1 in a listed file), and green again after `tighten`.
**Deps:** U3/U4/U5/U10/U15 (tests their outputs). **Acceptance:** `evals/run.sh` green; intentionally regressing any script — or making an allowlist nondeterministic — turns it red.
**Edges:** keep the fixture tiny and rg-deterministic; pin counts + the golden allowlist in `cases.md`; run `ratchet generate` under `LC_ALL=C` so the test is locale-independent.

### U13 — Generalize `init` + docs wiring `(P)`
**Files:** `SKILL.md` (`init` mode expansion), a `references/init.md` recipe; (repo side already wired).
**Steps:** turn the one-off scaffolding into a repeatable `init` mode that, given a new repo, discovers stated rules, writes a starter profile (sensible lens defaults), and creates the review home + gitignore + docs-index entry. Add a one-line pointer in the repo's `AGENTS.md`/docs to the review home.
**Deps:** U2 (schema). **Acceptance:** running `init` on a second repo produces a valid profile + home with no manual edits.

### U14 — First authoritative `full` run (W27) — the system acceptance test `(needs U3–U10, U15)`
**Files:** `docs/reviews/2026-W27/**` + registry update (generated, not hand-authored).
**Steps:** run `full` end-to-end; **grade the three deferred lenses** (tenancy/accessibility/live-site via U9); adversarially verify; **re-status the W26 findings**; produce SUMMARY + companions + HTML via U3; append via U4; file private issues via U10; pass U10's leak check; open the PR.
**Deps:** U1, U3, U4, U5, U6, U7, U8, U9, U10, U15. **Acceptance:** W27 exists with Direction arrows vs W26, all 15 lenses graded (none `null` without a stated reason), every finding verified, redaction check green, registry shows 2 rows + ratchet floors, HTML shows trends, **and a same-commit re-run reproduces identical grades (§7.1)** — if any letter flips, the rubric is too LLM-weighted and must be re-anchored before W27's trend is trusted.
**Edges:** if `full` confirms W26 grades were wrong (e.g. type-safety should be C not C+), the arrow reflects the *correction* and the SUMMARY says "baseline was provisional; corrected on first verified run."

### U15 — Ratchet Engine (blocking-for-net-new gates generated from measured violations) `(needs U5)`
**Premise.** The baseline's central finding is that the repo's standards are good but **unenforced**. This unit makes the review *install the floor*: every measurable stated-rule violation becomes a baseline-allowlisted, **blocking-for-net-new** CI gate, and the registry tracks each floor descending toward zero. The scorecard stops being a diagnosis and becomes a forcing function — net-new regressions become mechanically impossible and trends are guaranteed monotonic-down.

**Files:** skill `scripts/ratchet.mjs` (new), `references/ratchet-manifest.md` (new), `references/ratchet-rules.json` (the rule registry); repo side `.ratchet/<rule-id>.txt` (generated allowlists, one file per rule), `.agents/engineering-review/ratchets.json` (which rules are enabled for this repo), and one CI job in `.github/workflows/` running `ratchet check`.

**Core design — deterministic, count-based baselines (the crux; there will be many rules × hundreds of entries):**
- **One rule = `{ id, detector, scopeGlobs, allowlistPath }`.** `detector` is the **same definition the metrics use** (shared with `collect-metrics.sh`, U5) so "what is a violation" never drifts between the scorecard and the gate. *Single source of truth for violation definitions.*
- **Granularity = per-file occurrence COUNT, never line numbers.** Allowlist line format: `<count>\t<repo-relative-posix-path>`. A listed file passes only if its *current* count ≤ its baselined count; an unlisted file fails on ≥1. This blocks net-new both in new files **and within already-dirty files**, while staying immune to line-number churn (any edit above a violation would shift line numbers and explode a line-based allowlist — rejected for that reason).
- **Determinism guarantees (so `generate` is trivially, byte-identically reproducible):** repo-root-relative POSIX paths; `LC_ALL=C` byte sort by path; integer counts from the shared detector; LF newlines + trailing newline; **no timestamps, no absolute paths, no machine-specific data, no nondeterministic ordering** (sort rg output before grouping). `generate` on unchanged code ⇒ **empty diff**. One file per rule ⇒ scoped, merge-friendly diffs and parallel-safe regeneration.
- **Three idempotent commands:**
  - `ratchet generate [--rule id]` — (re)build allowlists from current code. Run once to baseline; safe to re-run; prunes orphaned entries for moved/deleted files deterministically.
  - `ratchet check` — recompute actual counts; **fail** if any unlisted file has ≥1 or any listed file exceeds its baseline. The CI gate. Blocking-for-net-new only → the baseline passes **green on day one**, so it lands without a big-bang fix.
  - `ratchet tighten [--rule id]` — lower each baseline to the current actual (the pawl: floors only descend). Run after fixes; `check` then refuses any future increase.
- **Registry coupling:** each rule's total floor (Σ counts) is written to the run's `metrics` as `<rule>_floor`; the review reports floors + weekly deltas, guaranteed monotonic-down.

**Pilot (first acceptance):** the **arbitrary-hex ban** — 389 occurrences, concentrated in `apps/outreach/components/demo-site-preview-*`, maps to the AGENTS.md design-token rule. Generate `.ratchet/arbitrary-hex.txt`, wire `ratchet check` into CI (advisory → blocking-for-net-new), add `arbitrary_hex_floor` to the registry. Then add rules for `any`, assertion-`as`, non-null `!`, and file-size (`>500 LOC`, count = 1 per offending file).

**Deps:** U5 (shared detectors). **Blocks:** none (U14b consumes it). **Acceptance:** (1) `generate` is byte-deterministic across two runs/machines (diff empty); (2) baseline `check` is green day one; (3) adding a net-new hex util to a *clean* file fails `check`; (4) adding one to an *already-listed* file (count+1) fails `check`; (5) fixing one then `tighten` drops the floor and `check` stays green; (6) registry shows `arbitrary_hex_floor` descending week-over-week.
**Edges:** multiline detectors → count with the same `-U` the metric uses; renamed/deleted file → `generate` prunes its entry deterministically; a rule needing AST (not a simple grep) → detector may shell to a small script but must stay deterministic + count-emitting; **never** put line numbers in an allowlist; a rule with 0 violations → omit its allowlist file (a non-existent allowlist means "zero tolerance, no baseline").

### U16 — Diff-aware weekly run + rotating deep-lens `(needs U6, §4.5 SHA)`
**Premise.** Re-grading 266K LOC deeply every week is expensive and noisy. Make the weekly `full` focus on **what changed** (causal attribution) while keeping the whole-repo trend cheap, and rotate one lens through a deep whole-repo pass each week so all lenses get deep coverage over a cycle.
**Files:** skill `references/diff-aware.md` (new) + `scripts/diff-scope.mjs` (new); registry `run.commit` (added in §4.5).
**Steps:** (1) record each run's head `commit` SHA in the registry. (2) next run computes the range `prev.commit..HEAD` (the week's merged work). (3) produce **(a)** whole-repo metrics for the scorecard trend (cheap — `collect-metrics.sh`), **(b)** **diff-scoped** lens findings/attribution ("the week's PRs added N `any`, M hex, K over-cap") by pointing the lens agents at changed files, and **(c)** a **rotating deep-lens**: one lens per week gets the full whole-repo deep treatment on a fixed, deterministic rotation (by week index mod lens-count) so each lens is deeply re-reviewed every ~N weeks without paying all-lenses-deep weekly. The U15 ratchet `check` is the enforcement complement — the diff is exactly where net-new appears.
**Deps:** U6 (lens agents), U4 + §4.5 (registry stores SHA). **Acceptance:** run N+1 attributes new violations to the `prev..HEAD` range; the deep-lens advances deterministically by week index; the whole-repo trend + every ratchet floor still update every week.
**Edges:** first run / no prior SHA → full review; rebased/force-pushed main (prev SHA unreachable) → fall back to full + note it; oversized week diff → cap reviewed files + log what was dropped (no silent truncation).

### U14b (downstream) — Act on non-ratchetable findings
With U15 in place, **mechanical stated-rule violations are handled by the Ratchet Engine** (they self-gate and ratchet down). U14b is now the *residual*: findings that can't be a count-based gate — FE error tracking (Observability), dependency triage (judgment), coverage-gate-on-PR placement (CI config), architecture/tenancy decisions. Each becomes its own ADR + spec, routed by audience (§16.2). **Out of scope for the review system's "done"**, but the loop is now: ratchet the countable, ADR the judgmental.

---

## 10. Dependency graph & parallelization

```
Wave A (all parallel, no deps):  U1  U2  U3  U4  U5  U7  U8  U12(partial)  U13
Wave B (after schemas/scripts):  U6 (needs U7,U8)   U9 (needs U1)   U10 (needs U7)
                                 U15 (needs U5 — shares detectors)   U12 (full, needs U3/U4/U5/U10/U15)
Wave C (after engine ready):     U11 (needs U1,U10)   U16 (needs U6 + §4.5 commit SHA)
Wave D (system acceptance):      U14 (needs U3,U4,U5,U6,U7,U8,U9,U10,U15)
Downstream:                      U14b (after U14)
```

File-overlap audit: each unit owns disjoint files (scripts/*.mjs are one-per-unit; prompts are one-per-lens; the only shared *reads* are the schemas in `references/schemas.md` (author once in U7, others read-only). The trend function (§4.7) is specified here so U3 and U4 implement identical logic — extract it to `scripts/lib/trend.mjs` (owned by whichever of U3/U4 starts first; the other imports) to avoid divergence.

---

## 11. Testing & verification strategy

- **Scripts (U5/U3/U4/U10):** deterministic unit tests via the `evals/mini-repo` fixture (U12) with pinned expected numbers — this is the regression guard for the measurement bugs fixed during fresh-eyes (namespace-import over-count, non-null under-count, xargs-batch LOC truncation).
- **Schemas:** validate every agent output against FINDINGS/VERDICT at the Workflow boundary (retry on mismatch).
- **Verification quality (U8):** seed known-true and known-false findings; assert the verifier keeps the first and drops the second; track verifier precision/recall over runs.
- **Redaction (U10):** a CI/`redaction-check` step that fails the run if redacted detail leaks into tracked files.
- **End-to-end (U14):** the first `full` run is the acceptance test; success = §9 U14 acceptance criteria.
- **Honesty audit:** a synthesis-time self-check ("which grades are judged vs measured? which lenses are `null` and why? does any arrow lack a justifying finding?") before writing SUMMARY.

---

## 12. Edge cases, failure modes, security & correctness (consolidated)

- **Measurement over/under-count** (the fresh-eyes class): namespace imports, prose `!`, comments, generated files. *Mitigation:* tuned patterns + `excludeGlobs` + the fixture tests (U12); always state what a count excludes.
- **`xargs` batching truncation** of LOC. *Mitigation:* sum per-file, `--files0`/`-0` (U5). (Per-file sum already applied.)
- **Tool absence read as a clean 0** (`pnpm audit`/`gh` offline). *Mitigation:* `tool_availability` flags (U5); consumers must distinguish absent vs zero.
- **Verifier drops a real finding** (false negative). *Mitigation:* perspective-diverse verifiers + majority vote for security/tenancy; low-confidence verdicts surface for human review rather than silent drop.
- **Grade inflation / dishonesty.** *Mitigation:* normative honesty rules; arrows must trace to a finding; measured-vs-judged labelling.
- **Trend miscompute on lens-set change.** *Mitigation:* stable `lenses` array; U4 warns + SUMMARY notes any change.
- **Registry race / merge conflict** (manual run + cron same week). *Mitigation:* idempotent append keyed by run id (U4); serialize.
- **Redaction leak into git history.** *Mitigation:* U10 leak check gates the run; scratch dir gitignored; registry is the only tracked durable record.
- **Cron in a stale/headless env** (skill or creds missing). *Mitigation:* prerequisite check + loud failure (U11), never a partial green run.
- **Customer-data exposure** in scan output (secrets, PII in screenshots). *Mitigation:* keep raw tool dumps in scratch; never paste secrets into tracked files; redaction lenses default `redacted:true`.
- **Cost blowout** of `full`. *Mitigation:* budget scaling in U6; `quick` for off-weeks; cap lens/verifier fan-out.

---

## 13. Risks & mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| **Weekly `full` attrites → the system silently stops** (pre-mortem #1) | **High** | High | **D0 Deterministic Core delivers value without weekly runs**; default weekly = diff-aware + rotating deep-lens, reserve all-lenses-deep `full` for monthly (§15 M0/note); **missing-registry-row alert** by Tuesday; per-run cost/time logged with a kill threshold |
| **LLM grades noisy/unreproducible → trend is meaningless, trust collapses** (pre-mortem #2) | **High** | High | **§7.1 reproducibility gate** (same-commit re-run must be identical; grades anchored to measured spine, LLM bounded ±1); until it passes, **measured metrics + ratchet floors are the authoritative trend**, letter-grades advisory |
| Skill never published / engine never built → stays a prototype (pre-mortem #3) | Med-High | High | **Ship the Core first (M0)** — small, standalone, valuable without the LLM engine; U1 publish first; local-path fallback |
| Ratchet friction → devs `--no-verify` / delete the gate (pre-mortem #4) | Med | High | Sanctioned escape valve (U15: `tighten`/reviewed allowlist bump, never `--no-verify`); detector false-positive budget + scoped globs; green-on-baseline so it never blocks existing code |
| Built but nobody acts on judgmental findings (pre-mortem #5; 28-PR backlog) | Med | Med | Ratchets self-close the countable; audience-routed filing (U10) puts the rest where it'll be seen; the Core delivers value regardless of follow-through |
| Verifier precision too low to trust | Low | High | U8 seeded tests + confidence surfacing + diverse verifiers |
| Lens creep makes trends incomparable | Med | Med | Stable lens set; changes are explicit + noted |
| Redaction discipline slips over time | Low | High | Automated leak check in every run (U10) |

---

## 14. Definition of done (whole system)

1. `/engineering-review` resolves in CC + Codex; `collect-metrics.sh` runs from the installed path (U1).
2. `quick`, `full`, and `report` modes all runnable; `full` does fan-out + adversarial verify + re-status + synthesis (U6–U8).
3. Profile validated by schema (U2); metrics emit a documented, schema-checked contract with tool-availability (U5).
4. HTML + registry generated by scripts, not by hand; trends correct (U3/U4); fixture tests green (U12).
5. All 15 lenses graded in a real run (deferred lenses have tooling — U9); every finding adversarially verified.
6. Redaction split enforced by an automated check; security/tenancy detail filed to private issues (U10).
7. A weekly cloud routine runs `full`, opens the PR, posts the scorecard, files issues, and fails loudly on error (U11).
8. **Ratchet Engine live (U15):** ≥1 rule (hex pilot) gating CI blocking-for-net-new, allowlists byte-deterministic via one `generate` command, floors tracked in the registry and descending.
9. **Diff-aware weekly run (U16):** runs attribute new violations to the week's commit range; a rotating deep-lens advances each week; whole-repo trend still updates.
10. **W27** exists as the first authoritative run with verified grades + Direction arrows vs W26 (U14).

---

## 15. Sequencing & milestones

> **Cadence reconsideration (open for the operator).** The pre-mortem rates *weekly `full`* the #1 cause of death. Recommended revision: **weekly = Deterministic Core + diff-aware + one rotating deep-lens; all-lenses-deep `full` monthly.** This keeps a trustworthy weekly trend + enforcement at a fraction of the recurring cost. The "full weekly" decision (§16.5) is left as-is pending your call — but M0 below makes the weekly value *not depend on* the `full` run either way.

- **M0 — Deterministic Core MVP (the load-bearing minimum, per D0).** Ship value with **zero LLM and zero weekly attention**: U1 (publish/install) + U5 (hardened metrics) + U12 (fixture tests) + **U15 hex ratchet wired into CI, blocking-for-net-new, green on baseline** + a metrics-only weekly registry row (counts + ratchet floors). *Gate:* `ratchet check` gates the hex rule in CI; `ratchet generate` is byte-deterministic; the registry gains a weekly row of measured metrics **without any LLM run**. **At M0 the project already delivers its most trustworthy outcome — practices can only ratchet toward the standard — even if M1+ never lands.**
- **M1 — Engine real (Wave A + B):** U2 contracts; U3/U4 generators; U7/U8 prompts; U6 workflow; remaining ratchet rules (`any`/`as`/non-null/file-size); §7.1 reproducibility check in the fixtures. *Gate:* a `full` dry-run on 2–3 lenses produces verified findings + generated HTML/registry; same-commit re-run yields identical grades.
- **M2 — Full coverage (Wave B/C):** U9 deferred-lens adapters; U10 redaction+filing; **U16 diff-aware + rotating deep-lens**; U11 cron. *Gate:* redaction check green; diff-run attributes new violations to the week; cron manual-trigger produces a PR.
- **M3 — First authoritative run (Wave D):** U14 = W27 full run, all lenses, verified, trended, with ratchet floors recorded. *Gate:* §14 done.
- **M4 — Value loop (downstream):** ratchets cover `any`/`as`/non-null/file-size + U14b turns non-ratchetable findings into ADRs. *Gate:* every ratchet floor trends ↓ and lowest grades trend ↑ in subsequent weeks.

> **Recommended first action (single-maintainer path):** **ship M0 first** — U1 (publish/install) → U5 hardening + U12 fixtures (lock the measurement spine, and with it the ratchet detectors) → U15 hex pilot wired into CI (prove the deterministic ratchet end-to-end on the highest-count rule + record the floor in a metrics-only weekly row). That is a complete, trustworthy, self-sustaining increment **before any LLM engine exists.** Only then build M1 (U3/U4 generators → U7/U8/U6 the `full` engine) and proceed to M2/M3.

---

## 16. Resolved decisions (operator answers)

1. **Cron environment — assume available, degrade gracefully.** Treat `rg` / `gh` auth / tracker creds / installed skill as present in the cloud-agent env, but **U11 must preflight and handle absence**: a missing tool → fail loudly with the exact remediation (e.g. the `npx skills add` command); a missing skill install → fall back to the local skill path if reachable, else abort with instructions; if a non-essential tool is missing (e.g. `pnpm audit` offline) → continue and mark that signal "not run" rather than 0. Never emit a partial run that *looks* complete.
2. **Private-issue sink is audience-routed** (not a single tracker). Each finding/follow-up carries an `audience`:
   - `audience: "agent"` (mechanically executable fix — eslint ratchet, delete dead code, add a test) → **BackPocket orchestrator** task (`.backpocket/orchestrator`).
   - `audience: "human"` (judgment/policy/security decision — accept-risk, tenancy-model choice, dependency triage call) → **Linear** issue.
   Security/tenancy detail follows the same rule: the *decision* goes to Linear; any *agent-executable remediation* it spawns goes to the orchestrator. U10's filing step sets `audience` per finding (default by severity/type: `P0/P1` policy & all tenancy/security *decisions* → human/Linear; mechanical `P2/P3/Nit` → agent/orchestrator) and the synthesizer records the routing in the SUMMARY.
3. **Scorecard posts to Slack — the "3 dev" dev channel.** Resolve the exact channel id at U11 setup (via the Slack connector). Post: Overall + Direction, the scorecard table, and the PR link.
4. **`full` budget — sensible default, applied where the fan-out happens (U6).** Default fleet: **one agent per enabled lens** (≤15) + **verifier-per-finding** — a single verifier for non-sensitive lenses, a **3-verifier majority** for security/tenancy. If a token target is set for the run, scale verifier depth up within it (`budget.total ? … : default`); otherwise use the fixed default. Cap total verifier agents (e.g. ≤60/run) to bound cost. Higher reasoning `effort` on security/tenancy lens + verifier agents.
5. **Cadence — `full` every week.** `schedule.md` mode = `full`, no alternation. (Use `quick` only for an ad-hoc manual off-cycle pulse.)
6. **Skill maturity gate (carried).** Promote `engineering-review` past `drafting` only after U14 proves it on a real verified run.
