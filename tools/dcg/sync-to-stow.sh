#!/usr/bin/env bash
# sync-to-stow.sh — publish this repo's DCG packs into the stow-managed dotfiles.
#
# ARCHITECTURE (see PLAN.md §2.0.6). This repo is the SOURCE OF TRUTH for pack
# content; stow is the DELIVERY mechanism:
#
#     tools/dcg/packs/*.yaml      (source, versioned, reviewed)
#          |  sync-to-stow.sh     (this script: validate + copy)
#          v
#     ~/.dotfiles/stow/agents/.config/dcg/packs/*.yaml
#          |  stow agents         (symlinks; travels to every machine)
#          v
#     ~/.config/dcg/packs/*.yaml  -> DCG loads via custom_paths glob
#
# We deliberately do NOT write ~/.config/dcg/config.toml: it is a symlink into
# the dotfiles repo, and writing it atomically (temp + rename) would REPLACE the
# symlink with a real file and silently detach it from stow. The enabled list is
# hand-maintained in the dotfiles repo; this script only VERIFIES it and reports
# drift.
#
# SCOPE FENCE (PLAN.md §2.0.1): configuration only. Never touches the DCG binary,
# its agent hooks, built-in packs, the allowlist, or pending_exceptions.jsonl.
#
# RULE 1: this script never deletes anything. It copies and it reports.
#
# Usage:
#   ./sync-to-stow.sh [--profile <name>] [--stow-dir <path>] [--dry-run] [--check]
#
#   --check    verify only; exit non-zero on any drift (for CI / pre-commit)
#   --dry-run  print planned actions, write nothing

set -euo pipefail

PROFILE="full"
STOW_DIR="${DCG_STOW_DIR:-$HOME/.dotfiles/stow/agents/.config/dcg}"
DRY_RUN=0
CHECK_ONLY=0

REPO_DCG="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIVE_CONFIG="$HOME/.config/dcg/config.toml"
LIVE_PACKS="$HOME/.config/dcg/packs"

# Every profile must carry these. Mirrors the invariant asserted in the profiles
# themselves; duplicated here so a hand-edited profile cannot quietly drop one.
REQUIRED_GUARDS=(
  core
  local.agents_skills_guard
  local.no_squash_merge
  local.convex_prod_deploy_guard
  local.no_bypass_prepush
  local.no_worktrees
)

die() { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }
warn() { printf '\033[33mwarn:\033[0m %s\n' "$*" >&2; }
info() { printf '  %s\n' "$*"; }
head2() { printf '\n\033[1m%s\033[0m\n' "$*"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)   PROFILE="${2:?--profile requires a name}"; shift 2 ;;
    --stow-dir)  STOW_DIR="${2:?--stow-dir requires a path}"; shift 2 ;;
    --dry-run)   DRY_RUN=1; shift ;;
    --check)     CHECK_ONLY=1; shift ;;
    -h|--help)   sed -n '2,32p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *)           die "unknown argument: $1 (see --help)" ;;
  esac
done

PROFILE_FILE="$REPO_DCG/profiles/$PROFILE.toml"
[[ -f "$PROFILE_FILE" ]] || die "no such profile: $PROFILE ($PROFILE_FILE)"

# ---------------------------------------------------------------- preflight
head2 "Preflight"
command -v dcg >/dev/null 2>&1 \
  || die "dcg not found on PATH. Install it with DCG's own installer first — this
       script only ships pack configuration and never installs or hooks DCG."
info "dcg: $(command -v dcg) ($(dcg --version 2>/dev/null | head -1))"
command -v python3 >/dev/null 2>&1 || die "python3 required (TOML parsing)"
info "profile: $PROFILE ($PROFILE_FILE)"
info "stow dir: $STOW_DIR"

# ------------------------------------------------- parse profile + invariant
# Structural TOML parse — never grep. A comment or stray string must not be able
# to satisfy the safety invariant.
PROFILE_PACKS="$(python3 - "$PROFILE_FILE" <<'PY'
import sys, tomllib
ALLOWED = {"schema_version", "name", "packs"}
with open(sys.argv[1], "rb") as fh:
    doc = tomllib.load(fh)
extra = set(doc) - ALLOWED
if extra:
    sys.exit(f"profile has unknown top-level keys: {sorted(extra)}")
if doc.get("schema_version") != 1:
    sys.exit(f"unsupported profile schema_version: {doc.get('schema_version')!r}")
enabled = doc.get("packs", {}).get("enabled", [])
if not enabled:
    sys.exit("profile has no [packs].enabled entries")
dupes = sorted({p for p in enabled if enabled.count(p) > 1})
if dupes:
    sys.exit(f"profile lists duplicate packs: {dupes}")
print("\n".join(enabled))
PY
)" || die "profile parse failed (see above)"

missing_guards=()
for g in "${REQUIRED_GUARDS[@]}"; do
  grep -qxF "$g" <<<"$PROFILE_PACKS" || missing_guards+=("$g")
done
if [[ ${#missing_guards[@]} -gt 0 ]]; then
  die "SAFETY INVARIANT VIOLATED — profile '$PROFILE' is missing: ${missing_guards[*]}
       Profiles scope which DOMAIN packs load; they are never a way to reduce
       safety. Add the guard(s) back, or fix REQUIRED_GUARDS if a pack was renamed."
fi
info "profile packs: $(wc -l <<<"$PROFILE_PACKS" | tr -d ' ') (safety invariant OK)"

# ------------------------------------------------------------ validate packs
head2 "Validating repo packs"
shopt -s nullglob
REPO_PACK_FILES=("$REPO_DCG"/packs/*.yaml)
shopt -u nullglob
[[ ${#REPO_PACK_FILES[@]} -gt 0 ]] || die "no packs found in $REPO_DCG/packs/"

for f in "${REPO_PACK_FILES[@]}"; do
  [[ -L "$f" ]] && die "refusing to sync a symlink: $f (packs must be real files)"
  [[ -f "$f" ]] || die "not a regular file: $f"
  if ! out="$(dcg pack validate "$f" 2>&1)"; then
    printf '%s\n' "$out" >&2
    die "pack failed validation: $(basename "$f")"
  fi
  info "ok $(basename "$f")"
done

# Every local.* pack the profile enables must exist as a file here.
absent=()
while IFS= read -r pack; do
  [[ "$pack" == local.* ]] || continue   # built-ins ship with DCG
  [[ -f "$REPO_DCG/packs/$pack.yaml" ]] || absent+=("$pack")
done <<<"$PROFILE_PACKS"
[[ ${#absent[@]} -eq 0 ]] \
  || die "profile '$PROFILE' enables packs with no file in packs/: ${absent[*]}"

# ------------------------------------------------------------------ sync
head2 "Syncing to stow"
if [[ ! -d "$STOW_DIR/packs" ]]; then
  if [[ $DRY_RUN -eq 1 || $CHECK_ONLY -eq 1 ]]; then
    warn "would create $STOW_DIR/packs"
  else
    mkdir -p "$STOW_DIR/packs"
    info "created $STOW_DIR/packs"
  fi
fi

changed=0
for f in "${REPO_PACK_FILES[@]}"; do
  base="$(basename "$f")"
  dest="$STOW_DIR/packs/$base"
  if [[ -f "$dest" ]] && cmp -s "$f" "$dest"; then
    info "unchanged $base"
    continue
  fi
  changed=$((changed + 1))
  verb="updated"; [[ -f "$dest" ]] || verb="added"
  if [[ $DRY_RUN -eq 1 || $CHECK_ONLY -eq 1 ]]; then
    warn "DRIFT: $base would be $verb in stow"
  else
    # Write via temp + rename in the destination dir: atomic, same filesystem,
    # and never leaves a half-written pack for DCG to load.
    tmp="$(mktemp "$STOW_DIR/packs/.$base.XXXXXX")"
    cat "$f" >"$tmp"
    chmod 0644 "$tmp"
    mv -f "$tmp" "$dest"
    info "$verb $base"
  fi
done
[[ $changed -eq 0 ]] && info "stow already current"

# ------------------------------------------------------- verify live state
head2 "Verifying live DCG state"

if [[ ! -e "$LIVE_CONFIG" ]]; then
  warn "no live config at $LIVE_CONFIG — run 'stow agents' in your dotfiles repo"
else
  if [[ -L "$LIVE_CONFIG" ]]; then
    info "config.toml -> $(readlink "$LIVE_CONFIG") (stow-managed)"
  else
    warn "$LIVE_CONFIG is a REAL FILE, not a stow symlink — dotfiles and live
       config can now drift. Consider adopting it into stow."
  fi

  # The enabled list is hand-maintained in the dotfiles repo. Report drift only.
  # NB: pass the wanted set via env, not stdin — the heredoc already owns stdin.
  live_missing="$(DCG_WANT="$PROFILE_PACKS" python3 - "$LIVE_CONFIG" <<'PY'
import os, sys, tomllib
want = {l.strip() for l in os.environ["DCG_WANT"].splitlines() if l.strip()}
with open(sys.argv[1], "rb") as fh:
    have = set(tomllib.load(fh).get("packs", {}).get("enabled", []))
print("\n".join(sorted(want - have)))
PY
)" || die "could not parse live config"
  if [[ -n "$live_missing" ]]; then
    warn "live config does not enable: $(tr '\n' ' ' <<<"$live_missing")
       Add them to [packs].enabled in $STOW_DIR/config.toml (hand-maintained by
       design — this script never rewrites a stow symlink)."
    CHECK_FAILED=1
  else
    info "live enabled list covers the whole '$PROFILE' profile"
  fi
fi

# Real pack files in the live dir that stow doesn't manage won't travel to a new
# machine. Report with the idiomatic fix; never delete (RULE 1).
if [[ -d "$LIVE_PACKS" ]]; then
  shopt -s nullglob
  for f in "$LIVE_PACKS"/*.yaml; do
    base="$(basename "$f")"
    if [[ ! -L "$f" ]]; then
      warn "$base is a real file in ~/.config/dcg/packs (not stow-managed) — it
       will NOT travel to a new machine. Adopt it with:
           cd ~/.dotfiles && stow --adopt agents && git -C ~/.dotfiles diff"
      CHECK_FAILED=1
    fi
  done
  shopt -u nullglob
fi

# ---------------------------------------------------------------- summary
head2 "Summary"
enabled_local="$(dcg config 2>/dev/null | grep -c 'local\.' || true)"
info "profile: $PROFILE | packs synced: ${#REPO_PACK_FILES[@]} | changed: $changed"
info "local.* packs active in DCG: $enabled_local"

if [[ ${CHECK_FAILED:-0} -eq 1 && $CHECK_ONLY -eq 1 ]]; then
  die "drift detected (see warnings above)"
fi
if [[ $DRY_RUN -eq 1 ]]; then
  info "dry run — nothing was written"
fi
printf '\n\033[32mdone\033[0m\n'
