---
name: review-council
status: refining
version: 0.9.0
tags: [decision-making, multi-agent, peer-review]
updated: 2026-06-16
description: "Run any high-stakes question or decision through a council of 5 AI advisors (Contrarian, First Principles, Expansionist, Outsider, Executor) who independently analyze it, anonymously peer-review each other, and synthesize a chairman's verdict with a recommendation and one next step. Adds optional domain guest seats, a deep/confrontation mode, and a cross-project decision ledger that learns over time. Based on Karpathy's LLM Council. MANDATORY TRIGGERS: 'council this', 'run the council', 'review-council', 'pressure-test this', 'stress-test this', 'debate this'; add 'deep' or 'war room this' for the adversarial confrontation round. STRONG TRIGGERS (paired with a real decision/tradeoff): 'should I X or Y', 'which option', 'is this the right move', 'validate this', 'I can't decide', 'I'm torn between'. Do NOT trigger on simple yes/no questions, factual lookups, or a casual 'should I' with no tradeoff. DO trigger when the user brings a genuine decision with stakes and multiple options to pressure-test."
---

# Review Council

You ask one AI a question, you get one answer shaped by how you asked it. Claude is agreeable — frame the question one way and it finds five reasons to do it; frame it the opposite way and it finds five reasons not to. That's fine for emails, dangerous for decisions.

The council fixes this. It runs your question through 5 independent advisors who each think from a fundamentally different angle, has them peer-review each other's work anonymously, then a chairman synthesizes a final verdict — where they agree, where they clash, what was missed, and what you should actually do.

Adapted from Andrej Karpathy's LLM Council, run inside one session using sub-agents with different **thinking lenses** instead of different models.

## Modes
- **Standard** (default — `/review-council`, or "council this"): the full flow below.
- **Deep** (add `deep` after activating — e.g. `/review-council deep` — or say "deep" / "war room this"): adds the confrontation round (Step 5). Use for one-way-door, high-stakes calls.

**Mode detection:** if the invocation argument or the user's message contains `deep` (or "war room"), run Deep mode; otherwise run Standard. The user can also switch to Deep mid-run (see Step 0).

There is intentionally **no "lightweight" mode** — every council runs the full flow. This is a deliberate, settled decision: the high floor is *itself* a forcing function for robust decision-making everywhere, and the marginal cost is acceptable. The council has twice recommended adding a cheap floor for adoption; **rejected by design — do not re-add it or re-litigate.** The user controls depth *upward* (add `deep`); nothing silently downsizes a session.

## When to run the council
Run it when being wrong is expensive and there's genuine uncertainty — a real decision, multiple options, stakes, and you've been going back and forth.
- ✅ "Should I launch a $97 workshop or a $497 course?" / "Which of these 3 positioning angles is strongest?" / "Should I pivot from X to Y?"
- ❌ Factual lookups, pure creation tasks, processing tasks, or trivial choices with one obvious answer.

**What the user should bring:** the more context the sharper the output. Ideally the decision, the options, the constraints, and what's at stake. If they give you only a one-liner, enrich it from the workspace (Step 1) rather than letting advisors invent context.

## The five advisors
Thinking styles, not job titles. Three natural tensions: **Contrarian vs Expansionist** (downside vs upside), **First Principles vs Executor** (rethink vs ship), with the **Outsider** keeping everyone honest.

1. **The Contrarian** — hunts for what's wrong, missing, or will fail.
2. **The First Principles Thinker** — ignores the surface question; asks what you're *actually* solving.
3. **The Expansionist** — hunts for upside everyone's missing.
4. **The Outsider** — zero context; catches the curse of knowledge.
5. **The Executor** — can it be done, and what's the fastest path? "What do you do Monday morning?"

Full descriptions + spawn prompt: [references/advisors.md](references/advisors.md). The 5 are the permanent **spine**; the convener may add 0–2 domain guest seats (Step 2).

## How a session runs

### Step 0 — Open the session
Print one line up front: which mode is running, and — when **not** in deep mode — that deep mode is available. Example: *"🏛️ Standard council running. Deep mode (an adversarial confrontation round on the real cruxes) is available — say `deep` to switch in; otherwise I'll keep going."* **Do not wait** — continue immediately unless the user interrupts to switch.

### Step 1 — Check the ledger, enrich context, then frame
```bash
# Path to this skill's ledger script — set to wherever you installed the skill:
S="$HOME/.claude/skills/review-council/scripts/council-ledger.mjs"   # Claude Code
# S="$HOME/.codex/skills/review-council/scripts/council-ledger.mjs"  # Codex
node "$S" due                  # decisions past their revisit-date with no outcome logged
node "$S" recent 5             # prior decisions in THIS project — catch reversals / duplicates
node "$S" calibration <type>   # advisor track record (auto-suppressed until enough closed-loop data)
```
If `due` returns anything, tell the user and offer to log those outcomes now (`log-outcome`, Step 8) — this is how the ledger learns. If a near-identical recent decision exists, surface it (*"you decided the opposite N weeks ago — what changed?"*).

Scan the workspace for specific context (≤30s): `CLAUDE.md`/`AGENTS.md`, any `memory/` folder, files the user referenced. Then reframe the raw question into one neutral prompt all advisors receive: (1) core decision, (2) key context from the user, (3) key context from the workspace, (4) what's at stake. **Don't add your opinion or steer it.** If too vague, ask exactly **one** clarifying question. Save the framed question.

### Step 2 — Cast guest seats (the Convener)
Inline, fast, and **visible**. Decide whether a real discipline adds non-obvious expertise; if so cast 0–2 sharply-crafted domain guest seats, **announcing each in one line with an override** (*"Casting one guest: B2B Pricing Strategist — override?"*). If nothing qualifies, run the clean 5 — never fabricate. The convener does **not** size the session (mode is user-controlled). Guest prompt + the five anti-overweighting guards: [references/convener.md](references/convener.md).

### Step 3 — Convene the council (in parallel)
Spawn all advisors **simultaneously** — all Task/Agent calls in a single message so they run concurrently and can't bleed into each other. To keep the lenses genuinely independent (not one model's correlated output in five costumes), instruct each to reason **only** from its own angle and ignore how a balanced answer would read. Each returns 150-300 words, no hedging. Spawn instructions: [references/advisors.md](references/advisors.md); guest template in [references/convener.md](references/convener.md).

### Step 4 — Anonymized peer review (in parallel)
Collect the responses, label them A, B, C… with the advisor→letter mapping **randomized** (kills positional *and* authority bias — including the guest's), and spawn one reviewer per response in parallel. Each answers: strongest response? biggest blind spot? what did *all* miss? Template: [references/peer-review.md](references/peer-review.md). The "what did all miss" answer is the highest-value output.

### Step 5 — (Deep mode only) Confrontation round
Resolve the genuine cruxes by direct engagement: opposing advisors steelman then rebut each other; classify each crux as **factual** (resolvable — optionally fetch the fact and re-run) or **values** (an owned tradeoff). Max 2 rounds. **Never average opposing strategic positions into mush.** Full procedure: [references/deep-mode.md](references/deep-mode.md).

### Step 6 — Chairman synthesis
One agent gets everything (framed question, all responses de-anonymized, all reviews, any confrontation outcomes) and produces the verdict: agree / clash / blind-spots / recommendation / one thing to do first — plus a **baseline check** (*would a single straightforward answer have said the same? did the lenses actually diverge, or just agree in different words?*), a **confidence (0–1)**, **kill-criteria**, a **revisit date**, and a one-line **pre-mortem**. Weight by argument quality, cross-advisor convergence, and surviving peer review — **never by credential or seat**. Preserve any high-conviction minority view. Structure + template: [references/chairman.md](references/chairman.md).

### Step 7 — Report + transcript
Set `TS=$(date +%Y%m%d-%H%M%S)` and write both to `./council/` (create if missing):
- `council/council-report-<TS>.html` — self-contained, scannable briefing.
- `council/council-transcript-<TS>.md` — full transcript incl. the revealed anonymization mapping.

Spec: [references/report.md](references/report.md). Open the HTML (`open <path>`) **and tell the user the exact path** so they're never file-hunting.

### Step 8 — Log the verdict (forced final step)
Always run this — pass simple flags, the script builds the JSON (never hand-write it):
```bash
node "$S" log-decision --type "<short tag>" --question "<framed question>" --rec "<recommendation>" \
  --confidence 0.7 --kill "<what flips it>" --revisit YYYY-MM-DD \
  --leans "Contrarian:against,First Principles:reframe,Expansionist:for,Outsider:for,Executor:for" \
  --guests "<guest seats or empty>" --mode "<standard|deep>"
```
Schema, `log-outcome`, the `due` loop, and calibration suppression: [references/ledger.md](references/ledger.md).

## Notes
- **Always spawn in parallel** (advisors and reviewers each in one batched message).
- **Always anonymize before review** — especially the guest, so it wins on merit, not authority.
- **The chairman gives a real answer**, not "it depends." One recommendation, one first step. In deep mode it preserves the tradeoff rather than splitting the difference.
- **Logging is not optional.** The ledger only compounds if every verdict is logged and outcomes get closed via the `due` loop.
