# Report Format, Redaction & `full`-mode Methodology

## Run directory

Each run writes to `<review-home>/<YYYY>-W<NN>/` (default home `docs/reviews/`):

```
docs/reviews/
  README.md                 # the review home (repo-tailored)
  REGISTRY.md               # longitudinal table, newest first
  scorecard.json            # machine registry (trend source)
  2026-W26/
    SUMMARY.md              # scorecard + verdict + closed-since + roadmap
    01-<lens>.md            # per-lens companion (one per graded lens with findings)
    02-<lens>.md
    report-2026-W26.html    # self-contained HTML report
  _scratch/                 # gitignored: full unredacted findings + security detail
```

## SUMMARY.md structure

Mirror the example. Sections, in order:

1. **Header** — date, codebase (LOC + test ratio), methodology (mode + lens count + verification), scope, baseline (link to prior run), author/model.
2. **Architectural verdict** — 2–4 paragraphs. Lead with the single most important truth of the run (the "inversion this review turns on"). Name what improved and what the headline risk is.
3. **Headline scorecard** — the table: `| Area | <prev week> | <this week> | Direction | Notes (trend-level) |`. Bold this run's grade. Last row is **Overall** with the cap rationale. If `redaction: split`, security/tenancy rows carry trend-level notes only.
4. **What was closed since `<prev>`** — re-status of prior findings: counts (Addressed / Partial / Open / Worsened) + the notable closures and regressions.
5. **Roadmap** — sequenced sprints/steps to raise the lowest grades. Trend-level in the tracked copy; file-referenced detail in scratch/private issues when redacting.
6. **ADR-worthy decisions** — decisions the findings imply (policy choices, enforcement escalations).
7. **Bottom line** — one honest paragraph.

## Companion doc structure (`NN-<lens>.md`)

One per graded lens that has findings. Open with a 1-paragraph thesis for the lens. Then each finding as a section:

```
## <ID> (<severity P0–P3 / Nit>) — <one-line title>

### Current state
<prose + a real code excerpt + `path:line` citation>

### Why it matters
<the concrete failure mode, tied to scale/team/product stakes>

### Proposed contract / fix
<the specific change, with the target code/config>

### Migration sequence
1. …  2. …  (ordered, safe-to-land steps)

### Blast radius
<files touched, serialize-vs-parallel, runtime risk, the safety net>
```

End with **Cross-references** to sibling companions. Severity: **P0** launch-blocking, **P1** must-fix-this-quarter, **P2** should-fix, **P3/Nit** polish.

## HTML report

A single self-contained `report-<YYYY>-WNN>.html`: header with the Overall grade as a big health number, a scorecard table with colored grade pills and trend arrows, and (optional) inline sparklines of key metrics across runs (the registry feeds these). No external assets except a CDN chart lib if used. Use it for the at-a-glance view and to skim trends without reading markdown.

## Redaction

When the profile sets `redaction: "split"`:

- **Tracked** (committed in `docs/reviews/<week>/`): the trend scorecard, the engineering narrative, and non-sensitive companions. Security/tenancy/data-access rows in the scorecard carry **trend-level notes only** — grade + direction + a one-line theme, never vuln class, file:line, or repro.
- **Scratch** (`docs/reviews/_scratch/`, gitignored): the full unredacted SUMMARY + the sensitive companions (security, tenancy, silent-failure, data-trust) with complete file:line detail.
- **Private issues**: file the actionable security/tenancy findings to the profile's `tracker` (e.g. a `security`-labelled issue), and reference them from the tracked SUMMARY as "(detail in private issues)".

When `redaction: "none"`, everything is committed in the week dir; skip the scratch split.

Either way, **the scratch dir must be gitignored** and never the place trend history lives — the registry (tracked) is the durable record.

## `full`-mode methodology (multi-agent)

`full` mode is the authoritative periodic run. It is opt-in (uses the Workflow orchestration tool). Shape:

1. **Map** — run `collect-metrics.sh`; load the prior registry row and prior findings.
2. **Fan out lenses** — one agent per enabled lens, in parallel, each returning structured findings (`{id, severity, title, file, line, evidence, why, fix, migration, blast_radius}`) and a proposed grade. Give each lens agent the metrics map + the repo's stated rules.
3. **Adversarially verify** — for each finding, an independent verifier agent re-checks it against the cited `file:line` and returns `{real: bool, severity_adjust, note}`. **Drop or downgrade findings that don't reproduce.** This is what separates this from a one-shot opinion.
4. **Re-status prior findings** — a pass that marks each prior-run finding Addressed/Partial/Open/Worsened with current evidence.
5. **Synthesize** — assemble grades (verifier-adjusted), compute trends from the registry, write SUMMARY + companions + HTML, append the registry row.

A sketch of the Workflow pipeline (pipeline by default — each lens verifies as soon as it's reviewed):

```js
const results = await pipeline(
  LENSES,
  lens => agent(lensPrompt(lens, metrics, rules), {label:`review:${lens.key}`, phase:'Review', schema: FINDINGS}),
  review => parallel(review.findings.map(f => () =>
    agent(`Adversarially verify against ${f.file}:${f.line}: ${f.title}. Default to NOT real if you can't reproduce.`,
          {label:`verify:${f.id}`, phase:'Verify', schema: VERDICT}).then(v => ({...f, verdict:v}))))
);
const confirmed = results.flat().filter(Boolean).filter(f => f.verdict?.real);
```

Scale agents to the lens count; security/tenancy lenses warrant higher reasoning effort. `quick` mode skips steps 2–3's fan-out (the reviewer does it inline) and is explicitly labelled provisional.
