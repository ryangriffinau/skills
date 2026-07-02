# Worker kickoff init-prompt (fallback form)

<!--
PRIMARY form: the init-prompt invokes the bridged slash prompt so the worker loop has one
source: `Run /p-agent-swarm-launcher — epic: <EPIC_ID>, branch: <BRANCH>`.
Use THIS full text only when slash prompts are not resolvable inside the codex pane on the
target machine. Substitute every <PLACEHOLDER>. Deliver via flywheel-kickoff.sh / ntm spawn
--init-prompt as ONE line.
-->

Follow AGENTS.md (Agent Flywheel protocol). Plan of record: <PLAN_PATH>. Beads epic: <EPIC_ID>
in <BEADS_DB_PATH>. Work ONLY on branch <BRANCH> — NEVER main, NEVER git worktrees.

LOOP CONTINUOUSLY until `br ready` is empty — never stop after one bead:
1. `br ready` → claim the top unblocked bead (`br update <id> --status in_progress`).
2. RESERVE the files you will edit via Agent Mail BEFORE editing (bead id as the reason).
   Agent Mail = the MCP tools / http://127.0.0.1:8765 — NEVER scan the filesystem for tooling.
3. `cass pack --robot "<topic>"` for prior context when it may exist.
4. Implement + tests per the bead's acceptance criteria.
5. Verify ONE-SHOT only: <TYPECHECK_CMD>; the bead's own tests; `ubs --staged --fail-on-warning`;
   fresh-eyes self-review. NEVER watch modes, NEVER a persistent dev server (e2e uses the
   Playwright webServer config with reuseExistingServer).
6. `br close <id>` → commit EXPLICIT paths → push immediately.
7. Go to 1.

If a bead is blocked on something you cannot provide (external secret, missing deployment
env), mark it blocked with a note (`br comments add`), post the blocker to Agent Mail, and
MOVE ON to the next ready bead. Respect serial chains declared in the bead graph
(<SERIAL_CHAINS>): never start a blocked bead. If a bead's work already exists in the tree,
verify it, commit it, close it — do not redo it. RULE 1: never delete files without
permission. Conventional Commits, lowercase subject.
