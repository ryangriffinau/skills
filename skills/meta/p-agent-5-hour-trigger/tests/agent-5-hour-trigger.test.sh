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
  env -u CLAUDECODE -u CLAUDE_CODE_ENTRYPOINT -u CLAUDE_CODE_REMOTE -u GEMINI_CLI \
    AGENT_5_HOUR_TRIGGER_START_PID=1 "$@" "$SCRIPT" check
}

expect_classify() {
  local path="$1" args="$2" expected="$3" actual
  actual="$("$SCRIPT" classify "$path" "$args" | tr '\n' ' ')"
  [ "$actual" = "$expected" ] || fail "classify '$path': expected '$expected', got '$actual'"
}

expect_check() {
  local name="$1" expected_exit="$2" expected_surface="$3" out rc
  shift 3
  set +e
  out="$(clean_check "$@" 2>/dev/null)"
  rc=$?
  set -e
  [ "$rc" -eq "$expected_exit" ] || fail "$name: expected exit $expected_exit, got $rc ($out)"
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
expect_classify "/usr/bin/node" "node /usr/local/bin/gemini -m flash" "agent=gemini surface=cli "
expect_classify "/usr/bin/node" "node /usr/local/bin/gemini --experimental-acp" "agent=gemini surface=ide "
expect_classify "/Applications/Ghostty.app/Contents/MacOS/ghostty" "ghostty" "agent=none "
pass "classify process paths"

expect_check "claude terminal CLI" 0 cli CLAUDECODE=1 CLAUDE_CODE_ENTRYPOINT=cli
expect_check "claude desktop" 3 desktop CLAUDECODE=1 CLAUDE_CODE_ENTRYPOINT=claude-desktop
expect_check "claude IDE" 3 ide CLAUDECODE=1 CLAUDE_CODE_ENTRYPOINT=claude-vscode
expect_check "claude web" 3 web CLAUDECODE=1 CLAUDE_CODE_ENTRYPOINT=cli CLAUDE_CODE_REMOTE=true
expect_check "claude SDK" 3 other CLAUDECODE=1 CLAUDE_CODE_ENTRYPOINT=sdk-ts
expect_check "gemini CLI marker" 0 cli GEMINI_CLI=1
expect_check "no agent" 4 unknown

# Nearest agent ancestor wins: a codex-named parent under any session is Codex CLI.
out="$(bash -c "exec -a codex bash -c '\"$SCRIPT\" check; echo rc=\$?'" 2>/dev/null)"
grep -qx "host=codex" <<<"$out" || fail "codex ancestry: $out"
grep -qx "surface=cli" <<<"$out" || fail "codex ancestry surface: $out"
grep -qx "rc=0" <<<"$out" || fail "codex ancestry exit: $out"
pass "codex CLI ancestry"

out="$(bash -c "exec -a /Applications/ChatGPT.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex bash -c '\"$SCRIPT\" check; echo rc=\$?' app-server" 2>/dev/null)"
grep -qx "surface=desktop" <<<"$out" || fail "codex desktop ancestry: $out"
grep -qx "rc=3" <<<"$out" || fail "codex desktop exit: $out"
pass "codex desktop ancestry"

# Install dry run with fake host CLIs and a throwaway HOME.
mkdir -p "$TEST_ROOT/bin" "$TEST_ROOT/home"
# shellcheck disable=SC2016 # the fake CLI expands these when it runs
printf '#!/bin/bash\necho "fake $(basename "$0") args: $*"\n[ -n "${FAKE_SLEEP:-}" ] && sleep "$FAKE_SLEEP"\nexit 0\n' >"$TEST_ROOT/bin/codex"
cp "$TEST_ROOT/bin/codex" "$TEST_ROOT/bin/gemini"
chmod +x "$TEST_ROOT/bin/codex" "$TEST_ROOT/bin/gemini"

run_install() {
  env -u XDG_STATE_HOME HOME="$TEST_ROOT/home" PATH="$TEST_ROOT/bin:$PATH" "$@"
}

can_schedule=1
if [ "$(uname -s)" = "Linux" ] && ! command -v crontab >/dev/null 2>&1; then
  can_schedule=0
fi

if [ "$can_schedule" -eq 1 ]; then
  out="$(run_install TZ=Asia/Kolkata "$SCRIPT" install --host codex --model test-model --dry-run)"
  grep -qx "local_minute=37" <<<"$out" || fail "Kolkata minute: $out"
  out="$(run_install TZ=UTC "$SCRIPT" install --host codex --model test-model --dry-run)"
  grep -qx "local_minute=7" <<<"$out" || fail "UTC minute: $out"
  grep -qF '00|05|10|15|20) ;;' <<<"$out" || fail "runner hour gate missing"
  grep -qF -- "--ephemeral --sandbox read-only -m test-model" <<<"$out" || fail "codex command missing"
  grep -qx -- "--- dry run: nothing written" <<<"$out" || fail "dry run marker missing"
  if [ "$(uname -s)" = "Darwin" ]; then
    grep -qF "<integer>7</integer>" <<<"$out" || fail "plist minute missing"
    if command -v plutil >/dev/null 2>&1; then
      printf '%s\n' "$out" | sed -n '/^--- plist$/,/^--- dry run/p' | sed '1d;$d' | plutil -lint - >/dev/null ||
        fail "plist does not lint"
    fi
  else
    grep -qE '^7 \* \* \* \* /bin/bash .*# agent-5-hour-trigger:codex$' <<<"$out" || fail "crontab line missing"
  fi
  [ -z "$(find "$TEST_ROOT/home" -mindepth 1 -print -quit)" ] || fail "dry run wrote files"
  pass "codex install dry run"

  out="$(run_install TZ=UTC "$SCRIPT" install --host gemini --model test-flash --dry-run)"
  grep -qF -- "-m test-flash -p Reply\\ with\\ OK." <<<"$out" || fail "gemini command missing: $out"
  pass "gemini install dry run"

  # Execute the generated runner with the hour gate opened and a short watchdog.
  run_install TZ=UTC "$SCRIPT" install --host codex --model test-model --dry-run |
    sed -n '/^--- runner$/,/^--- /p' | sed '1d;$d' |
    sed -e 's/^  00|05|10|15|20) ;;/  *) ;;/' -e 's/sleep 300/sleep 1/' >"$TEST_ROOT/runner.sh"
  bash -n "$TEST_ROOT/runner.sh" || fail "runner syntax"
  mkdir -p "$TEST_ROOT/home/.local/state/agent-5-hour-trigger"
  bash "$TEST_ROOT/runner.sh"
  FAKE_SLEEP=5 bash "$TEST_ROOT/runner.sh"
  log="$TEST_ROOT/home/.local/state/agent-5-hour-trigger/codex.log"
  grep -qF "fake codex args: exec --skip-git-repo-check --ephemeral --sandbox read-only -m test-model Reply with OK. This is a scheduled usage trigger." "$log" ||
    fail "runner did not call codex with one prompt argument: $(cat "$log")"
  grep -qx "exit=0" "$log" || fail "runner exit=0 missing"
  grep -qx "exit=143" "$log" || fail "watchdog did not stop a hung CLI: $(cat "$log")"
  pass "generated runner"
else
  echo "ok - install dry run skipped: crontab unavailable"
fi

set +e
out="$(run_install "$SCRIPT" install --host claude --model x 2>&1)"
rc=$?
set -e
[ "$rc" -eq 2 ] || fail "claude install should fail"
grep -qF "/schedule" <<<"$out" || fail "claude install should point to /schedule: $out"
set +e
out="$(run_install "$SCRIPT" install --host codex 2>&1)"
rc=$?
set -e
[ "$rc" -eq 2 ] || fail "install without --model should fail"
pass "install argument errors"
