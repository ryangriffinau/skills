#!/usr/bin/env bash
# Resolve a repo's optional .flywheel/profile into eval-able FLYWHEEL_* vars.
set -euo pipefail

usage() {
  echo "usage: flywheel-profile.sh --repo DIR" >&2
}

repo="."
while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo)
      [ "$#" -ge 2 ] || { usage; exit 2; }
      repo="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done

if ! repo_abs="$(cd "$repo" 2>/dev/null && pwd)"; then
  echo "flywheel-profile.sh: repo not found: $repo" >&2
  exit 2
fi

mode="solo"
worktrees="false"
precommit="light"
prepush="full"
projection_app=""
env_required=""
pm="none"

warn_invalid() {
  local key="$1" value="$2" default="$3"
  printf 'flywheel-profile.sh: warning: invalid %s=%s; using default %s\n' "$key" "$value" "$default" >&2
}

trim() {
  local value="$1"
  printf '%s' "$value" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

parse_profile_value() {
  local line="$1" key="$2" value
  value="${line#"$key"=}"
  value="${value%%#*}"
  trim "$value"
}

valid_env_required() {
  local value="$1" part
  local -a parts
  [ -n "$value" ] || return 0
  IFS=',' read -r -a parts <<< "$value"
  for part in "${parts[@]}"; do
    part="$(trim "$part")"
    case "$part" in
      ""|[0-9]*|*[!A-Za-z0-9_]*)
        return 1
        ;;
    esac
  done
  return 0
}

apply_profile_line() {
  local line="$1" value
  case "$line" in
    FLYWHEEL_MODE=*)
      value="$(parse_profile_value "$line" "FLYWHEEL_MODE")"
      case "$value" in
        solo|team) mode="$value" ;;
        *) warn_invalid "FLYWHEEL_MODE" "$value" "$mode" ;;
      esac
      ;;
    FLYWHEEL_WORKTREES=*)
      value="$(parse_profile_value "$line" "FLYWHEEL_WORKTREES")"
      case "$value" in
        false) worktrees="$value" ;;
        *) warn_invalid "FLYWHEEL_WORKTREES" "$value" "$worktrees" ;;
      esac
      ;;
    FLYWHEEL_PRECOMMIT=*)
      value="$(parse_profile_value "$line" "FLYWHEEL_PRECOMMIT")"
      case "$value" in
        light|heavy) precommit="$value" ;;
        *) warn_invalid "FLYWHEEL_PRECOMMIT" "$value" "$precommit" ;;
      esac
      ;;
    FLYWHEEL_PREPUSH=*)
      value="$(parse_profile_value "$line" "FLYWHEEL_PREPUSH")"
      case "$value" in
        full|none) prepush="$value" ;;
        *) warn_invalid "FLYWHEEL_PREPUSH" "$value" "$prepush" ;;
      esac
      ;;
    FLYWHEEL_PROJECTION_APP=*)
      value="$(parse_profile_value "$line" "FLYWHEEL_PROJECTION_APP")"
      case "$value" in
        ""|linear) projection_app="$value" ;;
        *) warn_invalid "FLYWHEEL_PROJECTION_APP" "$value" "$projection_app" ;;
      esac
      ;;
    FLYWHEEL_ENV_REQUIRED=*)
      value="$(parse_profile_value "$line" "FLYWHEEL_ENV_REQUIRED")"
      if valid_env_required "$value"; then
        env_required="$value"
      else
        warn_invalid "FLYWHEEL_ENV_REQUIRED" "$value" "$env_required"
      fi
      ;;
  esac
}

detect_package_manager() {
  local package_json="$repo_abs/package.json" package_manager manager
  if [ -f "$package_json" ]; then
    package_manager="$(
      tr -d '\r\n' < "$package_json" |
        sed -nE 's/.*"packageManager"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' |
        head -n 1
    )"
    if [ -n "$package_manager" ]; then
      manager="${package_manager%%@*}"
      case "$manager" in
        pnpm|bun|npm|yarn) pm="$manager" ;;
        *) printf 'flywheel-profile.sh: warning: unsupported packageManager=%s; using pm=none\n' "$package_manager" >&2 ;;
      esac
      return
    fi
  fi

  if [ -f "$repo_abs/pnpm-lock.yaml" ]; then
    pm="pnpm"
  elif [ -f "$repo_abs/bun.lockb" ]; then
    pm="bun"
  elif [ -f "$repo_abs/package-lock.json" ]; then
    pm="npm"
  elif [ -f "$repo_abs/yarn.lock" ]; then
    pm="yarn"
  fi
}

quote_value() {
  local value="$1"
  value="${value//\'/\'\\\'\'}"
  printf "'%s'" "$value"
}

if git -C "$repo_abs" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  profile="$repo_abs/.flywheel/profile"
  if [ -f "$profile" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
      apply_profile_line "$line"
    done < "$profile"
  fi
  detect_package_manager
fi

printf 'FLYWHEEL_MODE=%s\n' "$(quote_value "$mode")"
printf 'FLYWHEEL_WORKTREES=%s\n' "$(quote_value "$worktrees")"
printf 'FLYWHEEL_PRECOMMIT=%s\n' "$(quote_value "$precommit")"
printf 'FLYWHEEL_PREPUSH=%s\n' "$(quote_value "$prepush")"
printf 'FLYWHEEL_PROJECTION_APP=%s\n' "$(quote_value "$projection_app")"
printf 'FLYWHEEL_ENV_REQUIRED=%s\n' "$(quote_value "$env_required")"
printf 'FLYWHEEL_PM=%s\n' "$(quote_value "$pm")"
