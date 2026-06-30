#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECTOR="$SCRIPT_DIR/../scripts/beads-linear-projector"
TMP_ROOT="$(mktemp -d)"

cleanup() {
  if [ -d "$TMP_ROOT" ]; then
    find "$TMP_ROOT" -mindepth 1 -delete
    rmdir "$TMP_ROOT"
  fi
}
trap cleanup EXIT

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
  mkdir -p "$dir/.beads" "$dir/.flywheel"
  git -C "$dir" init -q
  printf '%s\n' "$dir"
}

run_projector() {
  local repo="$1" out_file="$TMP_ROOT/out" err_file="$TMP_ROOT/err"
  "$PROJECTOR" --repo "$repo" >"$out_file" 2>"$err_file"
  PROJECTOR_OUT="$(cat "$out_file")"
  PROJECTOR_ERR="$(cat "$err_file")"
}

repo="$(new_repo inactive)"
printf 'FLYWHEEL_MODE=solo\nFLYWHEEL_WORKTREES=false\nFLYWHEEL_PRECOMMIT=light\nFLYWHEEL_PREPUSH=full\nFLYWHEEL_PROJECTION_APP=\n' > "$repo/.flywheel/profile"
run_projector "$repo"
assert_empty "$PROJECTOR_OUT" "inactive projection stdout"
assert_empty "$PROJECTOR_ERR" "inactive projection stderr"

repo="$(new_repo linear)"
cat > "$repo/.flywheel/profile" <<'PROFILE'
FLYWHEEL_MODE=team
FLYWHEEL_WORKTREES=false
FLYWHEEL_PRECOMMIT=light
FLYWHEEL_PREPUSH=full
FLYWHEEL_PROJECTION_APP=linear
PROFILE
printf 'skills-bg7\tlin_prj_123\nother-epic\tlin_prj_other\n' > "$repo/.flywheel/projects.tsv"
cat > "$repo/.beads/issues.jsonl" <<'JSONL'
{"id":"skills-bg7","title":"Flywheel Profile","status":"open","priority":1,"issue_type":"epic"}
{"id":"skills-bg7.5","title":"Issue projection","status":"in_progress","priority":2,"issue_type":"task"}
{"id":"other","title":"Unmapped","status":"open","priority":3,"issue_type":"task"}
JSONL
run_projector "$repo"
assert_empty "$PROJECTOR_ERR" "linear projection stderr"
assert_contains "$PROJECTOR_OUT" '"app": "linear"' "linear app"
assert_contains "$PROJECTOR_OUT" '"op": "upsert_issue"' "linear op"
assert_contains "$PROJECTOR_OUT" '"projectId": "lin_prj_123"' "linear project id"
assert_contains "$PROJECTOR_OUT" '"externalId": "beads:skills-bg7.5"' "linear child external id"
assert_contains "$PROJECTOR_OUT" 'Codex workers do not apply them' "apply guidance"
if [[ "$PROJECTOR_OUT" == *'Unmapped'* ]]; then
  fail "unmapped issue should not be projected"
fi

repo="$(new_repo missing_map)"
printf 'FLYWHEEL_PROJECTION_APP=linear\n' > "$repo/.flywheel/profile"
printf '{"id":"skills-bg7","title":"Flywheel Profile","status":"open","priority":1,"issue_type":"epic"}\n' > "$repo/.beads/issues.jsonl"
run_projector "$repo"
assert_contains "$PROJECTOR_ERR" 'projects.tsv is missing' "missing projects warning"
assert_contains "$PROJECTOR_OUT" '"operations": []' "missing projects empty ops"

repo="$(new_repo unknown_app)"
printf 'FLYWHEEL_PROJECTION_APP=jira\n' > "$repo/.flywheel/profile"
run_projector "$repo"
assert_contains "$PROJECTOR_ERR" 'unsupported FLYWHEEL_PROJECTION_APP=jira' "unknown app warning"
assert_contains "$PROJECTOR_OUT" '"operations": []' "unknown app empty ops"

echo "ok - beads-linear-projector"
