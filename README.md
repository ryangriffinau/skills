# skills

Ryan Griffin's agent skills for Codex, Claude Code, and Antigravity CLI (`agy`). This repository contains the canonical source for the skills I authored. Other repositories install this collection from here.

Third-party collections, including jsm and Matt Pocock's skills, are installed separately.

## Install

Install with the [`skills`](https://github.com/vercel-labs/skills) CLI. Choose scope and providers explicitly:

```bash
# All published skills, available across projects in all three providers
npx skills@1.7.1 add ryangriffinau/skills --global --agent codex claude-code antigravity-cli --skill '*' --yes

# One skill
npx skills@1.7.1 add ryangriffinau/skills --global --agent codex claude-code antigravity-cli --skill review-council --yes
```

CLI 1.7.1 requires Node >=22.20.0. If the system Node is older, use an isolated supported runtime:

```bash
npx --yes --package=node@22.20.0 --package=skills@1.7.1 -- skills add ryangriffinau/skills --global --agent codex claude-code antigravity-cli --skill '*' --yes
```

GitHub supplies the published source. Only committed, pushed content is available through a remote install. Without `--global`, installation is project-scoped. The provider name `antigravity-cli` selects agy; `antigravity` selects the separate IDE.

Global installations use `~/.agents/skills`. Codex reads this universal location, and the installer links Claude Code there. Global provenance is recorded in `~/.agents/.skill-lock.json`; project installs use `skills-lock.json`.

CLI 1.7.1 treats agy as a universal reader, but agy 1.5.9 does not discover these global packages there. After installing, run this from a checkout of this repository:

```bash
python3 scripts/link-agy-skills.py --apply
```

This links only packages owned by `ryangriffinau/skills` into `~/.gemini/antigravity-cli/skills`. It refuses conflicting files or links and leaves other collections alone. Omit `--apply` for a read-only check. Repeat it after installing newly added skills; existing links follow package updates.

See [installation and migration](docs/specs/skills-distribution/INSTALLATION.md) for verification, backup locations, and cleanup of older installations.

## Updating

Installed skills are vendored copies. Editing this checkout does not update them. Inspect and preserve local edits before replacement, including files under `references/` and `scripts/`.

```bash
npx skills@1.7.1 list --global
npx skills@1.7.1 update review-council --global
```

In CLI 1.7.1, `check` aliases the mutating `update` command. An unqualified global update can change other collections too. Prefer named updates for this collection. Compare complete package contents, because a matching `SKILL.md` does not prove the references and scripts also match.

The proposed `rskills` manager remains [planned](docs/specs/skills-distribution/PLAN.md). The public CLI above is the current installation route.

## Invocation and migrated prompts

All active workflows now live under `skills/<category>/<name>/SKILL.md`. The 18 former files under `prompts/` were migrated with their bodies preserved. The `p-` prefix remains a personal naming convention. [migrations.json](migrations.json) records each old path, new package path, and body hash at migration time.

The old `prompts/` folder is retired. Do not create flat command files, forwarding wrappers, or another copy of a migrated workflow. Native packages replace the old command-directory bridges.

- Codex CLI: select `$<skill-name>` or use `/skills`.
- Codex desktop: select the skill with `@`.
- Claude Code: invoke `/<skill-name>`.
- agy: use `/skills` to inspect discovery, then request the skill by name.

For example, select `p-flywheel-conductor-jsm` to conduct a swarm using the installed jsm skills. Installing the package does not install NTM or provide tools that a host lacks. Open a new chat or reload the provider if its existing skill catalog is stale.

## Maturity

Each skill declares its status in frontmatter. A skill earns `battle-tested` only after it meets the structural requirements and has survived real use. See [CONVENTIONS.md](CONVENTIONS.md). The migrated prompt packages start at `refining` while their native package form is exercised across providers.

| Badge | Status | Meaning |
|---|---|---|
| 🟢 | `battle-tested` | Layered structure and real-world use |
| 🟡 | `refining` | In active use and still being improved |
| ⚪ | `drafting` | Early work that may depend on the author's setup |

## Skills

| Skill | Status | Version | Purpose |
|---|---|---|---|
| [add-prompt](skills/meta/add-prompt) | ⚪ | 0.7.1 | Save portable `p-*` skills with verbatim bodies, publish them, and verify installation |
| [codebase-benchmark](skills/engineering/codebase-benchmark) | ⚪ | 0.2.0 | Produce a whole-codebase scorecard with evidence and trends across reviews |
| [commit](skills/git/commit) | ⚪ | 0.3.0 | Create conventional commits scoped to current-session work |
| [commit-whole-diff](skills/git/commit-whole-diff) | ⚪ | 0.3.0 | Split the full working-tree diff into atomic conventional commits |
| [convex-prod-query](skills/engineering/convex-prod-query) | ⚪ | 0.3.1 | Read production Convex data with a query-only tool and its installer |
| [joint-design-review](skills/web/joint-design-review) | ⚪ | 0.2.1 | Review a product area, track findings, and verify improvements with screenshots |
| [p-close-the-gaps](skills/engineering/p-close-the-gaps) | 🟡 | 0.9.0 | Close the most useful gaps identified by a reality check |
| [p-copy-deslopifier](skills/comms/p-copy-deslopifier) | 🟡 | 0.9.0 | Remove common AI writing patterns while preserving the intended voice |
| [p-deep-project-primer](skills/engineering/p-deep-project-primer) | 🟡 | 0.9.0 | Read project instructions and understand the code and architecture |
| [p-deploy-and-verify](skills/engineering/p-deploy-and-verify) | 🟡 | 0.9.0 | Deploy an app and verify desktop and mobile behavior |
| [p-draft-plan](skills/planning/p-draft-plan) | 🟡 | 0.9.0 | Draft a fallback plan when jsm skills are unavailable; otherwise use `planning-workflow` |
| [p-flywheel-conductor-jsm](skills/engineering/p-flywheel-conductor-jsm) | 🟡 | 0.9.0 | Conduct an NTM swarm using jsm skills and the requested pane configuration |
| [p-fresh-eyes-review](skills/engineering/p-fresh-eyes-review) | 🟡 | 0.9.0 | Re-read recent code changes and fix obvious issues |
| [p-handoff-context-maxxed](skills/comms/p-handoff-context-maxxed) | 🟡 | 0.9.0 | Prepare a next-session prompt that preserves the work and ideas |
| [p-hitl](skills/comms/p-hitl) | 🟡 | 0.9.0 | Present decisions only the user can make, with facts, options, and recommendations |
| [p-idea-wizard](skills/planning/p-idea-wizard) | 🟡 | 0.9.0 | Generate, evaluate, and implement project improvement ideas |
| [p-planning-workflow-with-handoff](skills/planning/p-planning-workflow-with-handoff) | 🟡 | 0.9.0 | Draft a plan and prepare a self-contained prompt for an independent model |
| [p-premortem-general](skills/planning/p-premortem-general) | 🟡 | 0.9.0 | Assume a plan failed and identify the likely causes and early warning signs |
| [p-premortem-spec](skills/planning/p-premortem-spec) | 🟡 | 0.9.0 | Revise a plan around its likely failure modes |
| [p-reality-check](skills/engineering/p-reality-check) | 🟡 | 0.9.0 | Assess completion when jsm skills are unavailable; otherwise use `planning-workflow` |
| [p-reality-check-biggest-flaws](skills/engineering/p-reality-check-biggest-flaws) | 🟡 | 0.9.2 | Run a project reality check and identify the largest flaws and fixes |
| [p-smart-accretive-improvement](skills/planning/p-smart-accretive-improvement) | 🟡 | 0.9.0 | Identify the single most useful addition to the current work |
| [p-smarter-beads-wizard](skills/planning/p-smarter-beads-wizard) | 🟡 | 0.9.1 | Review and improve beads using idea-wizard and beads-workflow |
| [p-synthesize-plans](skills/planning/p-synthesize-plans) | 🟡 | 0.9.0 | Synthesize plans when jsm skills are unavailable; otherwise use `planning-workflow` |
| [p-tangible-progress](skills/engineering/p-tangible-progress) | 🟡 | 0.9.0 | Keep a session or swarm focused on working software and honest evidence |
| [p-unsummarizable](skills/comms/p-unsummarizable) | 🟡 | 0.9.0 | Tighten writing while preserving each useful idea |
| [review-council](skills/decision/review-council) | 🟡 | 0.9.0 | Compare advisor judgments through peer review and a final recommendation |
| [setup-agent-rate-window-ticks](skills/meta/setup-agent-rate-window-ticks) | 🟡 | 0.11.0 | Schedule quick calls on each provider's cloud so usage windows start at set times |
| [stale-work-audit](skills/engineering/stale-work-audit) | ⚪ | 0.1.0 | Compare old sessions, branches, PRs, and trackers against current evidence |
| [teach-me-nugget](skills/meta/teach-me-nugget) | ⚪ | 0.1.0 | Explain a concept from current work with concrete examples and usable heuristics |
| [website-porter](skills/web/website-porter) | 🟡 | 0.9.0 | Port an existing website while preserving SEO, appearance, and cutover safety |
| [write-goal](skills/planning/write-goal) | ⚪ | 0.4.0 | Turn an ambition into a verifiable goal and execution plan |
| [write-like-me](skills/comms/write-like-me) | ⚪ | 0.1.0 | Draft in your own voice from a voice file that learns from every edit and every sent version |
| [write-project-update](skills/comms/write-project-update) | 🟡 | 0.10.1 | Write an evidence-grounded customer, public, or internal project update |

See the [retirement and rename index](deprecated/README.md) for older names. Archived entrypoints use `RETIRED.md` so recursive discovery does not reinstall them. Preserve local edits and verify ownership before removing an old installation.

## Credits

- Vercel Labs maintains the [`skills`](https://github.com/vercel-labs/skills) CLI used to install and update this collection.
- Matt Pocock's skills influenced the approach to writing focused agent skills. His collection is installed separately.
- Jeffrey Emanuel created the [Agent Flywheel](https://github.com/Dicklesworthstone/agentic_coding_flywheel_setup) and [Jeffrey's Prompts](https://jeffreysprompts.com/). `p-draft-plan`, `p-synthesize-plans`, `p-reality-check`, `p-fresh-eyes-review`, `p-idea-wizard`, and `p-premortem-spec` derive from his prompts. The archived `p-plan-to-beads` and `p-agent-swarm-launcher` also came from that work. Current flywheel workflows use his maintained jsm skills.
- Andrej Karpathy's LLM Council inspired `review-council`. Its peer-review flow and decision ledger were added here.

Everything not attributed above is original. Third-party skill packages remain outside this repository.

## License

[MIT](LICENSE) © Ryan Griffin
