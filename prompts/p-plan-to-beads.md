---
description: Decompose a finalized plan into a granular Beads graph via the br CLI
argument-hint: [finalized synthesized plan]
---

You are converting a finalized, synthesized implementation plan into a concrete Beads task graph that a swarm of coding agents will execute. The plan to encode is provided below.

Take ALL of the plan below and, where it helps, elaborate on it further, then create a comprehensive and granular set of beads that cover the entire plan: epics, tasks, and subtasks (as needed), with the full dependency structure overlaid between them so that ready work can be triaged correctly and nothing starts before its prerequisites. Each bead must carry detailed, self-contained comments — enough context, reasoning, file/scope hints, and acceptance criteria that an agent picking up that bead cold, with no other context, can complete it correctly without stepping on other agents' work. Decompose so that independent beads touch non-overlapping files wherever possible.

Use ONLY the `br` CLI to create and modify the beads — create the epics/tasks/subtasks, set the dependencies between them, and attach the detailed comments all through `br`. Do not write pseudo-beads as markdown or invent a parallel task format. When you are finished, summarise the epic/task/subtask structure and the dependency graph you created so it can be reviewed.

Human-facing gates need a second interface: if a bead requires human judgment or approval,
write the bead for tracking, but also encode that the conductor must present a proactive
chat explanation to the human. That chat explanation must include what is being decided,
why it matters, exact decision options or steps, and the full evidence being judged. Do not
tell the human to read the bead. Do not truncate source evidence for adjudication; summaries
may accompany full evidence, not replace it.

For retirement/refactor work under a no-delete rule, encode a deletion-and-stub manifest:
path, size, reason, source of truth, and whether the file was deleted or stubbed. If deletion
requires human approval, create the approval gate and a follow-up DELETE-STUBS bead rather
than leaving silent empty files behind.

Before creating the final ship bead, resolve this repo's Flywheel Profile exactly once at encode time:

```bash
eval "$(skills/engineering/flywheel-local-launcher/scripts/flywheel-profile.sh --repo .)"
```

If the resolver is absent or fails, use the Emmanuel default for the final ship bead: `FLYWHEEL_MODE=solo` and `FLYWHEEL_PM=none`. Use the resolved `FLYWHEEL_MODE` and `FLYWHEEL_PM` to write complete, self-contained shipping instructions into the ship bead. Do not tell the future ship-bead agent to read `.flywheel/profile`; the mode-specific behavior must already be baked into the bead text.

**Always close the graph with two final beads, each depending on all implementation leaves:**
1. A **broad reality-check** bead — not a scope-limited verify. It must: get build/typecheck/test green; run a **repo-wide** `grep -ri` for ANY stale/orphaned reference (not just the directories this plan touched); do a `/p-fresh-eyes-review` of the whole diff; and run `/p-reality-check` that the intended outcome actually exists with no residual artifacts. This catches out-of-scope leftovers (stale docs/ADRs, half-renamed references) that per-bead reviews miss because each only sees its own scope.
2. A **ship** bead — mode-aware, based on the encode-time resolver output:
   - Include a whole-PR UBS sweep over changed source files in the final verification, in addition to per-bead `ubs --staged --fail-on-warning`; triage every warning as fixed or explicitly dismissed with rationale.
   - If `FLYWHEEL_MODE=solo`: write the bead to verify with the detected package manager where applicable, commit and push to the working branch, and explicitly say **no PR**.
   - If `FLYWHEEL_MODE=team`: write the bead to verify with the detected package manager where applicable, open the PR **ready** so CI and the preview environment run, enable auto-merge if the repo supports it, and merge when green: directly for safe / non-prod / template changes, otherwise with user approval. Explicitly say the agent must **not block-poll CI**; it should open the PR ready and let CI or the human complete if checks are still running.
   - If no profile exists, this is `solo`.

Input:

$ARGUMENTS
