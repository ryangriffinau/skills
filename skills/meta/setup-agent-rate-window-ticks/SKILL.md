---
name: setup-agent-rate-window-ticks
status: refining
version: 0.11.0
tags: [usage-limits, scheduling, claude-code, codex, antigravity]
updated: 2026-11-16
description: Set up rate window ticks, quick model calls at set times that start each usage window at a known time, from Claude Code, Codex or Antigravity CLI (agy). Ticks run every 5 hours where the plan has a 5-hour window (12:07am, 5:07am, 10:07am, 3:07pm and 8:07pm Melbourne time by default) and weekly otherwise. They run on the provider's cloud, created from the CLI, the desktop app or the web, with a local job only as a last resort. Checks for existing ticks first and removes them on request. Use only when explicitly invoked.
disable-model-invocation: true
---

# Setup Agent Rate Window Ticks

A tick is one quick model call at a set time. It starts the provider's usage window at that time. Run the bundled script from this skill's directory. In Codex, run it outside the sandbox with the user's approval.

Defaults, which the user can change:

- Cadence: every 5 hours when the plan has a 5-hour window, weekly otherwise.
- 5-hour times: 12:07am, 5:07am, 10:07am, 3:07pm and 8:07pm, Australia/Melbourne (`--times`, `--tz`).
- Weekly time: the first :07 after the live weekly reset where the host reports one, otherwise Monday 12:07am (`--weekday`, `--time`).
- Model: Sonnet or equivalent in Claude Code, GPT Sol or equivalent in Codex, Gemini Flash or equivalent in agy (`--model-hint`). agy keeps separate windows for Gemini models and for Claude and GPT models. Tick the second group with `--group claude-gpt`.

If the user asked to remove the ticks, go to "Remove the ticks".

## 1. Check the session

```bash
scripts/rate-window-ticks check
```

It prints `host`, `surface`, `cloud_method` and `cloud_from_here`. Exit 5 means a sandbox blocked the check, so rerun it outside the sandbox. Exit 4 means no supported agent was found: stop and tell the user.

## 2. Choose the cadence

```bash
scripts/rate-window-ticks windows --host <host>
```

- `cadence=5h` or `cadence=weekly`: use it. For weekly, use `weekly_suggestion` unless the user picked a day and time.
- `cadence=ask` (agy): ask which plan agy shows at startup or in `/help`. Google AI Pro and Ultra use 5h. Other plans use weekly.
- `cadence=none`: the plan has no usage window, so stop and tell the user.

## 3. Check for existing ticks

- Claude Code: run `/schedule list` and look for `agent-rate-window-ticks`, or `agent-5-hour-trigger` from before the rename. If one exists, report its schedule and whether it is enabled, then stop. Offer to enable a paused one, and to rename an old one with `/schedule update`. List any other enabled routine that checks usage and ask whether to keep it.
- Codex: in the ChatGPT desktop app, ask the chat to look for an `agent-rate-window-ticks` scheduled task. From the CLI, ask the user to check ChatGPT's Scheduled view.
- agy: ask the user whether a remote conversation already runs the tick. `/tasks` in that conversation lists its schedules.
- Local jobs, for every host: run `scripts/rate-window-ticks status --host <host>`. `state=installed` means a local tick exists: report it and stop. `legacy_state=installed` is a job from before the rename, which the install in step 6 replaces.

## 4. Get the settings

```bash
scripts/rate-window-ticks plan --host <host> --cadence <cadence>
```

Add `--weekday` and `--time` for a weekly tick, and any `--times`, `--tz`, `--model-hint` or `--group` the user chose. It prints the `name`, `prompt`, `model_hint`, `times`, `cron` with `CRON_TZ=`, `cron_utc` and `rrule`.

## 5. Schedule the tick on the provider's cloud

Try the CLI first, then the desktop app or the web.

Claude Code (`cloud_method=routine`): create a routine from this session.

/schedule daily usage reminder at 12:07am, 5:07am, 10:07am, 3:07pm and 8:07pm Melbourne time to quickly check in using Sonnet or equivalent

Use the plan's `name`, `cron` and `prompt`, which replace these times when the user changed the cadence or times. Set the model to the current Sonnet or its equivalent. Attach no repository and no connectors. If the scheduler rejects the `CRON_TZ=` form, use `cron_utc` and tell the user the times move by an hour when daylight saving changes. Without `/schedule`, create the same routine in the Claude desktop app (choose Cloud) or at https://claude.ai/code/routines. If the organization turned scheduled tasks off, go to step 6.

Codex (`cloud_method=chatgpt-scheduled-task`): the Codex CLI cannot create scheduled tasks. Tasks created with ChatGPT Work on the web run without the user's computer, and ChatGPT Work and Codex share usage. In the ChatGPT desktop app, a task that needs a project or local files runs only while the computer is on and the app is open, so attach no project.

- `cloud_from_here=yes` (ChatGPT desktop app): create a standalone scheduled task from this chat with the plan's `name`, `prompt` and `rrule` in the plan's `tz`, the model GPT Sol or equivalent, low reasoning effort, no project, and a new chat for each run.
- Otherwise, give the user those settings and ask them to create the task with ChatGPT Work on the web, or in the ChatGPT desktop app, and wait for them to confirm.

agy (`cloud_method=remote-agent-schedule`): remote agents are the only part of agy that runs in Google's cloud. They need Google AI Pro or Ultra on a personal Google account, and they have no print mode, so give the user these steps:

1. Run `scripts/rate-window-ticks models --host agy` for the model ID.
2. Start `agy --remote-agent --model <model>` and send the plan's `remote_request`.
3. After the first tick time, open `/tasks` in that conversation and confirm the schedule fired. The docs do not say whether a schedule keeps firing after the CLI exits.

If agy says "cloud conversations are not enabled for this user", the account has no cloud scheduler, so go to step 6.

## 6. Local job, as a last resort

Install a local job only when no cloud method works for this account and the user agrees, or when the user asks for one. It runs only while the computer is on.

```bash
scripts/rate-window-ticks models --host <host>
scripts/rate-window-ticks install --host <host> --cadence <cadence> --model <model> --dry-run
scripts/rate-window-ticks install --host <host> --cadence <cadence> --model <model>
scripts/rate-window-ticks status --host <host>
```

Pass the same schedule options as the plan. Show the user the dry run before installing. Leave out `--model` when `models` finds no match, and the CLI's default model runs.

## Remove the ticks

- Claude Code: pause the `agent-rate-window-ticks` routine, or `agent-5-hour-trigger`, with `/schedule update`. The CLI cannot delete a routine; the user can delete it at https://claude.ai/code/routines.
- Codex: delete the task in ChatGPT's Scheduled view, or ask the desktop app's chat to delete it.
- agy: in the remote conversation, open `/tasks` and kill the schedule.
- Local jobs: run `scripts/rate-window-ticks uninstall --host <host>`, then `status --host <host>` to confirm `state=not-installed`. Uninstall also removes a job from before the rename.
