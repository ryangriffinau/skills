---
name: write-project-update
status: refining
version: 0.10.0
tags: [communication, reporting, changelog, stakeholder]
updated: 2026-08-03
description: "Write an evidence-grounded project update. Use when the user wants a customer or stakeholder update, public changelog or release note, internal status report, or source-audited summary of shipped work."
---

# Write Project Update

Write the update the reader needs, then show the evidence behind it. The
copy-paste block stays readable; its grounding audit travels below it.

When project sources are unfamiliar, use the adapters in
[`references/EVIDENCE.md`](references/EVIDENCE.md). When calibrating customer
voice or asks formatting, consult
[`references/EXAMPLES.md`](references/EXAMPLES.md).

## 0. Fix the mode and channel

Choose the primary mode before gathering or drafting, then load only its rules:

- customer: [`references/customer.md`](references/customer.md)
- public changelog:
  [`references/public-changelog.md`](references/public-changelog.md)
- internal: [`references/internal.md`](references/internal.md)

If purposes overlap, choose the mode that owns the reader's next decision. Also
name the delivery channel. Teams, Slack and Notion keep useful Markdown headings,
bold and italics. SMS and email-paste use plain text with simple labels and
hyphen lists.

_Completion criterion:_ one mode, one audience and one channel are explicit, and
the matching mode reference has been read.

## 1. Ground the window

Fix exact start and end dates, or a release identifier and its commit boundary.
Read the live project record for that scope: shipped work, merged changes, closed
and deferred items, evaluation results, production output, current risks and the
near-term roadmap. The record outranks session memory.

Build a claim ledger before drafting. For each candidate claim, record the exact
source file, command output, work item or URL. Mark unsupported details as
`[PLACEHOLDER: exact fact or source needed]`; never turn them into prose that
looks factual.

Run a separate **gate sweep** across billing, access, approvals, credentials,
invitations and other pending human actions. Do not stop at the action that
prompted the update. Record temporary degradations and tempered capability state
(`starting`, `partial`, `ready`, `live`) while gathering.

_Completion criterion:_ every candidate claim maps to a source or an explicit
placeholder, and every pending human or billing gate has an accounted-for
disposition.

## 2. Put asks first

When the gate sweep finds reader actions, the first substantive section is the
asks block. Include every outstanding ask. Each ask contains:

1. a bold ask name (or an unadorned label in plain text);
2. an italic exact-action summary (or a plain `Action:` line);
3. the blunt reason it is needed;
4. a direct deep link, not a product home page;
5. cost-anxiety preemption: expected cost, free-tier status, caps or monitoring;
6. anticipated friction: permissions, re-invites, card requirements or owner.

Use `[PLACEHOLDER: direct billing link]` or another exact marker when a required
detail is missing. If the sweep finds no action, omit the block instead of
inventing one or writing “no action needed.”

_Completion criterion:_ the asks block leads whenever any gate is open, and
every open gate appears once with all six fields grounded or visibly marked.

## 3. Draft for the selected mode

Apply the selected mode's structure and translate each retained fact into the
reader's vocabulary. State concrete outcomes and consequences. Keep numbers only
when they change confidence or a decision, and source them precisely. Pull
forward-looking items from the actual roadmap, ordered by relevance to this
reader rather than by implementation chronology.

Use direct, declarative language. Name the thing more often than “we” or “you.”
Give real reasons without diplomatic fog. Temper capability claims to their
evidenced state and disclose temporary degradation proactively.

_Completion criterion:_ every paragraph performs a job defined by the selected
mode, every technical detail states its consequence, and chronology or internal
effort never determines emphasis.

## 4. Add depth only when it earns its place

If technical or domain detail will help a subset of readers verify or act, add a
clearly marked **Technical appendix** after the main update. Keep all optional
depth there. Omit it when it only demonstrates effort.

_Completion criterion:_ the main update stands alone, and every appendix item
adds decision, verification or operational value.

## 5. Verify the draft

Apply the repository's copy-editing or deslopify prompt when available. Then
check the draft directly:

- each factual claim has a ledger entry;
- placeholders remain conspicuous and cannot be mistaken for facts;
- all asks are first, complete and directly linked or explicitly marked;
- the mode reference's inclusions and exclusions hold;
- formatting matches the named channel;
- filler, repeated constructions, vague quality claims, throat-clearing and
  unsupported superlatives are gone.

Read it aloud once. Fix any sentence that needs a second reading.

_Completion criterion:_ every check passes and no unresolved detail is hidden.

## 6. Deliver copy and audit

Return, in this order:

1. one copy-paste-ready update block with no inline citations;
2. `Grounding audit`, below the block, as `claim -> source` entries;
3. `Placeholders`, listing every unresolved marker and the evidence needed, or
   `Placeholders: none`.

The audit is part of the delivered artifact, but never part of the message the
reader receives.

_Completion criterion:_ every factual sentence in the copy-paste block can be
traced through the audit, and the block can be copied without removing audit
markup or internal notes.

## 7. Learn from what was sent

When the sent version becomes available, diff it against the draft. Append only
reusable corrections as dated rules using
[`references/LEARNINGS.md`](references/LEARNINGS.md); do not encode one-off facts
or preferences inferred from silence.

_Completion criterion:_ each meaningful sent-versus-draft change is either
captured as a dated reusable rule or explicitly classified as case-specific.
