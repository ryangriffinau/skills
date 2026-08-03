#!/usr/bin/env bash
# Isolated integration coverage for the minimal non-stow installer.

set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DCG_DIR="$(cd "$TEST_DIR/.." && pwd)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/dcg-install-test.XXXXXX")"
trap 'rm -rf "$TEST_ROOT"' EXIT INT TERM HUP

export HOME="$TEST_ROOT/home"
unset DCG_CONFIG
CONFIG="$HOME/.config/dcg/config.toml"
PACK_DIR="$HOME/.config/dcg/packs"

fail() {
  printf 'install.test.sh: FAIL: %s\n' "$*" >&2
  exit 1
}

assert_contains() {
  local haystack="$1" needle="$2"
  [[ "$haystack" == *"$needle"* ]] || fail "expected output to contain: $needle"
}

file_fingerprint() {
  local path metadata
  path="$1"
  metadata="$(stat -f '%m:%z:%Lp' "$path" 2>/dev/null || stat -c '%Y:%s:%a' "$path")"
  printf '%s %s %s\n' "$path" "$metadata" "$(cksum <"$path")"
}

install_snapshot() {
  local path
  shopt -s nullglob
  for path in "$CONFIG" "$PACK_DIR"/*.yaml "$CONFIG".bak.*; do
    [[ -f "$path" ]] || continue
    file_fingerprint "$path"
  done | sort
  shopt -u nullglob
}

mkdir -p "$HOME/.config/dcg" "$HOME/.claude" "$HOME/.codex"
printf 'pending-exception-sentinel\n' >"$HOME/.config/dcg/pending_exceptions.jsonl"
printf '{"hooks":"claude-sentinel"}\n' >"$HOME/.claude/settings.json"
printf '{"hooks":"codex-sentinel"}\n' >"$HOME/.codex/hooks.json"
pending_before="$(cksum <"$HOME/.config/dcg/pending_exceptions.jsonl")"
claude_before="$(cksum <"$HOME/.claude/settings.json")"
codex_before="$(cksum <"$HOME/.codex/hooks.json")"

printf '1..7\n'

# 1. Fresh install with no prior config.
output="$("$DCG_DIR/install.sh" --profile full)"
assert_contains "$output" "installation complete"
[[ -f "$CONFIG" ]] || fail "fresh install did not create config.toml"
[[ "$(find "$PACK_DIR" -type f -name 'local.*.yaml' | wc -l | tr -d ' ')" == "5" ]] \
  || fail "fresh install did not copy all five local packs"
python3 - "$CONFIG" "$DCG_DIR/profiles/full.toml" <<'PY'
import sys, tomllib
with open(sys.argv[1], "rb") as handle:
    config = tomllib.load(handle)
with open(sys.argv[2], "rb") as handle:
    profile = tomllib.load(handle)
assert config["packs"]["custom_paths"] == ["~/.config/dcg/packs/*.yaml"]
assert config["packs"]["enabled"] == profile["packs"]["enabled"]
PY
[[ ! -e "$HOME/.config/dcg/.ryangriffinau-skills.manifest.json" ]] \
  || fail "descoped ownership manifest was created"
printf 'ok 1 - fresh install creates the selected profile and five packs\n'

# 2. Existing foreign configuration survives a full -> backpocket transition,
# and a drifted managed pack is repaired.
cat >"$CONFIG" <<'TOML'
foreign_top_level = "preserve-me"

[packs]
custom_paths = ["/foreign/packs/*.yaml", "~/.config/dcg/packs/*.yaml"]
enabled = [
  "foreign.pack",
  "core", "system.disk", "package_managers", "containers.docker",
  "database.postgresql", "database.supabase", "storage.s3",
  "cdn.cloudflare_workers", "dns.cloudflare", "platform.github",
  "payment.stripe", "infrastructure.terraform",
  "local.agents_skills_guard", "local.no_squash_merge",
  "local.convex_prod_deploy_guard", "local.no_bypass_prepush",
  "local.no_worktrees",
]
disabled = ["foreign.disabled"]

[agents.claude]
trust_level = "high"
TOML
printf 'stale pack bytes\n' >"$PACK_DIR/local.no_squash_merge.yaml"
output="$("$DCG_DIR/install.sh" --profile backpocket)"
assert_contains "$output" "installed local.no_squash_merge.yaml"
cmp -s "$PACK_DIR/local.no_squash_merge.yaml" "$DCG_DIR/packs/local.no_squash_merge.yaml" \
  || fail "drifted pack was not repaired"
python3 - "$CONFIG" <<'PY'
import sys, tomllib
with open(sys.argv[1], "rb") as handle:
    config = tomllib.load(handle)
assert config["foreign_top_level"] == "preserve-me"
assert config["packs"]["custom_paths"][0] == "/foreign/packs/*.yaml"
assert config["packs"]["enabled"][0] == "foreign.pack"
assert "infrastructure.terraform" in config["packs"]["enabled"]
assert config["packs"]["disabled"] == ["foreign.disabled"]
assert config["agents"]["claude"]["trust_level"] == "high"
PY
printf 'ok 2 - additive transition preserves foreign config and repairs pack drift\n'

# 3. backpocket -> full is already current because profiles are additive. Prove
# the no-op does not alter content, metadata, packs, or backup inventory.
before_noop="$(install_snapshot)"
output="$("$DCG_DIR/install.sh" --profile full)"
assert_contains "$output" "already current"
after_noop="$(install_snapshot)"
[[ "$before_noop" == "$after_noop" ]] || fail "no-op changed durable installer state"
printf 'ok 3 - additive profile return is a true durable no-op\n'

# 4. Dry-run validates without creating its target tree.
dry_root="$TEST_ROOT/dry-run-target"
output="$("$DCG_DIR/install.sh" --profile backpocket --config "$dry_root/config.toml" --dry-run)"
assert_contains "$output" "dry run"
[[ ! -e "$dry_root" ]] || fail "dry-run created its target directory"
printf 'ok 4 - dry-run writes nothing\n'

# 5. Malformed foreign config fails closed and remains byte-identical.
corrupt_root="$TEST_ROOT/corrupt-target"
mkdir -p "$corrupt_root"
printf '[packs\nenabled = ["core"]\n' >"$corrupt_root/config.toml"
corrupt_before="$(cksum <"$corrupt_root/config.toml")"
if "$DCG_DIR/install.sh" --config "$corrupt_root/config.toml" >"$corrupt_root/output" 2>&1; then
  fail "corrupt config unexpectedly installed"
fi
[[ "$corrupt_before" == "$(cksum <"$corrupt_root/config.toml")" ]] \
  || fail "corrupt config changed on failure"
[[ ! -d "$corrupt_root/packs" ]] || fail "packs were copied before corrupt config rejection"
printf 'ok 5 - corrupt config fails closed before mutation\n'

# 6. A stow-style config symlink is refused without changing its target.
symlink_root="$TEST_ROOT/symlink-target"
mkdir -p "$symlink_root"
printf '[packs]\nenabled = ["core"]\n' >"$symlink_root/stow-config.toml"
ln -s "$symlink_root/stow-config.toml" "$symlink_root/config.toml"
symlink_before="$(cksum <"$symlink_root/stow-config.toml")"
if "$DCG_DIR/install.sh" --config "$symlink_root/config.toml" >"$symlink_root/output" 2>&1; then
  fail "stow symlink unexpectedly installed"
fi
grep -q 'is a symlink' "$symlink_root/output" || fail "symlink refusal was not explained"
[[ "$symlink_before" == "$(cksum <"$symlink_root/stow-config.toml")" ]] \
  || fail "stow target changed on refusal"
printf 'ok 6 - stow-managed config symlink is refused unchanged\n'

# 7. Scope fence: runtime exception and hook files are never installer-owned.
[[ "$pending_before" == "$(cksum <"$HOME/.config/dcg/pending_exceptions.jsonl")" ]] \
  || fail "pending_exceptions.jsonl changed"
[[ "$claude_before" == "$(cksum <"$HOME/.claude/settings.json")" ]] \
  || fail "Claude hook config changed"
[[ "$codex_before" == "$(cksum <"$HOME/.codex/hooks.json")" ]] \
  || fail "Codex hook config changed"
printf 'ok 7 - pending exceptions and agent hook files remain byte-identical\n'
