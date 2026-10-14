#!/usr/bin/env bash
# flywheel-ready.sh — the ready beads that belong to THIS clone.
#
# Multi-person beads: every clone that pulls the shared .beads/issues.jsonl sees
# every teammate's beads, and bare `br ready` / `bv --robot-triage` list all of
# them. `br` stamps each bead with the canonical path of the clone that created
# it (source_repo_path), so ownership is mechanical and needs no human input: a
# bead is yours when it was created in this clone — by you or by your agents.
#
# This only FILTERS br's own output. It never overrides br, bv or the flywheel.
#
#   flywheel-ready.sh            # ids of dispatchable beads, one per line
#   flywheel-ready.sh --json     # the same beads as `br ready --json` records
#   flywheel-ready.sh --foreign  # ready beads owned by OTHER clones (look, don't claim)
set -euo pipefail

mode="${1:-ids}"
case "$mode" in
  ids|--json|--foreign) ;;
  -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
  *) echo "flywheel-ready.sh: unknown arg: $mode" >&2; exit 2 ;;
esac

root="$(git rev-parse --show-toplevel)"
root="$(cd "$root" && pwd -P)"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
br ready --json > "$tmp/ready.json"
br list --status open --json > "$tmp/open.json"

FLYWHEEL_MODE_ARG="$mode" FLYWHEEL_ROOT="$root" python3 - "$tmp/ready.json" "$tmp/open.json" <<'PY'
import json, os, sys

def records(path):
    with open(path) as handle:
        data = json.load(handle)
    if isinstance(data, list):
        return data
    return data.get("issues") or data.get("data") or []

mode = os.environ["FLYWHEEL_MODE_ARG"]
root = os.environ["FLYWHEEL_ROOT"]
owner_of = {r["id"]: r.get("source_repo_path") for r in records(sys.argv[2])}
ready = records(sys.argv[1])
mine = [r for r in ready if owner_of.get(r["id"]) == root]
foreign = [r for r in ready if owner_of.get(r["id"]) != root]

if mode == "--json":
    print(json.dumps(mine, indent=2))
elif mode == "--foreign":
    for r in foreign:
        print(f'{r["id"]}\t{owner_of.get(r["id"]) or "(unknown clone)"}\t{r.get("title", "")}')
else:
    for r in mine:
        print(r["id"])
PY
