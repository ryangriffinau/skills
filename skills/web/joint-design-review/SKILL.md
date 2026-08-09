---
name: joint-design-review
status: drafting
version: 0.1.0
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
audit → report → triage → rulings → bead → implement → verify.

**One product area per cycle. Never two.** A review that spans areas produces findings
nobody can act on and beads nobody owns.

## 1. Scope

If the user named an area, that is the scope. If not: inventory the app's areas, check
which are contended by other in-flight work, and propose an order with a one-line
recommendation. **Done when:** one named area is agreed.

## 2. Load the bar — progressively

Read the repo's `AGENTS.md`, docs entrypoint, and design-system doc (if any) first —
the repo's own contracts always win over the generic bar. If the repo declares a
frontend skill order, use that order verbatim.

Otherwise detect the stack from `package.json` and load skills **at the step that uses
them**, one rule-set in focus at a time. Staged loading is not about tokens: seven
rule-sets loaded together interfere — near-synonymous terms drift across skills, and a
rule from one bleeds into a dimension another owns.

| When | Load |
| --- | --- |
| Now, before reading a single component | `/impeccable` (the quality bar), plus the stack skill: `/tanstack` on TanStack projects; `/vercel-react-best-practices` on Next.js or plain React |
| Audit — heuristics and a11y dimensions | `/ux-audit` |
| Audit — motion dimension (and any motion fix later) | `/emil-design-eng` |
| Audit — reinvention dimension | `/pick-ui-library` |
| Audit — modality pass, and polish during implementation | `/ui-polish` |

Skills that name a framework still carry portable React and frontend standards — use
those parts on any React stack; discard only the rules tied to a framework the project
does not use. Index-style skills (`/vercel-react-best-practices` is a rule index with
one file per rule) stay index-only: pull the individual rule files a finding actually
touches, never the full expansion.

**Done when:** the bar (`/impeccable` + stack skill) is loaded before you have read a
single component — loading it after forming an opinion is not loading it — and each
remaining skill loads exactly when its row above fires.

## 3. Preflight

Every gate passes before the audit starts.

1. **The app renders — hard gate.** Load it and confirm a real surface appears. A design
   review without the running app is a code review wearing a costume. If the server is
   down, stop and say so in one sentence. Never start, restart, or kill a server you do
   not own.
2. **Contention.** If the repo runs multi-agent work (beads, agent mail, panes), check
   what is in progress. Pick an uncontended area or reserve files first — findings on a
   surface someone is mid-edit on are stale before they are read.
3. **History.** Search the docs for prior audits, acceptance screenshot sets, and design
   specs covering this area, and read them. State in the report which prior findings you
   rechecked and their current state. Re-raising a finding the user already ruled on
   burns trust in the whole report.
4. **Pin the tree.** Record the commit SHA the audit is true of and list dirty files in
   the area. Any finding crossing a dirty file is **provisional** and is rechecked
   before it becomes work.

## 4. Audit

**Mechanical sweep first.** Run the deterministic scan over the area before any
eyes-on work:

```bash
node <skill-dir>/scripts/static-scan.mjs <area-source-dirs>
```

It emits JSONL candidates for raw colour literals, `transition-all`, bare `ease-in`,
over-300ms durations, `scale(0)` entries, arbitrary z-index, px font sizes,
`window.history.back`, and `!important`. Hits are **candidates, not findings** —
verify each in context before it enters the report. Record the scan result (including
a clean one) in the report's coverage section; a skipped scan is a coverage gap.

Then go surface by surface through the whole area — list, detail, create/edit, empty,
loading, error, and permission-denied states. Cover desktop and mobile **separately and
fully**; optimise each modality on its own terms rather than accepting a compromise
that is mediocre on both.

Work every dimension and say which you covered:

1. **Flow and dead ends** — every reachable state, and whether the user can get out.
2. **Heuristics** — Nielsen per `/ux-audit`; name the heuristic on each finding.
3. **Accessibility** — keyboard path, focus order and visibility, composite-widget
   semantics, contrast, touch targets, colour-only meaning, labels.
4. **Design-system conformance** — semantic tokens only, no raw literals, no arbitrary
   z-index, no recreated primitive styles, judged against the project's own contract.
5. **Motion** — per `/emil-design-eng`: purpose, frequency, easing, duration, press
   feedback, interruptibility, reduced-motion.
6. **Reinvention** — behaviour hand-rolled that an installed dependency already owns.
7. **React and data correctness** — reset boundaries and keys, derived vs stored state,
   subscription lifecycle, waterfalls, re-render cost.
8. **Copy** — plain language that says what the user must do; never names internals.
9. **Consistency** — one concept rendered one way everywhere.

### Screenshot policy

Screenshots are the acceptance evidence, not decoration — green unit tests have
repeatedly false-closed UI work while the surface was visibly broken.

- **Light mode: every surface, desktop and mobile widths.**
- **Dark mode: only where the theme can actually diverge.** If the project's token
  contract defines both modes per token and a contract test locks the bridge, that test
  is the mechanical dark-mode gate. Screenshot dark mode only when (a) a finding is
  itself a theme defect, or (b) the work changes colour tokens or a shared component's
  colours — and then one representative surface at one width is enough, because the
  token propagates. A project with no token contract gets the full dark matrix.

**Done when:** every surface and dimension is covered and each finding has evidence. A
hit-only audit is not trustworthy — also record what you traced and cleared.

## 5. Report

Write the report from [references/report-template.md](references/report-template.md)
into the repo's docs (follow its docs layout; `docs/design/<area>-<date>/` when nothing
is declared), screenshots beside it. Rank findings by whether a real user can hit them
and by the cost of the mistake — never by ease of fix. If the repo declares a
communication register (for example Simplified Technical English), everything the user
reads follows it.

Beside the report, write `findings.jsonl` — one row per finding:
`{"id", "rank", "class", "dimension", "file", "line", "summary", "bead": null}`. The
report is for the user; the JSONL is the machine-readable contract the beading step
consumes and later steps verify against. **Done when:** the report has a findings
table, per-finding evidence with `file:line` and blast radius, a checked-and-cleared
table, and every finding has a `findings.jsonl` row.

## 6. Triage — two classes, no third

**Class A — standing approval. Raise it, bead it, fix it. Do not ask.** These have an
objectively correct answer and no product judgement:

| # | Class | Boundary |
| --- | --- | --- |
| 1 | Accessibility defect | WCAG and the project's a11y contract are standards, not taste |
| 2 | Functional defect | A control that does nothing, shows wrong data, or acts on hidden records |
| 3 | Dead end | A reachable state with no way forward and no way back |
| 4 | Missing state | No loading, empty, error, or skeleton state where one is needed |
| 5 | Design-system drift | Raw literals, off-scale spacing, arbitrary z-index, recreated primitive styles |
| 6 | Theme breakage | A surface unreadable or visibly wrong in a shipped theme |
| 7 | Responsive breakage | Overflow, clipping, overlap, or unreachable controls at a supported width |
| 8 | Motion violation | Against the loaded motion bar (`/emil-design-eng`) |
| 9 | Reinvented behaviour | Hand-rolled code an installed dependency already owns |
| 10 | Performance defect | A measurable cause: waterfall, re-render cascade, bundle regression |
| 11 | Inconsistency | One concept rendered two ways in the same product |
| 12 | Jargon in user copy | Replacing internal vocabulary with a plain instruction |
| 13 | Density conformance | Judged against the project's declared density/touch-target preference |

Class A fixes **what exists**. The moment a fix changes *what the system does*, it is
Class B. Where the project declares a preference (density, tone, motion personality),
Class A means conforming to it; where two Class A rules genuinely conflict and no
project preference settles it, the conflict is Class B.

**Class B — ruling required. Raise it, bead it as blocked, ask.**

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

Present Class B as a numbered list of decisions, each with a recommendation and the
trade-off in one sentence. A Class B change folded into a Class A fix is how a reviewer
misses it — keep them in separate findings, separate beads, separate commits.

**Done when:** every finding carries exactly one class, and the Class B list has been
put to the user. Wait for rulings before implementing any Class B item; Class A needs
no wait.

## 7. Bead everything, before any implementation

Use the project's canonical tracker. With beads present, follow `/beads-workflow` and
use only the `br` tool; without a tracker, write the findings doc and ask where work
should live.

- One **epic** per area review; one **child bead per finding** — never one bead for
  "the audit findings".
- Each bead is self-contained: the finding, `file:line`, before/after, blast radius,
  screenshot path, and **falsifying acceptance criteria** — a behavioural assertion
  that would have failed before the fix, plus the re-screenshot. "It compiles" and
  "tests pass" are not acceptance for a design bead.
- Label each bead with the review label plus the area, plus `standing-approval` or
  `needs-ruling`.
- Class B beads are created **now**, blocked, with the exact question and the
  recommendation in the description. Parking with context loses nothing; waiting loses
  the finding.
- Add real dependencies, verify the graph has no cycles, sync, and commit the tracker
  state with the report.

**Done when:** every row in `findings.jsonl` carries a non-null `bead` id. Check the
file, not your memory of it.

## 8. Implement and verify

Ship Class A beads without further approval. Ship a Class B bead only after its ruling,
recorded verbatim on the bead. Per bead: run the project's own quality gate, force a
real (uncached) run of tests and typecheck, re-screenshot the changed surface per the
screenshot policy, and commit with explicit paths — shared trees punish `git add -A`.

**Ratchet what the scan proved.** Once the area's static scan is clean, offer to pin
it: a small CI test that runs the same checks over the area and fails on new hits.
Invariants encoded as tests survive; invariants encoded as prose regress.

**Close the cycle:** report what shipped, what each screenshot proves, what remains
blocked on a ruling, and which area you recommend next with one reason. Then stop. The
next area starts on the user's word, not yours.
