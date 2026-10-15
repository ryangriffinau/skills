# Agent hooks

Owner-made lifecycle hooks for Claude Code and Codex, with an installer that merges them into each
agent's user config. Vendor hooks (dcg, plannotator, post-compact reminder, Codex Computer Use) are
installed by their own tools and are out of scope; this installer never edits their entries.

## Design

- **One hook so far: `flywheel-no-ask.sh`.** Flywheel conductor and swarm panes run in tmux, where
  an interactive question blocks the whole turn and stalls the swarm. Inside tmux the hook denies the
  question tool and tells the agent to ask in plain text. Outside tmux (desktop apps, plain terminal)
  it allows the tool. Escape hatch: `CLAUDE_ALLOW_ASK=1` (both agents).
- **Same script for both agents.** Claude Code and Codex both accept the
  `hookSpecificOutput.permissionDecision: "deny"` PreToolUse output. Matchers are the only difference:
  `AskUserQuestion` (Claude) and `request_user_input` (Codex, exact match).
- **Codex has the same problem.** In Codex 0.162.0, `request_user_input` blocks the turn in Plan mode
  (`is_blocking: mode == ModeKind::Plan` in `core/src/tools/handlers/request_user_input.rs`). It also
  gets the default function-tool PreToolUse payload in `core/src/tools/registry.rs`, so a hook can
  deny it. `request_user_input_async` does not block and is left alone. Codex hook commands receive
  `TMUX`: only identity-token variables are scrubbed (`protocol/src/shell_environment.rs`).
- **Merge by group.** Our group is identified by its installed command path. It is left alone if
  identical, replaced in place if changed, or appended at the end if missing. The installer never
  reorders groups, because Codex trust keys are positional (`hooks.json:pre_tool_use:<group>:<handler>`)
  and moving dcg's group would silently un-trust it.
- **Safe writes.** Malformed JSON, non-object configs, symlinked (dotfiles-managed) configs, and groups
  shared with foreign hooks are refused before any write. A config with a real change gets a
  timestamped `.bak` copy, then an atomic rename that keeps its file mode. Semantically unchanged
  configs are not rewritten.
- **Codex trust stays with the owner.** Codex runs a new or changed user hook only after it is
  trusted in `/hooks` ("hooks need review before they can run"). The installer does not write trust
  hashes into `config.toml`.

## Inventory (this machine, 2026-10-15)

| Agent | Event / matcher | Command | Made by | In this repo |
| --- | --- | --- | --- | --- |
| Claude | PreToolUse `Bash\|PowerShell\|Monitor` | `~/.local/bin/dcg` | dcg (vendor) | no; patterns in `tools/dcg` |
| Claude | PreToolUse `AskUserQuestion` | `~/.claude/hooks/flywheel-no-ask.sh` | owner/conductor | **yes** |
| Claude | SessionStart `compact` | `~/.local/bin/claude-post-compact-reminder` | flywheel (`Dicklesworthstone/post_compact_reminder`) | no |
| Codex | PreToolUse `Bash` | `~/.local/bin/dcg` | dcg (vendor) | no |
| Codex | PreToolUse `request_user_input` | `~/.codex/hooks/flywheel-no-ask.sh` | owner (this tool) | **yes** |
| Codex | Stop | `~/.local/bin/plannotator` | plannotator (vendor) | no |
| Codex | `notify` (config.toml) | Codex Computer Use `SkyComputerUseClient turn-ended` | OpenAI (vendor) | no |

Enabled Claude plugins (`playground`, `figma`) ship no hooks. No project-level hook configs were
found under `~/Code`.

## Use

```bash
./install.sh              # install or update both agents (idempotent)
./install.sh --check      # exit 1 if installed scripts or config groups drift from this checkout
./install.sh --dry-run    # report without writing
./install.sh --uninstall  # remove our groups, then our unmodified script copies
./install.sh --agent codex
```

The scripts are copied to `~/.claude/hooks/` and `~/.codex/hooks/`; `CLAUDE_CONFIG_DIR` and
`CODEX_HOME` are respected. After a Codex install or change, open `codex`, run `/hooks`, and trust
the `request_user_input` hook.

Requires `bash` and `jq`.

## Test

```bash
test/run.sh
```

The test suite runs under temporary `HOME` directories and never touches live configs. It covers:

- pipe tests inside and outside tmux, the escape hatch, and large stdin for both tool names
- merge tests on fixtures with pre-existing dcg, SessionStart, and Stop entries
- idempotency and no-op byte stability
- refusal of malformed, symlinked, and shared-group configs
- uninstall
- negative controls: mutated copies with the escape hatch removed, a clobbering merge, or a
  prepending merge must fail the same suites.

## Caveat (unverified)

The hook keys off `TMUX` in the environment the agent was started with. If a Codex session is served
by a shared app-server daemon, its hooks may see the daemon's environment instead of the pane's.
Inside tmux that would fail open and allow the question tool. Outside tmux it would fail closed if
the daemon was started in tmux. This has not been observed. If it happens, set `CLAUDE_ALLOW_ASK=1`
or restart the daemon outside tmux.
