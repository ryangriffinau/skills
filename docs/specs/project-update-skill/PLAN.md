---
title: "project-update skill — plan"
status: implemented as skills/comms/write-project-update (2026-08-03)
read_when:
  - building the project-update / stakeholder-update message skill
  - reviewing the legacy message-skill lessons that informed this plan
---

# project-update skill — plan

A skill that drafts a stakeholder-ready update — customer, public, or internal —
grounded in the project's own record (beads, commits, PRs, eval results, shipped
docs), in a plain results-first voice, run through a mandatory deslopify pass
before it is shown. Seeded by the Kingfield AI-Gateway-migration update
(2026-07-09), which exposed the failure modes this skill must prevent.

The implementation supersedes this planning record where they differ. In
particular, its mode names are `customer`, `public-changelog`, and `internal`, and
formatting follows the delivery channel.

## Why this skill exists

Ad-hoc update drafts drift into AI slop: platitudes, emphasis characters
everywhere, over-personalisation ("your"/"we"), rule-of-three triads, and
handwavy claims that removed the concrete result. They also silently drop the
things the reader must act on (e.g. "you need to upgrade — here is the billing
link"). The recurring fix is the same every time, so encode it.

## Lessons from the legacy message skill

Source reviewed during planning: an earlier project-specific message skill.

### Adopt
- **Logic / facts / voice separation.** SKILL.md holds process; `references/voice.md`
  holds how it sounds; facts come from a grounding source, never improvised.
- **Ground-then-deslopify as two mandatory gates.** Nothing is shown until every
  specific claim traces to a live source AND the deslopify checklist passes.
- **Mode-first.** Pick the mode before drafting; load only that mode's rails.
- **Channel-native output rules.** Teams, Slack and Notion retain useful Markdown
  emphasis; SMS and email-paste use plain text and simple lists.
- **Deslopify checklist inline** + delegate to `/p-copy-deslopifier`.
- **Learnings ledger** (lightweight): when the sent version differs from the
  draft, append a dated voice rule so the voice converges on what the human
  actually sends.

### Ignore / differ
- **CRM connector** — not our grounding source. We ground in the *project
  record*, not a deal record.
- **Sales modes** (intros, pitches, lost-deal) — out of scope; this is
  progress/outcome communication, not outbound sales.
- **R2 shared ledger + outcome resolver** — heavier than needed for v1. Start
  with a local `learnings.md` only; add a ledger if it earns its place.

### Improve on it
- **Grounding = project evidence, auto-cited.** The grounding step reads the
  actual record — `br`/beads (what shipped, what's deferred), `git log` / merged
  PRs, eval-result docs, spec/ADR files — and every claim in the draft must map
  to one. This is stronger than CRM notes: the update cites real artifacts
  (e.g. "prop_112 processed via `gateway/openai/gpt-5.4-mini`") rather than
  vibes. Ungrounded claims are cut or marked `[placeholder]`.
- **Client-vs-public is an explicit mode distinction**, not a tone knob. Ryan:
  "this feels like a public product changelog — not a release for a client. It's
  an important distinction." The two modes have different rules (below).
- **Mandatory "Asks / outstanding" section** with direct action links. The KF
  draft missed the reader's required action (top up Vercel credits) and its link
  — the skill forces an explicit asks block whenever the reader must do
  something.
- **Optional technical appendix.** Client updates lead with outcomes; a marked
  appendix at the end may carry domain/technical specifics for readers who want
  depth (KF example: the quality-finding primitives; the action / work-order /
  workflow-step distinction; the 107-example benchmark method). Never inline —
  appendix only, and only when it adds signal.

## Modes

- **customer** — a specific customer/stakeholder. Results-first, outcomes
  they care about, minimal jargon, one backend/plumbing line at most, explicit
  asks with links, optional technical appendix. (KF update = this mode.)
- **public-changelog** — broad product news. Feature-framed, no
  customer-specific asks, may keep more technical framing.
- **internal** — team/leadership. Denser, status + risk + next, may cite
  bead IDs and metrics directly.

If an update spans modes, lead with the one that owns the primary purpose.

## Voice rules (references/voice.md)

- Plain and declarative. State the outcome, not the feeling about the outcome.
  Ryan's rewrites are the calibration set:
  - "We've made the system materially more reliable, accurate, and future-ready"
    → "The quality issue capture system is now materially reliable, accurate and
    has more functionality."
  - "Accuracy is now measured, not assumed" → "AI benchmarking built in."
  - "Upgraded to a newer, more capable AI model" → "Model upgrade: GPT-4.1 →
    GPT-5.4 + AI Gateway."
- Use "you"/"we" sparingly — default to naming the thing, not the relationship.
- Use emphasis only where the delivery channel supports it. Avoid rule-of-three
  triads, platitudes ("future-ready", "seamless", "robust", "unlock") and
  throat-clearing.
- Hyphens over em-dashes. Short lines, phone-readable.
- Every claim concrete and grounded; if a number exists, use it.

## Workflow

1. **Pick mode and channel** (customer / public-changelog / internal).
2. **Load context — ground first.** Read the project record for the window: beads
   closed/deferred, merged PRs, eval-result docs, ADRs/specs. Build the claim
   list; each claim carries its source artifact. Cut anything ungrounded.
3. **Draft to outcomes** in the mode's shape and the shared voice. Lead with what
   changed for the reader; one plumbing line max for client mode.
4. **Asks / outstanding block** — if the reader must act, list each ask with a
   direct link and move the block ahead of the update. Mandatory when any action
   is outstanding.
5. **Optional appendix** — domain/technical depth, marked, at the end, only if it
   adds signal.
6. **Deslopify (mandatory).** Apply `/p-copy-deslopifier` + the inline checklist.
   Nothing is shown until it passes.
7. **Deliver** as one channel-native copy-paste block. Below it (never inline):
   the grounding audit (claim → source) and any `[placeholder]`.
8. **Learn.** Diff sent-vs-draft; append a dated rule to `learnings.md`.

## Deslopify checklist

Apply `/p-copy-deslopifier`. Cut: platitudes and "future-ready"-class filler;
gratuitous emphasis; rule-of-three triads; over-personalisation; hedging and
throat-clearing; redundancy; meta-commentary. Punctuation: hyphens over
em-dashes. Lead with the result or the ask.

## Layout (proposed)

- `skills/comms/write-project-update/SKILL.md` — shared ordered workflow.
- `references/{customer,public-changelog,internal}.md` — mode deltas.
- `references/EVIDENCE.md` — source adapters and claim ledger.
- `references/EXAMPLES.md` — calibration examples.
- `references/LEARNINGS.md` — portable format for project-local dated rules.

## First exemplar

The Kingfield AI-Gateway-migration customer update (2026-07-09) is the seed
exemplar: capture the slop-draft, Ryan's line edits, and the final grounded +
deslopified + appendix version. It is the calibration case the skill is tested
against.
