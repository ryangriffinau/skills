---
name: joint-design-review
status: drafting
version: 0.2.0
tags: [design, frontend, audit, ux, beads]
updated: 2026-08-09
description: >-
  Joint design review of one product area: audit against the loaded design bar, split
  findings into standing-approved fixes vs decisions that need the user's ruling, bead
  every finding, then implement and verify with screenshots. Use when the user asks for
  a design review, a UI/UX audit of a page or product area, frontend polish with
  approval gates, or a joint-design-review cycle.
---

# Joint design review

A design review is **joint**: the agent audits and fixes; the user rules. Every finding
lands in exactly one of two classes — **standing approval** (fix without asking) or
**ruling required** (park and ask). The cycle is: scope → load the bar → preflight →
audit → report → triage → rulings → materialise → implement.

**One product area per cycle. Never two.** A review that spans areas produces findings
nobody can act on and beads nobody owns.

Four scripts do the mechanical work. Run them; do not reimplement them by eye.

| Script | Step | Does |
| --- | --- | --- |
| `scripts/contention.mjs` | 3 | Resolves the area's data path and fails if any of it is dirty |
| `scripts/static-scan.mjs` | 4 | Deterministic sweep for the checkable Class A candidates |
| `scripts/shoot.mjs` | 4 | Captures every surface and rejects any capture of the wrong page |
| `scripts/findings.mjs` | 5, 7 | Validates the findings tracker; materialises it into real issues |

## 1. Scope

If the user named an area, that is the scope. If not: inventory the app's areas, check
which are contended, and propose an order with a one-line recommendation.
**Done when:** one named area is agreed.

## 2. Load the bar — progressively

Read the repo's `AGENTS.md`, docs entrypoint, and design-system doc first. The repo's
own contracts always win over the generic bar, and a repo-declared frontend skill order
is used verbatim.

Otherwise detect the stack from `package.json` and load skills **at the step that uses
them**, one rule-set in focus at a time. Staged loading is not about tokens: seven
rule-sets at once interfere — near-synonymous terms drift between skills, and a rule
from one bleeds into a dimension another owns.

| When | Load |
| --- | --- |
| Now, before reading a single component | `/impeccable`, plus the stack skill: `/tanstack` on TanStack; `/vercel-react-best-practices` on Next.js or plain React |
| Audit — heuristics and a11y | `/ux-audit` |
| Audit — motion, and any motion fix later | `/emil-design-eng` |
| Audit — reinvention | `/pick-ui-library` |
| Audit — modality pass, and polish during implementation | `/ui-polish` |

Framework-named skills still carry portable React standards — use those parts on any
React stack and discard only the framework-specific rules. Index-style skills stay
index-only: pull the individual rule files a finding touches, never the full expansion.

**Done when:** the bar is loaded before you have read a single component. Loading it
after forming an opinion is not loading it.

## 3. Preflight

1. **The app renders — hard gate.** Load it and confirm a real surface appears. A design
   review without the running app is a code review wearing a costume. If the server is
   down, say so in one sentence and stop. Never start, restart, or kill a server you do
   not own.
2. **Contention — run the script.** `node scripts/contention.mjs <area-paths>`. It
   resolves the area's imports back to the packages it renders from and fails if either
   set is dirty. Checking only the area's own component files is not enough: an area
   whose components are clean can still be served by a query another agent is mid-edit
   on, and the review will spend its effort diagnosing that.
3. **History, and what is deliberate.** Read the prior audits, screenshot sets, and
   design specs for this area. Then ask the question they rarely answer directly:
   **which of this area's current behaviours are deliberate?** A surface that looks
   under-built is often a decision you cannot see from the code. State in the report
   which prior findings you rechecked and their state now.
4. **Pin the tree.** Record the commit SHA and any dirty files. A finding crossing a
   dirty file is **provisional** and is rechecked before it becomes work.

## 4. Audit

**Mechanical sweep first**, before any eyes-on work:

```bash
node scripts/static-scan.mjs <area-paths>     # dirs and files, in any mix
```

Hits are **candidates, not findings** — verify each in context. Record the result,
including a clean one; a skipped scan is a coverage gap.

**Then capture every surface** with `scripts/shoot.mjs` and a config
(see [references/evidence.md](references/evidence.md)). The harness warms up the session
and asserts each capture landed on the page you asked for, then exits non-zero if any
did not. Never reason about an image it rejected.

Then work surface by surface — list, detail, create/edit, empty, loading, error,
permission-denied. Cover desktop and mobile **separately and fully**; optimise each
modality on its own terms rather than accepting a compromise mediocre on both.

Dimensions, all of which the report must account for:

1. **Flow and dead ends** — every reachable state, and whether the user can get out.
2. **Heuristics** — Nielsen per `/ux-audit`; name the heuristic on each finding.
3. **Accessibility** — keyboard path, focus order and visibility, composite-widget
   semantics, contrast, touch targets, colour-only meaning, labels.
4. **Design-system conformance** — judged against the project's own contract.
5. **Motion** — purpose, frequency, easing, duration, press feedback, reduced-motion.
6. **Reinvention** — behaviour hand-rolled that an installed dependency owns.
7. **React and data correctness** — reset boundaries and keys, derived vs stored state,
   subscription lifecycle, waterfalls, re-render cost.
8. **Copy** — plain, and no longer than it needs to be.
9. **Consistency** — one concept rendered one way everywhere.

**When a finding contradicts a deliberate choice**, do not assert breakage. State the
choice, say why it still costs the user, and bring evidence that a better option exists
— a [quality reference](references/quality-references.md) is the strongest form. Split
the artifact from the intent: a sound decision can leave an unsound implementation
behind it, and filing them as one finding makes the whole thing rejectable.

**Done when:** every surface and dimension is covered, each finding has evidence, and
you have also recorded what you traced and cleared. A hit-only audit is not trustworthy.

## 5. Report

Write the report from [references/report-template.md](references/report-template.md)
into the repo's docs, screenshots beside it. Rank by whether a real user can hit it and
what the mistake costs — never by ease of fix. Follow any communication register the
repo declares.

Beside it write `findings.jsonl`, the audit's own tracker — schema and rules in
[references/tracking.md](references/tracking.md). Then:

```bash
node scripts/findings.mjs validate <findings.jsonl>
node scripts/findings.mjs summary  <findings.jsonl>
```

**Done when:** `validate` passes.

## 6. Triage — two classes, no third

**Class A — standing approval. Raise it, bead it, fix it. Do not ask.**

| # | Class | Boundary |
| --- | --- | --- |
| 1 | Accessibility defect | WCAG and the project's a11y contract are standards, not taste |
| 2 | Functional defect | A control that does nothing, shows wrong data, or acts on hidden records |
| 3 | Dead end | A reachable state with no way forward and no way back |
| 4 | Missing state | No loading, empty, error, or skeleton state where one is needed |
| 5 | Design-system drift | Raw literals, off-scale values, arbitrary z-index, recreated primitive styles |
| 6 | Theme breakage | A surface unreadable or visibly wrong in a shipped theme |
| 7 | Responsive breakage | Overflow, clipping, overlap, or unreachable controls at a supported width |
| 8 | Motion violation | Against the loaded motion bar |
| 9 | Reinvented behaviour | Hand-rolled code an installed dependency already owns |
| 10 | Performance defect | A measurable cause: waterfall, re-render cascade, bundle regression |
| 11 | Inconsistency | One concept rendered two ways in the same product |
| 12 | Jargon in user copy | Internal vocabulary replaced with a plain instruction |
| 13 | Density conformance | Judged against the project's declared density preference |
| 14 | **Over-explanation** | Copy that says what the interface already shows |

**#14 is not #12.** #12 catches copy the user cannot understand. #14 catches copy the
user does not need — correct, plain, and still condescending. It covers **prose, helper
text, section headings, and field labels equally**: a label reading "Status" above a
control already reading "Open findings" is over-explanation in one word. Cut it and
trust the user. `static-scan.mjs` flags both shapes as candidates.

*The one boundary:* cutting explanation is Class A. Cutting a warning about an
irreversible, governed, or money-moving consequence is Class B — that warning may exist
because its absence once hurt someone.

Class A fixes **what exists**. The moment a fix changes *what the system does*, it is
Class B. Where the project declares a preference, Class A means conforming to it; where
two Class A rules conflict and no preference settles it, the conflict is Class B.

**Class B — ruling required. Raise it, record it as blocked, ask.**

| # | Class | Why it is the user's call |
| --- | --- | --- |
| 1 | Domain meaning or terminology | The business owns its language |
| 2 | Workflow or process change | Adding, removing, or reordering a user step |
| 3 | Information architecture | Moving features between pages; changing navigation |
| 4 | New feature or scope growth | Not a fix to what exists |
| 5 | Backend contract or schema change | New fields, queries, persisted shapes |
| 6 | New dependency or primitive direction | A standing architectural commitment |
| 7 | Brand | Colour, logo, tone, identity |
| 8 | Production data or irreversible action | Never taken on the agent's authority |
| 9 | File deletion | Renaming and moving are allowed; deletion needs permission |

Present Class B as a numbered list, each with a recommendation and the trade-off in one
sentence. Never fold a Class B change into a Class A fix.

Expect rulings to arrive as **conditional bars** ("address it only if we reach this
quality") and as **corrections to your framing**. Record both verbatim on the row, and
correct the classification rather than defending it.

**Done when:** every finding carries one class, and no Class B row is unruled —
`findings.mjs validate` enforces this.

## 7. Materialise into the tracker

`findings.jsonl` has been the tracker all along. Turning rows into real issues is a
separate, explicit act, and it happens **only on the user's word**.

The hazard is not just a write race. **A finding filed as a ready issue gets claimed and
built** — an agent swarm pulls ready work automatically, so filing before the Class B
rulings land hands unreviewed audit output to agents that will implement it. Do not
solve this with a second tracker workspace; see
[references/tracking.md](references/tracking.md) for why that fails.

```bash
node scripts/findings.mjs materialise <findings.jsonl> --epic "<title>"          # dry run
node scripts/findings.mjs materialise <findings.jsonl> --epic "<title>" --apply
```

It refuses to run while any Class B row is unruled, creates one epic plus one child per
row, and writes each returned id back into the row.

**Done when:** `findings.mjs summary` reports zero unbeaded rows.

## 8. Implement and verify

Ship Class A rows without further approval. Ship a Class B row only after its ruling,
recorded verbatim. Per item: run the project's quality gate, force a real uncached run
of tests and typecheck, re-capture the surface with `shoot.mjs`, and commit with
explicit paths — shared trees punish `git add -A`.

**Ratchet what the scan proved.** Once an area scans clean, offer to pin it: a CI test
running the same checks that fails on new hits. Invariants encoded as tests survive;
invariants encoded as prose regress.

**Close the cycle:** what shipped, what each screenshot proves, what remains blocked on
a ruling, and which area you recommend next with one reason. Then stop. The next area
starts on the user's word.
