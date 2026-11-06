#!/usr/bin/env bash
set -euo pipefail

SKILL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$SKILL_ROOT/scripts/agent-5-hour-trigger"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/agent-5-hour-trigger-test.XXXXXX")"
trap 'rm -rf "$TEST_ROOT"' EXIT

fail() {
  echo "not ok - $*" >&2
  exit 1
}

pass() {
  echo "ok - $*"
}

# Run the check without agent markers from the session that runs the tests.
clean_check() {
  env -u CLAUDECODE -u CLAUDE_CODE_ENTRYPOINT -u CLAUDE_CODE_REMOTE -u CODEX_SANDBOX -u GEMINI_CLI \
    AGENT_5_HOUR_TRIGGER_START_PID=1 "$@" "$SCRIPT" check
}

expect_classify() {
  local path="$1" args="$2" expected="$3" actual
  actual="$("$SCRIPT" classify "$path" "$args" | tr '\n' ' ')"
  [ "$actual" = "$expected" ] || fail "classify '$path': expected '$expected', got '$actual'"
}

expect_check() {
  local name="$1" expected_exit="$2" expected_host="$3" expected_surface="$4" out rc
  shift 4
  set +e
  out="$(clean_check "$@" 2>/dev/null)"
  rc=$?
  set -e
  [ "$rc" -eq "$expected_exit" ] || fail "$name: expected exit $expected_exit, got $rc ($out)"
  grep -qx "host=$expected_host" <<<"$out" || fail "$name: expected host=$expected_host in: $out"
  grep -qx "surface=$expected_surface" <<<"$out" || fail "$name: expected surface=$expected_surface in: $out"
  pass "$name"
}

expect_classify "/Users/me/Library/Application Support/Claude/claude-code/2.1.317/x/claude.app/Contents/MacOS/claude" \
  "/Users/me/Library/Application Support/Claude/claude-code/2.1.317/x/claude.app/Contents/MacOS/claude --output-format stream-json" \
  "agent=claude surface=desktop "
expect_classify "/Applications/ChatGPT.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex" \
  "/Applications/ChatGPT.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex -c x=1 app-server" \
  "agent=codex surface=desktop "
expect_classify "/Users/me/.cursor/extensions/openai.chatgpt-26.1-darwin-arm64/bin/macos-aarch64/codex" \
  "/Users/me/.cursor/extensions/openai.chatgpt-26.1-darwin-arm64/bin/macos-aarch64/codex app-server" \
  "agent=codex surface=ide "
expect_classify "/Users/me/.codex/packages/standalone/releases/0.166.0/bin/codex" "codex --yolo" "agent=codex surface=cli "
expect_classify "claude" "claude --chrome" "agent=claude surface=cli "
expect_classify "/Users/me/.local/bin/agy" "agy --dangerously-skip-permissions" "agent=agy surface=cli "
expect_classify "/Users/me/.local/bin/agy" "agy acp" "agent=agy surface=ide "
expect_classify "/Applications/Antigravity.app/Contents/Resources/bin/agy" "/Applications/Antigravity.app/Contents/Resources/bin/agy" "agent=agy surface=desktop "
expect_classify "/usr/bin/node" "node /usr/local/bin/gemini -m flash" "agent=none "
expect_classify "/Applications/Ghostty.app/Contents/MacOS/ghostty" "ghostty" "agent=none "
pass "classify process paths"

expect_check "claude terminal CLI" 0 claude cli CLAUDECODE=1 CLAUDE_CODE_ENTRYPOINT=cli
expect_check "claude desktop" 3 claude desktop CLAUDECODE=1 CLAUDE_CODE_ENTRYPOINT=claude-desktop
expect_check "claude IDE" 3 claude ide CLAUDECODE=1 CLAUDE_CODE_ENTRYPOINT=claude-vscode
expect_check "claude web" 3 claude web CLAUDECODE=1 CLAUDE_CODE_ENTRYPOINT=cli CLAUDE_CODE_REMOTE=true
expect_check "claude SDK" 3 claude other CLAUDECODE=1 CLAUDE_CODE_ENTRYPOINT=sdk-ts
expect_check "codex sandbox marker" 5 codex sandboxed CODEX_SANDBOX=seatbelt
expect_check "codex sandbox beats leaked claude markers" 5 codex sandboxed CODEX_SANDBOX=seatbelt CLAUDECODE=1 CLAUDE_CODE_ENTRYPOINT=cli
expect_check "gemini CLI is not supported" 4 unknown unknown GEMINI_CLI=1
expect_check "no agent" 4 unknown unknown

out="$(clean_check CLAUDECODE=1 CLAUDE_CODE_ENTRYPOINT=cli)"
grep -qx "scheduler=cloud" <<<"$out" || fail "claude scheduler: $out"
pass "claude uses the cloud scheduler"

# Nearest agent ancestor wins, whatever markers leak in from outer sessions.
for host in codex agy; do
  out="$(bash -c "exec -a $host bash -c '\"$SCRIPT\" check; echo rc=\$?'" 2>/dev/null)"
  grep -qx "host=$host" <<<"$out" || fail "$host ancestry: $out"
  grep -qx "surface=cli" <<<"$out" || fail "$host ancestry surface: $out"
  grep -qx "scheduler=local" <<<"$out" || fail "$host ancestry scheduler: $out"
  grep -qx "rc=0" <<<"$out" || fail "$host ancestry exit: $out"
  pass "$host CLI ancestry"
done

out="$(bash -c "exec -a /Applications/ChatGPT.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex bash -c '\"$SCRIPT\" check; echo rc=\$?' app-server" 2>/dev/null)"
grep -qx "surface=desktop" <<<"$out" || fail "codex desktop ancestry: $out"
grep -qx "rc=3" <<<"$out" || fail "codex desktop exit: $out"
pass "codex desktop ancestry"

# Local jobs, with fake host CLIs and fake schedulers in a throwaway HOME.
mkdir -p "$TEST_ROOT/bin" "$TEST_ROOT/home"
# shellcheck disable=SC2016 # the fake commands expand these when they run
printf '#!/bin/bash\necho "fake $(basename "$0") args: $*"\n[ -n "${FAKE_SLEEP:-}" ] && sleep "$FAKE_SLEEP"\nexit 0\n' >"$TEST_ROOT/bin/codex"
cp "$TEST_ROOT/bin/codex" "$TEST_ROOT/bin/agy"
# shellcheck disable=SC2016
printf '#!/bin/bash\nf="$FAKE_SCHED/crontab"\nif [ "$1" = "-l" ]; then [ -f "$f" ] && exec cat "$f"; echo "no crontab" >&2; exit 1; fi\n[ "$1" = "-" ] && cat >"$f"\n' >"$TEST_ROOT/bin/crontab"
# shellcheck disable=SC2016
printf '#!/bin/bash\nf="$FAKE_SCHED/launchd"\ntouch "$f"\ncase "$1" in\n  bootstrap) basename "$3" .plist >>"$f" ;;\n  bootout) grep -vx "${2##*/}" "$f" >"$f.tmp" || true; mv "$f.tmp" "$f" ;;\n  print) grep -qx "${2##*/}" "$f" ;;\nesac\n' >"$TEST_ROOT/bin/launchctl"
chmod +x "$TEST_ROOT/bin/codex" "$TEST_ROOT/bin/agy" "$TEST_ROOT/bin/crontab" "$TEST_ROOT/bin/launchctl"
mkdir -p "$TEST_ROOT/sched"

run_local() {
  env -u XDG_STATE_HOME HOME="$TEST_ROOT/home" FAKE_SCHED="$TEST_ROOT/sched" PATH="$TEST_ROOT/bin:$PATH" "$@"
}

have_zone=0
for dir in /usr/share/zoneinfo /usr/lib/zoneinfo /var/db/timezone/zoneinfo; do
  if [ -f "$dir/Australia/Melbourne" ]; then
    have_zone=1
  fi
done

if [ "$have_zone" -eq 1 ]; then
  out="$("$SCRIPT" plan --host claude)"
  grep -qx "scheduler=cloud" <<<"$out" || fail "plan scheduler: $out"
  grep -qx "name=agent-5-hour-trigger" <<<"$out" || fail "plan name: $out"
  grep -qx "cron=CRON_TZ=Australia/Melbourne 7 0,5,10,15,20 \* \* \*" <<<"$out" || fail "plan cron: $out"
  grep -qE "^cron_utc=7 (4,9,13,18,23|0,5,10,14,19) \* \* \*$" <<<"$out" || fail "plan UTC cron: $out"
  grep -qx "prompt=Quickly check in and reply with OK. Do nothing else." <<<"$out" || fail "plan prompt: $out"
  pass "cloud plan"

  out="$(run_local TZ=Asia/Kolkata "$SCRIPT" install --host codex --dry-run)"
  grep -qx "local_minute=37" <<<"$out" || fail "Kolkata minute: $out"
  out="$(run_local TZ=UTC "$SCRIPT" install --host codex --dry-run)"
  grep -qx "local_minute=7" <<<"$out" || fail "UTC minute: $out"
  grep -qF '00|05|10|15|20) ;;' <<<"$out" || fail "runner hour gate missing"
  grep -qF -- "exec --skip-git-repo-check --ephemeral --sandbox read-only Quickly\\ check\\ in" <<<"$out" || fail "codex command missing: $out"
  grep -qx -- "--- dry run: nothing written" <<<"$out" || fail "dry run marker missing"
  if [ "$(uname -s)" = "Darwin" ]; then
    grep -qF "<integer>7</integer>" <<<"$out" || fail "plist minute missing"
    if command -v plutil >/dev/null 2>&1; then
      sed -n '/^--- plist$/,/^--- dry run/p' <<<"$out" | sed '1d;$d' | plutil -lint - >/dev/null ||
        fail "plist does not lint"
    fi
  else
    grep -qE '^7 \* \* \* \* /bin/bash .*# agent-5-hour-trigger:codex$' <<<"$out" || fail "crontab line missing"
  fi
  [ -z "$(find "$TEST_ROOT/home" -mindepth 1 -print -quit)" ] || fail "dry run wrote files"
  pass "codex install dry run"

  out="$(run_local TZ=UTC "$SCRIPT" install --host agy --dry-run)"
  grep -qF -- "/agy -p Quickly\\ check\\ in\\ and\\ reply\\ with\\ OK." <<<"$out" || fail "agy command missing: $out"
  pass "agy install dry run"

  # Install, detect the existing job, replace it, and remove it.
  for host in codex agy; do
    out="$(run_local "$SCRIPT" install --host "$host")"
    grep -qx "existing_state=not-installed" <<<"$out" || fail "$host first install state: $out"
    grep -qx "status=installed" <<<"$out" || fail "$host first install: $out"
    [ -x "$TEST_ROOT/home/.local/state/agent-5-hour-trigger/run-$host.sh" ] || fail "$host runner missing"
    out="$(run_local "$SCRIPT" status --host "$host")"
    grep -qx "state=installed" <<<"$out" || fail "$host status after install: $out"
    out="$(run_local "$SCRIPT" install --host "$host" 2>/dev/null)"
    grep -qx "status=already-installed" <<<"$out" || fail "$host second install: $out"
    out="$(run_local "$SCRIPT" install --host "$host" --replace)"
    grep -qx "status=installed" <<<"$out" || fail "$host replace: $out"
    out="$(run_local "$SCRIPT" uninstall --host "$host")"
    grep -qx "status=removed" <<<"$out" || fail "$host uninstall: $out"
    [ ! -e "$TEST_ROOT/home/.local/state/agent-5-hour-trigger/run-$host.sh" ] || fail "$host runner left behind"
    out="$(run_local "$SCRIPT" status --host "$host")"
    grep -qx "state=not-installed" <<<"$out" || fail "$host status after uninstall: $out"
    out="$(run_local "$SCRIPT" uninstall --host "$host")"
    grep -qx "status=not-installed" <<<"$out" || fail "$host second uninstall: $out"
    pass "$host install, duplicate check, replace and uninstall"
  done
  if [ "$(uname -s)" = "Linux" ]; then
    echo "0 3 * * * /usr/bin/true # keep" >"$TEST_ROOT/sched/crontab"
    run_local "$SCRIPT" install --host codex >/dev/null
    run_local "$SCRIPT" uninstall --host codex >/dev/null
    grep -qx "0 3 \* \* \* /usr/bin/true # keep" "$TEST_ROOT/sched/crontab" || fail "unrelated crontab line was lost"
    pass "unrelated crontab lines are kept"
  fi

  # Execute a generated runner with the hour gate opened and a short watchdog.
  run_local TZ=UTC "$SCRIPT" install --host codex --dry-run |
    sed -n '/^--- runner$/,/^--- /p' | sed '1d;$d' |
    sed -e 's/^  00|05|10|15|20) ;;/  *) ;;/' -e 's/sleep 300/sleep 1/' >"$TEST_ROOT/runner.sh"
  bash -n "$TEST_ROOT/runner.sh" || fail "runner syntax"
  mkdir -p "$TEST_ROOT/home/.local/state/agent-5-hour-trigger"
  bash "$TEST_ROOT/runner.sh"
  FAKE_SLEEP=5 bash "$TEST_ROOT/runner.sh"
  log="$TEST_ROOT/home/.local/state/agent-5-hour-trigger/codex.log"
  grep -qF "fake codex args: exec --skip-git-repo-check --ephemeral --sandbox read-only Quickly check in and reply with OK. Do nothing else." "$log" ||
    fail "runner did not call codex with one prompt argument: $(cat "$log")"
  grep -qx "exit=0" "$log" || fail "runner exit=0 missing"
  grep -qx "exit=143" "$log" || fail "watchdog did not stop a hung CLI: $(cat "$log")"
  pass "generated runner"
else
  # Without zone data, plan and install must stop instead of using UTC.
  for args in "plan --host claude" "install --host codex --dry-run"; do
    set +e
    # shellcheck disable=SC2086 # split the argument string on purpose
    out="$(run_local "$SCRIPT" $args 2>&1)"
    rc=$?
    set -e
    [ "$rc" -eq 2 ] || fail "missing zone data: '$args' exited $rc: $out"
    grep -qF "time zone data for Australia/Melbourne not found" <<<"$out" || fail "missing zone data message: $out"
  done
  pass "missing zone data stops plan and install"
fi

expect_error() {
  local name="$1" pattern="$2" out rc
  shift 2
  set +e
  out="$(run_local "$@" 2>&1)"
  rc=$?
  set -e
  [ "$rc" -eq 2 ] || fail "$name: expected exit 2, got $rc ($out)"
  grep -qF -- "$pattern" <<<"$out" || fail "$name: expected '$pattern' in: $out"
}
expect_error "claude has no local job" "/schedule" "$SCRIPT" install --host claude
expect_error "gemini is not a host" "--host must be one of" "$SCRIPT" install --host gemini
expect_error "model selection is gone" "unknown argument: --model" "$SCRIPT" install --host codex --model x
expect_error "missing host" "--host must be one of" "$SCRIPT" uninstall
pass "argument errors"
