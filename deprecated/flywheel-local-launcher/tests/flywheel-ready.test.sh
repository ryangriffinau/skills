#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
READY="$SCRIPT_DIR/../scripts/flywheel-ready.sh"
TMP_ROOT="$(mktemp -d)"

cleanup() {
  if [ -d "$TMP_ROOT" ]; then
    find "$TMP_ROOT" -mindepth 1 -delete
    rmdir "$TMP_ROOT"
  fi
}
trap cleanup EXIT

fail() {
  echo "not ok - $1" >&2
  exit 1
}

repo="$TMP_ROOT/repo"
mkdir -p "$repo" "$TMP_ROOT/bin"
git -C "$repo" init -q
real_root="$(cd "$repo" && pwd -P)"

# Stub br: `ready --json` lists every ready bead in the shared ledger; `list --status open
# --json` carries source_repo_path, the clone that created each bead.
cat > "$TMP_ROOT/bin/br" <<SH
#!/usr/bin/env bash
case "\$*" in
  "ready --json")
    printf '%s\n' '[{"id":"t-mine","title":"mine","status":"open"},{"id":"t-theirs","title":"theirs","status":"open"}]' ;;
  "list --status open --json")
    printf '%s\n' '[{"id":"t-mine","source_repo_path":"$real_root"},{"id":"t-theirs","source_repo_path":"/Users/teammate/repo"}]' ;;
  *) exit 1 ;;
esac
SH
chmod +x "$TMP_ROOT/bin/br"

run_ready() {
  (cd "$repo" && PATH="$TMP_ROOT/bin:$PATH" bash "$READY" "$@")
}

ids="$(run_ready)"
[ "$ids" = "t-mine" ] || fail "ids: expected only the clone-owned bead, got: $ids"

json="$(run_ready --json)"
grep -Fq '"t-mine"' <<<"$json" || fail "json: expected t-mine in output"
grep -Fq '"t-theirs"' <<<"$json" && fail "json: teammate bead must not be dispatchable"

foreign="$(run_ready --foreign)"
grep -Fq "t-theirs" <<<"$foreign" || fail "foreign: expected teammate bead listed"
grep -Fq "/Users/teammate/repo" <<<"$foreign" || fail "foreign: expected owning clone path"
grep -Fq "t-mine" <<<"$foreign" && fail "foreign: own bead must not be listed as foreign"

set +e
(cd "$repo" && PATH="$TMP_ROOT/bin:$PATH" bash "$READY" --bogus >/dev/null 2>&1)
status=$?
set -e
[ "$status" -eq 2 ] || fail "unknown arg should exit 2"

# br failing (e.g. schema mismatch after an upgrade) must fail loud, never print an empty list.
cat > "$TMP_ROOT/bin/br" <<'SH'
#!/usr/bin/env bash
echo "Error: Schema version mismatch" >&2
exit 2
SH
set +e
broken="$(run_ready 2>/dev/null)"
status=$?
set -e
[ "$status" -ne 0 ] || fail "br failure must propagate a non-zero exit"
[ -z "$broken" ] || fail "br failure must not print ids"

echo "ok - flywheel-ready"
