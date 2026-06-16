# Project Vision Reference

## Structure

Use this shape unless the repo has a stronger local convention:

- `# Vision`
- One sentence saying what the project is and what it optimizes for.
- One crisp paragraph explaining the stable decision lens.
- `Target User`
- `Durable Advantage`
- `Will Not Do`
- `Update Rules`

## Vision Init Grill

Ask one question at a time. Give a recommended answer with each question.

1. Purpose: What does this project do, for whom, in one sentence?
2. Target user: Who is the real human this should serve first?
3. Pain: What recurring problem should this remove or make dramatically easier?
4. Solution bet: What is the opinionated way this project solves it?
5. Durable advantage: What asset, workflow, taste, data, distribution, or constraint makes this hard to copy?
6. Anti-goals: What tempting work should this project explicitly refuse?
7. Contradiction test: What plausible future request should agents challenge because it conflicts with this vision?

Do not keep the grill transcript in `VISION.md`.

## Layering

- `VISION.md`: project direction, target user, durable advantage, anti-goals.
- `AGENTS.md`: durable agent rules and required read order.
- `docs/agents/**`: repo-specific agent configuration, including autonomy and sign-off boundaries.
- `docs/workflow/**`: workflow governance, task lifecycle, verification, handoff.
- `ROADMAP.md`: unshaped ideas and future possibilities.
- `docs/specs/**`: shaped workstream plans.
- `docs/adr/**`: durable decisions with real trade-offs.
- Workspace docs: current app/package/tooling behavior.

## Quality Checks

- The vision names a real human, not just an organization.
- The problem and solution bet are specific enough to reject adjacent work.
- Durable advantage is explicit.
- Anti-goals close off tempting branches.
- No agent autonomy gates live in `VISION.md`.
- Update rules say not to edit unless explicitly requested.
