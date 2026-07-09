---
title: "Conductor sustain mode — synthesized plan"
status: awaiting Ryan approval before ryangriffinau/skills PR
read_when:
  - implementing the flywheel-conductor sustain-mode source-skill change
---

# Conductor Sustain Mode — Synthesized Plan

Synthesis of PLAN-DRAFT-WORKER.md and PLAN-DRAFT-CONDUCTOR.md (independent
drafts, 2026-07-08).

## Convergence (binding)

Both drafts independently selected the same name and the same core protocol —
treat these as settled:

- **Name: sustain mode** ("autopilot" rejected by both — overstates autonomy).
  Framing line (conductor draft): *sustain mode never changes WHAT runs, only
  WHEN it resumes.*
- **Consent**: ask once per session at first wall; approval persists for the
  session; decline is journaled and not re-asked.
- **Visibility**: one-line status on every arm/wake/verify; reminders every
  30–60 min during long waits.
- **Submit verification is mandatory**: every relaunch send is followed by
  capture-pane confirmation of `Working` (the 2026-07-07 silent no-op lesson).
- **Model guard**: never accept downgrade prompts; escalate instead.

## Authoritative detail: PLAN-DRAFT-WORKER.md

The worker draft is grounded in the actual skill source (SKILL.md steps,
references/{check-in,commands,guards}.md, scripts, tests) and is adopted
wholesale for:

- **G15 usage-reset-sustain guard** (new guard, not a G13 overload), including
  the global-vs-partial wall rule: one walled pane while others work is G9
  route-around, NOT sustain mode.
- **Typed parser output** (`usage_reset` record with reset_at, source_panes,
  confidence) + parsing rules (local-time resolution, past-time ambiguity →
  ask, 2–5 min buffer) + test fixtures including the must-not-fire cases.
- **Retry caps**: 2 failed relaunches per window, 3 wake-ups per session →
  escalate with parsed time, evidence, attempts, pane states, exact choice.
- **File split**: SKILL.md gets ~4 lines (mode paragraph, Step 0 re-entry
  hook, Step 4 route, guard index row); full protocol in new
  `references/sustain-mode.md`; commands/check-in/guards get focused
  additions; `"mode"` journal line type for sustain events.
- **Rollout**: docs → parser/triage + tests → dogfood with injected fixtures →
  PR citing customer-kingfield journal evidence. Acceptance list per worker
  draft §Rollout.

## Synthesis deltas (conductor draft additions)

1. Step-0 re-entry must reconstruct pending sustain timers from journal
   `"mode"` lines — timers die with sessions; the journal is the source of
   truth (this is why the timer brief must be self-contained).
2. Non-goal added: sustain mode does not extend to cron-style unattended
   scheduling; that is a separate future discussion.

## Next steps

1. **Ryan approves this plan** (gate — no skills-repo changes before this).
2. Encode as beads or a small PR checklist in `ryangriffinau/skills`;
   implement; dogfood; PR.
3. Close xsp.18 with the PR link; close the rearch-conformance-closeout-xsp
   epic.
