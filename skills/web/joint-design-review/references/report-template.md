# Joint design review — report template

Copy this structure. Replace every bracketed placeholder. Delete sections that are
genuinely empty rather than leaving stubs — but "Checked and cleared" is never deleted;
an empty one means the audit was hits-only and is not done.

---

```markdown
# Design review: [area] — [YYYY-MM-DD]

One-line statement of scope: which product area, which surfaces, and which this review
deliberately excludes.

## Tree state and scope

- Audited at commit `[SHA]`.
- Dirty files in the area at audit time: [list, or "none"].
- Data path checked by `contention.mjs`: [clean / contended — which packages].
- Findings crossing dirty files are marked **provisional** and need a recheck before
  they become work.
- Prior audits and rulings covering this area: [links]. Rechecked findings from them:
  [finding → current state: fixed / still open / regressed / ruled-and-deferred].

## Deliberate choices

What this area does on purpose, so a finding does not mistake a decision for a defect.
Say where each was confirmed — a prior spec, a code comment, or the user.

| Behaviour | Deliberate? | Source |
| --- | --- | --- |
| [e.g. mobile list shows title only] | yes | [spec link / user, date] |

An empty table means you did not ask. Ask.

## Findings at a glance

Ranked by whether a real user can hit it and the cost of the mistake — not by ease of
fix.

| Rank | Class | Before | After | Why |
| --- | --- | --- | --- | --- |
| 1 | A/B | [current behaviour/code] | [target behaviour/code] | [one-line reason] |

## Findings

One section per finding, in rank order.

### [N]. [Title — the defect, stated as a claim]

**Class:** A ([class name]) or B ([class name]) · **Dimension:** [flow / heuristics /
a11y / design-system / motion / reinvention / react-data / copy / consistency] ·
**Heuristic:** [# and name, when a Nielsen heuristic applies]

**Location:** `path/to/file.tsx:123`

**Evidence:** [screenshot path(s); code excerpt if the defect is in behaviour]

[Two to five sentences: what is wrong, how a user reaches it, what happens when they
do.]

**Replacement:**

```tsx
[concrete before → after, minimal]
```

**Blast radius:** [which surfaces and which user actions this touches — the reader
must be able to judge severity without opening the code]

**Provisional:** [only if it crosses a dirty file — say which, and what must be
rechecked]

## Class B decisions for ruling

Numbered so rulings can reference them. One decision per line item; recommendation
first.

1. **[Decision title]** — Recommend: [option]. Trade-off: [one sentence].
   Bead: [id, blocked].

## Checked and cleared

A hit-only audit is not trustworthy. Suspects traced and found fine:

| Suspect | Dimension | Verdict |
| --- | --- | --- |
| [what looked wrong] | [dimension] | **Cleared.** [why it is actually fine] |

## Coverage

- Static scan: [run at SHA — N candidates, M verified into findings, K cleared;
  or "clean"]. A missing scan row means the audit is incomplete.
- Surfaces audited: [list — list, detail, create/edit, empty, loading, error,
  permission-denied]
- Surfaces not reached and why: [list, or "none"]
- Dimensions covered: [enumerate all nine, each with the finding numbers or "clear"]
- Modalities: desktop [done/partial], mobile [done/partial]

## Screenshot index

| Surface | Width | Theme | File |
| --- | --- | --- | --- |
| [surface] | desktop/mobile | light/dark | [path] |

Dark-mode rows appear only where the policy requires them (theme finding, or a colour
token / shared component colour change — one representative surface then suffices).

## Beads

| Finding | Bead | Class | Status |
| --- | --- | --- | --- |
| 1 | [id] | A | open |
| 2 | [id] | B | blocked — decision 1 |

Epic: [id]. This table mirrors `findings.jsonl` beside the report; that file is the
machine-readable contract, and the review is not done until every row in it carries a
non-null `bead` id.
```
