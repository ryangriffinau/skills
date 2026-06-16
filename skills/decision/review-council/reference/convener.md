# The Convener — casting guest seats

Runs once, after the question is framed, before any advisor spawns. Cheap and inline (no sub-agent). Its **only** job is to decide whether to add domain guest seats — it does **not** size or downsize the session. Depth is the user's call (standard vs deep), never an invisible classification.

> Why no sizing here: a hidden classifier that caps a session's depth is an unreviewed single judgment made *before* the council — exactly the thing a council exists to distrust. Misjudge it and the highest-stakes decision silently gets the lightest treatment, and no one notices. So depth is explicit and user-controlled; the convener only adds expertise.

## Cast guest seats (0–2) — and make it visible
Add a guest **only if** a real discipline adds non-obvious expertise the generalist lenses would miss. **If nothing qualifies, run the clean 5 — never fabricate an expert.** Cap at 2 so the core spine always outnumbers guests.

**Announce each guest in one line with an override before spawning**, e.g. *"Casting one guest seat: B2B SaaS Pricing Strategist — override or proceed?"* (proceed by default; don't block). This keeps the one judgment the convener still makes reviewable.

Craft each guest sharply:
- **Precise discipline,** not a vague title. "B2B SaaS Pricing Strategist," not "Business Expert."
- **Narrow mandate:** surface domain-specific facts, constraints, standards, and failure modes the generalists can't see. The guest does **not** decide the question.
- **A named bias-to-watch** for that discipline (e.g. a security expert over-indexes on threats nobody will hit).
- **Grounding requirement:** cite concrete mechanisms, benchmarks, or standards — not vibes. A guest may use a research/web tool to verify a load-bearing claim.

### Guest spawn prompt template
```
You are [Precise Discipline] — a guest specialist on a review council. You are here for
domain expertise the generalist advisors lack.

A user has brought this question to the council:
---
[framed question]
---

Your mandate is narrow: surface the domain-specific facts, constraints, standards, and
failure modes a non-specialist would miss. Ground every load-bearing claim in a concrete
mechanism, benchmark, or standard — not intuition. You are NOT deciding the question and
you are NOT a tie-breaker; the council decides. Watch your own bias toward [named bias].

150-300 words. No preamble.
```

## Anti-overweighting guards (carry into review & synthesis)
The guest must not dominate just because it's "the expert." Five layered guards:
1. **Spine outnumbers.** Core 5 are permanent; guests ≤ 2.
2. **Anonymization does the work.** In peer review (see [peer-review.md](peer-review.md)) the guest is just another lettered response — reviewers judge it on merit with no authority cue.
3. **Scoped mandate.** Guest informs feasibility/facts, not the verdict.
4. **Chairman weights by argument quality + cross-advisor convergence + surviving peer review — never by credential.** "Domain confidence is not evidence; a guest claim is load-bearing only if it survives review." (Goes in the chairman prompt — see [chairman.md](chairman.md).)
5. **Minority preservation.** A high-conviction idea from any core advisor stays a live option even if the guest dismisses it.
