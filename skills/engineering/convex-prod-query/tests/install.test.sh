#!/usr/bin/env bash
# Isolated tests for scripts/install.sh. Uses a temporary HOME; never touches the
# operator's real settings, shim, or dcg configuration.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
INSTALL="$SKILL_DIR/scripts/install.sh"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/convex-prod-query-install.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT

export HOME="$TMP_ROOT/home"
mkdir -p "$HOME/.claude" "$HOME/.config/dcg/packs"
export PATH="$HOME/.local/bin:$PATH"
export CLAUDE_SETTINGS="$HOME/.claude/settings.json"
unset DCG_CONFIG DCG_CONFIG_FILE
CONFIG="$HOME/.config/dcg/config.toml"
LIVE_PACK="$HOME/.config/dcg/packs/local.convex_prod_deploy_guard.yaml"
BUNDLED_PACK="$SKILL_DIR/dcg/local.convex_prod_deploy_guard.yaml"

HAVE_DCG=0
command -v dcg >/dev/null 2>&1 && HAVE_DCG=1

fail() { echo "not ok - $1" >&2; exit 1; }
assert_contains() { [[ "$1" == *"$2"* ]] || fail "$3: expected [$2] in: $1"; }

# Foreign settings content that must survive the merge.
cat >"$CLAUDE_SETTINGS" <<'JSON'
{
  "hooks": {"PreToolUse": [{"matcher": "Bash", "hooks": [{"type": "command", "command": "/x/dcg"}]}]},
  "model": "opus",
  "permissions": {"allow": ["Bash(ls *)"], "deny": ["Read(./.env)"]}
}
JSON

# Foreign dcg config that must survive: an unrelated pack and a foreign table.
cat >"$CONFIG" <<'TOML'
[policy]
default_mode = "deny"

[packs]
enabled = [
  "core",
  "platform.github",
]
TOML

# 1. --check on a fresh machine reports gaps and writes nothing
set +e
OUT="$("$INSTALL" --check 2>&1)"; RC=$?
set -e
[[ "$RC" -ne 0 ]] || fail "check on fresh machine should fail"
assert_contains "$OUT" "write shim" "check reports the shim gap"
[[ ! -e "$HOME/.local/bin/convex-prod-query" ]] || fail "--check must not write the shim"
if [[ "$HAVE_DCG" -eq 1 ]]; then
  assert_contains "$OUT" "install dcg pack" "check reports the pack gap"
  [[ ! -e "$LIVE_PACK" ]] || fail "--check must not install the pack"
fi
echo "ok - check reports gaps without writing"

# 2. install writes the shim, merges deny rules, installs and enables the pack
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

if [[ "$HAVE_DCG" -eq 1 ]]; then
  cmp -s "$BUNDLED_PACK" "$LIVE_PACK" || fail "installed pack differs from the bundled copy"
  python3 - "$CONFIG" <<'PY'
import sys, tomllib
d = tomllib.load(open(sys.argv[1], "rb"))
enabled = d["packs"]["enabled"]
assert "local.convex_prod_deploy_guard" in enabled, enabled
assert "platform.github" in enabled, "foreign pack dropped from enabled"
assert "core" in enabled, "core dropped from enabled"
assert d["policy"]["default_mode"] == "deny", "foreign [policy] table lost"
assert any("packs" in p for p in d["packs"]["custom_paths"]), d["packs"]
PY
  echo "ok - pack installed and enabled, foreign config preserved"
fi

# 3. second run is a no-op (idempotent) and passes --check
BEFORE_SETTINGS="$(cksum <"$CLAUDE_SETTINGS")"
BEFORE_CONFIG="$(cksum <"$CONFIG")"
"$INSTALL" >/dev/null 2>&1 || fail "second install failed"
[[ "$BEFORE_SETTINGS" == "$(cksum <"$CLAUDE_SETTINGS")" ]] || fail "second run modified settings"
[[ "$BEFORE_CONFIG" == "$(cksum <"$CONFIG")" ]] || fail "second run modified dcg config"
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
cp "$SKILL_DIR/scripts/convex-prod-query" "$HOME/.agents/skills/convex-prod-query/scripts/"
if command -v bun >/dev/null 2>&1; then
  OUT="$("$HOME/.local/bin/convex-prod-query" --version 2>&1)" || fail "shim exec failed: $OUT"
  assert_contains "$OUT" "0.1.0" "shim runs the tool"
  echo "ok - shim runs the installed tool"
fi

if [[ "$HAVE_DCG" -eq 1 ]]; then
  # 6. a stale real pack file is replaced
  printf 'id: local.convex_prod_deploy_guard\nversion: 3.4.0\n' >"$LIVE_PACK"
  "$INSTALL" >/dev/null 2>&1 || fail "install over a stale pack failed"
  cmp -s "$BUNDLED_PACK" "$LIVE_PACK" || fail "stale pack was not replaced"
  echo "ok - stale pack replaced"

  # 7. a symlinked (stow-managed) pack is never replaced
  CANON="$TMP_ROOT/dotfiles-pack.yaml"
  printf 'id: local.convex_prod_deploy_guard\nversion: 3.4.0\n' >"$CANON"
  rm -f "$LIVE_PACK"; ln -s "$CANON" "$LIVE_PACK"
  set +e
  OUT="$("$INSTALL" 2>&1)"; RC=$?
  set -e
  [[ "$RC" -ne 0 ]] || fail "stale stow-managed pack should be reported as a gap"
  assert_contains "$OUT" "stow-managed" "symlinked pack reported, not written"
  assert_contains "$OUT" "sync-to-stow" "remediation names the sync path"
  [[ -L "$LIVE_PACK" ]] || fail "symlinked pack was replaced with a real file"
  [[ "$(sed -n 's/^version: //p' "$CANON")" == "3.4.0" ]] || fail "symlink target was written through"
  # current symlinked pack is accepted
  cp "$BUNDLED_PACK" "$CANON"
  OUT="$("$INSTALL" 2>&1)" || fail "current stow-managed pack should pass: $OUT"
  assert_contains "$OUT" "stow-managed symlink" "current symlinked pack accepted"
  echo "ok - stow-managed pack is never written through"

  # 8. a symlinked config.toml is never written
  rm -f "$LIVE_PACK"; cp "$BUNDLED_PACK" "$LIVE_PACK"
  CANON_CONFIG="$TMP_ROOT/dotfiles-config.toml"
  printf '[packs]\nenabled = [\n  "core",\n]\n' >"$CANON_CONFIG"
  rm -f "$CONFIG"; ln -s "$CANON_CONFIG" "$CONFIG"
  set +e
  OUT="$("$INSTALL" 2>&1)"; RC=$?
  set -e
  [[ "$RC" -ne 0 ]] || fail "unenabled pack with symlinked config should be a gap"
  assert_contains "$OUT" "stow symlink" "symlinked config reported"
  grep -q 'convex_prod_deploy_guard' "$CANON_CONFIG" && fail "symlinked config was written through"
  [[ -L "$CONFIG" ]] || fail "config symlink was replaced"
  echo "ok - stow-managed config is never written through"

  # 9. --no-install-pack skips the pack entirely
  rm -f "$CONFIG"; printf '[packs]\nenabled = ["core"]\n' >"$CONFIG"
  rm -f "$LIVE_PACK"
  "$INSTALL" --no-install-pack >/dev/null 2>&1 || fail "--no-install-pack failed"
  [[ ! -e "$LIVE_PACK" ]] || fail "--no-install-pack installed the pack anyway"
  echo "ok - --no-install-pack"

  # 10. a fresh machine with no dcg config at all gets a working one
  rm -f "$CONFIG"
  "$INSTALL" >/dev/null 2>&1 || fail "install with no dcg config failed"
  python3 - "$CONFIG" <<'PY'
import sys, tomllib
d = tomllib.load(open(sys.argv[1], "rb"))
assert "local.convex_prod_deploy_guard" in d["packs"]["enabled"]
assert "core" in d["packs"]["enabled"]
PY
  DCG_CONFIG="$CONFIG" dcg config --format json >/dev/null || fail "DCG rejects the generated config"
  echo "ok - bootstraps a missing dcg config"
fi

# 11. --no-protect-dcg leaves dcg paths out of the deny rules
rm -f "$CLAUDE_SETTINGS"; printf '{}\n' >"$CLAUDE_SETTINGS"
"$INSTALL" --no-protect-dcg >/dev/null 2>&1 || fail "no-protect install failed"
python3 - "$CLAUDE_SETTINGS" <<'PY'
import json, sys
deny = json.load(open(sys.argv[1]))["permissions"]["deny"]
assert not any("dcg" in r for r in deny), deny
assert "Edit(~/.agents/skills/convex-prod-query/**)" in deny
PY
echo "ok - --no-protect-dcg"

echo "all install tests passed"
