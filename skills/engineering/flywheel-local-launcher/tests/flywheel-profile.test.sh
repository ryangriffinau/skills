#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RESOLVER="$SCRIPT_DIR/../scripts/flywheel-profile.sh"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

fail() {
  echo "not ok - $1" >&2
  exit 1
}

assert_contains() {
  local haystack="$1" needle="$2" label="$3"
  [[ "$haystack" == *"$needle"* ]] || fail "$label: expected to contain $needle; got: $haystack"
}

assert_empty() {
  local value="$1" label="$2"
  [ -z "$value" ] || fail "$label: expected empty; got: $value"
}

new_repo() {
  local name="$1" dir
  dir="$TMP_ROOT/$name"
  mkdir -p "$dir"
  git -C "$dir" init -q
  printf '%s\n' "$dir"
}

run_resolver() {
  local repo="$1" out_file="$TMP_ROOT/out" err_file="$TMP_ROOT/err"
  "$RESOLVER" --repo "$repo" >"$out_file" 2>"$err_file"
  RESOLVER_OUT="$(cat "$out_file")"
  RESOLVER_ERR="$(cat "$err_file")"
}

repo="$(new_repo absent)"
run_resolver "$repo"
assert_contains "$RESOLVER_OUT" "FLYWHEEL_MODE='solo'" "absent profile mode"
assert_contains "$RESOLVER_OUT" "FLYWHEEL_WORKTREES='false'" "absent profile worktrees"
assert_contains "$RESOLVER_OUT" "FLYWHEEL_PRECOMMIT='light'" "absent profile precommit"
assert_contains "$RESOLVER_OUT" "FLYWHEEL_PREPUSH='full'" "absent profile prepush"
assert_contains "$RESOLVER_OUT" "FLYWHEEL_PROJECTION_APP=''" "absent profile projection"
assert_contains "$RESOLVER_OUT" "FLYWHEEL_PROJECTION_TEAM=''" "absent profile projection team"
assert_contains "$RESOLVER_OUT" "FLYWHEEL_ENV_REQUIRED=''" "absent profile env required"
assert_contains "$RESOLVER_OUT" "FLYWHEEL_PM='none'" "absent profile pm"
assert_empty "$RESOLVER_ERR" "absent profile stderr"

repo="$(new_repo valid)"
mkdir -p "$repo/.flywheel"
cat > "$repo/.flywheel/profile" <<'PROFILE'
FLYWHEEL_MODE=team          # inline comments are allowed
FLYWHEEL_WORKTREES=false
FLYWHEEL_PRECOMMIT=heavy
FLYWHEEL_PREPUSH=none
FLYWHEEL_PROJECTION_APP=linear
FLYWHEEL_PROJECTION_TEAM=WHC
FLYWHEEL_ENV_REQUIRED=LINEAR_API_KEY, OTHER_KEY
PROFILE
cat > "$repo/package.json" <<'JSON'
{
  "packageManager": "pnpm@9.12.0"
}
JSON
run_resolver "$repo"
assert_contains "$RESOLVER_OUT" "FLYWHEEL_MODE='team'" "valid profile mode"
assert_contains "$RESOLVER_OUT" "FLYWHEEL_PRECOMMIT='heavy'" "valid profile precommit"
assert_contains "$RESOLVER_OUT" "FLYWHEEL_PREPUSH='none'" "valid profile prepush"
assert_contains "$RESOLVER_OUT" "FLYWHEEL_PROJECTION_APP='linear'" "valid profile projection"
assert_contains "$RESOLVER_OUT" "FLYWHEEL_PROJECTION_TEAM='WHC'" "valid profile projection team"
assert_contains "$RESOLVER_OUT" "FLYWHEEL_ENV_REQUIRED='LINEAR_API_KEY, OTHER_KEY'" "valid profile env required"
assert_contains "$RESOLVER_OUT" "FLYWHEEL_PM='pnpm'" "packageManager pnpm"
assert_empty "$RESOLVER_ERR" "valid profile stderr"

repo="$(new_repo invalid)"
mkdir -p "$repo/.flywheel"
cat > "$repo/.flywheel/profile" <<'PROFILE'
FLYWHEEL_MODE=team; rm -rf /
FLYWHEEL_WORKTREES=true
FLYWHEEL_PRECOMMIT=slow
FLYWHEEL_PREPUSH=yes
FLYWHEEL_PROJECTION_APP=jira
FLYWHEEL_PROJECTION_TEAM=bad/team
FLYWHEEL_ENV_REQUIRED=LINEAR_API_KEY, BAD-KEY
PROFILE
touch "$repo/package-lock.json"
run_resolver "$repo"
assert_contains "$RESOLVER_OUT" "FLYWHEEL_MODE='solo'" "invalid mode falls back"
assert_contains "$RESOLVER_OUT" "FLYWHEEL_WORKTREES='false'" "invalid worktrees falls back"
assert_contains "$RESOLVER_OUT" "FLYWHEEL_PRECOMMIT='light'" "invalid precommit falls back"
assert_contains "$RESOLVER_OUT" "FLYWHEEL_PREPUSH='full'" "invalid prepush falls back"
assert_contains "$RESOLVER_OUT" "FLYWHEEL_PROJECTION_APP=''" "invalid projection falls back"
assert_contains "$RESOLVER_OUT" "FLYWHEEL_PROJECTION_TEAM=''" "invalid projection team falls back"
assert_contains "$RESOLVER_OUT" "FLYWHEEL_ENV_REQUIRED=''" "invalid env required falls back"
assert_contains "$RESOLVER_OUT" "FLYWHEEL_PM='npm'" "lockfile npm"
assert_contains "$RESOLVER_ERR" "invalid FLYWHEEL_MODE=team; rm -rf /" "invalid mode warns"
assert_contains "$RESOLVER_ERR" "invalid FLYWHEEL_PROJECTION_APP=jira" "invalid projection warns"
assert_contains "$RESOLVER_ERR" "invalid FLYWHEEL_PROJECTION_TEAM=bad/team" "invalid projection team warns"
assert_contains "$RESOLVER_ERR" "invalid FLYWHEEL_ENV_REQUIRED=LINEAR_API_KEY, BAD-KEY" "invalid env required warns"

repo="$(new_repo partial)"
mkdir -p "$repo/.flywheel"
printf 'FLYWHEEL_MODE=team\nFLYWHEEL_PROJECTION_TEAM=\n' > "$repo/.flywheel/profile"
run_resolver "$repo"
assert_contains "$RESOLVER_OUT" "FLYWHEEL_MODE='team'" "partial profile override"
assert_contains "$RESOLVER_OUT" "FLYWHEEL_PRECOMMIT='light'" "partial profile default"
assert_contains "$RESOLVER_OUT" "FLYWHEEL_PROJECTION_TEAM=''" "partial profile projection team default"
assert_contains "$RESOLVER_OUT" "FLYWHEEL_ENV_REQUIRED=''" "partial profile env required default"
assert_empty "$RESOLVER_ERR" "partial profile stderr"

repo="$TMP_ROOT/not-git"
mkdir -p "$repo/.flywheel"
printf 'FLYWHEEL_MODE=team\n' > "$repo/.flywheel/profile"
printf '{"packageManager":"bun@1.1.0"}\n' > "$repo/package.json"
run_resolver "$repo"
assert_contains "$RESOLVER_OUT" "FLYWHEEL_MODE='solo'" "outside git ignores profile"
assert_contains "$RESOLVER_OUT" "FLYWHEEL_PM='none'" "outside git ignores package files"

for case_name in pnpm_lock bun_lock npm_lock yarn_lock none; do
  repo="$(new_repo "$case_name")"
  case "$case_name" in
    pnpm_lock) touch "$repo/pnpm-lock.yaml"; expected="pnpm" ;;
    bun_lock) touch "$repo/bun.lockb"; expected="bun" ;;
    npm_lock) touch "$repo/package-lock.json"; expected="npm" ;;
    yarn_lock) touch "$repo/yarn.lock"; expected="yarn" ;;
    none) expected="none" ;;
  esac
  run_resolver "$repo"
  assert_contains "$RESOLVER_OUT" "FLYWHEEL_PM='$expected'" "$case_name package manager"
done

repo="$(new_repo package_manager_precedence)"
printf '{"packageManager":"yarn@4.0.0"}\n' > "$repo/package.json"
touch "$repo/pnpm-lock.yaml"
run_resolver "$repo"
assert_contains "$RESOLVER_OUT" "FLYWHEEL_PM='yarn'" "packageManager wins over lockfile"

echo "ok - flywheel-profile"
