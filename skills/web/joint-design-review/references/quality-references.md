# Quality references

A **quality reference** is an artefact the user has accepted as the bar for some work —
usually a screenshot of another product that already solves the problem. It is the
strongest evidence a review can bring when a finding contradicts a deliberate choice:
not "this is broken", but "this is possible, and here is a product doing it".

Users hand these over mid-review. The skill needs somewhere to put them, or the
reference dies in the chat log and the next agent re-litigates the same finding.

## Store it in the repo

`docs/design/references/<product>-<surface>.png` (or wherever the repo keeps design
docs), with a `README.md` in that folder holding one section per reference. Never leave
a reference as a chat attachment or an external link. It has to survive the session.

## Decompose it into techniques

**"Make it like Linear" is not actionable.** A stored image with no analysis produces
cargo-culting — the next agent copies the parts that were never the point.

Each reference section states:

- **Who accepted it, when, and against which findings.** A reference is evidence in a
  specific argument, not general inspiration.
- **The user's words, quoted.** Especially any condition attached.
- **The separable techniques it demonstrates**, numbered. Not "it looks clean" —
  "grouping carries status, so status needs no column"; "glyphs carry two signals in
  40px"; "filters are a horizontal row with no labels".
- **A mapping table** from the current implementation to the technique that replaces it.
- **What not to copy.** Every reference contains things specific to that product. Name
  them, or they get ported too.

## Conditional bars

A reference often arrives with a condition: *address it only if we reach this quality,
otherwise leave it alone.* Record that literally, in the reference and on the finding.

A conditional bar changes what "done" means. The work is authorised **only** if it
reaches the reference. A half-measure is explicitly worse than no change, because it
spends the budget and leaves the surface neither as designed nor as referenced.

## When a reference retires a recommendation

The user may accept the reference and reject the finding's proposed fix, or accept part
of a reference and defer the rest. Record the surviving part and mark the deferred part
as a later feature on its own row — do not smuggle it into the authorised work.
