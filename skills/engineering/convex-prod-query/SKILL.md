---
name: convex-prod-query
status: drafting
version: 0.2.0
tags: [convex, production, verification, dcg, tooling]
updated: 2026-09-16
description: "Read production Convex state from an agent session without approval prompts and without any way to write or deploy. Use when verifying work is complete on prod, checking prod data or function results, comparing dev vs prod, or when dcg blocks `convex run ... --prod` for something that is only a query. Ships the `convex-prod-query` CLI (query-only by construction) plus an installer that wires the shim, Claude Code deny rules, and the companion dcg pack it pairs with."
---

# convex-prod-query

Verifying that work is complete usually means reading production. `bunx convex run <fn> --prod` cannot be told apart from a mutation on the command line, so the dcg guard confirms every prod-targeted run. This skill ships a runner that is read-only by construction, so agents can read prod freely while writes and deploys stay gated.

## Use this when

- You need a production query result to prove a change landed or a bug is fixed.
- dcg blocked `convex run … --prod` and the function is a query.
- You want the same query against dev and prod side by side.
- You are on a new machine or a teammate's machine and need prod reads working in one command.

## Commands

```bash
convex-prod-query <module:function> '{"arg":"value"}'   # run a query on prod, print JSON
convex-prod-query --list <substring>                      # list query names on prod
convex-prod-query --dev <module:function> '{}'            # same call against the dev deployment
convex-prod-query --url https://<name>.convex.cloud <fn>  # explicit deployment (staging, preview)
convex-prod-query --env-file <path> …                     # dotenv to load (default: enclosing repo's .env)
```

In template-derived repos `bun run prod:query` is an alias for the same command. Run it from anywhere inside the repo; the tool walks up to the repo root to find `.env`.

## What makes it safe

- It only ever POSTs to the deployment's `/api/query` endpoint. The Convex server refuses to execute anything but a query there ("Trying to execute X as Query, but it is defined as Mutation"), verified with and without an admin key. The endpoint has no code-push path.
- It has no `--push`, `--prod`, or write options and refuses unknown flags.
- It authenticates with `CONVEX_PROD_READ_KEY`, a scoped Convex access token that carries no deploy or write permission. Even a tampered copy of the tool holds nothing that can deploy or write.
- The companion dcg pack carves the tool out explicitly and points agents at it from the `convex run --prod` confirm message.

## Companion dcg pack

This skill and the dcg pack `local.convex_prod_deploy_guard` are a pair. The pack confirms every prod-targeted `convex run` and names this tool in the message; the tool is what makes that gate liveable instead of a constant interruption. Install one without the other and you get either a blocked agent or an ungated one.

So the skill bundles the pack at `dcg/local.convex_prod_deploy_guard.yaml` and `scripts/install.sh` installs and enables it, additively, preserving any packs you already have. `tools/dcg` in the skills repo stays the source of truth for pack content and for installing the full pack set; `tests/dcg-pack-sync.test.sh` fails the moment the bundled copy drifts from it.

The installer never writes through a symlink. On a stow-managed machine the pack and `config.toml` belong to the dotfiles repo, so it verifies the version and prints the sync command (`tools/dcg/sync-to-stow.sh`, then `stow agents`) rather than detaching them. Pass `--no-install-pack` to skip the pack entirely.

## Install

One-time per machine:

```bash
npx skills@latest add ryangriffinau/skills --skill convex-prod-query -g -y
bash ~/.agents/skills/convex-prod-query/scripts/install.sh
```

`install.sh` is idempotent and does four things: checks `bun`, puts `convex-prod-query` on PATH as a shim in `~/.local/bin` (left alone on a stow-managed machine where the dotfiles already link it), adds Claude Code `permissions.deny` Edit rules for the tool, the shim, and the dcg configuration, and installs and enables the companion dcg pack. `install.sh --check` is the doctor mode and writes nothing. Codex is covered by its workspace-write sandbox rather than deny rules.

Per repo, once:

1. In the Convex dashboard, create a production access token scoped to `deployment:data:view`, `deployment:logs:view`, `deployment:env:view`, `deployment:functions:runInternalQueries`, `deployment:functions:runTestQuery`. Do not grant `deployment:deploy`, `data:write`, `env:write`, or `runInternalMutations`.
2. Put it in the repo's root `.env` as `CONVEX_PROD_READ_KEY=prod:<deployment>|<token>`.
3. Remove `CONVEX_PRODUCTION_DEPLOY_KEY` from every agent-readable env file. The full deploy key belongs to CI secrets only. If it is still present the tool works but warns on every run.

## What stays gated, on purpose

- `bunx convex run <fn> --prod` remains confirm-tier. A genuine prod write gets a one-time `dcg allow-once` from the human.
- `convex export --prod` egresses the whole dataset and stays confirm-tier.
- `convex deploy`, prod-targeted `convex dev`, and `convex run --push` are never agent-side. Production code ships from CI.
- Free without prompts: `convex data|logs|env get|function-spec … --prod`, with `CONVEX_DEPLOY_KEY` set to the read token.

## End-to-end tests on production

dcg does not gate a browser or Playwright hitting the deployed site. What it gates is seeding and cleanup through prod-targeted `convex run`. Keep those as the explicit approved step of a prod E2E run, or give the E2E runner its own scoped token with `runInternalMutations` and one sanctioned entry-point script. Run destructive suites against a preview or staging deployment.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `skill not installed at ~/.agents/skills/...` | `npx skills@latest add ryangriffinau/skills --skill convex-prod-query -g -y` |
| `no credential: set CONVEX_PROD_READ_KEY` | Add the scoped token to the repo's root `.env` (see Install, per repo) |
| `Could not find public function` on a known internal query | The key was not accepted as admin; check it is a deployment access token for that deployment |
| `X is not a query, so this tool will not run it` | Working as intended. Writes go through `convex run … --prod` plus `dcg allow-once` |
| dcg still confirms `convex-prod-query` | Pack older than 3.5.0. Rerun `install.sh`, or on a stow machine sync it from `tools/dcg` |
| `… is a stow symlink` during install | Expected on Ryan's machines. Update the pack in the skills repo and `stow agents`; nothing is written through the link |

## Files

- `scripts/convex-prod-query` — the tool (Bun, no dependencies beyond the Convex CLI for `--list`).
- `scripts/install.sh` — idempotent installer and doctor (`--check`).
- `dcg/local.convex_prod_deploy_guard.yaml` — the companion pack, copied from `tools/dcg`.
- `dcg/merge-config.py` — source-preserving TOML merge used to enable the pack additively.
- `tests/convex-prod-query.test.sh` — behaviour tests against a local mock of `/api/query`.
- `tests/install.test.sh` — installer tests in a temporary HOME.
- `tests/dcg-pack-sync.test.sh` — fails if the bundled pack drifts from `tools/dcg`.
