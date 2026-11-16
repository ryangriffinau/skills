---
name: p-fresh-eyes-review
description: Re-read recent code changes with fresh eyes and fix obvious issues
argument-hint: "[optional context, files, or diff scope]"
status: refining
version: 0.9.0
tags: [engineering, prompts]
updated: 2026-11-16
compatibility: "If the host leaves $ARGUMENTS literal, use the user message accompanying this skill invocation as its value."
---

Great, now carefully read over all of the new code you just wrote and any existing code you just modified with fresh eyes. Use ultrathink-level scrutiny.

Context:

$ARGUMENTS
