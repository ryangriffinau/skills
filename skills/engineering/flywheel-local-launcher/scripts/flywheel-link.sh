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

install_guard() {
  # `ntm guards install` wants to OWN the pre-commit hook and fails when husky already has one
  # (it targets .husky/_/pre-commit). On a husky repo, chain the portable lease guard from the
  # existing hook instead, so the guard and the repo's own checks both run. See setup.md.
  local hook=.husky/pre-commit
  if [ -f "$hook" ]; then
    mkdir -p scripts/ci
    cp "$SCRIPT_DIR/file-reservation-guard.sh" scripts/ci/file-reservation-guard.sh
    chmod +x scripts/ci/file-reservation-guard.sh
    if grep -q 'file-reservation-guard.sh' "$hook"; then
      echo "  ✓ lease guard already chained in $hook"
    elif head -1 "$hook" | grep -q '^#!'; then
      printf '%s\nscripts/ci/file-reservation-guard.sh\n%s\n' "$(head -1 "$hook")" "$(tail -n +2 "$hook")" > "$hook"
      echo "  ✓ lease guard chained into existing husky hook (after shebang)"
    else
      printf 'scripts/ci/file-reservation-guard.sh\n%s\n' "$(cat "$hook")" > "$hook"
      echo "  ✓ lease guard chained into existing husky hook"
    fi
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
    echo "==> ntm init";        ntm init  || echo "  (ntm init skipped/failed)"
    echo "==> lease guard";     install_guard
    echo "==> AGENTS.md check"; agents_md_check
  )
}

list() {
  local b f; b="$(base)"; shopt -s nullglob
  for f in "$b"/*; do [ -L "$f" ] && printf '  %s -> %s\n' "$(basename "$f")" "$(readlink "$f")"; done
}

case "${1:-preflight}" in
  preflight) preflight ;;
  link)  shift; link  "${1:-.}" ;;
  setup) shift; setup "${1:-.}" ;;
  list)  list ;;
  *) echo "usage: flywheel-link.sh {preflight | link [path] | setup [path] | list}" >&2; exit 2 ;;
esac
