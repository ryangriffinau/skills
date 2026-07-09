---
summary: "Scored rubric that grades a comprehensive plan against the franken_ocr calibre floor and gates decomposition."
status: "active"
stage: "planning"
owner: "Ryan"
updated_at: "2026-06-26"
read_when:
  - "At pipeline Stage 7, before /p-plan-to-beads, to decide whether a plan is calibre enough to decompose."
  - "When reviewing a spec/plan and you want an objective read on what is missing."
related_docs:
  - "docs/specs/comprehensive-planning/README.md"
  - "docs/specs/comprehensive-planning/comprehensive-plan-template.md"
---

# Plan Rubric

> **How to use.** Score the draft on each dimension `0 / 1 / 2`. This is the **gate at pipeline Stage 7**: a plan below the floor does not proceed to `/p-plan-to-beads` — it loops back to its weakest stage. Pair the score with a fresh-eyes read; the number is a floor check, not a substitute for judgement. See [README](./README.md) for the pipeline and [template](./comprehensive-plan-template.md) for the contract being graded.

## Dimensions

For each: **0** = absent · **1** = present but thin/ungrounded · **2** = full, per the convention.

| # | Dimension | 0 — absent | 1 — partial | 2 — full |
|---|-----------|------------|-------------|----------|
| 1 | **Ground-truth dossier** | opens at "Problem" with no sourced target | target described from memory, no sources | exhaustive, every fact tagged + sourced, work-surface derived |
| 2 | **Evidence tagging** | no tags | tags on some claims | every load-bearing claim is `[VERIFIED]`/`[REPORTED]`/`[OPEN]` |
| 3 | **Open-Questions Register** | unknowns hand-waved or absent | listed but not linked to blocks | `OQ-N` table with `Blocks` + `Source`; gates the roadmap |
| 4 | **Goals w/ owners + priority** | vague aspirations | measurable but no owner/ordering | operational definition + verification owner + explicit priority rule |
| 5 | **Named wedge** | no stated thesis | implied | one-line wedge the design follows from |
| 6 | **Rationale density** | decisions asserted bare | some "why" | every major decision carries its "why" |
| 7 | **Alternatives rejected** | none | mentioned generically | per-decision, with the (ideally measured) reason it lost |
| 8 | **Proof obligations** | numeric/correctness claims unbacked | asserted, untested | assertion **and** the test that asserts it |
| 9 | **Verification ladder** | "we'll test it" | a test list | rung table (granularity × tolerance) + reference noise floor first |
| 10 | **Architecture concreteness** | prose only | partial layout | annotated file tree (every file's job) + exists/build/gap table |
| 11 | **Diagrams** | none | one | architecture + pipeline + dependency DAG |
| 12 | **Phased roadmap w/ gates** | unordered tasks | phases without gates | phases with Goals·Tasks·Exit-gates; Phase −1 truth pack |
| 13 | **EV-ranked levers / spikes** | unprioritized | ranked by feel | EV formula applied; spikes carry artifact·proof·fallback |
| 14 | **Beads-readiness** | no handoff | loose mapping | epics=phases, OQ=blocking bead, file=bead+test+criteria |
| 15 | **Density** | padded prose | some fluff | survives `/p-unsummarizable` — no cuttable sentence |

## Scoring & gate

- **Max:** 30. Sum the dimensions.
- **Floor to decompose: 24/30**, with **no single dimension at 0** among #1, #3, #8, #9, #12 (dossier, OQ register, proof obligations, verification, gated roadmap — the five that make a plan safe to execute from).
- **Below floor → do not run `/p-plan-to-beads`.** Identify the lowest-scoring dimensions and loop to the stage that owns them:
  - #1, #2 weak → back to **Stage 1 (dossier)**.
  - #6, #7 weak → back to **Stage 4 (grill)**.
  - #3, #8, #9 weak → back to **Stage 5 (pre-mortem)** and tighten verification.
  - #15 weak → back to **Stage 6 (density)**.

## Depth-dial note

A small-surface plan still must score **2 on #1, #3, #8, #9, #12** — those flex in *length*, not presence. A three-file change can have a one-paragraph dossier and a two-row OQ table, but it cannot have *none*. That is the single high floor: rigor is constant, prose scales.
