---
summary: "Output contract for a franken_ocr-calibre comprehensive plan; the eleven sections /p-draft-plan must fill."
status: "active"
stage: "planning"
owner: "Ryan"
updated_at: "2026-06-26"
read_when:
  - "When drafting a comprehensive plan and you need the exact section skeleton and conventions to fill."
  - "When pointing /p-draft-plan or /p-synthesize-plans at a target structure."
related_docs:
  - "docs/specs/comprehensive-planning/README.md"
  - "docs/specs/comprehensive-planning/plan-rubric.md"
  - "docs/specs/_template.md"
---

# Comprehensive Plan Template

> **How to use.** Copy everything below the rule into `docs/specs/<workstream>/PLAN.md` and fill it. This is the *high-floor* sibling of [`_template.md`](../_template.md) — use it for large, novel, irreversible, or cross-boundary work. Keep every section; let depth flex with surface size, never rigor. The instructions in _italics_ explain each section and are deleted as you write. See [README](./README.md) for the conventions' rationale and [plan-rubric](./plan-rubric.md) for the grade gate.

---

```
---
summary: "<one sentence>"
status: "proposed"
stage: "planning"
owner: "<name>"
updated_at: "<YYYY-MM-DD>"
read_when: ["<when to load this plan>"]
related_docs: ["docs/specs/README.md", "docs/workspaces/<owner-doc>.md"]
related_adrs: ["docs/adr/NNNN-<decision>.md"]
---
```

# Comprehensive Plan for `<workstream>`

> **How to read this document.** Audience: `<who implements / reviews>`. Status: `<draft | review | accepted>`. Evidence tags: `[VERIFIED]` confirmed from a cited source · `[REPORTED]` claimed, unconfirmed · `[OPEN]` unknown, routed to §11. No implementation begins against an unresolved `[OPEN]`.

## 1. Mission & non-negotiable goals

_The smallest true statement of what this builds and the properties it must hold. Goals are a table — each row is a measurable property, not an aspiration._

| ID | Goal (operational definition) | Verification owner | Priority |
|----|-------------------------------|--------------------|----------|
| G1 | _e.g. "Public audit returns within 8s p95, measured by the staging smoke run."_ | _test / check that proves it_ | highest |
| G2 | … | … | … |

**Priority rule:** _state the ordering explicitly, e.g. "G1 over G2, always — a faster path that breaks correctness is reverted."_

**Non-goals:** _what this deliberately does not do._ **Scoped-out with reasons:** _considered-and-deferred decisions and why the "no" is intentional._

## 2. Ground-truth dossier

_The exhaustive, sourced reverse-engineering of the thing being built, imitated, integrated with, or replaced — the API, schema, benchmark, competitor surface, or legacy runtime. This is the section our specs usually skip and the one that buys the most calibre. Every fact is tagged and sourced._

- **Identity & shape** `[VERIFIED]` — _exact names, versions, contracts, sizes, with a `Source` for each._
- **Components / surface** — _break the target into its parts; for each, the exact interface it exposes._
- **Input / output contract** — _precise shapes in and out._
- **Complete work-surface (exists / build / gap):**

| Unit | Where used | Status | Plan |
|------|-----------|--------|------|
| _e.g. `resolveWebsite` Convex query_ | _customer site render_ | `EXISTS` / `BUILD` / `GAP` | _reuse / net-new / unknown→OQ_ |

_Reconcile any contradiction in the source into an `OQ-N` rather than guessing._

## 3. Why this approach — the wedge

**The wedge:** _the one-line thesis that justifies the whole design (the named insight everything else follows from)._ _Then the argument: cite measured prior results where they exist `[VERIFIED]`; record known traps as doctrine._

## 4. System architecture

_An annotated file/module tree where every file carries an inline comment stating its job, plus the diagrams._

```
<target layout>
  path/to/file.ts   # exactly what this file is responsible for
```

```mermaid
%% architecture and/or end-to-end pipeline
```

_Plus the exists/build/gap op table from §2 resolved into concrete modules._

## 5. Data model & contracts

_Schemas, types, payloads, API shapes — specified field-by-field before any implementation step. Name exact functions and tables._ **Proof obligations:** _any decision resting on a numeric/correctness assumption states the assertion **and** the test that asserts it._

## 6. Implementation chapters

_One subsection per major component. Concrete: exact libraries, exact functions, exact algorithms, exact boundaries. Pair every non-trivial decision with its rationale and its rejected alternatives._

### 6.1 `<component>`
- **Decision:** … **Why:** … **Rejected:** _alternative + the reason (ideally measured) it lost._

## 7. Verification & conformance

_For a port/migration/integration, a parity ladder. Establish the reference's own noise floor first, then ratchet._

| Rung | Granularity | Tolerance / pass condition |
|------|-------------|----------------------------|
| L0 | _exact preprocessing / fixtures_ | exact |
| L1 | _per-unit_ | _within stated tolerance_ |
| L… | _end-to-end_ | _within budget_ |

_Plus: test modules per layer, fixtures, and the staging E2E that proves it live._

## 8. Performance & levers

_EV-ranked, with the formula explicit. The ranking is a hypothesis to be replaced by measurement._

| Lever | Impact | Confidence | Reuse | Effort | Friction | EV |
|-------|--------|-----------|-------|--------|----------|----|

**Spikes / speculative ideas:** _each bound to `{artifact · proof obligation · deterministic fallback}`._

## 9. Phased roadmap

_Each phase has Goals · Tasks · Exit gates. Phase −1 is the truth pack: ground-truth green before any implementation. Milestones don't start until the prior is green, documented, and (where required) reviewed._

- **Phase −1 — Truth pack:** _Goals · Tasks · Exit gate (all §2 unknowns resolved or routed; dossier accepted)._
- **Phase 0..N:** …

## 10. Risks & mitigations

| Risk | Severity | Likelihood | Cheap early signal | Mitigation |
|------|----------|-----------|--------------------|------------|

_Pre-mortem output lands here: the top causes of failure, each with the cheapest signal that would warn you early._

## 11. Open-Questions Register

_The honesty mechanism. Every `[OPEN]` in the document appears here. **No implementation bead starts against an unresolved entry.** At decomposition, each open row becomes a P0 research bead blocking its dependent._

| ID | Question | Blocks | Source to read | Status |
|----|----------|--------|----------------|--------|
| OQ-1 | … | _G? / phase? / file?_ | _doc/code/person to consult_ | open / resolved |

## 12. Success metrics

_How we know it worked in production — distinct from the goals' verification owners. Each metric: definition + owner + target._

## 13. Decomposition & handoff to beads

_Map the plan onto the execution graph so `/p-plan-to-beads` is mechanical: epics = §9 phases; every open `OQ-N` = a P0 research bead that **blocks** the implementation bead depending on it; every spike = a bead carrying its `{artifact · proof obligation · fallback}` contract; every §4 file/unit = a bead with its test and its acceptance criteria._

## References

_Sources cited by the dossier and decisions, with links._
