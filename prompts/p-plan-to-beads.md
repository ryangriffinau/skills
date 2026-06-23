---
description: Decompose a finalized plan into a granular Beads graph via the br CLI
argument-hint: [finalized synthesized plan]
---

You are converting a finalized, synthesized implementation plan into a concrete Beads task graph that a swarm of coding agents will execute. The plan to encode is provided below.

Take ALL of the plan below and, where it helps, elaborate on it further, then create a comprehensive and granular set of beads that cover the entire plan: epics, tasks, and subtasks (as needed), with the full dependency structure overlaid between them so that ready work can be triaged correctly and nothing starts before its prerequisites. Each bead must carry detailed, self-contained comments — enough context, reasoning, file/scope hints, and acceptance criteria that an agent picking up that bead cold, with no other context, can complete it correctly without stepping on other agents' work. Decompose so that independent beads touch non-overlapping files wherever possible.

Use ONLY the `br` CLI to create and modify the beads — create the epics/tasks/subtasks, set the dependencies between them, and attach the detailed comments all through `br`. Do not write pseudo-beads as markdown or invent a parallel task format. When you are finished, summarise the epic/task/subtask structure and the dependency graph you created so it can be reviewed.

Input:

$ARGUMENTS
