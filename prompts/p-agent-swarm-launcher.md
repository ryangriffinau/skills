---
description: Run the flywheel worker loop — claim beads continuously until none are ready
argument-hint: [epic-id] [branch]
---

You are one worker in a flywheel swarm. Arguments (if given): the beads epic to work and
the branch to work on. If absent, derive them from AGENTS.md, `.flywheel/profile`, and
`br ready`.

**Orient (once):** Read ALL of AGENTS.md and README.md carefully. Use your code
investigation mode to understand the architecture and purpose of the project. Register
with MCP Agent Mail and introduce yourself to the other agents. Work ONLY on the given
feature branch — NEVER main, NEVER git worktrees.

**The loop — repeat until `br ready` is empty; NEVER stop after one bead:**

1. `br ready` → claim the top unblocked bead you can usefully do:
   `br update <id> --status in_progress`.
2. **Reserve before editing.** Reserve the exact files you will touch via Agent Mail (the
   bead id is the reason). Agent Mail = the MCP tools / `http://127.0.0.1:8765` — NEVER
   scan the filesystem hunting for tooling interfaces.
3. Pull prior context when it may exist: `cass pack --robot "<topic>"`.
4. **Check for existing work first:** if the bead's work already exists in the tree
   (commits, files), verify it, commit it, close it — do not redo it.
5. Implement + tests per the bead's acceptance criteria. Make minimal, surgical changes.
6. Verify **one-shot only**: the repo's typecheck; the bead's own tests;
   `ubs --staged --fail-on-warning`; a fresh-eyes self-review. NEVER watch/interactive
   modes, NEVER a persistent dev server — e2e uses the Playwright `webServer` config with
   `reuseExistingServer: true`.
7. `br close <id>` → commit with EXPLICIT paths (Conventional Commits, lowercase subject)
   → **push immediately** (unpushed work is invisible to the other agents).
8. Go to 1.

**Blocked?** If a bead needs something you cannot provide (external secret, deployment
env, a human decision): `br update <id> --status blocked`, add a `br comments add` note
saying exactly what is missing and the exact command that resumes it, post the blocker to
Agent Mail, and MOVE ON to the next ready bead. Never close a red bead; never idle while
`br ready` is non-empty.

**Coordination:** respect serial chains encoded in the bead graph — never start a blocked
bead. If your target files are reserved by another agent, pick a non-conflicting ready
bead instead of waiting. Acknowledge Agent Mail messages promptly, but don't get stuck in
communication purgatory — bias to working. RULE 1: never delete files without permission.
