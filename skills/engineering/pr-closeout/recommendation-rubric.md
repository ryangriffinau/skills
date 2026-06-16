# PR Closeout Recommendation Rubric

Use this reference to make recommendations that are useful before the user has manually classified each PR.

## Evidence Strength

High confidence:

- PR head branch exactly matches a local worktree or task branch.
- PR changed files include a task JSON or progress doc that names the workstream.
- Active thread title/preview mentions the same problem and branch/task evidence agrees.
- PR body references merged predecessor PRs, CI, or closeout status.

Medium confidence:

- Title and changed files match a recent session, but branch/task evidence is indirect.
- PR is clearly part of a known stack but the owning session is not visible.
- A docs/workflow PR has a small exact diff that can be checked on each target base.

Low confidence:

- Only title keywords match.
- The PR is old and has no local task, but may represent parked strategic work.
- Author is another person/account and current ownership is unclear.

## Recommendation Rules

### `leave-open`

Recommend when:

- The PR maps to current active work.
- The user explicitly says it is in progress or protected.
- The PR is intentionally parked and still useful.
- The PR is a draft with recent updates and visible task/session evidence.

### `close-unmerged`

Recommend when:

- User says it is redundant or obsolete.
- It is an old planning artifact and later durable docs supersede it.
- It has no active session, no current task, and no clear owner.
- It is a stale branch with changes already landed elsewhere.

Before closing a docs/workflow PR, verify whether the “essence” exists on the intended target branch. Use exact phrase/identifier checks, not vibe matching.

### `merge-to-base`

Recommend when:

- PR is small, mergeable, and directly relevant.
- Changed files are documentation/task tracking or low-risk cleanup.
- The target base is correct.
- Any required CI/review status is acceptable for the repo’s policy.

Do not merge code-impacting PRs just because they are old and mergeable. Inspect changed files and checks.

### `port-to-other-base`

Recommend when:

- A change landed on `staging` but also needs `main`, or the reverse.
- A workflow/policy/docs change should apply globally.
- A cleanup PR is relevant only on a branch that contains the underlying work.

Create a separate PR for the port unless the repo’s workflow explicitly allows direct pushes.

### `rebase-or-recreate`

Recommend when:

- The PR is relevant but conflicted, noisy, or based on a stale branch.
- The diff contains broad unrelated changes but a small valuable part should survive.
- Base branch drift makes direct merge risky.

### `ask-owner`

Recommend when:

- Author is another owner and intent is unclear.
- The PR touches a product/business decision.
- The PR is old but plausibly parked for a reason.
- CI/review history suggests unresolved disagreement.

### `do-not-touch`

Use when the user explicitly protects a PR or workstream. Keep it out of close/merge action lists even if it looks stale.

## Accretive Checks

Look for chances to improve the repo state while closing PRs:

- If a PR is redundant because docs moved, link the newer doc/spec in the closeout note.
- If a workflow change is useful but not on all canonical bases, port it with a tracked PR.
- If a cleanup PR marks a task done, confirm the underlying work exists on that base before merging.
- If several PRs represent the same workstream, recommend consolidating around the newest/cleanest branch.
- If open PRs map poorly to sessions, recommend renaming sessions or adding PR URLs to task JSON/progress docs.

## Mutation Audit Log

For every action taken, record:

- PR number and URL
- Exact action: closed, merged, created PR, converted draft, retargeted
- Target branch if relevant
- Merge SHA or close state
- Short reason based on evidence

Never claim a PR was handled until metadata has been re-read after the action.
