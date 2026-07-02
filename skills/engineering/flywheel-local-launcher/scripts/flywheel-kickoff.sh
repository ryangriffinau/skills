#!/usr/bin/env bash
# Generate the flywheel swarm launch recipe from the resolved repo profile.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RESOLVER="$SCRIPT_DIR/flywheel-profile.sh"

usage() {
  echo "usage: flywheel-kickoff.sh <session> --plan PATH [--cod N] [--cass AREA]" >&2
}

shell_quote() {
  local value="$1"
  value="${value//\'/\'\\\'\'}"
  printf "'%s'" "$value"
}

session=""
plan=""
cod_count="3"
cass_area=""

if [ "$#" -gt 0 ]; then
  session="$1"
  shift
fi

while [ "$#" -gt 0 ]; do
  case "$1" in
    --plan)
      [ "$#" -ge 2 ] || { usage; exit 2; }
      plan="$2"
      shift 2
      ;;
    --cod)
      [ "$#" -ge 2 ] || { usage; exit 2; }
      cod_count="$2"
      shift 2
      ;;
    --cass)
      [ "$#" -ge 2 ] || { usage; exit 2; }
      cass_area="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done

if [ -z "$session" ] || [ -z "$plan" ]; then
  usage
  exit 2
fi

case "$cod_count" in
  ''|*[!0-9]*)
    echo "flywheel-kickoff.sh: --cod must be a positive integer" >&2
    exit 2
    ;;
  0)
    echo "flywheel-kickoff.sh: --cod must be greater than zero" >&2
    exit 2
    ;;
esac

eval "$("$RESOLVER" --repo .)"

pm_guidance() {
  case "$FLYWHEEL_PM" in
    pnpm) echo "Package manager: pnpm. Use pnpm commands such as pnpm install, pnpm test, pnpm build, and pnpm typecheck when those scripts exist." ;;
    bun) echo "Package manager: bun. Use bun commands such as bun install, bun test, bun run build, and bun run typecheck when those scripts exist." ;;
    npm) echo "Package manager: npm. Use npm commands such as npm install, npm test, npm run build, and npm run typecheck when those scripts exist." ;;
    yarn) echo "Package manager: yarn. Use yarn commands such as yarn install, yarn test, yarn build, and yarn typecheck when those scripts exist." ;;
    *) echo "Package manager: none detected. Run focused repo tests directly; for bash changes, use bash -n, shellcheck when available, and the relevant shell test scripts." ;;
  esac
}

mode_guidance() {
  case "$FLYWHEEL_MODE" in
    team) echo "Final ship bead: open the PR ready so CI and preview run, enable auto-merge if available, and merge when green: directly for safe non-prod/template changes, otherwise with user approval. Do not block-poll CI." ;;
    *) echo "Final ship bead: commit and push to the working branch; no PR." ;;
  esac
}

precommit_guidance() {
  if [ "$FLYWHEEL_PRECOMMIT" = "heavy" ]; then
    echo "This repo has a heavy pre-commit profile; do the hook-align bead first before broad implementation."
  fi
}

cass_guidance=""
if [ -n "$cass_area" ]; then
  cass_guidance=" Pull context with cass pack --robot \"$cass_area\" when useful."
fi

init_prompt="$(
  cat <<PROMPT
Follow AGENTS.md. Run /p-deep-project-primer first. Plan: $plan. Loop: run br ready, claim the next ready bead, reserve files via Agent Mail BEFORE editing, implement and test, run ubs --staged --fail-on-warning plus fresh-eyes review, br close the bead id, then commit AND push immediately with explicit file paths and never git add dot. Continue until br ready is empty.$cass_guidance ONE shared tree, NEVER worktrees. Commits: conventional commits with lowercase subject and a valid scope. $(pm_guidance) $(mode_guidance) $(precommit_guidance)
PROMPT
)"

spawn_cmd="ntm spawn $(shell_quote "$session") --cod=$cod_count --assign --strategy=dependency"
if [ -n "$cass_area" ]; then
  spawn_cmd="$spawn_cmd --cass-context $(shell_quote "$cass_area")"
fi
spawn_cmd="$spawn_cmd --init-prompt $(shell_quote "$init_prompt")"

cat <<RECIPE
$spawn_cmd

Conductor note: do NOT launch a controller pane — a same-account Claude controller
rate-limits itself (flywheel-conductor guard G1). Drive this swarm from your own agent
session with the flywheel-conductor skill (poll -> triage -> act -> journal).

Readiness note: if 0/$cod_count agents are ready, respawn Codex panes with: ntm respawn $(shell_quote "$session") --type=cod --force
Then re-send the kickoff prompt to Codex panes and assign work:
ntm send $(shell_quote "$session") --cod $(shell_quote "$init_prompt")
ntm coordinator assign $(shell_quote "$session")
RECIPE
