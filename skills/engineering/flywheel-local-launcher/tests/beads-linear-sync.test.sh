#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_SYNC="$SCRIPT_DIR/../scripts/beads-linear-sync"
SOURCE_PROFILE="$SCRIPT_DIR/../scripts/flywheel-profile.sh"
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

assert_file_contains() {
  local file="$1" needle="$2" label="$3"
  grep -Fq "$needle" "$file" || fail "$label: expected $file to contain $needle"
}

TOOLS_DIR="$TMP_ROOT/tooling"
SCRIPTS_DIR="$TOOLS_DIR/scripts"
BIN_DIR="$TMP_ROOT/bin"
mkdir -p "$SCRIPTS_DIR" "$BIN_DIR"
cp "$SOURCE_SYNC" "$SCRIPTS_DIR/beads-linear-sync"
cp "$SOURCE_PROFILE" "$SCRIPTS_DIR/flywheel-profile.sh"
chmod +x "$SCRIPTS_DIR/beads-linear-sync" "$SCRIPTS_DIR/flywheel-profile.sh"

cat > "$SCRIPTS_DIR/flywheel-env" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
[ "${1:-}" = "get" ] || exit 2
[ "${2:-}" = "LINEAR_API_KEY" ] || exit 2
repo="."
shift 2
while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo) repo="$2"; shift 2 ;;
    *) shift ;;
  esac
done
case "$(basename "$repo")" in
  linear_a) printf 'key-linear-a' ;;
  linear_b) printf 'key-linear-b' ;;
  unchanged) printf 'key-unchanged' ;;
  errors) printf 'key-errors' ;;
  *) exit 1 ;;
esac
SH
chmod +x "$SCRIPTS_DIR/flywheel-env"

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
  *proj-network*)
    echo "network down" >&2
    exit 7
    ;;
  *proj-errors*)
    printf '{"errors":[{"message":"project unavailable"}]}'
    exit 0
    ;;
  *viewer*)
    printf '{"data":{"viewer":{"name":"Test User","email":"test@example.com"},"project":{"id":"proj-a","name":"Roadmap"}}}'
    exit 0
    ;;
  *projectUpdates*proj-unchanged*)
    printf '%s' '{"data":{"project":{"projectUpdates":{"nodes":[{"body":"[beads:unchanged] 1/2 beads closed (50%)."},{"body":"[beads:unchanged] 0/2 beads closed (0%)."}]}}}}'
    exit 0
    ;;
  *projectUpdates*)
    printf '%s' '{"data":{"project":{"projectUpdates":{"nodes":[{"body":"[beads:older] 0/2 beads closed (0%)."}]}}}}'
    exit 0
    ;;
  *projectUpdateCreate*)
    printf '{"data":{"projectUpdateCreate":{"success":true,"projectUpdate":{"id":"upd_1"}}}}'
    exit 0
    ;;
  *)
    printf '{"data":{}}'
    exit 0
    ;;
esac
SH
chmod +x "$BIN_DIR/curl"

cat > "$BIN_DIR/ntm" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
if [ "${1:-}" = "config" ] && [ "${2:-}" = "show" ]; then
  printf 'projects_base = "%s"\n' "$NTM_PROJECTS_BASE"
  exit 0
fi
exit 2
SH
chmod +x "$BIN_DIR/ntm"

new_repo() {
  local name="$1" projection="linear" dir
  [ "$#" -lt 2 ] || projection="$2"
  dir="$TMP_ROOT/$name"
  mkdir -p "$dir/.flywheel" "$dir/.beads"
  git -C "$dir" init -q
  printf 'FLYWHEEL_MODE=team\nFLYWHEEL_PROJECTION_APP=%s\n' "$projection" > "$dir/.flywheel/profile"
  printf '%s\n' "$dir"
}

write_epic() {
  local repo="$1" epic="$2" project="$3" second_status="${4:-open}"
  printf '%s\t%s\n' "$epic" "$project" > "$repo/.flywheel/projects.tsv"
  {
    printf '{"id":"%s","title":"Epic","status":"open"}\n' "$epic"
    printf '{"id":"%s.1","title":"Done","status":"closed"}\n' "$epic"
    printf '{"id":"%s.2","title":"Next","status":"%s"}\n' "$epic" "$second_status"
  } > "$repo/.beads/issues.jsonl"
}

run_sync() {
  local out_file="$TMP_ROOT/out" err_file="$TMP_ROOT/err"
  CURL_AUTH_LOG="$TMP_ROOT/curl-auth.log" CURL_BODY_LOG="$TMP_ROOT/curl-body.log" \
    PATH="$BIN_DIR:$PATH" "$SCRIPTS_DIR/beads-linear-sync" "$@" >"$out_file" 2>"$err_file"
  SYNC_OUT="$(cat "$out_file")"
  SYNC_ERR="$(cat "$err_file")"
  SYNC_ALL="$SYNC_OUT$SYNC_ERR"
}

repo="$(new_repo linear_a)"
write_epic "$repo" linear_a proj-a blocked
run_sync --repo "$repo" --dry-run
assert_contains "$SYNC_ALL" "linear_a -> proj-a 1/2 (50%, atRisk)" "dry-run computes blocked health"
assert_contains "$SYNC_ALL" "dry-run: would post atRisk update" "dry-run does not write"
assert_contains "$SYNC_ALL" "key valid (user Test User) ✓ project reachable ✓" "dry-run auth probe"
assert_file_contains "$TMP_ROOT/curl-auth.log" "key-linear-a" "flywheel-env key used"

repo="$(new_repo unchanged)"
write_epic "$repo" unchanged proj-unchanged open
run_sync --repo "$repo"
assert_contains "$SYNC_ALL" "unchanged, no new update (1/2)" "unchanged idempotency"
assert_not_contains "$(cat "$TMP_ROOT/curl-body.log")" "projectUpdateCreate" "unchanged skips mutation"

repo="$(new_repo errors)"
printf 'epic_errors\tproj-errors\nepic_network\tproj-network\n' > "$repo/.flywheel/projects.tsv"
{
  printf '{"id":"epic_errors","title":"Errors","status":"open"}\n'
  printf '{"id":"epic_errors.1","title":"Done","status":"closed"}\n'
  printf '{"id":"epic_network","title":"Network","status":"open"}\n'
  printf '{"id":"epic_network.1","title":"Done","status":"closed"}\n'
} > "$repo/.beads/issues.jsonl"
run_sync --repo "$repo"
assert_contains "$SYNC_ALL" "projectUpdates GraphQL errors" "GraphQL error class"
assert_contains "$SYNC_ALL" "projectUpdates curl/network error" "curl error class"

repo="$(new_repo missing_key)"
write_epic "$repo" missing_key proj-a open
run_sync --repo "$repo"
assert_contains "$SYNC_ALL" "LINEAR_API_KEY not set" "missing key fail-open"
assert_contains "$SYNC_ALL" "dry-run: LINEAR_API_KEY unresolved; auth probe skipped" "missing key dry-run fallback"

mv "$SCRIPTS_DIR/flywheel-env" "$SCRIPTS_DIR/flywheel-env.off"
repo="$(new_repo process_env)"
write_epic "$repo" process_env proj-a open
LINEAR_API_KEY=process-key run_sync --repo "$repo" --dry-run
assert_file_contains "$TMP_ROOT/curl-auth.log" "process-key" "process env fallback when flywheel-env absent"
mv "$SCRIPTS_DIR/flywheel-env.off" "$SCRIPTS_DIR/flywheel-env"

base="$TMP_ROOT/projects_base"
mkdir -p "$base"
repo_a="$(new_repo linear_a)"
repo_b="$(new_repo linear_b)"
repo_skip="$(new_repo skip_repo "")"
write_epic "$repo_a" linear_a proj-a open
write_epic "$repo_b" linear_b proj-a open
ln -s "$repo_a" "$base/linear_a"
ln -s "$repo_b" "$base/linear_b"
ln -s "$repo_skip" "$base/skip_repo"
NTM_PROJECTS_BASE="$base" run_sync --all --dry-run
assert_contains "$SYNC_ALL" "$base/linear_a: synced 1 mapped project(s)" "--all linear_a summary"
assert_contains "$SYNC_ALL" "$base/linear_b: synced 1 mapped project(s)" "--all linear_b summary"
assert_not_contains "$SYNC_ALL" "skip_repo: synced" "--all skips non-linear repo silently"
assert_file_contains "$TMP_ROOT/curl-auth.log" "key-linear-a" "--all resolves first repo key"
assert_file_contains "$TMP_ROOT/curl-auth.log" "key-linear-b" "--all resolves second repo key"

echo "ok - beads-linear-sync"
