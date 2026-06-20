# Stale Work Audit Profile

The profile is the local adapter config for one repo. Keep the global skill portable; put repo-specific workflow here.

Default path:

```text
.agents/stale-work-audit/profile.json
```

## Init Principles

- Inspect before asking.
- Record local choices as data, not prose hidden in chat.
- Prefer existing repo conventions from `AGENTS.md`, `CLAUDE.md`, `docs/`, ADRs, and issue tracker docs.
- Do not bake personal or company workflow into the skill.
- A future generic `setup-skills` skill may call this init. This skill owns only its own profile.

## Minimal Profile

```json
{
  "version": 1,
  "projectName": "example",
  "repos": {
    "canonical": [],
    "deprecated": []
  },
  "branches": {
    "primary": "main",
    "integration": null,
    "release": []
  },
  "docs": {
    "contextFiles": ["AGENTS.md", "CLAUDE.md", "README.md"],
    "patterns": ["docs/**"]
  },
  "pullRequests": {
    "sources": [
      { "type": "github", "repo": "owner/name", "enabled": true }
    ]
  },
  "issues": {
    "sources": [
      { "type": "github", "repo": "owner/name", "enabled": true },
      { "type": "linear", "team": "TEAM", "enabled": false },
      { "type": "local", "patterns": [".agents/issues/**"], "enabled": false }
    ]
  },
  "deployments": {
    "sources": []
  },
  "externalThreads": {
    "sources": [
      { "type": "agent-mail", "projectKey": "/abs/repo", "enabled": false },
      { "type": "slack", "channels": [], "maxResults": 5, "enabled": false },
      { "type": "github-review-threads", "enabled": true },
      { "type": "vercel-toolbar", "projectId": null, "teamId": null, "enabled": false }
    ]
  },
  "report": {
    "verbosity": "concise",
    "includeGraph": true,
    "includeUnknowns": true
  }
}
```

## Init Questions

Ask only for what discovery cannot infer:

1. Which repo(s) are authoritative for this project?
2. Are any sibling repos deprecated or read-only references?
3. What are the long-lived branch names?
4. Which PR source should be searched?
5. Which docs are the durable source of truth?
6. Which issue/task source should be used?
7. Which deployment source, if any, proves release state?
8. Which external thread sources should be tracked?

## Adapter Rules

Adapters are optional. Disabled or unavailable adapters must produce a skipped-source claim, not a failure.

Use source strength in this order by default:

1. Canonical repo code and Git history
2. Merged PRs and equivalent/superseding PRs
3. Durable docs and repo instruction files
4. Deployment records
5. Issue/task trackers
6. External threads
7. Pasted session/thread text
