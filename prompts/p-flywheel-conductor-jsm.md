---
description: Prime the project, launch a 3×cod + 1×cc NTM swarm using jsm skills, and loop every 5 minutes feeding idle agents from beads
argument-hint: "[cod-panes] [cc-panes] [tick-interval] — defaults: 3 cod (gpt-5.6 Sol, medium), 1 cc (Opus 5, medium), 5m"
---

Arguments (if given): the number of cod panes, the number of cc panes, and the loop tick interval. If absent, default to 3 cod panes (gpt-5.6 Sol, medium thinking effort), 1 cc pane (Opus 5, medium thinking effort), and a 5-minute tick — the configuration described below.

First read ALL of the AGENTS.md file and README.md file super carefully and understand ALL of both! Then use your code investigation agent mode to fully understand the code and technical architecture and purpose of the project.

**Preflight — finish before any NTM spawn:**

1. Invoke `/flywheel-local-launcher` and run its bundled `flywheel-link.sh preflight`.
   Inventory deployment-required variables and variables that select deployment identity,
   not only variables read by application code. Process-only values do not satisfy
   deployment validation. Generate and set self-generated secrets such as signing keys
   without asking the user. For platform-issued keys, tell the user exactly which variable
   is missing and park only the affected bead chain. Journal the variable **name only**,
   never its value. Detect ambient variables that override explicit target flags and clear
   or align them before accepting deployment evidence. Evidence: customer-kingfield,
   2026-07-05 — `CONVEX_DEPLOY_KEY` overrode Convex `--prod`, so a worker read non-prod
   data while claiming production facts.
2. Treat the preflight's Codex probe as a hard spawn gate. Codex self-update is interactive
   and process-replacing: if the probe reports an update, restart requirement, timeout, or
   anything other than a clean result, do not spawn. Complete the update/restart and rerun
   preflight until the probe is clean. Evidence: skills dogfood, 2026-07-02 — Codex
   0.142.4 → 0.142.5 self-updated inside fresh worker panes, exited both, and respawn left
   plain shells instead of Codex workers, starting the swarm at 0/N.

Only after both gates pass, use /ntm and /vibing-with-ntm to create a swarm comprising 3 cod instances (gpt-5.6 Sol on medium thinking effort) and 1 cc instances (Opus 5 with medium thinking effort). Make sure also that we don't run out of space by periodically clearing stale build artifacts. And make sure to use rch for all builds/tests (see the /rch skill). Try to avoid excessive build contention from concurrent builds for the same project by multiple agents within the same project-level swarm. And use your /loop tool every 5 minutes to pass fresh instructions to any agents in the swarms in need of further input (ie, that are idle), guided by bv for open beads (see the /beads-bv and /beads-br skills ). Look for beads that are clearly "stalled out"; that is, marked as being in progress (likely by long-dead agents) with no recent work on them whatsoever, and mark them as being open again.  Also if we run out of open beads, you can also try some rounds where applicable of applying one of the many testing skills such as /testing-conformance-harnesses (and any other skills beginning with the string "testing-"). And if we are done working on all open or stalled beads, and the review rounds are starting to converge and appear to be saturated (i.e., not many new bugs being found and fixed relative to the effort and token usage), then you can start applying various skills such as /mock-code-finder , /deadlock-finder-and-fixer , /reality-check-for-project , /profiling-software-performance  and /extreme-software-optimization  to helpfully come up with more useful things to do, which you can then create new beads for using br (see /beads-workflow) and execute using /vibing-with-ntm  skill and the existing swarm.
On the first cycle/tick only confirm the configured cod and cc panes and their thinking efforts with the user in case they wish to adjust.

**Pane context hygiene (every tick; /vibing-with-ntm OC-009 and AP-47).** A pane re-sends its whole context on every step, so keep conversations short: one bead per conversation where possible. Between beads — never mid-bead — read each pane's context (`ntm --robot-context <session>`, or the agent's own session log when you need the exact number) and restart any pane at or above ~40% of its window or after two auto-compactions: recover its Agent Mail identity, relaunch it, re-dispatch a bead-scoped brief. cod restarts with `/exit` and the same launch line; cc restarts with `/clear`. Every brief asks for quiet test reporters and `tail`, and forbids whole-file and whole-ledger dumps. Done when no pane starts a bead above the threshold.
