# Conventions

How skills in this repo are structured, versioned, and graded.

## Layout

```
skills/<category>/<name>/SKILL.md   # required entrypoint
                        /references/ # optional deep docs
                        /scripts/    # optional tooling
                        /evals/      # optional regression cases
prompts/p-<name>.md                  # slash-command prompts (separate from skills)
```

Categories are organizational only (`decision`, `planning`, `engineering`, `git`, `web`, `meta`). Maturity is **not** a folder — promoting a skill is a one-line frontmatter edit, never a directory move.

## Frontmatter schema

Every `SKILL.md` carries:

```yaml
---
name: <kebab-case, matches directory>
status: battle-tested | refining | drafting
version: <semver>
tags: [<topic>, <topic>]
updated: <YYYY-MM-DD>
description: <when-to-use; the trigger text Claude/Codex matches on>
---
```

## Maturity tiers

Adapted from Jeffrey Emanuel's premium/community distinction: the top tier is defined **structurally and by use**, not by marketing.

- **`battle-tested`** — clears the structural bar *and* has been relied on in real work:
  - scannable `SKILL.md` + at least one of `references/`, `scripts/`, or `evals/`
  - exercised on real tasks, not just authored
  - no known correctness gaps
- **`refining`** — solid and in active use, structure mostly there, still being sharpened. May change.
- **`drafting`** — early. Works for the author but unproven, thin, or still referencing a personal setup. Expect breakage.

A skill graduates by meeting the bar above and bumping `status` + `version`.

## Versioning

Semver. `battle-tested` skills are `>= 1.0.0`. `refining` typically `0.9.x`. `drafting` `0.x`.

## Source of truth

This repo is canonical. Consuming repos install from it (e.g. `npx skills add ryangriffinau/skills`) and pin via their own lock file — they never hand-edit a vendored copy.
