---
updated: 2026-11-16
read_when: Installing this collection, verifying prompt migration, or recovering local skill changes.
---

# Native skill installation

All 34 published workflows are packages under `skills/`. The 18 former files in
`prompts/` moved without changing their bodies. On 2026-11-25 they lost the `p-` prefix; `migrations.json` maps each legacy name to its current skill.
[migrations.json](../../../migrations.json) records each move and the original
body hash. Git preserves the original files; no duplicate prompt archive is needed.

Prompt bodies do not use `$ARGUMENTS`; hosts pass invocation text alongside
the skill. Argument hints are scalar strings.
The conductor retains its existing explicit-invocation policy. Workflow-specific
requirements such as NTM, `/loop`, or a terminal still apply; installing a skill
does not add those tools to a host.

## Installation

The [README](../../../README.md) provides the complete reinstall command using
`skills@1.7.1`, Node >=22.20.0, global scope, and these explicit provider targets:

| Provider | CLI target | Global discovery path |
| --- | --- | --- |
| Codex | `codex` | `~/.agents/skills` |
| Claude Code | `claude-code` | `~/.claude/skills` |
| Antigravity CLI (agy) | `antigravity-cli` | `~/.gemini/antigravity-cli/skills` |

The public installer writes the canonical package and Claude links. It owns
`~/.agents/.skill-lock.json`. An absent legacy Codex link is fine when Codex
discovers the universal package. `antigravity` is the editor target, not agy.

Live verification found that CLI 1.7.1 skips agy's global links because it treats
agy as a universal reader. agy 1.5.9 still requires its own global directory.
Run `python3 scripts/link-agy-skills.py --apply` from this repo after installation.
The helper reads installer ownership, checks all targets first, and creates only
missing links for this collection. Without `--apply`, it reports gaps without
changing anything. It refuses conflicting files or links.

Before reinstalling, compare complete installed packages with their recorded
source. Back up local changes, provider links, and lock metadata outside all
discovery roots. Refresh only this repository's packages. jsm and other sources
remain under their existing managers.

After installation, retire verified legacy command bridges and redundant copies.
Never remove a real command directory merely because an old guide expected a
symlink there. New sessions reload native catalogs without those bridges.

## Migration checks

CI runs metadata validation, the linter's regression suite, and
`tests/skill-distribution.test.sh`. The distribution check validates unique
package names, migration paths, absence of legacy prompt files and archived
entrypoints, and portable bundled references.

For an actual installation, compare all package files with the published commit.
Verify every provider link, provenance entry, and retired-name absence. Check
both customer-kingfield and workhorse-platform project contexts for shadowing.

Codex's app-server `skills/list` supports forced discovery reload. agy 1.5.9
supports the read-only `agy -p '/skills' --output-format json` command, which lists
skills without a model turn. For Claude, verify its skill directory and use a
fresh session's slash picker. Distinguish filesystem verification from an observed
picker or model execution. Do not launch a swarm as an installation smoke test.

## Local recovery

The November maintenance backup is stored outside discovery at
`~/.local/state/skills-maintenance/2026-11-16/`. It includes the original source
diff, provider paths and link targets, complete owned packages, and installer
lock metadata. `provider-before.json` records ownership and unrelated-file
hashes for comparison. Retired links are moved there after native verification.

Use those backups to recover a specific local edit. Do not restore an entire
old global lock over later installations from other sources. A concurrent session
published `write-like-me` during this migration, bringing the collection from 33
to 34 native packages; the final reinstall includes it. `claude-session-sharing`
contains a published script but has no `SKILL.md`, so it is not an installable skill.

## Updated runtime findings

The October warning is obsolete. On November 16, NTM reports 1.38.0. br 0.7.6
reads this repository's schema 19 database successfully with automatic import
and flush disabled. Neither finding requires the October upgrade or migration.
These checks do not establish the health of every active swarm.

The proposed `rskills` manager remains separate future work. This migration uses
the public installer directly.
