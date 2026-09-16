#!/usr/bin/env bash
# Isolated tests for scripts/install.sh. Uses a temporary HOME; never touches the
# operator's real settings, shim, or dcg configuration.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL="$SCRIPT_DIR/../scripts/install.sh"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/convex-prod-query-install.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT

export HOME="$TMP_ROOT/home"
mkdir -p "$HOME/.claude" "$HOME/.config/dcg/packs"
export PATH="$HOME/.local/bin:$PATH"
export CLAUDE_SETTINGS="$HOME/.claude/settings.json"
export DCG_PACK="$HOME/.config/dcg/packs/local.convex_prod_deploy_guard.yaml"

fail() { echo "not ok - $1" >&2; exit 1; }
assert_contains() { [[ "$1" == *"$2"* ]] || fail "$3: expected [$2] in: $1"; }

# Foreign settings content that must survive the merge byte-for-byte in meaning.
cat >"$CLAUDE_SETTINGS" <<'JSON'
{
  "hooks": {"PreToolUse": [{"matcher": "Bash", "hooks": [{"type": "command", "command": "/x/dcg"}]}]},
  "model": "opus",
  "permissions": {"allow": ["Bash(ls *)"], "deny": ["Read(./.env)"]}
}
JSON
printf 'id: local.convex_prod_deploy_guard\nversion: 3.5.0\n' >"$DCG_PACK"

# 1. --check on a fresh machine reports gaps and exits non-zero
set +e
OUT="$("$INSTALL" --check 2>&1)"; RC=$?
set -e
[[ "$RC" -ne 0 ]] || fail "check on fresh machine should fail"
assert_contains "$OUT" "write shim" "check reports the shim gap"
[[ ! -e "$HOME/.local/bin/convex-prod-query" ]] || fail "--check must not write the shim"
echo "ok - check reports gaps without writing"

# 2. install writes the shim and merges deny rules, preserving foreign settings
OUT="$("$INSTALL" 2>&1)" || fail "install failed: $OUT"
[[ -x "$HOME/.local/bin/convex-prod-query" ]] || fail "shim not written"
python3 - "$CLAUDE_SETTINGS" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
assert d["model"] == "opus", "foreign key lost"
assert d["hooks"]["PreToolUse"][0]["hooks"][0]["command"] == "/x/dcg", "hooks lost"
assert d["permissions"]["allow"] == ["Bash(ls *)"], "allow list altered"
deny = d["permissions"]["deny"]
assert deny[0] == "Read(./.env)", "existing deny entry moved or lost"
for r in ["Edit(~/.agents/skills/convex-prod-query/**)", "Edit(~/.local/bin/convex-prod-query)", "Edit(~/.config/dcg/**)", "Edit(~/.dotfiles/stow/agents/.config/dcg/**)"]:
    assert r in deny, f"missing deny rule {r}"
PY
echo "ok - install writes shim and merges deny rules"

# 3. second run is a no-op (idempotent) and passes --check
BEFORE="$(cksum <"$CLAUDE_SETTINGS")"
"$INSTALL" >/dev/null 2>&1 || fail "second install failed"
[[ "$BEFORE" == "$(cksum <"$CLAUDE_SETTINGS")" ]] || fail "second run modified settings"
"$INSTALL" --check >/dev/null 2>&1 || fail "check should pass after install"
echo "ok - idempotent"

# 4. shim refuses clearly when the skill is not installed
set +e
OUT="$("$HOME/.local/bin/convex-prod-query" --list 2>&1)"; RC=$?
set -e
[[ "$RC" -eq 2 ]] || fail "shim without skill should exit 2, got $RC"
assert_contains "$OUT" "npx skills@latest add ryangriffinau/skills" "shim prints install hint"
echo "ok - shim guides installation"

# 5. shim execs the skill's script when it is installed
mkdir -p "$HOME/.agents/skills/convex-prod-query/scripts"
cp "$SCRIPT_DIR/../scripts/convex-prod-query" "$HOME/.agents/skills/convex-prod-query/scripts/"
if command -v bun >/dev/null 2>&1; then
  OUT="$("$HOME/.local/bin/convex-prod-query" --version 2>&1)" || fail "shim exec failed: $OUT"
  assert_contains "$OUT" "0.1.0" "shim runs the tool"
  echo "ok - shim runs the installed tool"
fi

# 6. --no-protect-dcg leaves dcg paths alone
rm "$CLAUDE_SETTINGS"
printf '{}\n' >"$CLAUDE_SETTINGS"
"$INSTALL" --no-protect-dcg >/dev/null 2>&1 || fail "no-protect install failed"
python3 - "$CLAUDE_SETTINGS" <<'PY'
import json, sys
deny = json.load(open(sys.argv[1]))["permissions"]["deny"]
assert not any("dcg" in r for r in deny), deny
assert "Edit(~/.agents/skills/convex-prod-query/**)" in deny
PY
echo "ok - --no-protect-dcg"

# 7. stale dcg pack is reported as a gap
printf 'id: local.convex_prod_deploy_guard\nversion: 3.4.0\n' >"$DCG_PACK"
set +e
OUT="$("$INSTALL" --check 2>&1)"; RC=$?
set -e
[[ "$RC" -ne 0 ]] || fail "stale pack should fail check"
assert_contains "$OUT" "3.4.0 (< 3.5.0)" "stale pack reported"
echo "ok - stale dcg pack detected"

echo "all install tests passed"
