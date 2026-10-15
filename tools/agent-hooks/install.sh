#!/usr/bin/env bash
# Install, verify, or remove the owner-made agent hooks for Claude Code and Codex.
#
# Copies hooks/*.sh into each agent's home and merges one PreToolUse group per hook into
# ~/.claude/settings.json and ~/.codex/hooks.json. Other entries (dcg, plannotator, ...) are never
# touched: our group is found by its command path, replaced in place, or appended at the end.
# Appending matters for Codex: its trust key is "<file>:pre_tool_use:<group>:<handler>", so moving
# an existing group would silently un-trust it.

set -euo pipefail

TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK_NAME="flywheel-no-ask.sh"
SOURCE_SCRIPT="$TOOL_DIR/hooks/$HOOK_NAME"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
CODEX_DIR="${CODEX_HOME:-$HOME/.codex}"

MODE="install"
AGENTS="all"
DRY_RUN=0

die() { printf 'install.sh: error: %s\n' "$*" >&2; exit 1; }
warn() { printf 'install.sh: warning: %s\n' "$*" >&2; }
info() { printf '  %s\n' "$*"; }

usage() {
  cat <<'USAGE'
usage: ./install.sh [--agent claude|codex|all] [--uninstall | --check] [--dry-run]

  (default)     copy hooks and merge them into the agent configs (idempotent)
  --uninstall   remove our groups from the configs and our unmodified script copies
  --check       verify the installed state matches this checkout; exit 1 on drift
  --dry-run     report what would change without writing
  --agent NAME  limit to one agent (default: all)

Respects CLAUDE_CONFIG_DIR and CODEX_HOME. Changed config files get a timestamped backup.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent) AGENTS="${2:?--agent requires claude, codex, or all}"; shift 2 ;;
    --uninstall) MODE="uninstall"; shift ;;
    --check) MODE="check"; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done
case "$AGENTS" in claude|codex|all) ;; *) die "unknown agent: $AGENTS" ;; esac
command -v jq >/dev/null 2>&1 || die "jq is required"
[[ -f "$SOURCE_SCRIPT" ]] || die "missing hook source: $SOURCE_SCRIPT"

# Group-level merge. $cmd identifies our group; $matcher is the agent's tool name.
# shellcheck disable=SC2016
JQ_INSTALL='
  def ours: {matcher: $matcher, hooks: [{type: "command", command: $cmd}]};
  if type != "object" then error("top level is not an object") else . end
  | .hooks //= {}
  | if (.hooks | type) != "object" then error(".hooks is not an object") else . end
  | .hooks.PreToolUse //= []
  | if (.hooks.PreToolUse | type) != "array" then error(".hooks.PreToolUse is not an array") else . end
  | [.hooks.PreToolUse | to_entries[] | select(any(.value.hooks[]?; .command == $cmd)) | .key] as $hits
  | if ($hits | length) > 1 then error("our command appears in more than one PreToolUse group")
    elif ($hits | length) == 0 then .hooks.PreToolUse += [ours]
    elif (.hooks.PreToolUse[$hits[0]].hooks | length) > 1 then error("our command shares a group with other hooks; fix by hand")
    else .hooks.PreToolUse[$hits[0]] = ours
    end'

# shellcheck disable=SC2016
JQ_UNINSTALL='
  if type != "object" then error("top level is not an object") else . end
  | if (.hooks.PreToolUse | type) == "array" then
      .hooks.PreToolUse |= (map(.hooks |= map(select(.command != $cmd))) | map(select((.hooks | length) > 0)))
      | if .hooks.PreToolUse == [] then del(.hooks.PreToolUse) else . end
      | if .hooks == {} then del(.hooks) else . end
    else . end'

# shellcheck disable=SC2016
JQ_HAS_OURS='[.hooks.PreToolUse[]? | select(. == {matcher: $matcher, hooks: [{type: "command", command: $cmd}]})] | length == 1'

# shellcheck disable=SC2016
JQ_GROUP_INDEX='[.hooks.PreToolUse // [] | to_entries[] | select(any(.value.hooks[]?; .command == $cmd)) | .key] | first // empty'

WORK="$(mktemp -d "${TMPDIR:-/tmp}/agent-hooks.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT INT TERM HUP

file_mode() { stat -f '%Lp' "$1" 2>/dev/null || stat -c '%a' "$1"; }

# atomic_write SRC DEST MODE — temp file in DEST's directory, then rename.
atomic_write() {
  local temporary
  temporary="$(mktemp "$(dirname "$2")/.$(basename "$2").XXXXXX")"
  cat "$1" >"$temporary"
  chmod "$3" "$temporary"
  mv -f "$temporary" "$2"
}

backup() {
  local copy
  copy="$1.bak.$(date +%s).$$"
  cp -p "$1" "$copy"
  printf '%s' "$copy"
}

# validate_config FILE — refuse symlinks (stow/dotfiles) and malformed JSON before any write.
validate_config() {
  [[ ! -L "$1" ]] || die "$1 is a symlink (dotfiles-managed?); refusing to detach it"
  [[ -f "$1" ]] || return 0
  jq -e 'type == "object"' "$1" >/dev/null 2>&1 || die "$1 is not a JSON object; refusing to touch it"
}

# process AGENT CONFIG DEST_SCRIPT MATCHER
process() {
  local agent="$1" config="$2" dest="$3" matcher="$4"
  local work candidate changed=0 failed=0
  printf '%s\n' "$agent"
  validate_config "$config"
  [[ ! -L "$dest" ]] || die "$dest is a symlink; refusing to replace it"
  work="$WORK/$agent"
  mkdir -p "$work"
  local current="$work/current.json"
  candidate="$work/candidate.json"
  if [[ -f "$config" ]]; then cp "$config" "$current"; else printf '{}\n' >"$current"; fi
  cp "$current" "$candidate"

  case "$MODE" in
    check)
      if [[ -f "$dest" ]] && cmp -s "$SOURCE_SCRIPT" "$dest" && [[ -x "$dest" ]]; then
        info "script current: $dest"
      else
        info "DRIFT: script missing, modified, or not executable: $dest"; failed=1
      fi
      if jq -e --arg cmd "$dest" --arg matcher "$matcher" "$JQ_HAS_OURS" "$candidate" >/dev/null; then
        info "config current: $config (matcher $matcher)"
      else
        info "DRIFT: $config lacks exactly one '$matcher' group for $dest"; failed=1
      fi
      if [[ "$agent" == codex && $failed -eq 0 ]]; then
        local index key
        index="$(jq -r --arg cmd "$dest" "$JQ_GROUP_INDEX" "$candidate")"
        key="$config:pre_tool_use:$index:0"
        if grep -qF "[hooks.state.\"$key\"]" "$CODEX_DIR/config.toml" 2>/dev/null; then
          info "codex trust entry present: $key (confirm 'Trusted' in /hooks)"
        else
          info "codex trust entry absent: $key — run /hooks in Codex and trust it; untrusted hooks do not run"
        fi
      fi
      [[ $failed -eq 0 ]] || STATUS=1
      return 0
      ;;
    install)
      jq --arg cmd "$dest" --arg matcher "$matcher" "$JQ_INSTALL" "$current" >"$candidate" 2>"$work/err" \
        || die "merge failed for $config: $(cat "$work/err")"
      ;;
    uninstall)
      local index last
      index="$(jq -r --arg cmd "$dest" "$JQ_GROUP_INDEX" "$current")"
      last="$(jq -r '(.hooks.PreToolUse // []) | length - 1' "$current")"
      if [[ "$agent" == codex && -n "$index" && "$index" -lt "$last" ]]; then
        warn "removing Codex group $index shifts later PreToolUse groups; re-trust them in /hooks"
      fi
      jq --arg cmd "$dest" "$JQ_UNINSTALL" "$current" >"$candidate" 2>"$work/err" \
        || die "uninstall merge failed for $config: $(cat "$work/err")"
      ;;
  esac
  # Semantic comparison: an unchanged config is never rewritten, so its formatting survives.
  if [[ -f "$config" ]]; then
    jq -e -n --slurpfile a "$current" --slurpfile b "$candidate" '$a == $b' >/dev/null || changed=1
  elif [[ "$MODE" == install ]]; then
    changed=1
  fi

  if [[ $DRY_RUN -eq 1 ]]; then
    info "dry run: config_changed=$changed"
    return 0
  fi

  if [[ "$MODE" == install ]]; then
    mkdir -p "$(dirname "$dest")"
    if [[ -f "$dest" ]] && cmp -s "$SOURCE_SCRIPT" "$dest"; then
      info "script current: $dest"
    else
      [[ -f "$dest" ]] && info "backed up old script: $(backup "$dest")"
      atomic_write "$SOURCE_SCRIPT" "$dest" 0755
      info "installed script: $dest"
    fi
  fi

  if [[ $changed -eq 1 ]]; then
    mkdir -p "$(dirname "$config")"
    if [[ -f "$config" ]]; then
      local mode
      mode="$(file_mode "$config")"
      info "backed up config: $(backup "$config")"
      atomic_write "$candidate" "$config" "$mode"
    else
      atomic_write "$candidate" "$config" 0600
    fi
    info "updated config: $config"
  else
    info "config current: $config"
  fi
  if [[ "$MODE" == uninstall && -f "$dest" ]]; then
    if cmp -s "$SOURCE_SCRIPT" "$dest"; then
      rm -f "$dest"; info "removed script: $dest"
    else
      warn "$dest differs from this checkout; left in place"
    fi
  fi
  if [[ "$agent" == codex && "$MODE" == install && $changed -eq 1 ]]; then
    info "Codex runs a new or changed hook only after you trust it: open codex, run /hooks, trust '$matcher'"
  fi
}

STATUS=0
if [[ "$AGENTS" == all || "$AGENTS" == claude ]]; then
  process claude "$CLAUDE_DIR/settings.json" "$CLAUDE_DIR/hooks/$HOOK_NAME" AskUserQuestion
fi
if [[ "$AGENTS" == all || "$AGENTS" == codex ]]; then
  process codex "$CODEX_DIR/hooks.json" "$CODEX_DIR/hooks/$HOOK_NAME" request_user_input
fi
exit "$STATUS"
