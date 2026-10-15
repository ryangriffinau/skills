#!/usr/bin/env bash
# Hook pipe tests, isolated install/merge tests, and mutation negative controls.
# Never touches the real ~/.claude or ~/.codex: every install runs under a temporary HOME.
# shellcheck disable=SC2016  # bash -c bodies receive their values as positional arguments.

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL_DIR="$(cd "$TEST_DIR/.." && pwd)"
FIXTURES="$TEST_DIR/fixtures"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/agent-hooks-test.XXXXXX")"
trap 'rm -rf "$TEST_ROOT"' EXIT INT TERM HUP
unset CLAUDE_CONFIG_DIR CODEX_HOME CLAUDE_ALLOW_ASK

passed=0
failed=0
# Set QUIET=1 while running checks against mutants, where failures are expected.
QUIET=0

ok() { passed=$((passed + 1)); [[ $QUIET -eq 1 ]] || printf 'ok - %s\n' "$*"; }
not_ok() { failed=$((failed + 1)); [[ $QUIET -eq 1 ]] || printf 'not ok - %s\n' "$*"; return 1; }
check() { local name="$1"; shift; if "$@"; then ok "$name"; else not_ok "$name"; fi; }
quiet() { "$@" >/dev/null 2>&1; }

CLAUDE_INPUT='{"hook_event_name":"PreToolUse","tool_name":"AskUserQuestion","tool_input":{"questions":[]}}'
CODEX_INPUT='{"hook_event_name":"PreToolUse","tool_name":"request_user_input","tool_input":{"questions":[]}}'

# run_hook SCRIPT INPUT [ENV...] — prints stdout; exit status is the hook's.
run_hook() {
  local script="$1" input="$2"; shift 2
  printf '%s' "$input" | env -u TMUX -u CLAUDE_ALLOW_ASK "$@" "$script"
}

is_deny() {
  local out
  out="$(run_hook "$@")" || return 1
  jq -e '.hookSpecificOutput | .hookEventName == "PreToolUse" and .permissionDecision == "deny"
    and (.permissionDecisionReason | test("plain text"))' <<<"$out" >/dev/null 2>&1
}

is_allow() {
  local out
  out="$(run_hook "$@")" || return 1
  [[ -z "$out" ]]
}

# hook_suite SCRIPT — returns non-zero if any pipe test fails.
hook_suite() {
  local s="$1" before=$failed input
  for input in "$CLAUDE_INPUT" "$CODEX_INPUT"; do
    local tool
    tool="$(jq -r .tool_name <<<"$input")"
    check "$tool: denied inside tmux" is_deny "$s" "$input" TMUX=/tmp/tmux-501/default,1,0
    check "$tool: allowed outside tmux" is_allow "$s" "$input"
    check "$tool: allowed when TMUX is empty" is_allow "$s" "$input" TMUX=
    check "$tool: escape hatch allows inside tmux" is_allow "$s" "$input" TMUX=/tmp/t,1,0 CLAUDE_ALLOW_ASK=1
    check "$tool: only CLAUDE_ALLOW_ASK=1 opens the hatch" is_deny "$s" "$input" TMUX=/tmp/t,1,0 CLAUDE_ALLOW_ASK=yes
  done
  check "large stdin is drained" is_deny "$s" "$(head -c 300000 /dev/zero | tr '\0' a)" TMUX=/tmp/t,1,0
  [[ $failed -eq $before ]]
}

fingerprint() { cksum <"$1"; }
backups() { find "$(dirname "$1")" -maxdepth 1 -name "$(basename "$1").bak.*" | wc -l | tr -d ' '; }
jq_true() { jq -e "$2" "$1" >/dev/null 2>&1; }

# install_suite TOOL — every install runs under a fresh temporary HOME.
install_suite() {
  local tool="$1" before=$failed home claude codex
  local dcg_claude dcg_codex
  dcg_claude="$(jq -c '.hooks.PreToolUse[0]' "$FIXTURES/claude-settings.json")"
  dcg_codex="$(jq -c '.hooks.PreToolUse[0]' "$FIXTURES/codex-hooks.json")"

  home="$(mktemp -d "$TEST_ROOT/home.XXXXXX")"
  claude="$home/.claude/settings.json"; codex="$home/.codex/hooks.json"
  mkdir -p "$home/.claude" "$home/.codex"
  cp "$FIXTURES/claude-settings.json" "$claude"; chmod 0600 "$claude"
  cp "$FIXTURES/codex-hooks.json" "$codex"; chmod 0644 "$codex"

  check "install succeeds on fixtures" quiet env HOME="$home" "$tool/install.sh"
  check "claude: dcg group kept first and unchanged" jq_true "$claude" ".hooks.PreToolUse[0] == $dcg_claude"
  check "codex: dcg group kept first and unchanged (trust key :0:0 stable)" jq_true "$codex" ".hooks.PreToolUse[0] == $dcg_codex"
  check "claude: AskUserQuestion group appended" jq_true "$claude" \
    ".hooks.PreToolUse | length == 2 and .[1] == {matcher:\"AskUserQuestion\",hooks:[{type:\"command\",command:\"$home/.claude/hooks/flywheel-no-ask.sh\"}]}"
  check "codex: request_user_input group appended" jq_true "$codex" \
    ".hooks.PreToolUse | length == 2 and .[1] == {matcher:\"request_user_input\",hooks:[{type:\"command\",command:\"$home/.codex/hooks/flywheel-no-ask.sh\"}]}"
  check "claude: other keys and events preserved" jq_true "$claude" \
    '.model == "opus" and .permissions.allow == ["Bash(git status)"] and (.hooks.SessionStart | length == 1)'
  check "codex: Stop hook preserved" jq_true "$codex" '.hooks.Stop[0].hooks[0].timeout == 345600'
  check "scripts installed executable and identical" bash -c \
    '[[ -x "$1" && -x "$2" ]] && cmp -s "$1" "$3" && cmp -s "$2" "$3"' _ \
    "$home/.claude/hooks/flywheel-no-ask.sh" "$home/.codex/hooks/flywheel-no-ask.sh" "$tool/hooks/flywheel-no-ask.sh"
  check "backup taken before first write" bash -c '[[ "$1" == 1 && "$2" == 1 ]]' _ "$(backups "$claude")" "$(backups "$codex")"
  check "settings.json mode 0600 preserved" bash -c '[[ "$(stat -f %Lp "$1" 2>/dev/null || stat -c %a "$1")" == 600 ]]' _ "$claude"

  local fc fx
  fc="$(fingerprint "$claude")"; fx="$(fingerprint "$codex")"
  check "second install is a no-op" quiet env HOME="$home" "$tool/install.sh"
  check "no-op leaves bytes and backups unchanged" bash -c \
    '[[ "$1" == "$2" && "$3" == "$4" && "$5" == 1 && "$6" == 1 ]]' _ \
    "$fc" "$(fingerprint "$claude")" "$fx" "$(fingerprint "$codex")" "$(backups "$claude")" "$(backups "$codex")"
  check "--check passes after install" quiet env HOME="$home" "$tool/install.sh" --check

  check "uninstall succeeds" quiet env HOME="$home" "$tool/install.sh" --uninstall
  check "uninstall restores the fixtures semantically" bash -c \
    'jq -e -n --slurpfile a "$1" --slurpfile b "$2" --slurpfile c "$3" --slurpfile d "$4" "\$a == \$b and \$c == \$d" >/dev/null' _ \
    "$claude" "$FIXTURES/claude-settings.json" "$codex" "$FIXTURES/codex-hooks.json"
  check "uninstall removes installed scripts" bash -c '[[ ! -e "$1" && ! -e "$2" ]]' _ \
    "$home/.claude/hooks/flywheel-no-ask.sh" "$home/.codex/hooks/flywheel-no-ask.sh"
  check "--check fails after uninstall" bash -c '! env HOME="$1" "$2/install.sh" --check >/dev/null 2>&1' _ "$home" "$tool"

  # Today's live layout: the Claude group already exists at the same path, so no config write.
  home="$(mktemp -d "$TEST_ROOT/home.XXXXXX")"; claude="$home/.claude/settings.json"
  mkdir -p "$home/.claude"
  jq --arg cmd "$home/.claude/hooks/flywheel-no-ask.sh" \
    '.hooks.PreToolUse += [{matcher:"AskUserQuestion",hooks:[{type:"command",command:$cmd}]}]' \
    "$FIXTURES/claude-settings.json" >"$claude"
  fc="$(fingerprint "$claude")"
  check "pre-existing equivalent group: install succeeds" quiet env HOME="$home" "$tool/install.sh" --agent claude
  check "pre-existing equivalent group: config untouched, no backup" bash -c \
    '[[ "$1" == "$2" && "$3" == 0 ]]' _ "$fc" "$(fingerprint "$claude")" "$(backups "$claude")"

  # Missing config files are created with only our group.
  home="$(mktemp -d "$TEST_ROOT/home.XXXXXX")"
  check "missing configs: install succeeds" quiet env HOME="$home" "$tool/install.sh"
  check "missing configs: created with one group each" bash -c \
    'jq -e ".hooks.PreToolUse | length == 1" "$1" >/dev/null && jq -e ".hooks.PreToolUse | length == 1" "$2" >/dev/null' _ \
    "$home/.claude/settings.json" "$home/.codex/hooks.json"

  # Malformed JSON and symlinked configs are refused without writing anything.
  home="$(mktemp -d "$TEST_ROOT/home.XXXXXX")"; claude="$home/.claude/settings.json"
  mkdir -p "$home/.claude"; cp "$FIXTURES/malformed.json" "$claude"; fc="$(fingerprint "$claude")"
  check "malformed JSON: install refuses" bash -c '! env HOME="$1" "$2/install.sh" --agent claude >/dev/null 2>&1' _ "$home" "$tool"
  check "malformed JSON: file untouched, no backup, no script" bash -c \
    '[[ "$1" == "$2" && "$3" == 0 && ! -e "$4" ]]' _ "$fc" "$(fingerprint "$claude")" "$(backups "$claude")" "$home/.claude/hooks/flywheel-no-ask.sh"
  home="$(mktemp -d "$TEST_ROOT/home.XXXXXX")"; mkdir -p "$home/.codex"
  cp "$FIXTURES/codex-hooks.json" "$home/real-hooks.json"; ln -s "$home/real-hooks.json" "$home/.codex/hooks.json"
  check "symlinked config: install refuses" bash -c '! env HOME="$1" "$2/install.sh" --agent codex >/dev/null 2>&1' _ "$home" "$tool"
  check "symlinked config: link and target untouched" bash -c \
    '[[ -L "$1" ]] && cmp -s "$2" "$3"' _ "$home/.codex/hooks.json" "$home/real-hooks.json" "$FIXTURES/codex-hooks.json"

  # A group we own that also holds a foreign hook is never rewritten.
  home="$(mktemp -d "$TEST_ROOT/home.XXXXXX")"; claude="$home/.claude/settings.json"; mkdir -p "$home/.claude"
  jq --arg cmd "$home/.claude/hooks/flywheel-no-ask.sh" \
    '.hooks.PreToolUse += [{matcher:"AskUserQuestion",hooks:[{type:"command",command:$cmd},{type:"command",command:"/x"}]}]' \
    "$FIXTURES/claude-settings.json" >"$claude"
  check "shared group: install refuses" bash -c '! env HOME="$1" "$2/install.sh" --agent claude >/dev/null 2>&1' _ "$home" "$tool"

  [[ $failed -eq $before ]]
}

# mutant NAME SED_EXPR FILE — copy the tool and apply one mutation, verifying it took effect.
mutant() {
  local dir="$TEST_ROOT/mutant-$1"
  mkdir -p "$dir"; cp -R "$TOOL_DIR/." "$dir/"
  sed -i.orig "$2" "$dir/$3"
  if cmp -s "$dir/$3" "$dir/$3.orig"; then
    printf 'mutation %s did not apply\n' "$1" >&2; return 1
  fi
  printf '%s' "$dir"
}

expect_suite_fails() {
  local name="$1" suite="$2" target="$3" saved_passed=$passed saved_failed=$failed result
  QUIET=1
  if "$suite" "$target"; then result=0; else result=1; fi
  QUIET=0; passed=$saved_passed; failed=$saved_failed
  if [[ $result -eq 1 ]]; then ok "negative control: $name is detected"; else not_ok "negative control: $name went undetected"; fi
}

printf '# hook pipe tests\n'
hook_suite "$TOOL_DIR/hooks/flywheel-no-ask.sh"
printf '# install and merge tests\n'
install_suite "$TOOL_DIR"
printf '# negative controls\n'
if dir="$(mutant no-escape-hatch 's/ && \[ "\${CLAUDE_ALLOW_ASK:-}" != "1" \]//' hooks/flywheel-no-ask.sh)"; then
  expect_suite_fails "missing escape hatch" hook_suite "$dir/hooks/flywheel-no-ask.sh"
else not_ok "negative control: escape-hatch mutation applies"; fi
if dir="$(mutant clobbering-merge 's/\.hooks\.PreToolUse += \[ours\]/.hooks.PreToolUse = [ours]/' install.sh)"; then
  expect_suite_fails "merge that clobbers other hooks" install_suite "$dir"
else not_ok "negative control: merge mutation applies"; fi
if dir="$(mutant prepending-merge 's/\.hooks\.PreToolUse += \[ours\]/.hooks.PreToolUse = [ours] + .hooks.PreToolUse/' install.sh)"; then
  expect_suite_fails "merge that shifts the dcg group" install_suite "$dir"
else not_ok "negative control: prepend mutation applies"; fi

printf '# %d passed, %d failed\n' "$passed" "$failed"
[[ $failed -eq 0 ]]
