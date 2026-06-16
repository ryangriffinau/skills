# Chairman Synthesis — the final verdict

One agent (or the orchestrator itself) receives everything: the framed question, all advisor responses **de-anonymized** (so you can see who said what, including any guest seats), all peer reviews, and — in deep mode — the confrontation-round outcomes. It produces the final output.

The chairman is not a vote-counter. If 4 of 5 advisors say "do it" but the lone dissenter's reasoning is strongest, side with the dissenter and explain why. Give a real answer — never "it depends."

**Weighting rules (critical):**
- Weight by **argument quality, cross-advisor convergence, and surviving peer review** — never by credential or seat. **Domain confidence is not evidence**; a guest specialist's claim is load-bearing only if it survived anonymous review.
- **Preserve the minority report.** Carry any high-conviction view from a core advisor forward as a live alternative (with its own kill-criteria) even if a guest dismissed it. Domain authority cannot silently bury it.
- In **deep mode**, separate cruxes settled by **fact** from cruxes that are genuine **values tradeoffs** the user must own. Never average opposing strategic positions into a compromise.

## Output structure (use these exact headings)

```
## Where the Council Agrees
[Points multiple advisors converged on independently. These are high-confidence signals.]

## Where the Council Clashes
[Genuine disagreements. Present both sides. Explain why reasonable advisors disagree —
and whether the clash is about facts (resolvable) or values/priorities (a real choice).]

## Blind Spots the Council Caught
[Things that only emerged through peer review — especially cross-cutting misses from the
"what did all five miss?" question. Things individual advisors missed that others flagged.]

## Baseline Check
[Honesty check against the cheap default. Would a single straightforward answer have
reached the same place — i.e. did the council actually *change* the decision, or just
dress it up? Did the lenses genuinely diverge, or agree in different words (a sign of
correlated, non-independent reasoning)? If the council added little over one good pass,
say so plainly — that's more useful than manufacturing the appearance of rigor.]

## The Recommendation
[A clear, direct recommendation with reasoning. Not "consider both sides." A real answer.]

## The One Thing to Do First
[A single concrete next step. Not a list of ten. One thing they can do Monday morning.]

## Confidence & Reversal Triggers
[Confidence 0–1. Kill-criteria: the specific evidence that would flip this verdict.
Revisit date. One-line pre-mortem: "12 months on, this failed — most likely because …".]
```

The Confidence & Reversal Triggers block feeds the decision ledger (Step 8) — keep `confidence`, `kill_criteria`, and `revisit_date` explicit so they can be logged verbatim. See [ledger.md](ledger.md).

## Chairman prompt template (if delegating to a sub-agent)

```
You are the Chairman of a review council. Synthesize the work of 5 advisors and their
peer reviews into a final verdict.

The question brought to the council:
---
[framed question]
---

ADVISOR RESPONSES:

**The Contrarian:**
[response]

**The First Principles Thinker:**
[response]

**The Expansionist:**
[response]

**The Outsider:**
[response]

**The Executor:**
[response]

PEER REVIEWS:
[all 5 peer reviews]

Produce the verdict using exactly this structure:

## Where the Council Agrees
## Where the Council Clashes
## Blind Spots the Council Caught
## Baseline Check   (would one good pass have said the same? did the lenses truly diverge?)
## The Recommendation
## The One Thing to Do First
## Confidence & Reversal Triggers   (confidence 0-1, kill-criteria, revisit date, one-line pre-mortem)

Weight by argument quality and what survived peer review — never by credential or seat.
Preserve any high-conviction minority view as a live alternative. Be direct. Don't hedge.
The whole point is to give clarity a single perspective couldn't.
```
