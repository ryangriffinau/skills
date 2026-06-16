# Project Vision Workflow

## Init

1. Read existing context before asking questions:
   - `README.md`
   - `AGENTS.md`
   - `ROADMAP.md`
   - `docs/README.md`
   - relevant `docs/context/**`
   - existing `VISION.md`, if present
2. Ask only unresolved grill questions from [REFERENCE.md](REFERENCE.md).
3. Ask one question at a time and provide a recommended answer.
4. Stop once the answers close off obvious unintended branches; do not collapse to PRD/spec depth.
5. Create root `VISION.md` from the collapsed answers.
6. Wire `AGENTS.md` and the docs index so agents read `VISION.md` before substantial work.

## Apply

1. Read `VISION.md` before substantial planning, architecture, product, UX, or agent workflow work.
2. If requested work conflicts with `VISION.md`, raise the contradiction.
3. Do not edit `VISION.md` unless the user explicitly requests a vision update.

## Review

Check whether `VISION.md` is crisp, stable, and in the right layer. Move implementation detail to specs, ADRs, package docs, app docs, workflow docs, or roadmap items.

## Update

Only update `VISION.md` when the user explicitly requests a vision update. Preserve strong current principles, remove stale claims, and keep changes limited to long-lived direction.
