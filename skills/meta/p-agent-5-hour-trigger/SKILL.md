---
name: p-agent-5-hour-trigger
status: refining
version: 0.9.0
tags: [usage-limits, scheduling, claude-code, codex, gemini-cli]
updated: 2026-11-05
description: Schedule a usage trigger at 12:07am, 5:07am, 10:07am, 3:07pm and 8:07pm Melbourne time from Claude Code, Codex or Gemini CLI, after a mechanical check that the session runs in a terminal CLI. Use only when explicitly invoked.
---

Run this only from Claude Code, Codex or Gemini CLI in a terminal. Desktop, web and IDE apps are not supported.

## 1. Check the session

Run the bundled check from this skill's directory:

```bash
scripts/agent-5-hour-trigger check
```

It prints the `host` and `surface` and exits 0 only for a terminal CLI. If it exits with any other code, or you cannot run shell commands, stop. Tell the user what it reported and ask them to rerun this skill from a terminal CLI.

## 2. Schedule the trigger

When `host=claude`:

/schedule daily usage reminder at 12:07am, 5:07am, 10:07am, 3:07pm and 8:07pm Melbourne time using Sonnet

When `host=codex` or `host=gemini`, `/schedule` is not available. Install a local job for the same times, using the lightest model this host lists in place of Sonnet. Show the user the dry run, then install and confirm:

```bash
scripts/agent-5-hour-trigger install --host <host> --model <model> --dry-run
scripts/agent-5-hour-trigger install --host <host> --model <model>
scripts/agent-5-hour-trigger status
```

The job runs the host CLI once with a one-line prompt. It uses launchd on macOS and crontab on Linux, so it runs only while the computer is on. A run missed during sleep happens on wake only within the same Melbourne hour. To remove the job, run `scripts/agent-5-hour-trigger uninstall --host <host>`.
