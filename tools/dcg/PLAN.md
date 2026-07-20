# Plan — Portable `tools/dcg`: DCG rules, profiles, and installer

**Status:** proposed · **Author:** Ryan (via planning-workflow) · **Date:** 2026-07-19
**Home:** `ryangriffinau/skills/tools/dcg/` — a *tools* root beside `skills/`, **not** a skill.
**Distribution model:** all-central (every rule installs at the DCG **user** level via `install.sh`;
nothing repo-scoped) — per Ryan's decision. The installer merges **additively** (preserves foreign
config; §5), so "central" does not mean "overwrite a teammate's setup." The real production-deploy
control is a separate **operational layer** — agents never hold prod deploy credentials (§2.3); the
regex packs are defense-in-depth on top of that.
**Known tradeoff (flagged for Ryan):** repo-specific *wrapper names* (`deploy:prod`,
`scripts/deploy-exec.sh`) applied globally become false positives in unrelated repos that happen to
use those script names. The universal-by-meaning rules (`convex deploy`, no-squash) don't have this
issue. If that friction bites, the fix is to move the wrapper-name rules to a repo-scoped
`.dcg.toml` while keeping the universal rules central — a later refinement, not a v1 blocker.

---

## 1. Why this exists (the problem)

Ryan's machine carries hand-authored DCG (Destructive Command Guard) rules that encode
hard-won, incident-driven safety policy for this stack:

- **`local.convex_prod_deploy_guard`** (v3.2, three-tier) — born from the 2026-07-19 all-sites outage
  (a feature branch's Convex backend deployed to prod, replacing shared serving functions → every
  customer site 404'd as Vercel ISR expired). Hard-blocks prod *code deploys* (`convex deploy`,
  `deploy:prod`, `deploy-exec.sh`, prod-targeted `convex dev`/`run --push`, `convex mcp start
  --dangerously-enable-production-deployments`), gates prod data/config *writes* behind per-command
  confirmation, and lets read-only prod introspection + `codegen` + key-arming run free. See
  §2.2–§2.3 for the full policy + fail-open boundary.
- **`local.no_squash_merge`** — squash merges destroy per-bead commit ancestry and cause phantom
  add/add conflicts on long-lived workstream branches (customer-kingfield PR #126 incident).
- **`local.agents_skills_guard`** — a hand-made symlink into `~/.agents/skills` bypasses the
  `skills` CLI's source tracking and silently forks the canonical repo.

Today these live **only** in `~/.config/dcg/` on one machine. They are:
- **not portable** — a new laptop or a teammate starts with zero of these guards;
- **not versioned** — the rules and their incident rationale aren't in git history;
- **not reviewable** — changes to safety policy happen by editing a dotfile with no diff trail.

**Goal:** capture the rules + a named-profile abstraction + an idempotent installer in
`tools/dcg/`, so any machine or teammate gets the identical guard set with one command, and every
future change to the policy is a reviewable commit.

### Non-goals (explicit scope fence)

- **Not** installing, updating, or modifying DCG itself, and **not** wiring its agent hooks — that is
  `dcg install`'s job. We check + instruct only. See the hard scope fence in §2.0.1.
- **Not** repo-scoped `.dcg.toml` distribution — Ryan chose all-central. (A repo-scoped `.dcg.toml`
  at a git root *is* a real DCG mechanism, but it's deliberately out of scope here.)
- **Not** modeling DCG as a skill — DCG is a deterministic pre-exec hook, not a model-invoked skill.
  `tools/dcg` sits beside `skills/`, sharing the repo but not the skill contract.

---

## 2. Grounding — what DCG actually gives us (verified)

These are load-bearing facts about DCG, confirmed against the installed CLI (v0.6.5) and its config
this machine already runs. Everything below is built on them.

| Fact | Consequence for this plan |
| --- | --- |
| **Config hierarchy:** env `DCG_*` > `DCG_CONFIG` > project `.dcg.toml` (git root) > user `~/.config/dcg/config.toml` > `/etc/dcg` > defaults. | We manage the **user** layer only. The installer never touches project/env layers; those still override, and the README says so. |
| **No named-profile primitive.** DCG has `[packs] enabled` (a flat list) + `[agents.*]` trust levels. There is no built-in "profile = bundle of packs". | "Profiles" are **our convention**, realized by *rendering* the final `config.toml` from a chosen profile fragment. See §4. |
| **Custom packs** = YAML files matched by `[packs] custom_paths` globs, enabled by their `id` in `enabled`. Tilde (`~`) in a glob expands. (Proven: the live `local.*` packs load this way.) | We can point `custom_paths` **directly at the repo clone**, so `git pull` updates rules with zero re-copy. Absolute-path glob support is the one item to verify in T1. |
| **Pack schema:** `id, name, version, description, keywords[], destructive_patterns[{name,description,pattern,explanation,message}], safe_patterns[{name,description,pattern}]`. `keywords` gate which commands a pack is even evaluated against (perf). | Packs migrate **verbatim** — identity (`id`, filename) is preserved, so nothing about matching behavior changes on the move. |
| **Decision model is BINARY: `allow` or `deny`.** No native "warn/confirm/prompt" tier (severity is message metadata, not a decision). But `dcg allow-once <code>` + the allowlist let a human approve one blocked command. | A three-tier policy (allow / confirm / hard-block) is expressed as: allow = `safe_pattern` or no match; **confirm = `deny` whose message offers `dcg allow-once`**; hard-block = `deny` whose message says CI-only. See the `convex_prod_deploy_guard` v2 rewrite (§2.1). |
| **Stateless, single-line evaluation + Rust regex (no lookbehind/lookahead).** DCG sees only the current command line — a var `export`ed on a prior line, `.env.local`, an alias, `eval`, or an unresolved shell variable is invisible. | Rules gate on **in-line** signals (`--prod`, `--deployment prod`, an inline `KEY=…`, the subcommand). These are **known fail-open boundaries, not safe defaults** — the guard is defense-in-depth; the real control is the operational invariant in §2.3 (agents never hold prod deploy creds). Patterns use `[^|;&]*` to stay within one command segment. |
| **Testing mechanisms:** `dcg explain <cmd> --format json` (or `--robot`) returns a **per-command** `{decision, command, steps[]}` — the reliable per-case oracle. `dcg simulate -f <file> --format json` is **aggregate only** (`totals` + per-rule `exemplars`, ≤3) — it can NOT map a decision to a specific input line. `dcg pack validate <file>` checks schema + regex linearity. | `test/verify.sh` drives **per-case `dcg explain`** over a JSONL fixture (asserts `.decision` + matched rule); `simulate` is a secondary aggregate smoke check. Caveat: `explain`'s command lives in the **argument**, so running it against a real trigger (`dcg explain "convex deploy"`) self-trips the hook in an agent Bash context — verify.sh is meant to run in a plain human/CI shell (no PreToolUse hook), where this is a non-issue; `simulate`/`pack validate` take only a path and never self-trip. |

### 2.0 SUPERSEDING SIMPLIFICATION (Ryan, round 4) — use DCG's conventional pack dir

**Grounded fact:** DCG has **no** native pack-install command (`dcg pack` = `info|validate` only;
`dcg init` emits a sample config; `dcg packs` lists). Its built-in custom-pack facility *is*
`[packs] custom_paths` (glob) + `enabled` (id list) + `dcg pack validate` — which we already use.
DCG lacks only the distribution/lifecycle layer.

**Therefore: drop the content-addressed snapshot architecture.** It existed only because the
installer rewrote `custom_paths` to a new digest dir each run. Keep DCG's **conventional, already-
configured** location `~/.config/dcg/packs/*.yaml` as a **stable glob** and copy pack files into it.
This eliminates by design (not by machinery) — R2 findings #1/#3 and R3 blockers #2/#3, plus most of
#1: the digest contract, snapshot durability/orphans/GC roots, legacy-collision preflight and its
self-collision, duplicate pack IDs, and the `custom_paths` no-op-oracle blindness. The only config
mutation left is **adding our pack IDs to `enabled`** (a string-list merge), so the journal/recovery
model shrinks to one small file edit.

**Rollback comes from git, not from disk snapshots:** the repo *is* the version history
(`git checkout <sha> && ./install.sh`). Retained: copy-not-symlink (no clone dependency),
`dcg pack validate` pre-install, verify-before-activate, atomic config write, one timestamped backup.
Cost: no instant multi-version on-disk rollback (git + backup covers it). Teammate-owned packs in that
dir coexist — we own only our three filenames, which is additive by nature.

> Supersedes the snapshot design in §5 step 3 and the `--live`/sourcing discussion. Those sections
> stay for provenance but the snapshot machinery is **descoped**; T4b shrinks accordingly.

### 2.0.1 SCOPE FENCE — we ship configuration only, never touch core DCG

**This project provides pack YAML + pack configuration and makes it easy to install. Nothing else.**

In scope — the installer writes exactly two things:
1. our pack YAML files into DCG's conventional custom-pack dir (`~/.config/dcg/packs/`);
2. our pack IDs into `[packs] enabled` in `~/.config/dcg/config.toml` (additive merge).

**Explicitly OUT of scope — do not go near:**
- **Hook registration** (`~/.claude/settings.json`, `~/.codex/hooks.json`). That is `dcg install`'s
  job. If a machine doesn't have DCG properly installed, that is not our problem — detect and tell
  the user, never wire it ourselves. (`--bootstrap-dcg` is therefore **dropped**: we don't install,
  update, or modify the DCG binary.)
- **Built-in packs**, DCG internals, the allowlist, and `~/.config/dcg/pending_exceptions.jsonl`
  (14 live `allow-once` runtime entries — never clobber, never version).
- Any other key in `config.toml` we didn't add (general settings, heredoc, `[agents.*]`).

A fresh machine's prerequisite is simply "DCG installed and hooked per its own installer."

### 2.0.2 Pack config is ADDITIVE across layers (verified, corrects an earlier claim)

**Verified empirically, not assumed.** Running `dcg config` from `~/Documents/InStrand` (a git repo
carrying its own `.dcg.toml` that enables 12 built-in packs and lists none of our guards) reports
**both** config sources and an effective enabled set of **15 packs** — the project's 12 **plus all
three `local.*` guards inherited from the user config**.

So: **`[packs] enabled` is merged (union) across user → project layers, not replaced.** A project
`.dcg.toml` can *add* packs but cannot silently drop a global guard by omission. This strengthens the
all-central model (§2.1) — user-level install really is universal for enabled packs — and corrects an
earlier draft claim that the InStrand vault ran unguarded (it does not; no change needed there).

Remaining caveat (the honest limit): DCG exposes a separate **`Disabled packs`** mechanism
(`DCG_DISABLE` / a disabled list), so an *explicit* disable could still drop a guard, and `DCG_CONFIG`
can point at an entirely different config file. Omission cannot.

Clean sweep otherwise: allowlist empty; heredoc settings are defaults; no `[agents.*]` overrides; the
only project `.dcg.toml` anywhere under `~/Code/github` or `~/Documents` is InStrand's.

### 2.1 Global scope (confirms decisions D1/D2 — the whole point)

DCG's user-level config (`~/.config/dcg/config.toml`) is **machine-global**: the hook evaluates *every* agent Bash command regardless of which project directory it runs in. And per §2.0.2 (verified), a project `.dcg.toml` at a git root **adds to** the enabled set rather than replacing it — so a project config cannot silently drop a global guard by omission. Installing the `full` profile at the user level therefore applies the Convex prod-deploy guard (and every other pack) across **all** projects on that machine — customer-kingfield, platform-monorepo, any Convex repo. This is exactly the requirement ("install once, apply everywhere Convex is used"); no per-project install is needed and none is used. The installer only ever writes the user layer. (Only an *explicit* disable or a `DCG_CONFIG` override can drop a pack.)

### 2.2 `convex_prod_deploy_guard` at v3.2.0 (three-tier, command-gated)

The original guard blanket-blocked *arming* the prod key — too broad (it blocked read-only
introspection and data ops, not just deploys). Refined per Ryan's 2026-07-19 policy — **gate on the
command, not the key** — then hardened in review round 1:

- **ALLOW (no prompt):** read-only prod (`convex data`, `convex logs`, `convex env get`/`list`), any
  non-prod-targeted convex command, and arming the prod key alone. `convex codegen` is allow —
  it only generates local files and does not touch the deployment (the v2 codegen block was a
  false-positive, removed).
- **CONFIRM (deny + `dcg allow-once`):** prod-targeted **writes** — `convex run`, `convex import`,
  `convex env set`/`remove`/`unset`.
- **BLOCK (hard, CI-only):** prod **code deploys + prod-enabling ops** — `convex deploy`,
  `deploy:prod` scripts, `scripts/deploy-exec.sh`, prod-targeted `convex dev`, prod-targeted
  `convex run --push` (`--push` pushes local code first), and
  `convex mcp start --dangerously-enable-production-deployments` (unlocks prod-mutating MCP tools).

**Prod is detected from in-line signals:** `--prod`; `--deployment [team:][project:]prod` (qualified
names ending in `prod`, v3.1); or an inline `CONVEX_PRODUCTION_DEPLOY_KEY`, `CONVEX_DEPLOY_KEY=prod:`,
or `CONVEX_DEPLOYMENT=prod:` (env selector, v3.1). v3 added the `--deployment prod` selector the v2
patterns missed; v3.1 added the qualified-name + `CONVEX_DEPLOYMENT` env-selector forms + the mcp
flag, all real bypasses round 2 reproduced.

**Required before pack activation** (round 3 — deferring the *implementation* to T5 is fine, but
these must NOT ship allowed-through-activation; verify exact CLI forms + every spelling against Convex
docs, then add rules + deny/allow fixtures → target **v3.2 → v3.3**):
- **HARD:** `convex deployment select …:prod` (persists the selected prod deployment for later
  commands — directly bridges the prior-line blind spot); `convex deployment create --type prod`;
  `convex deployment token create` prod-targeted (**mints a prod credential that can land in
  `.env.local` — contradicts the §2.3 operational invariant; a hard block, not a confirm**).
- **CONFIRM:** prod-targeted `convex deployment token delete`; `convex env default
  set/remove/rm/unset --type prod`.
- **Known fail-open:** `deployment token create` against an *ambient previously-selected* prod
  deployment has no in-line prod signal — remains covered by §2.3, with a `known-gaps` fixture.

**This is defense in depth, not the authorization boundary** (see §2.3). Fail-open gaps are
documented in the pack, not papered over: `convex run` query-vs-mutation is undecidable (prod runs
confirm; bare/dev runs free); a key/selector set on a *prior* line or via `--env-file`/`.env.local`
is invisible; and a deployment name that doesn't literally contain `prod` (e.g. `happy-animal-123`)
can't be classified. **v3.2 (round 3): fixed a false-positive** — qualified selectors now terminate on
a shell token (`(?:\s|$|[|;&])`), not a word boundary, so `--deployment prod-staging` /
`team:project:prod-staging` / `prod.staging` correctly **ALLOW** (only a final component of exactly
`prod` denies). Validated (`dcg pack validate`: 9 destructive / 0 safe, 100% linear) and
behavior-verified via `dcg simulate` across all three rounds' matrices (v3: 20/10; v3.1 additions:
6/6; v3.2 FP fix: `prod-staging`/`prod.staging`/`team:project:prod-staging` now allow, exact
`prod`/`project:prod` still deny). Canonical + live.

### 2.3 The real safety invariant is operational, not regex

A stateless regex guard reduces *accidents*; it cannot enforce "production code never deploys
agent-side" while the agent holds credentials (or an authenticated token) capable of a prod deploy,
because shell indirection (`TOOL=convex; $TOOL deploy`), aliases, `eval`, and generated command
strings all evade regex. The load-bearing controls are therefore operational and belong in the plan
as first-class requirements:

- **Agent sessions must not receive production deploy keys.**
- **The agent identity must not have production code-deploy permission.**
- **Production deploy credentials remain CI-only** (main → convex-deploy).
- Installation and verification must **not claim** to close the fail-open gaps above — they document
  them (a `known-gaps` fixture, §6) so the boundary is honest.

**Current machine state captured as the migration baseline** (`~/.config/dcg/config.toml`):

```toml
[packs]
custom_paths = ["~/.config/dcg/packs/*.yaml"]
enabled = [
  "core", "system.disk", "containers.docker",
  "database.postgresql", "database.supabase",
  "cdn.cloudflare_workers", "dns.cloudflare",
  "platform.github", "payment.stripe",
  "infrastructure.terraform", "storage.s3", "package_managers",
  "local.agents_skills_guard", "local.no_squash_merge", "local.convex_prod_deploy_guard",
]
```

The three `local.*` entries are our custom packs; the rest are DCG built-ins we merely *enable*
by name (DCG ships their YAML — we don't).

---

## 3. Directory layout

```
tools/dcg/
  README.md                              # what/why + install/usage + "add a rule" runbook
  install.sh                             # idempotent installer (the one command)
  profiles/
    full.toml                            # DEFAULT — every pack (mirrors Ryan's machine, verbatim)
    backpocket.toml                      # monorepo-teammate subset (all safety guards + stack infra)
  packs/
    local.agents_skills_guard.yaml       # migrated verbatim
    local.no_squash_merge.yaml           # migrated verbatim
    local.convex_prod_deploy_guard.yaml  # migrated verbatim
  test/
    verify.sh                            # block/allow assertions via `dcg explain --robot`
  PLAN.md                                # this document (design record)
```

**Naming:** pack files keep the `local.` prefix so filename == `id` == current on-disk name.
Zero identity churn on migration.

---

## 4. The profile abstraction (our convention over DCG's gap)

A **profile** is a named, composable declaration of *which packs are active*, expressed as a TOML
fragment under `profiles/`. Because DCG's live config has a single flat `enabled` list, the
installer **renders** the chosen profile into `~/.config/dcg/config.toml`.

**Closed v1 profile schema** (round 2): a profile permits exactly `schema_version`, `name`, and
`[packs].enabled` — **unknown keys are rejected**. `[agents.*]` overrides are out of scope until
their merge+ownership semantics are designed. `custom_paths` is machine-derived (§5), never in a
profile. Note the `[packs].enabled` table header — the enforcement (below) parses `[packs].enabled`,
so the profile must use it, not a bare top-level `enabled`.

```toml
# profiles/full.toml
schema_version = 1
name = "full"

[packs]
enabled = [
  "core", "system.disk", "containers.docker",
  "database.postgresql", "database.supabase",
  "cdn.cloudflare_workers", "dns.cloudflare",
  "platform.github", "payment.stripe",
  "infrastructure.terraform", "storage.s3", "package_managers",
  "local.agents_skills_guard", "local.no_squash_merge", "local.convex_prod_deploy_guard",
]
```

```toml
# profiles/backpocket.toml
schema_version = 1
name = "backpocket"

[packs]
enabled = [
  "core", "system.disk", "package_managers", "platform.github", "payment.stripe",
  "local.agents_skills_guard", "local.no_squash_merge", "local.convex_prod_deploy_guard",
]
```

The installer renders the profile into a full config, injecting `custom_paths` at install time (§5).

### Profiles

| Profile | Contents | For |
| --- | --- | --- |
| **`full`** (default) | Exactly the 15 packs above — Ryan's current machine's enabled set. | Ryan's machines; anyone who wants the whole floor. |
| **`backpocket`** | `core, system.disk, package_managers, platform.github, payment.stripe` + **all three `local.*` guards**. Drops infra packs (terraform/s3/cloudflare/postgres/supabase/docker) a monorepo-only teammate doesn't touch. | A teammate working the platform-monorepo who doesn't own infra. |

**Profiles are managed *minimums*, not exclusive effective configs** (round 2): because the installer
merges additively, selecting `backpocket` after `full` *stops managing* the dropped infra packs but
**preserves any foreign pre-existing enabled entries** — so the effective config may remain a superset
of the profile. The profile defines what this installer *owns*, not the machine's whole policy.

**Safety invariant (non-negotiable):** *every* profile includes **all three `local.*` guards** and
`core`. Profiles vary only *domain* infra packs (you don't load the Postgres pack if you never run
`psql`). A profile is **domain-scoping, never safety-reduction** — there is no "lax" tier. This is
deliberate: it keeps the robust floor everywhere and prevents profiles from becoming a backdoor for
weaker safety. The installer enforces this by **structurally parsing** the rendered candidate's
effective `[packs].enabled` set (a TOML parse, not grep — a comment or stray string must not satisfy
it) and asserting exactly one instance each of `core`, `local.agents_skills_guard`,
`local.no_squash_merge`, `local.convex_prod_deploy_guard`. A profile that omits a guard fails the
install, not just review.

> **Decision to confirm (D1):** the two-profile set above. If teammates need finer domain slices we
> add profiles later; the abstraction is built for it. Default stays `full`.

---

## 5. The installer (`install.sh`) — contract & behavior

**One command:** `./tools/dcg/install.sh` (defaults: `--profile full`, copy-into-conventional-dir).

### Flags

| Flag | Effect | Default |
| --- | --- | --- |
| `--profile <name>` | Which `profiles/<name>.toml` to render. | `full` |
| `--live` | Opt-in dev mode: point `custom_paths` at the working clone (fast iteration; disabled if the clone moves). | off (copy is default) |
| *(no `--bootstrap-dcg`)* | Out of scope (§2.0.1): if `dcg` is absent or unhooked, we detect and instruct — installing/updating DCG is `dcg install`'s job, never ours. | — |
| `--dry-run` | Print the rendered config + planned actions; write nothing. | off |

### Pack sourcing — the key design choice

> **Reversed in review round 1 (gpt-5.6-sol).** Originally the default was "live": point
> `custom_paths` at the working clone so `git pull` updates rules with no re-install. For a *safety
> guard* that's the wrong default — a moved/deleted clone silently disables every custom pack, and a
> `git pull` mutates machine-global policy **before** it has passed the acceptance suite. "Always
> current" is undesirable when "current" is unverified.

> **Then simplified again in §2.0 (Ryan).** The round-1 answer to that was content-addressed
> snapshots — which turned out to be the source of nearly every later blocker. The right answer keeps
> the *copy* (which is what actually solves the moved-clone problem) and drops the digest machinery.

**Default (copy into DCG's conventional dir):** the installer validates the repo packs and copies
them into DCG's standard custom-pack location, referenced by a **stable glob that never changes**:

```toml
custom_paths = ["~/.config/dcg/packs/*.yaml"]   # already present on this machine
```

Because the packs are *copied*, the active guard is independent of where the clone lives and is
unaffected by an unreviewed `git pull` — the activation is deliberate (`install.sh`, after
verification §6). Because the glob is *stable*, there is no digest, no snapshot dir, no
`custom_paths` churn, and no migration. **Rollback is git:** `git checkout <sha> && ./install.sh`.

**`--live` (opt-in dev):** points `custom_paths` at the working clone for fast iteration while
authoring rules. Warns that moving the clone disables the packs; never for shared machines.

> **D2 (resolved):** copy-into-conventional-dir default; `--live` opt-in. Keeps global user-level
> scope (your decision-2) and robust sourcing, without the snapshot machinery.

### Behavior (transactional, merge-preserving, truly idempotent)

> **Revised in review round 1 (gpt-5.6-sol).** The original "render the whole config and replace it,
> backing up the old one" design was unsafe: a backup does not preserve *active* behavior — a
> teammate's (or Ryan's other machine's) unrelated `custom_paths`, enabled/disabled packs, general
> settings, and `[agents.*]` trust profiles would vanish from the live config. The installer must
> own **only its own entries** and merge structurally.

1. **Preflight + lock.** Acquire a **portable atomic lock** — `mkdir ~/.config/dcg/.ryangriffinau-skills.lock`
   (**not `flock`** — round 2 confirmed it's absent on the target macOS). Record PID/host/start/version
   inside; never auto-steal a stale lock (print recovery instructions); release from
   EXIT/INT/TERM/HUP traps. Hold it through recovery → activation. Require `dcg` present (unless
   `--dry-run`) — **detect and instruct only; never install, update, or modify DCG or its hooks**
   (§2.0.1). Assert a **supported DCG version** (from `dcg config --format json`) and the read-only
   capabilities used (`pack validate`, `config --format json`, per-command `explain --format json`).
   Fail loudly on an unknown version.
2. **Resolve profile structurally.** Parse `profiles/<name>.toml` (a TOML parse, not grep). Assert
   the **safety invariant on the parsed effective enabled set** — exactly one instance each of
   `core`, `local.agents_skills_guard`, `local.no_squash_merge`, `local.convex_prod_deploy_guard`.
   A comment or a string outside `[packs].enabled` must not satisfy the check.
3. **Validate the repo packs.** Run `dcg pack validate` on each `packs/*.yaml`; reject symlinks and
   non-regular files. That's it — **no snapshot, no digest, no staging dir** (§2.0 descoped all of it).
   The destination is DCG's conventional custom-pack dir `~/.config/dcg/packs/`, referenced by a
   **stable** glob that never changes. `--live` instead points `custom_paths` at the working clone.
4. **Parse existing config + ownership manifest.** Read the live `config.toml` as TOML and our prior
   manifest (`~/.config/dcg/.ryangriffinau-skills.manifest.json`) against a **closed versioned schema**
   — missing = first install; malformed / unknown-version / namespace-escaping = **fail closed** before
   touching anything. Never guess ownership. Simplified shape (no snapshot, no digest):
   `{schema_version, owner, profile, managed:{enabled_added[], pack_files[], custom_paths_added[]}}`.
   `enabled_added` records only IDs **absent before install** (pre-existing identical entries stay
   foreign unless explicitly adopted), `pack_files` the filenames we own in the packs dir.
5. **Build the candidate config — purely additive.** Preserve every foreign table/key (other
   `custom_paths`, enabled/disabled packs, `[agents.*]`, general settings). Then only:
   (a) ensure the conventional glob `~/.config/dcg/packs/*.yaml` is present in `custom_paths` — a
   single **stable** value, added once on a fresh machine and never churned (record in
   `custom_paths_added` only if we added it); and (b) **union** the profile's pack IDs into
   `[packs] enabled`, recording newly-added IDs in `enabled_added`. No collision preflight, no legacy
   migration, no exactly-once snapshot invariant — §2.0 removed the conditions that made those
   necessary (one stable glob, one dir, filenames we own).
6. **Verify the candidate before activation.** Run the full fixture suite against it with
   `DCG_CONFIG=<candidate>` (§6). No candidate activates until it passes.
7. **No-op fast path.** Compare (a) each repo pack's bytes against its counterpart in
   `~/.config/dcg/packs/`, and (b) the normalized live vs candidate TOML with the same parser. If both
   match, report `already current` — **no durable mutation** (transient lock/temp is fine).
   (`dcg config --format json` is a capability/version smoke check only — round 2 proved it omits
   `custom_paths` and pack identity, so it is never the oracle.)
8. **Activate — copy packs, then enable.** The ordering matters and is what makes this safe:
   because the glob is **stable and already in the config**, dropping a pack file into the packs dir
   *is* activation for that file, while a pack ID stays **inert until listed in `enabled`**. So:
   copy each pack file via write-temp-in-dest-dir + `rename(2)` (atomic per file), **then** write the
   config via the same atomic pattern, keeping a timestamped no-clobber backup, then write the
   manifest. Run the fixture smoke check against the now-active config; on failure restore the config
   backup atomically.
   **Crash semantics (why the round-3 journal state machine is no longer needed):** a crash after the
   file copies but before the config write leaves *extra, inert* pack files — harmless, and the next
   run simply completes. A crash during the config write is impossible to observe half-done (atomic
   rename: either old or new). Re-running is always safe and converges. Manifest lag is likewise
   self-healing: a stale manifest only under-claims ownership, and step 4's fail-closed parse catches
   corruption.
9. **Release lock + report.** Release the lock (trap-driven). **Report** profile, packs copied/updated,
   IDs newly enabled, backup path (if any), and the verify summary.

**No destructive operations** (RULE 1): no file is deleted; prior configs are backed up, and pack
files we don't own are never touched. A parser-backed TOML read/write helper is an explicit
implementation dependency — shell text surgery on arbitrary TOML is not robust enough.

---

## 6. Verification contract (`test/verify.sh`) — the acceptance gate

> **Revised in review round 1 (gpt-5.6-sol).** The original design drove `dcg simulate` and claimed
> per-line assertions — but `simulate`'s JSON is aggregate (`totals` + per-rule `exemplars`), so it
> *cannot* prove which decision belongs to which fixture row. Switched to a **per-case oracle**.

For each record in `test/fixtures/cases.jsonl`, extract the command with `jq -r .command` (pass it as
one argument — never `eval`/execute it), run `dcg explain --format json <command>` (plain shell / CI,
no PreToolUse hook), and assert:
`.schema_version == 2`; `.decision == expected`; **deny → `.match.rule_id == expected`**; allow →
`.match` absent. Round 2 corrections: the matched rule is at **`.match.rule_id`, NOT `.steps`**
(`.steps[].details.first_match` carries only the pack id); and **deny returns exit 0** (including
`--robot`) — so *never infer deny from exit status*; treat non-JSON output / process failure as a
harness error. JSONL (not TSV) avoids tab/quote/multiline fragility. `dcg simulate` stays a fast
aggregate smoke check only. This pins DCG drift and the intended *tier* (confirm and hard-block both
report `deny`, so the rule id is what distinguishes them). Fixture rows look like:

```json
{"expect":"deny","rule":"local.convex_prod_deploy_guard:raw-convex-deploy","command":"npx convex deploy"}
{"expect":"allow","command":"convex data --deployment prod"}
```

**Must DENY — hard block (prod code deploy)** — incl. the review-found invocation variants, all of
which reduce to `raw-convex-deploy`:

| Command | Expected rule |
| --- | --- |
| `pnpm run deploy:prod` | `…:pnpm-deploy-prod-script` |
| `convex deploy` / `npx convex deploy` / `pnpm dlx convex deploy` / `./node_modules/.bin/convex deploy` | `…:raw-convex-deploy` |
| `cd subdir && convex deploy` / `convex data && convex deploy` / `convex deploy --prod` / `convex deploy --dry-run` | `…:raw-convex-deploy` |
| `bash scripts/deploy-exec.sh` | `…:deploy-exec-script` |
| `CONVEX_DEPLOY_KEY=$CONVEX_PRODUCTION_DEPLOY_KEY convex dev` / `convex dev --deployment prod` | `…:prod-targeted-convex-dev` |
| `convex run m:mutate --prod --push` / `convex run m:x --deployment prod --push` | `…:prod-convex-run-push` |

**Must DENY — confirm (prod data/config write; human `dcg allow-once`):**

| Command | Expected rule |
| --- | --- |
| `CONVEX_DEPLOY_KEY=$CONVEX_PRODUCTION_DEPLOY_KEY convex run m:doThing` / `convex run m:mutate --deployment prod` | `…:prod-convex-run-write` |
| `convex import --prod snapshot.jsonl` / `convex import snapshot.zip --deployment=prod` | `…:prod-convex-import` |
| `convex env set FLAG on --prod` / `convex env --deployment prod set FLAG on` | `…:prod-convex-env-write` |

**Must DENY — other custom guards** (test alternate spellings, not just the easy form):

| Command | Expected rule |
| --- | --- |
| `gh pr merge 12 --squash` / `gh --repo o/r pr merge 12 --squash` | `…:gh-pr-merge-squash` |
| `git merge feature --squash` / `git -C repo merge feature --squash` | `…:git-merge-squash` |
| `ln -s /some/repo ~/.agents/skills/foo` / `ln --symbolic … ~/.agents/skills/x` / `/bin/ln -s … ~/.agents/skills/y` | `…:symlink-into-agents-skills` |

**Must ALLOW (regression guard against over-blocking):**

| Command | Why it must pass |
| --- | --- |
| `pnpm run deploy:staging` | staging deploys are safe |
| `convex dev` | bare dev deployment is safe |
| `convex data --prod` / `convex data --deployment prod` / `convex logs --prod` / `convex env get FLAG --prod` | read-only prod introspection |
| `CONVEX_DEPLOY_KEY=prod:example convex codegen` | codegen is local-only (v2 false-positive removed) |
| `convex run m:readThing` | bare (dev-targeted) run |
| `CONVEX_DEPLOY_KEY=$CONVEX_PRODUCTION_DEPLOY_KEY convex data` | read-only prod, prod key armed |
| `export CONVEX_DEPLOY_KEY=$CONVEX_PRODUCTION_DEPLOY_KEY` | arming the key alone is fine |
| `gh pr merge 12 --merge` | merge-commit is the sanctioned path |

The Convex subset of this matrix (30 commands) was run against the **live v3 guard** via
`dcg simulate` (20 deny / 10 allow, every review-found bypass closed) — `test/verify.sh` codifies it
as a per-case standing gate. Exit non-zero on any mismatch. `install.sh` runs it against the
*candidate* before activation; it also runs standalone in the skills repo's CI.

**`test/fixtures/known-gaps.jsonl`** — the fail-open cases DCG *cannot* catch, recorded as
`observed` (not `expect`) so they're honest documentation, never asserted as safe:

```json
{"observed":"allow","command":"TOOL=convex; $TOOL deploy","reason":"shell indirection unresolved pre-exec"}
{"observed":"allow","command":"convex dev","precondition":"prod key exported on a prior line"}
{"observed":"allow","command":"convex dev --env-file .env.production","reason":"regex can't read env-file contents"}
{"observed":"allow","command":"convex dev --deployment happy-animal-123","reason":"a deployment name need not encode that it is prod"}
{"observed":"allow","command":"CONVEX_DEPLOYMENT=$TARGET convex dev","reason":"inline selector value is shell indirection, unresolvable statically"}
```

Plus round-3 **FP-fix allow fixtures** (must ALLOW — staging deployments whose name merely starts
with `prod`): `convex dev --deployment prod-staging`, `convex run fn --deployment
team:project:prod-staging`, `convex import data.zip --deployment prod.staging`. Only a final component
of *exactly* `prod` denies.

These are the operational-invariant's job (§2.3), not the regex's.

> **Grounding task T1 — DONE (confirmed in review):** an absolute-path `custom_paths` glob loads the
> pack and denies the raw deploy command. (Less load-bearing now that §2.0 keeps the stable
> conventional glob rather than a per-install absolute digest path.)

---

## 7. README contract (`tools/dcg/README.md`)

Must contain, in order:
1. **What DCG is** (one line + link to the DCG project) and that this folder manages the **user**
   config layer only — project `.dcg.toml` and `DCG_*` env still override.
2. **Install:** `./install.sh` (and `--profile backpocket`, `--live`). Prerequisite: DCG already
   installed + hooked via its own installer (§2.0.1 — we never touch that).
3. **Profiles table:** what each profile enables and who it's for; the safety invariant.
4. **Add-a-rule runbook:** write `packs/<id>.yaml` (schema + a worked example) → add its `id` to the
   relevant profile(s) → re-run `install.sh` → confirm `test/verify.sh` green → commit. Every new
   rule ships with an incident/rationale sentence in its `description` (this is why the guards are
   trustworthy — the *why* travels with the *what*).
5. **Source-of-truth note:** the repo is now canonical; don't hand-edit `~/.config/dcg/`. If you
   must, fold the change back into the repo. The installer backs up any drift.

---

## 8. Task graph (→ beads in the **skills** repo, not platform-monorepo)

Dependency-ordered. IDs are placeholders until `br create` in `~/Code/github/ryangriffinau/skills`.

```
T1  Absolute-path custom_paths glob loads  [DONE — confirmed in review]
T2  Scaffold tools/dcg/ + stage 3 packs  [DONE — convex guard at v3 three-      (blocks T3,T5)
     tier, review-hardened; other two migrated verbatim]
T1b [DESCOPED by §2.0 — stable conventional glob means no duplicate-ID or
     path-ordering question to ground]
     [T2b/T4d REMOVED — out of scope per §2.0.1: hook wiring belongs to
     `dcg install`, and InStrand needs no change (pack config is additive)]
T3  Author versioned profile schema (schema_version,name,[packs].enabled;         (needs T2)
     reject unknown keys) + full.toml (15) + backpocket.toml (§4)
T4a Select/vendor structural TOML parse+serialize helper; strict profile +        (needs T3)
     manifest parsers + canonical config comparison
T4b Implement mkdir lock, copy packs into the STABLE conventional dir             (needs T4a)
     (~/.config/dcg/packs/), enabled-list ownership merge, atomic config write
     + timestamped backup, recovery. [SHRUNK by §2.0 — no snapshot hashing, no
     digest dirs, no legacy-collision migration, no custom_paths mutation]
T4c CLI flags + DCG-present/version detection (detect+instruct only, never       (needs T4a)
     install or hook — §2.0.1)
T5  Guard v3.2 [DONE — live: env selector, qualified :prod, mcp flag, FP fix].    (needs T2)
     PRE-ACTIVATION BLOCKER → v3.3: close deployment select/create/token-create
     (HARD), token-delete/env-default (CONFIRM) after doc-verify every spelling;
     cases.jsonl (all bypasses, exact rule ids) + known-gaps + FP-fix allow rows
T6  verify.sh — per-case `dcg explain --format json` (.match.rule_id, exit-0-     (needs T5)
     safe); contextual-pack alternate spellings
T7  README (install, scope fence §2.0.1, additive profile+manifest semantics,     (needs T3,T4b)
     git-based rollback, fail-open vs operational §2.3)
T8  Isolated integration tests (temp config home): fresh install (no prior        (needs T4b,T6)
     config), foreign-config preservation, additive enabled-union, pack-file
     update, full→backpocket→full, corrupt/missing manifest, concurrent/stale
     lock, crash between pack-copy and config-write (inert files, re-run
     converges), no-durable-mutation-on-no-op
T9  Real-machine E2E + explicit operational credential/identity audit (agents    (needs T8)
     hold no prod deploy key; agent identity can't deploy prod) — owned, evidenced
T10 CI workflow → feature-branch commit → PR                                     (needs T7,T9)
```

Critical path: **T4a → T4b → T8 → T9 → T10** (T1/T2 done; T1b descoped; T5 guard live at v3.2).
T3/T4a and T5/T6 parallelize.

**Acceptance for the whole effort:**
- Fresh machine: clone skills → `./tools/dcg/install.sh` → `verify.sh` green; **every expected
  destructive rule** blocks (all cases.jsonl deny rows), all allow rows pass, known-gaps documented.
- **Merge-preservation:** on a machine with pre-existing foreign DCG config (extra `custom_paths`,
  a disabled pack, an `[agents.*]` block), install preserves all of it and adds only the managed
  entries; the ownership manifest records exactly what's ours.
- **Scope fence (§2.0.1) holds:** the installer touches *only* our pack files and our IDs in
  `[packs] enabled`. No hook file, no DCG binary, no built-in pack, no allowlist, and
  `pending_exceptions.jsonl` byte-identical before/after.
- **Crash safety:** killing the installer between the pack copies and the config write leaves only
  *inert* extra pack files; re-running converges to the correct state. The config write itself is
  atomic (never observable half-done).
- **True idempotency:** a second `install.sh` with no repo change performs **no durable** config/
  manifest/backup/pack mutation and prints `already current`.
- **Operational invariant (§2.3) — its own task T9, owned + evidenced:** agent sessions carry no prod
  deploy key; the agent identity cannot deploy prod code. This — not the regex — is the real gate.

---

## 9. Rollout & risk

- **Migration is copy-forward, not cut-over.** The current `~/.config/dcg/` keeps working untouched
  until `install.sh` runs; the installer backs it up before writing. Reversible by restoring the
  `.bak.<epoch>` file.
- **Version drift risk:** a future DCG release could change pattern semantics. `verify.sh` catches
  it — a red gate on install/CI, not a silent regression.
- **Path-move risk (only in opt-in `--live` mode):** if the clone moves, `custom_paths` dangles →
  guards silently off. The **copy default avoids this entirely** (packs are copied into
  `~/.config/dcg/packs/`, independent of the clone). Residual mitigations
  for `--live` users: `verify.sh` re-run detects it; README calls it out; consider a future
  `install.sh --check` cron/verify hook (out of scope v1).

---

## 10. Open decisions for Ryan (before implementation)

**Rounds 1 & 2 (gpt-5.6-sol, high effort) are complete and integrated.** Both reproduced behavior
against live DCG v0.6.5. Round 1 (8 findings): closed prod-write bypasses (guard → v3), reshaped
installer/verify/sourcing. Round 2 (8 findings, verdict **NOT steady-state**): found real bugs in the
round-1 revisions — `dcg config --format json` isn't a valid no-op oracle, the matched rule is at
`.match.rule_id` (not `.steps`), `flock` is absent on macOS, first-install duplicates `local.*` pack
IDs, and 7 more live guard bypasses. All integrated above; the guard is now **v3.1 (live, verified)**.

- **D1 / D2 / D4 — RESOLVED:** both profiles; copy-into-conventional-dir default; all-central.
- **D5 / D6 — DONE:** rounds 2 and 3 complete + integrated. Round 3 (verdict NOT steady-state, 4
  blockers + 1 should-fix) defined the installer recovery **state machine**, fixed the legacy
  self-collision + snapshot digest/durability/orphan/GC contract, reclassified `deployment token
  create` as HARD (mints a prod credential), and fixed a **live guard false-positive** (guard → v3.2:
  `--deployment prod-staging` no longer wrongly denied). All integrated.
- **D7 — OPEN (your call):** three rounds have each found real issues — the trajectory is converging
  (R1 architecture → R2 broke R1's installer assumptions → R3 refined recovery internals + 1 regex
  FP), i.e. the remaining items are increasingly *implementation-detail the T8 test matrix will pin*
  rather than fresh architecture. Options: (a) **run round 4** to confirm steady-state before beads
  *(planning-workflow says 4+ rounds; cheap insurance on a safety tool)*; (b) **create beads now** for
  T1b–T10 and drive the remaining precision into implementation with the integration-test matrix
  *(defensible — R3's blockers are now specified in the plan)*; (c) pause for your own read.

Next: your D7 call → (round 4 →) create beads in the **skills** repo → implement T1b–T10.
```
