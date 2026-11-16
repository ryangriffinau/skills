---
name: p-hitl
description: Hand back each decision only I can make (situation, options, recommendation), dense enough to decide in one read
argument-hint: "[optional: which items; blank = all open]"
status: refining
version: 0.9.0
tags: [comms, prompts]
updated: 2026-11-16
compatibility: "If the host leaves $ARGUMENTS literal, use the user message accompanying this skill invocation as its value."
---

Hand back every open decision that only I can make, as numbered blocks, most urgent first.

**N. <The decision as one plain question, with any deadline.>** (ref: <IDs>)
- **Situation:** what is happening, what goes wrong if nobody decides, and the facts I need, inline.
- **Options:** two to four; for each, what actually changes for a customer, the money or the system.
- **Recommend:** the option you would pick and why, in one sentence; or why you cannot, and what would settle it.
- **Reply:** a one-line answer format, such as "2B".

Write from the decider's frame, not the asker's:
- Name the situation, not an ID, file path or internal term. IDs go in the ref; a term I must know gets one plain line.
- Every sentence carries information found nowhere else (/p-unsummarizable): no provenance, preamble or recap.
- Only my decisions. Anything you can decide, decide, and list it at the end under "Decided (veto if you disagree)", one line each.
- Make each recommendation concrete enough for an agent to carry out, so I can reply and then run /p-close-the-gaps.

Before sending, read each block as a stranger. If you could not decide from it alone, rewrite it.

Scope (blank = everything open): $ARGUMENTS
