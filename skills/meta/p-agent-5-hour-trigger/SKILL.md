---
name: p-agent-5-hour-trigger
status: refining
version: 0.10.0
tags: [usage-limits, scheduling, claude-code, codex, antigravity]
updated: 2026-11-06
description: Schedule a quick check at 12:07am, 5:07am, 10:07am, 3:07pm and 8:07pm Melbourne time from Claude Code, Codex or Antigravity CLI (agy), on the provider's cloud scheduler where the CLI has one and as a local job otherwise. Checks for a terminal CLI and an existing trigger first, and removes the trigger on request. Use only when explicitly invoked.
disable-model-invocation: true
---

Run this only from Claude Code, Codex or Antigravity CLI (`agy`) in a terminal. Desktop, web and IDE apps are not supported. Run the bundled script from this skill's directory. In Codex, run the script outside the sandbox, with the user's approval.

If the user asked to remove the trigger, go to "Remove the trigger".

## 1. Check the session

```bash
scripts/agent-5-hour-trigger check
```

It prints the `host`, `surface` and `scheduler`, and exits 0 only for a terminal CLI. Exit 5 means a sandbox blocked the check, so rerun it outside the sandbox. On any other exit code, or if you cannot run shell commands, stop. Tell the user what it reported and ask them to rerun this skill from a terminal CLI.

## 2. Check for an existing trigger

- `scheduler=cloud`: run `/schedule list`. If a task named `agent-5-hour-trigger` exists, report its schedule and whether it is enabled, then stop. If it is paused, offer to enable it with `/schedule update`.
- `scheduler=local`: run `scripts/agent-5-hour-trigger status --host <host>`. If it reports `state=installed`, report that and stop. If it reports `state=broken`, add `--replace` to the install in step 3.

## 3. Schedule the trigger

When `scheduler=cloud`, the provider runs the task on its own infrastructure. Get the settings, then schedule it:

```bash
scripts/agent-5-hour-trigger plan --host <host>
```

/schedule daily usage reminder at 12:07am, 5:07am, 10:07am, 3:07pm and 8:07pm Melbourne time to quickly check in

Use the plan's `name`, `cron` and `prompt`. The task needs no repository and no connectors. If the scheduler rejects the `CRON_TZ=` form, use `cron_utc` and tell the user the times shift by an hour when daylight saving changes.

When `scheduler=local`, this CLI cannot create a cloud schedule, so install a local job that runs the CLI with the same prompt at the same times. Show the user the dry run, then install and confirm:

```bash
scripts/agent-5-hour-trigger install --host <host> --dry-run
scripts/agent-5-hour-trigger install --host <host>
scripts/agent-5-hour-trigger status --host <host>
```

The job uses launchd on macOS and crontab on Linux, so it runs only while the computer is on. A run missed during sleep happens on wake only within the same Melbourne hour.

## Remove the trigger

Run the check in step 1 first.

- `scheduler=cloud`: disable the `agent-5-hour-trigger` task with `/schedule update`. The CLI cannot delete a task, so tell the user to delete it at https://claude.ai/code/routines if they want it gone.
- `scheduler=local`: run `scripts/agent-5-hour-trigger uninstall --host <host>`, then `scripts/agent-5-hour-trigger status --host <host>` to confirm `state=not-installed`.
