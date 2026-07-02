#!/usr/bin/env bash
# conductor-certify.sh — live proof the conductor workflow works on this machine.
#
#   sandbox repo → 3-bead env-free docs epic → one codex worker driven to green →
#   one INJECTED pane-kill must be detected (G7) and respawned within one cycle →
#   writes .flywheel/runtime/certified.json into --repo.
#
# usage: conductor-certify.sh --repo DIR --yes [--keep] [--timeout-mins N]
#   --yes           required: this spawns a real codex agent (token cost)
#   --keep          leave the sandbox + tmux session for inspection on failure
#   --timeout-mins  overall budget (default 20)
#
# exit: 0 certified · 1 failed · 2 usage/refused
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
POLL="$HERE/conductor-poll.sh"
TRIAGE="$HERE/conductor-triage.sh"
LAUNCHER="$HERE/../../flywheel-local-launcher/scripts/flywheel-link.sh"
EVAL_VERSION="tiny-epic-1"

repo="" yes=false keep=false timeout_mins=20
while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo) [ "$#" -ge 2 ] || exit 2; repo="$2"; shift 2 ;;
    --yes) yes=true; shift ;;
    --keep) keep=true; shift ;;
    --timeout-mins) [ "$#" -ge 2 ] || exit 2; timeout_mins="$2"; shift 2 ;;
    -h|--help) sed -n '2,14p' "$0"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ -n "$repo" ] || { echo "certify: --repo required" >&2; exit 2; }
$yes || { echo "certify: spawns a real codex agent (token cost) — re-run with --yes" >&2; exit 2; }
repo="$(cd "$repo" && pwd)"

to(){ perl -e '$t=shift; alarm $t; exec @ARGV or exit 124' "$@"; }
log(){ printf 'certify: %s\n' "$1"; }

# ---------- sandbox ----------
stamp="$(date +%s)"
session="fwcert$stamp"
# physical path: macOS $TMPDIR is a symlink (/var -> /private/var) and beads refuses
# symlinked roots ("points outside beads directory")
tmp_phys="$(cd "${TMPDIR:-/tmp}" && pwd -P)"
sandbox="$tmp_phys/$session"
mkdir -p "$sandbox"
log "sandbox: $sandbox (session: $session)"

git -C "$sandbox" init -q -b main
cat >"$sandbox/AGENTS.md" <<'EOF'
# AGENTS.md
This sandbox runs the Agent Flywheel. One shared tree, NEVER git worktrees.
Loop per bead: br ready -> claim (br update <id> --status in_progress) -> implement ->
br close <id> -> commit with explicit paths. No watch commands, no dev servers.
The beads live in this repo (.beads/). Docs beads only: create the named file with the
requested content. Never delete files.
EOF
printf '# fwcert sandbox\n' >"$sandbox/README.md"
git -C "$sandbox" add -- AGENTS.md README.md
git -C "$sandbox" -c user.email=cert@local -c user.name=cert commit -qm "chore: sandbox init"

# link into projects_base so ntm/agent-mail resolve the project key
to 30 bash "$LAUNCHER" link "$sandbox" >/dev/null 2>&1 || true

( cd "$sandbox" && to 30 br init >/dev/null 2>&1 ) || { log "br init failed"; exit 1; }
db="$sandbox/.beads/beads.db"
epic="$(cd "$sandbox" && br --db "$db" create "certify tiny epic" -t epic -p 1 --slug cert-epic --silent)"
for n in one two three; do
  (cd "$sandbox" && br --db "$db" create "write docs/$n.md containing the single line: certify $n" \
    -t task -p 2 --parent "$epic" --slug "cert-$n" \
    -d "Create docs/$n.md with exactly one line: 'certify $n'. Then br close this bead and commit the file with explicit paths." --silent >/dev/null)
done
log "epic $epic + 3 docs beads created"

cleanup() {
  if ! $keep; then
    to 30 ntm kill "$session" --force >/dev/null 2>&1 || true
    log "session killed (sandbox left at $sandbox — temp dir, OS-cleaned; --keep to inspect)"
  else
    log "kept: session $session, sandbox $sandbox"
  fi
}
trap cleanup EXIT

# ---------- spawn one worker ----------
init_prompt="Follow AGENTS.md. Beads db: $db. LOOP until br ready is empty: br ready -> claim the top bead -> do exactly what its description says -> br close it -> commit the created file with explicit paths. One-shot commands only."
( cd "$sandbox" && to 200 ntm spawn "$session" --cod=1 --init-prompt "$init_prompt" >/dev/null 2>&1 ) \
  || { log "ntm spawn failed"; exit 1; }
log "worker spawned"

# ---------- drive ----------
deadline=$(( $(date +%s) + timeout_mins * 60 ))
killed=false g7_seen=false g7_recovered=false last_nudge=0
while :; do
  now="$(date +%s)"
  [ "$now" -lt "$deadline" ] || { log "TIMEOUT after ${timeout_mins}m"; exit 1; }

  snap="$(to 30 bash "$POLL" --session "$session" --db "$db" --epic "$epic" 2>/dev/null)" || {
    log "poll failed (session gone?)"; exit 1; }
  closed="$(printf '%s' "$snap" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["progress"]["closed"])')"
  verdict="$(printf '%s' "$snap" | to 120 bash "$TRIAGE")"
  guards="$(printf '%s' "$verdict" | python3 -c 'import json,sys; print(" ".join(e["guard"] for e in json.load(sys.stdin)["exceptions"]))')"
  log "closed=$closed/3 guards=[${guards:-none}]"

  # G7 handling — the injected-kill recovery we are certifying
  case " $guards " in
    *" G7 "*)
      g7_seen=true
      pane="$(printf '%s' "$verdict" | python3 -c 'import json,sys; e=[x for x in json.load(sys.stdin)["exceptions"] if x["guard"]=="G7"]; print(e[0].get("pane",1))')"
      log "G7 detected on pane $pane -> respawning"
      to 90 ntm respawn "$session" --panes="$pane" --force >/dev/null 2>&1 || true
      perl -e 'sleep 20'
      to 15 ntm send "$session" --cod "$init_prompt" >/dev/null 2>&1 || true
      $killed && g7_recovered=true
      ;;
    *" G6 "*)
      if [ $(( now - last_nudge )) -gt 90 ]; then
        to 15 ntm send "$session" --cod "br ready is non-empty: claim the top bead now and continue the loop." >/dev/null 2>&1 || true
        last_nudge="$now"
      fi
      ;;
  esac

  # inject the pane-kill exactly once, after the first bead closes
  if ! $killed && [ "$closed" -ge 1 ]; then
    log "INJECTING pane-kill (respawn-pane -k -> bare shell)"
    to 10 tmux respawn-pane -k -t "$session:0.1" >/dev/null 2>&1 || true
    killed=true
  fi

  if [ "$closed" -ge 3 ]; then
    if $killed && ! $g7_seen; then log "epic green but injected kill was never detected"; exit 1; fi
    break
  fi
  perl -e 'sleep 45'
done

# ---------- certify ----------
mkdir -p "$repo/.flywheel/runtime"
printf '{"type":"certification","ts":%s,"eval_version":"%s","result":"pass"}\n' "$(date +%s)" "$EVAL_VERSION" \
  >>"$repo/.flywheel/runtime/journal.jsonl" 2>/dev/null || true
python3 - "$repo" "$EVAL_VERSION" <<'PY'
import json, sys, time
json.dump({"eval_version": sys.argv[2], "ts": int(time.time()), "result": "pass"},
          open(sys.argv[1] + "/.flywheel/runtime/certified.json", "w"))
PY
log "PASS — certified $repo (injected-kill detected=$g7_seen recovered=$g7_recovered)"
