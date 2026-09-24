# Check-in mechanics — how the conductor wakes itself

The conduct loop (SKILL.md Step 4) needs a recurring wake-up. Cadence while a swarm is
live: **every 4.5–5 minutes** (long enough for real work to move, short enough that a dead
pane or stall loses at most one cycle). Every wake-up renews the conductor lease
(reservation TTL 15 min = 3 missed check-ins before the swarm is adoptable).

## Claude Code (proven)

Arm a detached background timer; its completion re-invokes the session:

```bash
# run_in_background: true — the harness notifies on completion, which is the wake-up
perl -e 'sleep 285; print "SWARM CHECK-IN DUE: poll + triage the <session> swarm, act on exceptions, journal, re-arm.\n"'
```

The printed sentence is the next wake-up's instruction — make it name the session and the
loop so a compacted/summarized session still knows what to do. Where available, a native
scheduled wake-up (e.g. ScheduleWakeup with the same prompt) is equivalent; the background
timer is the portable-within-Claude-Code form, proven on the AT session.

**Known failure (G13):** the timer dies silently on session fork, app restart, or
teardown — no completion record. This is why Step 0 re-arms on every entry and why the
lease exists. Never assume a timer you armed in a previous context is still alive: check
the journal's last `checkin` ts on entry.

## Portable fallback (any agent app)

A bounded in-turn loop — degraded (occupies the session) but works everywhere:

```bash
for i in 1 2 3 4 5 6; do
  bash <SKILL>/scripts/conductor-poll.sh --session <S> --db <DB> --epic <E> \
    | bash <SKILL>/scripts/conductor-triage.sh
  # act on exceptions between iterations; journal; renew lease
  perl -e 'sleep 270'
done
```

Then hand back explicitly: report state and ask the user to re-invoke (or re-arm) — never
end the turn with the swarm silently unwatched.

## Codex app self-wake — TO VERIFY

Whether a Codex-app conductor session can self-re-invoke on a timer (equivalent of the
background-completion wake-up) is **unverified**. Until a certify run proves it, Codex
conductors use the portable fallback above. Verifying this is an open eval task — record
the result here and in a journal `lesson` when done.
