#!/usr/bin/env bash
set -euo pipefail

SKILL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$SKILL_ROOT/scripts/rate-window-ticks"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/rate-window-ticks-test.XXXXXX")"
trap 'rm -rf "$TEST_ROOT"' EXIT

fail() {
  echo "not ok - $*" >&2
  exit 1
}

pass() {
  echo "ok - $*"
}

expect_line() {
  local name="$1" line="$2" out="$3"
  grep -qxF -- "$line" <<<"$out" || fail "$name: expected '$line' in: $out"
}

# Run the check without agent markers from the session that runs the tests.
clean_check() {
  env -u CLAUDECODE -u CLAUDE_CODE_ENTRYPOINT -u CLAUDE_CODE_REMOTE -u CODEX_SANDBOX -u GEMINI_CLI \
    RATE_WINDOW_TICKS_START_PID=1 "$@" "$SCRIPT" check
}

expect_classify() {
  local path="$1" args="$2" expected="$3" actual
  actual="$("$SCRIPT" classify "$path" "$args" | tr '\n' ' ')"
  [ "$actual" = "$expected" ] || fail "classify '$path': expected '$expected', got '$actual'"
}

expect_check() {
  local name="$1" expected_exit="$2" expected_host="$3" expected_surface="$4" expected_cloud="$5" out rc
  shift 5
  set +e
  out="$(clean_check "$@" 2>/dev/null)"
  rc=$?
  set -e
  [ "$rc" -eq "$expected_exit" ] || fail "$name: expected exit $expected_exit, got $rc ($out)"
  expect_line "$name" "host=$expected_host" "$out"
  expect_line "$name" "surface=$expected_surface" "$out"
  if [ "$expected_cloud" != "-" ]; then
    expect_line "$name" "cloud_from_here=$expected_cloud" "$out"
  fi
  pass "$name"
}

"$SCRIPT" help | grep -qF "usage: rate-window-ticks" || fail "help"

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

# Any Claude Code surface can create a routine. Codex and agy CLIs hand off.
expect_check "claude terminal CLI" 0 claude cli yes CLAUDECODE=1 CLAUDE_CODE_ENTRYPOINT=cli
expect_check "claude desktop" 0 claude desktop yes CLAUDECODE=1 CLAUDE_CODE_ENTRYPOINT=claude-desktop
expect_check "claude IDE" 0 claude ide yes CLAUDECODE=1 CLAUDE_CODE_ENTRYPOINT=claude-vscode
expect_check "claude web" 0 claude web yes CLAUDECODE=1 CLAUDE_CODE_ENTRYPOINT=cli CLAUDE_CODE_REMOTE=true
expect_check "claude SDK" 0 claude other unknown CLAUDECODE=1 CLAUDE_CODE_ENTRYPOINT=sdk-ts
expect_check "codex sandbox marker" 5 codex sandboxed unknown CODEX_SANDBOX=seatbelt
expect_check "codex sandbox beats leaked claude markers" 5 codex sandboxed unknown CODEX_SANDBOX=seatbelt CLAUDECODE=1 CLAUDE_CODE_ENTRYPOINT=cli
expect_check "gemini CLI is not supported" 4 unknown unknown - GEMINI_CLI=1
expect_check "no agent" 4 unknown unknown -

out="$(clean_check CLAUDECODE=1 CLAUDE_CODE_ENTRYPOINT=cli)"
expect_line "claude cloud method" "cloud_method=routine" "$out"
pass "claude uses a cloud routine"

# Nearest agent ancestor wins, whatever markers leak in from outer sessions.
for pair in codex:chatgpt-scheduled-task agy:remote-agent-schedule; do
  host="${pair%%:*}"
  out="$(bash -c "exec -a $host bash -c '\"$SCRIPT\" check; echo rc=\$?'" 2>/dev/null)"
  expect_line "$host ancestry" "host=$host" "$out"
  expect_line "$host ancestry" "surface=cli" "$out"
  expect_line "$host ancestry" "cloud_method=${pair#*:}" "$out"
  expect_line "$host ancestry" "cloud_from_here=no" "$out"
  expect_line "$host ancestry" "rc=0" "$out"
  pass "$host CLI ancestry"
done

out="$(bash -c "exec -a /Applications/ChatGPT.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex bash -c '\"$SCRIPT\" check; echo rc=\$?' app-server" 2>/dev/null)"
expect_line "codex desktop ancestry" "surface=desktop" "$out"
expect_line "codex desktop ancestry" "cloud_from_here=yes" "$out"
expect_line "codex desktop ancestry" "rc=0" "$out"
pass "codex desktop ancestry"

# Fake host CLIs, a fake Codex app server, and fake schedulers in a throwaway HOME.
mkdir -p "$TEST_ROOT/bin" "$TEST_ROOT/home" "$TEST_ROOT/sched"
cat >"$TEST_ROOT/bin/fake-cli" <<'FAKE'
#!/bin/bash
name="$(basename "$0")"
case "$name ${1:-}" in
  "codex app-server") exec python3 "$(dirname "$0")/fake-app-server.py" ;;
  "agy models")
    printf 'Fetching available models...\n'
    printf 'gemini-3.8-flash-high\tGemini 3.8 Flash (High)\n'
    printf 'gemini-3.8-flash-low\tGemini 3.8 Flash (Low)\n'
    printf 'claude-sonnet-4-6\tClaude Sonnet 4.6 (Thinking)\n'
    exit 0
    ;;
esac
echo "fake $name args: $*"
if [ -n "${FAKE_SLEEP:-}" ]; then
  sleep "$FAKE_SLEEP"
fi
exit 0
FAKE
cat >"$TEST_ROOT/bin/fake-app-server.py" <<'FAKE'
import json
import os
import sys

five_hour = os.environ.get("FAKE_CODEX_WINDOWS") == "5h"
weekly = {"usedPercent": 3, "windowDurationMins": 10080, "resetsAt": 1795405005}
for line in sys.stdin:
    try:
        message = json.loads(line)
    except ValueError:
        continue
    if "id" not in message:
        continue
    method = message.get("method")
    if method == "initialize":
        result = {"userAgent": "fake"}
    elif method == "account/rateLimits/read":
        if five_hour:
            limits = {"planType": "plus", "secondary": weekly,
                      "primary": {"usedPercent": 10, "windowDurationMins": 300, "resetsAt": 1795327200}}
        else:
            limits = {"planType": "pro", "primary": weekly, "secondary": None}
        result = {"rateLimits": limits}
    elif method == "model/list":
        result = {"data": [
            {"model": "gpt-6.1-sol", "displayName": "GPT-6.1-Sol", "isDefault": True},
            {"model": "gpt-6-astra", "displayName": "GPT-6-Astra"},
            {"model": "gpt-6-luna", "displayName": "GPT-6-Luna"},
            {"model": "gpt-6-sol", "displayName": "GPT-6-Sol"},
        ]}
    else:
        print(json.dumps({"id": message["id"], "error": {"message": "unknown method"}}), flush=True)
        continue
    print(json.dumps({"id": message["id"], "result": result}), flush=True)
FAKE
for name in claude codex agy; do
  cp "$TEST_ROOT/bin/fake-cli" "$TEST_ROOT/bin/$name"
  chmod +x "$TEST_ROOT/bin/$name"
done
# shellcheck disable=SC2016 # the fake commands expand these when they run
printf '#!/bin/bash\nf="$FAKE_SCHED/crontab"\nif [ "$1" = "-l" ]; then [ -f "$f" ] && exec cat "$f"; echo "no crontab" >&2; exit 1; fi\n[ "$1" = "-" ] && cat >"$f"\n' >"$TEST_ROOT/bin/crontab"
# shellcheck disable=SC2016
printf '#!/bin/bash\nf="$FAKE_SCHED/launchd"\ntouch "$f"\ncase "$1" in\n  bootstrap) basename "$3" .plist >>"$f" ;;\n  bootout) grep -vx "${2##*/}" "$f" >"$f.tmp" || true; mv "$f.tmp" "$f" ;;\n  print) grep -qx "${2##*/}" "$f" ;;\nesac\n' >"$TEST_ROOT/bin/launchctl"
chmod +x "$TEST_ROOT/bin/crontab" "$TEST_ROOT/bin/launchctl"

run_local() {
  env -u XDG_STATE_HOME HOME="$TEST_ROOT/home" FAKE_SCHED="$TEST_ROOT/sched" PATH="$TEST_ROOT/bin:$PATH" "$@"
}

# Model hints resolve to a model the CLI offers.
out="$(run_local "$SCRIPT" models --host codex)"
expect_line "codex model" "model_hint=GPT Sol or equivalent" "$out"
expect_line "codex model" "model=gpt-6.1-sol" "$out"
out="$(run_local "$SCRIPT" models --host agy)"
expect_line "agy model" "model=gemini-3.8-flash-low" "$out"
out="$(run_local "$SCRIPT" models --host agy --group claude-gpt)"
expect_line "agy claude group model" "model=claude-sonnet-4-6" "$out"
out="$(run_local "$SCRIPT" models --host claude)"
expect_line "claude model" "model=sonnet" "$out"
out="$(run_local "$SCRIPT" models --host codex --model-hint "Nothing or equivalent")"
expect_line "no matching model" "model=" "$out"
grep -qF "default model" <<<"$out" || fail "no matching model note: $out"
pass "model hints"

out="$("$SCRIPT" windows --host claude)"
expect_line "claude windows" "cadence=5h" "$out"
out="$("$SCRIPT" windows --host agy)"
expect_line "agy windows" "cadence=ask" "$out"
pass "default cadences"

have_zone=0
for dir in /usr/share/zoneinfo /usr/lib/zoneinfo /var/db/timezone/zoneinfo; do
  if [ -f "$dir/Australia/Melbourne" ]; then
    have_zone=1
  fi
done

if [ "$have_zone" -eq 1 ]; then
  out="$(run_local "$SCRIPT" windows --host codex)"
  expect_line "codex weekly windows" "plan=pro" "$out"
  expect_line "codex weekly windows" "window=10080m used=3% resets_at=2026-11-23T14:36:45+11:00" "$out"
  expect_line "codex weekly windows" "cadence=weekly" "$out"
  expect_line "codex weekly windows" "weekly_suggestion=mon 15:07" "$out"
  out="$(run_local FAKE_CODEX_WINDOWS=5h "$SCRIPT" windows --host codex)"
  expect_line "codex 5h windows" "plan=plus" "$out"
  expect_line "codex 5h windows" "cadence=5h" "$out"
  pass "codex usage windows"

  out="$("$SCRIPT" plan --host claude)"
  expect_line "claude plan" "name=agent-rate-window-ticks" "$out"
  expect_line "claude plan" "prompt=Quickly check in and reply with OK. Do nothing else." "$out"
  expect_line "claude plan" "model_hint=Sonnet or equivalent" "$out"
  expect_line "claude plan" "times=00:07 05:07 10:07 15:07 20:07" "$out"
  expect_line "claude plan" "cron=CRON_TZ=Australia/Melbourne 7 0,5,10,15,20 * * *" "$out"
  expect_line "claude plan" "rrule=RRULE:FREQ=DAILY;BYHOUR=0,5,10,15,20;BYMINUTE=7" "$out"
  expect_line "claude plan" "cloud_method=routine" "$out"
  grep -qE "^cron_utc=7 (4,9,13,18,23|0,5,10,14,19) \* \* \*$" <<<"$out" || fail "claude plan UTC cron: $out"
  pass "claude plan"

  out="$("$SCRIPT" plan --host codex --cadence weekly --weekday mon --time 15:07)"
  expect_line "codex weekly plan" "model_hint=GPT Sol or equivalent" "$out"
  expect_line "codex weekly plan" "times=mon 15:07" "$out"
  expect_line "codex weekly plan" "cron=CRON_TZ=Australia/Melbourne 7 15 * * 1" "$out"
  expect_line "codex weekly plan" "rrule=RRULE:FREQ=WEEKLY;BYDAY=MO;BYHOUR=15;BYMINUTE=7" "$out"
  expect_line "codex weekly plan" "cloud_method=chatgpt-scheduled-task" "$out"
  grep -qE "^cron_utc=7 (4|5) \* \* 1$" <<<"$out" || fail "codex weekly UTC cron: $out"
  out="$("$SCRIPT" plan --host codex --cadence weekly --weekday Monday --time 00:07)"
  grep -qE "^cron_utc=7 (13|14) \* \* 0$" <<<"$out" || fail "weekly UTC cron across midnight: $out"
  pass "codex weekly plan"

  out="$("$SCRIPT" plan --host agy)"
  expect_line "agy plan" "model_hint=Gemini Flash or equivalent" "$out"
  grep -qE "^remote_request=.*CronExpression '7 [0-9,]+ \* \* \*' \(UTC\), IsDaemon true" <<<"$out" || fail "agy remote request: $out"
  out="$("$SCRIPT" plan --host agy --group claude-gpt)"
  expect_line "agy claude group plan" "model_hint=Claude Sonnet or equivalent" "$out"
  pass "agy plan and model groups"

  out="$("$SCRIPT" plan --host claude --times 01:30,06:30 --tz UTC)"
  expect_line "custom times" "cron=CRON_TZ=UTC 30 1,6 * * *" "$out"
  expect_line "custom times" "cron_utc=30 1,6 * * *" "$out"
  out="$("$SCRIPT" plan --host claude --tz Asia/Kolkata)"
  expect_line "half-hour zone" "cron_utc=37 4,9,14,18,23 * * *" "$out"
  pass "custom times and zones"

  out="$(run_local TZ=Asia/Kolkata "$SCRIPT" install --host codex --model gpt-6.1-sol --dry-run)"
  expect_line "Kolkata minute" "local_minute=37" "$out"
  out="$(run_local TZ=UTC "$SCRIPT" install --host codex --model gpt-6.1-sol --dry-run)"
  expect_line "codex dry run" "local_minute=7" "$out"
  expect_line "codex dry run" "model=gpt-6.1-sol" "$out"
  expect_line "codex dry run" "--- dry run: nothing written" "$out"
  grep -qF '00|05|10|15|20) ;;' <<<"$out" || fail "runner hour gate missing"
  grep -qF -- "exec -m gpt-6.1-sol -c model_reasoning_effort=" <<<"$out" || fail "codex model flags missing: $out"
  grep -qF -- "--skip-git-repo-check --ephemeral --sandbox read-only Quickly\\ check\\ in" <<<"$out" || fail "codex command missing: $out"
  if [ "$(uname -s)" = "Darwin" ]; then
    grep -qF "<integer>7</integer>" <<<"$out" || fail "plist minute missing"
    if command -v plutil >/dev/null 2>&1; then
      sed -n '/^--- plist$/,/^--- dry run/p' <<<"$out" | sed '1d;$d' | plutil -lint - >/dev/null ||
        fail "plist does not lint"
    fi
  else
    grep -qE '^7 \* \* \* \* /bin/bash .*# agent-rate-window-ticks:codex$' <<<"$out" || fail "crontab line missing"
  fi
  if [ -e "$TEST_ROOT/home/.local/state" ] || [ -e "$TEST_ROOT/home/Library/LaunchAgents" ] || [ -s "$TEST_ROOT/sched/crontab" ] || [ -s "$TEST_ROOT/sched/launchd" ]; then
    fail "dry run wrote files"
  fi
  pass "codex install dry run"

  out="$(run_local TZ=UTC "$SCRIPT" install --host codex --cadence weekly --weekday mon --time 15:07 --dry-run)"
  expect_line "weekly dry run" "model=cli-default" "$out"
  grep -qF 'date +%u-%H)" in' <<<"$out" || fail "weekly gate format missing: $out"
  grep -qF '  1-15) ;;' <<<"$out" || fail "weekly gate missing: $out"
  grep -qF -- "/codex exec -c model_reasoning_effort=" <<<"$out" || fail "weekly command without model missing: $out"
  pass "weekly install dry run"

  out="$(run_local TZ=UTC "$SCRIPT" install --host agy --model gemini-3.8-flash-low --dry-run)"
  grep -qF -- "/agy --model gemini-3.8-flash-low --effort low -p Quickly\\ check\\ in\\ and\\ reply\\ with\\ OK." <<<"$out" || fail "agy command missing: $out"
  out="$(run_local TZ=UTC "$SCRIPT" install --host claude --model sonnet --dry-run)"
  grep -qF -- "/claude -p Quickly\\ check\\ in\\ and\\ reply\\ with\\ OK.\\ Do\\ nothing\\ else. --model sonnet" <<<"$out" || fail "claude command missing: $out"
  pass "agy and claude install dry runs"

  # Install, detect the existing job, replace it, and remove it.
  for host in claude codex agy; do
    out="$(run_local "$SCRIPT" install --host "$host")"
    expect_line "$host first install" "existing_state=not-installed" "$out"
    expect_line "$host first install" "status=installed" "$out"
    [ -x "$TEST_ROOT/home/.local/state/agent-rate-window-ticks/run-$host.sh" ] || fail "$host runner missing"
    out="$(run_local "$SCRIPT" status --host "$host")"
    expect_line "$host status after install" "state=installed" "$out"
    out="$(run_local "$SCRIPT" install --host "$host" 2>/dev/null)"
    expect_line "$host second install" "status=already-installed" "$out"
    out="$(run_local "$SCRIPT" install --host "$host" --replace)"
    expect_line "$host replace" "status=installed" "$out"
    out="$(run_local "$SCRIPT" uninstall --host "$host")"
    expect_line "$host uninstall" "status=removed" "$out"
    [ ! -e "$TEST_ROOT/home/.local/state/agent-rate-window-ticks/run-$host.sh" ] || fail "$host runner left behind"
    out="$(run_local "$SCRIPT" status --host "$host")"
    expect_line "$host status after uninstall" "state=not-installed" "$out"
    out="$(run_local "$SCRIPT" uninstall --host "$host")"
    expect_line "$host second uninstall" "status=not-installed" "$out"
    pass "$host install, duplicate check, replace and uninstall"
  done

  # A job left under the old agent-5-hour-trigger name is replaced and removed.
  legacy_dir="$TEST_ROOT/home/.local/state/agent-5-hour-trigger"
  make_legacy() {
    mkdir -p "$legacy_dir"
    printf '#!/bin/bash\n' >"$legacy_dir/run-codex.sh"
    if [ "$(uname -s)" = "Darwin" ]; then
      echo "local.agent-5-hour-trigger.codex" >>"$TEST_ROOT/sched/launchd"
      mkdir -p "$TEST_ROOT/home/Library/LaunchAgents"
      : >"$TEST_ROOT/home/Library/LaunchAgents/local.agent-5-hour-trigger.codex.plist"
    else
      echo "7 * * * * /bin/bash /x/run-codex.sh # agent-5-hour-trigger:codex" >>"$TEST_ROOT/sched/crontab"
    fi
  }
  make_legacy
  out="$(run_local "$SCRIPT" status --host codex)"
  expect_line "legacy status" "legacy_state=installed" "$out"
  out="$(run_local "$SCRIPT" install --host codex)"
  expect_line "legacy install" "legacy=removed" "$out"
  expect_line "legacy install" "status=installed" "$out"
  out="$(run_local "$SCRIPT" status --host codex)"
  expect_line "legacy after install" "legacy_state=not-installed" "$out"
  expect_line "legacy after install" "state=installed" "$out"
  run_local "$SCRIPT" uninstall --host codex >/dev/null
  make_legacy
  out="$(run_local "$SCRIPT" uninstall --host codex)"
  expect_line "legacy uninstall" "status=removed" "$out"
  [ ! -e "$legacy_dir/run-codex.sh" ] || fail "legacy runner left behind"
  out="$(run_local "$SCRIPT" status --host codex)"
  expect_line "legacy after uninstall" "legacy_state=not-installed" "$out"
  pass "replaces and removes a job left under the old name"

  if [ "$(uname -s)" = "Linux" ]; then
    echo "0 3 * * * /usr/bin/true # keep" >"$TEST_ROOT/sched/crontab"
    run_local "$SCRIPT" install --host codex >/dev/null
    run_local "$SCRIPT" uninstall --host codex >/dev/null
    grep -qx "0 3 \* \* \* /usr/bin/true # keep" "$TEST_ROOT/sched/crontab" || fail "unrelated crontab line was lost"
    pass "unrelated crontab lines are kept"
  fi

  # Execute a generated runner with the hour gate opened and a short watchdog.
  run_local TZ=UTC "$SCRIPT" install --host codex --model gpt-6.1-sol --dry-run |
    sed -n '/^--- runner$/,/^--- /p' | sed '1d;$d' |
    sed -e 's/^  00|05|10|15|20) ;;/  *) ;;/' -e 's/sleep 300/sleep 1/' >"$TEST_ROOT/runner.sh"
  bash -n "$TEST_ROOT/runner.sh" || fail "runner syntax"
  mkdir -p "$TEST_ROOT/home/.local/state/agent-rate-window-ticks"
  bash "$TEST_ROOT/runner.sh"
  FAKE_SLEEP=5 bash "$TEST_ROOT/runner.sh"
  log="$TEST_ROOT/home/.local/state/agent-rate-window-ticks/codex.log"
  grep -qF 'fake codex args: exec -m gpt-6.1-sol -c model_reasoning_effort="low" --skip-git-repo-check --ephemeral --sandbox read-only Quickly check in and reply with OK. Do nothing else.' "$log" ||
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
expect_error "gemini is not a host" "--host must be one of" "$SCRIPT" install --host gemini
expect_error "missing host" "--host must be one of" "$SCRIPT" uninstall
expect_error "bad cadence" "--cadence must be 5h or weekly" "$SCRIPT" plan --host claude --cadence daily
expect_error "bad group" "--group must be gemini or claude-gpt" "$SCRIPT" plan --host agy --group other
expect_error "missing value" "missing value for --model" "$SCRIPT" install --host codex --model
expect_error "unknown argument" "unknown argument: --wat" "$SCRIPT" plan --host claude --wat
if [ "$have_zone" -eq 1 ]; then
  expect_error "times share a minute" "all --times must share one minute" "$SCRIPT" plan --host claude --times 00:07,05:15
  expect_error "duplicate hour" "duplicate hour in --times" "$SCRIPT" plan --host claude --times 00:07,00:07
  expect_error "bad time" "time must be HH:MM" "$SCRIPT" plan --host claude --cadence weekly --time 7pm
  expect_error "hour out of range" "time out of range" "$SCRIPT" plan --host claude --times 24:07
  expect_error "bad weekday" "--weekday must be" "$SCRIPT" plan --host claude --cadence weekly --weekday someday
fi
pass "argument errors"
