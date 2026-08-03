#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REMEDIATOR="$SCRIPT_DIR/../scripts/flywheel-remediate.sh"
SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/flywheel-remediation-e2e.XXXXXX")"
PROJECT="$SANDBOX/example-project"
PROJECTS_BASE="$SANDBOX/projects-base"
PROJECT_LINK="$PROJECTS_BASE/example-project"

cleanup() {
  [ ! -L "$PROJECT_LINK" ] || rm "$PROJECT_LINK"
  if [ -d "$SANDBOX" ]; then
    find "$SANDBOX" -depth -type f -delete
    find "$SANDBOX" -depth -type l -delete
    find "$SANDBOX" -depth -type d -exec rmdir {} + 2>/dev/null || true
  fi
}
trap cleanup EXIT

fail() {
  echo "not ok - $1" >&2
  exit 1
}

mkdir -p "$PROJECT/.backpocket/orchestrator/tasks" "$PROJECT/.ntm" "$PROJECTS_BASE"
git -C "$PROJECT" init -q
git -C "$PROJECT" config user.email fixture@example.test
git -C "$PROJECT" config user.name Fixture
printf '{"task":"retired-flow"}\n' > "$PROJECT/.backpocket/orchestrator/tasks/task.json"
printf 'legacy-workflow reads .backpocket/orchestrator/tasks\n' > "$PROJECT/WORKFLOW.md"
printf 'workspace = "/Users/example/Code/example-project"\n' > "$PROJECT/.ntm/config.toml"
printf 'keep me\n' > "$PROJECT/README.md"
git -C "$PROJECT" add .
git -C "$PROJECT" commit -qm 'fixture: legacy project'
ln -s "$PROJECT" "$PROJECT_LINK"

blocked_out="$SANDBOX/blocked.out"
if "$REMEDIATOR" decommission --repo "$PROJECT_LINK" \
  --legacy-token legacy-workflow \
  --archive-path .backpocket/orchestrator/tasks \
  --apply >"$blocked_out" 2>&1; then
  fail "decommission should refuse a live legacy reference"
fi
grep -Fq "WORKFLOW.md" "$blocked_out" || fail "blocked audit should name the live reference"
[ -f "$PROJECT/.backpocket/orchestrator/tasks/task.json" ] || fail "blocked audit must not move the candidate"

git -C "$PROJECT" rm -q WORKFLOW.md
"$REMEDIATOR" decommission --repo "$PROJECT_LINK" \
  --legacy-token legacy-workflow \
  --archive-path .backpocket/orchestrator/tasks \
  --apply >"$SANDBOX/decommission.out"
[ ! -e "$PROJECT/.backpocket/orchestrator/tasks" ] || fail "legacy task state should be absent"
[ -f "$PROJECT/archive/flywheel-decommission/.backpocket/orchestrator/tasks/task.json" ] || fail "task state should be archived"
if git -C "$PROJECT" grep -l -F legacy-workflow -- . ':(exclude)archive/**' >/dev/null; then
  fail "legacy token remains outside archive"
fi

ntm_hash_before="$(shasum "$PROJECT/.ntm/config.toml" | awk '{print $1}')"
"$REMEDIATOR" untrack-ntm --repo "$PROJECT_LINK" --apply >"$SANDBOX/untrack.out"
ntm_hash_after="$(shasum "$PROJECT/.ntm/config.toml" | awk '{print $1}')"
[ "$ntm_hash_before" = "$ntm_hash_after" ] || fail ".ntm contents were not preserved"
[ -z "$(git -C "$PROJECT" ls-files -- .ntm)" ] || fail ".ntm remains tracked"
git -C "$PROJECT" check-ignore -q .ntm/config.toml || fail ".ntm file is not ignored"

rm "$PROJECT_LINK"
[ ! -e "$PROJECT_LINK" ] && [ ! -L "$PROJECT_LINK" ] || fail "project symlink leaked"
find "$PROJECT" -depth -type f -delete
find "$PROJECT" -depth -type l -delete
find "$PROJECT" -depth -type d -exec rmdir {} + 2>/dev/null || true
rmdir "$PROJECTS_BASE"
rm "$blocked_out" "$SANDBOX/decommission.out" "$SANDBOX/untrack.out"
rmdir "$SANDBOX"
[ ! -e "$SANDBOX" ] || fail "temporary sandbox leaked"
trap - EXIT

echo "ok - remediation e2e: audit-then-archive, .ntm untracking, leak-free teardown"
