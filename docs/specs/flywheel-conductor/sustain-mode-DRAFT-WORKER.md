---
title: Conductor sustain mode plan draft
status: worker draft - 2026-07-08
source:
  - customer-kingfield-rearch-conformance-closeout-xsp.18
  - .flywheel/runtime/journal.jsonl
  - ~/.agents/skills/flywheel-conductor/SKILL.md
read_when:
  - synthesizing the flywheel-conductor source skill change
  - designing usage-reset auto-resume behavior
---

# Conductor Sustain Mode Plan Draft

This is an independent worker draft for conductor synthesis. It does not change
the source skill; it proposes the shape of the `ryangriffinau/skills` PR that
folds a first-class usage-reset continuity mode into `flywheel-conductor`.

## Evidence Base

Ryan's latest bead comment requires:

- the mode is something the conductor runs in for the session;
- the conductor asks once per session before first initiating it;
- approval persists for the session;
- the conductor sends periodic reminders/status while the mode is active;
- the name should be better aligned than "autopilot";
- planning must use independent worker and conductor drafts, then synthesis,
  before changing the source skill.

Live evidence from `.flywheel/runtime/journal.jsonl`:

- `2026-07-07T00:12:00Z` lesson: the conductor hit Codex usage limits three
  times, stood down, and waited for a human ping even when reset times were
  visible.
- `2026-07-07T10:50:00Z` check-in: all Codex panes were walled; reset time was
  parsed as 9:23 PM local; a timer was armed for 9:26 PM; the conductor noted a
  second lesson that sends must be followed by pane capture to verify `Working`.
- `2026-07-07T11:28:00Z` check-in: auto-relaunch succeeded; pane 2 and pane 5
  were verified `Working` on the assigned beads at `gpt-5.5 high`.

Current skill shape:

- `SKILL.md` Step 4 owns the conduct loop and check-in cadence.
- `references/check-in.md` owns timer mechanics and warns Codex app self-wake is
  unverified.
- `references/commands.md` owns exact commands, including broadcast, targeted
  send, pane capture, lease, and journal append.
- `references/guards.md` has G13 conductor survivability but no usage-reset
  guard or mode.
- `scripts/conductor-poll.sh` classifies pane state from tmux tails, but does
  not detect usage-limit copy or parse reset times.
- `scripts/conductor-triage.sh` emits G2/G3/G6/G7/G8 exceptions, but not a
  usage-reset exception.

## Name Candidates

Criteria: the name should describe continuity, scheduled self-resumption, and
visible unattended operation. It should not imply autonomous product judgment or
unchecked action.

Candidates:

- **sustain mode**: good fit. It says the conductor sustains an already-approved
  swarm loop through resets and gates. It does not imply the conductor makes new
  strategic decisions.
- **continuity mode**: accurate, slightly broad; could also mean session
  compaction/re-entry generally.
- **keepalive mode**: operationally familiar, but too low-level and heartbeat
  flavored.
- **watchkeeper mode**: vivid but too cute for source skill terminology.
- **self-resume mode**: precise but narrow; it names the mechanism, not the
  session behavior.
- **reset-resume mode**: precise for Codex credit walls, but too tied to one
  trigger and not a conductor mode name.
- **autopilot**: reject. It overstates autonomy and may make users uneasy.

Recommendation: **sustain mode**.

Use this phrase consistently:

> Sustain mode keeps an already-approved flywheel swarm under conductor
> supervision across known usage-reset windows. It schedules a wake-up, re-takes
> the conductor lease, re-kicks eligible workers, and verifies panes are
> `Working`.

## Consent And Reminder Protocol

Consent is session-scoped, not global.

1. First time a usage wall is detected in a session, the conductor asks:
   "Codex panes are usage-limited until `<time>`. Enable sustain mode for this
   session so I can wake at reset, re-take the conductor lease, re-kick workers,
   and report back? I will keep sending periodic status while it is active."
2. If approved, journal a `checkin` or new `mode` line with:
   `mode=sustain`, `consent=approved`, `session`, `epic`, `approved_at`, and
   reset-time evidence.
3. If declined, journal the decline and hand back normally. Do not ask again for
   that session unless the user explicitly re-enables it.
4. Once approved, the conductor may re-enter sustain mode for later usage walls
   in the same session without asking again.
5. While active, send visible status to the user:
   - when sustain mode arms a reset timer;
   - on each long wait reminder, recommended every 30-60 minutes for waits over
     60 minutes;
   - on wake before re-kicking;
   - after submit verification confirms workers are `Working`;
   - when retries are capped or escalation is needed.

The reminder should be short and factual:

> Sustain mode active: all workers are usage-limited until 9:23 PM local. Timer
> armed for 9:26 PM; next update at 9:26 PM or sooner if the session resumes.

## Wall Detection

Treat a wall as global only when all or the only relevant worker panes are
blocked by usage/credit/quota messaging. Do not arm sustain mode for one blocked
pane while other panes can keep working; route around it under G9/G10 instead.

Detection inputs:

- `tmux capture-pane` tail from each Codex worker;
- `conductor-poll.sh` pane dump;
- explicit user/conductor observation in journal;
- no file writes/commits for the relevant interval, used as corroborating
  evidence, not sole proof.

Greppable wall phrases to support in tests:

- `try again at 2:39 PM`
- `retry at 5:39 PM`
- `Jul 7 2:22 PM`
- `usage limit`
- `weekly quota`
- `purchase credits`
- `credit wall`

Parser output should be a typed record, not a prose string:

```json
{
  "kind": "usage_reset",
  "reset_at": "2026-07-07T11:23:00Z",
  "source_panes": [2, 5],
  "raw_time_text": "9:23 PM",
  "confidence": "exact"
}
```

Parsing rules:

- Resolve bare local times against the conductor's local timezone and current
  date.
- If the parsed time is already in the past by a small margin, assume the next
  occurrence only when pane copy clearly refers to a future retry. Otherwise
  classify as ambiguous and ask the user.
- Support date-qualified strings like `Jul 7 2:22 PM`.
- Add a safety buffer of 2-5 minutes after reset time before re-kicking.
- Cap the maximum sleep by implementation constraints; for very long waits,
  schedule periodic reminders and rely on Step 0 re-entry if the timer dies.

## Timer And Relaunch Loop

Sustain mode extends Step 4 rather than replacing it.

1. Detect global usage wall.
2. If session consent is not approved, ask once.
3. Journal the wall with parsed reset time, panes affected, timer target, and
   attempt count.
4. Arm a background timer using the existing check-in mechanism from
   `references/check-in.md`; where native scheduled wake-ups exist, prefer them.
5. On wake:
   - read the journal;
   - re-take or renew the `.flywheel/CONDUCTOR` lease;
   - run `conductor-poll.sh`;
   - if still walled and reset estimate was wrong, back off once, journal it,
     and re-arm;
   - if panes are shells/dead, use G7 recovery;
   - run G10 stale-bead reconciliation before assigning work;
   - re-kick ready/in-progress work using the normal conductor loop.
6. Verify delivery after every broadcast or targeted send:
   - wait 2-5 seconds;
   - capture each targeted pane;
   - confirm the pane shows `Working (...)` or a clear prompt requiring another
     Enter;
   - if not working, send the extra Enter where appropriate and capture again;
   - if still not working, classify with G7/G6/G8 rather than assuming success.
7. Journal the result with `submit_verified=true` and the pane indexes that
   reached `Working`.

The 2026-07-07 live lesson makes submit verification mandatory. The conductor
had previously sent prompts that silently no-oped; the successful relaunch was
only trusted after capture-pane showed `Working`.

## Guard Interactions

Add a new guard rather than overloading G13.

Proposed guard: **G15 — usage-reset-sustain**.

Signal:

- all relevant Codex worker panes show usage/credit/quota reset messages with a
  parseable retry time;
- no worker can make progress until that reset;
- prior journal line does not already have an active sustain timer for the same
  reset window.

Diagnosis:

- the swarm is externally paused by Codex usage limits, not by Beads or file
  locks. The conductor can safely preserve momentum by scheduling a reset-time
  wake-up, then re-entering Step 0/Step 4.

Fix:

- ask once for sustain-mode consent;
- parse reset time;
- arm timer with a small buffer;
- on wake, re-take lease, poll, re-kick, and verify `Working` by pane capture;
- cap retries and escalate to the user if the reset estimate fails repeatedly.

Evidence:

- customer-kingfield journal lines `2026-07-07T10:50:00Z` and
  `2026-07-07T11:28:00Z`.

Interactions:

- **G1 no-controller-pane**: sustain mode must not spawn an `ntm controller`.
- **G2 config-valid**: run config/preflight before relaunch if the session was
  killed or respawned.
- **G3 env-preflight**: do not use sustain mode for a user-gated env block.
- **G6 assignment-gap**: after wake, use G6 if ready beads are not claimed.
- **G7 respawn-dead-panes**: if reset leaves panes at shells, recover via G7.
- **G8 hang-vs-deep-work**: after relaunch, long turns are still judged normally.
- **G9 route-around-locks**: if only some workers are walled, route work to live
  panes rather than arming global sustain mode.
- **G10 stale-bead-reconciliation**: always run after a reset before assigning
  work.
- **G13 conductor-survivability**: sustain mode depends on journal + lease +
  Step 0 re-entry because timers can die.
- **G14 ship-bead-gating**: on reset wake, do not race a worker or conductor on
  a ship bead; re-check ownership.

## Retry Caps And Escalation

Recommended caps:

- max 2 failed relaunch attempts per reset window;
- max 3 sustain wake-ups per session before asking the user whether to continue;
- immediate escalation if reset-time parsing is ambiguous or all panes still
  show a future reset more than 15 minutes after the parsed time;
- immediate escalation if a relaunch would require accepting a lower-effort
  model or an interactive downgrade prompt.

Escalation message should include:

- parsed reset time;
- wall evidence;
- attempts made;
- current pane states;
- exact next human choice.

## Source Skill Changes

Recommended file split:

### `SKILL.md`

Keep `SKILL.md` small. Add:

- a short "Sustain mode" paragraph near State or Step 4;
- one sentence in Step 0: on re-entry, if journal shows active sustain mode,
  re-take lease and resume the sustain wake-up/relaunch path;
- one sentence in Step 4: if a global usage wall is detected, route to
  `references/sustain-mode.md`;
- one row in the guard index for G15.

Do not put parser details or timer commands in `SKILL.md`.

### New `references/sustain-mode.md`

Own the full protocol:

- mode definition and non-goals;
- consent prompt;
- reminder cadence;
- wall-detection examples;
- reset-time parsing rules;
- timer commands;
- wake/relaunch loop;
- submit verification;
- retry caps;
- exact journal fields;
- guard interactions.

### `references/commands.md`

Add copy-pasteable commands:

- capture all worker pane tails for wall evidence;
- arm sustain timer;
- broadcast/targeted re-kick with capture-pane verification;
- journal append examples for `sustain_armed`, `sustain_wake`,
  `sustain_relaunch_verified`, and `sustain_escalated`.

### `references/check-in.md`

Add a short section:

- sustain timers are long check-in timers;
- timers are not trusted across forks/restarts;
- Step 0 must inspect active sustain journal lines.

### `references/guards.md`

Add G15 in the same Signal/Diagnosis/Fix/Evidence format as existing guards.

### Scripts And Tests

Recommended script shape:

- Add `scripts/usage-reset-parse.sh` or extend `conductor-poll.sh` to emit
  `usage_reset` candidates per pane.
- Prefer a focused parser script/library if shell-only parsing becomes brittle.
- Extend `conductor-triage.sh` to emit G15 only when the wall is global across
  relevant worker panes.
- Add fixtures and expected JSON under `evals/fixtures` and `evals/expected`:
  - bare local time reset;
  - date-qualified reset;
  - purchase-credits wall;
  - one-pane wall while other panes work, which must not emit global G15;
  - ambiguous/past reset, which emits `needs_conductor`.
- Add tests to `tests/conductor-triage.test.sh` or a new parser test.

Journal schema should either:

- allow a new `"mode"` line type for sustain events; or
- keep current `checkin` lines and add structured optional fields.

Recommendation: add a `"mode"` line type. It makes sustain evidence easier to
query without overloading ordinary check-ins.

## Rollout Via `ryangriffinau/skills` PR

1. Conductor draft and worker draft are synthesized into one plan.
2. Encode source-skill implementation beads or a small PR plan in
   `ryangriffinau/skills`.
3. Implement docs first: `SKILL.md`, `references/sustain-mode.md`,
   `references/commands.md`, `references/check-in.md`, `references/guards.md`.
4. Implement parser/triage support with tests.
5. Run the source skill test suite.
6. Dogfood in a non-critical or simulated swarm:
   - inject pane tails with usage-reset text;
   - prove timer arming journal entry;
   - simulate wake;
   - prove relaunch prompt submit verification detects `Working`.
7. Open PR with evidence from customer-kingfield journal lines and new test
   fixtures.

Acceptance for the PR:

- source skill names the mode **sustain mode**;
- first-use consent is explicit and session-scoped;
- periodic reminders are required while active;
- reset-time parsing is tested;
- global-vs-partial wall distinction is tested;
- re-kick submit verification is mandatory;
- G15 is documented and indexed;
- no source-skill runtime writes occur outside repo-local `.flywheel/runtime`.

## Non-Goals

- Do not auto-accept model downgrade prompts.
- Do not bypass human-gated beads, external secrets, or approval gates.
- Do not keep a conductor lease alive for hours without visible user reminders.
- Do not implement a second controller pane.
- Do not turn sustain mode into general unattended product decision-making.
