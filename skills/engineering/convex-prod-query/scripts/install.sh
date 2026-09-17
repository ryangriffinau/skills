#!/usr/bin/env bash
# install.sh — wire the convex-prod-query tool into this machine.
#
# The tool and the dcg pack local.convex_prod_deploy_guard are a PAIR: the pack
# gates prod-targeted `convex run` and points agents at this tool, and the tool
# is what makes that gate liveable. This installer therefore ships both, so a
# machine can never end up with one and not the other.
#
# Idempotent. Run it after `npx skills add ryangriffinau/skills --skill convex-prod-query`
# (or from a checkout of the skills repo). It:
#   1. checks bun is available (the tool is a Bun script);
#   2. puts `convex-prod-query` on PATH as ~/.local/bin/convex-prod-query — a shim
#      that execs this skill's script. On a stow-managed machine (Ryan's dotfiles)
#      the shim already exists as a stow symlink and is left alone;
#   3. adds Claude Code `permissions.deny` Edit rules so agents cannot rewrite the
#      tool, the shim, or the dcg configuration through the file tools
#      (Codex is covered by its workspace-write sandbox);
#   4. installs the bundled dcg pack (dcg/local.convex_prod_deploy_guard.yaml) into
#      the user pack dir and unions it into [packs].enabled, additively. It never
#      replaces a symlinked pack or config — those are stow-managed and belong to
#      the dotfiles repo — and reports the sync command instead.
#
# tools/dcg in this repo remains the source of truth for pack content and the
# multi-pack installer; tests/dcg-pack-sync.test.sh fails if the bundled copies drift.
#
# Usage: install.sh [--check] [--dry-run] [--no-protect-dcg] [--no-install-pack] [--bin-dir DIR]
#   --check            verify only; exit non-zero on any gap (doctor mode)
#   --dry-run          print planned writes without performing them
#   --no-protect-dcg   skip the deny rules for ~/.config/dcg and the dotfiles copy
#   --no-install-pack  skip installing/enabling the companion dcg pack
#   --bin-dir DIR      shim location (default ~/.local/bin)

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOL="$SKILL_DIR/scripts/convex-prod-query"
BUNDLED_PACK="$SKILL_DIR/dcg/local.convex_prod_deploy_guard.yaml"
MERGE_CONFIG="$SKILL_DIR/dcg/merge-config.py"
BIN_DIR="${HOME}/.local/bin"
SHIM_NAME="convex-prod-query"
CLAUDE_SETTINGS="${CLAUDE_SETTINGS:-$HOME/.claude/settings.json}"
DEFAULT_DCG_CONFIG="$HOME/.config/dcg/config.toml"
DCG_CONFIG_FILE="${DCG_CONFIG_FILE:-$DEFAULT_DCG_CONFIG}"
PACK_ID="local.convex_prod_deploy_guard"
REQUIRED_PACK_VERSION="3.5.0"
INSTALL_CMD="npx skills@latest add ryangriffinau/skills --skill convex-prod-query -g -y"

CHECK_ONLY=0
DRY_RUN=0
PROTECT_DCG=1
INSTALL_PACK=1
failures=0

ok()   { printf 'OK   %s\n' "$*"; }
gap()  { printf 'GAP  %s\n' "$*"; failures=$((failures + 1)); }
act()  { printf 'DO   %s\n' "$*"; }
die()  { printf 'install.sh: error: %s\n' "$*" >&2; exit 1; }

usage() { sed -n '2,32p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check) CHECK_ONLY=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    --no-protect-dcg) PROTECT_DCG=0; shift ;;
    --no-install-pack) INSTALL_PACK=0; shift ;;
    --bin-dir) BIN_DIR="${2:?--bin-dir requires a path}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

writes_allowed() { [[ "$CHECK_ONLY" -eq 0 && "$DRY_RUN" -eq 0 ]]; }
planned() { [[ "$CHECK_ONLY" -eq 1 ]] && failures=$((failures + 1)); return 0; }
version_ge() { [[ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -1)" == "$2" ]]; }
# Tolerant of a missing file: callers treat an empty version as "not installed".
pack_version() {
  [[ -f "$1" ]] || return 0
  sed -n 's/^version:[[:space:]]*//p' "$1" 2>/dev/null | head -1 || true
}

# --- 1. runtime ---------------------------------------------------------------
if command -v bun >/dev/null 2>&1; then
  ok "bun $(bun --version 2>/dev/null)"
else
  gap "bun missing — install from https://bun.sh (curl -fsSL https://bun.sh/install | bash)"
fi

[[ -f "$TOOL" ]] || die "tool not found at $TOOL (run this script from an installed skill or a checkout)"
if [[ -x "$TOOL" ]]; then
  ok "tool $TOOL"
else
  if writes_allowed; then chmod +x "$TOOL"; ok "tool made executable: $TOOL"; else gap "tool not executable: $TOOL"; fi
fi

# --- 2. shim on PATH ------------------------------------------------------------
SHIM="$BIN_DIR/$SHIM_NAME"
write_shim() {
  mkdir -p "$BIN_DIR"
  cat >"$SHIM" <<'SHIM_EOF'
#!/usr/bin/env bash
# convex-prod-query shim — runs the tool installed by the convex-prod-query skill
# (ryangriffinau/skills). Read-only Convex query runner; see the skill's SKILL.md.
set -euo pipefail
TOOL="${CONVEX_PROD_QUERY_BIN:-$HOME/.agents/skills/convex-prod-query/scripts/convex-prod-query}"
if [[ ! -f "$TOOL" ]]; then
  printf 'convex-prod-query: skill not installed at %s\n' "$TOOL" >&2
  printf 'install it with: npx skills@latest add ryangriffinau/skills --skill convex-prod-query -g -y\n' >&2
  exit 2
fi
command -v bun >/dev/null 2>&1 || { printf 'convex-prod-query: bun is required (https://bun.sh)\n' >&2; exit 2; }
exec bun "$TOOL" "$@"
SHIM_EOF
  chmod +x "$SHIM"
}

if [[ -L "$SHIM" ]]; then
  target="$(readlink "$SHIM")"
  if [[ -x "$SHIM" ]]; then
    ok "shim is a symlink (stow/dotfiles-managed): $SHIM -> $target"
  else
    gap "shim symlink is broken: $SHIM -> $target (run 'cd ~/.dotfiles && ./dot link')"
  fi
elif [[ -x "$SHIM" ]] && grep -q 'convex-prod-query shim' "$SHIM" 2>/dev/null; then
  ok "shim present: $SHIM"
elif [[ -e "$SHIM" ]]; then
  gap "$SHIM exists but is not the convex-prod-query shim — inspect and remove it, then rerun"
else
  if writes_allowed; then
    write_shim
    ok "shim written: $SHIM"
  else
    act "write shim $SHIM (exec bun \$HOME/.agents/skills/convex-prod-query/scripts/convex-prod-query)"
    planned
  fi
fi

case ":$PATH:" in
  *":$BIN_DIR:"*) ok "$BIN_DIR is on PATH" ;;
  *) gap "$BIN_DIR is not on PATH — add 'export PATH=\"$BIN_DIR:\$PATH\"' to your shell profile" ;;
esac

# --- 3. Claude Code deny rules --------------------------------------------------
# Edit deny rules cover the Edit and Write tools and the file commands Claude Code
# recognises in Bash (sed -i, tee, > redirects). ~/ paths work in user settings.
rules=(
  "Edit(~/.agents/skills/convex-prod-query/**)"
  "Edit(~/.local/bin/convex-prod-query)"
)
if [[ "$PROTECT_DCG" -eq 1 ]]; then
  rules+=(
    "Edit(~/.config/dcg/**)"
    "Edit(~/.dotfiles/stow/agents/.config/dcg/**)"
  )
fi

if command -v python3 >/dev/null 2>&1; then
  missing="$(python3 - "$CLAUDE_SETTINGS" "${rules[@]}" <<'PY'
import json, os, sys
path, rules = sys.argv[1], sys.argv[2:]
deny = []
if os.path.exists(path):
    try:
        with open(path) as fh:
            deny = json.load(fh).get("permissions", {}).get("deny", []) or []
    except (json.JSONDecodeError, AttributeError):
        print("__INVALID__"); sys.exit(0)
print("\n".join(r for r in rules if r not in deny))
PY
)"
  if [[ "$missing" == "__INVALID__" ]]; then
    gap "$CLAUDE_SETTINGS is not valid JSON; fix it, then rerun"
  elif [[ -z "$missing" ]]; then
    ok "Claude Code deny rules present in $CLAUDE_SETTINGS"
  elif writes_allowed; then
    python3 - "$CLAUDE_SETTINGS" "${rules[@]}" <<'PY'
import json, os, sys
path, rules = sys.argv[1], sys.argv[2:]
data = {}
if os.path.exists(path):
    with open(path) as fh:
        data = json.load(fh)
perms = data.setdefault("permissions", {})
deny = perms.setdefault("deny", [])
for r in rules:
    if r not in deny:
        deny.append(r)
os.makedirs(os.path.dirname(path), exist_ok=True)
tmp = path + ".tmp"
with open(tmp, "w") as fh:
    json.dump(data, fh, indent=2)
    fh.write("\n")
os.replace(tmp, path)
PY
    ok "Claude Code deny rules added to $CLAUDE_SETTINGS:"
    printf '       %s\n' $missing
  else
    act "add to $CLAUDE_SETTINGS permissions.deny:"
    printf '       %s\n' $missing
    planned
  fi
else
  gap "python3 missing — cannot merge Claude Code deny rules (add them by hand: ${rules[*]})"
fi

# --- 4. companion dcg pack ------------------------------------------------------
# The pack is what makes agents reach for this tool: it confirms prod-targeted
# `convex run` and names `prod:query` in the message. Installing them together is
# the point of this section.
PACK_DIR="$(dirname "$DCG_CONFIG_FILE")/packs"
LIVE_PACK="$PACK_DIR/$PACK_ID.yaml"
if [[ "$DCG_CONFIG_FILE" == "$DEFAULT_DCG_CONFIG" ]]; then
  # DCG expands this conventional user-config glob; keep the literal tilde.
  # shellcheck disable=SC2088
  CUSTOM_PATH='~/.config/dcg/packs/*.yaml'
else
  CUSTOM_PATH="$PACK_DIR/*.yaml"
fi

pack_enabled() {
  python3 - "$DCG_CONFIG_FILE" "$PACK_ID" <<'PY' 2>/dev/null
import os, sys, tomllib
path, pack = sys.argv[1], sys.argv[2]
if not os.path.exists(path):
    sys.exit(1)
with open(path, "rb") as fh:
    data = tomllib.load(fh)
sys.exit(0 if pack in (data.get("packs", {}).get("enabled") or []) else 1)
PY
}

if [[ "$INSTALL_PACK" -eq 0 ]]; then
  ok "skipping the companion dcg pack (--no-install-pack)"
elif ! command -v dcg >/dev/null 2>&1; then
  gap "dcg not installed — the tool works without it, but the guard that points agents at it does not exist. Install DCG: https://github.com/Dicklesworthstone/destructive_command_guard"
elif [[ ! -f "$BUNDLED_PACK" ]]; then
  gap "bundled pack missing from the skill: $BUNDLED_PACK (reinstall: $INSTALL_CMD)"
elif ! dcg pack validate "$BUNDLED_PACK" >/dev/null 2>&1; then
  gap "this DCG release rejects the bundled pack: dcg pack validate '$BUNDLED_PACK'"
else
  bundled_version="$(pack_version "$BUNDLED_PACK")"
  live_version="$(pack_version "$LIVE_PACK")"

  # 4a. pack file
  if [[ -L "$LIVE_PACK" ]]; then
    # stow-managed: the dotfiles repo owns this file. Never write through it.
    if [[ -n "$live_version" ]] && version_ge "$live_version" "$REQUIRED_PACK_VERSION"; then
      ok "dcg pack $PACK_ID $live_version (stow-managed symlink)"
    else
      gap "dcg pack $PACK_ID is ${live_version:-unreadable} (< $REQUIRED_PACK_VERSION) and stow-managed — update it in the skills repo: tools/dcg/sync-to-stow.sh, then 'cd ~/.dotfiles && stow agents'"
    fi
  elif [[ -f "$LIVE_PACK" ]] && [[ -n "$live_version" ]] && version_ge "$live_version" "$bundled_version"; then
    ok "dcg pack $PACK_ID $live_version"
  elif writes_allowed; then
    mkdir -p "$PACK_DIR"
    cp "$BUNDLED_PACK" "$LIVE_PACK"
    ok "dcg pack $PACK_ID installed ($bundled_version) -> $LIVE_PACK"
  else
    act "install dcg pack $PACK_ID $bundled_version -> $LIVE_PACK"
    planned
  fi

  # 4b. enabled list
  if pack_enabled; then
    ok "dcg pack $PACK_ID is enabled in $DCG_CONFIG_FILE"
  elif [[ -L "$DCG_CONFIG_FILE" ]]; then
    gap "$DCG_CONFIG_FILE is a stow symlink — add \"$PACK_ID\" to [packs].enabled in the dotfiles copy, then 'cd ~/.dotfiles && stow agents'"
  elif [[ ! -f "$MERGE_CONFIG" ]]; then
    gap "config merge helper missing: $MERGE_CONFIG (reinstall: $INSTALL_CMD)"
  elif writes_allowed; then
    work_dir="$(mktemp -d "${TMPDIR:-/tmp}/convex-prod-query-install.XXXXXX")"
    candidate="$work_dir/config.toml"
    if ! python3 "$MERGE_CONFIG" "$DCG_CONFIG_FILE" "$candidate" \
         --custom-path "$CUSTOM_PATH" --enabled core --enabled "$PACK_ID"; then
      rm -rf "$work_dir"
      die "could not merge $DCG_CONFIG_FILE"
    fi
    # Prove this DCG release accepts the candidate before activating it.
    if ! DCG_CONFIG="$candidate" dcg config --format json >/dev/null 2>&1; then
      rm -rf "$work_dir"
      die "DCG rejected the merged config; $DCG_CONFIG_FILE left untouched"
    fi
    mkdir -p "$(dirname "$DCG_CONFIG_FILE")"
    if [[ -f "$DCG_CONFIG_FILE" ]]; then
      backup="$DCG_CONFIG_FILE.bak.$(date +%Y%m%d%H%M%S)"
      cp "$DCG_CONFIG_FILE" "$backup"
      ok "backed up $DCG_CONFIG_FILE -> $backup"
    fi
    cp "$candidate" "$DCG_CONFIG_FILE"
    rm -rf "$work_dir"
    ok "enabled $PACK_ID in $DCG_CONFIG_FILE (existing packs preserved)"
  else
    act "enable $PACK_ID in $DCG_CONFIG_FILE ([packs].enabled, additive)"
    planned
  fi
fi

# --- 5. Codex sandbox network -----------------------------------------------------
# Codex runs commands under a seatbelt sandbox that blocks network egress by
# default in workspace-write mode, so the tool's HTTPS call to *.convex.cloud
# fails there and every prod read costs an approval prompt. The fix is one
# config key. This step only reports; config.toml is personal and never written.
CODEX_CONFIG="${CODEX_CONFIG:-$HOME/.codex/config.toml}"
if [[ ! -f "$CODEX_CONFIG" ]]; then
  ok "Codex not configured on this machine (no $CODEX_CONFIG); skipping its sandbox check"
elif ! command -v python3 >/dev/null 2>&1; then
  gap "python3 missing — cannot read $CODEX_CONFIG; ensure [sandbox_workspace_write] network_access = true"
else
  codex_net="$(python3 - "$CODEX_CONFIG" <<'PY' 2>/dev/null || echo unreadable
import sys, tomllib
with open(sys.argv[1], "rb") as fh:
    d = tomllib.load(fh)
mode = d.get("sandbox_mode", "")
net = (d.get("sandbox_workspace_write") or {}).get("network_access", False)
print(f"{mode}:{'on' if net else 'off'}")
PY
)"
  case "$codex_net" in
    workspace-write:on|danger-full-access:*) ok "Codex sandbox allows network egress ($codex_net)" ;;
    unreadable) gap "$CODEX_CONFIG is not valid TOML; fix it, then rerun" ;;
    *) gap "Codex sandbox blocks network egress ($codex_net), so convex-prod-query cannot reach *.convex.cloud from a Codex session without an approval each time. Add to $CODEX_CONFIG:
       [sandbox_workspace_write]
       network_access = true" ;;
  esac
fi

# --- summary ----------------------------------------------------------------------
if ((failures > 0)); then
  printf '\n%d gap(s). Install the skill with: %s\n' "$failures" "$INSTALL_CMD"
  exit 1
fi
printf '\nconvex-prod-query is ready. Try: convex-prod-query --list users\n'
