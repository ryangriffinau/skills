# Portable DCG configuration

This directory versions user-level configuration for [Destructive Command Guard
(DCG)](https://github.com/Dicklesworthstone/destructive_command_guard), a pre-execution safety hook
for coding agents. It is not a skill and does not install, update, or modify DCG itself.

The scope is deliberately narrow: custom pack YAML, named pack profiles, delivery into Ryan's
stow-managed dotfiles, and acceptance tests. Project `.dcg.toml` files and `DCG_*` environment
settings remain separate configuration layers and may add or explicitly override user policy.

## Prerequisite

Install DCG and register its hooks using [DCG's own installation
instructions](https://github.com/Dicklesworthstone/destructive_command_guard#installation). This
repository never writes agent hook files, the DCG binary, built-in packs, allowlists, or
`pending_exceptions.jsonl`.

Confirm the prerequisite before using these files:

```bash
dcg --version
```

## Deliver to Ryan's machines

The repository is the source of truth; GNU stow is the delivery mechanism:

```text
tools/dcg/packs/*.yaml
        |  ./sync-to-stow.sh
        v
~/.dotfiles/stow/agents/.config/dcg/packs/*.yaml
        |  stow agents
        v
~/.config/dcg/packs/*.yaml
```

From this directory, validate the selected profile and packs, then copy changed packs into the
dotfiles tree:

```bash
./sync-to-stow.sh
```

The script never deletes files and never rewrites `~/.config/dcg/config.toml`; that file is a stow
symlink, so replacing it would detach live configuration from dotfiles. Keep its `[packs].enabled`
list hand-maintained in the dotfiles repository, then apply the stow package there:

```bash
cd ~/.dotfiles
stow agents
```

Useful delivery options:

| Option | Meaning |
| --- | --- |
| `--profile full` | Validate the default full profile. |
| `--profile backpocket` | Validate the teammate-oriented domain subset without reducing safety guards. |
| `--stow-dir PATH` | Publish to a different stow package root. |
| `--dry-run` | Report copies and drift without writing. |
| `--check` | Verify only and exit non-zero when stow or live configuration has drifted. |

## Install without stow

Teammates who do not clone Ryan's dotfiles can install the managed minimum directly:

```bash
./install.sh --profile backpocket
```

`install.sh` validates the profile, every selected custom pack, and the complete behavior fixture
before writing. It copies selected `local.*` packs into `~/.config/dcg/packs/`, preserves foreign
TOML content, unions the profile into `[packs].enabled`, and ensures the conventional custom-pack
glob is present. A changed config gets a timestamped backup; a second unchanged run is a no-op.

The installer refuses to write when `~/.config/dcg/config.toml` is a symlink. That is a stow-managed
machine, where replacing the symlink would detach live policy from dotfiles; use
`./sync-to-stow.sh` instead. Preview a non-stow installation with:

```bash
./install.sh --profile backpocket --dry-run
```

For a gradual team rollout, DCG's native `[policy] default_mode = "warn"` and `observe_until`
settings can soften newly introduced rules until an agreed date. This installer deliberately does
not own those policy keys; add them through the teammate's reviewed DCG configuration rather than
silently changing enforcement during pack installation.

Run the independent behavior gate after delivery or while authoring:

```bash
./test/verify.sh
```

`verify.sh` loads packs from this checkout unless `DCG_CONFIG` already names a candidate config. It
passes each fixture command to `dcg explain` as one inert argument; it never evaluates or executes
the fixture text.

## Profiles

Profiles declare managed minimums. They do not replace foreign enabled packs, and choosing a smaller
profile does not imply that previously enabled domain packs are removed.

| Profile | Enabled domains | Intended use |
| --- | --- | --- |
| `full` | Core, disk, package managers, Docker, PostgreSQL, Supabase, S3, Cloudflare, DNS, GitHub, Stripe, Terraform | Ryan's complete machine policy. |
| `backpocket` | Core, disk, package managers, GitHub, Stripe | A teammate who works on the application but does not own the infrastructure domains. |

Every profile must include `core` and all local safety guards:

- `local.agents_skills_guard`
- `local.no_squash_merge`
- `local.convex_prod_deploy_guard`
- `local.no_bypass_prepush`
- `local.no_worktrees`

`sync-to-stow.sh` parses TOML structurally and fails if this invariant is broken. Profiles scope
domain packs; they are never a weaker safety tier.

## Add or change a rule

1. Add or edit `packs/<id>.yaml`. Keep the filename equal to the pack `id`, bump its semver, and put
   the triggering incident or rationale in `description` so the reason travels with the regex.

   ```yaml
   id: local.example_guard
   name: Example Guard
   version: 1.0.0
   description: Blocks the command that caused incident YYYY-MM-DD and explains the safer path.
   keywords: [dangerous-tool]
   destructive_patterns:
     - name: dangerous-action
       description: Running the destructive action
       pattern: 'dangerous-tool\s+destroy\b'
       explanation: This action irreversibly removes shared state.
       message: 'Blocked: use the reviewed recovery workflow instead.'
   safe_patterns: []
   ```

2. Add the pack ID to every profile that should manage it. A safety guard belongs in every profile
   and in `REQUIRED_GUARDS` inside `sync-to-stow.sh`.
3. Add deny and allow rows to `test/fixtures/cases.jsonl`. Record regex blind spots in
   `test/fixtures/known-gaps.jsonl` with `observed`, never `expect`.
4. Validate behavior before publishing:

   ```bash
   dcg pack validate packs/local.example_guard.yaml
   ./test/verify.sh
   ./sync-to-stow.sh --dry-run
   ```

5. Run `./sync-to-stow.sh`, update the stow-managed `config.toml` enabled list when necessary, run
   `stow agents`, and commit the reviewed source changes.

Do not fix drift by hand-editing live pack files under `~/.config/dcg/packs/`; fold the change into
this directory and publish it. To roll back policy, revert the responsible repository commit and
run the same validation and sync path again. Git is the version history.

## Safety boundary

These regex packs are defense in depth against mistakes, not an authorization boundary. DCG sees a
single command string and cannot resolve a production selector exported on a prior line, shell
indirection such as `$TOOL deploy`, aliases, generated commands, or deployment types that are not
encoded in a deployment name. The known-gaps fixture records these limits without asserting that
they are safe.

The load-bearing production invariant is operational:

- agent sessions do not receive production deploy credentials;
- the agent identity cannot deploy production code;
- production deploy credentials and code deployment remain CI-only.

The packs reduce accidental exposure around that boundary; they do not replace it.
