#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KICKOFF="$SCRIPT_DIR/../scripts/flywheel-kickoff.sh"
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

new_repo() {
  local name="$1" dir
  dir="$TMP_ROOT/$name"
  mkdir -p "$dir"
  git -C "$dir" init -q
  printf '%s\n' "$dir"
}

run_kickoff() {
  local repo="$1"
  shift
  ( cd "$repo" && "$KICKOFF" "$@" )
}

repo="$(new_repo solo_pnpm)"
printf '{"packageManager":"pnpm@9.12.0"}\n' > "$repo/package.json"
output="$(run_kickoff "$repo" alpha --plan "docs/specs/flywheel profile/PLAN.md" --cod 2 --cass "flywheel profile")"
first_line="$(printf '%s\n' "$output" | sed -n '1p')"
assert_contains "$first_line" "ntm spawn 'alpha' --cod=2 --assign --strategy=dependency --cass-context 'flywheel profile' --init-prompt '" "solo spawn shape"
assert_contains "$output" "Plan: docs/specs/flywheel profile/PLAN.md." "plan in prompt"
assert_contains "$output" "Package manager: pnpm." "pnpm guidance"
assert_contains "$output" "Final ship bead: commit and push to the working branch; no PR." "solo ship guidance"
assert_not_contains "$output" "ntm controller" "no controller pane (conductor guard G1)"
assert_contains "$output" "flywheel-conductor" "conductor note present"
assert_contains "$output" "Readiness note: if 0/2 agents are ready" "readiness count"
assert_contains "$output" "ntm coordinator assign 'alpha'" "assign command"

repo="$(new_repo team_bun)"
mkdir -p "$repo/.flywheel"
cat > "$repo/.flywheel/profile" <<'PROFILE'
FLYWHEEL_MODE=team
FLYWHEEL_PRECOMMIT=heavy
PROFILE
touch "$repo/bun.lockb"
output="$(run_kickoff "$repo" "team session" --plan docs/specs/flywheel-profile/PLAN.md)"
first_line="$(printf '%s\n' "$output" | sed -n '1p')"
assert_contains "$first_line" "ntm spawn 'team session' --cod=3 --assign --strategy=dependency --init-prompt '" "team spawn default cod"
assert_not_contains "$first_line" "--cass-context" "omits empty cass"
assert_contains "$output" "Package manager: bun." "bun guidance"
assert_contains "$output" "Final ship bead: open the PR ready so CI and preview run" "team ship guidance"
assert_contains "$output" "Do not block-poll CI." "team no polling"
assert_contains "$output" "heavy pre-commit profile; do the hook-align bead first" "heavy precommit guidance"
assert_contains "$output" "respawn Codex panes with: ntm respawn 'team session' --type=cod --force" "respawn command"
assert_not_contains "$output" "cass pack --robot" "omits cass guidance when --cass is absent"

repo="$(new_repo solo_bun)"
touch "$repo/bun.lockb"
output="$(run_kickoff "$repo" "solo's session" --plan "docs/specs/flywheel's profile/PLAN.md" --cass "area's memory")"
first_line="$(printf '%s\n' "$output" | sed -n '1p')"
assert_contains "$first_line" "ntm spawn 'solo'\\''s session'" "single quote session is shell-quoted"
assert_contains "$first_line" "--cass-context 'area'\\''s memory'" "single quote cass is shell-quoted"
assert_contains "$output" "Package manager: bun." "solo bun guidance"
assert_contains "$output" "Plan: docs/specs/flywheel'\\''s profile/PLAN.md." "single quote plan is shell-quoted in prompt arg"
assert_contains "$output" "cass pack --robot \"area'\\''s memory\" when useful" "includes cass guidance when --cass is present"

repo="$(new_repo team_pnpm)"
mkdir -p "$repo/.flywheel"
printf 'FLYWHEEL_MODE=team\n' > "$repo/.flywheel/profile"
printf '{"packageManager":"pnpm@9.12.0"}\n' > "$repo/package.json"
output="$(run_kickoff "$repo" gamma --plan plan.md)"
assert_contains "$output" "Package manager: pnpm." "team pnpm guidance"
assert_contains "$output" "Final ship bead: open the PR ready so CI and preview run" "team pnpm ship guidance"

repo="$(new_repo no_pm)"
output="$(run_kickoff "$repo" beta --plan plan.md)"
assert_contains "$output" "Package manager: none detected." "none guidance"

if "$KICKOFF" missing-plan >/dev/null 2>&1; then
  fail "missing --plan should fail"
fi

if "$KICKOFF" beta --plan plan.md --cod 0 >/dev/null 2>&1; then
  fail "--cod 0 should fail"
fi

echo "ok - flywheel-kickoff"
