---
description: Tangible Progress, Anti-Ceremony, and Honest Credit — bind a session or swarm to working-software-only progress; no process porn, feature-first ratio, absolute honesty, refusal is not delivery
---

## Tangible Progress, Anti-Ceremony, and Honest Credit

The purpose of this project is working, deployable software delivered accretively in the shortest time compatible with correctness, performance, reliability, and innovation. Process exists to serve that outcome; it must never become the product.

- **No process porn.** Certificates, ledgers, dashboards, meta-reports, and process documents are not progress. A process artifact may exist only when it is a hard gate for a named feature or capability - the conformance validator and required release evidence qualify; self-referential paperwork does not. Choosing process artifacts because they are easy and low-risk is reward hacking, and it is treated as such.
- **Feature-first ratio.** The overwhelming majority of open work items must deliver runnable behavior - code, schemas, and contracts that an end user or consuming agent can actually exercise. Process/ops items are capped (guideline: at most ~5% of open beads), and each must name the feature work it gates; a process item that gates nothing does not get created.
- **Honesty is absolute.** Never fake a test, present a fixture or mock as live proof, weaken an assertion to make it pass, hard-code a success path, or close work that is not done. A false close is reopened with an incident comment on the record.
- **Refusal is not delivery.** A correctly typed refusal is far better than a fabricated result - and far less valuable than the real capability. Implementing only the refusal path earns partial credit at most: it never closes a feature work item. Full credit requires the positive capability implemented for real, tested, and verified. Mark refusal-only states explicitly (e.g., a `refusal-only` label plus a follow-up item) so they read as unfinished, never as shipped.

These rules bind human-directed sessions and NTM swarms alike, and they must be encoded into the acceptance criteria of the work items themselves.
