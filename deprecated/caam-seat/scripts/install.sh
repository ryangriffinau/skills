#!/usr/bin/env bash
# install.sh: wire the caam-seat tool into this machine.
#
# Idempotent. Run it after `npx skills add ryangriffinau/skills --skill caam-seat`
# (or from a checkout of the skills repo). It:
#   1. checks caam (with shallow-spawn) and jq are available;
#   2. puts `caam-seat` on PATH as ~/.local/bin/caam-seat, a shim that execs
#      this skill's script. A stow-managed symlink there is left alone;
#   3. points ntm's [agents] claude and codex templates at `caam-seat launch`,
#      so swarm panes can run on seats. With NTM_CC_SEAT / NTM_COD_SEAT unset the
#      launcher runs the plain CLI, so ordinary swarms are unchanged. The config
#      is backed up first, checked with `ntm config validate` when ntm is
#      installed, and restored if validation fails. A symlinked config belongs to
#      a dotfiles repo and is never written through.
#
# It never creates seats or logs anything in. That is `caam-seat setup`.
#
# Usage: install.sh [--check] [--dry-run] [--no-ntm] [--unwire-ntm] [--bin-dir DIR]
#   --check        verify only; exit non-zero on any gap (doctor mode)
#   --dry-run      print planned writes without performing them
#   --no-ntm       skip the ntm template step
#   --unwire-ntm   remove the caam-seat prefix from the ntm templates, then exit
#   --bin-dir DIR  shim location (default ~/.local/bin)

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOL="$SKILL_DIR/scripts/caam-seat"
BIN_DIR="$HOME/.local/bin"
SHIM_NAME="caam-seat"
NTM_CONFIG_FILE="${NTM_CONFIG:-$HOME/.config/ntm/config.toml}"
INSTALL_CMD="npx skills@latest add ryangriffinau/skills --skill caam-seat -g -y"

CHECK_ONLY=0
DRY_RUN=0
DO_NTM=1
UNWIRE=0
failures=0
planned_writes=0

ok()   { printf 'OK   %s\n' "$*"; }
gap()  { printf 'GAP  %s\n' "$*"; failures=$((failures + 1)); }
act()  { printf 'DO   %s\n' "$*"; }
die()  { printf 'install.sh: error: %s\n' "$*" >&2; exit 2; }
planned() { planned_writes=$((planned_writes + 1)); }
writes_allowed() { [[ "$CHECK_ONLY" -eq 0 && "$DRY_RUN" -eq 0 ]]; }

usage() { sed -n '2,25p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check) CHECK_ONLY=1 ;;
    --dry-run) DRY_RUN=1 ;;
    --no-ntm) DO_NTM=0 ;;
    --unwire-ntm) UNWIRE=1 ;;
    --bin-dir) BIN_DIR="${2:?--bin-dir needs a directory}"; shift ;;
    --bin-dir=*) BIN_DIR="${1#*=}" ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option '$1' (options: --check --dry-run --no-ntm --unwire-ntm --bin-dir DIR)" ;;
  esac
  shift
done

# --- ntm template rewrite ----------------------------------------------------------
# Only the claude and codex keys inside [agents] change, and only their command
# word: `claude ...` -> `caam-seat launch claude ...`, and the `codex` that starts
# the codex command (at the start of the value or right after `{{end}}`).

wire_ntm_file() {
  perl -i -pe '
    if (/^\s*\[([^\]]+)\]\s*$/) { $sec = $1 }
    if (($sec // "") eq "agents" && !/caam-seat launch/) {
      s/^(\s*claude\s*=\s*")claude(\s)/${1}caam-seat launch claude$2/;
      if (/^\s*codex\s*=/) {
        s/^(\s*codex\s*=\s*")codex(\s)/${1}caam-seat launch codex$2/
          or s/\{\{end\}\}codex(\s)/{{end}}caam-seat launch codex$1/;
      }
    }
  ' "$1"
}

unwire_ntm_file() {
  perl -i -pe '
    if (/^\s*\[([^\]]+)\]\s*$/) { $sec = $1 }
    s/caam-seat launch (claude|codex)(\s)/$1$2/g if ($sec // "") eq "agents";
  ' "$1"
}

ntm_template_state() { # prints: wired | wirable | absent | unknown
  local tool="$1" file="$2"
  awk -v tool="$tool" '
    /^[[:space:]]*\[/ { in_agents = ($0 ~ /^[[:space:]]*\[agents\][[:space:]]*$/) }
    in_agents && $0 ~ "^[[:space:]]*" tool "[[:space:]]*=" {
      seen = 1
      if (index($0, "caam-seat launch " tool)) state = "wired"
      else if (tool == "claude" && $0 ~ /^[[:space:]]*claude[[:space:]]*=[[:space:]]*"claude[[:space:]]/) state = "wirable"
      else if (tool == "codex" && ($0 ~ /^[[:space:]]*codex[[:space:]]*=[[:space:]]*"codex[[:space:]]/ || index($0, "{{end}}codex "))) state = "wirable"
      else state = "unknown"
    }
    END { if (!seen) print "absent"; else print state }
  ' "$file"
}

# Run from / so a project's .ntm/config.toml does not join the check.
validate_ntm() {
  command -v ntm >/dev/null 2>&1 || return 0
  command -v jq >/dev/null 2>&1 || return 0
  (cd / && ntm --config "$1" config validate --json 2>/dev/null) | jq -e '.valid == true' >/dev/null 2>&1
}

# --- 1. dependencies ---------------------------------------------------------------
if command -v jq >/dev/null 2>&1; then
  ok "jq present"
else
  gap "jq missing (brew install jq)"
fi
if ! command -v caam >/dev/null 2>&1; then
  gap "caam missing: install https://github.com/Dicklesworthstone/coding_agent_account_manager"
elif ! caam shallow-spawn --help >/dev/null 2>&1; then
  gap "caam has no shallow-spawn command: run 'caam update'"
else
  ok "caam with shallow profiles: $(caam version 2>/dev/null | head -n 1)"
fi
command -v perl >/dev/null 2>&1 || gap "perl missing; needed to edit the ntm config"

# --- unwire mode -------------------------------------------------------------------
if [[ "$UNWIRE" -eq 1 ]]; then
  if [[ ! -f "$NTM_CONFIG_FILE" ]]; then
    ok "no ntm config at $NTM_CONFIG_FILE; nothing to unwire"
    exit 0
  fi
  if [[ -L "$NTM_CONFIG_FILE" ]]; then
    die "$NTM_CONFIG_FILE is a symlink (dotfiles-managed); remove 'caam-seat launch ' from the claude and codex templates in the dotfiles copy"
  fi
  if writes_allowed; then
    cp -p "$NTM_CONFIG_FILE" "$NTM_CONFIG_FILE.bak.pre-caam-seat-unwire"
    unwire_ntm_file "$NTM_CONFIG_FILE"
    ok "ntm templates unwired (backup: $NTM_CONFIG_FILE.bak.pre-caam-seat-unwire)"
  else
    act "remove 'caam-seat launch ' from the [agents] templates in $NTM_CONFIG_FILE"
  fi
  exit 0
fi

# --- 2. shim on PATH -------------------------------------------------------------
SHIM="$BIN_DIR/$SHIM_NAME"
write_shim() {
  mkdir -p "$BIN_DIR"
  cat >"$SHIM" <<SHIM_EOF
#!/usr/bin/env bash
# caam-seat shim: runs the tool installed by the caam-seat skill
# (ryangriffinau/skills). See the skill's SKILL.md.
TOOL="\${CAAM_SEAT_BIN:-$TOOL}"
if [ ! -f "\$TOOL" ]; then
  printf 'caam-seat: tool not found at %s\n' "\$TOOL" >&2
  printf 'install it with: %s\n' "$INSTALL_CMD" >&2
  printf 'then run: bash ~/.agents/skills/caam-seat/scripts/install.sh\n' >&2
  exit 3
fi
exec bash "\$TOOL" "\$@"
SHIM_EOF
  chmod +x "$SHIM"
}

if [[ -L "$SHIM" ]]; then
  if [[ -x "$SHIM" ]]; then
    ok "shim is a symlink (dotfiles-managed): $SHIM -> $(readlink "$SHIM")"
  else
    gap "shim symlink is broken: $SHIM -> $(readlink "$SHIM")"
  fi
elif [[ -x "$SHIM" ]] && grep -q 'caam-seat shim' "$SHIM" 2>/dev/null; then
  if grep -qF "$TOOL" "$SHIM"; then
    ok "shim present: $SHIM -> $TOOL"
  elif writes_allowed; then
    write_shim
    ok "shim repointed: $SHIM -> $TOOL"
  else
    act "repoint shim $SHIM at $TOOL"
    planned
  fi
elif [[ -e "$SHIM" ]]; then
  gap "$SHIM exists but is not the caam-seat shim; inspect it, move it aside, then rerun"
elif writes_allowed; then
  write_shim
  ok "shim written: $SHIM -> $TOOL"
else
  act "write shim $SHIM (exec bash $TOOL)"
  planned
fi
case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) gap "$BIN_DIR is not on PATH; add it to your shell profile so ntm panes can find caam-seat" ;;
esac

# --- 3. ntm templates -------------------------------------------------------------
if [[ "$DO_NTM" -eq 0 ]]; then
  ok "ntm step skipped (--no-ntm)"
elif [[ ! -f "$NTM_CONFIG_FILE" ]]; then
  ok "no ntm config at $NTM_CONFIG_FILE; skipping ntm wiring (single-session use still works)"
else
  claude_state="$(ntm_template_state claude "$NTM_CONFIG_FILE")"
  codex_state="$(ntm_template_state codex "$NTM_CONFIG_FILE")"
  needs_write=0
  for pair in "claude:$claude_state" "codex:$codex_state"; do
    tool="${pair%%:*}"
    state="${pair#*:}"
    case "$state" in
      wired) ok "ntm $tool template calls caam-seat launch $tool" ;;
      wirable) needs_write=1 ;;
      absent) gap "ntm has no [agents] $tool template, so its panes cannot use seats. Add one to $NTM_CONFIG_FILE, for example:
       $tool = \"caam-seat launch $tool$([[ "$tool" == claude ]] && printf ' --dangerously-skip-permissions' || printf ' --dangerously-bypass-approvals-and-sandbox')\"" ;;
      *) gap "ntm $tool template has a shape this installer does not rewrite; put 'caam-seat launch ' before the $tool command in $NTM_CONFIG_FILE" ;;
    esac
  done
  if [[ "$needs_write" -eq 1 ]]; then
    if [[ -L "$NTM_CONFIG_FILE" ]]; then
      gap "$NTM_CONFIG_FILE is a symlink (dotfiles-managed); put 'caam-seat launch ' before the claude/codex command in the dotfiles copy"
    elif writes_allowed; then
      backup="$NTM_CONFIG_FILE.bak.pre-caam-seat"
      [[ -e "$backup" ]] || cp -p "$NTM_CONFIG_FILE" "$backup"
      staged="$(mktemp "${TMPDIR:-/tmp}/ntm-config.XXXXXX")"
      cp -p "$NTM_CONFIG_FILE" "$staged"
      wire_ntm_file "$staged"
      if ! validate_ntm "$staged" && validate_ntm "$NTM_CONFIG_FILE"; then
        rm -f "$staged"
        gap "ntm rejected the rewritten config, so $NTM_CONFIG_FILE was left unchanged; edit the templates by hand"
      else
        cat "$staged" >"$NTM_CONFIG_FILE"
        rm -f "$staged"
        for tool in claude codex; do
          if [[ "$(ntm_template_state "$tool" "$NTM_CONFIG_FILE")" == "wired" ]]; then
            ok "ntm $tool template now calls caam-seat launch $tool"
          fi
        done
        ok "ntm config backup: $backup"
      fi
    else
      act "prefix the ntm claude/codex templates in $NTM_CONFIG_FILE with 'caam-seat launch' (backup first)"
      planned
    fi
  fi
fi

# --- summary -------------------------------------------------------------------------
if [[ "$CHECK_ONLY" -eq 1 && "$planned_writes" -gt 0 ]]; then
  failures=$((failures + planned_writes))
fi
if ((failures > 0)); then
  printf '\n%d gap(s).\n' "$failures"
  exit 1
fi
if [[ "$DRY_RUN" -eq 1 && "$planned_writes" -gt 0 ]]; then
  printf '\n%d planned change(s). Rerun without --dry-run to apply.\n' "$planned_writes"
  exit 0
fi
printf '\ncaam-seat is installed. Next: caam-seat status\n'
