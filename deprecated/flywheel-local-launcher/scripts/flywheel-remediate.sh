#!/usr/bin/env bash
# Audit and apply the two repository remediations commonly needed after Flywheel setup.
set -euo pipefail

usage() {
  cat <<'USAGE'
usage:
  flywheel-remediate.sh decommission --legacy-token TOKEN --archive-path PATH [--archive-path PATH ...] [--repo DIR] [--apply]
  flywheel-remediate.sh untrack-ntm [--repo DIR] [--apply]

decommission audits first and refuses to archive while live tracked files refer to
TOKEN or an archive candidate. With --apply, each candidate is moved with git mv
to archive/flywheel-decommission/<original-path> and the live-reference audit is
repeated. Without --apply, both commands are read-only.

untrack-ntm reports tracked .ntm files and machine-local absolute paths. With
--apply, it adds .ntm/ to .gitignore and removes .ntm only from Git's index; local
files are preserved.
USAGE
}

fail() {
  echo "flywheel-remediate: error: $*" >&2
  exit 1
}

repo_root() {
  local requested="$1" root
  root="$(git -C "$requested" rev-parse --show-toplevel 2>/dev/null)" ||
    fail "not a Git repository: $requested"
  printf '%s\n' "$root"
}

validate_relative_path() {
  local path="$1"
  case "$path" in
    ""|/*|.|..|../*|*/../*|*/..)
      fail "archive paths must be non-empty repository-relative paths without '..': $path"
      ;;
  esac
}

tracked_under() {
  local repo="$1" path="$2"
  git -C "$repo" ls-files -- "$path"
}

live_token_references() {
  local repo="$1" token="$2"
  shift 2
  local path pathspecs=(. ':(exclude)archive/**')
  for path in "$@"; do
    pathspecs+=(":(exclude)$path" ":(exclude)$path/**")
  done
  git -C "$repo" grep -l -F -e "$token" -- "${pathspecs[@]}" 2>/dev/null || true
}

live_candidate_references() {
  local repo="$1"
  shift
  local candidate path pathspecs
  for candidate in "$@"; do
    pathspecs=(. ':(exclude)archive/**')
    for path in "$@"; do
      pathspecs+=(":(exclude)$path" ":(exclude)$path/**")
    done
    git -C "$repo" grep -l -F -e "$candidate" -- "${pathspecs[@]}" 2>/dev/null || true
  done | sort -u
}

audit_decommission() {
  local repo="$1" token="$2"
  shift 2
  local candidate tracked token_refs candidate_refs failed=0

  echo "==> decommission audit"
  echo "  legacy token: $token"
  for candidate in "$@"; do
    validate_relative_path "$candidate"
    tracked="$(tracked_under "$repo" "$candidate")"
    if [ -z "$tracked" ]; then
      echo "  ✗ candidate is not tracked: $candidate" >&2
      failed=1
    else
      echo "  ✓ candidate tracked: $candidate"
    fi
  done

  token_refs="$(live_token_references "$repo" "$token" "$@")"
  candidate_refs="$(live_candidate_references "$repo" "$@")"
  if [ -n "$token_refs" ]; then
    echo "  ✗ live files still contain legacy token '$token':" >&2
    printf '%s\n' "$token_refs" | sed 's/^/    /' >&2
    failed=1
  else
    echo "  ✓ no legacy-token references outside candidates/archive"
  fi
  if [ -n "$candidate_refs" ]; then
    echo "  ✗ live files still refer to an archive candidate:" >&2
    printf '%s\n' "$candidate_refs" | sed 's/^/    /' >&2
    failed=1
  else
    echo "  ✓ candidates are unreferenced by live tracked files"
  fi

  [ "$failed" -eq 0 ]
}

decommission() {
  local requested_repo=. token='' apply=0 arg repo destination
  local candidates=()
  while [ "$#" -gt 0 ]; do
    arg="$1"
    case "$arg" in
      --repo) requested_repo="${2:?missing --repo value}"; shift 2 ;;
      --legacy-token) token="${2:?missing --legacy-token value}"; shift 2 ;;
      --archive-path) candidates+=("${2:?missing --archive-path value}"); shift 2 ;;
      --apply) apply=1; shift ;;
      -h|--help) usage; return 0 ;;
      *) fail "unknown decommission argument: $arg" ;;
    esac
  done
  [ -n "$token" ] || fail "decommission requires --legacy-token"
  [ "${#candidates[@]}" -gt 0 ] || fail "decommission requires at least one --archive-path"
  repo="$(repo_root "$requested_repo")"
  audit_decommission "$repo" "$token" "${candidates[@]}" ||
    fail "audit failed; remove or archive every live entrypoint, then rerun"
  if [ "$apply" -eq 0 ]; then
    echo "audit passed; rerun with --apply to archive the candidates"
    return 0
  fi

  for arg in "${candidates[@]}"; do
    destination="archive/flywheel-decommission/$arg"
    [ ! -e "$repo/$destination" ] || fail "archive destination already exists: $destination"
    mkdir -p "$repo/$(dirname "$destination")"
    git -C "$repo" mv -- "$arg" "$destination"
    echo "  archived: $arg -> $destination"
  done
  [ -z "$(live_token_references "$repo" "$token")" ] ||
    fail "post-archive audit found live legacy-token references"
  for arg in "${candidates[@]}"; do
    [ -z "$(tracked_under "$repo" "$arg")" ] || fail "original path remains tracked: $arg"
  done
  echo "decommission complete: zero live '$token' references outside archive/"
}

ensure_ignore_line() {
  local repo="$1" line="$2"
  touch "$repo/.gitignore"
  if ! grep -Fqx "$line" "$repo/.gitignore"; then
    printf '%s\n' "$line" >> "$repo/.gitignore"
  fi
}

untrack_ntm() {
  local requested_repo=. apply=0 arg repo tracked absolute_refs before_hash after_hash
  while [ "$#" -gt 0 ]; do
    arg="$1"
    case "$arg" in
      --repo) requested_repo="${2:?missing --repo value}"; shift 2 ;;
      --apply) apply=1; shift ;;
      -h|--help) usage; return 0 ;;
      *) fail "unknown untrack-ntm argument: $arg" ;;
    esac
  done
  repo="$(repo_root "$requested_repo")"
  tracked="$(tracked_under "$repo" .ntm)"
  absolute_refs=""
  if [ -d "$repo/.ntm" ]; then
    absolute_refs="$(grep -RIlE '/(Users|home)/[^[:space:]]+' "$repo/.ntm" 2>/dev/null || true)"
  fi
  echo "==> .ntm audit"
  if [ -n "$tracked" ]; then
    printf '  tracked: %s file(s)\n' "$(printf '%s\n' "$tracked" | wc -l | tr -d ' ')"
  else
    echo "  tracked: 0 files"
  fi
  if [ -n "$absolute_refs" ]; then
    echo "  machine-local absolute paths detected:"
    printf '%s\n' "$absolute_refs" | sed "s|^$repo/|    |"
  fi
  if [ "$apply" -eq 0 ]; then
    echo "audit complete; rerun with --apply to preserve locally and untrack"
    return 0
  fi

  before_hash=""
  if [ -d "$repo/.ntm" ]; then
    before_hash="$(find "$repo/.ntm" -type f -exec shasum {} + | sort | shasum | awk '{print $1}')"
  fi
  ensure_ignore_line "$repo" ".ntm/"
  if [ -n "$tracked" ]; then
    git -C "$repo" rm -r --cached --ignore-unmatch -- .ntm >/dev/null
  fi
  after_hash=""
  if [ -d "$repo/.ntm" ]; then
    after_hash="$(find "$repo/.ntm" -type f -exec shasum {} + | sort | shasum | awk '{print $1}')"
  fi
  [ "$before_hash" = "$after_hash" ] || fail ".ntm contents changed while untracking"
  [ -z "$(tracked_under "$repo" .ntm)" ] || fail ".ntm remains tracked"
  git -C "$repo" check-ignore -q .ntm/ || fail ".ntm is not ignored"
  echo ".ntm untracked; local contents preserved and .ntm/ ignored"
}

case "${1:-}" in
  decommission) shift; decommission "$@" ;;
  untrack-ntm) shift; untrack_ntm "$@" ;;
  -h|--help) usage ;;
  "") usage; exit 2 ;;
  *) fail "unknown command: $1" ;;
esac
