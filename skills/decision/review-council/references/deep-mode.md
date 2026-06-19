# Deep mode — the confrontation round

Opt-in and **user-controlled** — never auto-selected. Triggered by adding `deep` after activating the skill (e.g. `/review-council deep`), or saying "deep" / "war room this". A standard session also opens with a one-line reminder that deep mode exists and can be switched in mid-run (the session keeps going unless the user says so). Runs **after** peer review and **before** the chairman.

Standard peer review is parallel anonymous critique — advisors never actually engage each other, so you can't tell whether a clash is real or just two people talking past each other. The confrontation round forces direct engagement on the genuine fault lines.

## Lineage (and the deliberate inversion)
Inspired by iterative-refinement systems like Dicklesworthstone's *llm-tournament*, which run multiple models across rounds and **synthesize hybrids** — merging the best features into one converged artifact. That's right for producing a *deliverable*. It's **wrong for a decision**: averaging two opposing strategic positions into a compromise produces mush and silently kills the high-conviction minority view.

So deep mode **borrows** two ideas and **inverts** the third:
- ✅ Borrow: *iterate until no new cruxes emerge* (a stopping criterion).
- ✅ Borrow: *synthesize strongest features* — but only for tactics that genuinely compose, never for the core strategic choice.
- 🔁 Invert: **resolve or preserve the tradeoff; never average it away.**

## Procedure
1. **Extract the cruxes.** From the responses + peer review, identify the 1–3 *genuine* disagreements (a crux = a point where, if it flipped, the recommendation would change). Ignore cosmetic differences.
2. **Confront, per crux.** Spawn the two (or more) advisors on opposite sides. Each must, in order:
   - **Steelman** the opposing position in one honest sentence (no strawmen).
   - **Rebut** it with their strongest specific argument.
3. **Classify each crux:**
   - **Factual** — hinges on an unknown fact ("does this market actually convert at X?"). → Optionally spawn a research sub-agent to fetch it, then re-run just those advisors with the fact in hand. Many "disagreements" dissolve here.
   - **Values / priorities** — hinges on what the user weights (speed vs durability, risk vs upside). → Not resolvable by argument. Surface it as an **owned tradeoff** the user must decide, with each side stated at full strength.
4. **Loop / stop.** Repeat for any *new* crux that surfaces, to a **max of 2 rounds**. Stop early when a round produces no new crux.

## Anti-mush rules (hand these to the chairman)
- **Do not compromise a strategic choice.** If the council splits on "course vs workshop," the answer is one of them (or a genuinely different third option), never "do a bit of both" unless that's a real, coherent option someone argued for.
- **Preserve the minority report.** If one advisor holds a high-conviction contrarian view that survived confrontation, the chairman names it as a live alternative with its kill-criteria — it does not get smoothed out.
- **Separate factual from values cruxes in the verdict** so the user knows what was *settled by evidence* vs what is *their call to make*.

The chairman's "Where the Council Clashes" section should report the confrontation outcomes: which cruxes were factual (and how they resolved) and which are genuine values tradeoffs left for the user.
