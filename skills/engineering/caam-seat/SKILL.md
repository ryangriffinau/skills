---
name: caam-seat
status: drafting
version: 0.1.0
tags: [caam, ntm, accounts, claude-code, codex, swarm, tooling]
updated: 2026-10-28
description: "Run Claude Code and Codex on several caam accounts at the same time: one caam shallow profile (a seat) per account, named after caam's vault profiles, made safe on macOS, and used for single sessions or whole ntm swarms. Use when you want a session or swarm on a different account from the active one, when caam shallow-spawn seems to run on the wrong account, when setting up seats from caam profiles, or when adding a new Claude or Codex account for swarms. Ships the `caam-seat` CLI and an installer that wires ntm's claude and codex templates."
---

# caam-seat

`caam activate` switches one machine-wide login. Every new session and every running pane follows it. To run a second account at the same time you need a separate HOME per account. caam's shallow profiles provide that. This skill calls each one a **seat** and adds the missing pieces:

- seats named after caam's vault profiles: `claude-<profile>` and `codex-<profile>`;
- a macOS fix, without which Claude seats run on the active account (see below);
- a fresh login per seat, checked against the account the seat is named for;
- one launcher used by single sessions and by ntm swarms.

## Use this when

- You want one Claude or Codex session on an account other than the active one.
- You want a whole ntm swarm (cc and cod panes) on other accounts while your main sessions keep the active one.
- `caam shallow-spawn <name> -- claude` shows your main account in `/status`.
- You added a new Claude or Codex account and want swarms to use it.
- Different projects must run on different accounts (client work vs personal).

## The macOS problem this fixes

caam symlinks `~/Library` into every shallow HOME. `security` finds the login Keychain through `$HOME/Library/Keychains`, and Claude Code reads its token from the Keychain before the seat's own `.claude/.credentials.json`. So on macOS a Claude seat runs on the **active** account, even when it is empty. caam's own design note assumes the opposite. Reported upstream as [caam #130](https://github.com/Dicklesworthstone/coding_agent_account_manager/issues/130).

caam-seat makes each Claude seat's `Library` a real directory that links every child of `~/Library` except `Keychains`. `security` then finds no login keychain, so Claude Code uses the seat's file, as caam intends. Every launch checks and repairs this. If `security login-keychain` still succeeds under the seat, caam-seat refuses to launch. Codex seats need none of this: caam forces file storage and pins `CODEX_HOME`. Evidence and the alternatives considered are in [references/macos-keychain.md](references/macos-keychain.md).

## Install (once per machine)

```bash
npx skills@latest add ryangriffinau/skills --skill caam-seat -g -y
bash ~/.agents/skills/caam-seat/scripts/install.sh            # or: --check, --dry-run
```

`install.sh` is idempotent. It checks caam and jq, puts `caam-seat` on PATH as a shim in `~/.local/bin`, and edits ntm's `[agents]` templates in `~/.config/ntm/config.toml`:

```toml
claude = "caam-seat launch claude --model ..."          # was: claude --model ...
codex = "{{if ...}}...{{end}}caam-seat launch codex ..."  # was: ...{{end}}codex ...
```

With no seat selected, `caam-seat launch` execs the plain CLI, so ordinary swarms behave exactly as before. The installer backs the config up to `config.toml.bak.pre-caam-seat`, checks the result with `ntm config validate`, and never writes through a symlinked config. To undo the change, run `install.sh --unwire-ntm`.

## Set up seats (once per account)

```bash
caam-seat status                 # accounts, seats, and the next commands to run
caam-seat setup                  # a seat for every caam profile that is not the active account
caam-seat setup claude/you@example.com   # or just the ones you name
caam-seat add codex work2        # an account caam does not have yet (e.g. a new Codex account)
```

For each account, `setup` creates the caam shallow profile with **empty** credentials, isolates it, and offers a browser login (`claude auth login --email <expected>` or `codex login`). It then checks the seat signed in to the account its name says. A fresh login gives the seat its own token. Copying the vault's token (`--from-vault`) would make two homes rotate one refresh token and log each other out.

Use `--dry-run` to preview, `--no-login` to log in later with `caam-seat login <seat>`, and `--yes` to skip the per-seat prompt. The active account is skipped, because your normal sessions already use it.

## Pin projects to accounts

```bash
cd ~/Code/github/client-a && caam-seat pin claude-you@client-a.com
cd ~/Code/github/side-project && caam-seat pin claude-you@example.com
caam-seat pin                      # list pins
caam-seat unpin claude             # from inside the project
```

A pin binds a project, meaning its git top level, to one seat per tool. Every `claude` or `codex` started there through caam-seat then uses that account. That covers a plain `ntm spawn` or `ntm add` (the wired templates read the pin), ntm restarts, `caam-seat spawn`, and `caam-seat run claude` for one session. If the pinned seat is logged out or missing, launches in that project are refused rather than falling back to the active account. `NTM_CC_SEAT` / `NTM_COD_SEAT`, or `--claude-seat` / `--codex-seat`, override a pin, and `none` forces the active account.

Pins live in `~/.config/caam-seat/pins.json`. caam has its own project associations (`caam project set`), but those also steer `caam activate`, which switches the machine-wide login. A pin only ever selects a seat.

## Use seats

```bash
caam-seat run claude-you@example.com               # one interactive session on that account
caam-seat run codex-work2 -- -m gpt-6-sol           # args after -- go to the CLI
caam-seat run claude                               # this project's pinned claude seat

caam-seat spawn myproject --label alt --cc=2 --cod=2   # a swarm on seats
caam-seat spawn myproject --label alt --cc=2 --cod=2 --dry-run
ntm add myproject--alt --cc=1                          # later panes use the same seats
```

`spawn` takes the usual `ntm spawn` flags. For each tool it uses the project's pin, else the ready seat with the biggest plan that is not the active account. Override with `--claude-seat <seat>` or `--codex-seat <seat>`. `none` keeps that tool's panes on the active account. It passes the seats to the panes with `--pane-env NTM_CC_SEAT=... NTM_COD_SEAT=...` and records them in the tmux session so `ntm add` panes pick them up. If you asked for `--cc` or `--cod` panes and no seat is ready, it stops rather than quietly running them on the active account.

Check a pane's account with `/status` in Claude Code or Codex.

## Commands

| Command | What it does |
|---|---|
| `caam-seat status [--json]` | caam accounts, seats, states, the seat swarms use, ntm wiring, next commands |
| `caam-seat setup [<tool>/<profile>...]` | create, isolate and log in seats; idempotent |
| `caam-seat setup --repair [<seat>...]` | re-apply macOS isolation only |
| `caam-seat add <claude\|codex> <name>` | seat for an account not in caam's vault |
| `caam-seat login <seat>` | browser login inside the seat, then an account check |
| `caam-seat pin <seat>` / `unpin [tool]` / `pin` | pin this project to a seat, remove it, list pins |
| `caam-seat run <seat\|claude\|codex> [-- args]` | open the seat's CLI; `claude`/`codex` use the project pin |
| `caam-seat spawn <session> [ntm flags]` | ntm swarm with panes on seats |
| `caam-seat launch <claude\|codex> [args]` | ntm template entry point: env seat, else project pin, else the plain CLI |
| `caam-seat doctor [--json]` | caam, shim, ntm wiring, and per seat: a `security` probe, login, account |
| `caam-seat capabilities` | JSON contract: commands, env, states, exit codes |

Exit codes: 0 ok, 1 failed or gaps found, 2 usage error, 3 missing dependency or setup step, 4 refused because a seat is not isolated. Errors print the exact command to run next.

Seat states: `ready`, `same-as-active` (works, but shares the active account's limits), `logged-out`, `wrong-account`, `exposed` (can still reach the real Keychain), plus `no-seat` and `active` for accounts.

## Known limits

- **ntm restarts.** `--pane-env` is part of the launch command ntm builds at spawn, and whether ntm's auto-restart reuses it is untested. A project pin does not depend on it, so pin projects that must stay on one account. After a restart in an unpinned project, check the pane with `/status`.
- **Rotation is machine-wide.** `ntm rotate` and caam auto-failover switch accounts with `caam activate`, not seats. Keep them off for seat swarms.
- **Keychain-only secrets inside Claude seats.** A tool that keeps its secret only in the login Keychain cannot see it inside a Claude seat. git's `osxkeychain` helper is one example. `gh` (hosts.yml) and git through `gh auth git-credential` keep working.
- **Usage numbers.** `caam limits` reads caam's vault copies, not seats. For a seat's usage, run `/usage` in the session.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `/status` in a seat shows your main account | `caam-seat doctor`, then `caam-seat setup --repair <seat>` |
| `seat ... is not logged in` | `caam-seat login <seat>` |
| `signed in as X, but it is the seat for Y` | `caam-seat login <seat>` and pick account Y in the browser |
| `ntm's claude template does not call caam-seat` | `bash ~/.agents/skills/caam-seat/scripts/install.sh` |
| `no ready codex seat` | `caam-seat add codex <name>`, or `--codex-seat none` on purpose |
| `refused: seat not isolated` (exit 4) | inspect `~/orch-homes/<seat>/Library`, then `caam-seat doctor` |
| Seat was recreated by `caam shallow-profile create --force` | the next launch repairs it; or `caam-seat setup --repair <seat>` |
| Panes in a project refuse to start after a pin | the pinned seat is logged out or gone: `caam-seat doctor` shows which, then `caam-seat login <seat>` or `caam-seat unpin claude` |

## When caam fixes #130

`caam-seat doctor` probes the Keychain directly, so it stays correct either way. Once caam withholds `Library/Keychains` itself, the repair step finds nothing to do. Seat naming, login checks, `spawn` and the ntm launcher remain useful.

## Files

- `scripts/caam-seat`: the CLI (bash 3.2 compatible, needs `caam` and `jq`). It is bash so the launch path can `exec`, which leaves `claude` or `codex` as the pane's process.
- `scripts/install.sh`: idempotent installer and doctor (`--check`, `--dry-run`, `--unwire-ntm`).
- `references/macos-keychain.md`: the Keychain finding, the evidence, and the fix options.
- `tests/caam-seat.test.sh`, `tests/install.test.sh`: behaviour tests against stub caam, claude, codex, security, ntm and tmux (`tests/stubs.sh`). They run on Linux CI with `CAAM_SEAT_PLATFORM=Darwin`.
