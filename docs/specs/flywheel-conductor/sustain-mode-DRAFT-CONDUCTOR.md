---
title: "Conductor sustain mode — conductor draft"
status: independent draft for synthesis (written before reading PLAN-DRAFT-WORKER.md)
read_when:
  - synthesizing conductor-sustain-mode/PLAN.md
---

# Conductor Sustain Mode — Conductor Draft

Written from direct operating experience (2026-07-07: wall at 9:23 PM parsed,
timer armed, swarm auto-relaunched, verified Working — journal entries in
`.flywheel/runtime/journal.jsonl`).

## Name

Candidates: **sustain** (recommended), keepalive, vigil, relay, steward.
"Sustain" says what it does — the conductor sustains the swarm across usage
walls and long waits — without implying unattended scope expansion the way
"autopilot" does. The mode never changes WHAT runs, only WHEN it resumes.

## Consent & visibility protocol (Ryan spec)

1. **Ask once per session**: the first time the conductor wants to arm a
   sustain timer, it asks the user ("Workers hit a usage wall resetting at
   X. Enter sustain mode for this session?"). One approval covers the session.
2. **Persistent thereafter**: subsequent walls/waits re-arm without asking.
3. **Reminders**: every re-arm emits a one-line status to the user (what is
   waiting, when it resumes, what fires next). On each actual resume, the
   first report names what was relaunched and the verification result.

## The loop (hardened by this week's failures)

1. **Detect**: pane tail matches `hit your usage limit ... try again at
   <time>` (also match idle-no-Working after a dispatch — sends at a wall
   silently no-op; that cost us a lost dispatch cycle on 2026-07-07).
2. **Parse**: reset time is LOCAL; compute delay = reset − now + 3 min
   buffer. If parse fails, default 30 min.
3. **Arm**: background timer whose message is a self-contained re-entry
   brief (bead ids, pane targets, model policy) — the firing context may be
   post-compaction, so never rely on conversation memory.
4. **Relaunch**: targeted `tmux send-keys` + 1.5s + Enter + 2.5s + Enter,
   then ALWAYS `capture-pane` and confirm a `Working` indicator. Not
   confirmed → check for a new wall message → parse → re-arm (goto 2).
5. **Model guard**: never accept downgrade prompts (Esc dismisses); workers
   stay at the user-approved model or wait.

## Skill integration shape

- `SKILL.md` gains a short **Sustain mode** subsection in the conduct loop:
  when to offer it, the consent rule, pointer to the reference file.
- Full protocol (detection patterns, parse rules, timer-brief template,
  submit-verification sequence) goes to a new reference file
  `references/sustain-mode.md` — keeps SKILL.md lean per skill conventions.
- G-rule addition: sustain re-arms are journaled (`type: "sustain"`), so an
  adopted/resumed conductor can reconstruct pending timers from the journal.

## Rollout

1. Synthesize plan → Ryan approves.
2. PR to `ryangriffinau/skills` editing `flywheel-conductor` (SKILL.md +
   references/sustain-mode.md), citing the live journal evidence.
3. Close xsp.18 with the PR link; close the xsp epic.

## Out of scope

Scheduling beyond usage walls (cron-style unattended runs), auto-approving
anything a human gate owns, and any change to worker-side behavior.
