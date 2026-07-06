---
name: engineering-review
status: drafting
version: 0.1.0
tags: [engineering, audit, quality, review, multi-agent]
updated: 2026-06-25
description: Run a whole-codebase, longitudinal engineering-practices review that produces a graded trend scorecard (security, architecture, type safety, testing, performance, observability, sprawl, design tokens, a11y, deps, CI/CD, docs) plus per-lens companion findings with file:line evidence and fix contracts, diffed against the prior run for ↑→↓ trend arrows. Use when the user wants a weekly/periodic engineering review, a codebase health scorecard, an architecture-quality audit, or to track engineering practices over time across a project. NOT for reviewing a single PR or diff — use code-review for that.
---

# Engineering Review

Produce a repeatable, **longitudinal** scorecard of a codebase's engineering practices. Each run grades a fixed set of lenses, attaches file:line evidence and concrete fix contracts, re-statuses every prior-run finding, and diffs grades against the last run to show whether each area is trending ↑ → ↓.

This is **whole-codebase and over-time**, not per-diff. For reviewing one PR/branch diff, use `code-review`.

## Core rules

- **Grade against the repo's own declared standards first.** Read `AGENTS.md` / `CLAUDE.md` / `docs/adr/**` / `VISION.md` before grading. A rule the repo states about itself (file-size cap, no `any`, design-token policy, Zod boundary) is an objective, defensible grading anchor. Vague best-practice opinions are weaker evidence — prefer measured violations of stated rules.
- **Every finding cites file:line and proposes a contract.** No finding without `path:line`. Each finding follows: *Current state (with code) → Why it matters → Fix contract → Migration sequence → Blast radius*. See [report-format.md](references/report-format.md).
- **Verify before you score.** In `full` mode, every finding is re-checked by an independent adversarial agent against its cited file:line; a finding that can't be reproduced is dropped or downgraded. In `quick` mode, spot-check the headline findings yourself.
- **Trends come from the registry, never from memory.** Read the prior run's grades from the registry, diff, and emit arrows. Do not invent a baseline.
- **Redaction is a setting.** When the profile sets `redaction: split`, the tracked report carries only the trend scorecard + engineering narrative; security/tenancy/data-access finding detail (vuln class, file:line, repro) goes to the gitignored scratch dir and private issues. See [report-format.md](references/report-format.md#redaction).
- **Read-only by default.** The review writes only review artifacts (its week dir, the registry, the scratch dir). It does not edit product code, open PRs, or change CI unless the user separately asks.
- **Keep repo specifics in the profile, not in this skill.** Lens weights, paths, redaction, and tracker live in `.agents/engineering-review/profile.json`.

## Modes

- `init` — create/update `.agents/engineering-review/profile.json` and the review home (`docs/reviews/` by default). Run once per repo.
- `baseline` — first run with no prior registry entry: grade every lens, write the registry's first row, no trend arrows yet.
- `quick` — single-pass review (no fan-out, no adversarial verifier). Grounded in `collect-metrics.sh` output + targeted reads. Produces the scorecard + top findings per lens + verdict. Cheapest; upgradeable to `full` later.
- `full` — the multi-agent run: parallel lens agents → adversarial verifier per finding → prior-finding re-status → scorecard → roadmap. Opt-in (uses the Workflow tool). Use for the authoritative periodic review.
- `report` — re-render an existing run's JSON/markdown into the HTML report without re-analyzing.

## Workflow

1. **Load context.** Read the repo's `AGENTS.md`/`CLAUDE.md`, `docs/adr/**`, `VISION.md`, and the docs index. Load `.agents/engineering-review/profile.json` (run `init` if missing).
2. **Map the repo (quantitative).** Run [scripts/collect-metrics.sh](scripts/collect-metrics.sh) to get LOC, file-size violations, type-escape-hatch counts, design-token violations, test ratio, Convex index/`.collect()` ratios, dep/catalog signals. This is the measured spine every grade hangs on.
3. **Pick the lenses.** Default set + per-repo additions from the profile. See [lens-catalog.md](references/lens-catalog.md).
4. **Run the lenses.**
   - `quick`: review each lens yourself from metrics + targeted reads; record the 1–3 highest-leverage findings per lens with file:line.
   - `full`: one agent per lens (parallel), then one adversarial verifier per finding (see [methodology in report-format.md](references/report-format.md)). Drop unverified findings.
5. **Re-status prior findings.** For each finding in the last run, mark Addressed / Partial / Open / Worsened with current evidence.
6. **Grade + trend.** Assign each lens an A–F± grade using [grading-and-trends.md](references/grading-and-trends.md); diff against the prior registry row for the ↑ → ↓ arrow; derive the Overall grade.
7. **Write artifacts.** `SUMMARY.md` (scorecard + verdict + closed-since + roadmap), per-lens companions, the HTML report, and append the new row to the registry (`scorecard.json` + `REGISTRY.md`). Respect the redaction setting.
8. **Hand off.** Surface the scorecard, the deltas, and the roadmap. If `redaction: split`, route security/tenancy detail to private issues per the profile's `tracker`.

## Cadence

The skill is cadence-agnostic. For a recurring weekly run, schedule a cloud agent (cron) that invokes this skill in `full` (or `quick`) mode against the repo and posts the scorecard. Keep the schedule definition in the repo's review home, not in this portable skill.

## References

- [lens-catalog.md](references/lens-catalog.md) — the lenses, what each inspects, its measurable signals, and grade anchors.
- [grading-and-trends.md](references/grading-and-trends.md) — the A–F± rubric, overall-grade derivation, the registry schema, and the trend mechanic.
- [report-format.md](references/report-format.md) — `SUMMARY.md` + companion structure, the HTML report, the redaction policy, and the `full`-mode multi-agent methodology.
- [scripts/collect-metrics.sh](scripts/collect-metrics.sh) — portable metric collector; emits the quantitative map the review grades against.
- Local profile schema and an example live in the consuming repo at `.agents/engineering-review/profile.json`.
