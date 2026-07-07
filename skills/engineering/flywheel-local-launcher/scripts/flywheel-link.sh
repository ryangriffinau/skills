#!/usr/bin/env bash
# flywheel-link.sh — preflight + link a repo into NTM's projects_base + per-repo flywheel init.
# Bundled with the flywheel-local-launcher skill. Scope: preflight | link | setup | list ONLY.
# It deliberately does NOT launch swarms or wrap `ntm spawn`.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

base() { ntm config show 2>/dev/null | sed -n 's/^projects_base = "\(.*\)"/\1/p' | head -1; }

run_probe_command() {
  local timeout_seconds="$1" output_file status_file pid elapsed status
  shift
  PROBE_OUTPUT=""
  output_file="$(mktemp "${TMPDIR:-/tmp}/flywheel-preflight-output.XXXXXX")"
  status_file="$(mktemp "${TMPDIR:-/tmp}/flywheel-preflight-status.XXXXXX")"
  (
    set +e
    "$@" >"$output_file" 2>&1
    printf '%s' "$?" >"$status_file"
  ) &
  pid="$!"
  elapsed=0
  while kill -0 "$pid" 2>/dev/null; do
    if [ -s "$status_file" ]; then
      break
    fi
    if [ "$elapsed" -ge "$timeout_seconds" ]; then
      kill "$pid" 2>/dev/null || true
      sleep 1
      kill -9 "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
      PROBE_OUTPUT="$(cat "$output_file" 2>/dev/null || true)"
      rm -f "$output_file" "$status_file"
      return 124
    fi
    sleep 1
    elapsed=$((elapsed + 1))
  done
  wait "$pid" 2>/dev/null || true
  if [ -s "$status_file" ]; then
    status="$(cat "$status_file")"
  else
    status=1
  fi
  PROBE_OUTPUT="$(cat "$output_file" 2>/dev/null || true)"
  rm -f "$output_file" "$status_file"
  return "$status"
}

probe_codex_exec() {
  printf 'Reply with ok only.\n' | codex exec --skip-git-repo-check --sandbox read-only --color never -
}

probe_claude_login() {
  claude -p --output-format text 'Reply with ok only.'
}

first_probe_line() {
  printf '%s\n' "$1" | sed -n '1p'
}

probe_warning() {
  local tool="$1" reason="$2" detail="${3:-}"
  echo "  ⚠ $tool probe warning: $reason"
  if [ -n "$detail" ]; then
    echo "    $(first_probe_line "$detail")"
  fi
}

probe_auth_state() {
  local timeout_seconds="${FLYWHEEL_PREFLIGHT_PROBE_TIMEOUT:-45}" codex_status claude_status lower
  case "$timeout_seconds" in
    ''|*[!0-9]*) timeout_seconds=45 ;;
  esac
  if [ "${FLYWHEEL_PREFLIGHT_SKIP_AUTH_PROBES:-0}" = "1" ]; then
    echo "  - codex/claude auth probes skipped via FLYWHEEL_PREFLIGHT_SKIP_AUTH_PROBES=1"
    return 0
  fi

  if command -v codex >/dev/null 2>&1; then
    if run_probe_command "$timeout_seconds" probe_codex_exec; then
      lower="$(printf '%s\n' "$PROBE_OUTPUT" | tr '[:upper:]' '[:lower:]')"
      if printf '%s\n' "$lower" | grep -Eq 'please restart|restart codex|self[- ]?update|updated.*codex|codex.*updated|new version'; then
        probe_warning "codex" "Codex appears to have updated; restart Codex before spawning" "$PROBE_OUTPUT"
      elif [ -n "$PROBE_OUTPUT" ]; then
        echo "  ✓ codex exec probe"
      else
        probe_warning "codex" "codex exec returned no text"
      fi
    else
      codex_status="$?"
      lower="$(printf '%s\n' "$PROBE_OUTPUT" | tr '[:upper:]' '[:lower:]')"
      if [ "$codex_status" -eq 124 ]; then
        probe_warning "codex" "codex exec timed out after ${timeout_seconds}s" "$PROBE_OUTPUT"
      elif printf '%s\n' "$lower" | grep -Eq 'please restart|restart codex|self[- ]?update|updated.*codex|codex.*updated|new version'; then
        probe_warning "codex" "Codex appears to have updated; restart Codex before spawning" "$PROBE_OUTPUT"
      elif printf '%s\n' "$lower" | grep -Eq '401|unauthori[sz]ed|authentication|not logged in|log in|login|api key|invalid.*auth'; then
        probe_warning "codex" "codex exec looks unauthenticated" "$PROBE_OUTPUT"
      else
        probe_warning "codex" "codex exec failed with exit $codex_status" "$PROBE_OUTPUT"
      fi
    fi
  fi

  if command -v claude >/dev/null 2>&1; then
    if run_probe_command "$timeout_seconds" probe_claude_login; then
      lower="$(printf '%s\n' "$PROBE_OUTPUT" | tr '[:upper:]' '[:lower:]')"
      if printf '%s\n' "$lower" | grep -Eq '401|unauthori[sz]ed|authentication|not logged in|/login|log in|login|invalid.*auth'; then
        probe_warning "claude" "claude looks unauthenticated" "$PROBE_OUTPUT"
      elif [ -n "$PROBE_OUTPUT" ]; then
        echo "  ✓ claude login probe"
      else
        probe_warning "claude" "claude returned no text"
      fi
    else
      claude_status="$?"
      lower="$(printf '%s\n' "$PROBE_OUTPUT" | tr '[:upper:]' '[:lower:]')"
      if [ "$claude_status" -eq 124 ]; then
        probe_warning "claude" "claude login probe timed out after ${timeout_seconds}s" "$PROBE_OUTPUT"
      elif printf '%s\n' "$lower" | grep -Eq '401|unauthori[sz]ed|authentication|not logged in|/login|log in|login|invalid.*auth'; then
        probe_warning "claude" "claude looks unauthenticated" "$PROBE_OUTPUT"
      else
        probe_warning "claude" "claude probe failed with exit $claude_status" "$PROBE_OUTPUT"
      fi
    fi
  fi
}

preflight() {
  local missing=0
  echo "Flywheel preflight:"
  for t in tmux ntm br bv dcg cass ubs claude codex; do
    if command -v "$t" >/dev/null 2>&1; then echo "  ✓ $t"; else echo "  ✗ $t (missing)"; missing=1; fi
  done
  if curl -fsS --max-time 3 "http://127.0.0.1:8765/" -o /dev/null 2>/dev/null || nc -z 127.0.0.1 8765 2>/dev/null; then
    echo "  ✓ agent-mail server (:8765)"
  else
    echo "  ✗ agent-mail server not running — start it with: am"; missing=1
  fi
  local b; b="$(base)"
  if [ -n "$b" ] && [ -d "$b" ]; then echo "  ✓ projects_base = $b"; else echo "  ✗ projects_base unset — run: ntm config set projects-base <dir>"; missing=1; fi
  probe_auth_state

  if [ "$missing" -ne 0 ]; then
    echo
    echo "Missing prerequisites. To install the stack:"
    case "$(uname -s)" in
      Linux)  echo "  Remote/Linux → one-shot ACFS bootstrap:"
              echo '    curl -fsSL "https://raw.githubusercontent.com/Dicklesworthstone/agentic_coding_flywheel_setup/main/install.sh?$(date +%s)" | bash -s -- --yes --mode vibe' ;;
      Darwin) echo "  macOS → ACFS is Linux-only; install each tool via its install.sh."
              echo "  See references/cheatsheet.md §3 for the exact per-tool commands." ;;
      *)      echo "  See references/cheatsheet.md §3." ;;
    esac
    return 1
  fi
  echo "All flywheel prerequisites present."
}

link() {
  local path="${1:-.}" abs b name dest
  abs="$(cd "$path" && pwd)"; b="$(base)"
  [ -n "$b" ] || { echo "could not read projects_base from 'ntm config'" >&2; return 1; }
  name="$(basename "$abs")"; dest="$b/$name"
  if [ -L "$dest" ] || [ -e "$dest" ]; then echo "already linked: $dest"; return 0; fi
  ln -s "$abs" "$dest"
  echo "linked $name -> $abs   (spawnable as: ntm spawn $name ...)"
}

agents_md_check() {
  if [ -f AGENTS.md ] && grep -qiE 'worktree' AGENTS.md; then
    echo "  ✓ AGENTS.md mentions a worktree policy"
  else
    cat <<'SNIP'
  ⚠ AGENTS.md has no flywheel / no-worktree protocol. Suggested snippet (DO NOT auto-add — confirm with the user first):

    ## Agent Flywheel protocol
    - Work in the single shared tree on the current branch. NEVER create or use git worktrees.
    - Coordinate via Agent Mail: reserve files before editing; message peers; release when done.
    - Pull next ready work with `bv`; pull prior context with `cass pack --robot "<topic>"`.
    - Before closing a bead: run `ubs --staged --fail-on-warning` and a fresh-eyes review.
SNIP
  fi
}

profile_mode_default() {
  if [ -d .github/workflows ] && [ -n "$(git remote 2>/dev/null | head -n 1)" ]; then
    printf 'team'
  else
    printf 'solo'
  fi
}

profile_precommit_default() {
  if [ -f .husky/pre-commit ] && grep -qiE 'typecheck|build|test' .husky/pre-commit; then
    printf 'heavy'
  else
    printf 'light'
  fi
}

print_heavy_precommit_warning() {
  cat <<'SNIP'
  ⚠ .husky/pre-commit looks heavy (typecheck/build/test). For commit-immediately flow,
    consider keeping pre-commit fast and moving heavy gates to pre-push or CI.
SNIP
}

print_profile_summary() {
  local resolved
  if resolved="$("$SCRIPT_DIR/flywheel-profile.sh" --repo .)"; then
    eval "$resolved"
    echo "  ✓ .flywheel/profile (mode=${FLYWHEEL_MODE}, pm=${FLYWHEEL_PM}, pre_commit=${FLYWHEEL_PRECOMMIT})"
  else
    echo "  ⚠ could not resolve .flywheel/profile" >&2
    return 1
  fi
}

scaffold_profile() {
  local profile=.flywheel/profile mode precommit
  if [ -f "$profile" ]; then
    print_profile_summary
    return 0
  fi

  mode="$(profile_mode_default)"
  precommit="$(profile_precommit_default)"
  mkdir -p .flywheel
  cat > "$profile" <<PROFILE
# .flywheel/profile — per-repo Agent Flywheel contract. Generated by fw setup. No secrets.
# Absent file = pure flywheel/Emmanuel defaults (solo, no PR, no projection, light gates).
FLYWHEEL_MODE=$mode
FLYWHEEL_WORKTREES=false
FLYWHEEL_PRECOMMIT=$precommit
FLYWHEEL_PREPUSH=full
FLYWHEEL_PROJECTION_APP=

# Required env var names checked before a swarm starts, comma-separated.
# FLYWHEEL_ENV_REQUIRED=LINEAR_API_KEY

# To project beads to Linear, set FLYWHEEL_PROJECTION_APP=linear and add:
# .flywheel/projects.tsv  # epic-id<TAB>linear-project-id
PROFILE

  if [ "$precommit" = "heavy" ]; then
    print_heavy_precommit_warning
  fi
  print_profile_summary
}

copy_guard_script() {
  mkdir -p scripts/ci
  cp "$SCRIPT_DIR/file-reservation-guard.sh" scripts/ci/file-reservation-guard.sh
  chmod +x scripts/ci/file-reservation-guard.sh
}

guard_hook_line() {
  printf '%s\n' 'scripts/ci/file-reservation-guard.sh || exit $?'
}

append_ignore_line() {
  local file="$1" line="$2" label="$3"
  touch "$file"
  if grep -Fqx "$line" "$file"; then
    echo "  = $label already ignores $line"
  else
    printf '%s\n' "$line" >> "$file"
    echo "  + $label ignores $line"
  fi
}

plain_linter_ignore_files() {
  local found=0
  for file in .prettierignore .eslintignore; do
    if [ -f "$file" ]; then
      found=1
      append_ignore_line "$file" ".beads/" "$file"
      append_ignore_line "$file" ".ntm/" "$file"
    fi
  done
  return "$found"
}

structured_linter_configs() {
  local files=()
  for file in \
    biome.json biome.jsonc \
    ruff.toml pyproject.toml \
    .eslintrc .eslintrc.json .eslintrc.yaml .eslintrc.yml .eslintrc.js .eslintrc.cjs \
    eslint.config.js eslint.config.mjs eslint.config.cjs; do
    [ -e "$file" ] && files+=("$file")
  done
  if [ "${#files[@]}" -eq 0 ]; then
    return 1
  fi

  echo "  ⚠ structured linter config detected: ${files[*]}"
  echo "    Add ignores manually where appropriate:"
  echo "      .beads/"
  echo "      .ntm/"
  return 0
}

configure_linter_ignores() {
  echo "  Exact ignore lines for flywheel state:"
  echo "    .beads/"
  echo "    .ntm/"
  plain_linter_ignore_files || true
  structured_linter_configs || true
}

ensure_gitignore_line() {
  local line="$1" label="$2"
  touch .gitignore
  if grep -Fqx "$line" .gitignore; then
    echo "  = $label already ignored"
  else
    printf '%s\n' "$line" >> .gitignore
    echo "  + $label added to .gitignore"
  fi
}

ensure_flywheel_gitignore_entries() {
  touch .gitignore
  if ! grep -Fq "flywheel conductor runtime state" .gitignore; then
    printf '\n# flywheel conductor runtime state (machine-local; see flywheel-conductor skill)\n' >> .gitignore
  fi
  ensure_gitignore_line ".flywheel/runtime/" ".flywheel/runtime/"
  ensure_gitignore_line ".bv/" ".bv/"
  ensure_gitignore_line ".ntm/" ".ntm/"
}

chain_guard_into_hook() {
  local hook="$1" label="$2" tmp guard_line
  guard_line="$(guard_hook_line)"
  copy_guard_script
  if grep -Fqx "$guard_line" "$hook"; then
    echo "  ✓ lease guard already chained in $hook"
  elif grep -Eq '^[[:space:]]*scripts/ci/file-reservation-guard\.sh[[:space:]]*$' "$hook"; then
    tmp="$(mktemp "${hook}.XXXXXX")"
    while IFS= read -r line || [ -n "$line" ]; do
      if [[ "$line" =~ ^[[:space:]]*scripts/ci/file-reservation-guard\.sh[[:space:]]*$ ]]; then
        printf '%s\n' "$guard_line"
      else
        printf '%s\n' "$line"
      fi
    done < "$hook" > "$tmp"
    mv "$tmp" "$hook"
    chmod +x "$hook"
    echo "  ✓ lease guard updated to fail closed in $hook"
  elif head -1 "$hook" | grep -q '^#!'; then
    tmp="$(mktemp "${hook}.XXXXXX")"
    {
      head -1 "$hook"
      printf '%s\n' "$guard_line"
      tail -n +2 "$hook"
    } > "$tmp"
    mv "$tmp" "$hook"
    chmod +x "$hook"
    echo "  ✓ lease guard chained into $label (after shebang)"
  else
    tmp="$(mktemp "${hook}.XXXXXX")"
    {
      printf '%s\n' "$guard_line"
      cat "$hook"
    } > "$tmp"
    mv "$tmp" "$hook"
    chmod +x "$hook"
    echo "  ✓ lease guard chained into $label"
  fi
}

install_guard() {
  # `ntm guards install` wants to OWN the pre-commit hook and fails when husky already has one
  # (it targets .husky/_/pre-commit). On a husky repo, chain the portable lease guard from the
  # existing hook instead, so the guard and the repo's own checks both run. See setup.md.
  local hook=.husky/pre-commit git_hook=.git/hooks/pre-commit
  if [ -f "$hook" ]; then
    chain_guard_into_hook "$hook" "existing husky hook"
  elif [ -f "$git_hook" ]; then
    chain_guard_into_hook "$git_hook" "existing git hook"
  else
    ntm guards install || echo "  (ntm guards install skipped/failed)"
  fi
}

setup() {
  local path="${1:-.}" abs b name dest
  abs="$(cd "$path" && pwd)"; b="$(base)"; name="$(basename "$abs")"; dest="$b/$name"
  link "$path"
  # Run the inits via the projects_base symlink path (NOT the real nested path) so Agent Mail
  # keys this repo under ONE project, matching `ntm spawn <name>`. See references/setup.md §C.
  ( cd "${dest:-$path}"
    echo "==> br init";         br init   || echo "  (br init skipped/failed — already initialised?)"
    echo "==> br/bv AGENTS.md injection"
    if command -v bv >/dev/null 2>&1; then
      bv --robot-triage >/dev/null 2>&1 \
        && echo "  + AGENTS.md workflow block triggered; commit it as part of setup" \
        || echo "  (bv --robot-triage skipped/failed)"
    else
      echo "  (bv unavailable; run bv once before the first swarm and commit any AGENTS.md change)"
    fi
    echo "==> verification bead"
    if [ "$(br list 2>/dev/null | grep -cE '\b(task|bug|feature|epic|chore)\b')" = "0" ]; then
      br create "Flywheel verification: prove the loop end-to-end" --type task --priority 3 \
        --description "Setup smoke test (flywheel-local-launcher). Claim this bead, make a trivial change (touch a scratch file or tweak a comment), run 'ubs --staged --fail-on-warning', then 'br close' it. If claim -> change -> close works, the flywheel loop is live in this repo. Safe to delete afterward." >/dev/null 2>&1 \
        && echo "  + starter verification bead created (run 'bv' to see it, then claim + close it)" \
        || echo "  (br create skipped/failed)"
    else
      echo "  = beads already present; not adding a starter bead"
    fi
    echo "==> ntm init";        ntm init  || echo "  (ntm init skipped/failed)"
    echo "==> lease guard";     install_guard
    echo "==> .flywheel/profile"; scaffold_profile
    echo "==> flywheel gitignore"; ensure_flywheel_gitignore_entries
    echo "==> linter ignores"; configure_linter_ignores
    echo "==> AGENTS.md check"; agents_md_check
  )
  verify "$path"
}

# Success test: prove the repo is flywheel-ready — resolvable by ntm AND holding a completable bead.
verify() {
  local path="${1:-.}" abs b name dest ok=1 n
  abs="$(cd "$path" && pwd)"; b="$(base)"; name="$(basename "$abs")"; dest="$b/$name"
  echo "==> verification — is '$name' flywheel-ready?"
  if [ -L "$dest" ] || [ -d "$dest" ]; then
    echo "  ✓ linked into projects_base ($dest) — 'ntm spawn $name' will resolve it"
  else
    echo "  ✗ NOT linked into projects_base — run: flywheel-link.sh link"; ok=0
  fi
  ( cd "${dest:-$path}" 2>/dev/null || cd "$path"
    if [ -d .beads ]; then echo "  ✓ beads initialised (.beads/)"; else echo "  ✗ no .beads/ — run: flywheel-link.sh setup"; fi
    n="$(br list 2>/dev/null | grep -cE '\b(task|bug|feature|epic|chore)\b' || true)"
    if [ "${n:-0}" -ge 1 ]; then
      echo "  ✓ ${n} bead(s) present — run 'bv', claim one, close it to prove the loop"
    else
      echo "  ⚠ no beads yet — create one with: br create \"<title>\" --type task"
    fi
  )
  if [ "$ok" = 1 ]; then
    echo "  ✅ SUCCESS: '$name' is flywheel-ready. Success test = 'bv' shows a bead AND 'ntm spawn $name' launches a swarm on it."
  else
    echo "  ❌ INCOMPLETE — resolve the ✗ above, then re-run: flywheel-link.sh verify"
  fi
}

list() {
  local b f; b="$(base)"; shopt -s nullglob
  for f in "$b"/*; do [ -L "$f" ] && printf '  %s -> %s\n' "$(basename "$f")" "$(readlink "$f")"; done
}

case "${1:-preflight}" in
  preflight) preflight ;;
  link)  shift; link  "${1:-.}" ;;
  setup) shift; setup "${1:-.}" ;;
  verify) shift; verify "${1:-.}" ;;
  list)  list ;;
  *) echo "usage: flywheel-link.sh {preflight | link [path] | setup [path] | verify [path] | list}" >&2; exit 2 ;;
esac
