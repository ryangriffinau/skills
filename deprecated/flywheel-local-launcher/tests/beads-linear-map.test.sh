#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_MAP="$SCRIPT_DIR/../scripts/beads-linear-map"
SOURCE_PROFILE="$SCRIPT_DIR/../scripts/flywheel-profile.sh"
SOURCE_ENV="$SCRIPT_DIR/../scripts/flywheel-env"
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

assert_not_contains() {
  local haystack="$1" needle="$2" label="$3"
  [[ "$haystack" != *"$needle"* ]] || fail "$label: expected not to contain $needle; got: $haystack"
}

assert_line_count() {
  local file="$1" expected="$2" label="$3" actual
  actual="$(wc -l < "$file" | tr -d '[:space:]')"
  [ "$actual" = "$expected" ] || fail "$label: expected $expected line(s); got $actual"
}

assert_tsv_line() {
  local file="$1" epic="$2" project="$3" label="$4"
  grep -Fq "$(printf '%s\t%s' "$epic" "$project")" "$file" || fail "$label: missing $epic tab $project in $file"
}

TOOLS_DIR="$TMP_ROOT/tooling"
SCRIPTS_DIR="$TOOLS_DIR/scripts"
BIN_DIR="$TMP_ROOT/bin"
mkdir -p "$SCRIPTS_DIR" "$BIN_DIR"
cp "$SOURCE_MAP" "$SCRIPTS_DIR/beads-linear-map"
cp "$SOURCE_PROFILE" "$SCRIPTS_DIR/flywheel-profile.sh"
cp "$SOURCE_ENV" "$SCRIPTS_DIR/flywheel-env"
chmod +x "$SCRIPTS_DIR/beads-linear-map" "$SCRIPTS_DIR/flywheel-profile.sh" "$SCRIPTS_DIR/flywheel-env"

cat > "$BIN_DIR/curl" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
body=""
auth=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    -H)
      case "${2:-}" in Authorization:*) auth="${2#Authorization: }" ;; esac
      shift 2
      ;;
    -d)
      body="$2"
      shift 2
      ;;
    *) shift ;;
  esac
done
printf '%s\n' "$auth" >> "$CURL_AUTH_LOG"
printf '%s\n' "$body" >> "$CURL_BODY_LOG"
case "$body" in
  *'teams(filter'*)
    printf '{"data":{"teams":{"nodes":[{"id":"team-whc-id","key":"WHC"}]}}}'
    ;;
  *)
    printf '{"data":{"projectCreate":{"success":true,"project":{"id":"proj-created-123"}}}}'
    ;;
esac
SH
chmod +x "$BIN_DIR/curl"

new_repo() {
  local name="$1" dir
  dir="$TMP_ROOT/$name"
  mkdir -p "$dir/.flywheel"
  git -C "$dir" init -q
  printf 'FLYWHEEL_MODE=team\nFLYWHEEL_PROJECTION_APP=linear\n' > "$dir/.flywheel/profile"
  printf '%s\n' "$dir"
}

run_map() {
  local out_file="$TMP_ROOT/out" err_file="$TMP_ROOT/err" status
  CURL_AUTH_LOG="$TMP_ROOT/curl-auth.log"
  CURL_BODY_LOG="$TMP_ROOT/curl-body.log"
  : > "$CURL_AUTH_LOG"
  : > "$CURL_BODY_LOG"
  set +e
  CURL_AUTH_LOG="$CURL_AUTH_LOG" CURL_BODY_LOG="$CURL_BODY_LOG" \
    PATH="$BIN_DIR:$PATH" "$SCRIPTS_DIR/beads-linear-map" "$@" >"$out_file" 2>"$err_file"
  status="$?"
  set -e
  MAP_OUT="$(cat "$out_file")"
  MAP_ERR="$(cat "$err_file")"
  MAP_ALL="$MAP_OUT$MAP_ERR"
  MAP_STATUS="$status"
}

repo="$(new_repo project_id)"
run_map epic-a --project-id proj-a --repo "$repo"
[ "$MAP_STATUS" -eq 0 ] || fail "project-id mapping failed: $MAP_ALL"
assert_tsv_line "$repo/.flywheel/projects.tsv" epic-a proj-a "project-id writes tsv"
assert_contains "$MAP_ALL" "mapped epic-a -> proj-a" "project-id log"
run_map epic-a --project-id proj-a --repo "$repo"
[ "$MAP_STATUS" -eq 0 ] || fail "project-id idempotent rerun failed: $MAP_ALL"
assert_line_count "$repo/.flywheel/projects.tsv" 1 "project-id idempotency"
assert_contains "$MAP_ALL" "already mapped epic-a -> proj-a" "project-id idempotent log"

repo="$(new_repo create_profile_team)"
printf 'FLYWHEEL_PROJECTION_TEAM=WHC\n' >> "$repo/.flywheel/profile"
LINEAR_API_KEY=create-key run_map epic-b --create "Roadmap Project" --repo "$repo"
[ "$MAP_STATUS" -eq 0 ] || fail "create mapping failed: $MAP_ALL"
assert_tsv_line "$repo/.flywheel/projects.tsv" epic-b proj-created-123 "create writes tsv"
assert_contains "$(cat "$TMP_ROOT/curl-auth.log")" "create-key" "create uses env key"
assert_contains "$(cat "$TMP_ROOT/curl-body.log")" "projectCreate" "create calls projectCreate"
assert_contains "$(cat "$TMP_ROOT/curl-body.log")" "Roadmap Project" "create sends project name"
assert_contains "$(cat "$TMP_ROOT/curl-body.log")" "WHC" "create uses profile team"
assert_contains "$(cat "$TMP_ROOT/curl-body.log")" "team-whc-id" "create resolves team key"

repo="$(new_repo create_team_override)"
printf 'FLYWHEEL_PROJECTION_TEAM=BACK\n' >> "$repo/.flywheel/profile"
LINEAR_API_KEY=create-key run_map epic-c --create "Override Project" --team WHC --repo "$repo"
[ "$MAP_STATUS" -eq 0 ] || fail "create override failed: $MAP_ALL"
assert_contains "$(cat "$TMP_ROOT/curl-body.log")" "WHC" "explicit team used"
assert_not_contains "$(cat "$TMP_ROOT/curl-body.log")" "BACK" "explicit team overrides profile"
assert_contains "$(cat "$TMP_ROOT/curl-body.log")" "team-whc-id" "explicit team key resolves"

repo="$(new_repo missing_team)"
LINEAR_API_KEY=create-key run_map epic-d --create "No Team" --repo "$repo"
[ "$MAP_STATUS" -ne 0 ] || fail "missing team should fail"
assert_contains "$MAP_ALL" "FLYWHEEL_PROJECTION_TEAM=" "missing team names profile line"

repo="$(new_repo conflict)"
printf 'epic-e\tproj-old\n' > "$repo/.flywheel/projects.tsv"
run_map epic-e --project-id proj-new --repo "$repo"
[ "$MAP_STATUS" -ne 0 ] || fail "conflicting mapping should fail"
assert_contains "$MAP_ALL" "already maps to proj-old" "conflicting mapping message"

echo "ok - beads-linear-map"
