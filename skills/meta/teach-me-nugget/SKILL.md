---
name: teach-me-nugget
status: drafting
version: 0.1.0
tags: [learning, mentoring, incident-review]
updated: 2026-07-30
description: Turn a concept just hit in live work into an immediately usable nugget — correct the user's guessed name, give the real terms of art, extract smells with concrete tests grounded in the incident's own numbers, and end on a one-line principle. Use when the user asks "what is this called?", guesses a name ("is this tree-shaking?"), or wants heuristics from a lesson just learned. Chat output only; deep study escalates to /teach.
---

# Teach Me Nugget

A **nugget** is the smallest teachable unit extractable from work that just
happened: the right name for the thing, how to smell it early, and one line to
keep. It is a fluency artifact — immediately usable, in-context — not a storage
artifact: it produces no files, no workspace, no curriculum. In /teach
vocabulary, a nugget builds fluency strength; storage strength is /teach's job,
and the escalation path between them is a single move — the user points /teach
at the nugget text.

The moment to fire: the user has just collided with a concept in live work they
can half-describe but not name — often mid-incident, right after the numbers
are on the table. Freshness is the whole leverage; a nugget written while the
user's own figures are still in front of them anchors where a textbook example
never will.

## Steps

1. **Correct the frame first.** If the user guessed a name ("is this a
   tree-shaking issue?"), open by showing precisely why that name does or does
   not fit, argued in the incident's own terms. The near-miss is the hook: the
   gap between the guessed concept and the real one is the lesson. Done when
   the guessed term has been explicitly accepted or rejected with a reason tied
   to the incident.

2. **Name it.** Give the real terms of art — one to three, each with a
   one-line definition. Terms must be searchable: the user should be able to
   google them, or hand them to /teach, verbatim. If a concept has no
   established name, say so and coin one, labeled as coined. Done when every
   named term is either a recognized term of art or marked as coined.

3. **Ground it in their incident.** Every claim cites the actual numbers, file
   paths, or code from the live work. The user's own figures (their 50×
   amplification, their 61% fan-in) are the anchor; a hypothetical example is
   a different, weaker nugget. Done when no claim in the nugget rests on an
   invented example.

4. **Extract the smells.** A table, ordered by catch-rate: each row is a
   smell, a concrete test anyone can run (a command, a threshold, a question),
   and the reading from this incident. This is the actionable core — the user
   should be able to apply a row to a different codebase tomorrow. Done when
   every row's test is executable without this conversation as context.

5. **Compress to one line.** End with a single memorable principle that
   carries the whole lesson — e.g. "if deleting an import would free
   megabytes, the truth is stored in the wrong phase." If it needs two
   sentences, it is two nuggets; pick the one the incident actually taught.
   Done when the line stands alone without the table.

6. **Offer the knowledge-tree hook.** One sentence connecting the concept to a
   fundamental the user already holds — the zone-of-proximal-development
   anchor that lets them tie the nugget back to their core knowledge tree. If
   no crisp connection exists, say that plainly: the inability to connect is
   itself the signal, and the recommendation is then to escalate — point
   /teach at this nugget for deep, stored study. Done when the nugget ends
   with either a hook or an explicit escalation recommendation.

## Shape of the output

One chat reply, readable in one sitting: frame correction → names → grounded
evidence → smells table → one-liner → hook. The reply IS the nugget; the user
may later paste it into /teach as a mission seed, and nothing else needs to be
set up for that to work.
