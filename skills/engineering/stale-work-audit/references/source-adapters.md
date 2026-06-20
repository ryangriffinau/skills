# Source Adapters

Every adapter returns graph records, not final prose.

## Adapter Output

```json
{
  "nodes": [],
  "edges": [],
  "claims": [],
  "links": []
}
```

`nodes` are things: work item, repo, branch, PR, commit, doc, issue, deployment, external thread.

`edges` connect things: mentions, implements, merged-into, supersedes, blocks, deployed-by, belongs-to, deprecated-by.

`claims` are evidence statements with:

- `id`
- `kind`
- `summary`
- `source`
- `strength`
- `confidence`
- `links`

## Built-In Adapter Types

Git:
- current branch
- remotes
- dirty state
- branches containing candidate commits
- merge-base checks when enough refs exist

Docs:
- `AGENTS.md`, `CLAUDE.md`, `README.md`, docs index files
- configured docs/context globs
- keyword matches from thread text

GitHub PRs:
- exact PR URLs and numbers from thread text
- branch and commit matches
- keyword search for equivalent or superseding PRs
- merged/closed/open state

Issue/task trackers:
- GitHub issues
- Linear
- local files from configured patterns
- freeform source notes in profile

Deployments:
- configured provider only
- branch, commit, and URL matches
- unavailable deployment source becomes an unknown, not a failure

External threads:
- Agent Mail
- Slack, lightweight and bounded
- GitHub review threads
- Vercel toolbar threads
- pasted Codex/session text

## Unavailable Sources

If a configured adapter cannot run because a CLI, token, connector, or network path is unavailable, emit a skipped-source claim. Do not fail the whole audit unless the user explicitly requested that source as mandatory.
