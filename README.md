# skills

Ryan Griffin's agent skills for Claude Code and Codex — the canonical home for the skills I've authored. Other repos (`ai-config`, project templates) install **from here**, so this repo is the source of truth, not a mirror.

Only skills I wrote live here. Skills I use but didn't author (Anthropic's, Matt Pocock's, marketing packs, etc.) are installed separately and intentionally excluded.

## Install

Install with the [`skills`](https://github.com/vercel-labs/skills) CLI. Choose scope and agents explicitly:

```bash
# All published skills, available across projects in Codex and Claude Code
npx skills@1.7.1 add ryangriffinau/skills --global --agent codex claude-code --skill '*' --yes

# One skill
npx skills@1.7.1 add ryangriffinau/skills --global --agent codex claude-code --skill review-council --yes
```

Version 1.7.1 requires Node >=22.20.0. This version was checked during the October 2026 discovery audit. Check a newer CLI's help before adopting changed commands.

GitHub is the source. Only committed, pushed content is available through the remote install. Without `--global`, installation is project-scoped. Global installs use `~/.agents/skills` with agent links, and provenance is recorded in `~/.agents/.skill-lock.json`; project installs use `skills-lock.json`.

### Multiple tools — the CLI handles it, no manual symlinks

For the global commands above, the CLI installs skill directories and creates the required agent links. To cover more agents, re-run `add` with explicit `--agent` targets. `experimental_sync` imports skills from `node_modules`; it is not a general repair command for global installations. Plain files under `prompts/` are not installed by `skills add`.

## Updating

Installed skills are vendored copies; editing this checkout does not update them. Inspect local edits before updating, including supporting files under `references/` and `scripts/`:

```bash
npx skills@1.7.1 list --global
npx skills@1.7.1 update review-council --global
```

In 1.7.1, `check` is an alias for `update`, **not a read-only check**. An unqualified global update can update skills from other sources too. Prefer named updates for this collection. Preserve local changes before replacement; a matching `SKILL.md` alone does not prove the complete installation matches the source.

See the [discovery audit and migration plan](docs/specs/skills-distribution/PLAN.md) for the verified local state, immediate flywheel fix, and planned unified installer.

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
| [review-council](skills/decision/review-council) | 🟡 | 0.9.0 | decision-making, multi-agent | 5-advisor council + anonymized peer review + chairman verdict + decision ledger |
| [website-porter](skills/web/website-porter) | 🟡 | 0.9.0 | web, migration, seo | Port a live / Webflow / CMS site into a repo, preserving SEO, fidelity, and cutover safety |
| [joint-design-review](skills/web/joint-design-review) | ⚪ | 0.2.0 | design, frontend, audit, ux, beads | Per-area design review: audit → standing-approved vs ruling-required triage → materialise findings into issues → implement with screenshot evidence |
| [write-project-update](skills/comms/write-project-update) | 🟡 | 0.10.1 | communication, reporting, changelog | Evidence-grounded customer, public-changelog, or internal project update with asks, source audit, and channel-native formatting |
| [write-goal](skills/planning/write-goal) | ⚪ | 0.4.0 | planning, goals | Turn a fuzzy ambition into a verifiable goal + execution plan for long-running agent work |
| [codebase-benchmark](skills/engineering/codebase-benchmark) | ⚪ | 0.2.0 | engineering, audit, quality | Repeatable whole-codebase scorecard with evidence and trends across reviews |
| [stale-work-audit](skills/engineering/stale-work-audit) | ⚪ | 0.1.0 | engineering, git, audit | Audit old sessions / threads / repos against current evidence without closing anything |
| [commit](skills/git/commit) | ⚪ | 0.3.0 | git | Conventional commits scoped to current-session work only |
| [commit-whole-diff](skills/git/commit-whole-diff) | ⚪ | 0.3.0 | git | Split the entire working-tree diff into atomic conventional commits |
| [add-prompt](skills/meta/add-prompt) | ⚪ | 0.6.0 | meta, prompts | Save portable `p-*` skills with verbatim bodies and verify publication and installation |
| [teach-me-nugget](skills/meta/teach-me-nugget) | ⚪ | 0.1.0 | learning, mentoring | Explain a concept from current work with concrete examples and usable heuristics |
| [convex-prod-query](skills/engineering/convex-prod-query) | ⚪ | 0.3.0 | convex, production, verification, dcg | Read prod Convex state with a query-only tool + installer that also ships the dcg pack it pairs with |

> Drafting skills are still being generalized or battle-tested. Keep repo-specific behavior behind a local init/profile.

> See the [retirement and rename index](deprecated/README.md). Archived entrypoints use `RETIRED.md` to keep them out of recursive discovery. Existing copies need an ownership-checked migration. Use [`p-flywheel-conductor-jsm`](prompts/p-flywheel-conductor-jsm.md) with installed jsm skills for the flywheel.

## Prompts

The current checkout stores older `p-*` prompts as plain Markdown files. This is a legacy packaging split, not a different kind of workflow. New `p-*` workflows are standard `SKILL.md` packages under `skills/`; the planned migration will move the older files there while keeping the `p-` names.

Claude Code accepts `/p-<name>` from its commands directory. Codex CLI uses `$<skill-name>` or `/skills`; the desktop app uses its `@` skill picker. The legacy `/prompts:<name>` syntax is not supported by the audited Codex CLI 0.159.3. See [OpenAI's skill docs](https://learn.chatgpt.com/docs/build-skills) and the [version-specific audit](docs/specs/skills-distribution/PLAN.md).

On Ryan's audited machine, a native compatibility copy exposes `$p-flywheel-conductor-jsm` in Codex and `@p-flywheel-conductor-jsm` in the desktop skill catalog. It contains the complete prompt and was updated with the source on October 14. It is not yet part of remote `npx skills` installs. Open a new chat if the desktop picker has a stale catalog. The planned migration removes this extra copy.

Prompts marked with `†` are attributed to Jeffrey Emanuel's [Jeffrey's Prompts](https://jeffreysprompts.com/).

| Prompt | Status | Purpose |
|---|---|---|
| [p-smart-accretive-improvement](prompts/p-smart-accretive-improvement.md) | 🟢 | The single smartest, most accretive next addition to a plan or project |
| [p-premortem-general](prompts/p-premortem-general.md) | 🟢 | Assume it failed — work backwards to the causes |
| [p-unsummarizable](prompts/p-unsummarizable.md) | 🟢 | Strip writing until no word can be cut without losing an idea |
| [p-draft-plan](prompts/p-draft-plan.md) † | 🟡 | Fallback planning when jsm skills are unavailable; otherwise use `planning-workflow` |
| [p-planning-workflow-with-handoff](prompts/p-planning-workflow-with-handoff.md) | 🟡 | Draft a comprehensive plan and a context-complete prompt for an independent model |
| [p-synthesize-plans](prompts/p-synthesize-plans.md) † | 🟢 | Fallback plan synthesis when jsm skills are unavailable; otherwise use `planning-workflow` |
| [p-reality-check](prompts/p-reality-check.md) † | 🟢 | Fallback project assessment when jsm skills are unavailable; otherwise use `planning-workflow` |
| [p-close-the-gaps](prompts/p-close-the-gaps.md) | 🟡 | After a reality check, close the biggest bang-for-the-buck gaps yourself with real agency and no ceremony |
| [p-fresh-eyes-review](prompts/p-fresh-eyes-review.md) † | 🟢 | Re-read recent code changes with fresh eyes and fix obvious issues |
| [p-idea-wizard](prompts/p-idea-wizard.md) † | 🟢 | Generate, evaluate, and implement top project improvement ideas |
| [p-premortem-spec](prompts/p-premortem-spec.md) † | 🟡 | Premortem a plan and revise it around failure modes |
| [p-deep-project-primer](prompts/p-deep-project-primer.md) | 🟡 | Read project instructions and understand architecture |
| [p-deploy-and-verify](prompts/p-deploy-and-verify.md) | 🟡 | Deploy an app and verify desktop and mobile behavior |
| [p-copy-deslopifier](prompts/p-copy-deslopifier.md) | 🟡 | Brand/voice-neutral cleanup of AI-sounding copy, narrower than `copy-editing` |
| [p-flywheel-conductor-jsm](prompts/p-flywheel-conductor-jsm.md) | 🟢 | Prime a project and conduct an NTM swarm using jsm skills and the requested pane configuration |
| [p-tangible-progress](prompts/p-tangible-progress.md) | 🟢 | Bind a session or swarm to working-software-only progress — no process porn, honest credit |
| [p-hitl](prompts/p-hitl.md) | 🟡 | Force a complete, paste-ready hand-back of every decision, blocker, and action needing you |
| [p-handoff-context-maxxed](prompts/p-handoff-context-maxxed.md) | 🟡 | Produce the perfect next-session kickoff prompt so no thread or great idea is lost |
| [p-smarter-beads-wizard](skills/planning/p-smarter-beads-wizard) | 🟡 | Read every bead deeply, revise the beads with idea-wizard's smartest ideas, then offer polishing and a complementary round |

## Credits

This collection stands on others' work:

- **Vercel Labs** — the [`skills`](https://github.com/vercel-labs/skills) CLI used to install and update this collection.
- **Matt Pocock** — the craft of writing high-quality, single-purpose agent skills (his `writing-great-skills` is the reference). I install his skills (`grilling`, `tdd`, `writing-great-skills`, …) globally rather than vendor them into this repo.
- **Jeffrey Emanuel** — the [Agent Flywheel](https://github.com/Dicklesworthstone/agentic_coding_flywheel_setup) (NTM, Agent Mail, beads, DCG, UBS, CASS). The planning/execution loop and prompts marked `†` come from his flywheel / [Jeffrey's Prompts](https://jeffreysprompts.com/). My older conductor and launcher are archived; current flywheel workflows use his maintained jsm skills.
- **Andrej Karpathy** — `review-council` is based on his LLM Council idea; the peer-review flow and decision ledger are mine.

Everything not attributed above is original. Skills I use but didn't author (Anthropic's, Matt Pocock's, marketing packs) are installed separately and intentionally excluded from this repo.

## License

[MIT](LICENSE) © Ryan Griffin
