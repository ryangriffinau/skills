# DCG issue draft — substring matches inside quoted payloads block the enclosing safe command

> **Status:** DRAFT for `Dicklesworthstone/destructive_command_guard`. Do **not** post
> until the operator approves. When posted, record the issue URL at the bottom.

**Title:** Guard substring-matches destructive tokens inside quoted string payloads, blocking safe enclosing commands

## Summary

DCG appears to scan the *raw text* of a command for destructive tokens (`git checkout --`,
`--force`, `-f`, `reset --hard`, etc.) rather than parsing the command's actual argv. As a
result, a **safe** command is blocked whenever a destructive-looking token appears **inside a
quoted string argument** — a JSON payload, a heredoc, an issue/bead description, a commit
message, or a log line that merely *mentions* a destructive command as prose.

The enclosing command performs no destructive action; the token is inert data. Three
independent false positives are captured below, all from real agent sessions.

## Repros

**(a) `printf` of a JSON log line was blocked** because the quoted JSON payload contained a
checkout-discard command *as prose*. The agent was appending an append-only journal line whose
`candidate` field described a guidance rule ("use a stash instead of a checkout-discard"). The
`printf ... >> journal.jsonl` is non-destructive — it only appends — but the discard token
inside the single-quoted JSON tripped the guard and the whole append was refused.

**(b) A compound command was blocked as a force-push** because an unrelated recursive-copy
flag matched a force pattern. A `cp -Rf <src> <dst>` inside a larger `&&` chain was read as a
`--force`/`-f` destructive flag; `cp -Rf` is an ordinary recursive copy, not a push. Splitting
the chain into separate simple commands cleared it.

**(c) Creating a tracker task was blocked** because the task's *description text* documented
repro (a). A `br create --description "... a bead body quoted `git checkout --` while
documenting the bug ..."` was refused — the guard matched the checkout-discard string that
existed only to *document* this very issue. The command creates a database row; it runs no git
operation at all.

## Root cause (hypothesis)

The matcher operates on the pre-tokenization command string and flags any occurrence of a
destructive token, with no awareness of shell quoting or argument boundaries. So any token that
lands inside `'...'`, `"..."`, a `printf` format/argument, a heredoc body, or a subcommand's
free-text argument is treated as if it were the operative verb of the command.

## Expected behavior

Parse the command to its actual argv (respecting shell quoting) and evaluate the **operative
command and its real flags** — not the contents of string/data payloads. Concretely:

- A token inside a single- or double-quoted argument is data, not a command; do not match it.
- `cp`, `printf`, `echo`, `br`, and other non-git binaries should never be classified by
  git-specific destructive patterns (`--force`, `reset --hard`, `checkout --`).
- Flag matching should be scoped to the binary the flag belongs to: `-f` on `cp` is not the
  `-f` on `git push`.

## Suggested fix

- Shell-tokenize first (e.g. a `shlex`-style split) and match against argv[0] + that command's
  own flags, ignoring quoted operands.
- Keep an allowlist of clearly non-destructive binaries (`printf`, `echo`, `cat`, `cp`, `mv`
  without `-f`-into-existing semantics, tracker CLIs) whose string arguments are never scanned.
- If full parsing is out of scope, at minimum skip content inside matched quote pairs and
  heredoc bodies before running the token scan.

## Impact

Agents working under DCG hit this whenever they (1) journal/log a lesson that names a
destructive command, (2) copy files recursively inside a compound command, or (3) file a
tracker task that documents a destructive-command bug. The workaround (rephrasing prose,
splitting commands, avoiding the literal tokens) is lossy — it degrades exactly the
audit-trail and documentation that safety tooling should encourage.

---

**Posting record:** _not yet posted — awaiting operator approval._
Posted URL: _n/a_
