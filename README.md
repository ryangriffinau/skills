# skills

Ryan Griffin's agent skills for Claude Code and Codex — the canonical home for the skills I've authored. Other repos (`ai-config`, project templates) install **from here**, so this repo is the source of truth, not a mirror.

Only skills I wrote live here. Skills I use but didn't author (Anthropic's, Matt Pocock's, marketing packs, etc.) are installed separately and intentionally excluded.

## Install

Install the whole collection with the [`skills`](https://github.com/mattpocock/skills) CLI:

```bash
npx skills@latest add ryangriffinau/skills                       # all skills
npx skills@latest add ryangriffinau/skills --skill review-council  # just one
```

GitHub is the registry — there's no publish step. The CLI clones this repo, installs each skill into your universal skills directory (`~/.agents/skills`), auto-symlinks agent dirs like `~/.claude/skills`, and records the install in its lockfile (source + version).

### Multiple tools — the CLI handles it, no manual symlinks

You don't symlink anything by hand. `skills add` installs each skill as a **real directory** in the universal skills dir (`~/.agents/skills`), which Codex, Cursor, Warp, and most agents read directly, and **auto-symlinks** agent-specific dirs (e.g. `~/.claude/skills`) back to it. To cover more agents, re-run `skills add` and select them (or pass `-a`), or run `npx skills experimental_sync`. One `npx skills update` then keeps every tool current.

## Updating

Installed skills are pinned vendored copies — nothing auto-updates when this repo changes. Pull updates with the CLI, and run it regularly:

```bash
npx skills check            # show which installed skills are behind
npx skills update           # update all of them
npx skills update <skill>   # update just one
```

`skills update` re-pulls from this repo and rewrites the matching `skills-lock.json` entries. Treat these exactly like any other CLI-installed skill: add with `skills add`, keep current with `skills update`.

## Maturity

Each skill declares a `status` in its `SKILL.md` frontmatter. A skill only earns **battle-tested** when it clears the structural bar *and* has survived real-world use — see [CONVENTIONS.md](CONVENTIONS.md).

| Badge | Status | Meaning |
|---|---|---|
| 🟢 | `battle-tested` | Layered structure + real-world use; relied on in production work |
| 🟡 | `refining` | Solid and in active use, still being sharpened |
| ⚪ | `drafting` | Early; works for me but unproven and may reference my personal setup |

## Skills

| Skill | Status | Ver | Tags | Purpose |
|---|---|---|---|---|
| [project-vision](skills/planning/project-vision) | 🟢 | 1.1.0 | planning, vision | Create/apply/check a compact root `VISION.md` as a durable decision lens |
| [review-council](skills/decision/review-council) | 🟡 | 0.9.0 | decision-making, multi-agent | 5-advisor council + anonymized peer review + chairman verdict + decision ledger |
| [website-porter](skills/web/website-porter) | 🟡 | 0.9.0 | web, migration, seo | Port a live / Webflow / CMS site into a repo, preserving SEO, fidelity, and cutover safety |
| [goal-plan](skills/planning/goal-plan) | ⚪ | 0.3.0 | planning, goals | Turn a fuzzy ambition into a verifiable goal + execution plan for long-running agent work |
| [pr-closeout](skills/engineering/pr-closeout) | ⚪ | 0.3.0 | git, github | Audit open PRs against sessions / worktrees / trackers and recommend a closeout for each |
| [stale-work-audit](skills/engineering/stale-work-audit) | ⚪ | 0.1.0 | engineering, git, audit | Audit old sessions / threads / repos against current evidence without closing anything |
| [commit](skills/git/commit) | ⚪ | 0.3.0 | git | Conventional commits scoped to current-session work only |
| [commit-whole-diff](skills/git/commit-whole-diff) | ⚪ | 0.3.0 | git | Split the entire working-tree diff into atomic conventional commits |
| [add-prompt](skills/meta/add-prompt) | ⚪ | 0.3.2 | meta, prompts | Create `/p-*` slash-command prompts bridged to Claude Code + Codex |
| [flywheel-local-launcher](skills/engineering/flywheel-local-launcher) | ⚪ | 0.1.0 | agents, flywheel, setup | Preflight the Agent Flywheel stack, link a repo into NTM's `projects_base`, and run per-repo init |

> Drafting skills (`commit`, `pr-closeout`, `goal-plan`, `stale-work-audit`, `add-prompt`, `flywheel-local-launcher`) are still being generalized or battle-tested. Skills with repo-specific behavior should keep it behind a local init/profile rather than hard-code one project workflow.

## Prompts

Slash-command prompts live separately from skills (following Jeffrey Emanuel's split between skills and prompts). Drop them in your prompts directory; they're invoked as `/p-<name>`.

Prompts marked with `†` are attributed to Jeffrey Emanuel's [Jeffrey's Prompts](https://jeffreysprompts.com/).

| Prompt | Status | Purpose |
|---|---|---|
| [p-smart-accretive-improvement](prompts/p-smart-accretive-improvement.md) | 🟢 | The single smartest, most accretive next addition to a plan or project |
| [p-pre-mortem](prompts/p-pre-mortem.md) | 🟢 | Assume it failed — work backwards to the causes |
| [p-unsummarizable](prompts/p-unsummarizable.md) | 🟢 | Strip writing until no word can be cut without losing an idea |
| [p-draft-plan](prompts/p-draft-plan.md) † | 🟡 | Draft one extremely detailed implementation plan, to fan out across competing models |
| [p-synthesize-plans](prompts/p-synthesize-plans.md) † | 🟢 | Compare competing plans and synthesize a stronger hybrid plan |
| [p-plan-to-beads](prompts/p-plan-to-beads.md) † | 🟡 | Decompose a finalized plan into a granular Beads graph via the `br` CLI |
| [p-reality-check](prompts/p-reality-check.md) † | 🟢 | Check whether a project actually has the intended outcome |
| [p-fresh-eyes-review](prompts/p-fresh-eyes-review.md) † | 🟢 | Re-read recent code changes with fresh eyes and fix obvious issues |
| [p-agent-swarm-launcher](prompts/p-agent-swarm-launcher.md) † | 🟢 | Launch coordinated agent work from repo instructions |
| [p-idea-wizard](prompts/p-idea-wizard.md) † | 🟢 | Generate, evaluate, and implement top project improvement ideas |
| [p-premortem-planner](prompts/p-premortem-planner.md) † | 🟡 | Premortem a plan and revise it around failure modes |
| [p-deep-project-primer](prompts/p-deep-project-primer.md) | 🟡 | Read project instructions and understand architecture |
| [p-deploy-and-verify](prompts/p-deploy-and-verify.md) | 🟡 | Deploy an app and verify desktop and mobile behavior |
| [p-copy-deslopifier](prompts/p-copy-deslopifier.md) | 🟡 | Brand/voice-neutral cleanup of AI-sounding copy, narrower than `copy-editing` |

## Credits

`review-council` is based on Andrej Karpathy's LLM Council idea; the implementation, peer-review flow, and decision ledger are mine. The `†` prompts are attributed to Jeffrey Emanuel's [Jeffrey's Prompts](https://jeffreysprompts.com/). Everything else is original.

## License

[MIT](LICENSE) © Ryan Griffin
