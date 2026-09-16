#!/usr/bin/env bash
# The skill bundles copies of the convex dcg pack and the config merge helper so
# that installing the tool also installs the guard that points agents at it.
# tools/dcg remains the source of truth; this test fails the moment they drift.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_DCG="$SKILL_DIR/../../../tools/dcg"

if [[ ! -d "$REPO_DCG" ]]; then
  echo "SKIP: tools/dcg not present (skill installed standalone)"
  exit 0
fi

fail() { echo "not ok - $1" >&2; exit 1; }

pairs=(
  "packs/local.convex_prod_deploy_guard.yaml:dcg/local.convex_prod_deploy_guard.yaml"
  "lib/merge-config.py:dcg/merge-config.py"
)

for pair in "${pairs[@]}"; do
  source="$REPO_DCG/${pair%%:*}"
  bundled="$SKILL_DIR/${pair##*:}"
  [[ -f "$source" ]] || fail "source of truth missing: $source"
  [[ -f "$bundled" ]] || fail "bundled copy missing: $bundled"
  cmp -s "$source" "$bundled" \
    || fail "${pair##*:} has drifted from tools/dcg/${pair%%:*} — copy it across (cp '$source' '$bundled')"
  echo "ok - ${pair##*:} matches tools/dcg/${pair%%:*}"
done

# The installer's floor must never exceed what the bundled pack actually provides,
# or a fresh install would report itself stale.
required="$(sed -n 's/^REQUIRED_PACK_VERSION="\([^"]*\)".*/\1/p' "$SKILL_DIR/scripts/install.sh" | head -1)"
bundled_version="$(sed -n 's/^version:[[:space:]]*//p' "$SKILL_DIR/dcg/local.convex_prod_deploy_guard.yaml" | head -1)"
[[ -n "$required" ]] || fail "could not read REQUIRED_PACK_VERSION from install.sh"
[[ -n "$bundled_version" ]] || fail "could not read version from the bundled pack"
lowest="$(printf '%s\n%s\n' "$required" "$bundled_version" | sort -V | head -1)"
[[ "$lowest" == "$required" ]] \
  || fail "install.sh requires $required but the bundled pack is only $bundled_version"
echo "ok - bundled pack $bundled_version satisfies the installer floor $required"

# The pack must point agents at the tool, and the tool's skill must name the pack.
grep -q 'prod:query' "$SKILL_DIR/dcg/local.convex_prod_deploy_guard.yaml" \
  || fail "the bundled pack no longer points agents at prod:query"
grep -q 'local.convex_prod_deploy_guard' "$SKILL_DIR/SKILL.md" \
  || fail "SKILL.md no longer names the companion pack"
echo "ok - pack and skill reference each other"

echo "all dcg pack sync tests passed"
