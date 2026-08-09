# The audit tracker

`findings.jsonl`, beside the report, **is the audit's tracker** for the whole review. It
is not a staging note that gets retyped into the real tracker later. It is the thing the
review is managed from, and `scripts/findings.mjs` reads and writes it.

## Why not just file issues as you find them

Two reasons. The second is the load-bearing one.

1. A shared tracker file is usually being written by other agents; writing races them.
2. **A finding filed as a ready issue gets claimed and built.** Swarms pull ready work
   automatically. File before the Class B rulings land and you have handed unreviewed
   audit output to agents that will implement it — including the findings the user was
   about to reject or reframe.

## Why not a second tracker workspace

Tried and abandoned, not assumed. `br init --db <path>` inside a repo that already has
`.beads/` fails with `Already initialized at './.beads/beads.db'`. The only override is
`--force`, which can target the **discovered** database — the live one the swarm is
using. There is no environment override; `br` is one-workspace-per-repo by design.

A plain JSONL file in the audit directory is invisible to `br`, to `bv`, and to every
pane. That is the isolation. Do not go looking for a cleverer one.

## Row schema

One row per finding or decision. Required: `id`, `class`, `dimension`, `file`,
`summary`. Everything else earns its place.

```json
{
  "id": "F1",
  "rank": 1,
  "class": "A",
  "classLabel": "functional-defect",
  "dimension": "react-data",
  "file": "src/routes/quality/-worklist.tsx",
  "line": 421,
  "summary": "One sentence stating the defect as a claim.",
  "reference": "docs/design/references/linear-mobile-issue-list.png",
  "ruling": "Verbatim, with who ruled and when.",
  "correction": "What the review got wrong, if the user reframed it.",
  "dependsOn": "B1",
  "status": "ruled",
  "bead": null
}
```

Field notes:

- `class` is `A` or `B`. Class A rows carry a `rank`; Class B rows carry a `ruling`
  before anything can be materialised.
- `classLabel` is the Class A/B row name from `SKILL.md` (`accessibility-defect`,
  `over-explanation`, …). It becomes a label on the created issue.
- `dependsOn` points at another row's `id`, or at an external tracker id when the work
  waits on something outside this review.
- `ruling` is **verbatim**. Paraphrasing a ruling loses the condition attached to it.
- `correction` records where the review's own framing was wrong. Keep it. A reviewer who
  hides corrections is not one whose findings you can trust.
- `bead` stays `null` until materialisation writes the id back. The review is complete
  when no row has a null `bead`.

## Commands

```bash
node scripts/findings.mjs validate <file>    # schema, duplicate ids, unresolved deps,
                                             # unranked Class A, unruled Class B
node scripts/findings.mjs summary  <file>    # ranked list + what still needs a ruling
node scripts/findings.mjs materialise <file> --epic "<title>"           # dry run: prints commands
node scripts/findings.mjs materialise <file> --epic "<title>" --apply   # executes, writes ids back
```

`materialise` refuses while any Class B row is unruled. That refusal is the point: it
makes "the user has not decided yet" a mechanical stop rather than something to
remember.

Each created issue carries the summary, the location, any reference and ruling, and a
falsifying acceptance criterion — a behavioural assertion that fails before the fix plus
a re-capture of the surface. "It compiles" is not acceptance for a design finding.

After `--apply`, flush and commit the tracker alongside the report.
