---
name: premortem-general
description: Run a pre-mortem — assume it failed, work backwards to the causes
argument-hint: "<the plan, feature, or decision>"
status: refining
version: 0.10.0
tags: [planning, prompts]
updated: 2026-11-25
---

Assume it's 6 months out and this has clearly failed.

Work backwards from the failure:

- What were the 3–5 most likely causes of death, ranked by probability?
- Which of these are we underweighting right now because they're uncomfortable?
- For the top two, what's the cheapest early signal that would warn us, and the
  single change we could make today to de-risk it?

Be specific and unsentimental. No generic risks — only ones that actually apply here.
