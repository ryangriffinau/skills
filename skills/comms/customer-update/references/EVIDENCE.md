# Gathering evidence

Commands for step 1. Adapt to the stack; the discipline is that every claim in
the update points back at one of these outputs.

## Shipped work

Fix the window as dates, then read what landed inside it.

```bash
git log --since="YYYY-MM-DD" --pretty='%s' | grep -E "^feat" | head -40
```

Group by area to find the themes rather than reading commit by commit:

```bash
git log --since="YYYY-MM-DD" --pretty='%s' \
  | grep -oE "^(feat|fix)\(([a-z-]+)\)" | sed 's/.*(//;s/)//' \
  | sort | uniq -c | sort -rn | head -15
```

Scope tags concentrate where the work went. A tag with 89 commits and one with 4
are not equally likely to have produced something the reader met.

Commit and closed-item totals belong in this step and stop here. They orient
_you_ toward the themes; they fail the step 3 number test for the artifact
itself.

## Accuracy and evaluation claims

Prefer a committed artifact over a remembered result. A good one records the
corpus identity and the model, so the claim survives a challenge:

```bash
find . -path ./node_modules -prune -o \
  \( -iname "*golden*" -o -iname "*eval*" \) -type f -print | head
```

Read the metrics object rather than a summary of it. Report the acceptance
threshold beside the score: a perfect result means little without the bar it
cleared, and a reader who sees only the score may reasonably ask about sample
size.

## Production and customer data

Figures about the reader's own data are the strongest numbers available, so take
them from a real run rather than an estimate. Read-only preview modes are the
safe source.

Record the deployment identity alongside the figure. A count from the wrong
environment is worse than no count.

## Forward-looking items

Take these from the tracker, filtered to what is genuinely queued, then apply the
visibility filter from step 2 exactly as you did for completed work.

```bash
br ready --json    # or the local equivalent
```

Planning-stage work is a weak commitment in a customer-facing document. Prefer an
item already in flight, and say so if the sender wants to signal something
earlier.
