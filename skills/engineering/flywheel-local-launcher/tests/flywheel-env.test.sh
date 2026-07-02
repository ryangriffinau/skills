#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_CLI="$SCRIPT_DIR/../scripts/flywheel-env"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

fail() {
  echo "not ok - $1" >&2
  exit 1
}

assert_eq() {
  local actual="$1" expected="$2" label="$3"
  [ "$actual" = "$expected" ] || fail "$label: expected <$expected>, got <$actual>"
}

assert_contains() {
  local haystack="$1" needle="$2" label="$3"
  [[ "$haystack" == *"$needle"* ]] || fail "$label: expected to contain <$needle>; got <$haystack>"
}

assert_not_contains() {
  local haystack="$1" needle="$2" label="$3"
  [[ "$haystack" != *"$needle"* ]] || fail "$label: should not contain <$needle>; got <$haystack>"
}

assert_mode_600() {
  local file="$1" mode
  mode="$(stat -f '%Lp' "$file" 2>/dev/null || stat -c '%a' "$file")"
  assert_eq "$mode" "600" "$file mode"
}

new_repo() {
  local name="$1" dir
  dir="$TMP_ROOT/$name"
  mkdir -p "$dir"
  git -C "$dir" init -q
  printf '%s\n' "$dir"
}

new_home() {
  local name="$1" dir
  dir="$TMP_ROOT/$name"
  mkdir -p "$dir/.flywheel"
  printf '%s\n' "$dir"
}

write_store() {
  local file="$1" key="$2" value="$3"
  mkdir -p "$(dirname "$file")"
  printf '%s=%s\n' "$key" "$value" > "$file"
  chmod 600 "$file"
}

repo="$(new_repo precedence)"
home="$(new_home home-precedence)"
mkdir -p "$repo/.flywheel"
write_store "$home/.flywheel/env" LINEAR_API_KEY "global-secret-1111"
write_store "$repo/.env" LINEAR_API_KEY "dotenv-secret-2222"
write_store "$repo/.flywheel/env.local" LINEAR_API_KEY "project-secret-3333"

out="$(HOME="$home" LINEAR_API_KEY="process-secret-4444" "$ENV_CLI" get LINEAR_API_KEY --repo "$repo")"
assert_eq "$out" "process-secret-4444" "process env wins"

out="$(HOME="$home" env -u LINEAR_API_KEY "$ENV_CLI" get LINEAR_API_KEY --repo "$repo")"
assert_eq "$out" "project-secret-3333" "project env.local wins over .env"

rm "$repo/.flywheel/env.local"
out="$(HOME="$home" env -u LINEAR_API_KEY "$ENV_CLI" get LINEAR_API_KEY --repo "$repo")"
assert_eq "$out" "dotenv-secret-2222" "repo .env wins over global"

rm "$repo/.env"
out="$(HOME="$home" env -u LINEAR_API_KEY "$ENV_CLI" get LINEAR_API_KEY --repo "$repo")"
assert_eq "$out" "global-secret-1111" "global fallback"

rm "$home/.flywheel/env"
set +e
err="$(HOME="$home" env -u LINEAR_API_KEY "$ENV_CLI" get LINEAR_API_KEY --repo "$repo" 2>&1 >/dev/null)"
status="$?"
set -e
assert_eq "$status" "1" "missing get exit"
assert_contains "$err" "flywheel-env set LINEAR_API_KEY" "missing get hint"

repo="$(new_repo check)"
home="$(new_home home-check)"
mkdir -p "$repo/.flywheel"
cat > "$repo/.flywheel/profile" <<'PROFILE'
FLYWHEEL_ENV_REQUIRED=LINEAR_API_KEY, OTHER_KEY
PROFILE
write_store "$repo/.env" LINEAR_API_KEY "dotenv-secret-5555"
set +e
out="$(HOME="$home" "$ENV_CLI" check --repo "$repo" 2>&1)"
status="$?"
set -e
assert_eq "$status" "1" "profile-required check exits 1 when any missing"
assert_contains "$out" "LINEAR_API_KEY env" "profile-required resolves .env"
assert_contains "$out" "OTHER_KEY MISSING" "profile-required reports missing"

write_store "$home/.flywheel/env" OTHER_KEY "other-secret-6666"
out="$(HOME="$home" "$ENV_CLI" check LINEAR_API_KEY OTHER_KEY --repo "$repo")"
assert_contains "$out" "LINEAR_API_KEY env" "explicit check resolves .env"
assert_contains "$out" "OTHER_KEY global" "explicit check resolves global"

repo="$(new_repo list)"
home="$(new_home home-list)"
mkdir -p "$repo/.flywheel"
write_store "$home/.flywheel/env" LINEAR_API_KEY "global-visible-7777"
write_store "$repo/.flywheel/env.local" LINEAR_API_KEY "project-visible-8888"
write_store "$repo/.env" EXTRA_SECRET "extra-visible-9999"
out="$(HOME="$home" env -u LINEAR_API_KEY "$ENV_CLI" list --repo "$repo")"
assert_contains "$out" "LINEAR_API_KEY" "list includes registry key"
assert_contains "$out" "project" "list includes project source"
assert_contains "$out" "...8888" "list masks project last4"
assert_contains "$out" "global" "list includes global source"
assert_contains "$out" "...7777" "list masks global last4"
assert_contains "$out" "EXTRA_SECRET" "list includes file keys"
assert_not_contains "$out" "project-visible-8888" "list does not reveal project secret"
assert_not_contains "$out" "global-visible-7777" "list does not reveal global secret"
assert_not_contains "$out" "extra-visible-9999" "list does not reveal dotenv secret"

repo="$(new_repo no-tty)"
home="$(new_home home-no-tty)"
set +e
err="$(HOME="$home" "$ENV_CLI" set LINEAR_API_KEY --repo "$repo" </dev/null 2>&1 >/dev/null)"
status="$?"
set -e
assert_eq "$status" "3" "set non-tty exits 3"
assert_contains "$err" "agents use flywheel-env get/check" "set non-tty hint"

if command -v expect >/dev/null 2>&1; then
  repo="$(new_repo interactive-set)"
  home="$(new_home home-interactive-set)"
  expect <<EXPECT >/dev/null
set timeout 5
spawn env HOME=$home $ENV_CLI set LINEAR_API_KEY --repo $repo
expect "Store \\[g\\]lobal or \\[p\\]roject-level"
send "p\r"
expect "Enter value for LINEAR_API_KEY:"
send "interactive-secret-2468\r"
expect "Add .flywheel/env.local to .gitignore?"
send "\r"
expect eof
EXPECT
  assert_eq "$(HOME="$home" "$ENV_CLI" get LINEAR_API_KEY --repo "$repo")" "interactive-secret-2468" "interactive project set resolves"
  assert_contains "$(cat "$repo/.gitignore")" ".flywheel/env.local" "interactive set gitignores project store"
  assert_mode_600 "$repo/.flywheel/env.local"
fi

echo "ok - flywheel-env"
