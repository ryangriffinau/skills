#!/bin/bash
# PreToolUse hook for the interactive question tool (owner request 2026-10-15).
# Claude Code: matcher "AskUserQuestion". Codex: matcher "request_user_input" (blocks the turn in
# Plan mode). Both agents accept the same hookSpecificOutput deny JSON.
# Flywheel sessions (conductor and swarm panes) run inside tmux. There an interactive question
# blocks the whole turn, so /loop ticks stop and panes go idle. Deny it inside tmux; allow it
# everywhere else (desktop apps, plain terminal). Escape hatch: CLAUDE_ALLOW_ASK=1 (both agents).
cat >/dev/null
if [ -n "${TMUX:-}" ] && [ "${CLAUDE_ALLOW_ASK:-}" != "1" ]; then
	printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Flywheel session (tmux): interactive questions block the swarm. Ask the owner in plain text in your reply, record the open item on its bead, and keep working on everything else."}}'
fi
exit 0
