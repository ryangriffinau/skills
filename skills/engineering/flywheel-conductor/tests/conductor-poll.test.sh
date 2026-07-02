#!/usr/bin/env bash
# Contract test for conductor-poll.sh with mocked br/tmux/git/ntm on PATH.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/../scripts/conductor-poll.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
MOCK="$TMP/bin"
mkdir -p "$MOCK" "$TMP/repo/.beads"
touch "$TMP/repo/.beads/beads.db"

fail() { echo "FAIL: $1" >&2; exit 1; }

# --- mock tmux ---
cat >"$MOCK/tmux" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  has-session) [ "${MOCK_NO_SESSION:-}" = "1" ] && exit 1 || exit 0 ;;
  list-panes)  printf '1|swarm__cod_1\n2|swarm__cod_2\n' ;;
  capture-pane)
    case "$*" in
      *":0.1"*) printf '• Editing files\n• Working (2m 5s • esc to interrupt)\n  gpt-5.5 high\n' ;;
      *":0.2"*)
        if [ "${MOCK_RESTART_PANE:-}" = "1" ]; then
          printf 'Update ran successfully\nPlease restart Codex\nuser:repo/ (branch*) $                 [20:55:57]\n'
        elif [ "${MOCK_TIMESTAMP_PROMPT:-}" = "1" ]; then
          printf 'user:repo/ (branch*) $                 [20:55:57]\n'
        else
          printf 'zsh: parse error near\nuser:repo/ (branch*) $ \n'
        fi ;;
    esac ;;
esac
EOF

# --- mock br ---
cat >"$MOCK/br" <<'EOF'
#!/usr/bin/env bash
[ "${MOCK_BR_FAIL:-}" = "1" ] && exit 1
has_all=false
for arg in "$@"; do
  [ "$arg" = "--all" ] && has_all=true
done
for a in "$@"; do
  case "$a" in
    list)
      if [ "${MOCK_SLUG_CHILDREN:-}" = "1" ]; then
        printf '[{"id":"e","status":"open"},{"id":"cert-one-aaa","parent":"e","status":"closed"},{"id":"cert-two-bbb","parent_id":"e","status":"closed"},{"id":"cert-three-ccc","epic_id":"e","status":"in_progress"},{"id":"other-x","status":"open"}]\n'
      elif [ "${MOCK_CLOSED_ONLY_WITH_ALL:-}" = "1" ]; then
        if $has_all; then
          printf '[{"id":"e","status":"open"},{"id":"e.1","status":"closed"},{"id":"e.2","status":"in_progress"},{"id":"e.3","status":"closed"},{"id":"e.4","status":"open"},{"id":"other-x","status":"open"}]\n'
        else
          printf '[{"id":"e","status":"open"},{"id":"e.2","status":"in_progress"},{"id":"e.4","status":"open"},{"id":"other-x","status":"open"}]\n'
        fi
      else
        printf '[{"id":"e","status":"open"},{"id":"e.1","status":"closed"},{"id":"e.2","status":"in_progress"},{"id":"e.3","status":"blocked"},{"id":"e.4","status":"open"},{"id":"other-x","status":"open"}]\n'
      fi
      exit 0 ;;
    ready)
      if [ "${MOCK_SLUG_CHILDREN:-}" = "1" ]; then
        printf '[{"id":"cert-three-ccc"},{"id":"other-x"}]\n'
      else
        printf '[{"id":"e.4"},{"id":"other-x"}]\n'
      fi
      exit 0 ;;
    show)
      printf '[{"id":"e","status":"open","dependents":[{"id":"cert-one-aaa","dependency_type":"parent-child"},{"id":"cert-two-bbb","dependency_type":"parent-child"},{"id":"cert-three-ccc","dependency_type":"parent-child"},{"id":"other-blocker","dependency_type":"blocks"}]}]\n'
      exit 0 ;;
  esac
done
exit 0
EOF

# --- mock git + ntm ---
cat >"$MOCK/git" <<'EOF'
#!/usr/bin/env bash
printf 'abc1234 feat: first thing\ndef5678 fix: second thing\n'
EOF
cat >"$MOCK/ntm" <<'EOF'
#!/usr/bin/env bash
if [ "${MOCK_NTM_WARN:-}" = "1" ]; then
  echo "ntm: warning: config load failed (parsing config: unknown field)" >&2
  echo "ntm: warning: config load failed (parsing config: unknown field)"
fi
echo 'projects_base = "/tmp"'
EOF
chmod +x "$MOCK"/*

run_poll() { PATH="$MOCK:$PATH" bash "$SCRIPT" --session swarm --db "$TMP/repo/.beads/beads.db" --epic e; }

# --- happy path ---
out="$(run_poll)"
echo "$out" | python3 -c '
import json, sys
d = json.load(sys.stdin)
assert d["session"] == "swarm" and d["epic"] == "e", "identity"
assert d["progress"] == {"closed": 1, "total": 4}, "progress: %s" % d["progress"]
assert d["in_progress"] == ["e.2"], "in_progress"
assert d["ready"] == ["e.4"], "ready epic-scoped: %s" % d["ready"]
assert d["blocked"] == [{"id": "e.3"}], "blocked"
p = {x["idx"]: x for x in d["panes"]}
assert p[1]["state"] == "working" and p[1]["working_secs"] == 125, "pane1: %s" % p[1]
assert p[2]["state"] == "shell", "pane2: %s" % p[2]
assert d["last_commits"][0]["sha"] == "abc1234", "commits"
assert d["config_warning"] is False, "config ok"
print("happy-path ok")
' || fail "happy path assertions"

# --- config warning surfaces (G2) ---
out="$(MOCK_NTM_WARN=1 run_poll)"
echo "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["config_warning"] is True; print("config-warning ok")' \
  || fail "config_warning not surfaced"

# --- closed beads are visible only through br list --all ---
out="$(MOCK_CLOSED_ONLY_WITH_ALL=1 run_poll)"
echo "$out" | python3 -c '
import json, sys
d = json.load(sys.stdin)
assert d["progress"] == {"closed": 2, "total": 4}, "all-progress: %s" % d["progress"]
assert d["in_progress"] == ["e.2"], "all in_progress: %s" % d["in_progress"]
assert d["ready"] == ["e.4"], "all ready: %s" % d["ready"]
print("list-all-closed ok")
' || fail "list --all closed visibility assertions"

# --- slug-id children scope by parent/dependents, not dotted id format ---
out="$(MOCK_SLUG_CHILDREN=1 run_poll)"
echo "$out" | python3 -c '
import json, sys
d = json.load(sys.stdin)
assert d["progress"] == {"closed": 2, "total": 3}, "slug progress: %s" % d["progress"]
assert d["in_progress"] == ["cert-three-ccc"], "slug in_progress: %s" % d["in_progress"]
assert d["ready"] == ["cert-three-ccc"], "slug ready: %s" % d["ready"]
print("slug-children ok")
' || fail "slug-id children assertions"

# --- shell prompt survives trailing timestamp/padding ---
out="$(MOCK_TIMESTAMP_PROMPT=1 run_poll)"
echo "$out" | python3 -c '
import json, sys
d = json.load(sys.stdin)
p = {x["idx"]: x for x in d["panes"]}
assert p[2]["state"] == "shell", "timestamp prompt pane2: %s" % p[2]
print("timestamp-shell ok")
' || fail "timestamp shell assertions"

# --- Codex update/restart banner is distinct from plain shell ---
out="$(MOCK_RESTART_PANE=1 run_poll)"
echo "$out" | python3 -c '
import json, sys
d = json.load(sys.stdin)
p = {x["idx"]: x for x in d["panes"]}
assert p[2]["state"] == "needs_restart", "restart pane2: %s" % p[2]
print("needs-restart ok")
' || fail "needs_restart assertions"

# --- exit 3 on missing session (G13) ---
set +e
MOCK_NO_SESSION=1 run_poll >/dev/null 2>&1
[ "$?" -eq 3 ] || fail "expected exit 3 on missing session"
set -e
echo "exit-3 ok"

# --- exit 4 on unreachable beads ---
set +e
MOCK_BR_FAIL=1 run_poll >/dev/null 2>&1
[ "$?" -eq 4 ] || fail "expected exit 4 on unreachable beads"
set -e
echo "exit-4 ok"

echo "PASS conductor-poll.test.sh"
