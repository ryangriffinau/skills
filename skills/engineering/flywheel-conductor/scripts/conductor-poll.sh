#!/usr/bin/env bash
# conductor-poll.sh — one-shot flywheel swarm snapshot as a single JSON object.
# The conductor's tight loop: fast, read-only, deterministic shape.
#
# usage: conductor-poll.sh --session NAME --db PATH [--epic ID]
# stdout: one JSON object (contract in plan §3.3 / SKILL.md Step 4)
# exit:   0 ok · 2 usage · 3 tmux session missing · 4 beads unreachable
set -euo pipefail

usage() {
  echo "usage: conductor-poll.sh --session NAME --db PATH [--epic ID]" >&2
}

session=""
db=""
epic=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --session) [ "$#" -ge 2 ] || { usage; exit 2; }; session="$2"; shift 2 ;;
    --db)      [ "$#" -ge 2 ] || { usage; exit 2; }; db="$2"; shift 2 ;;
    --epic)    [ "$#" -ge 2 ] || { usage; exit 2; }; epic="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) usage; exit 2 ;;
  esac
done
[ -n "$session" ] && [ -n "$db" ] || { usage; exit 2; }

# --- session liveness (exit 3 if gone: that's guard G13 territory) ---
if ! tmux has-session -t "$session" 2>/dev/null; then
  exit 3
fi

# --- beads reachability (exit 4 if unreadable) ---
beads_json=""
if ! beads_json="$(br --db "$db" --allow-stale list --json 2>/dev/null)"; then
  exit 4
fi
[ -n "$beads_json" ] || exit 4
ready_json="$(br --db "$db" --allow-stale ready --json 2>/dev/null || echo '[]')"
epic_json="[]"
if [ -n "$epic" ]; then
  epic_json="$(br --db "$db" --allow-stale show "$epic" --json 2>/dev/null || echo '[]')"
fi

# --- panes: index|title plus a tail capture per pane ---
panes_meta="$(tmux list-panes -t "$session" -F '#{pane_index}|#{pane_title}' 2>/dev/null || true)"
pane_dump=""
while IFS='|' read -r idx title; do
  [ -n "$idx" ] || continue
  cap="$(tmux capture-pane -t "$session:0.$idx" -p 2>/dev/null | tail -12 || true)"
  pane_dump="${pane_dump}===PANE ${idx}|${title}===
${cap}
"
done <<EOF_PANES
$panes_meta
EOF_PANES

# --- repo context derived from the beads db path (<repo>/.beads/beads.db) ---
repo_dir="$(cd "$(dirname "$db")/.." && pwd)"
commits="$(git -C "$repo_dir" log --oneline -5 2>/dev/null || true)"

# --- ntm config health (guard G2) ---
# capture first: `grep -q` on a live pipe SIGPIPEs ntm under pipefail (flaky miss)
config_warning=false
cfg_out="$(ntm config show 2>&1 || true)"
if printf '%s' "$cfg_out" | grep -qi "config load failed"; then
  config_warning=true
fi

export POLL_SESSION="$session" POLL_EPIC="$epic" POLL_CONFIG_WARNING="$config_warning"
export POLL_BEADS_JSON="$beads_json" POLL_READY_JSON="$ready_json" POLL_EPIC_JSON="$epic_json"
export POLL_PANE_DUMP="$pane_dump" POLL_COMMITS="$commits"

python3 <<'PY'
import json, os, re, sys, time

session = os.environ["POLL_SESSION"]
epic = os.environ.get("POLL_EPIC") or None

def load(name, default):
    raw = os.environ.get(name, "")
    try:
        return json.loads(raw) if raw.strip() else default
    except json.JSONDecodeError:
        return default

rows = load("POLL_BEADS_JSON", [])
if isinstance(rows, dict):
    rows = rows.get("issues") or rows.get("data") or []
ready_rows = load("POLL_READY_JSON", [])
if isinstance(ready_rows, dict):
    ready_rows = ready_rows.get("issues") or ready_rows.get("data") or []
epic_rows = load("POLL_EPIC_JSON", [])
if isinstance(epic_rows, dict):
    epic_rows = epic_rows.get("issues") or epic_rows.get("data") or [epic_rows]

def rid(r):
    return str(r.get("id", ""))

def field_id(value):
    if isinstance(value, dict):
        return str(value.get("id", ""))
    if value is None:
        return ""
    return str(value)

parent_fields = ("parent", "parent_id", "epic", "epic_id")
epic_child_ids = set()
for er in epic_rows:
    if not isinstance(er, dict):
        continue
    for child in er.get("dependents") or er.get("children") or []:
        if not isinstance(child, dict):
            continue
        dep_type = str(child.get("dependency_type", "parent-child"))
        if dep_type in ("parent-child", "child", ""):
            cid = rid(child)
            if cid:
                epic_child_ids.add(cid)

def is_child_of_epic(r):
    if epic is None:
        return True
    if rid(r) in epic_child_ids:
        return True
    for field in parent_fields:
        if field_id(r.get(field)) == epic:
            return True
    return rid(r).startswith(epic + ".")

def in_scope(r):
    return epic is None or rid(r) == epic or is_child_of_epic(r)

scoped = [r for r in rows if isinstance(r, dict) and in_scope(r)]
children = [r for r in scoped if epic is None or rid(r) != epic]
status = lambda r: str(r.get("status", ""))

closed = [rid(r) for r in children if status(r) == "closed"]
in_progress = [rid(r) for r in children if status(r) == "in_progress"]
blocked = [{"id": rid(r)} for r in children if status(r) == "blocked"]
ready = [rid(r) for r in ready_rows if isinstance(r, dict) and in_scope(r)]

# --- pane classification ---
panes = []
dump = os.environ.get("POLL_PANE_DUMP", "")
blocks = re.split(r"^===PANE ", dump, flags=re.M)
for block in blocks:
    if not block.strip():
        continue
    header, _, body = block.partition("===\n")
    if "|" not in header:
        continue
    idx_s, _, title = header.partition("|")
    try:
        idx = int(idx_s.strip())
    except ValueError:
        continue
    tail = body.rstrip()
    state, secs = "idle", None
    m = re.search(r"Working \((?:(\d+)h\s*)?(?:(\d+)m\s*)?(?:(\d+)s)?", tail)
    if m and any(m.groups()):
        state = "working"
        h, mn, s = (int(g) if g else 0 for g in m.groups())
        secs = h * 3600 + mn * 60 + s
    else:
        last = [l for l in tail.splitlines() if l.strip()]
        tail_txt = "\n".join(last[-4:]) if last else ""
        if re.search(r"Please restart Codex|Update ran successfully", tail_txt, re.I):
            state = "needs_restart"
        elif re.search(r"(?m)^[^\n]*[$%]\s*(?:\[[0-9]{1,2}:[0-9]{2}(?::[0-9]{2})?\]\s*)?$", tail_txt) or "parse error" in tail_txt:
            state = "shell"
        elif re.search(r"error|ERR", tail_txt) and "esc to interrupt" not in tail_txt:
            state = "error"
    pane = {"idx": idx, "title": title.strip(), "state": state}
    if secs is not None:
        pane["working_secs"] = secs
    panes.append(pane)

commits = [
    {"sha": line.split()[0], "subject": line.split(" ", 1)[1] if " " in line else ""}
    for line in os.environ.get("POLL_COMMITS", "").splitlines()
    if line.strip()
]

out = {
    "ts": int(time.time()),
    "session": session,
    "epic": epic,
    "progress": {"closed": len(closed), "total": len(children)},
    "in_progress": in_progress,
    "ready": ready,
    "blocked": blocked,
    "panes": panes,
    "last_commits": commits,
    "config_warning": os.environ.get("POLL_CONFIG_WARNING") == "true",
}
json.dump(out, sys.stdout)
sys.stdout.write("\n")
PY
