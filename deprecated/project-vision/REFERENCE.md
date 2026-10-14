# Project Vision Reference

## Structure

Use this shape unless the repo has a stronger local convention:

- `# Vision`
- One sentence saying what the project is and what it optimizes for.
- One crisp paragraph explaining the stable decision lens.
- `Target User`
- `Durable Advantage`
- `Will Not Do`
- `Update Rules`
- `Glossary` (optional, trailing — fallback only; see Canonical Vocabulary)

Write each `Will Not Do` clause as a concrete, citable trigger — the observable pattern `check` will point at, not a mood. Prefer "Adds a config flag to keep a legacy data contract alive instead of migrating it" over "stays disciplined about data." `Will Not Do` is the check-detectable layer; do not add a separate "tripwires" block, which only drifts out of sync with it.

## Vision Init Grill

Ask one question at a time. Give a recommended answer with each question.

1. Purpose: What does this project do, for whom, in one sentence?
2. Target user: Who is the real human this should serve first?
3. Pain: What recurring problem should this remove or make dramatically easier?
4. Solution bet: What is the opinionated way this project solves it?
5. Durable advantage: What asset, workflow, taste, data, distribution, or constraint makes this hard to copy?
6. Anti-goals: What tempting work should this project explicitly refuse?
7. Contradiction test: What plausible future request should agents challenge because it conflicts with this vision?

Do not keep the grill transcript in `VISION.md`.

## Stress Test

Before finalizing a `VISION.md` (in `init`, `review`, and any `update`), sort every load-bearing claim into exactly one of:

- **Durable constraint or tradeoff** — a rule the project holds even when tempted. Keep as-is.
- **North-star direction** — where the project is heading, written explicitly as a direction, not as an achieved fact ("we are betting on X", not "we are the X"). Keep, but make the aspirational framing explicit.
- **Present-truth claim** — an assertion about what is true today. Keep only if someone could measure or verify it today. If not, reframe it as a constraint or a labelled north-star direction, or cut it.

The failure this prevents: **asserting an aspiration as present truth you cannot measure** — e.g. `Durable Advantage: the fastest onboarding in the category` written as current fact, with no way to tell whether it holds. A vision is allowed a north star; it is not allowed an unmeasurable claim dressed as reality.

Ask of each load-bearing sentence: *could someone tell whether this is true today?* If not, it is a direction or it is nothing.

## Canonical Vocabulary

Every load-bearing term in `VISION.md` must be defined once, carry one canonical name, and read in plain language. Synonym drift (`users` vs `customers` vs `operators`) and unexplained jargon make a vision uncheckable.

Resolution order (in `init` and `review`):

1. **Align to an existing source.** If the repo has a canonical vocabulary source — `CONTEXT-MAP.md`, a root `CONTEXT.md`, or a domain model / glossary — use its canonical terms and do **not** duplicate it into `VISION.md`.
2. **Otherwise, add a concise trailing `## Glossary`** to `VISION.md` — load-bearing terms only, within the one-screen / under-80-line budget:

   ```md
   ## Glossary
   - **Customer** — a trade business that pays for the product. _Avoid_: client, account, user.
   - **Operator** — an internal staff member who runs a job. _Avoid_: admin, agent.
   ```

   One canonical name per concept, a one-sentence definition of what it *is* (not what it does), and the aliases to avoid. This mirrors the `domain-modeling` skill's `CONTEXT.md` `## Language` format. A full ubiquitous-language treatment belongs in that skill's `CONTEXT.md`; the `VISION.md` glossary is a lightweight fallback for load-bearing terms only. When the repo later adopts a `CONTEXT.md`, migrate the glossary there and align.

## Check Verdicts

`check` returns exactly one verdict, the clause it turns on, and an action:

| Verdict | Meaning | Action |
| --- | --- | --- |
| `ALIGNED` | Serves the vision; no clause strained | `proceed` |
| `TENSION` | Strains a clause or the durable advantage, short of contradiction | `reshape` (say how) |
| `CONTRADICTS` | Trips a `Will Not Do` clause or works against the direction | `escalate` to the user |

Rules:

- **Adversarial first.** Build the strongest contradiction case before concluding; a self-graded check defaults to passing its own work.
- **Cite, don't gesture.** Quote the specific clause. A verdict that can't name a clause is a vibe, not a check.
- **Never auto-resolve.** `CONTRADICTS` escalates the vision-vs-work decision to the user; `check` never edits `VISION.md` and never silently proceeds.
- **Label calibration honestly.** If the repo has no validating corpus (see WORKFLOW Calibrate), mark the verdict `uncalibrated`.

## Vision Check Log and Corpus

Two per-repo, committed artifacts. Their paths are a **local-profile setting**, not a global default — defaults shown are examples (see repo `CONVENTIONS.md`: do not hard-code one project's docs layout into the portable skill).

- **Check log** — default `docs/vision/checks.jsonl`, append-only, one line per `check`:
  `{ "date": "YYYY-MM-DD", "work": "<short summary>", "verdict": "ALIGNED|TENSION|CONTRADICTS", "clause": "<quoted clause>" }`
- **Calibration corpus** — default `docs/vision/corpus.jsonl`, one line per mined past decision:
  `{ "work": "<short summary>", "expected": "ALIGNED|TENSION|CONTRADICTS", "basis": "shipped|reverted|rejected|refused", "source": "<commit|adr|roadmap ref>" }`

## Layering

- `VISION.md`: project direction, target user, durable advantage, anti-goals.
- `AGENTS.md`: durable agent rules and required read order.
- `docs/agents/**`: repo-specific agent configuration, including autonomy and sign-off boundaries.
- `docs/workflow/**`: workflow governance, task lifecycle, verification, handoff.
- `ROADMAP.md`: unshaped ideas and future possibilities.
- `docs/specs/**`: shaped workstream plans.
- `docs/adr/**`: durable decisions with real trade-offs.
- Strategy / business doc (repo's own naming): economics, unit economics, pricing, go-to-market mechanism, and value attribution. `VISION.md` states the durable *bet*, not the operating economics.
- `CONTEXT-MAP.md` / `CONTEXT.md`: canonical domain vocabulary (owned by the `domain-modeling` skill). `VISION.md` aligns to it, or carries a concise fallback `## Glossary` when it does not exist.
- Workspace docs: current app/package/tooling behavior.

## Quality Checks

- The vision names a real human, not just an organization.
- The problem and solution bet are specific enough to reject adjacent work.
- Durable advantage is explicit.
- Anti-goals close off tempting branches.
- No agent autonomy gates live in `VISION.md`.
- No economics, go-to-market mechanism, or value attribution — those live in the strategy/business doc, stated once.
- Every load-bearing claim survives the Stress Test: it is a durable constraint, a labelled north-star direction, or a measurable present-truth claim — not an unmeasurable aspiration asserted as fact.
- Load-bearing terms are defined once, use one canonical name, and read in plain language — aligned to the repo's vocabulary source, or a concise trailing `## Glossary` when none exists.
- Update rules say not to edit unless explicitly requested.
- Each `Will Not Do` clause is a concrete, citable trigger `check` can render a verdict against.
