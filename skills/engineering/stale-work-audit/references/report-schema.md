# Report Schema

The JSON report is the stable surface for evals and future viewers.

## Shape

```json
{
  "schemaVersion": 1,
  "generatedAt": "2026-06-20T00:00:00.000Z",
  "profile": {
    "projectName": "example"
  },
  "summary": {
    "headline": "Concise status sentence",
    "counts": {
      "Done": 0,
      "Done, deploy unverified": 0,
      "Needs port": 0,
      "Superseded": 0,
      "Active": 0,
      "Blocked": 0,
      "Wrong repo / deprecated source": 0,
      "Unknown": 0
    }
  },
  "groups": [
    {
      "status": "Unknown",
      "items": []
    }
  ],
  "graph": {
    "nodes": [],
    "edges": [],
    "claims": []
  },
  "unknowns": [],
  "decisions": [],
  "links": []
}
```

## Item Shape

```json
{
  "id": "item-1",
  "title": "Work item",
  "status": "Unknown",
  "confidence": "low",
  "reason": "Why this status was chosen.",
  "prs": [],
  "strongestEvidence": [],
  "nextAction": "What the user should decide or do next."
}
```

## Viewer Compatibility

Treat `graph.nodes` and `graph.edges` as the portable audit substrate. A future beads/viewer-style UI should be able to consume this graph without re-running the audit.
