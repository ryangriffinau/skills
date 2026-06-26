# Branching & machines — one tree, no worktrees

The flywheel is **trunk-based**: many agents work **one shared tree on one branch**, coordinating by reserving files (Agent Mail) — not by isolating on branches or worktrees.

## Why no branches/worktrees
Branch-per-agent or per-feature creates merge hell at scale, and **logical conflicts survive textual merges** — a function-signature change on branch A and a new call site on branch B merge cleanly but fail to compile. On one shared tree the second agent sees the signature change *immediately* and adapts. Worktrees also add path confusion and split one logical workstream across trees. So coordination is **Agent Mail file reservations** (who edits what) + the **beads graph** (what's ready) — not branch isolation.

## "Multiple features at once" = beads, not branches
Features are **epics/beads in one graph**, not parallel branches. The swarm works ready beads from several epics concurrently (different files, leases prevent collisions), all committing to the one branch. You add beads; you don't context-switch branches.

## One machine (the common case)
**One workstream branch at a time** → swarm it → PR → `main` → next branch. No RU, no parallel branches. The swarm makes each workstream fast enough that serial workstreams feel concurrent.

## Multiple machines
Each machine runs **its own** workstream branch (or trunk) and merges to `main`; **RU** (repo updater) keeps every machine's `main` in sync so they branch from the same base. Machines **partition workstreams** — never run the same branch's swarm on two machines (Agent Mail is per-machine localhost).

## Escape hatch (rare): a second clone, never a worktree
If you genuinely need two *isolated* workstreams concurrently on one machine, use a **separate full `git clone`** (own `.git`, own branch, own Agent Mail project via a distinct `projects_base` symlink) — a separate independent flywheel. Worktrees are the anti-pattern because they split *one* logical workstream and reintroduce the merge/consistency problem; separate clones are two deliberately-separate universes.

## Team adaptation
Emanuel commits **straight to `main`** (safety net = DCG + UBS + tests-in-beads + fresh-eyes review). For a team/product repo that wants review, keep ~95% of the benefit: **one shared *per-workstream* branch → one PR → `main`** (still one tree, still leases, still no worktrees).
