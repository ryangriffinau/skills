---
status: ready-to-implement
updated: 2026-10-14
read_when: Investigating missing skills or implementing this collection's portable packages and installer.
---

# Skills discovery and distribution

## Decision

Publish every workflow as a native skill. Keep `p-` as Ryan's naming convention.
Support direct `npx skills` installation and an installed `rskills` command.
Use the public CLI as the installation engine. Add collection-specific diagnosis,
local-edit protection, migrations, and recovery around it.

Maintenance and the immediate conductor repair are complete. The package
conversion and new manager below are ready for implementation, not implemented.
Do not start a swarm to test packaging.

## Completed maintenance

| Change | Result |
| --- | --- |
| `goal-plan` | Renamed to `write-goal`, version 0.4.0 |
| `engineering-review` | Renamed to `codebase-benchmark`, version 0.2.0; profile migration preserves review history |
| `project-vision`, `flywheel-local-launcher`, `pr-closeout` | Archived with `RETIRED.md` entrypoints; launcher directs users to jsm |
| Old `flywheel-conductor` | Archive entrypoint renamed; stale global and repo-local installations removed from discovery |
| `p-agent-swarm-launcher`, `p-install-agent-skill` | Archived |
| `p-plan-to-beads` | Incorporated the existing remote retirement in favor of `beads-workflow` |
| `p-pre-mortem` | Renamed to `p-premortem-general`; this was the actual source for the requested `p-pre-premortem` rename |
| `p-premortem-planner` | Renamed to `p-premortem-spec` |
| `p-draft-plan`, `p-reality-check`, `p-synthesize-plans` | Fallback condition in description, `use_when`, and body; use `planning-workflow` when Jeffrey's skills are usable |
| `p-smart-accretive-improvement` | Body contains only Ryan's exact one-sentence question |
| `p-flywheel-conductor-jsm` | Exact requested replacement plus updated arguments and two short coordination rules |
| `write-project-update` | Recovered installed-only customer guidance into source; version 0.10.1 |
| `add-prompt` | Native packaging guidance for new prompts, correct invocation, no retired installer dependency; version 0.6.0 |
| Catalog | Added missing benchmark and teach-me-nugget entries; corrected install scope and public CLI attribution |

Retired source remains in [the archive](../../../deprecated/README.md). Its old
instructions are historical material, not active workflow dependencies.
Existing project helper scripts were not removed from consuming projects.

Local main was two commits behind remote main, with work from this investigation
and other sessions. A normal merge retained both remote commits, including
`p-close-the-gaps`. The new conductor intentionally supersedes its older remote
text. No squash, force push, or unrelated-file cleanup was used.

Maintenance was published through merge `66b4d8f`. Four changed native skills
were reinstalled from GitHub with `skills@1.7.1`. Six old installed names were
removed using that CLI after ownership checks and backups. The ignored local
old conductor was archived outside discovery. Installed launcher reference edits
were recovered in its archive before removing the installation.

Machine-local backups and audit receipts:
`~/.local/state/skills-maintenance/2026-10-14/`. These are recovery data, not a
portable source dependency. Unrelated `.beads/`, `.claude/`, and unfinished
`skills/meta/claude-session-sharing/` work remains untouched.

## Immediate invocation and its limits

- Codex CLI: `$p-flywheel-conductor-jsm`, or select it through `/skills`.
- Codex desktop: select `@p-flywheel-conductor-jsm`.
- Claude Code: `/p-flywheel-conductor-jsm`.

The native compatibility copy is
`~/.agents/skills/p-flywheel-conductor-jsm/SKILL.md`. It contains the full source
prompt, not an absolute-path forwarding instruction. Its `agents/openai.yaml`
disables implicit invocation. It is not yet a published native package, so a
fresh `npx skills` installation will not install it until phase 1 below.

Codex 0.162.0 `skills/list` with `forceReload: true` confirmed the conductor,
`write-goal`, `codebase-benchmark`, `planning-workflow`, and `vibing-with-ntm`
enabled in customer-kingfield, workhorse-platform, and this repo, with no parse
errors. None of the six retired/renamed old native names remained enabled.
This checks runtime discovery, not a visible desktop picker or a live swarm.
Open a new chat if an existing picker has stale data.

The requested quote is preserved verbatim, including `/loop` and model labels.
Those strings do not prove that a host offers that scheduler or model. The
installer must report capability gaps without silently rewriting user text.

## Root cause and current evidence

The earlier audit found 15 native packages and 20 flat prompt files. After the
requested cleanup and remote merge, there are 12 native packages and 18 active
flat prompts. Normal and full-depth discovery must agree on the 12 packages.
The flat prompts are still outside native package discovery.

Claude reads the linked command files. Codex's native skill catalog does not
load them from `~/.codex/prompts`. The audited 0.159.3 CLI source no longer
registered custom slash prompts. The current CLI is 0.162.0; native discovery
was rechecked. jsm worked because it installed complete native skill packages.
An absent legacy `~/.codex/skills` symlink is not a failure when Codex already
reads the universal `~/.agents/skills` installation.

References: [OpenAI skills](https://learn.chatgpt.com/docs/build-skills),
[legacy prompts](https://learn.chatgpt.com/docs/custom-prompts),
[version-specific Codex source](https://github.com/openai/codex/blob/rust-v0.159.3/codex-rs/tui/src/bottom_pane/slash_commands.rs),
[Claude skills](https://code.claude.com/docs/en/skills),
[public skills CLI](https://github.com/vercel-labs/skills).
Runtime and downloaded package evidence takes precedence over outdated examples.

Public CLI 1.7.1 was inspected and used, with these constraints:

- Use explicit `--global` or project scope and explicit agent targets.
- Global provenance: `~/.agents/.skill-lock.json`; project: `skills-lock.json`.
- `check` aliases the mutating updater. It is not a preview command.
- `experimental_sync` imports from `node_modules`; it is not a global repair.
- Node >=22.20.0 is required. The machine has 22.17.0; maintenance used an
  isolated Node 22.20.0 through `npx --package`, without changing global Node.
- Explicit named installs updated only the requested four packages. Complete
  package hashes and Claude links matched source afterward. All 11,907
  fingerprinted unrelated package files/links remained unchanged.
- A temporary project install from `ryangriffinau/skills#66b4d8f7e9f9ce5337f45964e1312cb024e6a95c`
  preserved GitHub source and the exact commit in `skills-lock.json`, and matched
  source bytes. Test the same contract for the global lock in the manager suite.
- `add --json` still printed human log lines before its JSON result. The adapter
  must handle that output deliberately and verify files/lock entries independently.

## Review against actual jsm behavior

Inspected jsm 0.3.34 help, local status, configuration, integrity verification,
update listing, installed files, and tool diagnostics. This establishes observed
behavior, not unverified claims about its internal transaction implementation.

| jsm behavior observed | Requirement for this collection |
| --- | --- |
| `install` changes local installation; `save` changes the cloud saved list; `sync` reconciles that list | Keep local installation and source selection distinct. Do not model every update as sync. This machine has 152 local skills and zero saved skills. |
| `upgrade` updates skills; `update` updates the jsm executable | Separate skill updates from manager self-update in help and state. |
| Primary skills directory is `~/.claude/skills`; inspected Claude and Codex copies match | Respect actual roots. Compare full packages and mirrors, not only entrypoints. Do not assume all managers use universal symlinks. |
| `verify vibing-with-ntm` reports matching content hashes | Verify references, scripts, and added/deleted files as part of package integrity. |
| `prune` previews by default; deletion requires managed-marker and known-content evidence | Retire only proven owned, unchanged packages. Name matching alone never authorizes deletion. |
| `pin`, version history, and `rollback` are exposed | Support a selected source revision and recoverable prior installation. Do not silently unpin. |
| Auto-update reports scheduler health and last result | If background updates are later enabled, expose actual run outcomes, not just configured intent. |
| `tools` manages executable dependencies separately | Report tool compatibility separately from skill freshness. Prefer jsm's tool management for its ecosystem. |

The four inspected Claude/Codex mirrors matched across all files:
`vibing-with-ntm` (24), `ntm` (21), `beads-br` (6), `agent-mail` (10).
Auto-update reported healthy active launchd, daily 03:00 with jitter, and a last
successful no-update run on October 12. This is a point-in-time report.
Some output requested with `--offline` still labeled its source `api` or mode
`online`; report source and timestamp rather than claiming proven network isolation.

### Conductor tail decisions

1. **Native subagents:** no documented equivalent for the existing requirement
   that bead work stay in observable NTM panes. Retained a short pane-only rule.
2. **Contributor scope:** native `br ready --epic` and `--label` filters exist in
   br 0.2.22. They can scope agreed work without our scripts. They do not infer
   ownership of unassigned beads. Retained an explicit scope requirement and
   removed the `flywheel-ready.sh`/launcher dependency.
3. **Pane context:** jsm's `vibing-with-ntm/references/RECOVERY.md` covers saturated
   context and safe handoff/restart. NTM's config reference covers rotation and
   default-off thresholds. Removed our conflicting 40%/two-compaction policy.

These are workflow decisions based on installed documentation. They are not
claims that every feature works in the currently installed executable.

### Live compatibility gaps to handle before a swarm

- NTM reports **1.18.3** via `ntm --robot-version`. The current jsm skill requires
  at least 1.20.0 and describes 1.35.1. It warns that older pane-targeting flags
  can be accepted but ignored. Upgrade and verify supported commands before use.
- `jsm tools doctor ntm --offline --json` reports NTM present but untracked and
  unhealthy: its `--version` probe fails. Use the working robot-version probe to
  distinguish a probe failure from absence. Inspect `jsm tools update ntm --dry-run`
  before deciding an upgrade path. Do not restart active swarms as an installer side effect.
- Verify the actual worker model and effort from live process arguments/status.
  A pane title is not proof. The older NTM effort suffix can be silently ignored.
- This repo's br database is schema 11. br 0.2.22 expects 17, and its explicit
  migration planner supports only sources 13–16. The database was not changed.
  Maintenance commits omitted only that broken Beads flush through temporary
  hooks; reservation checks and NTM pre-commit scans still passed.
- The local DCG 0.15.2 rejects an existing Convex test fixture. The same installer
  tests pass with CI's checksum-verified pinned DCG 0.6.5. Track compatibility
  separately; do not alter global safety tooling merely to make tests pass.

## Target design

### One portable source

Use `skills/<category>/<name>/SKILL.md` for every active workflow. Move the 18
flat prompts into that tree, preserving `p-` names and user-owned bodies.
No absolute author-machine paths, forwarding wrappers, or separately maintained
prompt copy may remain in a published package.

Use standard `name` and concise `description` fields. Keep existing maturity,
version, tags, and date metadata until a separately tested schema migration is
needed; do not turn this repair into gratuitous metadata churn. Validate names,
lengths, YAML, local references, and host-supported extension fields. Invocation
conditions belong in description and body, not only `use_when` metadata.

Add host metadata only where needed. Keep side-effectful conductor invocation
explicit. For legacy `$ARGUMENTS` and slash references, preserve quoted bodies,
document host limitations, and test argument delivery. Do not promise that
Claude-specific tools become available by converting the filename.

Generate the README catalog from active metadata. Add a small versioned
`migrations.json` describing old/new identities and retirements. History stays
under `deprecated/` with `RETIRED.md`; a recursive search must not publish it.

Claude currently reads a directory symlink to `prompts/`. During conversion,
retire only the recognized legacy bridge after native discovery works. Preserve
custom command directories and unrelated commands. Do not leave a duplicate
legacy command and native skill of the same name indefinitely.

### Two routes, one engine

Direct public installation remains supported:

```bash
npx skills@1.7.1 add ryangriffinau/skills --global --agent codex claude-code --skill '*' --yes
```

Implement `rskills` as a small Node ES-module CLI using the same supported Node
runtime as the public installer. Use Node's test runner and a pinned YAML parser.
Keep existing Bash/Bun tests. No registry, server, authentication layer, or JSM
replacement is needed. Ship a package `bin` entry and tagged GitHub releases so
it can be installed globally without publishing to an npm registry.

The release should document installation from an exact GitHub tag and provide
shell completion. Resolve dependencies into a lockfile; never download `latest`
during an ordinary update. Manager self-update is explicit and separate.

| Command (proposed, not yet available) | Contract |
| --- | --- |
| `rskills doctor [--project PATH] [--json]` | Read-only ownership, integrity, dependency and runtime discovery checks; show exact invocation and reload need |
| `rskills install --global` or `--project PATH` | Install this collection for explicit targets, defaulting to Codex and Claude; scope is mandatory |
| `rskills update --global --dry-run` | Resolve one source revision and compute the exact package/migration changes without modifying installed state |
| `rskills update --global` | Revalidate the plan, then update only safe, owned packages through the public installer |
| `rskills migrate --global --dry-run` | Preview legacy copies, old names, and bridge changes; without dry-run, apply verified migrations |
| `rskills pin REF` / `unpin` | Select or release a collection source revision; updates honor the selection |
| `rskills rollback RUN_ID` | Restore owned files and affected lock entries from a verified receipt; reject intervening edits |
| `rskills link --dev PATH --global` | Explicit live-source author mode with collision checks; release updates must not replace development links |

For every mutating command, allow an explicit project scope instead of global.
A read-only command may write disposable network/cache data, but must not modify
installed packages, provenance, settings, schedules, or the active source pin.
Document that distinction. Offline doctor uses local evidence and labels remote
freshness unknown. Exit 0 for healthy, 1 for actionable findings, 2 for usage or
an operation that could not be completed; JSON includes per-check status.

### Upgrade and recovery contract

Use one resolver for preview and apply. Resolve a source commit once, validate
its catalog, and select explicit package names. Use the verified remote fragment
form `ryangriffinau/skills#<commit>` and test both scopes. Do not install from a
local staging path and mislabel it as GitHub provenance. Parse only a validated
result payload from upstream output; retain bounded diagnostic logs and verify
installed files and lock entries independently of an exit-zero message.

Maintain a small receipt under the user state directory: schema version, run ID,
source repository and revision, scope, agent roots, package tree hashes, link
targets, affected upstream lock entries, backups, and completed step. The public
CLI remains authoritative for installation provenance. The receipt records
recovery and comparisons; it is not another package registry or competing lock.

For each package compare three complete trees: last installed baseline, current
local contents, and selected source. Unchanged local packages can update. Any
local change, including a new/deleted reference or script, produces a conflict
and a recoverable patch. Do not auto-merge executable instructions. If the old
baseline cannot be recovered, mark it unknown and require explicit adoption
instead of guessing from a matching name or `SKILL.md` hash.

Back up before invoking the installer. Recheck path ownership and hashes just
before each write. Use a per-scope manager lock and detect changed upstream lock
entries; unrelated installer processes may not honor our lock. Never restore a
whole global lock over concurrent changes. Merge only affected entries when
safe; otherwise retain the receipt and stop with an exact recovery action.

Treat external symlink targets, path traversal, and names owned by jsm or other
sources as conflicts. A renamed skill is installed and verified before the old
owned copy is retired. Backups live outside every skill search root. Recovery
must restore files, links, and provenance together. Retrying after a partial run
must be safe. No automatic prune of unfamiliar or locally edited directories.

## Review passes and adopted improvements

### Adversarial fresh-eyes pass

Reviewed the earlier proposal again with the assumption that upgrades lose data
or succeed on disk while failing in the user's project. This was a separate
review pass, not an independent-agent review.

| Failure challenged | Final design change |
| --- | --- |
| CLI preview secretly mutates via `check` | Own read-only planner; never call upstream `check` for preview |
| A live branch moves between preview and install | Bind the plan and installation to one source revision |
| Full-depth discovery resurrects archived skills | `RETIRED.md` archives and discovery parity tests |
| JSM mirrors mistaken for duplicates to remove | Source ownership and actual-root checks before any migration |
| Entry file matches but a reference was edited | Complete-tree three-way comparison |
| A rollback erases another installer’s new lock entry | Restore affected entries only, with conflict detection |
| Source copy works only on Ryan's machine | Install a fresh clone without that checkout; no absolute forwarding paths |
| Skill appears but requested tools or efforts do not work | Separate package discovery from tool/model/scheduler capability checks |
| Migrating only source leaves old commands discoverable | Verify native installation, then migrate owned old names and bridges |
| A full JSM clone makes this too large | Thin manager; no cloud lists, accounts, scheduler, or general tool updater in the first release |

### Smart-accretive pass 1

Applied the updated one-sentence prompt after the review. Adopted one addition:
**a runtime verification receipt**. `doctor --project` shows what each runtime
actually discovers, its resolved path, package revision/hash, scope, enabled
state, and any shadowing. Test a harmless disposable skill through both install
routes. Files written successfully are not enough to claim success.

Where a runtime offers no stable discovery API, report filesystem verification
and the unverified picker separately. Never launch a conductor as a smoke test.

### Smart-accretive pass 2

Applied the same prompt again to the revised plan. Adopted one addition:
**recover local improvements before upgrading**. The three-way planner exports
local-only changes as a patch against the known baseline, with the source path
and revision. It can distinguish a safe release update from a user's better
customer reference. This directly addresses the two real installed-only edits
found here. Uploading or publishing recovered content remains a separate action.

These additions are integrated into the contracts above. They are not optional
follow-on projects or reasons to delay the portable package conversion.

## Implementation order and acceptance

1. **Portable packages first.** Convert the conductor, then the other 17 prompts.
   Preserve exact protected bodies, references, and names. Update catalogs and
   authoring checks. Prove normal/full-depth discovery yields all 30 active
   packages and zero archives. Test both fresh install and this machine's upgrade.
2. **Read-only manager.** Implement source resolution, ownership and baseline
   comparison, migration preview, and doctor receipts. Prove these commands
   leave installed trees, lock entries, and settings unchanged on errors too.
3. **Mutations and recovery.** Add install/update/migrate, pin/rollback, and dev
   links through the tested public CLI adapter. Test injected interruption after
   each write boundary and concurrent lock changes. Ship only once recovery works.
4. **Release and CI.** Add the package bin, tagged installation instructions,
   generated catalog check, metadata/reference validation, and root lint tests
   to CI. Pin tested CLI/runtime/dependency versions. Keep direct `npx skills`
   installs first-class and use them in the compatibility matrix.
5. **User-surface proof.** Verify both target projects, native selections in
   Codex and Claude, and an instruction-only fixture's actual loading. Record
   any picker/API limitations. Confirm no unrelated JSM files changed.

Test cases: clean install; reinstall; global vs project; upgrade from legacy
prompts; renamed/retired names; edited/deleted/added supporting files; unknown
baseline; broken link; duplicate/shadowed name; third-party collision; incomplete
operation; changed source revision; concurrent lock update; unsupported Node;
network failure; pin; rollback; development link; stale runtime catalog.

Keep automated background updates out of the first release. Add them only after
manual recovery is proven and the user opts in. Then copy jsm's useful behavior:
visible schedule, last successful run, failures, protected local edits, and
owned-only updates. Do not implement a second updater for jsm's skills or tools.

Local Codex CLI/desktop and Claude Code are the first target. ChatGPT web/mobile
or remote Work would need a separately verified cloud/plugin distribution route.
Do not claim that local links reach those hosts or that NTM can run there.

Completion means a clean install and an upgrade expose the same intended skills,
preserve local work, and provide a tested recovery path. At that point the
machine-local conductor compatibility copy is replaced by its published package.
