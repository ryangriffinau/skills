#!/usr/bin/env bash
# Tests for scripts/install.sh in a temporary HOME with stub caam and ntm.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
INSTALL="$SKILL_DIR/scripts/install.sh"
# shellcheck source=stubs.sh
source "$SCRIPT_DIR/stubs.sh"

export PATH="$HOME/.local/bin:$PATH"
SHIM="$HOME/.local/bin/caam-seat"

# The real-world template shapes: a plain claude command and a codex command
# that starts after a Go-template conditional.
cat >"$NTM_CONFIG" <<'TOML'
projects_base = "/tmp/projects"

[agents]
codex = "{{if .SystemPromptFile}}CODEX_SYSTEM_PROMPT=\"$(cat {{shellQuote .SystemPromptFile}})\" {{end}}codex --dangerously-bypass-approvals-and-sandbox -m gpt -c x=${NTM_CODEX_EFFORT:-medium}"
# a comment that mentions claude = "claude" must not change
claude = "claude --model {{shellQuote (.Model | default \"opus\")}} --effort ${NTM_CLAUDE_EFFORT:-medium} --dangerously-skip-permissions"

[models]
default_claude = "opus"
claude = "claude never rewritten outside [agents]"
TOML
ORIGINAL="$(cat "$NTM_CONFIG")"

run() { set +e; OUT="$("$INSTALL" "$@" 2>&1)"; RC=$?; set -e; }

run --check
[[ "$RC" -ne 0 ]] || fail "--check on a fresh machine should fail"
assert_contains "$OUT" "write shim" "check reports the shim"
assert_contains "$OUT" "prefix the ntm claude/codex templates" "check reports the ntm wiring"
[[ ! -e "$SHIM" ]] || fail "--check must not write the shim"
[[ "$(cat "$NTM_CONFIG")" == "$ORIGINAL" ]] || fail "--check must not edit the ntm config"
pass "--check reports gaps and writes nothing"

run --dry-run
[[ "$RC" -eq 0 ]] || fail "--dry-run exit $RC: $OUT"
[[ ! -e "$SHIM" ]] || fail "--dry-run must not write the shim"
pass "--dry-run plans without writing"

run
[[ "$RC" -eq 0 ]] || fail "install exit $RC: $OUT"
[[ -x "$SHIM" ]] || fail "shim missing"
grep -q '^claude = "caam-seat launch claude --model ' "$NTM_CONFIG" || fail "claude template not wired: $(cat "$NTM_CONFIG")"
grep -q '{{end}}caam-seat launch codex --dangerously-bypass' "$NTM_CONFIG" || fail "codex template not wired"
grep -q '^# a comment that mentions claude = "claude" must not change' "$NTM_CONFIG" || fail "comment changed"
grep -q '^claude = "claude never rewritten outside \[agents\]"' "$NTM_CONFIG" || fail "[models] key changed"
[[ "$(cat "$NTM_CONFIG.bak.pre-caam-seat")" == "$ORIGINAL" ]] || fail "backup should hold the original"
SHIM_OUT="$(caam-seat version)"
[[ "$SHIM_OUT" == caam-seat* ]] || fail "shim should run the tool: $SHIM_OUT"
pass "install writes the shim, wires both templates, and keeps a backup"

WIRED="$(cat "$NTM_CONFIG")"
run
[[ "$RC" -eq 0 ]] || fail "second install exit $RC: $OUT"
[[ "$(cat "$NTM_CONFIG")" == "$WIRED" ]] || fail "second install changed the config"
run --check
[[ "$RC" -eq 0 ]] || fail "--check after install should pass: $OUT"
pass "install is idempotent and --check passes afterwards"

run --unwire-ntm
[[ "$RC" -eq 0 ]] || fail "--unwire-ntm exit $RC: $OUT"
[[ "$(cat "$NTM_CONFIG")" == "$ORIGINAL" ]] || fail "unwire should restore the original templates: $(diff <(printf '%s\n' "$ORIGINAL") "$NTM_CONFIG")"
pass "--unwire-ntm restores the original templates"

STUB_NTM_REJECT_WIRED=1 run
[[ "$RC" -ne 0 ]] || fail "install must fail when ntm rejects the rewrite"
assert_contains "$OUT" "left unchanged" "rejected rewrite is reported"
[[ "$(cat "$NTM_CONFIG")" == "$ORIGINAL" ]] || fail "rejected rewrite must leave the config untouched"
pass "a rewrite ntm rejects is never written"

mv "$NTM_CONFIG" "$STUB_ROOT/dotfiles-config.toml"
ln -s "$STUB_ROOT/dotfiles-config.toml" "$NTM_CONFIG"
run
[[ "$RC" -ne 0 ]] || fail "symlinked config should be a gap"
assert_contains "$OUT" "is a symlink" "symlinked config is reported"
[[ "$(cat "$STUB_ROOT/dotfiles-config.toml")" == "$ORIGINAL" ]] || fail "must not write through a symlink"
rm "$NTM_CONFIG"
pass "a dotfiles-managed config is never written through"

printf '[agents]\nclaude = "claude --x"\n' >"$NTM_CONFIG"
run
[[ "$RC" -ne 0 ]] || fail "missing codex template should be a gap"
assert_contains "$OUT" 'codex = "caam-seat launch codex' "missing template gets an example line"
grep -q '^claude = "caam-seat launch claude --x"' "$NTM_CONFIG" || fail "claude still wired when codex is absent"
pass "a missing template is reported with the line to add"

printf '#!/bin/sh\necho mine\n' >"$SHIM"
chmod +x "$SHIM"
run --no-ntm
[[ "$RC" -ne 0 ]] || fail "a foreign file at the shim path should be a gap"
assert_contains "$OUT" "is not the caam-seat shim" "foreign shim is reported"
[[ "$(cat "$SHIM")" == *"echo mine"* ]] || fail "foreign shim must not be overwritten"
pass "a foreign file at the shim path is left alone"

echo "all install tests passed"
