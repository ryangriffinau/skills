---
description: Force complete, paste-ready hand-back of every decision/blocker/action needing me
argument-hint: [optional: which items, or leave blank for all currently open]
---

Before actioning anything, hand back EVERY open decision, blocker, approval, or action that needs me — each a self-contained block I can act on without opening a file, searching a doc, or knowing an ID.

## Why this file is strict (2026-08-12)

Ryan rejected two hand-back items in a row with "I have no idea what any of this
is for" and "No idea what you're asking". Both were written as tracker IDs with a
question attached — `r2cw(a)`, `ojt9` image shape — so they were answerable only
by someone already holding the internal context. The information he needed to
decide was never in the message.

The failure was not laziness about detail. It was writing from the *asker's* frame
instead of the *decider's*. Every rule below exists to force the second frame. Do
not relax them because an item feels obvious to you — it feeling obvious is the
symptom.

## The rule that matters most

**I must be able to answer without knowing what any tracker ID means.**

If I have to ask "what is this for?" or "what is that ID?", the item has failed and you have wasted my time instead of saving it.

**An ID is never the subject.** It may appear only in parentheses, after a plain-English name, as a filing reference:

- WRONG: "`r2cw(a)`: should the repair path drop the open-order filter?"
- RIGHT: "**When we re-check an old message against orders, should we look at the orders as they are today, or as they were when the message was written?** (bead `r2cw`, item a)"

Same for file paths, function names, table names, event names, and internal vocabulary. Name the *situation*, then the artifact.

## Per item

1. **What is actually happening** — the real-world situation, in plain words, before any internal name. What does a person see, or fail to see? What breaks?
2. **Why it's on me** — one line. What makes it mine rather than yours.
3. **The data, inline** — the actual list, numbers, options, command, or rendered text pasted here. Never a pointer to where it lives. If it's a screen, describe what is on it.
4. **Each option's consequence** — what actually happens if I pick it. Not "option A is safer": what changes for a user, an operator, or the data.
5. **Your recommendation, or an honest refusal** — say which you'd pick and why. If you genuinely can't recommend, say so and say what you'd need to know. Never fake neutrality to avoid committing.
6. **The exact move** — copy-paste command, URL, or click.
7. **Reply format** — how I fire the answer back in one line.

## Rules

- **Every internal term gets one plain line before it is used.** Bead, milestone, artifact, acronym, table, event, flag. If defining it takes more than a line, you do not understand it well enough to be asking me about it — go and find out first.
- **Lead with consequence, not provenance.** I care what happens, not which bead it came from or which agent found it.
- Missing a detail? Say so and how you'll get it — never hand me a gap to chase.
- Setup work (environments, secrets, accounts, DNS, third-party config) is not a step list: propose the `wizard` skill and turn the steps into one guided CLI — you drive, I answer prompts.
- Do not pad the list. An item I have already answered, or that is not actually blocked on me, does not belong in it.
- End with the single highest-priority action and what it unblocks.

## Self-check before you send

Read each item back as if you had never seen this project. For each one:

- Could you answer it? If not, rewrite it.
- Does any sentence start with, or depend on, an ID or a file path? Rewrite it.
- Does it say what actually goes wrong for a person if I choose badly? If not, add it.

If an item survives all three, send it. If more than one item fails, the list is not ready.

Scope (blank = everything open): $ARGUMENTS
