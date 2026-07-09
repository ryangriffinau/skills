---
summary: "Pipeline and conventions for producing franken_ocr-calibre comprehensive plans from a rough articulation."
status: "active"
stage: "planning"
owner: "Ryan"
updated_at: "2026-06-26"
read_when:
  - "When you want to take a rough idea of what to build to a self-contained, near-zero-ambiguity implementation plan."
  - "When choosing or sequencing the /p-* planning prompts for a substantial workstream."
  - "Before writing a spec for anything large, novel, or high-stakes enough to deserve the full floor."
related_docs:
  - "docs/README.md"
  - "docs/specs/README.md"
  - "docs/specs/comprehensive-planning/comprehensive-plan-template.md"
  - "docs/specs/comprehensive-planning/plan-rubric.md"
---

# Comprehensive Planning

> **How to read this document.** This is the *method*, not a plan for a feature. It reverse-engineers how Jeffrey Emanuel's [`COMPREHENSIVE_PLAN_FOR_FRANKEN_OCR.md`](https://github.com/Dicklesworthstone/franken_ocr/blob/main/COMPREHENSIVE_PLAN_FOR_FRANKEN_OCR.md) reaches its calibre, and lays out the pipeline that takes *you* from "here is roughly what I want to build" to a document of that calibre. The **output contract** lives in [`comprehensive-plan-template.md`](./comprehensive-plan-template.md); the **forcing function** lives in [`plan-rubric.md`](./plan-rubric.md). Terms tagged `[VERIFIED]` are confirmed from source; `[REPORTED]` are claimed but unconfirmed; `[OPEN]` are unknowns routed to the Open-Questions Register.

## The core insight `[VERIFIED]`

Our `/p-draft-plan`, `/p-synthesize-plans`, `/p-plan-to-beads`, `/p-pre-mortem`, and `/p-unsummarizable` **are Jeffrey's own prompts**, or near-variants. The franken_ocr document is therefore **not** the product of prompts we lack. It is the product of three things our pipeline does not yet supply:

1. **A grounded front-half.** ~19% of his document is a sourced "target dossier" reverse-engineering the exact thing being built, *before* any solution design. None of our three best specs has an analogue — they open with "Problem," he opens with 143 lines of cited ground truth.
2. **An output contract.** A fixed 11-section skeleton with conventions our prompts never demand: evidence tags, goals carrying a *verification owner*, proof obligations worked inline, a layered verification ladder, EV-ranked levers, and an Open-Questions Register that **gates phases**.
3. **A forcing function.** Nothing checks a draft against that standard and refuses to proceed until it's met.

So the work is not "write better prompts." It is: **supply the dossier, bind the output to the contract, gate on the rubric, and sequence the prompts we already have.** That is this pipeline.

## What you supply: the Stage-0 intake

You do not need to write a plan. You write a **seed** — five short answers — and the pipeline grows it:

- **Build.** One paragraph: what we are making and for whom.
- **Ground truth.** The exact thing it must imitate, integrate with, or replace (an API, a benchmark, a schema, a competitor surface, a legacy runtime). Name it concretely; this is what the dossier will exhaustively pin down.
- **Non-negotiables.** The 1–3 properties that, if violated, mean failure regardless of everything else.
- **Constraints.** Stack, deadlines, package boundaries, things that must not change.
- **Unknowns you already feel.** Anything you suspect you don't know — these become the first `OQ-N` entries.

That seed is enough. Everything below turns it into the document.

## The pipeline

Single high floor. Depth flexes with **surface size**, never with rigor — a three-file change still gets a dossier, an OQ register, and a verification section; they are just shorter. Each stage names the tool we already have, the convention it enforces, and the gate that must pass before the next stage.

| # | Stage | Driver | Tool we already have | Enforces | Exit gate |
|---|-------|--------|----------------------|----------|-----------|
| 0 | **Articulate** | You | the Stage-0 intake above | a concrete ground-truth target | the five answers exist |
| 1 | **Dossier** | Agent (investigation mode) | `/p-deep-project-primer` + code/web investigation | every fact tagged + sourced; complete work-surface derived | the **exists / build / gap** table is filled; unknowns are `OQ-N` |
| 2 | **Draft (fan-out)** | Each frontier model independently | `/p-draft-plan` → the [template](./comprehensive-plan-template.md) | the full 11-section contract | ≥2 independent drafts, each filling every section |
| 3 | **Synthesize** | Strongest model | `/p-synthesize-plans` | best-of-all-worlds hybrid, no attribution | one merged plan |
| 4 | **Grill** | You ↔ agent | `/grill-me` (or `grill-with-docs`) | rationale + rejected alternatives on every major decision | every decision has a "why" and a "why-not"; new unknowns → OQ |
| 5 | **Pre-mortem** | Agent | `/p-pre-mortem` → `/p-premortem-planner` | failure modes → risk rows + cheap early signals | top failure causes are OQ entries or risk rows; plan revised |
| 6 | **Density** | Agent | `/p-unsummarizable` | every sentence load-bearing | no sentence survives deletion without losing an idea |
| 7 | **Grade** | Agent | [`plan-rubric.md`](./plan-rubric.md) | the calibre floor | rubric ≥ floor; **below floor → loop to the weakest stage** |
| 8 | **Decompose** | Agent | `/p-plan-to-beads` | epics = phases; OQ = blocking P0 bead; spike = bead-with-contract | beads graph mirrors the roadmap; no impl bead depends on an open OQ |

The gates are the point. Stage 1 refuses to hand off an ungrounded dossier; Stage 7 refuses to decompose a sub-calibre plan; Stage 8 refuses to schedule implementation behind an unresolved unknown. That chain is what makes the calibre *reproducible* instead of heroic.

### Where the leverage actually is

Stages 2, 3, 5, 6, 8 are prompts we already run well. The calibre gap is almost entirely **Stage 1 (dossier)** and the **contract + gate** the template and rubric impose on Stages 2 and 7. If you only adopt two things, adopt the dossier and the rubric.

## The conventions (carried by the template)

These are the devices that separate his document from ours. Each is a section or a required field in [`comprehensive-plan-template.md`](./comprehensive-plan-template.md); the catalog here is the *why* so the template can stay terse.

- **Evidence tags** — `[VERIFIED]` / `[REPORTED]` / `[OPEN]` on every load-bearing claim. Makes the plan falsifiable: a reader knows instantly which sentences are grounded and which are bets.
- **Open-Questions Register (`OQ-N`)** — a table of `ID · Question · Blocks · Source-to-read · Status`, and one hard rule: **no implementation bead starts against an unresolved `[OPEN]`.** This is the cleverest device in the source — completeness comes not from knowing everything but from *exhaustively enumerating and routing what you don't know*. It maps 1:1 onto beads dependencies.
- **Goals with operational definitions + verification owners** — a goal is not "be fast"; it is a measurable property plus *who/what proves it*, plus an explicit priority ordering ("G1 over G2, always").
- **Named conceptual wedge** — the one-line thesis that justifies the whole approach (his "a general framework pays a generality tax on every op; we run exactly one model"). If you can't name it, the approach isn't decided yet.
- **Exists / build / gap surface table** — derive the *complete* set of work units and tag each as reuse, net-new, or unknown. This is the antidote to confident prose over unscoped territory.
- **Annotated file tree** — the target layout where *every file carries an inline comment stating its job*. Zero-ambiguity handoff.
- **Proof obligations** — any decision resting on a numeric or correctness assumption states the assertion **and** the test that asserts it. "This fits in i32 with 9× headroom — but that is a proof obligation, not an assumption."
- **Verification parity ladder** — for any port/migration/integration, a rung table (granularity × tolerance) from exact-match to end-to-end, and the discipline of establishing the *reference's own noise floor first*.
- **Alternatives considered and rejected** — first-class on every major decision, with the reason it lost (ideally a measured one).
- **Scope-out with reasons** — record the considered-and-deferred "no"s (his PDF-support decision), so the boundary is intentional, not accidental.
- **EV-ranked levers** — prioritize with an explicit `EV = Impact · Confidence · Reuse / Effort · Friction`, and flag the ranking as a hypothesis to be replaced by measurement.
- **Spikes / "alien families"** — speculative high-upside ideas, each bound to `{artifact · proof obligation · deterministic fallback}` so nothing speculative is unfalsifiable.
- **Diagrams** — at minimum an architecture sketch, a pipeline flow, and the dependency DAG. Closes the prose-only gap the spec survey flagged across all three of our best plans.

## When to use this

Use the full floor for anything **large, novel, irreversible, or cross-boundary**: a new package, a migration, a customer-facing surface with abuse/security stakes, an integration against an external contract. For a contained change, run the same stages at lower depth — the sections remain, the prose shrinks. The one thing that does **not** flex is rigor: there is no "lightweight mode" that drops the dossier, the OQ register, or the verification section. The floor is the forcing function.

## Status & next move

- **Now:** this pipeline, the [template](./comprehensive-plan-template.md), and the [rubric](./plan-rubric.md) exist and are usable immediately by pointing `/p-draft-plan` at the template and grading with the rubric.
- **Next (highest-value, not yet done):** write **one worked exemplar** — rewrite a real in-flight workstream to full calibre as the north-star reference. A copyable exemplar teaches the standard faster than any template.
- **Later:** promote the template + an orchestrator prompt (`/p-deep-plan`) into the prompts library so the pipeline is invocable as a slash command across projects, not just documented.

## References

- [`comprehensive-plan-template.md`](./comprehensive-plan-template.md) — the output contract.
- [`plan-rubric.md`](./plan-rubric.md) — the forcing function / grade gate.
- [`COMPREHENSIVE_PLAN_FOR_FRANKEN_OCR.md`](https://github.com/Dicklesworthstone/franken_ocr/blob/main/COMPREHENSIVE_PLAN_FOR_FRANKEN_OCR.md) — the source exemplar.
- `docs/specs/_template.md` — the minimal spec template (this is its high-floor sibling, not its replacement).
