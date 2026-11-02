#!/usr/bin/env bash
# Behaviour tests for scripts/caam-seat against stub caam/claude/codex/security/ntm.
# Runs on Linux CI: CAAM_SEAT_PLATFORM=Darwin turns on the macOS isolation path.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TOOL="$SKILL_DIR/scripts/caam-seat"
# shellcheck source=stubs.sh
source "$SCRIPT_DIR/stubs.sh"

run() { set +e; OUT="$("$TOOL" "$@" 2>&1)"; RC=$?; set -e; }
SEATS="$CAAM_SHALLOW_HOMES_DIR"
ALT="claude-alt@example.com"
WORK="claude-work@corp.example"

# --- discovery and help ------------------------------------------------------------
run
[[ "$RC" -eq 0 ]] || fail "bare invocation should exit 0"
assert_contains "$OUT" "Start here" "bare invocation prints help"
pass "bare invocation prints help and exits 0"

run status --json
[[ "$RC" -eq 0 ]] || fail "status --json exit $RC: $OUT"
[[ "$(jq -r '.tools.claude.active.email' <<<"$OUT")" == "ryan@example.com" ]] || fail "status reports the active claude account"
jq -e '.next | index("caam-seat setup claude/alt@example.com")' <<<"$OUT" >/dev/null || fail "status suggests setup for alt"
jq -e '[.tools.claude.accounts[] | select(.profile == "_backup_1")] | length == 0' <<<"$OUT" >/dev/null || fail "system backups are hidden"
pass "status --json lists accounts and next commands"

run stauts
[[ "$RC" -eq 2 ]] || fail "typo command should exit 2"
assert_contains "$OUT" "did you mean: caam-seat status" "typo command suggestion"
run status --jsno
[[ "$RC" -eq 2 ]] || fail "typo flag should exit 2"
assert_contains "$OUT" "did you mean: caam-seat status --json" "typo flag suggestion"
run ls
[[ "$RC" -eq 0 ]] || fail "alias ls should run status"
assert_contains "$OUT" "runs 'caam-seat status'" "alias note"
pass "typos and aliases get corrected"

run capabilities
jq -e '.exit_codes["4"] and .commands.spawn and .env.NTM_CC_SEAT' <<<"$OUT" >/dev/null || fail "capabilities contract"
pass "capabilities prints the JSON contract"

# --- the caam behaviour this tool exists for -------------------------------------
caam shallow-profile create raw --tool claude
RAW_STATUS="$(caam shallow-spawn raw -- claude auth status)"
[[ "$(jq -r '.email' <<<"$RAW_STATUS")" == "ryan@example.com" ]] || fail "fixture: an unrepaired seat should read the active account from the Keychain"
run setup --repair raw
[[ "$RC" -eq 0 ]] || fail "setup --repair exit $RC: $OUT"
RAW_STATUS="$(caam shallow-spawn raw -- claude auth status)"
[[ "$(jq -r '.loggedIn' <<<"$RAW_STATUS")" == "false" ]] || fail "repaired empty seat must be logged out, got $RAW_STATUS"
pass "a plain caam seat reads the active login; --repair isolates it"

# --- setup ------------------------------------------------------------------------
run setup --dry-run
[[ "$RC" -eq 0 ]] || fail "setup --dry-run exit $RC"
assert_contains "$OUT" "create $ALT" "dry run plans alt seat"
assert_contains "$OUT" "Skipping claude/ryan@example.com" "dry run skips the active account"
[[ ! -e "$SEATS/$ALT" ]] || fail "dry run must not create seats"
pass "setup --dry-run plans without writing"

run setup claude/alt@example.com claude/work@corp.example --no-login
[[ "$RC" -eq 0 ]] || fail "setup --no-login exit $RC: $OUT"
[[ -d "$SEATS/$ALT/Library" && ! -L "$SEATS/$ALT/Library" ]] || fail "seat Library should be a real dir"
[[ ! -e "$SEATS/$ALT/Library/Keychains" ]] || fail "seat must not see Keychains"
[[ -L "$SEATS/$ALT/Library/Preferences" ]] || fail "other Library children stay linked"
[[ -L "$SEATS/$ALT/Library/.localized" ]] || fail "hidden Library children stay linked"
[[ -L "$SEATS/$ALT/Library/Application Support" ]] || fail "names with spaces stay linked"
if HOME="$SEATS/$ALT" security login-keychain >/dev/null 2>&1; then fail "security still finds a login keychain in the seat"; fi
assert_contains "$OUT" "caam-seat login $ALT" "setup points at the login command"
pass "setup creates isolated, logged-out seats"

run setup claude/alt@example.com --no-login
[[ "$RC" -eq 0 ]] || fail "re-running setup should be fine"
pass "setup is idempotent"

run setup claude/nobody@example.com
[[ "$RC" -eq 2 ]] || fail "unknown profile should exit 2"
assert_contains "$OUT" "caam-seat add claude" "unknown profile points at add"
pass "setup rejects profiles caam does not have"

# --- login ------------------------------------------------------------------------
run login "$ALT"
[[ "$RC" -eq 3 ]] || fail "login without a terminal should exit 3, got $RC"
assert_contains "$OUT" "run this yourself: caam-seat login $ALT" "login explains it needs a terminal"

KEYCHAIN_BEFORE="$(cat "$HOME/Library/Keychains/claude-credentials.json")"
set +e
OUT="$(CAAM_SEAT_ASSUME_TTY=1 STUB_LOGIN_EMAIL=someone@else.example "$TOOL" login "$ALT" 2>&1)"; RC=$?
set -e
[[ "$RC" -eq 1 ]] || fail "wrong account login should exit 1, got $RC"
assert_contains "$OUT" "signed in as someone@else.example" "wrong account is named"
set +e
OUT="$(CAAM_SEAT_ASSUME_TTY=1 "$TOOL" login "$ALT" 2>&1)"; RC=$?
set -e
[[ "$RC" -eq 0 ]] || fail "login exit $RC: $OUT"
[[ "$(cat "$HOME/Library/Keychains/claude-credentials.json")" == "$KEYCHAIN_BEFORE" ]] || fail "seat login must not touch the real Keychain item"
[[ "$(jq -r '.claudeAiOauth.refreshToken' "$SEATS/$ALT/.claude/.credentials.json")" == "ref-alt@example.com" ]] || fail "seat login lands in the seat file"
run status --json
[[ "$(jq -r --arg n "$ALT" '.seats[] | select(.name == $n) | .state' <<<"$OUT")" == "ready" ]] || fail "alt seat should be ready"
[[ "$(jq -r '.tools.claude.swarm_seat' <<<"$OUT")" == "$ALT" ]] || fail "alt is the claude swarm seat"
pass "login checks the account and never writes the real Keychain"

# --- run and launch ------------------------------------------------------------------
run run "$ALT" -- --model opus
[[ "$RC" -eq 0 ]] || fail "run exit $RC: $OUT"
assert_contains "$OUT" "claude-ran HOME=$SEATS/$ALT args=--model opus" "run uses the seat"
pass "run opens the seat's CLI"

run launch claude --model opus
assert_contains "$OUT" "claude-ran HOME=$REAL_HOME args=--model opus" "launch without a seat is the plain CLI"
pass "launch without NTM_CC_SEAT is unchanged"

# Simulate caam recreating the Library link, then launch several panes at once.
rm -rf "$SEATS/$ALT/Library"
ln -s "$REAL_HOME/Library" "$SEATS/$ALT/Library"
for i in 1 2 3 4; do
  (NTM_CC_SEAT="$ALT" "$TOOL" launch claude --pane "$i" >"$STUB_ROOT/launch.$i" 2>&1; echo "$?" >"$STUB_ROOT/launch.$i.rc") &
done
wait
for i in 1 2 3 4; do
  [[ "$(cat "$STUB_ROOT/launch.$i.rc")" == "0" ]] || fail "concurrent launch $i failed: $(cat "$STUB_ROOT/launch.$i")"
  assert_contains "$(cat "$STUB_ROOT/launch.$i")" "claude-ran HOME=$SEATS/$ALT args=--pane $i" "concurrent launch $i runs in the seat"
done
[[ -d "$SEATS/$ALT/Library" && ! -L "$SEATS/$ALT/Library" ]] || fail "launch should re-isolate the seat"
[[ ! -e "$SEATS/$ALT/Library/Keychains" ]] || fail "re-isolated seat must not see Keychains"
pass "launch repairs isolation, even from four panes at once"

set +e
OUT="$(NTM_CC_SEAT="$WORK" "$TOOL" launch claude 2>&1)"; RC=$?
set -e
[[ "$RC" -eq 1 ]] || fail "logged-out seat should exit 1, got $RC"
assert_contains "$OUT" "caam-seat login $WORK" "logged-out seat points at login"
set +e
OUT="$(NTM_COD_SEAT="$ALT" "$TOOL" launch codex 2>&1)"; RC=$?
set -e
[[ "$RC" -eq 2 ]] || fail "tool mismatch should exit 2, got $RC"
assert_contains "$OUT" "is a claude seat, not a codex seat" "tool mismatch is explained"
set +e
OUT="$(NTM_CC_SEAT="alt@example" "$TOOL" launch claude 2>&1)"; RC=$?
set -e
[[ "$RC" -eq 2 ]] || fail "unknown seat should exit 2, got $RC"
assert_contains "$OUT" "did you mean: caam-seat launch $ALT" "unknown seat suggestion"
pass "launch refuses logged-out, mismatched and unknown seats"

# --- add (account caam does not have) -----------------------------------------------
set +e
OUT="$(CAAM_SEAT_ASSUME_TTY=1 STUB_CODEX_EMAIL=new@example.com "$TOOL" add codex work2 2>&1)"; RC=$?
set -e
[[ "$RC" -eq 0 ]] || fail "add codex exit $RC: $OUT"
assert_contains "$OUT" "logged in as new@example.com" "add reports the codex account"
run run codex-work2 -- -m gpt
assert_contains "$OUT" "codex-ran HOME=$SEATS/codex-work2 CODEX_HOME=$SEATS/codex-work2/.codex args=-m gpt" "codex seat runs with its own CODEX_HOME"
[[ -L "$SEATS/codex-work2/Library" ]] || fail "codex seats keep their Library link (no Claude Keychain concern)"
pass "add creates and logs in a seat for a new account"

# --- spawn ----------------------------------------------------------------------------
run spawn myproj --label alt --cc=2 --cod=1
[[ "$RC" -eq 3 ]] || fail "spawn without wiring should exit 3, got $RC: $OUT"
assert_contains "$OUT" "scripts/install.sh" "spawn points at the installer"

cat >"$NTM_CONFIG" <<'TOML'
[agents]
claude = "caam-seat launch claude --model opus"
codex = "{{if .SystemPromptFile}}X=1 {{end}}caam-seat launch codex -m gpt"
TOML
run spawn myproj --label alt --cc=2 --cod=1 --dry-run
[[ "$RC" -eq 0 ]] || fail "spawn --dry-run exit $RC: $OUT"
assert_contains "$OUT" "NTM_CC_SEAT=$ALT" "dry run passes the claude seat"
assert_contains "$OUT" "NTM_COD_SEAT=codex-work2" "dry run passes the codex seat"
assert_contains "$OUT" "tmux setenv -t =myproj--alt NTM_CC_SEAT" "dry run records the seat for later panes"
: >"$STUB_LOG"
run spawn myproj --label alt --cc=2 --cod=1
[[ "$RC" -eq 0 ]] || fail "spawn exit $RC: $OUT"
grep -q "ntm spawn myproj --label alt --cc=2 --cod=1 --pane-env NTM_CC_SEAT=$ALT --pane-env NTM_COD_SEAT=codex-work2" "$STUB_LOG" || fail "ntm spawn call: $(cat "$STUB_LOG")"
grep -q "tmux setenv -t =myproj--alt NTM_COD_SEAT codex-work2" "$STUB_LOG" || fail "tmux setenv call"

run spawn myproj --cc=1 --claude-seat none --cod=1 --dry-run
assert_not_contains "$OUT" "NTM_CC_SEAT" "--claude-seat none keeps claude on the active account"
assert_contains "$OUT" "NTM_COD_SEAT=codex-work2" "codex seat still applied"
run spawn myproj --cc=1 --claude-seat "$WORK"
[[ "$RC" -eq 1 ]] || fail "spawn on a logged-out seat should exit 1"
run spawn myproj --cc=1 --pane-env NTM_CC_SEAT=x
[[ "$RC" -eq 2 ]] || fail "hand-set NTM_CC_SEAT should be refused"
pass "spawn picks seats, passes them to ntm, and records them for later panes"

# --- doctor ----------------------------------------------------------------------------
ln -s "$TOOL" "$STUB_BIN/caam-seat"
run doctor --json
[[ "$RC" -eq 1 ]] || fail "doctor should report the logged-out work seat"
jq -e --arg n "seat.$WORK.login" '.checks[] | select(.id == $n and .status == "gap")' <<<"$OUT" >/dev/null || fail "doctor flags the logged-out seat"
jq -e --arg n "seat.$ALT.isolation" '.checks[] | select(.id == $n and .status == "ok")' <<<"$OUT" >/dev/null || fail "doctor confirms isolation with security"
jq -e '.checks[] | select(.id == "ntm.claude" and .status == "ok")' <<<"$OUT" >/dev/null || fail "doctor sees ntm wiring"
pass "doctor checks isolation with security, logins and wiring"

# --- project pins ----------------------------------------------------------------------
PROJECTS="$HOME/projects"
mkdir -p "$PROJECTS/proj-a/sub" "$PROJECTS/proj-b"
git -C "$PROJECTS/proj-a" init -q
cat >"$NTM_CONFIG" <<TOML
projects_base = "$PROJECTS"

[agents]
claude = "caam-seat launch claude --model opus"
codex = "caam-seat launch codex -m gpt"
TOML
set +e
OUT="$(CAAM_SEAT_ASSUME_TTY=1 "$TOOL" login "$WORK" 2>&1)"; RC=$?
set -e
[[ "$RC" -eq 0 ]] || fail "login work exit $RC: $OUT"

run pin
assert_contains "$OUT" "no project pins" "empty pin list"
OUT="$(cd "$PROJECTS/proj-a/sub" && "$TOOL" pin "$WORK" 2>&1)"
assert_contains "$OUT" "Pinned $(cd "$PROJECTS/proj-a" && pwd -P)" "pin resolves the git top level"
run pin --json
[[ "$(jq -r --arg d "$(cd "$PROJECTS/proj-a" && pwd -P)" '.pins[$d].claude' <<<"$OUT")" == "$WORK" ]] || fail "pins.json records the seat: $OUT"
set +e
OUT="$(cd "$PROJECTS/proj-a" && "$TOOL" pin claude-wrok@corp.example 2>&1)"; RC=$?
set -e
[[ "$RC" -eq 2 ]] || fail "pinning an unknown seat should exit 2"
pass "pin records the project's git top level"

OUT="$(cd "$PROJECTS/proj-a/sub" && "$TOOL" launch claude --x 2>&1)"
assert_contains "$OUT" "claude-ran HOME=$SEATS/$WORK args=--x" "launch in a pinned project uses the pin"
OUT="$(cd "$PROJECTS/proj-b" && "$TOOL" launch claude --x 2>&1)"
assert_contains "$OUT" "claude-ran HOME=$REAL_HOME args=--x" "launch elsewhere is unchanged"
OUT="$(cd "$PROJECTS/proj-a" && NTM_CC_SEAT=none "$TOOL" launch claude --x 2>&1)"
assert_contains "$OUT" "claude-ran HOME=$REAL_HOME args=--x" "NTM_CC_SEAT=none overrides the pin"
OUT="$(cd "$PROJECTS/proj-a" && NTM_CC_SEAT="$ALT" "$TOOL" launch claude --x 2>&1)"
assert_contains "$OUT" "claude-ran HOME=$SEATS/$ALT args=--x" "NTM_CC_SEAT overrides the pin"
OUT="$(cd "$PROJECTS/proj-a" && "$TOOL" launch codex --y 2>&1)"
assert_contains "$OUT" "codex-ran HOME=$REAL_HOME" "a claude pin leaves codex alone"
pass "launch follows the project pin, and env overrides it"

OUT="$(cd "$PROJECTS/proj-a" && "$TOOL" run claude -- --z 2>&1)"
assert_contains "$OUT" "claude-ran HOME=$SEATS/$WORK args=--z" "run claude uses the pin"
set +e
OUT="$(cd "$PROJECTS/proj-b" && "$TOOL" run claude 2>&1)"; RC=$?
set -e
[[ "$RC" -eq 2 ]] || fail "run claude without a pin should exit 2"
assert_contains "$OUT" "pin one here: caam-seat pin <seat>" "run claude explains pinning"
pass "run claude opens the project's pinned seat"

run spawn proj-a --label x --cc=1 --dry-run
assert_contains "$OUT" "NTM_CC_SEAT=$WORK" "spawn uses the pin over the bigger plan"
assert_contains "$OUT" "pinned for" "spawn says the pin was used"
run spawn proj-b --cc=1 --dry-run
assert_contains "$OUT" "NTM_CC_SEAT=$ALT" "unpinned project gets the automatic pick"
pass "spawn respects project pins"

run status --json
jq -e --arg w "$WORK" '[.pins[] | .claude] | index($w)' <<<"$OUT" >/dev/null || fail "status shows pins"
OUT="$(cd "$PROJECTS/proj-a" && "$TOOL" unpin claude 2>&1)"
assert_contains "$OUT" "Unpinned claude" "unpin"
OUT="$(cd "$PROJECTS/proj-a" && "$TOOL" launch claude --x 2>&1)"
assert_contains "$OUT" "claude-ran HOME=$REAL_HOME" "unpinned project is back on the active account"
jq -n --arg d "$(cd "$PROJECTS/proj-b" && pwd -P)" '{schema: "caam-seat.pins/1", pins: {($d): {claude: "claude-gone"}}}' \
  >"$HOME/.config/caam-seat/pins.json"
run doctor --json
jq -e '.checks[] | select((.id | startswith("pin.")) and .status == "gap" and (.fix | startswith("caam-seat unpin")))' <<<"$OUT" >/dev/null ||
  fail "doctor flags a pin to a missing seat: $OUT"
set +e
OUT="$(cd "$PROJECTS/proj-b" && "$TOOL" launch claude 2>&1)"; RC=$?
set -e
[[ "$RC" -eq 2 ]] || fail "a pin to a missing seat must refuse to launch, got $RC"
pass "unpin works; doctor and launch catch a pin to a missing seat"

echo "all caam-seat tests passed"
