#!/usr/bin/env bash
# conductor-triage.sh — poll JSON in, exceptions JSON out. Script-first, LLM-escalate.
#
# usage: conductor-poll.sh ... | conductor-triage.sh [--llm] [--working-threshold SECS]
# stdout: {"all_clear": bool, "exceptions": [{guard, pane?, bead?, evidence, recommended_action}]}
#
# Deterministic rules (guard ids per references/guards.md):
#   G2  config_warning true
#   G3  blocked beads present (candidate — conductor verifies the cause)
#   G6  ready > 0, nothing in_progress, and no agent pane working
#   G7  pane state shell/error (dead or errored agent)
#   G8  pane working past threshold (CANDIDATE ONLY — judgment call; --llm escalates via
#       one-shot `codex exec`, else needs_conductor:true. The conductor, not this script,
#       decides deep-work-vs-tangent.)
#   G13 is detected by the caller (poll exit 3), not here.
#   G10 (stale beads) needs tree-vs-graph diffing — intentionally not scripted in v1.
set -euo pipefail

LLM=false
THRESHOLD=600
while [ "$#" -gt 0 ]; do
  case "$1" in
    --llm) LLM=true; shift ;;
    --working-threshold) [ "$#" -ge 2 ] || exit 2; THRESHOLD="$2"; shift 2 ;;
    -h|--help) grep '^#' "$0" | head -20; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

# stdin carries the poll JSON; the python program arrives via heredoc, so hand the
# data over through the environment (both cannot share stdin).
TRIAGE_INPUT="$(cat)"
export TRIAGE_INPUT

TRIAGE_LLM="$LLM" TRIAGE_THRESHOLD="$THRESHOLD" python3 <<'PY'
import json, os, shutil, subprocess, sys

poll = json.loads(os.environ["TRIAGE_INPUT"])
llm = os.environ.get("TRIAGE_LLM") == "true"
threshold = int(os.environ.get("TRIAGE_THRESHOLD", "600"))
exceptions = []

def exc(guard, evidence, action, pane=None, bead=None):
    e = {"guard": guard, "evidence": evidence, "recommended_action": action}
    if pane is not None:
        e["pane"] = pane
    if bead is not None:
        e["bead"] = bead
    exceptions.append(e)

panes = poll.get("panes", [])
agent_panes = [p for p in panes if p.get("idx", 0) != 0]

# G2 — broken ntm config (silent xhigh fallback)
if poll.get("config_warning"):
    exc("G2", "ntm config load failed — running on built-in defaults (codex xhigh)",
        "fix ~/.config/ntm/config.toml field placement; verify no warning; kill+respawn the session")

# G7 — dead or errored panes
for p in agent_panes:
    if p.get("state") == "shell":
        exc("G7", "pane %s (%s) dropped to a shell" % (p["idx"], p.get("title", "")),
            "ntm respawn --panes=%s --force, then re-feed the kickoff prompt" % p["idx"],
            pane=p["idx"])
    elif p.get("state") == "error":
        exc("G7", "pane %s (%s) shows an error state" % (p["idx"], p.get("title", "")),
            "read the pane tail; respawn if the agent is gone (controller-titled pane -> G1: kill it, do not replace)",
            pane=p["idx"])

# G6 — ready work with an idle swarm
ready = poll.get("ready", [])
in_progress = poll.get("in_progress", [])
working = [p for p in agent_panes if p.get("state") == "working"]
if ready and not in_progress and not working:
    exc("G6", "%d ready bead(s) (%s) with no claims and no working panes" % (len(ready), ", ".join(ready[:5])),
        "broadcast a claim nudge (ntm send --cod) naming the ready bead ids; verify a claim within one check-in")

# G3 — blocked beads (candidate; the conductor verifies the actual cause)
blocked = poll.get("blocked", [])
if blocked:
    ids = ", ".join(b.get("id", "?") for b in blocked[:5])
    exc("G3", "blocked bead(s): %s" % ids,
        "read each blocker note; if it is a missing deployment env var, set it (names only in journal) and unblock; else surface to the user",
        bead=blocked[0].get("id"))

# G8 — long-running turns (candidate only; judgment call)
for p in working:
    secs = p.get("working_secs") or 0
    if secs > threshold:
        candidate = {
            "guard": "G8", "pane": p["idx"],
            "evidence": "pane %s working %ss (threshold %ss)" % (p["idx"], secs, threshold),
        }
        verdict = None
        if llm and shutil.which("codex") and shutil.which("tmux"):
            try:
                cap = subprocess.run(
                    ["tmux", "capture-pane", "-t", "%s:0.%s" % (poll.get("session", ""), p["idx"]), "-p"],
                    capture_output=True, text=True, timeout=10).stdout[-2000:]
                prompt = ("Classify this coding-agent pane tail as exactly one token, DEEPWORK "
                          "(visible file edits, test runs, or an explicit lock-wait) or TANGENT "
                          "(scanning, tool-hunting, circular reading):\n" + cap)
                out = subprocess.run(["codex", "exec"], input=prompt,
                                     capture_output=True, text=True, timeout=90).stdout
                if "TANGENT" in out:
                    verdict = "tangent"
                elif "DEEPWORK" in out:
                    verdict = "deep_work"
            except Exception:
                verdict = None
        if verdict == "deep_work":
            continue  # leave it alone — not an exception
        if verdict == "tangent":
            candidate["recommended_action"] = "Esc the pane and refocus it on its bead with the exact next action"
        else:
            candidate["needs_conductor"] = True
            candidate["recommended_action"] = "read the pane tail yourself: deep work / lock-wait -> leave; tangent -> Esc + refocus"
        exceptions.append(candidate)

json.dump({"all_clear": not exceptions, "exceptions": exceptions}, sys.stdout)
sys.stdout.write("\n")
PY
