#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/lint-skills-test.XXXXXX")"
trap 'rm -rf "$TEST_ROOT"' EXIT

fail() {
  echo "not ok - $*" >&2
  exit 1
}

new_repo() {
  local repo="$1"
  mkdir -p "$repo/scripts"
  cp "$REPO_ROOT/scripts/lint-skills" "$repo/scripts/lint-skills"
  git -C "$repo" init -q
  git -C "$repo" config user.email test@example.invalid
  git -C "$repo" config user.name "Lint Skills Test"
}

write_skill() {
  local repo="$1" name="$2" version="$3" description="$4"
  mkdir -p "$repo/skills/comms/$name"
  printf '%s\n' \
    '---' \
    "name: $name" \
    'status: drafting' \
    "version: $version" \
    'tags: [test]' \
    'updated: 2026-08-03' \
    "description: $description" \
    '---' \
    >"$repo/skills/comms/$name/SKILL.md"
}

rename_repo="$TEST_ROOT/rename"
new_repo "$rename_repo"
write_skill "$rename_repo" old-update 0.1.0 "Old update"
git -C "$rename_repo" add .
git -C "$rename_repo" commit -qm base
git -C "$rename_repo" tag base
rm "$rename_repo/skills/comms/old-update/SKILL.md"
rmdir "$rename_repo/skills/comms/old-update"
write_skill "$rename_repo" write-update 0.2.0 "Renamed update"
git -C "$rename_repo" add -A
git -C "$rename_repo" commit -qm rename
(
  cd "$rename_repo"
  scripts/lint-skills --check-version-bumps --base-ref base
) >/dev/null || fail "renamed skill should pass version-bump enforcement"
echo "ok - deleted source directory is skipped during a skill rename"

modified_repo="$TEST_ROOT/modified"
new_repo "$modified_repo"
write_skill "$modified_repo" write-update 0.1.0 "Original description"
git -C "$modified_repo" add .
git -C "$modified_repo" commit -qm base
git -C "$modified_repo" tag base
write_skill "$modified_repo" write-update 0.1.0 "Changed without a version bump"
git -C "$modified_repo" add .
git -C "$modified_repo" commit -qm modify
if modified_output="$({
  cd "$modified_repo"
  scripts/lint-skills --check-version-bumps --base-ref base
} 2>&1)"; then
  fail "modified surviving skill should fail without a version bump"
fi
case "$modified_output" in
  *"version stayed 0.1.0"*) ;;
  *) fail "unchanged-version failure did not explain the stale version" ;;
esac
echo "ok - surviving modified skill still requires a version bump"

malformed_repo="$TEST_ROOT/malformed"
new_repo "$malformed_repo"
write_skill "$malformed_repo" write-update 0.1.0 "Original description"
mkdir -p "$malformed_repo/skills/comms/write-update/references"
printf '%s\n' '# Reference' >"$malformed_repo/skills/comms/write-update/references/NOTES.md"
git -C "$malformed_repo" add .
git -C "$malformed_repo" commit -qm base
git -C "$malformed_repo" tag base
rm "$malformed_repo/skills/comms/write-update/SKILL.md"
git -C "$malformed_repo" add -A
git -C "$malformed_repo" commit -qm malformed
if malformed_output="$({
  cd "$malformed_repo"
  scripts/lint-skills --check-version-bumps --base-ref base
} 2>&1)"; then
  fail "surviving skill directory without SKILL.md should fail"
fi
case "$malformed_output" in
  *"changed skill directory has no SKILL.md"*) ;;
  *) fail "missing-entrypoint failure did not identify SKILL.md" ;;
esac
echo "ok - surviving malformed skill directory still fails"
