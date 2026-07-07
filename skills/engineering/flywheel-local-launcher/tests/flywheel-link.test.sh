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

assert_file_not_exists() {
  local file="$1" label="$2"
  [ ! -e "$file" ] || fail "$label: expected $file to be absent"
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
if [ "${1:-}" = "init" ]; then
  mkdir -p .beads
  exit 0
fi
if [ "${1:-}" = "list" ]; then
  printf '%s\n' "task fixture-bead"
  exit 0
fi
exit 0
SH
  cat > "$bin_dir/bv" <<'SH'
#!/usr/bin/env bash
if [ "${1:-}" = "--robot-triage" ]; then
  printf '%s\n' "Agent Flywheel workflow instructions" >> AGENTS.md
fi
SH
  for tool in tmux dcg cass ubs claude codex curl nc; do
    cat > "$bin_dir/$tool" <<'SH'
#!/usr/bin/env bash
exit 0
SH
  done
  chmod +x "$bin_dir/ntm" "$bin_dir/br" "$bin_dir/bv" "$bin_dir"/tmux "$bin_dir"/dcg "$bin_dir"/cass "$bin_dir"/ubs "$bin_dir"/claude "$bin_dir"/codex "$bin_dir"/curl "$bin_dir"/nc
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

canonical="$TMP_ROOT/canonical-skills"
installed="$TMP_ROOT/installed-skill"
mkdir -p "$canonical/skills/engineering/flywheel-local-launcher" "$installed/scripts"
cp "$LINKER" "$installed/scripts/flywheel-link.sh"
cat > "$canonical/skills/engineering/flywheel-local-launcher/SKILL.md" <<'MD'
---
name: flywheel-local-launcher
version: 0.3.0
---
MD
cat > "$installed/SKILL.md" <<'MD'
---
name: flywheel-local-launcher
version: 0.1.0
---
MD
preflight_out="$TMP_ROOT/preflight-out"
PATH="$TMP_ROOT/bin:/bin:/usr/bin" NTM_PROJECTS_BASE="$TMP_ROOT/projects" FLYWHEEL_PREFLIGHT_SKIP_AUTH_PROBES=1 FLYWHEEL_SKILLS_REPO="$canonical" \
  /bin/bash "$installed/scripts/flywheel-link.sh" preflight >"$preflight_out" 2>&1
assert_output_contains "$preflight_out" "flywheel-local-launcher installed skill is stale" "staleness warning"
assert_output_contains "$preflight_out" "npx skills update flywheel-local-launcher" "staleness update command"

missing_out="$TMP_ROOT/missing-preflight-out"
set +e
PATH="/bin:/usr/bin" FLYWHEEL_PREFLIGHT_SKIP_AUTH_PROBES=1 bash "$LINKER" preflight >"$missing_out" 2>&1
missing_status="$?"
set -e
[ "$missing_status" -ne 0 ] || fail "preflight missing tools should exit nonzero"
assert_output_contains "$missing_out" "Missing prerequisites" "preflight missing tools message"

repo="$(new_repo setup_red)"
setup_red_out="$TMP_ROOT/setup-red-out"
set +e
PATH="/bin:/usr/bin" FLYWHEEL_PREFLIGHT_SKIP_AUTH_PROBES=1 bash "$LINKER" setup "$repo" >"$setup_red_out" 2>&1
setup_red_status="$?"
set -e
[ "$setup_red_status" -ne 0 ] || fail "setup should abort when preflight is red"
assert_output_contains "$setup_red_out" "run bootstrap first" "setup red bootstrap hint"

repo="$(new_repo verify_incomplete)"
verify_out="$TMP_ROOT/verify-out"
set +e
PATH="$TMP_ROOT/bin:/bin:/usr/bin" NTM_PROJECTS_BASE="$TMP_ROOT/projects" bash "$LINKER" verify "$repo" >"$verify_out" 2>&1
verify_status="$?"
set -e
[ "$verify_status" -ne 0 ] || fail "verify incomplete should exit nonzero"
assert_output_contains "$verify_out" "INCOMPLETE" "verify incomplete message"

bootstrap_out="$TMP_ROOT/bootstrap-out"
PATH="$TMP_ROOT/bin:/bin:/usr/bin" bash "$LINKER" bootstrap --dry-run >"$bootstrap_out" 2>&1
assert_output_contains "$bootstrap_out" "dry-run: curl -fsSL" "bootstrap dry-run installers"
assert_output_contains "$bootstrap_out" "Codex MCP config" "bootstrap codex config"
assert_output_contains "$bootstrap_out" "ntm config set projects-base" "bootstrap ntm config"
assert_output_contains "$bootstrap_out" "cass index" "bootstrap cass index"
assert_output_contains "$bootstrap_out" "flywheel-link.sh preflight" "bootstrap reruns preflight"

repo="$(new_repo team_repo)"
git -C "$repo" remote add origin git@example.com:org/repo.git
mkdir -p "$repo/.github/workflows"
printf '{"packageManager":"pnpm@9.12.0"}\n' > "$repo/package.json"
printf '{}\n' > "$repo/biome.json"
printf 'dist/\n' > "$repo/.prettierignore"
run_setup "$repo"
assert_file_contains "$repo/.flywheel/profile" "FLYWHEEL_MODE=team" "team scaffold mode"
assert_file_contains "$repo/.flywheel/profile" "FLYWHEEL_PRECOMMIT=light" "team scaffold precommit"
assert_file_contains "$repo/.flywheel/profile" "FLYWHEEL_PREPUSH=full" "team scaffold prepush"
assert_file_contains "$repo/.flywheel/profile" "FLYWHEEL_PROJECTION_APP=" "team scaffold projection"
assert_file_contains "$repo/.flywheel/profile" "# FLYWHEEL_ENV_REQUIRED=LINEAR_API_KEY" "team scaffold env required example"
assert_file_contains "$repo/.prettierignore" ".beads/" "prettier ignores beads"
assert_file_contains "$repo/.prettierignore" ".ntm/" "prettier ignores ntm"
assert_file_contains "$repo/.gitignore" ".flywheel/runtime/" "gitignore runtime"
assert_file_contains "$repo/.gitignore" ".bv/" "gitignore bv"
assert_file_contains "$repo/.gitignore" ".ntm/" "gitignore ntm"
assert_file_contains "$repo/AGENTS.md" "Agent Flywheel workflow instructions" "bv injection triggered"
assert_output_contains "$SETUP_OUT" ".flywheel/profile (mode=team, pm=pnpm, pre_commit=light)" "team summary"
assert_output_contains "$SETUP_OUT" "structured linter config detected: biome.json" "structured linter warning"
assert_output_contains "$SETUP_OUT" "commit it as part of setup" "agents injection commit instruction"

repo="$(new_repo heavy_repo)"
mkdir -p "$repo/.husky"
cat > "$repo/.husky/pre-commit" <<'SH'
#!/usr/bin/env bash
npm test
SH
run_setup "$repo"
assert_file_contains "$repo/.flywheel/profile" "FLYWHEEL_MODE=solo" "solo scaffold mode"
assert_file_contains "$repo/.flywheel/profile" "FLYWHEEL_PRECOMMIT=heavy" "heavy scaffold precommit"
assert_file_contains "$repo/.husky/pre-commit" 'scripts/ci/file-reservation-guard.sh || exit $?' "husky hook guard"
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
touch hook-continued
SH
chmod +x "$repo/.git/hooks/pre-commit"
run_setup "$repo"
assert_file_contains "$repo/.git/hooks/pre-commit" 'scripts/ci/file-reservation-guard.sh || exit $?' "git hook guard"
assert_file_contains "$repo/.git/hooks/pre-commit" "touch hook-continued" "git hook preserves body"
assert_file_executable "$repo/scripts/ci/file-reservation-guard.sh" "git hook copied guard"
assert_output_contains "$SETUP_OUT" "lease guard chained into existing git hook (after shebang)" "git hook summary"
cat > "$repo/scripts/ci/file-reservation-guard.sh" <<'SH'
#!/usr/bin/env bash
exit 42
SH
chmod +x "$repo/scripts/ci/file-reservation-guard.sh"
set +e
(cd "$repo" && bash .git/hooks/pre-commit)
hook_status="$?"
set -e
[ "$hook_status" -ne 0 ] || fail "git hook fail closed: expected nonzero exit"
assert_file_not_exists "$repo/hook-continued" "git hook fail closed"

repo="$(new_repo guard_soft_pass_repo)"
printf 'change\n' > "$repo/file.txt"
git -C "$repo" add file.txt
set +e
guard_output="$(cd "$repo" && MCP_AGENT_MAIL_PYTHON="$TMP_ROOT/missing-python" bash "$SCRIPT_DIR/../scripts/file-reservation-guard.sh" 2>&1)"
guard_status="$?"
set -e
[ "$guard_status" -eq 0 ] || fail "guard soft-pass: expected exit 0 when Agent Mail stack is absent"
case "$guard_output" in
  *"Agent Mail stack unavailable; skipping lease check"*) ;;
  *) fail "guard soft-pass: expected unavailable warning" ;;
esac

repo="$(new_repo legacy_hook_repo)"
cat > "$repo/.git/hooks/pre-commit" <<'SH'
#!/usr/bin/env bash
scripts/ci/file-reservation-guard.sh
touch legacy-continued
SH
chmod +x "$repo/.git/hooks/pre-commit"
run_setup "$repo"
assert_file_contains "$repo/.git/hooks/pre-commit" 'scripts/ci/file-reservation-guard.sh || exit $?' "legacy git hook guard upgraded"
assert_file_contains "$repo/.git/hooks/pre-commit" "touch legacy-continued" "legacy git hook preserves body"
assert_output_contains "$SETUP_OUT" "lease guard updated to fail closed in .git/hooks/pre-commit" "legacy git hook summary"

echo "ok - flywheel-link setup scaffold"
