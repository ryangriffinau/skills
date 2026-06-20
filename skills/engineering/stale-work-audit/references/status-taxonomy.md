# Status Taxonomy

Use one concise status per audited item.

## Statuses

`Done`
: The canonical repo contains the work, and PR/Git/doc evidence supports completion.

`Done, deploy unverified`
: Code appears complete, but deployment/release evidence is missing or unavailable.

`Needs port`
: Work exists in a non-authoritative repo, branch, PR, or thread, but not in the canonical repo.

`Superseded`
: A newer PR, branch, commit, issue, or design replaces the older work.

`Active`
: There is recent live work: open PR, active branch, current task, unresolved review thread, or recent owner signal.

`Blocked`
: The next step is a user/product/owner decision, credential, access, or external dependency.

`Wrong repo / deprecated source`
: The audit target is not authoritative for this work.

`Unknown`
: Evidence is too weak, unavailable, contradictory, or missing.

## Confidence

Use `high`, `medium`, or `low`.

High:
- canonical repo evidence and PR/Git evidence agree
- merged PR contains the relevant files or commits
- docs and code point to the same result

Medium:
- one strong source exists, but deployment/docs/PR context is missing
- equivalent PR evidence is plausible but not exact

Low:
- only thread text, title matching, stale docs, or weak keyword matches exist
- tool access failed for a source that would likely decide the status

## PR Evidence

Always surface PRs when found:

- direct PR: exact branch, commit, URL, or PR number match
- equivalent PR: same workstream, files, or title keywords on a different branch/repo
- superseding PR: newer PR that closes, replaces, or materially overlaps the work

Equivalent PRs can move an item from `Unknown` to `Superseded`, `Done`, or `Needs port`, but only with explicit confidence.
