---
name: customer-update
status: refining
version: 0.9.0
tags: [communication, reporting, stakeholder]
updated: 2026-07-30
description: Write a progress update for a reader outside the codebase: customer, client, or exec sponsor. Grounds every claim in source evidence, cuts internal delivery churn, and states outcomes in the reader's own business vocabulary. Use when the user asks for a customer update, client update, progress summary, stakeholder report, or what shipped this period.
---

# Customer Update

The reader knows their business and nothing about your repo. Every line earns its
place by changing what they know, trust, or decide.

Two words carry the skill. **Visible**: the reader met this in their own work.
**Churn**: internal process activity they never see. Keep visible, cut churn.

Worked before-and-after corpus, including the accepted minimum bar:
[`references/EXAMPLES.md`](references/EXAMPLES.md). Gathering commands by source
type: [`references/EVIDENCE.md`](references/EVIDENCE.md).

## 1. Gather from source

Read the actual record for the period: commit history, closed work items, test
and evaluation artifacts, production run output.

The session remembers what was discussed; the repo records what shipped. Those
diverge, and the repo wins.

_Completion criterion:_ every candidate item traces to a command output or file
read this session, and the period boundaries are fixed dates.

## 2. Filter to what they experienced

Classify every candidate **visible** or **churn**, then delete the churn outright
rather than softening it.

Churn is real work that leaves no trace in the reader's day: refactors, counts of
tracked items, internal ceremonies, backlog clearing, deploy plumbing, anything
whose subject is your team.

Then order the survivors by how directly the reader meets them. What they touch
daily leads, whatever order the work happened in.

_Completion criterion:_ every candidate carries a visible-or-churn verdict with a
reason, and the ordering reflects visibility rather than chronology.

## 3. Keep numbers that do work

A number stays when it changes the reader's confidence or their decision. Counts
of your own process fail that test; counts of their data pass it.

Quantify accuracy and coverage claims hardest, because those are the ones a
reader is entitled to doubt.

_Completion criterion:_ every surviving number has a named source you can point
at, and each cut number was cut for failing the test.

## 4. Write it in their vocabulary

Follow the **Form** rules below for titles, bodies, and the forward-looking
section. Translate every capability into something the reader could recognise
from their own operation, using their official terminology where it exists.

_Completion criterion:_ a reader with no access to the repo could act on every
line, and each technical item states its consequence.

## 5. Strip slop and overreach

Run [`/de-slopify`](https://github.com/ryangriffinau/skills) over the draft for
the general patterns, then clear the two this genre attracts: vague
quality-claims that assert without evidence, and one comparative construction
repeated across bullets.

Then apply the **Boundary** rule below.

_Completion criterion:_ the draft survives a read-aloud pass, and every remaining
claim is about work you did rather than decisions the reader owns.

## Form

**Titles** name a capability as a noun phrase. A title is a label, not a sentence
and not a claim, so it carries no verb of achievement and no adverb of
completeness.

- `Piece-level tracking now runs end to end.` becomes `Piece tracking for quality findings`
- `Classification accuracy was measured against hand-adjudicated evidence.` becomes `AI evaluation set labelled to improve accuracy`

**Bodies** state what changed and what it means for the reader, in two or three
sentences. Anything technical earns its place by its consequence: what the reader
stops doing by hand, stops missing, or can now trust.

**Coming up** items are a short feature name plus at most one sentence. Choose by
visibility, the same filter as step 2, so the item the reader will actually meet
leads the list.

## Boundary

Report what exists and what you built. Rollout timing, go-live, and whether staff
see something are the reader's decisions to make, so state readiness and leave
the decision with them.

Where a genuine caveat exists, name it in one line to the user rather than hiding
it in the artifact, and let them choose the framing.
