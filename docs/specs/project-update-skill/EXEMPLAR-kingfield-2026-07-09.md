# Exemplar: Kingfield AI-Gateway update (2026-07-09)

The seed calibration case. Three artifacts: the agent's first draft (slop),
Ryan's line-edit feedback, and the FINAL SENT version below. The deltas
draft→sent are the learning set.

## Deltas: what Ryan changed before sending (fold into SKILL rules)

1. **Actions upfront.** The asks moved to the TOP, before updates — the reader's
   required actions lead, headed "Actions upfront". The draft had them after
   the updates.
2. **Per-ask pattern**: bold name + italic exact-action TL;DR ("*Add $100
   credit.*", "*Just needs card - stay on Free.*") + blunt reason + direct deep
   link + cost-anxiety preemption ("Have already enabled hard caps on the
   project") + friction anticipation ("Let me know if you need any re-invites").
3. **Batch every outstanding ask** — the draft had one (Vercel); the sent
   version had three (Vercel $100, Braintrust card, Cloudflare R2 card). The
   grounding step must sweep ALL pending human/billing gates, not just the one
   that prompted the update.
4. **Channel-native formatting** — Teams supports markdown; bold/headings KEPT.
   The draft's "no emphasis characters" rule is channel-dependent (plain for
   SMS/email-paste; rich for Teams/Slack/Notion), not universal.
5. **Addressed to a person** (@frankl62), direct opener ("some big updates
   here"). Not a broadcast.
6. **Blunt reason-giving**: "We've dropped Azure AI because its full of bugs,
   old models and lacks features." State the real reason; no diplomatic fog.
7. **Tempered capability claims**: "AI starting to flag: nonconformance, root
   cause..." — *starting to*, not implying finished capability.
8. **Honest operational notes**: "Turned off SMS/reply notifications temporarily
   to roll out these updates" — disclose temporary degradation proactively.
9. **Coming-next enriched from the roadmap** (added iPad/mobile quality form) —
   pull near-term roadmap items the reader cares about, not only what the
   session touched.
10. **Appendix survived nearly verbatim** — the marked technical-appendix
    pattern is validated.

## Final sent version (verbatim)

@frankl62 some big updates here:

### **Actions upfront**

Let me know if you need any re-invites.

1. **AI Gateway credit**. *Add $100 credit.* We've dropped Azure AI because its full of bugs, old models and lacks features. We've moved to Vercel AI Gateway on a small starting credit. To keep production running uninterrupted, add a payment method and top up: Vercel Dashboard https://vercel.com/kingfield-galvanizings-projects/~/settings/billing > AI Gateway Credit > Add $100 and we can monitor usage over coming weeks. Have already enabled hard caps on the project.
2. **Braintrust upgrade**. *Just needs card - stay on Free.* Used for improving the AI assessments - compounds over time. Braintrust - The AI observability platform for building quality AI products
3. **Cloudflare upgrade.** *Just needs card - stay Free.* We need this to properly store attachments - its very cheap - everything will likely be on free tier for a while. Just needs card details. https://dash.cloudflare.com/b66ef86a967257506248a09c8821da94/r2/plans

### **Updates**

The quality issue capture system is now materially more reliable and accurate, with expanded functionality. Detail:

- **Model upgrade:** GPT-4.1 to GPT-5.4, via a new AI Gateway. Matched-or-better accuracy on benchmark, lower operating cost, full usage visibility, and the ability to switch models as better ones ship. No vendor lock-in.
- **AI benchmarking built in.** Extraction accuracy is tested continuously against 107 real Teams messages checked case by case. Current results: ~90% precision, ~91% recall, near-zero false alarms. Quality drops are caught before they reach production.
- **Teams Messages.** Turned off SMS/reply notifications temporarily to roll out these updates. Channels are read, matched to the right customer and order, and turned into structured proposals automatically. This morning a hole/air-trap issue on Job #41300 was captured, linked to Cola Engineering and the order item, risk-flagged, and queued for review within three seconds.
- **AI starting to flag**: nonconformance, root cause, rework (strip and regalvanise), quantities per piece.
- Backend re-architected so new features ship faster and with less risk.

**Coming next:**

- In-Teams notifications: porting over to full stack replies posted on the original message, one-click approve, and questions that pre-fill the detail (e.g. "Holes for all 34 pieces on order item 244345?") so the team confirms rather than writes.
- Simple form for quality input on iPad/mobile.
- Attachment capture: photos and paperwork saved with each proposal.
- Native Teams integration, and rework trend and root-cause analysis.

## **Appendix - some technical detail**

**Quality-finding primitives.** Each message is broken into a small set of typed facts: what was observed, what work is needed, claims made about it (cause, responsibility), what was already done, and any data anomalies. One message can produce several linked findings.

**Actions, work orders, workflow steps.** The model separates three things that are easy to conflate: a reported action (something the floor says already happened), a work order (physical or production work to be done), and a workflow step (an ops or management checkpoint such as approval). This tracks what was done, what must be done, and who signs off, without mixing them.

**Benchmark method.** The 107-example set covers the full range of real cases (needs-holes, rework, blasting, quantity errors, multi-order messages), each expected result checked by hand. It is the yardstick every model or prompt change is measured against.
