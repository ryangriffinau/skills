# Gathering evidence

Adapt these source adapters to the project. The invariant is a claim ledger with
a fixed scope and exact sources, not a particular command.

## Establish the window

Record inclusive start and end dates, or a release identifier and commit
boundary, plus the relevant environment or branch. A result from the wrong scope
or environment is worse than no number.

## Shipped and deferred work

Read commits, merged changes and the project tracker. Use counts only to locate
themes; process totals rarely belong in the update.

```bash
git log --since="YYYY-MM-DD" --until="YYYY-MM-DD 23:59:59" \
  --date=short --pretty='%ad %h %s'
br list --status closed --json
br list --status deferred --json
```

Confirm “shipped” against a release, deployment or production artifact when the
repo distinguishes merged from live.

## Human and billing gate sweep

Search beyond the work item that prompted the update. Inspect open and blocked
items, deployment/provider status, access notes and recent handoff documents for:

- billing, credits, cards, plans and quotas;
- approvals, decisions and sign-off;
- invitations, permissions, credentials and account ownership;
- migrations or configuration changes assigned to the reader.

For every open gate, capture the exact action, owner, reason, deep link, cost or
cap context, likely friction and source. Classify apparent gates that are already
resolved so they do not leak into the asks block.

## Accuracy and evaluation claims

Prefer a committed artifact over a remembered result. Record corpus identity,
sample size, model or version, acceptance threshold and run output. Read the
metrics object, not only its summary.

```bash
find . -path ./node_modules -prune -o \
  \( -iname '*golden*' -o -iname '*eval*' -o -iname '*benchmark*' \) \
  -type f -print
```

## Production and customer data

Use a read-only production query or run artifact. Record environment and
deployment identity beside the figure. Never estimate when an exact result is
available, and never expose private data in public-changelog mode.

## Risks, degradations and capability state

Read incident notes, known issues, rollout flags and current operational status.
Distinguish `starting`, `partial`, `ready` and `live`; do not upgrade the state in
the prose. Capture temporary disabled behavior even when it is inconvenient to
mention.

## Forward-looking work

Read the live roadmap or tracker, not session memory. Prefer committed or
in-flight work. Label planning-stage work honestly and apply the selected mode's
relevance filter.

```bash
br ready --json
```

## Claim ledger

Use one row per externally checkable claim:

```markdown
| Claim | Source | State | Mode-safe? |
| --- | --- | --- | --- |
| <exact claim> | <path, command output, item, or URL> | grounded | yes |
| [PLACEHOLDER: sample size] | <evidence needed> | unresolved | no |
```

The delivered grounding audit is the ledger reduced to `claim -> source`. Keep
unresolved rows in the placeholders list; never silently drop or smooth them.
