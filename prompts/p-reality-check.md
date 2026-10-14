---
description: Assess project completion only when Jeffrey's jsm skills are unavailable; otherwise use planning-workflow.
use_when: Jeffrey's jsm skills are not installed or usable in this runtime.
argument-hint: [project context, goal, or bead/task sources]
---

Use this fallback only when Jeffrey's jsm skills are not installed or usable.
Check the installed skill files, especially `planning-workflow`, rather than
only checking for the `jsm` executable. If those skills are available, use
`planning-workflow` instead. If the installation is incomplete, diagnose it
before choosing this fallback.

Reality-check the project against its intended outcome.

Use any provided context, repo docs, task trackers, specs, current implementation, tests, product surfaces, and open or in-progress beads/tasks to answer the core question: Where are we on this project? Do we actually have the thing we are trying to build? If not, what is blocking us? If we intelligently implement all open and in-progress beads, would we close that gap completely? Why or why not?

Context:

$ARGUMENTS
