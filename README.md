# skills

Ryan Griffin's agent skills for Claude Code and Codex — the canonical home for the skills I've authored. Other repos (`ai-config`, project templates) install **from here**, so this repo is the source of truth, not a mirror.

Only skills I wrote live here. Skills I use but didn't author (Anthropic's, Matt Pocock's, marketing packs, etc.) are installed separately and intentionally excluded.

## Install

Install the whole collection with the [`skills`](https://github.com/mattpocock/skills) CLI:

```bash
npx skills@latest add ryangriffinau/skills
```

Or copy a single skill's directory into your `.claude/skills/` (or `.agents/skills/`).

### Multiple agents / tools: symlink (recommended)

If you run several agent tools (Claude Code, Codex, Cursor) or several repos, **clone once and symlink** the skills into each tool's skills directory rather than copying. One canonical source, edits propagate everywhere, no drift:

```bash
git clone https://github.com/ryangriffinau/skills ~/code/skills
# link individual skills into each tool's skills dir
ln -s ~/code/skills/skills/decision/review-council ~/.claude/skills/review-council
ln -s ~/code/skills/skills/decision/review-council ~/.codex/skills/review-council
```

A small bridge script (same idea as a `prompts-bridge`) can keep these links in sync across tools. Copying is fine for a one-off; symlink whenever multiple agents should share — and stay in sync with — a single source of truth.

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
| [project-vision](skills/planning/project-vision) | 🟢 | 1.0.0 | planning, vision | Create/apply a compact root `VISION.md` as a durable decision lens |
| [review-council](skills/decision/review-council) | 🟡 | 0.9.0 | decision-making, multi-agent | 5-advisor council + anonymized peer review + chairman verdict + decision ledger |
| [website-porter](skills/web/website-porter) | 🟡 | 0.9.0 | web, migration, seo | Port a live / Webflow / CMS site into a repo, preserving SEO, fidelity, and cutover safety |
| [goal-plan](skills/planning/goal-plan) | ⚪ | 0.3.0 | planning, goals | Turn a fuzzy ambition into a verifiable goal + execution plan for long-running agent work |
| [pr-closeout](skills/engineering/pr-closeout) | ⚪ | 0.3.0 | git, github | Audit open PRs against sessions / worktrees / trackers and recommend a closeout for each |
| [stale-work-audit](skills/engineering/stale-work-audit) | ⚪ | 0.1.0 | engineering, git, audit | Audit old sessions / threads / repos against current evidence without closing anything |
| [commit](skills/git/commit) | ⚪ | 0.3.0 | git | Conventional commits scoped to current-session work only |
| [commit-whole-diff](skills/git/commit-whole-diff) | ⚪ | 0.3.0 | git | Split the entire working-tree diff into atomic conventional commits |
| [add-prompt](skills/meta/add-prompt) | ⚪ | 0.3.0 | meta, prompts | Create `/p-*` slash-command prompts bridged to Claude Code + Codex |

> Drafting skills (`commit`, `pr-closeout`, `goal-plan`, `stale-work-audit`, `add-prompt`) are still being generalized or battle-tested. Skills with repo-specific behavior should keep it behind a local init/profile rather than hard-code one project workflow.

## Prompts

Slash-command prompts live separately from skills (following Jeffrey Emanuel's split between skills and prompts). Drop them in your prompts directory; they're invoked as `/p-<name>`.

| Prompt | Status | Purpose |
|---|---|---|
| [p-smart-accretive-improvement](prompts/p-smart-accretive-improvement.md) | 🟢 | The single smartest, most accretive next addition to a plan or project |
| [p-pre-mortem](prompts/p-pre-mortem.md) | 🟢 | Assume it failed — work backwards to the causes |
| [p-unsummarizable](prompts/p-unsummarizable.md) | 🟢 | Strip writing until no word can be cut without losing an idea |

## Credits

`review-council` is based on Andrej Karpathy's LLM Council idea; the implementation, peer-review flow, and decision ledger are mine. Everything else is original.

## License

[MIT](LICENSE) © Ryan Griffin
