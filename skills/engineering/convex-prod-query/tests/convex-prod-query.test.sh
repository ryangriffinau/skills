#!/usr/bin/env bash
# Behaviour tests for scripts/convex-prod-query against a local mock of /api/query.
# Never contacts a real Convex deployment.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TOOL="$SCRIPT_DIR/../scripts/convex-prod-query"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/convex-prod-query-test.XXXXXX")"
MOCK_PID=""
trap 'rm -rf "$TMP_ROOT"; [[ -n "$MOCK_PID" ]] && kill "$MOCK_PID" 2>/dev/null || true' EXIT

command -v bun >/dev/null 2>&1 || { echo "SKIP: bun not installed"; exit 0; }

fail() { echo "not ok - $1" >&2; exit 1; }
assert_contains() { [[ "$1" == *"$2"* ]] || fail "$3: expected to contain [$2]; got: $1"; }
assert_not_contains() { [[ "$1" != *"$2"* ]] || fail "$3: expected NOT to contain [$2]; got: $1"; }

# Start the mock and read its port.
PORT_FILE="$TMP_ROOT/port"
bun "$SCRIPT_DIR/mock-convex.ts" >"$PORT_FILE" 2>/dev/null &
MOCK_PID=$!
for _ in $(seq 1 50); do
  [[ -s "$PORT_FILE" ]] && break
  sleep 0.1
done
PORT="$(cat "$PORT_FILE")"
[[ -n "$PORT" ]] || fail "mock server did not start"
URL="http://127.0.0.1:$PORT"

# A fake repo with a root .env so credential loading is exercised.
REPO="$TMP_ROOT/repo"
mkdir -p "$REPO/packages/backend"
printf '{"name":"fake"}\n' >"$REPO/package.json"
printf 'CONVEX_PROD_READ_KEY="prod:fake-deployment-123|readsecret"\nCONVEX_DEPLOY_KEY=dev:fake-dev-456|devsecret\n' >"$REPO/.env"

run() { # run <expected-exit> <label> args...
  local expected="$1" label="$2"; shift 2
  set +e
  OUT="$(cd "$REPO/packages/backend" && env -u CONVEX_PROD_READ_KEY -u CONVEX_PRODUCTION_DEPLOY_KEY -u CONVEX_DEPLOY_KEY bun "$TOOL" "$@" 2>&1)"
  RC=$?
  set -e
  [[ "$RC" -eq "$expected" ]] || fail "$label: expected exit $expected, got $RC; output: $OUT"
  echo "ok - $label"
}

# 1. success path: args and admin auth header reach the server; root .env found from a subdirectory
run 0 "query success" --url "$URL" echo:args '{"n":1}'
assert_contains "$OUT" '"n": 1' "args forwarded"
assert_contains "$OUT" 'Convex prod:fake-deployment-123|readsecret' "read key used as admin auth"
assert_contains "$OUT" 'via CONVEX_PROD_READ_KEY' "credential label"

# 2. mutation refused with a clear message, exit 1
run 1 "mutation refused" --url "$URL" lib/thing:doMutation '{}'
assert_contains "$OUT" 'is not a query, so this tool will not run it' "refusal message"

# 3. unknown function surfaces the server error
run 1 "unknown function" --url "$URL" nope:missing
assert_contains "$OUT" 'Could not find public function' "server error surfaced"

# 4. argument validation
run 2 "jsonArgs must be an object" --url "$URL" echo:args '[1]'
assert_contains "$OUT" 'must be a JSON object' "object validation"
run 2 "invalid JSON" --url "$URL" echo:args '{bad'
run 2 "no --push option" --url "$URL" --push echo:args
assert_contains "$OUT" 'no --push, --prod, or write options' "write options refused"
run 2 "usage with no args"

# 5. --dev picks the dev key
run 0 "--dev uses CONVEX_DEPLOY_KEY" --dev --url "$URL" echo:args
assert_contains "$OUT" 'Convex dev:fake-dev-456|devsecret' "dev key used"

# 6. full deploy key fallback warns; scoped key preferred when both exist
printf 'CONVEX_PRODUCTION_DEPLOY_KEY=prod:fake-deployment-123|fullsecret\n' >"$REPO/.env"
run 0 "full key fallback" --url "$URL" echo:args
assert_contains "$OUT" 'WARNING using CONVEX_PRODUCTION_DEPLOY_KEY' "fallback warns"
printf 'CONVEX_PRODUCTION_DEPLOY_KEY=prod:fake-deployment-123|fullsecret\nCONVEX_PROD_READ_KEY=prod:fake-deployment-123|readsecret\n' >"$REPO/.env"
run 0 "scoped key preferred" --url "$URL" echo:args
assert_not_contains "$OUT" 'WARNING' "no warning when scoped key present"

# 7. no credential anywhere -> exit 2 with guidance
rm "$REPO/.env"
run 2 "no credential" --url "$URL" echo:args
assert_contains "$OUT" 'no credential: set CONVEX_PROD_READ_KEY' "credential guidance"

# 8. deployment URL derived from the key prefix when --url is absent
printf 'CONVEX_PROD_READ_KEY=prod:fake-deployment-123|readsecret\n' >"$REPO/.env"
run 1 "url derived from key" echo:args
assert_contains "$OUT" 'on prod:fake-deployment-123' "target label from key"
assert_contains "$OUT" 'fake-deployment-123.convex.cloud' "derived host in error"

# 9. --env-file overrides discovery
printf 'CONVEX_PROD_READ_KEY=prod:other-deployment-999|x\n' >"$TMP_ROOT/alt.env"
run 0 "--env-file" --env-file "$TMP_ROOT/alt.env" --url "$URL" echo:args
assert_contains "$OUT" 'Convex prod:other-deployment-999|x' "env-file credential used"

echo "all convex-prod-query tests passed"
