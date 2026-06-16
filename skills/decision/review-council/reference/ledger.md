# The decision ledger — two-tier, cross-project

Turns the council from a one-shot tool into a compounding decision system. Every verdict is logged; future runs read it to avoid re-litigating settled ground, catch reversals, close outcome loops, and weight advisors by track record.

> The ledger only compounds if the loop actually closes. The failure mode (caught by the council reviewing itself) is logging decisions but never recording outcomes — leaving a confident-looking file built on nothing. Three defenses are built in: **logging is a forced step**, the script **generates the JSON** so it can't be malformed, and the **`due` check on every run** nags you to record outcomes that have come due.

## Why two tiers
| Tier | Path | Holds | Purpose |
|---|---|---|---|
| **Project** | `<git-root or cwd>/council/ledger.jsonl` | Full decision records | Decisions live with their context; git-trackable; no cross-project bleed |
| **Global** | `~/.claude/council/calibration.jsonl` | **Content-free signal only** (`{id, project_id, decision_type, advisors, confidence, outcome}`) | Per-advisor calibration across projects — without storing any decision content |

## The helper script
Use `scripts/council-ledger.mjs` for all reads/writes (`node` is on PATH system-wide). It generates correct JSON, resolves the project root, and accepts **simple flags** so the model never hand-builds a payload.

```bash
S=~/.claude/skills/review-council/scripts/council-ledger.mjs

# at session START:
node "$S" due                # decisions past revisit-date with NO outcome yet → nag to close them
node "$S" recent 5           # last 5 decisions in THIS project (reversal/dup check)
node "$S" calibration <type> # advisor hit-rates (auto-suppressed until enough closed-loop data)

# at session END (forced) — pass flags, the script builds the JSON:
node "$S" log-decision --type pricing --question "<framed q>" --rec "<recommendation>" \
  --confidence 0.7 --kill "<what flips it>" --revisit 2026-08-01 \
  --leans "Contrarian:against,First Principles:reframe,Expansionist:for,Outsider:for,Executor:for" \
  --guests "Pricing Strategist" --mode standard          # prints the decision id

# later, when an outcome is known (often triggered by the `due` nag):
node "$S" log-outcome --id <id> --outcome right \
  --correct "Contrarian,First Principles" --notes "workshop hit 4.8/5"
```
A single JSON object (arg or stdin) still works as a fallback. `decision_type` is a short stable tag (`pricing`, `hiring`, `architecture`, `positioning`, …) — keep the vocabulary small so calibration aggregates meaningfully.

## Calibration suppression
`calibration` returns `status: "insufficient_data"` until there are **≥ 8 logged outcomes** (and shows a rate only for advisors with **≥ 3 appearances**). This is deliberate: a hit-rate built on two or three resolved cases is authoritative noise, not signal. Until then, treat advisor weighting as "no track record yet."

## How to use it in a session
1. **Step 1:** run `due` first — if anything is returned, surface it and offer to `log-outcome` now. Then `recent` (reversal/dup check) and `calibration` (track record). Calibration is a tiebreaker signal, **never an override** of the current argument's merit, and only once it's past the suppression threshold.
2. **Step 6 (chairman):** the verdict includes **confidence** (0–1), **kill-criteria**, a **revisit date**, and a one-line **pre-mortem**.
3. **Step 8 (forced):** always `log-decision` with flags. Never skip it — an unlogged council teaches the ledger nothing.

## Lineage
Karpathy's council is one local app → a single central store (≈ our global tier). Dicklesworthstone's tournament writes per-run output into the working directory (≈ our project tier). The hybrid takes both and keeps cross-project learning content-free.
