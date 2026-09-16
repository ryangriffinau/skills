#!/usr/bin/env bash
# install.sh — wire the convex-prod-query tool into this machine.
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
#   4. checks the dcg pack local.convex_prod_deploy_guard is v3.5.0+ (the version
#      that carves the tool out and points agents at it) and prints the fix if not.
#
# Usage: install.sh [--check] [--dry-run] [--no-protect-dcg] [--bin-dir DIR]
#   --check           verify only; exit non-zero on any gap (doctor mode)
#   --dry-run         print planned writes without performing them
#   --no-protect-dcg  skip the deny rules for ~/.config/dcg and the dotfiles copy
#   --bin-dir DIR     shim location (default ~/.local/bin)

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOL="$SKILL_DIR/scripts/convex-prod-query"
BIN_DIR="${HOME}/.local/bin"
SHIM_NAME="convex-prod-query"
CLAUDE_SETTINGS="${CLAUDE_SETTINGS:-$HOME/.claude/settings.json}"
DCG_PACK="${DCG_PACK:-$HOME/.config/dcg/packs/local.convex_prod_deploy_guard.yaml}"
REQUIRED_PACK_VERSION="3.5.0"
INSTALL_CMD="npx skills@latest add ryangriffinau/skills --skill convex-prod-query -g -y"

CHECK_ONLY=0
DRY_RUN=0
PROTECT_DCG=1
failures=0

ok()   { printf 'OK   %s\n' "$*"; }
gap()  { printf 'GAP  %s\n' "$*"; failures=$((failures + 1)); }
act()  { printf 'DO   %s\n' "$*"; }
die()  { printf 'install.sh: error: %s\n' "$*" >&2; exit 1; }

usage() { sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check) CHECK_ONLY=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    --no-protect-dcg) PROTECT_DCG=0; shift ;;
    --bin-dir) BIN_DIR="${2:?--bin-dir requires a path}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

writes_allowed() { [[ "$CHECK_ONLY" -eq 0 && "$DRY_RUN" -eq 0 ]]; }

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
    [[ "$CHECK_ONLY" -eq 1 ]] && failures=$((failures + 1))
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
    [[ "$CHECK_ONLY" -eq 1 ]] && failures=$((failures + 1))
  fi
else
  gap "python3 missing — cannot merge Claude Code deny rules (add them by hand: ${rules[*]})"
fi

# --- 4. dcg pack currency -------------------------------------------------------
version_ge() { [[ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -1)" == "$2" ]]; }
if ! command -v dcg >/dev/null 2>&1; then
  gap "dcg not installed — the tool works without it, but the guard that points agents at it is missing (https://github.com/Dicklesworthstone/destructive_command_guard)"
elif [[ ! -f "$DCG_PACK" ]]; then
  gap "dcg pack local.convex_prod_deploy_guard not installed — install Ryan's packs: ryangriffinau/skills tools/dcg/install.sh (teammates) or ./dot link (dotfiles)"
else
  pack_version="$(sed -n 's/^version:[[:space:]]*//p' "$DCG_PACK" | head -1)"
  if version_ge "$pack_version" "$REQUIRED_PACK_VERSION"; then
    ok "dcg pack local.convex_prod_deploy_guard $pack_version"
  else
    gap "dcg pack local.convex_prod_deploy_guard is $pack_version (< $REQUIRED_PACK_VERSION) — update from ryangriffinau/skills tools/dcg"
  fi
fi

# --- summary ----------------------------------------------------------------------
if ((failures > 0)); then
  printf '\n%d gap(s). Install the skill with: %s\n' "$failures" "$INSTALL_CMD"
  exit 1
fi
printf '\nconvex-prod-query is ready. Try: convex-prod-query --list users\n'
