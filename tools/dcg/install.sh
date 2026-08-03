#!/usr/bin/env bash
# Minimal installer for teammates who do not use Ryan's stow-managed dotfiles.

set -euo pipefail

PROFILE="full"
CONFIG_FILE="$HOME/.config/dcg/config.toml"
DRY_RUN=0
DCG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# DCG expands this conventional config glob; it must remain a literal tilde.
# shellcheck disable=SC2088
CUSTOM_PATH='~/.config/dcg/packs/*.yaml'
REQUIRED_GUARDS=(
  core
  local.agents_skills_guard
  local.no_squash_merge
  local.convex_prod_deploy_guard
  local.no_bypass_prepush
  local.no_worktrees
)

die() { printf 'install.sh: error: %s\n' "$*" >&2; exit 1; }
info() { printf '  %s\n' "$*"; }

usage() {
  cat <<'USAGE'
usage: ./install.sh [--profile NAME] [--config PATH] [--dry-run]

Copies the selected profile's local packs into the conventional DCG user pack
directory and additively enables the profile. This is for non-stow users only.

  --profile NAME  profile under profiles/ (default: full)
  --config PATH   alternate user config path (primarily for isolated testing)
  --dry-run       validate and report without writing
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) PROFILE="${2:?--profile requires a name}"; shift 2 ;;
    --config) CONFIG_FILE="${2:?--config requires a path}"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

PROFILE_FILE="$DCG_DIR/profiles/$PROFILE.toml"
PACK_DIR="$(dirname "$CONFIG_FILE")/packs"
[[ -f "$PROFILE_FILE" ]] || die "unknown profile: $PROFILE"
[[ ! -L "$CONFIG_FILE" ]] || die "$CONFIG_FILE is a symlink (likely stow-managed); refusing to detach it. Use $DCG_DIR/sync-to-stow.sh instead."
command -v dcg >/dev/null 2>&1 || die "dcg is not installed; install and hook DCG using its own installer first"
command -v python3 >/dev/null 2>&1 || die "python3.11+ is required"
python3 -c 'import tomllib' >/dev/null 2>&1 || die "python3.11+ with tomllib is required"

PROFILE_PACKS="$(python3 - "$PROFILE_FILE" <<'PY'
import sys, tomllib
with open(sys.argv[1], "rb") as handle:
    profile = tomllib.load(handle)
extra = set(profile) - {"schema_version", "name", "packs"}
if extra:
    sys.exit(f"unknown profile keys: {sorted(extra)}")
if profile.get("schema_version") != 1:
    sys.exit(f"unsupported profile schema: {profile.get('schema_version')!r}")
enabled = profile.get("packs", {}).get("enabled")
if not isinstance(enabled, list) or not enabled or not all(isinstance(item, str) for item in enabled):
    sys.exit("[packs].enabled must be a non-empty string array")
if len(enabled) != len(set(enabled)):
    sys.exit("profile contains duplicate enabled packs")
print("\n".join(enabled))
PY
)" || die "could not parse profile: $PROFILE_FILE"

for guard in "${REQUIRED_GUARDS[@]}"; do
  grep -qxF "$guard" <<<"$PROFILE_PACKS" || die "profile violates safety invariant; missing $guard"
done

selected_packs=()
merge_args=()
while IFS= read -r pack; do
  [[ -n "$pack" ]] || continue
  merge_args+=(--enabled "$pack")
  if [[ "$pack" == local.* ]]; then
    selected_packs+=("$DCG_DIR/packs/$pack.yaml")
  fi
done <<<"$PROFILE_PACKS"

for source in "${selected_packs[@]}"; do
  [[ -f "$source" && ! -L "$source" ]] || die "profile pack is missing or not a regular file: $source"
  dcg pack validate "$source" >/dev/null || die "pack validation failed: $source"
done

# The behavior suite makes its own temporary config from the checkout. Explicitly
# discard a caller's DCG_CONFIG so candidate/live policy cannot mask pack defects.
env -u DCG_CONFIG "$DCG_DIR/test/verify.sh" >/dev/null

work_dir="$(mktemp -d "${TMPDIR:-/tmp}/dcg-install.XXXXXX")"
trap 'rm -rf "$work_dir"' EXIT INT TERM HUP
candidate="$work_dir/config.toml"
python3 "$DCG_DIR/lib/merge-config.py" "$CONFIG_FILE" "$candidate" \
  --custom-path "$CUSTOM_PATH" "${merge_args[@]}" \
  || die "could not merge $CONFIG_FILE"

# Prove that this DCG release accepts the candidate before copying or activating
# anything. Missing destination packs are inert until the config is installed.
DCG_CONFIG="$candidate" dcg config --format json >/dev/null \
  || die "DCG rejected the candidate config"

config_changed=1
[[ -f "$CONFIG_FILE" ]] && cmp -s "$CONFIG_FILE" "$candidate" && config_changed=0
changed_packs=()
for source in "${selected_packs[@]}"; do
  destination="$PACK_DIR/$(basename "$source")"
  [[ ! -L "$destination" ]] || die "refusing to replace symlinked pack: $destination"
  if [[ ! -f "$destination" ]] || ! cmp -s "$source" "$destination"; then
    changed_packs+=("$(basename "$source")")
  fi
done

info "profile: $PROFILE"
info "config: $CONFIG_FILE"
info "packs selected: ${#selected_packs[@]}"
if [[ $DRY_RUN -eq 1 ]]; then
  info "dry run: config_changed=$config_changed packs_changed=${#changed_packs[@]}"
  exit 0
fi
if [[ $config_changed -eq 0 && ${#changed_packs[@]} -eq 0 ]]; then
  info "already current"
  exit 0
fi

mkdir -p "$(dirname "$CONFIG_FILE")" "$PACK_DIR"
[[ ! -L "$CONFIG_FILE" ]] || die "$CONFIG_FILE became a symlink during installation; refusing to write"

for source in "${selected_packs[@]}"; do
  destination="$PACK_DIR/$(basename "$source")"
  [[ ! -L "$destination" ]] || die "refusing to replace symlinked pack: $destination"
  if [[ ! -f "$destination" ]] || ! cmp -s "$source" "$destination"; then
    temporary="$(mktemp "$PACK_DIR/.$(basename "$source").XXXXXX")"
    cp "$source" "$temporary"
    chmod 0644 "$temporary"
    mv -f "$temporary" "$destination"
    info "installed $(basename "$source")"
  fi
done

if [[ $config_changed -eq 1 ]]; then
  backup=""
  if [[ -f "$CONFIG_FILE" ]]; then
    backup="$CONFIG_FILE.bak.$(date +%s).$$"
    cp -p "$CONFIG_FILE" "$backup"
  fi
  temporary="$(mktemp "$(dirname "$CONFIG_FILE")/.config.toml.XXXXXX")"
  cp "$candidate" "$temporary"
  if [[ -f "$CONFIG_FILE" ]]; then
    config_mode="$(stat -f '%Lp' "$CONFIG_FILE" 2>/dev/null || stat -c '%a' "$CONFIG_FILE")"
    chmod "$config_mode" "$temporary"
  else
    chmod 0600 "$temporary"
  fi
  mv -f "$temporary" "$CONFIG_FILE"
  info "updated config.toml${backup:+ (backup: $backup)}"
fi

info "installation complete"
