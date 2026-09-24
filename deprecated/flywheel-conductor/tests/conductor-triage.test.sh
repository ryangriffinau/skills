#!/usr/bin/env bash
# Table-driven: every evals/fixtures/*.json through conductor-triage.sh must produce the
# guards (and key fields) in the matching evals/expected/*.json. Expected `exceptions` are
# treated as subset-matchers: each expected exception must appear (by guard + declared
# fields) in the actual output, and the actual count must equal the expected count.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/../scripts/conductor-triage.sh"
FX="$HERE/../evals/fixtures"
EX="$HERE/../evals/expected"

fail=0
for fixture in "$FX"/*.json; do
  name="$(basename "$fixture" .json)"
  expected="$EX/$name.json"
  [ -f "$expected" ] || { echo "FAIL $name: no expected file"; fail=1; continue; }
  actual="$(bash "$SCRIPT" < "$fixture")"
  if ACTUAL="$actual" python3 - "$expected" <<'PY'
import json, os, sys
exp = json.load(open(sys.argv[1]))
act = json.loads(os.environ["ACTUAL"])
assert act["all_clear"] == exp["all_clear"], "all_clear: %s != %s" % (act["all_clear"], exp["all_clear"])
assert len(act["exceptions"]) == len(exp["exceptions"]), \
    "count: %d != %d (%s)" % (len(act["exceptions"]), len(exp["exceptions"]), act["exceptions"])
for e in exp["exceptions"]:
    match = [a for a in act["exceptions"]
             if a.get("guard") == e["guard"]
             and all(a.get(k) == v for k, v in e.items())]
    assert match, "no actual exception matching %s in %s" % (e, act["exceptions"])
PY
  then echo "ok   $name"
  else echo "FAIL $name"; fail=1
  fi
done

[ "$fail" -eq 0 ] && echo "PASS conductor-triage.test.sh" || { echo "FAILURES"; exit 1; }
