#!/usr/bin/env bash
# flywheel-link.sh — preflight + link a repo into NTM's projects_base + per-repo flywheel init.
# Bundled with the flywheel-local-launcher skill. Scope: preflight | link | setup | list ONLY.
# It deliberately does NOT launch swarms or wrap `ntm spawn`.
set -euo pipefail

base() { ntm config show 2>/dev/null | sed -n 's/^projects_base = "\(.*\)"/\1/p' | head -1; }

preflight() {
  local missing=0
  echo "Flywheel preflight:"
  for t in tmux ntm br bv dcg cass ubs claude codex; do
    if command -v "$t" >/dev/null 2>&1; then echo "  ✓ $t"; else echo "  ✗ $t (missing)"; missing=1; fi
  done
  if curl -fsS "http://127.0.0.1:8765/api/" -o /dev/null 2>/dev/null || nc -z 127.0.0.1 8765 2>/dev/null; then
    echo "  ✓ agent-mail server (:8765)"
  else
    echo "  ✗ agent-mail server not running — start it with: am"; missing=1
  fi
  local b; b="$(base)"
  if [ -n "$b" ] && [ -d "$b" ]; then echo "  ✓ projects_base = $b"; else echo "  ✗ projects_base unset — run: ntm config set projects-base <dir>"; missing=1; fi

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
    - Before closing a bead: run `ubs --fail-on-warning .` and a fresh-eyes review.
SNIP
  fi
}

setup() {
  local path="${1:-.}"
  link "$path"
  ( cd "$path"
    echo "==> br init";            br init             || echo "  (br init skipped/failed — already initialised?)"
    echo "==> ntm init";           ntm init           || echo "  (ntm init skipped/failed)"
    echo "==> ntm guards install"; ntm guards install || echo "  (ntm guards install skipped/failed)"
    echo "==> AGENTS.md check";    agents_md_check
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
