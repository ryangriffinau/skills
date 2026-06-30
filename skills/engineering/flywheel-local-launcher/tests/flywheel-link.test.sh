#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LINKER="$SCRIPT_DIR/../scripts/flywheel-link.sh"
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

assert_file_contains() {
  local file="$1" needle="$2" label="$3"
  grep -Fq "$needle" "$file" || fail "$label: expected $file to contain $needle"
}

assert_output_contains() {
  local file="$1" needle="$2" label="$3"
  grep -Fq "$needle" "$file" || fail "$label: expected output to contain $needle"
}

assert_file_executable() {
  local file="$1" label="$2"
  [ -x "$file" ] || fail "$label: expected $file to be executable"
}

install_stubs() {
  local bin_dir="$TMP_ROOT/bin"
  mkdir -p "$bin_dir" "$TMP_ROOT/projects"
  cat > "$bin_dir/ntm" <<'SH'
#!/usr/bin/env bash
case "${1:-} ${2:-}" in
  "config show") printf 'projects_base = "%s"\n' "$NTM_PROJECTS_BASE" ;;
  "guards install") exit 0 ;;
  "init ") exit 0 ;;
  *) exit 0 ;;
esac
SH
  cat > "$bin_dir/br" <<'SH'
#!/usr/bin/env bash
exit 0
SH
  chmod +x "$bin_dir/ntm" "$bin_dir/br"
}

new_repo() {
  local name="$1" dir
  dir="$TMP_ROOT/$name"
  mkdir -p "$dir"
  git -C "$dir" init -q
  printf '%s\n' "$dir"
}

run_setup() {
  local repo="$1" out_file="$TMP_ROOT/out"
  PATH="$TMP_ROOT/bin:$PATH" NTM_PROJECTS_BASE="$TMP_ROOT/projects" \
    bash "$LINKER" setup "$repo" >"$out_file" 2>&1
  SETUP_OUT="$out_file"
}

install_stubs

repo="$(new_repo team_repo)"
git -C "$repo" remote add origin git@example.com:org/repo.git
mkdir -p "$repo/.github/workflows"
printf '{"packageManager":"pnpm@9.12.0"}\n' > "$repo/package.json"
run_setup "$repo"
assert_file_contains "$repo/.flywheel/profile" "FLYWHEEL_MODE=team" "team scaffold mode"
assert_file_contains "$repo/.flywheel/profile" "FLYWHEEL_PRECOMMIT=light" "team scaffold precommit"
assert_file_contains "$repo/.flywheel/profile" "FLYWHEEL_PREPUSH=full" "team scaffold prepush"
assert_file_contains "$repo/.flywheel/profile" "FLYWHEEL_PROJECTION_APP=" "team scaffold projection"
assert_output_contains "$SETUP_OUT" ".flywheel/profile (mode=team, pm=pnpm, pre_commit=light)" "team summary"

repo="$(new_repo heavy_repo)"
mkdir -p "$repo/.husky"
cat > "$repo/.husky/pre-commit" <<'SH'
#!/usr/bin/env bash
npm test
SH
run_setup "$repo"
assert_file_contains "$repo/.flywheel/profile" "FLYWHEEL_MODE=solo" "solo scaffold mode"
assert_file_contains "$repo/.flywheel/profile" "FLYWHEEL_PRECOMMIT=heavy" "heavy scaffold precommit"
assert_file_contains "$repo/.husky/pre-commit" "scripts/ci/file-reservation-guard.sh" "husky hook guard"
assert_file_contains "$repo/.husky/pre-commit" "npm test" "husky hook preserves body"
assert_file_executable "$repo/scripts/ci/file-reservation-guard.sh" "husky copied guard"
assert_output_contains "$SETUP_OUT" ".husky/pre-commit looks heavy" "heavy warning"
assert_output_contains "$SETUP_OUT" ".flywheel/profile (mode=solo, pm=none, pre_commit=heavy)" "heavy summary"

cat > "$repo/.flywheel/profile" <<'PROFILE'
FLYWHEEL_MODE=team
FLYWHEEL_WORKTREES=false
FLYWHEEL_PRECOMMIT=light
FLYWHEEL_PREPUSH=full
FLYWHEEL_PROJECTION_APP=
PROFILE
run_setup "$repo"
assert_file_contains "$repo/.flywheel/profile" "FLYWHEEL_MODE=team" "existing profile preserved"
assert_file_contains "$repo/.flywheel/profile" "FLYWHEEL_PRECOMMIT=light" "existing precommit preserved"
assert_output_contains "$SETUP_OUT" ".flywheel/profile (mode=team, pm=none, pre_commit=light)" "existing summary"

repo="$(new_repo git_hook_repo)"
cat > "$repo/.git/hooks/pre-commit" <<'SH'
#!/usr/bin/env bash
br sync --flush-only
SH
chmod +x "$repo/.git/hooks/pre-commit"
run_setup "$repo"
assert_file_contains "$repo/.git/hooks/pre-commit" "scripts/ci/file-reservation-guard.sh" "git hook guard"
assert_file_contains "$repo/.git/hooks/pre-commit" "br sync --flush-only" "git hook preserves body"
assert_file_executable "$repo/scripts/ci/file-reservation-guard.sh" "git hook copied guard"
assert_output_contains "$SETUP_OUT" "lease guard chained into existing git hook (after shebang)" "git hook summary"

echo "ok - flywheel-link setup scaffold"
